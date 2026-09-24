import 'dart:async';

import 'package:flutter/material.dart';

import 'map_page.dart';
import 'notice_banner.dart';
import 'back_router.dart';
import 'material.dart';
import 'messages_page.dart';
import 'packets_page.dart';
import 'settings_page.dart';
import 'settings_pages.dart';
import 'state.dart';
import 'stations_page.dart';
import 'theme.dart';
import 'theme_icons.dart';
import 'theme_store.dart';
import 'theme_text.dart';
import 'weather.dart';
import 'widgets.dart';

/// ─── UI 2.0 外壳：以地图为基底（重做版）───
///
/// ## 为什么推翻上一版
///
/// 上一版把 5 个页签放在**可拖拽卡片的头部**，用户反馈「底部卡片/导航那一块」
/// 最难看。复盘下来是结构缺陷，不是配色问题：
///
/// 1. **导航属于外壳，不该跟着卡片动**：卡片一展开，页签就升到屏幕中间偏上，
///    位置飘忽 —— 导航是「永远在同一个地方」的东西。
/// 2. **底部叠了两套 chrome**：把手 + 页签约 80px。收起时几乎只剩它俩，
///    展开时页签又跟着上去，怎么放都不对。
/// 3. **页签是 5 个实心色块**，而它只是个导航，视觉上过重。
/// 4. **卡片身份混乱**：它同时是导航条和内容面板，两种心智模型硬叠在一起。
///
/// ## 这一版的结构（三层，各自职责单一）
///
/// **两种朝向各一套布局**：竖屏是「地图整屏 + 底部悬浮导航 + 可拖拽内容面板」，
/// 横屏换成「地图整屏 + 左侧导航竖条 + 左侧内容面板」（见 [_landscapeBody]）——
/// 横屏高度太小，底部面板会把地图吃掉，而这一版的前提是「地图是底」。
///
/// 1. **地图整屏**（最底）：`MapPage` 一直活着，切到任何页都不销毁。
/// 2. **底部悬浮导航**（固定）：5 个页签，**永远在同一个位置**，不随内容移动。
///    半透明 + 模糊 + 胶囊外形，选中用**滑动的指示胶囊**而不是 5 块色底。
/// 3. **内容面板**（可拖拽）：只装内容，**不再包含导航**。头部是一根把手的
///    **44px 触摸区**（药丸本身只有 40×5，但整条都能抓）—— 原来只有 22px，
///    用户反馈「很难活动」。选「地图」时它整个收起，地图就是全屏的。
///
/// 拖动能从**四个地方**发起（见 [_draggableContent] 里关于手势竞技场的说明）：
/// 把手本身、底部导航条、内容不可滚动时的整片内容、以及「内容滚到顶后继续下拉」
/// （靠滚动通知）。拖完吸附到两个档位（半屏 / 近全屏），向下拖过阈值则收起回到地图。
/// 内容**可滚动且已在中间**时向上拖仍然是滚动列表 —— 这是 Flutter 手势竞技场的
/// 既定行为（内层 Scrollable 赢），与系统底部面板一致。
///
/// 地图要「让开」的地方通过两个 inset 告知：顶栏高度、底部（导航 + 面板）。
class HomeShell2 extends StatefulWidget {
  final AppState state;
  const HomeShell2({super.key, required this.state});

  @override
  State<HomeShell2> createState() => _HomeShell2State();
}

