import 'package:aprslocus/turn_dot.dart';
import 'package:flutter_test/flutter_test.dart';

/// 「转弯打点」航向过滤层（lib/turn_dot.dart）的回归测试。
///
/// 这里断言的每一条，都对应一个**真机上才看得出来**的失效模式：
/// 野值凭空触发补点、野值被钉成基准、稀疏采样被误杀、持续快转导致永久失明。
/// 算法与参数依据见 lib/turn_dot.dart 的文件头与 tool/sim_turn_dot.py。
void main() {
  final t0 = DateTime(2026, 1, 1, 12, 0, 0);

  /// 以 1 秒一帧喂一串航向。
  void feed(TurnDotDetector d, List<double> courses, {DateTime? from}) {
    var t = from ?? t0;
    for (final c in courses) {
      d.onCourse(c, t);
      t = t.add(const Duration(seconds: 1));
    }
  }

  group('fold180 最小夹角', () {
    test('环绕折算：359° → 1° 是 2°，不是 358°', () {
      expect(fold180(359.0 - 1.0), closeTo(2.0, 1e-9));
      expect(fold180(1.0 - 359.0), closeTo(2.0, 1e-9));
      expect(fold180(90.0), closeTo(90.0, 1e-9));
      expect(fold180(270.0), closeTo(90.0, 1e-9));
      expect(fold180(180.0), closeTo(180.0, 1e-9));
      expect(fold180(-45.0), closeTo(45.0, 1e-9));
    });
  });

  group('物理门：一帧跳太多就是野值', () {
    test('直路巡航 + 一帧 60° 野值 → 偏离判据完全不受影响', () {
      final d = TurnDotDetector();
      feed(d, List<double>.filled(10, 10.0));
      expect(d.deviationDeg, closeTo(0.0, 1e-9));

      // 60°/秒 远超 maxStepDeg：丢掉，不参与判断
      d.onCourse(70.0, t0.add(const Duration(seconds: 10)));
      expect(d.deviationDeg, closeTo(0.0, 1e-9));
      expect(d.lastTrustedDeg, closeTo(10.0, 1e-9));

      // 回到真实航向：也不该凭空产生偏离（野值没被当成新基准）
      d.onCourse(10.0, t0.add(const Duration(seconds: 11)));
      expect(d.deviationDeg, closeTo(0.0, 1e-9));
    });

    test('真实转向（22.5°/秒，发卡弯）要放行', () {
      final d = TurnDotDetector();
      feed(d, const [0.0, 0.0, 337.5, 315.0, 292.5, 270.0]);
      // 从 0° 转到 270°（= −90°）一共 90°
      expect(d.deviationDeg, closeTo(90.0, 1e-9));
    });

    test('连续丢弃到上限后**重新同步**（否则永久失明）', () {
      final d = TurnDotDetector();
      feed(d, List<double>.filled(5, 0.0));
      // 每帧 50°（> 40）：前 maxDrops-1 帧丢掉，第 maxDrops 帧强制同步。
      // 于是「可信航向」始终**跟在输入后面不超过 maxDrops 帧** ——
      // 若没有这个上限，它会永远停在 0° 上再也不动（永久失明）。
      var t = t0.add(const Duration(seconds: 5));
      var c = 0.0;
      for (var i = 0; i < 8; i++) {
        c = (c + 50.0) % 360.0;
        d.onCourse(c, t);
        t = t.add(const Duration(seconds: 1));
      }
      final lag = fold180(d.lastTrustedDeg! - c);
      expect(lag <= TurnDotDetector.maxStepDeg * TurnDotDetector.maxDrops, isTrue,
          reason: '可信航向落后 $lag°，超过 maxDrops 帧的转向量 —— 检测器没跟上');
    });

    test('稀疏采样（佳明那种 20 秒一个点）不会被误杀', () {
      final d = TurnDotDetector();
      d.onCourse(0.0, t0);
      // 20 秒后航向变了 110°：折算后允许 40 × 20 = 800°，必须放行
      d.onCourse(110.0, t0.add(const Duration(seconds: 20)));
      expect(d.deviationDeg, closeTo(110.0, 1e-9));
    });

    test('null 航向不动任何状态', () {
      final d = TurnDotDetector();
      feed(d, const [30.0, 30.0]);
      d.onCourse(null, t0.add(const Duration(seconds: 5)));
      expect(d.deviationDeg, closeTo(0.0, 1e-9));
      expect(d.lastTrustedDeg, closeTo(30.0, 1e-9));
    });
  });

  group('markSent：基准要用**可信**航向', () {
    test('发送后判据归零，且基准不是野值', () {
      final d = TurnDotDetector();
      feed(d, List<double>.filled(5, 0.0));
      // 35° 低于物理门（40），要被放行
      feed(d, const [35.0], from: t0.add(const Duration(seconds: 5)));
      expect(d.deviationDeg, closeTo(35.0, 1e-9));

      d.markSent();
      expect(d.deviationDeg, closeTo(0.0, 1e-9));

      // 发送那一刻若正好来了一帧野值（35° → 200°，跳 165°），它**不能**成为基准：
      // 否则之后真实的 35° 会与它差 165°，凭空触发一轮补点。
      d.onCourse(200.0, t0.add(const Duration(seconds: 6)));
      d.markSent();
      d.onCourse(35.0, t0.add(const Duration(seconds: 7)));
      expect(d.deviationDeg, closeTo(0.0, 1e-9));
    });

    test('还没喂过航向时 markSent 不炸、判据保持 0', () {
      final d = TurnDotDetector();
      d.markSent();
      expect(d.deviationDeg, closeTo(0.0, 1e-9));
      d.onCourse(120.0, t0);
      expect(d.deviationDeg, closeTo(0.0, 1e-9));   // 第一帧只立基准
      d.onCourse(150.0, t0.add(const Duration(seconds: 1)));
      expect(d.deviationDeg, closeTo(30.0, 1e-9));
    });
  });

  test('常量与仿真一致（两端漂移就等于仿真在验另一个算法）', () {
    expect(TurnDotDetector.maxStepDeg, 40.0);
    expect(TurnDotDetector.maxDrops, 3);
  });
}
