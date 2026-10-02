/// IC-705 局域网链路的接口（平台中立部分）。
///
/// 与 `net/audio_base.dart` 的设计一致：本文件只有接口，具体实现由
/// `net/icom_lan.dart` 条件导入：
///   - Android / iOS / Windows / Linux / macOS：真实实现（`icom_lan_io.dart`）
///   - Web：占位（不支持，浏览器拿不到原始 UDP）
///
/// 为什么让它 `implements AudioTransport`：APRSLocus 的 AFSK/AX.25/TNC2
/// 全链路都挂在 `AudioTransport` 上（见 `lib/audio.dart`），所以只要把
/// "电台音频" 伪装成一个音频设备，电台连接就能复用既有收发管线，
/// 不需要改动解析、消息、地图等任何既有功能。
library;

import 'audio_base.dart';
import 'icom_lan_settings.dart';

export 'audio_base.dart' show AudioDevice;

/// IC-705 局域网链路。
abstract class IcomLanLink implements AudioTransport {
  /// 当前链路使用的配置（界面可读，不直接改）。
  IcomLanConfig get config;

  /// 是否已进入"正在接收音频"（握手全部完成）。
  bool get isReceiving;

  /// 当前握手阶段的中文描述（界面直接显示）。
  String get phaseLabel;

  /// 最近链路日志（环形缓冲，供设置页排查）。
  List<String> get logs;

  /// 配置校验；返回 null 表示可用。
  String? validateConfig();
}
