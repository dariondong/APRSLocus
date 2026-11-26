import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'satellite.dart';
import 'theme.dart';
import 'widgets.dart';

/// 大罗盘：N/E/S/W 随手机航向转，橙色箭头指向卫星。
///
/// 用 [MotionService] 的航向（旋转矢量/磁力计），100ms 刷新一次。
/// 没有指南针时退化成「正北朝上」的静态罗盘。
class SatelliteCompass extends StatefulWidget {
  final Tle tle;
  final double lat, lng;

  /// 当前选中的过境；有它就在罗盘上画整条「经过线」（含 AOS/LOS）。
  final SatPass? pass;

  const SatelliteCompass({
    super.key,
    required this.tle,
    required this.lat,
    required this.lng,
    this.pass,
  });

  @override
  State<SatelliteCompass> createState() => _SatelliteCompassState();
}

class _SatelliteCompassState extends State<SatelliteCompass> {
  double _heading = -1;
  bool _hasCompass = false;
  Timer? _timer;
  List<SkyPoint> _trail = const [];

  @override
  void initState() {
    super.initState();
    _syncTrail();
    _start();
  }

  /// 轨迹只跟 (TLE, 观测点, 过境) 有关，预先算好；罗盘 10Hz 刷新时不能重算。
  void _syncTrail() {
    final p = widget.pass;
    _trail = p == null
        ? const []
        : passTrack(widget.tle, widget.lat, widget.lng, p);
  }

