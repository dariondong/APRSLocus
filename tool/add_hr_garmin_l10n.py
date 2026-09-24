#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为「粗定位（网络）不自动上报」补/改 l10n 键（6 语言）。

同时更新：
  * lib/l10n/app_*.arb                （真源）
  * lib/l10n/app_localizations.dart   （抽象类成员）
  * lib/l10n/app_localizations_*.dart （各语言实现）

还负责**改写已有键的文案**：`locModeNetHint` 里写着「GPS 停更 2 分钟」，而
v1.6.163 把策略层的等待提到了 5 分钟 —— 文案不跟着改就成了假话，而这种假话
没有任何编译期检查会拦（arb 是纯 JSON，改文案不会让任何测试变红）。

产物按 gen-l10n 的形状手写（仓库把产物提交进了 git，本机不能跑 gen-l10n），
写完由 tool/check_l10n_sync.py 校验 arb ↔ 产物一一对应。
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}

# key → (zh, zh_TW, en, ja, es, id)
# key → (zh, zh_TW, en, ja, es, id)
KEYS = {
    'locationGarmin': (
        '佳明 LiveTrack', '佳明 LiveTrack', 'Garmin LiveTrack',
        'Garmin LiveTrack', 'Garmin LiveTrack', 'Garmin LiveTrack',
    ),
    'hrCardTitle': ('心率', '心率', 'Heart rate', '心拍数',
                    'Frecuencia cardíaca', 'Detak jantung'),
    'hrCardSubtitle': (
        '蓝牙心率带（标准心率服务），可随信标一起上报',
        '藍牙心率帶（標準心率服務），可隨信標一起上報',
        'Bluetooth heart-rate straps (standard HR service), optionally sent with your beacon',
        'Bluetooth 心拍センサー（標準 HR サービス）。ビーコンに同梱できます',
        'Bandas de pecho Bluetooth (servicio HR estándar), opcionalmente con tu baliza',
        'Chest strap Bluetooth (layanan HR standar), opsional ikut beacon',
    ),
    'hrIncludeInBeacon': (
        '信标附带心率', '信標附帶心率', 'Send heart rate in beacon',
        'ビーコンに心拍数を付ける', 'Enviar pulso en la baliza', 'Kirim detak jantung di beacon',
    ),
    'hrIncludeHint': (
        '开启后在位置包的备注里加 HR=nn（APRS 的通行写法，第三方地图会当备注显示）。'
        '没有读数时不会发 HR=0 —— 那会被收端当成「心率 0」而不是「没测」。',
        '開啟後在位置包的備註裡加 HR=nn（APRS 的通行寫法，第三方地圖會當備註顯示）。'
        '沒有讀數時不會發 HR=0 —— 那會被收端當成「心率 0」而不是「沒測」。',
        'Adds HR=nn to the position comment (the common APRS convention; third-party maps '
        'show it as a comment). With no reading we send nothing rather than HR=0, which '
        'receivers would read as "pulse 0" instead of "not measured".',
        '位置コメントに HR=nn を付けます（APRS の慣例。サードパーティ地図ではコメント表示）。'
        '読み取りが無いときは HR=0 を送りません（受信側が「心拍 0」と誤解するため）。',
        'Añade HR=nn al comentario de posición (convención APRS habitual; los mapas de '
        'terceros lo muestran como comentario). Sin lectura no enviamos HR=0, porque el '
        'receptor lo leería como "pulso 0" en vez de "sin medir".',
        'Menambahkan HR=nn ke komentar posisi (konvensi APRS; peta pihak ketiga '
        'menampilkannya sebagai komentar). Tanpa bacaan, kami tidak mengirim HR=0.',
    ),
    'hrConnected': ('已连接 {name}', '已連線 {name}', 'Connected to {name}',
                    '{name} に接続', 'Conectado a {name}', 'Tersambung ke {name}'),
    'hrWaitReading': ('等待读数（把心率带贴紧皮肤）', '等待讀數（把心率帶貼緊皮膚）',
                      'Waiting for a reading (make sure the strap is snug)',
                      '読み取り待ち（ベルトを密着させてください）',
                      'Esperando lectura (ajusta la banda)', 'Menunggu bacaan (pasang strap rapat)'),
    'hrSearch': ('搜索心率设备', '搜尋心率裝置', 'Scan for heart-rate devices',
                 '心拍デバイスを検索', 'Buscar sensores de pulso', 'Cari perangkat detak jantung'),
    'hrScanning': ('正在搜索…', '正在搜尋…', 'Scanning…', '検索中…', 'Buscando…', 'Memindai…'),
    'hrStopScan': ('停止搜索', '停止搜尋', 'Stop scanning', '検索を停止', 'Detener búsqueda',
                   'Hentikan pemindaian'),
    'hrNoDevice': (
        '没有找到心率设备。确认心率带正在广播（多数胸带贴上电极片就开始广播），'
        '并让它离手机近一些。',
        '沒有找到心率裝置。確認心率帶正在廣播（多數胸帶貼上電極片就開始廣播），'
        '並讓它離手機近一些。',
        'No heart-rate device found. Make sure the strap is broadcasting (most straps start '
        'once the electrodes are worn) and is close to the phone.',
        '心拍デバイスが見つかりません。ベルトが送信中か確認し、スマホの近くに置いてください。',
        'No se encontró ningún sensor. Comprueba que la banda esté emitiendo y cerca del teléfono.',
        'Tidak ada perangkat ditemukan. Pastikan strap memancarkan dan dekat dengan ponsel.',
    ),
    'hrConnect': ('连接', '連線', 'Connect', '接続', 'Conectar', 'Sambungkan'),
    'hrDisconnect': ('断开', '斷開', 'Disconnect', '切断', 'Desconectar', 'Putuskan'),
    'hrForget': ('忘记该设备', '忘記該裝置', 'Forget device', 'デバイスを削除',
                 'Olvidar dispositivo', 'Lupakan perangkat'),
    'hrNotSupported': (
        '本机不支持蓝牙心率（该功能在 Android 版提供）',
        '本機不支援藍牙心率（該功能在 Android 版提供）',
        'Bluetooth heart rate is not available on this platform (Android only)',
        'この環境では Bluetooth 心拍を利用できません（Android 版のみ）',
        'El pulso por Bluetooth no está disponible en esta plataforma (solo Android)',
        'Detak jantung Bluetooth tidak tersedia di platform ini (hanya Android)',
    ),
    'hrConflictWithTnc': (
        '这个设备正被 TNC / PKWDWPL 的蓝牙链路使用，不能同时当心率带',
        '這個裝置正被 TNC / PKWDWPL 的藍牙鏈路使用，不能同時當心率帶',
        'That device is used by the TNC / PKWDWPL Bluetooth link; it cannot be the strap too',
        'そのデバイスは TNC / PKWDWPL の Bluetooth リンクが使用中です（兼用は不可）',
        'Ese dispositivo lo usa el enlace Bluetooth de TNC / PKWDWPL; no puede ser la banda',
        'Perangkat itu dipakai tautan Bluetooth TNC / PKWDWPL; tidak bisa jadi strap juga',
    ),
    'hrStrapHint': (
        '支持标准心率服务（0x180D）的胸带/臂带都行，例如 Polar H10、Garmin HRM、迈金、Coospo。'
        'TNC 走经典蓝牙、心率走 BLE，两条链路互不干扰。',
        '支援標準心率服務（0x180D）的胸帶／臂帶都行，例如 Polar H10、Garmin HRM、邁金、Coospo。'
        'TNC 走經典藍牙、心率走 BLE，兩條鏈路互不干擾。',
        'Any strap broadcasting the standard Heart Rate service (0x180D) works — Polar H10, '
        'Garmin HRM, Magene, Coospo. TNC uses classic Bluetooth and heart rate uses BLE, so '
        'the two links do not interfere.',
        '標準 HR サービス（0x180D）を送信する胸／腕ベルトならどれでも（Polar H10、Garmin HRM など）。'
        'TNC はクラシック Bluetooth、心拍は BLE なので互いに干渉しません。',
        'Sirve cualquier banda que emita el servicio HR estándar (0x180D): Polar H10, Garmin HRM. '
        'TNC usa Bluetooth clásico y el pulso usa BLE, así que no interfieren.',
        'Strap apa pun yang memancarkan layanan HR standar (0x180D) bisa dipakai. TNC memakai '
        'Bluetooth klasik dan detak jantung memakai BLE, jadi tidak saling mengganggu.',
    ),
    'garminCardTitle': ('佳明 LiveTrack', '佳明 LiveTrack', 'Garmin LiveTrack',
                        'Garmin LiveTrack', 'Garmin LiveTrack', 'Garmin LiveTrack'),
    'garminCardSubtitle': (
        '把佳明手表的活动实时位置接进来，随信标上报',
        '把佳明手錶的活動即時位置接進來，隨信標上報',
        'Pull your Garmin watch activity in and beacon it',
        'Garmin ウォッチの活動位置を取り込み、ビーコンで送信',
        'Trae la actividad de tu reloj Garmin y balízala',
        'Tarik aktivitas jam Garmin dan pancarkan sebagai beacon',
    ),
    'garminUrlLabel': ('分享链接', '分享連結', 'Share link', '共有リンク',
                       'Enlace compartido', 'Tautan berbagi'),
    'garminPaste': ('从剪贴板粘贴', '從剪貼簿貼上', 'Paste from clipboard',
                    'クリップボードから貼り付け', 'Pegar del portapapeles', 'Tempel dari papan klip'),
    'garminStart': ('开始追踪', '開始追蹤', 'Start tracking', '追跡を開始',
                    'Iniciar seguimiento', 'Mulai lacak'),
    'garminStop': ('停止追踪', '停止追蹤', 'Stop tracking', '追跡を停止',
                   'Detener seguimiento', 'Hentikan lacak'),
    'garminRunning': ('追踪中', '追蹤中', 'Tracking', '追跡中', 'Siguiendo', 'Melacak'),
    'garminStats': ('已转发 {n} 个点 · 最后更新 {t}', '已轉發 {n} 個點 · 最後更新 {t}',
                    '{n} points forwarded · last update {t}',
                    '{n} 点を転送 · 最終更新 {t}', '{n} puntos reenviados · última {t}',
                    '{n} titik diteruskan · terakhir {t}'),
    'garminBadUrl': (
        '链接格式不对。请粘贴完整的 LiveTrack 分享链接（含 /session/…/token/…）',
        '連結格式不對。請貼上完整的 LiveTrack 分享連結（含 /session/…/token/…）',
        'That is not a LiveTrack link. Paste the full share URL (with /session/…/token/…)',
        'リンク形式が正しくありません（/session/…/token/… を含む URL を貼り付けてください）',
        'El enlace no es válido. Pega la URL completa (con /session/…/token/…)',
        'Tautan tidak valid. Tempel URL lengkap (dengan /session/…/token/…)',
    ),
    'garminNoPoints': (
        '还没有取到点。活动可能刚开始，或链接已过期。',
        '還沒有取到點。活動可能剛開始，或連結已過期。',
        'No points yet — the activity may have just started, or the link has expired.',
        'まだ点を取得できません（開始直後か、リンク期限切れの可能性）。',
        'Aún no hay puntos: puede que la actividad acabe de empezar o el enlace haya caducado.',
        'Belum ada titik — aktivitas mungkin baru mulai atau tautan sudah kedaluwarsa.',
    ),
    'garminError': ('抓取失败：{error}', '抓取失敗：{error}', 'Fetch failed: {error}',
                    '取得に失敗：{error}', 'Fallo al obtener: {error}', 'Gagal mengambil: {error}'),
    'garminHowTo': (
        '怎么拿到链接：在佳明 Connect App 里打开该活动 → 分享 → 选「APRSlocus」'
        '（本应用已注册系统分享入口），链接会自动填到这里并开始追踪；'
        '也可以手动复制链接后粘贴到上面。',
        '怎麼拿到連結：在佳明 Connect App 裡打開該活動 → 分享 → 選「APRSlocus」'
        '（本應用已註冊系統分享入口），連結會自動填到這裡並開始追蹤；'
        '也可以手動複製連結後貼到上面。',
        'How to get the link: in the Garmin Connect app open the activity → Share → pick '
        '"APRSlocus" (the app registers a system share target) and the link lands here and '
        'starts tracking; or copy the link and paste it above.',
        'リンクの取得方法：Garmin Connect アプリで活動を開く → 共有 → 「APRSlocus」を選択'
        '（システム共有先に登録済み）。リンクがここに入り追跡が始まります。',
        'Cómo obtener el enlace: en la app Garmin Connect abre la actividad → Compartir → '
        'elige "APRSlocus" (la app registra un destino del sistema) y el enlace llega aquí.',
        'Cara mendapatkan tautan: di aplikasi Garmin Connect buka aktivitas → Bagikan → pilih '
        '"APRSlocus" (terdaftar sebagai tujuan berbagi sistem), tautan masuk ke sini.',
    ),
    'garminSharedToast': ('已收到佳明分享链接', '已收到佳明分享連結',
                          'Garmin share link received', 'Garmin 共有リンクを受け取りました',
                          'Enlace de Garmin recibido', 'Tautan Garmin diterima'),
    'garminOpen': ('去设置', '去設定', 'Open settings', '設定を開く', 'Abrir ajustes', 'Buka setelan'),
    'garminWebUnsupported': (
        'Web 版不支持（浏览器的跨域限制），请在 Android / Windows 版使用',
        'Web 版不支援（瀏覽器的跨域限制），請在 Android / Windows 版使用',
        'Not available on the web build (browser CORS); use the Android or Windows build',
        'Web 版では利用できません（ブラウザの CORS 制限）。Android / Windows 版をご利用ください',
        'No disponible en la versión web (CORS del navegador); usa la de Android o Windows',
        'Tidak tersedia di versi web (CORS peramban); gunakan versi Android atau Windows',
    ),
    'hrForTncNote': (
        '心率带与 TNC 用的是两套蓝牙（BLE / 经典），可以同时连接',
        '心率帶與 TNC 用的是兩套藍牙（BLE / 經典），可以同時連線',
        'Heart rate uses BLE while TNC uses classic Bluetooth, so both can be connected',
        '心拍は BLE、TNC はクラシック Bluetooth なので同時接続できます',
        'El pulso usa BLE y el TNC Bluetooth clásico, así que pueden conectarse a la vez',
        'Detak jantung memakai BLE dan TNC Bluetooth klasik, jadi keduanya bisa tersambung',
    ),
}

