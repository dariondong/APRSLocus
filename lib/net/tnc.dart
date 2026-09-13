// TNC 传输层工厂（条件导入）
//   - Android / iOS：原生蓝牙 SPP（MethodChannel + EventChannel）
//   - Windows / Linux / macOS：串口（dart:io 直接读写设备节点）
//   - Web：占位（不支持）
import 'tnc_base.dart';
export 'tnc_base.dart';
import 'tnc_stub.dart'
    if (dart.library.io) 'tnc_io.dart'
    if (dart.library.html) 'tnc_web.dart' as impl;

TncTransport createTncTransport() => impl.createTncTransport();
