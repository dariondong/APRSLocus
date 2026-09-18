import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'coord.dart';

/// ─── 地图数学 / 图源定义（纯逻辑，无 Widget）───
///
/// 这里放三样东西，它们原本散在 `tile_map.dart` 里（Widget 文件）：
///   1. Web Mercator 投影 [MapProj]
///   2. 图源枚举 [MapType] 与瓦片 URL 构造 [tileUrl]（**唯一定义处**）
///   3. 矩形经纬范围 [GeoBounds] 与瓦片枚举/计数、视口范围反算
///
/// 拆出来的理由很实在：**离线下载引擎与「下载区域」界面都要算瓦片编号**，
/// 而它们不该依赖 Widget 层。更要紧的是——如果下载用的瓦片编号与渲染用的
/// 不是同一套代码，就会出现「下载了却离线看不到」这种最难查的错位。
/// 所以两处都从这里取 [tileUrl] 与 [MapProj]。

/// Web Mercator 投影工具（连续 zoom）
class MapProj {
  static Offset latLngToPx(double lat, double lng, num zoom) {
    final n = 256 * math.pow(2, zoom);
    final x = (lng + 180) / 360 * n;
    final s = math.sin(lat * math.pi / 180);
    final y =
        (1 - math.log((1 + s) / (1 - s)) / (2 * math.pi)) / 2 * n;
    return Offset(x.toDouble(), y.toDouble());
  }

  /// 逆投影：像素坐标 → 经纬度
  static (double, double) pxToLatLng(Offset px, num zoom) {
    final n = 256 * math.pow(2, zoom);
    final lng = px.dx / n * 360 - 180;
    final y = px.dy / n;
    final a = math.exp(math.pi * (1 - 2 * y));
    final lat = (2 * math.atan(a) - math.pi / 2) * 180 / math.pi;
    return (lat.toDouble(), lng.toDouble());
  }
}

/// 瓦片图源请求头（部分图源校验 Referer）
const Map<String, String> tileHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36',
  'Referer': 'https://www.amap.com/',
};

/// 高德瓦片：按 tx+ty 哈希轮询 4 个子域名，避免单域名限流
String _gaodeUrl(int tx, int ty, int z, {int style = 7}) {
  final s = ((tx * 7 + ty * 13) % 4) + 1;
  return 'https://webrd0$s.is.autonavi.com/appmaptile'
      '?lang=zh_cn&size=1&scale=1&style=$style&x=$tx&y=$ty&z=$z';
}

/// 该图源是否为 GCJ-02（火星坐标）瓦片。
/// 国内图源（高德/腾讯）均为 GCJ-02，而 APRS 数据是 WGS-84，
/// 必须做坐标纠偏标记才能落准。
bool isGcjMapType(MapType t) =>
    t == MapType.gaode ||
    t == MapType.gaode_sat ||
    t == MapType.tencent ||
    t == MapType.tencent_sat;

/// 腾讯瓦片（GCJ-02）。注意其 **y 轴为 TMS**，与 XYZ 相反，
/// 需用 2^z-1-ty 翻转，否则整张图上下颠倒/错位。
/// 街道：realtimerender；卫星：sateTiles（按 16×16 分块路径）。
String _tencentUrl(int tx, int ty, int z, {bool sat = false}) {
  final tmsY = (1 << z) - 1 - ty;
  if (sat) {
    return 'https://p0.map.gtimg.com/sateTiles/$z/${tx ~/ 16}/${tmsY ~/ 16}'
        '/${tx}_$tmsY.jpg';
  }
  return 'https://rt0.map.gtimg.com/realtimerender'
      '?z=$z&x=$tx&y=$tmsY&type=vector&style=0';
}

// 各图源瓦片模板（Carto raster basemaps 需 API key，其余免 key）
const _cartoLightUrl =
    'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png?key='
    'cb1_2tpj_1_0a343408cea16e942cf61257';
const _cartoDarkUrl =
    'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png?key='
    'cb1_2tpj_1_0a343408cea16e942cf61257';
const _cartoVoyagerUrl =
    'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key='
    'cb1_2tpj_1_0a343408cea16e942cf61257';
