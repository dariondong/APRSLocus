import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'satellite.dart';
import 'theme.dart';

/// 大罗盘：N/E/S/W 随手机航向转，橙色箭头指向卫星。
///
/// 用 [MotionService] 的航向（旋转矢量/磁力计），100ms 刷新一次。
/// 没有指南针时退化成「正北朝上」的静态罗盘。
class SatelliteCompass extends StatefulWidget {
  final Tle tle;
  final double lat, lng;
  const SatelliteCompass({
    super.key,
    required this.tle,
    required this.lat,
    required this.lng,
  });

  @override
  State<SatelliteCompass> createState() => _SatelliteCompassState();
}

class _SatelliteCompassState extends State<SatelliteCompass> {
  double _heading = -1;
  bool _hasCompass = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
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
    final look = lookAt(widget.tle, widget.lat, widget.lng, DateTime.now());
    return CustomPaint(
      painter: SatelliteCompassPainter(
        heading: _hasCompass ? _heading : 0,
        targetAz: look.azimuthDeg,
        targetEl: look.elevationDeg,
        hasCompass: _hasCompass,
        above: look.elevationDeg >= 0,
      ),
    );
  }
}

/// 罗盘画笔：外圈方位、中心目标箭头、箭头根部的点表示仰角。
class SatelliteCompassPainter extends CustomPainter {
  final double heading;
  final double targetAz;
  final double targetEl;
  final bool hasCompass;
  final bool above;

  const SatelliteCompassPainter({
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

    if (!above) return;

    // 目标箭头：相对手机顶部的角度
    final rel = (hasCompass ? targetAz - heading : targetAz) * math.pi / 180;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rel);
    canvas.drawLine(
      Offset(0, -r * 0.18),
      Offset(0, -r * 0.62),
      Paint()
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = C.orange,
    );
    final arrow = Path()
      ..moveTo(0, -r * 0.80)
      ..lineTo(-12, -r * 0.55)
      ..lineTo(12, -r * 0.55)
      ..close();
    canvas.drawPath(arrow, Paint()..color = C.orange);
    final elR = r * (1 - targetEl.clamp(0.0, 90.0) / 90) * 0.9;
    canvas.drawCircle(
      Offset(0, -elR),
      4,
      Paint()
        ..style = PaintingStyle.fill
        ..color = C.orange,
    );
    canvas.restore();

    canvas.drawCircle(center, 3, Paint()..color = C.grey);
  }

  @override
  bool shouldRepaint(covariant SatelliteCompassPainter old) =>
      old.heading != heading ||
      old.targetAz != targetAz ||
      old.targetEl != targetEl ||
      old.hasCompass != hasCompass ||
      old.above != above;
}
