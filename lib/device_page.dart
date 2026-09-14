import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio_page.dart';
import 'link_test_card.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'tnc_page.dart';
import 'tnc_device_page.dart';
import 'widgets.dart';

/// ─── 设备页（概览）：数据来源 + 当前链路状态 + 自检 + 子页入口 ───
///
/// 为什么拆：原来一个页面里堆了数据来源、TNC 绑定、9 项 KISS 参数、射频行为、
/// 链路自检、音频入口、链路日志 —— 用户最常做的事（看当前链路通不通）要划过
/// 一屏参数才能看到，而调参时又要来回滚。现在按「使用者的问题」分层：
///
///   * 本页 **概览** —— 「我现在用哪个来源、通不通、自检过不过」（只看结论）
///   * `TncDevicePage` **TNC 设备与参数** —— 「设备要不要重连、参数怎么改」
///   * `AudioSettingsPage` **音频** —— 声卡链路的参数与文件模式
class DeviceOverviewPage extends StatelessWidget {
  final AppState state;
  const DeviceOverviewPage({super.key, required this.state});

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
          // ① 数据来源：三选一，切了就断链（与连接页共用同一张卡片）
          DataSourceCard(state: state, extra: s.dataSourceSwitchHint),
          const SizedBox(height: 16),
          // ② 当前来源状态：只读结论，避免在概览页误改参数
          _statusCard(context, s),
          const SizedBox(height: 16),
          // ③ 两个链路的入口
          _entriesCard(context, s),
          const SizedBox(height: 16),
          // ④ 自检：按当前来源换检查项（协议回路不接电台也能跑）
          LinkTestCard(
            state: state,
            source: state.usingAudio
                ? LinkTestSource.audio
                : LinkTestSource.tnc,
          ),
          const SizedBox(height: 16),
          _logCard(context, s),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  /// ② 当前来源的关键状态（TNC / 音频各自的指标，不混在一起显示）
  Widget _statusCard(BuildContext context, S s) {
    final rows = <Widget>[];
    if (state.usingAudio) {
      final a = state.audio;
      rows.addAll([
        SettingsRow2(s.connection,
            a.connected ? s.connected : s.disconnected,
            valueColor: a.connected ? C.green : C.slate),
        SettingsRow2(s.audioBackend, a.backendName),
        SettingsRow2(s.audioSampleRate, '${a.config.afsk.sampleRate} Hz'),
        SettingsRow2(
            s.audioStatsTitle, s.audioStatRx(a.rxFrames)),
        SettingsRow2('', s.audioStatTx(a.txFrames)),
      ]);
    } else if (state.usingTnc) {
      final t = state.tnc;
      rows.addAll([
        SettingsRow2(s.connection,
            t.connected ? s.connected : s.disconnected,
            valueColor: t.connected ? C.green : C.slate),
        SettingsRow2(s.tncBoundDevice, t.device?.label ?? s.tncNotBound,
            valueColor: t.device == null ? C.grey : C.ink),
        SettingsRow2(s.tncStats('${t.rxFrames}', '${t.txFrames}'), ''),
      ]);
    } else {
      rows.addAll([
        SettingsRow2(s.connection,
            state.connected ? s.connected : s.disconnected,
            valueColor: state.connected ? C.green : C.slate),
        SettingsRow2(s.server,
            '${state.aprs.server}:${state.aprs.port}'),
        SettingsRow2(s.callsign, state.myFullCall),
      ]);
    }
    // 「会不会真的发射」是射频来源最关键的一条，概览页必须能看到
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
      color: C.blue,
      children: rows,
    );
  }

  /// ③ 子页入口
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
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => page)),
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

  /// ④ 链路日志：显示**当前来源**的日志。
  ///
  /// 之前设备页只显示 TNC 日志，音频模式下用户看不到任何链路日志 ——
  /// 「音频收不到」时无从排查。现在按来源自动切换。
  Widget _logCard(BuildContext context, S s) {
    final logs = state.usingAudio ? state.audio.logs : state.tnc.logs;
    return SettingsSectionCard(
      title: s.deviceLogTitle,
      subtitle: s.deviceLogDesc,
      icon: Icons.receipt_long_rounded,
      color: C.slate,
      children: [
        if (logs.isEmpty)
          SettingsHint(s.tncLogEmpty)
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(children: [
              TextButton.icon(
                onPressed: () => Clipboard.setData(
                    ClipboardData(text: logs.join('\n'))),
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: Text(s.copyAllLogs, style: ts(12)),
                style: TextButton.styleFrom(foregroundColor: C.slate),
              ),
            ]),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in logs.take(30))
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