const _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _osmHotUrl = 'https://tile-{s}.openstreetmap.fr/hot/{z}/{x}/{y}.png';
const _openTopoUrl = 'https://tile.opentopomap.org/{z}/{x}/{y}.png';
const _esriStreetUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
const _esriSatUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

/// 替换 {z}/{x}/{y}/{s}，{s} 为子域名轮询（a/b/c）
String _fillTemplate(String tpl, int tx, int ty, int z) {
  final s = ['a', 'b', 'c'][(tx + ty) % 3];
  return tpl
      .replaceAll('{z}', '$z')
      .replaceAll('{x}', '$tx')
      .replaceAll('{y}', '$ty')
      .replaceAll('{s}', s);
}

/// 某图源在 z/x/y 处的瓦片地址；矢量图源（由客户端渲染）返回空串。
///
/// 在线渲染与离线下载**共用这一个函数**：两处各写一份 URL 拼接迟早会
/// 漂移成「下载得到的和显示要的不是同一张图」。
String tileUrl(MapType t, int tx, int ty, int z) {
  switch (t) {
    case MapType.gaode:
      return _gaodeUrl(tx, ty, z, style: 7);
    case MapType.gaode_sat:
      return _gaodeUrl(tx, ty, z, style: 6);
    case MapType.tencent:
      return _tencentUrl(tx, ty, z);
    case MapType.tencent_sat:
      return _tencentUrl(tx, ty, z, sat: true);
    case MapType.carto:
      return _fillTemplate(_cartoLightUrl, tx, ty, z);
    case MapType.carto_dark:
      return _fillTemplate(_cartoDarkUrl, tx, ty, z);
    case MapType.carto_voyager:
      return _fillTemplate(_cartoVoyagerUrl, tx, ty, z);
    case MapType.osm:
      return _fillTemplate(_osmUrl, tx, ty, z);
    case MapType.osm_hot:
      return _fillTemplate(_osmHotUrl, tx, ty, z);
    case MapType.open_topo:
      return _fillTemplate(_openTopoUrl, tx, ty, z);
    case MapType.esri_street:
      return _fillTemplate(_esriStreetUrl, tx, ty, z);
    case MapType.esri_sat:
      return _fillTemplate(_esriSatUrl, tx, ty, z);
    case MapType.vector:
    case MapType.vector_positron:
      // 矢量地图由 VectorMapView 客户端渲染，没有栅格瓦片地址
      return '';
  }
}

/// 地图类型
enum MapType {
  gaode('高德地图', group: '高德'),
  gaode_sat('高德卫星', group: '高德'),
  // 腾讯同为国内 GCJ-02 图源（分组键沿用 '高德'，界面显示为「国内地图」）
  tencent('腾讯地图', group: '高德'),
  tencent_sat('腾讯卫星', group: '高德'),
  vector('矢量地图', group: '其他'),
  vector_positron('Carto Positron(浅色矢量)', group: '其他'),
  carto('Carto 浅色', group: '其他'),
  carto_dark('Carto 深色', group: '其他'),
  carto_voyager('Carto 航行者', group: '其他'),
  osm('OSM 标准', group: '其他'),
  osm_hot('OSM 人道', group: '其他'),
  open_topo('OpenTopo 地形', group: '其他'),
  esri_street('Esri 街道', group: '其他'),
  esri_sat('Esri 影像', group: '其他');

  const MapType(this.label, {this.group = '高德'});
  final String label;
  final String group;

  /// 该图源是否可下载为离线瓦片（矢量图源需要另一套 mbtiles 流程）
  bool get canDownloadOffline =>
      this != MapType.vector && this != MapType.vector_positron;
}

/// 按名字取图源（存储里存的是 name，枚举顺序变了也不会错位）
MapType mapTypeByName(String name) => MapType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => MapType.gaode,
    );

/// 经纬度矩形范围（WGS-84）
class GeoBounds {
  final double south, west, north, east;

  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  /// 是否有效（跨 180° 经线的区域会被规整，见 [normalized]）
  bool get isValid =>
      south.isFinite &&
      west.isFinite &&
      north.isFinite &&
      east.isFinite &&
      north > south &&
      east > west;

  double get centerLat => (south + north) / 2;
  double get centerLng => (west + east) / 2;

