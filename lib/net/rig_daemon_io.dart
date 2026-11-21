import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'rig_daemon_base.dart';

RigDaemon createRigDaemon() => RigDaemonIo();

/// 真起进程：本机一份 rigctld，TCP 那一头由 `RigIo` 连。
///
/// 找程序的顺序：安装包自带 → 系统 PATH。Windows 安装包里带的是官方 w64 包
/// 里的 `rigctld.exe` 与它要的两个 DLL（CI 取、按官方 SHA256 校验，见
/// `.github/workflows/build-release.yml` 的「Bundle Hamlib rigctld」）。
/// Linux / macOS 没有官方二进制，退回系统的 `rigctld`。
///
/// 一处刻意的取舍：**端口已被占用就直接报错**，不硬起。上一次的 rigctld 还
/// 活着时，新进程会 bind 失败并立刻退出，而我们这边一看端口能连上就会以为
/// 「起好了」——那其实是连到了旧的那个，型号和串口都是旧的。
class RigDaemonIo implements RigDaemon {
  Process? _p;
  String _exe = '';
  String _log = '';
  RigDaemonError _err = RigDaemonError.none;

  /// rigctld 输出的最后几行，界面与日志里都用它。
  final List<String> _lines = <String>[];

  static const int _maxLines = 12;

  @override
  bool get supported =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  bool get running => _p != null;

  @override
  String get exe => _exe;

  @override
  RigDaemonError get error => _err;

  @override
  String get log => _log;

  /// 可执行文件名：Windows 要带 `.exe`，否则 `Process.start` 报找不到文件。
  String get _exeName => Platform.isWindows ? 'rigctld.exe' : 'rigctld';

  @override
  Future<String> locate() async {
    if (_exe.isNotEmpty) return _exe;
    final here = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;
    for (final dir in <String>['$here${sep}hamlib', '$here${sep}hamlib${sep}bin']) {
      final path = '$dir$sep$_exeName';
      if (await File(path).exists()) return _exe = path;
    }
    final found = await _which();
    return _exe = found;
  }

  /// PATH 里那一个。找不到返回空串（`which` 的退出码非 0 也算找不到）。
  Future<String> _which() async {
    try {
      final r = Platform.isWindows
          ? await Process.run('where', <String>['rigctld.exe'])
          : await Process.run('/bin/sh', <String>['-c', 'command -v rigctld']);
      if (r.exitCode != 0) return '';
      final lines = '${r.stdout}'.split(RegExp(r'\r?\n'));
      for (final l in lines) {
        final t = l.trim();
        if (t.isNotEmpty) return t;
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  @override
  Future<bool> start(RigDaemonConfig cfg) async {
    if (!supported) {
      _err = RigDaemonError.unsupported;
      return false;
    }
    if (cfg.model <= 0) {
      _err = RigDaemonError.noModel;
      return false;
    }
    await stop();
    _err = RigDaemonError.none;
    _lines.clear();
    _log = '';
    final path = await locate();
    if (path.isEmpty) {
      _err = RigDaemonError.noBinary;
      return false;
    }
    if (await _portOpen(cfg.host, cfg.port)) {
      _err = RigDaemonError.inUse;
      return false;
    }
    try {
      final p = await Process.start(
        path,
        rigctldArgs(cfg),
        workingDirectory: File(path).parent.path,
      );
      _p = p;
      const dec = Utf8Decoder(allowMalformed: true);
      p.stdout.transform(dec).listen(_push);
      p.stderr.transform(dec).listen(_push);
      unawaited(p.exitCode.then((int code) {
        if (!identical(_p, p)) return;
        _p = null;
        if (_err == RigDaemonError.none) _err = RigDaemonError.exited;
      }).catchError((Object _) {}));
    } catch (_) {
      _p = null;
      _err = RigDaemonError.startFailed;
      return false;
    }
    // 起好之后端口还得能连上：rigctld 打开串口要几百毫秒，有的型号更久。
    for (var i = 0; i < 40; i++) {
      if (await _portOpen(cfg.host, cfg.port)) return true;
      if (_p == null) {
        if (_err == RigDaemonError.none) _err = RigDaemonError.exited;
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    _err = RigDaemonError.timeout;
    await stop();
    return false;
  }

  @override
  Future<void> stop() async {
    final p = _p;
    _p = null;
    if (p == null) return;
    try {
      p.kill();
    } catch (_) {
      // 已经自己退了：kill 会抛，这里不必管。
    }
    try {
      await p.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {
      // 两秒还没退就别等了：进程句柄已经交给系统回收。
    }
  }

  /// 端口能不能连上（只开一下就走，不往电台发任何命令）。
  Future<bool> _portOpen(String host, int port) async {
    try {
      final s = await Socket.connect(host, port,
          timeout: const Duration(milliseconds: 300));
      s.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _push(String chunk) {
    for (final raw in chunk.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      _lines.add(line);
      while (_lines.length > _maxLines) {
        _lines.removeAt(0);
      }
    }
    _log = _lines.join('\n');
  }
}
