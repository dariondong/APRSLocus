// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';

import 'audio.dart';
import 'net/icom_lan_settings.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── WLAN 电台直连设备页（独立一级设备页）───
///
/// 专为 Icom WLAN / LAN 局域网直连打造的专属控制面板，
/// 完整支持 IC-705、IC-9700、IC-7610、IC-905 及自定义电台：
/// ① 电台连接状态与实时链路阶段（未连接 / 认证中 / 协商中 / 接收中 / 传输中）
/// ② 一键直连开关与连接/断开控制
/// ③ 电台型号预置与网络参数（电台 IP / 控制端口 / Network User 用户名与密码）
/// ④ CI-V 控制与发射参数（CI-V 地址 / 射频信标开关 / 发射延迟 TX Delay）
/// ⑤ 电台端配网指引与实时日志
class Ic705DevicePage extends StatefulWidget {
  final AppState state;
  const Ic705DevicePage({super.key, required this.state});

  @override
  State<Ic705DevicePage> createState() => _Ic705DevicePageState();
}

class _Ic705DevicePageState extends State<Ic705DevicePage> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _pass;
  late final TextEditingController _civAddr;
  late final TextEditingController _txDelay;

  /// 失焦提交用的焦点节点（`onEditingComplete` 只在回车时触发，见 [_onBlur]）。
  late final FocusNode _hostFocus;
  late final FocusNode _portFocus;
  late final FocusNode _userFocus;
  late final FocusNode _passFocus;
  late final FocusNode _civFocus;
  late final FocusNode _delayFocus;

  late WlanRadioModel _selectedModel;
  bool _busy = false;
  bool _logOpen = false;

  AppState get st => widget.state;
  AudioLink get audio => widget.state.audio;

  @override
  void initState() {
    super.initState();
    final c = audio.config;
    _selectedModel = c.icomLan.model;
    _host = TextEditingController(text: c.icomLan.host);
    _port = TextEditingController(text: '${c.icomLan.controlPort}');
    _user = TextEditingController(text: c.icomLan.username);
    _pass = TextEditingController(text: c.icomLan.password);
    _civAddr = TextEditingController(
      text: '0x${c.icomLan.radioCivAddress.toRadixString(16).toUpperCase()}',
    );
    _txDelay = TextEditingController(text: '${c.afsk.txDelayMs}');
    _hostFocus = FocusNode();
    _portFocus = FocusNode();
    _userFocus = FocusNode();
    _passFocus = FocusNode();
    _civFocus = FocusNode();
    _delayFocus = FocusNode();
    // 失焦即落定：`onEditingComplete` 只在按键盘「完成/回车」时触发，
    // **失焦不触发** —— 只挂它的话「填完随手点别处」等于什么都没存
    // （issue #22-1 心率阈值同款，本页此前全部输入框都是这个毛病）。
    for (final f in _focuses) {
      f.addListener(_onBlur);
    }
  }

  /// 本页全部输入框的焦点：失焦落定与 dispose 都靠它遍历。
  List<FocusNode> get _focuses => [
        _hostFocus, _portFocus, _userFocus,
        _passFocus, _civFocus, _delayFocus,
      ];

  /// 整组都不再持有焦点时落定一次（组内转移焦点不提交，避免打断输入）。
  void _onBlur() {
    if (_focuses.any((f) => f.hasFocus)) return;
    unawaited(_saveConfig());
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _pass.dispose();
    _civAddr.dispose();
    _txDelay.dispose();
    for (final f in _focuses) {
      f.dispose();
    }
    super.dispose();
  }

  void _toast(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? C.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  int _parseInt(TextEditingController c, int defaultValue) {
    final text = c.text.trim();
    if (text.startsWith('0x') || text.startsWith('0X')) {
      return int.tryParse(text.substring(2), radix: 16) ?? defaultValue;
    }
    return int.tryParse(text) ?? defaultValue;
  }

  Future<void> _saveConfig({bool? enabled}) async {
    final c = audio.config;
    final oldDelay = c.afsk.txDelayMs;
    final civ = _parseInt(_civAddr, _selectedModel.defaultCivAddress).clamp(0x01, 0xFF);
    final delay = _parseInt(_txDelay, 200).clamp(0, 2000);

    c.icomLan = IcomLanConfig(
      host: _host.text.trim(),
      controlPort: _parseInt(_port, _selectedModel.defaultPort).clamp(1, 65533),
      username: _user.text.trim(),
      password: _pass.text,
      model: _selectedModel,
      radioCivAddress: civ,
      controllerCivAddress: c.icomLan.controllerCivAddress,
      clientName: c.icomLan.clientName,
    );

    c.afsk = c.afsk.copyWith(txDelayMs: delay);

    if (enabled != null) {
      if (enabled) {
        c.source = AudioSource.icomLan;
        if (!st.enabledSources.contains(AppState.srcAudio)) {
          await st.toggleSource(AppState.srcAudio, true);
        }
      } else {
        c.source = AudioSource.device;
      }
    }

    await audio.save();
    // TX Delay 是纯发射参数：真的改了才重建调制器（失焦提交会在没改时也触发，
    // 不该无谓重建；采样率/音调等影响收发的另在音频设置页处理）。
    if (delay != oldDelay) audio.applyTxParams();
    if (mounted) setState(() {});
  }

  Future<void> _toggleConnection() async {
    final S s = S.of(context);
    setState(() => _busy = true);
    await _saveConfig();

    try {
      if (audio.connected && audio.usingIcomLan) {
        await audio.disconnect();
        st.adoptDeviceLink(AppState.srcAudio, false);
      } else {
        final err = audio.config.icomLan.validate();
        if (err != null) {
          _toast(err, color: C.orange);
          setState(() => _busy = false);
          return;
        }

        audio.config.source = AudioSource.icomLan;
        if (!st.enabledSources.contains(AppState.srcAudio)) {
          await st.toggleSource(AppState.srcAudio, true);
        }
        await audio.save();

        final conflict = await st.guardDeviceConnect(AppState.srcAudio);
        if (conflict != null) {
          _toast(conflict, color: C.red);
          setState(() => _busy = false);
          return;
        }

        final ok = await audio.connect();
        st.adoptDeviceLink(AppState.srcAudio, ok);
        if (!ok) {
          _toast(s.disconnected, color: C.red);
        }
      }
    } catch (e) {
      _toast('$e', color: C.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _phaseColor(String phase) {
    if (phase.contains('接收') || phase.contains('Receiving')) return C.green;
    if (phase.contains('发射') || phase.contains('Transmitting')) return C.orange;
    if (phase.contains('协商') || phase.contains('认证') || phase.contains('发现')) {
      return C.cyan;
    }
    if (phase.contains('失败') || phase.contains('错误') || phase.contains('拒绝')) {
      return C.red;
    }
    return C.grey;
  }

  @override
  Widget build(BuildContext context) {
    final S s = S.of(context);
    final c = audio.config;
    final isIcomMode = c.source == AudioSource.icomLan;
    final link = audio.icomLanLink;
    final isConnected = audio.connected && isIcomMode;
    // 保留原始（中文）阶段串：判颜色要用它（`_phaseColor` 按中文关键字匹配），
    // 展示文案才走本地化。link 为空时退回从连接态推。
    final rawPhase = link?.phaseLabel;

    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => SettingsPageShell(
        title: s.icomLanTitle,
        subtitle: s.icomTitleSubtitle,
        icon: Icons.wifi_tethering_rounded,
        color: C.cyan,
        body: Column(
          children: [
            // ① 状态与主开关卡片
            _buildStatusCard(s, isIcomMode, isConnected, rawPhase),
            const SizedBox(height: 16),

            // ② 电台网络参数与型号选择
            _buildNetworkCard(s, isIcomMode),
            const SizedBox(height: 16),

            // ③ CI-V 控制与发射参数
            _buildControlCard(s, isIcomMode),
            const SizedBox(height: 16),

            // ④ 电台端配网指引
            _buildGuideCard(s),
            const SizedBox(height: 16),

            // ⑤ 实时链路日志（折叠）
            _buildLogCard(s),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// ① 状态与主开关卡片
  ///
  /// [rawPhase] 是 net 层的原始阶段串（可能为 null，表示链路对象还没建）。
  Widget _buildStatusCard(
      S s, bool isIcomMode, bool isConnected, String? rawPhase) {
    // 颜色判据用原始中文（`_phaseColor` 按中文关键字匹配），展示文案走本地化。
    final statusColor = _phaseColor(rawPhase ?? (isConnected ? '接收' : ''));
    final phaseText = rawPhase == null
        ? (isConnected ? s.connected : s.disconnected)
        : icomPhaseLabel(s, rawPhase);
    final modelName = icomModelName(s, _selectedModel);

    return SettingsSectionCard(
      title: s.icomLinkStatusTitle,
      subtitle:
          isConnected ? s.icomLinkConnected(modelName) : s.icomLinkHandshaking,
      icon: Icons.sensors_rounded,
      color: C.cyan,
      children: [
        SettingsSwitch(
          s.icomLanEnable,
          value: isIcomMode,
          color: C.cyan,
          onChanged: (v) => unawaited(_saveConfig(enabled: v)),
        ),
        SettingsHint(s.icomBindHint(modelName)),
        Divider(height: 1, color: C.border),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                s.icomLinkPhase,
                style: ts(13, c: C.grey),
              ),
              const Spacer(),
              Text(
                phaseText,
                style: ts(13, w: FontWeight.w600, c: statusColor),
              ),
            ],
          ),
        ),
        if (isConnected) ...[
          SettingsRow2(
            s.icomRfStats,
            s.tncStats('${audio.rxFrames}', '${audio.txFrames}'),
            valueColor: C.green,
          ),
          SettingsRow2(
            s.icomAudioSampleRate,
            s.icomAudioFmtValue,
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _toggleConnection,
              icon: Icon(
                isConnected ? Icons.link_off_rounded : Icons.link_rounded,
                size: 18,
              ),
              label: Text(
                _busy
                    ? s.icomProcessing
                    : (isConnected ? s.icomDisconnectRadio : s.icomConnectRadio(modelName)),
                style: ts(13, w: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? C.red.withValues(alpha: 0.15) : C.cyan,
                foregroundColor: isConnected ? C.red : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// ② 电台网络参数与型号选择
  Widget _buildNetworkCard(S s, bool isIcomMode) {
    final modelName = icomModelName(s, _selectedModel);
    return SettingsSectionCard(
      title: s.icomNetworkTitle,
      subtitle: s.icomNetworkSubtitle,
      icon: Icons.wifi_rounded,
      color: C.blue,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.radio_rounded, size: 16, color: C.blue),
                  const SizedBox(width: 6),
                  Text(s.icomModelPreset, style: ts(13, w: FontWeight.w600)),
                  const Spacer(),
                  Text(modelName, style: ts(12, c: C.blue, w: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WlanRadioModel.values.map((m) {
                  final selected = m == _selectedModel;
                  return ChoiceChip(
                    label: Text(icomModelTab(s, m)),
                    selected: selected,
                    selectedColor: C.blue.withValues(alpha: 0.18),
                    backgroundColor: C.greyBg,
                    labelStyle: ts(
                      12,
                      w: selected ? FontWeight.bold : FontWeight.normal,
                      c: selected ? C.blue : C.slate,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedModel = m;
                          if (m != WlanRadioModel.custom) {
                            _civAddr.text = m.defaultCivHex;
                            _port.text = '${m.defaultPort}';
                          }
                        });
                        unawaited(_saveConfig());
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Text(
                icomModelDesc(s, _selectedModel),
                style: ts(11, c: C.grey),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: C.border),
        SettingsInput(
          s.icomLanHost,
          _host,
          hint: s.icomIpHint,
          focusNode: _hostFocus,
          onEditingComplete: () => unawaited(_saveConfig()),
        ),
        SettingsInput(
          s.icomLanPort,
          _port,
          hint: '${_selectedModel.defaultPort}',
          focusNode: _portFocus,
          onEditingComplete: () => unawaited(_saveConfig()),
        ),
        SettingsInput(
          s.icomLanUsername,
          _user,
          hint: s.icomUserHint,
          focusNode: _userFocus,
          onEditingComplete: () => unawaited(_saveConfig()),
        ),
        SettingsInput(
          s.icomLanPassword,
          _pass,
          hint: s.icomPassHint,
          focusNode: _passFocus,
          onEditingComplete: () => unawaited(_saveConfig()),
        ),
        SettingsHint(s.icomCredHint),
      ],
    );
  }

  /// ③ CI-V 控制与发射参数
  Widget _buildControlCard(S s, bool isIcomMode) {
    final c = audio.config;

    return SettingsSectionCard(
      title: s.icomCivTitle,
      subtitle: s.icomCivSubtitle,
      icon: Icons.tune_rounded,
      color: C.indigo,
      children: [
        SettingsSwitch(
          s.kissRfBeacon,
          value: c.rfBeacon,
          color: C.indigo,
          onChanged: (v) {
            c.rfBeacon = v;
            audio.save();
            if (mounted) setState(() {});
          },
        ),
        SettingsHint(s.icomRfBeaconHint),
        Divider(height: 1, color: C.border),
        SettingsInput(
          s.icomTxDelayLabel,
          _txDelay,
          hint: '200',
          focusNode: _delayFocus,
          onEditingComplete: () => unawaited(_saveConfig()),
        ),
        SettingsInput(
          s.icomCivAddrLabel,
          _civAddr,
          hint: _selectedModel.defaultCivHex,
          focusNode: _civFocus,
          onEditingComplete: () => unawaited(_saveConfig()),
        ),
        SettingsRow2(s.icomControllerAddr, s.icomControllerAddrValue),
      ],
    );
  }

  /// ④ 电台端配网指引
  Widget _buildGuideCard(S s) {
    return SettingsSectionCard(
      title: s.icomGuideTitle,
      subtitle: s.icomGuideSubtitle,
      icon: Icons.menu_book_rounded,
      color: C.green,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _guideStep('1', s.icomGuide1Title, s.icomGuide1Body),
              const SizedBox(height: 10),
              _guideStep('2', s.icomGuide2Title, s.icomGuide2Body),
              const SizedBox(height: 10),
              _guideStep('3', s.icomGuide3Title, s.icomGuide3Body),
              const SizedBox(height: 10),
              _guideStep('4', s.icomGuide4Title, s.icomGuide4Body),
            ],
          ),
        ),
      ],
    );
  }

  Widget _guideStep(String num, String title, String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            num,
            style: ts(11, w: FontWeight.bold, c: C.green),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ts(13, w: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(content, style: ts(12, c: C.slate)),
            ],
          ),
        ),
      ],
    );
  }

  /// ⑤ 实时链路日志
  Widget _buildLogCard(S s) {
    final logs = audio.logs;

    return SettingsFold(
      title: s.icomLogTitle,
      subtitle: s.icomLogSubtitle,
      icon: Icons.receipt_long_rounded,
      color: C.slate,
      open: _logOpen,
      onToggle: () => setState(() => _logOpen = !_logOpen),
      children: [
        Container(
          width: double.infinity,
          height: 220,
          padding: const EdgeInsets.all(10),
          color: Colors.black.withValues(alpha: 0.04),
          child: logs.isEmpty
              ? Center(
                  child: Text(s.icomLogEmpty, style: ts(12, c: C.grey)),
                )
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (_, i) => Text(
                    logs[i],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
