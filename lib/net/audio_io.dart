import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart';

import 'audio_base.dart';
import 'audio_winmm.dart';

/// 平台实现（io 平台）：
///   - Android / iOS：原生 AudioRecord + AudioTrack（MethodChannel + EventChannel）
///   - Windows：dart:ffi 直调 winmm（见 audio_winmm.dart）
///   - Linux / macOS：暂无实时后端 → 占位（上层用 WAV 文件模式）
AudioTransport createAudioTransport() {
  if (kIsWeb) return AudioStub();
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return AudioNative();
    case TargetPlatform.windows:
      return createWinmmAudio();
    default:
      return AudioStub();
  }
}

/// ─── Android / iOS：原生实时音频 ───
///
/// Dart 侧不做任何 DSP（采样率换算/重采样也不做）—— 原生只负责
/// 「按给定采样率采集 PCM16 交上来」和「把 PCM16 播出去」，
/// AFSK 调制解调与 HDLC 帧定界都在 Dart 侧（lib/afsk.dart），
/// 因此协议实现只有一份、可单元测试。
class AudioNative implements AudioTransport {
  static const MethodChannel _ch = MethodChannel('com.aprslocus/audio');
  static const EventChannel _ev = EventChannel('com.aprslocus/audio_events');

  StreamSubscription<dynamic>? _sub;

  @override
  bool get realtime => true;

  @override
  String get backendName => 'native';

  @override
  bool get capturing => _capturing;
  bool _capturing = false;

  @override
  bool get playing => _playing;
  bool _playing = false;

  @override
  void Function(Uint8List pcm16le)? onPcm;

  @override
  void Function(String status)? onStatus;

  @override
  void Function()? onClosed;

  @override
  void Function()? onPlaybackDone;

  bool _probed = false;
  bool _supported = false;

  @override
  Future<bool> get supported async {
    if (_probed) return _supported;
    _probed = true;
    try {
      _supported = await _ch.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      _supported = false;
    } catch (_) {
      _supported = false;
    }
    return _supported;
  }

  void _listen() {
    _sub ??= _ev.receiveBroadcastStream().listen(
      (event) {
        if (event is! Map) return;
        final type = event['type']?.toString();
        if (type == 'pcm') {
          // 平台通道里 byte[] 映射为 Uint8List；两种都容错
          final raw = event['data'];
          if (raw is Uint8List) {
            onPcm?.call(raw);
          } else if (raw is List) {
            onPcm?.call(
                Uint8List.fromList(raw.whereType<num>().map((n) => n.toInt()).toList()));
          }
          return;
        }
        if (type == 'state') {
          final st = event['state']?.toString() ?? '';
          if (st == 'playDone') {
            _playing = false;
            onPlaybackDone?.call();
          } else if (st == 'captureClosed') {
            _capturing = false;
            onClosed?.call();
          } else if (st == 'playing') {
            _playing = true;
          } else if (st.isNotEmpty) {
            onStatus?.call(st);
          } else if (event['message'] != null) {
            onStatus?.call(event['message'].toString());
          }
          return;
        }
      },
      onError: (Object e) {
        _capturing = false;
        onStatus?.call('$e');
        onClosed?.call();
      },
    );
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      return await _ch.invokeMethod<bool>('requestPermissions') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> startCapture({required int sampleRate}) async {
    if (!await supported) return 'unsupported';
    try {
      _listen();
      final ok =
          await _ch.invokeMethod<bool>('startCapture', {'sampleRate': sampleRate});
      _capturing = ok ?? false;
      return _capturing ? null : 'start-failed';
    } on PlatformException catch (e) {
      _capturing = false;
      return e.message ?? e.code;
    } catch (e) {
      _capturing = false;
      return '$e';
    }
  }

  @override
  Future<void> stopCapture() async {
    try {
      await _ch.invokeMethod<bool>('stopCapture');
    } catch (_) {}
    _capturing = false;
  }

  @override
  Future<String?> play(Uint8List pcm16le, {required int sampleRate}) async {
    if (pcm16le.isEmpty) return null;
    if (!await supported) return 'unsupported';
    try {
      final ok = await _ch.invokeMethod<bool>(
          'play', {'data': pcm16le, 'sampleRate': sampleRate});
      _playing = ok ?? false;
      return _playing ? null : 'play-failed';
    } on PlatformException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return '$e';
    }
  }

  @override
  Future<void> stopPlayback() async {
    try {
      await _ch.invokeMethod<bool>('stopPlayback');
    } catch (_) {}
    _playing = false;
  }

  @override
  Future<void> dispose() async {
    await stopCapture();
    await stopPlayback();
    await _sub?.cancel();
    _sub = null;
  }
}

/// Linux / macOS 等无实时后端平台的占位实现
class AudioStub implements AudioTransport {
  @override
  bool get realtime => false;

  @override
  String get backendName => 'stub';

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
