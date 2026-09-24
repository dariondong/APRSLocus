import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';
import 'material.dart';
import 'state.dart';
import 'widgets.dart';
import 'theme_store.dart';
import 'theme_text.dart';
import 'theme_icons.dart';
import 'map_page.dart';
import 'notice_banner.dart';
import 'stations_page.dart';
import 'messages_page.dart';
import 'packets_page.dart';
import 'settings_page.dart';
import 'settings_pages.dart';
import 'weather.dart';

class HomePage extends StatefulWidget {
  final AppState state;
  const HomePage({super.key, required this.state});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  String _search = '';
  int _lastFocusSeq = 0;
  int _lastPickSeq = 0;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce; // 搜索防抖：台站多时避免每敲一个字符重建地图/列表

  // 顶部消息气泡
  bool _showBubble = false;
  String _bubbleCall = '';
  String _bubbleText = '';
  Timer? _bubbleTimer;

  @override
  void initState() {
    super.initState();
    // 监听台站列表跳转地图 / 地图选点
    widget.state.addListener(_onStateChanged);
    // 收到新消息时弹出顶部气泡
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
      _showBubble = true;
      _bubbleCall = groupName != null
          ? S.of(context).groupBubble(groupName)
          : src;
      _bubbleText = text;
      if (mounted) setState(() {});
      _bubbleTimer?.cancel();
      _bubbleTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showBubble = false);
      });
    };
    // 收到群聊邀请时弹窗
    widget.state.onInviteReceived = (from, groupCall, groupName) {
      _showInviteDialog(from, groupCall, groupName);
    };
    // 收到群聊事件时通知
    widget.state.onGroupEvent = (groupCall, event) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '[$groupCall] ${localizedSystemMessage(context, event)}',
            ),
            backgroundColor: C.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };
    // 首次连接成功后询问：是否自动上报位置
    widget.state.onAskBeaconAuto = () {
      if (mounted) _askBeaconAuto();
    };
    // 首帧后补查一次：覆盖“OOBE 完成瞬间连接成功、绑定晚于连接”的竞态漏弹
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.state.maybeAskBeaconAuto();
    });
  }


  /// 首次连接成功后：询问是否自动上报位置（记住选择）
  Future<void> _askBeaconAuto() async {
    if (!mounted) return;
    final st = widget.state;
    final enable = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sheet = MaterialSurface(
          radius: 24,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: C.sheetFill,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: C.greenBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.send_rounded, color: C.green, size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        S.of(ctx).beaconAutoAskTitle,
                        style: ts(16, w: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  S.of(ctx).beaconAutoAskDesc,
                  style: ts(12, c: C.slate, h: 1.6),
                ),
                SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: C.slate,
                          side: BorderSide(color: C.borderStrong),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(S.of(ctx).beaconAutoNo,
                            style: ts(13, w: FontWeight.w600)),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: C.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(S.of(ctx).beaconAutoYes,
                            style: ts(13, w: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        return SafeArea(child: sheet);
      },
    );
    if (!mounted || enable == null) {
      // 用户直接划掉/返回：视为本次不选择，为避免反复打扰同样记住已问过
      if (mounted) widget.state.beaconAutoAnswered();
      return;
    }
    // 用户已做出选择 → 记录“已询问过”
    widget.state.beaconAutoAnswered();
    if (enable) {
      st.setBeaconEnabled(true);
      // 立即上报一次，让用户确认能在地图上看到自己
      if (st.myHasFix) {
        st.sendBeacon();
      } else {
        st.startTracking();
      }
    } else {
      st.setBeaconEnabled(false);
    }
  }

  void _onStateChanged() {
    if (!mounted) return;
    // 每秒 tick _notify() 都会进来，需要重建以更新倒计时等秒级数据
    setState(() {});
    if (widget.state.mapFocusSeq != _lastFocusSeq) {
      _lastFocusSeq = widget.state.mapFocusSeq;
      if (_tab != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _tab = 0);
        });
      }
    }
    if (widget.state.pickSeq != _lastPickSeq) {
      _lastPickSeq = widget.state.pickSeq;
      if (_tab != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _tab = 0);
        });
      }
    }
  }

  /// 群聊邀请弹窗
  void _showInviteDialog(String from, String groupCall, String groupName) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: C.orangeBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.group_add_rounded, color: C.orange, size: 20),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                S.of(context).groupInviteTitle,
                style: ts(16, w: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.of(context).groupInviteFrom(from), style: ts(13)),
            SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.bgSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).groupNameValue(groupName),
                    style: ts(13, w: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    S.of(context).groupCallsignValue(groupCall),
                    style: ts(12, c: C.orange, w: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.state.sendJoinConfirm(from, groupCall);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(S.of(context).groupInviteAccepted(groupName)),
                  backgroundColor: C.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              S.of(context).accept,
              style: ts(13, c: C.green, w: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(S.of(context).groupInviteRejected(groupName)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(S.of(context).reject, style: ts(13, c: C.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    widget.state.removeListener(_onStateChanged);
    widget.state.onNewMessage = null;
    widget.state.onInviteReceived = null;
    widget.state.onGroupEvent = null;
    widget.state.onAskBeaconAuto = null;
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 页签的图标与文案都来自主题：
  /// - 文案：[Tx] 先问主题有没有覆写，没有才回退 l10n；
  /// - 图标：交给 [ThemeController.buildSlotIcon]，它会在「用户导入了图片」
  ///   与「内置图标」之间选择，并在图片坏掉时回退。
  /// 元组第三项保留「默认图标名」，作为没装主题时的兜底，行为与旧版一致。
  static const _navSlots = [
    ('navMap', 'map_rounded'),
    ('navStations', 'cell_tower_rounded'),
    ('navMessages', 'chat_bubble_rounded'),
    ('navPackets', 'cable_rounded'),
    ('navSettings', 'settings_rounded'),
  ];

  List<(String, String, String)> get _nav {
    final tx = Tx.of(context);
    return [
      for (final sl in _navSlots) (sl.$1, sl.$2, _navLabel(tx, sl.$1)),
    ];
  }

  String _navLabel(Tx tx, String slot) {
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

  // 页面子树记忆化：仅当 tab / 搜索词变化时重建整个 IndexedStack。
  // 否则 HomePage 因键盘动画/状态通知重建时，各页面不会被父级连带重建，
  // 由各自内部监听器（地图 ListenableBuilder、台站页 StreamBuilder 等）自我更新。
  Widget? _cachedPage;
  int _cachedPageTab = -1;
  String _cachedPageSearch = '';

  Widget _page() {
    if (_cachedPageTab == _tab && _cachedPageSearch == _search) {
      return _cachedPage!;
    }
    _cachedPageTab = _tab;
    _cachedPageSearch = _search;
    // IndexedStack：所有页面常驻不销毁。
    // 地图页（含矢量 style 缓存、相机位置）切换 tab 后保留，
    // 避免每次切回都重新加载瓦片/重建地图。
    // 外层淡入动画：切 tab 时页面淡入，过渡平滑。
    _cachedPage = TweenAnimationBuilder<double>(
      key: ValueKey('tabfade-$_tab'),
      tween: Tween(begin: 0.3, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: IndexedStack(
        index: _tab,
        children: [
          MapPage(state: widget.state, searchQuery: _search, isActive: _tab == 0),
          StationsPage(state: widget.state, searchQuery: _search),
          MessagesPage(state: widget.state, isActive: _tab == 2),
          PacketsPage(state: widget.state),
          SettingsPage(state: widget.state),
        ],
      ),
    );
    return _cachedPage!;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    // 横屏（手机/平板）强制桌面布局：侧边栏 + 顶栏，出现平板/桌面效果
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final narrow = !landscape && w < 920;
    return Scaffold(
      backgroundColor: C.pageFill,
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                if (!narrow) _sidebar(),
                Expanded(
                  child: Column(
                    children: [
                      _topBar(),
                      // ── 公告横幅（主页也有一条；用户要求「在主页显示横幅」）──
                      // 放在顶栏与内容之间：它是**一条通知**，不该压在内容上；
                      // 这一列是 Column，所以它会**真的占掉**高度，内容自动下移 ——
                      // 不需要像 2.0 那边那样手动算让位量。
                      // 开关关掉时组件自己返回空（且不联网），这里不用判断。
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: NoticeBanner(state: widget.state),
                      ),
                      // 各页面内部自监听（地图/消息/数据包/设置用 ListenableBuilder、
                      // 台站页用 StreamBuilder），无需外层再包全量 state 监听。
                      Expanded(child: _page()),
                      _connBanner(),
                    ],
                  ),
                ),
              ],
            ),
            // 顶部新消息气泡
            if (_showBubble)
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(child: _messageBubble()),
              ),
          ],
        ),
      ),
      bottomNavigationBar: narrow ? _bottomNav() : null,
    );
  }

  // ─── 顶部新消息气泡 ───
  Widget _messageBubble() {
    return GestureDetector(
      onTap: () {
        setState(() => _showBubble = false);
        _bubbleTimer?.cancel();
        // 跳转到消息页
        widget.state.clearUnread();
        if (_tab != 2) setState(() => _tab = 2);
      },
      child: MaterialSurface(
        radius: 16,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: C.surfaceFillStrong,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: C.blue.withValues(alpha: 0.3)),
            boxShadow: elev3(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: C.blueBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _bubbleCall.length >= 2
                        ? _bubbleCall.substring(_bubbleCall.length - 2)
                        : _bubbleCall,
                    style: ts(9, c: C.blue, w: FontWeight.w700),
                  ),
                ),
              ),
              SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _bubbleCall,
                      style: ts(12, c: C.blue, w: FontWeight.w700),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _bubbleText,
                      style: ts(11, c: C.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.close_rounded, size: 14, color: C.greyLight),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 侧边栏（手机横屏时紧凑显示，避免溢出） ───
  bool get _compact {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    // 横屏较窄（含大屏手机横屏，如 926pt 宽）用紧凑侧栏，留更多空间给地图
    return sw > sh && sw < 1024;
  }

  Widget _sidebar() {
    final compact = _compact;
    final sw = MediaQuery.of(context).size.width;
    final width = compact ? (sw * 0.20).clamp(120.0, 155.0) : 232.0;
    // 侧边栏/底栏/顶栏这三块是「壳」，它们压在页面内容之上且**不随内容滚动**：
    // 材质开启时必须给它们真模糊，否则地图瓦片/列表会从半透明壳里直接透出来。
    return MaterialSurface(
      // 1.0 的壳（侧栏 / 顶栏 / 底栏）压在**壁纸**上，不在内容上：
      // 模糊一层渐变壁纸看不到差别，白付每帧一次 pass 收尾/重开（见 material.dart）。
      overWallpaper: true,
      child: Container(
        width: width,
        color: C.surfaceFillStrong,
        child: Column(
          children: [
            // Logo
            Padding(
              padding: compact
                  ? const EdgeInsets.fromLTRB(12, 12, 12, 10)
                  : const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  AppLogo(size: compact ? 30 : 38),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'APRSlocus',
                        style: ts(
                          compact ? 14 : 17,
                          w: FontWeight.w800,
                          ls: -0.3,
                        ),
                      ),
                      if (!compact) ...[
                        SizedBox(height: 1),
                        Text(
                          S.of(context).appTagline,
                          style: ts(10, c: C.grey),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // 导航
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 12,
                  vertical: 4,
                ),
                itemCount: _nav.length,
                separatorBuilder: (_, _) => SizedBox(height: 2),
                itemBuilder: (_, i) {
                  final sel = _tab == i;
                  final item = _nav[i];
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: sel
                          ? (ThemeController.instance.tabAccent(
                                      item.$1,
                                      isDark: C.dark,
                                    ) ??
                                    C.blue)
                                .withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (i == 2) widget.state.clearUnread();
                          setState(() => _tab = i);
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 10 : 14,
                            vertical: compact ? 8 : 11,
                          ),
                          child: Row(
                            children: [
                              ThemeController.instance.buildSlotIcon(
                                item.$1,
                                size: compact ? 18 : 20,
                                color: sel
                                    ? (ThemeController.instance.tabAccent(
                                            item.$1,
                                            isDark: C.dark,
                                          ) ??
                                          C.blue)
                                    : C.slate,
                                fallbackIcon: themeIconByName(item.$2),
                                selected: sel,
                              ),
                              SizedBox(width: 10),
                              Text(
                                item.$3,
                                style: ts(
                                  compact ? 12 : 13,
                                  c: sel
                                      ? (ThemeController.instance.tabAccent(
                                              item.$1,
                                              isDark: C.dark,
                                            ) ??
                                            C.blue)
                                      : C.ink,
                                  w: sel ? FontWeight.w600 : FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              if (i == 2 && widget.state.unreadMessages > 0)
                                _countBadge(widget.state.unreadMessages),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // 我的位置（紧凑模式隐藏，避免溢出）
            if (!compact) _myPanel(),
          ],
        ),
      ),
    );
  }

  Widget _countBadge(int n) {
    if (n == 0) return const SizedBox.shrink();
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: C.red,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          '$n',
          style: ts(9, c: Colors.white, w: FontWeight.w700),
        ),
      ),
    );
  }

  /// 底部导航小角标（窄屏）
  Widget _miniBadge(int n) {
    if (n <= 0) return const SizedBox.shrink();
    final text = n > 99 ? '99+' : '$n';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
      decoration: BoxDecoration(
        color: C.red,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          text,
          style: ts(9, c: Colors.white, w: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _myPanel() {
    // 每秒 tick 只刷新信标倒计时/收包速率等秒级文本；
    // 连接/定位等真实状态变化由 HomePage 重建（_onStateChanged setState）覆盖
    return ValueListenableBuilder<int>(
      valueListenable: widget.state.tick,
      builder: (context, _, _) => _myPanelBody(),
    );
  }

  Widget _myPanelBody() {
    final fix = widget.state.myHasFix;
    final locColor = fix
        ? C.green
        : widget.state.loc.running
        ? C.blue
        : C.yellow;
    final connColor = widget.state.connected
        ? C.green
        : widget.state.connecting
        ? C.blue
        : C.slate;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.bgSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 我的电台
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: C.blueBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.my_location_rounded, color: C.blue, size: 20),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.state.myCall,
                      style: ts(13, w: FontWeight.w700),
                    ),
                    Text(widget.state.myPosStr, style: ts(9, c: C.grey)),
                  ],
                ),
              ),
              if (fix) Icon(Icons.gps_fixed_rounded, color: C.green, size: 18),
            ],
          ),
          SizedBox(height: 8),
          // 网格 + 速率
          // 两端的文案都是「按当前状态拼出来的」：网格值与速率数字一变长
          // （例如速率到 4 位数），不限制宽度就会把这一段撑出横幅外。
          Row(
            children: [
              Icon(Icons.grid_4x4_rounded, size: 12, color: C.grey),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  S.of(context).gridValue(widget.state.myGrid),
                  style: ts(10, c: C.slate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Spacer(),
              Icon(Icons.speed_rounded, size: 12, color: C.grey),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  S.of(context).packetsPerMinute(widget.state.packetsPerMin),
                  style: ts(10, c: C.slate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          // 状态行
          Row(
            children: [
              _dot(locColor),
              SizedBox(width: 6),
              Text(
                localizedLocationStatus(context, widget.state.locStatus),
                style: ts(11, c: locColor, w: FontWeight.w600),
              ),
              Spacer(),
              _dot(connColor),
              SizedBox(width: 6),
              Text(
                widget.state.connected
                    ? S.of(context).connected
                    : S.of(context).demo,
                style: ts(
                  11,
                  c: widget.state.connected ? C.green : C.slate,
                  w: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.timer_rounded, size: 12, color: C.grey),
              SizedBox(width: 4),
              // 注意：AppState.nextBeaconIn 已经本地化（内部按 locale 取 l10n），
              // 不要再包一层 localizedNextBeaconValue —— 那个助手是按「中文
              // 状态串」做映射的旧模式，传入已本地化文案会匹配不上。
              Text(
                // 射频未开信标 / 当前是**粗定位（网络）**时给出原因，而不是显示
                // 一个不会生效的倒计时 —— 判据用结构化的 beaconPhase（与
                // AppState.canAutoBeacon 同源，两处漂移就是「倒计时走着不发」）。
                widget.state.beaconPhase == BeaconPhase.rfDisabled
                    ? S.of(context).beaconRfBeaconOff
                    : (widget.state.beaconPhase == BeaconPhase.coarseFix
                        ? S.of(context).beaconCoarseFix
                        : S.of(context).nextBeaconIn(widget.state.nextBeaconIn)),
                style: ts(10,
                    c: (widget.state.beaconNeedsRfEnable ||
                            widget.state.beaconPhase == BeaconPhase.coarseFix)
                        ? C.orange
                        : C.slate),
              ),
              Spacer(),
              Icon(Icons.sync_rounded, size: 12, color: C.grey),
              SizedBox(width: 4),
              Text(
                S.of(context).beaconCount(widget.state.beaconsSent),
                style: ts(10, c: C.slate),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 位置上报状态行：连接后可见。
          //
          // 这里用 [AppState.txSourceUp] 而不是 `connected`：只读模式（只开
          // PKWDWPL）下没有发射链路，但仍要让用户看到「正在收航点」——
          // 否则主页会把一个正在正常工作的应用显示成完全没连上。
          if (widget.state.txSourceUp || widget.state.pkwdwplOn) ...[
            // 只读模式（只启用 PKWDWPL）：位置上报那套开关对它没有任何意义，
            // 所以换行「只读接收」+ 已收航点数，而不是摆一个按了不会发射的
            // 「开启自动上报」。
            if (!widget.state.txSourceUp)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: C.orangeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 13, color: C.orange),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        S.of(context).pkwdwplReadOnly,
                        style: ts(10, c: C.orange, w: FontWeight.w600),
                      ),
                    ),
                    Text(
                      S.of(context)
                          .beaconCount(widget.state.pkwdwpl.rxFrames),
                      style: ts(10, c: C.slate, w: FontWeight.w600),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.state.beaconEnabled ? C.greenBg : C.greyBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.state.beaconEnabled
                          ? Icons.send_rounded
                          : Icons.notifications_off_rounded,
                      size: 13,
                      color: widget.state.beaconEnabled ? C.green : C.grey,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.state.beaconEnabled
                            ? (widget.state.smartBeaconEnabled
                                ? '自动上报中 · 智能分档(每 ${widget.state.beaconIntervalNow}s)'
                                : '自动上报中 · 每 ${widget.state.beaconInterval}s')
                            : '位置未上报 · 仅接收',
                        style: ts(
                          10.5,
                          c: widget.state.beaconEnabled ? C.green : C.slate,
                          w: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!widget.state.beaconEnabled)
                      GestureDetector(
                        onTap: () {
                          widget.state.setBeaconEnabled(true);
                          if (widget.state.myHasFix) {
                            widget.state.sendBeacon();
                          }
                        },
                        child: Text(
                          '开启自动上报',
                          style: ts(10, c: C.blue, w: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
            SizedBox(height: 10),
          ],
          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  // 只读模式（只启用 PKWDWPL）下没有发射链路，按钮**置灰**
                  // 并在文案里说明原因。不隐藏它：位置突然少一个按钮会让人
                  // 找不到，而置灰 + 说明反而能直接回答「为什么发不出去」。
                  onPressed: widget.state.readOnlyMode
                      ? null
                      : () {
                          if (widget.state.myHasFix) {
                            widget.state.sendBeacon();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  widget.state.connected
                                      ? S
                                            .of(context)
                                            .beaconSentAprsIs(
                                                widget.state.myGrid)
                                      : S
                                            .of(context)
                                            .beaconSentDemo(
                                                widget.state.myGrid),
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            widget.state.startTracking();
                          }
                        },
                  icon: Icon(
                    widget.state.myHasFix
                        ? Icons.send_rounded
                        : Icons.my_location_rounded,
                    size: 18,
                  ),
                  label: Text(
                    widget.state.readOnlyMode
                        ? S.of(context).pkwdwplRxOnly
                        : (widget.state.myHasFix
                            ? S.of(context).beaconNow
                            : S.of(context).getLocation),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.state.readOnlyMode
                        ? C.grey
                        : (widget.state.myHasFix ? C.green : C.blue),
                    side: BorderSide(
                      color: (widget.state.readOnlyMode
                              ? C.greyLight
                              : (widget.state.myHasFix ? C.green : C.blue))
                          .withValues(alpha: 0.5),
                    ),
                    // 手动上报是主页最高频的动作，给足触摸目标
                    // （44 高 ≈ Material 的最小可点区域，原 8 内边距只有 34）
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    textStyle: ts(13, w: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.state.toggleConnect,
                  icon: Icon(
                    widget.state.connected
                        ? Icons.stop_circle_outlined
                        : Icons.wifi_rounded,
                    size: 15,
                  ),
                  label: Text(
                    widget.state.connected
                        ? S.of(context).disconnect
                        : widget.state.connecting
                        ? S.of(context).connecting
                        : widget.state.usingAudio
                        ? S.of(context).audioCaptureStart
                        : widget.state.usingTnc
                        ? S.of(context).tncConnectAction
                        : S.of(context).connectAprsIs,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.state.connected ? C.red : C.blue,
                    side: BorderSide(
                      color: (widget.state.connected ? C.red : C.blue)
                          .withValues(alpha: 0.5),
                    ),
                    // 与「手动上报」对齐：两个按钮并排，一大一小会显得很怪
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    textStyle: ts(13, w: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 顶栏 ───
  Widget _topBar() {
    final compact = _compact;
    return MaterialSurface(
      // 同上：顶栏背后没有内容，只有壁纸
      overWallpaper: true,
      child: Container(
        height: compact ? 48 : 58,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 20),
        color: C.surfaceFillStrong,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 手机横屏紧凑模式下：只要右侧宽度足够就保留搜索+统计，否则只留标题+在线数
            final wide = constraints.maxWidth > 560;
            final searchW = (constraints.maxWidth * 0.28).clamp(140.0, 260.0);
            return Row(
              children: [
                Expanded(
                  child: Text(
                    _nav[_tab].$3,
                    style: T.h2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (wide) ...[
                  Container(
                    width: searchW,
                    height: 38,
                    decoration: BoxDecoration(
                      color: C.bgSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) {
                        // 防抖：输入停止 300ms 才更新搜索，台站多时避免逐字重建卡顿
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 300),
                          () {
                            if (mounted) setState(() => _search = v);
                          },
                        );
                      },
                      style: ts(13),
                      decoration: InputDecoration(
                        hintText: S.of(context).searchHint,
                        hintStyle: ts(13, c: C.grey),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: C.grey,
                        ),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: C.grey,
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  // 天气组件（在线左侧）：默认显示当前天气 + 温度，点击弹浮动面板
                  if (widget.state.weatherEnabled) ...[
                    WeatherBadge(state: widget.state),
                    const SizedBox(width: 8),
                  ],
                  _statTag(
                    '${widget.state.online}',
                    S.of(context).online,
                    C.green,
                    C.greenBg,
                  ),
                  SizedBox(width: 8),
                  _statTag(
                    '${widget.state.moving}',
                    S.of(context).moving,
                    C.blue,
                    C.blueBg,
                  ),
                  SizedBox(width: 8),
                  _statTag(
                    '${widget.state.packetsRx}',
                    S.of(context).packetsReceived,
                    C.slate,
                    C.greyBg,
                  ),
                ] else ...[
                  // 天气组件（在线左侧）：窄屏同样展示（标题可收缩防溢出）
                  if (widget.state.weatherEnabled) ...[
                    WeatherBadge(state: widget.state),
                    const SizedBox(width: 8),
                  ],
                  _statTag(
                    '${widget.state.online}',
                    S.of(context).online,
                    C.green,
                    C.greenBg,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statTag(String val, String label, Color c, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        '$val $label',
        style: ts(11, c: c, w: FontWeight.w600),
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: c,
      boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4)],
    ),
  );

  // ─── 未连接 / Passcode 错误提示横幅 ───
  Widget _connBanner() {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final st = widget.state;
        final compact = _compact;
        // Passcode 未验证：显示黄色警告横幅（类似未连接提示）
        if (st.connected && st.passcodeInvalid) {
          return Container(
            margin: EdgeInsets.fromLTRB(
                compact ? 10 : 12, 0, compact ? 10 : 12, compact ? 6 : 10),
            padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 14, vertical: compact ? 7 : 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: elev3(),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context).passcodeUnverified,
                        style: ts(12, c: Colors.white, w: FontWeight.w700),
                      ),
                      Text(
                        S.of(context).passcodeWarning,
                        style: ts(10, c: Colors.white70),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // 跳到设置 tab 并直接打开「连接设置」（passcode 输入所在页），
                    // 而不是只停在设置首页
                    if (_tab != 4) setState(() => _tab = 4);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ConnectionSettingsPage(
                          state: widget.state,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      S.of(context).goSettings,
                      style: ts(11, c: Colors.white, w: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        if (st.connected) return const SizedBox.shrink();
        final connecting = st.connecting;
        // TNC 模式下标题/副标题都要改口径：不再有「服务器」，
        // 否则用户会以为填个地址就能连上。
        final tncMode = st.usingTnc;
        final audioMode = st.usingAudio;
        // PKWDWPL 永远不会成为发射来源（只读），所以它只可能出现在
        // 「未连接」横幅下 —— 此时提示用户它需要单独绑定端口。
        // 只读模式（只启用 PKWDWPL）：没有发射链路，但一直在收航点。
        // 横幅改成「PKWDWPL · 只读接收」，而不是「未连接」——后者会让
        // 用户以为需要去点连接。
        //
        // 条件里额外看 pkwdwpl.connected：设备页手动连上、但来源还未启用
        // （旧配置/异常路径）时也不能说「未连接 APRS-IS 服务器」，那与事实相反。
        final pkwdwplMode =
            (st.pkwdwplOn || st.pkwdwpl.connected) && !st.txSourceUp;
        // 更一般的情况：**有链路在收，但它不是发射来源**（例如设备页刚连上
        // TNC，而发射仍走未连接的 APRS-IS）。这时也不能说「未连接」——
        // 用户明明刚连上东西，界面却报未连接。
        final rxOnly = st.rxActive && !st.txSourceUp && !pkwdwplMode;
        // 音频来源没有「设备」概念，改成展示采样率（用户真正关心的参数）
        final tncName = audioMode
            ? '${st.audio.config.afsk.sampleRate}Hz'
            : (st.tnc.device?.label ?? S.of(context).tncNotBound);
        final title = connecting
            ? (audioMode
                ? S.of(context).dataSourceAudio
                : (tncMode
                    ? S.of(context).dataSourceTnc
                    : S.of(context).connectingServer))
            : (audioMode
                ? S.of(context).audioCaptureStart
                : (tncMode
                    ? S.of(context).connectTncBar
                    : (pkwdwplMode
                        ? S.of(context).dataSourcePkwdwpl
                        : (rxOnly ? 'RX' : S.of(context).notConnectedAprsServer))));
        final subtitle = connecting
            ? (audioMode
                ? S.of(context).connConnectingAudio(tncName)
                : (tncMode
                    ? S.of(context).connectingToTnc(tncName)
                    : S
                        .of(context)
                        .connectingToServer(st.aprs.server, st.aprs.port)))
            : (audioMode
                ? S.of(context).dataSourceAudioDesc
                : (tncMode
                    ? S.of(context).dataSourceTncDesc
                    : (pkwdwplMode
                        ? S.of(context).dataSourcePkwdwplDesc
                        : (rxOnly
                            ? S.of(context).rxOnlyBanner(st.rxSourceLabel)
                            : S.of(context).connectNearbyDesc))));
        return Container(
          margin: EdgeInsets.fromLTRB(
              compact ? 10 : 12, 0, compact ? 10 : 12, compact ? 6 : 10),
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14, vertical: compact ? 7 : 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [C.blue, C.indigo],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: elev3(),
          ),
          child: Row(
            children: [
              if (connecting)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  Icons.wifi_tethering_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ts(13, c: Colors.white, w: FontWeight.w700),
                    ),
                    Text(
                      subtitle,
                      style: ts(10, c: Colors.white.withValues(alpha: 0.8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: connecting ? null : st.toggleConnect,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    connecting
                        ? S.of(context).connecting
                        : S.of(context).connectAction,
                    style: ts(12, c: C.blue, w: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── 底部导航（窄屏） ───
  Widget _bottomNav() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return MaterialSurface(
      // 同上：底栏背后没有内容，只有壁纸
      overWallpaper: true,
      child: Container(
        decoration: BoxDecoration(
          color: C.surfaceFillStrong,
          border: Border(top: BorderSide(color: C.border)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPad),
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(_nav.length, (i) {
                final sel = _tab == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (i == 2) widget.state.clearUnread();
                      setState(() => _tab = i);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ThemeController.instance.buildSlotIcon(
                              _nav[i].$1,
                              size: 22,
                              color: sel
                                  ? (ThemeController.instance.tabAccent(
                                          _nav[i].$1,
                                          isDark: C.dark,
                                        ) ??
                                        C.blue)
                                  : C.grey,
                              fallbackIcon: themeIconByName(_nav[i].$2),
                              selected: sel,
                            ),
                            if (i == 2 && widget.state.unreadMessages > 0)
                              Positioned(
                                right: -8,
                                top: -4,
                                child: _miniBadge(widget.state.unreadMessages),
                              ),
                          ],
                        ),
                        SizedBox(height: 3),
                        Text(
                          _nav[i].$3,
                          style: ts(
                            10,
                            c: sel
                                ? (ThemeController.instance.tabAccent(
                                        _nav[i].$1,
                                        isDark: C.dark,
                                      ) ??
                                      C.blue)
                                : C.grey,
                            w: sel ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
