import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';
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
                  painter: _CompassPainter(
                    heading: _hasCompass ? _heading : 0,
                    targetAz: look.azimuthDeg,
                    targetEl: look.elevationDeg,
                    hasCompass: _hasCompass,
                    above: above,
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

/// 罗盘：N/E/S/W 随手机航向转；橙色箭头指向卫星方位。
class _CompassPainter extends CustomPainter {
  final double heading;
  final double targetAz;
  final double targetEl;
  final bool hasCompass;
  final bool above;

  const _CompassPainter({
    required this.heading,
    required this.targetAz,
    required this.targetEl,
    required this.hasCompass,
    required this.above,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 8;
    final center = Offset(cx, cy);

    // 底色 + 外圈
    canvas.drawCircle(center, r, Paint()..color = C.bgSoft);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = C.border,
    );

    // 刻度（每 30°）
    for (var a = 0; a < 360; a += 30) {
      final rad = (a - heading) * math.pi / 180;
      final outer = Offset(cx + r * math.sin(rad), cy - r * math.cos(rad));
      final len = a % 90 == 0 ? 12.0 : 6.0;
      final inner = Offset(
        cx + (r - len) * math.sin(rad),
        cy - (r - len) * math.cos(rad),
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..strokeWidth = a % 90 == 0 ? 1.5 : 0.8
          ..color = C.greyLight,
      );
    }

    // N/E/S/W
    for (final (label, az) in const [
      ('N', 0.0),
      ('E', 90.0),
      ('S', 180.0),
      ('W', 270.0),
    ]) {
      final rad = (az - heading) * math.pi / 180;
      final p = Offset(
        cx + (r - 24) * math.sin(rad),
        cy - (r - 24) * math.cos(rad),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: label == 'N' ? C.red : C.slate,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    // 手机顶部方向（固定朝上）
    final phone = Path()
      ..moveTo(cx, cy - r + 2)
      ..lineTo(cx - 7, cy - r + 14)
      ..lineTo(cx + 7, cy - r + 14)
      ..close();
    canvas.drawPath(phone, Paint()..color = C.blue);

    if (!above) {
      // 地平线下：只画一个灰色的目标点提示它在哪边
      return;
    }

    // 目标箭头：相对手机顶部的角度
    final rel = (hasCompass ? targetAz - heading : targetAz) * math.pi / 180;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rel);
    // 指向线
    canvas.drawLine(
      Offset(0, -r * 0.18),
      Offset(0, -r * 0.62),
      Paint()
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = C.orange,
    );
    // 箭头
    final arrow = Path()
      ..moveTo(0, -r * 0.80)
      ..lineTo(-12, -r * 0.55)
      ..lineTo(12, -r * 0.55)
      ..close();
    canvas.drawPath(arrow, Paint()..color = C.orange);
    // 仰角：箭头根部的小圆环（越高越靠近圆心）
    final elR = r * (1 - targetEl.clamp(0.0, 90.0) / 90) * 0.9;
    canvas.drawCircle(
      Offset(0, -elR),
      4,
      Paint()
        ..style = PaintingStyle.fill
        ..color = C.orange,
    );
    canvas.restore();

    // 中心点
    canvas.drawCircle(center, 3, Paint()..color = C.grey);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) =>
      old.heading != heading ||
      old.targetAz != targetAz ||
      old.targetEl != targetEl ||
      old.hasCompass != hasCompass ||
      old.above != above;
}
