import 'package:flutter/material.dart';

import 'settings_widgets.dart';
import 'acn_link_page.dart';
import 'aprs_is_cards.dart';
import 'audio_page.dart';
import 'ext_gps_device_page.dart';
import 'garmin_page.dart';
import 'hr_page.dart';
import 'ic705_device_page.dart';
import 'pkwdwpl_device_page.dart';
import 'models.dart';
import 'platform_caps.dart';
import 'station_detail.dart';
import 'ssid_remote.dart';
import 'state.dart';
import 'theme.dart';
import 'tnc_device_page.dart';
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
/// 弹出「链路方式」浮动面板：数据来源的快捷切换。
///
/// 设置主页的「连接状态」面板点一下就调它 —— 换链路是高频动作（APRS-IS / 蓝牙 TNC /
/// 声卡音频 / 盒子之间切），原来得先进「连接」分类、进设备页、再滚到数据来源卡片。
/// 面板里直接用**同一张** [DataSourceCard]，所以两处永远不会说两套话。
Future<void> showLinkSheet(BuildContext context, AppState state) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.pageFill,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _LinkSheet(state: state),
  );
}

class _LinkSheet extends StatelessWidget {
  final AppState state;
  const _LinkSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // 面板里的勾选与连接状态都在变，而它不在调用方的重建树里 —— 自己听 state。
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 抓手：明确"这是一块能下拉关掉的面板"
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: C.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                DataSourceCard(state: state, extra: s.dataSourceSwitchHint),
                const SizedBox(height: 10),
                Text(s.tapAnywhereClose, style: ts(11, c: C.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
        // 两条「互联网链路」并排：APRS-IS 与 APRSNETCN SERVER。它们都是
        // 一条 TCP 登录（地址 + 端口 + passcode），都与电台无关，所以归在同一组；
        // 往下的 TNC / WLAN 电台 / 音频走的是自己的硬件，另起一组。
        _ownLabel(context, s.sourceGroupInternet),
        _tile(
          context,
          key: AppState.srcAprsIs,
          title: s.dataSourceAprsIs,
          desc: s.dataSourceAprsIsDesc,
          icon: Icons.cloud_rounded,
          // 与下面 APRSNETCN 那一行同一个口径：点整行进它自己的设置页。
          // 少了这一句，整行看着能点、点下去什么都不发生。
          onConfigure: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AprsIsServerPage(state: state)),
          ),
        ),
        // 第二条链路只有裸 TCP，Web 上没有（与连接设置卡同一个口径）
        if (tcpLinkPlatformSupported)
          _tile(
            context,
            key: AppState.srcAcn,
            title: s.acnCardTitle,
            desc: s.acnCardSubtitle,
            icon: Icons.hub_rounded,
            enabled: state.acnOn,
            up: state.acnConnected,
            onToggle: (on) => state.setAcnOn(on),
            onConfigure: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AcnLinkPage(state: state)),
            ),
          ),
        _ownLabel(context, s.sourceGroupRadio),
        _tile(
          context,
          key: AppState.srcTnc,
          title: s.dataSourceTnc,
          desc: s.dataSourceTncDesc,
          icon: Icons.settings_input_antenna_rounded,
          disabled: !tncPlatformSupported,
          disabledReason: s.iosFeatureUnsupported,
          onConfigure: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TncDevicePage(state: state)),
          ),
        ),
        _tile(
          context,
          key: 'icomlan',
          title: 'WLAN 电台（${state.audio.config.icomLan.model.id}）',
          desc: state.audio.config.icomLan.host.isNotEmpty
              ? '${state.audio.config.icomLan.model.displayName} · ${state.audio.config.icomLan.host}:${state.audio.config.icomLan.controlPort}'
              : '局域网直连 Icom 电台（IC-705 / IC-9700 / IC-7610 / IC-905）',
          icon: Icons.wifi_tethering_rounded,
          enabled: state.icomLanOn,
          isTx: state.isIcomLanTx,
          isTxMsg: state.isIcomLanTxMsg,
          up: state.icomLanOn && state.isUp(AppState.srcAudio),
          onToggle: (on) => state.toggleIcomLan(on),
          onSetTx: () => state.setTxIcomLan(),
          onSetTxMsg: () => state.setTxIcomLan(forMsg: true),
          onConfigure: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => Ic705DevicePage(state: state)),
          ),
        ),
        _tile(
          context,
          key: AppState.srcAudio,
          title: s.dataSourceAudio,
          desc: s.dataSourceAudioDesc,
          icon: Icons.graphic_eq_rounded,
          enabled: state.audioDeviceOn,
          isTx: state.isAudioDeviceTx,
          isTxMsg: state.isAudioDeviceTxMsg,
          up: state.audioDeviceOn && state.isUp(AppState.srcAudio),
          onToggle: (on) => state.toggleAudioDevice(on),
          onSetTx: () => state.setTxAudioDevice(),
          onSetTxMsg: () => state.setTxAudioDevice(forMsg: true),
          onConfigure: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AudioSettingsPage(state: state)),
          ),
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
          onConfigure: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PkwdwplDevicePage(state: state)),
          ),
        ),
        // 「高级连接通道设置」：默认关 —— 关着时位置与状态报文发往所有
        // 已启用且连上的可发射链路（见 posTxTargets），不再逐条打勾；
        // 消息仍按上一次勾的那一条发。打开后每行右侧才出现位置那颗圆点。
        SettingsSwitch(
          s.advChannels,
          value: state.advChannels,
          color: C.blue,
          onChanged: state.setAdvChannels,
        ),
        // ── 位置来源 / 心率来源（用户要求：佳明应当作为「数据来源」的一种选择）──
        //
        // 与上面那些**报文链路**分开列：那几条的语义是「报文从哪条链路收发」，
        // 而这几条是「**我自己的位置/心率**从哪来」。混成一组会让「发射来源」
        // 的判定变乱 —— 但用户找「数据来源」时就该在这一张卡里看到它们。
        //
        // 外接 GPS 模块也归在这一组（它原先排在上面报文链路的末尾）：用户看到
        // 它顶着「报文从哪里来」那个副标题写「本机位置来源」，一眼就问「这个位置对吗」。
        // 它需要的「扫设备 / 绑定 / 连接 / 日志」仍在设备页那一份入口里
        // （设置 → 设备 → 外接 GPS 子页），这里只管「现在是不是它在供位」。
        //
        // 手机 GPS 是**状态行**（`_statusRow`，不画圆点）：它不是用户选的，而是自动兜底，
        // 未启动定位时也显示成已选中过（用户实测指出）。佳明与外接模块都是**用户显式
        // 开启的一条源**，用 `_ownTile`：圆点只表示「现在生效的是它」——位置本身是自动
        // 让位的（佳明直播时优先用手表、超过 120s 没新点交回手机 GPS；模块断流 30s 同理）。
        _ownLabel(context, s.posSourceLabel),
        // 手机 GPS：只有在真的在追踪、且佳明**没有**在供位置时才算「在用」。
        // `loc.running` 是定位服务是否在跑（用户没启动追踪时它是 false）。
        _statusRow(
          context,
          icon: Icons.smartphone_rounded,
          title: s.ownSourcePhoneGps,
          // 供位的是外接模块时必须先说出来（此时手机定位多半已待机，
          // 写「未启动」会让人以为定位坏了）。
          desc: state.nmeaGpsSupplying
              ? s.ownSourceExtGpsLive
              : (!state.loc.running
                  ? s.posSourceIdle
                  : (state.garminOn
                      ? s.ownSourceGarminLive
                      : s.garminRunning)),
          live: state.loc.running,
        ),
        // 外接 GPS 模块：比佳明更靠前（`sim > spp > garmin > phone`，见
        // AppState.positionSourceNow），所以排在这一组里、佳明之前。
        _ownTile(
          context,
          icon: Icons.gps_fixed_rounded,
          title: s.dataSourceNmeaGps,
          // 四种如实状态：在供位（报收到的定位条数，与心率行报 bpm 同一个用意）/
          // 已连上但还没定上 / 开着却没连上 / 没开（它是什么）
          desc: state.nmeaGpsSupplying
              ? s.extGpsStats('${state.nmeaGps.fixes}')
              : (state.nmeaGpsOn
                  ? (state.nmeaGps.up
                      ? s.extGpsWaitingFix
                      : s.dataSourceNmeaGpsDesc)
                  : s.extGpsDeviceDesc),
          active: state.nmeaGpsSupplying,
          disabled: !tncPlatformSupported,
          disabledReason: s.iosFeatureUnsupported,
          onTap: () {
            // 还没绑过设备 → 先进设备页（扫设备 / 绑定 / 日志都在那里）
            if (state.nmeaGps.device == null) {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ExtGpsDevicePage(state: state)));
              return;
            }
            // 最后一条来源不允许关掉：全关掉应用就什么都不收 —— 与报文链路同一套规矩
            if (state.nmeaGpsOn && state.enabledSources.length <= 1) return;
            state.toggleSource(AppState.srcNmeaGps, !state.nmeaGpsOn);
          },
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
        // ── 我的其他 SSID（用户要求）──
        //
        // 同一个呼号下的其它设备（手机 -7、电脑 -9 …）在台站列表里是独立台站，
        // 但它们是「我自己的设备」：应当一眼看到，并且对其中装 APRSlocus 的
        // 那几台能直接下指令（激活 / 发一次信标 / 停止上报）。
        // 不是 APRSlocus 的，点一下走标准台站面板看信息。
        if (state.myOtherSsidStations.isNotEmpty) ...[
          _ownLabel(context, s.myOtherSsidLabel),
          for (final o in state.myOtherSsidStations) _ssidRow(context, o),
        ] else ...[
          // 一台也没有时也把这一块露出来：用户找「其他 SSID」到底在哪儿
          // （隐藏的区等于不存在），并说清它是什么时候才会出现。
          _ownLabel(context, s.myOtherSsidLabel),
          Padding(
            padding: const EdgeInsets.fromLTRB(23, 2, 14, 8),
            child: Text(s.myOtherSsidNone, style: ts(11, c: C.grey, h: 1.4)),
          ),
        ],
        // 多选时才需要解释「发射走哪条」，单选时这句话是噪音
        // 位置来源的**优先级**（与上报页同一句文案、同一个 getter）：两处都写清楚，
        // 用户才不会觉得「两个地方各说一个来源、不知道听谁的」。
        SettingsHint(s.posSourcePrecedence, color: C.slate),
        if (state.multiSource) SettingsHint(s.dataSourceTxHint),
        if (state.multiSource) SettingsHint(s.dataSourceIgateHint),
        // PKWDWPL 是只读的，这句必须常驻：否则用户会奇怪为何它没有发射圆点
        if (state.pkwdwplOn) SettingsHint(s.dataSourcePkwdwplHint),
        // 外接 GPS 同理（而且它供的是本机位置，不是报文 —— 更要说清）
        if (state.nmeaGpsOn) SettingsHint(s.dataSourceNmeaGpsHint),
        if (extra != null) SettingsHint(extra!),
      ],
    );
  }

  /// 我另一个 SSID 的一行。
  ///
  /// 装 APRSlocus 的那些台站多一条指令行（激活 / 发信标 / 停止）；别的设备
  /// 只显示状态，点一下走标准台站面板 —— 没有约定好的指令通道，硬塞按钮等于骗人。
  Widget _ssidRow(BuildContext context, Station o) {
    final s = S.of(context);
    final online = o.effectiveStatus != St.offline;
    final app = o.isAprslocusStation;
    final ago = localizedLastSeen(context, o);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClickCursor(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => StationDetail(state: state, station: o),
              ),
              child: Row(children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Center(
                    child: AprsSymbolImage(o.symbol, o.symbolTable,
                        size: 20,
                        grayscale: !online,
                        halo: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(o.call,
                            style: ts(12.5, w: FontWeight.w700, ls: 0.3)),
                        if (app) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: C.blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text('APRSlocus',
                                style:
                                    ts(9, c: C.blue, w: FontWeight.w700)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 1),
                      Text(
                        '${online ? s.online : s.offline} · $ago',
                        style: ts(10.5, c: C.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 16, color: C.greyLight),
              ]),
            ),
          ),
          if (app)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _ssidCmd(context, s.ssidCmdActivate, Icons.power_settings_new_rounded,
                      SsidCmd.activate, o),
                  _ssidCmd(context, s.ssidCmdBeacon, Icons.send_rounded,
                      SsidCmd.beacon, o),
                  _ssidCmd(context, s.ssidCmdStop,
                      Icons.stop_circle_outlined, SsidCmd.stop, o),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 一条指令按钮：发出去之后给出「发了什么」的反馈，发不出去（链路没连）
  /// 也要说清楚，否则用户只会以为按钮坏了。
  Widget _ssidCmd(BuildContext context, String label, IconData icon,
      SsidCmd cmd, Station o) {
    return GestureDetector(
      onTap: () {
        final ok = state.sendSsidCommand(o.call, cmd);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? S.of(context).ssidCmdSent(o.call, label)
              : S.of(context).ssidCmdNoLink),
          behavior: SnackBarBehavior.floating,
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: C.blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: C.blue.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: C.blue),
          const SizedBox(width: 4),
          Text(label, style: ts(10.5, c: C.blue, w: FontWeight.w600)),
        ]),
      ),
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

  /// 小组标题（互联网链路 / 电台链路 / 位置来源 / 心率来源）
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

  /// 一条报文链路一行：名称、通不通、在这条链路上能开什么。
  ///
  /// 形状与「设置 → 服务器」一级那两个入口一致（[SettingsLinkEntry]）：
  /// 左边图标、中间三段文字、右边发射圆点 + 开关 + 箭头。原来的复选框和
  /// 那颗 tune 小按钮都换掉了 —— 复选框与开关做的是同一件事，而 tune 图标
  /// 的可点区域只有 15 px，手指按到边上没反应。
  Widget _tile(
    BuildContext context, {
    required String key,
    required String title,
    required String desc,
    required IconData icon,
    bool? enabled,
    bool? isTx,
    bool? isTxMsg,
    bool? up,
    ValueChanged<bool>? onToggle,
    VoidCallback? onSetTx,
    VoidCallback? onSetTxMsg,
    VoidCallback? onConfigure,
    bool canTx = true,
    bool disabled = false,
    String? disabledReason,
  }) {
    final s = S.of(context);
    final isEnabled = enabled ?? state.enabledSources.contains(key);
    final isUp = up ?? state.isUp(key);
    // 只读来源（PKWDWPL）永远不是发射来源，圆点也不画 ——
    // 否则用户会以为「选上它就能发」。
    // 位置那颗只在「高级连接通道设置」打开时才画：关着时位置一律全发，
    // 画出来也只是个点不动的东西。消息那颗一直在（它不受那个开关影响）。
    final showPosDot = canTx && state.advChannels;
    final posTx = isTx ?? (showPosDot && state.posTxHas(key));
    final msgTx = isTxMsg ?? (canTx && state.dataSourceMsg == key);
    return SettingsLinkEntry(
      title: title,
      // 平台不支持时把原因写在这里，状态行就不画了
      subtitle: disabled ? (disabledReason ?? desc) : desc,
      status: disabled ? '' : (isUp ? s.connected : s.disconnected),
      up: isUp,
      on: isEnabled,
      enabled: !disabled,
      onToggle: onToggle ?? (v) => state.toggleSource(key, v),
      icon: icon,
      color: C.blue,
      txPos: (!disabled && showPosDot) ? posTx : null,
      txMsg: (!disabled && canTx) ? msgTx : null,
      onTxPos: () => state.togglePosTx(
          key == 'icomlan' ? AppState.srcAudio : key),
      onTxMsg: msgTx ? null : (onSetTxMsg ?? () => state.setTxMsgSource(key)),
      onTap: () {
        if (onConfigure != null) onConfigure();
      },
    );
  }
}
