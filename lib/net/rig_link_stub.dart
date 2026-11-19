import 'rig_link_base.dart';

/// 没有 TCP 的平台（Web）用这个：能力不存在，调用一律返回 false。
RigLink createRigLink() => RigStub();
