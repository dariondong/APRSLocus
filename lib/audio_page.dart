import 'dart:async';

import 'package:flutter/material.dart';

import 'audio.dart';
import 'l10n/app_localizations.dart';
import 'link_test_card.dart';
import 'settings_widgets.dart';
import 'tnc_page.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 音频页：声卡 TNC（AFSK 1200）的参数、电平与排查 ───
///
/// 与设备页（TNC）并列：两者都是「射频数据来源」的具体实现，只是链路不同 ——
/// 一个走 KISS over 蓝牙/串口，一个走 AFSK 音频。分页而不是塞进同一页，
/// 是因为参数集合几乎没有交集（KISS 参数 vs 采样率/音调），混在一起反而难找。
///
/// 「链路自检」卡片两侧共用（[LinkTestCard]），保证排查路径一致。
class AudioSettingsPage extends StatefulWidget {
  final AppState state;
  const AudioSettingsPage({super.key, required this.state});

  @override
  State<AudioSettingsPage> createState() => _AudioSettingsPageState();
}

class _AudioSettingsPageState extends State<AudioSettingsPage> {
  late final TextEditingController _sampleRate;
  late final TextEditingController _baud;
  late final TextEditingController _mark;
  late final TextEditingController _space;
  late final TextEditingController _txDelay;
  late final TextEditingController _path;
  late final TextEditingController _maxFrame;
  late final TextEditingController _csma;
  final TextEditingController _wavPath = TextEditingController();
  final TextEditingController _wavTnc2 = TextEditingController();

  bool _busy = false;
  bool _supported = true;
  String _wavOut = '';

  AppState get st => widget.state;
  AudioLink get audio => widget.state.audio;

  @override
  void initState() {
    super.initState();
    final c = audio.config;
    _sampleRate = TextEditingController(text: '${c.afsk.sampleRate}');
    _baud = TextEditingController(text: '${c.afsk.baud.round()}');
    _mark = TextEditingController(text: '${c.afsk.markHz.round()}');
    _space = TextEditingController(text: '${c.afsk.spaceHz.round()}');
    _txDelay = TextEditingController(text: '${c.afsk.txDelayMs}');
    _path = TextEditingController(text: c.path);
    _maxFrame = TextEditingController(text: '${c.maxFrame}');
    _csma = TextEditingController(text: '${c.csmaWaitMs}');
    _wavTnc2.text = diagSampleFrame;
    unawaited(_probe());
  }

