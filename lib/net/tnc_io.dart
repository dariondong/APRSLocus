import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

import 'tnc_base.dart';

/// 平台实现（io 平台）：
///   - Android / iOS：原生蓝牙 SPP（RFCOMM）**与 USB-OTG 串口**
///     （TncAutoTransport 按绑定设备自动选路）
///   - Windows：串口 TNC（用 `mode` / PowerShell 枚举 COM 口）
///   - Linux / macOS：串口 TNC（/dev/ttyUSB* 等，读写各持一个句柄）
TncTransport createTncTransport() {
  if (kIsWeb) return TncDesktopSerial();
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      // Android 现在有两条射频硬件通路：蓝牙 SPP 与 USB-OTG 串口。
      // 由 TncAutoTransport 按用户绑定的设备自动选路 —— 上层（TncLink /
      // 设备页）完全不用改，扫描列表里两种设备并列出现。
      //
      // 为什么不在上层判断：绑定的设备是**持久化**的，用户下次启动
      // 直接点「连接」，那时没人会再问「这是蓝牙还是 USB」——
      // 选路必须由传输层自己按 device.kind 完成。
      return TncAutoTransport(
        bluetooth: TncNativeBluetooth(),
        usb: TncNativeUsb(),
      );
    default:
      return TncDesktopSerial();
  }
}

/// PKWDWPL 链路（Kenwood `$PKWDWPL` 航点语句）的平台实现。
///
/// 与 TNC **同一套字节搬运**（蓝牙 SPP / 串口），差别只在协议层：
/// TNC 收到的是 KISS 帧，PKWDWPL 收到的是明文的 NMEA 行。
///
/// ⚠️ 通道名必须与 TNC 不同：原生 `TncManager` 只维护**一条** socket，
/// 两个链路共用一个通道会互相拆掉对方的连接（表现为「开了 TNC 之后
/// PKWDWPL 就断，来回争抢」）。所以这里用独立通道 → 原生侧是独立实例。
TncTransport createPkwdwplTransport() {
  if (kIsWeb) return TncDesktopSerial();
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return TncNativeBluetooth(
        methodChannel: 'com.aprslocus/pkwdwpl',
        eventChannel: 'com.aprslocus/pkwdwpl_events',
      );
    default:
      return TncDesktopSerial();
  }
}

/// ─── Android / iOS：原生蓝牙 SPP ───
///
/// Dart 侧不做任何协议处理，只搬运字节；KISS 组帧在 `kiss.dart`。
class TncNativeBluetooth implements TncTransport {
  /// 平台通道名。
  ///
  /// 参数化而不是写死常量，是为了让 **PKWDWPL 链路**复用这套**已经踩过所有坑**
  /// 的蓝牙实现（代次隔离、写队列、权限回调），只换通道名 ——
  /// 复制一份必然漏掉其中某个修复。默认值仍是原来的 TNC 通道。
  final MethodChannel _ch;
  final EventChannel _ev;

  TncNativeBluetooth({
    String methodChannel = 'com.aprslocus/tnc',
    String eventChannel = 'com.aprslocus/tnc_events',
  })  : _ch = MethodChannel(methodChannel),
        _ev = EventChannel(eventChannel);

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

  @override
  void Function(int size)? onTxAck;

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

  /// 处理原生事件流。
  ///
  /// 本方法被蓝牙与 **USB 串口**共用：两者的原生实现是同一套事件协议
  /// （bytes / state / txok / txfail），分成两份必然漏掉其中一个修复 ——
  /// 事实也正是如此：`txok` / `txfail` 以前**两边都没人处理**，
  /// 于是 `TncLink.txSelfTest` 的「写出确认」从来收不到回应，
  /// 每次都会退化成「已入队但未收到写出确认」——看起来像「没确认」，
  /// 实际是「根本没人听」。
  static StreamSubscription<dynamic> wireEvents(
    Stream<dynamic> stream, {
    required void Function(List<int> bytes) onBytes,
    required void Function() onClosed,
    required void Function(String status) onStatus,
    required void Function(int size) onTxAck,
    required void Function(String reason) onTxFailed,
  }) {
    return stream.listen(
      (event) {
        if (event is! Map) return;
        final type = event['type']?.toString();
        if (type == 'bytes') {
          // 平台通道里 byte[] 会映射为 Uint8List；这里两种都容错
          final raw = event['data'];
          if (raw is Uint8List) {
            onBytes(raw);
          } else if (raw is List) {
            onBytes(raw.whereType<num>().map((n) => n.toInt()).toList());
          }
          return;
        }
        if (type == 'txok') {
          final n = (event['size'] as num?)?.toInt() ?? 0;
          onTxAck(n);
          return;
        }
        if (type == 'txfail') {
          onTxFailed(event['message']?.toString() ?? 'tx-failed');
          return;
        }
        if (type == 'state') {
          final s = event['state']?.toString() ?? '';
          if (s == 'closed') {
            onClosed();
          } else if (s.isNotEmpty) {
            onStatus(s);
          }
        }
      },
      onError: (Object e) {
        onStatus('$e');
        onClosed();
      },
    );
  }

