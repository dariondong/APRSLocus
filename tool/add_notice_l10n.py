#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""公告横幅的 l10n 键（8 个 × 6 语言）。

背景：用户要求「在设置里添加一个公告横幅用户可以打开，公告内容从官网文件夹拉取，
md 应用内支持渲染 MD 和超链接」。

已有可复用的键：`retry`、`minutesAgo`、`hoursAgo`、`daysAgo`。
这里只补确实缺的 8 个（含 2 个带占位符的）。

写入约定与 tool/add_beacon_dist_l10n.py 一致：幂等、追加到 ARB 末尾，
并同步 gen-l10n 产物（本机无 flutter，跑不了 gen-l10n；产物提交进 git）。
"""
import io
import json
import os
import re
import sys

# 键 → (zh, zh_TW, en, ja, es, id)
KEYS = {
    'noticeTitle': ('公告', '公告', 'Announcements', 'お知らせ',
                    'Avisos', 'Pengumuman'),
    'noticeEmpty': ('暂无公告', '暫無公告', 'No announcements yet',
                    'お知らせはありません', 'Sin avisos por ahora',
                    'Belum ada pengumuman'),
    'noticeLoading': ('正在获取…', '正在取得…', 'Loading…', '取得中…',
                      'Cargando…', 'Memuat…'),
    'noticeReadMore': ('查看全文', '查看全文', 'Read more', '全文を読む',
                       'Leer más', 'Baca selengkapnya'),
    'noticeCached': ('缓存 · {ago}', '快取 · {ago}', 'Cached · {ago}',
                     'キャッシュ · {ago}', 'En caché · {ago}',
                     'Cache · {ago}'),
    'noticeOfflineCache': (
        '离线缓存 · {time}（联网后会自动更新）',
        '離線快取 · {time}（連網後會自動更新）',
        'Offline copy · {time} (updates automatically once online)',
        'オフラインのコピー · {time}（オンラインになると自動更新）',
        'Copia sin conexión · {time} (se actualiza al recuperar la red)',
        'Salinan offline · {time} (diperbarui otomatis saat online)'),
    'timeJustNow': ('刚刚', '剛剛', 'just now', 'たった今', 'ahora mismo',
                    'baru saja'),
    'refresh': ('刷新', '重新整理', 'Refresh', '更新', 'Actualizar',
                'Segarkan'),
}

# 带占位符的键 → 占位符名
PLACEHOLDER_KEYS = {'noticeCached': ['ago'], 'noticeOfflineCache': ['time']}

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
