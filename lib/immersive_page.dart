import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'coord.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'tile_map.dart';
import 'widgets.dart';

/// ─── 沉浸地图（导航风格）───
///
/// 与「追踪页」的区别：
/// - **不做左侧大面板**，全部信息压缩到**四角 HUD**，把地图还给用户
/// - **只以自己为中心**（其它台站仅作淡色背景参照，不可点击跟随）
/// - **地图跟随航行方向**（Heading-Up）：把地图层整体旋转 -航向，
///   使前进方向始终朝屏幕上方；停止移动或关闭开关时平滑回到正北朝上
/// - 竖屏 / 横屏均可用：四角定位 + 安全区内边距，横屏只是视野更宽
///
/// 四角分工：
///   左上：返回 + 定位状态（来源 / 网格）
///   右上：竖向操作列（航向朝上、跟随我、图源、缩放）
///   左下：**信标发送倒计时** + 连接状态 + 累计发送数
///   右下：**速度大字** + 航向 + 海拔 + 坐标
class ImmersiveMapPage extends StatefulWidget {
  final AppState state;
  const ImmersiveMapPage({super.key, required this.state});

  @override
  State<ImmersiveMapPage> createState() => _ImmersiveMapPageState();
}

class _ImmersiveMapPageState extends State<ImmersiveMapPage>
    with SingleTickerProviderStateMixin {
  static const _baseLat = 39.9042;
  static const _baseLng = 116.4074;
  static final (double, double) _gcjBase = Gcj.wgsToGcj(_baseLat, _baseLng);

  double _zoom = 15.0;

  /// 手动平移量（仅 [_follow] 为 false 时生效；跟随时每相由我的位置算出）
  Offset _manualPan = Offset.zero;
  bool _follow = true;

  /// 投影基准尺寸 = 画布对角线（旋转后仍铺满屏幕，见 [_mapLayer]）
  Size _canvas = Size.zero;

  bool _headingUp = true;
  /// 屏幕展示用连续角度（弧度，-航向）；见 [_nearest] 保证跨 0/360 不绕远
  double _rot = 0;
  late final Ticker _ticker;

  MapType get _mapType {
    for (final m in MapType.values) {
      if (m.name == widget.state.mapType) return m;
    }
    return MapType.gaode;
  }

  bool get _isGcj => isGcjMapType(_mapType);
  (double, double) get _base => _isGcj ? _gcjBase : (_baseLat, _baseLng);

  @override
  void initState() {
    super.initState();
    // 连续 ticker：把展示角度平滑逼近目标角度（GPS 每秒一帧，直接跳会抖动）
    _ticker = createTicker(_onTick)..start();
    // 导航风格需要横屏：临时解锁，退出后恢复
    widget.state.unlockLandscape();
  }

  @override
  void dispose() {
    _ticker.dispose();
    widget.state.restoreOrientation();
    super.dispose();
  }

  /// 取与 [ref] 最接近的等价角（避免 359°→1° 反向绕一整圈）
  static double _nearest(double target, double ref) {
    var d = (target - ref) % (2 * math.pi);
    if (d > math.pi) d -= 2 * math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    return ref + d;
  }

  void _onTick(Duration _) {
    final st = widget.state;
    final moving = (st.mySpeed ?? 0) > 0.5;
    final course = st.myCourse;
    double target;
    if (_headingUp && st.myHasFix && course != null && course >= 0 && moving) {
      // 前进方向朝上：地图旋转 -航向（Flutter 正角为顺时针）
      target = _nearest(-course * math.pi / 180, _rot);
    } else {
      target = _nearest(0, _rot);
    }
    final diff = target - _rot;
    if (diff.abs() < 0.0008) {
      if (_rot != target) setState(() => _rot = target);
      return;
    }
    setState(() => _rot += diff * 0.16);
  }

  (double, double) _tc(double lat, double lng) =>
      _isGcj ? Gcj.wgsToGcj(lat, lng) : (lat, lng);

  /// 让指定经纬度落在画布中心所需的 pan
  Offset _panFor(double lat, double lng, double zoom) {
    final b = _base;
    final g = _tc(lat, lng);
    final c = MapProj.latLngToPx(b.$1, b.$2, zoom);
    final p = MapProj.latLngToPx(g.$1, g.$2, zoom);
    return c - p;
  }

  /// 当前生效的 pan：跟随时由我的位置实时算出（不写 state，避免 build 中 setState）
  Offset get _pan {
    final st = widget.state;
    if (_follow && st.myHasFix && st.myLat != null && st.myLng != null) {
      return _panFor(st.myLat!, st.myLng!, _zoom);
    }
    return _manualPan;
  }

  Offset _toScreen(double lat, double lng) {
    final t = _tc(lat, lng);
    final b = _base;
    final c = MapProj.latLngToPx(b.$1, b.$2, _zoom);
    final p = MapProj.latLngToPx(t.$1, t.$2, _zoom);
    final pan = _pan;
    return Offset(
      p.dx - c.dx + _canvas.width / 2 + pan.dx,
      p.dy - c.dy + _canvas.height / 2 + pan.dy,
    );
  }

  void _recenter() {
    setState(() {
      _follow = true;
      _manualPan = Offset.zero;
    });
  }

  void _zoomBy(double dz) {
    final z = (_zoom + dz).clamp(3.0, 19.0);
    if (z == _zoom) return;
    setState(() {
      if (!_follow) {
        // 手动模式下保持视野中心不动：pan 随缩放等比放大
        _manualPan = _manualPan * math.pow(2, z - _zoom).toDouble();
      }
      _zoom = z;
    });
  }

  Future<void> _pickMapType() async {
    final st = widget.state;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(S.of(ctx).mapType, style: ts(15, w: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in MapType.values)
                GestureDetector(
                  onTap: () {
                    st.setMapType(t.name);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: st.mapType == t.name ? C.blue : C.bgSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: st.mapType == t.name ? C.blue : C.border),
                    ),
                    child: Text(t.label,
                        style: ts(12,
                            c: st.mapType == t.name ? Colors.white : C.slate,
                            w: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    return Scaffold(
      backgroundColor: C.black,
      body: ListenableBuilder(
        listenable: st,
        builder: (context, _) => LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            return Stack(children: [
              _mapLayer(size),
              // ── 四角 HUD（不随地图旋转，始终水平可读）──
              _hud(size, st),
            ]);
          },
        ),
      ),
    );
  }

  /// 地图层：旋转 + 对角线放大，保证任意角度都不露白边
  Widget _mapLayer(Size size) {
    // 首帧尺寸可能为 0：此时直接跳过，避免把 0 尺寸传给地图与投影
    if (size.width <= 0 || size.height <= 0) {
      return const Positioned.fill(child: SizedBox.shrink());
    }
    // 画布取对角线长度：旋转后其内接矩形仍能覆盖整个屏幕
    final diag =
        math.sqrt(size.width * size.width + size.height * size.height);
    _canvas = Size(diag, diag);
    final pan = _pan;
    return Positioned.fill(
      child: ClipRect(
        child: Transform.rotate(
          angle: _rot,
          child: OverflowBox(
            minWidth: diag,
            maxWidth: diag,
            minHeight: diag,
            maxHeight: diag,
            child: SizedBox(
              width: diag,
              height: diag,
              child: Stack(fit: StackFit.expand, children: [
                TileMapView(
                  centerLat: _base.$1,
                  centerLng: _base.$2,
                  zoom: _zoom,
                  pan: pan,
                  onPan: (d) => setState(() {
                    _follow = false;
                    _manualPan = _manualPan + d;
                  }),
                  onViewChanged: (z, p) => setState(() {
                    _follow = false;
                    _zoom = z;
                    _manualPan = p;
                  }),
                  onZoomRequest: (z, p) => setState(() {
                    _zoom = z;
                    if (!_follow) _manualPan = p;
                  }),
                  onTap: (_) {},
                  mapType: _mapType,
                ),
                IgnorePointer(
                  child: CustomPaint(
                    size: _canvas,
                    painter: _ImmersivePainter(
                      me: _meStation(),
                      others: _otherStations(),
                      toScreen: _toScreen,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// 把「我」包装成 Station 以便复用绘制（无定位时返回 null）
  Station? _meStation() {
    final st = widget.state;
    if (!st.myHasFix || st.myLat == null || st.myLng == null) return null;
    return Station(
      call: st.myFullCall,
      symbol: st.beaconSymbolNow,
      lat: st.myLat!,
      lng: st.myLng!,
      alt: st.myAlt,
      speed: st.mySpeed,
      course: st.myCourse,
      lastHeard: DateTime.now(),
      status: St.moving,
    );
  }

  /// 其它台站仅作淡色参照（不参与交互）。
  ///
  /// **不要过滤离线台站** —— 主地图（`_visible`）也只按接收范围/筛选过滤，
  /// 离线台站照样显示（灰显）。此前这里多加了 `!= offline` 判断，
  /// 导致台站数据较旧时（全部处于离线）地图上一个点都不画。
  /// 离线台站改由绘制层用更暗的颜色处理：既保留层级，也不会整片消失。
  List<Station> _otherStations() {
    final st = widget.state;
    final me = st.myFullCall.toUpperCase();
    return st.stations
        .where((s) =>
            s.call.toUpperCase() != me &&
            st.stationAllowedFor(s) &&
            !(s.lat == 0 && s.lng == 0))
        .take(400)
        .toList();
  }

  // ════════════════════════ HUD ════════════════════════

  Widget _hud(Size size, AppState st) {
    final pad = MediaQuery.of(context).padding;
    final s = S.of(context);
    const gap = 10.0;
    return Stack(children: [
      // ── 左上：返回 + 定位状态 ──
      Positioned(
        left: gap + pad.left,
        top: gap + pad.top,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _roundBtn(Icons.arrow_back_rounded, () => Navigator.pop(context),
                tooltip: s.back),
            const SizedBox(height: 8),
            _chip(
              icon: st.myHasFix
                  ? Icons.gps_fixed_rounded
                  : Icons.gps_off_rounded,
              color: st.myHasFix ? C.green : C.yellow,
              value: st.myHasFix ? st.locStatus : s.unlocated,
              sub: st.myHasFix && st.myLat != null ? st.myGrid : null,
            ),
          ],
        ),
      ),

      // ── 右上：操作列 ──
      Positioned(
        right: gap + pad.right,
        top: gap + pad.top,
        child: Column(children: [
          _roundBtn(
            _headingUp
                ? Icons.explore_rounded
                : Icons.navigation_outlined,
            () => setState(() => _headingUp = !_headingUp),
            tooltip: _headingUp ? s.headingUp : s.northUp,
            active: _headingUp,
          ),
          const SizedBox(height: 8),
          _roundBtn(Icons.my_location_rounded, _recenter,
              tooltip: s.followMe, active: _follow),
          const SizedBox(height: 8),
          _roundBtn(Icons.map_rounded, _pickMapType, tooltip: s.mapType),
          const SizedBox(height: 8),
          _roundBtn(Icons.add_rounded, () => _zoomBy(1)),
          const SizedBox(height: 8),
          _roundBtn(Icons.remove_rounded, () => _zoomBy(-1)),
        ]),
      ),

      // ── 左下：信标发送倒计时 ──
      Positioned(
        left: gap + pad.left,
        bottom: gap + pad.bottom,
        child: _beaconCard(st, s),
      ),

      // ── 右下：速度 / 航向 / 海拔 ──
      Positioned(
        right: gap + pad.right,
        bottom: gap + pad.bottom,
        child: _speedCard(st, s),
      ),
    ]);
  }

  /// 左下：上报倒计时（主）+ 连接状态 + 累计次数
  Widget _beaconCard(AppState st, AppLocalizations s) {
    final on = st.beaconEnabled;
    final col = st.connected ? C.green : C.grey;
    return _card(
      children: [
        Row(children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: col, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(st.connected ? s.connected : s.disconnected,
              style: ts(10.5, w: FontWeight.w700, c: Colors.white)),
        ]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic, children: [
          Text(st.nextBeaconIn,
              style: ts(26, w: FontWeight.w900, c: Colors.white, ls: -0.5)),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(s.beaconCountdown,
                style: ts(10, c: Colors.white.withValues(alpha: 0.7))),
          ),
        ]),
        const SizedBox(height: 2),
        Text('${s.beaconsSent} ${st.beaconsSent}${on ? '' : ' · ${s.beaconOff}'}',
            style: ts(9.5, c: Colors.white.withValues(alpha: 0.6))),
      ],
    );
  }

  /// 右下：速度大字 + 航向 / 海拔 / 坐标
  Widget _speedCard(AppState st, AppLocalizations s) {
    final spd = st.mySpeed;
    final alt = st.myAlt;
    final crsRaw = st.myCourse;
    // 收敛成 double? 后用**直接 null 判断**（可空提升只对直接条件生效）
    final crs = (crsRaw != null && crsRaw >= 0) ? crsRaw : null;
    return _card(
      alignEnd: true,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic, children: [
          Text(spd == null ? '--' : spd.toStringAsFixed(0),
              style: ts(30, w: FontWeight.w900, c: Colors.white, ls: -1)),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('km/h',
                style: ts(10, w: FontWeight.w700,
                    c: Colors.white.withValues(alpha: 0.75))),
          ),
        ]),
        const SizedBox(height: 3),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (crs != null) ...[
            // 箭头的语义是「屏幕上的前进方向」：
            // 航向朝上时屏幕上方就是前进方向 → 不旋转；
            // 正北朝上时屏幕上方是正北 → 按航向顺时针旋转。
            // 写 0.0 而非 0：与 double 相乘需同为 double，写 0 会得到 num 而编译失败
            Transform.rotate(
              angle: (_headingUp ? 0.0 : crs) * math.pi / 180,
              child: Icon(Icons.arrow_upward_rounded,
                  size: 13, color: Colors.white.withValues(alpha: 0.9)),
            ),
            const SizedBox(width: 4),
            Text('${crs.toStringAsFixed(0)}°',
                style: ts(11, w: FontWeight.w700, c: Colors.white)),
            const SizedBox(width: 10),
          ],
          Text(alt == null ? '--' : '${alt.toStringAsFixed(0)} m',
              style: ts(11, c: Colors.white.withValues(alpha: 0.8))),
        ]),
        const SizedBox(height: 3),
        Text(
            st.myHasFix && st.myLat != null && st.myLng != null
                ? '${st.myLat!.toStringAsFixed(5)}, ${st.myLng!.toStringAsFixed(5)}'
                : '--',
            style: ts(9.5, c: Colors.white.withValues(alpha: 0.55))),
      ],
    );
  }

  // ── 通用小组件（深色半透明，任何底图上都可读）──

  Widget _card({required List<Widget> children, bool alignEnd = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(minWidth: 116),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required Color color,
    required String value,
    String? sub,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text(value,
            style: ts(10.5, w: FontWeight.w700, c: Colors.white)),
        if (sub != null) ...[
          const SizedBox(width: 6),
          Text(sub,
              style: ts(10, c: Colors.white.withValues(alpha: 0.6))),
        ],
      ]),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap,
      {String? tooltip, bool active = false}) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? C.blue.withValues(alpha: 0.92)
              : Colors.black.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Icon(icon,
            size: 20, color: active ? Colors.white : Colors.white.withValues(alpha: 0.92)),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip, child: btn);
  }
}

