import 'package:flutter/material.dart';

import 'cloud_sync.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 云同步的两张卡（长在「服务器」页上，没有自己的一页）───
///
/// 用户：「不要把这些单独列成一页…归入服务器页，统一管理」。地址、账号、同步方式
/// 与云端数据都排在「服务器」页互联网链接那一簇里，与两条链路挨着 ——
/// 「数据存在哪台机器、用谁的账号」本来就是一回事，分成两页反而要来回跳。
///
/// 第一张管「连哪台、用谁的账号、怎么同步」，第二张管「云端现在有什么」。
/// 云端备份不在这儿：上传与取回留在「备份与恢复」页，那页本来就管整份备份的
/// 导出与预览，多一个入口只会让人分不清两份东西。
class CloudSyncCards extends StatefulWidget {
  final AppState state;
  const CloudSyncCards({super.key, required this.state});

  @override
  State<CloudSyncCards> createState() => _CloudSyncCardsState();
}

class _CloudSyncCardsState extends State<CloudSyncCards> {
  final _account = TextEditingController();
  final _password = TextEditingController();
  final _server = TextEditingController();
  bool _busy = false;
  String _err = '';
  Map<String, dynamic>? _remote;

  AppState get st => widget.state;

  @override
  void initState() {
    super.initState();
    _account.text = st.syncAccount;
    _server.text = st.syncServer;
    if (st.syncToken.isNotEmpty) _refresh();
  }

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    _server.dispose();
    super.dispose();
  }

  /// 失败原因一律回原因码，文案在这一层选。
  String _errText(S s, String code) {
    if (code == 'need-login') return s.syncNeedLogin;
    if (code == 'no-http') return s.syncNoWeb;
    if (code == 'busy') return s.syncBusy;
    if (code == 'missing-account') return '${s.syncAccount} / ${s.syncPassword}';
    return '${s.syncFailed}（$code）';
  }

  String _lastText(S s) {
    final stamps = [st.syncMsgAt, st.syncPullAt, st.syncTrackAt]
        .where((v) => v > 0)
        .toList();
    if (stamps.isEmpty) return s.syncNever;
    final at = DateTime.fromMillisecondsSinceEpoch(
        stamps.reduce((a, b) => a > b ? a : b));
    final now = DateTime.now();
    final hm =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      return hm;
    }
    return '${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')} $hm';
  }

  Future<void> _refresh() async {
    if (st.syncToken.isEmpty) return;
    try {
      final data = await st.syncState();
      if (mounted) setState(() => _remote = data);
    } on SyncException catch (error) {
      if (mounted) setState(() => _err = error.code);
    } catch (_) {
      if (mounted) setState(() => _err = 'network');
    }
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _err = '';
    });
    st.setSyncAccount(_account.text);
    st.setSyncPassword(_password.text);
    final code = await st.syncLogin();
    if (!mounted) return;
    setState(() => _busy = false);
    if (code.isNotEmpty) {
      setState(() => _err = code);
      return;
    }
    _password.clear();
    await _refresh();
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    await st.syncLogout();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _remote = null;
    });
  }

  Future<void> _runNow() async {
    final s = S.of(context);
    setState(() {
      _busy = true;
      _err = '';
    });
    final code = await st.syncNow();
    if (!mounted) return;
    setState(() => _busy = false);
    if (code.isNotEmpty) {
      setState(() => _err = code);
      return;
    }
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.syncRunDone), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _clearCloud() async {
    final s = S.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.syncClear, style: T.h2),
        content: Text(s.syncClearAsk, style: ts(12, c: C.slate, h: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel, style: ts(13, c: C.slate)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.syncClear, style: ts(13)),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    setState(() => _busy = true);
    final code = await st.syncClearCloud();
    if (!mounted) return;
    setState(() => _busy = false);
    if (code.isNotEmpty) {
      setState(() => _err = code);
      return;
    }
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.syncClearDone), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => Column(children: [
        _syncCard(s),
        const SizedBox(height: 16),
        _dataCard(s),
      ]),
    );
  }

  /// ① 这一张：数据在哪台机器、用谁的账号、怎么同步。
  Widget _syncCard(S s) {
    final logged = st.syncToken.isNotEmpty;
    return SettingsSectionCard(
      title: s.syncTitle,
      subtitle: s.syncLead,
      icon: Icons.cloud_sync_rounded,
      color: C.blue,
      children: [
        SettingsInput(
          s.syncServer,
          _server,
          onChanged: st.setSyncServer,
          hint: 'http://host:8899',
        ),
        // 生效地址写出来：空着的时候它就是项目自带那台，免得用户以为没配就没处去
        SettingsRow2(s.syncServerNow, st.syncBase),
        if (logged)
          SettingsRow2(
            s.syncAccount,
            st.syncCall.isEmpty ? s.syncLoggedIn('-') : s.syncLoggedIn(st.syncCall),
          )
        else ...[
          SettingsInput(
            s.syncAccount,
            _account,
            onChanged: st.setSyncAccount,
            hint: s.syncAccount,
          ),
          _passwordRow(s),
          SettingsHint(s.syncAccountHint),
        ],
        _loginRow(s, logged: logged),
        SettingsChoice<String>(
          s.syncMode,
          value: st.syncMode,
          options: AppState.syncModes,
          labelOf: (v) => v == 'auto'
              ? s.syncModeAuto
              : (v == 'manual' ? s.syncModeManual : s.syncModeOff),
          onChanged: st.setSyncMode,
        ),
        SettingsHint(s.syncModeAutoHint),
        // 明文这一条必须留着：口令与报文都会经过网络，用户有权先知道
        SettingsHint(s.syncPlainHint, color: C.orange),
      ],
    );
  }

  /// 口令单独一行：`SettingsInput` 不带隐藏输入，而口令该遮着。
  Widget _passwordRow(S s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
        child: Row(
          children: [
            Text(s.syncPassword, style: ts(12, c: C.slate)),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _password,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                textAlign: TextAlign.right,
                style: ts(13, w: FontWeight.w600),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  hintText: '••••••',
                  hintStyle: ts(12, c: C.greyLight, w: FontWeight.w400),
                  filled: true,
                  fillColor: C.bgSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: C.border, width: 0.4),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: C.border, width: 0.4),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: C.blue, width: 0.8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _loginRow(S s, {required bool logged}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: logged ? C.slate : C.blue,
                disabledBackgroundColor: C.greyBg,
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              onPressed: _busy ? null : (logged ? _logout : _login),
              child: Text(logged ? s.syncLogout : s.syncLogin, style: ts(13)),
            ),
          ),
        ],
      ),
    );
  }

  /// ② 这一张：云端现在有什么，两个动手的按钮。
  Widget _dataCard(S s) {
    final ready = st.syncToken.isNotEmpty;
    final msgs = (_remote?['messages'] as Map?) ?? const {};
    final tracks = (_remote?['tracks'] as Map?) ?? const {};
    final msgCount = (msgs['count'] as num?)?.toInt() ?? 0;
    final days = (tracks['days'] as num?)?.toInt() ?? 0;
    final points = (tracks['points'] as num?)?.toInt() ?? 0;
    return SettingsSectionCard(
      title: s.syncCloudData,
      icon: Icons.cloud_done_rounded,
      color: C.blue,
      children: [
        SettingsRow2(
          s.syncMessages,
          ready ? s.syncMsgSummary('$msgCount') : '—',
        ),
        SettingsRow2(
          s.syncTracks,
          ready ? s.syncTrackSummary('$days', '$points') : '—',
        ),
        SettingsRow2(s.syncLastAt, _lastText(s)),
        if (_err.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
            child: Text(_errText(s, _err), style: ts(12, c: C.red, h: 1.4)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: C.blue,
                    disabledBackgroundColor: C.greyBg,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: (_busy || !st.syncReady) ? null : _runNow,
                  icon: _busy
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: C.white,
                          ),
                        )
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: Text(s.syncNow, style: ts(12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: BorderSide(color: C.orange.withValues(alpha: 0.4)),
                  ),
                  onPressed: (_busy || !ready) ? null : _clearCloud,
                  icon: Icon(Icons.delete_outline_rounded, size: 16, color: C.orange),
                  label: Text(s.syncClear, style: ts(12, c: C.orange)),
                ),
              ),
            ],
          ),
        ),
        SettingsHint(s.syncClearHint),
        SettingsHint(s.syncBackupElsewhere),
      ],
    );
  }
}
