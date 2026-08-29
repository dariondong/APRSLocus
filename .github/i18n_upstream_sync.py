from pathlib import Path
import json

CONFLICT_FILES = [
    Path('lib/home_page.dart'),
    Path('lib/map_page.dart'),
    Path('lib/messages_page.dart'),
    Path('lib/settings_pages.dart'),
    Path('lib/stations_page.dart'),
]


def choose_theirs_in_conflicts(path: Path):
    text = path.read_text(encoding='utf-8')
    lines = text.splitlines(keepends=True)
    out = []
    i = 0
    count = 0
    while i < len(lines):
        if lines[i].startswith('<<<<<<< '):
            count += 1
            i += 1
            while i < len(lines) and not lines[i].startswith('======='):
                i += 1
            if i >= len(lines):
                raise RuntimeError(f'broken conflict in {path}')
            i += 1
            theirs = []
            while i < len(lines) and not lines[i].startswith('>>>>>>> '):
                theirs.append(lines[i])
                i += 1
            if i >= len(lines):
                raise RuntimeError(f'broken conflict in {path}')
            i += 1
            out.extend(theirs)
        else:
            out.append(lines[i])
            i += 1
    path.write_text(''.join(out), encoding='utf-8')
    print(f'{path}: resolved {count} conflict block(s) with upstream logic')


for p in CONFLICT_FILES:
    choose_theirs_in_conflicts(p)


def replace(path, old, new, expected=None):
    p = Path(path)
    s = p.read_text(encoding='utf-8')
    n = s.count(old)
    if expected is not None and n != expected:
        print(f'WARN {path}: expected {expected}, found {n}: {old[:70]!r}')
    if n:
        s = s.replace(old, new)
        p.write_text(s, encoding='utf-8')
        print(f'{path}: replaced {n} x {old[:55]!r}')


# Upstream map/status behavior + localized display.
replace('lib/map_page.dart',
        'final st = statusLabel(s.effectiveStatus);',
        'final st = localizedStatusLabel(context, s.effectiveStatus);')
replace('lib/map_page.dart',
        "_lg(C.yellow, '静止'),",
        '_lg(C.yellow, S.of(context).stationary),')

# Upstream station list behavior + localized presentation.
replace('lib/stations_page.dart',
        "_statMini('静止', '${st.stoppedCount}', C.yellow),",
        "_statMini(S.of(context).stationary, '${st.stoppedCount}', C.yellow),")
replace('lib/stations_page.dart',
        "_miniChip('静止', _filter == 'stopped', C.yellow,",
        "_miniChip(S.of(context).stationary, _filter == 'stopped', C.yellow,")
replace('lib/stations_page.dart',
        "Text('${s.typeName} · ${s.comment ?? ''}',",
        "Text('${localizedAprsSymbolName(context, s.symbol)} · ${s.comment ?? ''}',")
replace('lib/stations_page.dart',
        "_mini(Icons.access_time_rounded, s.lastSeen),",
        "_mini(Icons.access_time_rounded, localizedLastSeen(context, s)),")

# New upstream connection card: preserve new layout, localize every new user-facing string.
replace('lib/settings_pages.dart',
        "SettingsInput('WebSocket URL(可选)', _ws,",
        'SettingsInput(S.of(context).websocketOptional, _ws,')
replace('lib/settings_pages.dart',
        "SettingsRow2(S.of(context).connection, st.connInfo),",
        'SettingsRow2(S.of(context).connection, localizedConnectionInfo(context, st.connInfo)),')
replace('lib/settings_pages.dart',
        "Text('配置已修改',",
        'Text(S.of(context).configChanged,')
replace('lib/settings_pages.dart',
        "Text('重新连接后生效',",
        'Text(S.of(context).reconnectToApply,')
replace('lib/settings_pages.dart',
        "content: Text(st.connected\n                            ? '已重新连接'\n                            : '连接失败，请检查配置'),",
        'content: Text(st.connected\n                            ? S.of(context).reconnected\n                            : S.of(context).connectFailedCheckConfig),')
replace('lib/settings_pages.dart',
        "child: Text('未验证',",
        'child: Text(S.of(context).unverified,')
replace('lib/settings_pages.dart',
        "hintText: '-1 未验证',",
        'hintText: S.of(context).passcodeUnverifiedHint,')
replace('lib/settings_pages.dart',
        "Text('APRS-IS 登录验证码，填 -1 无法正常收发消息',",
        'Text(S.of(context).passcodeMessageWarning,')
replace('lib/settings_pages.dart',
        'Text(st.connInfo, style: ts(11, c: col.withValues(alpha: 0.8))),',
        'Text(localizedConnectionInfo(context, st.connInfo),\n                style: ts(11, c: col.withValues(alpha: 0.8))),')

