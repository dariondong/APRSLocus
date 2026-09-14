#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""向 6 个 ARB 注入「音频（声卡 TNC）」相关文案键（文本级插入，保持原格式不被重排）。

与 tool/add_tnc_l10n.py 同一套做法：幂等（先移除同名键再插入）、按锚点整块插入、
写完用 json 解析自检。锚点取一个稳定存在、与本次无关的键，避免插进多行方法体。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# key -> {lang: text}
DATA = {
    # ── 通知栏 ──
    'notifAudioConnected': {
        'zh': '音频链路在线', 'zh_TW': '音訊鏈路線上', 'en': 'Audio link online',
        'ja': 'オーディオリンク接続中', 'id': 'Tautan audio aktif',
        'es': 'Enlace de audio en línea',
    },
    'notifAudioDisconnected': {
        'zh': '音频链路已断开', 'zh_TW': '音訊鏈路已中斷',
        'en': 'Audio link disconnected', 'ja': 'オーディオリンク切断',
        'id': 'Tautan audio terputus', 'es': 'Enlace de audio desconectado',
    },
    # ── 连接状态 ──
    'connConnectingAudio': {
        'zh': '正在打开音频（{name}）…', 'zh_TW': '正在開啟音訊（{name}）…',
        'en': 'Opening audio ({name})…', 'ja': 'オーディオを開いています（{name}）…',
        'id': 'Membuka audio ({name})…', 'es': 'Abriendo audio ({name})…',
    },
    'connAudioConnected': {
        'zh': '音频链路在线 · {rate}', 'zh_TW': '音訊鏈路線上 · {rate}',
        'en': 'Audio link online · {rate}', 'ja': 'オーディオリンク接続 · {rate}',
        'id': 'Tautan audio aktif · {rate}', 'es': 'Enlace de audio en línea · {rate}',
    },
    'connRetryAudio': {
        'zh': '音频链路打开失败 · {seconds}s 后重试…',
        'zh_TW': '音訊鏈路開啟失敗 · {seconds}s 後重試…',
        'en': 'Could not open audio · retrying in {seconds}s…',
        'ja': 'オーディオを開けません · {seconds}秒後に再試行…',
        'id': 'Gagal membuka audio · coba lagi dalam {seconds}s…',
        'es': 'No se pudo abrir el audio · reintentando en {seconds}s…',
    },
    'connRetryAudioDetail': {
        'zh': '音频打开失败（{detail}）· {seconds}s 后重试…',
        'zh_TW': '音訊開啟失敗（{detail}）· {seconds}s 後重試…',
        'en': 'Audio failed ({detail}) · retrying in {seconds}s…',
        'ja': 'オーディオ失敗（{detail}）· {seconds}秒後に再試行…',
        'id': 'Audio gagal ({detail}) · coba lagi dalam {seconds}s…',
        'es': 'Fallo de audio ({detail}) · reintentando en {seconds}s…',
    },
    'connAudioLinkLost': {
        'zh': '音频链路中断 · {seconds}秒后自动重连…',
        'zh_TW': '音訊鏈路中斷 · {seconds}秒後自動重連…',
        'en': 'Audio link lost · reconnecting in {seconds}s…',
        'ja': 'オーディオリンク切断 · {seconds}秒後に再接続…',
        'id': 'Tautan audio terputus · menyambung ulang dalam {seconds}s…',
        'es': 'Enlace de audio perdido · reconectando en {seconds}s…',
    },
    'connAudioPositionSent': {
        'zh': '音频已发射 · 位置已发送 ({call})',
        'zh_TW': '音訊已發射 · 位置已傳送 ({call})',
        'en': 'Sent over audio · position transmitted ({call})',
        'ja': 'オーディオ送信 · 位置を送信しました ({call})',
        'id': 'Terkirim via audio · posisi terkirim ({call})',
        'es': 'Enviado por audio · posición transmitida ({call})',
    },
    # ── 数据来源 ──
    'dataSourceAudio': {
        'zh': '音频（声卡）', 'zh_TW': '音訊（音效卡）', 'en': 'Audio (soundcard)',
        'ja': 'オーディオ（サウンドカード）', 'id': 'Audio (kartu suara)',
        'es': 'Audio (tarjeta de sonido)',
    },
    'dataSourceAudioDesc': {
        'zh': '用麦克风/扬声器或声卡线接电台，收发 AFSK 1200',
        'zh_TW': '用麥克風/揚聲器或音效卡線接電台，收發 AFSK 1200',
        'en': 'AFSK 1200 to/from a radio via mic/speaker or a soundcard cable',
        'ja': 'マイク／スピーカーまたはサウンドカード接続で AFSK 1200 を送受信',
        'id': 'AFSK 1200 ke/dari radio lewat mic/speaker atau kabel kartu suara',
        'es': 'AFSK 1200 hacia/desde una radio por micrófono/altavoz o cable de sonido',
    },
    # ── 音频页 ──
    'audioSettings': {
        'zh': '音频（声卡 TNC）', 'zh_TW': '音訊（音效卡 TNC）',
        'en': 'Audio (soundcard TNC)', 'ja': 'オーディオ（サウンドカード TNC）',
        'id': 'Audio (TNC kartu suara)', 'es': 'Audio (TNC de tarjeta de sonido)',
    },
    'audioSettingsSubtitle': {
        'zh': '用声卡收发 AFSK 1200 报文',
        'zh_TW': '用音效卡收發 AFSK 1200 報文',
        'en': 'Send and receive AFSK 1200 packets with your soundcard',
        'ja': 'サウンドカードで AFSK 1200 パケットを送受信',
        'id': 'Kirim/terima paket AFSK 1200 dengan kartu suara',
        'es': 'Envía y recibe paquetes AFSK 1200 con la tarjeta de sonido',
    },
    'audioBackend': {
        'zh': '音频后端', 'zh_TW': '音訊後端', 'en': 'Audio backend',
        'ja': 'オーディオバックエンド', 'id': 'Backend audio', 'es': 'Motor de audio',
    },
    'audioUnsupported': {
        'zh': '当前平台不支持实时音频（可用 WAV 文件模式）',
        'zh_TW': '目前平台不支援即時音訊（可用 WAV 檔案模式）',
        'en': 'Real-time audio is not supported on this platform (WAV file mode is available)',
        'ja': 'このプラットフォームはリアルタイム音声に未対応です（WAV ファイル方式は利用可）',
        'id': 'Audio waktu-nyata tidak didukung di platform ini (mode berkas WAV tersedia)',
        'es': 'Este sistema no admite audio en tiempo real (el modo WAV sí está disponible)',
    },
    'audioNeedPermission': {
        'zh': '需要录音权限（RECORD_AUDIO），请授权后重试',
        'zh_TW': '需要錄音權限（RECORD_AUDIO），請授權後重試',
        'en': 'Microphone permission (RECORD_AUDIO) is required — grant it and try again',
        'ja': '録音権限（RECORD_AUDIO）が必要です。許可して再試行してください',
        'id': 'Izin mikrofon (RECORD_AUDIO) diperlukan — berikan lalu coba lagi',
        'es': 'Se requiere permiso de micrófono (RECORD_AUDIO): concédelo e inténtalo de nuevo',
    },
    'audioCaptureTitle': {
        'zh': '音频采集', 'zh_TW': '音訊擷取', 'en': 'Audio capture',
        'ja': 'オーディオ入力', 'id': 'Penangkapan audio', 'es': 'Captura de audio',
    },
    'audioCaptureDesc': {
        'zh': '从麦克风/线路输入解调 AFSK 1200',
        'zh_TW': '從麥克風/線路輸入解調 AFSK 1200',
        'en': 'Demodulate AFSK 1200 from the mic/line input',
        'ja': 'マイク／ライン入力から AFSK 1200 を復調',
        'id': 'Demodulasi AFSK 1200 dari masukan mic/line',
        'es': 'Demodula AFSK 1200 desde la entrada de micrófono/línea',
    },
    'audioCaptureStart': {
        'zh': '打开采集', 'zh_TW': '開啟擷取', 'en': 'Start capture',
        'ja': '入力を開始', 'id': 'Mulai tangkap', 'es': 'Iniciar captura',
    },
    'audioCaptureStop': {
        'zh': '停止采集', 'zh_TW': '停止擷取', 'en': 'Stop capture',
        'ja': '入力を停止', 'id': 'Hentikan', 'es': 'Detener captura',
    },
    'audioSampleRate': {
        'zh': '采样率', 'zh_TW': '取樣率', 'en': 'Sample rate',
        'ja': 'サンプルレート', 'id': 'Laju sampel', 'es': 'Frecuencia de muestreo',
    },
    'audioSampleRateTip': {
        'zh': '22050Hz 是声卡 TNC 常用值；设备不支持时改用 44100/48000。修改会重启采集',
        'zh_TW': '22050Hz 是音效卡 TNC 常用值；裝置不支援時改用 44100/48000。修改會重啟擷取',
        'en': '22050 Hz is the usual soundcard-TNC rate; use 44100/48000 if unsupported. Changing it restarts capture',
        'ja': '22050Hz はサウンドカード TNC の一般的な値です。非対応なら 44100/48000 を使用。変更すると入力が再起動します',
        'id': '22050Hz adalah nilai umum TNC kartu suara; pakai 44100/48000 bila tidak didukung. Mengubahnya memulai ulang penangkapan',
        'es': '22050 Hz es lo habitual en TNC de tarjeta de sonido; usa 44100/48000 si no se admite. Cambiarlo reinicia la captura',
    },
    'audioLevel': {
        'zh': '输入电平', 'zh_TW': '輸入電平', 'en': 'Input level',
        'ja': '入力レベル', 'id': 'Level masukan', 'es': 'Nivel de entrada',
    },
    'audioLevelTip': {
        'zh': '有信号时电平条会抬起；收到 AFSK 时「解调锁定」会点亮',
        'zh_TW': '有訊號時電平條會抬起；收到 AFSK 時「解調鎖定」會點亮',
        'en': 'The meter rises with a signal; "Demod locked" lights up when AFSK is detected',
        'ja': '信号があるとメーターが上がり、AFSK を受信すると「復調ロック」が点灯します',
        'id': 'Meter naik saat ada sinyal; "Demod terkunci" menyala saat AFSK terdeteksi',
        'es': 'El medidor sube con señal; "Demodulación sincronizada" se ilumina al detectar AFSK',
    },
    'audioSynced': {
        'zh': '解调锁定', 'zh_TW': '解調鎖定', 'en': 'Demod locked',
        'ja': '復調ロック', 'id': 'Demod terkunci', 'es': 'Demodulación sincronizada',
    },
    'audioUnlocked': {
        'zh': '未锁定', 'zh_TW': '未鎖定', 'en': 'Not locked',
        'ja': '未ロック', 'id': 'Tidak terkunci', 'es': 'Sin sincronizar',
    },
    'audioBadFrames': {
        'zh': '解码中止 {n} 次（噪声/失步）',
        'zh_TW': '解碼中止 {n} 次（雜訊/失步）',
        'en': '{n} aborted decodes (noise / out of sync)',
        'ja': '復調中断 {n} 回（ノイズ／同期外れ）',
        'id': '{n} dekode dibatalkan (derau/kehilangan sinkron)',
        'es': '{n} decodificaciones abortadas (ruido/desincronización)',
    },
    'audioBaud': {
        'zh': '比特率', 'zh_TW': '位元率', 'en': 'Bit rate',
        'ja': 'ビットレート', 'id': 'Laju bit', 'es': 'Velocidad en baudios',
    },
    'audioTones': {
        'zh': '音调（标/空）', 'zh_TW': '音調（標/空）', 'en': 'Tones (mark/space)',
        'ja': 'トーン（マーク／スペース）', 'id': 'Nada (mark/space)',
        'es': 'Tonos (mark/space)',
    },
    'audioTxTitle': {
        'zh': '音频发射', 'zh_TW': '音訊發射', 'en': 'Audio transmit',
        'ja': 'オーディオ送信', 'id': 'Pemancaran audio', 'es': 'Transmisión de audio',
    },
    'audioTxDesc': {
        'zh': '发射前先听信道，避免与其它台站碰撞',
        'zh_TW': '發射前先聽通道，避免與其他台站碰撞',
        'en': 'Listens before transmitting to avoid collisions',
        'ja': '送信前にチャネルを監視して衝突を避けます',
        'id': 'Mendengarkan sebelum memancar untuk menghindari tabrakan',
        'es': 'Escucha antes de transmitir para evitar colisiones',
    },
    'audioTxEnabled': {
        'zh': '允许发射', 'zh_TW': '允許發射', 'en': 'Allow transmit',
        'ja': '送信を許可', 'id': 'Izinkan pancar', 'es': 'Permitir transmisión',
    },
    'audioTxEnabledTip': {
        'zh': '关闭后只接收不发射（只想听信标时最省心）',
        'zh_TW': '關閉後只接收不發射（只想聽信標時最省心）',
        'en': 'When off, receive only — handy if you just want to monitor beacons',
        'ja': 'オフにすると受信のみ。ビーコンを聞くだけのときに便利です',
        'id': 'Jika mati, hanya menerima — praktis bila hanya ingin memantau beacon',
        'es': 'Si está desactivado, solo recepción: útil si solo quieres escuchar balizas',
    },
    'audioTxDelayTip': {
        'zh': '发射前导时长：给对端解调器锁定时间、给电台 PTT 建立时间',
        'zh_TW': '發射前導時長：給對端解調器鎖定時間、給電台 PTT 建立時間',
        'en': 'Preamble length: lets the far-end demod lock and the radio key up',
        'ja': '送信前のプリアンブル長。相手の復調ロックと無線機 PTT 立ち上げに必要です',
        'id': 'Panjang preamble: memberi waktu demod lawan mengunci dan PTT radio aktif',
        'es': 'Duración del preámbulo: da tiempo al demodulador remoto y al PTT',
    },
    'audioToneMark': {
        'zh': '标号频率 (Hz)', 'zh_TW': '標號頻率 (Hz)', 'en': 'Mark tone (Hz)',
        'ja': 'マーク周波数 (Hz)', 'id': 'Nada mark (Hz)', 'es': 'Tono mark (Hz)',
    },
    'audioToneSpace': {
        'zh': '空号频率 (Hz)', 'zh_TW': '空號頻率 (Hz)', 'en': 'Space tone (Hz)',
        'ja': 'スペース周波数 (Hz)', 'id': 'Nada space (Hz)',
        'es': 'Tono space (Hz)',
    },
    'audioMarkTip': {
        'zh': 'Bell 202 规定标号 1200Hz、空号 2200Hz；只有 ±几 Hz 的容差，不要随意改',
        'zh_TW': 'Bell 202 規定標號 1200Hz、空號 2200Hz；只有 ±幾 Hz 的容差，不要隨意改',
        'en': 'Bell 202 specifies mark 1200 Hz / space 2200 Hz; the tolerance is only a few Hz',
        'ja': 'Bell 202 はマーク 1200Hz／スペース 2200Hz。許容は数 Hz のみです',
        'id': 'Bell 202 menetapkan mark 1200Hz / space 2200Hz; toleransinya hanya beberapa Hz',
        'es': 'Bell 202 define mark 1200 Hz y space 2200 Hz; la tolerancia es de unos pocos Hz',
    },
    'audioSpaceTip': {
        'zh': '空号音调。与标号音调一起决定 FSK 频偏（标准为 1000Hz）',
        'zh_TW': '空號音調。與標號音調一起決定 FSK 頻偏（標準為 1000Hz）',
        'en': 'Space tone. Together with mark it sets the FSK shift (1000 Hz nominal)',
        'ja': 'スペース音。マークと合わせて FSK シフト（標準 1000Hz）を決めます',
        'id': 'Nada space. Bersama mark menentukan shift FSK (nominal 1000Hz)',
        'es': 'Tono space. Junto con mark define el desplazamiento FSK (1000 Hz nominal)',
    },
    'audioBaudTip': {
        'zh': 'APRS 在 VHF 上固定 1200 bd（Bell 202），HF 才用 300',
        'zh_TW': 'APRS 在 VHF 上固定 1200 bd（Bell 202），HF 才用 300',
        'en': 'APRS on VHF is always 1200 bd (Bell 202); 300 bd is for HF',
        'ja': 'VHF の APRS は常に 1200 bd（Bell 202）。300 は HF 用です',
        'id': 'APRS di VHF selalu 1200 bd (Bell 202); 300 untuk HF',
        'es': 'APRS en VHF es siempre 1200 bd (Bell 202); 300 bd es para HF',
    },
    'audioTxDelayLabel': {
        'zh': '发射前导 (ms)', 'zh_TW': '發射前導 (ms)', 'en': 'Tx preamble (ms)',
        'ja': '送信プリアンブル (ms)', 'id': 'Preamble Tx (ms)',
        'es': 'Preámbulo Tx (ms)',
    },
    'audioTnc2Tip': {
        'zh': '格式 SRC>DEST,PATH:info，例如 BG7LZQ-9>APALOC:>TEST',
        'zh_TW': '格式 SRC>DEST,PATH:info，例如 BG7LZQ-9>APALOC:>TEST',
        'en': 'Format SRC>DEST,PATH:info, e.g. BG7LZQ-9>APALOC:>TEST',
        'ja': '形式 SRC>DEST,PATH:info（例：BG7LZQ-9>APALOC:>TEST）',
        'id': 'Format SRC>DEST,PATH:info, mis. BG7LZQ-9>APALOC:>TEST',
        'es': 'Formato SRC>DEST,PATH:info, p. ej. BG7LZQ-9>APALOC:>TEST',
    },
    'audioCsmaWait': {
        'zh': '发射前等待信道空闲 (ms)', 'zh_TW': '發射前等待通道空閒 (ms)',
        'en': 'Wait for a clear channel (ms)', 'ja': 'チャネル空き待ち (ms)',
        'id': 'Tunggu kanal bebas (ms)', 'es': 'Esperar canal libre (ms)',
    },
    'audioCsmaWaitTip': {
        'zh': '检测到信道占用时最多等待多久；0 = 不等待直接发射',
        'zh_TW': '偵測到通道佔用時最多等待多久；0 = 不等待直接發射',
        'en': 'How long to wait when the channel is busy; 0 = transmit immediately',
        'ja': 'チャネル使用中に待つ最大時間。0 で即時送信',
        'id': 'Berapa lama menunggu saat kanal sibuk; 0 = langsung pancar',
        'es': 'Cuánto esperar si el canal está ocupado; 0 = transmitir de inmediato',
    },
    'audioStopTx': {
        'zh': '停止发射', 'zh_TW': '停止發射', 'en': 'Stop transmit',
        'ja': '送信を停止', 'id': 'Hentikan pancar', 'es': 'Detener transmisión',
    },
    # ── WAV 文件模式 ──
    'audioWavTitle': {
        'zh': 'WAV 文件模式', 'zh_TW': 'WAV 檔案模式', 'en': 'WAV file mode',
        'ja': 'WAV ファイル方式', 'id': 'Mode berkas WAV', 'es': 'Modo de archivo WAV',
    },
    'audioWavDesc': {
        'zh': '离线解码一段录音，或把报文导出成音频文件',
        'zh_TW': '離線解碼一段錄音，或把報文匯出成音訊檔案',
        'en': 'Decode a recording offline, or export a packet as audio',
        'ja': '録音をオフライン復調、またはパケットを音声ファイルに書き出し',
        'id': 'Dekode rekaman secara offline, atau ekspor paket sebagai audio',
        'es': 'Decodifica una grabación sin conexión o exporta un paquete como audio',
    },
    'audioWavPath': {
        'zh': '文件路径', 'zh_TW': '檔案路徑', 'en': 'File path',
        'ja': 'ファイルパス', 'id': 'Jalur berkas', 'es': 'Ruta del archivo',
    },
    'audioWavDecodeAction': {
        'zh': '解码此 WAV', 'zh_TW': '解碼此 WAV', 'en': 'Decode this WAV',
        'ja': 'この WAV を復調', 'id': 'Dekode WAV ini', 'es': 'Decodificar este WAV',
    },
    'audioWavExportAction': {
        'zh': '导出此报文', 'zh_TW': '匯出此報文', 'en': 'Export this packet',
        'ja': 'このパケットを書き出し', 'id': 'Ekspor paket ini',
        'es': 'Exportar este paquete',
    },
    'audioWavTnC2': {
        'zh': '待导出报文 (TNC2)', 'zh_TW': '待匯出報文 (TNC2)',
        'en': 'Packet to export (TNC2)', 'ja': '書き出すパケット (TNC2)',
        'id': 'Paket untuk ekspor (TNC2)', 'es': 'Paquete a exportar (TNC2)',
    },
    'audioWavNone': {
        'zh': '未解出报文（可能不是 AFSK 1200 录音）',
        'zh_TW': '未解出報文（可能不是 AFSK 1200 錄音）',
        'en': 'No packets decoded (maybe not an AFSK 1200 recording)',
        'ja': 'パケットを復調できません（AFSK 1200 の録音ではない可能性）',
        'id': 'Tidak ada paket terdekode (mungkin bukan rekaman AFSK 1200)',
        'es': 'No se decodificó ningún paquete (¿no es una grabación AFSK 1200?)',
    },
    'audioWavFound': {
        'zh': '解出 {n} 条报文', 'zh_TW': '解出 {n} 條報文',
        'en': 'Decoded {n} packet(s)', 'ja': '{n} 件のパケットを復調',
        'id': '{n} paket terdekode', 'es': '{n} paquete(s) decodificado(s)',
    },
    'audioWavWritten': {
        'zh': '已写入 {path}', 'zh_TW': '已寫入 {path}', 'en': 'Written to {path}',
        'ja': '{path} に書き出しました', 'id': 'Ditulis ke {path}',
        'es': 'Guardado en {path}',
    },
    'audioWavFailed': {
        'zh': '文件读写失败：{err}', 'zh_TW': '檔案讀寫失敗：{err}',
        'en': 'File I/O failed: {err}', 'ja': 'ファイル入出力に失敗：{err}',
        'id': 'Gagal baca/tulis berkas: {err}', 'es': 'Fallo de E/S: {err}',
    },
}

