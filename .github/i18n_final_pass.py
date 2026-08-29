import json
from pathlib import Path

ROOT = Path('.')

def replace(path, old, new, count=None):
    p = ROOT / path
    text = p.read_text(encoding='utf-8')
    found = text.count(old)
    if found == 0:
        print(f'WARN missing {path}: {old[:100]!r}')
        return
    if count is not None and found != count:
        print(f'WARN count {path}: expected {count}, got {found}: {old[:100]!r}')
    text = text.replace(old, new, count if count is not None else -1)
    p.write_text(text, encoding='utf-8')
    print(f'{path}: {found} x {old[:80]!r}')

# ARB additions / wording polish.
for locale, values in {
    'zh': {
        'leaveAction': '退出',
        'localRepoVersion': '本地 v{local} · 仓库最新 v{latest}',
    },
    'en': {
        'leaveAction': 'Leave',
        'localRepoVersion': 'Local v{local} · Latest repository v{latest}',
    },
}.items():
    p = ROOT / f'lib/l10n/app_{locale}.arb'
    data = json.loads(p.read_text(encoding='utf-8'))
    data.update(values)
    if locale == 'en':
        data['settingsDesc'] = 'Configure station, location & connection'
        data['oobeWelcomeDesc'] = 'Start configuring your APRS station'
        data['featureMsgDesc'] = 'Feed + conversation views with Unicode text and auto-reply support'
        data['featureFmoDesc'] = 'Automatically detects FMO data and shows structured details'
        data['beaconEnabled'] = 'Enable beaconing'
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

# Home: final location-status and group-event display mapping.
replace('lib/home_page.dart',
        'widget.state.locStatus,\n                style: ts(11, c: locColor, w: FontWeight.w600),',
        'localizedLocationStatus(context, widget.state.locStatus),\n                style: ts(11, c: locColor, w: FontWeight.w600),', 1)
replace('lib/home_page.dart',
        "content: Text('[$groupCall] $event'),",
        "content: Text('[$groupCall] ${localizedSystemMessage(context, event)}'),", 1)

# Message page: remaining hard-coded action/status labels and stored system-message display.
replace('lib/messages_page.dart', "'新建会话',\n                      C.blue,", 'S.of(context).newConversation,\n                      C.blue,', 1)
replace('lib/messages_page.dart', "Text(\n                          '退出',", 'Text(\n                          S.of(context).leaveAction,', 1)
replace('lib/messages_page.dart', ": '已加入';", ': S.of(context).memberJoined;', 1)
replace('lib/messages_page.dart', "Text(\n                            '邀请',", 'Text(\n                            S.of(context).invite,', 1)
replace('lib/messages_page.dart', "final sender = m.sent ? '我' : m.from;", 'final sender = m.sent ? S.of(context).meLabel : m.from;', 1)
replace('lib/messages_page.dart', 'child: Text(\n            m.text,\n            style: ts(10, c: C.grey, w: FontWeight.w500),', 'child: Text(\n            localizedSystemMessage(context, m.text),\n            style: ts(10, c: C.grey, w: FontWeight.w500),', 1)

# OOBE: full Passcode explanation.
replace('lib/oobe_page.dart',
        "content: Text(\n          'Passcode 是 APRS-IS 登录验证码，用于识别你的呼号。\\n\\n'\n          '使用默认值 -1（未验证）虽然可以连接，但将无法正常收发消息与群聊。\\n\\n'\n          '建议在 https://aprs.cool/AprsPG 输入呼号查询正确 Passcode 后填写。',",
        'content: Text(\n          S.of(context).oobePasscodeMissingDesc,', 1)

# Update page: remaining visible hard-coded Chinese.
replace('lib/check_update_page.dart',
        "Text(\n                  '本次更新更换了正式签名（1.4.8 起）。旧版本无法直接覆盖安装，'\n                  '请先卸载手机上的 APRSlocus 再安装新版，否则会提示签名冲突。',",
        'Text(\n                  S.of(context).signatureChangedDesc,', 1)
replace('lib/check_update_page.dart',
        "_isNewer\n                          ? '发现新版本 v${_latest!.tagName}'\n                          : '仓库最新版本 v${_latest!.tagName}',",
        '_isNewer\n                          ? S.of(context).newVersionTitle(_latest!.tagName)\n                          : S.of(context).repoLatestTitle(_latest!.tagName),', 1)
replace('lib/check_update_page.dart',
        "'本地 v${AppState.appVersion} · 仓库最新 v${release.tagName}',",
        'S.of(context).localRepoVersion(AppState.appVersion, release.tagName),', 1)
replace('lib/check_update_page.dart',
        "'正在下载 ${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',",
        'S.of(context).downloadProgress(\n                          (_progress * 100).clamp(0, 100).toStringAsFixed(0),\n                        ),', 1)

# Sponsor page: remove const around localized runtime lookup.
replace('lib/sponsor_page.dart',
        'child: const Center(\n                        child: Text(S.of(context).qrLoadFailed),\n                      ),',
        'child: Center(\n                        child: Text(S.of(context).qrLoadFailed),\n                      ),', 1)

# Map menus: keep Chinese internal enum group keys, localize only presentation.
replace('lib/map_page.dart',
        '_mapTypeGroup(S.of(context).otherType, C.slate, () => entry.remove()),',
        "_mapTypeGroup('其他', C.slate, () => entry.remove()),", 1)
replace('lib/map_page.dart',
        'Text(\n                group,\n                style: ts(10, c: color, w: FontWeight.w700),',
        "Text(\n                group == '高德' ? S.of(context).amapGroup : S.of(context).otherType,\n                style: ts(10, c: color, w: FontWeight.w700),", 1)
replace('lib/map_page.dart',
        't.label,\n                    style: ts(',
        'localizedMapTypeLabel(context, t.name),\n                    style: ts(', 1)
replace('lib/map_page.dart',
        "String coord = '北京 · ${_zoom.round()}级';",
        'String coord = S.of(context).mapDefaultCoord(_zoom.round());', 1)

# Display settings map type labels use enum name for lookup, not Chinese label.
replace('lib/settings_pages.dart',
        'child: Text(t.label,\n                            style: ts(',
        'child: Text(localizedMapTypeLabel(context, t.name),\n                            style: ts(', 1)

# Extend translation of stored group-event strings without changing stored/protocol data.
p = ROOT / 'lib/widgets.dart'
text = p.read_text(encoding='utf-8')
old = """  m = RegExp(r'^(.+) 拒绝了邀请$').firstMatch(value);\n  if (m != null) return S.of(context).systemInviteDeclined(m.group(1)!);\n  return value;\n}"""
new = """  m = RegExp(r'^(.+) 拒绝了邀请$').firstMatch(value);\n  if (m != null) return S.of(context).systemInviteDeclined(m.group(1)!);\n  m = RegExp(r'^(.+) 已加入群组$').firstMatch(value);\n  if (m != null) return S.of(context).systemMemberJoined(m.group(1)!);\n  m = RegExp(r'^(.+) 已退出群组$').firstMatch(value);\n  if (m != null) return S.of(context).systemMemberLeft(m.group(1)!);\n  return value;\n}"""
if old not in text:
    print('WARN widgets system-message extension pattern missing')
else:
    p.write_text(text.replace(old, new, 1), encoding='utf-8')
    print('widgets.dart: extended group-system-message localization')
