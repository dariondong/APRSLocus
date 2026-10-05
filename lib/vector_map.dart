import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import 'theme.dart';
import 'models.dart';
import 'widgets.dart';

/// 矢量地图视图（flutter_map + vector_map_tiles）
/// 使用 OpenFreeMap 免费矢量瓦片，无需 API key。
/// 坐标体系：WGS-84（标准 Web Mercator），无 GCJ 偏移。
/// 支持多种 style：默认 Liberty；vector_positron 使用 CARTO Positron 观感。
const kVectorStyleLiberty = 'https://tiles.openfreemap.org/styles/liberty';
const kVectorStylePositron = 'https://tiles.openfreemap.org/styles/positron';

/// 各 mapType 对应的矢量 style URL
String vectorStyleUrlFor(String mapType) {
  if (mapType == 'vector_positron') return kVectorStylePositron;
  return kVectorStyleLiberty;
}

class VectorMapView extends StatefulWidget {
  final List<Station> stations;
  // 台站数据版本：未变化时复用已构建的 Marker，避免每秒重建
  final int stationsVersion;
  final String myCall;
  final bool myHasFix;
  final double? myLat, myLng;
  // 航向（真北顺时针，度）：给我的位置标记画方位角「小角角」。
  final double? myCourse;
  // 轨迹显示：我的轨迹（蓝色）+ 选中台站轨迹（台站颜色）
  final List<TrackPt> myTrack;
  final String? selectedCall;
  final List<TrackPt> selectedTrack;
  final Color? selectedColor;
  final void Function(double lat, double lng)? onTap;
  final void Function(Station s)? onStationTap;
  // 外部焦点请求：focusSeq 变化时相机平移到 focusLat/focusLng
  final int focusSeq;
  final double? focusLat, focusLng;
  // 外部动作：actionSeq 变化时执行 action（zoomIn/zoomOut/myLoc）
  final int actionSeq;
  final String action;
  final bool showTracks;

  /// 显示台站热力图（矢量地图以前完全没有这一层，见 MapPage._showHeatmap）。
  final bool showHeatmap;

  /// 热力图档位 0/1/2（弱/中/强）：与栅格地图同一个值，缩放光斑半径。
  final int heatLevel;

  /// 设置里强制「无论台站多密 / 缩得多小都显示呼号标签」（见 AppState.mapLabelsAlways）。
  final bool showStationLabels;
  // 矢量底图 style URL（OpenFreeMap Liberty / CARTO Positron）
  final String styleUrl;
  const VectorMapView({
    super.key,
    required this.stations,
    this.stationsVersion = 0,
    required this.myCall,
    this.myHasFix = false,
    this.myLat,
    this.myLng,
    this.myCourse,
    this.myTrack = const [],
    this.selectedCall,
    this.selectedTrack = const [],
    this.selectedColor,
    this.onTap,
    this.onStationTap,
    this.focusSeq = 0,
    this.focusLat,
    this.focusLng,
    this.actionSeq = 0,
    this.action = '',
    this.showTracks = true,
    this.showHeatmap = false,
    this.heatLevel = 1,
    this.showStationLabels = false,
    this.styleUrl = kVectorStyleLiberty,
  });

  @override
  State<VectorMapView> createState() => _VectorMapViewState();
}

class _VectorMapViewState extends State<VectorMapView> {
  final MapController _map = MapController();
  Style? _style;
  String? _styleError;
  int _lastFocusSeq = -1;
  int _lastActionSeq = -1;
  bool _initDone = false;
  LatLng? _pendingFocus;
  // 台站 Marker 缓存（版本/缩放/选中项）
  int _lastMarkersVersion = -1;
  double _lastMarkerZoom = -999;
  String? _lastSelectedCall;
  bool _lastShowStationLabels = false;
  List<Marker>? _markersCache;

  @override
  void didUpdateWidget(covariant VectorMapView old) {
    super.didUpdateWidget(old);
    // 底图风格切换：重新加载对应 style
    if (widget.styleUrl != old.styleUrl) {
      _style = null;
      _styleError = null;
      _loadStyle(widget.styleUrl);
    }
    if (widget.focusSeq != old.focusSeq &&
        widget.focusLat != null &&
        widget.focusLng != null) {
      _focusOn(widget.focusLat!, widget.focusLng!);
    }
    if (widget.actionSeq != old.actionSeq) _handleAction();
  }