# 改写已有键（本批没有）
UPDATES = {}

CLASSES = {
    'zh': 'AppLocalizationsZh',
    'zh_TW': 'AppLocalizationsZhTw',
    'en': 'AppLocalizationsEn',
    'ja': 'AppLocalizationsJa',
    'es': 'AppLocalizationsEs',
    'id': 'AppLocalizationsId',
}


def class_body(src, name):
    """返回 (类体起始, 类体结束) 两个索引。"""
    m = re.search(r'(?m)^(?:abstract )?class ' + re.escape(name) + r'\b', src)
    if not m:
        raise SystemExit(f'找不到类 {name}')
    j = src.find('\n}\n', m.end())
    if j < 0:
        j = src.rfind('\n}')
    return m.end(), j


def line_str(value):
    """arb 里的一行字符串值（转义、引号由 json 负责）。"""
    return json.dumps(value, ensure_ascii=False)


def main() -> int:
    root = ROOT
    arb_dir = os.path.join(root, 'lib', 'l10n')

    # ① ARB：新增键
    for lg in LANGS:
        p = os.path.join(arb_dir, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8', newline='').read()
        add = []
        for key, vals in KEYS.items():
            if re.search(r'^\s*"' + re.escape(key) + r'":', src, re.M):
                print(f'  {lg}/{key}: 已存在，跳过')
                continue
            add.append(f'  {line_str(key)}: {line_str(vals[IDX[lg]])},')
        if not add:
            continue
        i = src.rstrip().rfind('}')
        head = src[:i].rstrip()
        if not head.endswith(','):
            head += ','
        src = head + '\n' + '\n'.join(add).rstrip(',') + '\n' + src[i:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{lg}: ARB 追加 {len(add)} 键')

    # ② ARB：改写已有键（整行替换，保留行首缩进与行尾逗号）
    for lg in LANGS:
        p = os.path.join(arb_dir, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8', newline='').read()
        n = 0
        for key, vals in UPDATES.items():
            pat = re.compile(r'(?m)^(\s*)"' + re.escape(key) + r'":\s*".*?"(,?)$')
            new_line = f'\\g<1>{line_str(key)}: {line_str(vals[IDX[lg]])}\\g<2>'
            src, k = pat.subn(new_line, src)
            if k != 1:
                raise SystemExit(f'{lg}/{key}: 期望替换 1 处，实际 {k} 处')
            n += k
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{lg}: ARB 改写 {n} 键')

    # ③ 抽象类（app_localizations.dart）
    p = os.path.join(arb_dir, 'app_localizations.dart')
    src = io.open(p, encoding='utf-8', newline='').read()
    code = []
    for key in KEYS:
        if f'String get {key};' in src:
            continue
        code.append(f'  /// No description provided for @{key}.')
        code.append('  ///')
        code.append('  /// In zh, this message translates to:')
        code.append(f"  /// **'{KEYS[key][0]}'**")
        code.append(f'  String get {key};')
        code.append('')
    if code:
        _s, j = class_body(src, 'AppLocalizations')
        src = src[:j] + '\n' + '\n'.join(code)[:-1] + src[j:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'抽象类追加 {len(code) // 6} 键')

    # ④ 各语言实现：新增 + 改写
    for lg in LANGS:
        name = CLASSES[lg]
        fn = ('app_localizations_zh.dart' if lg in ('zh', 'zh_TW')
              else f'app_localizations_{lg}.dart')
        p = os.path.join(arb_dir, fn)
        src = io.open(p, encoding='utf-8', newline='').read()
        b0, b1 = class_body(src, name)
        body = src[b0:b1]
        code = []
        for key, vals in KEYS.items():
            if re.search(r'String get ' + re.escape(key) + r'\s*[=;]', body):
                continue
            code.append('  @override')
            code.append(f'  String get {key} => {line_str(vals[IDX[lg]])};')
            code.append('')
        if code:
            src = src[:b1] + '\n' + '\n'.join(code)[:-1] + src[b1:]
            b0, b1 = class_body(src, name)
        # 改写已有实现（只在该类体内找，类名不同故不会串语言）
        body = src[b0:b1]
        for key, vals in UPDATES.items():
            pat = re.compile(r'(?m)^(  )String get ' + re.escape(key) +
                             r' => .*?;( *)$')
            new_line = (f'\\g<1>String get {key} => '
                        f'{line_str(vals[IDX[lg]])};\\g<2>')
            body, k = pat.subn(new_line, body)
            if k != 1:
                raise SystemExit(f'{name}.{key}: 期望替换 1 处，实际 {k} 处')
        src = src[:b0] + body + src[b1:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{name}: 实现更新（新增 {len(code) // 3} 键，改写 {len(UPDATES)} 键）')

    return 0


if __name__ == '__main__':
    sys.exit(main())
