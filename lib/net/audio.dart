// 音频传输层工厂（条件导入）
//   - Android / iOS：原生 AudioRecord + AudioTrack
//   - Windows：dart:ffi 直调 winmm（waveIn / waveOut）
//   - Linux / macOS：无实时后端（仅 WAV 文件模式，由 lib/audio.dart 处理）
//   - Web：占位（不支持）
import 'audio_base.dart';
export 'audio_base.dart';
import 'audio_stub.dart'
    if (dart.library.io) 'audio_io.dart'
    if (dart.library.html) 'audio_web.dart' as impl;

AudioTransport createAudioTransport() => impl.createAudioTransport();