  /// 处理外部动作（以视图中心缩放 / 定位到我）
  void _handleAction() {
    _lastActionSeq = widget.actionSeq;
    if (!_mapReady) return;
    switch (widget.action) {
      case 'zoomIn':
      case 'zoomOut':
        final cur = _map.camera.zoom;
        final nz = (widget.action == 'zoomIn' ? cur + 1 : cur - 1)
            .clamp(3.0, 19.0);
        _map.move(_map.camera.center, nz);
        break;
      case 'myLoc':
        if (widget.myLat != null && widget.myLng != null) {
          _map.move(LatLng(widget.myLat!, widget.myLng!), _map.camera.zoom);
        }
        break;
    }
  }

  /// 相机移动到指定坐标（WGS-84）
  void _focusOn(double lat, double lng) {
    _lastFocusSeq = widget.focusSeq;
    _initDone = true;
    if (!_mapReady) {
      _pendingFocus = LatLng(lat, lng);
      return;
    }
    _map.move(LatLng(lat, lng), 14.0);
  }

  bool _mapReady = false;

  /// 轨迹线（WGS-84 直接使用，无 GCJ 偏移）：
  /// 我的轨迹（蓝色）+ 选中台站的轨迹（台站颜色），与自绘瓦片地图一致
  List<Polyline> get _trackPolylines {
    if (!widget.showTracks) return const [];
    final result = <Polyline>[];
    if (widget.myTrack.length > 1) {
      result.add(Polyline(
        points: widget.myTrack.map((p) => LatLng(p.lat, p.lng)).toList(),
        color: C.blue.withValues(alpha: 0.85),
        strokeWidth: 3.5,
      ));
    }
    final sel = widget.selectedTrack;
    final selColor = widget.selectedColor;
    if (sel.length > 1 && selColor != null) {
      result.add(Polyline(
        points: sel.map((p) => LatLng(p.lat, p.lng)).toList(),
        color: selColor.withValues(alpha: 0.85),
        strokeWidth: 3.5,
      ));
    }
    return result;
  }

  // 进程级 style 缓存：按 style URL 分别缓存，整个应用生命周期每个只下载一次，
  // 避免每次切回矢量地图 / 切换底图风格都重新加载
  static final Map<String, Style> _cachedStyle = {};
  static final Set<String> _loading = {};
  static final Map<String, List<void Function(Style?, String?)>> _waiters = {};

  @override
  void initState() {
    super.initState();
    _loadStyle(widget.styleUrl);
  }

  Future<void> _loadStyle(String url) async {
    // 已有缓存：直接使用
    final cached = _cachedStyle[url];
    if (cached != null) {
      _style = cached;
      _styleError = null;
      if (mounted) setState(() {});
      return;
    }
    if (_styleError != null && !_loading.contains(url)) {
      return;
    }
    // 正在加载：等待共享结果
    if (_loading.contains(url)) {
      final completer = Completer<void>();
      _waiters.putIfAbsent(url, () => []).add((style, err) {
        _style = style;
        _styleError = err;
        if (mounted) setState(() {});
        completer.complete();
      });
      await completer.future;
      return;
    }
    _loading.add(url);
    try {
      final style = await StyleReader(
        uri: url,
        logger: const vtr.Logger.noop(),
      ).read();
      _cachedStyle[url] = style;
      _style = style;
      _styleError = null;
      _notifyWaiters(url, style, null);
    } catch (e) {
      _styleError = '$e';
      _notifyWaiters(url, null, '$e');
    } finally {
      _loading.remove(url);
    }
    if (mounted) setState(() {});
  }

