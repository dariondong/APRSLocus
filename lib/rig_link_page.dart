import 'dart:async';

import 'package:flutter/material.dart';

import 'net/rig_daemon.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 电台控制（Hamlib / rigctld）──
///
/// 这条「链路」不传报文：它只发频率、模式、PTT 三类控制命令。所以它不在
/// [AppState.enabledSources] 里，也没有「发射圆点」——设备页上它是一行
/// 普通的开关，点整行进这一页。
///
/// 它与音频链路是**一体**的：音频要发报时，先由这里按下 PTT、切到发报频率，
/// 播完再放开（`AudioLink.onTxKey` / `onTxUnkey`）。页面上的「发射 3 秒」
/// 只是单测按键用的。
///
/// 为什么不链 libhamlib：那是 C 库，三个桌面平台各要打一份二进制；而 hamlib
/// 自带的 `rigctld` 本来就是常驻进程，本地 TCP 说文本协议。用户自己起
/// `rigctld -m <型号> -r <串口>`（Linux/macOS 一条 apt/brew 命令，Windows 用
/// 官方 w64 包），地址填在这一页即可，换一台机器跑也照用。
class RigLinkPage extends StatelessWidget {
  final AppState state;
  const RigLinkPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SettingsPageShell(
      title: s.rigLinkTitle,
      subtitle: s.rigLinkLead,
      icon: Icons.tune_rounded,
      color: C.blue,
      body: Column(children: [
        RigCards(state: state),
        const SizedBox(height: 24),
      ]),
    );
  }
}

/// rigctld 的地址、端口与读数，加上三个动作。
class RigCards extends StatefulWidget {
  final AppState state;
  const RigCards({super.key, required this.state});

  @override
  State<RigCards> createState() => _RigCardsState();
}

