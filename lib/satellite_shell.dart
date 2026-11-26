import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'map_page.dart';
import 'models.dart';
import 'sat_passes_page.dart';
import 'satellite.dart';
import 'satellite_compass.dart';
import 'sat_overlay.dart';
import 'satellite_mode_page.dart';
import 'satellites_page.dart';
import 'state.dart';
import 'theme.dart';
import 'tile_map.dart';
import 'tnc_page.dart';
import 'widgets.dart';

/// ─── APRS 卫星模式外壳（指向器为主）───
///
/// 布局按实际“打卫星”的顺序：
///   顶栏：卫星 / 模式切换
///   主区：**大罗盘**（箭头指向卫星），右下角一张**小地图**
///   底栏：过境进度、多普勒上/下行、亚音、发信标 / 设置
///
/// 小地图不是装饰：收到新信标时自动缩放到那台站（并标出呼号），
/// 点一下可以放大成全屏地图。
class SatelliteShell extends StatefulWidget {
  final AppState state;
  const SatelliteShell({super.key, required this.state});

  @override
  State<SatelliteShell> createState() => _SatelliteShellState();
}

class _SatelliteShellState extends State<SatelliteShell> {
  AppState get st => widget.state;

  int _lastStationsVer = -1;
  double? _miniLat, _miniLng;
  double _miniZoom = 5;
  String? _beaconCall;
  DateTime? _beaconAt;
  DateTime? _alertedAos;

  /// 自动多普勒：每 2 秒检查一次，频率变化超过 40 Hz 才写电台。
  Timer? _tuneTimer;
  int _lastTunedHz = 0;
  DateTime? _autoTunedFor;
  String _lastSatKey = '';

