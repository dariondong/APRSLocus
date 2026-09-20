import 'dart:async';

import 'package:flutter/material.dart';

import 'immersive_page.dart';
import 'map_page.dart';
import 'material.dart';
import 'messages_page.dart';
import 'packets_page.dart';
import 'settings_page.dart';
import 'settings_pages.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'stations_page.dart';
import 'theme.dart';
import 'theme_icons.dart';
import 'theme_store.dart';
import 'theme_text.dart';
import 'widgets.dart';

/// ─── UI 2.0 外壳：以地图为基底 ───
///
/// 结构（自下而上三层）：
/// 1. **地图常驻整屏**（[MapPage]）：它不是「一个页签」，而是整个界面的底。
///    它自己不知道卡片有多高，所以由外壳把卡片高度通过 `bottomInset` 传进去，
///    让它把贴底的控件（比例尺/坐标条、上报横杠）往上让开。
/// 2. **底部可拖拽卡片**：台站 / 消息 / 数据包 / 设置装进来，卡片顶部就是
///    **导航行** —— 于是「切页」和「这页在卡片里」是同一件事。
/// 3. **浮在地图上的顶栏**：搜索、在线数、连接与定位入口。
///
/// ── 三个刻意的实现取舍（都踩过或差点踩到）──
///
/// **① 卡片内容固定按「最大高度」布局，再裁掉超出部分。**
/// 卡片收到最矮时可视高度只剩几十像素。若把页面直接塞进这个高度，页面内部的
/// `Column` 立刻溢出（黄黑斜纹），而且拖动时高度每帧都在变、布局每帧重做。
/// 改用 `OverflowBox + ClipRect`：页面**永远按展开时的高度**布局，只是被裁掉
/// 看不见的部分 —— 拖动过程零重算、不溢出，各页滚动位置与状态都保留。
///
/// **② 拖动只认把手与导航行，不抢列表的手势。**
/// `DraggableScrollableSheet` 要求把它的 `scrollController` 交给内部滚动体，
/// 那等于让外壳的控制器接管五个页面的列表（各自的下拉刷新、横向列表都会变脆）。
/// 所以这里自己实现拖动：只有头部响应竖直拖拽，松手吸附到最近档位。
/// 代价是「列表滑到顶再上滑能展开卡片」这种联动没有 —— 换来五页滚动行为零改动。
///
/// **③ 档位只有三个，且最矮那档按头部高度算出来。**
/// 写死 0.12 这种比例在窄屏/大字号上会把导航行切掉一半（看起来像「导航行缺了
/// 一块」），所以 peek 档 =（把手 + 导航行 + 底部安全区）/ 屏高。
class HomeShell2 extends StatefulWidget {
  final AppState state;
  const HomeShell2({super.key, required this.state});

  @override
  State<HomeShell2> createState() => _HomeShell2State();
}

