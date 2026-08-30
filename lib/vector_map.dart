import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import 'theme.dart';
import 'models.dart';

/// 矢量地图视图（flutter_map + vector_map_tiles）
/// 使用 OpenFreeMap 免费矢量瓦片，无需 API key。
/// 坐标体系：WGS-84（标准 Web Mercator），无 GCJ 偏移。
class VectorMapView extends StatefulWidget {
  final List<Station> stations;
  final String myCall;
  final bool myHasFix;
  final double? myLat, myLng;
  final void Function(double lat, double lng)? onTap;
  final void Function(Station s)? onStationTap;
  // 外部焦点请求：focusSeq 变化时相机平移到 focusLat/focusLng
  final int focusSeq;
  final double? focusLat, focusLng;
  // 外部动作：actionSeq 变化时执行 action（zoomIn/zoomOut/myLoc）
  final int actionSeq;
  final String action;
  final bool showTracks;
  // 是否启用台站聚合（台站多时合并为聚合球）
  final bool clustering;
  const VectorMapView({
    super.key,
    required this.stations,
    required this.myCall,
    this.myHasFix = false,
    this.myLat,
    this.myLng,
    this.onTap,
    this.onStationTap,
    this.focusSeq = 0,
    this.focusLat,
    this.focusLng,
    this.actionSeq = 0,
    this.action = '',
    this.showTracks = true,
    this.clustering = true,
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

  @override
  void didUpdateWidget(covariant VectorMapView old) {
    super.didUpdateWidget(old);
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

  /// 台站轨迹线（WGS-84 直接使用，无 GCJ 偏移）
  List<Polyline> get _trackPolylines {
    if (!widget.showTracks) return const [];
    final result = <Polyline>[];
    for (final s in widget.stations) {
      if (s.track.length < 2) continue;
      result.add(Polyline(
        points: s.track
            .map((p) => LatLng(p.lat, p.lng))
            .toList(),
        color: s.color.withValues(alpha: 0.8),
        strokeWidth: 3,
      ));
    }
    return result;
  }

  // 进程级 style 缓存：整个应用生命周期只下载一次 style JSON，
  // 避免每次切回矢量地图都重新加载
  static Style? _cachedStyle;
  static bool _loading = false;
  static final List<void Function(Style?, String?)> _waiters = [];

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  Future<void> _loadStyle() async {
    // 已有缓存：直接使用
    if (_cachedStyle != null) {
      _style = _cachedStyle;
      return;
    }
    if (_styleError != null) {
      return;
    }
    // 正在加载：等待共享结果
    if (_loading) {
      final completer = Completer<void>();
      _waiters.add((style, err) {
        _style = style;
        _styleError = err;
        if (mounted) setState(() {});
        completer.complete();
      });
      await completer.future;
      return;
    }
    _loading = true;
    try {
      final style = await StyleReader(
        uri: 'https://tiles.openfreemap.org/styles/liberty',
        logger: const vtr.Logger.noop(),
      ).read();
      _cachedStyle = style;
      _style = style;
      _notifyWaiters(style, null);
    } catch (e) {
      _styleError = '$e';
      _notifyWaiters(null, '$e');
    } finally {
      _loading = false;
    }
    if (mounted) setState(() {});
  }

  void _notifyWaiters(Style? style, String? err) {
    final waiters = List.from(_waiters);
    _waiters.clear();
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
                  // 轨迹线（所有有轨迹的台站）
                  if (_trackPolylines.isNotEmpty)
                    PolylineLayer(
                      polylines: _trackPolylines,
                    ),
                  // 我的位置
                  if (widget.myHasFix && widget.myLat != null && widget.myLng != null)
                    MarkerLayer(markers: [_myMarker()]),
                  // 台站标记（台站多时聚合为球，减少渲染量）
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
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.red.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline_rounded, size: 16, color: C.red),
                SizedBox(width: 6),
                Flexible(
                  child: Text('矢量地图加载失败\n$_styleError',
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
          Text('加载矢量地图…', style: TextStyle(color: C.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Marker _myMarker() {
    return Marker(
      point: LatLng(widget.myLat!, widget.myLng!),
      width: 28,
      height: 28,
      child: Container(
        decoration: BoxDecoration(
          color: C.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: softShadow(blur: 8, alpha: 0.3),
        ),
        child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 14),
      ),
    );
  }

  Marker _stationMarker(Station s) {
    return Marker(
      point: LatLng(s.lat, s.lng),
      width: 70,
      height: 52,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => widget.onStationTap?.call(s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: s.color, width: 1.5),
              ),
              child: Icon(s.icon, color: s.color, size: 18),
            ),
            // 呼号标签
            Container(
              margin: const EdgeInsets.only(top: 1),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
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

  /// 台站聚合：按经纬度网格聚类（zoom 越低网格越大，聚合越强）
  List<Marker> _buildStationMarkers() {
    final zoom = _mapReady ? _map.camera.zoom : 11.0;
    // 台站数量多且缩放级别低时聚合（可被 clustering 开关关闭）
    final total = widget.stations
        .where((s) => s.call != widget.myCall && s.lat != 0 && s.lng != 0)
        .length;
    // 台站少于阈值、已放大到足够清晰、或关闭聚合时不聚合
    if (!widget.clustering || total < 60 || zoom >= 13) {
      return widget.stations
          .where((s) =>
              s.call != widget.myCall && s.lat != 0 && s.lng != 0)
          .map((s) => _stationMarker(s))
          .toList();
    }
    final markers = <Marker>[];
    for (final c in _clusterStations()) {
      if (c.items.length > 1) {
        markers.add(_clusterMarker(c.lat, c.lng, c.items));
      } else {
        markers.add(_stationMarker(c.items.first));
      }
    }
    return markers;
  }

  /// 台站聚合：按经纬度网格聚类（zoom 越低网格越大，聚合越强）
  /// 返回 (经纬度中心, 台站列表) 列表
  List<({double lat, double lng, List<Station> items})> _clusterStations() {
    final zoom = _mapReady ? _map.camera.zoom : 11.0;
    // 网格大小（度）：zoom 每 +2 缩小一半
    final gridDeg = 0.5 / math.pow(2, (zoom - 8).clamp(0, 10)).toDouble();
    final clusters = <({double lat, double lng, List<Station> items})>[];
    final keyMap = <String, int>{};

    for (final s in widget.stations) {
      if (s.call == widget.myCall || s.lat == 0 || s.lng == 0) continue;
      // 量化到网格
      final gx = (s.lng / gridDeg).floor();
      final gy = (s.lat / gridDeg).floor();
      final key = '$gx,$gy';
      final idx = keyMap[key];
      if (idx == null) {
        keyMap[key] = clusters.length;
        clusters.add((
          lat: s.lat,
          lng: s.lng,
          items: [s],
        ));
      } else {
        final c = clusters[idx];
        // 更新中心（均值）
        final n = c.items.length;
        clusters[idx] = (
          lat: (c.lat * n + s.lat) / (n + 1),
          lng: (c.lng * n + s.lng) / (n + 1),
          items: [...c.items, s],
        );
      }
    }
    return clusters;
  }

  /// 聚合球 Marker：显示数量，点击放大
  Marker _clusterMarker(double lat, double lng, List<Station> items) {
    final count = items.length;
    final size = (24 + count.clamp(0, 20)).toDouble();
    return Marker(
      point: LatLng(lat, lng),
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () {
          // 放大一级展开聚合
          final z = (_map.camera.zoom + 1).clamp(2.0, 19.0);
          _map.move(LatLng(lat, lng), z);
        },
        child: Container(
          decoration: BoxDecoration(
            color: C.indigo.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: softShadow(blur: 8, alpha: 0.3),
          ),
          child: Center(
            child: Text('$count',
                style: ts(13, c: Colors.white, w: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}
