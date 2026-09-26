import AVFoundation
import Flutter
import UIKit

/// 声卡 TNC（AFSK 1200 / Bell 202）的 **iOS 原生音频链路**。
///
/// 与 Android（`AudioManager.kt`）一致：原生侧**只搬 PCM 采样，不理解 APRS** ——
/// AFSK 调制解调、HDLC 帧定界全在 Dart 侧（`lib/afsk.dart`）。
///
/// 通道契约：
///   方法通道 `com.aprslocus/audio`
///     - `isSupported`        → Bool
///     - `requestPermissions` → Bool（麦克风权限）
///     - `startCapture {sampleRate}` → Bool
///     - `stopCapture`        → true
///     - `play {data, sampleRate}`   → Bool
///     - `stopPlayback`       → true
///   事件通道 `com.aprslocus/audio_events`
///     - `{type:pcm, data}`（16 位单声道小端）
///     - `{type:state, state, message?}`
///       状态码与 Android 同名：`captureStarted:<src>` / `captureClosed` /
///       `playing` / `playDone` / `error`
///
/// 采集用 `AVAudioEngine` 的 inputNode tap，经 `AVAudioConverter` 转成目标采样率的
/// Int16 单声道；播放用 `AVAudioPlayerNode`。**半双工**：发射期间真的停掉采集
/// （否则会把自己的声音收回来，既污染 DPLL 又可能被当外来报文），播完恢复。
///
/// ⚠️ 本文件为**未在真机验证**的初版实现：通道与字段严格对齐 Android，
/// 实际音质 / 回声 / 采样率转换表现需装机后用自检与对端（Direwolf）确认。
final class AudioPlugin: NSObject {
  static let methodChannelName = "com.aprslocus/audio"
  static let eventChannelName = "com.aprslocus/audio_events"

  /// 采集读块：1024 样本 ≈ 46ms @22050Hz（与 Android 一致）。
  private static let readSamples: AVAudioFrameCount = 1024

  private var sink: FlutterEventSink?

  private var captureEngine: AVAudioEngine?
  private var captureConverter: AVAudioConverter?
  private var inputFormat: AVAudioFormat?
  private var targetFormat: AVAudioFormat?
  private var captureWanted = false
  private var capturePaused = false

  private var playerEngine: AVAudioEngine?
  private var playerNode: AVAudioPlayerNode?
  private var playing = false

  private static var instances: [AudioPlugin] = []

  static func register(with messenger: FlutterBinaryMessenger) {
    let plugin = AudioPlugin()
    let method = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
    method.setMethodCallHandler { call, result in
      plugin.handle(call, result: result)
    }
    let events = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
    events.setStreamHandler(plugin)
    instances.append(plugin)
  }

  // MARK: - 通道

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(true)
    case "requestPermissions":
      requestRecordPermission(result: result)
    case "startCapture":
      let rate = (call.arguments as? [String: Any])?["sampleRate"] as? Int ?? 22050
      result(startCapture(sampleRate: rate))
    case "stopCapture":
      stopCapture(notify: true)
      result(true)
    case "play":
      let args = call.arguments as? [String: Any]
      let rate = args?["sampleRate"] as? Int ?? 22050
      let data = Self.bytes(from: args?["data"])
      if data == nil || data!.isEmpty {
        result(FlutterError(code: "NO_DATA", message: "缺少音频数据", details: nil))
      } else {
        result(play(data: data!, sampleRate: rate))
      }
    case "stopPlayback":
      stopPlayback()
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func bytes(from value: Any?) -> Data? {
    if let typed = value as? FlutterStandardTypedData { return typed.data }
    if let data = value as? Data { return data }
    return nil
  }

  private func emit(_ map: [String: Any?]) {
    guard let sink = sink else { return }
    DispatchQueue.main.async { sink(map) }
  }

  private func emitState(_ state: String, message: String? = nil) {
    var m: [String: Any?] = ["type": "state", "state": state]
    if let message = message { m["message"] = message }
    emit(m)
  }

  private func emitError(_ message: String) {
    emitState("error", message: message)
  }

  // MARK: - 权限 / 会话

