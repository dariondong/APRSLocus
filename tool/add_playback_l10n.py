#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为「历史轨迹按天回放」补 l10n 键（6 语言）。

同时更新：
  * lib/l10n/app_*.arb                （真源）
  * lib/l10n/app_localizations.dart   （抽象类成员）
  * lib/l10n/app_localizations_*.dart （各语言实现）

产物按 gen-l10n 的形状手写（仓库把产物提交进了 git，本机不能跑 gen-l10n），
写完由 tool/check_l10n_sync.py 校验 arb ↔ 产物一一对应。
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}

# key → (zh, zh_TW, en, ja, es, id)
KEYS = {
    'historyTapDay': (
        '点按某一天可查看地图与回放',
        '點按某一天可查看地圖與回放',
        'Tap a day to see the map and replay it',
        '日をタップすると地図とリプレイを表示します',
        'Toca un día para ver el mapa y su reproducción',
        'Ketuk satu hari untuk melihat peta dan putar ulang'),
    'historyPlay': (
        '播放', '播放', 'Play', '再生', 'Reproducir', 'Putar'),
    'historyPause': (
        '暂停', '暫停', 'Pause', '一時停止', 'Pausar', 'Jeda'),
    'historyReplay': (
        '重播', '重播', 'Replay', 'もう一度再生', 'Repetir', 'Putar ulang'),
    'historyFollow': (
        '跟随', '跟隨', 'Follow', '追従', 'Seguir', 'Ikuti'),
}

# 生成类名（顺序与 LANGS 对应）
CLASSES = {
    'zh': 'AppLocalizationsZh',
    'zh_TW': 'AppLocalizationsZhTw',
    'en': 'AppLocalizationsEn',
    'ja': 'AppLocalizationsJa',
    'es': 'AppLocalizationsEs',
    'id': 'AppLocalizationsId',
}


def class_body(src, name):
    """返回 (类体起始, 类体结束) 两个索引。"""
    m = re.search(r'(?m)^(?:abstract )?class ' + re.escape(name) + r'\b', src)
    if not m:
        raise SystemExit(f'找不到类 {name}')
    j = src.find('\n}\n', m.end())
    if j < 0:
        j = src.rfind('\n}')
    return m.end(), j


def main() -> int:
    root = ROOT
    arb_dir = os.path.join(root, 'lib', 'l10n')

    # ① ARB
    for lg in LANGS:
        p = os.path.join(arb_dir, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8', newline='').read()
        add = []
        for key, vals in KEYS.items():
            if re.search(r'^\s*"' + re.escape(key) + r'":', src, re.M):
                print(f'  {lg}/{key}: 已存在，跳过')
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
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{lg}: ARB 追加 {len(add)} 键')

    # ② 抽象类（app_localizations.dart）
    p = os.path.join(arb_dir, 'app_localizations.dart')
    src = io.open(p, encoding='utf-8', newline='').read()
    code = []
    for key in KEYS:
        if f'String get {key};' in src:
            continue
        code.append(f'  /// No description provided for @{key}.')
        code.append('  ///')
        code.append('  /// In zh, this message translates to:')
        code.append(f"  /// **'{KEYS[key][0]}'**")
        code.append(f'  String get {key};')
        code.append('')
    if code:
        _s, j = class_body(src, 'AppLocalizations')
        src = src[:j] + '\n' + '\n'.join(code)[:-1] + src[j:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'抽象类追加 {len(code) // 6} 键')

    # ③ 各语言实现
    for lg in LANGS:
        name = CLASSES[lg]
        fn = ('app_localizations_zh.dart' if lg in ('zh', 'zh_TW')
              else f'app_localizations_{lg}.dart')
        p = os.path.join(arb_dir, fn)
        src = io.open(p, encoding='utf-8', newline='').read()
        b0, b1 = class_body(src, name)
        body = src[b0:b1]
        code = []
        for key, vals in KEYS.items():
            if re.search(r'String get ' + re.escape(key) + r'\s*[=;]', body):
                continue
            code.append('  @override')
            code.append(f"  String get {key} => "
                        f'{json.dumps(vals[IDX[lg]], ensure_ascii=False)};')
            code.append('')
        if not code:
            continue
        src = src[:b1] + '\n' + '\n'.join(code)[:-1] + src[b1:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{name}: 实现追加 {len(code) // 3} 键')

    print('done')
    return 0


if __name__ == '__main__':
    sys.exit(main())
