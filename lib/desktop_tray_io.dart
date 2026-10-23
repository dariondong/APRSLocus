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

bool get _onWindows => defaultTargetPlatform == TargetPlatform.windows;
bool get _onMacOS => defaultTargetPlatform == TargetPlatform.macOS;

class _Tray with TrayListener, WindowListener {
  /// window_manager 初始化成功过
  bool _windowOk = false;

  /// 托盘真的建起来了
  bool _trayOk = false;

  /// 两个 listener 各只挂一次（`addListener` 会重复登记，事件就成倍地来）
  bool _winListener = false;
  bool _trayListener = false;

  /// 建托盘 / 初始化窗口控制都失败时，隔一会儿再试：早先是「试一次就封死」，
  /// 那一次没成就再也没有托盘。
  DateTime _retryAt = DateTime.fromMillisecondsSinceEpoch(0);

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

    final now = DateTime.now();
    final due = !now.isBefore(_retryAt);

    if (!_windowOk && due) {
      try {
        await windowManager.ensureInitialized();
        if (!_winListener) {
          windowManager.addListener(this);
          _winListener = true;
        }
        _windowOk = true;
      } catch (_) {
        // 某些 Linux 桌面/容器里没有窗口管理集成：托盘照建，只是藏不起来。
        _windowOk = false;
      }
    }

    if (!_trayOk && due) await _createTray();

    if (!_trayOk || !_windowOk) {
      _retryAt = now.add(const Duration(seconds: 3));
    }

    await _rebuildMenu(show: show, hide: hide, quit: quit);
    await _applyPrevent();
  }

  /// 建图标与提示文字。失败（没有托盘宿主、图标读不出来）就记下
  /// `_trayOk = false`，[sync] 之后会隔 3 s 再试，不会一次不成永远没有托盘。
  Future<void> _createTray() async {
    try {
      if (!_trayListener) {
        trayManager.addListener(this);
        _trayListener = true;
      }
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

  /// 点托盘图标。三个平台的差别是真的，不是风格问题：
  ///
  /// * Windows：菜单**不会**自己弹 —— tray_manager 的 Windows 实现里
  ///   `setContextMenu` 只把条目塞进一个 HMENU，真正的 `TrackPopupMenu` 只在
  ///   `popUpContextMenu` 里。所以右键必须自己调，左键留给「叫回窗口」。
  /// * macOS：`setContextMenu` 也只是把菜单存下来，`popUpContextMenu` 才把它挂
  ///   到 statusItem 上点一下 —— 左键不弹菜单的话，那条菜单永远看不到。
  /// * Linux：appindicator 自己挂着菜单，点一下系统就弹，别再插手。
  @override
  void onTrayIconMouseDown() {
    if (_quitting || !_trayOk) return;
    if (_onWindows) {
      unawaited(_toggleWindow());
    } else if (_onMacOS) {
      unawaited(_popMenu());
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    if (_quitting || !_trayOk || !_onWindows) return;
    unawaited(_popMenu());
  }

  /// 把菜单弹到鼠标位置。
  ///
  /// `bringAppToFront` 在 Windows 上会把主窗口设成前景窗口 —— Win32 的规矩：
  /// 不这么做，`TrackPopupMenu` 的菜单点外面关不掉。它对隐藏的窗口只做激活，
  /// 不会把它显示出来。
  Future<void> _popMenu() async {
    try {
      // ignore: deprecated_member_use
      await trayManager.popUpContextMenu(bringAppToFront: true);
    } catch (_) {}
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
