import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'guide.dart';
import 'models.dart';
import 'pos_quality.dart';
import 'settings_pages.dart';
import 'state.dart';
import 'widgets.dart';
import 'station_detail.dart';
import 'station_note.dart';
import 'tile_map.dart';
import 'vector_map.dart';
import 'immersive_page.dart';
import 'strategy_map_page.dart';
import 'track_groups_sheet.dart';
import 'coord.dart';
import 'coord_format.dart';
import 'material.dart';

class MapPage extends StatefulWidget {
  final AppState state;
  final String searchQuery;

  /// 底部**被占用**多少高度（像素，自屏幕底算起，**不含**底部安全区）。
  ///
  /// 2.0 布局下地图是整屏的底，底部叠着两件东西：悬浮导航 + 可拖拽的内容面板。
  /// 不告诉地图「下面被占到哪里」，它贴底的「比例尺/坐标条」与「上报横杠」就会
  /// 被压住（表现是「2.0 里这些控件不见了」）。
  ///
  /// 口径为什么要写成「被占用的边界」而不是「让出多少」：调用点里贴底控件的
  /// 位置是 `14 + 安全区 + bottomInset`，只要这里给的是占用边界，控件就永远落在
  /// 它上方 14px —— 面板收起时贴着导航、打开时贴着面板。反过来若语义含糊，
  /// 就会把安全区重复算一次，凭空多出一大段空隙（这正是改这一版时踩到的）。
  /// 顶部**被占用**多少高度（像素，自屏幕顶算起，含顶部安全区）。
  ///
  /// 2.0 布局下外壳在顶上浮了一条搜索/状态栏，而地图自己的信息条、图例、右侧
  /// 工具列、沉浸入口过去全都锚在 `top: 14` —— 不让开就全被压在栏底下
  /// （表现就是「地图页布局混乱」）。外壳把栏高传进来，地图把所有顶部锚点
  /// 整体下移到栏之下；从工具列弹出的两个 Overlay 面板也按它下移。
  final double topInset;

  final double bottomInset;

  /// 左侧**被占用**多少宽度（像素，自屏幕左沿算起，**不含**左侧安全区）。
  ///
  /// 竖屏下左侧没有东西，所以是 0；**横屏**下 2.0 的外壳把导航竖条（以及展开时的
  /// 内容面板）摆在左边，而地图仍是整屏铺满的 —— 不告诉地图，它贴左的控件
  /// （信息条、沉浸入口、底部比例尺/坐标条）就会**压在那张半透明卡片底下**：
  /// 卡是磨砂的，所以不是「被挡住」这么干脆，而是控制条在卡片背后糊成一片，
  /// 看着像渲染坏了。
  ///
  /// 口径与 [bottomInset] 一致：给「被占用的边界」，地图自己再加上安全区。
  final double leftInset;

  /// 当前是否为激活 Tab（首页 IndexedStack 可见页）。非激活时跳过地图重建，
  /// 避免台站上千时后台地图反复 rebuild 造成全局卡顿。
  final bool isActive;

  /// 是否**冻结**（面板展开在它上面时）。
  ///
  /// 与 [isActive] 的区别很关键：
  ///   * `isActive == false` → 整块地图换成 `SizedBox.shrink()`（真的不画了）；
  ///   * `frozen == true`   → **继续画**，但不再产出新的帧：停掉脉冲动画、
  ///     标记继续复用上一次缓存。
  ///
  /// 为什么必须「继续画」：面板开着磨砂时，`BackdropFilter` 要把背后已经画好的
  /// 内容离屏重绘一遍。地图一旦不画了，模糊背后就只剩页面底色 —— 那不叫优化，
  /// 那叫把磨砂弄坏。
  ///
  /// 冻结的实际收益：地图内容不再变化 → 它自己那层 `RepaintBoundary` 的光栅化
  /// 结果被 Flutter 复用 → 面板的模糊改成**采样缓存纹理**，而不是每帧把整张地图
  /// 重新光栅化一遍。这正是「面板一动就卡」的来源。
  final bool frozen;
  const MapPage({
    super.key,
    required this.state,
    this.searchQuery = '',
    this.isActive = true,
    this.frozen = false,
    this.topInset = 0,
    this.bottomInset = 0,
    this.leftInset = 0,
  });
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  // 视图状态：连续 zoom + 像素偏移
  double _zoom = 11.0;
  Offset _pan = Offset.zero;
  bool _showTracks = true;
  bool _heatEnabled = true; // 低缩放热力图开关

  /// 锁定地图中心的**三态**（用户要求把这一颗改成切换）：
  /// 0 关（自由拖动）/ 1 锁定中心·正北朝上 / 2 锁定中心·航向朝上。
  ///
  /// 值与落盘都在 [AppState.mapFollowMode]：用户要求「上次选的航向锁定要能保持」，
  /// 它原来是本页的 State 字段，冷启动就回到 0。
  ///
  /// 与上面那颗「定位」的分工不变：定位是**跳一次**，锁定是**一直跟着** ——
  /// 自己走动（或新定位点到达）时地图跟着走。两种动作会自动解锁：
  /// 拖地图（见下方 Listener）、点了某个台站要聚焦过去（见 [_handleViewFocus]）——
  /// 用户一动手就是要自己看，不该在下一帧被拽回中心。
  int get _followMode => widget.state.mapFollowMode;

  /// 旧口径沿用：`> 0` 就是「锁定中心」。其余引用（拖一下解锁、矢量底图
  /// 跟随）关心的只是「有没有锁」，不用跟着三态一起改。
  bool get _followMe => _followMode > 0;

  /// 航向朝上时的画布转角（弧度，顺时针为正 = -航向）。
  ///
  /// 由 [_rotCtrl] 平滑逼近目标角（定位每秒一帧，直接跳会抖）；同帧把
  /// `cos/sin` 一并算好存着 —— `_toScreen` 每个台站每帧都要用，不能逐点算。
  late final AnimationController _rotCtrl;
  Tween<double> _rotTween = Tween<double>(begin: 0, end: 0);
  double _rot = 0;
  double _rotCos = 1;
  double _rotSin = 0;

  /// 这次已经安排给 [_rotCtrl] 的目标角。判断「目标变了没有」要用原始角，
  /// 不能用 `_rotTween.end`：那是化到当前角附近的等价角，会差 2π。
  double _rotWant = 0;

  /// 旋转时底图的边长（屏幕对角线，见 [_mapCanvas]）。
  double _diag = 0;

  /// 按下时的指针位置，只用于判断「这是拖还是点」（见 build 里的 Listener）。
  Offset? _dragStart;
  /// 缩小到该级别以下时自动显示热力图（按网格统计台站密度）。
  ///
  /// 6.5 → 9.0（用户反馈「热力图不容易触发」）：6.5 已经是「省/区域」级，
  /// 缩到城市级（9 前后）根本触发不了，而台站开始挤成一团恰恰在城市级。
  static const double _heatZoom = 9.0;
  Size _lastSize = Size.zero;

  /// 地图**画出来的**那几层（轨迹 / 信标点 / 选中轨迹 / 精度圈 / 热力图）用的裁剪器。
  ///
  /// 每帧在 build 里按外壳传进来的让位量重建（为什么必须裁，见赋值处的说明）。
  _OverlayInsetClipper _ovClip =
      _OverlayInsetClipper(left: 0, top: 0, bottom: 0);

  MapType get _currentMapType => MapType.values.firstWhere(
    (t) => t.name == widget.state.mapType,
    orElse: () => MapType.gaode,
  );

  /// 当前底图是否为卫星/影像：决定符号光晕与呼号标签的配色
  /// （卫星影像底图偏暗、纹理杂，普通标记与白底标签都容易糊进去）。
  bool get _isSat => isSatelliteMapType(_currentMapType);

  /// 是否使用矢量地图模式（flutter_map）：OpenFreeMap Liberty / Carto Positron
  bool get _isVector =>
      _currentMapType == MapType.vector ||
      _currentMapType == MapType.vector_positron;

  /// 插件地图（自绘标记不可用的模式）
  bool get _usePluginMap => _isVector;

  /// 低缩放热力图：瓦片自绘模式 + 开关开启 + zoom 足够低 + 台站够多
  bool get _showHeatmap =>
      // 矢量地图也支持（见 VectorMapView.showHeatmap）—— 以前这里写着 !_usePluginMap，
      // 于是"矢量地图热力图失效"。
      _heatEnabled &&
      _zoom <= _heatZoom &&
      // 20 → 10：城市里同时可见 20 个台站的场景太少，门槛跟 zoom 一起放宽
      _visible.length >= 10;

  Station? _selected;
  final ValueNotifier<Offset?> _hover = ValueNotifier(null);

  /// 右侧工具列**单列**的总高：3 个工具钮（3×38 + 2×6 间隙）+ 组间 6
  /// + 6 个缩放钮（6×38 + 5×6 间隙）= 390。
  ///
  /// 只用来判断「要不要分两列」（见 [_rightToolbar]）。以前那里是一个裸的
  /// 「520」，看不出与按钮尺寸的关系 —— 改一颗按钮的高度就得重新猜阈值。
  /// ⚠ 缩放钮加了「锁定地图中心」这一颗之后，这个数必须跟着涨：
  /// `check_landscape_layout.py` 就是按它判断「矮横屏要不要分两列」的。
  static const double _kToolbarColH = 390;

  /// 上报横杠（[_beaconBar]）自身的高度：一行 12 号字 + 上下各 8 内边距 + 描边。
  ///
  /// 只给「地图画出来的那几层」的裁剪线用（见 `_ovClip`），不参与任何布局 ——
  /// 那个 `Positioned` 仍然是按内容撑开的，这里只是估一个「它大概有多高」。
  static const double _kBeaconBarH = 38;

  /// 底部坐标条（[_bottomControls]）自身的高度：13 号图标 + 上下各 7 内边距 + 描边。
  static const double _kBottomCtrlH = 30;

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

