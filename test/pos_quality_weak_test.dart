import 'package:aprslocus/pos_quality.dart';
import 'package:flutter_test/flutter_test.dart';

/// 弱信号判据（用户要求：卫星弱时别把轨迹堆成一坨）。
///
/// 判据错了不会编译失败、也不会崩，只会在路上表现出来 —— 要么该放稀时不放稀
/// （轨迹一团），要么好信号也被当成弱（轨迹缺一大段）。两头都得钉住。
void main() {
  test('颗数不够算弱信号', () {
    expect(PosQuality.weakFix(sats: 3, accuracyM: 5), isTrue);
    expect(PosQuality.weakFix(sats: 4, accuracyM: 5), isTrue);
    expect(PosQuality.weakFix(sats: 5, accuracyM: 5), isFalse);
  });

  test('精度差也算弱信号', () {
    expect(PosQuality.weakFix(sats: 9, accuracyM: 45), isTrue);
    expect(PosQuality.weakFix(sats: 9, accuracyM: 12), isFalse);
  });

  test('这个源不说颗数时只看精度', () {
    expect(PosQuality.weakFix(sats: null, accuracyM: 80), isTrue);
    expect(PosQuality.weakFix(sats: null, accuracyM: 6), isFalse);
    // 0 = 这个源没给有效颗数，不能当成「一颗星都没有」
    expect(PosQuality.weakFix(sats: 0, accuracyM: 6), isFalse);
  });

  test('弱信号门限明显宽于正常门限', () {
    final normal = PosQuality.trackMinDistM(speedKmh: 30);
    expect(PosQuality.weakTrackMinDistM, greaterThan(normal));
    expect(PosQuality.weakTrackMinGapSec, greaterThan(PosQuality.trackMaxGapSec));
    expect(PosQuality.weakSkipAccuracyM, greaterThan(PosQuality.weakAccuracyM));
  });
}
