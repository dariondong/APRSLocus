// 电台控制（Hamlib / rigctld）的工厂（条件导入）
//   - 桌面 / 移动端：dart:io 的 Socket，说 rigctld 的文本协议
//   - Web：占位（没有 TCP）
import 'rig_link_base.dart';
export 'rig_link_base.dart';
import 'rig_link_stub.dart'
    if (dart.library.io) 'rig_link_io.dart' as impl;

RigLink createRigLink() => impl.createRigLink();
