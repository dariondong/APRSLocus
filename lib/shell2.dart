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
/// 3. **内容面板**（可拖拽）：只装内容，**不再包含导航**。头部只剩一根细把手
///    （约 22px，不再是 80px 的双层 chrome）。选「地图」时它整个收起，
///    地图就是全屏的 —— 这才是「地图为基底」。
///
/// 拖动只在把手上响应：向下拖过阈值就收起回到地图（符合直觉的「下滑关闭」），
/// 否则吸附到两个档位（半屏 / 近全屏）。刻意**不**接管内容里列表的手势。
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

  /// 内容面板高度占屏高比例；0 = 收起（地图全屏）
  double _extent = 0;

  Tween<double> _snap = Tween(begin: 0, end: 0);
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..addListener(() => setState(() => _extent = _snap.evaluate(_anim)));

  /// 顶栏真实高度（首帧估值，量到后校准）。
  ///
  /// 为什么不写死：顶栏高度由内容决定（搜索框在窄屏变高、状态胶囊文字随语言
  /// 变长），写死就会在别的语言/字号下压住地图控件。
  final GlobalKey _barKey = GlobalKey();
  /// 首帧估值：右上角那一簇约 32~34 高（胶囊 6+文字+6 与圆形按钮取高者）。
  /// 先给接近真实的值，量到后校准 —— 差太多会让地图顶部控件在首帧跳一下。
  double _barH = 34;

  /// 导航胶囊高度
  static const double _kNav = 56;

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

  void _onState() {
    if (mounted) setState(() {});
  }

  /// 底部导航占的总高度（含安全区与下边距）
  double _navSpace(BuildContext context) =>
      _kNav + MediaQuery.of(context).padding.bottom + _kGutter;

  /// 顶栏占的高度（顶部安全区 + 栏高 + 间隙），同时是地图顶部让位量与面板上限
  double _topInset() => MediaQuery.of(context).padding.top + 6 + _barH + 8;

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
    final size = MediaQuery.of(context).size;
    final navSpace = _navSpace(context);
    final topInset = _topInset();
    final h = size.height;
    setState(() => _extent = (_extent - dy / h)
        .clamp(0.0, _fullRatio(size, navSpace, topInset)));
  }

  void _onDragEnd() {
    final size = MediaQuery.of(context).size;
    final navSpace = _navSpace(context);
    final topInset = _topInset();
    final full = _fullRatio(size, navSpace, topInset);
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
    final sheetH = (size.height * _extent)
        .clamp(0.0, _maxSheetH(size, navSpace, topInset));
    final showSheet = _extent > 0.02;

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
                              minHeight: sheetH,
                              maxHeight: sheetH,
                              child: SizedBox(
                                height: sheetH,
                                child: _content(),
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
        final size = MediaQuery.of(context).size;
        final full = _fullRatio(size, _navSpace(context), _topInset());
        _snapTo(_extent >= (_kHalf + full) / 2 ? _kHalf : full);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 22,
        width: double.infinity,
        child: Center(
          child: Container(
            width: 34,
            height: 4,
            decoration: BoxDecoration(
              color: C.greyLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

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
    return MaterialSurface(
      radius: 999,
      blurSigma: 20,
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
    return Align(
      alignment: Alignment.centerRight,
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
    return Tooltip(
      message: up ? s.disconnect : s.connectAction,
      child: _iconBtn(
        up ? Icons.wifi_off_rounded : Icons.wifi_rounded,
        up ? C.red : C.blue,
        st.toggleConnect,
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

  /// 连接/在线状态胶囊：点一下进连接设置
  /// （2.0 没有侧栏，而「连接状态」是最高频的诊断入口，得给它一个位置）
  Widget _statusPill(AppState st) {
    final up = st.connected;
    final c = up ? C.green : (st.connecting ? C.blue : C.slate);
    // 只给一个数字（例如「37」）看不出是什么；带上「在线」这个词，
    // 与 1.0 顶栏的统计标签口径一致。
    final text = up
        ? '${st.online} ${S.of(context).online}'
        : (st.connecting ? S.of(context).connecting : S.of(context).offline);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ConnectionSettingsPage(state: st)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c),
            ),
            const SizedBox(width: 5),
            Text(text, style: ts(11, c: c, w: FontWeight.w700)),
          ],
        ),
      ),
    );
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
