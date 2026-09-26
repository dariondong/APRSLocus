import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'theme.dart';
import 'coord.dart';
import 'map_math.dart';
import 'tile_cache.dart';
import 'net/http_send.dart';

// 地图数学（MapProj / GeoBounds / 瓦片编号）、图源枚举与瓦片 URL 已移到
// map_math.dart —— 离线下载引擎要用同一份，不能再留在 Widget 文件里。
// 这里 re-export，既有 `import 'tile_map.dart'` 的调用方无需改动。
export 'map_math.dart';

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

  /// 是否把在线瓦片写入磁盘缓存（用户可在设置里关掉）
  final bool cacheEnabled;

  /// 仅离线模式：只用缓存/已下载瓦片，不发网络请求
  final bool offlineOnly;

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
    this.cacheEnabled = true,
    this.offlineOnly = false,
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
    final proj = projectionFor(widget.mapType);
    final c = proj.latLngToPx(widget.centerLat, widget.centerLng, widget.zoom);
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
    final proj = projectionFor(widget.mapType);
    final c1 = proj.latLngToPx(widget.centerLat, widget.centerLng, newZoom);
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
    final proj = projectionFor(widget.mapType);
    final c1 = proj.latLngToPx(widget.centerLat, widget.centerLng, newZoom);
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
        final proj = projectionFor(widget.mapType);
        final centerPx =
            proj.latLngToPx(widget.centerLat, widget.centerLng, widget.zoom);
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
        // 百度瓦片的列号已是「平移后」的连续编号、且不跨 ±180 环绕，
        // 不能再按 2^z 取模（会把有效列折回去取到另一张瓦片）。
        final wrap = !isBaiduMapType(widget.mapType);
        for (var tx = tx0; tx <= tx1; tx++) {
          for (var ty = ty0; ty <= ty1; ty++) {
            final wx = wrap ? ((tx % n + n) % n) : tx;
            tiles.add(Positioned(
              key: ValueKey('t$z-$tx-$ty-${widget.mapType.name}'),
              left: tx * tilePx - left,
              top: ty * tilePx - top,
              child: _Tile(
                  tx: wx, ty: ty, z: z, scale: scale,
                  mapType: widget.mapType,
                  cacheEnabled: widget.cacheEnabled,
                  offlineOnly: widget.offlineOnly),
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
                      proj: proj,
                      // 高德/腾讯为 GCJ-02；百度由 proj 内部转 BD-09；国际图源 WGS-84
                      gcj: isGcjMapType(widget.mapType),
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
  /// 底图坐标系：高德/腾讯 GCJ-02 → 元素坐标做 WGS→GCJ；
  /// 百度 → 由 [proj]（BaiduProjection）内部转 BD-09；国际 WGS 底图 → 原样
  final bool gcj;
  /// 渲染投影（百度不是 Web Mercator）
  final MapProjection proj;
  _FallbackPainter({
    required this.zoom,
    required this.pan,
    required this.centerLat,
    required this.centerLng,
    this.gcj = true,
    this.proj = const WebMercatorProjection(),
  });

  /// 把 WGS-84 元素坐标映射到底图坐标系
  (double, double) _tc(double lat, double lng) =>
      gcj ? Gcj.wgsToGcj(lat, lng) : (lat, lng);

  Offset _s(double lat, double lng) {
    final c = proj.latLngToPx(centerLat, centerLng, zoom);
    final p = proj.latLngToPx(lat, lng, zoom);
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
    final ring = _tc(39.9087, 116.3975);
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

    final a = _tc(39.9075, 116.30);
    final b = _tc(39.9075, 116.50);
    final c = _tc(39.85, 116.3975);
    final d = _tc(39.95, 116.3975);
    roadLine(a.$1, a.$2, b.$1, b.$2, major: true); // 长安街
    roadLine(c.$1, c.$2, d.$1, d.$2, major: true); // 中轴线

    // 次要道路（东西/南北各几条）
    for (final lat in [39.88, 39.92, 39.94]) {
      final p1 = _tc(lat, 116.32);
      final p2 = _tc(lat, 116.48);
      roadLine(p1.$1, p1.$2, p2.$1, p2.$2);
    }
    for (final lng in [116.35, 116.42, 116.45]) {
      final p1 = _tc(39.86, lng);
      final p2 = _tc(39.95, lng);
      roadLine(p1.$1, p1.$2, p2.$1, p2.$2);
    }

    // 水域
    final water = Paint()..color = C.water;
    final lake = _tc(39.999, 116.266);
    final lp = _s(lake.$1, lake.$2);
    canvas.drawOval(
        Rect.fromCenter(center: lp, width: 0.02 * dLng, height: 0.012 * dLat),
        water);
    final river = _tc(39.90, 116.44);
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
      final t = _tc(lat, lng);
      final p = _s(t.$1, t.$2);
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

/// 单张瓦片：缓存 → 在线 → 祖先瓦片放大 → 占位。
///
/// 四级降级不是列着好看的，每种都对应真实场景：
///   1. **缓存**：下过离线区域、或之前浏览过 → 断网也能看；
///   2. **在线**：正常情况（顺带写缓存）；
///   3. **祖先瓦片放大**：只下到 z16、现场缩到 z17 时，整屏不该变白 ——
///      这是离线地图「下载到 16 级」这个常见选择能不能用的关键；
///   4. **占位**：连缓存都没有的新设备/图源 → 透出自绘矢量底图，地图仍可看可点。
class _Tile extends StatefulWidget {
  final int tx, ty, z;
  final double scale;
  final MapType mapType;

  /// 是否把在线瓦片写入磁盘缓存
  final bool cacheEnabled;

  /// 仅离线模式：完全不发网络请求（野外省流量）
  final bool offlineOnly;

  const _Tile({
    required this.tx,
    required this.ty,
    required this.z,
    required this.scale,
    this.mapType = MapType.gaode,
    this.cacheEnabled = true,
    this.offlineOnly = false,
  });

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  /// 已解析到的像素。null = 还没解析出来 / 最终没有可用的图
  Uint8List? _bytes;

  /// 0 = 本瓦片的原图；n>0 = 用向上 n 级的祖先瓦片放大顶替
  int _upSteps = 0;

  /// 顶替时本瓦片在祖先图内的象限位置（每格 = 1 个本瓦片边长）
  (int, int) _quad = (0, 0);

  /// 本次是否已尝试落盘：同一张瓦片被多次重建时不重复写
  bool _triedWrite = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _Tile old) {
    super.didUpdateWidget(old);
    if (old.mapType != widget.mapType ||
        old.offlineOnly != widget.offlineOnly ||
        old.cacheEnabled != widget.cacheEnabled ||
        old.z != widget.z ||
        old.tx != widget.tx ||
        old.ty != widget.ty) {
      _bytes = null;
      _upSteps = 0;
      _triedWrite = false;
      _resolve();
    }
    // 只有 scale 变化（捏合/滚轮缩放）时**不重新解析**：图还是同一张，
    // 只是要按新的像素边长画。几何一律在 build() 里按当前 _px 现算 ——
    // 若把「算好尺寸的 Widget」存起来，缩放动画中瓦片会停在旧尺寸上，
    // 祖先放大那一路还会因裁切偏移仍按旧边长算而错位（离线缩放时最明显）。
  }

  bool _sameDatum(MapType other) => sameDatum(widget.mapType, other);

  /// 在线候选链：当前图源 → Carto 浅色 → OSM（逐级降级，与旧版一致，
  /// 但只接受**同坐标系**的候选 —— 拿 WGS-84 的图源去填 GCJ-02 的瓦片
  /// 会整整偏出 500 米，比留白更容易把人带错路）。
  List<MapType> get _onlineCandidates => <MapType>[
        widget.mapType,
        if (widget.mapType != MapType.carto &&
            _sameDatum(MapType.carto) &&
            MapType.carto.canDownloadOffline)
          MapType.carto,
        if (widget.mapType != MapType.osm &&
            _sameDatum(MapType.osm) &&
            MapType.osm.canDownloadOffline)
          MapType.osm,
      ];

  double get _px => 256.0 * widget.scale;

  /// 记录解析结果。几何不在这里算 —— 见 [build] 与 [didUpdateWidget]。
  void _setBytes(Uint8List? b, {int upSteps = 0, (int, int) quad = (0, 0)}) {
    if (!mounted) return;
    setState(() {
      _bytes = b;
      _upSteps = b == null ? 0 : upSteps;
      _quad = quad;
    });
  }

  /// 按**当前**缩放比现算尺寸的图像
  Widget _tileImage() {
    final px = _px;
    final provider =
        ResizeImage(MemoryImage(_bytes!), width: 256, allowUpscaling: true);
    if (_upSteps == 0) {
      return Image(
        image: provider,
        width: px,
        height: px,
        fit: BoxFit.fill,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    }
    // 祖先图有 f×f 个本瓦片那么大，只露出本瓦片所在的那一格
    final f = 1 << _upSteps;
    return ClipRect(
      child: OverflowBox(
        maxWidth: px * f,
        maxHeight: px * f,
        alignment: Alignment.topLeft,
        child: Transform.translate(
          offset: Offset(-_quad.$1 * px, -_quad.$2 * px),
          child: Image(
            image: provider,
            width: px * f,
            height: px * f,
            fit: BoxFit.fill,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }

  Future<void> _resolve() async {
    final src = widget.mapType.name;

    // 1) 本图源缓存
    if (TileCache.available) {
      final hit = await TileCache.get(src, widget.z, widget.tx, widget.ty);
      if (hit != null) return _setBytes(hit);
    }

    // 2) 在线
    if (!widget.offlineOnly) {
      for (final t in _onlineCandidates) {
        final url = tileUrl(t, widget.tx, widget.ty, widget.z);
        if (url.isEmpty) continue;
        try {
          final bytes = await httpGetBytes(
            Uri.parse(url),
            headers: tileHeaders,
            timeout: const Duration(seconds: 15),
          );
          if (!looksLikeImage(bytes)) continue;
          if (widget.cacheEnabled && !_triedWrite) {
            _triedWrite = true;
            // 落盘不阻塞显示：写盘失败（无权限/满盘）不该让瓦片显示不出来
            unawaited(
                TileCache.put(t.name, widget.z, widget.tx, widget.ty, bytes));
          }
          return _setBytes(bytes);
        } catch (_) {
          // 换下一个候选
        }
      }
    }

    // 3) 祖先瓦片放大（离线可用的关键兜底）
    final up = await _upscaleFromAncestor();
    if (up != null) {
      return _setBytes(up.bytes, upSteps: up.upSteps, quad: up.quad);
    }

    // 4) 其它同坐标系图源的缓存（之前用别的图源浏览过这块区域）
    if (TileCache.available) {
      for (final t in MapType.values) {
        if (t == widget.mapType || !_sameDatum(t)) continue;
        final hit = await TileCache.get(t.name, widget.z, widget.tx, widget.ty);
        if (hit != null) return _setBytes(hit);
      }
    }

    // 5) 放弃：透出自绘底图
    _setBytes(null);
  }

  /// 取最近的（最多向上 4 级）祖先瓦片，按象限裁切放大顶替本瓦片。
  ///
  /// 裁切是必须的：直接把整张祖先图铺进本格，会看到**邻居**的地图 ——
  /// 位置全错，比空白更糟。这里用 OverflowBox + ClipRect 做「放大后平移再裁」，
  /// 不引入自定义 ImageProvider，也让 Flutter 的 ImageCache 照常去重解码。
  /// 只返回**数据**（字节 + 向上几级 + 象限），不返回 Widget：
  /// 尺寸必须留到 build 时按当前缩放比现算，理由见 [didUpdateWidget]。
  Future<({Uint8List bytes, int upSteps, (int, int) quad})?>
      _upscaleFromAncestor() async {
    if (!TileCache.available) return null;
    final me = TileId(widget.z, widget.tx, widget.ty);
    var cur = me.parent;
    for (var steps = 1; steps <= 4 && cur != null; steps++) {
      final hit =
          await TileCache.get(widget.mapType.name, cur.z, cur.x, cur.y);
      if (hit != null) {
        return (bytes: hit, upSteps: steps, quad: me.quadIn(cur));
      }
      cur = cur.parent;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // 尺寸始终占住（避免 Stack 布局抖动）；几何按当前缩放比现算
    return SizedBox(
      width: _px,
      height: _px,
      child: _bytes == null ? const SizedBox.shrink() : _tileImage(),
    );
  }
}
