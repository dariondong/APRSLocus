#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""向 6 个 ARB 注入「APRSlocusBOX（小盒子）设备页」的文案键。

文本级插入（保持原 ARB 的键序与格式，不做整文件重排），幂等可重复执行。
同 tool/add_*_l10n.py 的既有约定。

⚠️ 两条与 ICU 有关的注意事项（与 PKWDWPL 那次同源）：
  1. 译文里没有 `$`；键名/命令名（`CFG`、`link`、`bt`）都是字面量，无需转义；
  2. 译文中禁止出现**单个**半角单引号 —— ICU 把 `'` 当转义符，一个落单的
     引号会让整条消息解析失败（英文/西文里避开 isn't、don't 这类缩写）。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATA = {
    # ── 设备页入口 ──
    'boxDeviceTitle': {
        'zh': 'APRSlocusBOX', 'zh_TW': 'APRSlocusBOX', 'en': 'APRSlocusBOX',
        'ja': 'APRSlocusBOX', 'id': 'APRSlocusBOX', 'es': 'APRSlocusBOX',
    },
    'boxDeviceDesc': {
        'zh': '小盒子：连上后用手机改配置、喂位置、发信标',
        'zh_TW': '小盒子：連上後用手機改設定、餵位置、發信標',
        'en': 'The box: connect to change its config, feed it a position, '
              'trigger a beacon',
        'ja': '小箱：接続してスマホから設定変更・位置供給・ビーコン送信',
        'id': 'Kotak: sambungkan untuk mengubah konfigurasi, memasok posisi, '
              'memicu beacon',
        'es': 'La caja: conéctala para cambiar su configuración, darle '
              'posición y lanzar un beacon',
    },
    # ── 连接 ──
    'boxBindTitle': {
        'zh': '盒子连接', 'zh_TW': '盒子連線', 'en': 'Box connection',
        'ja': '箱の接続', 'id': 'Koneksi kotak', 'es': 'Conexión de la caja',
    },
    'boxModeTip': {
        'zh': '盒子的「链路模式」要先设成 bt 或 both，蓝牙才可用；wifi 模式下请用 '
              'USB 串口连。link 与 bt 改完要重启盒子才生效。',
        'zh_TW': '盒子的「鏈路模式」要先設成 bt 或 both，藍牙才能用；wifi 模式下請用 '
                 'USB 串列埠連。link 與 bt 改完要重啟盒子才生效。',
        'en': 'Bluetooth only works when the box link mode is bt or both; in '
              'wifi mode use a USB serial cable. link and bt apply after '
              'rebooting the box.',
        'ja': '箱のリンクモードを bt か both にしないと Bluetooth は使えません。'
              'wifi モードでは USB シリアルで接続してください。'
              'link と bt は箱の再起動で反映されます。',
        'id': 'Bluetooth hanya aktif bila mode link kotak disetel bt atau '
              'both; pada mode wifi gunakan kabel serial USB. link dan bt '
              'berlaku setelah kotak di-reboot.',
        'es': 'El Bluetooth solo funciona si el modo enlace de la caja es bt '
              'o both; en modo wifi usa un cable serie USB. link y bt se '
              'aplican tras reiniciar la caja.',
    },
    'boxBtLinkWarn': {
        'zh': '盒子现在是 link = wifi：蓝牙管理用不了 —— 改成 bt/both 并重启盒子，'
              '或者插 USB 串口',
        'zh_TW': '盒子現在是 link = wifi：藍牙管理用不了 —— 改成 bt/both 並重啟盒子，'
                 '或者插 USB 串列埠',
        'en': 'The box is in link = wifi: Bluetooth management will not work. '
              'Set it to bt/both and reboot, or use a USB serial cable.',
        'ja': '箱は link = wifi です：Bluetooth 管理は使えません。bt/both に変えて'
              '再起動するか、USB シリアルを使ってください。',
        'id': 'Kotak sedang link = wifi: manajemen Bluetooth tidak bisa dipakai. '
              'Ubah ke bt/both lalu reboot, atau pakai kabel serial USB.',
        'es': 'La caja está en link = wifi: la gestión por Bluetooth no '
              'funcionará. Cámbialo a bt/both y reinicia, o usa un cable serie '
              'USB.',
    },
    'boxBaud': {
        'zh': '串口线速（USB / 桌面）', 'zh_TW': '串列埠線速（USB / 桌面）',
        'en': 'Serial baud rate (USB / desktop)',
        'ja': 'シリアル速度（USB / デスクトップ）',
        'id': 'Baud serial (USB / desktop)',
        'es': 'Velocidad serie (USB / escritorio)',
    },
    # ── 状态 ──
    'boxStatTitle': {
        'zh': '盒子状态', 'zh_TW': '盒子狀態', 'en': 'Box status',
        'ja': '箱の状態', 'id': 'Status kotak', 'es': 'Estado de la caja',
    },
    'boxStatLinkMode': {
        'zh': '链路模式', 'zh_TW': '鏈路模式', 'en': 'Link mode',
        'ja': 'リンクモード', 'id': 'Mode link', 'es': 'Modo de enlace',
    },
    'boxStatBeacon': {
        'zh': '自动信标', 'zh_TW': '自動信標', 'en': 'Auto beacon',
        'ja': '自動ビーコン', 'id': 'Beacon otomatis', 'es': 'Beacon automático',
    },
    'boxStatHost': {
        'zh': 'APRS-IS 服务器', 'zh_TW': 'APRS-IS 伺服器',
        'en': 'APRS-IS server', 'ja': 'APRS-IS サーバー',
        'id': 'Server APRS-IS', 'es': 'Servidor APRS-IS',
    },
    'boxStatGps': {
        'zh': 'GPS 波特率', 'zh_TW': 'GPS 波特率', 'en': 'GPS baud',
        'ja': 'GPS ボーレート', 'id': 'Baud GPS', 'es': 'Baudios del GPS',
    },
    'boxStatEvents': {
        'zh': '事件计数', 'zh_TW': '事件計數', 'en': 'Event counters',
        'ja': 'イベント数', 'id': 'Jumlah peristiwa', 'es': 'Recuento de eventos',
    },
    'boxLastEvent': {
        'zh': '最近事件', 'zh_TW': '最近事件', 'en': 'Last event',
        'ja': '最新イベント', 'id': 'Peristiwa terakhir', 'es': 'Último evento',
    },
    'boxNoEventYet': {
        'zh': '还没有事件', 'zh_TW': '還沒有事件', 'en': 'No events yet',
        'ja': 'イベントはまだありません', 'id': 'Belum ada peristiwa',
        'es': 'Aún no hay eventos',
    },
    # ── 配置 ──
    'boxCfgTitle': {
        'zh': '盒子配置', 'zh_TW': '盒子設定', 'en': 'Box config',
        'ja': '箱の設定', 'id': 'Konfigurasi kotak',
        'es': 'Configuración de la caja',
    },
    'boxCfgSubtitle': {
        'zh': '键名与盒子文档逐字一致，点一项即可修改',
        'zh_TW': '鍵名與盒子文件逐字一致，點一項即可修改',
        'en': 'Key names match the box documentation; tap an item to change it',
        'ja': 'キー名は箱のドキュメントと同じです。項目をタップして変更します',
        'id': 'Nama kunci sama persis dengan dokumentasi kotak; ketuk item '
              'untuk mengubah',
        'es': 'Los nombres de clave coinciden con la documentación; toca un '
              'elemento para cambiarlo',
    },
    'boxCfgRead': {
        'zh': '读取配置', 'zh_TW': '讀取設定', 'en': 'Read config',
        'ja': '設定を読み込む', 'id': 'Baca konfigurasi',
        'es': 'Leer configuración',
    },
    'boxCfgEmpty': {
        'zh': '还没读到配置 —— 先连接，再点「读取配置」',
        'zh_TW': '還沒讀到設定 —— 先連線，再點「讀取設定」',
        'en': 'No config read yet — connect first, then tap Read config',
        'ja': '設定はまだ読めていません — 接続してから読み込んでください',
        'id': 'Konfigurasi belum terbaca — sambungkan dulu, lalu ketuk Baca '
              'konfigurasi',
        'es': 'Aún no se ha leído la configuración — conecta primero y toca '
              'Leer configuración',
    },
    'boxCfgRebootHint': {
        'zh': 'link 与 bt 是开机设置：改完必须重启盒子才生效',
        'zh_TW': 'link 與 bt 是開機設定：改完必須重啟盒子才生效',
        'en': 'link and bt are boot settings: reboot the box to apply',
        'ja': 'link と bt は起動時設定です：箱の再起動で反映されます',
        'id': 'link dan bt adalah setelan boot: reboot kotak untuk '
              'menerapkannya',
        'es': 'link y bt son ajustes de arranque: reinicia la caja para '
              'aplicarlos',
    },
    'boxCfgSent': {
        'zh': '已发送到盒子', 'zh_TW': '已傳送到盒子', 'en': 'Sent to the box',
        'ja': '箱へ送信しました', 'id': 'Terkirim ke kotak',
        'es': 'Enviado a la caja',
    },
    'boxCfgEditTitle': {
        'zh': '修改配置项', 'zh_TW': '修改設定項', 'en': 'Change setting',
        'ja': '設定を変更', 'id': 'Ubah setelan', 'es': 'Cambiar ajuste',
    },
    'boxCfgEditHint': {
        'zh': '会发送 CFG 键=值；留空表示清空该值',
        'zh_TW': '會傳送 CFG 鍵=值；留空表示清空該值',
        'en': 'Sends CFG key=value; leave empty to clear the value',
        'ja': 'CFG キー=値を送信します。空欄は値を消去します',
        'id': 'Akan mengirim CFG kunci=nilai; kosongkan untuk menghapus nilai',
        'es': 'Envía CFG clave=valor; déjalo vacío para borrar el valor',
    },
    'boxCfgMasked': {
        'zh': '密码不回显：留空表示不改，只有填了新值才会写入',
        'zh_TW': '密碼不回顯：留空表示不改，只有填了新值才會寫入',
        'en': 'Passwords are not echoed: leave empty to keep it, enter a new '
              'value to overwrite',
        'ja': 'パスワードは表示されません：空欄なら変更なし、新しい値だけ'
              '書き込まれます',
        'id': 'Kata sandi tidak ditampilkan: biarkan kosong berarti tidak '
              'berubah, isi nilai baru untuk menimpa',
        'es': 'Las contraseñas no se muestran: déjalo vacío para no cambiarla '
              'o escribe un valor nuevo',
    },
    'boxCfgNoChange': {
        'zh': '未修改（密码不回显）', 'zh_TW': '未修改（密碼不回顯）',
        'en': 'Not changed (password is not echoed)',
        'ja': '変更なし（パスワードは非表示）',
        'id': 'Tidak diubah (kata sandi tidak ditampilkan)',
        'es': 'Sin cambios (la contraseña no se muestra)',
    },
    # ── 喂位置 ──
    'boxFeedTitle': {
        'zh': '把位置喂给盒子', 'zh_TW': '把位置餵給盒子',
        'en': 'Feed position to the box', 'ja': '位置を箱へ供給',
        'id': 'Pasok posisi ke kotak', 'es': 'Enviar posición a la caja',
    },
    'boxFeedSubtitle': {
        'zh': '盒子没有 GPS 时用它；喂进去的位置 60 秒内有效',
        'zh_TW': '盒子沒有 GPS 時用它；餵進去的位置 60 秒內有效',
        'en': 'Use it when the box has no GPS; a fed position stays valid for '
              '60 seconds',
        'ja': '箱に GPS がないときに使います。供給した位置は 60 秒有効です',
        'id': 'Pakai bila kotak tidak punya GPS; posisi yang dipasok berlaku '
              '60 detik',
        'es': 'Úsalo si la caja no tiene GPS; la posición enviada vale 60 '
              'segundos',
    },
    'boxFeedAuto': {
        'zh': '自动喂位置（30 秒一次）', 'zh_TW': '自動餵位置（30 秒一次）',
        'en': 'Feed automatically (every 30 s)',
        'ja': '自動で位置を供給（30 秒ごと）',
        'id': 'Pasok otomatis (tiap 30 detik)',
        'es': 'Enviar automáticamente (cada 30 s)',
    },
    'boxFeedSend': {
        'zh': '发送当前位置', 'zh_TW': '傳送目前位置',
        'en': 'Send current position', 'ja': '現在位置を送信',
        'id': 'Kirim posisi saat ini', 'es': 'Enviar posición actual',
    },
    'boxFeedStop': {
        'zh': '停止喂位置', 'zh_TW': '停止餵位置', 'en': 'Stop feeding',
        'ja': '供給を停止', 'id': 'Hentikan pasokan',
        'es': 'Dejar de enviar',
    },
    'boxFeedNoFix': {
        'zh': '手机还没有定位 —— 先在主页拿到定位',
        'zh_TW': '手機還沒有定位 —— 先在首頁取得定位',
        'en': 'No fix on the phone yet — get a position on the home page first',
        'ja': 'スマホ側にまだ位置がありません — 先にホームで測位してください',
        'id': 'Ponsel belum punya posisi — dapatkan dulu di halaman utama',
        'es': 'El teléfono aún no tiene posición — consíguela primero en la '
              'página principal',
    },
    # ── 动作 ──
    'boxActTitle': {
        'zh': '盒子动作', 'zh_TW': '盒子動作', 'en': 'Box actions',
        'ja': '箱の操作', 'id': 'Aksi kotak', 'es': 'Acciones de la caja',
    },
    'boxActBeacon': {
        'zh': '立即信标', 'zh_TW': '立即信標', 'en': 'Beacon now',
        'ja': '今すぐビーコン', 'id': 'Beacon sekarang',
        'es': 'Beacon ahora',
    },
    'boxActStatus': {
        'zh': '状态报文', 'zh_TW': '狀態報文', 'en': 'Status packet',
        'ja': 'ステータス', 'id': 'Paket status', 'es': 'Paquete de estado',
    },
    'boxActNet': {
        'zh': '重连 APRS-IS', 'zh_TW': '重連 APRS-IS',
        'en': 'Reconnect APRS-IS', 'ja': 'APRS-IS 再接続',
        'id': 'Sambung ulang APRS-IS', 'es': 'Reconectar APRS-IS',
    },
    'boxActClear': {
        'zh': '清空台站', 'zh_TW': '清空台站', 'en': 'Clear stations',
        'ja': '局リストを消去', 'id': 'Bersihkan stasiun',
        'es': 'Borrar estaciones',
    },
    'boxActTest': {
        'zh': '格式自检', 'zh_TW': '格式自檢', 'en': 'Format self-test',
        'ja': '書式セルフテスト', 'id': 'Uji mandiri format',
        'es': 'Autoprueba de formato',
    },
    'boxActReboot': {
        'zh': '重启盒子', 'zh_TW': '重啟盒子', 'en': 'Reboot box',
        'ja': '箱を再起動', 'id': 'Reboot kotak', 'es': 'Reiniciar la caja',
    },
    # ── 手机状态推给盒子 ──
    'boxPushTitle': {
        'zh': '手机状态给盒子', 'zh_TW': '手機狀態給盒子',
        'en': 'Phone status to the box', 'ja': 'スマホの状態を箱へ',
        'id': 'Status ponsel ke kotak', 'es': 'Estado del teléfono a la caja',
    },
    'boxPushStatus': {
        'zh': '推送实时状态（心率 / 速度 / 倒计时 / 里程 / 附近台站）',
        'zh_TW': '推送即時狀態（心率 / 速度 / 倒計時 / 里程 / 附近台站）',
        'en': 'Push live status (heart rate / speed / countdown / mileage / nearby)',
        'ja': 'リアルタイム状態を送る（心拍 / 速度 / カウントダウン / 距離 / 近くの局）',
        'id': 'Kirim status langsung (detak jantung / kecepatan / hitung mundur / jarak)',
        'es': 'Enviar estado en vivo (pulso / velocidad / cuenta atrás / distancia)',
    },
    'boxPushHint': {
        'zh': '盒子 PHONE 页显示这些；只写盒子屏幕，不上射频。与「喂位置」是两件事。',
        'zh_TW': '盒子 PHONE 頁顯示這些；只寫盒子螢幕，不上射頻。與「餵位置」是兩件事。',
        'en': 'The box PHONE page shows these; it only draws on the box screen, '
              'never on air. Separate from feeding a position.',
        'ja': '箱の PHONE ページに表示します。箱の画面に描くだけで電波は出しません。'
              '位置の供給とは別物です。',
        'id': 'Halaman PHONE kotak menampilkan ini; hanya menggambar di layar '
              'kotak, tidak dipancarkan. Terpisah dari memasok posisi.',
        'es': 'La página PHONE de la caja muestra esto; solo se dibuja en la '
              'pantalla de la caja, nunca sale al aire. Es distinto de enviar '
              'una posición.',
    },
    'boxEvtTitle': {
        'zh': '盒子事件', 'zh_TW': '盒子事件', 'en': 'Box events',
        'ja': '箱のイベント', 'id': 'Peristiwa kotak',
        'es': 'Eventos de la caja',
    },
}

