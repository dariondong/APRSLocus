#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为「界面材质（磨砂玻璃 / 云母）」补 l10n 键（6 语言）。

写入约定与 tool/add_theme_bg_l10n.py 一致：幂等（同名键已存在就跳过）、
追加到 ARB 末尾，随后用 `flutter gen-l10n` 重新生成 Dart 侧。

注意：这里**不写** @key 元数据（与仓库里其它 add_*_l10n 脚本一致）——
生成的文件里那些键只有 "No description provided" 注释，Dart 侧不受影响。
"""
import io
import json
import os
import re
import sys

# key → (zh, zh_TW, en, ja, es, id)
KEYS = {
    'uiMaterial': ('界面材质', '介面材質', 'UI material', '画面マテリアル',
                   'Material de la interfaz', 'Material antarmuka'),
    'uiMaterialDesc': (
        '让卡片、顶栏与弹窗半透明，并在它们背后做真实模糊',
        '讓卡片、頂欄與彈窗半透明，並在她們背後做真實模糊',
        'Make cards, bars and dialogs translucent, with a real blur behind them',
        'カード・バー・ダイアログを半透明にし、その背後を実際にぼかします',
        'Hace translúcidas las tarjetas, barras y diálogos, con desenfoque real detrás',
        'Membuat kartu, bilah, dan dialog tembus pandang, dengan buram nyata di belakangnya'),
    'uiMaterialOff': ('关闭（实色）', '關閉（實色）', 'Off (solid)', 'オフ（不透明）',
                      'Desactivado (sólido)', 'Mati (padat)'),
    'uiMaterialOffDesc': (
        '表面实色，与旧版完全一致',
        '表面實色，與舊版完全一致',
        'Solid surfaces, exactly as before',
        '表面は不透明で、従来どおりです',
        'Superficies sólidas, igual que antes',
        'Permukaan padat, sama seperti sebelumnya'),
    'uiMaterialGlass': ('磨砂玻璃', '磨砂玻璃', 'Frosted glass', 'すりガラス',
                        'Cristal esmerilado', 'Kaca buram'),
    'uiMaterialGlassDesc': (
        '更透、模糊更强：像 Windows 11 的亚克力（Acrylic）',
        '更透、模糊更強：像 Windows 11 的壓克力（Acrylic）',
        'More transparent with a stronger blur — like Windows 11 Acrylic',
        'より透明でぼかしが強め。Windows 11 のアクリルに近い見た目です',
        'Más transparente y con más desenfoque, como el acrílico de Windows 11',
        'Lebih tembus pandang dengan buram lebih kuat, seperti Acrylic Windows 11'),
    'uiMaterialMica': ('云母', '雲母', 'Mica', 'マイカ', 'Mica', 'Mica'),
    'uiMaterialMicaDesc': (
        '更实、模糊较轻，带一层主色色调：像 Windows 11 的云母（Mica）',
        '更實、模糊較輕，帶一層主色色調：像 Windows 11 的雲母（Mica）',
        'More solid with a lighter blur and a tint of your accent colour — '
        'like Windows 11 Mica',
        'より不透明でぼかしは控えめ、アクセント色がうっすら乗ります。'
        'Windows 11 のマイカに近い見た目です',
        'Más sólido, con menos desenfoque y un matiz de tu color de acento, '
        'como el Mica de Windows 11',
        'Lebih padat dengan buram ringan dan sedikit warna aksen, '
        'seperti Mica Windows 11'),
    'uiMaterialHint': (
        '材质只作用于应用自己的表面（卡片、顶栏、导航栏、弹窗、地图浮层），'
        '不是系统窗口的透明。模糊要占显卡：旧机型上可能不如关闭时顺滑。',
        '材質只作用於應用程式自己的表面（卡片、頂欄、導覽列、彈窗、地圖浮層），'
        '不是系統視窗的透明。模糊要佔顯卡：舊機型上可能不如關閉時順暢。',
        'The material only affects the app\'s own surfaces (cards, bars, dialogs, '
        'map overlays) — it is not window transparency. Blur costs GPU time, so on '
        'older devices it may feel less smooth than Off.',
        'マテリアルはアプリ内の表面（カード・バー・ダイアログ・地図の重なり）だけに'
        'かかります。ウィンドウ自体の透明化ではありません。ぼかしは GPU を使うため、'
        '古い端末ではオフより動作が重くなることがあります。',
        'El material solo afecta a las superficies de la app (tarjetas, barras, '
        'diálogos, capas del mapa); no es transparencia de ventana. El desenfoque '
        'consume GPU: en equipos antiguos puede ir menos fluido que con «Desactivado».',
        'Material hanya memengaruhi permukaan aplikasi (kartu, bilah, dialog, lapisan '
        'peta); bukan transparansi jendela. Buram memakai GPU, jadi di perangkat lama '
        'mungkin terasa kurang lancar dibanding Mati.'),
    'uiMaterialBgHint': (
        '当前主题用了背景图：材质不再另画底色，只把顶栏与浮层做成磨砂。',
        '目前主題用了背景圖：材質不再另畫底色，只把頂欄與浮層做成磨砂。',
        'This theme uses a background image, so the material adds no backdrop of its '
        'own and only frosts the bars and overlays.',
        'このテーマは背景画像を使っているため、マテリアルは独自の背景を描かず、'
        'バーと重なりだけをぼかします。',
        'Este tema usa una imagen de fondo, así que el material no añade fondo propio '
        'y solo esmerila las barras y las capas.',
        'Tema ini memakai gambar latar, jadi material tidak menambah latar sendiri dan '
        'hanya membuat bilah serta lapisan menjadi buram.'),
    'uiMaterialPreview': ('预览', '預覽', 'Preview', 'プレビュー', 'Vista previa',
                          'Pratinjau'),
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
            val = vals[IDX[lg]]
            add.append(f'  {json.dumps(key, ensure_ascii=False)}: '
                       f'{json.dumps(val, ensure_ascii=False)},')
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
