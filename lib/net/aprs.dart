// APRS 连接器工厂（条件导入）
//   - 桌面 / 移动 / 桌面(io)：dart:io Socket 直连 APRS-IS TCP
//   - Web：WebSocket
import 'aprs_base.dart';
export 'aprs_base.dart';
import 'aprs_stub.dart'
    if (dart.library.io) 'aprs_io.dart'
    if (dart.library.html) 'aprs_web.dart' as impl;

AprsConnector createAprs() => impl.createAprs();
