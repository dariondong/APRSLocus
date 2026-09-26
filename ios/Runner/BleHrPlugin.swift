import CoreBluetooth
import Flutter
import UIKit

/// 蓝牙**心率带**（BLE 标准心率服务 0x180D）的 **iOS 原生实现**。
///
/// 通道契约与 Android（`BleHrManager.kt`）完全一致：
///
///   方法通道 `com.aprslocus/blehr`
///     - `isSupported`        → Bool
///     - `requestPermissions` → Bool（iOS 首次使用蓝牙由系统自动弹窗，这里恒 true）
///     - `startScan`          → Bool
///     - `stopScan`           → true
///     - `connect {address}`  → Bool（iOS 上 `address` 是外设 **UUID 字符串**，不是 MAC）
///     - `disconnect`         → true
///     - `status`             → {connected, scanning}
///   事件通道 `com.aprslocus/blehr_events`
///     - `{type:scan, scanning}`
///     - `{type:device, id, name, rssi}`
///     - `{type:state, state:connecting|connected|disconnected, id?, name?, bonded?, reason?}`
///     - `{type:hr, bpm, contact, energy, rr, at}`
///     - `{type:battery, level}`
///
/// ── 与 Android 的差异（都要如实处理，不能假装一致）──
///   1. iOS 没有经典蓝牙 SPP → 「地址被 TNC 占用」的防冲突判定不适用；
///      TNC 链路在 iOS 上本来就不存在，这里无需比对。
///   2. iOS 用 **UUID** 标识外设（Android 用 MAC）→ `id`/`address` 走 UUID 字符串，
///      Dart 侧只做「存下来、原样传回」的搬运，因此不必改。
///
/// ── 为什么 `CBCentralManager` **延迟创建** ──
/// 只要创建 `CBCentralManager`，系统就会弹蓝牙权限。若在应用启动时（注册通道）
/// 就创建，用户**还没进心率页**就会被问「是否允许使用蓝牙」，观感很差。
/// 所以这里在第一次真正要用（`isSupported` 之外的扫描 / 连接 / 状态查询）时才创建。
///
/// ⚠️ 本文件为**未在真机验证**的初版实现：通道与字段严格对齐 Android，
/// 实际蓝牙行为（后台扫描限制、配对弹窗等）需装机后确认。
final class BleHrPlugin: NSObject {
  static let methodChannelName = "com.aprslocus/blehr"
  static let eventChannelName = "com.aprslocus/blehr_events"

  private static let hrService = CBUUID(string: "180D")
  private static let hrMeasurement = CBUUID(string: "2A37")
  private static let batteryService = CBUUID(string: "180F")
  private static let batteryLevel = CBUUID(string: "2A19")

  /// 扫描最长 15 秒自动停（与 Android 一致）：省电，也少争天线。
  private static let scanSeconds = 15.0

  private var central: CBCentralManager?
  private var sink: FlutterEventSink?
  private var scanning = false
  private var pendingScan = false
  private var scanStopTimer: Timer?
  private var peripheral: CBPeripheral?
  private var hrCharacteristic: CBCharacteristic?
  private var batteryCharacteristic: CBCharacteristic?

  /// 扫描期记住「UUID → 广播名」，连接事件里 peripheral.name 常为空时兜底。
  private var advertNames: [UUID: String] = [:]
  /// 扫描到的外设，连接时优先从这里取（系统可能还没缓存）。
  private var known: [UUID: CBPeripheral] = [:]

  private static var instances: [BleHrPlugin] = []

  static func register(with messenger: FlutterBinaryMessenger) {
    let plugin = BleHrPlugin()
    let method = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
    method.setMethodCallHandler { call, result in
      plugin.handle(call, result: result)
    }
    let events = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
    events.setStreamHandler(plugin)
    instances.append(plugin)
  }

  /// 第一次真正要用时创建（会触发系统蓝牙授权弹窗）。
  private func ensureCentral() -> CBCentralManager {
    if let c = central { return c }
    let c = CBCentralManager(delegate: self, queue: .main)
    central = c
    return c
  }