  void _listen() {
    // 事件协议（bytes / state / txok / txfail）与 USB 串口完全一致，
    // 所以共用一份解析：分成两份必然漏掉其中一个修复（见 wireEvents 注释）。
    _sub ??= TncNativeBluetooth.wireEvents(
      _ev.receiveBroadcastStream(),
      onBytes: (b) => onBytes?.call(b),
      onClosed: () {
        connected = false;
        onClosed?.call();
      },
      onStatus: (s) => onStatus?.call(s),
      onTxAck: (n) => onTxAck?.call(n),
      onTxFailed: (r) => onTxFailed?.call(r),
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
  void Function(int size)? onTxAck;

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
    // 串口参数（波特率 / 8N1 / raw）：dart:io 没有串口 API，但**系统有工具** ——
    // Linux `stty -F`、macOS `stty -f`、Windows `mode COMx: BAUD=...`。
    // 先设好再开句柄：这些工具自己开一次设备、设参数、关闭，而 tty 参数
    // 留在设备节点上，随后打开的两个句柄就继承它。
    // 失败不阻断（原本就能用的设备不该被拦下），但要如实写进链路日志 ——
    // 「没设上却以为设上了」比报错难查得多。
    final berr = await _applySerialParams(device);
    if (berr != null) onStatus?.call('串口参数未设置：$berr');
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
      onTxAck?.call(bytes.length);
    } catch (e) {
      // 串口写失败同样要可见（此前被吞掉）
      onStatus?.call('串口写入失败：$e');
      onTxFailed?.call('$e');
    }
  }

  /// 用系统工具设串口参数。返回 null 表示成功/无需设置，否则是错误描述。
  ///
  /// [TncDevice.baud] 为 0 时用 9600（APRS 串口 TNC 最常见）。
  Future<String?> _applySerialParams(TncDevice device) async {
    final baud = device.baud > 0 ? device.baud : 9600;
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        // mode 的口令形式：mode COM3: BAUD=9600 PARITY=N DATA=8 STOP=1
        final port = device.id.replaceAll(r'\\.\', '');
        final r = await Process.run('cmd', [
          '/c',
          'mode', '$port:', 'BAUD=$baud', 'PARITY=N', 'DATA=8', 'STOP=1',
        ]);
        return r.exitCode == 0 ? null : 'mode 退出码 ${r.exitCode}：${r.stderr}';
      }
      // Linux 用 -F，macOS 用 -f（没有 -F）
      final flag = defaultTargetPlatform == TargetPlatform.macOS ? '-f' : '-F';
      final r = await Process.run('stty', [
        flag, device.id, '$baud', 'cs8', '-cstopb', '-parenb', 'raw', '-echo',
      ]);
      return r.exitCode == 0
          ? null
          : 'stty 退出码 ${r.exitCode}：${r.stderr}';
    } catch (e) {
      return '$e';
    }
  }
}

/// ─── Android：USB 串口（USB-OTG 硬件串口）───
///
/// 为什么需要它：Android 上此前只有经典蓝牙 SPP。USB-OTG 转串口线
/// （CH340 / CP2102 / FTDI / PL2303）与电台自带 USB 口是**最便宜、
/// 延迟最低、最不容易被系统限流**的接法，却没有入口。
///
/// 与蓝牙侧**共用同一套事件协议**（bytes / state / txok / txfail），
/// 因此 `wireEvents` 只有一份 —— 分成两份必然漏掉其中某个修复。
///
/// 设备标识是 `vid:pid:serial`（由原生侧生成）：序列号使同一根线重插后
/// 标识稳定，而绑定的设备是要持久化的（下次启动直接连）。
class TncNativeUsb implements TncTransport {
  static const MethodChannel _ch =
      MethodChannel('com.aprslocus/usbserial');
  static const EventChannel _ev =
      EventChannel('com.aprslocus/usbserial_events');

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