class _HomeShell2State extends State<HomeShell2>
    with SingleTickerProviderStateMixin {
  /// 当前页签（0 = 地图）
  int _tab = 0;

  /// 上一次通知时的「外壳所显示的值」快照（见 [_onState]）
  String _stateKey = '';

  /// 「在地图查看 / 在地图选点」上一次处理过的序号（见 [_onState]）。
  int _lastFocusSeq = 0;
  int _lastPickSeq = 0;

  /// 「展开内容面板」上一次处理过的序号（见 [AppState.requestSheetExpand]）。
  int _lastExpandSeq = 0;

  /// 是否刚刚用「滚动」动过面板（决定滚动结束后要不要吸附）
  bool _movedByScroll = false;

  /// 是否正在用手指拖面板（含把手/导航/内容三种发起方式）
  bool _dragging = false;

  /// 面板此刻是否在「动画 / 手拖」中。
  ///
  /// 现在它**不再用于「要不要做模糊」**：模糊一直开着，因为面板壳改成了
  /// 「自身固定为最高档高度、只裁出可视区」（见面板那一段的注释）—— 拖动时
  /// 模糊层的几何完全不变，代价只剩「底图不变时可复用」的那一次。
  ///
  /// 它现在只服务两件事：
  /// * [_paneOpen]（→ 地图冻结）—— 动画中面板也在往上长，就得算「开着」；
  /// * [_insetSheetH]（→ 传给地图的让位量）—— 动画中要传**吸附目标值**，
  ///   否则地图每帧重排重绘。
  bool get _paneAnimating => _anim.isAnimating || _dragging || _movedByScroll;

  /// 面板是否**占着屏幕**（含动画：动画中它也在往上长）。
  ///
  /// 用它来冻结地图 —— 用户的原话是「触发其他面板之后地图不再渲染，固定」。
  /// 冻结后地图仍在屏幕上（磨砂背后必须有内容），只是不再产出新的帧：
  /// 停脉冲动画、数据变化不重建标记。**视图变化仍然跟随**（拖地图时标记不会僵住）。
  bool get _paneOpen => _extent > 0.02 || _paneAnimating;


  /// 内容面板高度占屏高比例；0 = 收起（地图全屏）
  double _extent = 0;

  Tween<double> _snap = Tween(begin: 0, end: 0);
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )
    ..addListener(() => setState(() => _extent = _snap.evaluate(_anim)))
    // 动画**结束**时还要再 setState 一次：`_paneAnimating` 依赖 `isAnimating`，
    // 而它变 false 本身不会触发重建 —— 少了这一下，面板会一直停在「没有磨砂」
    // 的状态，用户会以为材质坏了（这正是最难查的那种「改了没反应」）。
    ..addStatusListener((st) {
      if (st == AnimationStatus.completed || st == AnimationStatus.dismissed) {
        if (mounted) setState(() {});
      }
    });

  /// 右上角那一簇（天气 / 在线 / 连接 / 定位）的真实高度（首帧估值，量到后校准）。
  ///
  /// 为什么不写死：高度由内容决定（状态胶囊的文字长度随语言变），写死会在别的
  /// 语言/字号下压住地图顶部的控件。
  final GlobalKey _barKey = GlobalKey();
  /// 首帧估值：右上角那一簇约 32~34 高（胶囊 6+文字+6 与圆形按钮取高者）。
  /// 先给接近真实的值，量到后校准 —— 差太多会让地图顶部控件在首帧跳一下。
  double _barH = 34;

  /// 导航胶囊高度
  static const double _kNav = 56;

  /// 未连接横幅的高度（见 [_linkBanner]）。固定值：它要参与顶部让位量的计算，
  /// 让位量必须是**确定的数**（量出来的高度会在首帧抖动一下）。
  static const double _kLinkBannerH = 36;

  /// 把手触摸区高度（药丸本身只有 40×5，但整条都能拖/能点）
  static const double _kHandle = 44;

  /// 横屏左侧导航竖条宽度
  static const double _kRailW = 70;

  /// 统一外边距（左右 / 面板与导航之间 / 导航距底）。
  ///
  /// 原来左右是 10、面板与导航之间是 8、导航距底又是 10 —— 同一组悬浮元素用三个
  /// 不同的间距，这种不一致最容易被看出来「没收拾过」。统一成一个常数后，
  /// 想调就一处调，也不会再各自漂移。
  static const double _kGutter = 10;

  /// 内容面板的「半屏」档（比例）
  static const double _kHalf = 0.46;

  /// 「近全屏」档不是固定比例，而是**由可用高度算出来**：
  /// 面板上沿不许碰到顶栏 —— 顶栏装着搜索、连接状态与定位按钮，
  /// 被面板盖住就等于这些入口消失了（0.86 这种写死的比例在小屏上正好会盖住）。

  /// 向下拖过这个比例就收起（回到地图）
  static const double _kDismiss = 0.30;

  /// 面板可达的最大高度（像素）：屏高 − 底部导航 − 面板下边距 − 顶栏占位。
  ///
  /// 用像素而不是比例，是因为它由「顶栏实际高度」决定（见上方说明）。
  /// 那个「面板下边距」不能漏：面板自己往下留了 `_kGutter`，
  /// 漏掉它算出来的上限会让面板上沿正好**贴住**顶栏（差的就是这一档间隙）。
  double _maxSheetH(Size size, double navSpace, double topInset) =>
      (size.height - navSpace - _kGutter - topInset).clamp(160.0, size.height);

  double _fullRatio(Size size, double navSpace, double topInset) =>
      _maxSheetH(size, navSpace, topInset) / size.height;

  // 新消息气泡
  bool _showBubble = false;
  String _bubbleCall = '';
  String _bubbleText = '';
  Timer? _bubbleTimer;

  static const List<(String, String)> _slots = [
    ('navMap', 'map_rounded'),
    ('navStations', 'cell_tower_rounded'),
    ('navMessages', 'chat_bubble_rounded'),
    ('navPackets', 'cable_rounded'),
    ('navSettings', 'settings_rounded'),
  ];

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onState);
    widget.state.onNewMessage = (src, text, groupId) {
      String? groupName;
      if (groupId != null) {
        for (final g in widget.state.chatGroups) {
          if (g.id == groupId) {
            groupName = g.name;
            break;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _bubbleCall =
            groupName != null ? S.of(context).groupBubble(groupName) : src;
        _bubbleText = text;
        _showBubble = true;
      });
      _bubbleTimer?.cancel();
      _bubbleTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showBubble = false);
      });
    };
  }

  @override
  void dispose() {
    _anim.dispose();
    _bubbleTimer?.cancel();
    widget.state.onNewMessage = null;
    widget.state.removeListener(_onState);
    super.dispose();
  }

  /// 只在「外壳真正显示的值」变化时重建。
  ///
  /// ── 这是「磨砂玻璃卡」最主要的成因 ──
  ///
  /// AppState 每秒 tick 一次、每次收包（250ms 节流）也会 notify；原来这里无条件
  /// `setState`，于是**整个外壳每秒被重建好几次**，而外壳里就挂着那几层
  /// `BackdropFilter` —— 每次重建都会重建这些层，模糊跟着重算。
  ///
  /// 外壳实际显示的东西只有这几项：连接状态、在线数、未读数、天气开关、
  /// 有无定位（定位按钮要用）。其余状态（收到的报文、台站列表、消息…）都由
  /// 各页**自己**监听 AppState 更新（ListenableBuilder / StreamBuilder），
  /// 不需要外壳代劳 —— 于是重建频率从「每秒数次」降到「状态真的变了才一次」。
  void _onState() {
    if (!mounted) return;
    final st = widget.state;
    // ── ① 跨页请求：页面让外壳做一件事 ──
    //
    // 这些请求**不改变外壳自己显示的值**，所以必须放在下面那个
    // 「显示值没变就 return」之前 —— 否则它们会被那行提前返回吃掉。
    //
    // 「在地图查看」（[AppState.focusOnMap]）与「在地图选点」都只是改了
    // 状态：地图那边的 `_handleViewFocus` 会把视野飞过去，而**外壳还得
    // 把页签切回地图**。1.0 里这件事在 `HomePage._onStateChanged` 做，
    // 我重写 2.0 外壳时整段漏掉了 —— 结果是台站页点「在地图查看」之后，
    // 地图在背后悄悄飞到了那个台站，用户却还停在台站面板上，看着就像
    // 「点了没反应」。
    if (st.mapFocusSeq != _lastFocusSeq || st.pickSeq != _lastPickSeq) {
      _lastFocusSeq = st.mapFocusSeq;
      _lastPickSeq = st.pickSeq;
      // 放到帧后：这两条可能由本帧的 build/通知里改出来，
      // 直接 setState 会在 build 期间标记重建。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tab != 0) _select(0);
      });
    }
    // 会话页要露出输入框 → 请求把面板展开到最高档（见 messages_page）。
    if (st.sheetExpandSeq != _lastExpandSeq) {
      _lastExpandSeq = st.sheetExpandSeq;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _tab == 0) return;
        final full = _fullRatioOf();
        if (_extent < full - 0.01) _snapTo(full);
      });
    }
    final key = '${st.connected}|${st.connecting}|${st.online}|'
        '${st.unreadMessages}|${st.weatherEnabled}|${st.myHasFix}|'
        // 未连接横幅的显隐还依赖「是不是只读模式」（见 _showLinkBanner）
        '${st.readOnlyMode}|'
        // 公告横幅的显隐与让位量都依赖这个开关
        '${st.noticeBanner}';
    if (key == _stateKey) return;
    _stateKey = key;
    setState(() {});
  }

  /// 底部导航占的总高度（含安全区与下边距）
  double _navSpace(BuildContext context) =>
      _kNav + MediaQuery.of(context).padding.bottom + _kGutter;

  /// 顶栏占的高度（顶部安全区 + 栏高 + 间隙），同时是地图顶部让位量与面板上限
  double _topInset() => MediaQuery.of(context).padding.top + 6 + _barH + 8;

  /// 当前屏高 / 面板可达的最大比例（拖动与滚动两条路共用，避免两处算法漂移）
  double _screenH() => MediaQuery.of(context).size.height;

  /// 传给地图的「面板占用高度」：动画/拖动期间取**吸附目标**，静止时取当前值。
  ///
  /// 两个值在静止时相同（所以不会出现跳变），只在动画中是「目标 vs 逐帧中间态」——
  /// 而后者正是我们不想让地图知道的：它每帧变一次，地图就每帧重排重绘一次。
  double _insetSheetH() {
    if (!_paneAnimating) return _extent * _screenH();
    // `Tween.end` 的类型是 `double?`（可以为 null），必须兜一下 ——
    // 否则 analyze 报 unchecked_use_of_nullable_value。
    final target = _anim.isAnimating ? (_snap.end ?? _extent) : _extent;
    return target.clamp(0.0, 1.0) * _screenH();
  }

  double _fullRatioOf() =>
      _fullRatio(MediaQuery.of(context).size, _navSpace(context), _topInset());

  void _snapTo(double target) {
    _snap = Tween(begin: _extent, end: target);
    _anim
      ..reset()
      ..forward();
  }

  /// 选页签：地图 → 内容面板收起（地图全屏）；其余 → 展开到半屏
  void _select(int i) {
    if (i == 2) widget.state.clearUnread();
    setState(() => _tab = i);
    _snapTo(i == 0 ? 0 : (_extent > 0.05 ? _extent : _kHalf));
  }

  void _onDrag(double dy) {
    _anim.stop();
    setState(() {
      _dragging = true; // 只用于 _paneAnimating/_insetSheetH 的判断（不再影响模糊）
      _extent = (_extent - dy / _screenH()).clamp(0.0, _fullRatioOf());
    });
  }

  void _onDragEnd() {
    if (_dragging) setState(() => _dragging = false);
    final full = _fullRatioOf();
    if (_extent < _kDismiss) {
      // 下滑关闭：回到地图（并把页签同步过去，否则导航会停在旧页签上）
      setState(() => _tab = 0);
      _snapTo(0);
      return;
    }
    _snapTo(_extent >= (_kHalf + full) / 2 ? full : _kHalf);
  }

  @override
  Widget build(BuildContext context) {
    // 顶栏量高：帧后读一次，变了才 setState（稳定后不再触发，无循环）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final h = _barKey.currentContext?.size?.height;
      if (h != null && h > 1 && (h - _barH).abs() > 0.5) {
        setState(() => _barH = h);
      }
    });

    final size = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    // 横屏（宽 > 高）：换成「左侧竖条 + 左侧内容面板」，见 [_landscapeBody]
    final isWide = size.width > size.height;
    final navSpace = _navSpace(context);
    final barTop = pad.top + 6;
    // 未连接横幅要占一行，并且**算进地图的顶部让位量**（与 bottomInset 同一套
    // 口径：给「被外壳占用的边界」）—— 不扣的话它会压住地图自己的顶部浮层。
    // 用固定高度而不是量出来的值：让位量参与面板/标记的几何，抖动一下就会被
    // 看成「界面在跳」。
    final showLink = _showLinkBanner(widget.state);
    final linkBannerH = showLink ? _kLinkBannerH + 6 : 0.0;
    // 公告横幅同样压在**地图上方**（用户要求「在主页显示横幅」），所以也要
    // 算进顶部让位量 —— 与未连接横幅同一套口径、同一个理由：不算进去它会压住
    // 地图自己的顶部浮层（信息条/图例/工具列），而且它自己也会被瓦片糊住。
    // 高度用**常量** [NoticeBanner.stripHeight]：让位量参与地图控件与面板的几何，
    // 不能是量出来会抖的值。
    final noticeH = widget.state.noticeBanner
        ? NoticeBanner.stripHeight + 6
        : 0.0;
    final topInset = _topInset() + linkBannerH + noticeH;
    // 上限就是 _maxSheetH：绝不盖住顶栏
    final maxSheetH = _maxSheetH(size, navSpace, topInset);
    final sheetH = (size.height * _extent).clamp(0.0, maxSheetH);
    final showSheet = _extent > 0.02;
    // 内容**固定**按「展开到最大时可视区的高度」布局，只裁显示区。两个理由：
    //   * 拖动时这个高度不变 → 不会逐帧重新布局（这才是这套设计的全部意义）；
    //   * 必须减掉把手：不减的话内容比可视区高一个把手，底部那一条被裁掉且滚不到
    //     （原来就是按当前的 sheetH 布局，等于每帧重排 + 底部永远有 44px 看不见）。
    final pageH = (maxSheetH - _kHandle).clamp(0.0, size.height);

    // 返回键（含 Android 手势返回 / 预测式返回）：
    //   在「地图」页 → 交给系统（正常退出应用）；
    //   在其他页    → 回到地图页，而不是直接退出。
    // 这是用户明确要的：2.0 里地图是底，其他页只是「盖在上面的内容」，
    // 按返回回到地图符合「退一层」的直觉。
    // 放在外壳（而不是各页）是因为导航本身就是外壳的事；
    // push 出来的子页（设置子页等）各自是独立路由，由 Navigator 先处理，不受影响。
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 先问内层页面要不要接手（例如消息页正停在某个会话详情里，它要的是
        // 「回会话列表」而不是「跳回地图」）。**这一步不能省**：同一个 route 上的
        // 多个 PopScope 回调会全部触发、没有优先级，不问就会出现「回到列表」
        // 和「跳到地图」同时发生。
        if (BackRouter.instance.consume()) return;
        // 不在「地图」页：回地图（_select(0) 同时会把内容面板收起）
        _select(0);
      },
      child: Scaffold(
      backgroundColor: C.pageFill,
      body: isWide ? _landscapeBody(pad, barTop, topInset) : Stack(
        children: [
          // ① 地图整屏（永远在，切换内容页也不销毁）
          Positioned.fill(
            child: MapPage(
              state: widget.state,
              isActive: true,
              // 面板开着（或正在动）期间**冻结**地图：不产出新帧（见 MapPage.frozen）。
              // 这是「面板一展开就卡」最后一块拼图 —— 冻结后地图那层
              // RepaintBoundary 的光栅化结果可以被复用，面板的模糊改成采样缓存纹理。
              frozen: _paneOpen,
              topInset: topInset,
              // 底部被占用的边界 B（自屏幕底算起）＝ 导航 + （面板 + 间隙）。
              // 地图那边的口径是「相对安全区」，所以这里减去 pad.bottom ——
              // 这样贴底控件永远落在 B 上方 14px：面板收起时贴着导航，
              // 面板打开时贴着面板，而不是随卡片高度漂出一个大空隙。
              //
              // ⚠ 动画/拖动期间用**吸附目标值** `_snap.end` 而不是当前 `sheetH`：
              // 否则每帧都会把新的 inset 传进 MapPage，触发一次重排 + 重绘，
              // 正好把上面那个「冻结」抵消掉。地图在动画期间本来就该是「固定」的。
              bottomInset: navSpace +
                  (showSheet ? _kGutter + _insetSheetH() : 0) -
                  pad.bottom,
            ),
          ),

          // ② 浮层顶栏
          Positioned(
            top: barTop,
            left: _kGutter,
            right: _kGutter,
            child: KeyedSubtree(key: _barKey, child: _topBar()),
          ),

                  // ②a 公告横幅（压在地图上、顶栏之下；见 [NoticeBanner]）
          //     放在未连接横幅**上面**：后者是更紧急的状态提示（发不出去），
          //     离眼睛更近才对。两者的高度都已算进 topInset。
          if (widget.state.noticeBanner)
            Positioned(
              top: barTop + _barH + 6,
              left: _kGutter,
              right: _kGutter,
              child: NoticeBanner(state: widget.state),
            ),

          // ②b 未连接横幅（压在地图上、顶栏之下；见 [_linkBanner]）
          if (showLink)
            Positioned(
              top: barTop +
                  _barH +
                  6 +
                  (widget.state.noticeBanner
                      ? NoticeBanner.stripHeight + 6
                      : 0),
              left: _kGutter,
              right: _kGutter,
              child: _linkBanner(widget.state),
            ),

          // ③ 内容面板（可拖拽，只装内容；头部只有一根把手）
                  if (showSheet)
                    Positioned(
                      left: _kGutter,
                      right: _kGutter,
                      bottom: navSpace + _kGutter,
                      child: SizedBox(
                        height: sheetH, // 可视高度（拖动/动画时在变）
                        child: ClipRRect(
                          // 裁口的**底边要圆角**（与面板自身同为 24）：这个裁口就是用户
                          // 半开时看到的「卡片下沿」——直角裁口会把面板下面切成直角
                          // （用户反馈过）；圆角后任意高度都像一张完整的圆角卡。全开时
                          // `sheetH == maxSheetH`，裁口恰好落在面板自身的圆角上，两个
                          // 圆角重合，不会出现「圆角套圆角」。
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(24),
                          ),
                          // 面板**自身固定为最高档高度**，只裁出下面 `sheetH` 可见。
                          //
                          // ── 为什么这样排（这是「拖起来卡 + 一拖就变白」的根因）──
                          //
                          // `BackdropFilter` 的代价与它的**几何**直接相关：面板高度每帧都在
                          // 变时，每帧都要重做一次离屏模糊（拖一下就是十几次全屏模糊）——
                          // 那是「卡」；而之前为了不卡，只好在拖动期间**关掉模糊并把填色换成
                          // 不透明的白**，于是又出现「莫名其妙变白」（正常态 `sheetFill` 只有
                          // 58% alpha，跳成实白非常显眼）。
                          //
                          // 固定高度之后，模糊层的几何在拖动中**完全不变**；再叠加地图那侧
                          // 的 `frozen`（底图不变 → 模糊结果可复用），就能**一直开着模糊**：
                          // 既不变白、也不每帧重算。裁切只影响可见区域，观感与「高度真的在变」
                          // 完全一致。
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: maxSheetH,
                            maxHeight: maxSheetH,
                            child: SizedBox(
                              height: maxSheetH,
                              child: MaterialSurface(
                                // 四角都圆：面板下沿露在导航上方（不是贴屏幕底），
                                // 只圆上角会让它看着像被切断。
                                radius: 24,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: C.sheetFill,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: elev3(),
                                  ),
                                  child: Column(
                                    children: [
                                      _handle(),
                                      Expanded(
                                        child: ClipRect(
                                          child: OverflowBox(
                                            alignment: Alignment.topCenter,
                                            minHeight: pageH,
                                            maxHeight: pageH,
                                            child: SizedBox(
                                              height: pageH,
                                              child: _draggableContent(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

          // ④ 底部悬浮导航（固定位置，永不随内容移动）
          Positioned(
            left: _kGutter,
            right: _kGutter,
            bottom: pad.bottom + _kGutter,
            child: _navBar(),
          ),

          // ⑤ 新消息气泡压在最上层
          if (_showBubble)
            Positioned(
              top: barTop + _barH + 10,
              left: 0,
              right: 0,
              child: Center(child: _bubble()),
            ),
        ],
      ),
      ),
    );
  }

  // ─── 内容面板：只剩一根把手 ───

  Widget _handle() {
    return GestureDetector(
      onVerticalDragUpdate: (d) => _onDrag(d.delta.dy),
      onVerticalDragEnd: (_) => _onDragEnd(),
      // 轻点把手：在半屏 / 近全屏之间切换
      onTap: () {
        final full = _fullRatioOf();
        _snapTo(_extent >= (_kHalf + full) / 2 ? _kHalf : full);
      },
      behavior: HitTestBehavior.opaque,
      // 触摸目标 44（iOS 的最小推荐值）：原来是 22，用户反馈「很难活动」。
      // 药丸本身仍然很小（40×5），但整条 44 高的区域都能抓、能点、能拖。
      child: SizedBox(
        height: _kHandle,
        width: double.infinity,
        child: Center(
          child: Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: C.grey,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ),
      ),
    );
  }

  /// 把内容包起来，让拖拽不只发生在把手上。
  ///
  /// ── 为什么「整页拖动」要靠这两层，而不是给内容加一个手势 ──
  ///
  /// Flutter 的**手势竞技场**里，内层 `Scrollable` 总是赢过外层的拖拽识别器：
  /// 一个 `GestureDetector(onVerticalDragUpdate:)` 包住 `ListView` 时，竖着拖只会
  /// 滚动列表，外层回调一次都收不到。所以「整页可拖」只能换两条路：
  ///
  /// 1. **监听滚动通知**（[NotificationListener]）：内容滚到顶之后继续往下拉会发出
  ///    `OverscrollNotification`，把那段「多余的距离」拿来收面板 —— 于是「整页下滑
  ///    收起」成立（这也是用户最常试的手势）。
  /// 2. **外层手势兜底**：内容**不可滚动**时（该页内容比面板矮、或本来就不滚动），
  ///    内层没有识别器可赢，外层这个就接得到 —— 这类页面上「整页上下拖」直接成立。
  ///
  /// 诚实的边界：内容**可滚动**且已在中间位置时，向上拖仍然是滚动列表（这与
  /// iOS/Android 的系统底部面板一致：列表要能滚）。要展开面板有三条路：把手（44px）、
  /// 底部导航条（也能拖）、或轻点把手。
  Widget _draggableContent() {
    return GestureDetector(
      // deferToChild：不抢子控件的点击，只在子控件没接手竖直拖拽时才生效
      behavior: HitTestBehavior.deferToChild,
      onVerticalDragUpdate: (d) => _onDrag(d.delta.dy),
      onVerticalDragEnd: (_) => _onDragEnd(),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: _content(),
      ),
    );
  }

  /// 内容滚到顶后继续下拉 → 收面板；滚动结束 → 吸附到最近档位
  ///
  /// ── 只对「正向（非 reverse）列表」生效，这一条是踩出来的 ──
  ///
  /// 消息页的会话/聊天列表是 `reverse: true`（最新消息在底部，往上滑看历史）。
  /// 在反向列表里，用户「往下拉」是朝**最新消息**方向，那不是「到顶了还想再拉」，
  /// 却被这里当成了收面板 —— 用户反馈「消息页往下拉，面板就缩下去了」。
  ///
  /// 所以加一道方向门控：只有正向竖向列表（`AxisDirection.down`）才允许
  /// 「滚到顶继续下拉 → 收面板」。反向列表（消息页）与横向列表（筛选芯片那一行）
  /// 一律不参与 —— 这两类列表的 overscroll 语义与「把面板拉下去」无关。
  bool _onScrollNotification(ScrollNotification n) {
    final ongoing = _movedByScroll;
    if (n is! ScrollEndNotification && n.metrics.axisDirection != AxisDirection.down) {
      // 反向/横向：如果之前已经动过面板，仍然要让 ScrollEnd 把它吸附回去
      return false;
    }
    if (n is OverscrollNotification &&
        n.overscroll != 0 &&
        n.dragDetails != null) {
      // 到边还继续拖 → 交给面板，**两个方向都交**：
      //   * 到顶继续下拉（overscroll < 0）→ 收面板；
      //   * 到底继续上推（overscroll > 0）→ 展开面板。
      // 同一个公式两向通用：overscroll 的符号与「手指方向」一致
      // （负＝手指向下拽＝收；正＝手指向上提＝开）。
      //
      // `dragDetails != null` 只认**手指还在拖**的越界：惯性撞墙、iOS 回弹
      // 也发 OverscrollNotification，那两种不该拽面板（松手后会被莫名吸一下）。
      //
      // 这是「内容可滚动时整页可拖」的入口，与把手/导航条并列。手势竞技场里
      // 列表在中间位置时永远赢（那一段必须留给滚动），但**到边后**手指还越界的
      // 部分本来无处可去 —— 正好交棒。用户反馈「抓不住：抓哪儿都变滚动」，
      // 就是只做了到顶下拉这半边、缺了到底上推。
      _anim.stop();
      _movedByScroll = true;
      setState(() => _extent =
          (_extent + n.overscroll / _screenH()).clamp(0.0, _fullRatioOf()));
      return false;
    }
    if (n is ScrollEndNotification && ongoing) {
      // 只有「真的用滚动动过面板」才吸附：普通列表滚完不该触发一次面板动画
      _movedByScroll = false;
      _onDragEnd();
    }
    return false;
  }

  /// `_content()` 结果的缓存（只在页签变化时失效）。
  ///
  /// 为什么必须缓存：面板展开/拖拽动画里外壳每帧 `setState`，而 `_content()`
  /// 每次都新建 `IndexedStack` 与四个页面 widget —— 那等于**动画的每一帧都把
  /// 台站页 / 消息页 / 数据包页 / 设置页全重建一遍**（页面里还有列表、筛选、
  /// 监听器）。返回同一个 widget 实例后，Flutter 见到 `identical` 会跳过这棵
  /// 子树的 rebuild，动画帧的成本回到「只重排面板」。
  Widget? _contentCache;
  int _contentCacheTab = -1;

  /// 内容按面板高度布局、只裁显示区（见类注释 ①）
  Widget _content() {
    if (_contentCache != null && _contentCacheTab == _tab) {
      return _contentCache!;
    }
    _contentCacheTab = _tab;
    // IndexedStack：切页不销毁（滚动位置、会话都保留）。
    // 地图页不在这里 —— 选地图时整个面板收起，地图就是底。
    // 不写 clamp：`num.clamp` 的静态类型有特例，而本机没有 analyze 可验，
    // 这里要的是一个确定的 int，用最直白的写法。
    final raw = _tab - 1;
    final index = raw < 0 ? 0 : (raw > 3 ? 3 : raw);
    _contentCache = IndexedStack(
      index: index,
      children: [
        StationsPage(state: widget.state),
        // isActive 必须跟着当前页签：它是「页面是否在前台」的语义，
        // 写死 true 会让消息页在别的 tab 上也拦返回、也把「正在看的会话」算错。
        MessagesPage(state: widget.state, isActive: _tab == 2),
        PacketsPage(state: widget.state),
        SettingsPage(state: widget.state),
      ],
    );
    return _contentCache!;
  }

  // ─── 底部悬浮导航 ───

  Widget _navBar() {
    final pad = MediaQuery.of(context).padding;
    // 导航条也能拖动面板：它紧贴在面板下方、又高又宽，是除把手之外最好抓的地方。
    // 竖直拖动在它身上原本什么都不做（页签只认点击），所以这不会抢任何现有手势。
    return GestureDetector(
      onVerticalDragUpdate: (d) => _onDrag(d.delta.dy),
      onVerticalDragEnd: (_) => _onDragEnd(),
      child: MaterialSurface(
      radius: 999,
      child: Container(
        height: _kNav,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: C.surfaceFillStrong,
          borderRadius: BorderRadius.circular(999),
          boxShadow: elev2(),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final itemW = c.maxWidth / _slots.length;
            final accent = _accentOf(_slots[_tab].$1);
            // fit: expand 不能省 —— Stack 默认 StackFit.loose，非定位子项（这行
            // 页签）会按自身高度贴到上沿，胶囊底部空出一截（看着像没对齐）。
            return Stack(
              fit: StackFit.expand,
              children: [
                // 选中指示：一个**滑动的胶囊**，而不是 5 块固定色底 ——
                // 位置在动但没有 5 处同时存在的「重」色，视觉上轻得多。
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: itemW * _tab,
                  top: 8,
                  bottom: 8,
                  width: itemW,
                  child: Center(
                    child: Container(
                      width: itemW * 0.78,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _slots.length; i++)
                      Expanded(child: _navItem(i)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      ),
    );
  }

  Color _accentOf(String slot) =>
      ThemeController.instance.tabAccent(slot, isDark: C.dark) ?? C.blue;

  /// 一个页签。
  ///
  /// [rail] 为真时用在横屏的左侧竖条里：那里没有底部导航那种**滑动的指示胶囊**，
  /// 所以选中底由每一项自己画（同一套颜色，只是位置固定）。
  Widget _navItem(int i, {bool rail = false}) {
    final sel = _tab == i;
    final slot = _slots[i].$1;
    final unread = widget.state.unreadMessages;
    return ClickCursor(
      child: GestureDetector(
        onTap: () => _select(i),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: rail ? const EdgeInsets.symmetric(vertical: 9) : EdgeInsets.zero,
          decoration: rail && sel
              ? BoxDecoration(
                  color: _accentOf(slot).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ThemeController.instance.buildSlotIcon(
                  slot,
                  size: 21,
                  color: sel ? _accentOf(slot) : C.grey,
                  fallbackIcon: themeIconByName(_slots[i].$2),
                  selected: sel,
                ),
                if (i == 2 && unread > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints:
                          const BoxConstraints(minWidth: 14, minHeight: 14),
                      decoration: BoxDecoration(
                        color: C.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: ts(9, c: Colors.white, w: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _labelOf(Tx.of(context), slot),
              style: ts(10,
                  c: sel ? _accentOf(slot) : C.grey,
                  w: sel ? FontWeight.w700 : FontWeight.w400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        ),
      ),
    );
  }

  // ─── 横屏（宽 > 高）───

  /// 2.0 横屏：左侧「导航竖条 + 内容面板」，地图占满其余空间。
  ///
  /// ── 为什么横屏不复用底部面板 ──
  ///
  /// 横屏的**高度**很小（手机横放常不足 400dp），底部面板一展开就吃掉大半高度，
  /// 地图基本看不见 —— 而这一版的设计前提是「地图是底」。所以横屏把导航与内容
  /// 一起挪到**左侧**：宽绰的那一维给内容，地图占满右侧，两者互不遮挡。
  ///
  /// 横屏刻意**不做拖拽**：竖向空间本来就紧，把面板拉高拉低没有意义；改成
  /// 「点导航切换、选『地图』则收起面板」，行为确定，也不会跟列表滚动抢手势。
  /// 横屏：**一整块工作区**（左竖条 + 右内容，同一张卡）。
  ///
  /// 以前这里是两张独立的圆角卡：竖条是 `MainAxisSize.min`（只有内容高、贴顶），
  /// 内容面板却占满整高 —— 两块并排**高度不齐**，上沿都从安全区开始、下沿一个到
  /// 屏幕底一个不到，看着就是「没收拾过」。合并成一张卡后高度天然一致、间距只有
  /// 一处，而且**少一层 `BackdropFilter`**（每层都要把背后的地图离屏重绘一遍）。
  ///
  /// 选「地图」页时内容为空，此时只留一张竖条卡并**垂直居中**：贴顶会显得像掉在
  /// 上面，居中才稳。
  Widget _landscapeBody(EdgeInsets pad, double barTop, double topInset) {
    final size = MediaQuery.of(context).size;
    // 横屏的刘海/挖孔在**左、右两侧**（不在顶部）—— 竖条与顶栏都要让开 pad.left，
    // 否则刘海会把竖条最上面那颗图标吃掉一半。竖屏下 pad.left/right 通常是 0，
    // 所以这两项只在横屏（尤其带刘海的机器）生效。
    final safeL = pad.left + _kGutter;
    final safeR = pad.right + _kGutter;
    // 面板宽度：宽度的 40%，但**先保证给地图留够 260**，再夹到 200~560。
    //
    // ⚠ 写法有讲究：早期是「先按 byMap 取小、再 clamp(300, 560)」—— 那个**下限
    // 300 会把上一步的保护整个顶掉**：600 宽的窄横屏（分屏/小机）算出来
    // paneW = 300，地图只剩 219 —— 既不满足「留 260」，也不是 40%。
    // 所以顺序必须是：先算「面板最多能给多少」，下限只作为极窄屏的兜底。
    const double minMapW = 260;
    final double occupied = safeL + _kRailW + 1; // 安全区 + 外边距 + 竖条 + 细分隔
    final double mapCap = size.width - occupied - minMapW;
    final double byFraction = size.width * 0.40;
    final double paneW =
        (byFraction < mapCap ? byFraction : mapCap).clamp(200.0, 560.0);
    final paneBottom = _kGutter + pad.bottom;
    final showPane = _tab != 0;
    // 地图贴左控件要避开的宽度：竖条，加上展开时**压在地图上**的内容面板。
    // 不让开的话，信息条/沉浸入口/底部坐标条会糊在那张磨砂卡背后。
    final double mapLeftInset = occupied + (showPane ? paneW : 0.0);

    final work = showPane
        ? SizedBox(
            width: _kRailW + 1 + paneW,
            child: MaterialSurface(
              radius: 22,
              child: Container(
                decoration: BoxDecoration(
                  color: C.sheetFill,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: elev3(),
                ),
                child: Row(
                  children: [
                    _railColumn(),
                    // 细分隔：两块同属一张卡，但仍看得出分界
                    Container(width: 1, color: C.grey.withValues(alpha: 0.12)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(22),
                        ),
                        child: ClipRect(child: _content()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : _railCard();

    return Stack(
      children: [
        // 地图铺满整屏（左侧被工作区压住的部分看不见，但地图本身仍是全尺寸的，
        // 平移/缩放不会被压缩变形）
        Positioned.fill(
          child: MapPage(
            state: widget.state,
            isActive: true,
            // 横屏没有「面板滑上来」的过程，但内容页展开时地图同样被盖住 ——
            // 冻结它（理由见 MapPage.frozen）。地图页时保持正常刷新。
            frozen: showPane && _paneOpen,
            topInset: topInset,
            // 底部没有任何东西占用（导航在左边）—— 只留一个外边距当呼吸空间。
            //
            // ⚠ 必须**不含** pad.bottom：地图那边的口径是「相对安全区」
            // （它自己会加一次 pad.bottom），传 paneBottom（含安全区）会把
            // 底部控件凭空抬高一个安全区的高度 —— 竖屏那边是减掉了的，
            // 两边口径必须一致。
            bottomInset: _kGutter,
            leftInset: mapLeftInset,
          ),
        ),
        // 公告横幅（横屏同样在顶栏之下；左边让开竖条/内容面板）
        if (widget.state.noticeBanner)
          Positioned(
            top: barTop + _barH + 6,
            left: mapLeftInset + _kGutter,
            right: safeR,
            child: NoticeBanner(state: widget.state),
          ),
        // 未连接横幅（横屏也在顶栏之下；见 [_linkBanner]）。
        // 左边让开竖条：它横跨地图区，压到竖条上会显得是两张卡撞在一起。
        if (_showLinkBanner(widget.state))
          Positioned(
            top: barTop +
                _barH +
                6 +
                (widget.state.noticeBanner
                    ? NoticeBanner.stripHeight + 6
                    : 0),
            left: mapLeftInset + _kGutter,
            right: safeR,
            child: _linkBanner(widget.state),
          ),
        // 右上角那一簇（横屏更宽，放右边不挡地图中心）
        Positioned(
          top: barTop,
          left: safeL,
          right: safeR,
          child: Align(
            alignment: Alignment.centerRight,
            child: KeyedSubtree(key: _barKey, child: _topBar()),
          ),
        ),
        // 工作区：展开时是一整块；收起时只剩居中竖条
        Positioned(
          left: safeL,
          top: topInset,
          bottom: paneBottom,
          child: showPane
              ? work
              : Align(alignment: Alignment.centerLeft, child: work),
        ),
        if (_showBubble)
          Positioned(
            top: barTop + _barH + 10,
            // 居中要相对**可见的地图区**：横屏时左侧被竖条/面板占着，
            // 从 0 开始居中会偏到卡片那一边（气泡也是半透明的，叠上去很脏）
            left: showPane ? mapLeftInset : 0,
            right: 0,
            child: Center(child: _bubble()),
          ),
      ],
    );
  }

  /// 收起内容时的独立竖条卡（只剩导航）
  ///
  /// `IntrinsicHeight` 不能省。`_railItems()` 是 `SingleChildScrollView`
  /// （为极矮横屏准备的），而它**没有 `shrinkWrap`** —— 在「高度有界」的父约束下
  /// 会直接撑满可用高度。结果是：卡片变成一条**通高的空框**，5 个导航项全挤在上沿
  /// —— 正是下面注释里说「贴顶会显得像掉在上面」的那种难看样子，所谓「垂直居中」
  /// 也就根本没生效（外层 `Align` 居中的是一个已经满高的盒子）。
  ///
  /// `IntrinsicHeight` 取「内容高度」并按父约束夹住，两个目的一次达成：
  ///   * 内容矮 → 卡片收缩到内容高，外层 `Align` 才能真正把它垂直居中；
  ///   * 内容高（极矮横屏）→ 被夹在可用高度内，`SingleChildScrollView` 仍可滚，
  ///     不会溢出成黄条纹。
  Widget _railCard() {
    return MaterialSurface(
      radius: 20,
      child: IntrinsicHeight(
        child: Container(
          width: _kRailW,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: C.sheetFill,
            borderRadius: BorderRadius.circular(20),
            boxShadow: elev2(),
          ),
          child: _railItems(),
        ),
      ),
    );
  }

  /// 竖条内容（**不含卡片壳**）：展开时它嵌在工作区那张大卡里，
  /// 收起时套在 [_railCard] 里 —— 两种形态共用同一份导航，不会漂成两个样子。
  Widget _railColumn() {
    return SizedBox(
      width: _kRailW,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: _railItems(),
      ),
    );
  }

  /// 竖条的导航项列表。
  ///
  /// 套 `SingleChildScrollView`：极矮横屏（手机横放常不足 400dp）下 5 个导航项
  /// 会溢出成黄条纹 —— 那正是最容易被看出来「没收拾过」的地方。
  Widget _railItems() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _slots.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            _navItem(i, rail: true),
          ],
        ],
      ),
    );
  }

  String _labelOf(Tx tx, String slot) {
    switch (slot) {
      case 'navMap':
        return tx.navMap;
      case 'navStations':
        return tx.navStations;
      case 'navMessages':
        return tx.navMessages;
      case 'navPackets':
        return tx.navPackets;
      default:
        return tx.navSettings;
    }
  }

  // ─── 浮层顶栏 ───

  Widget _topBar() {
    final st = widget.state;
    // 顶栏**没有搜索框**（用户反馈：主页与台站页没必要出现）。
    //
    // 两个理由：一是台站页**自己就有搜索框**，外壳这个对它是重复的
    // （StationsPage._query 优先用本页那一个，外壳的只在它为空时才起作用）；
    // 二是「一整条浮在地图上的浅色横条」本身就压视觉重量。
    // 现在只留右上角一簇悬浮胶囊：连接状态 + 定位。
    // 包成**一只实心胶囊**：去掉搜索条之后这几个小块原本各自 12% 透明直接压在
    // 瓦片上，既读不清也不整。这里刻意**不套** MaterialSurface —— 这一簇面积远
    // 这一簇是「小浮层」，本来就不该模糊（见 material.dart），套了只是白加一层；
    // 用实心 chipFill 才是正解（小浮层实心、大面板磨砂）。
    // 用「小浮层」那一档材质（chipFill + chipBlur）：半透明 + 磨砂
    // （chipBlur 随档位变：满血档给大半径，其余档 12）。
    // 这几个小块原本是各自 12% 透明直接压在瓦片上（读不清、也不整），包成一只胶囊
    // 之后既整齐，也看得出背后有地图。
    return Align(
      alignment: Alignment.centerRight,
      child: MaterialSurface(
        radius: 999,
        blurSigma: C.chipBlur,
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: C.chipFill,
          borderRadius: BorderRadius.circular(999),
          boxShadow: elev2(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          // 天气组件（「设置 → 显示 → 顶栏天气组件」控制）。与 1.0 一样放在
          // 在线数左侧：它自带青色胶囊、点击弹出天气面板，不用另做外观。
          if (st.weatherEnabled) ...[
            WeatherBadge(state: st),
            const SizedBox(width: 6),
          ],
          _statusPill(st),
          const SizedBox(width: 6),
          // 一键连接 / 断开。
          // 1.0 里这个动作在侧栏与「未连接横幅」各有一处，而我重写 2.0 外壳时
          // 漏掉了 —— 结果 2.0 里只能进连接设置页才能连/断。补回来。
          _connBtn(st),
          const SizedBox(width: 6),
          _locateBtn(st),
        ],
        ),
        ),
      ),
    );
  }

  /// 是否显示未连接横幅（见 [_linkBanner]）。
  ///
  /// 三种情况**不显示**，各有理由（第一版只看 `!connected`，于是只读模式下
  /// 也会挂一条「未连接」，等于让人白去点连接、白去查设置）：
  ///  * 已连接 —— 没什么好提示的；
  ///  * 连接中 —— 顶部胶囊已经在转圈说明它；
  ///  * **只读模式**（只启用 PKWDWPL 这类只收来源）—— 没有发射链路是正常的，
  ///    这也是 v1.6.109 撤掉「不能只剩只读来源」那条限制时定下的口径。
  bool _showLinkBanner(AppState st) =>
      !st.connected && !st.connecting && !st.readOnlyMode;

  /// **未连接横幅**：把「现在发不出去」这件事明确说出来，并给一个能立刻点的动作。
  ///
  /// 为什么需要（用户反馈「强化未连接提示」）：2.0 里连接状态只由右上角那颗
  /// 小胶囊（● APRS-IS · 未连接）表达，和天气、连接钮、定位钮挤在一起 ——
  /// 未连接时整屏看起来「一切正常」，而实际上**发送、信标、消息全都发不出去**。
  /// 1.0 里有一条明显的横幅，重写 2.0 外壳时只留了胶囊。
  ///
  /// 位置与几何：整条都是按钮（点一下即连接），并且它占用的高度会**从地图的
  /// 顶部让位量里扣掉**（见 build 里的 `linkBannerH`）—— 否则它会压住地图自己
  /// 的顶部浮层（信息条 / 图例 / 工具列），而那几件是按 topInset 摆的。
  Widget _linkBanner(AppState st) {
    final s = S.of(context);
    return ClickCursor(
      child: GestureDetector(
        // 整条都能点：与 _toolBtn 同一个坑 —— 底色来自 BoxDecoration，
        // 而 DecoratedBox 不吸收点击，不写 opaque 就只有中间那点文字能点。
        behavior: HitTestBehavior.opaque,
        onTap: st.toggleConnect,
        child: MaterialSurface(
          radius: 12,
          blurSigma: C.chipBlur,
          child: Container(
            height: _kLinkBannerH,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: C.chipFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.orange.withValues(alpha: 0.45)),
              boxShadow: elev2(),
            ),
            child: Row(
              children: [
                Icon(Icons.link_off_rounded, size: 16, color: C.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.notConnectedAprsServer,
                          style: ts(11, w: FontWeight.w700, h: 1.1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(s.connectNearbyDesc,
                          style: ts(9, c: C.grey, h: 1.1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 行动按钮（与整条同动作）：把「点了会发生什么」写出来，
                // 而不是只给一个状态词 —— 与 _connBtn 的分工一致。
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: C.orange.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(s.connectAction,
                      style: ts(10, c: C.orange, w: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 连接 / 断开按钮（连接中显示转圈）
  Widget _connBtn(AppState st) {
    final s = S.of(context);
    if (st.connecting) {
      return Tooltip(
        message: s.connecting,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: C.blue.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          // 不能 const：C.blue 是 static 字段（非常量），
          // `const Padding(... color: C.blue)` 会报 invalid_constant ——
          // 仓库里别处也踩过同一个坑（station_detail.dart 有注释记着）。
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: CircularProgressIndicator(strokeWidth: 2, color: C.blue),
          ),
        ),
      );
    }
    final up = st.connected;
    // ── 为什么要改成「带文字的浅底按钮」（用户反馈「多不清晰」）──
    //
    // 上一版做成了「未连接 = **实心蓝**圆钮、已连接 = 淡红圆钮」，本意是让未连接
    // 时那颗按钮看起来像主操作。但它同时被读成了状态灯：**实心**在图形界面的惯例里
    // 意味着「已开启」，于是用户看到的正好相反 —— 原话是「填充时是断开」（填满的
    // 时候反而是断开状态）。而连上之后按钮又变成「断开」，同一个位置来回换含义。
    //
    // 现在把**状态**与**动作**彻底分开：
    // * 状态只由左边那颗胶囊表达（● APRS-IS · 已连接 / 未连接，带颜色）；
    // * 这颗按钮**只表达点了会发生什么**，所以一律带动词文字（连接 / 断开连接），
    //   底色一律是淡底（不用实心）—— 不留「实心是否是状态」的解读空间。
    return Tooltip(
      message: up ? s.disconnect : s.connectAction,
      child: ClickCursor(
        child: GestureDetector(
          onTap: st.toggleConnect,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: (up ? C.red : C.blue).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  up ? Icons.link_off_rounded : Icons.wifi_rounded,
                  size: 15,
                  color: up ? C.red : C.blue,
                ),
                const SizedBox(width: 4),
                Text(
                  up ? s.disconnect : s.connectAction,
                  style: ts(11, c: up ? C.red : C.blue, w: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 定位按钮：回到地图并居中到我
  ///
  /// 2.0 里地图始终在，所以从任何一页点它都能直接落回地图 —— 不必先切页。
  Widget _locateBtn(AppState st) {
    return _iconBtn(Icons.my_location_rounded, C.blue, () {
      if (_tab != 0) _select(0);
      final me = st.myStation;
      if (me != null) {
        st.focusOnMap(me);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).noFixYet),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  /// 连接状态胶囊 + 当前链路来源。
  ///
  /// ── 为什么重做（用户反馈「连接的提示很不明确」）──
  ///
  /// 原来它显示「37 在线」—— 那是**台站数**，不是连接状态；而台站数在地图的
  /// 信息条里已经显示了（在线 / 移动 / 台站）。最糟的是「离线」这个词：`connected`
  /// 的真实含义是**发射链路可用**，与「有没有台站在线」是两件事，同一个词同时
  /// 暗示两件事，用户没法判断到底是自己没连上、还是收不到台站。
  ///
  /// 现在如实拆开：**来源 · 状态**。来源取自 `dataSource`（APRS-IS / TNC / 音频 /
  /// PKWDWPL），状态用 `connected`（发射链路）：
  ///
  /// * 已连接 → 绿；
  /// * 连接中 → 蓝；
  /// * **只收不发**（只启用 PKWDWPL 这类只读来源）→ 青，并直说「只收不发」——
  ///   这不是故障，1.0 的横幅也是这么区分的；
  /// * 未连接 → 灰。
  ///
  /// 点一下进连接设置（原来是暗示都没有，只在 tooltip 里说 —— tooltip 在手机上
  /// 根本看不到，这也是「不明确」的一部分）。
  Widget _statusPill(AppState st) {
    final s = S.of(context);
    final source = _sourceLabel(st);
    final (state, color) = _linkState(st);
    return Tooltip(
      message: '${_linkDetail(st)}\n${s.linkTapForSettings}',
      child: ClickCursor(
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ConnectionSettingsPage(state: st)),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                ),
                const SizedBox(width: 5),
                // 来源 + 状态：挤不下时省略来源（状态更要紧）
                Flexible(
                  child: Text(
                    '$source · $state',
                    style: ts(11, c: color, w: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 当前**发射来源**的短名（与 1.0 的用词一致）
  /// 状态胶囊里的**短**来源名。
  ///
  /// 为什么不用设置页那套完整说法（「音频（声卡）」「PKWDWPL（Kenwood 航点）」）：
  /// 那颗胶囊和天气、连接按钮、定位按钮并排挤在窄屏顶部，长名会把这一行撑爆。
  /// 完整说法留在设置页/连接页 —— 那里有整行宽度，也该解释清楚。
  /// `APRS-IS` / `TNC` / `PKWDWPL` 是协议名与设备类别名，不是可翻译短语，直接用字面量。
  String _sourceLabel(AppState st) {
    if (st.dataSource == AppState.srcTnc) return 'TNC';
    if (st.dataSource == AppState.srcAudio) return S.of(context).dataSourceAudioShort;
    if (st.dataSource == AppState.srcPkwdwpl) return 'PKWDWPL';
    return 'APRS-IS';
  }

  /// 链路状态（文案, 颜色）。
  ///
  /// 「只读接收」单列一档：它**没有发射链路是正常的**，画成「未连接」会让人
  /// 白去点连接、白去查设置。
  (String, Color) _linkState(AppState st) {
    final s = S.of(context);
    if (st.readOnlyMode) return (s.pkwdwplRxOnly, C.cyan);
    if (st.connecting) return (s.connecting, C.blue);
    if (st.connected) return (s.connected, C.green);
    return (s.linkNotConnected, C.slate);
  }

  /// tooltip 里的细节：具体连到哪儿（服务器地址 / 设备名），让「点进去看」之前
  /// 就有个判断依据
  String _linkDetail(AppState st) {
    if (st.dataSource == AppState.srcTnc) {
      return st.tnc.device?.label ?? S.of(context).tncNotBound;
    }
    if (st.dataSource == AppState.srcPkwdwpl) {
      return st.pkwdwpl.device?.label ?? S.of(context).tncNotBound;
    }
    if (st.dataSource == AppState.srcAudio) {
      return '${st.audio.config.afsk.sampleRate} Hz';
    }
    final s = S.of(context);
    return st.readOnlyMode
        ? s.pkwdwplRxOnly
        : '${st.aprs.server}:${st.aprs.port}';
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return ClickCursor(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  // ─── 新消息气泡 ───

  Widget _bubble() {
    return ClickCursor(
      child: GestureDetector(
        onTap: () {
          setState(() => _showBubble = false);
          _bubbleTimer?.cancel();
          widget.state.clearUnread();
          _select(2);
        },
        child: MaterialSurface(
          radius: 999,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: C.surfaceFillStrong,
              borderRadius: BorderRadius.circular(999),
              boxShadow: elev2(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_rounded, size: 16, color: C.blue),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '$_bubbleCall · $_bubbleText',
                    style: ts(12, c: C.ink, w: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
