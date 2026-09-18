#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为「主题导出带图片」补 l10n 键（6 语言）。"""
import io, json, os, re, sys

# key → (zh, zh_TW, en, ja, es, id)
KEYS = {
    'themeExportWithImages': ('导出时包含图片', '匯出時包含圖片',
                              'Include images in the export',
                              '書き出しに画像を含める',
                              'Incluir imágenes al exportar',
                              'Sertakan gambar saat ekspor'),
    'themeExportWithImagesHint': ('导出文件会包含图片本体（约 {size}），'
                                  '对方导入后能直接看到同样的背景与图标；'
                                  '文件因此不再适合手工编辑。',
                                  '匯出檔會包含圖片本體（約 {size}），'
                                  '對方匯入後能直接看到同樣的背景與圖示；'
                                  '檔案因此不再適合手動編輯。',
                                  'The export will carry the images themselves '
                                  '(about {size}), so the recipient sees the same '
                                  'background and icons. The file is then no longer '
                                  'hand-editable.',
                                  '書き出しファイルに画像本体（約 {size}）が含まれ、'
                                  '受け取った側でも同じ背景とアイコンが表示されます。'
                                  'その代わり手編集には向かなくなります。',
                                  'La exportación incluirá las imágenes (unos {size}), '
                                  'así que quien la reciba verá el mismo fondo e '
                                  'iconos. El archivo deja de ser editable a mano.',
                                  'Ekspor akan menyertakan gambar (sekitar {size}), '
                                  'jadi penerima melihat latar dan ikon yang sama. '
                                  'Berkasnya jadi tidak lagi bisa diedit manual.'),
    'themeExportNoImages': ('当前主题没有引用图片，导出文件只含配色与文字',
                            '目前主題沒有引用圖片，匯出檔只含配色與文字',
                            'This theme references no images; the export contains '
                            'only colours and text',
                            'このテーマは画像を参照していません。書き出しには色と'
                            '文字だけが含まれます',
                            'Este tema no usa imágenes: la exportación solo lleva '
                            'colores y texto',
                            'Tema ini tidak memakai gambar; ekspornya hanya berisi '
                            'warna dan teks'),
    'themeExportClipboardTooBig': ('图片较大，无法通过剪贴板传递，请用「导出全部主题」保存为文件',
                                   '圖片較大，無法透過剪貼簿傳遞，請用「匯出全部主題」存成檔案',
                                   'The images are too large for the clipboard — use '
                                   '"Export all themes" to save a file instead',
                                   '画像が大きいためクリップボードでは渡せません。'
                                   '「すべてのテーマを書き出す」でファイルに保存してください',
                                   'Las imágenes son demasiado grandes para el '
                                   'portapapeles: usa «Exportar todos los temas» '
                                   'para guardarlas en un archivo',
                                   'Gambarnya terlalu besar untuk papan klip — '
                                   'gunakan “Ekspor semua tema” untuk menyimpan berkas'),
    'themeImportImagesSkipped': ('有 {n} 张图片未导入（过大或格式不支持）',
                                 '有 {n} 張圖片未匯入（過大或格式不支援）',
                                 '{n} image(s) were not imported (too large or '
                                 'unsupported)',
                                 '{n} 件の画像を読み込めませんでした（大きすぎるか'
                                 '未対応形式）',
                                 'No se importaron {n} imagen(es) (demasiado grandes '
                                 'o no admitidas)',
                                 '{n} gambar tidak diimpor (terlalu besar atau '
                                 'tidak didukung)'),
    'backupThemeImagesHint': ('备份会包含主题引用的图片本体；不包含时，'
                              '换机恢复后主题会回退成内置图标',
                              '備份會包含主題引用的圖片本體；不包含時，'
                              '換機還原後主題會回退成內建圖示',
                              'The backup will embed the images your themes use. '
                              'Without them, a restored theme falls back to '
                              'built-in icons.',
                              'バックアップにテーマが参照する画像本体を含めます。'
                              '含めない場合、復元後にテーマは内蔵アイコンに戻ります。',
                              'La copia incluirá las imágenes que usan tus temas. '
                              'Sin ellas, al restaurar el tema vuelve a los iconos '
                              'integrados.',
                              'Cadangan akan menyertakan gambar yang dipakai tema. '
                              'Tanpanya, tema yang dipulihkan kembali ke ikon bawaan.'),
    'backupThemeImagesOff': ('不含图片：备份更小，但换机恢复后主题会缺少背景与自定义图标',
                             '不含圖片：備份更小，但換機還原後主題會缺少背景與自訂圖示',
                             'Images excluded: a smaller backup, but a restored '
                             'theme will be missing its background and custom icons',
                             '画像を含めません。バックアップは小さくなりますが、'
                             '復元したテーマでは背景とカスタムアイコンが欠けます',
                             'Sin imágenes: copia más pequeña, pero al restaurar el '
                             'tema le faltarán el fondo y los iconos personalizados',
                             'Tanpa gambar: cadangan lebih kecil, tetapi tema yang '
                             'dipulihkan kehilangan latar dan ikon kustom'),
}

PLACEHOLDERS = {'themeExportWithImagesHint': [('size', 'String')],
                'themeImportImagesSkipped': [('n', 'int')]}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    total = 0
    for lg in LANGS:
        p = os.path.join(root, 'lib', 'l10n', f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8').read()
        add = []
        for key, vals in KEYS.items():
            if re.search(r'^\s*"' + re.escape(key) + r'":', src, re.M):
                print(f'  {lg}/{key}: 已存在，跳过'); continue
            add.append(f'  {json.dumps(key, ensure_ascii=False)}: '
                       f'{json.dumps(vals[IDX[lg]], ensure_ascii=False)},')
            if key in PLACEHOLDERS:
                ph = ', '.join(f'"{n}": {{"type": "{t}"}}' for n, t in PLACEHOLDERS[key])
                add.append(f'  "@{key}": {{')
                add.append(f'    "placeholders": {{{ph}}}')
                add.append('  },')
        if not add: continue
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