  @override
  void Function(int size)? onTxAck;

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
    _sub ??= TncNativeBluetooth.wireEvents(
      _ev.receiveBroadcastStream(),
      onBytes: (b) => onBytes?.call(b),
      onClosed: () {
        connected = false;
        onClosed?.call();
      },
      onStatus: (s) => onStatus?.call(s),
      onTxAck: (n) => onTxAck?.call(n),
      onTxFailed: (r) => onTxFailed?.call(r),
    );
  }

  @override
  Future<List<TncDevice>> listDevices() async {
    if (!await supported) return const [];
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('listDevices');
      final out = <TncDevice>[];
      for (final it in raw ?? const []) {
        final d = TncDevice.fromJson(it);
        if (d != null) out.add(d.copyWith(kind: 'usb'));
      }
      return out;
    } catch (e) {
      onStatus?.call('$e');
      return const [];
    }
  }

  @override
  Future<bool> requestPermissions() async {
    // USB 的授权是**按设备**、由系统弹窗完成的（见原生 connect），
    // 没有可预先申请的运行时权限。恒为 true —— 否则会把「还没插线」
    // 误报成「没有权限」。
    try {
      return await _ch.invokeMethod<bool>('requestPermissions') ?? true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<String?> connect(TncDevice device) async {
    if (!await supported) return 'unsupported';
    try {
      _listen();
      final ok = await _ch.invokeMethod<bool>('connect', {
        'id': device.id,
        'baudRate': device.baud > 0 ? device.baud : 9600,
      });
      connected = ok ?? false;
      return connected ? null : 'open-failed';
    } on PlatformException catch (e) {
      connected = false;
      // 错误码 → 可读原因：授权被拒 / 设备不在 / 被占用 三者对用户的意义
      // 完全不同（后两个要动手插拔或关掉别的串口应用）。
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
    // 与蓝牙侧同一条教训：必须传 Uint8List（StandardMessageCodec 只把它
    // 编成 byte[]，List<int> 会编成 ArrayList → Kotlin 侧取到 null），
    // 且 invokeMethod 的失败是**异步**的，必须 catchError 才不会静默。
    _ch.invokeMethod<bool>('send', {'data': bytes}).catchError((Object e) {
      onStatus?.call('$e');
      onTxFailed?.call('$e');
      return false;
    });
  }

  /// 当前链路的芯片与波特率（日志/界面提示用）
  Future<Map<String, dynamic>> info() async {
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('info');
      return r ?? const {};
    } catch (_) {
      return const {};
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

/// ─── Android：蓝牙 SPP 与 USB 串口之间的自动选路 ───
///
/// 为什么必须自动：绑定的设备是**持久化**的，用户下次启动直接点「连接」——
/// 那一刻没有人会问「这件设备是蓝牙还是 USB」。选路只能由传输层按
/// [TncDevice.kind] 自己完成。
///
/// 同一时刻只保持**一条**链路（与 `TncLink` 的单连接模型一致）：
/// 连 USB 前先断蓝牙，反之亦然。两条同时开着只会把接收字节流瓜分掉
/// （串口两个句柄各读一部分 / 蓝牙第二条 RFCOMM 顶掉第一条），
/// 症状正是「能发不能收」。
class TncAutoTransport implements TncTransport {
  TncAutoTransport({required this.bluetooth, required this.usb});

  final TncTransport bluetooth;
  final TncTransport usb;

  TncTransport? _active;

  @override
  bool get connected => _active?.connected ?? false;

  @override
  Future<bool> get supported async =>
      await bluetooth.supported || await usb.supported;

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

  /// 把两个后端的回调都接到同一个出口。切路时**不需要**重接：
  /// 回调闭包指向本对象的字段，字段由上层赋值，与当前活跃后端无关。
  void _wire() {
    for (final t in [bluetooth, usb]) {
      t.onBytes = (b) => onBytes?.call(b);
      t.onStatus = (s) => onStatus?.call(s);
      t.onTxAck = (n) => onTxAck?.call(n);
      t.onTxFailed = (r) => onTxFailed?.call(r);
      t.onClosed = () {
        // 只有活跃后端断开才算链路断开：切换时的关闭是预期行为
        if (t == _active) onClosed?.call();
      };
    }
  }

  bool _wired = false;

  @override
  Future<List<TncDevice>> listDevices() async {
    if (!_wired) {
      _wire();
      _wired = true;
    }
    final out = <TncDevice>[];
    out.addAll(await bluetooth.listDevices());
    out.addAll(await usb.listDevices());
    return out;
  }

  @override
  Future<bool> requestPermissions() async {
    if (!_wired) {
      _wire();
      _wired = true;
    }
    // 只问蓝牙要运行时权限：USB 那边是按设备授权的系统弹窗，
    // 没有可预先申请的东西。两个都问会让纯 USB 用户莫名多吃一个蓝牙授权框。
    return bluetooth.requestPermissions();
  }

  @override
  Future<String?> connect(TncDevice device) async {
    if (!_wired) {
      _wire();
      _wired = true;
    }
    final target = device.isUsb ? usb : bluetooth;
    final other = device.isUsb ? bluetooth : usb;
    // 切路：先把另一条断干净（单连接模型）
    if (other.connected) {
      try {
        await other.disconnect();
      } catch (_) {}
    }
    _active = target;
    return target.connect(device);
  }

  @override
  Future<void> disconnect() async {
    final a = _active;
    _active = null;
    try {
      await a?.disconnect();
    } catch (_) {}
    // 另一条也顺手断掉：用户点的是「断开」，不该留下一条没人认领的链路
    for (final t in [bluetooth, usb]) {
      if (t != a && t.connected) {
        try {
          await t.disconnect();
        } catch (_) {}
      }
    }
  }

  @override
  void send(Uint8List bytes) {
    final a = _active;
    if (a == null) {
      onTxFailed?.call('no-active-link');
      return;
    }
    a.send(bytes);
  }
}
