import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'satellite.dart';
import 'state.dart';
import 'widgets.dart';

/// 卫星悬浮小窗（Android）。
///
/// 用途：打卫星时很多人会同时开 Look4Sat，APRSlocus 退到后台。
/// 这个小窗浮在**其他应用之上**，显示当前卫星、过境倒计时、方位/仰角、
/// 多普勒修正后的上/下行，并提供一个「发信标」按钮 —— 不用来回切应用。
///
/// 原生侧：`SatOverlayService` + `WindowManager` 悬浮窗（SYSTEM_ALERT_WINDOW）。
/// 本类只负责：权限、把 [AppState] 的实时读数推给原生、接收原生的发信标请求。
class SatOverlayController extends ChangeNotifier with WidgetsBindingObserver {
  SatOverlayController._();
  static final SatOverlayController instance = SatOverlayController._();

  static const MethodChannel _ch = MethodChannel('com.aprslocus/sat_overlay');

  bool _enabled = false;

  /// 小窗当前是否开着。
  bool get enabled => _enabled;

  AppState? _state;
  S? _s;
  bool _handlerReady = false;
  bool _pendingEnable = false;
  bool _observing = false;

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 打开 / 关闭小窗。没有悬浮窗权限时会先跳系统设置，授权回来后自动打开。
  Future<void> toggle(BuildContext context, AppState st) async {
    final s = S.of(context);
    if (!_android) {
      _toast(context, s.satMiniUnsupported);
      return;
    }
    if (_enabled) {
      await hide();
      if (context.mounted) _toast(context, s.satMiniOff);
      return;
    }
    _state = st;
    _s = s;
    final can = await _canDraw();
    if (!can) {
      _pendingEnable = true;
      _observe();
      try {
        await _ch.invokeMethod('openPermissionSettings');
      } catch (_) {
        // 个别 ROM 没有这个设置页，用户只能自己去系统设置里开。
      }
      if (context.mounted) _toast(context, s.satMiniPermission);
      return;
    }
    await _enable();
    if (context.mounted) {
      _toast(context, _enabled ? s.satMiniOn : s.satMiniPermission);
    }
  }

  /// 关闭小窗（不弹提示，供页面退出/重置时用）。
  Future<void> hide() async {
    _pendingEnable = false;
    if (!_enabled) return;
    _enabled = false;
    _state?.tick.removeListener(_push);
    try {
      await _ch.invokeMethod('hide');
    } catch (_) {
      // 原生侧已停止也无妨。
    }
    notifyListeners();
  }

  Future<bool> _canDraw() async {
    try {
      return await _ch.invokeMethod<bool>('canDraw') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _enable() async {
    final st = _state;
    final s = _s;
    if (st == null || s == null) return;
    _ensureHandler();
    bool ok;
    try {
      ok = await _ch.invokeMethod<bool>('show', _data(st, s)) ?? false;
    } catch (_) {
      ok = false;
    }
    if (!ok) return;
    _enabled = true;
    st.tick.addListener(_push);
    _push();
    notifyListeners();
  }

  void _observe() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_pendingEnable) return;
    _pendingEnable = false;
    _canDraw().then((ok) {
      if (ok) _enable();
    });
  }

  /// 原生小窗上的「发信标」按钮 → 这里真正发。
  void _ensureHandler() {
    if (_handlerReady) return;
    _handlerReady = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'closed') {
        if (_enabled) {
          _enabled = false;
          _state?.tick.removeListener(_push);
          notifyListeners();
        }
        return null;
      }
      if (call.method != 'beacon') return null;
      final st = _state;
      final s = _s;
      if (st == null || s == null) return null;
      if (!st.usingRf) return s.satLinkNeeded;
      if (!st.connected) return s.beaconNotConnected;
      if (!st.myPositionReportable) return s.beaconWaitingFix;
      st.sendBeacon();
      return s.satSent;
    });
  }

  /// 每秒把当前读数推给原生小窗。
  void _push() {
    final st = _state;
    final s = _s;
    if (!_enabled || st == null || s == null) return;
    _ch.invokeMethod('update', _data(st, s)).catchError((_) {});
  }

  Map<String, Object?> _data(AppState st, S s) {
    final now = DateTime.now().toUtc();
    final pass = st.satPickedPass;
    final inPass =
        pass != null && !now.isBefore(pass.aos) && now.isBefore(pass.los);
    final before = pass != null && now.isBefore(pass.aos);

    String status;
    if (pass == null) {
      status = st.satName.isEmpty ? s.satNeedSync : s.satNoPass;
    } else if (inPass) {
      status = '${s.satInPass} · ${_mmss(pass.los.difference(now))}';
    } else if (before) {
      status = '${s.satWaitAos} · ${_mmss(pass.aos.difference(now))}';
    } else {
      status = s.satPassOver;
    }

    SatLook? look;
    final tle = st.satSelected;
    final lat = st.myLat;
    final lng = st.myLng;
    if (tle != null && lat != null && lng != null) {
      look = lookAt(tle, lat, lng, now);
    }
    final dUp =
        look == null ? 0.0 : dopplerHz(st.satUpMhz, look.rangeRateKmS);
    final dDown =
        look == null ? 0.0 : dopplerHz(st.satDownMhz, look.rangeRateKmS);
    final up = st.satUpMhz - dUp / 1e6;
    final down = st.satDownMhz + dDown / 1e6;

    return {
      'name': st.satName.isEmpty ? 'APRS' : st.satName,
      'status': status,
      'az': look == null ? '--' : '${look.azimuthDeg.toStringAsFixed(0)}°',
      'el': look == null ? '--' : '${look.elevationDeg.toStringAsFixed(0)}°',
      'up': up.toStringAsFixed(3),
      'down': down.toStringAsFixed(3),
      'tone': st.satTone,
      'tx': s.featureBeacon,
      'link': st.usingRf,
      'active': inPass,
      'noLink': s.satLinkNeeded,
    };
  }

  void _toast(BuildContext context, String m) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
    );
  }

  String _mmss(Duration d) {
    final sec = d.inSeconds.clamp(0, 359999);
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}
