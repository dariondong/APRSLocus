from pathlib import Path
import json
import subprocess

CONFLICT_FILES = [
    'lib/home_page.dart',
    'lib/map_page.dart',
    'lib/messages_page.dart',
    'lib/settings_pages.dart',
    'lib/stations_page.dart',
]

# Preserve the already-localized, known-good versions of conflicted UI files.
# Upstream behavior changes are ported explicitly below. Non-conflicting files
# (models/state/workflows/changelog/pubspec) remain auto-merged by git.
subprocess.run(['git', 'checkout', '--ours', '--', *CONFLICT_FILES], check=True)
print('Kept localized side for conflicted UI files; applying upstream changes explicitly')


def read(path):
    return Path(path).read_text(encoding='utf-8')


def write(path, text):
    Path(path).write_text(text, encoding='utf-8')


def replace(path, old, new, expected=1):
    s = read(path)
    n = s.count(old)
    if n != expected:
        raise SystemExit(f'{path}: expected {expected} occurrence(s), found {n}: {old[:100]!r}')
    write(path, s.replace(old, new))
    print(f'{path}: replaced {n} x {old[:60]!r}')


# ── home_page.dart: upstream search debounce ──
replace(
    'lib/home_page.dart',
    '  final _searchCtrl = TextEditingController();\n',
    '  final _searchCtrl = TextEditingController();\n'
    '  Timer? _searchDebounce; // 搜索防抖：台站多时避免每敲一个字符重建地图/列表\n',
)
replace(
    'lib/home_page.dart',
    '    widget.state.onGroupEvent = null;\n    _searchCtrl.dispose();',
    '    widget.state.onGroupEvent = null;\n    _searchDebounce?.cancel();\n    _searchCtrl.dispose();',
)
replace(
    'lib/home_page.dart',
    '                    onChanged: (v) => setState(() => _search = v),',
    '                    onChanged: (v) {\n'
    '                      // 防抖：输入停止 300ms 才更新搜索，台站多时避免逐字重建卡顿\n'
    '                      _searchDebounce?.cancel();\n'
    '                      _searchDebounce = Timer(\n'
    '                        const Duration(milliseconds: 300),\n'
    '                        () {\n'
    '                          if (mounted) setState(() => _search = v);\n'
    '                        },\n'
    '                      );\n'
    '                    },',
)

# ── map_page.dart: 5-minute effective status + upstream map-menu key fix ──
replace(
    'lib/map_page.dart',
    '(s) => s.status == St.moving || (_selected?.call == s.call),',
    '(s) => s.effectiveStatus == St.moving || (_selected?.call == s.call),',
)
replace(
    'lib/map_page.dart',
    '      final pulsing = s.status == St.moving || sel;',
    '      final pulsing = s.effectiveStatus == St.moving || sel;',
)
replace(
    'lib/map_page.dart',
    '                  if (s.status == St.moving || sel)',
    '                  if (s.effectiveStatus == St.moving || sel)',
)
replace(
    'lib/map_page.dart',
    '    final st = statusLabel(s.status);',
    '    final st = localizedStatusLabel(context, s.effectiveStatus);',
)
replace(
    'lib/map_page.dart',
    '          _lg(C.red, S.of(context).emergency),',
    '          _lg(C.yellow, S.of(context).stationary),\n'
    '          SizedBox(height: 5),\n'
    '          _lg(C.grey, S.of(context).offline),',
)
replace(
    'lib/map_page.dart',
    "                    _mapTypeGroup(\n                      S.of(context).otherType,\n                      C.slate,\n                      () => entry.remove(),\n                    ),",
    "                    _mapTypeGroup(\n                      '其他',\n                      C.slate,\n                      () => entry.remove(),\n                    ),",
)

