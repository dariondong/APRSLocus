import 'package:flutter/material.dart';

import 'coord.dart';
import 'map_math.dart';
import 'material.dart';
import 'models.dart';
import 'station_detail.dart';
import 'state.dart';
import 'theme.dart';
import 'tile_map.dart';
import 'widgets.dart';

/// ─── 分享位置：选点 / 选台站（私聊）───
///
/// 从私聊会话的输入栏「发送位置点」进入。需求有两层：
///   1. **选一个坐标点**发给对方 —— 拖地图、点任意位置取坐标（不只是发自己）；
///   2. **分享其他台站** —— 从台站列表挑一个，点它**先呼出台站面板**看详情，
///      确认无误后再发。
///
/// 返回给调用方（[MessagesPage]）的是一对 `(纬度, 经度)`；发送动作由调用方
/// 走既有的 [AppState.sendLocation]（带 ack 的单播），本页不发报文 —— 它只是
/// 一个「取坐标」的浮层，不碰协议，职责单一、也好测。
class LocationPickerPage extends StatefulWidget {
  final AppState state;

  /// 私聊对象呼号（用于标题与「发送给 XX」按钮文案）。
  final String call;

  const LocationPickerPage({super.key, required this.state, required this.call});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const _baseLat = 39.9042;
  static const _baseLng = 116.4074;
  static final (double, double) _gcjBase = Gcj.wgsToGcj(_baseLat, _baseLng);

  double _zoom = 12.0;
  Offset _pan = Offset.zero;
  Size _size = Size.zero;

  /// 当前选中的坐标（未选时为 null，按钮置灰）。
  (double, double)? _picked;

  /// 选中的坐标若来自「分享某个台站」，这里记下它的呼号（自由选点为 null）。
  /// 返回给调用方后决定气泡样式（台站卡片 vs 普通位置点）。
  String? _pickedStation;

  bool _selMode = false;

  MapType get _mapType {
    var t = mapTypeByName(widget.state.mapType);
    // 与策略地图同一取舍：瓦片自绘层不支持矢量图源，退到卫星。
    if (t == MapType.vector || t == MapType.vector_positron) {
      t = MapType.gaode_sat;
    }
    return t;
  }

  bool get _isGcj => isGcjMapType(_mapType);
  (double, double) get _base => _isGcj ? _gcjBase : (_baseLat, _baseLng);
  MapProjection get _proj => projectionFor(_mapType);

  (double, double) _tc(double lat, double lng) =>
      _isGcj ? Gcj.wgsToGcj(lat, lng) : (lat, lng);

  Offset _toScreen(double lat, double lng) {
    final t = _tc(lat, lng);
    final b = _base;
    final c = _proj.latLngToPx(b.$1, b.$2, _zoom);
    final p = _proj.latLngToPx(t.$1, t.$2, _zoom);
    return Offset(
      p.dx - c.dx + _size.width / 2 + _pan.dx,
      p.dy - c.dy + _size.height / 2 + _pan.dy,
    );
  }

  (double, double) _screenToLatLng(Offset s) {
    final b = _base;
    final c = _proj.latLngToPx(b.$1, b.$2, _zoom);
    final p = Offset(
      s.dx + c.dx - _size.width / 2 - _pan.dx,
      s.dy + c.dy - _size.height / 2 - _pan.dy,
    );
    final g = _proj.pxToLatLng(p, _zoom);
    if (_isGcj && widget.state.coordDatum != 'gcj') {
      return Gcj.gcjToWgs(g.$1, g.$2);
    }
    return g;
  }

  Offset _panFor(double lat, double lng, double zoom) {
    final b = _base;
    final g = _tc(lat, lng);
    final c = _proj.latLngToPx(b.$1, b.$2, zoom);
    final p = _proj.latLngToPx(g.$1, g.$2, zoom);
    return c - p;
  }

  @override
  void initState() {
    super.initState();
    final st = widget.state;
    if (st.myHasFix && st.myLat != null && st.myLng != null) {
      _pan = _panFor(st.myLat!, st.myLng!, _zoom);
    }
  }

  // ─── 交互 ───

  void _onMapTap(Offset local) {
    final ll = _screenToLatLng(local);
    setState(() {
      _picked = ll;
      _pickedStation = null; // 自由选点：不再是「分享台站」
    });
  }

  void _useMyPosition() {
    final st = widget.state;
    if (!st.myHasFix || st.myLat == null || st.myLng == null) {
      _toast(S.of(context).needFixToSendLocation);
      return;
    }
    setState(() {
      _picked = (st.myLat!, st.myLng!);
      _pickedStation = null;
      _pan = _panFor(st.myLat!, st.myLng!, _zoom);
      _selMode = false;
    });
  }

  void _pickStation(Station s) {
    setState(() {
      _picked = (s.lat, s.lng);
      _pickedStation = s.call;
      _pan = _panFor(s.lat, s.lng, _zoom);
    });
  }

