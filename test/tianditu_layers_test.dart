import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/map_math.dart';

/// 天地图图层的回归。
///
/// 用户在既有地形图上再要求「加天地图的地形图/等高线，什么图都添加」。天地图与
/// 前面那批 Esri 免 key 图源最大的不同：**要 Key**，而且**底图不自带文字** ——
/// 地名在另一张透明注记层（cva/cia/cta）里。最容易错的不是渲染而是：
///   ① 把天地图（WGS-84）误判成 GCJ，导致底图整体偏出数百米；
///   ② 忘记拼注记层，地图没有地名还以为图源坏了；
///   ③ 子域名/参数写错，请求直接 404/418。
void main() {
  const tdt = <MapType>[
    MapType.tianditu,
    MapType.tianditu_img,
    MapType.tianditu_ter,
  ];

  test('天地图三张底图都归到「天地图」分组（不与高德/地形混在一起）', () {
    for (final t in tdt) {
      expect(t.group, '天地图', reason: '${t.name} 不在天地图分组');
    }
  });

  test('天地图是 WGS-84：不纠偏、可离线、能与 OSM 互兜底', () {
    for (final t in tdt) {
      expect(datumOf(t), MapDatum.wgs84, reason: '${t.name} 坐标系不是 WGS-84');
      expect(isGcjMapType(t), isFalse, reason: '${t.name} 被误判为 GCJ');
      expect(isBaiduMapType(t), isFalse, reason: '${t.name} 被误判为百度');
      expect(sameDatum(t, MapType.osm), isTrue, reason: '${t.name} 不能与 OSM 互兜底');
      expect(t.canDownloadOffline, isTrue, reason: '${t.name} 不能离线下载');
    }
  });

  test('底图 URL 走 /{layer}_w/wmts，参数顺序与天地图 WMTS 一致', () {
    const tk = String.fromEnvironment('TIANDITU_KEY');
    // 未配置 key 的环境（如本地/CI 未注入）下拉不到 URL，是设计上的降级。
    if (tk.isEmpty) return;
    final url = tileUrl(MapType.tianditu, 3, 5, 7);
    expect(url.startsWith('https://t'), isTrue, reason: url);
    expect(url.contains('.tianditu.gov.cn/vec_w/wmts?'), isTrue, reason: url);
    expect(url.contains('SERVICE=WMTS'), isTrue, reason: url);
    expect(url.contains('&LAYER=vec'), isTrue, reason: url);
    expect(url.contains('&TILEMATRIX=7'), isTrue, reason: url);
    expect(url.contains('&TILEROW=5'), isTrue, reason: url);
    expect(url.contains('&TILECOL=3'), isTrue, reason: url);
    expect(url.contains('&tk=$tk'), isTrue, reason: url);
  });

  test('三张底图对应不同的注记层，且注记层名不写进底图 URL', () {
    expect(annotationLayerOf(MapType.tianditu), 'cva');
    expect(annotationLayerOf(MapType.tianditu_img), 'cia');
    expect(annotationLayerOf(MapType.tianditu_ter), 'cta');
    // 底图 URL 里不能夹带注记层，否则格子对不上
    final base = tileUrl(MapType.tianditu, 3, 5, 7);
    if (base.isNotEmpty) {
      expect(base.contains('/cva'), isFalse, reason: base);
      expect(base.contains('LAYER=cva'), isFalse, reason: base);
    }
  });

  test('非注记图源没有注记层（不能给 Esri/OSM 硬塞天地图文字）', () {
    for (final t in [MapType.osm, MapType.esri_topo, MapType.gaode]) {
      expect(annotationLayerOf(t), isNull, reason: '${t.name} 不该有注记层');
      expect(annotationUrl(t, 3, 5, 7), isEmpty, reason: '${t.name} 注记 URL 应为空');
    }
  });

  test('底图与注记的缓存来源键必须分开（否则互相顶掉）', () {
    for (final t in tdt) {
      expect(annotationSourceName(t), isNot(t.name),
          reason: '${t.name} 注记键与底图键重名');
      expect(annotationSourceName(t).startsWith(t.name), isTrue,
          reason: '${t.name} 注记键应以图源名为前缀，便于查找');
    }
  });
}
