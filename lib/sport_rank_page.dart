import 'package:flutter/material.dart';

import 'models.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'station_detail.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 运动排行榜（设置 → 运动排行榜，在荣誉墙上方）───
///
/// 用户需求（issue #22-3）：「在设置页面荣誉墙上方加一个运动排行榜，显示当天
/// APRSLocus 用户运动的排行榜。点击用户，可以呼出台站页面。（基于 2 号提供更改。）」
///
/// ── 这份榜单**是什么、不是什么**（必须写在页面上）──
///
/// 这里没有服务器，也没有「所有 APRSlocus 用户」这个集合可用 —— 数据只能来自
/// **本机收到的位置报文**里那个非标准备注字段 `STEPS=`（见 #22-2 的实现）。
/// 于是它天然是「你听得到的邻居」的排行，且**对方必须开了步数上报**才会出现。
/// 把这一条写在页面上比榜单本身更重要：不写，用户会以为自己在跟全国比。
///
/// 排序只在「有步数的人之间」有意义，所以没带步数的 APRSlocus 台站单独列一段 ——
/// 直接丢掉它们会让人以为「附近只有这几个人在用」。
class SportRankPage extends StatelessWidget {
  final AppState state;
  const SportRankPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = state;
    final ranked = st.sportRank();
    // 没带步数的 APRSlocus 台站：只列出来（不排），让用户知道自己并不孤单
    final noSteps = st.stations
        .where((x) =>
            x.toCall == AppState.apalocToCall &&
            !RegExp(r'STEPS=\d+').hasMatch(x.comment ?? '') &&
            x.call != st.myFullCall)
        .toList()
      ..sort((a, b) => b.lastHeard.compareTo(a.lastHeard));

    return SettingsPageShell(
      title: s.sportRank,
      subtitle: s.sportRankDesc,
      icon: Icons.leaderboard_rounded,
      color: C.green,
      body: Column(children: [
        // ① 口径说明：放在**最上面**，先讲清这是什么榜再看数字
        SettingsHint(s.sportRankNote, color: C.orange),
        const SizedBox(height: 12),
        // ② 我自己那一行：本机步数来自手机计步传感器（不依赖别人上报）
        _meCard(context, st),
        const SizedBox(height: 16),
        // ③ 榜单
        SettingsSectionCard(
          title: s.sportRankToday,
          subtitle: S.of(context).sportRankDesc,
          icon: Icons.emoji_events_rounded,
          color: C.green,
          children: [
            if (ranked.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Text(s.sportRankEmpty,
                    style: ts(12, c: C.grey, h: 1.5)),
              )
            else
              for (var i = 0; i < ranked.length; i++)
                _rankTile(context, st, i + 1, ranked[i].$1, ranked[i].$2),
          ],
        ),
        if (noSteps.isNotEmpty) ...[
          const SizedBox(height: 16),
          SettingsSectionCard(
            title: s.sportRankNoSteps,
            subtitle: S.of(context).beaconIncludeSteps,
            icon: Icons.person_search_rounded,
            color: C.grey,
            children: [
              for (final x in noSteps.take(10)) _noStepsTile(context, st, x),
            ],
          ),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }

  /// 我自己：今日步数 + 是否随信标发出（决定别人能不能在榜上看到我）。
  Widget _meCard(BuildContext context, AppState st) {
    final s = S.of(context);
    return SettingsSectionCard(
      title: s.sportRankMe,
      subtitle: st.myFullCall,
      icon: Icons.directions_walk_rounded,
      color: C.blue,
      children: [
        SettingsRow2(
          s.stepsTodayLabel,
          st.stepsToday > 0
              ? s.stepsCount('${st.stepsToday}')
              : (st.hasStepSensor
                  ? s.stepsNeedPermission
                  : s.stepsUnsupported),
          valueColor: st.stepsToday > 0 ? C.green : C.orange,
        ),
        SettingsSwitch(s.beaconIncludeSteps,
            value: st.beaconIncludeSteps, onChanged: st.setBeaconIncludeSteps),
        SettingsHint(
          st.beaconIncludeSteps
              ? s.stepsHint
              : S.of(context).sportRankNote,
          color: C.grey,
        ),
      ],
    );
  }

  Widget _rankTile(
      BuildContext context, AppState st, int rank, Station x, int steps) {
    final s = S.of(context);
    final medal = switch (rank) {
      1 => const Color(0xFFC9A227),
      2 => const Color(0xFF9CA3AF),
      3 => const Color(0xFFB45309),
      _ => C.grey,
    };
    return SettingsNavRow(
      title: x.call,
      subtitle: '${s.sportRankToday} · ${_ago(context, x.lastHeard)}',
      icon: rank <= 3 ? Icons.emoji_events_rounded : Icons.person_rounded,
      color: medal,
      trailing: s.stepsCount('$steps'),
      onTap: () => _open(context, st, x),
    );
  }

  Widget _noStepsTile(BuildContext context, AppState st, Station x) {
    final s = S.of(context);
    return SettingsNavRow(
      title: x.call,
      subtitle: _ago(context, x.lastHeard),
      icon: Icons.person_outline_rounded,
      color: C.grey,
      trailing: s.sportRankNoSteps,
      onTap: () => _open(context, st, x),
    );
  }

  /// 打开台站详情。类名是 [StationDetail]（不是 StationDetailPage），
  /// 参数顺序是 `state` 在前 —— 与仓库里其它调用点保持一致。
  void _open(BuildContext context, AppState st, Station x) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StationDetail(state: st, station: x)),
    );
  }

  /// 「刚刚 / 3 分钟前 / 2 小时前」——榜单上的时间要能一眼判断新旧。
  ///
  /// 复用仓库里已有的 `timeJustNow / minutesAgo / hoursAgo / daysAgo`：
  /// 那三个的占位符在 arb 里声明为 **int**（不是 String），所以这里传 int ——
  /// 传字符串会报 argument_type_not_assignable（issue #22 这轮踩过一次同类坑）。
  String _ago(BuildContext context, DateTime t) {
    final s = S.of(context);
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return s.timeJustNow;
    if (d.inMinutes < 60) return s.minutesAgo(d.inMinutes);
    if (d.inHours < 24) return s.hoursAgo(d.inHours);
    return s.daysAgo(d.inDays);
  }
}
