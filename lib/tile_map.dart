import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'theme.dart';
import 'coord.dart';

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

/// 瓦片地址（浅色、支持 CORS），优先高德中文瓦片（多子域名轮询）
const _tileHeaders = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36',
  'Referer': 'https://www.amap.com/',
};

/// 高德瓦片：按 tx+ty 哈希轮询 4 个子域名，避免单域名限流
String _gaodeUrl(int tx, int ty, int z, {int style = 7}) {
  final s = ((tx * 7 + ty * 13) % 4) + 1;
  return 'https://webrd0$s.is.autonavi.com/appmaptile'
      '?lang=zh_cn&size=1&scale=1&style=$style&x=$tx&y=$ty&z=$z';
}

// 各图源瓦片模板（全部免 API Key）
const _cartoLightUrl = 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
const _cartoDarkUrl = 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
const _cartoVoyagerUrl =
    'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
const _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _osmHotUrl =
    'https://tile-{s}.openstreetmap.fr/hot/{z}/{x}/{y}.png';
const _openTopoUrl = 'https://tile.opentopomap.org/{z}/{x}/{y}.png';
const _esriStreetUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
const _esriSatUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

/// 地图类型
enum MapType {
  gaode('高德地图', group: '高德'),
  gaode_sat('高德卫星', group: '高德'),
  vector('矢量地图', group: '其他'),
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
}

///
/// 任何情况下都有一层自绘矢量底图（环路/道路/水域），
/// 瓦片加载中/失败时透出底图，保证地图始终可看可用。
class TileMapView extends StatefulWidget {
  final double centerLat, centerLng;
  final double zoom;
  final Offset pan;
  final ValueChanged<Offset> onPan;
  final void Function(double zoom, Offset pan) onViewChanged;
  final void Function(double zoom, Offset pan) onZoomRequest;
  final void Function(Offset localPos) onTap;
  final Widget? overlay;
  final double minZoom, maxZoom;
  final MapType mapType;

  const TileMapView({
    super.key,
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    required this.pan,
    required this.onPan,
    required this.onViewChanged,
    required this.onZoomRequest,
    required this.onTap,
    this.overlay,
    this.minZoom = 3,
    this.maxZoom = 19,
    this.mapType = MapType.gaode,
  });

  @override
  State<TileMapView> createState() => _TileMapViewState();
}

class _TileMapViewState extends State<TileMapView> {
  Offset _lastFocal = Offset.zero;
  Offset? _anchorWorld; // 手势开始时手指下的世界像素点（跟手锚点）
  double _startZoom = 11.0; // 手势起始 zoom（d.scale 是累计值，必须用起始值作基准）

  /// 手指下的世界像素点
  Offset _worldAt(Offset screen, Size size) {
    final c = MapProj.latLngToPx(widget.centerLat, widget.centerLng, widget.zoom);
    final center = Offset(size.width / 2, size.height / 2);
    return (screen - center) + c - widget.pan;
  }

  void _handleScaleStart(ScaleStartDetails d, Size size) {
    _lastFocal = d.localFocalPoint;
    _startZoom = widget.zoom;
    _anchorWorld = _worldAt(d.localFocalPoint, size);
  }

  /// 缩放后让锚点保持在当前手指位置：
  ///   anchor1 = anchor0 * 2^(newZoom - startZoom)
  ///   screen = anchor1 - c1 + center + pan' = focal
  ///   pan' = focal - center + c1 - anchor1
  Offset _panToAnchor(Offset focal, double newZoom, Size size) {
    final sf = math.pow(2, newZoom - _startZoom).toDouble();
    final c1 = MapProj.latLngToPx(widget.centerLat, widget.centerLng, newZoom);
    final center = Offset(size.width / 2, size.height / 2);
    final anchor1 = (_anchorWorld ?? Offset.zero) * sf;
    return (focal - center) + c1 - anchor1;
  }

  void _handleScaleUpdate(ScaleUpdateDetails d, Size size) {
    // d.scale 是手势起始以来的累计缩放比 → 累计 zoom 增量
    final dz = math.log(d.scale) / math.ln2;
    // 缩放与平移同时处理：缩放时焦点移动也应跟手平移
    final focalDelta = d.localFocalPoint - _lastFocal;
    _lastFocal = d.localFocalPoint;
    if (dz.abs() > 0.02) {
      final newZoom = (_startZoom + dz).clamp(widget.minZoom, widget.maxZoom);
      // 缩放后的锚点，再叠加上焦点移动产生的平移
      final anchored = _panToAnchor(d.localFocalPoint, newZoom, size);
      if ((newZoom - widget.zoom).abs() > 0.005) {
        widget.onViewChanged(newZoom, anchored);
        return;
      }
    }
    // 纯平移（单指拖动 / 焦点移动）：增量累积
    if (focalDelta != Offset.zero) {
      widget.onPan(focalDelta);
    }
  }