PLACEHOLDERS = {}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
ANCHOR = '"dataSourceSwitchHint"'


def main():
    for lang in LANGS:
        path = os.path.join(ROOT, 'lib/l10n/app_%s.arb' % lang)
        lines = io.open(path, encoding='utf-8').read().split('\n')
        # 幂等：先移除同名前次注入
        keep = []
        for ln in lines:
            st = ln.strip()
            if any(st.startswith('"%s"' % k) for k in DATA):
                continue
            if any(st.startswith('"@%s"' % k) for k in PLACEHOLDERS):
                continue
            keep.append(ln)
        lines = keep
        idx = next(i for i, ln in enumerate(lines)
                   if ln.strip().startswith(ANCHOR))
        block = []
        for key, tr in DATA.items():
            block.append('  "%s": %s,' % (
                key, json.dumps(tr[lang], ensure_ascii=False)))
        for key, ph in PLACEHOLDERS.items():
            block.append('  "@%s": %s,' % (
                key,
                json.dumps({'placeholders': {k: {'type': v} for k, v in ph.items()}},
                           ensure_ascii=False)))
        lines[idx + 1:idx + 1] = block
        io.open(path, 'w', encoding='utf-8').write('\n'.join(lines))
        # 立刻自检：JSON 必须还能解析（ICU 单引号/转义问题会在这里露出来）
        d = json.loads(io.open(path, encoding='utf-8').read())
        n = len([k for k in d if not k.startswith('@')])
        print('%s ok, %d keys' % (os.path.basename(path), n))


if __name__ == '__main__':
    main()
