/// Windows 实时音频后端：`dart:ffi` 直调 winmm（waveIn / waveOut）
///
/// 为什么不用第三方音频插件：本项目依赖极少（见 pubspec.yaml），而 winmm 是
/// 系统自带、随 Windows 一起提供的老牌 API，`dart:ffi` 又是 SDK 内置能力 ——
/// 不引入任何依赖即可拿到 16 位 PCM 采集与播放，正好满足 AFSK 的需要。
///
/// 设计要点：
///   * **不用回调**（CALLBACK_FUNCTION）：Win32 音频回调来自驱动线程，
///     跨线程进 Dart isolate 有额外的同步与阻塞风险；这里用 CALLBACK_NULL +
///     `Timer.periodic` 轮询 buffer 的 WHDR_DONE 标志，全部逻辑留在 Dart 主
///     isolate，行为确定、易排查（代价是最多 ~15ms 的额外延迟，对 1200bd
///     数据（每比特 0.83ms、整包 1s+）完全可忽略）。
///   * 采集用 4 个 1024 样本（约 46ms）的循环缓冲；播放按「一包一次」
///     分配缓冲，播完即释放 —— APRS 发射是突发而非连续流。
///   * 所有 Win32 调用都检查返回码并转成可读文字，失败时如实报错（不会
///     静默不工作）。
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'audio_base.dart';

// ─── Win32 结构体 ───

/// WAVEFORMATEX（mmreg.h）。注意头文件把它 pack(1)，但各字段偏移与自然
/// 对齐一致；这里只传指针，Dart 侧多出的尾部填充无影响。
final class _WaveFormatEx extends Struct {
  @Uint16()
  external int wFormatTag;
  @Uint16()
  external int nChannels;
  @Uint32()
  external int nSamplesPerSec;
  @Uint32()
  external int nAvgBytesPerSec;
  @Uint16()
  external int nBlockAlign;
  @Uint16()
  external int wBitsPerSample;
  @Uint16()
  external int cbSize;
}

/// WAVEHDR（mmeapi.h）
final class _WaveHdr extends Struct {
  external Pointer<Uint8> lpData;
  @Uint32()
  external int dwBufferLength;
  @Uint32()
  external int dwBytesRecorded;
  @IntPtr()
  external int dwUser;
  @Uint32()
  external int dwFlags;
  @Uint32()
  external int dwLoops;
  external Pointer<_WaveHdr> lpNext;
  @IntPtr()
  external int reserved;
}

// ─── 常量 ───
const int _waveMapper = 0xFFFFFFFF; // WAVE_MAPPER：让系统选默认设备
const int _callbackNull = 0x00000000;
const int _whdrDone = 0x00000001;
const int _waveFormatPcm = 1;
const int _lptr = 0x0040; // LocalAlloc 标志（固定内存）

/// 采集缓冲：1024 样本 ≈ 46ms @22050Hz。4 个缓冲 ≈ 186ms 余量，
/// 足够吸收 Dart 侧解析与 UI 刷新的抖动而不断流。
const int _inBufSamples = 1024;
const int _inBufCount = 4;

