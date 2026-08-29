import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';
import 'state.dart';
import 'widgets.dart';
import 'map_page.dart';
import 'stations_page.dart';
import 'messages_page.dart';
import 'packets_page.dart';
import 'settings_page.dart';

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
            content: Text('[$groupCall] $event'),
            backgroundColor: C.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };
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
                borderRadius: BorderRadius.circular(10),
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
                borderRadius: BorderRadius.circular(10),
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
              style: ts(14, c: C.green, w: FontWeight.w700),
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
            child: Text(S.of(context).reject, style: ts(14, c: C.red)),
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
    _searchCtrl.dispose();
    super.dispose();
  }

  static const _navIcons = [
    (Icons.map_outlined, Icons.map_rounded),
    (Icons.cell_tower_outlined, Icons.cell_tower_rounded),
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
    (Icons.cable_outlined, Icons.cable_rounded),
    (Icons.settings_outlined, Icons.settings_rounded),
  ];

  List<(IconData, IconData, String)> get _nav {
    final s = S.of(context);
    return [
      (Icons.map_outlined, Icons.map_rounded, s.map),
      (Icons.cell_tower_outlined, Icons.cell_tower_rounded, s.stations),
      (
        Icons.chat_bubble_outline_rounded,
        Icons.chat_bubble_rounded,
        s.messages,
      ),
      (Icons.cable_outlined, Icons.cable_rounded, s.packets),
      (Icons.settings_outlined, Icons.settings_rounded, s.settings),
    ];
  }

  Widget _page() {
    // IndexedStack：所有页面常驻不销毁。
    // 地图页（含矢量/高德JS 的 style 缓存、相机位置、WebView 状态）切换 tab 后保留，
    // 避免每次切回都重新加载瓦片/重建 WebView。
    // 外层淡入动画：切 tab 时页面淡入，过渡平滑。
    return TweenAnimationBuilder<double>(
      key: ValueKey('tabfade-$_tab'),
      tween: Tween(begin: 0.3, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: IndexedStack(
        index: _tab,
        children: [
          MapPage(state: widget.state, searchQuery: _search),
          StationsPage(state: widget.state, searchQuery: _search),
          MessagesPage(state: widget.state, isActive: _tab == 2),
          PacketsPage(state: widget.state),
          SettingsPage(state: widget.state),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    // 横屏（手机/平板）强制桌面布局：侧边栏 + 顶栏，出现平板/桌面效果
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final narrow = !landscape && w < 920;
    return Scaffold(
      backgroundColor: C.bg,
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
                      Expanded(
                        child: ListenableBuilder(
                          listenable: widget.state,
                          builder: (_, _) => _page(),
                        ),
                      ),
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
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.blue.withValues(alpha: 0.3)),
          boxShadow: softShadow(blur: 16, alpha: 0.25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: C.blueBg,
                borderRadius: BorderRadius.circular(9),
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
    );
  }

  // ─── 侧边栏（手机横屏时紧凑显示，避免溢出） ───
  bool get _compact {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    return sw > sh && sw < 920;
  }

  Widget _sidebar() {
    final compact = _compact;
    final sw = MediaQuery.of(context).size.width;
    final width = compact ? (sw * 0.20).clamp(120.0, 155.0) : 232.0;
    return Container(
      width: width,
      color: C.white,
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
                      Text(S.of(context).appTagline, style: ts(10, c: C.grey)),
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
                    color: sel ? C.blueBg : Colors.transparent,
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
                            Icon(
                              sel ? item.$2 : item.$1,
                              color: sel ? C.blue : C.slate,
                              size: compact ? 18 : 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              item.$3,
                              style: ts(
                                compact ? 12 : 13,
                                c: sel ? C.blue : C.ink,
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
    );
  }

  Widget _countBadge(int n) {
    if (n == 0) return const SizedBox.shrink();
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: C.red,
        borderRadius: BorderRadius.circular(9),
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
          style: ts(8, c: Colors.white, w: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _myPanel() {
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
        borderRadius: BorderRadius.circular(14),
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
                  borderRadius: BorderRadius.circular(10),
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
          Row(
            children: [
              Icon(Icons.grid_4x4_rounded, size: 12, color: C.grey),
              SizedBox(width: 4),
              Text(
                S.of(context).gridValue(widget.state.myGrid),
                style: ts(10, c: C.slate),
              ),
              Spacer(),
              Icon(Icons.speed_rounded, size: 12, color: C.grey),
              SizedBox(width: 4),
              Text(
                S.of(context).packetsPerMinute(widget.state.packetsPerMin),
                style: ts(10, c: C.slate),
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
                widget.state.locStatus,
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
              Text(
                S.of(context).nextBeaconIn(widget.state.nextBeaconIn),
                style: ts(10, c: C.slate),
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
          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (widget.state.myHasFix) {
                      widget.state.sendBeacon();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            widget.state.connected
                                ? S
                                      .of(context)
                                      .beaconSentAprsIs(widget.state.myGrid)
                                : S
                                      .of(context)
                                      .beaconSentDemo(widget.state.myGrid),
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      widget.state.startTracking();
                    }
                  },
                  icon: Icon(Icons.send_rounded, size: 15),
                  label: Text(
                    widget.state.myHasFix
                        ? S.of(context).beaconNow
                        : S.of(context).getLocation,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.state.myHasFix ? C.green : C.blue,
                    side: BorderSide(
                      color: (widget.state.myHasFix ? C.green : C.blue)
                          .withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: ts(11, w: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
                        : S.of(context).connectAprsIs,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.state.connected ? C.red : C.blue,
                    side: BorderSide(
                      color: (widget.state.connected ? C.red : C.blue)
                          .withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: ts(11, w: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: C.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 手机横屏紧凑模式不显示搜索框+统计，避免溢出
          final wide = constraints.maxWidth > 560 && !_compact;
          final searchW = (constraints.maxWidth * 0.28).clamp(140.0, 260.0);
          return Row(
            children: [
              Text(_nav[_tab].$3, style: T.h2),
              Spacer(),
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
                    onChanged: (v) => setState(() => _search = v),
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
              ] else
                _statTag(
                  '${widget.state.online}',
                  S.of(context).online,
                  C.green,
                  C.greenBg,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _statTag(String val, String label, Color c, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
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
        // Passcode 未验证：显示黄色警告横幅（类似未连接提示）
        if (st.connected && st.passcodeInvalid) {
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: softShadow(blur: 16, alpha: 0.22),
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
                    if (_tab != 4) setState(() => _tab = 4);
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
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [C.blue, C.indigo],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: softShadow(blur: 16, alpha: 0.22),
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
                      connecting
                          ? S.of(context).connectingServer
                          : S.of(context).notConnectedAprsServer,
                      style: ts(13, c: Colors.white, w: FontWeight.w700),
                    ),
                    Text(
                      connecting
                          ? S
                                .of(context)
                                .connectingToServer(
                                  st.aprs.server,
                                  st.aprs.port,
                                )
                          : S.of(context).connectNearbyDesc,
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
                    borderRadius: BorderRadius.circular(10),
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
    return Container(
      decoration: BoxDecoration(
        color: C.white,
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
                          Icon(
                            sel ? _nav[i].$2 : _nav[i].$1,
                            color: sel ? C.blue : C.grey,
                            size: 22,
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
                          c: sel ? C.blue : C.grey,
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
    );
  }
}
