#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""往 6 个 ARB + 产物里加「群发 / 邀请确认」三句文案。

用户要求：群发前确认一次；邀请（单人 / 建群批量）前也各确认一次。

本脚本与 tool/add_l10n_keys.py 同源，但**带占位符且类型不同**
（`String` 与 `int` 混用）—— add_l10n_keys 的 member() 只会写 `String get`
或全 `String` 形参，给不了 gen-l10n 的 `String f(int n)`。所以这里把
成员签名做成显式声明，逐键给形参名与 Dart 类型，产物与 gen-l10n 同形
（见 check_l10n_sync 第 4 条：产物成员必须与 arb 一一对应）。

幂等：已存在的键/成员会跳过，可反复执行。
⚠ ICU：译文里不要出现落单的半角单引号。
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L10N = os.path.join(ROOT, 'lib', 'l10n')
LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']

# key → (形参 [(名, Dart 类型)], {语言: 文案})
KEYS = {
    'confirmSendToGroup': (
        [('group', 'String')],
        {
            'zh': '确认发送到 {group}？',
            'zh_TW': '確認傳送到 {group}？',
            'en': 'Send to {group}?',
            'ja': '{group} に送信しますか？',
            'es': '¿Enviar a {group}?',
            'id': 'Kirim ke {group}?',
        },
    ),
    'confirmInviteMember': (
        [('call', 'String')],
        {
            'zh': '确认邀请 {call} 加入群聊？',
            'zh_TW': '確認邀請 {call} 加入群聊？',
            'en': 'Invite {call} to the group chat?',
            'ja': '{call} をグループチャットに招待しますか？',
            'es': '¿Invitar a {call} al chat grupal?',
            'id': 'Undang {call} ke obrolan grup?',
        },
    ),
    'confirmCreateGroup': (
        [('n', 'int')],
        {
            'zh': '确认创建群聊并向 {n} 位成员发出邀请？',
            'zh_TW': '確認建立群聊並向 {n} 位成員發出邀請？',
            'en': 'Create the group and invite {n} member(s)?',
            'ja': 'グループを作成し、{n} 名を招待しますか？',
            'es': '¿Crear el grupo e invitar a {n} miembro(s)?',
            'id': 'Buat grup dan undang {n} anggota?',
        },
    ),
}

CONCRETE = {
    'zh': ('app_localizations_zh.dart', 'AppLocalizationsZh'),
    'zh_TW': ('app_localizations_zh.dart', 'AppLocalizationsZhTw'),
    'en': ('app_localizations_en.dart', 'AppLocalizationsEn'),
    'ja': ('app_localizations_ja.dart', 'AppLocalizationsJa'),
    'es': ('app_localizations_es.dart', 'AppLocalizationsEs'),
    'id': ('app_localizations_id.dart', 'AppLocalizationsId'),
}


def member(key):
    ps = KEYS[key][0]
    if not ps:
        return 'get %s' % key
    return '%s(%s)' % (key, ', '.join('%s %s' % (t, n) for n, t in ps))


def interp(key, text):
    for n, _t in KEYS[key][0]:
        text = text.replace('{%s}' % n, '$%s' % n)
    return text


def add_arb_lines(text, lines):
    i = text.rstrip().rfind('}')
    head = text[:i].rstrip()
    if head.endswith(','):
        head = head[:-1]
    body = ',\n'.join(l.rstrip().rstrip(',') for l in lines)
    return head + ',\n' + body + '\n' + text[i:]


def insert_before_class_close(src, cname, code):
    m = re.search(r'(?m)^(?:abstract )?class ' + re.escape(cname) + r'\b', src)
    if not m:
        raise SystemExit('找不到类 ' + cname)
    j = src.find('\n}', m.end())
    if j < 0:
        raise SystemExit('找不到类 %s 的结尾' % cname)
    return src[:j] + '\n' + code.rstrip('\n') + '\n' + src[j:]


def main() -> int:
    # ① arb
    for lg in LANGS:
        p = os.path.join(L10N, 'app_%s.arb' % lg)
        t = io.open(p, encoding='utf-8', newline='').read()
        add = []
        for k, (ps, tr) in KEYS.items():
            if '"%s":' % k in t:
                continue
            add.append('  %s: %s' % (json.dumps(k, ensure_ascii=False),
                                     json.dumps(tr[lg], ensure_ascii=False)))
            if ps:
                meta = {'placeholders': {n: {'type': t} for n, t in ps}}
                add.append('  %s: %s' % (json.dumps('@' + k, ensure_ascii=False),
                                         json.dumps(meta, ensure_ascii=False)))
        if add:
            t = add_arb_lines(t, add)
            io.open(p, 'w', encoding='utf-8', newline='').write(t)
        try:
            json.load(io.open(p, encoding='utf-8'))
        except Exception as e:
            print('%s arb 拼坏了: %s' % (lg, e))
            return 1
        print('%s arb ok（新增 %d 行）' % (lg, len(add)))

    # ② 抽象类
    p = os.path.join(L10N, 'app_localizations.dart')
    s = io.open(p, encoding='utf-8').read()
    code = []
    for k in KEYS:
        if re.search(r'String (?:get )?%s\b' % k, s):
            continue
        code.append('  /// No description provided for @%s.\n  ///\n'
                    '  /// In zh, this message translates to:\n  /// **\'%s\'**\n'
                    '  String %s;\n'
                    % (k, KEYS[k][1]['zh'].replace('$', r'\$'), member(k)))
    if code:
        s = insert_before_class_close(s, 'AppLocalizations', '\n'.join(code))
        io.open(p, 'w', encoding='utf-8').write(s)
    print('抽象类 %s +%d' % (L10N, len(code)))

    # ③ 各语言具体类（zh 文件里有两个类，分别处理）
    for lg in LANGS:
        fn, cname = CONCRETE[lg]
        p = os.path.join(L10N, fn)
        s = io.open(p, encoding='utf-8').read()
        m = re.search(r'(?m)^(?:abstract )?class ' + re.escape(cname) + r'\b', s)
        if not m:
            raise SystemExit('找不到类 ' + cname)
        b1 = s.find('\n}', m.end())
        body = s[m.end():b1]
        code = []
        for k, (_ps, tr) in KEYS.items():
            if re.search(r'String (?:get )?%s\b' % k, body):
                continue
            code.append('  @override\n  String %s {\n    return %s;\n  }\n'
                        % (member(k),
                           json.dumps(interp(k, tr[lg]), ensure_ascii=False)))
        if code:
            s = s[:b1] + '\n' + '\n'.join(code) + s[b1:]
            io.open(p, 'w', encoding='utf-8').write(s)
        print('%s +%d' % (cname, len(code)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
