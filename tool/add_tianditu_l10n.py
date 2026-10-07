#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""天地图图层文案（6 语言）：分组标题 + 三张天地图底图名。

背景：用户要求「添加天地图的地形图、等高线图，什么图都添加」。底图新增三张
天地图瓦片（矢量 `vec` / 影像 `img` / 地形 `ter`，见 lib/map_math.dart 的
MapType.tianditu|tianditu_img|tianditu_ter），并单独归到「天地图」分组 ——
分组标题与图源名要能在 6 种界面语言下显示。

做法沿用本仓库惯例（arb 为真源 → 抽象类 → 各语言产物），插在既有
`mapTypeEsriHillshade` 之后，保持 mapType* 家族挨在一起，便于人工对照。
"""
import io
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L10N = os.path.join(ROOT, 'lib', 'l10n')

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
IDX = {lg: i for i, lg in enumerate(LANGS)}

TARGETS = [
    ('zh', 'app_localizations_zh.dart', 'AppLocalizationsZh'),
    ('zh_TW', 'app_localizations_zh.dart', 'AppLocalizationsZhTw'),
    ('en', 'app_localizations_en.dart', 'AppLocalizationsEn'),
    ('ja', 'app_localizations_ja.dart', 'AppLocalizationsJa'),
    ('es', 'app_localizations_es.dart', 'AppLocalizationsEs'),
    ('id', 'app_localizations_id.dart', 'AppLocalizationsId'),
]

# key → (zh, zh_TW, en, ja, id, es)
KEYS = {
    'tiandituGroup': (
        '天地图', '天地圖', 'Tianditu', '天地図', 'Tianditu', 'Tianditu',
    ),
    'mapTypeTianditu': (
        '天地图 矢量', '天地圖 向量', 'Tianditu Vector',
        '天地図 ベクター', 'Tianditu Vektor', 'Tianditu vectorial',
    ),
    'mapTypeTiandituImg': (
        '天地图 影像', '天地圖 影像', 'Tianditu Imagery',
        '天地図 衛星写真', 'Tianditu Citra', 'Tianditu imágenes',
    ),
    'mapTypeTiandituTer': (
        '天地图 地形', '天地圖 地形', 'Tianditu Terrain',
        '天地図 地形', 'Tianditu Terrain', 'Tianditu terreno',
    ),
}

ANCHOR_GETTER = 'mapTypeEsriHillshade'


def dart_literal(s):
    return "'" + s.replace('\\', '\\\\').replace("'", r"\'") + "'"


def main() -> int:
    # ① arb：插在 mapTypeEsriHillshade 那一行之后（保持 mapType* 家族相邻）
    total = 0
    for lg in LANGS:
        p = os.path.join(L10N, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8').read()
        lines = src.split('\n')
        anchor = None
        for i, ln in enumerate(lines):
            if re.match(r'\s*"' + ANCHOR_GETTER + r'":', ln):
                anchor = i
                break
        assert anchor is not None, f'{p}: 找不到 {ANCHOR_GETTER} 锚点'
        add = []
        for key, vals in KEYS.items():
            if re.search(r'"' + re.escape(key) + r'":', src):
                continue
            add.append('  %s: %s,' % (json.dumps(key, ensure_ascii=False),
                                      json.dumps(vals[IDX[lg]], ensure_ascii=False)))
        if add:
            lines[anchor + 1:anchor + 1] = add
            out = '\n'.join(lines)
            # 立刻验 JSON：拼错在这里就炸，不要留到 check 脚本才发现
            json.loads(out)
            io.open(p, 'w', encoding='utf-8', newline='').write(out)
        total += len(add)
        print(f'  arb {lg}: +{len(add)}')

    # ② 抽象类：插在 mapTypeEsriHillshade 声明块之后
    p = os.path.join(L10N, 'app_localizations.dart')
    src = io.open(p, encoding='utf-8').read()
    blocks = []
    for key, vals in KEYS.items():
        if re.search(r'String (?:get )?' + re.escape(key) + r'\s*[;(<={]', src):
            continue
        blocks.append(
            f'  /// No description provided for @{key}.\n'
            f'  ///\n'
            f'  /// In zh, this message translates to:\n'
            f'  /// **{json.dumps(vals[0], ensure_ascii=False)}**\n'
            f'  String get {key};')
    if blocks:
        m = re.search(r'(?m)^  String get ' + ANCHOR_GETTER + r';\s*$', src)
        assert m, '抽象类：找不到锚点声明'
        src = src[:m.end()] + '\n\n' + '\n\n'.join(blocks) + src[m.end():]
        io.open(p, 'w', encoding='utf-8').write(src)
    print(f'  抽象类 +{len(blocks)}')

    # ③ 各语言类：插在 mapTypeEsriHillshade getter 之后。
    #    zh 与 zh_TW 同文件，必须按类体定位 —— 否则第二遍会写到第一遍的位置。
    for lg, fname, cls in TARGETS:
        p = os.path.join(L10N, fname)
        src = io.open(p, encoding='utf-8').read()
        i = src.find(f'class {cls}')
        assert i > 0, f'{fname}: 找不到 {cls}'
        end = src.find('\n}', i)
        body = src[i:end]
        blocks = []
        for key, vals in KEYS.items():
            if re.search(r'String (?:get )?' + re.escape(key) + r'\s*[;(<={]', body):
                continue
            blocks.append('  @override\n  String get %s => %s;'
                          % (key, dart_literal(vals[IDX[lg]])))
        if blocks:
            m = re.search(r'(?m)^  String get ' + ANCHOR_GETTER +
                          r' => [^\n]*;\s*$', body)
            assert m, f'{fname}: {cls} 里找不到锚点 getter'
            body = body[:m.end()] + '\n\n' + '\n\n'.join(blocks) + body[m.end():]
            src = src[:i] + body + src[end:]
            io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'  {cls} +{len(blocks)}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
