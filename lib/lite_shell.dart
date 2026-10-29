import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'messages_page.dart';
import 'packets_page.dart';
import 'settings_page.dart';
import 'state.dart';
import 'stations_page.dart';
import 'theme.dart';
import 'tnc_page.dart';
import 'widgets.dart';

/// ─── 精简模式的外壳 ───
///
/// 用户要的是「回归最初的 APRS 工具属性」：一个能收、能发、能看台站和报文的
/// 窗口，没有地图底、没有可拖拽的面板、没有浮层顶栏。
///
/// 于是这一套外壳只有三层：
///
/// 1. **一条状态行**：呼号、链路在不在、信标还有多少秒。点一下链路状态就开
///    设备快捷面板（连接 / 断开的入口就在那儿，与 1.0、2.0 同一处）。
/// 2. **一排页签**：台站 / 消息 / 报文 / 设置。选中的那条只靠**下划线**和
///    字重区分，不用色块 —— 有四个色块的导航栏正是 2.0 被推翻的原因之一。
/// 3. **整片内容**：四个页面各占满屏，`IndexedStack` 常驻不销毁。
///
/// 为什么复用那四个页面而不是另写一套：它们是 1.0 布局下的整页形态（地图页
/// 之外的四个页签就是它们），在满屏宽度下本来就成立。另写一套只会有两份
/// 各自演化、慢慢说不到一起去。
///
/// 附加模块（排行榜、荣誉墙、赞助、翻译、轨迹、ADIF、天气）不在这里露面：
/// 入口在设置页里，而设置页按 [AppState.featureOn] 自己就不显示它们了。
class LiteShell extends StatefulWidget {
  final AppState state;
  const LiteShell({super.key, required this.state});

  @override
  State<LiteShell> createState() => _LiteShellState();
}

class _LiteShellState extends State<LiteShell> {
  /// 当前页签（0 = 台站）
  int _tab = 0;

  AppState get st => widget.state;

  /// 页面子树记忆化：只有切页签时才重建这一棵树。
  ///
  /// 否则 state 每通知一次（每秒的 tick、每来一条报文）外壳都重建一遍，
  /// 四个页面跟着重建 —— 台站列表几千条，那样真的会卡。
  Widget? _cachedPage;
  int _cachedPageTab = -1;

  Widget _pages() {
    if (_cachedPageTab == _tab) return _cachedPage!;
    _cachedPageTab = _tab;
    _cachedPage = IndexedStack(
      index: _tab,
      children: [
        StationsPage(state: st),
        MessagesPage(state: st, isActive: _tab == 1),
        PacketsPage(state: st),
        // 同上：设置页常驻，动画的起跑跟着页签
        SettingsPage(state: st, isActive: _tab == 3),
      ],
    );
    return _cachedPage!;
  }

  void _select(int i) {
    if (i == _tab) return;
    if (i == 1) st.clearUnread();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 返回键先回第一个页签（与 1.0 / 2.0 一致），已在第一个页签才退出应用
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() => _tab = 0);
      },
      child: Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Column(
            children: [
              _statusLine(),
              _tabs(),
              _reportBar(),
              Expanded(child: _pages()),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部那一行：呼号、链路状态、信标倒计时。
  Widget _statusLine() {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final up = st.anyLinkUp;
        return Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Text(
                st.myFullCall,
                style: ts(15, w: FontWeight.w800, ls: -0.2),
              ),
              const SizedBox(width: 10),
              // 链路状态：点开设备快捷面板。这里不给它一个按钮的边框 ——
              // 一行里最安静的那一项，但点得着。
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => showLinkSheet(context, st),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: up ? C.green : C.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        up ? s.connected : s.disconnected,
                        style: ts(11.5, c: up ? C.slate : C.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // 秒数不在这里——它归下面那条上报状态条（同一件事只说一遍）。
            ],
          ),
        );
      },
    );
  }

  /// 上报状态条：现在这一发是什么、以及「自动 / 单次」与「立即上报」。
  ///
  /// 用户 2026-10-22：「极简模式下保留手动发射状态条」。地图页底部那条横杠在精简
  /// 模式里没有位置（这一套外壳没有地图），于是一个只想手动发一包的人得跑进设置页。
  /// 这一条把那个入口捉回来：文案与颜色直接取 [beaconBarText] / [beaconBarColor]，
  /// 与地图页同一个判据；右侧就是三处共用的 [ReportActions]。
  ///
  /// 只一行、不摆符号与详细档的参量：精简模式要的就是这一行。
  Widget _reportBar() {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final c = beaconBarColor(st);
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.border, width: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    st.beaconEnabled
                        ? Icons.send_rounded
                        : Icons.notifications_off_rounded,
                    size: 14,
                    color: c,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      beaconBarText(context, st),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(11.5, c: C.ink, w: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ReportActions(state: st),
                ],
              ),
              // 声卡链路在收时，状态条底下挂一条声压条（与地图那条同一份）
              if (showAudioLevel(st))
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: AudioLevelStrip(level: st.audio.levelNotifier),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 一排页签。选中只有下划线 + 字重，没有色块。
  Widget _tabs() {
    final s = S.of(context);
    final items = <String>[s.stations, s.messages, s.packets, s.settings];
    final unread = st.unreadMessages;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.border, width: 0.5)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => _select(i),
                child: Container(
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _tab == i ? C.blue : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    i == 1 && unread > 0 ? '${items[i]} $unread' : items[i],
                    style: ts(
                      13,
                      c: _tab == i ? C.ink : C.slate,
                      w: _tab == i ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
