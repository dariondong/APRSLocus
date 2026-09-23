#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""补两个键：输入框的占位提示（通用 + 台站备注专用）。

背景（用户反馈）：「台站备注，用户都不知道那里是可以输入的」。
根因：`SettingsInput` 里的 `TextField` 是 `border: none`、无背景、**无占位符**，
而「台站备注」默认是空串（v1.6.80 起默认清空）—— 于是那一行右边整片空白，
看起来和静态的「标签 + 值」行一模一样，没人知道能点。

两个键：
  * `inputTapHint`     —— 通用占位（任何空的 SettingsInput 都显示）
  * `callCommentEmpty` —— 台站备注专用，直接写清「点这里输入」

写入约定与 tool/add_beacon_dist_l10n.py 一致：幂等、追加到 ARB 末尾，
并同步 gen-l10n 产物（本机无 flutter，跑不了 gen-l10n；产物提交进 git）。
"""
import io
import json
import os
import re
import sys

KEYS = {
    'inputTapHint': ('点击输入', '點擊輸入', 'Tap to type',
                     'タップして入力', 'Toca para escribir',
                     'Ketuk untuk mengetik'),
    'callCommentEmpty': (
        '未填写 · 点这里输入', '未填寫 · 點這裡輸入', 'Not set · tap to type',
        '未設定 · タップして入力', 'Sin definir · toca para escribir',
        'Belum diisi · ketuk untuk mengetik'),
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}

TARGETS = [
    ('zh', 'app_localizations_zh.dart', 'AppLocalizationsZh'),
    ('zh_TW', 'app_localizations_zh.dart', 'AppLocalizationsZhTw'),
    ('en', 'app_localizations_en.dart', 'AppLocalizationsEn'),
    ('ja', 'app_localizations_ja.dart', 'AppLocalizationsJa'),
    ('es', 'app_localizations_es.dart', 'AppLocalizationsEs'),
    ('id', 'app_localizations_id.dart', 'AppLocalizationsId'),
]


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    l10n = os.path.join(root, 'lib', 'l10n')

    # ① arb
    total = 0
    for lg in LANGS:
        p = os.path.join(l10n, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8').read()
        add = []
        for key, vals in KEYS.items():
            if re.search(r'^\s*"' + re.escape(key) + r'":', src, re.M):
                continue
            add.append(f'  {json.dumps(key, ensure_ascii=False)}: '
                       f'{json.dumps(vals[IDX[lg]], ensure_ascii=False)},')
        if not add:
            continue
        i = src.rstrip().rfind('}')
        head = src[:i].rstrip()
        if not head.endswith(','):
            head += ','
        src = head + '\n' + '\n'.join(add).rstrip(',') + '\n' + src[i:]
        io.open(p, 'w', encoding='utf-8').write(src)
        total += len(add)
        print(f'  arb {lg}: 追加 {len(add)} 行')

    # ② 抽象类
    p = os.path.join(l10n, 'app_localizations.dart')
    src = io.open(p, encoding='utf-8').read()
    missing = [k for k in KEYS if not re.search(
        r'String (?:get )?' + re.escape(k) + r'\s*[;(<={]', src)]
    if missing:
        blocks = []
        for k in missing:
            blocks.append(
                f'  /// No description provided for @{k}.\n'
                f'  ///\n'
                f'  /// In zh, this message translates to:\n'
                f'  /// **{json.dumps(KEYS[k][0], ensure_ascii=False)}**\n'
                f'  String get {k};')
        anchor = '  /// No description provided for @tierIdleTitle.'
        assert anchor in src, '抽象类锚点缺失'
        src = src.replace(anchor, '\n\n'.join(blocks) + '\n\n' + anchor, 1)
        io.open(p, 'w', encoding='utf-8').write(src)
        print(f'  抽象类: 追加 {len(missing)} 条声明')

    # ③ 各语言类：插在每个类的 tierMinTurnHint 之后（与上次同一位置）
    for lg, fname, cls in TARGETS:
        p = os.path.join(l10n, fname)
        src = io.open(p, encoding='utf-8').read()
        i = src.find(f'class {cls}')
        assert i > 0, f'{fname}: 找不到 {cls}'
        body = src[i:src.find('\n}', i)]
        need = [k for k in KEYS
                if not re.search(r'String (?:get )?' + re.escape(k) + r'\s*[;(<={]', body)]
        if not need:
            continue
        m = re.compile(r"(?m)^  String get tierMinTurnHint => '[^']*';\n").search(src, i)
        assert m, f'{cls}: 找不到 tierMinTurnHint 锚点'
        blocks = []
        for k in need:
            blocks.append(f'  @override\n  String get {k} => '
                          f"'{KEYS[k][IDX[lg]]}';")
        src = src[:m.end()] + '\n' + '\n\n'.join(blocks) + '\n' + src[m.end():]
        io.open(p, 'w', encoding='utf-8').write(src)
        print(f'  产物 {fname}/{cls}: 追加 {len(need)} 条')

    print(f'\narb 共写入 {total} 行')
    return 0


if __name__ == '__main__':
    sys.exit(main())
