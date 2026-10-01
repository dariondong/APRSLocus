#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""向 6 个 ARB 注入「赞赏声明」文案（赞赏页用，与用户协议 9.4 同一口径）。

文本级插入（保持原 ARB 的键序与格式），幂等可重复执行 —— 同 tool/add_*_l10n.py 的既有约定。
⚠ ICU：译文里不要出现落单的半角单引号（`'` 会被当转义符）。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATA = {
    'donateNotice': {
        'zh': '赞赏完全出于自愿：不换取任何功能、优先支持或服务承诺，且不予退还；'
              '未成年人请在监护人同意后再进行。',
        'zh_TW': '贊賞完全出於自願：不換取任何功能、優先支援或服務承諾，且不予退還；'
                 '未成年人請在監護人同意後再進行。',
        'en': 'Tips are entirely voluntary: they do not buy any feature, priority support, '
              'or service commitment, and are non-refundable. Minors should ask a guardian '
              'first.',
        'ja': 'ご支援は完全に任意です：機能・優先サポート・サービスを約束するものではなく、'
              '返金もできません。未成年の方は保護者の同意を得てからお願いします。',
        'id': 'Dukungan sepenuhnya sukarela: tidak menukar fitur, dukungan prioritas, atau '
              'jaminan layanan apa pun, dan tidak dapat dikembalikan. Anak di bawah umur '
              'harap meminta izin orang tua/wali.',
        'es': 'Las donaciones son totalmente voluntarias: no compran ninguna función, '
              'soporte prioritario ni compromiso de servicio, y no son reembolsables. '
              'Los menores deben pedir permiso a su tutor.',
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
