import 'dart:typed_data';

import 'tnc_base.dart';

/// Web：浏览器无法访问经典蓝牙 SPP / 串口，Web Serial 也仅 Chromium 且需用户手势。
/// 本版本先不实现，返回「不支持」，UI 会给出提示。
TncTransport createTncTransport() => TncStub();

class TncStub implements TncTransport {
  @override
  bool get connected => false;

  @override
  Future<bool> get supported async => false;

  @override
  void Function(List<int> bytes)? onBytes;

  @override
  void Function(String status)? onStatus;

  @override
  void Function()? onClosed;

  @override
  void Function(String reason)? onTxFailed;

  @override
  void Function(int size)? onTxAck;

  @override
  Future<List<TncDevice>> listDevices() async => const [];

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<String?> connect(TncDevice device) async => 'unsupported';

  @override
  Future<void> disconnect() async {}

  @override
  void send(Uint8List bytes) {}
}