  private func requestRecordPermission(result: @escaping FlutterResult) {
    if #available(iOS 17.0, *) {
      AVAudioApplication.requestRecordPermission { granted in
        DispatchQueue.main.async { result(granted) }
      }
    } else {
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        DispatchQueue.main.async { result(granted) }
      }
    }
  }

  private func hasRecordPermission() -> Bool {
    if #available(iOS 17.0, *) {
      return AVAudioApplication.shared.recordPermission == .granted
    } else {
      return AVAudioSession.sharedInstance().recordPermission == .granted
    }
  }

  @discardableResult
  private func activateSession() -> Bool {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(
        .playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
      try session.setActive(true)
      return true
    } catch {
      emitError("音频会话初始化失败：\(error.localizedDescription)")
      return false
    }
  }

  private func deactivateSession() {
    try? AVAudioSession.sharedInstance().setActive(
      false, options: .notifyOthersOnDeactivation)
  }

  // MARK: - 采集

  private func startCapture(sampleRate: Int) -> Bool {
    guard hasRecordPermission() else {
      emitError("缺少录音权限（麦克风）")
      return false
    }
    captureWanted = true
    if captureEngine != nil { return true }
    return startCaptureInternal(sampleRate: sampleRate)
  }

  private func startCaptureInternal(sampleRate: Int) -> Bool {
    guard activateSession() else { return false }
    let engine = AVAudioEngine()
    let input = engine.inputNode
    let inFormat = input.outputFormat(forBus: 0)
    guard inFormat.sampleRate > 0,
      let outFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: Double(sampleRate),
        channels: 1,
        interleaved: false)
    else {
      emitError("采样率 \(sampleRate) Hz 不受支持")
      return false
    }
    guard let converter = AVAudioConverter(from: inFormat, to: outFormat) else {
      emitError("采样率转换器创建失败")
      return false
    }
    inputFormat = inFormat
    targetFormat = outFormat
    captureConverter = converter

    input.installTap(onBus: 0, bufferSize: Self.readSamples, format: inFormat) {
      [weak self] buffer, _ in
      self?.handleInput(buffer)
    }
    engine.prepare()
    do {
      try engine.start()
    } catch {
      input.removeTap(onBus: 0)
      emitError("音频采集启动失败：\(error.localizedDescription)")
      return false
    }
    captureEngine = engine
    emitState("captureStarted:AVAudioEngine")
    return true
  }

  private func handleInput(_ buffer: AVAudioPCMBuffer) {
    guard let converter = captureConverter, let outFormat = targetFormat else { return }
    let ratio = outFormat.sampleRate / buffer.format.sampleRate
    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
    guard capacity > 0,
      let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity)
    else { return }
    var consumed = false
    var error: NSError?
    let status = converter.convert(to: out, error: &error) { _, outStatus in
      if consumed {
        outStatus.pointee = .noDataNow
        return nil
      }
      consumed = true
      outStatus.pointee = .haveData
      return buffer
    }
    if status == .error {
      if let error = error { emitError("采集转换失败：\(error.localizedDescription)") }
      return
    }
    guard out.frameLength > 0, let ptr = out.int16ChannelData?[0] else { return }
    let byteCount = Int(out.frameLength) * MemoryLayout<Int16>.size
    emit(["type": "pcm", "data": Data(bytes: ptr, count: byteCount)])
  }

  private func stopCapture(notify: Bool) {
    captureWanted = false
    teardownCapture()
    if notify { emitState("captureClosed") }
  }

  private func teardownCapture() {
    if let engine = captureEngine {
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
    }
    captureEngine = nil
    captureConverter = nil
    inputFormat = nil
    targetFormat = nil
    deactivateSession()
  }

  /// 发射前半双工暂停（不通知 Dart，Dart 仍以为在采集 —— 与 Android 同口径）。
  private func pauseCapture() {
    guard captureWanted, captureEngine != nil else { return }
    capturePaused = true
    if let engine = captureEngine {
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
    }
    captureEngine = nil
    captureConverter = nil
  }

  private func resumeCapture() {
    guard capturePaused else { return }
    capturePaused = false
    if captureWanted {
      let rate = Int(targetFormat?.sampleRate ?? 22050)
      _ = startCaptureInternal(sampleRate: rate)
    }
  }

  // MARK: - 播放

  private func play(data: Data, sampleRate: Int) -> Bool {
    stopPlayback()
    guard activateSession() else { return false }
    guard
      let format = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: Double(sampleRate),
        channels: 1,
        interleaved: false)
    else {
      emitError("播放采样率 \(sampleRate) Hz 不受支持")
      return false
    }
    let frames = AVAudioFrameCount(data.count / MemoryLayout<Int16>.size)
    guard frames > 0, let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
    else {
      emitError("音频数据无效")
      return false
    }
    buf.frameLength = frames
    if let dst = buf.int16ChannelData?[0] {
      data.withUnsafeBytes { raw in
        if let base = raw.baseAddress { memcpy(dst, base, data.count) }
      }
    }

    // 半双工：先停采集，避免把自己的发射收回来
    pauseCapture()

    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: format)
    engine.prepare()
    do {
      try engine.start()
    } catch {
      emitError("播放引擎启动失败：\(error.localizedDescription)")
      resumeCapture()
      return false
    }
    playerEngine = engine
    playerNode = player
    playing = true
    emitState("playing")
    player.scheduleBuffer(buf, at: nil, options: [], completionHandler: { [weak self] in
      DispatchQueue.main.async {
        guard let self = self else { return }
        self.playerNode?.stop()
        self.playerEngine?.stop()
        self.playerNode = nil
        self.playerEngine = nil
        self.playing = false
        // 半双工收尾：恢复采集后再告诉上层「播完了」。
        // ⚠ 会话**不能**在这里无条件 setActive(false)：恢复采集刚把它打开，
        // 关掉会把刚恢复的采集一起停掉。只有确实没有采集在跑时才收尾。
        self.resumeCapture()
        if self.captureEngine == nil { self.deactivateSession() }
        self.emitState("playDone")
      }
    })
    player.play()
    return true
  }

  private func stopPlayback() {
    if playerNode != nil || playerEngine != nil {
      playerNode?.stop()
      playerEngine?.stop()
      playerNode = nil
      playerEngine = nil
    }
    if playing {
      playing = false
      resumeCapture()
      if captureEngine == nil { deactivateSession() }
    }
  }
}

// MARK: - FlutterStreamHandler

extension AudioPlugin: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}