  @override
  void didUpdateWidget(covariant SatelliteCompass old) {
    super.didUpdateWidget(old);
    final a = old.pass;
    final b = widget.pass;
    if (old.tle != widget.tle ||
        old.lat != widget.lat ||
        old.lng != widget.lng ||
        a?.aos != b?.aos ||
        a?.los != b?.los) {
      _syncTrail();
    }
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
    final s = S.of(context);
    final now = DateTime.now();
    final look = lookAt(widget.tle, widget.lat, widget.lng, now);
    final altKm = subPoint(widget.tle, now).altKm;
    return CustomPaint(
      painter: SatelliteCompassPainter(
        heading: _hasCompass ? _heading : 0,
        targetAz: look.azimuthDeg,
        targetEl: look.elevationDeg,
        hasCompass: _hasCompass,
        above: look.elevationDeg >= 0,
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
  final List<SkyPoint> trail;
  final DateTime now;
  final double rangeKm;
  final double altKm;
  final String azLabel;
  final String elLabel;
  final String rangeLabel;
  final String altLabel;
  final String headingLabel;

  const SatelliteCompassPainter({
    required this.heading,
    required this.targetAz,
    required this.targetEl,
    required this.hasCompass,
    required this.above,
    this.trail = const [],
    required this.now,
    this.rangeKm = 0,
    this.altKm = 0,
    this.azLabel = 'AZ',
    this.elLabel = 'EL',
    this.rangeLabel = 'R',
    this.altLabel = 'H',
    this.headingLabel = 'HDG',
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

    // 过境「经过线」：先画在箭头下面，卫星在地平线下也能看到整条轨迹。
    _drawTrail(canvas, cx, cy, r, center);

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

    // 罗盘上的当前读数：方位/仰角、航向、距离、高度。
    _drawReadouts(canvas, size);
  }

  @override
  bool shouldRepaint(covariant SatelliteCompassPainter old) =>
      old.heading != heading ||
      old.targetAz != targetAz ||
      old.targetEl != targetEl ||
      old.hasCompass != hasCompass ||
      old.above != above ||
      old.trail != trail ||
      old.now != now;

  /// 罗盘上的「经过线」：整条过境的方位/仰角轨迹。
  ///
  /// 未来亮、已过淡；两端小圈是 AOS / LOS；卫星正在过境时再加一个当前点圈。
  /// 画布跟着手机航向一起转，所以把手机转到北，这条线就是真实的过境弧。
  void _drawTrail(
      Canvas canvas, double cx, double cy, double r, Offset center) {
    if (trail.length < 2) return;

    // 30° / 60° 仰角参考圈（仰角越高越靠中心）。
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = C.greyLight.withValues(alpha: 0.55);
    canvas.drawCircle(center, r * 0.9 * (1 - 30 / 90), ring);
    canvas.drawCircle(center, r * 0.9 * (1 - 60 / 90), ring);
    _tiny(canvas, '30°', Offset(cx + 3, cy - r * 0.9 * 0.6 - 12), C.grey);
    _tiny(canvas, '60°', Offset(cx + 3, cy - r * 0.9 * 0.3 - 12), C.grey);

    Offset pos(SkyPoint p) {
      final el = p.elevationDeg.clamp(0.0, 90.0);
      final rad = (p.azimuthDeg - heading) * math.pi / 180;
      final rr = r * (1 - el / 90) * 0.9;
      return Offset(cx + rr * math.sin(rad), cy - rr * math.cos(rad));
    }

    // 整条线先垫一层很淡的底，避免细线在亮底图上断掉。
    final all = Path();
    for (var i = 0; i < trail.length; i++) {
      final p = pos(trail[i]);
      if (i == 0) {
        all.moveTo(p.dx, p.dy);
      } else {
        all.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      all,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = C.cyan.withValues(alpha: 0.10),
    );

    final past = Path();
    final future = Path();
    var pastStarted = false;
    var futureStarted = false;
    for (var i = 0; i < trail.length; i++) {
      final p = trail[i];
      final d = pos(p);
      if (!p.at.isAfter(now)) {
        if (!pastStarted) {
          past.moveTo(d.dx, d.dy);
          pastStarted = true;
        } else {
          past.lineTo(d.dx, d.dy);
        }
      } else {
        if (!futureStarted) {
          futureStarted = true;
          if (i > 0) {
            final q = pos(trail[i - 1]);
            future.moveTo(q.dx, q.dy);
            future.lineTo(d.dx, d.dy);
          } else {
            future.moveTo(d.dx, d.dy);
          }
        } else {
          future.lineTo(d.dx, d.dy);
        }
      }
    }
    if (pastStarted) {
      canvas.drawPath(
        past,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = C.cyan.withValues(alpha: 0.30),
      );
    }
    if (futureStarted) {
      canvas.drawPath(
        future,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = C.cyan.withValues(alpha: 0.92),
      );
    }

    // AOS / LOS 端点。
    final endPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = C.cyan.withValues(alpha: 0.9);
    canvas.drawCircle(pos(trail.first), 3.2, endPaint);
    canvas.drawCircle(pos(trail.last), 3.2, endPaint);

    // 每分钟一个点：看得出卫星沿轨迹走的快慢（靠近天顶时走得快）。
    var lastMin = -1;
    final tick = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (final p in trail) {
      if (p.at.minute == lastMin) continue;
      lastMin = p.at.minute;
      canvas.drawCircle(pos(p), 1.6, tick);
    }

    // TCA：轨迹上最高仰角那一点，单独标出来。
    var tca = trail.first;
    for (final p in trail) {
      if (p.elevationDeg > tca.elevationDeg) tca = p;
    }
    final td = pos(tca);
    final diamond = Path()
      ..moveTo(td.dx, td.dy - 4)
      ..lineTo(td.dx + 4, td.dy)
      ..lineTo(td.dx, td.dy + 4)
      ..lineTo(td.dx - 4, td.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = C.orange);
    _tiny(canvas, 'TCA', td + const Offset(6, -10), C.orange);

    // 当前点：只在「这条过境正在进行」时画，避免选了别的过境时错位。
    if (!now.isBefore(trail.first.at) && !now.isAfter(trail.last.at)) {
      final d = pos(trail.firstWhere(
        (p) => !p.at.isBefore(now),
        orElse: () => trail.last,
      ));
      canvas.drawCircle(
        d,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: 0.75),
      );
    }
  }

  // ─── 读数 ───

  TextPainter _tp(String text, double size, Color color, FontWeight weight,
      {double ls = 0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: weight,
          letterSpacing: ls,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
  }

  void _tiny(Canvas canvas, String text, Offset at, Color color) {
    final tp =
        _tp(text, 8.5, color.withValues(alpha: 0.92), FontWeight.w700);
    tp.paint(canvas, at);
  }

  void _pill(Canvas canvas, Rect r) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(9)),
      Paint()..color = C.bg.withValues(alpha: 0.78),
    );
  }

  /// 左上/右上角的大读数：小标签 + 大数值。
  void _stat(Canvas canvas, Offset at, String label, String value,
      Color accent, {required bool right}) {
    final l = _tp(label, 8.5, C.grey, FontWeight.w700, ls: 0.5);
    final v = _tp(value, 21, accent, FontWeight.w800, ls: -0.5);
    final w = math.max(l.width, v.width);
    final x = right ? at.dx - w : at.dx;
    _pill(canvas, Rect.fromLTWH(x - 7, at.dy - 3, w + 14,
        l.height + v.height + 7));
    l.paint(canvas, Offset(x, at.dy));
    v.paint(canvas, Offset(x, at.dy + l.height + 1));
    canvas.drawCircle(
      Offset(x - 3.5, at.dy + l.height / 2),
      1.8,
      Paint()..color = accent,
    );
  }

  /// 罗盘上的实时读数：方位/仰角、航向、高度、距离。
  void _drawReadouts(Canvas canvas, Size size) {
    _stat(canvas, const Offset(8, 8), azLabel,
        '${targetAz.toStringAsFixed(0)}°', C.cyan, right: false);
    _stat(canvas, Offset(size.width - 8, 8), elLabel,
        '${targetEl.toStringAsFixed(0)}°', C.orange, right: true);

    final hdg = hasCompass ? '${heading.round()}°' : '--';
    final items = [
      _tp('$headingLabel $hdg', 10, C.slate, FontWeight.w600),
      _tp(
          '$altLabel ${altKm <= 0 ? '--' : '${altKm.toStringAsFixed(0)} km'}',
          10,
          C.slate,
          FontWeight.w600),
      _tp(
          '$rangeLabel ${rangeKm <= 0 ? '--' : '${rangeKm.toStringAsFixed(0)} km'}',
          10,
          C.slate,
          FontWeight.w600),
    ];
    const gap = 10.0;
    final total = items.fold<double>(0, (a, t) => a + t.width) +
        gap * (items.length - 1);
    final y = size.height - 20;
    var x = (size.width - total) / 2;
    if (total > size.width - 16) {
      // 窄屏：只保留航向和距离，别叠成一团。
      x = 8;
    }
    final draw = total > size.width - 16 ? [items[0], items[2]] : items;
    var cx = x;
    for (final t in draw) {
      _pill(canvas, Rect.fromLTWH(cx - 6, y - 3, t.width + 12, t.height + 6));
      t.paint(canvas, Offset(cx, y));
      cx += t.width + gap;
    }
  }
}
