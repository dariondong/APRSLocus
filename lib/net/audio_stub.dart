import 'dart:typed_data';

import 'audio_base.dart';

/// 占位实现：平台无音频后端（或 Web）。
///
/// 注意 `realtime == false` 且 `supported == false`：上层据此提示用户
/// 「当前平台仅支持 WAV 文件方式收发」，而不是静默不工作。
class AudioStub implements AudioTransport {
  @override
  bool get realtime => false;

  @override
  String get backendName => 'unsupported';

  @override
  bool get capturing => false;

  @override
  bool get playing => false;

  @override
  void Function(Uint8List pcm16le)? onPcm;

  @override
  void Function(String status)? onStatus;

  @override
  void Function()? onClosed;

  @override
  void Function()? onPlaybackDone;

  @override
  Future<bool> get supported async => false;

  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<String?> startCapture({required int sampleRate}) async => 'unsupported';

  @override
  Future<void> stopCapture() async {}

  @override
  Future<String?> play(Uint8List pcm16le, {required int sampleRate}) async =>
      'unsupported';

  @override
  Future<void> stopPlayback() async {}

  @override
  Future<void> dispose() async {}
}

AudioTransport createAudioTransport() => AudioStub();