  /// 打开台站详细面板（与主地图 / 策略地图同一入口）。
  void _openStation(Station s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StationDetail(state: widget.state, station: s),
    );
  }

  void _confirm() {
    if (_picked == null) return;
    Navigator.pop(context, (_picked!, _pickedStation));
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  // ─── 视图 ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => LayoutBuilder(
          builder: (context, c) {
            _size = Size(c.maxWidth, c.maxHeight);
            return Stack(
              children: [
                _mapLayer(_size),
                _topBar(),
                if (_selMode) _stationPanel(c.maxHeight),
                if (!_selMode) _hintBar(),
                _bottomBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _mapLayer(Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return const Positioned.fill(child: SizedBox.shrink());
    }
    final picked = _picked;
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          TileMapView(
            centerLat: _base.$1,
            centerLng: _base.$2,
            zoom: _zoom,
            pan: _pan,
            onPan: (d) => setState(() => _pan += d),
            onViewChanged: (z, p) => setState(() {
              _zoom = z;
              _pan = p;
            }),
            onZoomRequest: (z, p) => setState(() {
              _zoom = z;
              _pan = p;
            }),
            onTap: _onMapTap,
            mapType: _mapType,
            cacheEnabled: widget.state.tileCacheOn,
            offlineOnly: widget.state.offlineOnly,
          ),
          if (picked != null)
            IgnorePointer(
              child: CustomPaint(
                size: size,
                painter: _PickPainter(
                  picked: picked,
                  toScreen: _toScreen,
                  color: C.orange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topBar() {
    final gc = _picked == null
        ? ''
        : '${_picked!.$1.toStringAsFixed(5)}, ${_picked!.$2.toStringAsFixed(5)}';
    return Positioned(
      top: 8 + MediaQuery.of(context).padding.top,
      left: 12,
      right: 12,
      child: Row(
        children: [
          _roundBtn(Icons.close_rounded, () => Navigator.pop(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: C.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).locationPickTitle,
                    style: ts(14, c: Colors.white, w: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    gc.isEmpty
                        ? S.of(context).locationPickHint
                        : '$gc  ·  ${S.of(context).locationSendTo(widget.call)}',
                    style: ts(10, c: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _roundBtn(
            Icons.people_alt_rounded,
            () => setState(() => _selMode = !_selMode),
            color: _selMode ? C.cyan : Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: C.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Icon(icon, size: 20, color: color ?? Colors.white),
      ),
    );
  }

  Widget _hintBar() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 78 + MediaQuery.of(context).padding.bottom,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: C.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _picked == null
                ? S.of(context).locationPickHint
                : (_pickedStation ?? '${_picked!.$1.toStringAsFixed(5)}, '
                    '${_picked!.$2.toStringAsFixed(5)}'),
            style: ts(11, c: Colors.white, w: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  /// 右侧台站面板：点一行 = 选中该台站的位置；行尾「详情」按钮 = 呼出台站面板。
  /// 这样「分享它的位置」与「看它的资料」两个动作不会互相顶掉。
  Widget _stationPanel(double maxH) {
    final st = widget.state;
    final list = st.stations.toList()
      ..sort((a, b) => b.lastHeard.compareTo(a.lastHeard));
    return Positioned(
      right: 12,
      top: 8 + MediaQuery.of(context).padding.top + 48,
      bottom: 78 + MediaQuery.of(context).padding.bottom,
      width: 236,
      child: MaterialSurface(
        radius: 16,
        child: Container(
          decoration: BoxDecoration(
            color: C.sheetFill,
            borderRadius: BorderRadius.circular(16),
            boxShadow: elev3(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        S.of(context).locationPickTitle,
                        style: ts(12, c: C.slate, w: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selMode = false),
                      child: Icon(Icons.close_rounded, size: 16, color: C.grey),
                    ),
                  ],
                ),
              ),
              // 「我的位置」置顶：最常见的分享目标。
              ListTile(
                dense: true,
                leading: Icon(Icons.my_location_rounded, size: 18, color: C.cyan),
                title: Text(S.of(context).locationMyPos,
                    style: ts(12, w: FontWeight.w600)),
                onTap: _useMyPosition,
              ),
              Divider(height: 1, color: C.border),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(S.of(context).noConversations,
                            style: ts(11, c: C.grey)))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final s = list[i];
                          return ListTile(
                            dense: true,
                            title: Text(s.call,
                                style: ts(12, w: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${s.lat.toStringAsFixed(4)}, '
                              '${s.lng.toStringAsFixed(4)}',
                              style: mono(9, c: C.grey),
                            ),
                            // 行尾「分享」：把该台站的坐标选为要发送的点（回中心）。
                            trailing: GestureDetector(
                              onTap: () => _pickStation(s),
                              child: Icon(Icons.share_location_rounded,
                                  size: 18, color: C.blue),
                            ),
                            // 点整行 = 呼出该台站的详细面板（用户要求：点一下能看到对方资料）。
                            onTap: () => _openStation(s),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final has = _picked != null;
    return Positioned(
      left: 12,
      right: 12,
      bottom: 10 + MediaQuery.of(context).padding.bottom,
      child: MaterialSurface(
        radius: 18,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: C.sheetFill,
            borderRadius: BorderRadius.circular(18),
            boxShadow: elev3(),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _useMyPosition,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: C.bgSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.my_location_rounded, size: 16, color: C.cyan),
                        const SizedBox(width: 6),
                        Text(S.of(context).locationMyPos,
                            style: ts(12, c: C.slate, w: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: has ? _confirm : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: has ? C.blue : C.grey,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: has ? elev2() : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            S.of(context).locationSendTo(widget.call),
                            style: ts(12, c: Colors.white, w: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 选点标记 + 十字准星（浮层之上，不接手势）。
class _PickPainter extends CustomPainter {
  final (double, double) picked;
  final Offset Function(double lat, double lng) toScreen;
  final Color color;

  _PickPainter({
    required this.picked,
    required this.toScreen,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = toScreen(picked.$1, picked.$2);
    final ring = Paint()..color = color.withValues(alpha: 0.22);
    canvas.drawCircle(c, 16, ring);
    canvas.drawCircle(c, 10, Paint()..color = Colors.white);
    canvas.drawCircle(c, 7.5, Paint()..color = color);
    canvas.drawCircle(
      c,
      16,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _PickPainter old) =>
      old.picked != picked || old.color != color;
}
