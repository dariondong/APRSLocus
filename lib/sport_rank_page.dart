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
class SportRankPage extends StatefulWidget {
  final AppState state;
  const SportRankPage({super.key, required this.state});

  @override
  State<SportRankPage> createState() => _SportRankPageState();
}

class _SportRankPageState extends State<SportRankPage> {
  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = state;

    // ── 门票：自己不开「随信标发步数」，就看不到榜单（用户要求）──
    //
    // 这不是「小气」，而是这份数据唯一的来源决定的：榜单上每一个数字都是**别人
    // 主动发出来的**。只读不发的人拿得到别人的位置，却不贡献自己那一份 ——
    // 长期看就是「榜上永远是那几个在发的人」。所以改成互相可见：
    // 你开了上传，才看得到别人上传的。
    //
    // ⚠ 注意这里**只挡榜单**，不挡页面本身：口径说明、自己的今日步数、授权按钮
    // 都要照常显示 —— 否则新用户进门就是一句「看不到」，连怎么开都不知道。
    if (!st.beaconIncludeSteps) {
      return SettingsPageShell(
        title: s.sportRank,
        subtitle: s.sportRankDesc,
        icon: Icons.leaderboard_rounded,
        color: C.green,
        body: Column(children: [
          _gateCard(context, st),
          const SizedBox(height: 16),
          _meCard(context, st),
          const SizedBox(height: 24),
        ]),
      );
    }

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

  /// 门票卡：说清「为什么必须先自己开」，并给一个一键开启。
  ///
  /// 三个要素缺一不可：
  ///   * **原因**（榜单上的数字都来自别人主动发出的报文）；
  ///   * **一键开启**（不要只留一句「请先去设置里打开」—— 让用户自己回去翻三层菜单）；
  ///   * **开启后我会发出什么**（`STEPS=今天步数`，与 TRV/ODO 同类的非标准字段）——
  ///     分享自己的数据这件事必须由用户看清了再点，不能含糊过去。
  Widget _gateCard(BuildContext context, AppState st) {
    final s = S.of(context);
    return SettingsSectionCard(
      title: s.sportRankGateTitle,
      subtitle: s.sportRankGateSubtitle,
      icon: Icons.lock_outline_rounded,
      color: C.orange,
      children: [
        SettingsHint(s.sportRankGateBody, color: C.orange),
        SettingsHint(s.sportRankGateWhatSent, color: C.grey),
        if (!st.hasStepSensor)
          SettingsHint(s.stepsUnsupported, color: C.grey)
        else if (st.stepsRaw < 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final ok = await st.requestStepsPermission();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? s.stepsGranted : s.stepsDenied),
                    behavior: SnackBarBehavior.floating,
                  ));
                  setState(() {});
                },
                icon: const Icon(Icons.directions_walk_rounded, size: 16),
                label: Text(s.stepsGrant),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.orange,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: ts(12, w: FontWeight.w600),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: () => setState(() => st.setBeaconIncludeSteps(true)),
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: Text(s.sportRankGateEnable),
              style: FilledButton.styleFrom(
                backgroundColor: C.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
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
            value: st.beaconIncludeSteps,
            // 用 setState 包一层：打开后本页立刻放行（否则要退出去再进来）
            onChanged: (v) =>
                setState(() => st.setBeaconIncludeSteps(v))),
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