  void _notifyWaiters(String url, Style? style, String? err) {
    final waiters = _waiters.remove(url);
    if (waiters == null) return;
    for (final w in waiters) {
      w(style, err);
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    // 初始中心：优先待处理焦点，其次我的位置
    final initLat = _pendingFocus?.latitude ?? widget.myLat ?? 39.9042;
    final initLng = _pendingFocus?.longitude ?? widget.myLng ?? 116.4074;
    final initZoom = _pendingFocus != null ? 14.0 : 11.0;
    return Stack(children: [
      Positioned.fill(
        child: style == null
            ? _loadingOrError()
            : FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: LatLng(initLat, initLng),
                  initialZoom: initZoom,
                  minZoom: 2,
                  maxZoom: 19,
                  backgroundColor: const Color(0xFFF3F5F9),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (tapPos, latLng) =>
                      widget.onTap?.call(latLng.latitude, latLng.longitude),
                  onMapReady: () {
                    _mapReady = true;
                    // 地图就绪后应用待处理焦点
                    if (_pendingFocus != null) {
                      final f = _pendingFocus!;
                      _pendingFocus = null;
                      _map.move(f, 14.0);
                      _lastFocusSeq = widget.focusSeq;
                    } else if (widget.focusSeq != _lastFocusSeq &&
                        widget.focusLat != null &&
                        widget.focusLng != null) {
                      _lastFocusSeq = widget.focusSeq;
                      _map.move(
                          LatLng(widget.focusLat!, widget.focusLng!), 14.0);
                    }
                  },
                ),
                children: [
                  VectorTileLayer(
                    theme: style.theme,
                    sprites: style.sprites,
                    tileProviders: style.providers,
                    cacheFolder: getApplicationSupportDirectory,
                  ),
                  // 轨迹线（我的 + 选中台站）
                  if (_trackPolylines.isNotEmpty)
                    PolylineLayer(
                      polylines: _trackPolylines,
                    ),
                  // 我的位置
                  if (widget.myHasFix && widget.myLat != null && widget.myLng != null)
                    if (widget.showHeatmap)
                    Builder(
                      builder: (ctx) {
                        // 用 flutter_map 自己的相机投影 —— 尺寸与平移才和瓦片完全一致
                        final cam = MapCamera.of(ctx);
                        return IgnorePointer(
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _VectorHeatmapPainter(
                              stations: widget.stations,
                              camera: cam,
                              level: widget.heatLevel,
                            ),
                          ),
                        );
                      },
                    ),
                  MarkerLayer(markers: [_myMarker()]),
                  // 台站标记
                  MarkerLayer(
                    markers: _buildStationMarkers(),
                  ),
                ],
              ),
      ),
      // 加载失败提示
      if (style == null && _styleError != null)
        Positioned(
          left: 0,
          right: 0,
          top: 60,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: C.redBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.red.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline_rounded, size: 16, color: C.red),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                      S.of(context).vectorMapLoadFailed('$_styleError'),
                      style: ts(11, c: C.red, w: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _loadingOrError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 2.5),
          SizedBox(height: 10),
          Text(S.of(context).loadingVectorMap,
              style: TextStyle(color: C.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Marker _myMarker() {
    // 有航向时用带指向的箭头图标，并在圆外叠一个方位角「小角角」；
    // 无航向（null / 静止未取得）时退回普通圆点，不画角标 —— 别拿猜的方向误导。
    final crs = widget.myCourse;
    final hasCourse = crs != null && crs >= 0;
    return Marker(
      point: LatLng(widget.myLat!, widget.myLng!),
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        // 角标会伸出圆外（比标记框略大），不裁剪才不会把尖端切掉。
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: C.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              // 这里**故意**不用 elev1/2/3：这是地图标记背后的一圈深色光晕，用途是让压在各种瓦片上的文字可读，属于「可读性」而不是「层次」。
              // 同上：可读性光晕，不属于三级高度体系。
              boxShadow: softShadow(blur: 8, alpha: 0.3),
            ),
            child: Icon(
              hasCourse ? Icons.navigation_rounded : Icons.my_location_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          if (hasCourse)
            HeadingCornerIndicator(
              course: crs,
              radius: 14,
              size: 9,
              accent: C.blue,
            ),
        ],
      ),
    );
  }

  /// 相机中心（上次建 Marker 时）——与 stationsVersion 一起决定要不要重建。
  LatLng? _lastMarkerCenter;

  Marker _stationMarker(Station s, {required bool labels}) {
    final selected = s.call == widget.selectedCall;
    // key = 呼号：列表变化时让 Flutter 按**身份**复用元素，而不是按位置把后面全部重建。
    return Marker(
      key: ValueKey(s.call),
      point: LatLng(s.lat, s.lng),
      width: 70,
      height: 52,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        // translucent：标记与身后的地图都收到指针 —— 否则手指正好落在台站上时，
        // 地图既不能缩放也不能拖动（手势全被标记吃了）。
        behavior: HitTestBehavior.translucent,
        onTap: () => widget.onStationTap?.call(s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // APRS 官方符号图标原图（不加圆底/描边圈）
            SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: AprsSymbolImage(
                  s.symbol,
                  s.symbolTable,
                  size: selected ? 32 : 24,
                  grayscale: s.effectiveStatus == St.offline,
                ),
              ),
            ),
            // 呼号标签（台站密 / 缩得小时不画）
            if (labels)
              Container(
                margin: const EdgeInsets.only(top: -22),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: s.color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  s.call,
                  style: ts(9,
                      c: s.color,
                      w: FontWeight.w700,
                      h: 1.0),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 台站标记：按数据版本/缩放缓存，避免每秒 tick 重建全部 Marker
  List<Marker> _buildStationMarkers() {
    final zoom = _mapReady ? _map.camera.zoom : 11.0;
    // 台站版本 + 缩放级别 + 聚合开关未变时复用 Marker，
    // 避免 MapPage 每秒 tick 重建时反复创建全部 Marker
    // 相机中心也要参与判断：加了视口裁剪之后，**拖动**同样会改变"该建哪些 Marker"，
    // 只盯版本号/缩放会让裁剪结果僵在原地。
    final center = _mapReady ? _map.camera.center : null;
    final moved = center != null &&
        (_lastMarkerCenter == null ||
            (center.latitude - _lastMarkerCenter!.latitude).abs() > 0.0005 ||
            (center.longitude - _lastMarkerCenter!.longitude).abs() > 0.0005);
    if (widget.stationsVersion == _lastMarkersVersion &&
        (zoom - _lastMarkerZoom).abs() < 0.5 &&
        widget.selectedCall == _lastSelectedCall &&
        widget.showStationLabels == _lastShowStationLabels &&
        !moved &&
        _markersCache != null) {
      return _markersCache!;
    }
    _lastMarkerCenter = center;
    _lastMarkersVersion = widget.stationsVersion;
    _lastMarkerZoom = zoom;
    _lastSelectedCall = widget.selectedCall;
    _lastShowStationLabels = widget.showStationLabels;
    final bounds = _mapReady ? _map.camera.visibleBounds : null;
    final vis = widget.stations
        .where((s) =>
            s.call != widget.myCall && s.lat != 0 && s.lng != 0)
        .where((s) => _inBounds(s, bounds))
        .toList();
    // 台站密的时候（或缩得很小）不画呼号标签：文字排版是每个标记最贵的一步。
    // 设置里可强制「无论密度/缩放都显示」（见 AppState.mapLabelsAlways）。
    final labels =
        widget.showStationLabels || vis.length <= 60 || zoom >= 13;
    final result = vis.map((s) => _stationMarker(s, labels: labels)).toList();
    _markersCache = result;
    return result;
  }

  /// 该台站是否落在视口内（含约 20% 留白）。
  ///
  /// 为什么必须有：以前是把**全部**台站塞进 MarkerLayer —— 几千个 Marker widget
  /// 每帧都要布局与绘制；而 stationsVersion 每个报文都会 +1，于是每个报文都会把全部
  /// Marker 重建一遍。台站一多就卡死。
  bool _inBounds(Station s, LatLngBounds? b) {
    if (b == null) return true;
    final padLat = (b.north - b.south) * 0.2 + 0.002;
    final padLng = (b.east - b.west) * 0.2 + 0.002;
    return s.lat >= b.south - padLat &&
        s.lat <= b.north + padLat &&
        s.lng >= b.west - padLng &&
        s.lng <= b.east + padLng;
  }


}

/// 矢量地图上的台站热力图：每个台站叠一个柔和光斑，密的区域自然变亮。
///
/// 与栅格地图那份 `_HeatmapPainter` 分开写：那一个用的是 MapPage 自己的投影，而这里
/// 只能用 flutter_map 的相机（`MapCamera.of`）。配色按同一套走（橙色叠加）。
class _VectorHeatmapPainter extends CustomPainter {
  final List<Station> stations;
  final MapCamera camera;
  final int level;

  const _VectorHeatmapPainter(
      {required this.stations, required this.camera, this.level = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final radius =
        46.0 * (level == 0 ? 0.7 : (level >= 2 ? 1.5 : 1.0)); // 光斑半径
    final paint = Paint()..blendMode = BlendMode.plus;
    for (final s in stations) {
      if (s.lat == 0 && s.lng == 0) continue;
      final p = camera.latLngToScreenOffset(LatLng(s.lat, s.lng));
      // 视口外的直接跳过（相机投影已含平移与缩放）
      if (p.dx < -radius ||
          p.dy < -radius ||
          p.dx > size.width + radius ||
          p.dy > size.height + radius) {
        continue;
      }
      paint.shader = RadialGradient(
        colors: [
          C.orange.withValues(alpha: 0.30),
          C.orange.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: p, radius: radius));
      canvas.drawCircle(p, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VectorHeatmapPainter old) =>
      !identical(old.stations, stations) ||
      old.level != level ||
      old.camera.zoom != camera.zoom ||
      old.camera.center != camera.center;
}
