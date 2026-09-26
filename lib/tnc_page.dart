import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_widgets.dart';
import 'garmin_page.dart';
import 'hr_page.dart';
import 'platform_caps.dart';
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
          disabled: !tncPlatformSupported,
          disabledReason: s.iosFeatureUnsupported,
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
          disabled: !tncPlatformSupported,
          disabledReason: s.iosFeatureUnsupported,
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
        // 位置来源**不是二选一**（佳明直播时优先用手表，超过 120s 没新点自动交回
        // 手机 GPS），所以这里**不画选中圆点**，只如实显示「现在是谁在供位置」。
        // 曾经画成单选，出现两个不诚实的表现（用户实测指出）：
        //   * 未启动定位时「手机 GPS」也显示已选中 —— 其实什么都没在跑；
        //   * 佳明那行可以「选中」，哪怕应用根本没在追踪。
        _ownLabel(context, s.posSourceLabel),
        // 手机 GPS：只有在真的在追踪、且佳明**没有**在供位置时才算「在用」。
        // `loc.running` 是定位服务是否在跑（用户没启动追踪时它是 false）。
        _statusRow(
          context,
          icon: Icons.smartphone_rounded,
          title: s.ownSourcePhoneGps,
          desc: !state.loc.running
              ? s.posSourceIdle
              : (state.garminOn ? s.ownSourceGarminLive : s.garminRunning),
          live: state.loc.running,
        ),
        _ownTile(
          context,
          icon: Icons.watch_rounded,
          title: s.garminCardTitle,
          // 三种如实状态：链接有效且有点 / 链接有效但没点 / 还没配
          desc: !state.garminOn
              ? (state.garminUrl.isEmpty
                  ? s.garminCardSubtitle
                  : s.ownSourceGarminStale)
              : s.garminRunning,
          active: state.garminOn && state.garmin.fresh,
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
          // 已连接时把**当前心率**也显示出来（用户要「主屏能看到心率」，
          // 设置页这一行顺便也能看到，接没接上、有没有读数一目了然）。
          desc: state.bleHr.connected
              ? (state.bleHr.bpm == null
                  ? s.hrConnected(state.bleHr.deviceName ?? '--')
                  : '${s.hrConnected(state.bleHr.deviceName ?? '--')} · '
                      '${s.hrLineHr('${state.bleHr.bpm} bpm')}')
              // 没插胸带但佳明在供数据 → 如实说「心率来自佳明 LiveTrack」，
              // 而不是显示「未连接（点一下连接心率带）」让人以为缺东西。
              : (state.garminOn && state.garmin.fresh
                  ? (state.myHr == null
                      ? s.hrFromGarmin
                      : '${s.hrFromGarmin} · ${s.hrLineHr('${state.myHr} bpm')}')
                  : s.ownSourceHrIdle),
          active: (state.bleHr.connected && state.bleHr.bpm != null) ||
              (state.garminOn && state.garmin.fresh && state.myHr != null),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => HrDevicePage(state: state))),
          disabled: !bleHrPlatformSupported,
          disabledReason: s.hrNotSupported,
        ),
        // 多选时才需要解释「发射走哪条」，单选时这句话是噪音
        // 位置来源的**优先级**（与上报页同一句文案、同一个 getter）：两处都写清楚，
        // 用户才不会觉得「两个地方各说一个来源、不知道听谁的」。
        SettingsHint(s.posSourcePrecedence, color: C.slate),
        if (state.multiSource) SettingsHint(s.dataSourceTxHint),
        if (state.multiSource) SettingsHint(s.dataSourceIgateHint),
        // PKWDWPL 是只读的，这句必须常驻：否则用户会奇怪为何它没有发射圆点
        if (state.pkwdwplOn) SettingsHint(s.dataSourcePkwdwplHint),
        if (extra != null) SettingsHint(extra!),
      ],
    );
  }

  /// **只读状态行**：用于「位置来源」——它不是用户二选一的开关，而是「现在谁在供位
  /// 置」。所以**不画选中圆点**（画了就是在暗示「这是你选的」，而实际上应用是自动让位的）。
  /// 只有一个小圆点表示「在跑 / 没在跑」，避免未启动追踪时看着像已经选好了。
  Widget _statusRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
    required bool live,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: live ? C.green : C.grey),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: ts(12.5, c: live ? C.ink : C.slate, w: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(desc,
                  style: ts(10.5, c: C.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        // 状态点：绿=在供位置；灰=没在跑
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: live ? C.green : C.greyLight,
          ),
        ),
      ]),
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
    bool disabled = false,
    String? disabledReason,
  }) {
    // 平台不支持：置灰、不可点，副标题换成原因（与 _tile 同一套观感）
    final sub = disabled ? (disabledReason ?? desc) : desc;
    return ClickCursor(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
          ),
          child: Row(children: [
            Icon(icon,
                size: 16,
                color: disabled ? C.greyLight : (active ? C.red : C.grey)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: ts(12.5,
                          c: disabled
                              ? C.greyLight
                              : (active ? C.ink : C.slate),
                          w: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Text(sub,
                      style: ts(10.5, c: disabled ? C.orange : C.grey),
                      maxLines: disabled ? 2 : 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(
                disabled
                    ? Icons.lock_outline
                    : (active
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off),
                size: 16,
                color: disabled
                    ? C.greyLight
                    : (active ? C.red : C.greyLight)),
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
    bool disabled = false,
    String? disabledReason,
  }) {
    final s = S.of(context);
    final enabled = state.enabledSources.contains(key);
    final up = state.isUp(key);
    // 只读来源（PKWDWPL）永远不是发射来源，圆点也不显示 ——
    // 否则用户会以为「选上它就能发」。
    final isTx = canTx && state.dataSource == key;
    // 最后一条不允许取消勾选：全关掉应用就什么都不收，而界面没有任何提示
    final canToggleOff = state.enabledSources.length > 1 || !enabled;
    // 平台不支持：整行置灰、不可点，副标题换成「为什么不可用」——
    // 让用户一眼看出不是坏了，而是本平台根本没有这条链路。
    final sub = disabled ? (disabledReason ?? desc) : desc;
    return InkWell(
      onTap: disabled ? null : () => state.toggleSource(key, !enabled),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: disabled
              ? Colors.transparent
              : (enabled
                  ? C.blue.withValues(alpha: 0.04)
                  : Colors.transparent),
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(children: [
          // 勾选状态：这是「是否启用这条链路」，不是「选中它去发射」
          Icon(
            disabled
                ? Icons.block
                : (enabled
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded),
            size: 19,
            color: disabled
                ? C.greyLight
                : (enabled ? C.blue : C.greyLight),
          ),
          const SizedBox(width: 10),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: disabled
                  ? C.greyBg
                  : (enabled ? C.blue.withValues(alpha: 0.12) : C.greyBg),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                size: 17,
                color: disabled ? C.greyLight : (enabled ? C.blue : C.grey)),
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
                            c: disabled
                                ? C.greyLight
                                : (enabled ? C.blue : C.grey)),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (!disabled && enabled) ...[
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
                Text(sub,
                    style: ts(11, c: disabled ? C.orange : C.grey),
                    maxLines: disabled ? 2 : 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // 平台不支持：用一把锁替代发射标记，明确「本平台不可用」
          if (disabled)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.lock_outline,
                  size: 16, color: C.greyLight),
            )
          // 发射来源标记：只有启用的**可发射**链路才有资格
          else if (enabled && canTx)
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
