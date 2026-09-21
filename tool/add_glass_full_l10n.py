#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为「满血磨砂玻璃」档补 l10n 键（6 语言）。

背景：用户反馈「默认状态下小图层没有磨砂效果」，并明确要「加一个满血磨砂玻璃按键」。
现有的「磨砂玻璃」档给工具钮/图例这类**小浮层**只上 12 的轻磨砂（半径给大反而会把
38px 的边缘糊成一团灰），所以小东西看起来「没有磨砂」。新增一档把该顾虑放下：
小浮层也用满强度模糊。需要两个键（档名 + 说明）。

写入约定与 tool/add_link_status_l10n.py 一致：幂等、追加到 ARB 末尾，随后 gen-l10n。
"""
import io
import json
import os
import re
import sys

KEYS = {
    'uiMaterialGlassFull': ('满血磨砂玻璃', '滿血磨砂玻璃',
                            'Full frosted glass', 'フルすりガラス',
                            'Cristal esmerilado intenso', 'Kaca buram penuh'),
    'uiMaterialGlassFullDesc': (
        '最透、最糊，而且**小组件也一起糊**（工具钮 / 图例 / 小提示都有磨砂）'
        '—— 观感最重，也最吃显卡',
        '最透、最糊，而且**小元件也一起糊**（工具鈕 / 圖例 / 小提示都有磨砂）'
        '—— 觀感最重，也最吃顯卡',
        'The most transparent and the blurriest, **including the small widgets** '
        '(map tool buttons, legend, hint pills) — the heaviest look, and the '
        'heaviest on the GPU',
        '最も透明で最もぼかしが強く、**小さな部品も一緒にぼかします**'
        '（地図のツールボタン・凡例・ヒント）。見た目は最も重く、GPU 負荷も最大です',
        'Lo más transparente y con más desenfoque, **incluidos los widgets '
        'pequeños** (botones del mapa, leyenda, avisos): el aspecto más marcado y '
        'también el más exigente para la GPU',
        'Paling tembus pandang dan paling buram, **termasuk widget kecil** '
        '(tombol peta, legenda, petunjuk) — tampilan paling tebal, dan paling '
        'memberatkan GPU'),
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    arb_dir = os.path.join(root, 'lib', 'l10n')
    total = 0
    for lg in LANGS:
        p = os.path.join(arb_dir, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8').read()
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
        io.open(p, 'w', encoding='utf-8').write(src)
        total += len(add)
        print(f'{lg}: 追加 {len(add)} 行')
    print(f'\n共写入 {total} 行')
    return 0


if __name__ == '__main__':
    sys.exit(main())