  @override
  void dispose() {
    for (final c in [
      _sampleRate, _baud, _mark, _space, _txDelay,
      _path, _maxFrame, _csma, _wavPath, _wavTnc2,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _probe() async {
    final ok = await audio.supported();
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

  double _doubleOf(TextEditingController c, double fallback) =>
      double.tryParse(c.text.trim()) ?? fallback;

  /// 收集输入 → config → 持久化。采样率/音调变化时必须重建调制解调器，
  /// 连接中还要重开采集（[AudioLink.applyParams] 负责）。
  Future<void> _collect({bool restart = false}) async {
    final c = audio.config;
    final oldRate = c.afsk.sampleRate;
    c.afsk = c.afsk.copyWith(
      sampleRate: _intOf(_sampleRate, oldRate).clamp(8000, 192000),
      baud: _doubleOf(_baud, c.afsk.baud).clamp(300, 9600),
      markHz: _doubleOf(_mark, c.afsk.markHz).clamp(300, 4000),
      spaceHz: _doubleOf(_space, c.afsk.spaceHz).clamp(300, 4000),
      txDelayMs: _intOf(_txDelay, c.afsk.txDelayMs).clamp(0, 2550),
    );
    c.path = _path.text.trim();
    c.maxFrame = _intOf(_maxFrame, c.maxFrame).clamp(16, 512);
    c.csmaWaitMs = _intOf(_csma, c.csmaWaitMs).clamp(0, 10000);
    _sampleRate.text = '${c.afsk.sampleRate}';
    _baud.text = '${c.afsk.baud.round()}';
    await audio.save();
    if (restart || c.afsk.sampleRate != oldRate) {
      await audio.applyParams();
      st.reloadUi();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleLink() async {
    setState(() => _busy = true);
    if (audio.connected) {
      await audio.disconnect();
      st.connected = false;
      st.setConnStatus(ConnPhase.manual);
    } else {
      // 先取好文案：await 之后 context 可能已失效（use_build_context_synchronously）
      final l = AppLocalizations.of(context);
      await _collect();
      if (!await audio.requestPermissions()) {
        setState(() => _busy = false);
        _toast(l.audioNeedPermission, color: C.red);
        return;
      }
      final ok = await audio.connect();
      st.connected = ok;
      st.setConnStatus(
        ok ? ConnPhase.audioConnected : ConnPhase.retryAudio,
        arg: ok ? '${audio.config.afsk.sampleRate}Hz' : audio.lastError,
        seconds: ok ? 0 : 8,
      );
      if (!ok) {
        _toast('${l.connectFailedCheckConfig} ${audio.lastDetail}',
            color: C.red);
      }
    }
    st.reloadUi();
    if (mounted) setState(() => _busy = false);
  }

  /// 解码 WAV 文件（离线收）
  Future<void> _decodeWav() async {
    final l = AppLocalizations.of(context);
    final path = _wavPath.text.trim();
    if (path.isEmpty) {
      _toast(l.audioWavPath, color: C.orange);
      return;
    }
    setState(() => _busy = true);
    final (lines, err) = await audio.decodeWavFile(path);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _wavOut = err != null
          ? l.audioWavFailed(err)
          : (lines.isEmpty
              ? l.audioWavNone
              : '${l.audioWavFound(lines.length)}\n\n${lines.join('\n')}');
    });
  }

  /// 导出报文为 WAV（离线发）
  Future<void> _exportWav() async {
    final l = AppLocalizations.of(context);
    final path = _wavPath.text.trim();
    if (path.isEmpty || _wavTnc2.text.trim().isEmpty) {
      _toast(l.audioWavPath, color: C.orange);
      return;
    }
    setState(() => _busy = true);
    final err = await audio.encodeWavFile(path, _wavTnc2.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _wavOut = err != null ? l.audioWavFailed(err) : l.audioWavWritten(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => SettingsPageShell(
        title: s.audioSettings,
        subtitle: s.audioSettingsSubtitle,
        icon: Icons.graphic_eq_rounded,
        color: C.cyan,
        body: Column(children: [
          DataSourceCard(state: st, extra: s.dataSourceSwitchHint),
          const SizedBox(height: 16),
          _captureCard(s),
          const SizedBox(height: 16),
          _paramsCard(s),
          const SizedBox(height: 16),
          _txCard(s),
          const SizedBox(height: 16),
          _wavCard(s),
          const SizedBox(height: 16),
          LinkTestCard(state: st, source: LinkTestSource.audio),
          const SizedBox(height: 16),
          _logCard(s),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  /// ① 采集：状态 + 电平表 + 开关
  Widget _captureCard(S s) {
    final level = audio.level.clamp(0.0, 1.0);
    return SettingsSectionCard(
      title: s.audioCaptureTitle,
      subtitle: s.audioCaptureDesc,
      icon: Icons.mic_rounded,
      color: C.cyan,
      children: [
        SettingsRow2(
          s.audioBackend,
          _supported ? audio.backendName : s.audioUnsupported,
          valueColor: _supported ? C.ink : C.orange,
        ),
        SettingsRow2(
          s.connection,
          audio.connected ? s.connected : s.disconnected,
          valueColor: audio.connected ? C.green : C.slate,
        ),
        SettingsRow2(
          s.audioSynced,
          audio.synced ? s.audioSynced : s.audioUnlocked,
          valueColor: audio.synced ? C.green : C.grey,
        ),
        // 电平表：实时刷新（tick 每秒 1 次 + 数据到达时的节流通知）
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(s.audioLevel, style: ts(12, c: C.slate)),
                const Spacer(),
                Text('${(level * 100).round()}%',
                    style: ts(11, c: C.grey)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: level,
                  minHeight: 7,
                  backgroundColor: C.greyBg,
                  valueColor: AlwaysStoppedAnimation(
                    audio.channelBusy ? C.orange : C.cyan,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(s.audioLevelTip, style: ts(10, c: C.grey, h: 1.35)),
            ],
          ),
        ),
        // 解码中止次数只在真的发生时显示：正常信道它是 0，写在常驻行里
        // 反而会让人以为「一直有错误」
        if (audio.badFrames > 0)
          SettingsHint(s.audioBadFrames(audio.badFrames), color: C.orange),
        SettingsRow2(
          s.audioStatRx(audio.rxFrames),
          s.audioStatTx(audio.txFrames),
        ),
        if (audio.droppedDuringTx > 0)
          SettingsHint(s.audioStatDrop(audio.droppedDuringTx)),
        if (!_supported) SettingsHint(s.audioUnsupported, color: C.orange),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy || !_supported ? null : _toggleLink,
                icon: Icon(
                  audio.connected
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline,
                  size: 16,
                ),
                label: Text(audio.connected ? s.audioCaptureStop : s.audioCaptureStart,
                    style: ts(12, c: Colors.white, w: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: audio.connected ? C.red : C.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await audio.restart();
                        st.connected = audio.connected;
                        st.reloadUi();
                        if (mounted) setState(() => _busy = false);
                      },
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: Text(s.audioRestart, style: ts(12, w: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.orange,
                  side: BorderSide(color: C.orange.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  /// ② 调制解调参数
  Widget _paramsCard(S s) {
    return SettingsSectionCard(
      title: s.audioSettings,
      subtitle: s.audioSettingsSubtitle,
      icon: Icons.tune_rounded,
      color: C.cyan,
      children: [
        SettingsInput(s.audioSampleRate, _sampleRate,
            tip: s.audioSampleRateTip,
            onEditingComplete: () => unawaited(_collect(restart: true))),
        SettingsInput(s.audioBaud, _baud,
            tip: s.audioBaudTip,
            onEditingComplete: () => unawaited(_collect(restart: true))),
        SettingsInput(s.audioToneMark, _mark,
            tip: s.audioMarkTip,
            onEditingComplete: () => unawaited(_collect(restart: true))),
        SettingsInput(s.audioToneSpace, _space,
            tip: s.audioSpaceTip,
            onEditingComplete: () => unawaited(_collect(restart: true))),
        SettingsInput(s.audioTxDelayLabel, _txDelay,
            tip: s.audioTxDelayTip,
            onEditingComplete: () => unawaited(_collect(restart: true))),
        SettingsHint(s.audioSampleRateTip),
      ],
    );
  }

  /// ③ 发射
  Widget _txCard(S s) {
    return SettingsSectionCard(
      title: s.audioTxTitle,
      subtitle: s.audioTxDesc,
      icon: Icons.warning_amber_rounded,
      color: C.orange,
      children: [
        SettingsSwitch(s.audioTxEnabled, value: audio.config.txEnabled,
            color: C.orange, onChanged: (v) async {
          audio.config.txEnabled = v;
          await audio.save();
          st.reloadUi();
          if (mounted) setState(() {});
        }),
        SettingsHint(s.audioTxEnabledTip, color: C.orange),
        SettingsSwitch(s.kissRfBeacon, value: audio.config.rfBeacon,
            color: C.orange, onChanged: (v) async {
          audio.config.rfBeacon = v;
          await audio.save();
          st.reloadUi();
          if (mounted) setState(() {});
        }),
        SettingsHint(s.kissRfBeaconTip, color: C.orange),
        SettingsInput(s.audioCsmaWait, _csma,
            tip: s.audioCsmaWaitTip,
            onChanged: (_) => unawaited(_collect())),
        SettingsInput(s.kissRfPath, _path,
            tip: s.kissRfPathTip,
            onChanged: (_) => unawaited(_collect())),
        SettingsInput(s.kissMaxFrame, _maxFrame,
            tip: s.kissMaxFrameTip,
            onChanged: (_) => unawaited(_collect())),
        SettingsSwitch(s.kissAutoAck, value: audio.config.autoAck,
            color: C.cyan, onChanged: (v) async {
          audio.config.autoAck = v;
          await audio.save();
          if (mounted) setState(() {});
        }),
        SettingsHint(s.kissAutoAckTip),
        SettingsSwitch(s.kissAutoReconnect, value: audio.config.autoReconnect,
            color: C.green, onChanged: (v) async {
          audio.config.autoReconnect = v;
          await audio.save();
          if (mounted) setState(() {});
        }),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: audio.transmitting
                  ? () async {
                      await audio.stopTx();
                      if (mounted) setState(() {});
                    }
                  : null,
              icon: const Icon(Icons.stop_rounded, size: 16),
              label: Text(s.audioStopTx, style: ts(12, w: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.red,
                side: BorderSide(color: C.red.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// ④ WAV 文件模式
  Widget _wavCard(S s) {
    return SettingsSectionCard(
      title: s.audioWavTitle,
      subtitle: s.audioWavDesc,
      icon: Icons.folder_open_rounded,
      color: C.indigo,
      children: [
        SettingsInput(s.audioWavPath, _wavPath, tip: s.audioWavDesc),
        SettingsInput(s.audioWavTnC2, _wavTnc2, tip: s.audioTnc2Tip),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _decodeWav,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text(s.audioWavDecodeAction, style: ts(12)),
                style: OutlinedButton.styleFrom(foregroundColor: C.indigo),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _exportWav,
                icon: const Icon(Icons.upload_rounded, size: 16),
                label: Text(s.audioWavExportAction, style: ts(12)),
                style: OutlinedButton.styleFrom(foregroundColor: C.green),
              ),
            ),
          ]),
        ),
        if (_wavOut.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: C.bgSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_wavOut,
                style: ts(10.5, c: C.slate, h: 1.4)
                    .copyWith(fontFamily: 'monospace')),
          ),
      ],
    );
  }

  /// ⑤ 日志
  Widget _logCard(S s) {
    final logs = audio.logs;
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

/// WAV 导出输入框的默认示例报文（与自检用的一致，便于对照）
const String diagSampleFrame = 'BG7LZQ-9>APALOC:>APRSlocus AUDIO TEST';
