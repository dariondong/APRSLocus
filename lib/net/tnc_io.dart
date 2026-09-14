import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

import 'tnc_base.dart';

/// 平台实现（io 平台）：
///   - Android / iOS：原生蓝牙 SPP（RFCOMM）→ MethodChannel + EventChannel
///   - Windows：串口 TNC（用 `mode` / PowerShell 枚举 COM 口）
///   - Linux / macOS：串口 TNC（/dev/ttyUSB* 等，读写各持一个句柄）
TncTransport createTncTransport() {
  if (kIsWeb) return TncDesktopSerial();
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return TncNativeBluetooth();
    default:
      return TncDesktopSerial();
  }
}

/// ─── Android / iOS：原生蓝牙 SPP ───
///
/// Dart 侧不做任何协议处理，只搬运字节；KISS 组帧在 `kiss.dart`。
class TncNativeBluetooth implements TncTransport {
  static const MethodChannel _ch = MethodChannel('com.aprslocus/tnc');
  static const EventChannel _ev = EventChannel('com.aprslocus/tnc_events');

  StreamSubscription<dynamic>? _sub;

  @override
  bool connected = false;

  @override
  void Function(List<int> bytes)? onBytes;

  @override
  void Function(String status)? onStatus;

  @override
  void Function()? onClosed;

