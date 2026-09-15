#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""向 6 个 ARB 注入「PKWDWPL 链路（Kenwood 航点语句）」的文案键。

文本级插入（保持原 ARB 的键序与格式，不做整文件重排），幂等可重复执行。
同 tool/add_*_l10n.py 的既有约定。

⚠️ 两条与 ICU 有关的注意事项（踩过就知道很痛）：
  1. 译文里的 `$` 必须原样写字面量（gen-l10n 会自行转义成 `\\$`），
     这里是 `$PKWDWPL`，**不要**写成 `\\$PKWDWPL`（那会输出两个字符）；
  2. 译文中禁止出现**单个**半角单引号 —— ICU 把 `'` 当转义符，
     一个落单的引号就会让整条消息解析失败（英文里要避免 isn't / radio's
     这类缩写，改用不带引号的说法）。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATA = {
    # ── 数据来源（与 TNC 并列的一条链路） ──
    'dataSourcePkwdwpl': {
        'zh': 'PKWDWPL（Kenwood 航点）', 'zh_TW': 'PKWDWPL（Kenwood 航點）',
        'en': 'PKWDWPL (Kenwood waypoints)',
        'ja': 'PKWDWPL（ケンウッド航点）',
        'id': 'PKWDWPL (waypoint Kenwood)',
        'es': 'PKWDWPL (puntos de ruta Kenwood)',
    },
    'dataSourcePkwdwplDesc': {
        'zh': '用蓝牙/串口读取电台输出的 Kenwood $PKWDWPL 航点语句（只收不发）',
        'zh_TW': '用藍牙/串列埠讀取電台輸出的 Kenwood $PKWDWPL 航點語句（只收不發）',
        'en': 'Read the Kenwood $PKWDWPL waypoint sentences from the radio over '
              'Bluetooth or serial (receive-only)',
        'ja': 'Bluetooth/シリアルで無線機が出力する Kenwood $PKWDWPL 航点文を'
              '読み取ります（受信のみ）',
        'id': 'Baca kalimat waypoint Kenwood $PKWDWPL dari radio lewat '
              'Bluetooth/serial (hanya terima)',
        'es': 'Lee las sentencias Kenwood $PKWDWPL que emite el equipo por '
              'Bluetooth o serie (solo recepción)',
    },
    'dataSourcePkwdwplHint': {
        'zh': 'PKWDWPL 是**只读**链路：能收台站、不参与发射（发射请用 APRS-IS / '
              'TNC / 音频）',
        'zh_TW': 'PKWDWPL 是**唯讀**鏈路：能收台站、不參與發射（發射請用 APRS-IS / '
                 'TNC / 音訊）',
        'en': 'PKWDWPL is a **receive-only** link: it brings in stations but never '
              'transmits (use APRS-IS / TNC / audio for transmitting)',
        'ja': 'PKWDWPL は**受信専用**リンクです。局を受信しますが送信には'
              '使われません（送信は APRS-IS / TNC / オーディオを使用）',
        'id': 'PKWDWPL adalah tautan **hanya terima**: menerima stasiun tetapi '
              'tidak pernah memancar (gunakan APRS-IS / TNC / audio untuk memancar)',
        'es': 'PKWDWPL es un enlace de **solo recepción**: recibe estaciones pero '
              'nunca transmite (para transmitir usa APRS-IS / TNC / audio)',
    },
    # ── 连接状态（只保留「连接中 / 已连接」：失败与掉线只进日志与链路行） ──
    'connConnectingPkwdwpl': {
        'zh': '正在连接 PKWDWPL（{arg}）…', 'zh_TW': '正在連線 PKWDWPL（{arg}）…',
        'en': 'Connecting to PKWDWPL ({arg})…',
        'ja': 'PKWDWPL に接続中（{arg}）…',
        'id': 'Menghubungkan PKWDWPL ({arg})…',
        'es': 'Conectando a PKWDWPL ({arg})…',
    },
    'connPkwdwplConnected': {
        'zh': 'PKWDWPL 已连接 · {arg}', 'zh_TW': 'PKWDWPL 已連線 · {arg}',
        'en': 'PKWDWPL connected · {arg}',
        'ja': 'PKWDWPL 接続済み · {arg}',
        'id': 'PKWDWPL terhubung · {arg}',
        'es': 'PKWDWPL conectado · {arg}',
    },
    # ── 设备页 ──
    'pkwdwplDeviceTitle': {
        'zh': 'PKWDWPL 设备', 'zh_TW': 'PKWDWPL 裝置',
        'en': 'PKWDWPL device', 'ja': 'PKWDWPL デバイス',
        'id': 'Perangkat PKWDWPL', 'es': 'Dispositivo PKWDWPL',
    },
    'pkwdwplDeviceDesc': {
        'zh': '绑定电台端口 · 查看航点接收状态',
        'zh_TW': '綁定電台連接埠 · 檢視航點接收狀態',
        'en': 'Bind the radio port and check waypoint reception',
        'ja': '無線機のポートを登録し、航点の受信状態を確認します',
        'id': 'Pasangkan port radio dan lihat status penerimaan waypoint',
        'es': 'Vincula el puerto del equipo y revisa la recepción de puntos de ruta',
    },
    'pkwdwplBindTitle': {
        'zh': '设备绑定与状态', 'zh_TW': '裝置綁定與狀態',
        'en': 'Device binding and status', 'ja': 'デバイス登録と状態',
        'id': 'Pemasangan perangkat dan status', 'es': 'Vinculación y estado',
    },
    'pkwdwplBindSubtitle': {
        'zh': '选择输出 $PKWDWPL 语句的那个串口 / 蓝牙端口',
        'zh_TW': '選擇輸出 $PKWDWPL 語句的那個串列埠 / 藍牙埠',
        'en': 'Pick the serial or Bluetooth port that outputs $PKWDWPL sentences',
        'ja': '$PKWDWPL 文を出力するシリアル / Bluetooth ポートを選択します',
        'id': 'Pilih port serial atau Bluetooth yang mengeluarkan kalimat $PKWDWPL',
        'es': 'Elige el puerto serie o Bluetooth que emite sentencias $PKWDWPL',
    },
    'pkwdwplRxOnly': {
        'zh': '只收不发', 'zh_TW': '只收不發',
        'en': 'Receive-only', 'ja': '受信のみ',
        'id': 'Hanya terima', 'es': 'Solo recepción',
    },
    'pkwdwplTip': {
        'zh': '在电台菜单里把 PC / GPS 端口的输出格式设为 "$PKWDWPL"（一般 4800 8N1）；'
              '这条链路只读，不会发射任何报文',
        'zh_TW': '在電台選單裡把 PC / GPS 埠的輸出格式設為 "$PKWDWPL"（一般 4800 8N1）；'
                 '這條鏈路唯讀，不會發射任何報文',
        'en': 'Set the PC / GPS port output format on the radio to "$PKWDWPL" '
              '(usually 4800 8N1). This link is read-only and transmits nothing.',
        'ja': '無線機のメニューで PC / GPS ポートの出力形式を "$PKWDWPL" に'
              '設定してください（通常 4800 8N1）。このリンクは受信専用で、'
              '一切送信しません。',
        'id': 'Setel format keluaran port PC / GPS di radio ke "$PKWDWPL" '
              '(biasanya 4800 8N1). Tautan ini hanya baca dan tidak memancarkan apa pun.',
        'es': 'Configura el formato de salida del puerto PC / GPS del equipo como '
              '"$PKWDWPL" (normalmente 4800 8N1). Este enlace es de solo lectura y '
              'no transmite nada.',
    },
    'pkwdwplStrictChecksum': {
        'zh': '严格校验和（不符即丢弃）', 'zh_TW': '嚴格校驗和（不符即丟棄）',
        'en': 'Strict checksum (drop mismatches)',
        'ja': '厳格なチェックサム（不一致は破棄）',
        'id': 'Checksum ketat (buang jika tidak cocok)',
        'es': 'Suma de comprobación estricta (descarta si no coincide)',
    },
    'pkwdwplStrictChecksumTip': {
        'zh': '默认关闭：验证不符时只标注并记日志，不丢句子 —— 本地线缆上的'
              '不符多半是固件格式与手册有出入，整条丢弃会让界面「什么都不显示」，'
              '反而更难排查',
        'zh_TW': '預設關閉：驗證不符時只標註並記日誌，不丟句子 —— 本機線纜上的'
                 '不符多半是韌體格式與手冊有出入，整條丟棄會讓介面「什麼都不顯示」，'
                 '反而更難排查',
        'en': 'Off by default: a mismatch is flagged and logged instead of dropped, '
              'because on a local cable it usually means the firmware format differs '
              'from the manual. Dropping every sentence would leave the screen empty '
              'and make diagnosis much harder.',
        'ja': '既定ではオフ。不一致は破棄せず記録とログのみ行います。'
              'ローカル接続での不一致はファームウェアの書式差であることが多く、'
              'すべて破棄すると画面が空になり、かえって原因を追いにくくなります。',
        'id': 'Nonaktif secara bawaan: ketidakcocokan hanya ditandai dan dicatat, '
              'tidak dibuang, karena pada kabel lokal hal ini biasanya berarti format '
              'firmware berbeda dari manual. Membuang semuanya akan membuat layar '
              'kosong dan jauh lebih sulit ditelusuri.',
        'es': 'Desactivado por defecto: una discrepancia se marca y se registra en '
              'lugar de descartarse, porque en un cable local suele significar que el '
              'formato del firmware difiere del manual. Descartar todo dejaría la '
              'pantalla vacía y dificultaría mucho el diagnóstico.',
    },
    'pkwdwplErrReadOnly': {
        'zh': '只读链路，不能发射', 'zh_TW': '唯讀鏈路，不能發射',
        'en': 'receive-only link cannot transmit',
        'ja': '受信専用リンクのため送信できません',
        'id': 'tautan hanya terima tidak dapat memancar',
        'es': 'el enlace de solo recepción no puede transmitir',
    },
    'pkwdwplStatTitle': {
        'zh': '航点接收', 'zh_TW': '航點接收',
        'en': 'Waypoint reception', 'ja': '航点の受信',
        'id': 'Penerimaan waypoint', 'es': 'Recepción de puntos de ruta',
    },
    'pkwdwplStats': {
        'zh': '已收航点 {rx} 条', 'zh_TW': '已收航點 {rx} 條',
        'en': '{rx} waypoints received',
        'ja': '航点を {rx} 件受信',
        'id': '{rx} waypoint diterima',
        'es': '{rx} puntos de ruta recibidos',
    },
    'pkwdwplStatRejected': {
        'zh': '丢弃/无效语句', 'zh_TW': '丟棄/無效語句',
        'en': 'Dropped or invalid sentences',
        'ja': '破棄/無効な文',
        'id': 'Kalimat dibuang atau tidak valid',
        'es': 'Sentencias descartadas o inválidas',
    },
    'pkwdwplStatMismatch': {
        'zh': '校验和不符', 'zh_TW': '校驗和不符',
        'en': 'Checksum mismatches', 'ja': 'チェックサム不一致',
        'id': 'Ketidakcocokan checksum', 'es': 'Discrepancias de suma',
    },
    'pkwdwplStatIgnored': {
        'zh': '其它 NMEA 语句（已忽略）', 'zh_TW': '其它 NMEA 語句（已忽略）',
        'en': 'Other NMEA sentences (ignored)',
        'ja': 'その他の NMEA 文（無視）',
        'id': 'Kalimat NMEA lain (diabaikan)',
        'es': 'Otras sentencias NMEA (ignoradas)',
    },
    'pkwdwplLogEmpty': {
        'zh': '暂无 PKWDWPL 日志', 'zh_TW': '暫無 PKWDWPL 日誌',
        'en': 'No PKWDWPL log yet', 'ja': 'PKWDWPL のログはまだありません',
        'id': 'Belum ada log PKWDWPL', 'es': 'Aún no hay registro de PKWDWPL',
    },
}

PLACEHOLDERS = {
    'connConnectingPkwdwpl': {'arg': 'String'},
    'connPkwdwplConnected': {'arg': 'String'},
    'pkwdwplStats': {'rx': 'String'},
}

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
        d = json.loads(io.open(path, encoding='utf-8').read())
        n = len([k for k in d if not k.startswith('@')])
        print('%s ok, %d keys' % (os.path.basename(path), n))


if __name__ == '__main__':
    main()
