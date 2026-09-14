import 'dart:async';

import 'package:flutter/material.dart';

import 'net/tnc.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'tnc.dart';
import 'widgets.dart';

/// ─── TNC 设备与参数（设备页的子页）───
///
/// 从原「设备页」拆出来，只保留**需要动手改**的东西：
///   ① 设备绑定 / 连接 / 重启（含扫描已配对设备）
///   ② TNC 初始化串（新增：等价 APRSdroid 的 `kiss.init`）
///   ③ KISS 参数（TxDelay/P/SlotTime/TxTail/FullDuplex/信道/帧长/中继）
///   ④ 射频行为（射频信标 / 自动 ACK / 自动重连）
///   ⑤ 发射自检（新增：把「能收不能发」拆成可判断的结论）
///
/// 「当前通不通」「日志」不在这里 —— 那些在概览页，避免调参时反复滚屏。
class TncDevicePage extends StatefulWidget {
  final AppState state;
  const TncDevicePage({super.key, required this.state});

  @override
  State<TncDevicePage> createState() => _TncDevicePageState();
}

class _TncDevicePageState extends State<TncDevicePage> {
  late final TextEditingController _txDelay;
  late final TextEditingController _txTail;
  late final TextEditingController _persistence;
  late final TextEditingController _slotTime;
  late final TextEditingController _channel;
  late final TextEditingController _maxFrame;
  late final TextEditingController _path;
  late final TextEditingController _hwCmd;
  late final TextEditingController _hwVal;
  late final TextEditingController _initString;
  late final TextEditingController _initDelay;

  bool _scanning = false;
  bool _supported = true;
  bool _busy = false;
  String _txTestResult = '';

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
    _hwCmd =
        TextEditingController(text: c.hardwareCmd < 0 ? '' : '${c.hardwareCmd}');
    _hwVal = TextEditingController(text: '${c.hardwareVal}');
    _initString = TextEditingController(text: c.initString);
    _initDelay = TextEditingController(text: '${c.initDelayMs}');
    unawaited(_probe());
  }

  @override
  void dispose() {
    for (final c in [
      _txDelay, _txTail, _persistence, _slotTime,
      _channel, _maxFrame, _path, _hwCmd, _hwVal, _initString, _initDelay,
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
    c.initString = _initString.text;
    c.initDelayMs = _intOf(_initDelay, c.initDelayMs).clamp(0, 5000);
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
      st.connected = false;
      st.setConnStatus(ConnPhase.manual);
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
        st.setConnStatus(ConnPhase.tncConnected,
            arg: tnc.device?.label ?? '');
      } else {
        st.connected = false;
        st.setConnStatus(ConnPhase.retryTnc,
            arg: tnc.lastError, seconds: 8);
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

  /// 发射自检：把「能收不能发」拆成可判断的结论
  Future<void> _txSelfTest() async {
    final s = S.of(context);
    await _collect();
    final err = await tnc.txSelfTest(st.myFullCall, st.txPath);
    if (!mounted) return;
    setState(() {
      _txTestResult =
          err == null ? s.tncTxTestOk('${tnc.txFrames}') : s.tncTxTestFail(linkErrorText(s, err));
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => SettingsPageShell(
        title: s.tncDeviceTitle,
        subtitle: s.tncDeviceDesc,
        icon: Icons.settings_input_antenna_rounded,
        color: C.indigo,
        body: Column(children: [
          _bindCard(s),
          const SizedBox(height: 16),
          _initCard(s),
          const SizedBox(height: 16),
          _kissCard(s),
          const SizedBox(height: 16),
          _txTestCard(s),
          const SizedBox(height: 16),
          _rfCard(s),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  /// ① 设备绑定与连接
  Widget _bindCard(S s) {
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
                label: Text(tnc.connected ? s.disconnect : s.tncConnectAction),
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

  /// ② TNC 初始化串（等价 APRSdroid 的 `kiss.init`）
  ///
  /// 这是「能收不能发」最值得先试的一招：不少蓝牙/串口 TNC 模块上电停在
  /// 命令模式，必须先收到 `KISS ON`/`RESTART` 才会进入 KISS 转发。
  Widget _initCard(S s) {
    return SettingsSectionCard(
      title: s.tncInitTitle,
      subtitle: s.tncInitSubtitle,
      icon: Icons.terminal_rounded,
      color: C.purple,
      children: [
        SettingsHint(s.tncInitTip, color: C.purple),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: TextField(
            controller: _initString,
            maxLines: 4,
            minLines: 2,
            style: ts(12).copyWith(fontFamily: 'monospace'),
            onChanged: (_) => unawaited(_collect()),
            decoration: InputDecoration(
              hintText: 'KISS ON\nRESTART',
              hintStyle: ts(12, c: C.grey).copyWith(fontFamily: 'monospace'),
              isDense: true,
              filled: true,
              fillColor: C.bgSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SettingsInput(s.tncInitDelay, _initDelay,
            tip: s.tncInitDelayTip,
            onChanged: (_) => unawaited(_collect())),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: tnc.connected
                  ? () async {
                      await _collect();
                      final n = await tnc.sendInitString();
                      if (!mounted) return;
                      _toast(
                        n == 0 ? s.tncInitEmpty : s.tncInitSent(n),
                        color: n == 0 ? C.orange : C.green,
                      );
                      setState(() {});
                    }
                  : null,
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text(s.tncInitSendAction, style: ts(12, w: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.purple,
                side: BorderSide(color: C.purple.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ),
      ],
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
        // 默认不下发：APRSdroid 也是默认不发，避免用错误的参数覆盖 TNC 配置
        SettingsSwitch(s.tncPushParams, value: tnc.config.pushKissParams,
            color: C.cyan, onChanged: (v) async {
          tnc.config.pushKissParams = v;
          await tnc.persistConfig();
          if (mounted) setState(() {});
        }),
        SettingsHint(s.tncPushParamsTip, color: C.cyan),
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

  /// ④ 发射自检：把「能收不能发」拆成可判断的结论
  Widget _txTestCard(S s) {
    return SettingsSectionCard(
      title: s.tncTxTestTitle,
      subtitle: s.tncTxTestSubtitle,
      icon: Icons.wifi_tethering_rounded,
      color: C.orange,
      children: [
        SettingsHint(s.tncTxTestHint, color: C.orange),
        if (_txTestResult.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                _txTestResult.startsWith(s.tncTxTestOkPrefix)
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                size: 14,
                color: _txTestResult.startsWith(s.tncTxTestOkPrefix)
                    ? C.green
                    : C.red,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_txTestResult,
                    style: ts(11, c: C.slate, h: 1.4)),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
          child: SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: tnc.connected && !_busy ? _txSelfTest : null,
              icon: const Icon(Icons.bolt_rounded, size: 16),
              label: Text(s.tncTxTestAction,
                  style: ts(12, c: Colors.white, w: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: C.orange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        if (!tnc.connected) SettingsHint(s.tncNeedConnected, color: C.grey),
      ],
    );
  }

  /// ⑤ 射频行为
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
}
