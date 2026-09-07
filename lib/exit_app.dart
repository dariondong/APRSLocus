import 'exit_app_io.dart' if (dart.library.html) 'exit_app_web.dart' as impl;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel, SystemNavigator;

const _exitChannel = MethodChannel('com.aprslocus/exit');

/// 是否在设置页显示“退出应用”入口。
/// Android / Windows / Linux / macOS 支持；iOS（商店规范）与 Web 不显示。
bool get canShowExitButton {
  if (kIsWeb) return false;
  final t = defaultTargetPlatform;
  return t == TargetPlatform.android ||
      t == TargetPlatform.windows ||
      t == TargetPlatform.linux ||
      t == TargetPlatform.macOS;
}

/// 按平台真正退出应用（调用前应已保存设置、停止定位服务、断开 APRS）。
/// - Android：原生通道结束前台服务 → finishAndRemoveTask → 结束进程；
/// - Windows / Linux / macOS：直接 exit(0)；
/// - iOS：退回桌面（不杀进程）；Web：无操作。
Future<void> exitApplication() async {
  if (kIsWeb) return;
  final t = defaultTargetPlatform;
  if (t == TargetPlatform.android) {
    try {
      await _exitChannel.invokeMethod<void>('exitApp');
      return;
    } catch (_) {
      // 原生通道不可用时退回 Flutter 级“返回桌面”
    }
    await SystemNavigator.pop();
    return;
  }
  if (t == TargetPlatform.iOS) {
    await SystemNavigator.pop();
    return;
  }
  await impl.exitProcess();
}