  double get latSpan => north - south;
  double get lngSpan => east - west;

  GeoBounds normalized() {
    var s = south.clamp(-85.05112878, 85.05112878).toDouble();
    var n = north.clamp(-85.05112878, 85.05112878).toDouble();
    var w = west;
    var e = east;
    // 经度规整到 [-180,180]，跨 180° 时保持东西跨度不变
    while (w < -180) {
      w += 360;
      e += 360;
    }
    while (w > 180) {
      w -= 360;
      e -= 360;
    }
    if (n < s) {
      final t = s;
      s = n;
      n = t;
    }
    return GeoBounds(south: s, west: w, north: n, east: e);
  }

  /// 转到底图坐标系：GCJ 图源的瓦片编号必须用 GCJ 坐标算
  GeoBounds toGcj() {
    final a = Gcj.wgsToGcj(south, west);
    final b = Gcj.wgsToGcj(north, east);
    return GeoBounds(
      south: math.min(a.$1, b.$1),
      west: math.min(a.$2, b.$2),
      north: math.max(a.$1, b.$1),
      east: math.max(a.$2, b.$2),
    );
  }

  Map<String, dynamic> toJson() => {
        's': south,
        'w': west,
        'n': north,
        'e': east,
      };

  static GeoBounds fromJson(Map<String, dynamic> j) => GeoBounds(
        south: (j['s'] as num).toDouble(),
        west: (j['w'] as num).toDouble(),
        north: (j['n'] as num).toDouble(),
        east: (j['e'] as num).toDouble(),
      );

  /// 人类可读的范围（用于区域卡片副标题）
  String describe() {
    String f(double v, bool lat) {
      final dir = lat ? (v >= 0 ? 'N' : 'S') : (v >= 0 ? 'E' : 'W');
      return '${v.abs().toStringAsFixed(3)}°$dir';
    }

    return '${f(south, true)}–${f(north, true)}, '
        '${f(west, false)}–${f(east, false)}';
  }

  @override
  String toString() => describe();

  @override
  bool operator ==(Object other) =>
      other is GeoBounds &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);
}

/// 瓦片编号（z/x/y）。y 为 XYZ（左上为原点）编号，
/// 与 `MapProj` 一致；腾讯图源的 TMS 翻转在 [tileUrl] 内部处理。
class TileId {
  final int z, x, y;
  const TileId(this.z, this.x, this.y);

  /// 父级瓦片（缩放一层）。瓦片金字塔的标准关系：父 = (x/2, y/2)。
  TileId? get parent =>
      z <= 0 ? null : TileId(z - 1, x >> 1, y >> 1);

  /// 本瓦片在父瓦片内的 2×2 位置（放大父图时用它裁切）
  (int, int) get quadInParent => (x & 1, y & 1);

  /// 本瓦片在祖先 [ancestor] 内的位置（祖先一层覆盖 2^(z-ancestor.z) 的方块）
  (int, int) quadIn(TileId ancestor) {
    final d = z - ancestor.z;
    return (x - (ancestor.x << d), y - (ancestor.y << d));
  }

  @override
  String toString() => '$z/$x/$y';

  @override
  bool operator ==(Object other) =>
      other is TileId && other.z == z && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(z, x, y);
}

/// 瓦片总数上限：超出的区域直接拒绝下载。
///
/// 这不是「防呆」而是防卡死：一张瓦片约 15 KB，20 万张就是 3 GB 与数小时，
/// 而枚举/计数本身要遍历 20 万次。上限取 200000，界面上会提示缩小范围。
const int kMaxOfflineTiles = 200000;

/// 单张瓦片的估算体积（高德/OSM 实测 12–18 KB，取 16 KB 作估计值）
const int kTileBytesEstimate = 16 * 1024;

/// 经度 → 瓦片 x（不取模）
int tileXFor(double lng, int z) {
  final n = 1 << z;
  final v = ((lng + 180) / 360 * n).floor();
  return v;
}

/// 纬度 → 瓦片 y（不取模）
int tileYFor(double lat, int z) {
  final clamped = lat.clamp(-85.05112878, 85.05112878).toDouble();
  final p = MapProj.latLngToPx(clamped, 0, z);
  return (p.dy / 256).floor();
}

