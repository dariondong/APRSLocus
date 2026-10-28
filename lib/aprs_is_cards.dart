import 'dart:async';

import 'package:flutter/material.dart';

import 'input_history.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── APRS-IS 这条链路的卡 ───
///
/// 与 `AcnCards`（lib/acn_cards.dart）一一对应：开关、连接状态、地址、端口、
/// passcode、发射圆点、WebSocket 地址，一张卡说清一条 TCP 登录。
/// 「设置 → 服务器」一级只摆两条链路的入口，这张卡落在 APRS-IS 自己那一页
/// （`AprsIsServerPage`），另一条链路在 `AcnLinkPage`。
class AprsIsCards extends StatefulWidget {
  final AppState state;
  const AprsIsCards({super.key, required this.state});

  @override
  State<AprsIsCards> createState() => _AprsIsCardsState();
}

class _AprsIsCardsState extends State<AprsIsCards> {
  late final TextEditingController _server;

  /// 服务器输入框的焦点：**离开时**把这次连的地址记进历史（见 lib/input_history.dart）。
  final _serverFocus = FocusNode();
  late final TextEditingController _port;
  late final TextEditingController _ws;
  late final TextEditingController _pass;

  /// 保存进页面时的值：只用来判断「改过了、要重连」，不参与连接
  late final String _origServer;
  late final int _origPort;
  late final String _origPass;
  late final String? _origWs;
  bool _configDirty = false;

  /// 落盘防抖：地址是一个字一个字敲出来的，每敲一下就写一遍整份偏好没必要；
  /// 但**必须**写 —— 只改内存里的 `aprs.server` 的话，退出页面就丢了。
  Timer? _saveTimer;

