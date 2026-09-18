#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为「主题（自定义界面）」补 l10n 键（6 语言）。

写入约定与 tool/add_backup_l10n.py / tool/add_sys_widget_l10n.py 完全一致：
按锚点插入 ARB 的 `"key": "值"` 行，随后 `flutter gen-l10n` 重新生成。
"""
import io
import json
import os
import re
import sys

# key → (zh, zh_TW, en, ja, es, id)
KEYS = {
    # 入口与总览
    'themeTitle': ('主题', '主題', 'Theme', 'テーマ', 'Tema', 'Tema'),
    'themeEntryDesc': ('自定义颜色、图标与文字', '自訂顏色、圖示與文字',
                       'Custom colours, icons and text',
                       '色・アイコン・文字をカスタマイズ',
                       'Personaliza colores, iconos y texto',
                       'Sesuaikan warna, ikon, dan teks'),
    'themeSubtitle': ('把界面配色、图标与常用文案改成你自己的',
                      '把介面配色、圖示與常用文案改成你自己的',
                      'Make the colours, icons and common labels your own',
                      '配色・アイコン・よく使う文言を自分好みに',
                      'Haz tuyos los colores, iconos y textos habituales',
                      'Jadikan warna, ikon, dan teks umum milik Anda'),
    'themePresets': ('预设与我的主题', '預設與我的主題', 'Presets & my themes',
                     'プリセットと自分のテーマ', 'Preajustes y mis temas',
                     'Preset & tema saya'),
    'themePresetTag': ('预设', '預設', 'preset', 'プリセット', 'preajuste',
                       'preset'),
    'themeActive': ('使用中', '使用中', 'In use', '使用中', 'En uso',
                    'Sedang dipakai'),
    'themePresetDefault': ('默认', '預設', 'Default', '既定', 'Predeterminado',
                           'Bawaan'),
    'themePresetOcean': ('海洋', '海洋', 'Ocean', 'オーシャン', 'Océano',
                         'Samudra'),
    'themePresetForest': ('森林', '森林', 'Forest', 'フォレスト', 'Bosque',
                          'Hutan'),
    'themePresetMidnight': ('暗夜', '暗夜', 'Midnight', 'ミッドナイト',
                            'Medianoche', 'Tengah malam'),
    'themePresetSunset': ('日落', '日落', 'Sunset', 'サンセット', 'Atardecer',
                          'Senja'),
    'themePresetContrast': ('高对比', '高對比', 'High contrast', 'ハイコントラスト',
                            'Alto contraste', 'Kontras tinggi'),
    'themeBuiltinHint': ('预设主题不可修改，复制为我的主题后即可自由编辑',
                         '預設主題不可修改，複製為我的主題後即可自由編輯',
                         'Presets cannot be edited — copy one to your themes first',
                         'プリセットは編集できません。自分のテーマに複製してください',
                         'Los preajustes no se editan: cópialos a tus temas',
                         'Preset tidak bisa diubah — salin dulu ke tema Anda'),
    # 分区
    'themeColors': ('颜色', '顏色', 'Colours', '色', 'Colores', 'Warna'),
    'themeColorsDesc': ('逐项覆写配色；未修改的项跟随默认',
                        '逐項覆寫配色；未修改的項跟隨預設',
                        'Overwrite colours individually; untouched ones stay default',
                        '項目ごとに上書き（未変更は既定のまま）',
                        'Sobrescribe colores uno a uno; el resto queda por defecto',
                        'Timpa warna satu per satu; sisanya tetap bawaan'),
    'themeRadius': ('卡片圆角', '卡片圓角', 'Card corner radius',
                    'カードの角丸', 'Redondeo de tarjetas', 'Sudut kartu'),
    'themeRadiusDesc': ('作用于卡片与输入框（小徽标等不受影响）',
                        '作用於卡片與輸入框（小徽標等不受影響）',
                        'Applies to cards and inputs (small badges are unaffected)',
                        'カードと入力欄に適用（小さなバッジは対象外）',
                        'Se aplica a tarjetas y campos (las insignias no cambian)',
                        'Berlaku untuk kartu dan kolom isian (lencana kecil tidak)'),
    'themeIcons': ('图标', '圖示', 'Icons', 'アイコン', 'Iconos', 'Ikon'),
    'themeIconsDesc': ('为底部页签与设置入口换图标',
                       '為底部頁籤與設定入口換圖示',
                       'Replace the tab bar and settings entries icons',
                       'タブバーと設定入口のアイコンを変更',
                       'Cambia los iconos de las pestañas y de los ajustes',
                       'Ganti ikon tab bawah dan pintu masuk pengaturan'),
    'themeTexts': ('文字', '文字', 'Text', '文字', 'Texto', 'Teks'),
    'themeTextsDesc': ('覆写常用文案（按钮与错误提示不开放，避免界面变得不可操作）',
                       '覆寫常用文案（按鈕與錯誤提示不開放，避免介面變得不可操作）',
                       'Overwrite common labels (buttons and error messages are '
                       'deliberately excluded so the UI stays operable)',
                       'よく使う文言を上書き（ボタンとエラー表示は対象外。'
                       '操作不能になるのを防ぐため）',
                       'Sobrescribe textos habituales (los botones y los mensajes '
                       'de error se excluyen a propósito)',
                       'Timpa teks umum (tombol dan pesan galat sengaja dikecualikan)'),
    # 操作
    'themeNew': ('新建主题', '新增主題', 'New theme', '新しいテーマ',
                 'Nuevo tema', 'Tema baru'),
    'themeDuplicate': ('复制为我的主题', '複製為我的主題', 'Copy to my themes',
                       '自分のテーマに複製', 'Copiar a mis temas',
                       'Salin ke tema saya'),
    'themeRename': ('重命名', '重新命名', 'Rename', '名前を変更', 'Renombrar',
                    'Ganti nama'),
    'themeDelete': ('删除主题', '刪除主題', 'Delete theme', 'テーマを削除',
                    'Eliminar tema', 'Hapus tema'),
    'themeDeleteConfirm': ('删除主题「{name}」？此操作无法撤销。',
                           '刪除主題「{name}」？此操作無法復原。',
                           'Delete the theme “{name}”? This cannot be undone.',
                           'テーマ「{name}」を削除しますか？元に戻せません。',
                           '¿Eliminar el tema «{name}»? No se puede deshacer.',
                           'Hapus tema “{name}”? Tidak bisa dibatalkan.'),
    'themeReset': ('恢复默认', '恢復預設', 'Reset', '既定に戻す',
                   'Restablecer', 'Setel ulang'),
    'themeResetAll': ('重置本主题', '重設本主題', 'Reset this theme',
                      'このテーマをリセット', 'Restablecer este tema',
                      'Setel ulang tema ini'),
    'themeSaved': ('主题已保存', '主題已儲存', 'Theme saved', 'テーマを保存しました',
                   'Tema guardado', 'Tema disimpan'),
    'themeNameHint': ('主题名称', '主題名稱', 'Theme name', 'テーマ名',
                      'Nombre del tema', 'Nama tema'),
    # 颜色 / 图标 / 文字 的具体操作
    'themePickColor': ('选择颜色', '選擇顏色', 'Pick a colour', '色を選ぶ',
                       'Elegir color', 'Pilih warna'),
    'themePickIcon': ('选择图标', '選擇圖示', 'Pick an icon', 'アイコンを選ぶ',
                      'Elegir icono', 'Pilih ikon'),
    'themePickIconSearch': ('搜索图标名（英文）', '搜尋圖示名稱（英文）',
                            'Search icon names', 'アイコン名で検索',
                            'Buscar nombres de iconos', 'Cari nama ikon'),
    'themeEditText': ('修改文字', '修改文字', 'Edit text', '文字を編集',
                      'Editar texto', 'Ubah teks'),
    'themeTextHint': ('留空即恢复默认', '留空即恢復預設',
                      'Leave empty to reset', '空欄で既定に戻す',
                      'Vacío para restablecer', 'Kosongkan untuk menyetel ulang'),
    'themeIconImport': ('从图片导入', '從圖片匯入', 'Import an image',
                        '画像から読み込む', 'Importar imagen', 'Impor gambar'),
    'themeIconImportHint': ('PNG/JPG/WebP/GIF/BMP/SVG，≤2MB',
                            'PNG/JPG/WebP/GIF/BMP/SVG，≤2MB',
                            'PNG/JPG/WebP/GIF/BMP/SVG, up to 2 MB',
                            'PNG/JPG/WebP/GIF/BMP/SVG、2MB まで',
                            'PNG/JPG/WebP/GIF/BMP/SVG, hasta 2 MB',
                            'PNG/JPG/WebP/GIF/BMP/SVG, maks 2 MB'),
    'themeIconImportDone': ('已导入图标：{name}', '已匯入圖示：{name}',
                            'Icon imported: {name}', 'アイコンを読み込みました：{name}',
                            'Icono importado: {name}', 'Ikon diimpor: {name}'),
    'themeIconWebHint': ('Web 版不支持导入图片，请使用内置图标库',
                         'Web 版不支援匯入圖片，請使用內建圖示庫',
                         'Importing images is not available on the web — use the '
                         'built-in icon library',
                         'Web 版では画像を読み込めません。内蔵アイコンを使ってください',
                         'En la web no se pueden importar imágenes: usa la '
                         'biblioteca integrada',
                         'Di web tidak bisa mengimpor gambar — gunakan pustaka '
                         'ikon bawaan'),
    'themeIconErrFormat': ('不支持的图片格式（支持 PNG/JPG/WebP/GIF/BMP/SVG）',
                           '不支援的圖片格式（支援 PNG/JPG/WebP/GIF/BMP/SVG）',
                           'Unsupported image format (PNG/JPG/WebP/GIF/BMP/SVG)',
                           '未対応の画像形式です（PNG/JPG/WebP/GIF/BMP/SVG）',
                           'Formato de imagen no admitido '
                           '(PNG/JPG/WebP/GIF/BMP/SVG)',
                           'Format gambar tidak didukung '
                           '(PNG/JPG/WebP/GIF/BMP/SVG)'),
    'themeIconErrTooLarge': ('图片超过 2MB，请先压缩',
                             '圖片超過 2MB，請先壓縮',
                             'The image is larger than 2 MB — please compress it',
                             '画像が 2MB を超えています。圧縮してください',
                             'La imagen supera los 2 MB: comprímela',
                             'Gambar melebihi 2 MB — kompres dulu'),
    'themeIconErrFailed': ('导入图标失败', '匯入圖示失敗', 'Could not import the icon',
                           'アイコンの読み込みに失敗しました',
                           'No se pudo importar el icono',
                           'Gagal mengimpor ikon'),
    'themeIconErrUnsupported': ('当前平台不支持导入图片',
                                '目前平台不支援匯入圖片',
                                'Importing images is not supported on this platform',
                                'この環境では画像の読み込みに対応していません',
                                'Esta plataforma no admite importar imágenes',
                                'Platform ini tidak mendukung impor gambar'),
    # 导入 / 导出
    'themeIo': ('导入与导出', '匯入與匯出', 'Import & export', '読み込みと書き出し',
                'Importar y exportar', 'Impor & ekspor'),
    'themeIoDesc': ('主题是 JSON 文本，可以分享给别人，也可以手工编辑',
                    '主題是 JSON 文字，可以分享給別人，也可以手動編輯',
                    'A theme is JSON text — shareable and hand-editable',
                    'テーマは JSON テキスト。共有も手編集もできます',
                    'Un tema es texto JSON: se puede compartir y editar a mano',
                    'Tema berupa teks JSON — bisa dibagikan dan diedit manual'),
    'themeExport': ('导出此主题', '匯出此主題', 'Export this theme',
                    'このテーマを書き出す', 'Exportar este tema',
                    'Ekspor tema ini'),
    'themeExportAll': ('导出全部主题', '匯出全部主題', 'Export all themes',
                       'すべてのテーマを書き出す', 'Exportar todos los temas',
                       'Ekspor semua tema'),
    'themeImport': ('导入主题', '匯入主題', 'Import themes', 'テーマを読み込む',
                    'Importar temas', 'Impor tema'),
    'themeImportPaste': ('从剪贴板导入', '從剪貼簿匯入', 'Import from clipboard',
                         'クリップボードから読み込む', 'Importar del portapapeles',
                         'Impor dari papan klip'),
    'themeImportDone': ('已导入 {n} 个主题', '已匯入 {n} 個主題',
                        'Imported {n} themes', '{n} 件のテーマを読み込みました',
                        'Se importaron {n} temas', 'Mengimpor {n} tema'),
    'themeErrNotJson': ('文件不是有效的 JSON', '檔案不是有效的 JSON',
                        'The file is not valid JSON',
                        'ファイルが有効な JSON ではありません',
                        'El archivo no es JSON válido',
                        'Berkas bukan JSON yang valid'),
    'themeErrNotTheme': ('这不是 APRSlocus 主题文件',
                         '這不是 APRSlocus 主題檔',
                         'This is not an APRSlocus theme file',
                         'APRSlocus のテーマファイルではありません',
                         'No es un archivo de tema de APRSlocus',
                         'Ini bukan berkas tema APRSlocus'),
    'themeErrSchemaNewer': ('主题来自更新版本的 APRSlocus，请先升级应用',
                            '主題來自較新版本的 APRSlocus，請先更新應用程式',
                            'The theme comes from a newer APRSlocus — update the '
                            'app first',
                            '新しいバージョンの APRSlocus のテーマです。'
                            'アプリを更新してください',
                            'El tema proviene de una versión más nueva de '
                            'APRSlocus: actualiza la app',
                            'Tema berasal dari APRSlocus versi lebih baru — '
                            'perbarui aplikasi dulu'),
    'themeErrEmpty': ('文件里没有可用的主题', '檔案裡沒有可用的主題',
                      'The file contains no usable theme',
                      '読み込めるテーマがありません',
                      'El archivo no contiene ningún tema utilizable',
                      'Berkas tidak berisi tema yang bisa dipakai'),
    'themeFixedPrimary': ('当前主题已固定主色，请到「主题」页修改',
                          '目前主題已固定主色，請到「主題」頁修改',
                          'The active theme pins the primary colour — change it on '
                          'the Theme page',
                          '現在のテーマがメインカラーを固定しています。'
                          '「テーマ」ページで変更してください',
                          'El tema activo fija el color principal: cámbialo en la '
                          'página Tema',
                          'Tema aktif mengunci warna utama — ubah di halaman Tema'),
    # 配色令牌
    'themeTokenPrimary': ('主色', '主色', 'Primary', 'メインカラー',
                          'Principal', 'Utama'),
    'themeTokenSurface': ('卡片表面', '卡片表面', 'Card surface', 'カード表面',
                          'Superficie de tarjeta', 'Permukaan kartu'),
    'themeTokenBackground': ('页面背景', '頁面背景', 'Page background',
                             'ページ背景', 'Fondo de página', 'Latar halaman'),
    'themeTokenBackgroundSoft': ('次层背景', '次層背景', 'Secondary background',
                                 '副次的な背景', 'Fondo secundario',
                                 'Latar sekunder'),
    'themeTokenTextPrimary': ('主文字', '主文字', 'Primary text', '本文',
                              'Texto principal', 'Teks utama'),
    'themeTokenTextSecondary': ('次要文字', '次要文字', 'Secondary text',
                                '副次的な文字', 'Texto secundario',
                                'Teks sekunder'),
    'themeTokenTextMuted': ('弱化文字', '弱化文字', 'Muted text', '補助文字',
                            'Texto atenuado', 'Teks redup'),
    'themeTokenDivider': ('分隔线', '分隔線', 'Divider', '区切り線',
                          'Separador', 'Pemisah'),
    'themeTokenSuccess': ('成功/在线', '成功/上線', 'Success / online',
                          '成功・オンライン', 'Éxito / en línea',
                          'Berhasil / daring'),
    'themeTokenWarning': ('警告', '警告', 'Warning', '警告', 'Aviso', 'Peringatan'),
    'themeTokenDanger': ('危险/离线', '危險/離線', 'Danger / offline',
                         '危険・オフライン', 'Peligro / sin conexión',
                         'Bahaya / luring'),
    'themeTokenInfo': ('信息/强调', '資訊/強調', 'Info / accent', '情報・強調',
                       'Información / acento', 'Info / aksen'),
}

# 带占位符的键
PLACEHOLDERS = {
    'themeDeleteConfirm': [('name', 'String')],
    'themeIconImportDone': [('name', 'String')],
    'themeImportDone': [('n', 'int')],
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
            if key in PLACEHOLDERS:
                ph = ', '.join(
                    f'"{n}": {{"type": "{t}"}}' for n, t in PLACEHOLDERS[key])
                add.append(f'  "@{key}": {{')
                add.append(f'    "placeholders": {{{ph}}}')
                add.append('  },')
        if not add:
            continue
        # 末尾不能有逗号：先给末键补逗号，追加后再去掉新键后的逗号
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
