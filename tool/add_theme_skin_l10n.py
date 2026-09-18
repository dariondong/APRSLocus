#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为「皮肤 / 更高自定义」补 l10n 键（6 语言）。"""
import io, json, os, re, sys

# key → (zh, zh_TW, en, ja, es, id)
T = {
 'themeSurface': ('卡片表面', '卡片表面', 'Card surface', 'カード表面',
                  'Superficie de tarjeta', 'Permukaan kartu'),
 'themeSurfaceDesc': ('有背景图时，卡片要多透才既看得见图又读得清字',
                      '有背景圖時，卡片要多透才既看得見圖又讀得清字',
                      'With a background image, how translucent cards should be',
                      '背景画像があるときのカードの透過度',
                      'Con imagen de fondo, cuán translúcidas son las tarjetas',
                      'Saat ada latar, seberapa transparan kartu'),
 'themeSurfaceAlpha': ('不透明度（越低越透）', '不透明度（越低越透）',
                       'Opacity (lower is more see-through)',
                       '不透明度（低いほど透ける）',
                       'Opacidad (más bajo = más transparente)',
                       'Opasitas (makin rendah makin tembus)'),
 'themeSurfaceAlphaDesc': ('0.85 左右既保留遮盖力又透出一点背景；低于 0.6 文字容易糊',
                           '0.85 左右既保留遮蓋力又透出一點背景；低於 0.6 文字容易糊',
                           'Around 0.85 keeps coverage while showing the backdrop; '
                           'below 0.6 text starts to smear',
                           '0.85 前後なら下地を透かしつつ読めます。0.6 未満は文字が'
                           'にじみやすくなります',
                           'En torno a 0.85 cubre y deja ver el fondo; por debajo de '
                           '0.6 el texto se emborrona',
                           'Sekitar 0.85 menutup sekaligus memperlihatkan latar; '
                           'di bawah 0.6 teks mulai kabur'),
 'themeSurfaceNoBg': ('当前没有背景图，这一项暂时看不出效果',
                      '目前沒有背景圖，這一項暫時看不出效果',
                      'No background image is set, so this has no visible effect yet',
                      '背景画像がないため、今は効果が見えません',
                      'No hay imagen de fondo, así que aún no se nota',
                      'Belum ada gambar latar, jadi belum terlihat efeknya'),
 'themeLayout': ('界面松紧与字体', '介面鬆緊與字體', 'Density & font',
                 '余白とフォント', 'Densidad y tipografía',
                 'Kerapatan & font'),
 'themeLayoutDesc': ('只作用于卡片与输入框的留白，不改各处细节间距',
                     '只作用於卡片與輸入框的留白，不改各處細節間距',
                     'Affects card and input padding only, not every spacing',
                     'カードと入力欄の余白のみ。細かな間隔は変わりません',
                     'Solo afecta al relleno de tarjetas y campos',
                     'Hanya memengaruhi padding kartu dan kolom isian'),
 'themeDensity': ('松紧', '鬆緊', 'Density', '余白', 'Densidad', 'Kerapatan'),
 'themeDensityCompact': ('紧凑', '緊湊', 'Compact', '詰める', 'Compacta',
                         'Padat'),
 'themeDensityNormal': ('标准', '標準', 'Normal', '標準', 'Normal', 'Normal'),
 'themeDensityComfortable': ('宽松', '寬鬆', 'Comfortable', 'ゆったり',
                             'Amplia', 'Longgar'),
 'themeDensityHint': ('改的是卡片内边距；若某项看起来没变，说明那处留白是单独写死的',
                      '改的是卡片內邊距；若某項看起來沒變，說明那處留白是單獨寫死的',
                      'This changes card padding; if something looks unchanged, its '
                      'spacing is fixed individually',
                      'カードの余白を変えます。変わらない箇所は個別に固定されています',
                      'Cambia el relleno de las tarjetas; si algo no cambia, su '
                      'espaciado está fijado aparte',
                      'Ini mengubah padding kartu; jika ada yang tak berubah, '
                      'jaraknya ditetapkan terpisah'),
 'themeFont': ('字体', '字體', 'Font', 'フォント', 'Tipografía', 'Font'),
 'themeFontDefault': ('跟随系统', '跟隨系統', 'System default', 'システム既定',
                      'Predeterminada', 'Bawaan sistem'),
 'themeFontSystem': ('系统界面字体', '系統介面字體', 'System UI font',
                     'システム UI フォント', 'Fuente del sistema',
                     'Font antarmuka sistem'),
 'themeFontMono': ('等宽', '等寬', 'Monospace', '等幅', 'Monoespaciada',
                   'Monospace'),
 'themeFontHint': ('只使用系统已装的字体；某台设备没装时会自动回退，不会变方框',
                   '只使用系統已裝的字體；某台裝置沒裝時會自動回退，不會變方框',
                   'Uses system-installed fonts only; if one is missing it falls '
                   'back automatically (no tofu boxes)',
                   'システムにインストール済みのフォントのみ使用します。無い場合は'
                   '自動的に代替され、豆腐にはなりません',
                   'Solo usa fuentes instaladas en el sistema; si falta alguna, se '
                   'sustituye automáticamente',
                   'Hanya memakai font sistem; jika tidak ada, otomatis dialihkan'),
 'themeTabs': ('强调色', '強調色', 'Accent colours', 'アクセントカラー',
               'Colores de acento', 'Warna aksen'),
 'themeTabsDesc': ('入口卡片的渐变色，以及每个页签自己的强调色',
                   '入口卡片的漸變色，以及每個頁籤自己的強調色',
                   'The entry-card gradient, and a per-tab accent colour',
                   '入口カードのグラデーションと、タブごとのアクセントカラー',
                   'El degradado de las tarjetas y un color de acento por pestaña',
                   'Gradien kartu masuk dan warna aksen per tab'),
 'themeUniformAccent': ('统一入口卡片配色', '統一入口卡片配色',
                        'Unify entry-card colours',
                        '入口カードの配色を統一', 'Unificar colores de tarjetas',
                        'Samakan warna kartu masuk'),
 'themeAccentFrom': ('渐变起始色', '漸變起始色', 'Gradient start', 'グラデ開始',
                     'Inicio del degradado', 'Awal gradien'),
 'themeAccentTo': ('渐变结束色', '漸變結束色', 'Gradient end', 'グラデ終了',
                   'Fin del degradado', 'Akhir gradien'),
 'themeOverridden': ('已自定义', '已自訂', 'Custom', 'カスタム', 'Personalizado',
                     'Kustom'),
 'themeFollowsPrimary': ('跟随主色', '跟隨主色', 'Follows primary',
                         'メインカラーに追従', 'Sigue al principal',
                         'Ikut warna utama'),
 'themeBgAlign': ('对齐', '對齊', 'Alignment', '位置', 'Alineación', 'Perataan'),
 'themeAlignCenter': ('居中', '置中', 'Center', '中央', 'Centro', 'Tengah'),
 'themeAlignTop': ('上', '上', 'Top', '上', 'Arriba', 'Atas'),
 'themeAlignBottom': ('下', '下', 'Bottom', '下', 'Abajo', 'Bawah'),
 'themeAlignLeft': ('左', '左', 'Left', '左', 'Izquierda', 'Kiri'),
 'themeAlignRight': ('右', '右', 'Right', '右', 'Derecha', 'Kanan'),
 'themeAlignTopLeft': ('左上', '左上', 'Top left', '左上', 'Arriba izq.',
                       'Kiri atas'),
 'themeAlignTopRight': ('右上', '右上', 'Top right', '右上', 'Arriba der.',
                        'Kanan atas'),
 'themeAlignBottomLeft': ('左下', '左下', 'Bottom left', '左下', 'Abajo izq.',
                          'Kiri bawah'),
 'themeAlignBottomRight': ('右下', '右下', 'Bottom right', '右下', 'Abajo der.',
                           'Kanan bawah'),
 'themeBgScale': ('缩放', '縮放', 'Scale', '拡大縮小', 'Escala', 'Skala'),
 'themeBgScaleDesc': ('1.0 = 原始尺寸；放大可用于「只取画面一角」',
                      '1.0 = 原始尺寸；放大可用於「只取畫面一角」',
                      '1.0 = original size; zoom in to show only part of the image',
                      '1.0 = 元のサイズ。拡大すると一部だけを見せられます',
                      '1.0 = tamaño original; amplía para mostrar solo una parte',
                      '1.0 = ukuran asli; perbesar untuk menampilkan sebagian'),
 'themeAuthor': ('作者', '作者', 'Author', '作者', 'Autor', 'Penulis'),
 'themeDescription': ('说明', '說明', 'Description', '説明', 'Descripción',
                      'Deskripsi'),
 'themeSkinInfo': ('皮肤信息', '皮膚資訊', 'Skin info', 'スキン情報',
                   'Información de la skin', 'Info skin'),
 'themeSkinInfoDesc': ('分享给别人时，这两项会跟着皮肤一起走',
                       '分享給別人時，這兩項會跟著皮膚一起走',
                       'Both travel with the skin when you share it',
                       '共有すると、この 2 項も一緒に渡ります',
                       'Ambos viajan con la skin al compartirla',
                       'Keduanya ikut saat skin dibagikan'),
 'themeAuthorHint': ('你的呼号或昵称', '你的呼號或暱稱', 'Your callsign or nickname',
                     'コールサインかニックネーム', 'Tu indicativo o apodo',
                     'Callsign atau nama panggilan Anda'),
 'themeDescHint': ('一句话说明这套皮肤', '一句話說明這套皮膚',
                   'One line about this skin', 'このスキンの一言説明',
                   'Una línea sobre esta skin', 'Satu baris tentang skin ini'),
 'themePreviewSwatches': ('预览色板', '預覽色板', 'Preview swatches',
                          'プレビュー色', 'Muestras de color', 'Contoh warna'),
}
LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    total = 0
    for lg in LANGS:
        p = os.path.join(root, 'lib', 'l10n', f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8').read()
        add = []
        for key, vals in T.items():
            if re.search(r'^\s*"' + re.escape(key) + r'":', src, re.M):
                continue
            add.append('  %s: %s,' % (json.dumps(key, ensure_ascii=False),
                                      json.dumps(vals[IDX[lg]], ensure_ascii=False)))
        if not add:
            print(f'{lg}: 无新增'); continue
        i = src.rstrip().rfind('}')
        head = src[:i].rstrip()
        if not head.endswith(','): head += ','
        src = head + '\n' + '\n'.join(add).rstrip(',') + '\n' + src[i:]
        io.open(p, 'w', encoding='utf-8').write(src)
        total += len(add)
        print(f'{lg}: 追加 {len(add)} 行')
    print(f'\n共写入 {total} 行')
    return 0

if __name__ == '__main__':
    sys.exit(main())
