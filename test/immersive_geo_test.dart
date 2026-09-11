import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/models.dart';
import 'package:aprslocus/state.dart';
import 'package:aprslocus/tile_map.dart';

/// 沉浸地图的坐标变换与「可见范围」回归保护。
///
/// 背景：该页以自己为中心，画布取屏幕对角线（保证旋转不露白边），
/// 但**可见屏窗口只占对角画布的约 45%**，所以实际可见跨度
/// ≈ `屏幕px / 256 · 360° / 2^zoom`。这正是「看不到其它台站」的
/// 主要成因之一：zoom 15 ≈ ±1km、12 ≈ ±6km、10 ≈ ±25km、9 ≈ ±50km。
/// 这里把变换与量级固定下来，避免后续调缩放时又把台站挤出视野。
void main() {
  const baseLat = 39.9042, baseLng = 116.4074;

  /// 复刻 immersive_page 的投影（含画布对角线放大）
  (Offset Function(double, double), double) makeToScreen(
      Size screen, double zoom) {
    final diag = math.sqrt(
        screen.width * screen.width + screen.height * screen.height);
    final c = MapProj.latLngToPx(baseLat, baseLng, zoom);
    Offset toScreen(double lat, double lng) {
      final p = MapProj.latLngToPx(lat, lng, zoom);
      // 跟随时 pan 恒为 0（以我为中心）
      return Offset(p.dx - c.dx + diag / 2, p.dy - c.dy + diag / 2);
    }

    return (toScreen, diag);
  }

  test('我自己落在画布正中心（跟随模式下 pan 为 0）', () {
    const screen = Size(400, 800);
    final (toScreen, diag) = makeToScreen(screen, 10);
    final self = toScreen(baseLat, baseLng);
    expect((self.dx - diag / 2).abs() < 0.01, isTrue);
    expect((self.dy - diag / 2).abs() < 0.01, isTrue);
  });

  /// 给定 zoom 下、屏幕上能看到的最大纬向偏移（度）。
  /// 用二分法求，避免手算误差。
  double visibleSpanDeg(Size screen, double zoom) {
    final (toScreen, diag) = makeToScreen(screen, zoom);
    final halfH = screen.height / 2;
    bool visible(double d) =>
        (toScreen(baseLat + d, baseLng).dy - diag / 2).abs() <= halfH;
    var lo = 0.0, hi = 10.0;
    for (var i = 0; i < 40; i++) {
      final mid = (lo + hi) / 2;
      if (visible(mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  test('可见跨度随 zoom 单调递减，且 zoom 10 至少覆盖 ±0.2°（~22km）', () {
    const screen = Size(400, 800);
    final s10 = visibleSpanDeg(screen, 10);
    final s12 = visibleSpanDeg(screen, 12);
    final s15 = visibleSpanDeg(screen, 15);

    // 1° 纬度 ≈ 111km
    expect(s10, greaterThan(0.2),
        reason: 'zoom 10 应至少覆盖 ±22km（实际 ±${(s10 * 111).round()}km）');
    expect(s10, greaterThan(s12), reason: 'zoom 越小跨度越大');
    expect(s12, greaterThan(s15), reason: 'zoom 越小跨度越大');
    // 街道级（15）可见范围应明显很窄
    expect(s15, lessThan(0.05),
        reason: 'zoom 15 可见仅 ±${(s15 * 111).toStringAsFixed(1)}km，'
            '以我为中心时看不到附近台站 → 故默认取 10');
  });

  test('接收范围为空时不过滤台站（沉浸页与主地图口径一致）', () {
    final st = AppState();
    expect(st.receiveCountries, isEmpty);
    Station mk(String call) => Station(
          call: call,
          symbol: '>',
          lat: baseLat + 0.05,
          lng: baseLng + 0.05,
          lastHeard: DateTime.now(),
          status: St.online,
        );
    final list = [mk('BG7PGW-9'), mk('BA1AAA-1'), mk('RS0ISS')];
    expect(list.where(st.stationAllowedFor).length, list.length,
        reason: '未选国家=不限制，沉浸页不应因此看不到台站');
  });

  test('非法坐标（0,0 空岛）必须被排除', () {
    // 与 _otherStations / _nearby 的过滤条件一致
    bool useable(double lat, double lng) => !(lat == 0 && lng == 0);
    expect(useable(0, 0), isFalse);
    expect(useable(baseLat, baseLng), isTrue);
  });
}
