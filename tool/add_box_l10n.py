#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""给「盒子连接」页补两条属于盒子自己的文案（原来复用了 TNC 的）。

盒子页的按钮原来写的是「连接 TNC」、未支持时提示「暂不支持 TNC 链路」—— 盒子不是 TNC，
这两句会让用户以为连的是 TNC。其余文案（已绑定设备 / 扫描设备 / 需要蓝牙权限…）本来就是
中性措辞，不动。

文本级插入，幂等可重复执行 —— 同 tool/add_*_l10n.py 的既有约定。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATA = {
    'boxConnectAction': {
        'zh': '连接盒子', 'zh_TW': '連接盒子', 'en': 'Connect box',
        'ja': 'ボックスに接続', 'id': 'Sambung kotak', 'es': 'Conectar caja',
    },
    'boxLinkUnsupported': {
        'zh': '当前平台暂不支持盒子链路（需要蓝牙或 USB 串口）',
        'zh_TW': '目前平台暫不支援盒子鏈路（需要藍牙或 USB 序列埠）',
        'en': 'The box link is not supported on this platform (needs Bluetooth or USB serial)',
        'ja': 'このプラットフォームはボックス接続に対応していません（Bluetooth または USB シリアルが必要）',
        'id': 'Tautan kotak tidak didukung di platform ini (perlu Bluetooth atau serial USB)',
        'es': 'El enlace de la caja no es compatible en esta plataforma (requiere Bluetooth o serie USB)',
    },
    'boxNoDevicePaired': {
        'zh': '未找到设备 · 先到系统蓝牙设置里配对盒子，或插上 USB 串口线（OTG）',
        'zh_TW': '找不到裝置 · 先到系統藍牙設定裡配對盒子，或插上 USB 序列埠線（OTG）',
        'en': 'No device found - pair the box in system Bluetooth settings first, or plug in a '
              'USB serial cable (OTG)',
        'ja': 'デバイスが見つかりません。先にシステムの Bluetooth 設定でボックスをペアリングするか、'
              'USB シリアルケーブル（OTG）を接続してください',
        'id': 'Perangkat tidak ditemukan - pasangkan kotak di pengaturan Bluetooth sistem, '
              'atau tancapkan kabel serial USB (OTG)',
        'es': 'No se encontró ningún dispositivo: empareja la caja en los ajustes de Bluetooth '
              'del sistema o conecta un cable serie USB (OTG)',
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
