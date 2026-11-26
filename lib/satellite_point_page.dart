import 'dart:async';

import 'package:flutter/material.dart';

import 'motion.dart';
import 'satellite_compass.dart';
import 'satellite.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 指向卫星（罗盘/陀螺仪）───
///
/// 不是相机 AR：用手机航向把「卫星在哪个方向」转成**相对手机顶部**的角度，
/// 箭头指向哪边就往哪边转；仰角单独写成「抬头多少度」。
/// 航向来自 [MotionService]（Android 旋转矢量 / 加速度计+磁力计），
/// 没有指南针时退化成「正北朝上」的静态罗盘，并如实说明。
class SatellitePointPage extends StatefulWidget {
  final AppState state;
  const SatellitePointPage({super.key, required this.state});

  @override
  State<SatellitePointPage> createState() => _SatellitePointPageState();
}

class _SatellitePointPageState extends State<SatellitePointPage> {
  Timer? _timer;
  double _heading = -1;
  bool _hasCompass = false;

  /// 过境轨迹缓存：页面 10Hz 重绘，不能每次重算整条弧。
  SatPass? _trailPass;
  double? _trailLat;
  double? _trailLng;
  List<SkyPoint> _trail = const [];

  AppState get st => widget.state;

  @override
  void initState() {
    super.initState();
    _startSensors();
  }

  Future<void> _startSensors() async {
    await MotionService.instance.start(motion: true);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final sample = await MotionService.instance.refresh();
      if (!mounted) return;
      setState(() {
        _heading = sample.heading;
        _hasCompass = sample.hasCompass && sample.heading >= 0;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tle = st.satSelected;
    final lat = st.myLat;
    final lng = st.myLng;
    if (tle == null || lat == null || lng == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.satPoint)),
        body: Center(child: Text(s.satNoPosition, style: ts(13, c: C.grey))),
      );
    }
    final now = DateTime.now();
    final look = lookAt(tle, lat, lng, now);
    final above = look.elevationDeg >= 0;
    final heading = _hasCompass ? _heading : 0.0;
    final rel = _relative(look.azimuthDeg, heading);
    final pass = st.satPickedPass;
    final altKm = subPoint(tle, now).altKm;

    // 过境轨迹按 (过境, 观测点) 缓存，位置/选星变化时才重算。
    if (pass != null &&
        (_trailPass?.aos != pass.aos ||
            _trailPass?.los != pass.los ||
            _trailLat != lat ||
            _trailLng != lng)) {
      _trailPass = pass;
      _trailLat = lat;
      _trailLng = lng;
      _trail = passTrack(tle, lat, lng, pass);
    } else if (pass == null && _trail.isNotEmpty) {
      _trailPass = null;
      _trail = const [];
    }

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        title: Text('${s.satPoint} · ${st.satName}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(
                  painter: SatelliteCompassPainter(
                    heading: _hasCompass ? _heading : 0,
                    targetAz: look.azimuthDeg,
                    targetEl: look.elevationDeg,
                    hasCompass: _hasCompass,
                    above: above,
                    trail: _trail,
                    now: now,
                    rangeKm: look.rangeKm,
                    altKm: altKm,
                    azLabel: s.bearing,
                    elLabel: s.satElevation,
                    rangeLabel: s.satRange,
                    altLabel: s.altitude,
                    headingLabel: s.satHeading,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: C.sheetFill,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: C.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _readout(s.satPointTarget,
                          '${look.azimuthDeg.toStringAsFixed(0)}°'),
                      _readout(s.satElevation,
                          '${look.elevationDeg.toStringAsFixed(0)}°'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!above)
                    Text(
                      pass == null
                          ? s.satPointBelow
                          : '${s.satPointBelow} '
                              '${s.satPass(_hm(pass.aos), pass.maxElevation.toStringAsFixed(0))}',
                      textAlign: TextAlign.center,
                      style: ts(12, c: C.orange, h: 1.4),
                    )
                  else if (!_hasCompass)
                    Text(s.satPointNoCompass,
                        textAlign: TextAlign.center,
                        style: ts(12, c: C.orange, h: 1.4))
                  else
                    Text(
                      _turnHint(s, rel, look.elevationDeg),
                      textAlign: TextAlign.center,
                      style: ts(13, c: C.ink, w: FontWeight.w700, h: 1.4),
                    ),
                  const SizedBox(height: 6),
                  Text(s.satPointHint,
                      textAlign: TextAlign.center,
                      style: ts(10.5, c: C.grey, h: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readout(String label, String value) => Column(
        children: [
          Text(label, style: ts(10.5, c: C.grey)),
          const SizedBox(height: 2),
          Text(value,
              style: ts(22, c: C.ink, w: FontWeight.w800, ls: -0.4)),
        ],
      );

  String _turnHint(S s, double rel, double el) {
    final deg = rel.abs().toStringAsFixed(0);
    final dir = rel.abs() <= 5
        ? s.satPointAligned
        : '${rel > 0 ? s.satPointTurnRight : s.satPointTurnLeft} $deg°';
    return '$dir · ${s.satPointElev} ${el.toStringAsFixed(0)}°';
  }

  /// 卫星方位相对手机顶部：-180..180（正 = 向右）。
  double _relative(double az, double heading) {
    var d = az - heading;
    while (d > 180) {
      d -= 360;
    }
    while (d < -180) {
      d += 360;
    }
    return d;
  }

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }
}