# Group-management block changed upstream (block -> remove). Keep that behavior and restore i18n.
repls = [
    ("Text('群呼号: ${group.groupCall}',", "Text(S.of(context).groupCallsignLine(group.groupCall),"),
    ("Text('暂无成员', style: ts(13, c: C.grey))", "Text(S.of(context).noMembers, style: ts(13, c: C.grey))"),
    ("Text('点击下方「邀请成员」添加', style: ts(11, c: C.greyLight))", "Text(S.of(context).inviteMembersHint, style: ts(11, c: C.greyLight))"),
    ("statusText = isOnlineStation ? S.of(context).online : '已加入';", "statusText = isOnlineStation ? S.of(context).online : S.of(context).memberJoined;"),
    ("statusText = '待确认';", "statusText = S.of(context).memberPending;"),
    ("statusText = '已拒绝';", "statusText = S.of(context).memberDeclined;"),
    ("statusText = '已退出';", "statusText = S.of(context).memberLeft;"),
    ("statusText = '超时';", "statusText = S.of(context).memberTimeout;"),
    ("child: Text('移除', style: ts(11, c: C.red, w: FontWeight.w600)),", "child: Text(S.of(context).remove, style: ts(11, c: C.red, w: FontWeight.w600)),"),
    ("Text('邀请成员', style: ts(13, c: C.orange, w: FontWeight.w700)),", "Text(S.of(context).inviteMembers, style: ts(13, c: C.orange, w: FontWeight.w700)),"),
    ("title: Text('删除群组', style: ts(16, w: FontWeight.w700)),", "title: Text(S.of(context).deleteGroup, style: ts(16, w: FontWeight.w700)),"),
    ("content: Text('确定删除「${group.name}」？此操作不可撤销。', style: ts(13)),", "content: Text(S.of(context).deleteGroupConfirm(group.name), style: ts(13)),"),
    ("child: Text('删除', style: ts(13, c: Colors.white, w: FontWeight.w700)),", "child: Text(S.of(context).delete, style: ts(13, c: Colors.white, w: FontWeight.w700)),"),
    ("Text('${members.length} 名成员 · $onlineCount 在线',", "Text(S.of(context).memberOnlineCount(members.length, onlineCount),"),
    ("group.isOwner(st.myCall) ? '+ 邀请' : '完成',", "group.isOwner(st.myCall) ? '+ ${S.of(context).invite}' : S.of(context).done,"),
    ("child: Text('群主', style: ts(9, c: C.orange, w: FontWeight.w700)),", "child: Text(S.of(context).groupOwner, style: ts(9, c: C.orange, w: FontWeight.w700)),"),
    ("title: Text('退出群组', style: ts(16, w: FontWeight.w700)),", "title: Text(S.of(context).leaveGroup, style: ts(16, w: FontWeight.w700)),"),
    ("content: Text('确定退出「${group.name}」？你将不再收到该群的消息。', style: ts(13)),", "content: Text(S.of(context).leaveGroupConfirm(group.name), style: ts(13)),"),
    ("content: Text('已退出 ${group.name}'),", "content: Text(S.of(context).leftGroup(group.name)),"),
    ("child: Text('退出', style: ts(13, c: Colors.white, w: FontWeight.w700)),", "child: Text(S.of(context).leave, style: ts(13, c: Colors.white, w: FontWeight.w700)),"),
    ("title: Text('邀请成员到 ${group.name}', style: ts(15, w: FontWeight.w700)),", "title: Text(S.of(context).inviteMembersTo(group.name), style: ts(15, w: FontWeight.w700)),"),
    ("hintText: '搜索呼号…',", "hintText: S.of(context).searchCallsign,"),
    ("hintText: '手动输入呼号',", "hintText: S.of(context).manualCallsign,"),
    ("SnackBar(content: Text('已发送邀请给 $call'), duration: const Duration(seconds: 2)),", "SnackBar(content: Text(S.of(context).inviteSent(call)), duration: const Duration(seconds: 2)),"),
    ("child: Text('邀请', style: ts(11, c: C.orange, w: FontWeight.w700)),", "child: Text(S.of(context).invite, style: ts(11, c: C.orange, w: FontWeight.w700)),"),
    ("Center(child: Text('暂无更多在线台站', style: ts(12, c: C.grey)))", "Center(child: Text(S.of(context).noMoreOnlineStations, style: ts(12, c: C.grey)))"),
    ("SnackBar(content: Text('已发送邀请给 ${s.call}'), duration: const Duration(seconds: 2)),", "SnackBar(content: Text(S.of(context).inviteSent(s.call)), duration: const Duration(seconds: 2)),"),
    ("Text('已邀请', style: ts(10, c: C.green))", "Text(S.of(context).invited, style: ts(10, c: C.green))"),
    ("Text('点击邀请', style: ts(10, c: C.orange))", "Text(S.of(context).tapToInvite, style: ts(10, c: C.orange))"),
    ("child: Text('完成', style: ts(13, c: C.blue)),", "child: Text(S.of(context).done, style: ts(13, c: C.blue)),"),
]
for old, new in repls:
    replace('lib/messages_page.dart', old, new)

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

# Conflict markers must be gone.
for p in CONFLICT_FILES:
    t = p.read_text(encoding='utf-8')
    if '<<<<<<< ' in t or '\n=======\n' in t or '>>>>>>> ' in t:
        raise SystemExit(f'unresolved conflict markers in {p}')
