#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""「新建会话 → 从收藏台站开始」的文案（六语言）。"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = {
    'startFromFavorites': {
        'zh': '从收藏台站开始', 'zh_TW': '從收藏臺站開始',
        'en': 'Start from a favourite station',
        'ja': 'お気に入りの局から始める',
        'id': 'Mulai dari stasiun favorit',
        'es': 'Empezar desde una estación favorita',
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
