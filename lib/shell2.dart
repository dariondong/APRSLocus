import 'dart:async';

import 'package:flutter/material.dart';

import 'map_page.dart';
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

  /// 是否刚刚用「滚动」动过面板（决定滚动结束后要不要吸附）
  bool _movedByScroll = false;

  /// 内容面板高度占屏高比例；0 = 收起（地图全屏）
  double _extent = 0;

  Tween<double> _snap = Tween(begin: 0, end: 0);
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..addListener(() => setState(() => _extent = _snap.evaluate(_anim)));

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

  /// 把手触摸区高度（药丸本身只有 40×5，但整条都能拖/能点）
  static const double _kHandle = 44;

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
    final key = '${st.connected}|${st.connecting}|${st.online}|'
        '${st.unreadMessages}|${st.weatherEnabled}|${st.myHasFix}';
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
    setState(() => _extent =
        (_extent - dy / _screenH()).clamp(0.0, _fullRatioOf()));
  }

  void _onDragEnd() {
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
    final navSpace = _navSpace(context);
    final barTop = pad.top + 6;
    final topInset = _topInset();
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
        // 不在「地图」页：回地图（_select(0) 同时会把内容面板收起）
        _select(0);
      },
      child: Scaffold(
      backgroundColor: C.pageFill,
      body: Stack(
        children: [
          // ① 地图整屏（永远在，切换内容页也不销毁）
          Positioned.fill(
            child: MapPage(
              state: widget.state,
              isActive: true,
              topInset: topInset,
              // 底部被占用的边界 B（自屏幕底算起）＝ 导航 + （面板 + 间隙）。
              // 地图那边的口径是「相对安全区」，所以这里减去 pad.bottom ——
              // 这样贴底控件永远落在 B 上方 14px：面板收起时贴着导航，
              // 面板打开时贴着面板，而不是随卡片高度漂出一个大空隙。
              bottomInset: navSpace +
                  (showSheet ? _kGutter + sheetH : 0) -
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

          // ③ 内容面板（可拖拽，只装内容；头部只有一根把手）
          if (showSheet)
            Positioned(
              left: _kGutter,
              right: _kGutter,
              bottom: navSpace + _kGutter,
              child: SizedBox(
                height: sheetH,
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
  bool _onScrollNotification(ScrollNotification n) {
    if (n is OverscrollNotification && n.overscroll < 0) {
      // overscroll 为负 = 已经到顶还在往下拖
      _anim.stop();
      _movedByScroll = true;
      setState(() => _extent =
          (_extent + n.overscroll / _screenH()).clamp(0.0, _fullRatioOf()));
      return false;
    }
    if (n is ScrollEndNotification && _movedByScroll) {
      // 只有「真的用滚动动过面板」才吸附：普通列表滚完不该触发一次面板动画
      _movedByScroll = false;
      _onDragEnd();
    }
    return false;
  }

  /// 内容按面板高度布局、只裁显示区（见类注释 ①）
  Widget _content() {
    // IndexedStack：切页不销毁（滚动位置、会话都保留）。
    // 地图页不在这里 —— 选地图时整个面板收起，地图就是底。
    // 不写 clamp：`num.clamp` 的静态类型有特例，而本机没有 analyze 可验，
    // 这里要的是一个确定的 int，用最直白的写法。
    final raw = _tab - 1;
    final index = raw < 0 ? 0 : (raw > 3 ? 3 : raw);
    return IndexedStack(
      index: index,
      children: [
        StationsPage(state: widget.state),
        MessagesPage(state: widget.state, isActive: true),
        PacketsPage(state: widget.state),
        SettingsPage(state: widget.state),
      ],
    );
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

  Widget _navItem(int i) {
    final sel = _tab == i;
    final slot = _slots[i].$1;
    final unread = widget.state.unreadMessages;
    return GestureDetector(
      onTap: () => _select(i),
      behavior: HitTestBehavior.opaque,
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
    // 用「小浮层」那一档材质（chipFill + kChipBlurSigma）：半透明 + 轻磨砂。
    // 这几个小块原本是各自 12% 透明直接压在瓦片上（读不清、也不整），包成一只胶囊
    // 之后既整齐，也看得出背后有地图。
    return Align(
      alignment: Alignment.centerRight,
      child: MaterialSurface(
        radius: 999,
        blurSigma: C.kChipBlurSigma,
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
    // 未连接时做成**实心蓝**（主操作的样子），而不是浅色图标钮：
    // 原来那颗按钮无论连不连都是一个 12% 透明的浅底，看不出「现在该点它」。
    // 已连接仍用红色（断开语义）保持区分。
    return Tooltip(
      message: up ? s.disconnect : s.connectAction,
      child: GestureDetector(
        onTap: st.toggleConnect,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: up ? C.red.withValues(alpha: 0.12) : C.blue,
            shape: BoxShape.circle,
          ),
          child: Icon(
            up ? Icons.wifi_off_rounded : Icons.wifi_rounded,
            size: 18,
            color: up ? C.red : Colors.white,
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
    );
  }

  /// 当前**发射来源**的短名（与 1.0 的用词一致）
  String _sourceLabel(AppState st) {
    final s = S.of(context);
    if (st.dataSource == AppState.srcTnc) return s.dataSourceTnc;
    if (st.dataSource == AppState.srcAudio) return s.dataSourceAudio;
    if (st.dataSource == AppState.srcPkwdwpl) return s.dataSourcePkwdwpl;
    return s.dataSourceAprsIs;
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
    return GestureDetector(
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
    );
  }

  // ─── 新消息气泡 ───

  Widget _bubble() {
    return GestureDetector(
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
    );
  }
}
