#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""「热力图档位」的文案（六语言）：档位本身 + 弱/中/强三档。"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = {
    'heatLevel': {
        'zh': '热力图档位', 'zh_TW': '熱力圖檔位', 'en': 'Heatmap level',
        'ja': 'ヒートマップの強さ', 'id': 'Tingkat peta panas', 'es': 'Nivel del mapa de calor',
    },
    'heatLevelLow': {
        'zh': '弱', 'zh_TW': '弱', 'en': 'Light', 'ja': '弱', 'id': 'Ringan', 'es': 'Suave',
    },
    'heatLevelMid': {
        'zh': '中', 'zh_TW': '中', 'en': 'Medium', 'ja': '中', 'id': 'Sedang', 'es': 'Medio',
    },
    'heatLevelHigh': {
        'zh': '强', 'zh_TW': '強', 'en': 'Strong', 'ja': '強', 'id': 'Kuat', 'es': 'Fuerte',
    },
}
LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
ANCHOR = '"dataSourceSwitchHint"'


def main():
    for lang in LANGS:
        path = os.path.join(ROOT, 'lib/l10n/app_%s.arb' % lang)
        lines = io.open(path, encoding='utf-8').read().split('\n')
        keep = [ln for ln in lines
                if not any(ln.strip().startswith('"%s"' % k) for k in DATA)]
        idx = next(i for i, ln in enumerate(keep) if ln.strip().startswith(ANCHOR))
        block = ['  "%s": %s,' % (k, json.dumps(tr[lang], ensure_ascii=False))
                 for k, tr in DATA.items()]
        keep[idx + 1:idx + 1] = block
        io.open(path, 'w', encoding='utf-8').write('\n'.join(keep))
        d = json.loads(io.open(path, encoding='utf-8').read())
        print('%s ok, %d keys' % (os.path.basename(path),
                                  len([k for k in d if not k.startswith('@')])))


if __name__ == '__main__':
    main()
