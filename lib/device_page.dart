import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio_page.dart';
import 'link_test_card.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'tnc_device_page.dart';
import 'tnc_page.dart';
import 'widgets.dart';

/// ─── 设备页（概览）：数据来源 + 网关 + 链路状态 + 子页入口 ───
///
/// 页面组织原则：**按「使用者此刻要回答的问题」排序，高级内容折叠**。
///
///   ① 我现在用哪些来源？        → 数据来源（多选）
///   ② 我要不要当网关？          → 网关
///   ③ 现在通不通？             → 链路（每来源一行）
///   ④ 要改参数 / 排查 → 子页    → TNC 设备与参数 / 音频
///   ⑤ 出问题了要证据            → 链路自检、日志（**折叠**）
///
/// 上一版把这些平铺在一页里，其中「自检结果」与「日志」两块**很高又不常看**，
/// 于是最常看的「通不通」被顶到需要滚动才能看到 —— 这就是「还是有点乱」的
/// 来源。折叠后默认一屏内能看到 ①②③ 与两个入口。
class DeviceOverviewPage extends StatefulWidget {
  final AppState state;
  const DeviceOverviewPage({super.key, required this.state});

  @override
  State<DeviceOverviewPage> createState() => _DeviceOverviewPageState();
}

class _DeviceOverviewPageState extends State<DeviceOverviewPage> {
  bool _testOpen = false;
  bool _logOpen = false;

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => SettingsPageShell(
        title: s.deviceOverviewTitle,
        subtitle: s.deviceOverviewSubtitle,
        icon: Icons.devices_other_rounded,
        color: C.indigo,
        body: Column(children: [
          // ① 数据来源（多选 + 发射来源）
          DataSourceCard(
            state: state,
            extra: s.dataSourceSwitchHint,
          ),
          const SizedBox(height: 16),
          // ② 网关
          _igateCard(context, s),
          const SizedBox(height: 16),
          // ③ 每条链路的状态（只读结论，避免在概览页误改参数）
          _linksCard(context, s),
          const SizedBox(height: 16),
          // ④ 子页入口
          _entriesCard(context, s),
          const SizedBox(height: 16),
          // ⑤ 自检（折叠：结果很长，但排查时最有用）
          SettingsFold(
            title: s.diagTitle,
            subtitle: s.diagSubtitle,
            icon: Icons.health_and_safety_rounded,
            color: C.cyan,
            open: _testOpen,
            onToggle: () => setState(() => _testOpen = !_testOpen),
            children: [
              LinkTestCard(
                state: state,
                source: state.audioOn && !state.tncOn
                    ? LinkTestSource.audio
                    : LinkTestSource.tnc,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ⑥ 日志（折叠：平时不需要看，出问题才展开）
          SettingsFold(
            title: s.deviceLogTitle,
            subtitle: s.deviceLogDesc,
            icon: Icons.receipt_long_rounded,
            color: C.slate,
            open: _logOpen,
            onToggle: () => setState(() => _logOpen = !_logOpen),
            children: [_logBody(context, s)],
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  /// ② 网关（iGate）
  Widget _igateCard(BuildContext context, S s) {
    return SettingsSectionCard(
      title: s.igateTitle,
      subtitle: s.igateSubtitle,
      icon: Icons.hub_rounded,
      color: C.purple,
      children: [
        SettingsSwitch(
          s.igateEnable,
          value: state.igateEnabled,
          color: C.purple,
          onChanged: state.setIgateEnabled,
        ),
        SettingsHint(s.igateHint),
        // 启用前置条件没满足时**明确说缺什么**，而不是静默不工作
        if (state.igateEnabled && !state.igateReady)
          SettingsHint(s.igateNeedRf, color: C.orange),
        if (state.igateEnabled && !state.aprsIsOn)
          SettingsHint(s.igateNeedIs, color: C.orange),
        if (state.igateEnabled) ...[
          SettingsSwitch(
            s.igateTwoWay,
            value: state.igateTwoWay,
            color: C.orange,
            onChanged: state.setIgateTwoWay,
          ),
          SettingsHint(s.igateTwoWayHint, color: C.orange),
          SettingsRow2(s.igateStatToIs, '${state.igateGated}',
              valueColor: state.igateGated > 0 ? C.green : C.grey),
          SettingsRow2(
            s.igateStatToRf,
            '${state.igateToRf}',
            valueColor: state.igateToRf > 0 ? C.green : C.grey,
          ),
          SettingsRow2(s.igateStatDup, '${state.igateDupDropped}'),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(children: [
              TextButton.icon(
                onPressed: state.resetIgateStats,
                icon: const Icon(Icons.restart_alt_rounded, size: 15),
                label: Text(s.igateResetStats, style: ts(12)),
                style: TextButton.styleFrom(foregroundColor: C.grey),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  /// ③ 链路状态：每一行就是一条链路，不会混淆
  Widget _linksCard(BuildContext context, S s) {
    final rows = <Widget>[];
    for (final src in [AppState.srcAprsIs, AppState.srcTnc, AppState.srcAudio]) {
      if (!state.enabledSources.contains(src)) continue;
      final up = state.isUp(src);
      final isTx = state.dataSource == src;
      final name = src == AppState.srcAprsIs
          ? s.dataSourceAprsIs
          : (src == AppState.srcTnc ? s.dataSourceTnc : s.dataSourceAudio);
      final detail = switch (src) {
        AppState.srcAprsIs => '${state.aprs.server}:${state.aprs.port}',
        AppState.srcTnc => state.tnc.device?.label ?? s.tncNotBound,
        _ => '${state.audio.config.afsk.sampleRate} Hz · ${state.audio.backendName}',
      };
      final stats = switch (src) {
        AppState.srcAprsIs => s.notifRx('${state.packetsRx}'),
        AppState.srcTnc => s.tncStats(
            '${state.tnc.rxFrames}', '${state.tnc.txFrames}'),
        _ => s.tncStats(
            '${state.audio.rxFrames}', '${state.audio.txFrames}'),
      };
      rows.add(SettingsRow2(
        '$name${isTx ? ' · ${s.dataSourceTxBadge}' : ''}',
        '$detail  ${up ? '· ${stats}' : ''}',
        valueColor: up ? C.green : C.slate,
      ));
    }
    // 「会不会真的发射」是射频来源最关键的一条
    if (state.usingRf) {
      rows.add(SettingsRow2(
        s.kissRfBeacon,
        state.rfBeaconEnabled ? s.tncSwitchOn : s.tncSwitchOff,
        valueColor: state.rfBeaconEnabled ? C.green : C.grey,
      ));
    }
    return SettingsSectionCard(
      title: s.deviceCurrentLink,
      subtitle: s.deviceCurrentLinkDesc,
      icon: Icons.sensors_rounded,
      color: C.green,
      children: rows,
    );
  }

  /// ④ 子页入口
  Widget _entriesCard(BuildContext context, S s) {
    return SettingsSectionCard(
      title: s.deviceEntries,
      subtitle: s.deviceEntriesDesc,
      icon: Icons.tune_rounded,
      color: C.cyan,
      children: [
        _entry(
          context,
          icon: Icons.bluetooth_rounded,
          color: C.indigo,
          title: s.tncDeviceTitle,
          desc: s.tncDeviceDesc,
          page: TncDevicePage(state: state),
        ),
        _entry(
          context,
          icon: Icons.graphic_eq_rounded,
          color: C.cyan,
          title: s.audioSettings,
          desc: s.audioSettingsSubtitle,
          page: AudioSettingsPage(state: state),
        ),
      ],
    );
  }

  Widget _entry(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required Widget page,
  }) {
    return InkWell(
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ts(13, w: FontWeight.w700, c: C.ink)),
                const SizedBox(height: 2),
                Text(desc, style: ts(11, c: C.grey)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: C.greyLight),
        ]),
      ),
    );
  }

  /// ⑥ 日志正文（TNC / 音频 / APRS-IS 三段，按当前启用的来源显示）
  Widget _logBody(BuildContext context, S s) {
    // 多选时可能同时在用两条链路，日志必须能分开看 —— 混在一起会把
    // 「收不到」的排查彻底变成猜谜
    // 两类日志的形态不同：AppState 是结构化 LogEntry（便于筛选/本地化级别），
    // 链路层是纯文本（原生侧只给字符串）。这里统一转成可显示的行。
    final sections = <(String, List<String>)>[];
    if (state.aprsIsOn) {
      sections.add((
        s.dataSourceAprsIs,
        state.logs.map((e) => '${e.source} ${e.message}').toList(),
      ));
    }
    if (state.tncOn) sections.add((s.dataSourceTnc, state.tnc.logs));
    if (state.audioOn) sections.add((s.dataSourceAudio, state.audio.logs));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, logs) in sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(children: [
              Text(name, style: ts(11, c: C.slate, w: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: logs.join('\n'))),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: Text(s.copyAllLogs, style: ts(11)),
                style: TextButton.styleFrom(
                  foregroundColor: C.slate,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 30),
                ),
              ),
            ]),
          ),
          if (logs.isEmpty)
            SettingsHint(s.tncLogEmpty)
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in logs.take(20))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        l,
                        style: ts(10, c: C.slate, h: 1.35)
                            .copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