/// winmm / kernel32 函数指针集合（**懒加载**：只有真正用到时才 dlopen，
/// 避免在其它平台 import 本文件就加载 winmm.dll）
class _WinmmApi {
  _WinmmApi() {
    final winmm = DynamicLibrary.open('winmm.dll');
    final k32 = DynamicLibrary.open('kernel32.dll');

    localAlloc = k32.lookupFunction<
        Pointer<Uint8> Function(Uint32, IntPtr),
        Pointer<Uint8> Function(int, int)>('LocalAlloc');
    localFree = k32.lookupFunction<Pointer<Uint8> Function(Pointer<Uint8>),
        Pointer<Uint8> Function(Pointer<Uint8>)>('LocalFree');

    waveInOpen = winmm.lookupFunction<
        Int32 Function(Pointer<IntPtr>, Uint32, Pointer<_WaveFormatEx>, IntPtr,
            IntPtr, Uint32),
        int Function(Pointer<IntPtr>, int, Pointer<_WaveFormatEx>, int, int,
            int)>('waveInOpen');
    waveInPrepareHeader = winmm.lookupFunction<
        Int32 Function(IntPtr, Pointer<_WaveHdr>, Uint32),
        int Function(int, Pointer<_WaveHdr>, int)>('waveInPrepareHeader');
    waveInUnprepareHeader = winmm.lookupFunction<
        Int32 Function(IntPtr, Pointer<_WaveHdr>, Uint32),
        int Function(int, Pointer<_WaveHdr>, int)>('waveInUnprepareHeader');
    waveInAddBuffer = winmm.lookupFunction<
        Int32 Function(IntPtr, Pointer<_WaveHdr>, Uint32),
        int Function(int, Pointer<_WaveHdr>, int)>('waveInAddBuffer');
    waveInStart = winmm.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
        'waveInStart');
    waveInStop = winmm.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
        'waveInStop');
    waveInReset =
        winmm.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'waveInReset');
    waveInClose =
        winmm.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'waveInClose');

    waveOutOpen = winmm.lookupFunction<
        Int32 Function(Pointer<IntPtr>, Uint32, Pointer<_WaveFormatEx>, IntPtr,
            IntPtr, Uint32),
        int Function(Pointer<IntPtr>, int, Pointer<_WaveFormatEx>, int, int,
            int)>('waveOutOpen');
    waveOutPrepareHeader = winmm.lookupFunction<
        Int32 Function(IntPtr, Pointer<_WaveHdr>, Uint32),
        int Function(int, Pointer<_WaveHdr>, int)>('waveOutPrepareHeader');
    waveOutUnprepareHeader = winmm.lookupFunction<
        Int32 Function(IntPtr, Pointer<_WaveHdr>, Uint32),
        int Function(int, Pointer<_WaveHdr>, int)>('waveOutUnprepareHeader');
    waveOutWrite = winmm.lookupFunction<
        Int32 Function(IntPtr, Pointer<_WaveHdr>, Uint32),
        int Function(int, Pointer<_WaveHdr>, int)>('waveOutWrite');
    waveOutReset =
        winmm.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'waveOutReset');
    waveOutClose =
        winmm.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'waveOutClose');
  }

  late final Pointer<Uint8> Function(int, int) localAlloc;
  late final Pointer<Uint8> Function(Pointer<Uint8>) localFree;
  late final int Function(Pointer<IntPtr>, int, Pointer<_WaveFormatEx>, int, int,
      int) waveInOpen;
  late final int Function(int, Pointer<_WaveHdr>, int) waveInPrepareHeader;
  late final int Function(int, Pointer<_WaveHdr>, int) waveInUnprepareHeader;
  late final int Function(int, Pointer<_WaveHdr>, int) waveInAddBuffer;
  late final int Function(int) waveInStart;
  late final int Function(int) waveInStop;
  late final int Function(int) waveInReset;
  late final int Function(int) waveInClose;
  late final int Function(Pointer<IntPtr>, int, Pointer<_WaveFormatEx>, int, int,
      int) waveOutOpen;
  late final int Function(int, Pointer<_WaveHdr>, int) waveOutPrepareHeader;
  late final int Function(int, Pointer<_WaveHdr>, int) waveOutUnprepareHeader;
  late final int Function(int, Pointer<_WaveHdr>, int) waveOutWrite;
  late final int Function(int) waveOutReset;
  late final int Function(int) waveOutClose;
}

/// 一次待播发的缓冲（要一直持有到设备播完，否则 Dart GC 后驱动读到野指针）
class _PlayItem {
  final Pointer<_WaveHdr> hdr;
  final Pointer<Uint8> data;

  const _PlayItem(this.hdr, this.data);
}

