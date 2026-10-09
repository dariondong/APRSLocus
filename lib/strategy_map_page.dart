import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'coord.dart';
import 'map_math.dart';
import 'material.dart';
import 'models.dart';
import 'strategy_map.dart';
import 'state.dart';
import 'theme.dart';
import 'tile_map.dart';
import 'widgets.dart';

/// ─── 策略地图 ───
///
/// 与同群队友共享**标点 / 划线 / 画圈 / 集合点**，全部经 APRS 消息（见
/// `lib/strategy_map.dart` 的协议）。本页只负责「放/改/删 + 画出来」，
/// 编解码与收发都在 [AppState]。
///
/// 交互分工（尽量贴近主地图的手感）：
/// * 单击地图：当前工具下放一个点 / 圈 / 集合点；划线工具下每击追加一个点。
/// * 单击已有元素：选中它，弹出操作（导航 / 编辑信息 / 删除）。
/// * 双击元素：直接导航（落到主地图并聚焦）。
/// * 长按地图：切换回平移（配合单指拖动）。
class StrategyMapPage extends StatefulWidget {
  final AppState state;
  final String groupCall;
  final String groupName;

  const StrategyMapPage({
    super.key,
    required this.state,
    required this.groupCall,
    required this.groupName,
  });

  @override
  State<StrategyMapPage> createState() => _StrategyMapPageState();
}

/// 当前绘制工具
enum _Tool { pan, point, line, circle, rally }

