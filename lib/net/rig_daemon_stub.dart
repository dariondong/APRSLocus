import 'rig_daemon_base.dart';

RigDaemon createRigDaemon() => RigDaemonStub();

/// Web：起不了子进程，也没有 TCP。一律当能力不存在，不抛异常。
class RigDaemonStub implements RigDaemon {
  @override
  bool get supported => false;

  @override
  bool get running => false;

  @override
  String get exe => '';

  @override
  RigDaemonError get error => RigDaemonError.unsupported;

  @override
  String get log => '';

  @override
  Future<String> locate() async => '';

  @override
  Future<bool> start(RigDaemonConfig cfg) async => false;

  @override
  Future<void> stop() async {}
}