  AppState get st => widget.state;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: st.aprs.server);
    _serverFocus.addListener(_onServerFocus);
    _port = TextEditingController(text: '${st.aprs.port}');
    _ws = TextEditingController(text: st.aprs.wsUrl ?? '');
    _pass = TextEditingController(text: st.aprs.passcode);
    _origServer = st.aprs.server;
    _origPort = st.aprs.port;
    _origPass = st.aprs.passcode;
    _origWs = st.aprs.wsUrl;
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _serverFocus.removeListener(_onServerFocus);
    _serverFocus.dispose();
    _server.dispose();
    _port.dispose();
    _ws.dispose();
    _pass.dispose();
    super.dispose();
  }

  /// 输入框失焦时把这次填的地址记进历史（`onChanged` 里记就会变成逐字母的记录）。
  void _onServerFocus() {
    if (_serverFocus.hasFocus) return;
    st.rememberInput(InputHistory.server, _server.text);
  }

  /// 从历史里挑一台：写回输入框与配置。
  ///
  /// 程序赋值不会触发 `onChanged`，所以配置与「配置已改」提示要在这里补上一遍，
  /// 否则挑完历史后页面还以为什么都没改。
  void _pickServer(String v) {
    _server.text = v;
    st.aprs.server = v.trim();
    _checkConfigDirty();
    _save();
    setState(() {});
  }

  /// 改完参数就把当前值写进偏好（防抖 400ms）。以前这里只改内存、不落盘，
  /// 表现就是「服务器地址填了、退出再进来又是空的」。
  void _save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), st.persist);
  }

  void _checkConfigDirty() {
    final dirty = st.aprs.server != _origServer ||
        st.aprs.port != _origPort ||
        st.aprs.passcode != _origPass ||
        st.aprs.wsUrl != _origWs;
    if (dirty != _configDirty) {
      setState(() => _configDirty = dirty);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => _linkCard(context),
    );
  }

  /// 这张链路卡：连接状态 → 服务器参数 → 配置变更提示。
  Widget _linkCard(BuildContext context) {
    return SettingsSectionCard(
      title: S.of(context).connectionCard2,
      subtitle: S.of(context).aprsIsCardSubtitle,
      icon: Icons.dns_rounded,
      color: C.purple,
      children: [
        // 这条链路的开关就摆在自己卡里，与 APRSNETCN 那一张一个口径。
        SettingsSwitch(
          S.of(context).dataSourceAprsIs,
          value: st.aprsIsOn,
          color: C.purple,
          onChanged: (v) => st.toggleSource(AppState.srcAprsIs, v),
        ),
        SettingsRow2(S.of(context).connection,
            localizedConnectionInfo(context, st.connInfo),
            valueColor: st.isUp(AppState.srcAprsIs) ? C.green : C.grey),
        _serverInput(),
        SettingsInput(S.of(context).port, _port,
            onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null) st.aprs.port = n;
          _checkConfigDirty();
          _save();
        }),
        _passcodeInput(),
        // 位置与状态报文那一行只在「高级连接通道设置」打开时出现：关着时
        // 位置一律发往所有已启用且连上的链路，这一行勾了也不起作用。
        if (st.advChannels)
          SettingsTxPick(
            S.of(context).txKindPosition,
            icon: Icons.my_location_rounded,
            multi: true,
            checked: st.posTxHas(AppState.srcAprsIs),
            onTap: () => st.togglePosTx(AppState.srcAprsIs),
          ),
        SettingsTxPick(
          S.of(context).messages,
          icon: Icons.forum_rounded,
          checked: st.dataSourceMsg == AppState.srcAprsIs,
          onTap: () => st.setTxMsgSource(AppState.srcAprsIs),
        ),
        SettingsInput(S.of(context).wsUrlOptional, _ws,
            onChanged: (v) {
          st.aprs.wsUrl = v.trim().isEmpty ? null : v.trim();
          _checkConfigDirty();
          _save();
        }),
        if (_configDirty) ...[
          Divider(height: 1, color: C.border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: C.orange, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.of(context).configChanged,
                          style: ts(13, c: C.orange, w: FontWeight.w700)),
                      Text(S.of(context).reconnectToApply,
                          style: ts(11, c: C.orange.withValues(alpha: 0.8))),
                    ]),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: C.orange, size: 22),
                tooltip: S.of(context).reconnect,
                onPressed: () async {
                  setState(() => _configDirty = false);
                  await st.reconnect();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(st.connected
                          ? S.of(context).reconnected
                          : S.of(context).connectFailedCheckConfig),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ]),
          ),
        ],
      ],
    );
  }

  /// 服务器地址输入（没填时给「未配置」徽标 + 一句原因）。
  ///
  /// 用户要求：没有配置服务器时要点出**连不上的原因**并提示去配置，与 Passcode
  /// 填 -1 的验证提示一个口径。服务器这一项空了以后，点多少次「连接」都不会成功，
  /// 而空输入框自己看不出这件事。
  ///
  /// 挂在 ValueListenableBuilder 上是为了让徽标与这句话**逐字**跟着输入走：
  /// `_checkConfigDirty()` 只在「脏」翻转时才 setState（把原本就有的地址删空时
  /// 它不翻），跟着它刷会留下一个过期的徽标。
  Widget _serverInput() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _server,
      builder: (_, v, _) {
        final missing = v.text.trim().isEmpty;
        return Column(children: [
          SettingsInput(
            S.of(context).server,
            _server,
            focusNode: _serverFocus,
            badge: missing ? S.of(context).serverMissing : null,
            onChanged: (x) {
              st.aprs.server = x.trim();
              _checkConfigDirty();
              _save();
            },
            // 「最近连过的服务器」：地址是一串不短的域名，重敲一遍最容易出错
            trailing: st.serverHistory.isEmpty
                ? null
                : HistoryButton(
                    entries: st.serverHistory,
                    title: S.of(context).serverHistoryTitle,
                    onPick: _pickServer,
                    onDelete: (v) => st.forgetInput(InputHistory.server, v),
                    onClear: () => st.clearInputHistory(InputHistory.server),
                  ),
          ),
          if (missing)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: C.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    S.of(context).serverMissingWarning,
                    style: ts(10.5, c: C.red, h: 1.4),
                  ),
                ),
              ]),
            ),
        ]);
      },
    );
  }

  /// Passcode 输入（未验证时醒目提示）
  Widget _passcodeInput() {
    final isDefault = _pass.text.trim().isEmpty || _pass.text.trim() == '-1';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(S.of(context).passcode, style: ts(12, c: C.slate)),
          if (isDefault) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: C.orangeBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(S.of(context).unverified,
                  style: ts(9, c: C.orange, w: FontWeight.w700)),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: _pass,
          style: ts(13, w: FontWeight.w600),
          onChanged: (v) {
            st.aprs.passcode = v.trim().isEmpty ? '-1' : v.trim();
            _checkConfigDirty();
            _save();
          },
          decoration: InputDecoration(
            hintText: S.of(context).passcodeUnverifiedHint,
            hintStyle: ts(13, c: C.greyLight),
            isDense: true,
            filled: true,
            fillColor: C.bgSoft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(S.of(context).passcodeMessageWarning, style: ts(10, c: C.grey)),
      ]),
    );
  }
}

/// ─── APRS-IS 的整页 ───
///
/// 卡本身在 `AprsIsCards`：「设置 → 服务器」一级两条链路各是一个入口，
/// 点进来就是这一页。与 `AcnLinkPage`（lib/acn_link_page.dart）一一对应。
class AprsIsServerPage extends StatelessWidget {
  final AppState state;
  const AprsIsServerPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SettingsPageShell(
      title: s.aprsIsServerTitle,
      subtitle: s.aprsIsServerLead,
      icon: Icons.cloud_rounded,
      color: C.purple,
      body: Column(children: [
        AprsIsCards(state: state),
        const SizedBox(height: 24),
      ]),
    );
  }
}
