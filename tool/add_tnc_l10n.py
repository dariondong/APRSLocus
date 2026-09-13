#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""向 6 个 ARB 注入 TNC 相关文案键（文本级插入，保持原格式不被重排）。"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# key -> {lang: text}
DATA = {
    # ── 通知栏 ──
    'notifTncConnected': {
        'zh': 'TNC 已连接', 'zh_TW': 'TNC 已連線', 'en': 'TNC connected',
        'ja': 'TNC 接続済み', 'id': 'TNC terhubung', 'es': 'TNC conectado',
    },
    'notifTncDisconnected': {
        'zh': 'TNC 未连接', 'zh_TW': 'TNC 未連線', 'en': 'TNC disconnected',
        'ja': 'TNC 未接続', 'id': 'TNC terputus', 'es': 'TNC desconectado',
    },
    # ── 数据来源 ──
    'dataSourceTitle': {
        'zh': '数据来源', 'zh_TW': '資料來源', 'en': 'Data source',
        'ja': 'データソース', 'id': 'Sumber data', 'es': 'Fuente de datos',
    },
    'dataSourceSubtitle': {
        'zh': '报文从哪里来', 'zh_TW': '報文從哪裡來',
        'en': 'Where packets come from', 'ja': 'パケットの取得元',
        'id': 'Dari mana paket berasal', 'es': 'De dónde vienen los paquetes',
    },
    'dataSourceAprsIs': {
        'zh': 'APRS-IS', 'zh_TW': 'APRS-IS', 'en': 'APRS-IS',
        'ja': 'APRS-IS', 'id': 'APRS-IS', 'es': 'APRS-IS',
    },
    'dataSourceAprsIsDesc': {
        'zh': '通过互联网接入全球 APRS 网络',
        'zh_TW': '透過網際網路接入全球 APRS 網路',
        'en': 'Global APRS network over the internet',
        'ja': 'インターネット経由で世界の APRS 網に接続',
        'id': 'Jaringan APRS global lewat internet',
        'es': 'Red APRS global por internet',
    },
    'dataSourceTnc': {
        'zh': 'TNC', 'zh_TW': 'TNC', 'en': 'TNC',
        'ja': 'TNC', 'id': 'TNC', 'es': 'TNC',
    },
    'dataSourceTncDesc': {
        'zh': '通过蓝牙或串口的 TNC 与电台直接收发',
        'zh_TW': '透過藍牙或串列的 TNC 與電台直接收發',
        'en': 'Send and receive on air through a Bluetooth or serial TNC',
        'ja': 'Bluetooth／シリアルの TNC 経由で無線機から直接送受信',
        'id': 'Kirim dan terima lewat udara via TNC Bluetooth atau serial',
        'es': 'Envía y recibe por radio mediante un TNC Bluetooth o serie',
    },
    'dataSourceSwitchHint': {
        'zh': '切换数据来源会断开当前连接',
        'zh_TW': '切換資料來源會中斷目前連線',
        'en': 'Switching the data source disconnects the current link',
        'ja': 'データソースを切り替えると現在の接続は切断されます',
        'id': 'Mengganti sumber data akan memutus koneksi saat ini',
        'es': 'Cambiar la fuente de datos desconecta el enlace actual',
    },
    # ── TNC 设备绑定 ──
    'tncBindTitle': {
        'zh': '蓝牙 TNC', 'zh_TW': '藍牙 TNC', 'en': 'Bluetooth TNC',
        'ja': 'Bluetooth TNC', 'id': 'TNC Bluetooth', 'es': 'TNC Bluetooth',
    },
    'tncBindSubtitle': {
        'zh': '绑定并连接电台侧的 TNC',
        'zh_TW': '綁定並連接電台端的 TNC',
        'en': 'Bind and connect the TNC on your radio',
        'ja': '無線機側の TNC を登録して接続します',
        'id': 'Pasangkan dan hubungkan TNC di radio Anda',
        'es': 'Empareja y conecta el TNC de tu radio',
    },
    'tncBoundDevice': {
        'zh': '已绑定设备', 'zh_TW': '已綁定裝置', 'en': 'Bound device',
        'ja': '登録済みデバイス', 'id': 'Perangkat terpasang',
        'es': 'Dispositivo emparejado',
    },
    'tncNotBound': {
        'zh': '未绑定设备', 'zh_TW': '未綁定裝置', 'en': 'No bound device',
        'ja': '未登録', 'id': 'Belum ada perangkat',
        'es': 'Sin dispositivo emparejado',
    },
    'tncScanPaired': {
        'zh': '扫描已配对设备', 'zh_TW': '掃描已配對裝置',
        'en': 'Scan paired devices', 'ja': 'ペアリング済みを取得',
        'id': 'Pindai perangkat terpasang',
        'es': 'Buscar dispositivos emparejados',
    },
    'tncNoPaired': {
        'zh': '未找到设备 · 请先在系统蓝牙设置里配对 TNC',
        'zh_TW': '未找到裝置 · 請先在系統藍牙設定裡配對 TNC',
        'en': 'No devices found — pair the TNC in the system Bluetooth settings first',
        'ja': 'デバイスが見つかりません。先にシステムの Bluetooth 設定で TNC をペアリングしてください',
        'id': 'Tidak ada perangkat — pasangkan TNC di pengaturan Bluetooth sistem lebih dulu',
        'es': 'No se encontraron dispositivos: empareja el TNC en los ajustes de Bluetooth del sistema',
    },
    'tncUnbind': {
        'zh': '解除绑定', 'zh_TW': '解除綁定', 'en': 'Unbind',
        'ja': '登録解除', 'id': 'Lepas', 'es': 'Desemparejar',
    },
    'tncConnectAction': {
        'zh': '连接 TNC', 'zh_TW': '連接 TNC', 'en': 'Connect TNC',
        'ja': 'TNC に接続', 'id': 'Hubungkan TNC', 'es': 'Conectar TNC',
    },
    'tncRestart': {
        'zh': '重启链路', 'zh_TW': '重啟鏈路', 'en': 'Restart link',
        'ja': 'リンクを再起動', 'id': 'Mulai ulang tautan',
        'es': 'Reiniciar enlace',
    },
    'tncSupportedNo': {
        'zh': '当前平台暂不支持 TNC 链路',
        'zh_TW': '目前平台暫不支援 TNC 鏈路',
        'en': 'TNC links are not supported on this platform yet',
        'ja': 'このプラットフォームは TNC リンクに未対応です',
        'id': 'Tautan TNC belum didukung di platform ini',
        'es': 'Este sistema aún no admite enlaces TNC',
    },
    'tncNeedPermission': {
        'zh': '需要蓝牙权限，请授权后重试',
        'zh_TW': '需要藍牙權限，請授權後重試',
        'en': 'Bluetooth permission is required — grant it and try again',
        'ja': 'Bluetooth の権限が必要です。許可して再試行してください',
        'id': 'Izin Bluetooth diperlukan — berikan lalu coba lagi',
        'es': 'Se requiere permiso de Bluetooth: concédelo e inténtalo de nuevo',
    },
    'tncOpenFailedHint': {
        'zh': '打开设备失败 · Windows 的 COM 口是独占设备，请确认没有被其他软件占用',
        'zh_TW': '開啟裝置失敗 · Windows 的 COM 埠是獨佔裝置，請確認沒有被其他軟體佔用',
        'en': 'Could not open the device — Windows COM ports are exclusive; make sure no other app holds it',
        'ja': 'デバイスを開けません。Windows の COM ポートは占有型です。他のソフトが使用していないか確認してください',
        'id': 'Gagal membuka perangkat — port COM Windows bersifat eksklusif; pastikan tidak dipakai aplikasi lain',
        'es': 'No se pudo abrir el dispositivo: los puertos COM de Windows son exclusivos; comprueba que ninguna otra app lo use',
    },
    'tncStats': {
        'zh': '收 {rx} 帧 · 发 {tx} 帧', 'zh_TW': '收 {rx} 幀 · 發 {tx} 幀',
        'en': '{rx} frames received · {tx} sent',
        'ja': '受信 {rx} フレーム · 送信 {tx} フレーム',
        'id': '{rx} bingkai diterima · {tx} terkirim',
        'es': '{rx} tramas recibidas · {tx} enviadas',
    },
    'tncLog': {
        'zh': '链路日志', 'zh_TW': '鏈路日誌', 'en': 'Link log',
        'ja': 'リンクログ', 'id': 'Log tautan', 'es': 'Registro del enlace',
    },
    'tncLogEmpty': {
        'zh': '暂无日志', 'zh_TW': '暫無日誌', 'en': 'No log entries yet',
        'ja': 'ログはまだありません', 'id': 'Belum ada log',
        'es': 'Todavía no hay registros',
    },
    # ── KISS 参数 ──
    'kissParamsTitle': {
        'zh': 'KISS 参数', 'zh_TW': 'KISS 參數', 'en': 'KISS parameters',
        'ja': 'KISS パラメータ', 'id': 'Parameter KISS',
        'es': 'Parámetros KISS',
    },
    'kissParamsSubtitle': {
        'zh': '直接下发到 TNC 的链路层参数',
        'zh_TW': '直接下發到 TNC 的鏈路層參數',
        'en': 'Link-layer settings pushed straight to the TNC',
        'ja': 'TNC に直接送るリンク層パラメータ',
        'id': 'Pengaturan lapisan tautan yang dikirim langsung ke TNC',
        'es': 'Ajustes de capa de enlace enviados directamente al TNC',
    },
    'kissTxDelay': {
        'zh': '发射延时 (ms)', 'zh_TW': '發射延時 (ms)', 'en': 'TX delay (ms)',
        'ja': '送信遅延 (ms)', 'id': 'Tunda TX (ms)', 'es': 'Retardo de TX (ms)',
    },
    'kissTxDelayTip': {
        'zh': 'KISS TXDELAY，单位 10ms。发射前留给自己 PTT 建立的时间',
        'zh_TW': 'KISS TXDELAY，單位 10ms。發射前留給自己 PTT 建立的時間',
        'en': 'KISS TXDELAY in 10 ms units — time for your PTT to settle before data',
        'ja': 'KISS TXDELAY（10ms 単位）。データ送出前に PTT が立ち上がるまでの待ち時間',
        'id': 'KISS TXDELAY dalam satuan 10 ms — waktu PTT sebelum data dikirim',
        'es': 'KISS TXDELAY en unidades de 10 ms: tiempo para que el PTT se establezca',
    },
    'kissTxTail': {
        'zh': '发射尾音 (ms)', 'zh_TW': '發射尾音 (ms)', 'en': 'TX tail (ms)',
        'ja': '送信テール (ms)', 'id': 'Ekor TX (ms)', 'es': 'Cola de TX (ms)',
    },
    'kissTxTailTip': {
        'zh': 'KISS TXTAIL，单位 10ms。某些电台需要尾部保持才能收全',
        'zh_TW': 'KISS TXTAIL，單位 10ms。某些電台需要尾部保持才能收全',
        'en': 'KISS TXTAIL in 10 ms units — some radios need the tail to be heard fully',
        'ja': 'KISS TXTAIL（10ms 単位）。無線機によっては末尾の保持が必要',
        'id': 'KISS TXTAIL dalam satuan 10 ms — sebagian radio perlu ekor agar terdengar utuh',
        'es': 'KISS TXTAIL en unidades de 10 ms: algunas radios necesitan la cola para oírse completas',
    },
    'kissPersistence': {
        'zh': '持续度 P', 'zh_TW': '持續度 P', 'en': 'Persistence',
        'ja': 'パーシステンス P', 'id': 'Persistensi', 'es': 'Persistencia',
    },
    'kissPersistenceTip': {
        'zh': 'KISS PERSISTENCE，0-255。越小越礼让，共用信道时能减少碰撞',
        'zh_TW': 'KISS PERSISTENCE，0-255。越小越禮讓，共用信道時能減少碰撞',
        'en': 'KISS PERSISTENCE, 0–255 — lower is more polite and avoids collisions on a shared channel',
        'ja': 'KISS PERSISTENCE（0〜255）。小さいほど譲り合い、共有チャネルの衝突を減らせます',
        'id': 'KISS PERSISTENCE, 0–255 — makin kecil makin sopan dan mengurangi tabrakan di kanal bersama',
        'es': 'KISS PERSISTENCE, 0-255: cuanto menor, más cede y menos colisiones en un canal compartido',
    },
    'kissSlotTime': {
        'zh': '时隙 (ms)', 'zh_TW': '時隙 (ms)', 'en': 'Slot time (ms)',
        'ja': 'スロットタイム (ms)', 'id': 'Waktu slot (ms)',
        'es': 'Tiempo de ranura (ms)',
    },
    'kissSlotTimeTip': {
        'zh': 'KISS SLOTTIME，单位 10ms。与持续度共同决定信道竞争节奏',
        'zh_TW': 'KISS SLOTTIME，單位 10ms。與持續度共同決定信道競爭節奏',
        'en': 'KISS SLOTTIME in 10 ms units — works with persistence to pace channel access',
        'ja': 'KISS SLOTTIME（10ms 単位）。パーシステンスと共にチャネルアクセスを調整します',
        'id': 'KISS SLOTTIME dalam satuan 10 ms — bekerja bersama persistensi mengatur akses kanal',
        'es': 'KISS SLOTTIME en unidades de 10 ms: junto con la persistencia regula el acceso al canal',
    },
    'kissFullDuplex': {
        'zh': '全双工', 'zh_TW': '全雙工', 'en': 'Full duplex',
        'ja': '全二重', 'id': 'Dupleks penuh', 'es': 'Dúplex completo',
    },
    'kissFullDuplexTip': {
        'zh': 'KISS FULLDUPLEX，普通电台必须关闭（同时收发会互相干扰）',
        'zh_TW': 'KISS FULLDUPLEX，一般電台必須關閉（同時收發會互相干擾）',
        'en': 'KISS FULLDUPLEX — leave off for ordinary radios (simultaneous TX/RX interferes)',
        'ja': 'KISS FULLDUPLEX。通常の無線機では必ずオフ（同時送受信は干渉します）',
        'id': 'KISS FULLDUPLEX — matikan untuk radio biasa (TX/RX bersamaan saling mengganggu)',
        'es': 'KISS FULLDUPLEX: déjalo desactivado en radios normales (TX/RX simultáneos interfieren)',
    },
    'kissChannel': {
        'zh': '信道 / KISS 端口', 'zh_TW': '信道 / KISS 埠',
        'en': 'Channel / KISS port', 'ja': 'チャネル / KISS ポート',
        'id': 'Kanal / porta KISS', 'es': 'Canal / puerto KISS',
    },
    'kissChannelTip': {
        'zh': '多信道 TNC 才有多端口，单信道电台保持 0',
        'zh_TW': '多信道 TNC 才有多埠，單信道電台保持 0',
        'en': 'Only multi-channel TNCs have several ports; keep 0 for single-channel radios',
        'ja': 'マルチチャネル TNC のみ複数ポート。単一チャネルの無線機は 0 のまま',
        'id': 'Hanya TNC multikanal punya beberapa port; biarkan 0 untuk radio satu kanal',
        'es': 'Solo los TNC multicanal tienen varios puertos; deja 0 en radios de un canal',
    },
    'kissMaxFrame': {
        'zh': '帧长上限 (字节)', 'zh_TW': '幀長上限 (位元組)',
        'en': 'Max frame size (bytes)', 'ja': '最大フレーム長 (バイト)',
        'id': 'Ukuran bingkai maks (bita)', 'es': 'Tamaño máximo de trama (bytes)',
    },
    'kissMaxFrameTip': {
        'zh': '超过此长度的报文不会发出（1200bd 下 AX.25 单帧约 330 字节）',
        'zh_TW': '超過此長度的報文不會發出（1200bd 下 AX.25 單幀約 330 位元組）',
        'en': 'Longer packets are not sent at all (at 1200 baud an AX.25 frame is ~330 bytes)',
        'ja': 'これを超えるパケットは送信しません（1200bd で AX.25 フレームは約 330 バイト）',
        'id': 'Paket yang lebih panjang tidak dikirim (pada 1200 baud bingkai AX.25 sekitar 330 bita)',
        'es': 'Los paquetes más largos no se envían (a 1200 baudios una trama AX.25 ronda 330 bytes)',
    },
    'kissHardwareCmd': {
        'zh': '厂商命令码', 'zh_TW': '廠商命令碼', 'en': 'Vendor command',
        'ja': 'ベンダーコマンド', 'id': 'Perintah vendor', 'es': 'Comando del fabricante',
    },
    'kissHardwareVal': {
        'zh': '参数值', 'zh_TW': '參數值', 'en': 'Value',
        'ja': '値', 'id': 'Nilai', 'es': 'Valor',
    },
    'kissHardwareTip': {
        'zh': 'KISS SETHARDWARE (0x06)，厂商自定义；-1 表示不下发',
        'zh_TW': 'KISS SETHARDWARE (0x06)，廠商自訂；-1 表示不下發',
        'en': 'KISS SETHARDWARE (0x06), vendor-specific; -1 means do not send',
        'ja': 'KISS SETHARDWARE (0x06)。ベンダー固有。-1 で送信しません',
        'id': 'KISS SETHARDWARE (0x06), khusus vendor; -1 berarti tidak dikirim',
        'es': 'KISS SETHARDWARE (0x06), específico del fabricante; -1 significa no enviar',
    },
    'kissApplyParams': {
        'zh': '下发参数', 'zh_TW': '下發參數', 'en': 'Push parameters',
        'ja': 'パラメータを送信', 'id': 'Kirim parameter',
        'es': 'Enviar parámetros',
    },
    'kissParamsSent': {
        'zh': 'KISS 参数已下发', 'zh_TW': 'KISS 參數已下發',
        'en': 'KISS parameters sent', 'ja': 'KISS パラメータを送信しました',
        'id': 'Parameter KISS terkirim', 'es': 'Parámetros KISS enviados',
    },
    'kissBackToCommand': {
        'zh': '回到 TNC 命令模式', 'zh_TW': '回到 TNC 命令模式',
        'en': 'Return to TNC command mode', 'ja': 'TNC コマンドモードへ戻る',
        'id': 'Kembali ke mode perintah TNC',
        'es': 'Volver al modo de comandos del TNC',
    },
    'kissBackToCommandTip': {
        'zh': '发送 RETURN (0x0F)。多数 KISS TNC 会就此停止转发，需重启链路才恢复',
        'zh_TW': '發送 RETURN (0x0F)。多數 KISS TNC 會就此停止轉發，需重啟鏈路才恢復',
        'en': 'Sends RETURN (0x0F). Most KISS TNCs stop forwarding until the link is restarted',
        'ja': 'RETURN (0x0F) を送ります。多くの KISS TNC は転送を停止し、リンク再起動が必要です',
        'id': 'Mengirim RETURN (0x0F). Sebagian besar TNC KISS berhenti meneruskan sampai tautan dimulai ulang',
        'es': 'Envía RETURN (0x0F). La mayoría de los TNC KISS dejan de reenviar hasta reiniciar el enlace',
    },
    'kissRfPath': {
        'zh': '射频中继路径', 'zh_TW': '射頻中繼路徑', 'en': 'RF digipeater path',
        'ja': 'RF デジピータパス', 'id': 'Jalur digipeater RF',
        'es': 'Ruta de digipeadores RF',
    },
    'kissRfPathTip': {
        'zh': '射频上使用的中继，如 WIDE1-1,WIDE2-1；留空则不指定',
        'zh_TW': '射頻上使用的中繼，如 WIDE1-1,WIDE2-1；留空則不指定',
        'en': 'Digipeaters used on air, e.g. WIDE1-1,WIDE2-1; leave empty for none',
        'ja': 'オンエアで使うデジピータ（例 WIDE1-1,WIDE2-1）。空欄なら指定しません',
        'id': 'Digipeater yang dipakai di udara, mis. WIDE1-1,WIDE2-1; kosongkan bila tidak perlu',
        'es': 'Digipeadores usados en el aire, p. ej. WIDE1-1,WIDE2-1; déjalo vacío para ninguno',
    },
    'kissRfBeacon': {
        'zh': '允许射频信标', 'zh_TW': '允許射頻信標', 'en': 'Allow RF beaconing',
        'ja': 'RF ビーコンを許可', 'id': 'Izinkan beacon RF',
        'es': 'Permitir balizas por RF',
    },
    'kissRfBeaconTip': {
        'zh': '打开后才会在射频上定时发射位置。发射需以自己的呼号并在执照范围内操作',
        'zh_TW': '打開後才會在射頻上定時發射位置。發射需以自己的呼號並在執照範圍內操作',
        'en': 'Only then will positions be transmitted on air. Transmitting requires your own licence and callsign',
        'ja': 'オンにすると位置を定期的に送信します。送信はご自身の免許とコールサインで行ってください',
        'id': 'Hanya setelah aktif posisi dikirim lewat udara. Memancar memerlukan lisensi dan tanda panggil Anda',
        'es': 'Solo entonces se transmitirán posiciones por radio. Transmitir requiere tu licencia e indicativo',
    },
    'kissAutoAck': {
        'zh': '自动回复 ACK', 'zh_TW': '自動回覆 ACK', 'en': 'Auto-acknowledge',
        'ja': '自動 ACK', 'id': 'ACK otomatis', 'es': 'Confirmar automáticamente',
    },
    'kissAutoAckTip': {
        'zh': '关闭后不回应收到的消息回执，可减少射频占用',
        'zh_TW': '關閉後不回覆收到的訊息回執，可減少射頻佔用',
        'en': 'When off, incoming messages are not acknowledged — keeps the channel quieter',
        'ja': 'オフにすると受信メッセージに ACK を返さず、チャネルの占有を減らせます',
        'id': 'Jika mati, pesan masuk tidak di-ACK — kanal lebih sepi',
        'es': 'Si se desactiva, los mensajes entrantes no se confirman: el canal queda más libre',
    },
    'kissAutoReconnect': {
        'zh': '断开后自动重连', 'zh_TW': '斷開後自動重連',
        'en': 'Reconnect automatically', 'ja': '切断後に自動再接続',
        'id': 'Sambung ulang otomatis', 'es': 'Reconectar automáticamente',
    },
    'kissNeedConnected': {
        'zh': '请先连接 TNC', 'zh_TW': '請先連接 TNC', 'en': 'Connect the TNC first',
        'ja': '先に TNC に接続してください', 'id': 'Hubungkan TNC lebih dulu',
        'es': 'Conecta primero el TNC',
    },
    'tncSwitchOn': {
        'zh': '已开启', 'zh_TW': '已開啟', 'en': 'On',
        'ja': 'オン', 'id': 'Aktif', 'es': 'Activado',
    },
    'tncSwitchOff': {
        'zh': '已关闭', 'zh_TW': '已關閉', 'en': 'Off',
        'ja': 'オフ', 'id': 'Nonaktif', 'es': 'Desactivado',
    },
    # ── 连接页适配 ──
    'connTncSourceHint': {
        'zh': 'TNC 模式下不使用服务器与过滤器，相关设置已停用',
        'zh_TW': 'TNC 模式下不使用伺服器與過濾器，相關設定已停用',
        'en': 'TNC mode does not use a server or filters, so those settings are disabled',
        'ja': 'TNC モードではサーバーとフィルタを使わないため、該当設定は無効です',
        'id': 'Mode TNC tidak memakai server atau filter, jadi pengaturan itu dinonaktifkan',
        'es': 'El modo TNC no usa servidor ni filtros, así que esos ajustes están desactivados',
    },
    'connectTncBar': {
        'zh': '点「连接」建立 TNC 链路',
        'zh_TW': '點「連接」建立 TNC 鏈路',
        'en': 'Tap Connect to open the TNC link',
        'ja': '「接続」で TNC リンクを開きます',
        'id': 'Ketuk Hubungkan untuk membuka tautan TNC',
        'es': 'Toca Conectar para abrir el enlace TNC',
    },
    'connectingToTnc': {
        'zh': '正在连接 TNC · {name}',
        'zh_TW': '正在連接 TNC · {name}',
        'en': 'Connecting TNC · {name}',
        'ja': 'TNC に接続中 · {name}',
        'id': 'Menghubungkan TNC · {name}',
        'es': 'Conectando TNC · {name}',
    },
    # ── 消息页限制 ──
    'tncMsgTitle': {
        'zh': '射频（TNC）模式', 'zh_TW': '射頻（TNC）模式',
        'en': 'Radio (TNC) mode', 'ja': 'RF（TNC）モード',
        'id': 'Mode radio (TNC)', 'es': 'Modo radio (TNC)',
    },
    'tncMsgDesc': {
        'zh': '射频信道是共享资源，消息能力相应受限',
        'zh_TW': '射頻信道是共享資源，訊息能力相應受限',
        'en': 'The radio channel is shared, so messaging is limited accordingly',
        'ja': 'RF チャネルは共有資源のため、メッセージ機能は制限されます',
        'id': 'Kanal radio dipakai bersama, jadi perpesanan dibatasi',
        'es': 'El canal de radio es compartido, por lo que la mensajería está limitada',
    },
    'tncGroupDisabled': {
        'zh': '射频模式不支持群聊广播',
        'zh_TW': '射頻模式不支援群聊廣播',
        'en': 'Group broadcasts are unavailable in radio mode',
        'ja': 'RF モードではグループ配信は利用できません',
        'id': 'Siaran grup tidak tersedia di mode radio',
        'es': 'Las difusiones de grupo no están disponibles en modo radio',
    },
    'tncMsgLimitHint': {
        'zh': '单条限 {n} 字符（APRS 消息规范）',
        'zh_TW': '單條限 {n} 字元（APRS 訊息規範）',
        'en': '{n} characters per message (APRS spec)',
        'ja': '1 通あたり {n} 文字（APRS 仕様）',
        'id': '{n} karakter per pesan (spesifikasi APRS)',
        'es': '{n} caracteres por mensaje (norma APRS)',
    },
    'tncMsgTooLong': {
        'zh': '超出射频模式单条消息长度上限',
        'zh_TW': '超出射頻模式單條訊息長度上限',
        'en': 'Exceeds the message length limit for radio mode',
        'ja': 'RF モードの 1 通あたりの文字数上限を超えています',
        'id': 'Melebihi batas panjang pesan untuk mode radio',
        'es': 'Supera el límite de longitud de mensaje en modo radio',
    },
}

PLACEHOLDERS = {
    'tncStats': {'rx': 'String', 'tx': 'String'},
    'connectingToTnc': {'name': 'String'},
    'tncMsgLimitHint': {'n': 'String'},
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