  @override
  void initState() {
    super.initState();
    st.addListener(_onState);
    _lastStationsVer = st.stationsVersion;
    _lastSatKey = _satKey();
    _miniLat = st.myLat;
    _miniLng = st.myLng;
    _tuneTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _autoDoppler(),
    );
  }

  @override
  void dispose() {
    _tuneTimer?.cancel();
    st.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (!mounted) return;
    final sk = _satKey();
    if (sk != _lastSatKey) {
      _lastSatKey = sk;
      setState(() {});
    }
    final ver = st.stationsVersion;
    if (ver == _lastStationsVer) return;
    _lastStationsVer = ver;
    final latest = _latestStation();
    if (latest == null) return;
    // 同一台站重复信标也刷新（它可能移动了）；只是避免每次心跳都重设。
    if (latest.call == _beaconCall &&
        !latest.lastHeard.isAfter(_beaconAt ?? DateTime(2000))) {
      return;
    }
    setState(() {
      _beaconCall = latest.call;
      _beaconAt = latest.lastHeard;
      _miniLat = latest.lat;
      _miniLng = latest.lng;
      _miniZoom = 7;
    });
  }

  /// 卫星相关状态变了才重建外壳（选星、收藏、频率、路径、自动多普勒）。
  String _satKey() =>
      '${st.satName}|${st.satPassIndex}|${st.satFavorites.length}'
      '|${st.satAutoDoppler}|${st.satUpMhz}|${st.satDownMhz}'
      '|${st.satTone}|${st.satPath}|${st.satTleText.length}';

  /// 最近 10 分钟听到的、不是自己的、有坐标的最新台站。
  Station? _latestStation() {
    Station? best;
    final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
    final me = st.myFullCall.toUpperCase();
    for (final s in st.stations) {
      if (s.call.toUpperCase() == me) continue;
      if (s.lat == 0 && s.lng == 0) continue;
      if (s.lastHeard.isBefore(cutoff)) continue;
      if (best == null || s.lastHeard.isAfter(best.lastHeard)) best = s;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tle = st.satSelected;
    final lat = st.myLat;
    final lng = st.myLng;
    final canPoint = tle != null && lat != null && lng != null;

    double? miniLat = _miniLat ?? st.myLat;
    double? miniLng = _miniLng ?? st.myLng;
    if ((miniLat == null || miniLng == null) && tle != null) {
      final sub = subPoint(tle, DateTime.now());
      miniLat = sub.lat;
      miniLng = sub.lng;
    }

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context, s),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: canPoint
                              ? SatelliteCompass(
                                  tle: tle,
                                  lat: lat,
                                  lng: lng,
                                  pass: st.satPickedPass,
                                )
                              : _compassHint(context, s),
                        ),
                      ),
                    ),
                  ),
                  if (miniLat != null && miniLng != null)
                    Positioned(
                      right: 14,
                      bottom: 12,
                      child: _miniMap(context, s, miniLat, miniLng, tle),
                    ),
                ],
              ),
            ),
            _operatingBar(context, s),
          ],
        ),
      ),
    );
  }

  // ─── 顶栏 ───

  Widget _topBar(BuildContext context, S s) {
    final fav = st.satName.isNotEmpty && st.isSatFavorite(st.satName);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 4),
      child: Row(
        children: [
          Icon(Icons.satellite_alt_rounded, size: 20, color: C.blue),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _openCatalog(context),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.satMode,
                      style: ts(14, w: FontWeight.w800, ls: -0.2)),
                  Text(
                    st.satName.isEmpty ? s.satNeedSync : st.satName,
                    style: ts(10, c: C.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: s.satFavorites,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: () {
              if (st.satName.isEmpty) {
                _openCatalog(context);
                return;
              }
              st.toggleSatFavorite(st.satName);
            },
            icon: Icon(
              fav ? Icons.star_rounded : Icons.star_border_rounded,
              size: 20,
              color: fav ? C.orange : C.grey,
            ),
          ),
          IconButton(
            tooltip: s.satPasses,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: () => _openPasses(context),
            icon: Icon(Icons.format_list_bulleted_rounded,
                size: 20, color: C.slate),
          ),
          GestureDetector(
            onTap: () => _showModes(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: C.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dashboard_customize_rounded,
                      size: 14, color: C.blue),
                  const SizedBox(width: 4),
                  Text(s.featureModes,
                      style: ts(11, c: C.blue, w: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compassHint(BuildContext context, S s) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.explore_off_rounded, size: 42, color: C.greyLight),
          const SizedBox(height: 8),
          Text(
            st.satName.isEmpty ? s.satNeedSync : s.satNoPosition,
            textAlign: TextAlign.center,
            style: ts(12, c: C.grey),
          ),
          TextButton(
            onPressed: () => _openSettings(context),
            child: Text(s.settings, style: ts(12, c: C.blue)),
          ),
        ],
      ),
    );
  }

  // ─── 小地图（收到新信标就缩放到那台站）───

  Widget _miniMap(BuildContext context, S s, double lat, double lng, Tle? tle) {
    return GestureDetector(
      onTap: () => _openFullMap(context),
      child: Container(
        width: 134,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border),
          boxShadow: elev2(),
          color: C.bgSoft,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: TileMapView(
                    centerLat: lat,
                    centerLng: lng,
                    zoom: _miniZoom,
                    pan: Offset.zero,
                    onPan: (_) {},
                    onViewChanged: (_, _) {},
                    onZoomRequest: (_, _) {},
                    onTap: (_) {},
                    mapType: MapType.gaode,
                    cacheEnabled: st.tileCacheOn,
                    offlineOnly: st.offlineOnly,
                    overlay: Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _MiniPainter(
                            centerLat: lat,
                            centerLng: lng,
                            zoom: _miniZoom,
                            tle: tle,
                            stations: st.stations,
                            highlight: _beaconCall,
                            myLat: st.myLat,
                            myLng: st.myLng,
                            now: DateTime.now(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_beaconCall != null)
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: C.orange.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _beaconCall!,
                      style: ts(8.5, c: Colors.white, w: FontWeight.w700),
                    ),
                  ),
                ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Icon(Icons.open_in_full_rounded,
                    size: 12, color: C.slate.withValues(alpha: 0.65)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 底栏操作台 ───

  Widget _operatingBar(BuildContext context, S s) {
    return ValueListenableBuilder<int>(
      valueListenable: st.tick,
      builder: (context, _, _) {
        final now = DateTime.now().toUtc();
        final pass = st.satPickedPass;
        final inPass = pass != null &&
            !now.isBefore(pass.aos) &&
            now.isBefore(pass.los);
        final before = pass != null && now.isBefore(pass.aos);
        final progress = inPass
            ? (now.difference(pass.aos).inMicroseconds /
                    pass.duration.inMicroseconds)
                .clamp(0.0, 1.0)
            : 0.0;
        if (inPass && _alertedAos != pass.aos) {
          _alertedAos = pass.aos;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(s.satAosNow),
                backgroundColor: C.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          });
        }
        final tle = st.satSelected;
        final lat = st.myLat;
        final lng = st.myLng;
        SatLook? look;
        if (tle != null && lat != null && lng != null) {
          look = lookAt(tle, lat, lng, now);
        }
        final dUp =
            look == null ? 0.0 : dopplerHz(st.satUpMhz, look.rangeRateKmS);
        final dDown =
            look == null ? 0.0 : dopplerHz(st.satDownMhz, look.rangeRateKmS);
        final up = st.satUpMhz - dUp / 1e6;
        final down = st.satDownMhz + dDown / 1e6;

        final color = inPass ? C.green : (before ? C.orange : C.grey);
        final title = pass == null
            ? (st.satName.isEmpty ? s.satNeedSync : s.satNoPass)
            : inPass
                ? '${s.satInPass} · ${_mmss(pass.los.difference(now))}'
                : before
                    ? '${s.satWaitAos} · ${_mmss(pass.aos.difference(now))}'
                    : s.satPassOver;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: C.surfaceFill,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: elev3(),
            border: Border(top: BorderSide(color: C.border, width: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    inPass ? Icons.sensors_rounded : Icons.timer_outlined,
                    size: 15,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(title,
                        style: ts(12.5, c: color, w: FontWeight.w700)),
                  ),
                  if (pass != null)
                    Text('${_hm(pass.aos)}–${_hm(pass.los)}',
                        style: ts(10, c: C.grey)),
                ],
              ),
              if (pass != null) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: inPass ? progress : 0,
                    minHeight: 4,
                    backgroundColor: C.bgSoft,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _freqCell(s.satUplink, up, dUp, C.blue),
                  _freqCell(
                    st.satAutoDoppler
                        ? '${s.satDownlink} · AUTO'
                        : s.satDownlink,
                    down,
                    dDown,
                    C.green,
                  ),
                  _readCell(
                    s.bearing,
                    look == null
                        ? '--'
                        : '${look.azimuthDeg.toStringAsFixed(0)}°',
                  ),
                  _readCell(
                    s.satElevation,
                    look == null
                        ? '--'
                        : '${look.elevationDeg.toStringAsFixed(0)}°',
                  ),
                ],
              ),
              if (st.satTone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(s.satTone, style: ts(10, c: C.grey)),
                    const SizedBox(width: 6),
                    Text(st.satTone,
                        style: ts(11.5, c: C.ink, w: FontWeight.w700)),
                    const Spacer(),
                    if (look != null)
                      Text('${look.rangeKm.toStringAsFixed(0)} km',
                          style: ts(10, c: C.grey)),
                  ],
                ),
              ],
              if (!st.usingRf) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: C.orange),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(s.satLinkNeeded,
                          style: ts(9.5, c: C.orange, h: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                    TextButton(
                      onPressed: () => showLinkSheet(context, st),
                      child: Text(s.dataSourceTitle,
                          style: ts(10.5, c: C.orange, w: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: SatOverlayController.instance,
                builder: (context, _) {
                  final miniOn = SatOverlayController.instance.enabled;
                  return Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _sendBeacon(context, s),
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: Text(s.featureBeacon,
                              style: ts(12.5, w: FontWeight.w700)),
                          style: FilledButton.styleFrom(
                            backgroundColor: C.green,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: s.satTune,
                        child: OutlinedButton(
                          onPressed: () => _tuneNow(context, s),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 11),
                          ),
                          child: Icon(Icons.tune_rounded,
                              size: 16,
                              color: st.rigConnected ? C.green : C.grey),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: s.satMini,
                        child: OutlinedButton(
                          onPressed: () => SatOverlayController.instance
                              .toggle(context, st),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 11),
                            backgroundColor: miniOn
                                ? C.blue.withValues(alpha: 0.10)
                                : null,
                            side: BorderSide(
                                color: miniOn ? C.blue : C.border),
                          ),
                          child: Icon(
                            Icons.picture_in_picture_alt_rounded,
                            size: 16,
                            color: miniOn ? C.blue : C.slate,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _openSettings(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                        ),
                        child: Icon(Icons.settings_rounded,
                            size: 16, color: C.slate),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _freqCell(String label, double mhz, double shift, Color color) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ts(9.5, c: C.grey)),
            Text(mhz.toStringAsFixed(3),
                style: ts(15.5, c: color, w: FontWeight.w800, ls: -0.3)),
            Text(_hz(shift), style: ts(8.5, c: C.grey)),
          ],
        ),
      );

  Widget _readCell(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ts(9.5, c: C.grey)),
            Text(value,
                style: ts(15.5, c: C.ink, w: FontWeight.w800, ls: -0.3)),
          ],
        ),
      );

  // ─── 动作 ───

  void _sendBeacon(BuildContext context, S s) {
    if (!st.usingRf) {
      _toast(context, s.satLinkNeeded);
      return;
    }
    if (!st.connected) {
      _toast(context, s.beaconNotConnected);
      return;
    }
    final ok = st.myPositionReportable;
    st.sendBeacon();
    _toast(
      context,
      ok
          ? s.positionBeaconDetail(st.myGrid, st.beaconAttachedDetail)
          : s.beaconWaitingFix,
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SatelliteModePage(state: st)),
    );
  }

  void _openCatalog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SatellitesPage(state: st)),
    );
  }

  void _openPasses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SatPassesPage(state: st)),
    );
  }

  /// 当前下行 + 多普勒修正（MHz）。没有定位时退回标称频率。
  double _tunedDownMhz() {
    final tle = st.satSelected;
    final lat = st.myLat;
    final lng = st.myLng;
    if (tle == null || lat == null || lng == null) return st.satDownMhz;
    final look = lookAt(tle, lat, lng, DateTime.now().toUtc());
    return st.satDownMhz +
        dopplerHz(st.satDownMhz, look.rangeRateKmS) / 1e6;
  }

  /// 自动多普勒：过境中持续把下行写进电台。
  /// 只在（自动开 + 电台已连 + 正在过境）时动手，且频率变化 < 40 Hz 不重复发。
  void _autoDoppler() {
    if (!st.satAutoDoppler || !st.rigConnected) return;
    final pass = st.satPickedPass;
    if (pass == null) return;
    final now = DateTime.now().toUtc();
    if (now.isBefore(pass.aos) || now.isAfter(pass.los)) return;
    if (_autoTunedFor != pass.aos) {
      _autoTunedFor = pass.aos;
      _lastTunedHz = 0;
    }
    final hz = (_tunedDownMhz() * 1e6).round();
    if ((hz - _lastTunedHz).abs() < 40) return;
    _lastTunedHz = hz;
    st.rigSetFreq(hz);
  }

  Future<void> _tuneNow(BuildContext context, S s) async {
    if (!st.rigConnected) {
      _toast(context, s.satRigOff);
      return;
    }
    final mhz = _tunedDownMhz();
    await st.rigSetFreq((mhz * 1e6).round());
    if (!context.mounted) return;
    _toast(context, '${mhz.toStringAsFixed(3)} MHz');
  }

  void _openFullMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _FullMapPage(state: st)),
    );
  }

  void _showModes(BuildContext context) {
    final s = S.of(context);
    final modes = <(AppMode, String, IconData)>[
      (AppMode.sheet, s.uiLayoutSheet, Icons.map_rounded),
      (AppMode.classic, s.uiLayoutClassic, Icons.dashboard_rounded),
      (AppMode.lite, s.featureLite, Icons.bolt_rounded),
      (AppMode.satellite, s.satMode, Icons.satellite_alt_rounded),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.surfaceFill,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: C.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            for (final (m, label, icon) in modes)
              ListTile(
                leading: Icon(icon,
                    color: st.appMode == m ? C.blue : C.slate),
                title: Text(label, style: ts(13, w: FontWeight.w600)),
                trailing: st.appMode == m
                    ? Icon(Icons.check_rounded, size: 18, color: C.blue)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  st.setAppMode(m);
                },
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String m) {
    ScaffoldMessenger.of(context).showSnackBar(
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

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  String _hz(double hz) {
    final k = hz / 1000.0;
    return '${k >= 0 ? '+' : ''}${k.toStringAsFixed(1)} kHz';
  }
}

/// 小地图上的卫星星下点/足迹、台站与新信标高亮。
class _MiniPainter extends CustomPainter {
  final double centerLat, centerLng, zoom;
  final Tle? tle;
  final List<Station> stations;
  final String? highlight;
  final double? myLat, myLng;
  final DateTime now;

  const _MiniPainter({
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    required this.tle,
    required this.stations,
    required this.highlight,
    required this.myLat,
    required this.myLng,
    required this.now,
  });

  Offset _to(Size size, double lat, double lng) {
    final proj = projectionFor(MapType.gaode);
    final c = proj.latLngToPx(centerLat, centerLng, zoom);
    final p = proj.latLngToPx(lat, lng, zoom);
    return Offset(size.width / 2 + p.dx - c.dx, size.height / 2 + p.dy - c.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 卫星星下点 + 足迹
    final t = tle;
    if (t != null) {
      final sub = subPoint(t, now.toUtc());
      final center = _to(size, sub.lat, sub.lng);
      const earthR = 6378.137;
      final radDeg = math.acos(earthR / (earthR + sub.altKm)) * 180 / math.pi;
      final edge = _to(
        size,
        (sub.lat + radDeg).clamp(-89.0, 89.0),
        sub.lng,
      );
      final rr = (edge - center).distance;
      if (rr.isFinite && rr > 1) {
        canvas.drawCircle(
          center,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = C.cyan.withValues(alpha: 0.75),
        );
        canvas.drawCircle(center, rr,
            Paint()..color = C.cyan.withValues(alpha: 0.06));
      }
      canvas.drawCircle(center, 2.5, Paint()..color = C.cyan);
    }

    // 台站
    for (final s in stations) {
      if (s.lat == 0 && s.lng == 0) continue;
      final p = _to(size, s.lat, s.lng);
      if (p.dx < -4 ||
          p.dy < -4 ||
          p.dx > size.width + 4 ||
          p.dy > size.height + 4) {
        continue;
      }
      final hi = s.call == highlight;
      canvas.drawCircle(
        p,
        hi ? 3.5 : 1.8,
        Paint()
          ..color = hi
              ? C.orange
              : C.blue.withValues(alpha: 0.65),
      );
      if (hi) {
        final tp = TextPainter(
          text: TextSpan(
            text: s.call,
            style: TextStyle(
              fontSize: 8,
              color: C.orange,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p + const Offset(5, -4));
      }
    }

    // 我的位置
    final mlat = myLat;
    final mlng = myLng;
    if (mlat != null && mlng != null) {
      final p = _to(size, mlat, mlng);
      canvas.drawCircle(p, 2.8, Paint()..color = C.green);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniPainter old) =>
      old.centerLat != centerLat ||
      old.centerLng != centerLng ||
      old.zoom != zoom ||
      old.highlight != highlight ||
      old.now != now ||
      old.stations != stations;
}

/// 小地图点开后的全屏地图（卫星层仍由 MapPage 画）。
class _FullMapPage extends StatelessWidget {
  final AppState state;
  const _FullMapPage({required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapPage(
              state: state,
              isActive: true,
              topInset: 60,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: Material(
              color: C.surfaceFill,
              borderRadius: BorderRadius.circular(999),
              child: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: C.slate),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
