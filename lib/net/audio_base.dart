/// 音频传输层抽象（平台无关部分）
///
/// 与 `net/tnc_base.dart` 的设计完全一致：本文件只放**接口**，具体实现由
/// `net/audio.dart` 条件导入：
///   - Android / iOS：原生 AudioRecord + AudioTrack（MethodChannel + EventChannel）
///   - Windows：`dart:ffi` 直调 winmm（waveIn / waveOut）
///   - Linux / macOS：暂无实时音频后端（走 WAV 文件模式）
///   - Web：占位（不支持）
///
/// 分工：传输层**只搬 PCM 采样**，不理解 APRS —— AFSK 调制解调、HDLC 帧定界
/// 全在 Dart 侧（`lib/afsk.dart`）。这样：
///   ① 协议实现只有一份，可单元测试（test/afsk_test.dart）；
///   ② 原生侧不随协议变动而需要重新发版；
///   ③ 换后端（声卡/文件/将来加 SDR）不需要改协议代码。
library;

import 'dart:typed_data';

/// 音频后端接口
abstract class AudioTransport {
  /// 平台是否具备音频能力（Web / 无音频设备时为 false）
  Future<bool> get supported;

  /// 是否支持**实时**采集与播放。
  ///
  /// false 表示该平台只能用 WAV 文件模式（导入录音解码 / 导出音频发射），
  /// 上层据此给出提示，而不是让用户以为点一下就能收发。
  bool get realtime;

  /// 后端名称（日志/UI 展示用，**未本地化**的调试串）
  String get backendName;

  /// 采集是否正在运行
  bool get capturing;

  /// 是否正在播放
  bool get playing;

  /// 采集到的 PCM16 小端字节（单声道）
  void Function(Uint8List pcm16le)? onPcm;

  /// 状态/错误文本（未本地化，供日志）
  void Function(String status)? onStatus;

  /// 采集被系统中断（拔掉声卡、被其它 App 抢占麦克风等）
  void Function()? onClosed;

  /// 一段音频播发完毕（UI 据此把「发射中」改回空闲）
  void Function()? onPlaybackDone;

  /// 请求平台权限（Android 的 RECORD_AUDIO）。无此概念的平台恒为 true
  Future<bool> requestPermissions();

  /// 开始采集；返回 null 表示成功，否则是错误描述
  Future<String?> startCapture({required int sampleRate});

  /// 停止采集（幂等）
  Future<void> stopCapture();

  /// 播发一段 PCM16 小端单声道采样（整包一次性写入，不等待播放完毕）。
  /// 返回 null 表示已交给设备，否则是错误描述。
  Future<String?> play(Uint8List pcm16le, {required int sampleRate});

  /// 停止当前播放并清空队列（幂等）
  Future<void> stopPlayback();

  /// 释放资源（幂等）
  Future<void> dispose();
}