/// 该 z 层上覆盖 [b] 的瓦片矩形（x/y 均为闭区间，x 可能超过 2^z-1，取模在枚举时做）
({int x0, int x1, int y0, int y1}) tileRange(GeoBounds b, int z) {
  final n = 1 << z;
  final x0 = tileXFor(b.west, z);
  var x1 = tileXFor(b.east, z);
  // 东边界正好落在整圈处（如 ±180°）时 x1 会等于 2^z —— 它与 x0 是同一列，
  // 不减 1 会多枚举一列并让计数虚高（跨 180° 的区域最容易踩到）
  if (x1 - x0 + 1 > n) x1 = x0 + n - 1;
  final y0 = tileYFor(b.north, z).clamp(0, n - 1);
  final y1 = tileYFor(b.south, z).clamp(0, n - 1);
  return (x0: x0, x1: x1, y0: y0, y1: y1);
}

/// 覆盖 [b] 的瓦片张数（按算术公式，不展开枚举）
int countTilesIn(GeoBounds b, int minZoom, int maxZoom) {
  if (!b.isValid || maxZoom < minZoom) return 0;
  var total = 0;
  for (var z = minZoom; z <= maxZoom; z++) {
    final r = tileRange(b, z);
    final w = r.x1 - r.x0 + 1;
    final h = r.y1 - r.y0 + 1;
    if (w <= 0 || h <= 0) continue;
    total += w * h;
  }
  return total;
}

/// 展开 [b] 在 [minZoom]..[maxZoom] 上的所有瓦片。
///
/// [onTile] 返回 false 表示停止枚举（用于暂停/取消立即生效）。
/// 经度方向取模包边，纬度方向已 clamp。
void forEachTile(
  GeoBounds b,
  int minZoom,
  int maxZoom,
  bool Function(int z, int x, int y) onTile,
) {
  if (!b.isValid) return;
  for (var z = minZoom; z <= maxZoom; z++) {
    final n = 1 << z;
    final r = tileRange(b, z);
    for (var y = r.y0; y <= r.y1; y++) {
      for (var x = r.x0; x <= r.x1; x++) {
        final wx = ((x % n) + n) % n;
        if (!onTile(z, wx, y)) return;
      }
    }
  }
}

/// 视口反算：给定渲染参数，返回视口对应的 WGS-84 经纬范围。
///
/// 与 `TileMapView` 的换算必须严格一致（否则框选的范围和实际下载不一致）：
///   left = centerPx - pan - size/2
///   viewCenterPx = centerPx - pan
/// [gcj] 为 true 时（国内图源）先把视口角点从 GCJ-02 反解回 WGS-84。
GeoBounds viewBounds({
  required double centerLat,
  required double centerLng,
  required double zoom,
  required Offset pan,
  required Size size,
  bool gcj = false,
}) {
  final c = MapProj.latLngToPx(centerLat, centerLng, zoom);
  final vc = c - pan;
  final tl = vc - Offset(size.width / 2, size.height / 2);
  final br = Offset(tl.dx + size.width, tl.dy + size.height);
  var a = MapProj.pxToLatLng(tl, zoom);
  var b = MapProj.pxToLatLng(br, zoom);
  if (gcj) {
    a = Gcj.gcjToWgs(a.$1, a.$2);
    b = Gcj.gcjToWgs(b.$1, b.$2);
  }
  final latMin = math.min(a.$1, b.$1);
  final latMax = math.max(a.$1, b.$1);
  var lngMin = math.min(a.$2, b.$2);
  var lngMax = math.max(a.$2, b.$2);
  if (lngMax - lngMin >= 360) {
    lngMin = -180;
    lngMax = 180;
  } else {
    lngMin = lngMin.clamp(-180.0, 180.0).toDouble();
    lngMax = lngMax.clamp(-180.0, 180.0).toDouble();
  }
  return GeoBounds(
    south: latMin.clamp(-85.05112878, 85.05112878).toDouble(),
    west: lngMin,
    north: latMax.clamp(-85.05112878, 85.05112878).toDouble(),
    east: lngMax,
  );
}

/// 把字节数格式化成人读字符串
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(2)} GB';
}