  /// 「从群聊消息跳进策略地图」上一次处理过的序号（见 [AppState.openStrategyMap]）。
  /// 初值必须是 0（= [AppState.strategyJumpSeq] 的初值），否则首帧会把
  /// 「序号没变」误判成新请求，一启动就弹出群选择。
  int _lastStrategyJumpSeq = 0;
  int _lastPickSeq = -1;
  bool _pickMode = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(_onRotTick);
  }

  /// 脉冲动画按需启停：没有移动/选中台站时停转，省掉每帧重建开销
  void _syncPulse() {
    // 移动台站过多时（>12）停用脉冲动画，避免同一动画驱动大量实例每帧重绘卡顿
    final sel = _selected?.call;
    var moving = 0;
    for (final s in _visible) {
      if (s.effectiveStatus == St.moving) moving++;
    }
    final need = moving > 0 || sel != null;
    if (moving > 12) {
      if (_pulse.isAnimating) {
        _pulse.stop();
        _forceMarkerRebuild = true; // 移除已显示的脉冲圈，改静态
      }
      return;
    }
    if (need && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!need && _pulse.isAnimating) {
      _pulse.stop();
      // 停转后强制标记重建一次，去掉标记里残留的静态脉冲圈
      _forceMarkerRebuild = true;
    }
  }

  @override
  void didUpdateWidget(covariant MapPage old) {
    super.didUpdateWidget(old);
    // 解冻的一次性补偿：冻结期间地图上的台站/焦点/尺寸变化都被跳过了，
    // 这里补一次强制重建，否则解冻后会短暂显示冻结前的旧标记。
    if (old.frozen && !widget.frozen) _forceMarkerRebuild = true;
  }

  @override
  void dispose() {
    _cancelAnim();
    _pulse.dispose();
    _rotCtrl.dispose();
    _hover.dispose();
    super.dispose();
  }

  // 基准（WGS-84 北京）
  static const _baseLat = 39.9042;
  static const _baseLng = 116.4074;
  // GCJ-02（火星坐标）转换后的高德投影基准
  static final (double, double) _gcjBase = Gcj.wgsToGcj(_baseLat, _baseLng);

  // ─── 投影 ───
  // 瓦片底图坐标系：高德瓦片为 GCJ-02；国际图源（Carto/OSM/Esri/OpenTopo）为 WGS-84。
  // 投影基准必须与底图一致，否则标记整体偏移。
  // 国内图源（高德/腾讯）为 GCJ-02，需要坐标纠偏
  bool get _isGcjTile => !_usePluginMap && isGcjMapType(_currentMapType);

  /// 投影基准坐标：高德→GCJ 天安门；国际 WGS→原始 WGS-84 天安门
  (double, double) get _projBase =>
      _isGcjTile ? _gcjBase : (_baseLat, _baseLng);

  // 坐标转换缓存：手势每帧对每个台站做三角函数转换很贵，缓存坐标结果
  final Map<String, (double, double)> _gcjCache = {};

  /// 把台站坐标映射到底图坐标系：GCJ 瓦片做 WGS→GCJ，国际 WGS 瓦片原样
  (double, double) _toTileCoord(double lat, double lng) {
    if (!_isGcjTile) return (lat, lng);
    final key = '${lat.toStringAsFixed(6)}|${lng.toStringAsFixed(6)}';
    final v = _gcjCache[key];
    if (v != null) return v;
    if (_gcjCache.length > 3000) _gcjCache.clear();
    final r = Gcj.wgsToGcj(lat, lng);
    _gcjCache[key] = r;
    return r;
  }

  /// 当前渲染投影：百度不是 Web Mercator，标记必须与瓦片共用同一套投影
  MapProjection get _proj => projectionFor(_currentMapType);

  /// 取与 [ref] 最接近的等价角（避免 359°→1° 反向绕一整圈）
  static double _nearest(double target, double ref) {
    var d = (target - ref) % (2 * math.pi);
    if (d > math.pi) d -= 2 * math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    return ref + d;
  }

  /// 绕 [c] 旋转（旋转量取当前 `_rot` 的 cos/sin）
  Offset _spin(Offset p, Offset c) {
    final d = p - c;
    return Offset(
      c.dx + d.dx * _rotCos - d.dy * _rotSin,
      c.dy + d.dx * _rotSin + d.dy * _rotCos,
    );
  }

  Offset _toScreen(double lat, double lng, Size size) {
    final g = _toTileCoord(lat, lng);
    final b = _projBase;
    final c = _proj.latLngToPx(b.$1, b.$2, _zoom);
    final p = _proj.latLngToPx(g.$1, g.$2, _zoom);
    final raw = Offset(
      p.dx - c.dx + size.width / 2 + _pan.dx,
      p.dy - c.dy + size.height / 2 + _pan.dy,
    );
    // 航向朝上：底图被 `Transform.rotate(_rot)` 转过（见 [_mapCanvas]，
    // 旋转中心与页面中心重合），所以覆盖层（轨迹 / 信标点 / 标记）要跟着
    // 绕页面中心转同一个角，否则会从底图上滑开。
    return _rot == 0 ? raw : _spin(raw, size.center(Offset.zero));
  }

  /// 底图给的**局部坐标** → 页面坐标。
  ///
  /// 旋转时底图是「对角线画布」（边长 [_diag]，见 [_mapCanvas]），它的原点
  /// 与页面不重合：先减画布中心、旋转、再加回页面中心。没转时两者本是一套。
  Offset _canvasToPage(Offset local, Size size) {
    if (_rot == 0 || _diag <= 0) return local;
    final c = Offset(_diag / 2, _diag / 2);
    return size.center(Offset.zero) + (_spin(local, c) - c);
  }

  /// 页面坐标 → 经纬度（鼠标悬停读数用）。
  ///
  /// 转过之后先绕页面中心反旋回去，再交给 [_screenToLatLng] —— 那套算法
  /// 假定坐标系没转过。
  (double, double) _pageToLatLng(Offset pagePoint, Size size) {
    if (_rot == 0) return _screenToLatLng(pagePoint, size);
    final c = size.center(Offset.zero);
    final d = pagePoint - c;
    return _screenToLatLng(
      Offset(
        c.dx + d.dx * _rotCos + d.dy * _rotSin,
        c.dy - d.dx * _rotSin + d.dy * _rotCos,
      ),
      size,
    );
  }

  /// 算这一帧的「航向朝上」目标角，目标一变就安排一段过渡。
  ///
  /// 目标角 = -航向（Flutter 正角为顺时针）。没有航向 / 没在动 / 底图是矢量
  /// （相机在 flutter_map 手里，转不了）时回正北 —— 与沉浸页同一套口径。
  ///
  /// 不能在 build 里直接 `forward`（那会在 build 期间就通知监听者重建），
  /// 所以只在这里定好 tween，启动交给 post-frame 回调。
  void _syncRot() {
    final st = widget.state;
    final course = st.myCourse;
    final moving = (st.mySpeed ?? 0) > 0.5;
    final bool headingUp = _followMode == 2 &&
        !_isVector &&
        st.myHasFix &&
        course != null &&
        course >= 0 &&
        moving;
    final double want = headingUp ? -course * math.pi / 180 : 0.0;
    if (want == _rotWant) return;
    _rotWant = want;
    // 从**当前角**出发取等价角，避免 359°→1° 时绕一整圈
    _rotTween = Tween<double>(begin: _rot, end: _nearest(want, _rot));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rotCtrl.forward(from: 0);
    });
  }

  /// 每帧把展示角逼近目标角（同帧算好 cos/sin 供覆盖层逐点用）
  void _onRotTick() {
    final r = _rotTween.evaluate(_rotCtrl);
    if (r == _rot) return;
    setState(() {
      _rot = r;
      _rotCos = math.cos(r);
      _rotSin = math.sin(r);
    });
  }

  /// 航向朝上时把底图连画布一起转：画布取屏幕**对角线**长度并居中，
  /// 这样任意角度四角都不会露白（与沉浸页同一套做法）。
  ///
  /// 转的时候底图自己的手势（拖动 / 双指缩放 / 滚轮 / 点击）都在**画布**
  /// 坐标系里发生：`TileMapView` 的 pan 本来就是「相对画布中心」的量，所以
  /// 拖动与缩放锚点都不用换算；只有点地图选点的落点要经 [_canvasToPage]。
  Widget _mapCanvas(Size size, Widget child) {
    if (_rot == 0 || _diag <= 0) return child;
    return ClipRect(
      child: Transform.rotate(
        angle: _rot,
        child: OverflowBox(
          minWidth: _diag,
          maxWidth: _diag,
          minHeight: _diag,
          maxHeight: _diag,
          child: SizedBox(width: _diag, height: _diag, child: child),
        ),
      ),
    );
  }

  (double, double) _screenToLatLng(Offset screen, Size size) {
    final b = _projBase;
    final c = _proj.latLngToPx(b.$1, b.$2, _zoom);
    final p = Offset(
      screen.dx + c.dx - size.width / 2 - _pan.dx,
      screen.dy + c.dy - size.height / 2 - _pan.dy,
    );
    final g = _proj.pxToLatLng(p, _zoom);
    // GCJ 瓦片：坐标是 GCJ-02，按用户 datum 偏好输出 WGS-84；
    // 百度由投影内部转回 WGS-84；国际 WGS 瓦片原样。
    //
    // 经度一律用 [wrapLng] 收进 [-180,180)：pan 是不封顶的（瓦片按取模换列），
    // 拖动越过一整圈之后反算出来的经度会一路累加，读数就成了 181°、360°…
    if (_isGcjTile) {
      if (widget.state.coordDatum == 'gcj') return (g.$1, wrapLng(g.$2));
      final w = Gcj.gcjToWgs(g.$1, g.$2);
      return (w.$1, wrapLng(w.$2));
    }
    return (g.$1, wrapLng(g.$2));
  }

  /// 让某点居中的 pan：screen = p - c + size/2 + pan = size/2 → pan = c - p
  Offset _panFor(double lat, double lng, double zoom) {
    final g = _toTileCoord(lat, lng);
    final b = _projBase;
    final c = _proj.latLngToPx(b.$1, b.$2, zoom);
    final p = _proj.latLngToPx(g.$1, g.$2, zoom);
    return c - p;
  }

  String get _scaleText {
    const pxLen = 120.0;
    // 用投影反算，任何图源（含百度）都准 —— 不能再套 Web Mercator 的公式
    final c = _proj.latLngToPx(_projBase.$1, _projBase.$2, _zoom);
    final a = _proj.pxToLatLng(c, _zoom);
    final b = _proj.pxToLatLng(Offset(c.dx + pxLen, c.dy), _zoom);
    final km = haversine(a.$1, a.$2, b.$1, b.$2);
    if (km >= 100) return '${km.toStringAsFixed(1)} km';
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
    final b = _projBase;
    final c1 = _proj.latLngToPx(b.$1, b.$2, _fromZoom);
    final c2 = _proj.latLngToPx(b.$1, b.$2, _toZoom);
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
      final c = _proj.latLngToPx(_projBase.$1, _projBase.$2, z);
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

  // 图层筛选：隐藏的类型
  //
  // 不另存一份：直接读写 [AppState.mapHiddenTypes]（用户要求「地图筛选要记住」）。
  // 存两份的话，面板里的勾与落盘那份迟早会不同步 —— 那种错只有在重启后才看得见。
  Set<TypeGroup> get _hiddenTypes => widget.state.mapHiddenTypes;

  // 可见台站缓存：台站版本 + 筛选条件未变时复用，
  // 避免每秒 tick 重建时对几百个台站反复全量过滤
  int _visibleStationsVersion = -1;
  int _visibleFilterHash = 0;
  List<Station> _visibleCache = const [];

  List<Station> get _visible {
    final sv = widget.state.stationsVersion;
    final q = widget.searchQuery.trim().toLowerCase();
    // 无分配 hash：搜索词 + 隐藏类型 + 国家筛选快照
    final filterHash = Object.hash(
      q,
      Object.hashAll(_hiddenTypes),
      Object.hashAll(widget.state.receiveCountries),
      widget.state.receiveOthers,
      widget.state.applyFilterToMap,
      widget.state.stationFilter.key,
    );
    if (sv == _visibleStationsVersion && filterHash == _visibleFilterHash) {
      return _visibleCache;
    }
    var list = widget.state.stations;
    // 国家/地区接收筛选：始终按 stationAllowedFor 过滤（传对象避免线性查找）
    list = list.where(widget.state.stationAllowedFor).toList();
    if (q.isNotEmpty) {
      list = list
          .where(
            (s) =>
                s.call.toLowerCase().contains(q) ||
                s.typeName.contains(q) ||
                s.alias.contains(q) ||
                (s.deviceName ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
    if (_hiddenTypes.isNotEmpty) {
      list = list.where((s) => !_hiddenTypes.contains(s.typeGroup)).toList();
    }
    // 台站面板筛选应用到地图（可选，默认关闭；两处共用 StationFilter.matches）
    final st = widget.state;
    if (st.applyFilterToMap && !st.stationFilter.isEmpty) {
      list = list.where(st.stationFilter.matches).toList();
    }
    _visibleStationsVersion = sv;
    _visibleFilterHash = filterHash;
    _visibleCache = list;
    return list;
  }

  // ─── 构建 ───
  @override
  Widget build(BuildContext context) {
    // 非激活 Tab（在其它页面时地图在 IndexedStack 后台）：跳过昂贵构建，
    // 仅保留轻量占位。台站多时避免后台地图反复 rebuild 拖慢全局。
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        // 处理视图初始化 + 焦点跳转（一次性，避免互相覆盖）
        _handleViewFocus();
        _handleStrategyJump();
        // 进入地图选点模式 —— 用 postFrameCallback 避免 build 中 setState
        if (widget.state.pickSeq != _lastPickSeq) {
          _lastPickSeq = widget.state.pickSeq;
          final newPick = widget.state.pickMode;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pickMode != newPick)
              setState(() => _pickMode = newPick);
          });
        }
        return LayoutBuilder(
          builder: (ctx, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            _lastSize = size;
            // 旋转时的底图边长（见 [_mapCanvas]）：先算好供 _canvasToPage 用
            if (size.width > 0 && size.height > 0) {
              _diag = math.sqrt(
                size.width * size.width + size.height * size.height,
              );
            }
            // 锁定地图中心：每次状态刷新（多半是收到一条新的定位点）都把地图对回
            // 我的位置。这里**只改写 `_pan`、不 setState** —— 本帧的地图本来就会拿
            // 新的 `_pan` 去画，再 setState 只是白多一帧重建。
            //
            // 矢量底图不走 `_pan`（相机在 flutter_map 自己手里），那一条由
            // [VectorMapView.follow] 负责，两条口径一致。
            final st0 = widget.state;
            if (_followMe &&
                st0.myHasFix &&
                st0.myLat != null &&
                st0.myLng != null) {
              _pan = _panFor(st0.myLat!, st0.myLng!, _zoom);
            }
            // 航向朝上：算这一帧的目标转角（目标变了就安排一段过渡）
            _syncRot();
            final vis = _visible;
            final searched = widget.searchQuery.trim().isNotEmpty;
            // 矮横屏（小屏手机横放，以及「窗口很宽但很矮」的桌面窗口）：
            // 隐藏图例减少遮挡，并让右侧工具列换两列（见 _rightToolbar）。
            //
            // 判据用**顶栏之下实际可用**的高度，而不是裸屏高：顶部让位量会被
            // 未连接横幅与公告横幅各顶掉一行（合计 +84），桌面上又常有「很宽
            // 但很矮」的窗口形状 —— 按裸屏高判断这些都会漏判，而漏判的表现
            // 就是工具列最下面的「定位」被 Stack 裁掉、点不到。
            final double availH =
                size.height - widget.topInset - widget.bottomInset;
            final bool shortWide =
                size.width > size.height && availH < _kToolbarColH + 54;
            // 顶部锚点的基准：所有顶部浮层从 14 挪到「外壳顶栏之下」
            final double topBase = 14 + widget.topInset;
            // 贴底控件（比例尺/坐标条、上报横杠）在 2.0 里会被卡片顶上来。
            // 顶到右侧工具列（约 434 高）那一段就会同时压住工具列与顶栏 ——
            // 这正是「混乱」的来源。所以按顶栏之下的可用高度判断：
            // 不够就**不显示**，而不是硬塞进去。484 ≈ 工具列高 + 间隙
            // （阈值一直跟着 [_kToolbarColH] 涨：工具列长高了，贴底控件就得
            // 更晚才出现，不然两者会在矮屏上叠在一起）。
            final bool roomForBottom = availH > 484;
            // ── 地图**画出来的**那几层也要让开外壳占用的区域 ──
            //
            // 与贴左控件同一个口径（见 [leftInset] 与 [bottomInset]）：2.0 外壳的
            // 导航竖条、内容面板、顶栏与贴底浮层都是**磨砂半透明**地悬在整屏地图
            // 之上（1.0 与地图并排，传进来的几个 inset 都是 0，这里等于不裁）。
            // 控件早就会让开，画上去的那几层却照旧铺满整屏 —— 于是蓝线从卡片背后
            // 透出来，看着像「轨迹压住了卡片」。裁到可见地图区之后，卡片底下不再有
            // 这条线，磨砂里剩下的只有底图，观感与「卡片是实的」一致。
            //
            // 画笔坐标与各层位置都不变：`CustomPaint` 自己就是 `size` 大小，外面包
            // 一层同尺寸的 `ClipRect` 只改「画到哪儿」，不改「画在哪儿」。
            final double padBottom = MediaQuery.of(context).padding.bottom;
            _ovClip = _OverlayInsetClipper(
              left: widget.leftInset,
              top: widget.topInset,
              // 贴底浮层（上报横杠 / 底部坐标条）的底边距与自身高度必须与下面那两个
              // `Positioned` 一致，否则裁剪线会落在横杠里面（线上还会剩一截露在杠下）。
              bottom: !roomForBottom
                  ? 0
                  : (widget.state.connected && widget.state.myHasFix
                      ? 62 + padBottom + widget.bottomInset + _kBeaconBarH
                      : 14 + padBottom + widget.bottomInset + _kBottomCtrlH),
            );
            if (widget.frozen) {
              // 冻结：停掉脉冲动画。它是地图这边**唯一的每帧**重绘来源
              // （`_pulse.repeat()` 会驱动所有移动台站的扩散圈逐帧重建），
              // 停掉之后地图内容不再变化，光栅化结果可以被复用。
              if (_pulse.isAnimating) {
                _pulse.stop();
                _forceMarkerRebuild = true; // 去掉标记里残留的静态脉冲圈
              }
            } else {
              _syncPulse();
            }

            return Stack(
              children: [
                // 功能引导：这是**全屏地图**，四周全是浮层（统计条 / 图例 / 工具列 /
                // 上报横杠 / 比例尺），浮卡片找不到「一定不重叠」的位置 —— 实测会
                // 压住图例下沿 1px。改走一次性底部弹层，关掉即记为已看。
                GuideSheetOnce(
                  guideId: 'home',
                  state: widget.state,
                  // 地图在 IndexedStack 里：只有它真的在前台时才弹
                  enabled: widget.isActive,
                ),
                // 瓦片地图（RepaintBoundary 隔离重绘）
                RepaintBoundary(
                  // 锁定地图中心时的「拖一下就解锁」：一拖就是要自己看，
                  // 不该在下一帧被拽回中心（与沉浸页的跟随按钮同口径）。
                  //
                  // 用原始指针事件而不是手势回调：自绘瓦片底图的手势在
                  // TileMapView 自己手里、矢量底图在 flutter_map 手里，两条
                  // 路都得覆盖；`Listener` 只观察、不参与手势竞技，所以
                  // 「点台站」「点地图选点」这些点击一个都不受影响。
                  child: Listener(
                    onPointerDown: (e) => _dragStart = e.position,
                    onPointerMove: (e) {
                      final start = _dragStart;
                      if (!_followMe || start == null) return;
                      // 6px 以内算「点」，不算拖 —— 手指按下去总会抖一点，
                      // 用 0 阈值会把每一次点击都当成拖动。
                      if ((e.position - start).distance < 6) return;
                      _dragStart = null;
                      // 自己拖地图：三态一起退回「关」，转角也随之回正北（也落盘）
                      setState(() => widget.state.setMapFollowMode(0));
                    },
                    onPointerUp: (_) => _dragStart = null,
                    onPointerCancel: (_) => _dragStart = null,
                    child: MouseRegion(
                      onHover: (e) => _hover.value = e.localPosition,
                      onExit: (_) => _hover.value = null,
                      child: _isVector
                          ? VectorMapView(
                              stations: _visible,
                              styleUrl: vectorStyleUrlFor(_currentMapType.name),
                              stationsVersion: widget.state.stationsVersion,
                              myCall: widget.state.myFullCall,
        showHeatmap: _showHeatmap,
        heatLevel: widget.state.heatLevel,
                              myHasFix: widget.state.myHasFix,
                              myLat: widget.state.myLat,
                              myLng: widget.state.myLng,
                              myCourse: widget.state.myCourse,
                              myTrack: widget.state.myTrack,
                              selectedCall: _selected?.call,
                              selectedTrack: _selected?.track ?? const [],
                              selectedColor: _selected?.color,
                              focusSeq: widget.state.mapFocusSeq,
                              focusLat: widget.state.mapFocus?.lat,
                              focusLng: widget.state.mapFocus?.lng,
                              actionSeq: _mapActionSeq,
                              action: _mapAction,
                              showTracks: _showTracks,
                              // 锁定地图中心：矢量底图的相机在 flutter_map 手里，
                              // 由它自己跟（见 VectorMapView.follow）
                              follow: _followMe,
                              // 设置里可强制「无论密度/缩放都显示标签」
                              showStationLabels: widget.state.mapLabelsAlways,
                              onTap: _handleMapLatLng,
                              onStationTap: (s) {
                                _openDetail(s);
                                _selected = s;
                                // 这里照常同步脉冲：选中态要在屏幕上看得见。
                                // 若此刻处于冻结（面板正在动），下一帧 build 会把
                                // 它再停掉 —— 用户的点击反馈优先于省这一两帧。
                                _syncPulse();
                              },
                            )
                          : _mapCanvas(
                              size,
                              TileMapView(
                                centerLat: _projBase.$1,
                                centerLng: _projBase.$2,
                                zoom: _zoom,
                                pan: _pan,
                                onPan: _panDelta,
                                onViewChanged: _setView,
                                // 滚轮：瞬时围绕焦点缩放，跟手不飘
                                onZoomRequest: (z, p) => _animateTo(z, p),
                                onTap: _handleMapTap,
                                mapType: _currentMapType,
                                // 离线地图：缓存开关与「仅离线」模式（设置页可改）
                                cacheEnabled: widget.state.tileCacheOn,
                                offlineOnly: widget.state.offlineOnly,
                              ),
                            ),
                    ),
                  ),
                ),
                // 我的位置轨迹线（不挡手势）
                if (!_usePluginMap &&
                    _showTracks &&
                    widget.state.myTrack.length > 1)
                  IgnorePointer(
                    child: ClipRect(
                      clipper: _ovClip,
                      child: CustomPaint(
                        size: size,
                        painter: _TrackOverlayPainter(
                          points: widget.state.myTrack,
                          color: C.blue,
                          toScreen: (lat, lng) => _toScreen(lat, lng, size),
                          rot: _rot,
                        ),
                      ),
                    ),
                  ),
                // **信标点**（真正发到服务器去的那些点）：画在轨迹之上、标记之下。
                // 单独一层而不是混进轨迹：轨迹是「我走过哪里」，信标点是
                // 「我报到哪里」—— 后者要能一眼数出来（对方收到几个点、
                // 间隔是否合预期），所以要画成独立符号而不是线上的节点。
                if (!_usePluginMap && widget.state.beaconMarks.isNotEmpty)
                  IgnorePointer(
                    child: ClipRect(
                      clipper: _ovClip,
                      child: CustomPaint(
                        size: size,
                        painter: _BeaconMarkPainter(
                          points: widget.state.beaconMarks,
                          color: C.orange,
                          toScreen: (lat, lng) => _toScreen(lat, lng, size),
                          rot: _rot,
                        ),
                      ),
                    ),
                  ),
                // 轨迹线（不挡手势）
                if (!_usePluginMap &&
                    _selected != null &&
                    _selected!.track.length > 1)
                  IgnorePointer(
                    child: ClipRect(
                      clipper: _ovClip,
                      child: CustomPaint(
                        size: size,
                        painter: _TrackOverlayPainter(
                          points: _selected!.track,
                          color: _selected!.color,
                          toScreen: (lat, lng) => _toScreen(lat, lng, size),
                          rot: _rot,
                        ),
                      ),
                    ),
                  ),
                // 自己的定位精度圈（实测精度，见 myAccuracy）。
                // 只画**自己**这一个圈：接收台站的模糊圈/推测位置已按反馈撤掉
                // （见 lib/pos_quality.dart 顶部说明）—— 那套要每秒遍历所有可见
                // 台站算三角函数，而改善的是「别人的点准不准」，代价与收益不成比例。
                // 这一层只在精度/位置变化时重绘（shouldRepaint 不比较时间），
                // 所以它既不占帧，也不会在磨蹭面板展开时反复触发离屏模糊。
                if (!_usePluginMap &&
                    widget.state.myHasFix &&
                    widget.state.myAccuracy > 0)
                  IgnorePointer(
                    child: ClipRect(
                      clipper: _ovClip,
                      child: CustomPaint(
                        size: size,
                        painter: _MyAccuracyPainter(
                          lat: widget.state.myLat!,
                          lng: widget.state.myLng!,
                          accuracyM: widget.state.myAccuracy,
                          toScreen: (lat, lng) => _toScreen(lat, lng, size),
                        ),
                      ),
                    ),
                  ),
                // 低缩放热力图（按网格统计台站密度，不改变标记本身）
                if (_showHeatmap)
                  IgnorePointer(
                    child: ClipRect(
                      clipper: _ovClip,
                      child: CustomPaint(
                        size: size,
                        painter: _HeatmapPainter(
                          stations: _visible,
                          toScreen: (lat, lng) => _toScreen(lat, lng, size),
                          level: widget.state.heatLevel,
                          rot: _rot,
                        ),
                      ),
                    ),
                  ),
                // 我的位置标记（点击弹信息面板）
                if (!_usePluginMap && widget.state.myHasFix) _myMarker(size),
                // 台站标记（热力图模式下隐藏，其余直接 Stack Positioned）
                if (!_usePluginMap && !_showHeatmap)
                  ..._stationMarkers(size),
                // ── 左上竖列：台站统计 + 沉浸地图入口 ──
                //
                // 两者放在**同一个 Column** 里顺序排布，而不是各自 Positioned
                // 各自算 top —— 后者只要有人调一处间距就会互相盖住：早先统计在
                // topBase、入口硬写 topBase+44，任何新控件插进来都可能糊上去。
                // 顺序排布之后，结构上不可能再重叠。
                //
                // ⚠ 功能引导**不放这一列**：这一列的高度全看字体度量，而右上图例
                // 是独立浮层 —— 卡片按列排下去会正好压在图例下沿（按真实几何量过，
                // 差 1px；换个语言或缩放下必然翻车）。地图是全屏视图，引导改走
                // 一次性弹层（见下面 GuideSheetOnce）。
                Positioned(
                  top: topBase,
                  left: 14 + widget.leftInset,
                  right: 74,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 心率放**最上面**：它是用户运动时最想一眼看到的东西，
                      // 而台站计数是「背景信息」（需求原话：「让心率显示在主屏幕上面」）。
                      _hrChip(),
                      const SizedBox(height: 10),
                      _infoChip(vis, searched),
                      const SizedBox(height: 10),
                      _immersiveEntry(),
                    ],
                  ),
                ),
                // 选点提示
                if (_pickMode)
                  Positioned(
                    top: topBase,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: C.orange,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: elev3(),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.gps_fixed_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              S.of(context).mapPickDesc,
                              style: ts(
                                12,
                                c: Colors.white,
                                w: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                widget.state.finishPick();
                                setState(() => _pickMode = false);
                              },
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // 焦点标记：从策略地图「导航」过来的目标点。
                // 策略点不在 stations 里（是远端构造的合成台站），台站标记里
                // 找不到它 —— 缺了这枚标记，用户落图后看不到「刚才要导的那个点」，
                // 就会觉得「跳转导航用不了」。只在有焦点时画，改动焦点即更新。
                // 与台站标记同口径：矢量图（插件）走原生渲染、坐标口径不同，只画瓦片图。
                if (!_usePluginMap) _focusMarker(size),
                // ── 地图小浮层的「共享底」：一簇浮层只让引擎采一次底 ──
                //
                // 这一簇（图例 / 工具列 8 颗按钮 / 上报横杠 / 底部坐标条）全是
                // **兄弟节点、互不重叠、背后都是同一张地图**，模糊半径也都取
                // `C.chipBlur`。每个 `BackdropFilter` 都要让引擎「结束当前 render
                // pass → 采样 → 重开」一次，而这一步在移动端比模糊本身还贵 ——
                // 地图页一屏十来个小浮层就是每帧十来次；列表一滚动（60fps）就是
                // 每秒上千次。套进同一个 `BackdropGroup`（配合 `MaterialSurface`
                // 里的 `BackdropFilter.grouped`）之后：引擎只采一次底，而且因为
                // 各层 filter 完全相同，模糊也只算一次，再按各自的矩形贴上去 ——
                // 观感逐像素不变（详见 material.dart 顶部那段）。
                //
                // ⚠ 只包**这一簇**，不包整页：共享 key 的语义是「后一个表面采样的
                // 是第一个表面**之前**的那张底」，也就是说两者之间画的内容不会出现
                // 在它的模糊里 —— 所以只有「连续绘制、互不重叠」的一簇能合并。
                // 台站标记（里面还套着选中信息窗）与搜索提示条都留在组外，
                // 正是这个原因。
                Positioned.fill(
                  child: BackdropGroup(
                    child: Stack(
                      children: [
                        // ── 右侧工具列 ──
                        // 此前用 14 / 58 / 102 / 146 四个硬编码 top 各自 Positioned，
                        // 而 `_zoomCtrl()` 含 6 个按钮（放大/缩小/轨迹/热力图/定位/锁定，一直
                        // 排到 448），矮屏上必然打架。改成「单列顺序排布」后结构上不可能再重叠；
                        // 手机横放时**再分两列**（见 `_rightToolbar`，否则最下面的「定位」会被裁掉）。
                        Positioned(
                          right: 14,
                          top: topBase,
                          child: _rightToolbar(shortWide),
                        ),
                        // 竖屏：底部通栏“上报通知”横杠（仅已连接+有定位时显示，横屏由侧边栏承担）
                        if (roomForBottom &&
                            widget.state.connected &&
                            widget.state.myHasFix)
                          Positioned(
                            left: 14 + widget.leftInset,
                            right: 14,
                            bottom: 62 + MediaQuery.of(context).padding.bottom + widget.bottomInset,
                            // 「距下次上报 12 秒」是**秒级**字段：整页只在
                            // AppState 通知（有台站刷新 / 状态翻转）时重建，
                            // 于是**没有台站刷新时这个秒数就冻住不动**（用户报的
                            // 「地图页如果没有台站刷新上报秒数就不会更新」）。
                            // 挂到每秒自增的 [AppState.tick] 上即可 —— 与
                            // MyPanel / 台站页的口径一致。
                            child: ValueListenableBuilder<int>(
                              valueListenable: widget.state.tick,
                              builder: (_, _, _) => _beaconBar(),
                            ),
                          ),
                        // 底部控制（安全区白条 + 14px）
                        if (roomForBottom)
                          Positioned(
                            left: 14 + widget.leftInset,
                            right: 14,
                            bottom: 14 + MediaQuery.of(context).padding.bottom + widget.bottomInset,
                            child: ValueListenableBuilder<Offset?>(
                              valueListenable: _hover,
                              builder: (_, hp, _) => _bottomControls(hp),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // 搜索提示
                if (searched)
                  Positioned(
                    top: topBase,
                    // 横屏时左侧被竖条占着：居中要相对**可见的地图区**，
                    // 否则提示条会偏向左侧、压到卡片边缘
                    left: widget.leftInset,
                    right: 0,
                    child: Center(
                      child: MaterialSurface(
                        radius: 12,
                        blurSigma: C.chipBlur,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: C.chipFill,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: elev2(),
                          ),
                          child: Text(
                            S
                                .of(context)
                                .foundStations(
                                  vis.length,
                                  widget.searchQuery.trim(),
                                ),
                            style: ts(12, w: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// 视图初始化/焦点跳转，一次性执行，保证互不覆盖
  /// 返回本次是否触发了「焦点跳转」（见 [AppState.focusOnMap]）。
  bool _handleViewFocus() {
    final focus = widget.state.mapFocus;
    if (focus != null && widget.state.mapFocusSeq != _lastFocusSeq) {
      _lastFocusSeq = widget.state.mapFocusSeq;
      _lastFocusedCall = focus.call;
      _didInitView = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selected = focus);
        // 直接落位，不走过渡动画。从策略地图点「导航」跳过来时，这一帧之后
        // 地图很可能被覆盖/冻结，动画会在中途被打断，停在「飞了一半」的
        // 中间态 —— 用户看到的就是「点了没反应/飘到半路」。瞬时落位才可靠。
        _cancelAnim();
        setState(() {
          _zoom = 14.0;
          _pan = _panFor(focus.lat, focus.lng, 14.0);
          // 跳到某个台站 = 用户要看那个点，锁定随之解除：留着的话下一帧就被
          // 「锁定地图中心」拽回我的位置，用户根本看不到刚聚焦的台站。
          widget.state.setMapFollowMode(0);
        });
      });
      return true;
    }
    if (!_didInitView) {
      _didInitView = true;
      if (widget.state.myHasFix) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _animateTo(
            13.0,
            _panFor(widget.state.myLat!, widget.state.myLng!, 13.0),
          );
        });
      }
    }
    return false;
  }

  // ─── 标记 ───
  // 标记列表缓存：视图(缩放/平移/选中)或台站版本变化立即重建以保持实时；
  // 台站/视图都没变（每秒 tick）直接复用，避免重建几百个 Marker；
  // 纯尺寸变化(键盘展开动画/收包洪峰)节流到 ~150ms
  List<Widget>? _markerCache;
  DateTime _markerCacheTime = DateTime.fromMillisecondsSinceEpoch(0);
  Size? _markerCacheSize;
  int _markerViewHash = 0;
  String? _markerSelHash;
  List<Station>? _markerVisibleList; // 上次构建标记所用的可见台站列表（用同一性判断）
  bool _forceMarkerRebuild = false; // 脉冲动画停转后强制重建一次，移除残留圈
  bool _markerLabelsAlways = false; // 上次构建标记时的「始终显示标签」设置（变化需重建）

  List<Widget> _stationMarkers(Size size) {
    final now = DateTime.now();
    final viewHash =
        (_zoom * 64).round() * 1000003 +
        _pan.dx.round() * 1009 +
        _pan.dy.round() +
        // 航向朝上时画布一直在转：转角和 pan/zoom 一样是**视图**的一部分，
        // 不进缓存键的话标记会僵在旧角度上、从底图上滑开。
        (_rot * 1000).round() * 4000037 +
        // 卫星与街道的标记外观不同（符号光晕/标签配色）→ 必须进缓存键，
        // 否则切底图后标记要等下一次拖拽才更新。
        (_isSat ? 1 : 0) * 2000003;
    final selHash = _selected?.call ?? '';
    // 冻结（面板开着/正在动）时：**数据**变化不再重建标记，但**视图**变化必须
    // 跟随 —— 否则用户在这个状态下拖地图，标记会僵在原地（那是明显的错位）。
    // 解冻时由 didUpdateWidget 置 _forceMarkerRebuild 补一次重建。
    if (widget.frozen &&
        _markerCache != null &&
        viewHash == _markerViewHash &&
        selHash == _markerSelHash) {
      return _markerCache!;
    }
    // 可见台站列表身份变化（台站版本 / 搜索 / 图层筛选 / 国家筛选变化都会使 _visible
    // 返回新列表）→ 立即重建，保证实时与筛选生效；
    // 视图(拖动/缩放/选中)变化 → 立即重建，保证跟手；
    // 都没有变化（每秒 tick）→ 直接复用缓存，不再重建 Marker；
    // 尺寸变化(键盘动画) → 150ms 节流
    final vis = _visible;
    final visChanged = !identical(vis, _markerVisibleList);
    final viewChanged =
        viewHash != _markerViewHash || selHash != _markerSelHash;
    final force = _forceMarkerRebuild;
    _forceMarkerRebuild = false;
    // 设置里切换「始终显示标签」也要重建：否则缓存复用会让开关“点了没反应”。
    final labelsAlways = widget.state.mapLabelsAlways;
    final labelsAlwaysChanged = labelsAlways != _markerLabelsAlways;
    final sizeChanged = _markerCacheSize != size;
    final elapsed = now.difference(_markerCacheTime).inMilliseconds;
    final fresh =
        _markerCache != null &&
        !force &&
        !visChanged &&
        !viewChanged &&
        !labelsAlwaysChanged &&
        (sizeChanged ? elapsed < 150 : true);
    if (fresh) return _markerCache!;
    _markerCacheTime = now;
    _markerCacheSize = size;
    _markerViewHash = viewHash;
    _markerSelHash = selHash;
    _markerVisibleList = vis;
    _markerLabelsAlways = labelsAlways;
    _markerCache = _buildMarkers(size);
    return _markerCache!;
  }

  List<Widget> _buildMarkers(Size size) {
    final stations = _visible;
    // 台站密的时候（或缩得很小）不画呼号标签：文字排版是每个标记最贵的一步。
    // 设置里可强制「无论密度/缩放都显示」（见 AppState.mapLabelsAlways）。
    final showLabels = widget.state.mapLabelsAlways ||
        stations.length <= 60 ||
        _zoom >= 13;
    // 先滤掉屏幕外台站（含少量留白），避免为不可见台站创建 widget
    return stations.where((s) {
      final p = _toScreen(s.lat, s.lng, size);
      return p.dx >= -60 && p.dx <= size.width + 60 &&
          p.dy >= -60 && p.dy <= size.height + 60;
    }).map((s) {
      final pos = _toScreen(s.lat, s.lng, size);
      final sel = _selected?.call == s.call;
      // 选中后那条小条（宽 196）的落点：以标记为中心，再夹进屏幕；
      // 下方放不下（离底边近）就翻到标记上方，免得被屏幕边缘切掉。
      final chipLeft = (pos.dx - 98)
              .clamp(6.0, math.max(6.0, size.width - 202.0)) -
          (pos.dx - 28);
      final chipTop = pos.dy > size.height - 150 ? -78.0 : 34.0;
      final pulsing = s.effectiveStatus == St.moving || sel;
      final dx = pos.dx - 28;
      final dy = pos.dy - 28;
      // key = 呼号：列表变化时按身份复用元素，而不是整段重建。
      return Positioned(
        key: ValueKey(s.call),
        left: dx,
        top: dy,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _selected = s),
          onDoubleTap: () => _openDetail(s),
          // 单击只「选中并显示标签 / 信息窗」，不再把地图飞过去 ——
          // 之前单击会直接动画平移到该台站并放大到 z14，地图一跳，
          // 想连看几个相邻台站就得反复拖回来。需要详情走双击（或信息窗）。
          onTap: () => setState(() => _selected = s),
          // 长按信标：呼出快速消息面板（就近发一条短信，不必先进消息页）。
          // 命中区本来就是这颗标记自身的 56×56 方框，不会抢地图的长按手势。
          onLongPress: () => _showQuickMessage(s),
          // **translucent**：标记与它身后的地图都收到这个指针，由手势竞技场裁决。
          // 用 opaque 会把地图的手势挡掉 —— 手指正好落在台站上时就没法缩放/拖动了。
          behavior: HitTestBehavior.translucent,
          child: RepaintBoundary(
            child: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 脉冲扩散圈：单独 RepaintBoundary 隔离，动画帧不重绘图标/标签
                  if (pulsing)
                    RepaintBoundary(
                        child: _PulseRing(color: s.color, sel: sel, anim: _pulse)),
                  // APRS 官方符号图标原图（不加圆底/描边圈）
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Center(
                      child: AprsSymbolImage(
                        s.symbol,
                        s.symbolTable,
                        size: sel ? 30 : 24,
                        grayscale: s.effectiveStatus == St.offline,
                        // 卫星影像底图：给符号加一圈深色光晕，否则彩色/浅色
                        // 符号压在明亮的航拍纹理上会「糊」进背景。
                        halo: _isSat,
                      ),
                    ),
                  ),
                  // 常驻呼号标签（仅未选中、且台站不密时显示）
                  if (!sel && showLabels)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 40,
                      child: _callLabel(s),
                    ),
                  if (sel)
                    Positioned(
                      top: chipTop,
                      left: chipLeft,
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

  /// 台站常驻呼号小标签。
  ///
  /// 街道图用「白底 + 台站色字」；卫星影像用「深底 + 白字」——
  /// 白底小字压在明亮航拍纹理上会被背景吃掉，深底反而更跳。
  Widget _callLabel(Station s) {
    final sat = _isSat;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        constraints: const BoxConstraints(maxWidth: 120),
        decoration: BoxDecoration(
          color: sat
              ? const Color(0xD9101418)
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: sat
                ? Colors.white.withValues(alpha: 0.28)
                : s.color.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          s.call,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ts(9, c: sat ? Colors.white : s.color, w: FontWeight.w700, h: 1.0),
        ),
      ),
    );
  }

  /// 单击台站后跟着标记走的那条小条（不是详情面板 —— 详情走双击）。
  ///
  /// 上一版是一段用 ` · ` 串起来的长文本：呼号、状态、速度、高度、距离、
  /// 备注、状态报文、还有一句「点击查看」全挤在同一个 StringBuffer 里，
  /// 换行位置全看字多不多 —— 窄屏上会拉成一长条，读起来要横着扫。
  ///
  /// 现在按「一层一件事」排：
  ///   ① 呼号单独一行（右侧箭头示意可点）；
  ///   ② 状态行：在线点 + 状态 + 距离；
  ///   ③ 数字行：速度 / 高度 / 网格（有哪个写哪个，不占位 `--`）；
  ///   ④ 备注（最多两行，网址照旧可点）；
  ///   ⑤ 状态报文（紫色，独立一帧的东西，不与备注混行）。
  ///
  /// 固定宽度 + 在 [_buildMarkers] 里按屏幕边缘夹紧，手机上不会顶出画面。
  Widget _infoWindow(Station s) {
    final online = s.effectiveStatus != St.offline;
    final my = widget.state.myStation;
    final dist = my == null
        ? null
        : '${s.distKm(my.lat, my.lng).toStringAsFixed(1)} km';
    final nums = <String>[
      if (s.speed != null) s.speedStr,
      if (s.alt != null) s.altStr,
      s.grid,
    ];
    final comment = s.comment?.trim() ?? '';
    final statusText = s.statusText?.trim() ?? '';
    // blurSigma: C.chipBlur —— 跟手的小浮层不值得自己再算一层 12 的离屏模糊
    return MaterialSurface(
      radius: 12,
      blurSigma: C.chipBlur,
      child: Container(
        width: 196,
        padding: const EdgeInsets.fromLTRB(10, 7, 8, 8),
        decoration: BoxDecoration(
          color: C.chipFill,
          borderRadius: BorderRadius.circular(12),
          boxShadow: elev2(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ① 头行：呼号单独占一行（它永远不该被后面的状态/距离挤成省略号 ——
            //    用户：「它呼号显示不全，呼号要单独一行」）
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.call,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(13, c: s.color, w: FontWeight.w800, ls: 0.3),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 14, color: C.greyLight),
              ],
            ),
            // ② 状态行：在线点 + 状态 + 距离
            const SizedBox(height: 1),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: online ? C.green : C.greyLight,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  localizedStatusLabel(context, s.effectiveStatus),
                  style: ts(9.5, c: C.grey),
                ),
                const Spacer(),
                if (dist != null)
                  Text(dist, style: ts(9.5, c: C.slate, w: FontWeight.w600)),
              ],
            ),
            // ③ 数字行：只写在的
            const SizedBox(height: 2),
            Text(
              nums.join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(10.5, c: C.slate, w: FontWeight.w600),
            ),
            // ④ 备注（中继频点 / 活动公告常在这里，网址可点）
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 4),
              StationNote(comment,
                  maxLines: 2, style: ts(10, c: C.ink, h: 1.35)),
            ],
            // ⑤ 状态报文：与备注是两个字段，各自一行
            if (statusText.isNotEmpty) ...[
              const SizedBox(height: 3),
              StationNote(statusText,
                  maxLines: 1, style: ts(10, c: C.purple, h: 1.35)),
            ],
          ],
        ),
      ),
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
              return Stack(
                alignment: Alignment.center,
                children: [
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
                  // 方位角「小角角」：朝航向伸出的三角箭头。
                  // **放在圆点之前（其下层）**：三角底边藏进圆点、被圆点盖住，
                  // 屏幕上只剩圆环外露出的尖角；与圆点同心叠放（放进圆点的 child
                  // 会被圆形裁剪）。
                  //
                  // 航向朝上时画布已经转过 -航向，箭头要再叠上同一个角，屏幕上
                  // 它才仍指着行进方向（与沉浸页同一口径）。
                  HeadingCornerIndicator(
                    course: widget.state.myCourse == null
                        ? null
                        : widget.state.myCourse! + _rot * 180 / math.pi,
                    accent: C.blue,
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
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.my_location_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                  Positioned(
                    top: 30,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: C.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${S.of(context).meLabel} · ${widget.state.myCall}',
                        style: ts(9, c: Colors.white, w: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 焦点标记：`AppState.focusOnMap` 指定的目标点（来自策略地图「导航」等）。
  ///
  /// 目标点往往**不在台站表里**（策略元素是远端合成出来的），台站标记画不到它，
  /// 所以要单独画一枚。它随 `mapFocusSeq` 变化重建；[frozen] 冻结时仍会重绘
  /// 一次（frozen 只节流台站标记，焦点标记是独立 Stack 项，不受标记缓存影响）。
  Widget _focusMarker(Size size) {
    final f = widget.state.mapFocus;
    if (f == null || widget.state.mapFocusSeq == 0) {
      return const SizedBox.shrink();
    }
    // 目标若是**真实台站**（台站列表现有项），台站标记已经会画它，
    // 再叠一枚焦点标记只会糊成一团。只有「台站表里没有的点」（策略元素）
    // 才需要这枚补画。用 _visible 而非 all stations：被筛选隐藏的台站
    // 也该补上，否则用户看不到导航目标。
    if (_visible.any((s) => s.call == f.call)) {
      return const SizedBox.shrink();
    }
    final pos = _toScreen(f.lat, f.lng, size);
    return Positioned(
      left: pos.dx - 20,
      top: pos.dy - 20,
      child: IgnorePointer(
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 外圈脉冲底（静态，不接动画，避免与地图脉冲混淆）
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: C.orange.withValues(alpha: 0.22),
                ),
              ),
              // 主体：橙色圆 + 白边
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: C.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: elev2(),
                ),
                child: const Icon(Icons.place_rounded,
                    size: 12, color: Colors.white),
              ),
              // 标签（策略元素名/ID），压在点上方
              Positioned(
                top: -18,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 140),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: C.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    f.call,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(9, c: Colors.white, w: FontWeight.w700),
                  ),
                ),
              ),
            ],
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
      builder: (_) => MaterialSurface(
        radius: 24,
        topOnly: true,
        child: Container(
          decoration: BoxDecoration(
            color: C.sheetFill,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: C.blueBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.my_location_rounded,
                        color: C.blue,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.of(context).myLocationPanel(st.myCall),
                            style: ts(16, w: FontWeight.w800),
                          ),
                          Text(
                            localizedLocationStatus(context, st.locStatus),
                            style: ts(11,
                                c: st.myPositionReportable ? C.green : C.yellow),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: C.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SoftCard(
                  padding: const EdgeInsets.all(14),
                  child: ValueListenableBuilder<int>(
                    // 弹层里也有「距下次上报」这种秒级字段，同样挂到 tick 上：
                    // 弹层是点开时一次性构建的，不挂的话开着它秒数一样不动。
                    valueListenable: st.tick,
                    builder: (_, _, _) => Column(
                      children: [
                        KV(
                          S.of(context).latitude,
                          st.myLat == null
                              ? '--'
                              : fmtLat(st.myLat!, st.coordFmt),
                          icon: Icons.explore_rounded,
                        ),
                        const SizedBox(height: 8),
                        KV(
                          S.of(context).longitude,
                          st.myLng == null
                              ? '--'
                              : fmtLng(st.myLng!, st.coordFmt),
                          icon: Icons.explore_rounded,
                        ),
                        // 定位精度：GPS 实测值（1σ）。以前它算而不报，用户无从
                        // 判断眼前这个点到底是「±5m」还是「±80m」——
                        // 而这两种情况的可用性完全不同
                        if (st.myAccuracy > 0) ...[
                          const SizedBox(height: 8),
                          KV(
                            S.of(context).posAccuracy,
                            '±${fmtUncertaintyM(st.myAccuracy)}',
                            icon: Icons.my_location_rounded,
                          ),
                        ],
                        const SizedBox(height: 8),
                        KV('Maidenhead', st.myGrid, icon: Icons.grid_4x4_rounded),
                        const SizedBox(height: 8),
                        KV(
                          S.of(context).speedLabel,
                          st.mySpeed != null
                              ? '${st.mySpeed!.toStringAsFixed(1)} km/h'
                              : '--',
                          icon: Icons.speed_rounded,
                        ),
                        const SizedBox(height: 8),
                        KV(
                          S.of(context).bearing,
                          st.myCourse != null
                              ? '${st.myCourse!.toStringAsFixed(0)}°'
                              : '--',
                          icon: Icons.explore_rounded,
                        ),
                        const SizedBox(height: 8),
                        KV(
                          S.of(context).beaconIntervalLabel,
                          // ⚠ 必须用 beaconIntervalNow（生效值）：纯网络模式下
                          // 生效值是 beaconNetInterval，智能模式下是当前档位间隔；
                          // 用 st.beaconInterval 会显示固定模式那个旧字段，与倒计时
                          // （按 beaconIntervalNow 走）对不上。
                          st.smartBeaconEnabled
                              ? '智能 · ${S.of(context).secondsValue(st.beaconIntervalNow)}'
                              : S.of(context).secondsValue(st.beaconIntervalNow),
                          icon: Icons.timer_rounded,
                        ),
                        const SizedBox(height: 8),
                        KV(
                          S.of(context).beaconsSentLabel,
                          S.of(context).countTimes(st.beaconsSent),
                          icon: Icons.sync_rounded,
                        ),
                        const SizedBox(height: 8),
                        KV(
                          S.of(context).nextBeaconLabel,
                          st.nextBeaconIn,
                          icon: Icons.access_time_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          st.sendBeacon();
                          // 上报闸（myPositionReportable）会挡住「还没本轮定位」的点；
                          // 这里如实反馈，别弹一条假的「已发送」。
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(st.myPositionReportable
                                  ? S.of(context).positionBeaconDetail(
                                      st.myGrid,
                                      st.beaconAttachedDetail,
                                    )
                                  : S.of(context).beaconWaitingFix),
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
                        icon: Icon(Icons.edit_location_alt_rounded, size: 16),
                        label: Text(S.of(context).reselectPoint),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: C.blue,
                          side: BorderSide(color: C.blue.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: ts(12, w: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleMapTap(Offset pos) {
    if (_pickMode) {
      // 选点模式：点击地图设为我的位置
      //
      // `pos` 是**底图局部坐标**：航向朝上时底图在「对角线画布」里，要先
      // 换算回页面坐标（[_canvasToPage]），再反算经纬度。（没转时原样。）
      final (lat, lng) = _screenToLatLng(
        _canvasToPage(pos, _lastSize),
        _lastSize,
      );
      widget.state.setMyPosition(lat, lng);
      widget.state.finishPick();
      setState(() {
        _pickMode = false;
        _selected = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S
                .of(context)
                .pickedCoord(
                  maidenhead(lat, lng),
                  fmtLat(lat, widget.state.coordFmt),
                  fmtLng(lng, widget.state.coordFmt),
                ),
          ),
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
          content: Text(
            S
                .of(context)
                .pickedCoord(
                  maidenhead(lat, lng),
                  fmtLat(lat, widget.state.coordFmt),
                  fmtLng(lng, widget.state.coordFmt),
                ),
          ),
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

  /// 长按信标呼出的「快速消息」面板。
  ///
  /// 目标是从地图上直接给某个台站就近发一条短信，不用先进消息页再找会话。
  /// - 输入框自动聚焦并带上收件人提示；
  /// - 只有一个「发送」按钮，发送即调用 [AppState.sendMessage]（与消息页同一条路径，
  ///   长度校验、翻译、待发队列等行为完全一致），不在此重复实现发送逻辑；
  /// - 空白内容不允许发送，避免误触发出空报文。
  void _showQuickMessage(Station s) {
    final st = widget.state;
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: MaterialSurface(
          radius: 24,
          topOnly: true,
          child: Container(
            decoration: BoxDecoration(
              color: C.sheetFill,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: s.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: AprsSymbolImage(
                            s.symbol,
                            s.symbolTable,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.of(ctx).sendMessageTo(s.call),
                              style: ts(14, w: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.call,
                              style: ts(11, c: C.slate),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: C.slate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    textInputAction: TextInputAction.send,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: S.of(ctx).sendToCallHint(s.call),
                      filled: true,
                      fillColor: C.surfaceFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (v) {
                      final text = v.trim();
                      if (text.isEmpty) return;
                      st.sendMessage(s.call, text);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            S.of(ctx).cancel,
                            style: ts(13, c: C.slate, w: FontWeight.w600),
                          ),
                        ),
                      ),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: C.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final text = ctrl.text.trim();
                            if (text.isEmpty) return;
                            st.sendMessage(s.call, text);
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            S.of(ctx).send,
                            style: ts(13, c: Colors.white, w: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 覆盖控件 ───
  /// 心率胶囊（主屏幕左上，最上面那一个）。
  ///
  /// **没有读数就整块不出现**（返回 `SizedBox.shrink()`，连 10px 间隙也由调用处
  /// 那两条 `SizedBox` 自己塌陷成 0 高 —— 实际上会剩 10px 空隙，所以这里让它
  /// 在无读数时连间隙都不要：见 build 里用 `_hrChip()` 返回的 widget 是否为空）。
  /// 一屏浮层上摆一个永远是空白的胶囊，比不显示更糟。
  Widget _hrChip() {
    final st = widget.state;
    final hr = st.myHr;
    if (hr == null) return const SizedBox.shrink();
    // 来源标注：心率带连上就写 BLE，否则若是佳明在跑就写 Garmin。
    // 不标来源的话，用户看到 140 会不知道是胸带还是手表报的。
    final fromBle = st.bleHr.connected;
    final tag = fromBle ? 'BLE' : (st.garminOn ? 'Garmin' : '');
    final live = fromBle ? st.bleHr.bpm != null : st.garminOn;
    return MaterialSurface(
      radius: 16,
      blurSigma: C.chipBlur,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: C.chipFill,
          borderRadius: BorderRadius.circular(16),
          boxShadow: elev2(),
          border: Border.all(color: C.red.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_rounded, size: 14, color: C.red),
            const SizedBox(width: 6),
            Text(
              '$hr',
              style: ts(15, c: C.red, w: FontWeight.w800),
            ),
            const SizedBox(width: 3),
            Text('bpm', style: ts(10, c: C.grey)),
            if (tag.isNotEmpty) ...[
              const SizedBox(width: 7),
              // 读数过期（心率带掉线 / 佳明没在跑）时灰掉来源，别让人以为还在测
              Text(tag, style: ts(9.5, c: live ? C.red : C.greyLight, w: FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(List<Station> vis, bool searched) {
    return MaterialSurface(
      radius: 16,
      blurSigma: C.chipBlur,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: C.chipFill,
          borderRadius: BorderRadius.circular(16),
          boxShadow: elev2(),
        ),
        // 三段计数都是**定宽子项**（一个 Text 一个图标，没有弹性），而它能拿到的
        // 宽度由外壳给的 left/right 决定 —— 2.0 横屏下（左侧竖条 + 展开的内容面板）
        // 常只剩 200 出头，三段中文/西语文案必然撑爆 Row（debug 下溢出条纹、
        // release 下直接被截）。所以按**实际可用宽度**分两档：够宽给三段，紧的
        // 时候只留「在线 + 台站」（移动数最次要），每个计数再用 Flexible + ellipsis
        // 兜底（西语的「en movimiento」比中文长一倍）。
        child: LayoutBuilder(
          builder: (_, cons) {
            final compact = cons.maxWidth < 250;
            final online = Flexible(
              child: Text(
                S.of(context).onlineCount(widget.state.online),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(12, c: C.green, w: FontWeight.w600),
              ),
            );
            final moving = Flexible(
              child: Text(
                S.of(context).movingCount(widget.state.moving),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(12, c: C.blue, w: FontWeight.w600),
              ),
            );
            final stations = Flexible(
              child: Text(
                S.of(context).stationCount(vis.length),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(12, c: searched ? C.slate : C.grey),
              ),
            );
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(C.green),
                const SizedBox(width: 6),
                online,
                if (!compact) ...[
                  const SizedBox(width: 12),
                  _dot(C.blue),
                  const SizedBox(width: 6),
                  moving,
                ],
                const SizedBox(width: 12),
                _dot(C.slate),
                const SizedBox(width: 6),
                stations,
              ],
            );
          },
        ),
      ),
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
          child: Row(
            children: [
              Container(
                width: 3,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                group == '高德'
                    ? S.of(context).amapGroup
                    : group == '地形'
                        ? S.of(context).terrainGroup
                        : group == '天地图'
                            ? S.of(context).tiandituGroup
                            : S.of(context).otherType,
                style: ts(10, c: color, w: FontWeight.w700),
              ),
            ],
          ),
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _currentMapType == t
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 16,
                    color: _currentMapType == t ? C.blue : C.grey,
                  ),
                  SizedBox(width: 10),
                  Text(
                    localizedMapTypeLabel(context, t.name),
                    style: ts(
                      13,
                      c: _currentMapType == t ? C.blue : C.ink,
                      w: _currentMapType == t
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 2),
      ],
    );
  }

  /// 右侧工具列的单颗按钮（统一 38×38 / 圆角 12 / 柔和投影）。
  /// 抽出来是为了让工具列能写成单个 Column 顺序排布，
  /// 避免多个硬编码 top 的 Positioned 在矮屏上互相重叠。
  Widget _toolBtn({
    required IconData icon,
    required VoidCallback onTap,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return ClickCursor(
      child: GestureDetector(
        onTap: onTap,
        // ⚠ 必须显式 opaque：按钮的底色来自 `BoxDecoration`，而它对应的
        // `DecoratedBox`（`RenderDecoratedBox extends RenderProxyBox`）**不重写
        // `hitTestSelf`** —— 也就是**不吸收点击**，命中全交给子节点。默认的
        // `deferToChild` 于是把可点区域缩到中间那个 20px 图标上：38px 的按钮
        // 只有中心 28% 能点，按到边缘/圆角**完全没反应**（用户报的
        // 「图层选择面板打不开」就是这么来的：他按的是按钮，不是图标）。
        behavior: HitTestBehavior.opaque,
        child: MaterialSurface(
          radius: 12,
          // 38px 的小控件：不模糊（省一层离屏重绘），所以 bg 必须由调用方给
          // 「实心」的 chipTint —— 本函数的三个调用点都这么传。
          blurSigma: C.chipBlur,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: elev1(),
              border: Border.all(color: border),
            ),
            child: Icon(icon, size: 20, color: fg),
          ),
        ),
      ),
    );
  }

  /// 右侧工具列。
  ///
  /// 竖屏（及高度充裕的横屏）用**单列**；矮横屏（`shortWide`）必须换成**两列**。
  ///
  /// 为什么：单列共 8 个按钮 ≈ 346px（3 个工具钮 126 + 5 个缩放钮 214 + 间隙），
  /// 而手机横放时可用高度常只有 300px 出头 —— 单列会被 Stack 裁掉（默认
  /// `Clip.hardEdge`），而裁掉的恰好是最下面的「定位」：横屏看地图时最常用的
  /// 那一个。横向空间在横屏是宽裕的，所以分两列是最直接的解法，
  /// 分组也是现成的：左列「图层 / 轨迹分组 / 底图」，右列「缩放 / 轨迹 / 热力图 / 定位」。
  ///
  /// 两列都靠上对齐（`CrossAxisAlignment.start`），否则高的那列会把矮的推居中，
  /// 上沿就不是齐的了。
  Widget _rightToolbar(bool shortWide) {
    final toolCol = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _toolBtn(
          icon: Icons.layers_rounded,
          onTap: () => _showLayerMenu(context),
          // 用 surfaceTint 保留「选中变蓝 / 普通白」的语义，
          // 只让通透程度跟着材质走（详见 material.dart）
          bg: chipTint(_hiddenTypes.isNotEmpty ? C.blueBg : C.white),
          fg: _hiddenTypes.isNotEmpty ? C.blue : C.slate,
          border: _hiddenTypes.isNotEmpty ? C.blue : C.border,
        ),
        const SizedBox(height: 6),
        _toolBtn(
          icon: Icons.group_rounded,
          onTap: () => showTrackGroupPicker(context, widget.state),
          bg: C.orangeBg,
          fg: C.orange,
          border: C.orange.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 6),
        _toolBtn(
          icon: Icons.flag_rounded,
          onTap: _openStrategyMap,
          bg: C.green.withValues(alpha: 0.14),
          fg: C.green,
          border: C.green.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 6),
        _toolBtn(
          icon: Icons.map_rounded,
          // ⚠ 必须带 ()：写成 `() => _showMapTypeMenu` 只是**返回这个函数本身**，
          // 从不调用它 —— 点下去等于什么都不做（用户报的「底图选择面板弹不出来」）。
          // 而 Dart 允许把 `void Function() Function()` 赋给 `VoidCallback`
          // （返回值位置的 `void` 是顶类型），所以编译与 analyze **都不会报**。
          onTap: () => _showMapTypeMenu(),
          bg: chipTint(C.white),
          fg: C.slate,
          border: C.border,
        ),
      ],
    );
    if (!shortWide) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [toolCol, const SizedBox(height: 6), _zoomCtrl()],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [toolCol, const SizedBox(width: 6), _zoomCtrl()],
    );
  }

  /// 沉浸地图入口（导航风格：以我为中心 / 航向朝上 / 四角 HUD）。
  ///
  /// 它是**左上竖列**的一员（与统计条、引导卡同列），不再自己算 Positioned：
  /// 这条入口原先单独放在 `top: topBase + 44`，右侧工具列实际含 8 个按钮
  /// （一直排到 400 多），一旦有人改列间距它就会被别人盖住 —— 曾经被引导卡糊住过。
  Widget _immersiveEntry() {
    return ClickCursor(
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ImmersiveMapPage(state: widget.state)),
        ),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: C.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(12),
            boxShadow: elev1(),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Tooltip(
            message: S.of(context).immersiveMapTip,
            child: const Icon(Icons.navigation_rounded,
                size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _zoomCtrl() {
    return Column(
      children: [
        RoundIconBtn(
          Icons.add_rounded,
          onTap: () {
            if (_usePluginMap) {
              _pluginAction('zoomIn');
              return;
            }
            final z = (_zoom + 1).clamp(3.0, 19.0);
            _animateTo(z, _panForCenter(z));
          },
        ),
        SizedBox(height: 6),
        RoundIconBtn(
          Icons.remove_rounded,
          onTap: () {
            if (_usePluginMap) {
              _pluginAction('zoomOut');
              return;
            }
            final z = (_zoom - 1).clamp(3.0, 19.0);
            _animateTo(z, _panForCenter(z));
          },
        ),
        SizedBox(height: 6),
        RoundIconBtn(
          _showTracks ? Icons.route_rounded : Icons.route_outlined,
          tooltip: S.of(context).track,
          color: _showTracks ? C.green : C.slate,
          onTap: () => setState(() => _showTracks = !_showTracks),
        ),
        SizedBox(height: 6),
        // 低缩放热力图开关
        RoundIconBtn(
          _heatEnabled
              ? Icons.local_fire_department_rounded
              : Icons.local_fire_department_outlined,
          tooltip: S.of(context).heatmap,
          color: _heatEnabled ? C.orange : C.slate,
          onTap: () => setState(() => _heatEnabled = !_heatEnabled),
        ),
        SizedBox(height: 6),
        RoundIconBtn(
          Icons.my_location_rounded,
          tooltip: S.of(context).locateMe,
          color: C.blue,
          onTap: () {
            if (_usePluginMap) {
              _pluginAction('myLoc');
              return;
            }
            if (widget.state.myHasFix) {
              _animateTo(
                15.0,
                _panFor(widget.state.myLat!, widget.state.myLng!, 15.0),
              );
            } else {
              _animateTo(11.0, Offset.zero);
            }
          },
        ),
        SizedBox(height: 6),
        // ── 锁定地图中心（三态）──
        //
        // 与上面那颗「定位」配成一对：定位是**跳一次**（还会把缩放拉到 15），
        // 锁定是**一直跟着** —— 开了之后自己走动时地图持续把我的位置摆在中心，
        // 缩放交给用户（锁定只管位置，不抢缩放）。
        //
        // 用户要求把这一颗改成切换，于是三态循环：
        //   关（自由拖动）→ 锁定中心·正北朝上 → 锁定中心·航向朝上 → 关
        // 图标用 gps_fixed / gps_not_fixed 这一对：它就是「定位是否锁在我身上」
        // 的通用符号，比再画一颗准星更不容易被认成别的意思；航向朝上那态
        // 换成指南针（explore），与沉浸页切航向的按钮同一套图标。
        RoundIconBtn(
          _followMode == 1
              ? Icons.gps_fixed_rounded
              : (_followMode == 2
                    ? Icons.explore_rounded
                    : Icons.gps_not_fixed_rounded),
          // 提示语说的是**这一下按下去会切到哪**：
          // 关 → 锁定中心 → 航向朝上 → 关（最后一态回到「取消锁定」）
          tooltip: _followMode == 0
              ? S.of(context).lockMapCenter
              : (_followMode == 1
                    ? S.of(context).headingUp
                    : S.of(context).unlockMapCenter),
          color: _followMe ? C.blue : C.slate,
          onTap: () {
            final st = widget.state;
            final next = (_followMode + 1) % 3;
            if (next > 0 &&
                st.myHasFix &&
                st.myLat != null &&
                st.myLng != null) {
              // 打开就立刻居中一次（不缩放），否则要等到下一个定位点才生效，
              // 按下去像没反应。
              _setView(_zoom, _panFor(st.myLat!, st.myLng!, _zoom));
            }
            setState(() => st.setMapFollowMode(next));
          },
        ),
      ],
    );
  }

  // ─── 插件地图（矢量）动作分发 ───
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
      builder: (ctx) => Stack(
        children: [
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
            top: 14 + widget.topInset,
            child: Material(
              color: Colors.transparent,
              child: StatefulBuilder(
                builder: (ctx, setMenuState) =>
                    _layerPanelContent(setMenuState, () {
                      entry.remove();
                    }),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(entry);
  }

  /// 打开策略地图（先确定用哪个群）。
  ///
  /// 策略地图是**群维度**的功能：没有群就没法共享。有多个群时让用户选一个，
  /// 只有一个群就直接进去，省一步点击。
  void _openStrategyMap() {
    final st = widget.state;
    if (st.chatGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).strategyNeedGroup),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    void open(ChatGroup g) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StrategyMapPage(
          state: st,
          groupCall: g.groupCall,
          groupName: g.name,
        ),
      ),
    );
    if (st.chatGroups.length == 1) {
      open(st.chatGroups.first);
      return;
    }
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.of(ctx).strategyPickGroup,
                    style: ts(16, w: FontWeight.w800)),
                const SizedBox(height: 10),
                for (final g in st.chatGroups)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.groups_rounded),
                    title: Text(g.name, style: ts(14, w: FontWeight.w700)),
                    subtitle: Text(g.groupCall, style: ts(11, c: C.slate)),
                    onTap: () {
                      Navigator.pop(ctx);
                      open(g);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 处理「群聊消息 → 打开策略地图」请求。
  ///
  /// 消息页只能改状态（见 [AppState.openStrategyMap]），真正的外壳切页签由
  /// HomeShell2/HomePage 做；这里在地图页驻留时补上 push。
  ///
  /// push 放在**本帧末尾**（addPostFrameCallback 不改 schedule）执行，而不是等
  /// 下一帧：从策略地图点「导航」时先 `Navigator.pop` 再 `focusOnMap`，同一帧里
  /// 既设了焦点又设了跳转请求。处理视图焦点的回调也排在帧末 —— 两者在同一批
  /// 回调里按注册顺序跑完，焦点先落位、再 push，不会再出现「push 把焦点覆盖成
  /// 空」的竞态。必须帧末的另一个原因：请求可能由本帧 build/通知改出来，
  /// 此刻直接 push 会在 build 期间改导航栈。
  void _handleStrategyJump() {
    final seq = widget.state.strategyJumpSeq;
    if (seq == _lastStrategyJumpSeq) return;
    _lastStrategyJumpSeq = seq;
    final gc = widget.state.strategyJumpGroupCall;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openStrategyMapGroup(gc);
    });
  }

  /// 打开指定群的策略地图（呼号匹配不上时退回默认入口）。
  void _openStrategyMapGroup(String groupCall) {
    final st = widget.state;
    if (st.chatGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).strategyNeedGroup),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    ChatGroup? g;
    final gc = groupCall.toUpperCase();
    for (final x in st.chatGroups) {
      if (x.groupCall.toUpperCase() == gc) {
        g = x;
        break;
      }
    }
    if (g == null) {
      _openStrategyMap();
      return;
    }
    final grp = g;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StrategyMapPage(
          state: st,
          groupCall: grp.groupCall,
          groupName: grp.name,
        ),
      ),
    );
  }

  /// 地图类型切换菜单
  void _showMapTypeMenu() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
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
            top: 58 + widget.topInset,
            child: Material(
              color: Colors.transparent,
              child: MaterialSurface(
                radius: 16,
                child: Container(
                  width: 210,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: C.sheetFill,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: elev3(),
                  ),
                  // 图层较多时允许滚动，避免超出屏幕
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.68,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 高德系列
                          _mapTypeGroup('高德', C.blue, () => entry.remove()),
                          // 地形/等高线
                          _mapTypeGroup('地形', C.green, () => entry.remove()),
                          // 天地图（需 Key）
                          _mapTypeGroup('天地图', C.cyan, () => entry.remove()),
                          // 其他地图
                          _mapTypeGroup('其他', C.slate, () => entry.remove()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(entry);
  }

  Widget _layerPanelContent(StateSetter setMenuState, VoidCallback onClose) {
    final types = <(TypeGroup, String, IconData, Color)>[
      (
        TypeGroup.mobile,
        S.of(context).mobile,
        Icons.directions_car_rounded,
        C.blue,
      ),
      (TypeGroup.fixed, S.of(context).fixed, Icons.home_rounded, C.purple),
      (
        TypeGroup.infra,
        S.of(context).infrastructure,
        Icons.cell_tower_rounded,
        C.green,
      ),
      (TypeGroup.wx, S.of(context).weather, Icons.cloud_rounded, C.cyan),
      (TypeGroup.fmo, 'FMO', Icons.radio_rounded, C.orange),
      (TypeGroup.other, S.of(context).otherType, Icons.apps_rounded, C.slate),
    ];
    return MaterialSurface(
      radius: 16,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.sheetFill,
          borderRadius: BorderRadius.circular(16),
          boxShadow: elev3(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.layers_rounded, size: 15, color: C.blue),
                SizedBox(width: 6),
                Text(
                  S.of(context).layerFilter,
                  style: ts(12, w: FontWeight.w700),
                ),
                Spacer(),
                if (_hiddenTypes.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      widget.state.clearMapHiddenTypes();
                      setMenuState(() {});
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: C.blueBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        S.of(context).showAll,
                        style: ts(10, c: C.blue, w: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            // 将台站面板的筛选（状态/类型/同款软件/设备）应用到地图
            GestureDetector(
              onTap: () {
                widget.state
                    .setApplyFilterToMap(!widget.state.applyFilterToMap);
                setMenuState(() {});
                setState(() {});
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt_rounded,
                    size: 16,
                    color: widget.state.applyFilterToMap ? C.blue : C.greyLight,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context).applyStationFilter,
                          style: ts(
                            12,
                            c: widget.state.applyFilterToMap ? C.ink : C.grey,
                            w: FontWeight.w600,
                          ),
                        ),
                        if (widget.state.applyFilterToMap &&
                            !widget.state.stationFilter.isEmpty)
                          Text(
                            S.of(context).stationFilterOn,
                            style: ts(9, c: C.blue),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 22,
                    decoration: BoxDecoration(
                      color: widget.state.applyFilterToMap
                          ? C.blue.withValues(alpha: 0.25)
                          : C.greyBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Align(
                      alignment: widget.state.applyFilterToMap
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: widget.state.applyFilterToMap ? C.blue : C.grey,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 14, color: C.border),
            for (final t in types)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: GestureDetector(
                  onTap: () {
                    widget.state.toggleMapHiddenType(t.$1);
                    setMenuState(() {});
                    setState(() {});
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(
                        t.$3,
                        size: 16,
                        color: _hiddenTypes.contains(t.$1) ? C.greyLight : t.$4,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.$2,
                          style: ts(
                            12,
                            c: _hiddenTypes.contains(t.$1) ? C.grey : C.ink,
                            w: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 22,
                        decoration: BoxDecoration(
                          color: !_hiddenTypes.contains(t.$1)
                              ? t.$4.withValues(alpha: 0.25)
                              : C.greyBg,
                          borderRadius: BorderRadius.circular(12),
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
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 2,
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
          ],
        ),
      ),
    );
  }


  /// 竖屏左下角信标/上报状态胶囊：距下次上报倒计时 + 立即上报

  /// 竖屏底部“上报通知”通栏横杠：自动上报状态/倒计时 + 立即上报
  Widget _beaconBar() {
    final st = widget.state;
    final on = st.beaconEnabled;
    // 文案与颜色都从 widgets.dart 的 beaconBarText / beaconBarColor 来：
    // 精简模式的状态条用的是同一份，两处不再各写一套（见那两个函数的说明）。
    final label = beaconBarText(context, st);
    final c = beaconBarColor(st);
    return ClickCursor(
      child: GestureDetector(
        onTap: _showMyPanel,
        // 长按呼出「电台身份」编辑面板（呼号 / SSID / 台站备注）。
        // 这条横杠就是「现在这一发会发出什么」的读数牌，改呼号/备注正对着它；
        // 为此要进设置 → 电台页太绕。
        onLongPress: () => showStationIdentitySheet(context, st),
        child: MaterialSurface(
          radius: 12,
          blurSigma: C.chipBlur,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: C.chipFill,
              borderRadius: BorderRadius.circular(12),
              boxShadow: elev2(),
              border: Border.all(color: c.withValues(alpha: 0.25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 详细档在**最左侧**摆当前真要发出去的那一枚信标符号。
                    //
                    // 为什么要摆：符号不总是「我的符号」—— 智能档按速度档给不同
                    // 符号（`activeSmartTier.symbol`），纯网络定位还能单独指定一枚
                    // （`networkSymbol`，见 `beaconSymbolNow`）。只看倒计时与档位，
                    // 用户不知道这一发在地图上会长成什么样。
                    //
                    // 表字符固定 `/`：本应用的报文永远是主表
                    // （`AprsFmt.position` 写的是 `!lat/lng$symbol`）。
                    if (st.beaconBarDetailed)
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.withValues(alpha: 0.22)),
                        ),
                        // 官方符号表 PNG（与地图标记同一套资源），缺席时自己回退
                        // Material 图标；`halo` 让彩色符号在这个半透明横杠上也
                        // 分辨得出（与地图标记同一个理由）。
                        child: AprsSymbolImage(
                          st.beaconSymbolNow,
                          '/',
                          size: 18,
                          halo: true,
                        ),
                      ),
                    Icon(
                      on ? Icons.send_rounded : Icons.notifications_off_rounded,
                      size: st.beaconBarDetailed ? 16 : 14,
                      color: c,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: ts(st.beaconBarDetailed ? 12.5 : 11,
                            c: C.ink, w: FontWeight.w600),
                      ),
                    ),
                    // 上报动作组（切换自动上报 + 立即上报）——三处共用同一个
                    // widgets.ReportActions，不再各写一份（见该 widget 说明）。
                    ReportActions(state: st),
                  ],
                ),
                // ── 详细档：一行「当前触发条件」（issue #21-2）──
                //
                // 秒级字段（倒计时/还差多少米）必须挂到 `tick` 上：这一条每
                // 秒重建一次，但只有这一行 —— 整个面板/地图不跟着重建（若把
                // 它挂到整页上，就是每秒重刷一遍地图与标记）。
                //
                // 不挂到 `st` 本身：`_notify()` 在收包高峰会每秒叫好几次，
                // 而这一行的信息量只到「秒」，按 tick 刷新就是恰当的频次。
                if (st.beaconBarDetailed)
                  ValueListenableBuilder<int>(
                    valueListenable: st.tick,
                    builder: (_, _, _) => Padding(
                      padding: const EdgeInsets.only(top: 5, left: 2),
                      child: Text(
                        _beaconCriteriaLine(st),
                        style: ts(10.5, c: C.slate, h: 1.3, w: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 详细档那一行「当前触发条件」（issue #21-2）。
  ///
  /// 只摆**真的生效**的量（门限全部来自 AppState 的 `...Now` getter）：
  /// 当前档位、还剩多少秒、距离打点还差多少米、转弯还差多少度；
  /// 没有开、或当前模式下不适用的判据**如实写「关」**，而不是隐藏 ——
  /// 隐藏会让人以为「这一档本该有距离打点」。
  String _beaconCriteriaLine(AppState st) {
    final s = S.of(context);
    final parts = <String>[];

    // ① 当前档位：智能档按速度区间描述；纯网络是固定间隔；其余是固定间隔。
    if (st.locationMode == 'network') {
      parts.add(s.beaconBarTierNetwork);
    } else if (st.smartBeaconEnabled) {
      final tier = st.activeSmartTier;
      parts.add(tier == null
          ? s.beaconBarTierSmart
          : s.beaconBarTierSmartFrom('${tier.minSpeed}'));
    } else {
      parts.add(s.beaconBarTierFixed);
    }

    // ② 时间判据：只有「确实会发射」的阶段才给倒计时；否则说原因
    //   （与 _beaconBar 的 label 同源，避免两行各说一套）。
    switch (st.beaconPhase) {
      case BeaconPhase.counting:
      case BeaconPhase.coarseForced:
        parts.add(s.beaconBarTimeLeft('${st.beaconSecondsLeft}s'));
      case BeaconPhase.imminent:
        parts.add(s.beaconBarTimeLeft(s.beaconSoon));
      default:
        // 不发射的阶段（未连接 / 等待定位 / 信标关 / 射频信标关 /
        // 网络定位暂不上报 / 佳明来源）：倒计时没有意义，因此不摆。
        // 佳明与「外接 GPS 模块」两档例外地要给来源，所以单独列出来。
        if (st.beaconPhase == BeaconPhase.garmin) {
          parts.add(s.beaconGarminSource);
        } else if (st.beaconPhase == BeaconPhase.spp) {
          parts.add(s.beaconSppSource);
        }
    }

    // ③ 距离判据：0 = 这一档没开距离打点
    final needDist = st.beaconMinDistNow;
    if (needDist > 0) {
      parts.add(s.beaconBarDistLeft(_fmtDistM(st.beaconDistToGoM)));
    }

    // ④ 转弯判据：两个闸（速度 / 最小间隔）也摆出来 —— 否则用户转了个弯
    //    却没发，会以为功能失灵（实际是速度不够或刚发过）
    final needTurn = st.beaconMinTurnNow;
    if (needTurn > 0) {
      final gateLeft = st.beaconTurnGateSecLeft;
      if ((st.mySpeed ?? 0) < AppState.turnGateSpeedKmh) {
        parts.add(s.beaconBarTurnLowSpeed('${AppState.turnGateSpeedKmh}'));
      } else if (gateLeft > 0) {
        parts.add(s.beaconBarTurnWait('${gateLeft}s'));
      } else {
        parts.add(s.beaconBarTurnLeft(
          st.beaconTurnDeg.toStringAsFixed(0),
          '$needTurn',
        ));
      }
    }

    return parts.join('  ·  ');
  }

  /// 距离 → 人读文字（米 / 公里）。
  ///
  /// 不直接调 `track_log.dart` 的 `fmtKm`：那会把地图页与历史轨迹模块绑在一起
  /// （而这里只需要一个两位数的小格式），能少一个跨层依赖就少一个。
  static String _fmtDistM(double m) {
    if (m < 1000) return '${m.round()} m';
    return '${(m / 1000).toStringAsFixed(m >= 10000 ? 0 : 1)} km';
  }

  Widget _bottomControls(Offset? hoverPos) {
    final myLat = widget.state.myLat;
    final myLng = widget.state.myLng;
    final hasFix = widget.state.myHasFix;
    // 距离：鼠标悬停点 → 我的位置；否则地图中心 → 我的位置
    String coord = S.of(context).mapDefaultCoord(_zoom.round());
    String grid = '';
    // 底图坐标系：GCJ 瓦片按用户 datum 偏好显示；国际 WGS 底图始终 WGS-84
    String datum = !_isGcjTile || widget.state.coordDatum != 'gcj'
        ? S.of(context).datumWgs
        : S.of(context).datumGcj;
    if (hoverPos != null && hoverPos.dx > 0 && _lastSize.width > 0) {
      // 悬停点是**页面坐标**（MouseRegion 在旋转之外），转过之后要反旋回来
      final (lat, lng) = _pageToLatLng(hoverPos, _lastSize);
      coord = fmtLatLng(lat, lng, widget.state.coordFmt);
      grid = maidenhead(lat, lng);
    } else if (hasFix &&
        myLat != null &&
        myLng != null &&
        _lastSize.width > 0) {
      // 计算地图中心到我的位置的距离
      final (cLat, cLng) = _screenToLatLng(
        Offset(_lastSize.width / 2, _lastSize.height / 2),
        _lastSize,
      );
      final dist = haversine(cLat, cLng, myLat, myLng);
      coord = S.of(context).distKm(dist.toStringAsFixed(1));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: MaterialSurface(
        radius: 12,
        blurSigma: C.chipBlur,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: C.chipFill,
            borderRadius: BorderRadius.circular(12),
            boxShadow: elev1(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.straighten_rounded, size: 13, color: C.slate),
              SizedBox(width: 5),
              Text(
                _scaleText,
                style: ts(10, c: C.slate, w: FontWeight.w600),
              ),
              SizedBox(width: 8),
              Container(width: 1, height: 12, color: C.border),
              SizedBox(width: 8),
              Text(
                coord,
                style: ts(11, c: C.slate, w: FontWeight.w500),
              ),
              if (grid.isNotEmpty) ...[
                SizedBox(width: 8),
                Container(width: 1, height: 12, color: C.border),
                SizedBox(width: 8),
                Text(
                  grid,
                  style: mono(10, c: C.blue, w: FontWeight.w600),
                ),
              ],
              SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: C.blueBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  datum,
                  style: ts(9, c: C.blue, w: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: c,
      boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4)],
    ),
  );
}

/// 脉冲扩散圈：仅此层在动画期间重建，避免整片标记每帧重建拖慢手势
class _PulseRing extends StatelessWidget {
  final Color color;
  final bool sel;
  final Animation<double> anim;
  const _PulseRing({
    required this.color,
    required this.sel,
    required this.anim,
  });

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
/// 信标点画笔：把「已上报到服务器」的点画成小菱形。
///
/// 为什么是菱形且只在中心画一个小点：
///   * 地图上已经有台站图标、轨迹线、精度圈，信标点再用圆形就和它们混了；
///     菱形是这里唯一没被占用的形状。
///   * 尺寸刻意很小（半宽 4）：一屏可能有几十个信标点，画大了整张图就花了；
///     它要回答的是「密度与走向」，不是「精确到哪一米」。
///
/// 只画屏幕内的（含 20px 留白）：跑一天会有上百个点，绝大多数在视野外，
/// 逐个做三角函数是白费 —— 与台站标记同一套「先滤屏外」的做法。
class _BeaconMarkPainter extends CustomPainter {
  final List<TrackPt> points;
  final Color color;
  final Offset Function(double lat, double lng) toScreen;

  /// 画布转角（航向朝上时为 -航向）。`toScreen` 已经把它算进结果，这里只
  /// 用来让 `shouldRepaint` 认得「只转了一下也是变了」。
  final double rot;

  const _BeaconMarkPainter({
    required this.points,
    required this.color,
    required this.toScreen,
    this.rot = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    // 白描边：信标点常压在轨迹线与瓦片路网上，加一圈白才分得出来
    final edge = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const r = 4.0;
    for (final p in points) {
      final o = toScreen(p.lat, p.lng);
      if (o.dx < -20 || o.dx > size.width + 20) continue;
      if (o.dy < -20 || o.dy > size.height + 20) continue;
      final path = Path()
        ..moveTo(o.dx, o.dy - r)
        ..lineTo(o.dx + r, o.dy)
        ..lineTo(o.dx, o.dy + r)
        ..lineTo(o.dx - r, o.dy)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
    }
  }

  /// 时间不参与比较：该层只在点位列表变化时重画（`beaconMarks` 增删即换实例）。
  @override
  bool shouldRepaint(covariant _BeaconMarkPainter old) =>
      !identical(old.points, points) || old.color != color || old.rot != rot;
}

class _TrackOverlayPainter extends CustomPainter {
  final List<TrackPt> points;
  final Color color;
  final Offset Function(double lat, double lng) toScreen;

  /// 画布转角（见 [_BeaconMarkPainter] 里的说明）
  final double rot;

  _TrackOverlayPainter({
    required this.points,
    required this.color,
    required this.toScreen,
    this.rot = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    // 不画平滑版本：每帧重建一条平滑轨迹的代价换不来观感（见 pos_quality.dart 顶部）。
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
      old.points != points || old.color != color || old.rot != rot;
}

/// 自己的定位精度圈：把 GPS **实测**精度如实画出来（`myAccuracy`）。
///
/// 只画一个圈，且 `shouldRepaint` 只比较位置与精度 —— **不按秒重绘**。
/// 这一点是刻意的：接收台站那套不确定圈/推测位置每秒重绘，而它叠在磨砂面板的
/// 离屏模糊上（面板一展开就每帧重算），v1.6.147 已撤掉。
class _MyAccuracyPainter extends CustomPainter {
  final double lat, lng, accuracyM;
  final Offset Function(double lat, double lng) toScreen;

  _MyAccuracyPainter({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.toScreen,
  });

  /// 单位虚线圆（半径 1），进程内只构造一次。
  /// 不用「每帧跑 PathMetrics 逐段切」—— Skia/Impeller 都不在 GPU 上做路径虚线，
  /// 切段是纯 CPU 工作（见 CHANGELOG v1.6.146 的说明）。
  static final Path _unitDash = () {
    final p = Path();
    const segs = 48;
    const dashRatio = 0.55;
    final rect = Rect.fromCircle(center: Offset.zero, radius: 1);
    for (var i = 0; i < segs; i++) {
      p.arcTo(rect, i / segs * 2 * math.pi, 2 * math.pi / segs * dashRatio, true);
    }
    return p;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final c = toScreen(lat, lng);
    // 米 → 像素：用「向北 0.001°（≈111m）」在屏幕上的位移反算，
    // 这样瓦片图（自算投影）与矢量图不用各写一套换算。
    final p2 = toScreen(lat + 0.001, lng);
    final pxPerM = (p2 - c).distance.clamp(0.01, 1e6) / 111.32;
    final r = accuracyM * pxPerM;
    if (r < 4 || r > size.longestSide * 1.5) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = C.blue.withValues(alpha: 0.6);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(r);
    paint.strokeWidth = 1.2 / r; // 抵消缩放，保证屏幕线宽不变
    canvas.drawPath(_unitDash, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MyAccuracyPainter old) =>
      old.lat != lat ||
      old.lng != lng ||
      old.accuracyM != accuracyM ||
      old.toScreen != toScreen;
}

/// 低缩放热力图：把台站按屏幕位置绘制成密度热力点（网格统计 + 色阶），无第三方依赖
class _HeatmapPainter extends CustomPainter {
  final List<Station> stations;
  final Offset Function(double lat, double lng) toScreen;
  _HeatmapPainter({
    required this.stations,
    required this.toScreen,
    this.level = 1,
    this.rot = 0,
  });

  /// 画布转角（见 [_BeaconMarkPainter] 里的说明）
  final double rot;

  /// 热力图档位 0/1/2（弱/中/强）：只缩放网格单元的半径，密度统计本身不变。
  final int level;
  double get _levelScale => level == 0 ? 0.7 : (level >= 2 ? 1.5 : 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (stations.isEmpty || size.isEmpty) return;
    // 网格单元（px）：统计每个格子内台站数作为密度
    final cell = 28.0 * _levelScale;
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;
    final grid = List<int>.filled(cols * rows, 0);
    for (final s in stations) {
      final p = toScreen(s.lat, s.lng);
      if (p.dx < 0 || p.dx > size.width || p.dy < 0 || p.dy > size.height) {
        continue;
      }
      final cx = (p.dx / cell).floor().clamp(0, cols - 1);
      final cy = (p.dy / cell).floor().clamp(0, rows - 1);
      grid[cy * cols + cx]++;
    }
    var maxC = 0;
    for (final v in grid) {
      if (v > maxC) maxC = v;
    }
    if (maxC <= 0) return;

    for (var cy = 0; cy < rows; cy++) {
      for (var cx = 0; cx < cols; cx++) {
        final c = grid[cy * cols + cx];
        if (c == 0) continue;
        final t = c / maxC; // 0..1 密度
        final center = Offset(cx * cell + cell / 2, cy * cell + cell / 2);
        final color = _heatColor(t);
        final alpha = 0.16 + t * 0.5;
        final r = cell * 0.9 + t * 6;
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              center,
              r,
              [
                color.withValues(alpha: alpha),
                color.withValues(alpha: alpha * 0.55),
                color.withValues(alpha: 0),
              ],
              [0.0, 0.5, 1.0],
            ),
        );
      }
    }
  }

  /// 密度 0..1 → 颜色（蓝 → 青 → 黄 → 红）
  Color _heatColor(double t) {
    const stops = [
      Color(0xFF2563EB),
      Color(0xFF06B6D4),
      Color(0xFFFACC15),
      Color(0xFFEF4444),
    ];
    final x = t.clamp(0.0, 1.0) * (stops.length - 1);
    final i = x.floor().clamp(0, stops.length - 2);
    return Color.lerp(stops[i], stops[i + 1], x - i)!;
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) =>
      old.stations != stations || old.rot != rot;
}

/// 把地图**画出来的**那几层裁到「可见地图区」的裁剪器。
///
/// 为什么需要（用户反馈）：「横屏地图界面上，蓝色历史轨迹线图层覆盖在了左侧定位
/// 信息卡片和底部上报状态横条（『距下次上报 47s』那一块）之上，轨迹线穿透并压住了
/// 这些 UI 浮层。」
///
/// 图层顺序本身是对的：轨迹层排在主 Stack 里所有浮层**之前**（见那里的注释），
/// 画不到卡片上面。真正的原因是那些卡片**本身是磨砂半透明的** —— 2.0 外壳的
/// 竖条 / 内容面板 / 顶栏 / 贴底浮层都悬在整屏铺满的地图之上，背后那张地图（连同
/// 这条线）会从卡片里透出来。贴左控件早就按 [MapPage.leftInset] 让开了，画上去的
/// 层却没让，表现就是「线穿过了卡片」。
///
/// 1.0 布局下地图与侧栏是并排的（传进来的几个 inset 都是 0），这个框就等于整屏，
/// 什么都不裁，与旧版逐像素一致。
class _OverlayInsetClipper extends CustomClipper<Rect> {
  /// 左侧被外壳占用的宽度（竖条 + 展开时的内容面板）。
  final double left;

  /// 顶栏高度。
  final double top;

  /// 底部贴底浮层占用的高度（上报横杠或底部坐标条）。
  final double bottom;

  _OverlayInsetClipper({
    required this.left,
    required this.top,
    required this.bottom,
  });

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
        left.clamp(0.0, size.width),
        top.clamp(0.0, size.height),
        size.width,
        (size.height - bottom).clamp(0.0, size.height),
      );

  @override
  bool shouldReclip(covariant _OverlayInsetClipper old) =>
      old.left != left || old.top != top || old.bottom != bottom;
}