# ── stations_page.dart: effective status + debounce ──
replace(
    'lib/stations_page.dart',
    "import 'package:flutter/material.dart';",
    "import 'dart:async';\n\nimport 'package:flutter/material.dart';",
)
replace(
    'lib/stations_page.dart',
    '  final _searchCtrl = TextEditingController();\n',
    '  final _searchCtrl = TextEditingController();\n'
    '  Timer? _searchDebounce; // 搜索防抖：台站多时避免逐字重建列表\n',
)
replace(
    'lib/stations_page.dart',
    '  void dispose() {\n    _searchCtrl.dispose();',
    '  void dispose() {\n    _searchDebounce?.cancel();\n    _searchCtrl.dispose();',
)
replace(
    'lib/stations_page.dart',
    "      case 'online':\n        s = s.where((s) => s.status != St.offline).toList();\n        break;\n      case 'moving':\n        s = s.where((s) => s.status == St.moving).toList();\n        break;\n      case 'emergency':\n        s = s.where((s) => s.status == St.emergency).toList();\n        break;",
    "      case 'online':\n        s = s.where((s) => s.effectiveStatus != St.offline).toList();\n        break;\n      case 'moving':\n        s = s.where((s) => s.effectiveStatus == St.moving).toList();\n        break;\n      case 'stopped':\n        s = s.where((s) => s.effectiveStatus == St.stopped).toList();\n        break;",
)
replace(
    'lib/stations_page.dart',
    '                onChanged: (_) => setState(() {}),',
    '                onChanged: (_) {\n'
    '                  // 防抖：输入停止 300ms 才重建列表，台站多时避免卡顿\n'
    '                  _searchDebounce?.cancel();\n'
    '                  _searchDebounce = Timer(\n'
    '                    const Duration(milliseconds: 300),\n'
    '                    () {\n'
    '                      if (mounted) setState(() {});\n'
    '                    },\n'
    '                  );\n'
    '                },',
)
replace(
    'lib/stations_page.dart',
    "                          _statMini(\n                            S.of(context).emergency,\n                            '${st.emergency}',\n                            C.red,\n                          ),",
    "                          _statMini(\n                            S.of(context).stationary,\n                            '${st.stoppedCount}',\n                            C.yellow,\n                          ),",
)
replace(
    'lib/stations_page.dart',
    "                        _miniChip(\n                          S.of(context).emergency,\n                          _filter == 'emergency',\n                          C.red,\n                          () => setState(\n                            () => _filter = _filter == 'emergency'\n                                ? 'all'\n                                : 'emergency',\n                          ),\n                        ),",
    "                        _miniChip(\n                          S.of(context).stationary,\n                          _filter == 'stopped',\n                          C.yellow,\n                          () => setState(\n                            () => _filter = _filter == 'stopped'\n                                ? 'all'\n                                : 'stopped',\n                          ),\n                        ),",
)
replace(
    'lib/stations_page.dart',
    '                          StatusBadge(s.status),',
    '                          StatusBadge(s.effectiveStatus),',
)

# ── messages_page.dart: upstream removed block/unblock; keep removal only ──
replace(
    'lib/messages_page.dart',
    '                            final isBlocked = group.blockedMembers.contains(\n'
    '                              call.toUpperCase(),\n'
    '                            );\n',
    '',
)
replace(
    'lib/messages_page.dart',
    '                            if (isBlocked) {\n'
    '                              statusText = S.of(context).memberBlocked;\n'
    '                              statusColor = C.red;\n'
    '                            } else if (status == GroupMemberStatus.joined) {',
    '                            if (status == GroupMemberStatus.joined) {',
)
msg_path = 'lib/messages_page.dart'
msg = read(msg_path)
method = msg.index('  void _showEditGroupDialog(AppState st, ChatGroup group) {')
action_start = msg.index('                                  // 操作按钮', method)
action_end = msg.index('                                ],\n                              ),\n                            );', action_start)
new_action = '''                                  // 操作按钮
                                  GestureDetector(
                                    onTap: () {
                                      // 移除成员：从 memberStatus 和 activeMembers 删除
                                      setSheetState(() {
                                        group.memberStatus.remove(
                                          call.toUpperCase(),
                                        );
                                        group.activeMembers.remove(
                                          call.toUpperCase(),
                                        );
                                      });
                                      // 保存群聊变更（持久化 + 刷新）
                                      st.saveGroupNow();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: C.redBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        S.of(context).remove,
                                        style: ts(
                                          11,
                                          c: C.red,
                                          w: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
'''
msg = msg[:action_start] + new_action + msg[action_end:]
write(msg_path, msg)
print('lib/messages_page.dart: replaced block/unblock controls with upstream remove-only behavior')

