import 'dart:typed_data';

import 'icom_lan_base.dart';
import 'icom_lan_settings.dart';

/// Web 占位：浏览器没有原始 UDP，无法直连电台。
///
/// `supported == false` 是刻意的：上层据此提示"当前平台不支持 IC-705
/// 局域网直连"，而不是让用户对着一个永远连不上的开关发呆。
class IcomLanStub implements IcomLanLink {
  IcomLanStub({required this.config});

  @override
  final IcomLanConfig config;

  @override
  Future<bool> get supported async => false;

  @override
  bool get realtime => false;

  @override
  String get backendName => 'unsupported';

  @override
  bool get capturing => false;

  @override
  bool get playing => false;

  @override
  bool get isReceiving => false;

  @override
  String get phaseLabel => '当前平台不支持 IC-705 局域网直连';

  @override
  List<String> get logs => const [];

  @override
  void Function(Uint8List pcm16le)? onPcm;

  @override
  void Function(String status)? onStatus;

  @override
  void Function()? onClosed;

  @override
  void Function()? onPlaybackDone;

  @override
  String? validateConfig() => '当前平台不支持 IC-705 局域网直连';

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<String?> startCapture({required int sampleRate}) async =>
      '当前平台不支持 IC-705 局域网直连';

  @override
  Future<void> stopCapture() async {}

  @override
  Future<String?> play(Uint8List pcm16le, {required int sampleRate}) async =>
      '当前平台不支持 IC-705 局域网直连';

  @override
  Future<void> stopPlayback() async {}

  @override
  Future<void> dispose() async {}

  @override
  void setOutputDevice(int id) {}

  @override
  void setInputDevice(int id) {}

  @override
  Future<List<AudioDevice>> listOutputDevices() async => const [];

  @override
  Future<List<AudioDevice>> listInputDevices() async => const [];
}

IcomLanLink createIcomLanLink({required IcomLanConfig config}) =>
    IcomLanStub(config: config);
