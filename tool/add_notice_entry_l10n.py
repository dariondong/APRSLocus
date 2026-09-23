#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""设置主页「公告」入口那条按钮的 l10n 键（1 个 × 6 语言）。

背景（用户需求）：「不要在子页留了。在设置主页底下添加一个公告进入按钮」。

为什么**要**新开一个键，而不是复用已有的：
  * `noticeTitle`（公告）是这个入口的**标题**，复用它是应该的；
  * 但它需要一个**副标题**来说明「点它做什么」—— 设置主页每个入口都有一行小字
    （「导出 ADIF / 通联日志文件」「主题 / 自定义颜色、图标与文字」…），少了这行
    这一条就会显得像半成品。已有键里没有一句合适的话：
    `noticeReadMore`（查看全文）是**动作**不是**说明**，当副标题读起来像按钮文字。

写入约定与 tool/add_notice_l10n.py 完全一致：幂等、追加到 ARB 末尾、
并同步 gen-l10n 产物（本机无 flutter，跑不了 gen-l10n；产物提交进 git）。

用法：python3 tool/add_notice_entry_l10n.py
"""
import io
import json
import os
import re
import sys

# 键 → (zh, zh_TW, en, ja, es, id)
KEYS = {
    'noticeEntryDesc': (
        '查看官网发布的最新公告',
        '查看官網發布的最新公告',
        'Latest announcements from the website',
        '公式サイトの最新お知らせを見る',
        'Consulta los últimos avisos de la web',
        'Lihat pengumuman terbaru dari situs web'),
}

PLACEHOLDER_KEYS = {}

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

# 产物里插在哪个键之后（该键每个语言类都有，位置稳定）
ANCHOR_GETTER = 'tierMinTurnHint'


def dart_literal(s, holders):
    out = s
    for h in holders:
        out = out.replace('{' + h + '}', '${' + h + '}')
    return "'" + out.replace("'", r"\'") + "'"


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
            if key in PLACEHOLDER_KEYS:
                holders = ', '.join(
                    f'"{h}": {{"type": "String"}}' for h in PLACEHOLDER_KEYS[key])
                add.append(f'  "@{key}": {{"placeholders": {{{holders}}}}},')
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
            if k in PLACEHOLDER_KEYS:
                args = ', '.join(
                    f'String {h}' for h in PLACEHOLDER_KEYS[k])
                body = f'String {k}({args});'
            else:
                body = f'String get {k};'
            blocks.append(
                f'  /// No description provided for @{k}.\n'
                f'  ///\n'
                f'  /// In zh, this message translates to:\n'
                f'  /// **{json.dumps(KEYS[k][0], ensure_ascii=False)}**\n'
                f'  {body}')
        anchor = '  /// No description provided for @tierIdleTitle.'
        assert anchor in src, '抽象类锚点缺失'
        src = src.replace(anchor, '\n\n'.join(blocks) + '\n\n' + anchor, 1)
        io.open(p, 'w', encoding='utf-8').write(src)
        print(f'  抽象类: 追加 {len(missing)} 条声明')

    # ③ 各语言类
    for lg, fname, cls in TARGETS:
        p = os.path.join(l10n, fname)
        src = io.open(p, encoding='utf-8').read()
        i = src.find(f'class {cls}')
        assert i > 0, f'{fname}: 找不到 {cls}'
        body = src[i:src.find('\n}', i)]
        need = [k for k in KEYS if not re.search(
            r'String (?:get )?' + re.escape(k) + r'\s*[;(<={]', body)]
        if not need:
            continue
        m = re.compile(
            r"(?m)^  String get " + ANCHOR_GETTER + r" => '[^']*';\n").search(src, i)
        assert m, f'{cls}: 找不到 {ANCHOR_GETTER} 锚点'
        blocks = []
        for k in need:
            lit = dart_literal(KEYS[k][IDX[lg]], PLACEHOLDER_KEYS.get(k, []))
            if k in PLACEHOLDER_KEYS:
                args = ', '.join(f'String {h}' for h in PLACEHOLDER_KEYS[k])
                blocks.append(f'  @override\n  String {k}({args}) {{\n'
                              f'    return {lit};\n  }}')
            else:
                blocks.append(f'  @override\n  String get {k} => {lit};')
        src = src[:m.end()] + '\n' + '\n\n'.join(blocks) + '\n' + src[m.end():]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'  产物 {fname}/{cls}: 追加 {len(need)} 条')

    print(f'\narb 共写入 {total} 行')
    return 0


if __name__ == '__main__':
    sys.exit(main())
