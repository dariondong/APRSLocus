import 'dart:typed_data';

import 'audio_base.dart';

/// Web：浏览器可以拿麦克风（getUserMedia）与播放音频，但 Flutter Web 下
/// 需要 JS 互操作且采样率/缓冲不可控，本版本先不实现 —— 返回「不支持」，
/// UI 会提示改用 WAV 文件方式。
AudioTransport createAudioTransport() => AudioStub();

class AudioStub implements AudioTransport {
  @override
  bool get realtime => false;

  @override
  String get backendName => 'web';

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
