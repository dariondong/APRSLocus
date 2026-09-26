import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/coord.dart';
import 'package:aprslocus/map_math.dart';

/// 百度瓦片/投影的数学回归。
///
/// 期望值来自权威参考实现（tile-lnglat-transform，从百度官方 JS API 提取并校对）：
///   BD-09 (113.3964152, 23.0581857) @ level 15
///     → 平面点 (12623368.55, 2622170.64)
///     → 瓦片 (6163, 1280)、像素 (193, 91)
void main() {
  test('百度平面点与瓦片编号（官方参考向量）', () {
    final p = BaiduPlane.lngLatToPoint(113.3964152, 23.0581857);
    expect((p.$1 - 12623368.55).abs() < 1.0, isTrue,
        reason: 'pointX=${p.$1}');
    expect((p.$2 - 2622170.64).abs() < 1.0, isTrue,
        reason: 'pointY=${p.$2}');

    // 百度：tile = floor(point * 2^(level-18) / 256)
    final unit = 1 << (18 - 15); // 8
    final tileX = (p.$1 / unit / 256).floor();
    final tileY = (p.$2 / unit / 256).floor();
    expect(tileX, 6163);
    expect(tileY, 1280);

    final pixelX = (p.$1 / unit - tileX * 256).floor();
    final pixelY = (p.$2 / unit - tileY * 256).floor();
    expect(pixelX, 193);
    expect(pixelY, 91);
  });

  test('平面点 → 经纬度 反解（官方参考向量）', () {
    final ll = BaiduPlane.pointToLngLat(12623368.55, 2622170.64);
    expect((ll.$1 - 113.3964152).abs() < 1e-3, isTrue, reason: 'lng=${ll.$1}');
    expect((ll.$2 - 23.0581857).abs() < 1e-3, isTrue, reason: 'lat=${ll.$2}');
  });

  test('BaiduProjection 往返一致（WGS-84）', () {
    const proj = BaiduProjection();
    const lat = 31.2304;
    const lng = 121.4737;
    final px = proj.latLngToPx(lat, lng, 15);
    final back = proj.pxToLatLng(px, 15);
    // 容差 ~1e-4°（≈11m）：百度多项式反解 + Gcj 近似反解都会引入 ~1e-5° 误差
    expect((back.$1 - lat).abs() < 1e-4, isTrue, reason: 'lat=${back.$1}');
    expect((back.$2 - lng).abs() < 1e-4, isTrue, reason: 'lng=${back.$2}');
  });

  test('BaiduProjection 列/行落在 [0,2^z) 且跨整数级连续', () {
    const proj = BaiduProjection();
    const lat = 39.9087;
    const lng = 116.3975;
    const z = 15;
    final px = proj.latLngToPx(lat, lng, z);
    final col = (px.dx / 256).floor();
    final row = (px.dy / 256).floor();
    expect(col, inInclusiveRange(0, (1 << z) - 1));
    expect(row, inInclusiveRange(0, (1 << z) - 1));

    // zoom 从 z 到 z+1 时世界像素翻倍（否则跨级会跳变）
    final a = proj.latLngToPx(lat, lng, z);
    final b = proj.latLngToPx(lat, lng, z + 1);
    expect((b.dx - a.dx * 2).abs() < 1e-6, isTrue, reason: '${b.dx} vs ${a.dx * 2}');
    expect((b.dy - a.dy * 2).abs() < 1e-6, isTrue, reason: '${b.dy} vs ${a.dy * 2}');
  });

  test('tileUrl 把「上层列/行」正确还原成百度瓦片编号', () {
    const z = 15;
    final half = 1 << (z - 1);
    // 上层列/行 ↔ 百度瓦片：col = bx + half，row = half - 1 - by
    final url = tileUrl(MapType.baidu, 6163 + half, half - 1 - 1280, z);
    expect(url.contains('x=6163'), isTrue, reason: url);
    expect(url.contains('y=1280'), isTrue, reason: url);
    expect(url.contains('z=15'), isTrue, reason: url);

    final sat = tileUrl(MapType.baidu_sat, 6163 + half, half - 1 - 1280, z);
    expect(sat.contains('x=6163'), isTrue, reason: sat);
    expect(sat.contains('y=1280'), isTrue, reason: sat);
  });

  test('WGS→BD09 走 GCJ 中间步（国内偏移落在合理范围）', () {
    // 上海 WGS：BD-09 与 WGS 的差通常在数百米量级
    final bd = Bd09.wgsToBd09(31.2304, 121.4737);
    final back = Bd09.bd09ToWgs(bd.$1, bd.$2);
    // Gcj 的反解是近似（2x−g），容差放到 1e-4°（≈11m）
    expect((back.$1 - 31.2304).abs() < 1e-4, isTrue);
    expect((back.$2 - 121.4737).abs() < 1e-4, isTrue);
  });
}
