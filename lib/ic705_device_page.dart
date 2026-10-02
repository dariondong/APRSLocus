// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'audio.dart';
import 'net/icom_lan_settings.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── IC-705 Wi-Fi 直连设备页（独立一级设备页）───
///
/// 专为 IC-705 局域网直连打造的专属控制面板：
/// ① 电台连接状态与实时链路阶段（未连接 / 认证中 / 协商中 / 接收中 / 传输中）
/// ② 一键直连开关与连接/断开控制
/// ③ 电台网络参数（电台 IP / 控制端口 / Network User 用户名与密码）
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

  bool _busy = false;
  bool _logOpen = false;

  AppState get st => widget.state;
  AudioLink get audio => widget.state.audio;

  @override
  void initState() {
    super.initState();
    final c = audio.config;
    _host = TextEditingController(text: c.icomLan.host);
    _port = TextEditingController(text: '${c.icomLan.controlPort}');
    _user = TextEditingController(text: c.icomLan.username);
    _pass = TextEditingController(text: c.icomLan.password);
    _civAddr = TextEditingController(
      text: '0x${c.icomLan.radioCivAddress.toRadixString(16).toUpperCase()}',
    );
    _txDelay = TextEditingController(text: '${c.afsk.txDelayMs}');
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _pass.dispose();
    _civAddr.dispose();
    _txDelay.dispose();
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
    final civ = _parseInt(_civAddr, 0xA4).clamp(0x01, 0xFF);
    final delay = _parseInt(_txDelay, 200).clamp(0, 2000);

    c.icomLan = IcomLanConfig(
      host: _host.text.trim(),
      controlPort: _parseInt(_port, 50001).clamp(1, 65533),
      username: _user.text.trim(),
      password: _pass.text,
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
    final phase = link?.phaseLabel ?? (isConnected ? s.connected : s.disconnected);

    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => SettingsPageShell(
        title: s.icomLanTitle,
        subtitle: '局域网直连 IC-705 电台，收发 12 kHz PCM 音频与 CI-V 控制',
        icon: Icons.wifi_tethering_rounded,
        color: C.cyan,
        body: Column(
          children: [
            // ① 状态与主开关卡片
            _buildStatusCard(s, isIcomMode, isConnected, phase),
            const SizedBox(height: 16),

            // ② 电台网络参数
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
            const SizedBox(height: 16),

            // ⑥ 开源与合规说明
            _buildOpenSourceCard(s),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// ① 状态与主开关卡片
  Widget _buildStatusCard(S s, bool isIcomMode, bool isConnected, String phase) {
    final statusColor = _phaseColor(phase);

    return SettingsSectionCard(
      title: '电台链路状态',
      subtitle: isConnected ? '已与 IC-705 建立高速局域网直连' : '未连接或正在握手',
      icon: Icons.sensors_rounded,
      color: C.cyan,
      children: [
        SettingsSwitch(
          s.icomLanEnable,
          value: isIcomMode,
          color: C.cyan,
          onChanged: (v) => unawaited(_saveConfig(enabled: v)),
        ),
        SettingsHint('开启后，APRS 音频收发数据源将直接绑定至 IC-705 局域网直连'),
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
                '链路阶段',
                style: ts(13, c: C.grey),
              ),
              const Spacer(),
              Text(
                phase,
                style: ts(13, w: FontWeight.w600, c: statusColor),
              ),
            ],
          ),
        ),
        if (isConnected) ...[
          SettingsRow2(
            '射频收发统计',
            s.tncStats('${audio.rxFrames}', '${audio.txFrames}'),
            valueColor: C.green,
          ),
          SettingsRow2(
            '音频采样率',
            '12000 Hz (LPCM 16-bit 单声道)',
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
                    ? '处理中...'
                    : (isConnected ? '断开电台连接' : '立即连接 IC-705'),
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

  /// ② 电台网络参数
  Widget _buildNetworkCard(S s, bool isIcomMode) {
    return SettingsSectionCard(
      title: '电台网络参数',
      subtitle: '设置 IC-705 的局域网 IP 与 Network User 凭据',
      icon: Icons.wifi_rounded,
      color: C.blue,
      children: [
        SettingsInput(
          s.icomLanHost,
          _host,
          hint: '192.168.1.143',
          onEditingComplete: () => unawaited(_saveConfig()),
        ),
        SettingsInput(
          s.icomLanPort,
          _port,
          hint: '50001',
          onEditingComplete: () => unawaited(_saveConfig()),
        ),
        SettingsInput(
          s.icomLanUsername,
          _user,
          hint: '114514',
          onEditingComplete: () => unawaited(_saveConfig()),
        ),
        SettingsInput(
          s.icomLanPassword,
          _pass,
          hint: 'aa1919810',
          onEditingComplete: () => unawaited(_saveConfig()),
        ),
        SettingsHint('提示：用户名和密码必须与 IC-705 电台内 Network User Setting 完全一致。'),
      ],
    );
  }

  /// ③ CI-V 控制与发射参数
  Widget _buildControlCard(S s, bool isIcomMode) {
    final c = audio.config;

    return SettingsSectionCard(
      title: 'CI-V 控制与发射设置',
      subtitle: 'PTT 自动控制、前导延时与信标参数',
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
        SettingsHint('是否允许通过电台射频自动周期发射信标（半双工，发射时自动静默监听）。'),
        Divider(height: 1, color: C.border),
        SettingsInput(
          '发射前导延迟 (TX Delay, ms)',
          _txDelay,
          hint: '200',
          onEditingComplete: () => unawaited(_saveConfig()),
        ),
        SettingsInput(
          '电台 CI-V 地址 (十六进制)',
          _civAddr,
          hint: '0xA4',
          onEditingComplete: () => unawaited(_saveConfig()),
        ),
        SettingsRow2('控制器地址', '0xE0 (默认)'),
      ],
    );
  }

  /// ④ 电台端配网指引
  Widget _buildGuideCard(S s) {
    return SettingsSectionCard(
      title: '电台设置指引',
      subtitle: '在 IC-705 电台上的必要准备步骤',
      icon: Icons.menu_book_rounded,
      color: C.green,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _guideStep(
                '1',
                '网络连接',
                '在电台菜单进入 MENU → SET → WLAN Set → Connection Type，选择 Connect to Network 连接家用路由 Wi-Fi，或选择 Access Point 开启热点由手机直连。',
              ),
              const SizedBox(height: 10),
              _guideStep(
                '2',
                '添加网络用户',
                '进入 WLAN Set → Network User Setting，添加一个用户（设置好用户名和密码），并开启允许连接。',
              ),
              const SizedBox(height: 10),
              _guideStep(
                '3',
                '确认 CI-V 地址',
                '进入 MENU → SET → Connectors → CI-V，确保 CI-V Address 设为 A4h（默认值）。',
              ),
              const SizedBox(height: 10),
              _guideStep(
                '4',
                '设置模式与频率',
                '将电台频率切换至当地 APRS 频率（如 144.640 MHz），模式设为 FM 或 FM-D。',
              ),
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
      title: '电台通信诊断日志',
      subtitle: '查看 IC-705 局域网控制包与 CI-V 通信记录',
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
                  child: Text('暂无通信日志', style: ts(12, c: C.grey)),
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

  /// ⑥ 开源许可与仓库链接
  Widget _buildOpenSourceCard(S s) {
    return SettingsSectionCard(
      title: '开源与合规说明',
      subtitle: '遵循 GNU General Public License v3.0 (GPL-3.0) 协议',
      icon: Icons.code_rounded,
      color: C.blue,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IC-705 Wi-Fi 直连功能（12 kHz PCM 音频收发与 CI-V 控制）基于 APRSLocus 与 aprsdroid mod 开发，遵循 GPL-3.0 协议开源。所有修改均可查阅并获取完整源代码。',
                style: ts(12, c: C.slate, h: 1.5),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/nimenhagg/APRSLocus-Customize'),
                  mode: LaunchMode.externalApplication,
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: C.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new_rounded, size: 16, color: C.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '查看 IC-705 适配分支源码 (GitHub Fork)',
                          style: ts(12, w: FontWeight.w600, c: C.blue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 16, color: C.blue),
                    ],
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
