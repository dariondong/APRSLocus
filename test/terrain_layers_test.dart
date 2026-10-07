import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/map_math.dart';

/// 地形/等高线图层的回归。
///
/// 用户要求「加一些等高线图 / 地形图图层」。这些底图是**国际 WGS-84 瓦片**
/// （Esri 免 key），最容易错的不是渲染而是：坐标顺序（Esri 是 z/y/x，不是
/// z/x/y）、坐标系被判成 GCJ 而导致整体偏 500m、以及地图类型分组没归到「地形」。
void main() {
  const terrain = <MapType>[
    MapType.open_topo,
    MapType.esri_topo,
    MapType.esri_relief,
    MapType.esri_hillshade,
  ];

  test('地形图源都属于「地形」分组（用户能在同一组里找到）', () {
    for (final t in terrain) {
      expect(t.group, '地形', reason: '${t.name} 不在地形分组');
    }
  });

  test('地形图源可离线下载（否则野外断网就废了）', () {
    for (final t in terrain) {
      expect(t.canDownloadOffline, isTrue, reason: '${t.name} 不能离线下载');
    }
  });

  test('地形图源是 WGS-84，可与 OSM 互为兜底，不做 GCJ 纠偏', () {
    for (final t in terrain) {
      expect(datumOf(t), MapDatum.wgs84, reason: '${t.name} 坐标系不是 WGS-84');
      expect(isGcjMapType(t), isFalse, reason: '${t.name} 被误判为 GCJ');
      expect(isBaiduMapType(t), isFalse, reason: '${t.name} 被误判为百度');
      expect(sameDatum(t, MapType.osm), isTrue, reason: '${t.name} 不能与 OSM 互兜底');
    }
  });

  test('OpenTopo 走 opentopomap 的 256px PNG', () {
    final url = tileUrl(MapType.open_topo, 3, 5, 7);
    expect(url, 'https://tile.opentopomap.org/7/3/5.png');
  });

  test('Esri 地形三图源坐标顺序为 z/y/x（写反会取到另一张图）', () {
    // 取 tx=3, ty=5, z=7：正确模板应得到 .../tile/7/5/3
    const tx = 3, ty = 5, z = 7;
    final expected = <MapType, String>{
      MapType.esri_topo:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/7/5/3',
      MapType.esri_relief:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Shaded_Relief/MapServer/tile/7/5/3',
      MapType.esri_hillshade:
          'https://server.arcgisonline.com/ArcGIS/rest/services/Elevation/World_Hillshade/MapServer/tile/7/5/3',
    };
    expected.forEach((t, url) {
      expect(tileUrl(t, tx, ty, z), url, reason: '${t.name} URL 不符');
    });
  });

  test('所有地形图源都能给出含层级的瓦片 URL', () {
    for (final t in terrain) {
      final url = tileUrl(t, 3, 5, 7);
      expect(url.startsWith('https://'), isTrue, reason: '${t.name}: $url');
      expect(url.contains('/7/'), isTrue, reason: '${t.name} 缺层级: $url');
    }
  });
}
