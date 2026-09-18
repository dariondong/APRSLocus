import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/map_math.dart';
import 'package:aprslocus/offline_map.dart';

/// 离线地图的纯逻辑测试。
///
/// 重点在三处「错了就会静默出问题」的地方：
///   1. **估算与实际下载的瓦片集合必须完全一致** —— 不一致的表现是
///      「界面说 300 张，实际下了 320 张」或者更糟：「下完了却缺一条边」。
///   2. **瓦片编号的边界**：±180° 经线、±85° 纬度、整圈区域。这些地方
///      差一个 tile 就是多下一列或者漏一列，肉眼看不出来。
///   3. **国内图源的 GCJ 纠偏**：瓦片编号必须用 GCJ 坐标算，
///      用 WGS 算会整体偏移，下回来的图与地图错位。
void main() {
  group('瓦片编号与范围', () {
    test('z=1 时的四个象限边界', () {
      expect(tileXFor(-180, 1), 0);
      expect(tileXFor(-0.0001, 1), 0);
      expect(tileXFor(0, 1), 1);
      expect(tileXFor(180, 1), 2); // 经度 +180 与 -180 是同一列，由 tileRange 收口
      expect(tileYFor(85.0, 1), 0);
      expect(tileYFor(0, 1), 1);
      expect(tileYFor(-85.0, 1), 1);
    });

    test('整圈纬度的 tileRange 不会多出一列', () {
      const whole = GeoBounds(south: -85, west: -180, north: 85, east: 180);
      for (final z in [0, 1, 3]) {
        final r = tileRange(whole, z);
        expect(r.x0, 0);
        expect(r.x1, (1 << z) - 1, reason: 'z=$z 应恰好覆盖整圈');
      }
      expect(countTilesIn(whole, 0, 0), 1);
    });

    test('countTilesIn 与 forEachTile 枚举数量一致（估算=实际下载范围）', () {
      const boxes = [
        GeoBounds(south: 39.8, west: 116.2, north: 40.0, east: 116.6),
        GeoBounds(south: -33.9, west: 151.0, north: -33.6, east: 151.4),
        GeoBounds(south: 0, west: 0, north: 1, east: 1),
        GeoBounds(south: 60, west: 170, north: 70, east: 179.9),
        GeoBounds(south: -85, west: -180, north: 85, east: 180),
      ];
      // 全球框必须换一套层级：z14~16 在全球范围下是 4.3 亿张瓦片，
      // 枚举本身跑不完（不是引擎慢，是样本选错了 —— 真实下载会被
      // kMaxOfflineTiles 挡在 20 万张，永远到不了这一层）。
      const normalZooms = [[10, 10], [8, 11], [14, 16]];
      const worldZooms = [[0, 0], [1, 3], [4, 6]];
      for (final b in boxes) {
        final zoomsList = (b.latSpan > 90 || b.lngSpan > 90)
            ? worldZooms
            : normalZooms;
        for (final zooms in zoomsList) {
          final counted = countTilesIn(b, zooms[0], zooms[1]);
          final seen = <String>{};
          forEachTile(b, zooms[0], zooms[1], (z, x, y) {
            seen.add('$z/$x/$y');
            return true;
          });
          expect(seen.length, counted,
              reason: '$b z${zooms[0]}-${zooms[1]} 估算与枚举不一致');
        }
      }
    });

    test('枚举出的瓦片集合确实覆盖区域内任意采样点', () {
      const b = GeoBounds(south: 39.7, west: 116.1, north: 40.1, east: 116.7);
      const z = 12;
      final tiles = <String>{};
      forEachTile(b, z, z, (zz, x, y) {
        tiles.add('$zz/$x/$y');
        return true;
      });
      for (var i = 0; i <= 10; i++) {
        for (var j = 0; j <= 10; j++) {
          final lat = b.south + (b.north - b.south) * i / 10;
          final lng = b.west + (b.east - b.west) * j / 10;
          final n = 1 << z;
          final x = ((tileXFor(lng, z) % n) + n) % n;
          final y = tileYFor(lat, z);
          expect(tiles.contains('$z/$x/$y'), isTrue,
              reason: '采样点 ($lat,$lng) 落在未枚举的瓦片上');
        }
      }
    });

    test('超出上限的大区域能被识别出来', () {
      const huge = GeoBounds(south: -60, west: -170, north: 70, east: 179);
      expect(countTilesIn(huge, 0, 16) > kMaxOfflineTiles, isTrue);
    });

    test('forEachTile 返回 false 立即停止（取消下载要及时）', () {
      const b = GeoBounds(south: 39.7, west: 116.1, north: 40.1, east: 116.7);
      var calls = 0;
      forEachTile(b, 10, 14, (z, x, y) {
        calls++;
        return calls < 3;
      });
      expect(calls, 3);
    });
  });

  group('父级瓦片（离线放大顶替）', () {
    test('parent 与 quadIn 的关系', () {
      const me = TileId(5, 13, 10);
      expect(me.parent, const TileId(4, 6, 5));
      expect(me.quadInParent, (1, 0));

      const t = TileId(16, 43000, 26000);
      final anc = TileId(14, 43000 >> 2, 26000 >> 2);
      final q = t.quadIn(anc);
      expect(q.$1, t.x - (anc.x << 2));
      expect(q.$2, t.y - (anc.y << 2));
      expect(q.$1 >= 0 && q.$1 < 4, isTrue);
      expect(q.$2 >= 0 && q.$2 < 4, isTrue);
    });

    test('z=0 没有父级', () {
      expect(const TileId(0, 0, 0).parent, isNull);
    });
  });

  group('图源 URL', () {
    test('所有栅格图源都能给出含层级的 URL', () {
      for (final t in MapType.values) {
        final url = tileUrl(t, 3, 5, 7);
        if (!t.canDownloadOffline) {
          expect(url, isEmpty, reason: '矢量图源不该有栅格 URL: $t');
        } else {
          expect(url.startsWith('http'), isTrue, reason: '$t');
          expect(url.contains('7'), isTrue, reason: '$t 缺层级: $url');
        }
      }
    });

    test('腾讯图源 y 轴做 TMS 翻转（否则整图上下颠倒）', () {
      const z = 3;
      final ty = 2;
      final url = tileUrl(MapType.tencent, 1, ty, z);
      final tmsY = (1 << z) - 1 - ty;
      expect(url.contains('y=$tmsY'), isTrue);
      expect(tmsY, 5);
    });
  });

  group('GeoBounds', () {
    test('GCJ 纠偏：国内坐标会平移，且平移量很小', () {
      const b = GeoBounds(
          south: 39.8, west: 116.3, north: 40.0, east: 116.5);
      final g = b.toGcj();
      expect(g, isNot(equals(b)));
      expect((g.south - b.south).abs() < 0.01, isTrue);
      expect((g.east - b.east).abs() < 0.01, isTrue);
      // 国外不做纠偏（否则会把 WGS 图源整体推歪）
      const uk = GeoBounds(south: 51.4, west: -0.2, north: 51.6, east: 0.1);
      expect(uk.toGcj(), uk);
    });

    test('isValid 能挡住空/倒置范围', () {
      expect(
          const GeoBounds(south: 1, west: 1, north: 1, east: 2).isValid, isFalse);
      expect(
          const GeoBounds(south: 2, west: 1, north: 1, east: 2).isValid, isFalse);
      expect(
          const GeoBounds(south: 1, west: 1, north: 2, east: 2).isValid, isTrue);
    });

    test('JSON 往返', () {
      const b = GeoBounds(
          south: -33.9, west: 151.1, north: -33.6, east: 151.4);
      final back = GeoBounds.fromJson(b.toJson());
      expect(back, b);
    });
  });

  group('视口反算', () {
    test('视口中心与跨度符合投影（GCJ 与世界坐标两种）', () {
      const size = Size(400, 800);
      const zoom = 15.0;
      for (final gcj in [false, true]) {
        final b = viewBounds(
          centerLat: gcj ? 39.9087 : 39.9042,
          centerLng: gcj ? 116.3975 : 116.4074,
          zoom: zoom,
          pan: Offset.zero,
          size: size,
          gcj: gcj,
        );
        expect(b.isValid, isTrue);
        // 视口 400×800 px，z15 时 1 px ≈ 1.19 m（纬度），跨度应很小
        expect(b.latSpan > 0 && b.latSpan < 0.05, isTrue);
        expect(b.lngSpan > 0 && b.lngSpan < 0.05, isTrue);
        // 纬度方向像素比经度方向长一倍 → 跨度约为 2:1（按度数是 4:1，
        // 因为经度的度-米换算要乘 cos(lat)；这里只验证「南北比东西长」）
        expect(b.latSpan > b.lngSpan, isTrue);
      }
    });

    test('pan 会把视口推向相反方向', () {
      const size = Size(200, 200);
      const base = GeoBounds(
          south: 39.9, west: 116.4, north: 39.91, east: 116.41);
      final a = viewBounds(
          centerLat: 39.9042,
          centerLng: 116.4074,
          zoom: 15,
          pan: Offset.zero,
          size: size);
      final b = viewBounds(
          centerLat: 39.9042,
          centerLng: 116.4074,
          zoom: 15,
          pan: const Offset(100, 0), // 内容向右拖 → 看的是更西边
          size: size);
      expect(base.isValid, isTrue);
      expect(b.centerLng < a.centerLng, isTrue);
    });
  });

  group('离线区域模型', () {
    test('JSON 往返保留全部字段', () {
      final r = OfflineRegion(
        id: 'abc',
        name: '家附近',
        mapType: MapType.gaode.name,
        bounds: const GeoBounds(
            south: 39.8, west: 116.3, north: 40.0, east: 116.5),
        minZoom: 10,
        maxZoom: 16,
        total: 300,
        done: 120,
        bytes: 1024 * 1024,
        failed: 2,
        status: OfflineStatus.paused,
      );
      final back = OfflineRegion.fromJson(r.toJson());
      expect(back.id, r.id);
      expect(back.name, r.name);
      expect(back.mapType, r.mapType);
      expect(back.bounds, r.bounds);
      expect(back.minZoom, 10);
      expect(back.maxZoom, 16);
      expect(back.total, 300);
      expect(back.done, 120);
      expect(back.bytes, 1024 * 1024);
      expect(back.failed, 2);
      expect(back.status, OfflineStatus.paused);
      expect(back.progress, closeTo(0.4, 1e-9));
    });

    test('被杀掉的 running 状态回落成 paused（否则界面永远显示「下载中」）', () {
      final r = OfflineRegion(
        id: 'x',
        name: 'n',
        mapType: MapType.osm.name,
        bounds: const GeoBounds(south: 1, west: 1, north: 2, east: 2),
        minZoom: 1,
        maxZoom: 2,
        status: OfflineStatus.running,
      );
      expect(OfflineRegion.fromJson(r.toJson()).status, OfflineStatus.paused);
    });

    test('瓦片编号空间：国内图源用 GCJ 范围，国际图源原样', () {
      const b = GeoBounds(south: 39.8, west: 116.3, north: 40.0, east: 116.5);
      final gcj = OfflineRegion(
        id: 'a', name: 'a', mapType: MapType.gaode.name,
        bounds: b, minZoom: 10, maxZoom: 12,
      );
      final wgs = OfflineRegion(
        id: 'b', name: 'b', mapType: MapType.osm.name,
        bounds: b, minZoom: 10, maxZoom: 12,
      );
      expect(gcj.tileSpaceBounds, isNot(equals(b)));
      expect(wgs.tileSpaceBounds, b);
      expect(gcj.tileCount > 0, isTrue);
      expect(wgs.tileCount > 0, isTrue);
    });

    test('resumable 只覆盖未完成的状态', () {
      expect(OfflineStatus.pending.resumable, isTrue);
      expect(OfflineStatus.paused.resumable, isTrue);
      expect(OfflineStatus.canceled.resumable, isTrue);
      expect(OfflineStatus.failed.resumable, isTrue);
      expect(OfflineStatus.running.resumable, isFalse);
      expect(OfflineStatus.done.resumable, isFalse);
    });
  });

  group('格式化', () {
    test('formatBytes 的分档与进位', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(999), '999 B');
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(1024 * 1024), '1.0 MB');
      expect(formatBytes(16 * 1024), '16 KB');
      expect(formatBytes(1024 * 1024 * 1024), '1.00 GB');
    });
  });

  group('区域 id', () {
    test('连续生成不重复', () {
      final ids = {for (var i = 0; i < 200; i++) newOfflineRegionId()};
      expect(ids.length, 200);
    });
  });
}
