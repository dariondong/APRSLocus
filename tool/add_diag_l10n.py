#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""向 6 个 ARB 注入「链路自检（TNC / 音频）」相关文案键。

做法与 tool/add_tnc_l10n.py、tool/add_audio_l10n.py 一致：幂等、按锚点整块
插入、写完用 json 解析自检。通用文案（复制日志/暂无日志/重启链路等）复用既有键，
不在这里重复定义。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATA = {
    # ── 自检卡片 ──
    'diagTitle': {
        'zh': '链路自检', 'zh_TW': '鏈路自檢', 'en': 'Link self-test',
        'ja': 'リンク自己診断', 'id': 'Uji mandiri tautan',
        'es': 'Autodiagnóstico del enlace',
    },
    'diagSubtitle': {
        'zh': '逐层确认协议、权限、设备到底哪一环有问题',
        'zh_TW': '逐層確認協定、權限、裝置到底哪一環有問題',
        'en': 'Checks protocol, permissions and devices layer by layer',
        'ja': 'プロトコル・権限・デバイスのどこに問題があるか順に確認します',
        'id': 'Memeriksa protokol, izin, dan perangkat lapis demi lapis',
        'es': 'Comprueba protocolo, permisos y dispositivos capa por capa',
    },
    'diagRun': {
        'zh': '开始自检', 'zh_TW': '開始自檢', 'en': 'Run self-test',
        'ja': '自己診断を実行', 'id': 'Jalankan uji', 'es': 'Ejecutar prueba',
    },
    'diagRunning': {
        'zh': '自检中…', 'zh_TW': '自檢中…', 'en': 'Testing…',
        'ja': '診断中…', 'id': 'Menguji…', 'es': 'Probando…',
    },
    'diagPassed': {
        'zh': '通过 {n} 项', 'zh_TW': '通過 {n} 項', 'en': '{n} passed',
        'ja': '{n} 項目合格', 'id': '{n} lulus', 'es': '{n} correctas',
    },
    'diagFailed': {
        'zh': '失败 {n} 项', 'zh_TW': '失敗 {n} 項', 'en': '{n} failed',
        'ja': '{n} 項目失敗', 'id': '{n} gagal', 'es': '{n} fallidas',
    },
    'diagHint': {
        'zh': '协议回路不接电台也能跑：先确认软件层没问题，再去查设备与接线',
        'zh_TW': '協定迴路不接電台也能跑：先確認軟體層沒問題，再去查裝置與接線',
        'en': 'Protocol loops run without a radio: rule out software first, then check devices and wiring',
        'ja': 'プロトコル回路は無線機なしでも実行できます。まずソフト側を切り分け、次にデバイスと配線を確認',
        'id': 'Uji protokol bisa jalan tanpa radio: pastikan perangkat lunak dulu, lalu cek perangkat dan kabel',
        'es': 'Los bucles de protocolo funcionan sin radio: descarta el software y luego revisa dispositivos y cableado',
    },
    'diagTncSection': {
        'zh': 'TNC（KISS / AX.25）', 'zh_TW': 'TNC（KISS / AX.25）',
        'en': 'TNC (KISS / AX.25)', 'ja': 'TNC（KISS / AX.25）',
        'id': 'TNC (KISS / AX.25)', 'es': 'TNC (KISS / AX.25)',
    },
    'diagAudioSection': {
        'zh': '音频（AFSK 1200）', 'zh_TW': '音訊（AFSK 1200）',
        'en': 'Audio (AFSK 1200)', 'ja': 'オーディオ（AFSK 1200）',
        'id': 'Audio (AFSK 1200)', 'es': 'Audio (AFSK 1200)',
    },
    'diagKissEscape': {
        'zh': 'KISS 转义', 'zh_TW': 'KISS 跳脫', 'en': 'KISS escaping',
        'ja': 'KISS エスケープ', 'id': 'Escape KISS', 'es': 'Escape KISS',
    },
    'diagKissEscapeFail': {
        'zh': 'KISS 转义还原失败（软件层问题，换设备也没用）',
        'zh_TW': 'KISS 跳脫還原失敗（軟體層問題，換裝置也沒用）',
        'en': 'KISS unescaping failed (software issue — changing hardware will not help)',
        'ja': 'KISS エスケープの復元に失敗（ソフト側の問題。デバイスを替えても解決しません）',
        'id': 'Gagal membalik escape KISS (masalah perangkat lunak — ganti perangkat tidak membantu)',
        'es': 'Fallo al deshacer el escape KISS (problema de software: cambiar el dispositivo no ayuda)',
    },
    'diagAx25': {
        'zh': 'AX.25 帧编解码', 'zh_TW': 'AX.25 幀編解碼', 'en': 'AX.25 framing',
        'ja': 'AX.25 フレーム', 'id': 'Pembingkaian AX.25',
        'es': 'Tramado AX.25',
    },
    'diagAx25Fail': {
        'zh': 'AX.25 编码失败（报文格式不合法）',
        'zh_TW': 'AX.25 編碼失敗（報文格式不合法）',
        'en': 'AX.25 encoding failed (malformed packet)',
        'ja': 'AX.25 符号化に失敗（パケット形式が不正）',
        'id': 'Pengodean AX.25 gagal (format paket salah)',
        'es': 'Fallo de codificación AX.25 (paquete mal formado)',
    },
    'diagAx25Mismatch': {
        'zh': 'AX.25 回路不一致，解回：{got}',
        'zh_TW': 'AX.25 迴路不一致，解回：{got}',
        'en': 'AX.25 round-trip mismatch, decoded: {got}',
        'ja': 'AX.25 の往復が不一致。復号結果：{got}',
        'id': 'Hasil bolak-balik AX.25 tidak cocok: {got}',
        'es': 'El ida y vuelta AX.25 no coincide: {got}',
    },
    'diagFcs': {
        'zh': 'FCS 校验', 'zh_TW': 'FCS 校驗', 'en': 'FCS check',
        'ja': 'FCS 検査', 'id': 'Pemeriksaan FCS', 'es': 'Comprobación FCS',
    },
    'diagFcsFail': {
        'zh': 'FCS 校验异常（改动一个字节本应被拒收）',
        'zh_TW': 'FCS 校驗異常（改動一個位元組本應被拒收）',
        'en': 'FCS check is wrong (a one-byte change must be rejected)',
        'ja': 'FCS 検査が異常（1 バイト変更は拒否されるべきです）',
        'id': 'Pemeriksaan FCS salah (perubahan satu byte harus ditolak)',
        'es': 'La comprobación FCS es incorrecta (un cambio de un byte debe rechazarse)',
    },
    'diagTncLoopback': {
        'zh': 'TNC 协议回路', 'zh_TW': 'TNC 協定迴路', 'en': 'TNC protocol loop',
        'ja': 'TNC プロトコル回路', 'id': 'Loop protokol TNC',
        'es': 'Bucle de protocolo TNC',
    },
    'diagTncLoopbackOk': {
        'zh': 'KISS/AX.25 编解码往返一致（{len} 字节）',
        'zh_TW': 'KISS/AX.25 編解碼往返一致（{len} 位元組）',
        'en': 'KISS/AX.25 round-trip identical ({len} bytes)',
        'ja': 'KISS/AX.25 の往復が一致（{len} バイト）',
        'id': 'Bolak-balik KISS/AX.25 identik ({len} byte)',
        'es': 'Ida y vuelta KISS/AX.25 idéntico ({len} bytes)',
    },
    'diagAfskLoopback': {
        'zh': 'AFSK 调制解调回路', 'zh_TW': 'AFSK 調變解調迴路',
        'en': 'AFSK modem loop', 'ja': 'AFSK 変復調回路',
        'id': 'Loop modem AFSK', 'es': 'Bucle de módem AFSK',
    },
    'diagAfskLoopbackOk': {
        'zh': '调制→解调一致（{samples} 采样 @{rate}Hz）',
        'zh_TW': '調變→解調一致（{samples} 取樣 @{rate}Hz）',
        'en': 'Modulate → demodulate identical ({samples} samples @{rate}Hz)',
        'ja': '変調→復調が一致（{samples} サンプル @{rate}Hz）',
        'id': 'Modulasi → demodulasi identik ({samples} sampel @{rate}Hz)',
        'es': 'Modular → demodular idéntico ({samples} muestras @{rate}Hz)',
    },
    'diagAfskLoopbackFail': {
        'zh': '解出 {n} 帧（应为 1 帧）', 'zh_TW': '解出 {n} 幀（應為 1 幀）',
        'en': 'Decoded {n} frame(s) — expected 1',
        'ja': '{n} フレームを復調（期待値は 1）',
        'id': '{n} bingkai terdekode — seharusnya 1',
        'es': '{n} trama(s) decodificada(s): se esperaba 1',
    },
    'diagAfskLevelFail': {
        'zh': '波形幅度过低（调制结果接近静音）',
        'zh_TW': '波形幅度過低（調變結果接近靜音）',
        'en': 'Waveform level too low (output is nearly silent)',
        'ja': '波形の振幅が低すぎます（ほぼ無音）',
        'id': 'Level gelombang terlalu rendah (hampir senyap)',
        'es': 'Nivel de onda demasiado bajo (casi silencio)',
    },
    'diagPlatform': {
        'zh': '平台能力', 'zh_TW': '平台能力', 'en': 'Platform support',
        'ja': 'プラットフォーム対応', 'id': 'Dukungan platform',
        'es': 'Compatibilidad de plataforma',
    },
    'diagPlatformOk': {
        'zh': '可用 · 后端 {name}', 'zh_TW': '可用 · 後端 {name}',
        'en': 'Available · backend {name}', 'ja': '利用可能 · バックエンド {name}',
        'id': 'Tersedia · backend {name}', 'es': 'Disponible · motor {name}',
    },
    'diagTncPlatformNo': {
        'zh': '当前平台不支持 TNC 链路', 'zh_TW': '目前平台不支援 TNC 鏈路',
        'en': 'TNC links are not supported on this platform',
        'ja': 'このプラットフォームは TNC リンクに未対応です',
        'id': 'Tautan TNC tidak didukung di platform ini',
        'es': 'Este sistema no admite enlaces TNC',
    },
    'diagAudioPlatformWarn': {
        'zh': '不支持实时音频 · 仍可用 WAV 文件模式',
        'zh_TW': '不支援即時音訊 · 仍可用 WAV 檔案模式',
        'en': 'No real-time audio — WAV file mode is still available',
        'ja': 'リアルタイム音声は非対応 · WAV ファイル方式は利用できます',
        'id': 'Tanpa audio waktu-nyata — mode berkas WAV tetap tersedia',
        'es': 'Sin audio en tiempo real: el modo WAV sigue disponible',
    },
    'diagNoRealtime': {
        'zh': '非实时', 'zh_TW': '非即時', 'en': 'not real-time',
        'ja': '非リアルタイム', 'id': 'bukan waktu-nyata', 'es': 'no en tiempo real',
    },
    'diagPermission': {
        'zh': '录音权限', 'zh_TW': '錄音權限', 'en': 'Mic permission',
        'ja': '録音権限', 'id': 'Izin mikrofon', 'es': 'Permiso de micrófono',
    },
    'diagPermissionOk': {
        'zh': '已授权', 'zh_TW': '已授權', 'en': 'Granted',
        'ja': '許可済み', 'id': 'Diberikan', 'es': 'Concedido',
    },
    'diagSkipped': {
        'zh': '已跳过（平台不支持）', 'zh_TW': '已跳過（平台不支援）',
        'en': 'Skipped (unsupported platform)',
        'ja': 'スキップ（未対応プラットフォーム）',
        'id': 'Dilewati (platform tidak didukung)',
        'es': 'Omitido (plataforma no compatible)',
    },
    'diagCapture': {
        'zh': '音频采集', 'zh_TW': '音訊擷取', 'en': 'Audio capture',
        'ja': 'オーディオ入力', 'id': 'Penangkapan audio', 'es': 'Captura de audio',
    },
    'diagCaptureOk': {
        'zh': '收到 {bytes} 字节 @{rate}Hz', 'zh_TW': '收到 {bytes} 位元組 @{rate}Hz',
        'en': 'Received {bytes} bytes @{rate}Hz',
        'ja': '{bytes} バイト受信 @{rate}Hz',
        'id': 'Menerima {bytes} byte @{rate}Hz',
        'es': 'Recibidos {bytes} bytes @{rate}Hz',
    },
    'diagCaptureNoData': {
        'zh': '没有收到任何音频数据 · 检查输入设备与权限',
        'zh_TW': '沒有收到任何音訊資料 · 檢查輸入裝置與權限',
        'en': 'No audio data received — check the input device and permissions',
        'ja': '音声データが届きません。入力デバイスと権限を確認してください',
        'id': 'Tidak ada data audio — periksa perangkat masukan dan izin',
        'es': 'No se recibieron datos de audio: revisa el dispositivo de entrada y los permisos',
    },
    'diagCaptureFailed': {
        'zh': '打开采集失败：{err}', 'zh_TW': '開啟擷取失敗：{err}',
        'en': 'Could not start capture: {err}',
        'ja': '入力を開始できません：{err}',
        'id': 'Gagal memulai penangkapan: {err}',
        'es': 'No se pudo iniciar la captura: {err}',
    },
    'diagSpeaker': {
        'zh': '扬声器输出', 'zh_TW': '揚聲器輸出', 'en': 'Speaker output',
        'ja': 'スピーカー出力', 'id': 'Keluaran speaker', 'es': 'Salida de altavoz',
    },
    'diagSpeakerOk': {
        'zh': '测试音已播放', 'zh_TW': '測試音已播放', 'en': 'Test tone played',
        'ja': 'テスト音を再生しました', 'id': 'Nada uji diputar',
        'es': 'Tono de prueba reproducido',
    },
    'diagSpeakerFail': {
        'zh': '播放失败：{err}', 'zh_TW': '播放失敗：{err}',
        'en': 'Playback failed: {err}', 'ja': '再生に失敗：{err}',
        'id': 'Pemutaran gagal: {err}', 'es': 'Fallo de reproducción: {err}',
    },
    'diagFileIo': {
        'zh': 'WAV 文件读写', 'zh_TW': 'WAV 檔案讀寫', 'en': 'WAV file I/O',
        'ja': 'WAV ファイル入出力', 'id': 'I/O berkas WAV', 'es': 'E/S de archivo WAV',
    },
    'diagFileIoOk': {
        'zh': '写入→读出→解调一致 @{rate}Hz',
        'zh_TW': '寫入→讀出→解調一致 @{rate}Hz',
        'en': 'Write → read → decode identical @{rate}Hz',
        'ja': '書き込み→読み出し→復調が一致 @{rate}Hz',
        'id': 'Tulis → baca → dekode identik @{rate}Hz',
        'es': 'Escritura → lectura → decodificación idénticas @{rate}Hz',
    },
    'diagFileWriteFail': {
        'zh': '文件写入失败：{err}', 'zh_TW': '檔案寫入失敗：{err}',
        'en': 'File write failed: {err}', 'ja': 'ファイル書き込みに失敗：{err}',
        'id': 'Gagal menulis berkas: {err}', 'es': 'Fallo de escritura: {err}',
    },
    'diagFileReadFail': {
        'zh': '文件读取失败', 'zh_TW': '檔案讀取失敗', 'en': 'File read failed',
        'ja': 'ファイル読み出しに失敗', 'id': 'Gagal membaca berkas',
        'es': 'Fallo de lectura del archivo',
    },
    'diagFileDecodeFail': {
        'zh': '文件里的音频解不出报文（可能不是 AFSK 1200 录音）',
        'zh_TW': '檔案裡的音訊解不出報文（可能不是 AFSK 1200 錄音）',
        'en': 'No packet decoded from the file (maybe not an AFSK 1200 recording)',
        'ja': 'ファイル内の音声からパケットを復調できません（AFSK 1200 の録音ではない可能性）',
        'id': 'Tidak ada paket terdekode dari berkas (mungkin bukan rekaman AFSK 1200)',
        'es': 'No se decodificó ningún paquete del archivo (¿no es una grabación AFSK 1200?)',
    },
    'connAudioSourceHint': {
        'zh': '音频模式下不使用服务器、过滤器与 KISS 参数',
        'zh_TW': '音訊模式下不使用伺服器、過濾器與 KISS 參數',
        'en': 'Audio mode does not use the server, filters or KISS settings',
        'ja': 'オーディオモードではサーバー・フィルタ・KISS 設定は使いません',
        'id': 'Mode audio tidak memakai server, filter, atau setelan KISS',
        'es': 'El modo de audio no usa servidor, filtros ni ajustes KISS',
    },
    # ── 测试发射 ──
    'testTxTitle': {
        'zh': '测试发射', 'zh_TW': '測試發射', 'en': 'Test transmit',
        'ja': 'テスト送信', 'id': 'Uji pancar', 'es': 'Transmisión de prueba',
    },
    'testTxDesc': {
        'zh': '发一条状态报文，验证链路真的通到空中',
        'zh_TW': '發一條狀態報文，驗證鏈路真的通到空中',
        'en': 'Sends a status packet to prove the link really reaches the air',
        'ja': 'ステータスパケットを送信し、実際に電波に出るか確認します',
        'id': 'Mengirim paket status untuk membuktikan tautan benar-benar ke udara',
        'es': 'Envía un paquete de estado para comprobar que el enlace llega al aire',
    },
    'testTxAction': {
        'zh': '发射测试帧', 'zh_TW': '發射測試幀', 'en': 'Transmit test frame',
        'ja': 'テストフレームを送信', 'id': 'Pancarkan bingkai uji',
        'es': 'Transmitir trama de prueba',
    },
    'testTxSent': {
        'zh': '测试帧已交给链路', 'zh_TW': '測試幀已交給鏈路',
        'en': 'Test frame handed to the link', 'ja': 'テストフレームをリンクに渡しました',
        'id': 'Bingkai uji diberikan ke tautan',
        'es': 'Trama de prueba entregada al enlace',
    },
    'testTxFail': {
        'zh': '测试帧发送失败：{err}', 'zh_TW': '測試幀發送失敗：{err}',
        'en': 'Test frame failed: {err}', 'ja': 'テストフレーム送信に失敗：{err}',
        'id': 'Bingkai uji gagal: {err}', 'es': 'Fallo de la trama de prueba: {err}',
    },
    'testTxNeedsConnect': {
        'zh': '请先连接链路', 'zh_TW': '請先連接鏈路', 'en': 'Connect the link first',
        'ja': '先にリンクを接続してください', 'id': 'Hubungkan tautan dulu',
        'es': 'Conecta primero el enlace',
    },
    'testTxHint': {
        'zh': '这是**真实发射**（状态报文，不含坐标）。射频发射请确认在自己的呼号与执照范围内',
        'zh_TW': '這是**真實發射**（狀態報文，不含座標）。射頻發射請確認在自己的呼號與執照範圍內',
        'en': 'This **really transmits** (a status packet, no coordinates). Make sure you are operating within your licence and callsign',
        'ja': 'これは**実際の送信**です（ステータスパケット、位置情報なし）。自分のコールサインと免許の範囲内で運用してください',
        'id': 'Ini **benar-benar memancar** (paket status, tanpa koordinat). Pastikan sesuai lisensi dan tanda panggil Anda',
        'es': 'Esto **transmite de verdad** (paquete de estado, sin coordenadas). Asegúrate de operar dentro de tu licencia e indicativo',
    },
    # ── 音频页 ──
    'audioStatsTitle': {
        'zh': '音频统计', 'zh_TW': '音訊統計', 'en': 'Audio statistics',
        'ja': 'オーディオ統計', 'id': 'Statistik audio', 'es': 'Estadísticas de audio',
    },
    'audioStatRx': {
        'zh': '收 {n} 帧', 'zh_TW': '收 {n} 幀', 'en': '{n} frames received',
        'ja': '受信 {n} フレーム', 'id': '{n} bingkai diterima',
        'es': '{n} tramas recibidas',
    },
    'audioStatTx': {
        'zh': '发 {n} 帧', 'zh_TW': '發 {n} 幀', 'en': '{n} frames sent',
        'ja': '送信 {n} フレーム', 'id': '{n} bingkai terkirim',
        'es': '{n} tramas enviadas',
    },
    'audioStatDrop': {
        'zh': '发射期间丢弃 {n} 字节', 'zh_TW': '發射期間丟棄 {n} 位元組',
        'en': '{n} bytes dropped while transmitting',
        'ja': '送信中に {n} バイト破棄', 'id': '{n} byte dibuang saat memancar',
        'es': '{n} bytes descartados durante la transmisión',
    },
    'audioRestart': {
        'zh': '重启音频链路', 'zh_TW': '重啟音訊鏈路', 'en': 'Restart audio link',
        'ja': 'オーディオリンクを再起動', 'id': 'Mulai ulang tautan audio',
        'es': 'Reiniciar enlace de audio',
    },
    'audioTxDisabled': {
        'zh': '「允许发射」已关闭，仅接收', 'zh_TW': '「允許發射」已關閉，僅接收',
        'en': '"Allow transmit" is off — receiving only',
        'ja': '「送信を許可」がオフ — 受信のみ',
        'id': '"Izinkan pancar" mati — hanya menerima',
        'es': '"Permitir transmisión" desactivado: solo recepción',
    },
  'audioLoopbackHint': {
        'zh': '自检会真的做一次调制→解调；提示「发射期间丢弃」属正常半双工行为',
        'zh_TW': '自檢會真的做一次調變→解調；提示「發射期間丟棄」屬正常半雙工行為',
        'en': 'The self-test really modulates and demodulates; "dropped while transmitting" is normal half-duplex behaviour',
        'ja': '自己診断は実際に変調→復調を行います。「送信中に破棄」は半二重として正常です',
        'id': 'Uji mandiri benar-benar memodulasi lalu mendemodulasi; "dibuang saat memancar" normal pada half-duplex',
        'es': 'La prueba modula y demodula de verdad; "descartados durante la transmisión" es normal en semidúplex',
    },
}

