#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为「备份包含历史轨迹」在导出页补 l10n 键（6 语言）。

背景：历史轨迹原本是按天落在文件里的（tracklog/YYYY-MM-DD.json），
不进「只认偏好键」的备份，所以换机后轨迹全丢。现在把轨迹拼入备份，
导出页需要一行如实说明「这份备份里带了多少天轨迹」——键 `backupTracks`
带一个 int 占位符 {n}。

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

# key → (zh, zh_TW, en, ja, es, id)；{n} 为占位符
KEY = 'backupTracks'
VALS = (
    '包含 {n} 天的历史轨迹',
    '包含 {n} 天的歷史軌跡',
    'Includes {n} days of track history',
    '{n} 日分の走行履歴を含む',
    'Incluye {n} días de historial de rutas',
    'Menyertakan {n} hari riwayat lintasan',
)

CLASSES = {
    'zh': 'AppLocalizationsZh',
    'zh_TW': 'AppLocalizationsZhTw',
    'en': 'AppLocalizationsEn',
    'ja': 'AppLocalizationsJa',
    'es': 'AppLocalizationsEs',
    'id': 'AppLocalizationsId',
}

# 「设置配置」组现在会一并带走历史轨迹，简介要如实补上，否则用户只看到
# 「电台、信标、地图…」会以为轨迹没备。语言 → (旧, 新)
DESC_FIX = {
    'zh': ('电台、信标、地图、筛选、数据来源、服务器',
           '电台、信标、地图、筛选、数据来源、服务器、历史轨迹'),
    'zh_TW': ('電台、信標、地圖、篩選、資料來源、伺服器',
              '電台、信標、地圖、篩選、資料來源、伺服器、歷史軌跡'),
    'en': ('Station, beacon, map, filters, sources, server',
           'Station, beacon, map, filters, sources, server, track history'),
    'ja': ('局、ビーコン、地図、フィルター、接続先、サーバー',
           '局、ビーコン、地図、フィルター、接続先、サーバー、走行履歴'),
    'es': ('Estación, baliza, mapa, filtros, fuentes, servidor',
           'Estación, baliza, mapa, filtros, fuentes, servidor, '
           'historial de rutas'),
    'id': ('Stasiun, beacon, peta, filter, sumber, server',
           'Stasiun, beacon, peta, filter, sumber, server, riwayat lintasan'),
}

ARB = {'zh': 'app_zh.arb', 'zh_TW': 'app_zh_TW.arb', 'en': 'app_en.arb',
       'ja': 'app_ja.arb', 'es': 'app_es.arb', 'id': 'app_id.arb'}
GEN = {'zh': 'app_localizations_zh.dart', 'zh_TW': 'app_localizations_zh.dart',
       'en': 'app_localizations_en.dart', 'ja': 'app_localizations_ja.dart',
       'es': 'app_localizations_es.dart', 'id': 'app_localizations_id.dart'}


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

    # ① arb：模板与各语言各加一条（带 placeholders 元数据）
    for lg in LANGS:
        p = os.path.join(arb_dir, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8', newline='').read()
        if re.search(r'^\s*"' + re.escape(KEY) + r'":', src, re.M):
            print(f'  {lg}/{KEY}: 已存在，跳过')
            continue
        entry = (f'  {json.dumps(KEY, ensure_ascii=False)}: '
                 f'{json.dumps(VALS[IDX[lg]], ensure_ascii=False)},\n'
                 f'  "@{KEY}": {{\n'
                 f'    "placeholders": {{"n": {{"type": "int"}}}}\n'
                 f'  }},')
        i = src.rstrip().rfind('}')
        head = src[:i].rstrip()
        if not head.endswith(','):
            head += ','
        # entry 末行的逗号要去掉：它后面直接就是闭合的 `}`，留着就是非法 JSON
        # （Illegal trailing comma）。head 的逗号负责分隔上一条与这一条。
        src = head + '\n' + entry.rstrip(',') + '\n' + src[i:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{lg}: ARB 追加 {KEY}')

    # ② 抽象类
    p = os.path.join(arb_dir, 'app_localizations.dart')
    src = io.open(p, encoding='utf-8', newline='').read()
    if f'String {KEY}(' not in src:
        code = (
            f'  /// No description provided for @{KEY}.\n'
            '  ///\n'
            '  /// In zh, this message translates to:\n'
            f"  /// **'{VALS[0]}'**\n"
            f'  String {KEY}(int n);\n'
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
        if re.search(r'String ' + re.escape(KEY) + r'\s*\(', body):
            print(f'  {lg}: 已存在，跳过')
            continue
        text = VALS[IDX[lg]].replace('{n}', '$n')
        code = ('  @override\n'
                f'  String {KEY}(int n) {{\n'
                f"    return '{text}';\n"
                '  }\n')
        src = src[:b1] + '\n' + code + src[b1:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{name}: 追加 {KEY}')

    # ④ 追加：把「设置配置」组简介补上「历史轨迹」
    for lg, (old, new) in DESC_FIX.items():
        for path in (os.path.join(arb_dir, ARB[lg]),
                     os.path.join(arb_dir, GEN[lg])):
            src = io.open(path, encoding='utf-8', newline='').read()
            if old in src:
                io.open(path, 'w', encoding='utf-8', newline='').write(
                    src.replace(old, new))
                print(f'{lg}: 简介已补历史轨迹（{os.path.basename(path)}）')
            elif new not in src:
                print(f'  {lg}: 简介旧文案未找到，跳过（{os.path.basename(path)}）')

    print('done')
    return 0


if __name__ == '__main__':
    sys.exit(main())