  /// 围绕屏幕焦点缩放到 newZoom，返回对应的 pan（滚轮使用）
  Offset _panForFocus(Offset localFocus, double newZoom, Size size) {
    final sf = math.pow(2, newZoom - widget.zoom).toDouble();
    final c1 = MapProj.latLngToPx(widget.centerLat, widget.centerLng, newZoom);
    final center = Offset(size.width / 2, size.height / 2);
    final focusWorld = _worldAt(localFocus, size);
    return (localFocus - center) + c1 - focusWorld * sf;
  }

  void _handleScroll(PointerScrollEvent e, Size size) {
    // 向上滚(dy<0)→放大；向下滚(dy>0)→缩小。每格约 ±1 级
    final dZoom = (-e.scrollDelta.dy / 120).clamp(-2.0, 2.0);
    final newZoom = (widget.zoom + dZoom)
        .clamp(widget.minZoom, widget.maxZoom)
        .toDouble();
    if ((newZoom - widget.zoom).abs() < 0.001) return;
    widget.onZoomRequest(newZoom, _panForFocus(e.localPosition, newZoom, size));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final z = widget.zoom.floor().clamp(0, 19);
        final centerPx =
            MapProj.latLngToPx(widget.centerLat, widget.centerLng, widget.zoom);
        // 视口左上角世界像素 = centerPx - pan - size/2（与标记层 pan 符号一致）
        final left = centerPx.dx - widget.pan.dx - size.width / 2;
        final top = centerPx.dy - widget.pan.dy - size.height / 2;
        final scale = math.pow(2, widget.zoom - z).toDouble();
        final tilePx = 256.0 * scale;
        final tx0 = (left / tilePx).floor();
        final tx1 = ((left + size.width) / tilePx).floor();
        final ty0 = (top / tilePx).floor();
        final ty1 = ((top + size.height) / tilePx).floor();

        final tiles = <Widget>[];
        final n = 1 << z; // 本级别瓦片数量（经度循环包边）
        for (var tx = tx0; tx <= tx1; tx++) {
          for (var ty = ty0; ty <= ty1; ty++) {
            final wx = (tx % n + n) % n;
            tiles.add(Positioned(
              key: ValueKey('t$z-$tx-$ty-${widget.mapType.name}'),
              left: tx * tilePx - left,
              top: ty * tilePx - top,
              child: _Tile(
                  tx: wx, ty: ty, z: z, scale: scale,
                  mapType: widget.mapType),
            ));
          }
        }

        return Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) _handleScroll(e, size);
          },
          child: GestureDetector(
            onScaleStart: (d) => _handleScaleStart(d, size),
            onScaleUpdate: (d) => _handleScaleUpdate(d, size),
            onTapUp: (d) => widget.onTap(d.localPosition),
            // 注意：不注册 onDoubleTapDown，否则单击需等待双击判定(~300ms)延迟
            behavior: HitTestBehavior.opaque,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 自绘矢量底图（始终可见）
                  CustomPaint(
                    size: size,
                    painter: _FallbackPainter(
                      zoom: widget.zoom,
                      pan: widget.pan,
                      centerLat: widget.centerLat,
                      centerLng: widget.centerLng,
                    ),
                  ),
                  ...tiles,
                  if (widget.overlay != null) widget.overlay!,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 自绘矢量底图：保证无网络/瓦片失败时地图仍然可用
class _FallbackPainter extends CustomPainter {
  final double zoom;
  final Offset pan;
  final double centerLat, centerLng;
  _FallbackPainter({
    required this.zoom,
    required this.pan,
    required this.centerLat,
    required this.centerLng,
  });

  Offset _s(double lat, double lng) {
    final c = MapProj.latLngToPx(centerLat, centerLng, zoom);
    final p = MapProj.latLngToPx(lat, lng, zoom);
    return Offset(
      p.dx - c.dx + pan.dx,
      p.dy - c.dy + pan.dy,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 背景
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = C.mapBg);

    // 屏幕网格（始终跟随视图）
    final gp = Paint()..color = C.mapGrid..strokeWidth = 0.5;
    double sp = 60.0;
    final ox = pan.dx % sp;
    final oy = pan.dy % sp;
    for (double x = ox; x < size.width; x += sp) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);
    }
    for (double y = oy; y < size.height; y += sp) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }

    // 北京环形路（以天安门为中心）
    final ring = Gcj.wgsToGcj(39.9087, 116.3975);
    final rc = _s(ring.$1, ring.$2);
    final dLng = (_s(ring.$1, ring.$2 + 0.01).dx - rc.dx) / 0.01;
    final dLat = (_s(ring.$1 + 0.01, ring.$2).dy - rc.dy) / 0.01;
    final road = Paint()
      ..color = C.mapGridStrong.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final roadLight = Paint()
      ..color = C.mapGrid.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const rings = [0.030, 0.055, 0.085, 0.115];
    for (final r in rings) {
      canvas.drawOval(
        Rect.fromCenter(
          center: rc,
          width: 2 * r * dLng,
          height: 2 * r * dLat,
        ),
        r == rings.first ? roadLight : road,
      );
    }

    // 主干道
    void roadLine(double lat1, double lng1, double lat2, double lng2,
        {bool major = false}) {
      final p1 = _s(lat1, lng1);
      final p2 = _s(lat2, lng2);
      canvas.drawLine(p1, p2, major ? road : roadLight);
    }

    final a = Gcj.wgsToGcj(39.9075, 116.30);
    final b = Gcj.wgsToGcj(39.9075, 116.50);
    final c = Gcj.wgsToGcj(39.85, 116.3975);
    final d = Gcj.wgsToGcj(39.95, 116.3975);
    roadLine(a.$1, a.$2, b.$1, b.$2, major: true); // 长安街
    roadLine(c.$1, c.$2, d.$1, d.$2, major: true); // 中轴线

    // 次要道路（东西/南北各几条）
    for (final lat in [39.88, 39.92, 39.94]) {
      final p1 = Gcj.wgsToGcj(lat, 116.32);
      final p2 = Gcj.wgsToGcj(lat, 116.48);
      roadLine(p1.$1, p1.$2, p2.$1, p2.$2);
    }
    for (final lng in [116.35, 116.42, 116.45]) {
      final p1 = Gcj.wgsToGcj(39.86, lng);
      final p2 = Gcj.wgsToGcj(39.95, lng);
      roadLine(p1.$1, p1.$2, p2.$1, p2.$2);
    }

    // 水域
    final water = Paint()..color = C.water;
    final lake = Gcj.wgsToGcj(39.999, 116.266);
    final lp = _s(lake.$1, lake.$2);
    canvas.drawOval(
        Rect.fromCenter(center: lp, width: 0.02 * dLng, height: 0.012 * dLat),
        water);
    final river = Gcj.wgsToGcj(39.90, 116.44);
    final rp = _s(river.$1, river.$2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: rp, width: 0.03 * dLng, height: 0.008 * dLat),
        const Radius.circular(6),
      ),
      water,
    );

    // 标签
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void label(String text, double lat, double lng, {double size = 10}) {
      final p = _s(lat, lng);
      tp.text = TextSpan(
        text: text,
        style: ts(size, c: C.slate.withValues(alpha: 0.7), w: FontWeight.w600),
      );
      tp.layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    label('北京城区', 39.9087, 116.3975, size: 13);
    label('海淀', 39.96, 116.30);
    label('朝阳', 39.92, 116.44);
    label('西城', 39.91, 116.37);
    label('东城', 39.91, 116.41);
  }

  @override
  bool shouldRepaint(covariant _FallbackPainter old) =>
      old.zoom != zoom || old.pan != pan;
}

