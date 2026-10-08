#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为消息页标题右侧「发射位置信标」按钮补 l10n 键（6 语言）。

同时更新 arb（真源）与提交进 git 的 gen-l10n 产物（抽象类 + 各语言实现），
写完由 tool/check_l10n_sync.py 校验一一对应。
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}

KEY = 'sendPositionBeacon'
VALS = (
    '发射位置信标',
    '發射位置信標',
    'Transmit position beacon',
    '位置ビーコンを送信',
    'Transmitir baliza de posición',
    'Pancarkan beacon posisi',
)

CLASSES = {
    'zh': 'AppLocalizationsZh',
    'zh_TW': 'AppLocalizationsZhTw',
    'en': 'AppLocalizationsEn',
    'ja': 'AppLocalizationsJa',
    'es': 'AppLocalizationsEs',
    'id': 'AppLocalizationsId',
}

ARB = {'zh': 'app_zh.arb', 'zh_TW': 'app_zh_TW.arb', 'en': 'app_en.arb',
       'ja': 'app_ja.arb', 'es': 'app_es.arb', 'id': 'app_id.arb'}


def class_body(src, name):
    m = re.search(r'(?m)^(?:abstract )?class ' + re.escape(name) + r'\b', src)
    if not m:
        raise SystemExit(f'找不到类 {name}')
    j = src.find('\n}', m.end())
    if j < 0:
        j = src.rfind('\n}')
    return m.end(), j


def main():
    arb_dir = os.path.join(ROOT, 'lib', 'l10n')

    # ① arb：模板与各语言各加一条（文本插入，保持既有排版）
    for lg in LANGS:
        p = os.path.join(arb_dir, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8', newline='').read()
        if re.search(r'^\s*"' + re.escape(KEY) + r'":', src, re.M):
            print(f'  {lg}/{KEY}: 已存在，跳过')
            continue
        entry = (f'  {json.dumps(KEY, ensure_ascii=False)}: '
                 f'{json.dumps(VALS[IDX[lg]], ensure_ascii=False)},')
        i = src.rstrip().rfind('}')
        head = src[:i].rstrip()
        if not head.endswith(','):
            head += ','
        src = head + '\n' + entry.rstrip(',') + '\n' + src[i:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{lg}: ARB 追加 {KEY}')

    # ② 抽象类
    p = os.path.join(arb_dir, 'app_localizations.dart')
    src = io.open(p, encoding='utf-8', newline='').read()
    if f'String get {KEY};' not in src:
        code = (
            f'  /// No description provided for @{KEY}.\n'
            '  ///\n'
            '  /// In zh, this message translates to:\n'
            f"  /// **'{VALS[0]}'**\n"
            f'  String get {KEY};\n'
        )
        _s, j = class_body(src, 'AppLocalizations')
        src = src[:j] + '\n' + code + src[j:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print('抽象类追加 1 键')

    # ③ 各语言实现
    for lg in LANGS:
        name = CLASSES[lg]
        fn = ('app_localizations_zh.dart' if lg in ('zh', 'zh_TW')
              else f'app_localizations_{lg}.dart')
        p = os.path.join(arb_dir, fn)
        src = io.open(p, encoding='utf-8', newline='').read()
        b0, b1 = class_body(src, name)
        body = src[b0:b1]
        if re.search(r'String get ' + re.escape(KEY) + r'\s*=>', body):
            print(f'  {lg}: 已存在，跳过')
            continue
        code = ('  @override\n'
                f"  String get {KEY} => '{VALS[IDX[lg]]}';\n")
        src = src[:b1] + '\n' + code + src[b1:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{name}: 追加 {KEY}')

    print('done')
    return 0


if __name__ == '__main__':
    sys.exit(main())
