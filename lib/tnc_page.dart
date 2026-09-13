import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/app_localizations.dart';
import 'net/tnc.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'tnc.dart';
import 'widgets.dart';

/// ─── 设备页：蓝牙 / 串口 TNC 绑定与 KISS 控制 ───
///
/// 设计说明：
///   - 「数据来源」开关在这里也放一份 —— 用户往往是在插上 TNC 之后才想到切换，
///     强迫他退回连接页找不到入口。
///   - KISS 参数的**单位换算在数据层**（`TncConfig.msToKiss`）：界面上写 ms、
///     下发时转成 10ms 单位。用户不该为了发一条 KISS 命令自己去做除法。
///   - 每个参数都带 Tooltip 说明它到底改变什么，而不是只给一个 KISS 缩写。
class TncSettingsPage extends StatefulWidget {
  final AppState state;
  const TncSettingsPage({super.key, required this.state});

  @override
  State<TncSettingsPage> createState() => _TncSettingsPageState();
}

class _TncSettingsPageState extends State<TncSettingsPage> {
  late final TextEditingController _txDelay;
  late final TextEditingController _txTail;
  late final TextEditingController _persistence;
  late final TextEditingController _slotTime;
  late final TextEditingController _channel;
  late final TextEditingController _maxFrame;
  late final TextEditingController _path;
  late final TextEditingController _hwCmd;
  late final TextEditingController _hwVal;

  bool _scanning = false;
  bool _supported = true;
  bool _busy = false;

  AppState get st => widget.state;
  TncLink get tnc => widget.state.tnc;

  @override
  void initState() {
    super.initState();
    final c = tnc.config;
    _txDelay = TextEditingController(text: '${c.txDelayMs}');
    _txTail = TextEditingController(text: '${c.txTailMs}');
    _persistence = TextEditingController(text: '${c.persistence}');
    _slotTime = TextEditingController(text: '${c.slotTimeMs}');
    _channel = TextEditingController(text: '${c.channel}');
    _maxFrame = TextEditingController(text: '${c.maxFrame}');
    _path = TextEditingController(text: c.path);
    _hwCmd = TextEditingController(text: c.hardwareCmd < 0 ? '' : '${c.hardwareCmd}');
    _hwVal = TextEditingController(text: '${c.hardwareVal}');
    unawaited(_probe());
  }