class WinmmAudio implements AudioTransport {
  _WinmmApi? _api;
  Object? _initError;

  _WinmmApi? get _lib {
    if (_api != null) return _api;
    if (_initError != null) return null;
    try {
      _api = _WinmmApi();
      return _api;
    } catch (e) {
      _initError = e;
      onStatus?.call('winmm 初始化失败：$e');
      return null;
    }
  }

  @override
  bool get realtime => true;

  @override
  String get backendName => 'winmm';

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

  // 采集状态
  int _hwi = 0; // HWAVEIN（0 = 未打开）
  Pointer<Uint8> _fmtIn = nullptr;
  final List<Pointer<_WaveHdr>> _inHdrs = [];
  final List<Pointer<Uint8>> _inBufs = [];
  Timer? _inTimer;

  // 播放状态
  int _hwo = 0; // HWAVEOUT
  Pointer<Uint8> _fmtOut = nullptr;
  int _outRate = 0;
  final List<_PlayItem> _pending = [];
  Timer? _outTimer;

  bool _disposed = false;

  // ─── 内存 ───

  Pointer<Uint8> _alloc(int bytes) {
    final p = _lib!.localAlloc(_lptr, bytes);
    if (p == nullptr) throw StateError('LocalAlloc($bytes) 失败');
    return p;
  }

  void _free(Pointer<Uint8> p) {
    if (p != nullptr) _lib?.localFree(p);
  }

  /// 写一个 16 位单声道 PCM 的 WAVEFORMATEX
  Pointer<Uint8> _makeFormat(int sampleRate) {
    final p = _alloc(sizeOf<_WaveFormatEx>()).cast<_WaveFormatEx>();
    p.ref
      ..wFormatTag = _waveFormatPcm
      ..nChannels = 1
      ..nSamplesPerSec = sampleRate
      ..nAvgBytesPerSec = sampleRate * 2
      ..nBlockAlign = 2
      ..wBitsPerSample = 16
      ..cbSize = 0;
    return p.cast<Uint8>();
  }

  // ─── 能力 / 权限 ───

  @override
  Future<bool> get supported async => _lib != null;

  @override
  Future<bool> requestPermissions() async => true; // Windows 不需要麦克风授权

  // ─── 采集 ───

  @override
  Future<String?> startCapture({required int sampleRate}) async {
    if (_disposed) return 'disposed';
    final api = _lib;
    if (api == null) return 'winmm-unavailable';
    if (_capturing) return null;
    await stopCapture();

    _fmtIn = _makeFormat(sampleRate);
    final phwi = _alloc(sizeOf<IntPtr>()).cast<IntPtr>();
    var rc = api.waveInOpen(phwi, _waveMapper, _fmtIn.cast<_WaveFormatEx>(),
        _callbackNull, 0, 0);
    if (rc != 0) {
      _free(phwi.cast<Uint8>());
      _free(_fmtIn);
      _fmtIn = nullptr;
      return 'waveInOpen: ${mmError(rc)}';
    }
    _hwi = phwi.value;
    _free(phwi.cast<Uint8>());

    final hdrSize = sizeOf<_WaveHdr>();
    for (var i = 0; i < _inBufCount; i++) {
      final data = _alloc(_inBufSamples * 2);
      final hdr = _alloc(hdrSize).cast<_WaveHdr>();
      hdr.ref
        ..lpData = data
        ..dwBufferLength = _inBufSamples * 2
        ..dwBytesRecorded = 0
        ..dwUser = 0
        ..dwFlags = 0
        ..dwLoops = 0
        ..lpNext = nullptr
        ..reserved = 0;
      rc = api.waveInPrepareHeader(_hwi, hdr, hdrSize);
      if (rc != 0) {
        await stopCapture();
        return 'waveInPrepareHeader: ${mmError(rc)}';
      }
      rc = api.waveInAddBuffer(_hwi, hdr, hdrSize);
      if (rc != 0) {
        await stopCapture();
        return 'waveInAddBuffer: ${mmError(rc)}';
      }
      _inHdrs.add(hdr);
      _inBufs.add(data);
    }
    rc = api.waveInStart(_hwi);
    if (rc != 0) {
      await stopCapture();
      return 'waveInStart: ${mmError(rc)}';
    }
    _capturing = true;
    // CALLBACK_NULL → 用轮询取数据（见文件头注释）
    _inTimer = Timer.periodic(const Duration(milliseconds: 15), (_) => _pollInput());
    onStatus?.call('winmm 采集已启动 @${sampleRate}Hz');
    return null;
  }

