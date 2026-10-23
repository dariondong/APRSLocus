import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'exit_app.dart' show exitApplication;

/// ─── 系统托盘的桌面实现（Windows / macOS / Linux）───
///
/// 只在 desktop_tray.dart 的条件导入里被非 Web 分支引用，所以
/// `tray_manager` / `window_manager`（两个都直接 import 'dart:io'）不会进
/// Web 构建。
///
/// 有一条硬规矩：**托盘没建起来就不许拦关闭**。Linux 上（比如没装
/// appindicator 扩展的 GNOME）托盘可能整个不显示，这时如果把窗口一关就藏起来，
/// 用户既看不到窗口也点不到托盘，只能去任务管理器杀进程 —— 比不做这个功能更糟。
/// 所以「能不能拦」是 `_trayOk && _windowOk` 一起决定的，见 [_applyPrevent]。

/// Windows 托盘图标必须是 .ico（原生侧用 `LoadImage(IMAGE_ICON)` 读，
/// 它不认 png）；macOS / Linux 读 png。
const String _iconWindows = 'assets/tray_icon.ico';
const String _iconOther = 'assets/tray_icon.png';

final _Tray _instance = _Tray();

class _Tray with TrayListener, WindowListener {
  /// window_manager 初始化试过了（无论成败，只试一次）
  bool _inited = false;

  /// 窗口控制真的可用
  bool _windowOk = false;

  /// 托盘真的建起来了
  bool _trayOk = false;

  /// 当前是否真的在拦关闭（与「用户想不想」是两件事）
  bool _prevent = false;

  /// 用户那一档：关窗口时最小化到托盘
  bool _closeToTray = true;

  /// 正在退出：这期间不再拦关闭，也不再藏窗口
  bool _quitting = false;

  /// 上次建菜单用的三条文字，文字没变就不重建
  String _menuSig = '';

  Future<void> Function()? _onQuit;

  Future<void> sync({
    required String show,
    required String hide,
    required String quit,
    required bool closeToTray,
    required Future<void> Function() onQuit,
  }) async {
    _onQuit = onQuit;
    _closeToTray = closeToTray;

    if (!_inited) {
      _inited = true;
      try {
        await windowManager.ensureInitialized();
        windowManager.addListener(this);
        _windowOk = true;
      } catch (_) {
        // 某些 Linux 桌面/容器里没有窗口管理集成：托盘照建，只是藏不起来。
        _windowOk = false;
      }
    }

    if (!_trayOk) await _createTray();
    await _rebuildMenu(show: show, hide: hide, quit: quit);
    await _applyPrevent();
  }

  /// 建图标与提示文字。失败（没有托盘宿主）就记下 `_trayOk = false`，
  /// 之后不再重试 —— 每帧重试也没有意义，反而会刷一屏异常。
  Future<void> _createTray() async {
    try {
      trayManager.addListener(this);
      await trayManager.setIcon(
        defaultTargetPlatform == TargetPlatform.windows
            ? _iconWindows
            : _iconOther,
        // macOS 的模板图：系统按 alpha 当遮罩染色，深浅色菜单栏都自动反色，
        // 所以这张图是什么颜色都无所谓。
        isTemplate: defaultTargetPlatform == TargetPlatform.macOS,
      );
      await trayManager.setToolTip('APRSlocus');
      _trayOk = true;
    } catch (_) {
      _trayOk = false;
    }
  }

  Future<void> _rebuildMenu({
    required String show,
    required String hide,
    required String quit,
  }) async {
    if (!_trayOk) return;
    final sig = '$show|$hide|$quit';
    if (sig == _menuSig) return;
    try {
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: show),
        MenuItem(key: 'hide', label: hide),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: quit),
      ]));
      _menuSig = sig;
    } catch (_) {
      // 菜单没建成不影响图标本身，下次同步会再试
    }
  }

  /// 「关窗口时最小化到托盘」是否生效 = 用户开着 **并且** 托盘与窗口控制都在。
  Future<void> _applyPrevent() async {
    final want = _closeToTray && _trayOk && _windowOk && !_quitting;
    if (want == _prevent) return;
    try {
      await windowManager.setPreventClose(want);
      _prevent = want;
    } catch (_) {
      _prevent = false;
    }
  }

  Future<void> _showWindow() async {
    if (!_windowOk) return;
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  Future<void> _hideWindow() async {
    if (!_windowOk) return;
    try {
      await windowManager.hide();
    } catch (_) {}
  }

  /// 点托盘图标：窗口露着就收起来，藏着（或最小化）就叫回来。
  Future<void> _toggleWindow() async {
    if (!_windowOk || _quitting) return;
    try {
      final visible = await windowManager.isVisible();
      final minimized = visible ? await windowManager.isMinimized() : false;
      if (visible && !minimized) {
        await _hideWindow();
      } else {
        await _showWindow();
      }
    } catch (_) {}
  }

  /// 托盘菜单里点了「退出」：与设置页那个退出按钮同一条路。
  Future<void> _quit() async {
    if (_quitting) return;
    _quitting = true;
    // 先松开关闭拦截：退出过程中任何一次「关窗口」都不该再被我们接住。
    try {
      await windowManager.setPreventClose(false);
    } catch (_) {}
    _prevent = false;
    try {
      await trayManager.destroy();
    } catch (_) {}
    final cb = _onQuit;
    if (cb != null) {
      try {
        await cb();
        return;
      } catch (_) {
        // 收尾那步出错也要能退出，落到下面的兜底
      }
    }
    await exitApplication();
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_toggleWindow());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        unawaited(_showWindow());
        break;
      case 'hide':
        unawaited(_hideWindow());
        break;
      case 'quit':
        unawaited(_quit());
        break;
    }
  }

  @override
  void onWindowClose() {
    if (_quitting || !_prevent) return;
    unawaited(_hideWindow());
  }
}

/// 建托盘 + 同步状态（幂等，可反复调用）。
Future<void> traySync({
  required String show,
  required String hide,
  required String quit,
  required bool closeToTray,
  required Future<void> Function() onQuit,
}) =>
    _instance.sync(
      show: show,
      hide: hide,
      quit: quit,
      closeToTray: closeToTray,
      onQuit: onQuit,
    );
