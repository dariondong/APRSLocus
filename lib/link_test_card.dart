import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'diag.dart';
import 'l10n/app_localizations.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';

/// ─── 链路自检卡片（TNC / 音频共用）───
///
/// 为什么做成共用组件：两个射频来源的排查路径其实一样（协议 → 平台 → 权限 →
/// 设备 → 收发），各写一份迟早出现「TNC 页能测、音频页不能测」这类不一致。
///
/// 使用方式：`LinkTestCard(state: st, source: LinkTestSource.tnc)`。
enum LinkTestSource { tnc, audio }

class LinkTestCard extends StatefulWidget {
  final AppState state;
  final LinkTestSource source;

  const LinkTestCard({super.key, required this.state, required this.source});

  @override
  State<LinkTestCard> createState() => _LinkTestCardState();
}

class _LinkTestCardState extends State<LinkTestCard> {
  DiagResult? _result;
  bool _running = false;

  AppState get st => widget.state;
  bool get _isAudio => widget.source == LinkTestSource.audio;

  Future<void> _run() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _running = true;
      _result = null;
    });
    var r = DiagResult(const []);
    try {
      if (_isAudio) {
        final a = st.audio;
        r = r.plus(LinkDiag.protocolLoopbackAudio(l, sampleRate: a.config.afsk.sampleRate));
        r = r.plus(await LinkDiag.audioPlatform(l, a));
        r = r.plus(await LinkDiag.audioPermission(l, a));
        r = r.plus(await LinkDiag.audioCapture(l, a));
        r = r.plus(await LinkDiag.audioSpeaker(l, a));
        r = r.plus(await LinkDiag.audioFileIo(l, await _tempDir()));
      } else {
        final t = st.tnc;
        r = r.plus(LinkDiag.protocolLoopbackTnc(l));
        // TNC 传输层没有「后端」概念（KISS over 蓝牙/串口），用协议名标注即可
        r = r.plus(await LinkDiag.tncPlatform(l, t.supported, 'KISS'));
      }
    } catch (e) {
      // 自检自身异常不应把界面卡在「测试中」
      r = r.plus(DiagItem(l.diagTitle, '$e', ok: false));
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = r;
    });
  }

  Future<String> _tempDir() async {
    try {
      final d = await getTemporaryDirectory();
      return d.path;
    } catch (_) {
      return '/tmp'; // 桌面兜底；Android 上 getTemporaryDirectory 恒可用
    }
  }

  Future<void> _testTx() async {
    final l = AppLocalizations.of(context);
    final err = st.sendTestFrame();
    if (!mounted) return;
    final msg = err == null
        ? l.testTxSent
        : l.testTxFail(linkErrorText(l, err));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: err == null ? C.green : C.red,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = _result;
    return SettingsSectionCard(
      title: l.diagTitle,
      subtitle: l.diagSubtitle,
      icon: Icons.health_and_safety_rounded,
      color: C.cyan,
      children: [
        // 结果列表（跑过才显示）
        if (r != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in r.items) _row(item),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(
                    r.ok ? Icons.check_circle_rounded : Icons.error_rounded,
                    size: 14,
                    color: r.ok ? C.green : C.red,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    [
                      l.diagPassed(r.passed),
                      if (r.failures > 0) l.diagFailed(r.failures),
                    ].join(' · '),
                    style: ts(11,
                        c: r.ok ? C.green : C.red, w: FontWeight.w700),
                  ),
                ]),
              ],
            ),
          )
        else
          SettingsHint(l.diagHint),
        if (_isAudio) SettingsHint(l.audioLoopbackHint),
        // 操作行：开始自检 + 测试发射
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _running ? null : _run,
                icon: _running
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 16),
                label: Text(_running ? l.diagRunning : l.diagRun,
                    style: ts(12, c: Colors.white, w: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: C.cyan,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: st.connected ? _testTx : null,
                icon: const Icon(Icons.wifi_tethering_rounded, size: 16),
                label: Text(l.testTxAction, style: ts(12, w: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.orange,
                  side: BorderSide(color: C.orange.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ]),
        ),
        SettingsHint(
          st.connected ? l.testTxDesc : l.testTxNeedsConnect,
          color: st.connected ? C.orange : C.grey,
          icon: Icons.warning_amber_rounded,
        ),
        SettingsHint(l.testTxHint, color: C.red, icon: Icons.campaign_rounded),
      ],
    );
  }

  Widget _row(DiagItem item) {
    final col = item.ok ? (item.warn ? C.orange : C.green) : C.red;
    final icon = item.ok
        ? (item.warn ? Icons.info_rounded : Icons.check_circle_rounded)
        : Icons.cancel_rounded;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: col),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: ts(12, w: FontWeight.w700, c: col)),
                const SizedBox(height: 1),
                Text(item.detail, style: ts(10, c: C.slate, h: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