  void _pollInput() {
    final api = _api;
    if (api == null || _hwi == 0 || !_capturing) return;
    try {
      final hdrSize = sizeOf<_WaveHdr>();
      for (var i = 0; i < _inHdrs.length; i++) {
        final hdr = _inHdrs[i];
        if ((hdr.ref.dwFlags & _whdrDone) == 0) continue;
        var n = hdr.ref.dwBytesRecorded;
        final cap = _inBufSamples * 2;
        if (n > cap) n = cap;
        if (n > 0) {
          final cb = onPcm;
          if (cb != null) cb(Uint8List.fromList(_inBufs[i].asTypedList(n)));
        }
        // 交还缓冲：清标志后重新入队
        hdr.ref
          ..dwFlags = 0
          ..dwBytesRecorded = 0;
        final rc = api.waveInAddBuffer(_hwi, hdr, hdrSize);
        if (rc != 0) {
          onStatus?.call('waveInAddBuffer 失败：${mmError(rc)}');
        }
      }
    } catch (e) {
      onStatus?.call('采集轮询异常：$e');
    }
  }

  @override
  Future<void> stopCapture() async {
    _inTimer?.cancel();
    _inTimer = null;
    final api = _api;
    if (_hwi != 0 && api != null) {
      try {
        api.waveInStop(_hwi);
        api.waveInReset(_hwi);
        final hdrSize = sizeOf<_WaveHdr>();
        for (final h in _inHdrs) {
          api.waveInUnprepareHeader(_hwi, h, hdrSize);
        }
        api.waveInClose(_hwi);
      } catch (e) {
        onStatus?.call('关闭采集失败：$e');
      }
    }
    for (final h in _inHdrs) {
      _free(h.cast<Uint8>());
    }
    for (final b in _inBufs) {
      _free(b);
    }
    _inHdrs.clear();
    _inBufs.clear();
    _free(_fmtIn);
    _fmtIn = nullptr;
    _hwi = 0;
    _capturing = false;
  }

  // ─── 播放 ───

  Future<String?> _ensureOut(int sampleRate) async {
    final api = _lib;
    if (api == null) return 'winmm-unavailable';
    if (_hwo != 0 && _outRate == sampleRate) return null;
    await _closeOut();
    _fmtOut = _makeFormat(sampleRate);
    final phwo = _alloc(sizeOf<IntPtr>()).cast<IntPtr>();
    final rc = api.waveOutOpen(phwo, _waveMapper, _fmtOut.cast<_WaveFormatEx>(),
        _callbackNull, 0, 0);
    if (rc != 0) {
      _free(phwo.cast<Uint8>());
      _free(_fmtOut);
      _fmtOut = nullptr;
      return 'waveOutOpen: ${mmError(rc)}';
    }
    _hwo = phwo.value;
    _free(phwo.cast<Uint8>());
    _outRate = sampleRate;
    return null;
  }

