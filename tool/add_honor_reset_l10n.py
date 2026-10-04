#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""向 6 个 ARB 注入「清除已阅读荣誉」（开发者选项）文案。

文本级插入（保持原 ARB 的键序与格式），幂等可重复执行 —— 同 tool/add_*_l10n.py
的既有约定。
⚠ ICU：译文里不要出现落单的半角单引号（`'` 会被当转义符）。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATA = {
    'honorResetRow': {
        'zh': '清除已阅读荣誉',
        'zh_TW': '清除已閱讀榮譽',
        'en': 'Clear read honors',
        'ja': '既読の名誉を消去',
        'id': 'Hapus kehormatan yang dibaca',
        'es': 'Borrar distinciones leídas',
    },
    'honorResetTitle': {
        'zh': '清除已阅读荣誉？',
        'zh_TW': '清除已閱讀榮譽？',
        'en': 'Clear read honors?',
        'ja': '既読の名誉を消去しますか？',
        'id': 'Hapus kehormatan yang dibaca?',
        'es': '¿Borrar distinciones leídas?',
    },
    'honorResetConfirm': {
        'zh': '清空「已阅读」记录，下次进入会把当前已拥有的荣誉重新展示一遍。',
        'zh_TW': '清空「已閱讀」記錄，下次進入會把目前擁有的榮譽重新展示一遍。',
        'en': 'This clears the “read” record so every honor you already own '
              'shows again on the next launch.',
        'ja': '「既読」の記録を消去します。次回起動時に、現在持っている名誉が'
              'すべて再表示されます。',
        'id': 'Menghapus catatan “sudah dibaca” sehingga semua kehormatan yang '
              'sudah Anda miliki ditampilkan lagi saat berikutnya.',
        'es': 'Borra el registro de “leídas” para que todas las distinciones que '
              'ya tienes vuelvan a mostrarse la próxima vez.',
    },
    'honorResetButton': {
        'zh': '清除',
        'zh_TW': '清除',
        'en': 'Clear',
        'ja': '消去',
        'id': 'Hapus',
        'es': 'Borrar',
    },
    'honorResetDone': {
        'zh': '已阅读荣誉已清除',
        'zh_TW': '已閱讀榮譽已清除',
        'en': 'Read honors cleared',
        'ja': '既読の名誉を消去しました',
        'id': 'Kehormatan yang dibaca dihapus',
        'es': 'Distinciones leídas borradas',
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
        idx = next(i for i, ln in enumerate(keep)
                   if ln.strip().startswith(ANCHOR))
        block = ['  "%s": %s,' % (k, json.dumps(tr[lang], ensure_ascii=False))
                 for k, tr in DATA.items()]
        keep[idx + 1:idx + 1] = block
        io.open(path, 'w', encoding='utf-8').write('\n'.join(keep))
        d = json.loads(io.open(path, encoding='utf-8').read())
        print('%s ok, %d keys' % (os.path.basename(path),
                                  len([k for k in d if not k.startswith('@')])))


if __name__ == '__main__':
    main()
