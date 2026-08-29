import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'theme.dart';
import 'models.dart';
import 'state.dart';
import 'widgets.dart';
import 'station_detail.dart';
import 'tile_map.dart';
import 'vector_map.dart';
import 'amap_js_map.dart';
import 'coord.dart';

class MapPage extends StatefulWidget {
  final AppState state;
  final String searchQuery;
  const MapPage({super.key, required this.state, this.searchQuery = ''});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage>
    with TickerProviderStateMixin {
  // 视图状态：连续 zoom + 像素偏移
  double _zoom = 11.0;
  Offset _pan = Offset.zero;
  bool _showTracks = true;
  Size _lastSize = Size.zero;

  MapType get _currentMapType => MapType.values.firstWhere(
      (t) => t.name == widget.state.mapType,
      orElse: () => MapType.gaode);

  /// 是否使用矢量地图模式（flutter_map）
  bool get _isVector => _currentMapType == MapType.vector;

  /// 是否使用高德 JS 地图（WebView）。
  /// Windows 的 WebView2 鼠标坐标异常（始终左上角），回退到稳定的瓦片地图。
  bool get _isAmapJs =>
      !_isWindowsDesktop &&
      _currentMapType == MapType.amap_js;

  bool get _isWindowsDesktop =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// 插件地图（自绘标记不可用的模式）
  bool get _usePluginMap => _isVector || _isAmapJs;

  Station? _selected;
  final ValueNotifier<Offset?> _hover = ValueNotifier(null);

  // 脉冲动画（移动/选中标记）
  late final AnimationController _pulse;
  // 平滑定位动画
  AnimationController? _viewAnim;
  double _fromZoom = 11.0;
  Offset _fromPan = Offset.zero;
  double _toZoom = 11.0;
  Offset _toPan = Offset.zero;

  // 视图初始化 / 焦点跟踪 / 选点
  bool _didInitView = false;
  String? _lastFocusedCall;
  int _lastFocusSeq = -1;
  int _lastPickSeq = -1;
  bool _pickMode = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  /// 脉冲动画按需启停：没有移动/选中台站时停转，省掉每帧重建开销
  void _syncPulse() {
    final need = _visible.any((s) =>
        s.status == St.moving || (_selected?.call == s.call));
    if (need && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!need && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _cancelAnim();
    _pulse.dispose();
    _hover.dispose();
    super.dispose();
  }

  // 基准（WGS-84 北京）+ GCJ-02 转换后的投影基准
  static const _baseLat = 39.9042;
  static const _baseLng = 116.4074;
  static final (double, double) _gcjBase = Gcj.wgsToGcj(_baseLat, _baseLng);

  // ─── 投影（统一在 GCJ-02 坐标系，与高德瓦片对齐） ───
  // GCJ 转换缓存：手势每帧对每个台站做三角函数转换很贵，缓存坐标结果
  final Map<String, (double, double)> _gcjCache = {};

  (double, double) _gcj(double lat, double lng) {
    final key = '${lat.toStringAsFixed(6)}|${lng.toStringAsFixed(6)}';
    final v = _gcjCache[key];
    if (v != null) return v;
    if (_gcjCache.length > 3000) _gcjCache.clear();
    final r = Gcj.wgsToGcj(lat, lng);
    _gcjCache[key] = r;
    return r;
  }

  Offset _toScreen(double lat, double lng, Size size) {
    final g = _gcj(lat, lng);
    final c = MapProj.latLngToPx(_gcjBase.$1, _gcjBase.$2, _zoom);
    final p = MapProj.latLngToPx(g.$1, g.$2, _zoom);
    return Offset(
      p.dx - c.dx + size.width / 2 + _pan.dx,
      p.dy - c.dy + size.height / 2 + _pan.dy,
    );
  }

  (double, double) _screenToLatLng(Offset screen, Size size) {
    final c = MapProj.latLngToPx(_gcjBase.$1, _gcjBase.$2, _zoom);
    final p = Offset(
      screen.dx + c.dx - size.width / 2 - _pan.dx,
      screen.dy + c.dy - size.height / 2 - _pan.dy,
    );
    final g = MapProj.pxToLatLng(p, _zoom);
    // 高德坐标(GCJ)直接显示；标准 WGS-84 需反解
    if (widget.state.coordDatum == 'gcj') return g;
    return Gcj.gcjToWgs(g.$1, g.$2);
  }

  /// 让某点居中的 pan：screen = p - c + size/2 + pan = size/2 → pan = c - p
  Offset _panFor(double lat, double lng, double zoom) {
    final g = Gcj.wgsToGcj(lat, lng);
    final c = MapProj.latLngToPx(_gcjBase.$1, _gcjBase.$2, zoom);
    final p = MapProj.latLngToPx(g.$1, g.$2, zoom);
    return c - p;
  }

  String get _scaleText {
    const pxLen = 120.0;
    final n = 256 * math.pow(2, _zoom);
    final dLng = pxLen / n * 360;
    final km = dLng * 111.32 * math.cos(_baseLat * math.pi / 180);
    if (km >= 100) return '${(km / 1000).toStringAsFixed(1)} km';
    if (km >= 1) return '${km.toStringAsFixed(0)} km';
    return '${(km * 1000).toStringAsFixed(0)} m';
  }

  // ─── 视图控制 ───

  /// 取消并安全释放视图动画
  void _cancelAnim() {
    final a = _viewAnim;
    if (a == null) return;
    _viewAnim = null;
    try {
      if (a.isAnimating) a.stop();
      a.dispose();
    } catch (_) {}
  }

  /// 平滑定位到某坐标并缩放到指定级别
  /// 中心世界点插值：zoom 是指数缩放，pan 线性插值会导致中心漂移晃动，
  /// 改为插值"中心对应的世界像素点"，每帧按当前 zoom 反算 pan，中心平滑稳定
  void _animateTo(double zoom, Offset pan) {
    _cancelAnim();
    _fromZoom = _zoom;
    _fromPan = _pan;
    _toZoom = zoom;
    _toPan = pan;
    // 起止中心对应的世界像素（以起始 zoom 为参考系）
    final ref = _fromZoom;
    final c1 = MapProj.latLngToPx(_gcjBase.$1, _gcjBase.$2, _fromZoom);
    final c2 = MapProj.latLngToPx(_gcjBase.$1, _gcjBase.$2, _toZoom);
    final wc1 = (c1 - _fromPan) * math.pow(2, ref - _fromZoom).toDouble();
    final wc2 = (c2 - _toPan) * math.pow(2, ref - _toZoom).toDouble();

    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    ctrl.addListener(() {
      final t = Curves.easeOutCubic.transform(ctrl.value);
      final z = _fromZoom + (_toZoom - _fromZoom) * t;
      final wc = Offset.lerp(wc1, wc2, t)!;
      final c = MapProj.latLngToPx(_gcjBase.$1, _gcjBase.$2, z);
      setState(() {
        _zoom = z;
        _pan = c - wc * math.pow(2, z - ref).toDouble();
      });
    });
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && _viewAnim == ctrl) {
        _viewAnim = null;
        try {
          ctrl.dispose();
        } catch (_) {}
      }
    });
    _viewAnim = ctrl;
    ctrl.forward();
  }

  void _animateToStation(Station s, {double? zoom}) {
    _animateTo(zoom ?? math.max(_zoom, 14.0), _panFor(s.lat, s.lng, zoom ?? math.max(_zoom, 14.0)));
  }

  void _setView(double zoom, Offset pan) {
    _cancelAnim();
    setState(() {
      _zoom = zoom;
      _pan = pan;
    });
  }

  /// 增量平移（同帧多次事件也能精确累积，不丢帧）
  void _panDelta(Offset delta) {
    _cancelAnim();
    setState(() => _pan += delta);
  }

  /// 围绕屏幕中心缩放到 newZoom（保持中心地理点不变）
  Offset _panForCenter(double newZoom) {
    final sf = math.pow(2, newZoom - _zoom).toDouble();
    return _pan * sf;
  }

  /// 精确墨卡托 y 归一化值 [0,1]
  double _mercY(double lat) {
    final s = math.sin(lat * math.pi / 180);
    return (1 - math.log((1 + s) / (1 - s)) / (2 * math.pi)) / 2;
  }

  /// 自适应：缩放到覆盖所有可见台站（精确墨卡托 + 标记边距）
  void _fitAll() {
    final vis = _visible;
    if (vis.isEmpty) return;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final s in vis) {
      if (s.lat < minLat) minLat = s.lat;
      if (s.lat > maxLat) maxLat = s.lat;
      if (s.lng < minLng) minLng = s.lng;
      if (s.lng > maxLng) maxLng = s.lng;
    }
    final size = _lastSize;
    final w = size.width > 100 ? size.width : 1000;
    final h = size.height > 100 ? size.height : 700;
    // 留出标记(~28px)与边距
    final availW = w - 72.0;
    final availH = h - 72.0;
    final spanLng = math.max(maxLng - minLng, 0.002);
    final spanY = math.max((_mercY(maxLat) - _mercY(minLat)).abs(), 1e-6);
    // world_px = 256 * 2^z；x 跨度 = world*(spanLng/360)
    // zX = log2(availW * 360 / (spanLng * 256))
    final zX = math.log(availW * 360 / (spanLng * 256)) / math.ln2;
    final zY = math.log(availH / (spanY * 256)) / math.ln2;
    final z = (zX < zY ? zX : zY).clamp(8.0, 16.0);
    final cLat = (minLat + maxLat) / 2;
    final cLng = (minLng + maxLng) / 2;
    _animateTo(z, _panFor(cLat, cLng, z));
  }

  // 图层筛选：隐藏的类型
  final Set<TypeGroup> _hiddenTypes = {};

  List<Station> get _visible {
    final q = widget.searchQuery.trim().toLowerCase();
    var list = widget.state.stations;
    // 国家/地区接收筛选：始终按 stationAllowedFor 过滤（传对象避免线性查找）
    list = list.where(widget.state.stationAllowedFor).toList();
    if (q.isNotEmpty) {
      list = list
          .where((s) =>
              s.call.toLowerCase().contains(q) ||
              s.typeName.contains(q) ||
              s.alias.contains(q))
          .toList();
    }
    if (_hiddenTypes.isNotEmpty) {
      list = list.where((s) => !_hiddenTypes.contains(s.typeGroup)).toList();
    }
    return list;
  }

  // ─── 构建 ───
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        // 处理视图初始化 + 焦点跳转（一次性，避免互相覆盖）
        _handleViewFocus();
        // 进入地图选点模式 —— 用 postFrameCallback 避免 build 中 setState
        if (widget.state.pickSeq != _lastPickSeq) {
          _lastPickSeq = widget.state.pickSeq;
          final newPick = widget.state.pickMode;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pickMode != newPick) setState(() => _pickMode = newPick);
          });
        }
        return LayoutBuilder(
          builder: (ctx, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            _lastSize = size;
            final vis = _visible;
            final searched = widget.searchQuery.trim().isNotEmpty;
            _syncPulse();

          return Stack(children: [
            // 瓦片地图（RepaintBoundary 隔离重绘）
            RepaintBoundary(
              child: MouseRegion(
                onHover: (e) => _hover.value = e.localPosition,
                onExit: (_) => _hover.value = null,
                child: _isVector
                    ? VectorMapView(
                        stations: _visible,
                        myCall: widget.state.myFullCall,
                        myHasFix: widget.state.myHasFix,
                        myLat: widget.state.myLat,
                        myLng: widget.state.myLng,
                        focusSeq: widget.state.mapFocusSeq,
                        focusLat: widget.state.mapFocus?.lat,
                        focusLng: widget.state.mapFocus?.lng,
                        actionSeq: _mapActionSeq,
                        action: _mapAction,
                        showTracks: _showTracks,
                        onTap: _handleMapLatLng,
                        onStationTap: (s) {
                          _openDetail(s);
                          _selected = s;
                          _syncPulse();
                        },
                      )
                    : _isAmapJs
                        ? AmapJsMapView(
                            stations: _visible,
                            myCall: widget.state.myFullCall,
                            myHasFix: widget.state.myHasFix,
                            myLat: widget.state.myLat,
                            myLng: widget.state.myLng,
                            focusSeq: widget.state.mapFocusSeq,
                            focusLat: widget.state.mapFocus?.lat,
                            focusLng: widget.state.mapFocus?.lng,
                            actionSeq: _mapActionSeq,
                            action: _mapAction,
                            showTracks: _showTracks,
                            onTap: _handleMapLatLng,
                            onMyLocationTap: _showMyPanel,
                            onStationTap: (s) {
                              _openDetail(s);
                              _selected = s;
                              _syncPulse();
                            },
                          )
                        : TileMapView(
                            centerLat: _gcjBase.$1,
                            centerLng: _gcjBase.$2,
                            zoom: _zoom,
                            pan: _pan,
                            onPan: _panDelta,
                            onViewChanged: _setView,
                            // 滚轮：瞬时围绕焦点缩放，跟手不飘
                            onZoomRequest: (z, p) => _animateTo(z, p),
                            onTap: _handleMapTap,
                            // Windows 上高德 JS 回退为高德矢量瓦片
                            mapType: (_currentMapType == MapType.amap_js && _isWindowsDesktop)
                                ? MapType.gaode
                                : _currentMapType,
                          ),
              ),
            ),
            // 轨迹线（不挡手势）
            if (!_usePluginMap &&
                _selected != null &&
                _selected!.track.length > 1)
              IgnorePointer(
                child: CustomPaint(
                  size: size,
                  painter: _TrackOverlayPainter(
                    points: _selected!.track,
                    color: _selected!.color,
                    toScreen: (lat, lng) => _toScreen(lat, lng, size),
                  ),
                ),
              ),
            // 我的位置标记（点击弹信息面板）
            if (!_usePluginMap && widget.state.myHasFix) _myMarker(size),
            // 台站标记（直接在 Stack 中，每个标记独立 Positioned，不阻断手势）
            if (!_usePluginMap) ..._stationMarkers(size),
              // 信息
              Positioned(top: 14, left: 14, child: _infoChip(vis, searched)),
              // 选点提示
              if (_pickMode)
                Positioned(
                  top: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: C.orange,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: softShadow(blur: 14, alpha: 0.25),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.gps_fixed_rounded,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(S.of(context).mapPickDesc,
                            style: ts(12,
                                c: Colors.white, w: FontWeight.w700)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            widget.state.finishPick();
                            setState(() => _pickMode = false);
                          },
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ]),
                    ),
                  ),
                ),
              // 图例
              Positioned(top: 14, right: 60, child: _legend()),
              // 图层筛选按钮（覆盖在右上角）
              Positioned(
                right: 14,
                top: 14,
                child: GestureDetector(
                  onTap: () => _showLayerMenu(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _hiddenTypes.isNotEmpty ? C.blueBg : C.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: softShadow(blur: 12, y: 3, alpha: 0.08),
                      border: Border.all(
                          color: _hiddenTypes.isNotEmpty ? C.blue : C.border),
                    ),
                    child: Icon(Icons.layers_rounded,
                        size: 20,
                        color: _hiddenTypes.isNotEmpty ? C.blue : C.slate),
                  ),
                ),
              ),
              // 地图类型切换按钮
              Positioned(
                right: 14,
                top: 58,
                child: GestureDetector(
                  onTap: _showMapTypeMenu,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: C.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: softShadow(blur: 12, y: 3, alpha: 0.08),
                      border: Border.all(color: C.border),
                    ),
                    child: Icon(Icons.map_rounded, size: 20, color: C.slate),
                  ),
                ),
              ),
              // 缩放（位于地图按钮下方）
              Positioned(right: 14, top: 102, child: _zoomCtrl()),
              // 底部控制（安全区白条 + 14px）
              Positioned(
                left: 14,
                right: 14,
                bottom: 14 + MediaQuery.of(context).padding.bottom,
                child: ValueListenableBuilder<Offset?>(
                  valueListenable: _hover,
                  builder: (_, hp, _) => _bottomControls(hp),
                ),
              ),
              // 搜索提示
              if (searched)
                Positioned(
                  top: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: C.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: softShadow(),
                      ),
                      child: Text(
                        S.of(context).foundStations(vis.length, widget.searchQuery.trim()),
                        style: ts(12, w: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              // 视野内无台站提示
              if (vis.isNotEmpty && !_hasVisibleStation(size))
                Positioned(
                  bottom: 70,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _fitAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: C.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: softShadow(blur: 14, alpha: 0.15),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.search_off_rounded,
                              size: 15, color: C.cyan),
                          SizedBox(width: 6),
                          Text(S.of(context).noStationInView,
                              style: ts(11, c: C.cyan, w: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]);
          },
        );
      },
    );
  }

  /// 视图初始化/焦点跳转，一次性执行，保证互不覆盖
  void _handleViewFocus() {
    final focus = widget.state.mapFocus;
    if (focus != null && widget.state.mapFocusSeq != _lastFocusSeq) {
      _lastFocusSeq = widget.state.mapFocusSeq;
      _lastFocusedCall = focus.call;
      _didInitView = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selected = focus);
        _animateTo(14.0, _panFor(focus.lat, focus.lng, 14.0));
      });
      return;
    }
    if (!_didInitView) {
      _didInitView = true;
      if (widget.state.myHasFix) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _animateTo(13.0,
              _panFor(widget.state.myLat!, widget.state.myLng!, 13.0));
        });
      }
    }
  }

  // ─── 标记 ───
  // 标记列表缓存：视图(缩放/平移/选中)变化立即重建以跟手；
  // 纯尺寸变化(键盘展开动画/收包洪峰)节流到 ~400ms，避免每帧重建全部标记
  List<Widget>? _markerCache;
  DateTime _markerCacheTime = DateTime.fromMillisecondsSinceEpoch(0);
  Size? _markerCacheSize;
  int _markerViewHash = 0;
  String? _markerSelHash;

  List<Widget> _stationMarkers(Size size) {
    final now = DateTime.now();
    final viewHash =
        (_zoom * 64).round() * 1000003 + _pan.dx.round() * 1009 + _pan.dy.round();
    final selHash = _selected?.call ?? '';
    // 视图(拖动/缩放/选中)变化 → 立即重建，保证跟手；
    // 尺寸变化(键盘动画) → 150ms 节流；
    // 视图与尺寸都没变(收包洪峰) → 400ms 节流
    final viewChanged = viewHash != _markerViewHash || selHash != _markerSelHash;
    final sizeChanged = _markerCacheSize != size;
    final elapsed = now.difference(_markerCacheTime).inMilliseconds;
    final fresh = _markerCache != null &&
        !viewChanged &&
        (sizeChanged ? elapsed < 150 : elapsed < 400);
    if (fresh) return _markerCache!;
    _markerCacheTime = now;
    _markerCacheSize = size;
    _markerViewHash = viewHash;
    _markerSelHash = selHash;
    _markerCache = _buildMarkers(size);
    return _markerCache!;
  }

  List<Widget> _buildMarkers(Size size) {
    return _visible.map((s) {
      final pos = _toScreen(s.lat, s.lng, size);
      if (pos.dx < -50 ||
          pos.dx > size.width + 50 ||
          pos.dy < -50 ||
          pos.dy > size.height + 50) {
        return const SizedBox.shrink();
      }
      final sel = _selected?.call == s.call;
      final pulsing = s.status == St.moving || sel;
      final dx = pos.dx - 28;
      final dy = pos.dy - 28;
      return Positioned(
        left: dx,
        top: dy,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _selected = s),
          onDoubleTap: () => _openDetail(s),
          onTap: () => _animateToStation(s),
          behavior: HitTestBehavior.opaque,
          child: RepaintBoundary(
            child: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 脉冲扩散圈：只在移动/选中时动画，且只重建这一层
                  if (pulsing)
                    _PulseRing(color: s.color, sel: sel, anim: _pulse),
                  Container(
                    width: sel ? 30 : 22,
                    height: sel ? 30 : 22,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: s.color.withValues(alpha: 0.4),
                          blurRadius: sel ? 14 : 6,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(s.icon,
                          color: Colors.white, size: sel ? 14 : 11),
                    ),
                  ),
                  if (sel)
                    Positioned(
                      top: 34,
                      left: 0,
                      child: GestureDetector(
                        onTap: () => _openDetail(s),
                        child: _infoWindow(s),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _infoWindow(Station s) {
    final st = statusLabel(s.status);
    final info = StringBuffer(s.call)
      ..write('  ·  $st');
    if (s.speed != null) info.write('  ·  ${s.speedStr}');
    final my = widget.state.myStation;
    if (my != null) {
      info.write('  ·  ${s.distKm(my.lat, my.lng).toStringAsFixed(1)}km');
    }
    info.write('  · ${S.of(context).tapToView}');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: softShadow(blur: 10, alpha: 0.15),
      ),
      child: Text(info.toString(),
          style: ts(11, c: s.color, w: FontWeight.w700)),
    );
  }

  Widget _myMarker(Size size) {
    final pos = _toScreen(widget.state.myLat!, widget.state.myLng!, size);
    // 固定命中层（不随动画重建，确保点击稳定）
    return Positioned(
      left: pos.dx - 40,
      top: pos.dy - 40,
      child: GestureDetector(
        onTap: _showMyPanel,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 80,
          height: 80,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) {
              final v = _pulse.value;
              return Stack(alignment: Alignment.center, children: [
                Transform.scale(
                  scale: 1 + v * 1.2,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: C.blue.withValues(alpha: (1 - v) * 0.25),
                    ),
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: C.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: C.blue.withValues(alpha: 0.5),
                          blurRadius: 12),
                    ],
                  ),
                  child: const Icon(Icons.my_location_rounded,
                      color: Colors.white, size: 15),
                ),
                Positioned(
                  top: 30,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: C.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${S.of(context).meLabel} · ${widget.state.myCall}',
                        style: ts(9, c: Colors.white, w: FontWeight.w700)),
                  ),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }

  /// 我的位置信息面板
  void _showMyPanel() {
    final st = widget.state;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: C.blueBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.my_location_rounded,
                      color: C.blue, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.of(context).myLocationPanel(st.myCall),
                          style: ts(16, w: FontWeight.w800)),
                      Text(st.locStatus,
                          style: ts(11, c: st.myHasFix ? C.green : C.yellow)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: C.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              const SizedBox(height: 14),
              SoftCard(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  KV(S.of(context).latitude, st.myLat?.toStringAsFixed(5) ?? '--',
                      icon: Icons.explore_rounded),
                  const SizedBox(height: 8),
                  KV(S.of(context).longitude, st.myLng?.toStringAsFixed(5) ?? '--',
                      icon: Icons.explore_rounded),
                  const SizedBox(height: 8),
                  KV('Maidenhead', st.myGrid,
                      icon: Icons.grid_4x4_rounded),
                  const SizedBox(height: 8),
                  KV(S.of(context).speedLabel, st.mySpeed != null ? '${st.mySpeed!.toStringAsFixed(1)} km/h' : '--',
                      icon: Icons.speed_rounded),
                  const SizedBox(height: 8),
                  KV(S.of(context).bearing, st.myCourse != null ? '${st.myCourse!.toStringAsFixed(0)}°' : '--',
                      icon: Icons.explore_rounded),
                  const SizedBox(height: 8),
                  KV(S.of(context).beaconIntervalLabel, '${st.beaconInterval} 秒',
                      icon: Icons.timer_rounded),
                  const SizedBox(height: 8),
                  KV(S.of(context).beaconsSentLabel, '${st.beaconsSent} 次',
                      icon: Icons.sync_rounded),
                  const SizedBox(height: 8),
                  KV(S.of(context).nextBeaconLabel, st.nextBeaconIn,
                      icon: Icons.access_time_rounded),
                ]),
              ),
              SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      st.sendBeacon();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(S.of(context).positionBeacon(st.myGrid)),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: Icon(Icons.send_rounded, size: 16),
                    label: Text(S.of(context).manualBeacon),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.green,
                      side: BorderSide(color: C.green.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: ts(12, w: FontWeight.w600),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      st.finishPick();
                      setState(() => _pickMode = false);
                      // 重新进入选点
                      st.startPick();
                    },
                    icon: Icon(Icons.edit_location_alt_rounded,
                        size: 16),
                    label: Text('重新选点'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.blue,
                      side: BorderSide(color: C.blue.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: ts(12, w: FontWeight.w600),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  /// 视野内是否有可见台站（放大后视野缩小时判断）
  bool _hasVisibleStation(Size size) {
    for (final s in _visible) {
      final pos = _toScreen(s.lat, s.lng, size);
      if (pos.dx > -20 &&
          pos.dx < size.width + 20 &&
          pos.dy > -20 &&
          pos.dy < size.height + 20) {
        return true;
      }
    }
    return false;
  }

  void _handleMapTap(Offset pos) {
    if (_pickMode) {
      // 选点模式：点击地图设为我的位置
      final (lat, lng) = _screenToLatLng(pos, _lastSize);
      widget.state.setMyPosition(lat, lng);
      widget.state.finishPick();
      setState(() {
        _pickMode = false;
        _selected = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).pickedCoord(
              maidenhead(lat, lng), lat.toStringAsFixed(5), lng.toStringAsFixed(5))),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _selected = null);
  }

  /// 矢量地图点击（收到 WGS-84 经纬度）
  void _handleMapLatLng(double lat, double lng) {
    if (_pickMode) {
      // 矢量地图坐标已是 WGS-84，直接使用
      widget.state.setMyPosition(lat, lng);
      widget.state.finishPick();
      setState(() {
        _pickMode = false;
        _selected = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).pickedCoord(
              maidenhead(lat, lng), lat.toStringAsFixed(5), lng.toStringAsFixed(5))),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _selected = null);
  }

  void _openDetail(Station s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StationDetail(state: widget.state, station: s),
    );
  }

  // ─── 覆盖控件 ───
  Widget _infoChip(List<Station> vis, bool searched) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: softShadow(blur: 14, alpha: 0.09),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _dot(C.green),
        SizedBox(width: 6),
        Text(S.of(context).onlineCount(widget.state.online),
            style: ts(12, c: C.green, w: FontWeight.w600)),
        SizedBox(width: 12),
        _dot(C.blue),
        SizedBox(width: 6),
        Text(S.of(context).movingCount(widget.state.moving),
            style: ts(12, c: C.blue, w: FontWeight.w600)),
        SizedBox(width: 12),
        _dot(C.slate),
        SizedBox(width: 6),
        Text(S.of(context).stationCount(vis.length),
            style: ts(12, c: searched ? C.slate : C.grey)),
      ]),
    );
  }

  /// 地图类型分组列表
  Widget _mapTypeGroup(String group, Color color, VoidCallback onClose) {
    final types = MapType.values.where((t) => t.group == group).toList();
    if (types.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
          child: Row(children: [
            Container(
              width: 3,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 5),
            Text(group, style: ts(10, c: color, w: FontWeight.w700)),
          ]),
        ),
        for (final t in types)
          GestureDetector(
            onTap: () {
              widget.state.setMapType(t.name);
              onClose();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _currentMapType == t ? C.blueBg : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(
                  _currentMapType == t
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 16,
                  color: _currentMapType == t ? C.blue : C.grey,
                ),
                SizedBox(width: 10),
                Text(t.label,
                    style: ts(13,
                        c: _currentMapType == t ? C.blue : C.ink,
                        w: _currentMapType == t
                            ? FontWeight.w700
                            : FontWeight.w500)),
              ]),
            ),
          ),
        const SizedBox(height: 2),
      ],
    );
  }


  Widget _legend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: softShadow(blur: 12, alpha: 0.07),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _lg(C.green, S.of(context).online),
          SizedBox(height: 5),
          _lg(C.blue, S.of(context).moving),
          SizedBox(height: 5),
          _lg(C.red, S.of(context).emergency),
        ],
      ),
    );
  }

  Widget _lg(Color c, String t) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        SizedBox(width: 6),
        Text(t, style: ts(10, c: C.slate)),
      ]);

  Widget _zoomCtrl() {
    return Column(children: [
      RoundIconBtn(Icons.add_rounded,
          onTap: () {
            if (_usePluginMap) {
              _pluginAction('zoomIn');
              return;
            }
            final z = (_zoom + 1).clamp(8.0, 19.0);
            _animateTo(z, _panForCenter(z));
          }),
      SizedBox(height: 6),
      RoundIconBtn(Icons.remove_rounded,
          onTap: () {
            if (_usePluginMap) {
              _pluginAction('zoomOut');
              return;
            }
            final z = (_zoom - 1).clamp(8.0, 19.0);
            _animateTo(z, _panForCenter(z));
          }),
      SizedBox(height: 6),
      RoundIconBtn(_showTracks ? Icons.route_rounded : Icons.route_outlined,
          tooltip: S.of(context).track,
          color: _showTracks ? C.green : C.slate,
          onTap: () => setState(() => _showTracks = !_showTracks)),
      SizedBox(height: 6),
      RoundIconBtn(Icons.my_location_rounded,
          tooltip: S.of(context).locateMe,
          color: C.blue,
          onTap: () {
            if (_usePluginMap) {
              _pluginAction('myLoc');
              return;
            }
            if (widget.state.myHasFix) {
              _animateTo(15.0,
                  _panFor(widget.state.myLat!, widget.state.myLng!, 15.0));
            } else {
              _animateTo(11.0, Offset.zero);
            }
          }),
    ]);
  }

  // ─── 插件地图（矢量/高德JS）动作分发 ───
  int _mapActionSeq = 0;
  String _mapAction = '';

  void _pluginAction(String action) {
    setState(() {
      _mapAction = action;
      _mapActionSeq++;
    });
  }

  /// 图层筛选弹窗
  void _showLayerMenu(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Stack(children: [
        // 半透明遮罩
        Positioned.fill(
          child: GestureDetector(
            onTap: () => entry.remove(),
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.black26),
          ),
        ),
        // 面板
        Positioned(
          right: 56,
          top: 14,
          child: Material(
            color: Colors.transparent,
            child: StatefulBuilder(
              builder: (ctx, setMenuState) => _layerPanelContent(setMenuState, () {
                entry.remove();
              }),
            ),
          ),
        ),
      ]),
    );
    overlay.insert(entry);
  }

  /// 地图类型切换菜单
  void _showMapTypeMenu() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Stack(children: [
        // 半透明遮罩
        Positioned.fill(
          child: GestureDetector(
            onTap: () => entry.remove(),
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.black26),
          ),
        ),
        // 面板
        Positioned(
          right: 56,
          top: 58,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: softShadow(blur: 20, y: 6, alpha: 0.14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 高德系列
                  _mapTypeGroup('高德', C.blue, () => entry.remove()),
                  // 其他地图
                  _mapTypeGroup(S.of(context).otherType, C.slate, () => entry.remove()),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
    overlay.insert(entry);
  }

  Widget _layerPanelContent(StateSetter setMenuState, VoidCallback onClose) {
    final types = <(TypeGroup, String, IconData, Color)>[
      (TypeGroup.mobile, S.of(context).mobile, Icons.directions_car_rounded, C.blue),
      (TypeGroup.fixed, S.of(context).fixed, Icons.home_rounded, C.purple),
      (TypeGroup.infra, S.of(context).infrastructure, Icons.cell_tower_rounded, C.green),
      (TypeGroup.wx, S.of(context).weather, Icons.cloud_rounded, C.cyan),
      (TypeGroup.fmo, 'FMO', Icons.radio_rounded, C.orange),
      (TypeGroup.other, S.of(context).otherType, Icons.apps_rounded, C.slate),
    ];
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: softShadow(blur: 16, alpha: 0.18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.layers_rounded, size: 15, color: C.blue),
            SizedBox(width: 6),
            Text(S.of(context).layerFilter, style: ts(12, w: FontWeight.w700)),
            Spacer(),
            if (_hiddenTypes.isNotEmpty)
              GestureDetector(
                onTap: () {
                  setMenuState(() => _hiddenTypes.clear());
                  setState(() {});
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: C.blueBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(S.of(context).showAll,
                      style: ts(10, c: C.blue, w: FontWeight.w600)),
                ),
              ),
          ]),
          SizedBox(height: 8),
          for (final t in types)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: GestureDetector(
                onTap: () {
                  setMenuState(() {
                    if (_hiddenTypes.contains(t.$1)) {
                      _hiddenTypes.remove(t.$1);
                    } else {
                      _hiddenTypes.add(t.$1);
                    }
                  });
                  setState(() {});
                },
                behavior: HitTestBehavior.opaque,
                child: Row(children: [
                  Icon(t.$3,
                      size: 16,
                      color: _hiddenTypes.contains(t.$1) ? C.greyLight : t.$4),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(t.$2,
                        style: ts(12,
                            c: _hiddenTypes.contains(t.$1) ? C.grey : C.ink,
                            w: FontWeight.w600)),
                  ),
                  Container(
                    width: 40,
                    height: 22,
                    decoration: BoxDecoration(
                      color: !_hiddenTypes.contains(t.$1)
                          ? t.$4.withValues(alpha: 0.25)
                          : C.greyBg,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Align(
                      alignment: !_hiddenTypes.contains(t.$1)
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: !_hiddenTypes.contains(t.$1) ? t.$4 : C.grey,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 2)
                          ],
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bottomControls(Offset? hoverPos) {
    final myLat = widget.state.myLat;
    final myLng = widget.state.myLng;
    final hasFix = widget.state.myHasFix;
    // 距离：鼠标悬停点 → 我的位置；否则地图中心 → 我的位置
    String coord = '北京 · ${_zoom.round()}级';
    String grid = '';
    String datum = widget.state.coordDatum == 'gcj'
        ? S.of(context).datumGcj
        : S.of(context).datumWgs;
    if (hoverPos != null && hoverPos.dx > 0 && _lastSize.width > 0) {
      final (lat, lng) = _screenToLatLng(hoverPos, _lastSize);
      coord = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      grid = maidenhead(lat, lng);
    } else if (hasFix && myLat != null && myLng != null && _lastSize.width > 0) {
      // 计算地图中心到我的位置的距离
      final (cLat, cLng) = _screenToLatLng(
          Offset(_lastSize.width / 2, _lastSize.height / 2), _lastSize);
      final dist = haversine(cLat, cLng, myLat, myLng);
      coord = S.of(context).distKm(dist.toStringAsFixed(1));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: softShadow(blur: 12, alpha: 0.08),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.straighten_rounded, size: 13, color: C.slate),
          SizedBox(width: 5),
          Text(_scaleText, style: ts(10, c: C.slate, w: FontWeight.w600)),
          SizedBox(width: 8),
          Container(width: 1, height: 12, color: C.border),
          SizedBox(width: 8),
          Text(coord, style: ts(11, c: C.slate, w: FontWeight.w500)),
          if (grid.isNotEmpty) ...[
            SizedBox(width: 8),
            Container(width: 1, height: 12, color: C.border),
            SizedBox(width: 8),
            Text(grid, style: mono(10, c: C.blue, w: FontWeight.w600)),
          ],
          SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: C.blueBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(datum,
                style: ts(9, c: C.blue, w: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c,
            boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4)]),
      );
}

/// 脉冲扩散圈：仅此层在动画期间重建，避免整片标记每帧重建拖慢手势
class _PulseRing extends StatelessWidget {
  final Color color;
  final bool sel;
  final Animation<double> anim;
  const _PulseRing({required this.color, required this.sel, required this.anim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, _) {
        final a = anim.value;
        if (a <= 0) return const SizedBox.shrink();
        return Transform.scale(
          scale: 1 + a * 0.9,
          child: Container(
            width: sel ? 32 : 24,
            height: sel ? 32 : 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: (1 - a) * 0.5),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 轨迹叠加绘制（用于选中台站历史轨迹）
class _TrackOverlayPainter extends CustomPainter {
  final List<TrackPt> points;
  final Color color;
  final Offset Function(double lat, double lng) toScreen;
  _TrackOverlayPainter({
    required this.points,
    required this.color,
    required this.toScreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final outline = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final line = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    bool first = true;
    for (final p in points) {
      final pos = toScreen(p.lat, p.lng);
      if (first) {
        path.moveTo(pos.dx, pos.dy);
        first = false;
      } else {
        path.lineTo(pos.dx, pos.dy);
      }
    }
    canvas.drawPath(path, outline);
    canvas.drawPath(path, line);

    final dot = Paint()..color = color.withValues(alpha: 0.5);
    for (int i = 0; i < points.length; i += 5) {
      final pos = toScreen(points[i].lat, points[i].lng);
      canvas.drawCircle(pos, 2.2, dot);
    }
    final start = toScreen(points.first.lat, points.first.lng);
    final end = toScreen(points.last.lat, points.last.lng);
    canvas.drawCircle(start, 3, Paint()..color = C.greyLight);
    canvas.drawCircle(end, 4.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrackOverlayPainter old) =>
      old.points != points || old.color != color;
}
