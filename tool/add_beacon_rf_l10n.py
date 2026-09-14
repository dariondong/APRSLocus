#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""注入「射频信标未开启」相关文案（6 语言）。

背景：射频来源（TNC / 音频）下 canAutoBeacon 需要显式打开「射频信标」，
但倒计时 UI 曾经照走，用户看到「倒计时结束什么也没发生」。
现在 beaconPhase 会返回 rfDisabled，需要一组文案解释原因并给出开启入口。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATA = {
    'beaconRfBeaconOff': {
        'zh': '射频信标未开启', 'zh_TW': '射頻信標未開啟',
        'en': 'RF beacon is off', 'ja': 'RF ビーコンがオフ',
        'id': 'Beacon RF mati', 'es': 'Baliza RF desactivada',
    },
    'beaconRfEnableHint': {
        'zh': '射频来源的自动发射需要显式打开「射频信标」。在此之前不会自动发射位置（倒计时也不会走动）。',
        'zh_TW': '射頻來源的自動發射需要明確開啟「射頻信標」。在此之前不會自動發射位置（倒數也不會走動）。',
        'en': 'Automatic transmission on an RF source requires the “RF beacon” switch. Until then no position is transmitted automatically (and the countdown does not run).',
        'ja': 'RF ソースでの自動送信には「RF ビーコン」を明示的に有効にする必要があります。それまでは位置を自動送信しません（カウントダウンも進みません）。',
        'id': 'Pemancaran otomatis pada sumber RF memerlukan sakelar "Beacon RF". Sebelum itu posisi tidak dipancarkan otomatis (hitung mundur juga tidak berjalan).',
        'es': 'La transmisión automática en una fuente de RF requiere activar «Baliza RF». Hasta entonces no se transmite la posición automáticamente (ni corre la cuenta atrás).',
    },
    'beaconRfEnableAction': {
        'zh': '开启射频信标', 'zh_TW': '開啟射頻信標', 'en': 'Enable RF beacon',
        'ja': 'RF ビーコンを有効化', 'id': 'Aktifkan beacon RF',
        'es': 'Activar baliza RF',
    },
    'beaconRfEnabled': {
        'zh': '已开启射频信标，将按间隔自动发射',
        'zh_TW': '已開啟射頻信標，將按間隔自動發射',
        'en': 'RF beacon enabled — will transmit on schedule',
        'ja': 'RF ビーコンを有効化しました（間隔どおり自動送信します）',
        'id': 'Beacon RF aktif — akan memancar sesuai jadwal',
        'es': 'Baliza RF activada: transmitirá según el intervalo',
    },
    'beaconRfEnableWarn': {
        'zh': '发射将使用你的呼号，请在执照范围内操作',
        'zh_TW': '發射將使用你的呼號，請在執照範圍內操作',
        'en': 'Transmission uses your callsign — operate within your licence',
        'ja': '送信はあなたのコールサインで行われます。免許の範囲内で運用してください',
        'id': 'Pemancaran memakai tanda panggil Anda — patuhi lisensi',
        'es': 'La transmisión usa tu indicativo: opera dentro de tu licencia',
    },
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
ANCHOR = '"codeContributionTranslation"'


def main():
    for lang in LANGS:
        path = os.path.join(ROOT, 'lib/l10n/app_%s.arb' % lang)
        lines = io.open(path, encoding='utf-8').read().split('\n')
        out = []
        for ln in lines:
            stripped = ln.strip()
            if any(stripped.startswith('"%s"' % k) for k in DATA):
                continue
            out.append(ln)
        lines = out
        idx = None
        for i, ln in enumerate(lines):
            if ln.strip().startswith(ANCHOR):
                idx = i
                break
        assert idx is not None, 'anchor not found in %s' % path
        block = ['  "%s": %s,' % (k, json.dumps(v[lang], ensure_ascii=False))
                 for k, v in DATA.items()]
        lines[idx + 1:idx + 1] = block
        io.open(path, 'w', encoding='utf-8').write('\n'.join(lines))
        d = json.loads(io.open(path, encoding='utf-8').read())
        n = len([k for k in d if not k.startswith('@')])
        print('%s ok, %d keys (+%d)' % (path, n, len(DATA)))


if __name__ == '__main__':
    main()