PLACEHOLDERS = {
    'diagPassed': {'n': 'int'},
    'diagFailed': {'n': 'int'},
    'diagAx25Mismatch': {'got': 'String'},
    'diagTncLoopbackOk': {'len': 'int'},
    'diagAfskLoopbackOk': {'samples': 'int', 'rate': 'int'},
    'diagAfskLoopbackFail': {'n': 'int'},
    'diagPlatformOk': {'name': 'String'},
    'diagCaptureOk': {'bytes': 'int', 'rate': 'int'},
    'diagCaptureFailed': {'err': 'String'},
    'diagSpeakerFail': {'err': 'String'},
    'diagFileIoOk': {'rate': 'int'},
    'diagFileWriteFail': {'err': 'String'},
    'testTxFail': {'err': 'String'},
    'audioStatRx': {'n': 'int'},
    'audioStatTx': {'n': 'int'},
    'audioStatDrop': {'n': 'int'},
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
ANCHOR = '"codeContributionTranslation"'


def main():
    for lang in LANGS:
        path = os.path.join(ROOT, 'lib/l10n/app_%s.arb' % lang)
        lines = io.open(path, encoding='utf-8').read().split('\n')
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
            block.append('  "%s": %s,' % (key, json.dumps(tr[lang], ensure_ascii=False)))
        for key, ph in PLACEHOLDERS.items():
            block.append('  "@%s": %s,' % (
                key,
                json.dumps({'placeholders': {k: {'type': v} for k, v in ph.items()}},
                           ensure_ascii=False),
            ))
        lines[idx + 1:idx + 1] = block
        io.open(path, 'w', encoding='utf-8').write('\n'.join(lines))
        d = json.loads(io.open(path, encoding='utf-8').read())
        n = len([k for k in d if not k.startswith('@')])
        print('%s ok, %d keys (+%d)' % (path, n, len(DATA)))


if __name__ == '__main__':
    main()