# ── settings_pages.dart: upstream final connection-card redesign, localized ──
settings_path = 'lib/settings_pages.dart'
settings = read(settings_path)
cls = settings.index('class _ConnectionSettingsPageState extends State<ConnectionSettingsPage> {')
build_start = settings.index('  @override\n  Widget build(BuildContext context) {', cls)
filter_start = settings.index('  Widget _filterCard() {', build_start)
connection_block = '''  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        // 同步过滤器数值（filterFollow 等模式下可能外部变化）
        _syncFilterControllers(st);
        return SettingsPageShell(
          title: S.of(context).connectionSettings2,
          subtitle: S.of(context).connectionSettingsSubtitle,
          icon: Icons.wifi_rounded,
          color: C.purple,
          body: Column(
            children: [
              _connCard(),
              const SizedBox(height: 16),
              _filterCard(),
              const SizedBox(height: 16),
              _receivePrefCard(),
            ],
          ),
        );
      },
    );
  }

  /// 连接状态 + 服务器配置卡片（合并）
  Widget _connCard() {
    return SettingsSectionCard(
      title: S.of(context).server,
      icon: Icons.dns_rounded,
      color: C.purple,
      children: [
        _connBanner(),
        Divider(height: 1, color: C.border),
        SettingsInput(
          S.of(context).server,
          _server,
          onChanged: (v) {
            st.aprs.server = v.trim();
            _checkConfigDirty();
          },
        ),
        SettingsInput(
          S.of(context).port,
          _port,
          onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null) st.aprs.port = n;
            _checkConfigDirty();
          },
        ),
        _passcodeInput(),
        SettingsInput(
          S.of(context).websocketOptional,
          _ws,
          onChanged: (v) {
            st.aprs.wsUrl = v.trim().isEmpty ? null : v.trim();
            _checkConfigDirty();
          },
        ),
        SettingsRow2(
          S.of(context).connection,
          localizedConnectionInfo(context, st.connInfo),
        ),
        if (_configDirty) ...[
          Divider(height: 1, color: C.border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: C.orange, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context).configChanged,
                        style: ts(13, c: C.orange, w: FontWeight.w700),
                      ),
                      Text(
                        S.of(context).reconnectToApply,
                        style: ts(
                          11,
                          c: C.orange.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: C.orange, size: 22),
                  tooltip: S.of(context).reconnect,
                  onPressed: () async {
                    setState(() => _configDirty = false);
                    await st.reconnect();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            st.connected
                                ? S.of(context).reconnected
                                : S.of(context).connectFailedCheckConfig,
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(S.of(context).passcode, style: ts(12, c: C.slate)),
              if (isDefault) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: C.orangeBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    S.of(context).unverified,
                    style: ts(9, c: C.orange, w: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _pass,
            style: ts(13, w: FontWeight.w600),
            onChanged: (v) {
              st.aprs.passcode = v.trim().isEmpty ? '-1' : v.trim();
              _checkConfigDirty();
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
          Text(
            S.of(context).passcodeMessageWarning,
            style: ts(10, c: C.grey),
          ),
        ],
      ),
    );
  }

  Widget _connBanner() {
    final col = st.connected
        ? C.green
        : st.connecting
        ? C.blue
        : C.red;
    final bg = st.connected
        ? C.greenBg
        : st.connecting
        ? C.blueBg
        : C.redBg;
    final icon = st.connected
        ? Icons.check_circle_rounded
        : st.connecting
        ? Icons.sync_rounded
        : Icons.cloud_off_rounded;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: col, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  st.connected
                      ? '${S.of(context).connected} APRS-IS'
                      : st.connecting
                      ? S.of(context).connecting
                      : S.of(context).disconnected,
                  style: ts(13, c: col, w: FontWeight.w700),
                ),
                Text(
                  localizedConnectionInfo(context, st.connInfo),
                  style: ts(11, c: col.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(
              st.connected
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
              color: st.connected ? C.red : C.green,
            ),
            onPressed: st.toggleConnect,
          ),
        ],
      ),
    );
  }

'''
settings = settings[:build_start] + connection_block + settings[filter_start:]
write(settings_path, settings)
print('lib/settings_pages.dart: ported upstream connection-card redesign with localization')

# Add only genuinely new strings introduced by the redesigned passcode input.
for file, vals in [
    ('lib/l10n/app_zh.arb', {
        'unverified': '未验证',
        'passcodeUnverifiedHint': '-1 未验证',
        'passcodeMessageWarning': 'APRS-IS 登录验证码，填 -1 无法正常收发消息',
    }),
    ('lib/l10n/app_en.arb', {
        'unverified': 'Unverified',
        'passcodeUnverifiedHint': '-1 (unverified)',
        'passcodeMessageWarning': 'APRS-IS login passcode. Using -1 prevents normal message send/receive.',
    }),
]:
    p = Path(file)
    data = json.loads(p.read_text(encoding='utf-8'))
    data.update(vals)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{file}: ensured {len(vals)} new keys')

# Sanity checks for the upstream behaviors we deliberately ported.
checks = {
    'lib/home_page.dart': ['_searchDebounce = Timer(', 'Duration(milliseconds: 300)'],
    'lib/map_page.dart': ['s.effectiveStatus == St.moving', "_mapTypeGroup(\n                      '其他'", 'S.of(context).stationary'],
    'lib/messages_page.dart': ['group.memberStatus.remove(', 'S.of(context).remove'],
    'lib/settings_pages.dart': ['Widget _connCard()', 'Widget _passcodeInput()', 'passcodeMessageWarning'],
    'lib/stations_page.dart': ['case \'stopped\':', 'StatusBadge(s.effectiveStatus)', 'st.stoppedCount'],
}
for path, needles in checks.items():
    t = read(path)
    for needle in needles:
        if needle not in t:
            raise SystemExit(f'{path}: missing expected upstream behavior: {needle}')
    if '<<<<<<< ' in t or '\n=======\n' in t or '>>>>>>> ' in t:
        raise SystemExit(f'unresolved conflict markers in {path}')
