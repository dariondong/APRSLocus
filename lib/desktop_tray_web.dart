/// Web 上没有系统托盘：这一层的所有入口都是空操作。
///
/// 存在只为让 desktop_tray.dart 的条件导入两边同名 —— Web 构建不会去编译
/// desktop_tray_io.dart（它 import 的 tray_manager / window_manager 都直接
/// import 'dart:io'，编进去 Web 就过不去）。
Future<void> traySync({
  required String show,
  required String hide,
  required String quit,
  required bool closeToTray,
  required Future<void> Function() onQuit,
}) async {}