  @override
  void Function(String reason)? onTxFailed;

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
        if (type == 'bytes') {
          // 平台通道里 byte[] 会映射为 Uint8List；这里两种都容错
          final raw = event['data'];
          if (raw is Uint8List) {
            onBytes?.call(raw);
          } else if (raw is List) {
            onBytes?.call(raw.whereType<num>().map((n) => n.toInt()).toList());
          }
          return;
        }
        if (type == 'state') {
          final s = event['state']?.toString() ?? '';
          if (s == 'closed') {
            connected = false;
            onClosed?.call();
          } else if (s.isNotEmpty) {
            onStatus?.call(s);
          }
        }
      },
      onError: (Object e) {
        connected = false;
        onStatus?.call('$e');
        onClosed?.call();
      },
    );
  }

  @override
  Future<List<TncDevice>> listDevices() async {
    if (!await supported) return const [];
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('listBondedDevices');
      final out = <TncDevice>[];
      for (final it in raw ?? const []) {
        final d = TncDevice.fromJson(it);
        if (d != null) out.add(d);
      }
      return out;
    } catch (e) {
      onStatus?.call('$e');
      return const [];
    }
  }

  @override
  Future<String?> connect(TncDevice device) async {
    if (!await supported) return 'unsupported';
    try {
      _listen();
      await _ch.invokeMethod<bool>('connect', {'address': device.id});
      connected = true;
      return null;
    } on PlatformException catch (e) {
      connected = false;
      return e.message ?? e.code;
    } catch (e) {
      connected = false;
      return '$e';
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _ch.invokeMethod<bool>('disconnect');
    } catch (_) {}
    connected = false;
  }

  @override
  void send(Uint8List bytes) {
    if (!connected) return;
    // 两个要点，都是「蓝牙 TNC 能收不能发」事故的直接教训：
    //   ① 传的必须是 Uint8List：StandardMessageCodec 只把它编成平台的
    //      byte[]；List<int> 会编成 ArrayList，Kotlin 侧
    //      `call.argument<ByteArray>("data")` 得到 null → NO_DATA。
    //   ② invokeMethod 的失败是**异步**的，同步 try/catch 抓不到 ——
    //      必须 catchError，否则发送失败完全静默（用户只会看到
    //      「倒计时走完没反应」）。
    _ch.invokeMethod<bool>('send', {'data': bytes}).catchError((Object e) {
      onStatus?.call('$e');
      onTxFailed?.call('$e');
      return false;
    });
  }

  /// 请求系统蓝牙权限（Android 12+ 需要 BLUETOOTH_CONNECT）
  @override
  Future<bool> requestPermissions() async {
    try {
      return await _ch.invokeMethod<bool>('requestPermissions') ?? false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

/// ─── Windows / Linux / macOS：串口 TNC ───
///
/// 说明：APRS 的串口 TNC（如 Kenwood、Yaesu 内置 TNC、Direwolf 直连）走
/// 标准 KISS-over-serial。Dart 的 `dart:io` 没有串口 API（无法设置波特率），
/// 所以这里**读写各持一个句柄**：Linux/macOS 的 tty 设备支持重复打开，
/// Linux/macOS 可用；Windows 的 COM 口是独占设备，第二次打开会失败 ——
/// 此时返回明确的错误提示，而不是静默不工作。
///
/// 波特率由操作系统/驱动决定（蓝牙 SPP 无波特率概念；USB 串口通常沿用
/// 驱动默认值），如需精确控制请在系统设备管理器里设置。
class TncDesktopSerial implements TncTransport {
  RandomAccessFile? _read;
  RandomAccessFile? _write;
  bool _closing = false;

  @override
  bool connected = false;

  @override
  void Function(List<int> bytes)? onBytes;

  @override
  void Function(String status)? onStatus;

  @override
  void Function()? onClosed;

  @override
  void Function(String reason)? onTxFailed;

  @override
  Future<bool> get supported async => !kIsWeb;

  @override
  Future<bool> requestPermissions() async => true;

  /// Linux/macOS 常见串口前缀
  static const List<String> _ttyGlobs = [
    '/dev/ttyUSB',
    '/dev/ttyACM',
    '/dev/tty.usbserial',
    '/dev/tty.SLAB_USBtoUART',
    '/dev/tty.wchusbserial',
    '/dev/tty.usbmodem',
    '/dev/ttyAMA',
  ];

  @override
  Future<List<TncDevice>> listDevices() async {
    final out = <TncDevice>[];
    if (defaultTargetPlatform == TargetPlatform.windows) {
      out.addAll(await _listWindowsComPorts());
      return out;
    }
    for (final prefix in _ttyGlobs) {
      for (var i = 0; i < 8; i++) {
        final path = '$prefix$i';
        try {
          if (await File(path).exists()) {
            out.add(TncDevice(id: path, name: path.split('/').last, kind: 'serial'));
          }
        } catch (_) {}
      }
    }
    return out;
  }

  /// Windows：优先 PowerShell 取友好名，回退 `mode` 命令的纯 COM 列表
  Future<List<TncDevice>> _listWindowsComPorts() async {
    try {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        r"Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match '\(COM\d+\)' } | ForEach-Object { $_.Name }",
      ]);
      if (r.exitCode == 0) {
        final out = <TncDevice>[];
        final re = RegExp(r'\((COM\d+)\)');
        for (final line in '${r.stdout}'.split('\n')) {
          final m = re.firstMatch(line);
          if (m == null) continue;
          final id = m.group(1)!;
          final name = line.replaceAll(re, '').trim();
          out.add(TncDevice(id: id, name: name, kind: 'serial'));
        }
        if (out.isNotEmpty) return out;
      }
    } catch (_) {}
    try {
      final r = await Process.run('mode', const []);
      final re = RegExp(r'^(COM\d+):', multiLine: true);
      final out = <TncDevice>[];
      for (final m in re.allMatches('${r.stdout}')) {
        out.add(TncDevice(id: m.group(1)!, kind: 'serial'));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<String?> connect(TncDevice device) async {
    await disconnect();
    final path =
        defaultTargetPlatform == TargetPlatform.windows && !device.id.startsWith(r'\\.\')
            ? r'\\.\' + device.id
            : device.id;
    try {
      _read = await File(path).open(mode: FileMode.read);
    } catch (e) {
      return 'open-read-failed: $e';
    }
    try {
      _write = await File(path).open(mode: FileMode.append);
    } catch (e) {
      try {
        await _read?.close();
      } catch (_) {}
      _read = null;
      // Windows COM 口独占：读句柄已占用导致写句柄打不开
      return 'open-write-failed: $e';
    }
    _closing = false;
    connected = true;
    unawaited(_readLoop());
    return null;
  }

  Future<void> _readLoop() async {
    final raf = _read;
    if (raf == null) return;
    try {
      while (!_closing) {
        final chunk = await raf.read(512);
        if (chunk.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 20));
          continue;
        }
        onBytes?.call(chunk);
      }
    } catch (e) {
      if (!_closing) onStatus?.call('read-loop: $e');
    } finally {
      if (!_closing) {
        connected = false;
        onClosed?.call();
      }
    }
  }

  @override
  Future<void> disconnect() async {
    _closing = true;
    connected = false;
    final r = _read;
    final w = _write;
    _read = null;
    _write = null;
    try {
      await r?.close();
    } catch (_) {}
    try {
      await w?.close();
    } catch (_) {}
  }

  @override
  void send(Uint8List bytes) {
    final w = _write;
    if (w == null) {
      onStatus?.call('串口未打开，丢弃 ${bytes.length} 字节');
      return;
    }
    try {
      w.writeFrom(bytes);
    } catch (e) {
      // 串口写失败同样要可见（此前被吞掉）
      onStatus?.call('串口写入失败：$e');
      onTxFailed?.call('$e');
    }
  }

}
