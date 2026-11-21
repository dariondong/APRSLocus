// 本机 rigctld 的工厂（条件导入）
//   - 桌面：真起一个子进程（dart:io 的 Process）
//   - Web：占位（起不了子进程，也没有 TCP）
import 'rig_daemon_base.dart';
export 'rig_daemon_base.dart';
import 'rig_daemon_stub.dart'
    if (dart.library.io) 'rig_daemon_io.dart' as impl;

RigDaemon createRigDaemon() => impl.createRigDaemon();
