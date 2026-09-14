#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""注入「设备页重构 + TNC 初始化串 + 发射自检」相关文案（6 语言）。"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATA = {
    # ── 概览页 ──
    'deviceOverviewTitle': {
        'zh': '设备', 'zh_TW': '裝置', 'en': 'Devices',
        'ja': 'デバイス', 'id': 'Perangkat', 'es': 'Dispositivos',
    },
    'deviceOverviewSubtitle': {
        'zh': '数据来源、链路状态与自检', 'zh_TW': '資料來源、鏈路狀態與自檢',
        'en': 'Data source, link status and self-test',
        'ja': 'データソース・リンク状態・自己診断',
        'id': 'Sumber data, status tautan, dan uji mandiri',
        'es': 'Fuente de datos, estado del enlace y autodiagnóstico',
    },
    'deviceCurrentLink': {
        'zh': '当前链路', 'zh_TW': '目前鏈路', 'en': 'Current link',
        'ja': '現在のリンク', 'id': 'Tautan saat ini', 'es': 'Enlace actual',
    },
    'deviceCurrentLinkDesc': {
        'zh': '只读摘要 · 改参数请进对应子页',
        'zh_TW': '唯讀摘要 · 改參數請進對應子頁',
        'en': 'Read-only summary — edit parameters in the sub-pages',
        'ja': '読み取り専用の要約。パラメータ変更は各サブページで',
        'id': 'Ringkasan hanya-baca — ubah parameter di sub-halaman',
        'es': 'Resumen de solo lectura: edita los parámetros en las subpáginas',
    },
    'deviceEntries': {
        'zh': '设备与参数', 'zh_TW': '裝置與參數', 'en': 'Devices & parameters',
        'ja': 'デバイスとパラメータ', 'id': 'Perangkat & parameter',
        'es': 'Dispositivos y parámetros',
    },
    'deviceEntriesDesc': {
        'zh': '每条链路一个子页，各管各的参数',
        'zh_TW': '每條鏈路一個子頁，各管各的參數',
        'en': 'One sub-page per link, each with its own settings',
        'ja': 'リンクごとに 1 ページ、設定もそれぞれ独立',
        'id': 'Satu sub-halaman per tautan, setelannya masing-masing',
        'es': 'Una subpágina por enlace, cada una con sus ajustes',
    },
    'tncDeviceTitle': {
        'zh': 'TNC 设备与参数', 'zh_TW': 'TNC 裝置與參數',
        'en': 'TNC device & parameters', 'ja': 'TNC デバイスとパラメータ',
        'id': 'Perangkat & parameter TNC', 'es': 'Dispositivo y parámetros TNC',
    },
    'tncDeviceDesc': {
        'zh': '蓝牙/串口绑定、初始化串、KISS 参数与发射自检',
        'zh_TW': '藍牙/序列綁定、初始化串、KISS 參數與發射自檢',
        'en': 'Bluetooth/serial binding, init string, KISS parameters and TX self-test',
        'ja': 'Bluetooth／シリアル接続、初期化文字列、KISS パラメータ、送信自己診断',
        'id': 'Binding Bluetooth/serial, string init, parameter KISS, uji pancar',
        'es': 'Emparejamiento Bluetooth/serie, cadena de inicio, parámetros KISS y autoprueba de TX',
    },
    'deviceLogTitle': {
        'zh': '链路日志', 'zh_TW': '鏈路日誌', 'en': 'Link log',
        'ja': 'リンクログ', 'id': 'Log tautan', 'es': 'Registro del enlace',
    },
    'deviceLogDesc': {
        'zh': '显示当前来源的日志（TNC / 音频自动切换）',
        'zh_TW': '顯示目前來源的日誌（TNC / 音訊自動切換）',
        'en': 'Shows the log of the current source (TNC / audio switches automatically)',
        'ja': '現在のソースのログを表示（TNC／オーディオで自動切替）',
        'id': 'Menampilkan log sumber saat ini (TNC / audio otomatis)',
        'es': 'Muestra el registro de la fuente actual (TNC/audio cambia solo)',
    },
    # ── TNC 初始化串 ──
    'tncInitTitle': {
        'zh': 'TNC 初始化串', 'zh_TW': 'TNC 初始化字串',
        'en': 'TNC init string', 'ja': 'TNC 初期化文字列',
        'id': 'String init TNC', 'es': 'Cadena de inicio del TNC',
    },
    'tncInitSubtitle': {
        'zh': '连接后逐行发送（等价 APRSdroid 的 kiss.init）',
        'zh_TW': '連線後逐行傳送（等價 APRSdroid 的 kiss.init）',
        'en': 'Sent line by line after connecting (same as APRSdroid kiss.init)',
        'ja': '接続後に 1 行ずつ送信（APRSdroid の kiss.init 相当）',
        'id': 'Dikirim baris demi baris setelah terhubung (setara kiss.init APRSdroid)',
        'es': 'Se envía línea a línea tras conectar (equivalente al kiss.init de APRSdroid)',
    },
    'tncInitTip': {
        'zh': '若 TNC「能收不能发」，先在这里试：很多蓝牙/串口 TNC 模块上电停在命令模式，必须先收到 KISS ON、RESTART 等指令才进入 KISS 转发状态。每行一条命令（发送时自动补 CRLF）。',
        'zh_TW': '若 TNC「能收不能發」，先在這裡試：很多藍牙/序列 TNC 模組上電停在命令模式，必須先收到 KISS ON、RESTART 等指令才進入 KISS 轉發狀態。每行一條命令（傳送時自動補 CRLF）。',
        'en': 'If the TNC receives but will not transmit, try here first: many Bluetooth/serial TNC modules boot into command mode and need KISS ON / RESTART before they will forward in KISS. One command per line (CRLF is appended automatically).',
        'ja': 'TNC が「受信できるのに送信できない」場合はまずここを試してください。多くの Bluetooth／シリアル TNC は起動時にコマンドモードのままで、KISS ON／RESTART などを受け取って初めて KISS 転送に入ります。1 行 1 コマンド（CRLF は自動付加）。',
        'id': 'Bila TNC menerima tetapi tidak memancar, coba di sini dulu: banyak modul TNC Bluetooth/serial menyala dalam mode perintah dan perlu KISS ON / RESTART agar mau meneruskan dalam KISS. Satu perintah per baris (CRLF ditambahkan otomatis).',
        'es': 'Si el TNC recibe pero no transmite, prueba aquí primero: muchos módulos TNC Bluetooth/serie arrancan en modo comando y necesitan KISS ON / RESTART para reenviar en KISS. Un comando por línea (se añade CRLF automáticamente).',
    },
    'tncInitDelay': {
        'zh': '行间隔 (ms)', 'zh_TW': '行間隔 (ms)', 'en': 'Delay per line (ms)',
        'ja': '行ごとの間隔 (ms)', 'id': 'Jeda per baris (ms)',
        'es': 'Retardo por línea (ms)',
    },
    'tncInitDelayTip': {
        'zh': '每行命令之间的等待时间。模块处理命令需要时间，太短会丢命令',
        'zh_TW': '每行命令之間的等待時間。模組處理命令需要時間，太短會丟命令',
        'en': 'Wait between lines. Modules need time to process commands; too short drops them',
        'ja': '行間の待ち時間。モジュールがコマンドを処理する時間が必要で、短すぎると取りこぼします',
        'id': 'Jeda antar baris. Modul butuh waktu memproses perintah; terlalu singkat bisa terlewat',
        'es': 'Espera entre líneas. El módulo necesita tiempo; si es muy corto se pierden comandos',
    },
    'tncInitSendAction': {
        'zh': '立即发送初始化串', 'zh_TW': '立即傳送初始化字串',
        'en': 'Send init string now', 'ja': '初期化文字列を今すぐ送信',
        'id': 'Kirim string init sekarang', 'es': 'Enviar cadena de inicio ahora',
    },
    'tncInitSent': {
        'zh': '已发送 {n} 行初始化串', 'zh_TW': '已傳送 {n} 行初始化字串',
        'en': 'Sent {n} init line(s)', 'ja': '初期化文字列を {n} 行送信しました',
        'id': '{n} baris init terkirim', 'es': '{n} línea(s) de inicio enviadas',
    },
    'tncInitEmpty': {
        'zh': '未填写初始化串', 'zh_TW': '未填寫初始化字串',
        'en': 'No init string configured', 'ja': '初期化文字列が未入力です',
        'id': 'String init belum diisi', 'es': 'No hay cadena de inicio',
    },
    # ── KISS 参数下发开关 ──
    'tncPushParams': {
        'zh': '连接后下发 KISS 参数', 'zh_TW': '連線後下發 KISS 參數',
        'en': 'Push KISS parameters on connect',
        'ja': '接続時に KISS パラメータを送信',
        'id': 'Kirim parameter KISS saat terhubung',
        'es': 'Enviar parámetros KISS al conectar',
    },
    'tncPushParamsTip': {
        'zh': '默认关闭（与 APRSdroid 一致）。打开后连接时会把上面的参数推给 TNC，覆盖它自己的配置 —— 参数不合适可能让它一直退避而不发射，所以只在需要统一管理时打开。',
        'zh_TW': '預設關閉（與 APRSdroid 一致）。打開後連線時會把上面的參數推給 TNC，覆蓋它自己的設定 —— 參數不合適可能讓它一直退避而不發射，所以只在需要統一管理時打開。',
        'en': 'Off by default (same as APRSdroid). When on, the values above are pushed to the TNC on connect, overriding its own configuration — inappropriate values can make it back off forever without transmitting, so enable only if you want centralised control.',
        'ja': '既定はオフ（APRSdroid と同じ）。オンにすると接続時に上記の値を TNC へ送り、TNC 自身の設定を上書きします。値が不適切だと送信せず待ち続けることがあるため、一元管理したいときだけ有効にしてください。',
        'id': 'Mati secara bawaan (sama seperti APRSdroid). Bila aktif, nilai di atas dikirim ke TNC saat terhubung dan menimpa konfigurasinya — nilai yang tidak cocok bisa membuatnya terus menunggu tanpa memancar, jadi aktifkan hanya bila ingin dikelola terpusat.',
        'es': 'Desactivado por defecto (igual que APRSdroid). Si se activa, los valores de arriba se envían al TNC al conectar y sobrescriben su configuración; valores inadecuados pueden hacer que nunca transmita, así que actívalo solo si quieres gestionarlo de forma centralizada.',
    },
    # ── 发射自检 ──
    'tncTxTestTitle': {
        'zh': '发射自检', 'zh_TW': '發射自檢', 'en': 'TX self-test',
        'ja': '送信自己診断', 'id': 'Uji pancar', 'es': 'Autoprueba de TX',
    },
    'tncTxTestSubtitle': {
        'zh': '向 TNC 写一帧测试包，判断问题在链路还是 TNC',
        'zh_TW': '向 TNC 寫一幀測試包，判斷問題在鏈路還是 TNC',
        'en': 'Writes one test frame to the TNC to tell link problems from TNC problems',
        'ja': 'テストフレームを 1 つ TNC に書き込み、問題がリンク側か TNC 側かを切り分けます',
        'id': 'Menulis satu bingkai uji ke TNC untuk memisahkan masalah tautan vs TNC',
        'es': 'Escribe una trama de prueba al TNC para distinguir problemas de enlace o del TNC',
    },
    'tncTxTestHint': {
        'zh': '发的是一帧状态包（不含坐标），不会把台站在 aprs.fi 上挪位置。若这里显示「已写入」却仍然不发射，问题在 TNC 侧：先试初始化串（KISS ON / RESTART），再检查 TxDelay 与信道占用。',
        'zh_TW': '發的是一幀狀態包（不含座標），不會把台站在 aprs.fi 上挪位置。若這裡顯示「已寫入」卻仍然不發射，問題在 TNC 側：先試初始化字串（KISS ON / RESTART），再檢查 TxDelay 與通道佔用。',
        'en': 'It sends a status frame (no coordinates), so it will not move your station on aprs.fi. If it reports "written" but nothing is transmitted, the problem is on the TNC side: try the init string (KISS ON / RESTART) first, then check TxDelay and channel occupancy.',
        'ja': '送るのはステータスフレーム（位置情報なし）なので、aprs.fi 上で局を移動させません。ここで「書き込み済み」と出るのに送信されない場合、問題は TNC 側です。まず初期化文字列（KISS ON／RESTART）を試し、次に TxDelay とチャネルの混雑を確認してください。',
        'id': 'Yang dikirim adalah bingkai status (tanpa koordinat), jadi tidak memindahkan stasiun Anda di aprs.fi. Bila tertulis "tertulis" tetapi tetap tidak memancar, masalahnya di sisi TNC: coba string init (KISS ON / RESTART) dulu, lalu periksa TxDelay dan okupansi kanal.',
        'es': 'Envía una trama de estado (sin coordenadas), así que no moverá tu estación en aprs.fi. Si indica "escrito" pero no se transmite, el problema está en el TNC: prueba primero la cadena de inicio (KISS ON / RESTART) y luego revisa TxDelay y la ocupación del canal.',
    },
    'tncTxTestAction': {
        'zh': '写入测试帧', 'zh_TW': '寫入測試幀', 'en': 'Write test frame',
        'ja': 'テストフレームを書き込む', 'id': 'Tulis bingkai uji',
        'es': 'Escribir trama de prueba',
    },
    'tncTxTestOkPrefix': {
        'zh': '已写入', 'zh_TW': '已寫入', 'en': 'Written',
        'ja': '書き込み済み', 'id': 'Tertulis', 'es': 'Escrito',
    },
    'tncTxTestOk': {
        'zh': '已写入 TNC（累计 {n} 帧）。若电台仍不发射，问题在 TNC 侧：试初始化串或检查 TxDelay。',
        'zh_TW': '已寫入 TNC（累計 {n} 幀）。若電台仍不發射，問題在 TNC 側：試初始化字串或檢查 TxDelay。',
        'en': 'Written to the TNC ({n} frames total). If the radio still does not transmit, the issue is on the TNC side: try the init string or check TxDelay.',
        'ja': 'TNC に書き込みました（累計 {n} フレーム）。無線機が送信しない場合は TNC 側の問題です。初期化文字列を試すか TxDelay を確認してください。',
        'id': 'Tertulis ke TNC (total {n} bingkai). Bila radio tetap tidak memancar, masalahnya di sisi TNC: coba string init atau periksa TxDelay.',
        'es': 'Escrito en el TNC ({n} tramas en total). Si la radio sigue sin transmitir, el problema está en el TNC: prueba la cadena de inicio o revisa TxDelay.',
    },
    'tncTxTestFail': {
        'zh': '未写入：{err}', 'zh_TW': '未寫入：{err}', 'en': 'Not written: {err}',
        'ja': '書き込み失敗：{err}', 'id': 'Tidak tertulis: {err}',
        'es': 'No escrito: {err}',
    },
    'tncNeedConnected': {
        'zh': '请先连接 TNC', 'zh_TW': '請先連接 TNC', 'en': 'Connect the TNC first',
        'ja': '先に TNC へ接続してください', 'id': 'Hubungkan TNC dulu',
        'es': 'Conecta primero el TNC',
    },
}

PLACEHOLDERS = {
    'tncInitSent': {'n': 'int'},
    'tncTxTestOk': {'n': 'String'},
    'tncTxTestFail': {'err': 'String'},
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
ANCHOR = '"codeContributionTranslation"'


def main():
    for lang in LANGS:
        path = os.path.join(ROOT, 'lib/l10n/app_%s.arb' % lang)
        lines = io.open(path, encoding='utf-8').read().split('\n')
        out = []
        for ln in lines:
            st = ln.strip()
            if any(st.startswith('"%s"' % k) for k in DATA):
                continue
            if any(st.startswith('"@%s"' % k) for k in PLACEHOLDERS):
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
        for k, ph in PLACEHOLDERS.items():
            block.append('  "@%s": %s,' % (
                k,
                json.dumps({'placeholders': {a: {'type': b} for a, b in ph.items()}},
                           ensure_ascii=False)))
        lines[idx + 1:idx + 1] = block
        io.open(path, 'w', encoding='utf-8').write('\n'.join(lines))
        d = json.loads(io.open(path, encoding='utf-8').read())
        n = len([k for k in d if not k.startswith('@')])
        print('%s ok, %d keys (+%d)' % (path, n, len(DATA)))


if __name__ == '__main__':
    main()
