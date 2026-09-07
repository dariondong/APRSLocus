import 'dart:io' show exit;

/// 桌面平台（Windows / Linux / macOS）直接结束进程。
Future<void> exitProcess() async {
  exit(0);
}