/// 沉浸层绘制：我的航向箭头（居中）+ 其它台站淡点 + 我的轨迹
class _ImmersivePainter extends CustomPainter {
  final Station? me;
  final List<Station> others;
  final Offset Function(double lat, double lng) toScreen;

  _ImmersivePainter({
    required this.me,
    required this.others,
    required this.toScreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── 其它台站：小淡点（仅参照，不可交互）──
    // 在线＝常规淡蓝灰；离线＝更暗更小，保持层级但不会「看不见」
    final dotOnline = Paint()..color = C.slate.withValues(alpha: 0.55);
    final dotOffline = Paint()..color = C.slate.withValues(alpha: 0.28);
    for (final s in others) {
      final o = toScreen(s.lat, s.lng);
      if (o.dx < -20 ||
          o.dx > size.width + 20 ||
          o.dy < -20 ||
          o.dy > size.height + 20) {
        continue;
      }
      final offline = s.effectiveStatus == St.offline;
      canvas.drawCircle(
          o, offline ? 2.4 : 3.2, offline ? dotOffline : dotOnline);
    }

    final m = me;
    if (m == null) return;
    final c = toScreen(m.lat, m.lng);

    // ── 我的轨迹 ──
    if (m.track.length > 1) {
      final path = Path();
      var first = true;
      for (final p in m.track) {
        final o = toScreen(p.lat, p.lng);
        if (first) {
          path.moveTo(o.dx, o.dy);
          first = false;
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = C.blue.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── 我的位置：光晕 + 航向箭头 ──
    canvas.drawCircle(c, 20, Paint()..color = C.blue.withValues(alpha: 0.16));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    // 直接 null 判断以启用可空提升（不要用中间 bool 变量）
    final crs = m.course;
    if (crs != null && crs >= 0) canvas.rotate(crs * math.pi / 180);
    // 三角箭头（指向屏幕上方；地图已按 -航向 旋转，故合成后即「朝前」）
    final arrow = Path()
      ..moveTo(0, -13)
      ..lineTo(9, 11)
      ..lineTo(0, 6)
      ..lineTo(-9, 11)
      ..close();
    canvas.drawPath(arrow, Paint()..color = C.blue);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ImmersivePainter old) => true;
}
