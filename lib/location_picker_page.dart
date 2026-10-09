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

/// ─── 分享位置：自由选点 / 选台站（私聊）───
///
/// 从私聊会话的输入栏「+ → 发送位置点」进入。两条路径分开、互不干扰：
///   1. **自由选点** —— 在地图上点 / 拖任意位置取坐标（默认行为，永远可用）；
///   2. **选择台站** —— 从底部「选择台站」进入**可搜索、可分页**的台站列表，
///      挑一个台站把它**的位置**作为待发点（可选呼号会随帧标成台站卡片）。
///
/// 返回给调用方（[MessagesPage]）的是一对 `(纬度, 经度)` 与可选的分享呼号；
/// 发送动作由调用方走既有的 [AppState.sendLocation]（带 ack 的单播），本页
/// 不发报文 —— 它只是一个「取坐标」的浮层，不碰协议，职责单一。
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

  /// 当前选中的坐标（未选时为 null，发送按钮置灰）。
  (double, double)? _picked;

  /// 选中的坐标若来自「选择台站」，记下该台站呼号（自由选点为 null）。
  /// 返回给调用方后决定气泡样式（台站卡片 vs 普通位置点）。
  String? _pickedStation;

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

  /// 地图点击 = **自由选点**（永远有效，且会清掉「分享台站」标记）。
  void _onMapTap(Offset local) {
    setState(() {
      _picked = _screenToLatLng(local);
      _pickedStation = null;
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
    });
  }

  /// 从「选择台站」列表选中：用该台站坐标 + 呼号（渲染成台站卡片）。
  void _pickStation(Station s) {
    setState(() {
      _picked = (s.lat, s.lng);
      _pickedStation = s.call;
      _pan = _panFor(s.lat, s.lng, _zoom);
    });
  }

  Future<void> _openStationPicker() async {
    final s = await showModalBottomSheet<Station>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StationPickerSheet(state: widget.state),
    );
    if (s != null && mounted) _pickStation(s);
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
                if (_picked == null) _hintBar(),
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

  /// 未选点时的操作提示（浮在地图上，不挡手势）。
  Widget _hintBar() {
    return Positioned(
      bottom: 168 + MediaQuery.of(context).padding.bottom,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: C.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              S.of(context).locationPickHint,
              style: ts(11, c: Colors.white, w: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final has = _picked != null;
    final s = S.of(context);
    return Positioned(
      left: 12,
      right: 12,
      bottom: 10 + MediaQuery.of(context).padding.bottom,
      child: MaterialSurface(
        radius: 18,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: C.sheetFill,
            borderRadius: BorderRadius.circular(18),
            boxShadow: elev3(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _pillBtn(
                      icon: Icons.my_location_rounded,
                      label: s.locationMyPos,
                      color: C.cyan,
                      onTap: _useMyPosition,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _pillBtn(
                      icon: Icons.format_list_bulleted_rounded,
                      label: s.locationPickStations,
                      color: C.slate,
                      onTap: _openStationPicker,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: has ? _confirm : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
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
                          s.locationSendTo(widget.call),
                          style: ts(13, c: Colors.white, w: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: ts(12, c: C.slate, w: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── 台站选择面板（可搜索 / 可分页）───
///
/// 台站动辄成百上千，一屏列不全，所以做成**独立整屏面板**：顶部搜索框、中间
/// 分页列表（每页 [pageSize] 条）、底部页码 + 上/下页按钮（带文字，不做成
/// 藏在角落的小箭头）。点一行即选中该台站（[Navigator.pop] 回传）；行尾
/// 「详情」按钮可先看资料而不关闭本面板。
class StationPickerSheet extends StatefulWidget {
  final AppState state;
  static const int pageSize = 20;

  const StationPickerSheet({super.key, required this.state});

  @override
  State<StationPickerSheet> createState() => _StationPickerSheetState();
}

class _StationPickerSheetState extends State<StationPickerSheet> {
  final _search = TextEditingController();
  String _q = '';
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Station> get _filtered {
    final st = widget.state;
    final myLat = st.myLat;
    final myLng = st.myLng;
    final q = _q.trim().toUpperCase();
    final list = st.stations.where((s) {
      if (q.isEmpty) return true;
      return s.call.toUpperCase().contains(q) ||
          s.alias.toUpperCase().contains(q);
    }).toList();
    if (q.isNotEmpty) {
      // 搜索命中：按呼号排序最直观
      list.sort((a, b) => a.call.compareTo(b.call));
    } else if (myLat != null && myLng != null) {
      // 有定位：近 → 远
      list.sort((a, b) => haversine(myLat, myLng, a.lat, a.lng)
          .compareTo(haversine(myLat, myLng, b.lat, b.lng)));
    } else {
      list.sort((a, b) => b.lastHeard.compareTo(a.lastHeard));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final list = _filtered;
    final pages =
        (list.length + StationPickerSheet.pageSize - 1) ~/ StationPickerSheet.pageSize;
    if (pages > 0 && _page >= pages) _page = pages - 1;
    if (_page < 0) _page = 0;
    final start = _page * StationPickerSheet.pageSize;
    final end =
        (start + StationPickerSheet.pageSize).clamp(0, list.length).toInt();
    final pageItems = list.sublist(start, end);

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: MaterialSurface(
        radius: 24,
        topOnly: true,
        child: Container(
          decoration: BoxDecoration(
            color: C.sheetFill,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: C.greyLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.locationPickStations,
                          style: ts(15, w: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: C.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() {
                      _q = v;
                      _page = 0;
                    }),
                    style: ts(13),
                    decoration: InputDecoration(
                      hintText: s.locationSearchHint,
                      hintStyle: ts(13, c: C.grey),
                      prefixIcon:
                          Icon(Icons.search_rounded, size: 18, color: C.grey),
                      suffixIcon: _q.isEmpty
                          ? null
                          : GestureDetector(
                              onTap: () => setState(() {
                                _search.clear();
                                _q = '';
                                _page = 0;
                              }),
                              child: Icon(Icons.cancel_rounded,
                                  size: 18, color: C.grey),
                            ),
                      filled: true,
                      fillColor: C.bgSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                Divider(height: 1, color: C.border),
                Expanded(
                  child: pageItems.isEmpty
                      ? Center(
                          child: Text(s.locationNoStation,
                              style: ts(12, c: C.grey)))
                      : ListView.builder(
                          itemCount: pageItems.length,
                          itemBuilder: (_, i) {
                            final st = pageItems[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(Icons.radio_rounded,
                                  size: 18, color: C.blue),
                              title: Text(
                                st.alias.isEmpty
                                    ? st.call
                                    : '${st.call}  ·  ${st.alias}',
                                style: ts(13, w: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${st.lat.toStringAsFixed(4)}, '
                                '${st.lng.toStringAsFixed(4)}'
                                '${st.grid.isEmpty ? '' : '  ${st.grid}'}',
                                style: mono(9, c: C.grey),
                              ),
                              // 点整行 = 选中该台站坐标（回传给选点页）。
                              onTap: () => Navigator.pop(context, st),
                              // 行尾「详情」= 先看台站资料（不关闭选择面板）。
                              trailing: GestureDetector(
                                onTap: () => showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => StationDetail(
                                      state: widget.state, station: st),
                                ),
                                child: Icon(Icons.info_outline_rounded,
                                    size: 18, color: C.grey),
                              ),
                            );
                          },
                        ),
                ),
                if (pages > 1)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: C.border)),
                    ),
                    child: Row(
                      children: [
                        _pageBtn(
                          icon: Icons.chevron_left_rounded,
                          label: s.locationPrevPage,
                          enabled: _page > 0,
                          onTap: () => setState(() => _page--),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              s.locationPageInfo('${_page + 1}', '$pages'),
                              style: ts(12, c: C.slate, w: FontWeight.w700),
                            ),
                          ),
                        ),
                        _pageBtn(
                          icon: Icons.chevron_right_rounded,
                          label: s.locationNextPage,
                          enabled: _page < pages - 1,
                          onTap: () => setState(() => _page++),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageBtn({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final col = enabled ? C.blue : C.greyLight;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? C.bgSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: enabled ? C.border : C.border.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: col),
            const SizedBox(width: 2),
            Text(label, style: ts(11, c: col, w: FontWeight.w600)),
          ],
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
