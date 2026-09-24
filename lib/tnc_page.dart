import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_widgets.dart';
import 'garmin_page.dart';
import 'hr_page.dart';
import 'state.dart';
import 'theme.dart';
import 'tnc.dart';
import 'widgets.dart';

/// ─── TNC 页的**共享组件** ───
///
/// 页面本体已拆分（设备页重构，v1.6.105）：
///   * 概览（数据来源 + 当前链路 + 自检 + 入口）→ lib/device_page.dart
///   * TNC 设备与参数（绑定 / 初始化串 / KISS 参数 / 射频行为 / 发射自检）
///     → lib/tnc_device_page.dart
///   * 音频 → lib/audio_page.dart
///
/// 本文件只留两块被多处复用的东西：
///   ① `DataSourceCard`：连接页与设备页都要能切来源，各写一份必然不一致
///   ② `copyTncLog`：调试用的日志复制助手
/// 数据来源选择卡片（连接页 / 设备页 / 音频页共用）
///
/// 做成公共组件的原因：同一个设置在三个入口都要能改 —— 各写一份迟早出现
/// 文案与行为不一致。
///
/// **多选**：每条来源是一个可勾选的链路，可以同时开几条（例如
/// 「APRS-IS + TNC」就是网关的典型配置：射频收、互联网转发）。
/// 但**发射只有一条**（[AppState.dataSource]）：同一个呼号从两条链路发出去
/// 会造成重复报文，射频上还白占一次时隙；所以多选时额外提供「发射」标记，
/// 由用户指定（默认沿用原来的来源）。
class DataSourceCard extends StatelessWidget {
  final AppState state;
  final String? extra;
  const DataSourceCard({super.key, required this.state, this.extra});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SettingsSectionCard(
      title: s.dataSourceTitle,
      subtitle: s.dataSourceSubtitle,
      icon: Icons.swap_horiz_rounded,
      color: C.blue,
      children: [
        _tile(
          context,
          key: AppState.srcAprsIs,
          title: s.dataSourceAprsIs,
          desc: s.dataSourceAprsIsDesc,
          icon: Icons.cloud_rounded,
        ),
        _tile(
          context,
          key: AppState.srcTnc,
          title: s.dataSourceTnc,
          desc: s.dataSourceTncDesc,
          icon: Icons.settings_input_antenna_rounded,
        ),
        // PKWDWPL（Kenwood 航点语句）与 TNC 并列：同一根线缆/蓝牙，
        // 但线上是 NMEA 明文行、而且**只收不发**（canTx: false）
        _tile(
          context,
          key: AppState.srcPkwdwpl,
          title: s.dataSourcePkwdwpl,
          desc: s.dataSourcePkwdwplDesc,
          icon: Icons.route_rounded,
          canTx: false,
        ),
        _tile(
          context,
          key: AppState.srcAudio,
          title: s.dataSourceAudio,
          desc: s.dataSourceAudioDesc,
          icon: Icons.graphic_eq_rounded,
        ),
        // ── 位置来源 / 心率来源（用户要求：佳明应当作为「数据来源」的一种选择）──
        //
        // 与上面那些**报文链路**分开列：那几条的语义是「报文从哪条链路收发」，
        // 而这两条是「**我自己的位置/心率**从哪来」。混成一组会让「发射来源」
        // 的判定变乱 —— 但用户找「数据来源」时就该在这一张卡里看到它们。
        _ownLabel(context, s.posSourceLabel),
        _ownTile(
          context,
          icon: Icons.smartphone_rounded,
          title: s.ownSourcePhoneGps,
          desc: s.hrForTncNote == '' ? '' : s.dataSourceSubtitle,
          active: !state.garminOn,
          onTap: () {
            if (state.garminOn) state.setGarminOn(false);
          },
        ),
        _ownTile(
          context,
          icon: Icons.watch_rounded,
          title: s.garminCardTitle,
          desc: state.garminOn ? s.garminRunning : s.garminCardSubtitle,
          active: state.garminOn,
          onTap: () {
            // 没配过链接 → 直接进设置页（用户在那里粘贴/分享）
            if (!state.garminOn && state.garminUrl.isEmpty) {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => GarminTrackPage(state: state)));
            } else {
              state.setGarminOn(!state.garminOn);
            }
          },
        ),
        _ownLabel(context, s.hrSourceLabel),
        _ownTile(
          context,
          icon: Icons.favorite_rounded,
          title: s.hrCardTitle,
          desc: state.bleHr.connected
              ? s.hrConnected(state.bleHr.deviceName ?? '--')
              : s.hrCardSubtitle,
          active: state.bleHr.connected,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => HrDevicePage(state: state))),
        ),
        // 多选时才需要解释「发射走哪条」，单选时这句话是噪音
        if (state.multiSource) SettingsHint(s.dataSourceTxHint),
        if (state.multiSource) SettingsHint(s.dataSourceIgateHint),
        // PKWDWPL 是只读的，这句必须常驻：否则用户会奇怪为何它没有发射圆点
        if (state.pkwdwplOn) SettingsHint(s.dataSourcePkwdwplHint),
        if (extra != null) SettingsHint(extra!),
      ],
    );
  }

  /// 小组标题（位置来源 / 心率来源）
  Widget _ownLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(children: [
        Container(
          width: 3,
          height: 10,
          decoration: BoxDecoration(
            color: C.red,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: ts(11, c: C.red, w: FontWeight.w700)),
      ]),
    );
  }

  /// 「自己位置/心率」的来源项：与报文链路不同 —— 它不是开关式的多选，
  /// 而是**选中**（左侧圆点表示当前生效的那一个）。
  Widget _ownTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
    required bool active,
    required VoidCallback onTap,
  }) {
    return ClickCursor(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: active ? C.red : C.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: ts(12.5,
                          c: active ? C.ink : C.slate, w: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Text(desc,
                      style: ts(10.5, c: C.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(active ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 16, color: active ? C.red : C.greyLight),
          ]),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required String key,
    required String title,
    required String desc,
    required IconData icon,
    bool canTx = true,
  }) {
    final s = S.of(context);
    final enabled = state.enabledSources.contains(key);
    final up = state.isUp(key);
    // 只读来源（PKWDWPL）永远不是发射来源，圆点也不显示 ——
    // 否则用户会以为「选上它就能发」。
    final isTx = canTx && state.dataSource == key;
    // 最后一条不允许取消勾选：全关掉应用就什么都不收，而界面没有任何提示
    final canToggleOff = state.enabledSources.length > 1 || !enabled;
    return InkWell(
      onTap: () => state.toggleSource(key, !enabled),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? C.blue.withValues(alpha: 0.04) : Colors.transparent,
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(children: [
          // 勾选状态：这是「是否启用这条链路」，不是「选中它去发射」
          Icon(
            enabled
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            size: 19,
            color: enabled ? C.blue : C.greyLight,
          ),
          const SizedBox(width: 10),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: enabled ? C.blue.withValues(alpha: 0.12) : C.greyBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 17, color: enabled ? C.blue : C.grey),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(title,
                        style: ts(13,
                            w: FontWeight.w700,
                            c: enabled ? C.blue : C.grey),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (enabled) ...[
                    const SizedBox(width: 6),
                    // 每条链路的真实连通状态：多选时这是最需要一眼看到的信息
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: up ? C.green : C.greyLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(up ? s.connected : s.disconnected,
                        style: ts(10, c: up ? C.green : C.grey)),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(desc, style: ts(11, c: C.grey)),
              ],
            ),
          ),
          // 发射来源标记：只有启用的**可发射**链路才有资格
          if (enabled && canTx)
            GestureDetector(
              onTap: isTx ? null : () => state.setTxSource(key),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTx
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: isTx ? C.orange : C.greyLight,
                    ),
                    if (isTx)
                      Text(s.dataSourceTxBadge,
                          style: ts(9, c: C.orange, w: FontWeight.w700)),
                    if (!isTx && !canToggleOff)
                      const SizedBox(height: 0),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
