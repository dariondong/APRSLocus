import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/widgets.dart';

import 'desktop_tray_io.dart'
    if (dart.library.html) 'desktop_tray_web.dart' as impl;
import 'exit_app.dart' show exitApplication;
import 'state.dart';
import 'widgets.dart' show S;

/// ─── 系统托盘（Windows / macOS / Linux）───
///
/// 桌面上关窗口等于退出，而开着 APRS 的人多半是想让它一直挂在后台收报文。
/// 所以桌面版做了两件事：常驻一枚托盘图标，以及「关窗口 = 收进托盘」。
/// 真要退出走托盘菜单里的「退出」，或者把设置里那一档关掉。
///
/// 为什么分成三个文件：`tray_manager` 与 `window_manager` 都直接
/// `import 'dart:io'`，一旦被编译进 Web 构建就过不去（Web 是这个项目的一等
/// 平台）。所以真实现落在 desktop_tray_io.dart，Web 换成空实现 ——
/// 与 lib/exit_app.dart 用条件导入分平台是同一个做法。
///
/// 这里只做「薄壳」：判断有没有托盘、把三条菜单文字和那一档设置递给实现、
/// 并当作 App 里的一层挂上去。所有原生调用都在 desktop_tray_io.dart。

/// 桌面三平台才有系统托盘。
bool get desktopTraySupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// 托盘菜单那三条文字。语言一切换就得跟着换，所以每次同步都重新给。
class DesktopTrayLabels {
  const DesktopTrayLabels({
    required this.show,
    required this.hide,
    required this.quit,
  });

  final String show;
  final String hide;
  final String quit;
}

/// 系统托盘与「关窗口不退出」的唯一入口。
class DesktopTray {
  const DesktopTray._();

  /// 建托盘、同步菜单文字与「关窗口时最小化到托盘」这一档。
  ///
  /// 可反复调用（设置变了、语言变了都会再调一次）：实现里会比较上次的状态，
  /// 没变就不碰原生那侧。
  ///
  /// [onQuit] 是托盘里「退出」要走的路径，与设置页那个退出按钮同一条
  /// （先 shutdownForExit 收尾，再 exitApplication）。
  static Future<void> sync({
    required DesktopTrayLabels labels,
    required bool closeToTray,
    required Future<void> Function() onQuit,
  }) =>
      impl.traySync(
        show: labels.show,
        hide: labels.hide,
        quit: labels.quit,
        closeToTray: closeToTray,
        onQuit: onQuit,
      );
}

/// 把托盘挂进 App 的一层壳（放在 MaterialApp 的 builder 里）。
///
/// 为什么挂在 builder 而不是 App 的 initState：builder 位于 Localizations
/// **之下**，`S.of(context)` 拿到的就是当前真正生效的语言（包括「跟随系统」
/// 那档）。在 App 层取语言得自己重算 locale，算错就会出现「界面是英文、
/// 托盘菜单还是中文」。
class DesktopTrayHost extends StatefulWidget {
  const DesktopTrayHost({super.key, required this.state, required this.child});

  final AppState state;
  final Widget child;

  @override
  State<DesktopTrayHost> createState() => _DesktopTrayHostState();
}

class _DesktopTrayHostState extends State<DesktopTrayHost> {
  bool get _wanted => desktopTraySupported;

  @override
  void initState() {
    super.initState();
    if (_wanted) widget.state.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wanted) _sync();
  }

  @override
  void dispose() {
    if (_wanted) widget.state.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final s = S.of(context);
    unawaited(DesktopTray.sync(
      labels: DesktopTrayLabels(
        show: s.trayMenuShow,
        hide: s.trayMenuHide,
        quit: s.trayMenuQuit,
      ),
      closeToTray: widget.state.closeToTray,
      onQuit: () async {
        await widget.state.shutdownForExit();
        await exitApplication();
      },
    ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