  // MARK: - 通道

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      // 不创建 central（避免只为询问就弹权限）；iOS 设备都带 BLE，乐观返回 true，
      // 真正的不可用（关机/未授权）会在 startScan / connect 时以事件说明。
      result(central?.state != .unsupported && central?.state != .unauthorized)
    case "requestPermissions":
      // iOS 的蓝牙权限在首次创建 CBCentralManager 时由系统弹窗；这里主动建一次。
      _ = ensureCentral()
      result(true)
    case "startScan":
      result(startScan())
    case "stopScan":
      stopScan(notify: true)
      result(true)
    case "connect":
      let address = (call.arguments as? [String: Any])?["address"] as? String
      if address == nil || address!.isEmpty {
        result(FlutterError(code: "NO_ADDRESS", message: "缺少设备地址", details: nil))
      } else {
        connect(address: address!, result: result)
      }
    case "disconnect":
      disconnect(reason: "已断开")
      result(true)
    case "status":
      result([
        "connected": peripheral?.state == .connected,
        "scanning": scanning,
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func emit(_ map: [String: Any?]) {
    guard let sink = sink else { return }
    sink(map)
  }

  // MARK: - 扫描

  private func startScan() -> Bool {
    let c = ensureCentral()
    switch c.state {
    case .poweredOn:
      return beginScan()
    case .unsupported, .unauthorized:
      emit(["type": "state", "state": "scanFailed", "reason": "蓝牙不可用或未授权"])
      return false
    default:
      // 还没就绪（开机后 state 会异步到 poweredOn）：挂起，就绪后自动开扫。
      pendingScan = true
      return true
    }
  }

  private func beginScan() -> Bool {
    if scanning { return true }
    central?.scanForPeripherals(
      withServices: [Self.hrService],
      options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
    )
    scanning = true
    emit(["type": "scan", "scanning": true])
    scanStopTimer?.invalidate()
    scanStopTimer = Timer.scheduledTimer(withTimeInterval: Self.scanSeconds, repeats: false) {
      [weak self] _ in
      self?.stopScan(notify: true)
    }
    return true
  }

  private func stopScan(notify: Bool) {
    pendingScan = false
    if scanning {
      central?.stopScan()
    }
    scanning = false
    scanStopTimer?.invalidate()
    scanStopTimer = nil
    if notify {
      emit(["type": "scan", "scanning": false])
    }
  }

  // MARK: - 连接

  private func connect(address: String, result: @escaping FlutterResult) {
    let c = ensureCentral()
    guard c.state == .poweredOn else {
      let reason = c.state == .unauthorized ? "未授予蓝牙权限" : "蓝牙未开启"
      result(FlutterError(code: "BT_NOT_READY", message: reason, details: nil))
      return
    }
    guard let uuid = UUID(uuidString: address) else {
      result(FlutterError(code: "BAD_ADDRESS", message: "设备地址无效", details: nil))
      return
    }
    // 扫描与连接不能同时进行（同一套射频资源，且会拖慢建链）。
    stopScan(notify: false)
    if let p = peripheral {
      c.cancelPeripheralConnection(p)
      peripheral = nil
    }
    let target = known[uuid] ?? c.retrievePeripherals(withIdentifiers: [uuid]).first
    guard let target = target else {
      result(FlutterError(code: "UNKNOWN_DEVICE", message: "找不到该设备，请重新扫描", details: nil))
      return
    }
    emit(["type": "state", "state": "connecting"])
    peripheral = target
    target.delegate = self
    c.connect(target, options: nil)
    // 建链是异步的：这里只说「请求发出去了」，成不成看 didConnect / didFailToConnect。
    result(true)
  }

  private func disconnect(reason: String) {
    if let c = central, let p = peripheral {
      c.cancelPeripheralConnection(p)
    }
    peripheral = nil
    hrCharacteristic = nil
    batteryCharacteristic = nil
    emit(["type": "state", "state": "disconnected", "reason": reason])
  }

  // MARK: - 心率测量解析（与 Android 逐位一致）

  private func handleHeartRate(_ data: Data) {
    if data.isEmpty { return }
    let flags = Int(data[0]) & 0xFF
    var i = 1
    // flags 的每一位都决定后面字段存不存在，偏移必须按位算：
    // 漏掉 energy（bit3）会把 RR 当心率读出来（真机上表现为「心率偶尔 3000」）。
    let bpm: Int
    if flags & 0x01 != 0 {
      if i + 1 >= data.count { return }
      bpm = (Int(data[i]) & 0xFF) | ((Int(data[i + 1]) & 0xFF) << 8)
      i += 2
    } else {
      if i >= data.count { return }
      bpm = Int(data[i]) & 0xFF
      i += 1
    }
    let contactSupported = flags & 0x04 != 0
    let contact = contactSupported ? (flags & 0x02 != 0) : true
    var energy: Int? = nil
    if flags & 0x08 != 0 {
      if i + 1 < data.count {
        energy = (Int(data[i]) & 0xFF) | ((Int(data[i + 1]) & 0xFF) << 8)
      }
      i += 2
    }
    var rr: [Int] = []
    if flags & 0x10 != 0 {
      while i + 1 < data.count {
        rr.append((Int(data[i]) & 0xFF) | ((Int(data[i + 1]) & 0xFF) << 8))
        i += 2
      }
    }
    if bpm <= 0 { return }
    emit([
      "type": "hr",
      "bpm": bpm,
      "contact": contact,
      "energy": energy as Any?,
      "rr": rr,
      "at": Int(Date().timeIntervalSince1970 * 1000),
    ])
  }
}

// MARK: - FlutterStreamHandler

extension BleHrPlugin: FlutterStreamHandler {
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

// MARK: - CBCentralManagerDelegate

extension BleHrPlugin: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .poweredOn:
      if pendingScan {
        pendingScan = false
        _ = beginScan()
      }
    case .poweredOff:
      if scanning { stopScan(notify: true) }
      emit(["type": "state", "state": "disconnected", "reason": "蓝牙已关闭"])
    case .unauthorized:
      emit(["type": "state", "state": "scanFailed", "reason": "未授予蓝牙权限"])
    default:
      break
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    let id = peripheral.identifier
    known[id] = peripheral
    let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
    let name = advName ?? peripheral.name ?? ""
    if !name.isEmpty { advertNames[id] = name }
    emit([
      "type": "device",
      "id": id.uuidString,
      "name": name,
      "rssi": RSSI.intValue,
    ])
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    emit([
      "type": "state",
      "state": "connected",
      "id": peripheral.identifier.uuidString,
      "name": peripheral.name ?? advertNames[peripheral.identifier] ?? "",
      // iOS 无「配对/绑定」概念，恒 false
      "bonded": false,
    ])
    peripheral.delegate = self
    peripheral.discoverServices([Self.hrService, Self.batteryService])
  }

  func centralManager(
    _ central: CBCentralManager,
    didFailToConnect peripheral: CBPeripheral,
    error: Error?
  ) {
    emit([
      "type": "state",
      "state": "disconnected",
      "reason": error?.localizedDescription ?? "连接失败",
    ])
  }

  func centralManager(
    _ central: CBCentralManager,
    didDisconnectPeripheral peripheral: CBPeripheral,
    error: Error?
  ) {
    if self.peripheral === peripheral { self.peripheral = nil }
    hrCharacteristic = nil
    batteryCharacteristic = nil
    emit([
      "type": "state",
      "state": "disconnected",
      "reason": error?.localizedDescription ?? "连接已断开",
    ])
  }
}

// MARK: - CBPeripheralDelegate

extension BleHrPlugin: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard error == nil, let services = peripheral.services else { return }
    var foundHr = false
    for service in services {
      if service.uuid == Self.hrService {
        peripheral.discoverCharacteristics([Self.hrMeasurement], for: service)
        foundHr = true
      } else if service.uuid == Self.batteryService {
        peripheral.discoverCharacteristics([Self.batteryLevel], for: service)
      }
    }
    if !foundHr {
      emit(["type": "state", "state": "disconnected", "reason": "该设备没有心率服务"])
      central?.cancelPeripheralConnection(peripheral)
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error: Error?
  ) {
    guard error == nil, let chars = service.characteristics else { return }
    for ch in chars {
      if ch.uuid == Self.hrMeasurement {
        hrCharacteristic = ch
        // setNotifyValue 会顺带写 CCCD（不写的话外设根本不推通知 —— 最常见的坑）。
        peripheral.setNotifyValue(true, for: ch)
      } else if ch.uuid == Self.batteryLevel {
        batteryCharacteristic = ch
        peripheral.readValue(for: ch)
      }
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard error == nil, let data = characteristic.value else { return }
    if characteristic.uuid == Self.hrMeasurement {
      handleHeartRate(data)
    } else if characteristic.uuid == Self.batteryLevel {
      if data.isEmpty { return }
      emit(["type": "battery", "level": Int(data[0]) & 0xFF])
    }
  }
}
