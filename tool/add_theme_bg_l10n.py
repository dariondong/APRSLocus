#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为「主题 · 背景图」补 l10n 键（6 语言）。

写入约定与 tool/add_theme_l10n.py 一致。
"""
import io
import json
import os
import re
import sys

# key → (zh, zh_TW, en, ja, es, id)
KEYS = {
    'themeBg': ('背景图', '背景圖', 'Background image', '背景画像',
                'Imagen de fondo', 'Gambar latar'),
    'themeBgDesc': ('用一张图片做整个界面的底；卡片会自动变得半透明',
                    '用一張圖片做整個介面的底；卡片會自動變得半透明',
                    'Use an image as the app backdrop; cards turn translucent '
                    'automatically',
                    '画像をアプリ全体の背景に。カードは自動的に半透明になります',
                    'Usa una imagen como fondo; las tarjetas se vuelven '
                    'transparentes automáticamente',
                    'Pakai gambar sebagai latar; kartu otomatis jadi semi-transparan'),
    'themeBgPick': ('选择图片', '選擇圖片', 'Choose image', '画像を選ぶ',
                    'Elegir imagen', 'Pilih gambar'),
    'themeBgReplace': ('更换图片', '更換圖片', 'Replace image', '画像を変更',
                       'Cambiar imagen', 'Ganti gambar'),
    'themeBgRemove': ('移除背景图', '移除背景圖', 'Remove background',
                      '背景を削除', 'Quitar fondo', 'Hapus latar'),
    'themeBgOpacity': ('不透明度', '不透明度', 'Opacity', '不透明度',
                       'Opacidad', 'Opasitas'),
    'themeBgOpacityDesc': ('同时决定遮罩浓度：调高更看见图，也更容易看不清文字',
                           '同時決定遮罩濃度：調高更看見圖，也更容易看不清文字',
                           'Also sets the veil strength: higher shows more image and '
                           'risks unreadable text',
                           'マスクの濃さも兼ねます。上げるほど画像が見え、'
                           '文字が読みにくくなります',
                           'También define el velo: más alto muestra más imagen y '
                           'arriesga la legibilidad',
                           'Sekaligus mengatur kerudung: makin tinggi makin '
                           'terlihat gambarnya, makin berisiko teks tak terbaca'),
    'themeBgBlur': ('模糊', '模糊', 'Blur', 'ぼかし', 'Desenfoque', 'Buram'),
    'themeBgBlurDesc': ('模糊能把照片的细节压掉，让上面的文字更清楚',
                        '模糊能把照片的細節壓掉，讓上面的文字更清楚',
                        'Blurring removes photo detail so text on top stays legible',
                        'ぼかすと写真の細部が消え、上の文字が読みやすくなります',
                        'El desenfoque elimina detalle y hace legible el texto encima',
                        'Pemburaman menghapus detail foto agar teks di atasnya '
                        'tetap terbaca'),
    'themeBgFit': ('填充方式', '填滿方式', 'Fill mode', '表示方法',
                   'Modo de ajuste', 'Mode isian'),
    'themeBgFitCover': ('铺满', '鋪滿', 'Cover', '全面', 'Cubrir', 'Penuh'),
    'themeBgFitContain': ('完整显示', '完整顯示', 'Contain', '全体表示',
                          'Contener', 'Muat'),
    'themeBgFitStretch': ('拉伸', '拉伸', 'Stretch', '引き伸ばし',
                          'Estirar', 'Regangkan'),
    'themeBgFitTile': ('平铺', '並排', 'Tile', 'タイル', 'Mosaico', 'Ubin'),
    'themeBgNone': ('未设置', '未設定', 'Not set', '未設定', 'Sin definir',
                    'Belum diatur'),
    'themeBgErrTooLarge': ('背景图超过 8MB，请先压缩（图标上限是 2MB）',
                           '背景圖超過 8MB，請先壓縮（圖示上限是 2MB）',
                           'The background is larger than 8 MB — compress it first '
                           '(icons are capped at 2 MB)',
                           '背景画像が 8MB を超えています。圧縮してください'
                           '（アイコンは 2MB まで）',
                           'El fondo supera los 8 MB: comprímelo '
                           '(los iconos tienen un límite de 2 MB)',
                           'Latar melebihi 8 MB — kompres dulu '
                           '(ikon dibatasi 2 MB)'),
    'themeBgLocalOnly': ('背景图只存在本机：主题文件里只记录引用，不含图片本身，'
                         '分享给别人后对方会看到无背景的主题。',
                         '背景圖只存在本機：主題檔裡只記錄引用，不含圖片本身，'
                         '分享給別人後對方會看到無背景的主題。',
                         'The image stays on this device: the theme file records only '
                         'a reference, not the image, so anyone you share it with '
                         'sees the theme without a background.',
                         '背景画像はこの端末にのみ保存されます。テーマファイルには'
                         '参照だけが記録され、画像自体は含まれないため、'
                         '共有した相手には背景なしのテーマが表示されます。',
                         'La imagen se queda en este dispositivo: el archivo de tema '
                         'solo guarda una referencia, así que quien lo reciba verá el '
                         'tema sin fondo.',
                         'Gambar tetap di perangkat ini: berkas tema hanya mencatat '
                         'referensi, bukan gambarnya, jadi penerima akan melihat tema '
                         'tanpa latar.'),
    'themeBgDisabledHint': ('当前主题未使用背景图，界面底为纯色',
                            '目前主題未使用背景圖，介面底為純色',
                            'This theme has no background image; the backdrop is a '
                            'solid colour',
                            'このテーマに背景画像はありません。背景は単色です',
                            'Este tema no tiene fondo: el fondo es un color sólido',
                            'Tema ini tanpa gambar latar; latarnya warna solid'),
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