  @override
  void dispose() {
    for (final c in [
      _txDelay, _txTail, _persistence, _slotTime,
      _channel, _maxFrame, _path, _hwCmd, _hwVal,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _probe() async {
    final ok = await tnc.supported();
    if (mounted) setState(() => _supported = ok);
  }

  void _toast(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? C.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  int _intOf(TextEditingController c, int fallback) =>
      int.tryParse(c.text.trim()) ?? fallback;

  /// 把界面上的输入收集回 config 并持久化
  Future<void> _collect() async {
    final c = tnc.config;
    c.txDelayMs = _intOf(_txDelay, c.txDelayMs).clamp(0, 2550);
    c.txTailMs = _intOf(_txTail, c.txTailMs).clamp(0, 2550);
    c.persistence = _intOf(_persistence, c.persistence).clamp(0, 255);
    c.slotTimeMs = _intOf(_slotTime, c.slotTimeMs).clamp(0, 2550);
    c.channel = _intOf(_channel, c.channel).clamp(0, 15);
    c.maxFrame = _intOf(_maxFrame, c.maxFrame).clamp(0, 2048);
    c.path = _path.text.trim();
    final cmd = int.tryParse(_hwCmd.text.trim());
    c.hardwareCmd = (cmd == null || cmd < 0) ? -1 : cmd.clamp(0, 15);
    c.hardwareVal = _intOf(_hwVal, c.hardwareVal).clamp(0, 255);
    await tnc.persistConfig();
  }

  Future<void> _apply() async {
    await _collect();
    if (!tnc.connected) {
      _toast(S.of(context).kissNeedConnected, color: C.orange);
      return;
    }
    tnc.applyKiss();
    _toast(S.of(context).kissParamsSent, color: C.green);
    setState(() {});
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    // Android 12+ 需要运行时蓝牙权限；先请求再扫描，否则列表恒为空
    if (!await tnc.requestPermissions()) {
      if (mounted) {
        setState(() => _scanning = false);
        _toast(S.of(context).tncNeedPermission, color: C.red);
      }
      return;
    }
    await tnc.scan();
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _toggleLink() async {
    setState(() => _busy = true);
    if (tnc.connected) {
      await tnc.disconnect();
      // 同步 AppState 的连接状态（首页状态栏读的是它）
      st.connected = false;
      st.connInfo = '未连接 · TNC';
    } else {
      if (tnc.device == null) {
        setState(() => _busy = false);
        _toast(S.of(context).tncNotBound, color: C.orange);
        return;
      }
      if (!await tnc.requestPermissions()) {
        setState(() => _busy = false);
        _toast(S.of(context).tncNeedPermission, color: C.red);
        return;
      }
      await _collect();
      final ok = await tnc.connect();
      if (ok) {
        st.connected = true;
        st.connInfo = 'TNC 已连接 · ${tnc.device?.label ?? ''}';
      } else {
        st.connected = false;
        st.connInfo = 'TNC 连接失败 · ${tnc.lastError}';
        if (tnc.status == TncStatus.openFailed) {
          _toast(S.of(context).tncOpenFailedHint, color: C.red);
        } else {
          _toast('${S.of(context).connectFailedCheckConfig} ${tnc.lastDetail}',
              color: C.red);
        }
      }
    }
    st.reloadUi();
    if (mounted) setState(() => _busy = false);
  }

  String _statusText(S s) {
    switch (tnc.status) {
      case TncStatus.connected:
        return s.connected;
      case TncStatus.connecting:
        return s.connecting;
      case TncStatus.noDevice:
        return s.tncNotBound;
      case TncStatus.unsupported:
        return s.tncSupportedNo;
      case TncStatus.noPermission:
        return s.tncNeedPermission;
      case TncStatus.openFailed:
        return s.tncOpenFailedHint;
      case TncStatus.closed:
        return s.disconnected;
      case TncStatus.error:
        return s.connectFailedCheckConfig;
      default:
        return s.disconnected;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => SettingsPageShell(
        title: s.deviceSettings2,
        subtitle: s.deviceSettingsSubtitle,
        icon: Icons.radio_rounded,
        color: C.indigo,
        body: Column(children: [
          _sourceCard(s),
          const SizedBox(height: 16),
          _bindCard(s),
          const SizedBox(height: 16),
          _kissCard(s),
          const SizedBox(height: 16),
          _rfCard(s),
          const SizedBox(height: 16),
          _logCard(s),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  /// ① 数据来源（共用组件，连接页也用同一个）
  Widget _sourceCard(S s) =>
      DataSourceCard(state: st, extra: s.dataSourceSwitchHint);

  /// ② 设备绑定
  Widget _bindCard(S s) {
    // 连接状态与收发计数合并成一行：
    // 两个都是「链路此刻怎么样」，分开两行反而要多读一行标签。
    final statusValue = tnc.connected
        ? '${_statusText(s)} · ${s.tncStats('${tnc.rxFrames}', '${tnc.txFrames}')}'
        : _statusText(s);
    return SettingsSectionCard(
      title: s.tncBindTitle,
      subtitle: s.tncBindSubtitle,
      icon: Icons.bluetooth_rounded,
      color: C.indigo,
      children: [
        SettingsRow2(
          s.tncBoundDevice,
          tnc.device?.label ?? s.tncNotBound,
          valueColor: tnc.device == null ? C.grey : C.ink,
        ),
        SettingsRow2(
          s.connection,
          statusValue,
          valueColor: tnc.connected
              ? C.green
              : (tnc.connecting ? C.blue : C.slate),
        ),
        if (!_supported) SettingsHint(s.tncSupportedNo, color: C.orange),
        // 操作行
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _scanning || !_supported ? null : _scan,
                icon: _scanning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded, size: 16),
                label: Text(s.tncScanPaired),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.indigo,
                  side: BorderSide(color: C.indigo.withValues(alpha: 0.5)),
                  textStyle: ts(12, w: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy || !_supported ? null : _toggleLink,
                icon: Icon(
                  tnc.connected
                      ? Icons.link_off_rounded
                      : Icons.link_rounded,
                  size: 16,
                ),
                label: Text(
                  tnc.connected ? s.disconnect : s.tncConnectAction,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: tnc.connected ? C.red : C.green,
                  textStyle: ts(12, c: Colors.white, w: FontWeight.w600),
                ),
              ),
            ),
          ]),
        ),
        if (tnc.device != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Row(children: [
              TextButton.icon(
                onPressed: () async {
                  tnc.bind(null);
                  setState(() {});
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 15),
                label: Text(s.tncUnbind, style: ts(12)),
                style: TextButton.styleFrom(foregroundColor: C.grey),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  setState(() => _busy = true);
                  await tnc.restart();
                  st.connected = tnc.connected;
                  st.reloadUi();
                  if (mounted) setState(() => _busy = false);
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 15),
                label: Text(s.tncRestart, style: ts(12)),
                style: TextButton.styleFrom(foregroundColor: C.orange),
              ),
            ]),
          ),
        if (tnc.devices.isNotEmpty) ...[
          Divider(height: 1, color: C.border),
          for (final d in tnc.devices) _deviceTile(d),
        ] else if (!_scanning)
          SettingsHint(s.tncNoPaired, icon: Icons.bluetooth_disabled_rounded),
      ],
    );
  }

  Widget _deviceTile(TncDevice d) {
    final selected = tnc.device?.id == d.id;
    return InkWell(
      onTap: () async {
        tnc.bind(d);
        if (mounted) setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? C.indigo.withValues(alpha: 0.10) : Colors.transparent,
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(children: [
          Icon(
            d.isBluetooth ? Icons.bluetooth_rounded : Icons.usb_rounded,
            size: 16,
            color: selected ? C.indigo : C.grey,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(d.label,
                style: ts(12, w: selected ? FontWeight.w700 : FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, size: 16, color: C.indigo),
        ]),
      ),
    );
  }

  /// ③ KISS 参数
  Widget _kissCard(S s) {
    return SettingsSectionCard(
      title: s.kissParamsTitle,
      subtitle: s.kissParamsSubtitle,
      icon: Icons.tune_rounded,
      color: C.cyan,
      children: [
        SettingsInput(s.kissTxDelay, _txDelay,
            tip: s.kissTxDelayTip,
            onChanged: (_) => unawaited(_collect())),
        SettingsInput(s.kissTxTail, _txTail,
            tip: s.kissTxTailTip,
            onChanged: (_) => unawaited(_collect())),
        SettingsInput(s.kissPersistence, _persistence,
            tip: s.kissPersistenceTip,
            onChanged: (_) => unawaited(_collect())),
        SettingsInput(s.kissSlotTime, _slotTime,
            tip: s.kissSlotTimeTip,
            onChanged: (_) => unawaited(_collect())),
        SettingsSwitch(s.kissFullDuplex, value: tnc.config.fullDuplex,
            color: C.red, onChanged: (v) async {
          tnc.config.fullDuplex = v;
          await tnc.persistConfig();
          setState(() {});
        }),
        SettingsInput(s.kissChannel, _channel,
            tip: s.kissChannelTip,
            onChanged: (_) => unawaited(_collect())),
        SettingsInput(s.kissMaxFrame, _maxFrame,
            tip: s.kissMaxFrameTip,
            onChanged: (_) => unawaited(_collect())),
        SettingsInput(s.kissRfPath, _path,
            tip: s.kissRfPathTip,
            onChanged: (_) => unawaited(_collect())),
        SettingsInput(s.kissHardwareCmd, _hwCmd,
            tip: s.kissHardwareTip,
            onChanged: (_) => unawaited(_collect())),
        SettingsInput(s.kissHardwareVal, _hwVal,
            tip: s.kissHardwareTip,
            onChanged: (_) => unawaited(_collect())),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.upload_rounded, size: 16),
              label: Text(s.kissApplyParams,
                  style: ts(13, c: Colors.white, w: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: C.cyan,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  if (!tnc.connected) {
                    _toast(s.kissNeedConnected, color: C.orange);
                    return;
                  }
                  tnc.kissReturn();
                  _toast(s.kissBackToCommand, color: C.orange);
                },
                icon: const Icon(Icons.terminal_rounded, size: 15),
                label: Text(s.kissBackToCommand, style: ts(11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.orange,
                  side: BorderSide(color: C.orange.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ]),
        ),
        SettingsHint(s.kissBackToCommandTip, color: C.orange),
        SettingsHint(s.kissHardwareTip),
      ],
    );
  }

  /// ④ 射频行为
  Widget _rfCard(S s) {
    return SettingsSectionCard(
      title: s.tncMsgTitle,
      subtitle: s.tncMsgDesc,
      icon: Icons.warning_amber_rounded,
      color: C.orange,
      children: [
        SettingsSwitch(s.kissRfBeacon, value: tnc.config.rfBeacon,
            color: C.orange, onChanged: (v) async {
          tnc.config.rfBeacon = v;
          await tnc.persistConfig();
          st.reloadUi();
          if (mounted) setState(() {});
        }),
        SettingsHint(s.kissRfBeaconTip, color: C.orange),
        SettingsSwitch(s.kissAutoAck, value: tnc.config.autoAck,
            color: C.cyan, onChanged: (v) async {
          tnc.config.autoAck = v;
          await tnc.persistConfig();
          if (mounted) setState(() {});
        }),
        SettingsHint(s.kissAutoAckTip),
        SettingsSwitch(s.kissAutoReconnect, value: tnc.config.autoReconnect,
            color: C.green, onChanged: (v) async {
          tnc.config.autoReconnect = v;
          await tnc.persistConfig();
          if (mounted) setState(() {});
        }),
      ],
    );
  }

  /// ⑤ 链路日志
  Widget _logCard(S s) {
    final logs = tnc.logs;
    return SettingsSectionCard(
      title: s.tncLog,
      icon: Icons.receipt_long_rounded,
      color: C.slate,
      children: [
        if (logs.isEmpty)
          SettingsHint(s.tncLogEmpty)
        else
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
                      style: ts(10, c: C.slate, h: 1.35).copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 供设置页其它入口复用：复制到剪贴板（调试用）
Future<void> copyTncLog(BuildContext context, TncLink tnc) async {
  await Clipboard.setData(ClipboardData(text: tnc.logs.join('\n')));
}

/// 数据来源选择卡片（连接页与设备页共用）
///
/// 做成公共组件的原因：同一个设置在两个入口都要能改 —— 用户插上 TNC 后
/// 往往在「设备」页，而排查连接问题时又会去「连接」页；各写一份迟早出现
/// 文案与行为不一致。
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
          key: AppState.srcAprsIs,
          title: s.dataSourceAprsIs,
          desc: s.dataSourceAprsIsDesc,
          icon: Icons.cloud_rounded,
        ),
        _tile(
          key: AppState.srcTnc,
          title: s.dataSourceTnc,
          desc: s.dataSourceTncDesc,
          icon: Icons.settings_input_antenna_rounded,
        ),
        if (extra != null) SettingsHint(extra!),
      ],
    );
  }

  Widget _tile({
    required String key,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    final selected = state.dataSource == key;
    return InkWell(
      onTap: selected ? null : () => state.setDataSource(key),
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
              color: selected ? C.blue.withValues(alpha: 0.12) : C.greyBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: selected ? C.blue : C.grey),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: ts(13,
                        w: FontWeight.w700, c: selected ? C.blue : C.ink)),
                const SizedBox(height: 2),
                Text(desc, style: ts(11, c: C.grey)),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, size: 18, color: C.blue)
          else
            Icon(Icons.radio_button_unchecked_rounded,
                size: 18, color: C.greyLight),
        ]),
      ),
    );
  }
}