class _StrategyMapPageState extends State<StrategyMapPage>
    with SingleTickerProviderStateMixin {
  static const _baseLat = 39.9042;
  static const _baseLng = 116.4074;
  static final (double, double) _gcjBase = Gcj.wgsToGcj(_baseLat, _baseLng);

  double _zoom = 12.0;
  Offset _pan = Offset.zero;
  Size _size = Size.zero;

  _Tool _tool = _Tool.pan;
  final List<(double, double)> _draft = []; // 划线草稿
  StrategyItem? _selected;

  /// 队友标记缓存：state 每秒 tick、收包都会 notify，若每次 build 都新建列表，
  /// `shouldRepaint` 的 `teammates != teammates` 会恒为真 → 每帧全量重绘。
  /// 用「呼号|纬度|经度|航向」拼键，只有队友实际移动/转向才换新列表。
  List<Station> _teammates = const [];
  String _teammateKey = '';

  List<Station> _teammatesNow() {
    ChatGroup? g;
    for (final x in widget.state.chatGroups) {
      if (x.groupCall.toUpperCase() == _gc) {
        g = x;
        break;
      }
    }
    if (g == null) {
      _teammateKey = '';
      _teammates = const [];
      return _teammates;
    }
    final list = widget.state.strategyTeammates(g);
    final key = list
        .map((s) =>
            '${s.call}|${s.lat.toStringAsFixed(5)}|${s.lng.toStringAsFixed(5)}|${s.course?.round()}')
        .join(',');
    if (key != _teammateKey) {
      _teammateKey = key;
      _teammates = list;
    }
    return _teammates;
  }

  // 视图动画（导航时平滑居中）
  late final AnimationController _anim;
  double _fromZoom = 12, _toZoom = 12;
  Offset _fromPan = Offset.zero, _toPan = Offset.zero;

  String get _gc => widget.groupCall.toUpperCase();

  MapType get _mapType {
    var t = mapTypeByName(widget.state.mapType);
    // 瓦片自绘层不支持矢量图源（会取不到瓦片 → 整页空白），退到卫星/高德。
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
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addListener(_onAnim);
    _fromZoom = _toZoom = _zoom;
    // 进页即居中有定位的自己（或北京基准），避免落在空白海域
    final st = widget.state;
    if (st.myHasFix && st.myLat != null && st.myLng != null) {
      _pan = _panFor(st.myLat!, st.myLng!, _zoom);
    } else {
      _pan = Offset.zero;
    }
    // 新进群先拉一份别人的图层
    st.requestStrategySnapshot(_gc);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onAnim() {
    setState(() {
      _zoom = _fromZoom + (_toZoom - _fromZoom) * _anim.value;
      _pan = Offset.lerp(_fromPan, _toPan, _anim.value)!;
    });
  }

  /// 平滑把某个经纬度居中（导航）。
  void _navigateTo(double lat, double lng, {double? zoom}) {
    final z = zoom ?? math.max(_zoom, 14.0);
    _fromZoom = _zoom;
    _fromPan = _pan;
    _toZoom = z;
    _toPan = _panFor(lat, lng, z);
    _anim.forward(from: 0);
  }

  /// 导航到主地图并聚焦（把该点包装成 Station 复用现有“台站列表 → 地图定位”）。
  void _openInTrackMap(StrategyItem it) {
    widget.state.focusOnMap(
      Station(
        call: it.label.isEmpty ? it.id : it.label,
        symbol: _navSymbol(it.kind),
        lat: it.lat,
        lng: it.lng,
        lastHeard: DateTime.now(),
        status: St.moving,
      ),
    );
    Navigator.pop(context);
  }

  // ─── 交互 ───

  void _onMapTap(Offset local) {
    final (lat, lng) = _screenToLatLng(local);
    switch (_tool) {
      case _Tool.pan:
        // 先看有没有点中元素（容差 22px）
        final hit = _hitTest(local);
        setState(() => _selected = hit);
        if (hit != null) {
          _navigateTo(hit.lat, hit.lng, zoom: _zoom); // 居中到该元素
          _showItemSheet(hit);
        }
        return;
      case _Tool.point:
        _addPoint(lat, lng, StrategyKind.point);
        return;
      case _Tool.rally:
        _addPoint(lat, lng, StrategyKind.rally);
        return;
      case _Tool.circle:
        _askCircle(lat, lng);
        return;
      case _Tool.line:
        setState(() => _draft.add((lat, lng)));
        return;
    }
  }

  /// 命中测试：找离点击最近、且在容差内的元素。
  StrategyItem? _hitTest(Offset local) {
    StrategyItem? best;
    var bestD = 26.0;
    for (final it in widget.state.strategyOf(_gc)) {
      final pts = it.kind == StrategyKind.line && it.path.isNotEmpty
          ? it.path
          : [(it.lat, it.lng)];
      for (final p in pts) {
        final d = (_toScreen(p.$1, p.$2) - local).distance;
        if (d < bestD) {
          bestD = d;
          best = it;
        }
      }
    }
    return best;
  }

  void _addPoint(double lat, double lng, StrategyKind kind) {
    _promptLabel(
      title: kind == StrategyKind.rally
          ? S.of(context).strategyAddRally
          : S.of(context).strategyAddPoint,
      initial: '',
      onOk: (label, _) {
        final ok = widget.state.putStrategy(
          _gc,
          kind,
          lat: lat,
          lng: lng,
          label: label,
        );
        _toast(ok
            ? S.of(context).strategyShared
            : S.of(context).strategySendFailed);
      },
    );
  }

  void _askCircle(double lat, double lng) {
    final ctrl = TextEditingController(text: '800');
    final nameCtrl = TextEditingController();
    var ci = -1;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(S.of(ctx).strategyAddCircle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: S.of(ctx).strategyRadius,
                  hintText: S.of(ctx).strategyRadiusHint,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: S.of(ctx).strategyLabel,
                  hintText: S.of(ctx).strategyLabelHint,
                ),
              ),
              const SizedBox(height: 10),
              Text(S.of(ctx).strategyColor, style: ts(12, w: FontWeight.w600)),
              const SizedBox(height: 6),
              _pickColor(ci, (v) => setDialogState(() => ci = v)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.of(ctx).cancel),
            ),
            FilledButton(
              onPressed: () {
                final r = int.tryParse(ctrl.text.trim()) ?? 800;
                Navigator.pop(ctx);
                final ok = widget.state.putStrategy(
                  _gc,
                  StrategyKind.circle,
                  lat: lat,
                  lng: lng,
                  radiusM: r.clamp(20, StrategyProto.maxRadiusM),
                  label: nameCtrl.text.trim(),
                  colorIndex: ci,
                );
                _toast(ok
                    ? S.of(context).strategyShared
                    : S.of(context).strategySendFailed);
              },
              child: Text(S.of(ctx).ok),
            ),
          ],
        ),
      ),
    );
  }

  void _promptLabel({
    required String title,
    required String initial,
    required void Function(String label, int colorIndex) onOk,
    bool showColor = false,
    int initialColor = -1,
  }) {
    final ctrl = TextEditingController(text: initial);
    var ci = initialColor;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: StrategyProto.maxLabelLen,
                decoration: InputDecoration(hintText: S.of(ctx).strategyLabelHint),
              ),
              if (showColor) ...[
                const SizedBox(height: 4),
                Text(S.of(ctx).strategyColor, style: ts(12, w: FontWeight.w600)),
                const SizedBox(height: 6),
                _pickColor(ci, (v) => setDialogState(() => ci = v)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.of(ctx).cancel),
            ),
            FilledButton(
              onPressed: () {
                final v = ctrl.text.trim();
                Navigator.pop(ctx);
                onOk(v, ci);
              },
              child: Text(S.of(ctx).ok),
            ),
          ],
        ),
      ),
    );
  }

  /// 颜色选择行：默认 + 调色板。用于线/圈（[StrategyProto.palette] 全网一致）。
  Widget _pickColor(int value, ValueChanged<int> onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (var i = -1; i < StrategyProto.palette.length; i++)
          GestureDetector(
            onTap: () => onPick(i),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: i < 0 ? C.greyLight : StrategyProto.colorAt(i),
                shape: BoxShape.circle,
                border: Border.all(
                  color: value == i ? C.black : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: i < 0
                  ? Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white)
                  : (value == i
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white)
                      : null),
            ),
          ),
      ],
    );
  }

  void _finishLine() {
    if (_draft.length < 2) {
      _toast(S.of(context).strategyNeedTwoPoints);
      return;
    }
    _promptLabel(
      title: S.of(context).strategyAddLine,
      initial: '',
      showColor: true,
      onOk: (label, colorIndex) {
        final ok = widget.state.putStrategy(
          _gc,
          StrategyKind.line,
          lat: _draft.first.$1,
          lng: _draft.first.$2,
          path: List.of(_draft),
          label: label,
          colorIndex: colorIndex,
        );
        if (ok) {
          setState(() {
            _draft.clear();
            _tool = _Tool.pan;
          });
          _toast(S.of(context).strategyShared);
        } else {
          _toast(S.of(context).strategySendFailed);
        }
      },
    );
  }

  void _showItemSheet(StrategyItem it) {
    final mine = it.owner == widget.state.myCall.toUpperCase();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MaterialSurface(
        radius: 24,
        topOnly: true,
        child: Container(
          decoration: BoxDecoration(
            color: C.sheetFill,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_iconOf(it.kind), color: _itemColorOf(it), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.label.isEmpty
                                ? _kindName(ctx, it.kind)
                                : it.label,
                            style: ts(16, w: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${S.of(ctx).strategyItemOf(it.owner)} · '
                            '${it.lat.toStringAsFixed(5)}, '
                            '${it.lng.toStringAsFixed(5)}',
                            style: ts(11, c: C.slate),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _actionBtn(
                        ctx,
                        Icons.navigation_rounded,
                        S.of(ctx).strategyNavigate,
                        C.blue,
                        () {
                          Navigator.pop(ctx);
                          _openInTrackMap(it);
                        },
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionBtn(
                          ctx,
                          Icons.edit_rounded,
                          S.of(ctx).strategyEditInfo,
                          C.orange,
                          () {
                            Navigator.pop(ctx);
                            _editItem(it);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionBtn(
                          ctx,
                          Icons.delete_rounded,
                          S.of(ctx).strategyDeleteItem,
                          C.red,
                          () {
                            Navigator.pop(ctx);
                            widget.state.deleteStrategy(_gc, it.id);
                            setState(() => _selected = null);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 编辑附带的名称 / 圈半径。实用点：改了名字立刻同步给全群。
  void _editItem(StrategyItem it) {
    final nameCtrl = TextEditingController(text: it.label);
    final rCtrl = TextEditingController(
      text: it.kind == StrategyKind.circle ? '${it.radiusM}' : '',
    );
    final isLine = it.kind == StrategyKind.line;
    final isCircle = it.kind == StrategyKind.circle;
    var ci = it.colorIndex;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(S.of(ctx).strategyEditInfo),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                maxLength: StrategyProto.maxLabelLen,
                decoration: InputDecoration(
                  labelText: S.of(ctx).strategyLabel,
                  hintText: S.of(ctx).strategyLabelHint,
                ),
              ),
              if (isCircle)
                TextField(
                  controller: rCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: S.of(ctx).strategyRadius,
                    hintText: S.of(ctx).strategyRadiusHint,
                  ),
                ),
              if (isLine || isCircle) ...[
                const SizedBox(height: 8),
                Text(S.of(ctx).strategyColor, style: ts(12, w: FontWeight.w600)),
                const SizedBox(height: 6),
                _pickColor(ci, (v) => setDialogState(() => ci = v)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.of(ctx).cancel),
            ),
            FilledButton(
              onPressed: () {
                final r = int.tryParse(rCtrl.text.trim()) ?? it.radiusM;
                Navigator.pop(ctx);
                final ok = widget.state.putStrategy(
                  _gc,
                  it.kind,
                  lat: it.lat,
                  lng: it.lng,
                  id: it.id,
                  radiusM: isCircle
                      ? r.clamp(20, StrategyProto.maxRadiusM)
                      : 0,
                  path: it.path,
                  label: nameCtrl.text.trim(),
                  colorIndex: ci,
                );
                _toast(ok
                    ? S.of(context).strategyShared
                    : S.of(context).strategySendFailed);
              },
              child: Text(S.of(ctx).ok),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClear() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(S.of(ctx).strategyClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(ctx).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.red),
            onPressed: () {
              Navigator.pop(ctx);
              widget.state.clearStrategy(_gc);
              setState(() => _selected = null);
            },
            child: Text(S.of(ctx).strategyClearAll),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  /// 导航到主地图时用的 APRS 符号（point / rally / circle / line 各有其形）。
  String _navSymbol(StrategyKind k) => switch (k) {
    StrategyKind.point => '>',
    StrategyKind.rally => 'f',
    StrategyKind.circle => 'A',
    StrategyKind.line => '>',
  };

  IconData _iconOf(StrategyKind k) => switch (k) {
    StrategyKind.point => Icons.place_rounded,
    StrategyKind.line => Icons.timeline_rounded,
    StrategyKind.circle => Icons.circle_outlined,
    StrategyKind.rally => Icons.flag_rounded,
  };

  Color _colorOf(StrategyKind k) => switch (k) {
    StrategyKind.point => C.blue,
    StrategyKind.line => C.orange,
    StrategyKind.circle => C.red,
    StrategyKind.rally => C.green,
  };

  /// State 层的「元素实际颜色」：显式选色的线/圈用元素色，否则用类型默认色。
  /// 与 painter 内的 `_itemColor` 同规则（两处都改才一致）。
  Color _itemColorOf(StrategyItem it) =>
      it.colorIndex < 0 ? _colorOf(it.kind) : it.color;

  String _kindName(BuildContext ctx, StrategyKind k) => switch (k) {
    StrategyKind.point => S.of(ctx).strategyAddPoint,
    StrategyKind.line => S.of(ctx).strategyAddLine,
    StrategyKind.circle => S.of(ctx).strategyAddCircle,
    StrategyKind.rally => S.of(ctx).strategyAddRally,
  };

  Widget _actionBtn(
    BuildContext ctx,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text(label,
                style: ts(11, c: color, w: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ─── 构建 ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            _size = size;
            return Stack(
              children: [
                _mapLayer(size),
                _topBar(),
                _hintBar(),
                _toolbar(),
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
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          TileMapView(
            centerLat: _base.$1,
            centerLng: _base.$2,
            zoom: _zoom,
            pan: _pan,
            onPan: (d) => setState(() {
              _anim.stop();
              _pan += d;
            }),
            onViewChanged: (z, p) => setState(() {
              _anim.stop();
              _zoom = z;
              _pan = p;
            }),
            onZoomRequest: (z, p) => setState(() {
              _anim.stop();
              _zoom = z;
              _pan = p;
            }),
            onTap: _onMapTap,
            mapType: _mapType,
            cacheEnabled: widget.state.tileCacheOn,
            offlineOnly: widget.state.offlineOnly,
          ),
          IgnorePointer(
            child: CustomPaint(
              size: size,
              painter: _StrategyPainter(
                items: widget.state.strategyOf(_gc),
                draft: _draft,
                selected: _selected,
                teammates: _teammatesNow(),
                toScreen: _toScreen,
                pixelsPerDegree: _pixelsPerDegree(),
                colors: _StrategyColors(
                  point: C.blue,
                  line: C.orange,
                  circle: C.red,
                  rally: C.green,
                  label: C.white,
                  labelBg: C.black.withValues(alpha: 0.62),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 每像素对应的纬度度数（用于把半径米数换算成屏幕像素，近似足够）。
  double _pixelsPerDegree() {
    final a = _toScreen(0, 0);
    final b = _toScreen(1, 0);
    final d = (b - a).distance;
    return d <= 0 ? 1 : d;
  }

  Widget _topBar() {
    return Positioned(
      top: 8 + MediaQuery.of(context).padding.top,
      left: 12,
      right: 12,
      child: Row(
        children: [
          _roundBtn(Icons.arrow_back_rounded, () => Navigator.pop(context)),
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
                    S.of(context).strategyMap,
                    style: ts(14, c: Colors.white, w: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.groupName,
                    style: ts(10, c: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _roundBtn(Icons.sync_rounded,
              () => widget.state.requestStrategySnapshot(_gc)),
          const SizedBox(width: 8),
          // 重发：射频下丢包是静默的，给一个明确的手动动作（见 retryStrategy）。
          // 有未确认帧时高亮并只重发那些；没有时重发全量。
          _roundBtn(
            Icons.replay_rounded,
            _onRetry,
            color: widget.state.strategyAckPending(_gc) > 0
                ? C.orange
                : Colors.white,
          ),
          const SizedBox(width: 8),
          _roundBtn(
            Icons.delete_sweep_rounded,
            _confirmClear,
            color: C.red,
          ),
        ],
      ),
    );
  }

  void _onRetry() {
    final pending = widget.state.strategyAckPending(_gc);
    final n = pending == 0
        ? widget.state.retryStrategy(_gc, all: true)
        : widget.state.retryStrategy(_gc);
    if (n == 0) {
      _toast(S.of(context).strategyRetryNone);
    } else {
      _toast(pending == 0
          ? S.of(context).strategyRetryAll
          : S.of(context).strategyRetry);
    }
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
    String hint;
    switch (_tool) {
      case _Tool.line:
        hint = '${S.of(context).strategyLineHint}（${_draft.length}）';
        break;
      case _Tool.circle:
        hint = S.of(context).strategyAddCircle;
        break;
      case _Tool.rally:
        hint = S.of(context).strategyAddRally;
        break;
      case _Tool.point:
        hint = S.of(context).strategyAddPoint;
        break;
      case _Tool.pan:
        hint = widget.state.strategyOf(_gc).isEmpty
            ? S.of(context).strategyEmpty
            : S.of(context).strategyMapHint;
        break;
    }
    // 射频下把「有几帧没被确认」直接摆出来：丢包是静默的，不提示就等于
    // 让用户以为发成功了；点右上角重发即可。
    final pending = widget.state.strategyAckPending(_gc);
    if (pending > 0) {
      hint = '${S.of(context).strategyAckPending(pending)}\n$hint';
    }
    return Positioned(
      left: 12,
      right: 12,
      bottom: 92 + MediaQuery.of(context).padding.bottom,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: C.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            hint,
            style: ts(11, c: Colors.white, w: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    Widget t(_Tool tool, IconData icon, String label, Color color,
        {VoidCallback? onTap}) {
      final on = _tool == tool;
      return Expanded(
        child: GestureDetector(
          onTap: onTap ??
              () => setState(() {
                    _tool = tool;
                    if (tool != _Tool.line) _draft.clear();
                  }),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? color : C.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? color : C.border),
              boxShadow: elev1(),
            ),
            child: Column(
              children: [
                Icon(icon, size: 20, color: on ? Colors.white : color),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: ts(10,
                      c: on ? Colors.white : C.slate, w: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: 8,
      right: 8,
      bottom: 10 + MediaQuery.of(context).padding.bottom,
      child: MaterialSurface(
        radius: 18,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: C.sheetFill,
            borderRadius: BorderRadius.circular(18),
            boxShadow: elev3(),
          ),
          child: Row(
            children: [
              t(_Tool.point, Icons.place_rounded,
                  S.of(context).strategyAddPoint, C.blue),
              // 划线工具：已在划线中就点它「完成」，否则进入划线模式
              t(_Tool.line, Icons.timeline_rounded,
                  _tool == _Tool.line
                      ? S.of(context).done
                      : S.of(context).strategyAddLine,
                  C.orange,
                  onTap: () {
                    if (_tool == _Tool.line) {
                      _finishLine();
                    } else {
                      setState(() => _tool = _Tool.line);
                    }
                  }),
              t(_Tool.circle, Icons.circle_outlined,
                  S.of(context).strategyAddCircle, C.red),
              t(_Tool.rally, Icons.flag_rounded,
                  S.of(context).strategyAddRally, C.green),
              t(_Tool.pan, Icons.pan_tool_alt_rounded,
                  S.of(context).strategyPan, C.slate),
            ],
          ),
        ),
      ),
    );
  }
}

/// 画图层参数（颜色一次性传入，避免 painter 里反复读主题）。
class _StrategyColors {
  final Color point, line, circle, rally, label, labelBg;
  const _StrategyColors({
    required this.point,
    required this.line,
    required this.circle,
    required this.rally,
    required this.label,
    required this.labelBg,
  });
}

class _StrategyPainter extends CustomPainter {
  final List<StrategyItem> items;
  final List<(double, double)> draft;
  final StrategyItem? selected;
  final Offset Function(double lat, double lng) toScreen;
  final double pixelsPerDegree;
  final _StrategyColors colors;

  /// 群成员里报得到位置的台站（队友）。位置来自普通 APRS 信标，与策略协议无关。
  final List<Station> teammates;

  _StrategyPainter({
    required this.items,
    required this.draft,
    required this.selected,
    required this.toScreen,
    required this.pixelsPerDegree,
    required this.colors,
    this.teammates = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 队友画在最下层：策略元素（标点/线/圈）压在其上，避免标记互相遮挡
    for (final s in teammates) {
      _paintTeammate(canvas, s);
    }
    for (final it in items) {
      _paintItem(canvas, it, it.key == selected?.key);
    }
    _paintDraft(canvas);
  }

  /// 队友标记：圆点 + 呼号 + **方位角小角标**。
  ///
  /// 方位角取信标里的航向（[Station.course]，正北为 0°、顺时针）。静止或无航向
  /// 时 course 为 null —— 不画角标（画成朝北会撒谎）。角标是一个沿航向的小三角，
  /// 贴在圆点外缘；旁边再写度数，扫一眼就知道队友在往哪走。
  void _paintTeammate(Canvas canvas, Station s) {
    final c = toScreen(s.lat, s.lng);
    // 白色描边 + 青色的圆：与策略元素（方/旗/圆）在形状和颜色上都区分得开
    canvas.drawCircle(c, 10, Paint()..color = Colors.white);
    canvas.drawCircle(c, 7.5, Paint()..color = C.cyan);
    // 呼号标签（画在点下方，避免与方位角角标重叠）
    _chip(canvas, s.call, c + const Offset(0, 12));
    final course = s.course;
    if (course != null) {
      _bearingBadge(canvas, c, course);
    }
  }

  /// 方位角小角标：沿 [courseDeg] 方向、贴在圆点外缘的小三角 + 度数。
  void _bearingBadge(Canvas canvas, Offset c, double courseDeg) {
    final rad = courseDeg * math.pi / 180.0;
    // 屏幕坐标：正北（0°）朝上（-y），东（90°）朝右（+x）
    final dir = Offset(math.sin(rad), -math.cos(rad));
    const r = 15.0;
    final tip = c + dir * r;
    final base = c + dir * (r - 7);
    // 以方向为轴画一个小等腰三角（绕 tip 的前进方向转 90°）
    final perp = Offset(-dir.dy, dir.dx);
    final p1 = base + perp * 4.5;
    final p2 = base - perp * 4.5;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(path, Paint()..color = C.orange);
    // 度数：贴在角标外侧（沿同一方向再挪一点），小字
    _chip(canvas, '${courseDeg.round()}°', tip + dir * 10);
  }

  /// 小圆角标签（白底黑字），用于呼号/方位角。
  void _chip(Canvas canvas, String text, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.black,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: tp.width + 8,
        height: tp.height + 3,
      ),
      const Radius.circular(5),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.white.withValues(alpha: 0.85));
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintDraft(Canvas canvas) {
    if (draft.isEmpty) return;
    final paint = Paint()
      ..color = colors.line.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (draft.length > 1) {
      final path = Path();
      final p0 = toScreen(draft.first.$1, draft.first.$2);
      path.moveTo(p0.dx, p0.dy);
      for (final p in draft.skip(1)) {
        final s = toScreen(p.$1, p.$2);
        path.lineTo(s.dx, s.dy);
      }
      canvas.drawPath(path, paint);
    }
    for (final p in draft) {
      canvas.drawCircle(toScreen(p.$1, p.$2), 4,
          Paint()..color = colors.line);
    }
  }

  /// 线/圈的实际颜色：显式选过色就用元素色，否则沿用主题里的默认色。
  ///
  /// 不直接在未选色时回落到 [StrategyItem.color]（调色板首色）：调色板是
  /// 协议的一部分，颜色顺序不能改，而主题默认色（线橙/圈红）与调色板首色
  /// 并不相同 —— 直接回落会让所有历史元素悄悄变个颜色。
  Color _itemColor(StrategyItem it, Color fallback) =>
      it.colorIndex < 0 ? fallback : it.color;

  void _paintItem(Canvas canvas, StrategyItem it, bool isSel) {
    switch (it.kind) {
      case StrategyKind.line:
        if (it.path.length < 2) return;
        final paint = Paint()
          ..color = _itemColor(it, colors.line)
          ..strokeWidth = isSel ? 5 : 3.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final path = Path();
        final p0 = toScreen(it.path.first.$1, it.path.first.$2);
        path.moveTo(p0.dx, p0.dy);
        for (final p in it.path.skip(1)) {
          final s = toScreen(p.$1, p.$2);
          path.lineTo(s.dx, s.dy);
        }
        canvas.drawPath(path, paint);
        _label(canvas, it, toScreen(it.path.first.$1, it.path.first.$2));
        return;
      case StrategyKind.circle:
        final c = toScreen(it.lat, it.lng);
        final rPx = it.radiusM / 111320.0 * pixelsPerDegree;
        final cc = _itemColor(it, colors.circle);
        final fill = Paint()
          ..color = cc.withValues(alpha: 0.14)
          ..style = PaintingStyle.fill;
        final stroke = Paint()
          ..color = cc
          ..strokeWidth = isSel ? 3.5 : 2
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(c, rPx, fill);
        canvas.drawCircle(c, rPx, stroke);
        canvas.drawCircle(c, 4, Paint()..color = cc);
        _label(canvas, it, c);
        return;
      case StrategyKind.point:
        _pin(canvas, toScreen(it.lat, it.lng), colors.point, isSel,
            Icons.place_rounded, it);
        return;
      case StrategyKind.rally:
        _pin(canvas, toScreen(it.lat, it.lng), colors.rally, isSel,
            Icons.flag_rounded, it);
        return;
    }
  }

  /// 用「圆 + 图标」画一个标记（不引 assets，走 Material Icons 字形）。
  void _pin(Canvas canvas, Offset c, Color color, bool isSel, IconData icon,
      StrategyItem it) {
    if (isSel) {
      canvas.drawCircle(c, 18,
          Paint()..color = color.withValues(alpha: 0.25));
    }
    canvas.drawCircle(c, 11, Paint()..color = Colors.white);
    canvas.drawCircle(c, 9, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 11,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    _label(canvas, it, c);
  }

  void _label(Canvas canvas, StrategyItem it, Offset anchor) {
    final text = it.label.isEmpty ? it.owner : '${it.label} · ${it.owner}';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 10,
          color: colors.label,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(anchor.dx - tp.width / 2 - 5, anchor.dy - 34,
          tp.width + 10, tp.height + 4),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = colors.labelBg);
    tp.paint(canvas, Offset(anchor.dx - tp.width / 2, anchor.dy - 32));
  }

  @override
  bool shouldRepaint(covariant _StrategyPainter old) =>
      old.items != items ||
      old.draft != draft ||
      old.selected != selected ||
      old.teammates != teammates ||
      old.pixelsPerDegree != pixelsPerDegree;
}
