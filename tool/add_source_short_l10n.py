#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为「状态胶囊里的来源短名」补一个 l10n 键（6 语言）。

背景：2.0 右上角那一簇里，状态胶囊要显示「来源 · 状态」（例如「音频 · 已连接」）。
原有的 `dataSourceAudio` 是「音频（声卡）」—— 那是**设置页里**用的完整说法，
放进胶囊会和天气组件、连接按钮、定位按钮一起挤爆窄屏。

其余三个来源本来就是协议/缩写名，不需要翻译，直接用字面量：
`APRS-IS` / `TNC` / `PKWDWPL`（`dataSourcePkwdwpl` 那串「PKWDWPL（Kenwood 航点）」
里的括号说明同样只适合设置页）。只有「音频」是需要翻译的普通词，所以只补它。
"""
import io
import json
import os
import re
import sys

KEYS = {
    'dataSourceAudioShort': ('音频', '音訊', 'Audio', '音声', 'Audio', 'Audio'),
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
