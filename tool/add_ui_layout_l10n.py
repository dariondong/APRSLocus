#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为「界面布局（1.0 经典 / 2.0 地图为基底）」补 l10n 键（6 语言）。

写入约定与 tool/add_ui_material_l10n.py 一致：幂等、追加到 ARB 末尾，
随后 `flutter gen-l10n` 重新生成 Dart 侧。
"""
import io
import json
import os
import re
import sys

# key → (zh, zh_TW, en, ja, es, id)
KEYS = {
    'uiLayout': ('界面布局', '介面佈局', 'UI layout', '画面レイアウト',
                 'Diseño de la interfaz', 'Tata letak antarmuka'),
    'uiLayoutDesc': (
        '2.0 把地图当成整个界面的底：其余页面收进底部可上滑的卡片',
        '2.0 把地圖當成整個介面的底：其餘頁面收進底部可上滑的卡片',
        '2.0 uses the map as the base of the whole UI, with the other pages '
        'in a draggable card at the bottom',
        '2.0 では地図を画面全体の土台にし、他のページは下部のドラッグできる'
        'カードに収めます',
        '2.0 usa el mapa como base de toda la interfaz y coloca las demás '
        'páginas en una tarjeta deslizable abajo',
        '2.0 memakai peta sebagai dasar seluruh antarmuka dan menaruh halaman '
        'lain di kartu yang bisa digeser di bawah'),
    'uiLayoutClassic': ('经典布局（1.0）', '經典佈局（1.0）',
                        'Classic layout (1.0)', 'クラシック（1.0）',
                        'Diseño clásico (1.0)', 'Tata letak klasik (1.0)'),
    'uiLayoutClassicDesc': (
        '宽屏左侧栏 + 窄屏底部导航，与旧版完全一致',
        '寬螢幕左側欄 + 窄螢幕底部導覽，與舊版完全一致',
        'Side rail on wide screens, bottom navigation on narrow ones — '
        'exactly as before',
        '広い画面は左サイドバー、狭い画面は下部ナビ。従来どおりです',
        'Barra lateral en pantallas anchas y navegación inferior en las '
        'estrechas, igual que antes',
        'Bilah samping di layar lebar, navigasi bawah di layar sempit, '
        'sama seperti sebelumnya'),
    'uiLayoutSheet': ('地图为基底（2.0）', '地圖為基底（2.0）',
                      'Map-first (2.0)', '地図ベース（2.0）',
                      'Mapa como base (2.0)', 'Peta sebagai dasar (2.0)'),
    'uiLayoutSheetDesc': (
        '地图常驻整屏；台站 / 消息 / 数据包 / 设置装进底部可拖拽卡片，'
        '上滑或点把手即可展开',
        '地圖常駐整螢幕；台站 / 訊息 / 資料包 / 設定收進底部可拖曳卡片，'
        '上滑或點把手即可展開',
        'The map stays full-screen; stations / messages / packets / settings '
        'live in a draggable card below — swipe up or tap the handle to expand',
        '地図は常に全画面。台站 / メッセージ / パケット / 設定は下部の'
        'ドラッグできるカードに入り、上スワイプかハンドルのタップで開きます',
        'El mapa ocupa toda la pantalla; estaciones / mensajes / paquetes / '
        'ajustes van en una tarjeta deslizable abajo: desliza hacia arriba o '
        'toca el asa para expandirla',
        'Peta selalu layar penuh; stasiun / pesan / paket / pengaturan ada di '
        'kartu yang bisa digeser di bawah — geser ke atas atau ketuk '
        'pegangannya untuk membuka'),
    'uiLayoutHint': (
        '切换后立即生效，两种布局的设置各自保留；卡片收起时地图上的按钮会自动上移',
        '切換後立即生效，兩種佈局的設定各自保留；卡片收起時地圖上的按鈕會自動上移',
        'Takes effect immediately; both layouts keep their own settings. '
        'Map controls move up automatically as the card collapses',
        'すぐに反映されます。両レイアウトの設定は別々に保持されます。'
        'カードを畳むと地図上のボタンが自動で上に移動します',
        'Se aplica al instante; cada diseño conserva sus propios ajustes. '
        'Los controles del mapa suben solos al plegarse la tarjeta',
        'Langsung berlaku; kedua tata letak menyimpan pengaturannya sendiri. '
        'Tombol di peta otomatis naik saat kartu dilipat'),
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