class _RigCardsState extends State<RigCards> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _freq;
  late final TextEditingController _txFreq;
  late final TextEditingController _model;
  late final TextEditingController _device;
  late final TextEditingController _baud;
  late final TextEditingController _localPort;
  String _mode = 'FM';
  Timer? _pttTimer;

  AppState get st => widget.state;

  /// hamlib 的模式名（大写，就是 `rigctl` 里那几个）。
  static const _modes = <String>['FM', 'NFM', 'AM', 'USB', 'LSB', 'CW'];

  @override
  void initState() {
    super.initState();
    _host = TextEditingController(text: st.rigHost);
    _port = TextEditingController(text: st.rigPort > 0 ? '${st.rigPort}' : '');
    _freq = TextEditingController(
        text: st.rigFreqHz == null
            ? ''
            : (st.rigFreqHz! / 1000000).toStringAsFixed(3));
    _txFreq = TextEditingController(
        text: st.rigTxFreqHz <= 0
            ? ''
            : (st.rigTxFreqHz / 1000000).toStringAsFixed(3));
    _model = TextEditingController(
        text: st.rigLocalModel > 0 ? '${st.rigLocalModel}' : '');
    _device = TextEditingController(text: st.rigLocalDevice);
    _baud = TextEditingController(
        text: st.rigLocalBaud > 0 ? '${st.rigLocalBaud}' : '');
    _localPort = TextEditingController(
        text: st.rigLocalPort > 0 ? '${st.rigLocalPort}' : '');
    // 程序路径只有查过才知道：进来先找一次，为了那行「程序」不至于永远空着。
    unawaited(st.rigDaemon.locate().then((_) {
      if (mounted) setState(() {});
    }));
    if (_modes.contains(st.rigMode)) _mode = st.rigMode;
  }

  @override
  void dispose() {
    _pttTimer?.cancel();
    _host.dispose();
    _port.dispose();
    _freq.dispose();
    _txFreq.dispose();
    _model.dispose();
    _device.dispose();
    _baud.dispose();
    _localPort.dispose();
    super.dispose();
  }

  /// 频率读数：`145.640 MHz`；读不到写 `—`。
  String get _freqText {
    final hz = st.rigFreqHz;
    if (hz == null) return '—';
    return '${(hz / 1000000).toStringAsFixed(3)} MHz';
  }

  /// 把输入框里的 MHz 换成 Hz。写错了不发命令（宁可什么都不做）。
  void _applyFreq() {
    final mhz = double.tryParse(_freq.text.trim().replaceAll(',', '.'));
    if (mhz == null || mhz <= 0) return;
    unawaited(st.rigSetFreq((mhz * 1000000).round()));
  }

  /// 发射 3 秒后自动放开：这是测试 PTT 用的，不是给人一直按着上天的。
  void _pttOnce() {
    unawaited(st.rigSetPtt(true));
    _pttTimer?.cancel();
    _pttTimer = Timer(const Duration(seconds: 3), () {
      unawaited(st.rigSetPtt(false));
    });
  }

  /// 发报频率（MHz）：只存下来，真发报时由 `state` 切过去。
  /// 清空就是「不动电台当前的频率」。
  void _applyTxFreq() {
    final txt = _txFreq.text.trim().replaceAll(',', '.');
    if (txt.isEmpty) {
      st.setRigTxFreq(0);
      return;
    }
    final mhz = double.tryParse(txt);
    if (mhz == null || mhz <= 0) return;
    st.setRigTxFreq((mhz * 1000000).round());
  }

  /// 本机 rigctld（安装包自带那份）的开关、型号与串口。
  ///
  /// 四格输入都不预填：型号编号、串口、鲍率、端口都是用户那台电台的事。
  /// 端口写清 4532 是 hamlib 自己的默认值，算告诉而不是替他填。
  Widget _localCard(S s) {
    final err = _daemonErrorText(s);
    return Column(children: [
      SettingsSectionCard(
        title: s.rigDaemonCard,
        icon: Icons.memory_rounded,
        color: C.blue,
        children: [
          SettingsSwitch(
            s.rigDaemonSwitch,
            value: st.rigLocalOn,
            color: C.blue,
            enabled: st.rigDaemon.supported,
            onChanged: (v) => unawaited(st.setRigLocalOn(v)),
          ),
          SettingsInput(
            s.rigDaemonModel,
            _model,
            hint: '3085 = IC-705',
            badge: st.rigLocalModel <= 0 ? s.oobeDoneUnset : null,
            onChanged: (v) => st.setRigLocalModel(int.tryParse(v.trim()) ?? 0),
          ),
          SettingsInput(
            s.rigDaemonDevice,
            _device,
            hint: 'COM3 / /dev/ttyUSB0',
            onChanged: st.setRigLocalDevice,
          ),
          SettingsInput(
            s.rigDaemonBaud,
            _baud,
            hint: '38400',
            onChanged: (v) => st.setRigLocalBaud(int.tryParse(v.trim()) ?? 0),
          ),
          SettingsInput(
            s.rigDaemonPort,
            _localPort,
            hint: '${AppState.kRigDefaultPort}',
            onChanged: (v) => st.setRigLocalPort(int.tryParse(v.trim()) ?? 0),
          ),
          SettingsRow2(
            s.rigDaemonState,
            st.rigDaemonBusy
                ? s.rigDaemonStarting
                : (st.rigDaemon.running
                    ? s.rigDaemonRunning
                    : s.rigDaemonStopped),
            valueColor: st.rigDaemon.running ? C.green : C.slate,
          ),
          SettingsRow2(
            s.rigDaemonExe,
            st.rigDaemon.exe.isEmpty ? '—' : st.rigDaemon.exe,
          ),
          if (err != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, size: 14, color: C.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(err,
                      style: ts(10.5, c: C.red),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          if (st.rigLocalOn)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  side: BorderSide(color: C.blue.withValues(alpha: 0.35)),
                ),
                onPressed: st.rigDaemonBusy
                    ? null
                    : () async {
                        await st.stopRigDaemon();
                        await st.startRigDaemon();
                      },
                child: Text(s.rigDaemonRestart, style: ts(13, c: C.blue)),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
    ]);
  }

  /// 起不来的原因换成一句人话；没错就返回 null。
  String? _daemonErrorText(S s) {
    switch (st.rigDaemonError) {
      case RigDaemonError.none:
        return null;
      case RigDaemonError.unsupported:
        return s.rigDaemonUnsupported;
      case RigDaemonError.noBinary:
        return s.rigDaemonNoBinary;
      case RigDaemonError.noModel:
        return s.rigDaemonNoModel;
      case RigDaemonError.inUse:
        return s.rigDaemonInUse;
      case RigDaemonError.exited:
        return s.rigDaemonExited;
      case RigDaemonError.timeout:
        return s.rigDaemonTimeout;
      case RigDaemonError.startFailed:
        return s.rigDaemonFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => Column(children: [
        _localCard(s),
        SettingsSectionCard(
          title: s.rigConnection,
          icon: Icons.cable_rounded,
          color: C.blue,
          children: [
            // 本机那份 rigctld 在管这台电台时，地址与端口不由用户填：
            // 回环地址与上卡里的端口就是它的，填了也不会用。
            if (st.rigLocalOn)
              SettingsRow2(s.rigAddr, st.rigAddr)
            else ...[
              SettingsInput(
                s.rigAddr,
                _host,
                hint: s.rigAddrHint,
                // 空着就是没配：与服务器地址同一个规矩，不预填任何地址。
                badge: st.rigHost.trim().isEmpty ? s.oobeDoneUnset : null,
                onChanged: st.setRigHost,
              ),
              SettingsInput(
                s.port,
                _port,
                onChanged: (v) => st.setRigPort(int.tryParse(v.trim()) ?? 0),
              ),
            ],
            SettingsRow2(
              s.rigStatus,
              st.rigBusy
                  ? '…'
                  : (st.rigConnected ? s.connected : s.disconnected),
              valueColor: st.rigConnected ? C.green : C.slate,
            ),
            SettingsRow2(s.radioCat, st.rigInfo.isEmpty ? '—' : st.rigInfo),
            SettingsRow2(s.rigFreqMhz, _freqText),
            SettingsRow2(s.rigMode, st.rigMode.isEmpty ? '—' : st.rigMode),
            if (st.rigError.isNotEmpty && st.rigError != 'no-address')
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded, size: 14, color: C.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(st.rigError,
                        style: ts(10.5, c: C.red),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: BorderSide(color: C.blue.withValues(alpha: 0.35)),
                    ),
                    onPressed: st.reconnectRig,
                    child: Text(s.reconnect, style: ts(13, c: C.blue)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: C.blue,
                      disabledBackgroundColor: C.greyBg,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: () => st.setRigOn(!st.rigOn),
                    child: Text(st.rigOn ? s.disconnect : s.rigConnectNow,
                        style: ts(13)),
                  ),
                ),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSectionCard(
          title: s.rigControl,
          icon: Icons.radio_rounded,
          color: C.blue,
          children: [
            SettingsInput(s.rigFreqMhz, _freq, hint: '144.640'),
            SettingsChoice<String>(
              s.rigMode,
              value: _mode,
              options: _modes,
              labelOf: (m) => m,
              onChanged: (v) {
                setState(() => _mode = v);
                unawaited(st.rigSetMode(v));
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: C.blue,
                      disabledBackgroundColor: C.greyBg,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: st.rigConnected ? _applyFreq : null,
                    child: Text(s.rigApply, style: ts(13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: BorderSide(color: C.orange.withValues(alpha: 0.45)),
                    ),
                    onPressed: st.rigConnected ? _pttOnce : null,
                    child: Text(s.rigPttTest, style: ts(13, c: C.orange)),
                  ),
                ),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSectionCard(
          title: s.rigTxLink,
          icon: Icons.settings_input_antenna_rounded,
          color: C.blue,
          children: [
            SettingsSwitch(
              s.rigKeyTxTitle,
              value: st.rigKeyTx,
              color: C.blue,
              onChanged: st.setRigKeyTx,
            ),
            SettingsInput(
              s.rigTxFreq,
              _txFreq,
              hint: 'MHz',
              onChanged: (_) => _applyTxFreq(),
            ),
          ],
        ),
      ]),
    );
  }
}