class _Tile extends StatelessWidget {
  final int tx, ty, z;
  final double scale;
  final MapType mapType;
  const _Tile({
    required this.tx,
    required this.ty,
    required this.z,
    required this.scale,
    this.mapType = MapType.gaode,
  });

  /// 替换 {z}/{x}/{y}/{s}，{s} 为子域名轮询（a/b/c）
  String _fmt(String tpl) {
    final s = ['a', 'b', 'c'][(tx + ty) % 3];
    return tpl
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$tx')
        .replaceAll('{y}', '$ty')
        .replaceAll('{s}', s);
  }

  /// 当前图源 URL（矢量地图不在此渲染，返回空串）
  String _url(MapType t) {
    switch (t) {
      case MapType.gaode:
        return _gaodeUrl(tx, ty, z, style: 7);
      case MapType.gaode_sat:
        return _gaodeUrl(tx, ty, z, style: 6);
      case MapType.carto:
        return _fmt(_cartoLightUrl);
      case MapType.carto_dark:
        return _fmt(_cartoDarkUrl);
      case MapType.carto_voyager:
        return _fmt(_cartoVoyagerUrl);
      case MapType.osm:
        return _fmt(_osmUrl);
      case MapType.osm_hot:
        return _fmt(_osmHotUrl);
      case MapType.open_topo:
        return _fmt(_openTopoUrl);
      case MapType.esri_street:
        return _fmt(_esriStreetUrl);
      case MapType.esri_sat:
        return _fmt(_esriSatUrl);
      case MapType.vector:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) => _try(0);

  Widget _try(int idx) {
    final size = 256.0 * scale;
    // 候选链：当前图源 → Carto 浅色 → OSM → 空白（逐级降级）
    final candidates = <MapType>[
      mapType,
      if (mapType != MapType.carto) MapType.carto,
      if (mapType != MapType.osm) MapType.osm,
    ];
    if (idx >= candidates.length) return const SizedBox.shrink();
    final url = _url(candidates[idx]);
    // 无 URL（如矢量地图）时继续降级到下一候选
    if (url.isEmpty) return _try(idx + 1);
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.fill,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      headers: _tileHeaders,
      errorBuilder: (_, _, _) => _try(idx + 1),
    );
  }
}
