import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'rig_link_base.dart';

RigLink createRigLink() => RigIo();

/// rigctld 的文本协议客户端（桌面 / 移动端）。
///
/// 为什么走 rigctld 而不是链 libhamlib：hamlib 是 C 库，各平台要各自打一份
/// （Windows 那份带三个 mingw 运行时 DLL，约 12 MB），而 rigctld 本来就是
/// hamlib 自己的常驻进程，协议是纯文本、一行一条。这样这台机器上不需要
/// 任何原生依赖，用户自己起 `rigctld -m <型号> -r <串口>` 就能用；把
/// rigctld 跑到另一台机器上也照用。
///
/// 用**扩展格式**（命令前加 `+`）：回包除了结尾的 `RPRT <code>`，还有一行
/// `键: 值`，比短格式（`f` 只回一个数、`m` 回两行分不清谁是谁）好解析；
/// 就算服务端开了 `--vfo`（短格式会先回一行 VFO 名）也不会认错。
class RigIo implements RigLink {
  Socket? _sock;
  StreamSubscription<Uint8List>? _sub;

  /// 还没换行的尾巴：TCP 不保证一次 `listen` 正好是一个整包。
  String _carry = '';

  /// 当前那条命令已经收到的行（不含结尾的 `RPRT`）。
  final List<String> _lines = <String>[];

  /// 正在等回包的那一次请求。
  Completer<_Reply>? _waiter;

  String _err = '';
  bool _connected = false;

  /// 命令排队：同一个 socket 上两条命令不能交错，回包都以 `RPRT` 结尾，
  /// 交错就分不清谁是谁的。所以一条跑完再发下一条。
  Future<void> _tail = Future<void>.value();

  @override
  bool get connected => _connected;

  @override
  String get lastError => _err;

  @override
  Future<bool> connect(String host, int port) async {
    disconnect();
    _err = '';
    try {
      final s = await Socket.connect(host, port,
          timeout: const Duration(seconds: 4));
      s.setOption(SocketOption.tcpNoDelay, true);
      _sock = s;
      _connected = true;
      _sub = s.listen(
        _onData,
        onError: (Object e) => _fail(_short(e)),
        onDone: () => _fail('closed'),
        cancelOnError: true,
      );
      return true;
    } catch (e) {
      _err = _short(e);
      _connected = false;
      return false;
    }
  }

  @override
  void disconnect() {
    _connected = false;
    _lines.clear();
    _carry = '';
    final w = _waiter;
    _waiter = null;
    if (w != null && !w.isCompleted) {
      w.complete(const _Reply(-1, <String>[]));
    }
    _sub?.cancel();
    _sub = null;
    try {
      _sock?.destroy();
    } catch (_) {}
    _sock = null;
  }

  /// socket 掉了：标记断开，正在等的那一条立刻失败，不干等超时。
  void _fail(String why) {
    _err = why;
    _connected = false;
    _sub?.cancel();
    _sub = null;
    _sock = null;
    final w = _waiter;
    _waiter = null;
    if (w != null && !w.isCompleted) {
      w.complete(const _Reply(-1, <String>[]));
    }
  }

  void _onData(Uint8List data) {
    _carry += utf8.decode(data, allowMalformed: true);
    var i = _carry.indexOf('\n');
    while (i >= 0) {
      final line = _carry.substring(0, i).replaceAll('\r', '');
      _carry = _carry.substring(i + 1);
      if (line.startsWith('RPRT')) {
        final code = int.tryParse(line.substring(4).trim()) ?? -1;
        final lines = List<String>.from(_lines);
        _lines.clear();
        final w = _waiter;
        _waiter = null;
        if (w != null && !w.isCompleted) w.complete(_Reply(code, lines));
      } else if (line.trim().isNotEmpty) {
        _lines.add(line);
      }
      i = _carry.indexOf('\n');
    }
  }

  Future<_Reply?> _cmd(String c) {
    final prev = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    return prev.then((_) async {
      try {
        return await _send(c);
      } finally {
        if (!gate.isCompleted) gate.complete();
      }
    });
  }

  Future<_Reply?> _send(String c) async {
    final s = _sock;
    if (s == null || !_connected) {
      _err = 'not-connected';
      return null;
    }
    final w = Completer<_Reply>();
    _waiter = w;
    _lines.clear();
    _carry = '';
    try {
      s.write('+$c\n');
    } catch (e) {
      _err = _short(e);
      _fail(_err);
      return null;
    }
    try {
      return await w.future.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      if (identical(_waiter, w)) _waiter = null;
      _err = 'timeout';
      return null;
    }
  }

  @override
  Future<RigStatus?> status() async {
    final info = await _cmd('\\get_info');
    final f = await _cmd('f');
    final m = await _cmd('m');
    if (info == null && f == null && m == null) return null;
    return RigStatus(
      freqHz: int.tryParse(f?.v('Frequency') ?? ''),
      mode: m?.v('Mode') ?? '',
      info: info?.v('Info') ?? '',
    );
  }

  @override
  Future<bool> setFreq(int hz) async {
    final r = await _cmd('F $hz');
    return r != null && r.code == 0;
  }

  /// 设模式。passband 传 0 表示「这个模式的默认带宽」，免得为每个模式各记
  /// 一个数字；hamlib 自己会换成该模式的标准值（实测 `M FM 0` 之后
  /// `m` 回 `FM 15000`）。
  @override
  Future<bool> setMode(String mode) async {
    final r = await _cmd('M $mode 0');
    return r != null && r.code == 0;
  }

  @override
  Future<bool> setPtt(bool on) async {
    final r = await _cmd('T ${on ? 1 : 0}');
    return r != null && r.code == 0;
  }

  String _short(Object e) {
    final t = '$e';
    return t.length > 120 ? t.substring(0, 120) : t;
  }
}

/// 一条回包：结尾的返回码 + 前面那些 `键: 值` 行。
class _Reply {
  final int code;
  final List<String> lines;
  const _Reply(this.code, this.lines);

  /// 取 `键: 值` 里的值（键区分大小写，与 hamlib 的写法一致）。
  String? v(String key) {
    for (final l in lines) {
      if (l.startsWith('$key:')) return l.substring(key.length + 1).trim();
    }
    return null;
  }
}
