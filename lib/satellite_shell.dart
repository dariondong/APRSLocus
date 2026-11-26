import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'map_page.dart';
import 'material.dart';
import 'satellite.dart';
import 'satellite_mode_page.dart';
import 'satellite_point_page.dart';
import 'state.dart';
import 'theme.dart';
import 'tnc_page.dart';
import 'widgets.dart';

/// ─── APRS 卫星模式外壳 ───
///
/// 与 1.0 经典 / 2.0 地图 / 精简并列，不是设置里的一个开关：
///   * 地图铺底（卫星星下点、足迹与轨迹由 MapPage 的卫星层画）；
///   * 顶部一颗状态胶囊：卫星名 + 下次过境，右侧直接切换模式；
///   * 底部可拖动面板：卫星选择/同步、极坐标天空图、过境列表、实时多普勒、
///     频率/路径、指向卫星。
class SatelliteShell extends StatelessWidget {
  final AppState state;
  const SatelliteShell({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: C.pageFill,
      body: Stack(
        children: [
          Positioned.fill(
            child: MapPage(
              state: state,
              isActive: true,
              // 让开顶部状态胶囊；底部由面板盖住。
              topInset: 64,
              bottomInset: 0,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: _topBar(context, s),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.46,
            minChildSize: 0.12,
            maxChildSize: 0.94,
            builder: (ctx, controller) => Container(
              decoration: BoxDecoration(
                color: C.pageFill,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: elev3(),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 2),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: C.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Cockpit(
                      state: state,
                      controller: controller,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context, S s) {
    final pass = state.satPickedPass;
    final name = state.satName;
    final label = name.isEmpty
        ? s.satMode
        : '$name${pass == null ? '' : ' · ${_hm(pass.aos)}'}';
    return MaterialSurface(
      radius: 999,
      blurSigma: C.chipBlur,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: C.chipFill,
          borderRadius: BorderRadius.circular(999),
          boxShadow: elev2(),
        ),
        child: Row(
          children: [
            Icon(Icons.satellite_alt_rounded, size: 17, color: C.blue),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: ts(12.5, w: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () => _showModes(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
      ),
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
      backgroundColor: C.sheetFill,
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
                    color: state.appMode == m ? C.blue : C.slate),
                title: Text(label, style: ts(13, w: FontWeight.w600)),
                trailing: state.appMode == m
                    ? Icon(Icons.check_rounded, size: 18, color: C.blue)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  state.setAppMode(m);
                },
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }
}

/// 卫星操作台：按真实流程排 —— 过境进度 → 对准读数 → 多普勒上/下行 →
/// 链路检查 → 发信标/指向/调谐/设置。配置项收进二级页，不在这里堆。
class _Cockpit extends StatefulWidget {
  final AppState state;
  final ScrollController controller;
  const _Cockpit({required this.state, required this.controller});

  @override
  State<_Cockpit> createState() => _CockpitState();
}

class _CockpitState extends State<_Cockpit> {
  DateTime? _alertedAos;

  AppState get st => widget.state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => ValueListenableBuilder<int>(
        valueListenable: st.tick,
        builder: (context, _, _) {
          final tle = st.satSelected;
          final lat = st.myLat;
          final lng = st.myLng;
          final pass = st.satPickedPass;
          final now = DateTime.now().toUtc();
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
          SatLook? look;
          if (tle != null && lat != null && lng != null) {
            look = lookAt(tle, lat, lng, now);
          }
          final dUp = look == null
              ? 0.0
              : dopplerHz(st.satUpMhz, look.rangeRateKmS);
          final dDown = look == null
              ? 0.0
              : dopplerHz(st.satDownMhz, look.rangeRateKmS);
          final up = st.satUpMhz - dUp / 1e6;
          final down = st.satDownMhz + dDown / 1e6;

          return ListView(
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _passHeader(s, pass, inPass, before, progress, now),
              const SizedBox(height: 10),
              _bigNumbers(s, look, up, down, dUp, dDown),
              if (!st.usingRf) ...[
                const SizedBox(height: 10),
                _linkWarning(context, s),
              ],
              const SizedBox(height: 12),
              _actions(context, s, down),
            ],
          );
        },
      ),
    );
  }

  Widget _passHeader(S s, SatPass? pass, bool inPass, bool before,
      double progress, DateTime now) {
    final color = inPass ? C.green : (before ? C.orange : C.grey);
    final title = pass == null
        ? (st.satName.isEmpty ? s.satNeedSync : s.satNoPass)
        : inPass
            ? '${s.satInPass} · ${_mmss(pass.los.difference(now))}'
            : before
                ? '${s.satWaitAos} · ${_mmss(pass.aos.difference(now))}'
                : s.satPassOver;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: C.sheetFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(inPass ? Icons.sensors_rounded : Icons.timer_outlined,
                  size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    style: ts(13, c: color, w: FontWeight.w700)),
              ),
              if (pass != null)
                Text(
                    '${st.satName} · '
                    '${pass.maxElevation.toStringAsFixed(0)}°',
                    style: ts(11, c: C.slate, w: FontWeight.w600)),
            ],
          ),
          if (pass != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: inPass ? progress : 0,
                minHeight: 6,
                backgroundColor: C.bgSoft,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('AOS ${_hm(pass.aos)}', style: ts(10, c: C.grey)),
                const Spacer(),
                Text('LOS ${_hm(pass.los)}', style: ts(10, c: C.grey)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bigNumbers(S s, SatLook? look, double up, double down,
      double dUp, double dDown) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: C.sheetFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _bigCell(
                  s.satElevation,
                  look == null
                      ? '--'
                      : '${look.elevationDeg.toStringAsFixed(0)}°'),
              _bigCell(
                  s.bearing,
                  look == null
                      ? '--'
                      : '${look.azimuthDeg.toStringAsFixed(0)}°'),
            ],
          ),
          const Divider(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _freqCell(s.satUplink, up, dUp, C.blue),
              _freqCell(s.satDownlink, down, dDown, C.green),
            ],
          ),
          if (st.satTone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(s.satTone, style: ts(10.5, c: C.grey)),
                const Spacer(),
                Text(st.satTone,
                    style: ts(13, c: C.ink, w: FontWeight.w700)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bigCell(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(label, style: ts(10, c: C.grey)),
            const SizedBox(height: 2),
            Text(value,
                style: ts(26, c: C.ink, w: FontWeight.w800, ls: -0.5)),
          ],
        ),
      );

  Widget _freqCell(String label, double mhz, double shift, Color color) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ts(10, c: C.grey)),
            const SizedBox(height: 2),
            Text(mhz.toStringAsFixed(3),
                style: ts(18, c: color, w: FontWeight.w800, ls: -0.3)),
            Text('MHz ${_hz(shift)}', style: ts(9.5, c: C.grey)),
          ],
        ),
      );

  Widget _linkWarning(BuildContext context, S s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: C.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.orange.withValues(alpha: 0.40)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: C.orange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(s.satLinkNeeded,
                style: ts(10.5, c: C.orange, h: 1.35)),
          ),
          TextButton(
            onPressed: () => showLinkSheet(context, st),
            child: Text(s.dataSourceTitle,
                style: ts(11, c: C.orange, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, S s, double down) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () => _sendBeacon(context, s),
          icon: const Icon(Icons.send_rounded, size: 16),
          label: Text(s.featureBeacon, style: ts(12.5, w: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: C.green,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SatellitePointPage(state: st),
            ),
          ),
          icon: const Icon(Icons.explore_rounded, size: 15),
          label: Text(s.satPoint, style: ts(12)),
        ),
        if (st.rigConnected)
          OutlinedButton.icon(
            onPressed: () => _tune(context, down),
            icon: const Icon(Icons.tune_rounded, size: 15),
            label: Text(s.satTune, style: ts(12)),
          ),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SatelliteModePage(state: st),
            ),
          ),
          icon: const Icon(Icons.settings_rounded, size: 15),
          label: Text(s.settings, style: ts(12)),
        ),
      ],
    );
  }

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

  Future<void> _tune(BuildContext context, double down) async {
    await st.rigSetFreq((down * 1e6).round());
    if (!context.mounted) return;
    _toast(context, '${down.toStringAsFixed(3)} MHz');
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