class _HomeShell2State extends State<HomeShell2>
    with SingleTickerProviderStateMixin {
  int _tab = 0;

  /// 卡片高度占屏高的比例
  double _extent = 0.22;

  /// 吸附动画用的 tween（拖动时直接改 _extent，不走它）
  Tween<double> _snap = Tween(begin: 0.22, end: 0.22);
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..addListener(() => setState(() => _extent = _snap.evaluate(_anim)));

  // 搜索（仅地图/台站页用，沿用 1.0 顶栏那套 300ms 防抖）
  String _search = '';
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  // 新消息气泡
  bool _showBubble = false;
  String _bubbleCall = '';
  String _bubbleText = '';
  Timer? _bubbleTimer;

  /// 卡片头部高度（把手 8+8+4 与导航行 58）
  static const double _kHeader = 80;

  /// 非地图页展开到的工作高度
  static const double _kOpen = 0.62;

  /// 最大高度：留一条缝，「卡片浮在地图上」这件事才看得出来
  static const double _kMax = 0.92;

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
    _searchDebounce?.cancel();
    _bubbleTimer?.cancel();
    _searchCtrl.dispose();
    widget.state.onNewMessage = null;
    widget.state.removeListener(_onState);
    super.dispose();
  }

  /// 收起状态也要跟着刷新：连接状态、未读角标都画在卡片头部
  void _onState() {
    if (mounted) setState(() {});
  }

  /// 最矮档：刚好放下「把手 + 导航行 + 底部安全区」
  double _peekExtent(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final pad = MediaQuery.of(context).padding.bottom;
    return ((_kHeader + pad + 12) / h).clamp(0.12, 0.34);
  }

  List<double> _detents(BuildContext context) =>
      [_peekExtent(context), _kOpen, _kMax];

  void _snapTo(double target) {
    _snap = Tween(begin: _extent, end: target);
    _anim
      ..reset()
      ..forward();
  }

  void _snapToNearest() {
    final ds = _detents(context);
    var best = ds.first;
    for (final d in ds) {
      if ((d - _extent).abs() < (best - _extent).abs()) best = d;
    }
    _snapTo(best);
  }

  void _select(int i) {
    if (i == 2) widget.state.clearUnread();
    setState(() => _tab = i);
    // 选「地图」→ 收起（地图是底，卡片只是附件）；选其他页 → 展开到工作高度
    _snapTo(i == 0 ? _peekExtent(context) : _kOpen);
  }

  void _onDrag(double dy) {
    _anim.stop();
    final lo = _detents(context).first;
    setState(() {
      _extent = (_extent - dy / MediaQuery.of(context).size.height)
          .clamp(lo, _kMax);
    });
  }

  /// 只有「地图/台站」页用全局搜索：其余页各有自己的搜索/筛选入口
  bool get _searchable => _tab == 0 || _tab == 1;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    final peek = _peekExtent(context);
    // 旋屏/改字号后旧的 _extent 可能比新的 peek 还矮，那会把导航行切掉一半 ——
    // 这里就地修正（比在 didChangeMetrics 里维护一份状态更不会漏）。
    if (_extent < peek) _extent = peek;
    final cardH = size.height * _extent;
    final headerH = _kHeader + pad.bottom;
    final visible = (cardH - headerH).clamp(0.0, double.infinity);
    // 页面永远按「最大档」的高度布局，只裁显示区（见类注释 ①）
    final pageH = (size.height * _kMax - headerH).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: C.pageFill,
      body: Stack(
        children: [
          // ① 地图永远是底；按卡片高度让开贴底控件
          Positioned.fill(
            child: MapPage(
              state: widget.state,
              searchQuery: _search,
              isActive: true,
              bottomInset: cardH + 6,
            ),
          ),

          // ② 浮在地图上的顶栏（避开状态栏）
          Positioned(top: pad.top + 6, left: 10, right: 10, child: _topBar()),

          // ③ 底部卡片
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: cardH,
              child: MaterialSurface(
                radius: 24,
                topOnly: true,
                child: Container(
                  decoration: BoxDecoration(
                    color: C.sheetFill,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: softShadow(blur: 18, y: 4, alpha: 0.16),
                  ),
                  child: Column(
                    children: [
                      _cardHeader(),
                      SizedBox(
                        height: visible,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: pageH,
                            maxHeight: pageH,
                            child: SizedBox(height: pageH, child: _pages()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ④ 气泡压在最上层，免得被卡片挡住
          if (_showBubble)
            Positioned(
              top: pad.top + 62,
              left: 0,
              right: 0,
              child: Center(child: _bubble()),
            ),
        ],
      ),
    );
  }

  // ─── 顶栏（浮层）───

  Widget _topBar() {
    final st = widget.state;
    return MaterialSurface(
      radius: 16,
      blurSigma: 18,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: C.surfaceFillStrong,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.border),
          boxShadow: softShadow(blur: 12, alpha: 0.10),
        ),
        child: Row(
          children: [
            if (_searchable)
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: ts(13),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: S.of(context).searchHint,
                    hintStyle: ts(13, c: C.grey),
                    prefixIcon:
                        Icon(Icons.search_rounded, size: 18, color: C.grey),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 26, minHeight: 0),
                    suffixIcon: _search.isEmpty
                        ? null
                        : GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                            child: Icon(Icons.close_rounded,
                                size: 16, color: C.grey),
                          ),
                  ),
                  onChanged: (v) {
                    // 防抖：台站上千时逐字搜索会让地图逐字重排
                    _searchDebounce?.cancel();
                    _searchDebounce =
                        Timer(const Duration(milliseconds: 300), () {
                      if (mounted) setState(() => _search = v);
                    });
                  },
                ),
              )
            else
              Expanded(
                child: Text(
                  _labelOf(Tx.of(context), _slots[_tab].$1),
                  style: T.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(width: 6),
            _statusPill(st),
            const SizedBox(width: 6),
            _iconBtn(Icons.my_location_rounded, C.blue, () {
              if (_tab != 0) _select(0);
              final me = st.myStation;
              if (me != null) {
                // 复用地图既有的「焦点跳转」通道：2.0 里地图始终在，所以从任何
                // 页点定位都能直接落回地图，不必先切页再点一次。
                st.focusOnMap(me);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(S.of(context).noFixYet),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }),
          ],
        ),
      ),
    );
  }

  /// 连接/在线状态胶囊：点一下进连接设置
  ///
  /// 2.0 里没有侧栏，而「连接状态」是最高频的诊断入口 —— 不在这里给一个入口，
  /// 用户会找不到（1.0 里它同时出现在侧栏面板与顶栏横幅）。
  Widget _statusPill(AppState st) {
    final up = st.connected;
    final c = up ? C.green : (st.connecting ? C.blue : C.slate);
    final text = up
        ? '${st.online}'
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
          borderRadius: BorderRadius.circular(20),
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
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  // ─── 卡片头部：把手 + 导航行（整块可拖）───

  Widget _cardHeader() {
    final pad = MediaQuery.of(context).padding.bottom;
    return GestureDetector(
      // 竖直拖动 ↔ 收放卡片；轻点 ↔ 在「收起 / 工作高度」间切换
      onVerticalDragUpdate: (d) => _onDrag(d.delta.dy),
      onVerticalDragEnd: (_) => _snapToNearest(),
      onTap: () {
        final peek = _peekExtent(context);
        _snapTo((_extent - peek).abs() < 0.02 ? _kOpen : peek);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: C.greyLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                for (var i = 0; i < _slots.length; i++)
                  Expanded(child: _navItem(i)),
              ],
            ),
          ),
          if (pad > 0) SizedBox(height: pad) else const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _navItem(int i) {
    final sel = _tab == i;
    final slot = _slots[i].$1;
    final accent =
        ThemeController.instance.tabAccent(slot, isDark: C.dark) ?? C.blue;
    final unread = widget.state.unreadMessages;
    return GestureDetector(
      onTap: () => _select(i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: sel ? accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ThemeController.instance.buildSlotIcon(
                  slot,
                  size: 21,
                  color: sel ? accent : C.grey,
                  fallbackIcon: themeIconByName(_slots[i].$2),
                  selected: sel,
                ),
                if (i == 2 && unread > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      constraints:
                          const BoxConstraints(minWidth: 14, minHeight: 14),
                      decoration: BoxDecoration(
                        color: C.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: ts(8, c: Colors.white, w: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              _labelOf(Tx.of(context), slot),
              style: ts(10,
                  c: sel ? accent : C.grey,
                  w: sel ? FontWeight.w600 : FontWeight.w400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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

  // ─── 卡片内容：五页常驻 ───

  Widget _pages() {
    // IndexedStack：切页不销毁（台站列表滚动位置、会话、设置入口状态都保留）。
    // 刻意不给淡入动画：卡片本身在动，再叠一层淡入会显得闪。
    return IndexedStack(
      index: _tab,
      children: [
        _mapSummary(),
        StationsPage(state: widget.state, searchQuery: _search),
        MessagesPage(state: widget.state, isActive: true),
        PacketsPage(state: widget.state),
        SettingsPage(state: widget.state),
      ],
    );
  }

  /// 地图页对应的卡片内容。
  ///
  /// 地图本身已经是底了，这里不能再放一张地图 —— 放的是「抬起卡片时最想知道的
  /// 地图相关状态」：我是谁、在哪个网格、信标会不会真的发出去、链路通不通。
  /// 这也让「点地图页签 → 卡片收起」有了意义：收起是看地图，抬起是看自己这台电台。
  Widget _mapSummary() {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final st = widget.state;
        final s = S.of(context);
        final fix = st.myHasFix;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: C.blueBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(Icons.my_location_rounded, color: C.blue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(st.myCall,
                            style: ts(15, w: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(st.myPosStr,
                            style: ts(10, c: C.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (fix)
                    Icon(Icons.gps_fixed_rounded, color: C.green, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _tag(s.gridValue(st.myGrid), C.slate),
                  const SizedBox(width: 8),
                  _tag(s.packetsPerMinute(st.packetsPerMin), C.blue),
                  const SizedBox(width: 8),
                  _tag(
                    localizedLocationStatus(context, st.locStatus),
                    fix ? C.green : C.yellow,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 上报状态：这张卡是「看自己」的地方，所以信标的关键结论
              // （会不会真的发出去）要直说，而不是只画一个倒计时。
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: C.bgSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      st.beaconEnabled
                          ? Icons.send_rounded
                          : Icons.notifications_off_rounded,
                      size: 15,
                      color: st.beaconEnabled ? C.green : C.slate,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        st.beaconEnabled
                            ? (st.beaconPhase == BeaconPhase.imminent
                                ? s.beaconImminent
                                : s.beaconNextIn(st.nextBeaconIn))
                            : s.beaconOffChip,
                        style: ts(12, c: C.ink, w: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        st.sendBeacon();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(s.positionBeacon(st.myGrid)),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: C.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(s.manualBeacon,
                            style: ts(10.5,
                                c: Colors.white, w: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SettingsNavRow(
                title: S.of(context).immersiveMap,
                subtitle: S.of(context).immersiveMapTip,
                icon: Icons.navigation_rounded,
                color: C.indigo,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImmersiveMapPage(state: st),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tag(String text, Color c) => Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: ts(10.5, c: c, w: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );

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
        radius: 14,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: C.surfaceFillStrong,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.blue.withValues(alpha: 0.3)),
            boxShadow: softShadow(blur: 16, alpha: 0.25),
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
