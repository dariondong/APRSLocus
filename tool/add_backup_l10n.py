#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为「备份与恢复」补 l10n 键（6 语言）。

写法沿用仓库里 tool/add_*_l10n.py 的既有做法：按锚点插入 ARB 的
`"key": "值"` 行，随后 `flutter gen-l10n` 重新生成。

为什么脚本化而不是手改：这一批有 50 多个键 × 6 语言，手改要动 300 多处，
漏一处就是「某个语言下这块显示空字符串/回退中文」——而且不会报错。
"""
import io
import json
import os
import re
import sys

# key → (zh, zh_TW, en, ja, es, id)
KEYS = {
    # 入口与总说明
    'backupTitle': ('备份与恢复', '備份與還原', 'Backup & restore',
                    'バックアップと復元', 'Copia de seguridad',
                    'Cadangkan & pulihkan'),
    'backupSubtitle': ('导出或导入配置与数据', '匯出或匯入設定與資料',
                       'Export or import settings and data',
                       '設定とデータの書き出し・読み込み',
                       'Exporta o importa ajustes y datos',
                       'Ekspor atau impor pengaturan dan data'),
    'backupEntryDesc': ('打包配置与数据为 JSON 文件', '打包設定與資料為 JSON 檔',
                        'Pack settings and data into a JSON file',
                        '設定とデータを JSON にまとめる',
                        'Empaqueta ajustes y datos en JSON',
                        'Kemas pengaturan dan data ke JSON'),
    'backupDesc': ('备份文件是 JSON 文本，换机或重装后可恢复；'
                   '导入按分组覆盖，无法撤销。',
                   '備份檔是 JSON 文字，換機或重裝後可還原；'
                   '匯入會依分組覆蓋，無法復原。',
                   'The backup is a JSON file you can restore after switching '
                   'or reinstalling. Import overwrites per group and cannot be undone.',
                   'バックアップは JSON ファイルで、機種変更や再インストール後に'
                   '復元できます。読み込みはグループ単位で上書きされ、元に戻せません。',
                   'La copia es un archivo JSON que puedes restaurar al cambiar de '
                   'dispositivo o reinstalar. La importación sobrescribe por grupo '
                   'y no se puede deshacer.',
                   'Cadangan berupa berkas JSON yang bisa dipulihkan setelah ganti '
                   'perangkat atau pasang ulang. Impor menimpa per grup dan tidak '
                   'bisa dibatalkan.'),
    # 导出
    'backupExport': ('导出备份', '匯出備份', 'Export backup',
                     'バックアップを書き出す', 'Exportar copia', 'Ekspor cadangan'),
    'backupExportDesc': ('选择要包含的内容，然后保存为文件或复制到剪贴板',
                         '選擇要包含的內容，再存成檔案或複製到剪貼簿',
                         'Pick what to include, then save to a file or copy as text',
                         '含める内容を選び、ファイル保存またはクリップボードへコピー',
                         'Elige qué incluir y guárdalo en un archivo o cópialo',
                         'Pilih isi, lalu simpan ke berkas atau salin'),
    'backupExportToFile': ('保存为文件', '存成檔案', 'Save to file',
                           'ファイルに保存', 'Guardar en archivo',
                           'Simpan ke berkas'),
    'backupCopyJson': ('复制到剪贴板', '複製到剪貼簿', 'Copy to clipboard',
                       'クリップボードにコピー', 'Copiar al portapapeles',
                       'Salin ke papan klip'),
    'backupExportDone': ('备份已导出', '備份已匯出', 'Backup exported',
                         'バックアップを書き出しました', 'Copia exportada',
                         'Cadangan diekspor'),
    'backupExportFailed': ('导出失败，请检查存储权限或剩余空间',
                           '匯出失敗，請檢查儲存權限或剩餘空間',
                           'Export failed — check storage permission or free space',
                           '書き出しに失敗しました。ストレージの権限や空き容量を'
                           '確認してください',
                           'No se pudo exportar: revisa el permiso de '
                           'almacenamiento o el espacio libre',
                           'Ekspor gagal — periksa izin penyimpanan atau ruang '
                           'yang tersisa'),
    'backupCopyDone': ('备份内容已复制到剪贴板', '備份內容已複製到剪貼簿',
                       'Backup copied to clipboard',
                       'バックアップをクリップボードにコピーしました',
                       'Copia copiada al portapapeles', 'Cadangan disalin'),
    'backupSavedTo': ('已保存到：{path}', '已儲存到：{path}', 'Saved to: {path}',
                      '保存先：{path}', 'Guardado en: {path}',
                      'Disimpan ke: {path}'),
    # 分组
    'backupCatSettings': ('设置配置', '設定', 'Settings', '設定', 'Ajustes',
                          'Pengaturan'),
    'backupCatSettingsDesc': ('电台、信标、地图、筛选、数据来源、服务器',
                              '電台、信標、地圖、篩選、資料來源、伺服器',
                              'Station, beacon, map, filters, sources, server',
                              '局、ビーコン、地図、フィルター、接続先、サーバー',
                              'Estación, baliza, mapa, filtros, fuentes, servidor',
                              'Stasiun, beacon, peta, filter, sumber, server'),
    'backupCatStations': ('台站与联系人', '臺站與聯絡人', 'Stations & contacts',
                          '局とコンタクト', 'Estaciones y contactos',
                          'Stasiun & kontak'),
    'backupCatStationsDesc': ('收藏、手动添加的联系人及其备注',
                              '我的最愛、手動新增的聯絡人與備註',
                              'Favourites, manual contacts and their notes',
                              'お気に入り・手動追加した局とメモ',
                              'Favoritos, contactos manuales y sus notas',
                              'Favorit, kontak manual, dan catatannya'),
    'backupCatMessages': ('消息记录', '訊息記錄', 'Messages',
                          'メッセージ履歴', 'Mensajes', 'Pesan'),
    'backupCatMessagesDesc': ('单聊消息与已读位置', '單聊訊息與已讀位置',
                              'Direct messages and read positions',
                              '個別メッセージと既読位置',
                              'Mensajes directos y posiciones leídas',
                              'Pesan langsung dan posisi baca'),
    'backupCatChats': ('群聊', '群組聊天', 'Group chats', 'グループチャット',
                       'Chats grupales', 'Obrolan grup'),
    'backupCatChatsDesc': ('群组、成员与已读状态', '群組、成員與已讀狀態',
                           'Groups, members and read state',
                           'グループ、メンバー、既読状態',
                           'Grupos, miembros y estado leído',
                           'Grup, anggota, dan status baca'),
    'backupCatTranslate': ('翻译设置', '翻譯設定', 'Translation settings',
                           '翻訳設定', 'Ajustes de traducción',
                           'Pengaturan terjemahan'),
    'backupCatTranslateDesc': ('翻译接口、密钥与语言偏好',
                               '翻譯介面、金鑰與語言偏好',
                               'Providers, keys and language preferences',
                               '翻訳サービス、API キー、言語設定',
                               'Proveedores, claves y preferencias de idioma',
                               'Penyedia, kunci, dan preferensi bahasa'),
    'backupCatHonors': ('成就与荣誉', '成就與榮譽', 'Achievements & honours',
                        '実績と栄誉', 'Logros y honores', 'Pencapaian & kehormatan'),
    'backupCatHonorsDesc': ('解锁记录、计数与默认徽章',
                            '解鎖記錄、計數與預設徽章',
                            'Unlocks, counters and default badge',
                            '解除記録、カウント、既定バッジ',
                            'Desbloqueos, contadores y insignia predeterminada',
                            'Bukaan, penghitung, dan lencana bawaan'),
    'backupItems': ('{n} 项', '{n} 項', '{n} items', '{n} 件', '{n} elementos',
                    '{n} item'),
    'backupSelectAll': ('全选', '全選', 'Select all', 'すべて選択',
                        'Seleccionar todo', 'Pilih semua'),
    'backupNoSelection': ('请至少选择一个分组', '請至少選擇一個分組',
                          'Select at least one group',
                          'グループを 1 つ以上選んでください',
                          'Selecciona al menos un grupo',
                          'Pilih minimal satu grup'),
    # 导入
    'backupImport': ('导入备份', '匯入備份', 'Import backup',
                     'バックアップを読み込む', 'Importar copia',
                     'Impor cadangan'),
    'backupImportDesc': ('选择之前导出的 JSON 备份文件',
                         '選擇先前匯出的 JSON 備份檔',
                         'Choose a backup JSON file exported earlier',
                         '以前書き出した JSON バックアップを選択',
                         'Elige un archivo JSON exportado antes',
                         'Pilih berkas JSON cadangan yang pernah diekspor'),
    'backupPickFile': ('选择备份文件', '選擇備份檔', 'Choose backup file',
                       'バックアップを選択', 'Elegir archivo',
                       'Pilih berkas cadangan'),
    'backupPaste': ('从剪贴板粘贴', '從剪貼簿貼上', 'Paste from clipboard',
                    'クリップボードから貼り付け', 'Pegar del portapapeles',
                    'Tempel dari papan klip'),
    'backupPasteEmpty': ('剪贴板里没有文本', '剪貼簿裡沒有文字',
                         'No text in the clipboard',
                         'クリップボードにテキストがありません',
                         'No hay texto en el portapapeles',
                         'Tidak ada teks di papan klip'),
    'backupPreview': ('备份内容', '備份內容', 'Backup contents',
                      'バックアップの内容', 'Contenido de la copia',
                      'Isi cadangan'),
    'backupFromVersion': ('来源版本 {v}', '來源版本 {v}', 'From version {v}',
                          '書き出し元 {v}', 'Versión de origen {v}',
                          'Dari versi {v}'),
    'backupExportedAt': ('导出时间 {t}', '匯出時間 {t}', 'Exported {t}',
                         '書き出し日時 {t}', 'Exportado {t}',
                         'Diekspor {t}'),
    'backupImportSelected': ('导入所选', '匯入所選', 'Import selected',
                             '選択した項目を読み込む', 'Importar selección',
                             'Impor yang dipilih'),
    'backupImportConfirmTitle': ('确认导入？', '確認匯入？',
                                 'Import this backup?',
                                 '読み込みますか？', '¿Importar la copia?',
                                 'Impor cadangan ini?'),
    'backupImportConfirm': ('所选分组会被备份里的内容覆盖，且无法撤销。'
                            '建议先导出一次当前数据。',
                            '所選分組會被備份內容覆蓋，且無法復原。'
                            '建議先匯出一次目前的資料。',
                            'The selected groups will be overwritten and this '
                            'cannot be undone. Consider exporting a backup of '
                            'the current data first.',
                            '選択したグループは上書きされ、元に戻せません。'
                            '先に現在のデータを書き出すことをおすすめします。',
                            'Los grupos seleccionados se sobrescribirán y no se '
                            'puede deshacer. Se recomienda exportar antes una copia '
                            'de los datos actuales.',
                            'Grup terpilih akan ditimpa dan tidak bisa '
                            'dibatalkan. Sebaiknya ekspor dulu data saat ini.'),
    'backupImported': ('已导入 {n} 项', '已匯入 {n} 項', 'Imported {n} items',
                       '{n} 件を読み込みました', 'Se importaron {n} elementos',
                       'Mengimpor {n} item'),
    'backupSkipped': ('跳过 {n} 项（本版本不认识的内容）',
                      '略過 {n} 項（本版本不認識的內容）',
                      'Skipped {n} unknown entries',
                      '不明な {n} 件をスキップしました',
                      'Se omitieron {n} entradas desconocidas',
                      'Melewati {n} entri tak dikenal'),
    'backupImportNothing': ('备份里不包含所选分组的数据',
                            '備份裡不包含所選分組的資料',
                            'The backup has no data for the selected groups',
                            '選択したグループのデータがバックアップにありません',
                            'La copia no tiene datos de los grupos seleccionados',
                            'Cadangan tidak punya data untuk grup terpilih'),
    'backupRestartTitle': ('导入完成', '匯入完成', 'Import complete',
                           '読み込み完了', 'Importación completada',
                           'Impor selesai'),
    'backupRestartHint': ('数据已写入，重启应用后完全生效'
                          '（成就、翻译、服务器连接等）。',
                          '資料已寫入，重新啟動後才會完全生效'
                          '（成就、翻譯、伺服器連線等）。',
                          'Data is saved; restart the app for everything to take '
                          'effect (achievements, translation, server connection).',
                          'データは保存されました。完全に反映するにはアプリを'
                          '再起動してください（実績・翻訳・サーバー接続など）。',
                          'Los datos están guardados; reinicia la app para que '
                          'todo surta efecto (logros, traducción, conexión).',
                          'Data tersimpan; mulai ulang aplikasi agar semuanya '
                          'berlaku (pencapaian, terjemahan, koneksi server).'),
    'backupRestartNow': ('退出应用', '結束應用程式', 'Quit app',
                         'アプリを終了', 'Salir de la app', 'Keluar aplikasi'),
    'backupLater': ('稍后', '稍後', 'Later', 'あとで', 'Más tarde', 'Nanti'),
    'backupSecurityTip': ('备份文件包含呼号、服务器口令与 API 密钥，请妥善保管。',
                          '備份檔包含呼號、伺服器密碼與 API 金鑰，請妥善保管。',
                          'The backup contains your callsign, server passcode and '
                          'API keys — keep it safe.',
                          'バックアップにはコールサイン、サーバーのパスコード、'
                          'API キーが含まれます。大切に保管してください。',
                          'La copia incluye tu indicativo, la contraseña del '
                          'servidor y claves API: guárdala bien.',
                          'Cadangan berisi callsign, passcode server, dan kunci '
                          'API — simpan dengan aman.'),
    'backupWebHint': ('Web 版请用「复制到剪贴板 / 从剪贴板粘贴」导入导出。',
                      'Web 版請用「複製到剪貼簿 / 從剪貼簿貼上」匯入匯出。',
                      'On the web, use “copy to clipboard / paste from clipboard”.',
                      'Web 版では「クリップボードにコピー / 貼り付け」を使ってください。',
                      'En la web usa «copiar / pegar del portapapeles».',
                      'Di web, gunakan “salin / tempel dari papan klip”.'),
    # 错误
    'backupErrNotJson': ('文件不是有效的 JSON', '檔案不是有效的 JSON',
                         'The file is not valid JSON',
                         'ファイルが有効な JSON ではありません',
                         'El archivo no es JSON válido',
                         'Berkas bukan JSON yang valid'),
    'backupErrNotBackup': ('这不是 APRSlocus 的备份文件',
                           '這不是 APRSlocus 的備份檔',
                           'This is not an APRSlocus backup file',
                           'APRSlocus のバックアップではありません',
                           'No es una copia de APRSlocus',
                           'Ini bukan berkas cadangan APRSlocus'),
    'backupErrSchemaNewer': ('备份来自更新版本的 APRSlocus，请先升级应用',
                             '備份來自較新版本的 APRSlocus，請先更新應用程式',
                             'The backup comes from a newer APRSlocus — update the '
                             'app first',
                             '新しいバージョンの APRSlocus のバックアップです。'
                             'アプリを更新してください',
                             'La copia proviene de una versión más nueva de '
                             'APRSlocus: actualiza la app primero',
                             'Cadangan berasal dari APRSlocus versi lebih baru — '
                             'perbarui aplikasi dulu'),
    'backupErrEmpty': ('备份里没有可导入的内容', '備份裡沒有可匯入的內容',
                       'The backup contains nothing to import',
                       '読み込める内容がありません',
                       'La copia no contiene nada que importar',
                       'Cadangan tidak berisi apa pun untuk diimpor'),
    'backupErrTooLarge': ('备份文件超过 32 MB，无法读取',
                          '備份檔超過 32 MB，無法讀取',
                          'The backup is larger than 32 MB and cannot be read',
                          'バックアップが 32 MB を超えているため読み込めません',
                          'La copia supera los 32 MB y no se puede leer',
                          'Cadangan melebihi 32 MB dan tidak bisa dibaca'),
    'backupErrRead': ('读取备份文件失败', '讀取備份檔失敗',
                      'Could not read the backup file',
                      'バックアップを読み込めませんでした',
                      'No se pudo leer la copia',
                      'Gagal membaca berkas cadangan'),
    'backupErrUnsupported': ('当前平台暂不支持选择文件，请改用剪贴板粘贴',
                             '目前平台不支援選擇檔案，請改用剪貼簿貼上',
                             'Picking files is not supported here — paste from the '
                             'clipboard instead',
                             'この環境ではファイル選択が使えません。'
                             'クリップボードから貼り付けてください',
                             'Aquí no se pueden elegir archivos: pega desde el '
                             'portapapeles',
                             'Memilih berkas tidak didukung di sini — tempel dari '
                             'papan klip'),
}

# 带占位符的键必须写 @key 元数据，否则 gen-l10n 会把 {n} 当字面量
PLACEHOLDERS = {
    'backupItems': [('n', 'int')],
    'backupSavedTo': [('path', 'String')],
    'backupFromVersion': [('v', 'String')],
    'backupExportedAt': [('t', 'String')],
    'backupImported': [('n', 'int')],
    'backupSkipped': [('n', 'int')],
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
                    f'"{name}": {{"type": "{ty}"}}' for name, ty in PLACEHOLDERS[key])
                add.append(f'  "@{key}": {{')
                add.append(f'    "placeholders": {{{ph}}}')
                add.append('  },')
        if not add:
            continue
        # 插到最后一个顶层键之前。ARB 是 JSON 对象 —— 末尾不能有逗号，
        # 而最后一个原有键自带逗号，必须先把逗号补上再追加、最后去掉新键后的逗号。
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