  @override
  Future<String?> play(Uint8List pcm16le, {required int sampleRate}) async {
    if (_disposed) return 'disposed';
    if (pcm16le.isEmpty) return null;
    final api = _lib;
    if (api == null) return 'winmm-unavailable';
    final err = await _ensureOut(sampleRate);
    if (err != null) return err;

    final data = _alloc(pcm16le.length);
    data.asTypedList(pcm16le.length).setAll(0, pcm16le);
    final hdr = _alloc(sizeOf<_WaveHdr>()).cast<_WaveHdr>();
    hdr.ref
      ..lpData = data
      ..dwBufferLength = pcm16le.length
      ..dwBytesRecorded = 0
      ..dwUser = 0
      ..dwFlags = 0
      ..dwLoops = 0
      ..lpNext = nullptr
      ..reserved = 0;
    final hdrSize = sizeOf<_WaveHdr>();
    var rc = api.waveOutPrepareHeader(_hwo, hdr, hdrSize);
    if (rc != 0) {
      _free(hdr.cast<Uint8>());
      _free(data);
      return 'waveOutPrepareHeader: ${mmError(rc)}';
    }
    rc = api.waveOutWrite(_hwo, hdr, hdrSize);
    if (rc != 0) {
      api.waveOutUnprepareHeader(_hwo, hdr, hdrSize);
      _free(hdr.cast<Uint8>());
      _free(data);
      return 'waveOutWrite: ${mmError(rc)}';
    }
    _pending.add(_PlayItem(hdr, data));
    _playing = true;
    _outTimer ??=
        Timer.periodic(const Duration(milliseconds: 20), (_) => _pollOutput());
    return null;
  }

  void _pollOutput() {
    final api = _api;
    if (api == null || _hwo == 0) return;
    try {
      final hdrSize = sizeOf<_WaveHdr>();
      _pending.removeWhere((item) {
        if ((item.hdr.ref.dwFlags & _whdrDone) == 0) return false;
        api.waveOutUnprepareHeader(_hwo, item.hdr, hdrSize);
        _free(item.hdr.cast<Uint8>());
        _free(item.data);
        return true;
      });
      if (_pending.isEmpty) {
        _playing = false;
        _outTimer?.cancel();
        _outTimer = null;
        onPlaybackDone?.call();
      }
    } catch (e) {
      onStatus?.call('播放轮询异常：$e');
    }
  }

  @override
  Future<void> stopPlayback() async {
    _outTimer?.cancel();
    _outTimer = null;
    final api = _api;
    if (_hwo != 0 && api != null) {
      try {
        api.waveOutReset(_hwo);
        final hdrSize = sizeOf<_WaveHdr>();
        for (final item in _pending) {
          api.waveOutUnprepareHeader(_hwo, item.hdr, hdrSize);
          _free(item.hdr.cast<Uint8>());
          _free(item.data);
        }
      } catch (e) {
        onStatus?.call('停止播放失败：$e');
      }
    } else {
      for (final item in _pending) {
        _free(item.hdr.cast<Uint8>());
        _free(item.data);
      }
    }
    _pending.clear();
    _playing = false;
  }

  Future<void> _closeOut() async {
    await stopPlayback();
    final api = _api;
    if (_hwo != 0 && api != null) {
      try {
        api.waveOutClose(_hwo);
      } catch (_) {}
    }
    _hwo = 0;
    _outRate = 0;
    _free(_fmtOut);
    _fmtOut = nullptr;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopCapture();
    await _closeOut();
  }
}

/// winmm 返回码 → 可读文字（供日志与界面提示）
String mmError(int code) {
  const map = <int, String>{
    0: '成功',
    1: '未指明错误',
    2: '设备 ID 无效',
    3: '驱动未启用',
    4: '设备已被占用',
    5: '句柄无效',
    6: '未安装驱动',
    7: '内存不足',
    8: '不支持该功能',
    10: '标志无效',
    11: '参数无效',
    12: '设备忙',
    20: '驱动不支持回调',
    21: '需要更多数据',
    32: '波形格式不支持',
    33: '仍在播放',
    34: '缓冲未 prepare',
    35: '需要同步',
  };
  return 'MMSYSERR $code（${map[code] ?? '未知'}）';
}

AudioTransport createWinmmAudio() => WinmmAudio();