# 占位符：写成字符串的用 String，整数用 int（与既有键的写法保持一致）
PLACEHOLDERS = {
    'connConnectingAudio': {'name': 'String'},
    'connAudioConnected': {'rate': 'String'},
    'connRetryAudio': {'seconds': 'int'},
    'connRetryAudioDetail': {'detail': 'String', 'seconds': 'int'},
    'connAudioLinkLost': {'seconds': 'int'},
    'connAudioPositionSent': {'call': 'String'},
    'audioBadFrames': {'n': 'int'},
    'audioWavFound': {'n': 'int'},
    'audioWavWritten': {'path': 'String'},
    'audioWavFailed': {'err': 'String'},
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
ANCHOR = '"codeContributionTranslation"'


def main():
    for lang in LANGS:
        path = os.path.join(ROOT, 'lib/l10n/app_%s.arb' % lang)
        lines = io.open(path, encoding='utf-8').read().split('\n')
        # 幂等：已注入则先移除
        out = []
        for ln in lines:
            stripped = ln.strip()
            if any(stripped.startswith('"%s"' % k) for k in DATA):
                continue
            if any(stripped.startswith('"@%s"' % k) for k in PLACEHOLDERS):
                continue
            out.append(ln)
        lines = out
        idx = None
        for i, ln in enumerate(lines):
            if ln.strip().startswith(ANCHOR):
                idx = i
                break
        assert idx is not None, 'anchor not found in %s' % path
        block = []
        for key, tr in DATA.items():
            val = tr[lang]
            block.append('  "%s": %s,' % (key, json.dumps(val, ensure_ascii=False)))
        for key, ph in PLACEHOLDERS.items():
            block.append('  "@%s": %s,' % (
                key,
                json.dumps({'placeholders': {k: {'type': v} for k, v in ph.items()}},
                           ensure_ascii=False),
            ))
        lines[idx + 1:idx + 1] = block
        io.open(path, 'w', encoding='utf-8').write('\n'.join(lines))
        # 语法自检
        d = json.loads(io.open(path, encoding='utf-8').read())
        n = len([k for k in d if not k.startswith('@')])
        print('%s ok, %d keys (+%d)' % (path, n, len(DATA)))


if __name__ == '__main__':
    main()
