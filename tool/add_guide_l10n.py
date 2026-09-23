#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""功能引导的 l10n 键（27 个 × 6 语言）。

背景：用户要求「添加更多的小引导，为软件的功能做功能引导」。形态定为**各页首次
进入时的一张小提示卡**（见 lib/guide.dart），记住已读、设置里可重置。

键的命名约定：`guide<Id>Title` / `guide<Id>Body`，`<Id>` 就是 lib/guide.dart 里
Guide.id 的驼峰写法（如 id 'offlineMap' → guideOfflineMapTitle）。
另有 3 个通用键（弹层标题、知道了、重看）和 4 个「重置引导」的键。

写入约定与 tool/add_notice_l10n.py 一致：幂等、追加到 ARB 末尾，
并同步 gen-l10n 产物（本机没有 flutter，跑不了 gen-l10n；产物提交进 git）。
"""
import io
import json
import os
import re
import sys

# 键 → (zh, zh_TW, en, ja, es, id)
KEYS = {
    # ── 通用 ──
    'guideTitle': ('功能引导', '功能導覽', 'Feature guide', '機能ガイド',
                   'Guía de funciones', 'Panduan fitur'),
    'guideGotIt': ('知道了', '知道了', 'Got it', '了解しました',
                   'Entendido', 'Mengerti'),
    'guideShowAgain': ('重看本页引导', '重看本頁引導', 'Show this guide again',
                       'このページのガイドを再表示', 'Ver esta guía otra vez',
                       'Tampilkan panduan ini lagi'),

    # ── 各页引导 ──
    'guideHomeTitle': ('主页 · 地图与台站', '主頁 · 地圖與臺站',
                       'Home · map & stations', 'ホーム · 地図と局',
                       'Inicio · mapa y estaciones', 'Beranda · peta & stasiun'),
    'guideHomeBody': (
        '地图上的每个点都是收到的台站，点开可以看它的轨迹与详情；底部按钮把你的位置发出去（需先连接）。',
        '地圖上的每個點都是收到的臺站，點開可以看它的軌跡與詳情；底部按鈕把你的位置送出去（需先連線）。',
        'Every dot on the map is a station you are receiving — tap one for its track and details. The bottom button sends your position (connect first).',
        '地図上の点は受信した局です。タップすると軌跡と詳細が見られます。下部のボタンで自分の位置を送信します（先に接続が必要）。',
        'Cada punto del mapa es una estación que estás recibiendo: tócalo para ver su ruta y sus datos. El botón inferior envía tu posición (conecta antes).',
        'Setiap titik di peta adalah stasiun yang Anda terima — ketuk untuk melihat jejak dan detailnya. Tombol bawah mengirim posisi Anda (sambungkan dulu).'),

    'guideImmersiveTitle': ('沉浸地图', '沉浸地圖', 'Immersive map',
                            'イマーシブマップ', 'Mapa inmersivo', 'Peta imersif'),
    'guideImmersiveBody': (
        '全屏看台站：双指缩放、单指拖动，左下角可切换「跟随自己」，左上角返回。',
        '全螢幕看臺站：雙指縮放、單指拖曳，左下角可切換「跟隨自己」，左上角返回。',
        'Full-screen station view: pinch to zoom, drag to pan, “follow me” at the bottom-left, back arrow at the top-left.',
        '全画面の地図です。ピンチで拡大縮小、ドラッグで移動、左下で「自分を追従」を切り替え、左上で戻ります。',
        'Mapa a pantalla completa: pellizca para ampliar, arrastra para mover, «seguirme» abajo a la izquierda, volver arriba a la izquierda.',
        'Peta layar penuh: cubit untuk zoom, seret untuk menggeser, “ikuti saya” di kiri bawah, kembali di kiri atas.'),

    'guideMessagesTitle': ('消息', '訊息', 'Messages', 'メッセージ',
                           'Mensajes', 'Pesan'),
    'guideMessagesBody': (
        '输入呼号即可开聊；右上角能建群组、发广播。收不到回复时，先确认顶部已连接。',
        '輸入呼號即可開聊；右上角能建群組、發廣播。收不到回覆時，先確認頂部已連線。',
        'Type a callsign to start a chat; the top-right menu creates groups and sends bulletins. No replies? Check that you are connected.',
        'コールサインを入力すると会話を開始できます。右上のメニューでグループ作成・一斉送信ができます。返信が来ないときは接続状態を確認してください。',
        'Escribe un indicativo para chatear; el menú superior derecho crea grupos y envía boletines. ¿Sin respuestas? Comprueba que estás conectado.',
        'Ketik callsign untuk mulai mengobrol; menu kanan atas membuat grup dan mengirim siaran. Tidak ada balasan? Periksa koneksi Anda.'),

    'guideDeviceTitle': ('设备与数据源', '裝置與資料來源', 'Devices & data sources',
                         'デバイスとデータソース', 'Dispositivos y fuentes',
                         'Perangkat & sumber data'),
    'guideDeviceBody': (
        '选数据从哪来（APRS-IS / TNC / 声卡）以及用哪条链路发射。蓝牙 TNC 要先去「设备」子页配对。',
        '選資料從哪來（APRS-IS / TNC / 音效卡）以及用哪條鏈路發射。藍牙 TNC 要先去「裝置」子頁配對。',
        'Choose where data comes from (APRS-IS / TNC / sound card) and which link transmits. Pair a Bluetooth TNC in the device sub-page first.',
        'データの取得元（APRS-IS / TNC / サウンドカード）と送信に使う回線を選びます。Bluetooth TNC は先にデバイスの子ページでペアリングしてください。',
        'Elige de dónde vienen los datos (APRS-IS / TNC / tarjeta de sonido) y qué enlace transmite. Empareja el TNC Bluetooth en su subpágina.',
        'Pilih sumber data (APRS-IS / TNC / kartu suara) dan tautan untuk memancar. Pasangkan TNC Bluetooth di sub-halaman perangkat.'),

    'guideSettingsTitle': ('设置', '設定', 'Settings', '設定', 'Ajustes',
                           'Pengaturan'),
    'guideSettingsBody': (
        '八类入口：电台、信标、连接、显示、设备、数据、高级、更新。改完的设置立刻生效，不需要重启。',
        '八類入口：電台、信標、連線、顯示、裝置、資料、進階、更新。改完的設定立刻生效，不需要重啟。',
        'Eight categories: radio, beacon, connection, display, devices, data, advanced, update. Changes take effect immediately.',
        '8 つのカテゴリ：無線機、ビーコン、接続、表示、デバイス、データ、詳細、更新。変更はすぐ反映されます。',
        'Ocho categorías: radio, baliza, conexión, pantalla, dispositivos, datos, avanzado, actualización. Los cambios se aplican al momento.',
        'Delapan kategori: radio, beacon, koneksi, tampilan, perangkat, data, lanjutan, pembaruan. Perubahan langsung berlaku.'),

    'guideOfflineMapTitle': ('离线地图', '離線地圖', 'Offline maps',
                             'オフラインマップ', 'Mapas sin conexión',
                             'Peta offline'),
    'guideOfflineMapBody': (
        '框选一块区域下载瓦片，没网也能看地图。下载可随时暂停，之后接着下。',
        '框選一塊區域下載圖磚，沒網路也能看地圖。下載可隨時暫停，之後接著下。',
        'Select an area and download its tiles so the map keeps working without network. You can pause and resume.',
        '範囲を選んでタイルを保存すると、通信がなくても地図が見られます。中断しても後から再開できます。',
        'Selecciona una zona y descarga sus teselas para ver el mapa sin red. Puedes pausar y reanudar.',
        'Pilih area lalu unduh ubinnya agar peta tetap bisa dilihat tanpa jaringan. Bisa dijeda dan dilanjutkan.'),

    'guideLogTitle': ('系统日志', '系統日誌', 'System log', 'システムログ',
                      'Registro del sistema', 'Log sistem'),
    'guideLogBody': (
        '收发包与链路事件都记在这里。排查问题时先看这儿，右上角可以复制全部日志。',
        '收發包與鏈路事件都記在這裡。排查問題時先看這裡，右上角可以複製全部日誌。',
        'Every packet and link event is recorded here — the first place to look when something is wrong. Copy the whole log from the top-right.',
        '送受信パケットと回線のイベントが記録されます。不具合の切り分けはまずここから。右上で全文をコピーできます。',
        'Aquí se registran los paquetes y los eventos del enlace: es lo primero que hay que mirar si algo falla. Copia todo desde arriba a la derecha.',
        'Semua paket dan peristiwa tautan dicatat di sini — tempat pertama memeriksa saat ada masalah. Salin seluruh log dari kanan atas.'),

    'guideBackupTitle': ('备份与恢复', '備份與還原', 'Backup & restore',
                         'バックアップと復元', 'Copia y restauración',
                         'Cadangan & pemulihan'),
    'guideBackupBody': (
        '导出设置文件，换机后一键恢复。瓦片与翻译缓存不在备份内，需要重新下载。',
        '匯出設定檔，換機後一鍵還原。圖磚與翻譯快取不在備份內，需重新下載。',
        'Export a settings file and restore it in one tap on a new device. Map tiles and the translation cache are not included.',
        '設定ファイルを書き出せば、機種変更後にワンタップで復元できます。タイルと翻訳キャッシュは含まれません。',
        'Exporta un archivo de ajustes y restáuralo con un toque en otro dispositivo. Las teselas y la caché de traducción no se incluyen.',
        'Ekspor berkas pengaturan dan pulihkan sekali ketuk di perangkat baru. Ubin peta dan cache terjemahan tidak disertakan.'),

    'guideExportAdifTitle': ('导出 ADIF', '匯出 ADIF', 'Export ADIF',
                             'ADIF 書き出し', 'Exportar ADIF', 'Ekspor ADIF'),
    'guideExportAdifBody': (
        '把收到的台站位置导成 ADIF 文件，供日志软件导入。可选时间范围与模式。',
        '把收到的臺站位置匯出成 ADIF 檔，供日誌軟體匯入。可選時間範圍與模式。',
        'Write the stations you received into an ADIF file for your logging software, with an optional time range and mode.',
        '受信した局の位置を ADIF ファイルに書き出し、ログソフトへ取り込めます。期間とモードを指定できます。',
        'Guarda las estaciones recibidas en un archivo ADIF para tu programa de log, con rango de fechas y modo opcionales.',
        'Simpan stasiun yang Anda terima ke berkas ADIF untuk perangkat lunak log, dengan rentang waktu dan mode opsional.'),

    'guidePacketsTitle': ('数据包', '資料封包', 'Packets', 'パケット',
                          'Paquetes', 'Paket'),
    'guidePacketsBody': (
        '原始收发报文列表，用来核对解析结果。点一行可以看到完整内容。',
        '原始收發報文列表，用來核對解析結果。點一行可以看到完整內容。',
        'The raw received and sent frames, useful for checking how a packet was parsed. Tap a row for the full text.',
        '生の送受信フレーム一覧です。解析結果の確認に便利です。行をタップすると全文が見られます。',
        'Las tramas originales enviadas y recibidas, útiles para comprobar cómo se interpretó un paquete. Toca una fila para ver el texto completo.',
        'Frame mentah yang diterima dan dikirim, berguna untuk memeriksa hasil parsing. Ketuk baris untuk teks lengkapnya.'),

    # ── 设置里的「重新查看功能引导」 ──
    'guideResetRow': ('重新查看功能引导', '重新查看功能導覽',
                      'Show all feature guides again',
                      'すべての機能ガイドを再表示',
                      'Ver otra vez las guías de funciones',
                      'Tampilkan semua panduan fitur lagi'),
    'guideResetTitle': ('重新查看功能引导？', '重新查看功能導覽？',
                        'Show all feature guides again?',
                        'すべての機能ガイドを再表示しますか？',
                        '¿Ver otra vez las guías de funciones?',
                        'Tampilkan semua panduan fitur lagi?'),
    'guideResetConfirm': (
        '清空「已看过」记录，各页顶部的小提示卡会再出现一次。',
        '清空「已看過」記錄，各頁頂部的小提示卡會再出現一次。',
        'This clears the “already seen” record so the tip card appears once more on each page.',
        '「既読」の記録を消去すると、各ページ上部の小さなヒントがもう一度表示されます。',
        'Se borra el registro de «ya visto» y la tarjeta de ayuda vuelve a aparecer en cada página.',
        'Ini menghapus catatan “sudah dilihat” sehingga kartu petunjuk muncul lagi di tiap halaman.'),
    'guideResetButton': ('重新显示', '重新顯示', 'Show again', '再表示',
                         'Mostrar otra vez', 'Tampilkan lagi'),
    'guideResetDone': ('功能引导已重置', '功能導覽已重設',
                       'Feature guides reset', '機能ガイドをリセットしました',
                       'Guías de funciones restablecidas',
                       'Panduan fitur direset'),
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}

TARGETS = [
    ('zh', 'app_localizations_zh.dart', 'AppLocalizationsZh'),
    ('zh_TW', 'app_localizations_zh.dart', 'AppLocalizationsZhTw'),
    ('en', 'app_localizations_en.dart', 'AppLocalizationsEn'),
    ('ja', 'app_localizations_ja.dart', 'AppLocalizationsJa'),
    ('es', 'app_localizations_es.dart', 'AppLocalizationsEs'),
    ('id', 'app_localizations_id.dart', 'AppLocalizationsId'),
]

# 产物里插在哪个键之后（该键每个语言类都有，位置稳定）
ANCHOR_GETTER = 'tierMinTurnHint'


def dart_literal(s, holders=()):
    out = s
    for h in holders:
        out = out.replace('{' + h + '}', '${' + h + '}')
    return "'" + out.replace("'", r"\'") + "'"


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    l10n = os.path.join(root, 'lib', 'l10n')

    # ① arb
    total = 0
    for lg in LANGS:
        p = os.path.join(l10n, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8').read()
        add = []
        for key, vals in KEYS.items():
            if re.search(r'^\s*"' + re.escape(key) + r'":', src, re.M):
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
        print(f'  arb {lg}: 追加 {len(add)} 行')

    # ② 抽象类
    p = os.path.join(l10n, 'app_localizations.dart')
    src = io.open(p, encoding='utf-8').read()
    missing = [k for k in KEYS if not re.search(
        r'String (?:get )?' + re.escape(k) + r'\s*[;(<={]', src)]
    if missing:
        blocks = []
        for k in missing:
            blocks.append(
                f'  /// No description provided for @{k}.\n'
                f'  ///\n'
                f'  /// In zh, this message translates to:\n'
                f'  /// **{json.dumps(KEYS[k][0], ensure_ascii=False)}**\n'
                f'  String get {k};')
        anchor = '  /// No description provided for @tierIdleTitle.'
        assert anchor in src, '抽象类锚点缺失'
        src = src.replace(anchor, '\n\n'.join(blocks) + '\n\n' + anchor, 1)
        io.open(p, 'w', encoding='utf-8').write(src)
        print(f'  抽象类: 追加 {len(missing)} 条声明')

    # ③ 各语言类
    for lg, fname, cls in TARGETS:
        p = os.path.join(l10n, fname)
        src = io.open(p, encoding='utf-8').read()
        i = src.find(f'class {cls}')
        assert i > 0, f'{fname}: 找不到 {cls}'
        body = src[i:src.find('\n}', i)]
        need = [k for k in KEYS if not re.search(
            r'String (?:get )?' + re.escape(k) + r'\s*[;(<={]', body)]
        if not need:
            continue
        m = re.compile(
            r"(?m)^  String get " + ANCHOR_GETTER + r" => '[^']*';\n").search(src, i)
        assert m, f'{cls}: 找不到 {ANCHOR_GETTER} 锚点'
        blocks = []
        for k in need:
            lit = dart_literal(KEYS[k][IDX[lg]])
            blocks.append(f'  @override\n  String get {k} => {lit};')
        src = src[:m.end()] + '\n' + '\n\n'.join(blocks) + '\n' + src[m.end():]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'  产物 {fname}/{cls}: 追加 {len(need)} 条')

    print(f'\narb 共写入 {total} 行')
    return 0


if __name__ == '__main__':
    sys.exit(main())
