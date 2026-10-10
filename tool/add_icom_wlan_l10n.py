#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把「WLAN 电台直连（Icom LAN）」整块的写死中文补上 6 语言 l10n。

## 为什么需要它

`ic705_device_page.dart` 与 `settings_pages.dart` / `home_page.dart` 里的
WLAN/Icom 直连文案当初是直接写死中文的（该功能先中文上线），只补了少数
`icomLan*` 键。结果切到英/日/西/印尼语时，这一整页仍然是中文 —— 用户报
「部分内容没有国际化」指的就是这里。设备型号的 displayName / description
同样是中文（在网络参数卡里直接显示）。

## 覆盖范围

  * 设备页 `ic705_device_page.dart`：标题副标题、五张卡片的标题/副标题/提示、
    联网指引四步、链路阶段四态、通信日志卡；
  * 设置页 `settings_pages.dart`：音频卡里的 WLAN 标题与「电台地址」行；
  * 首页 `home_page.dart`：连接横幅的「连接 / 正在连接 / 描述」三处；
  * 型号预置 `WlanRadioModel` 的 displayName / description；
  * 顺带：更新页 `assetNameFor` 的安装包回退名，以及关于页 BA3RZL 的
    「养生」小字备注。

## 产物

arb（6 语言，真源）+ 抽象类 + 6 个 gen-l10n 产物 —— 与 `add_l10n_keys.py`
同一套路数。本机不能跑 gen-l10n，产物必须一起改（见 check_l10n_sync.py）。

用法：python3 tool/add_icom_wlan_l10n.py
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {l: i for i, l in enumerate(LANGS)}
CLASSES = {
    'zh': 'AppLocalizationsZh', 'zh_TW': 'AppLocalizationsZhTw',
    'en': 'AppLocalizationsEn', 'ja': 'AppLocalizationsJa',
    'es': 'AppLocalizationsEs', 'id': 'AppLocalizationsId',
}

# key → (zh, zh_TW, en, ja, es, id)
DATA = {
    'icomTitleSubtitle': (
        '局域网直连 Icom 电台（IC-705 / IC-9700 / IC-7610 / IC-905），收发 12 kHz PCM 音频与 CI-V 控制',
        '區域網路直連 Icom 電台（IC-705 / IC-9700 / IC-7610 / IC-905），收發 12 kHz PCM 音訊與 CI-V 控制',
        'Direct Icom LAN radio (IC-705 / IC-9700 / IC-7610 / IC-905): 12 kHz PCM audio and CI-V control',
        'Icom 無線機へ LAN 直結（IC-705 / IC-9700 / IC-7610 / IC-905）。12 kHz PCM 音声と CI-V 制御',
        'Radio Icom por LAN directa (IC-705 / IC-9700 / IC-7610 / IC-905): audio PCM de 12 kHz y control CI-V',
        'Radio Icom via LAN langsung (IC-705 / IC-9700 / IC-7610 / IC-905): audio PCM 12 kHz dan kontrol CI-V',
    ),
    'icomLinkStatusTitle': (
        '电台链路状态', '電台鏈路狀態', 'Radio link status', '無線機リンク状態',
        'Estado del enlace', 'Status tautan radio',
    ),
    'icomLinkConnected': (
        '已与 {model} 建立局域网直连', '已與 {model} 建立區域網路直連',
        'LAN link established with {model}', '{model} と LAN 直結しました',
        'Enlace LAN establecido con {model}', 'Tautan LAN terjalin dengan {model}',
    ),
    'icomLinkHandshaking': (
        '未连接或正在握手', '未連線或正在握手', 'Not connected or handshaking',
        '未接続、またはハンドシェイク中', 'Sin conexión o negociando',
        'Belum tersambung atau menjalin',
    ),
    'icomBindHint': (
        '开启后，APRS 音频收发数据源将直接绑定至 {model} 局域网直连',
        '開啟後，APRS 音訊收發資料來源將直接綁定至 {model} 區域網路直連',
        'When on, the APRS audio source binds directly to the {model} LAN link',
        'オンにすると、APRS 音声の送受信元は {model} の LAN 直結に束ねられます',
        'Al activarlo, la fuente de audio APRS se enlaza a la conexión LAN del {model}',
        'Saat aktif, sumber audio APRS langsung terikat ke tautan LAN {model}',
    ),
    'icomLinkPhase': (
        '链路阶段', '鏈路階段', 'Link phase', 'リンク段階', 'Fase del enlace', 'Fase tautan',
    ),
    'icomRfStats': (
        '射频收发统计', '射頻收發統計', 'RF RX/TX stats', 'RF 送受信統計',
        'Estadísticas RF', 'Statistik RF',
    ),
    'icomAudioFmt': (
        '12000 Hz (LPCM 16-bit 单声道)', '12000 Hz (LPCM 16-bit 單聲道)',
        '12000 Hz (LPCM 16-bit mono)', '12000 Hz（LPCM 16bit モノラル）',
        '12000 Hz (LPCM 16 bits mono)', '12000 Hz (LPCM 16-bit mono)',
    ),
    'icomProcessing': (
        '处理中...', '處理中...', 'Working...', '処理中...', 'Procesando...', 'Memproses...',
    ),
    'icomDisconnectRadio': (
        '断开电台连接', '斷開電台連線', 'Disconnect radio', '無線機を切断',
        'Desconectar radio', 'Putuskan radio',
    ),
    'icomConnectRadio': (
        '立即连接 {model}', '立即連線 {model}', 'Connect {model} now', '今すぐ {model} に接続',
        'Conectar {model} ahora', 'Sambungkan {model} sekarang',
    ),
    'icomNetworkTitle': (
        '电台网络参数', '電台網路參數', 'Radio network settings', '無線機ネットワーク設定',
        'Parámetros de red', 'Setelan jaringan radio',
    ),
    'icomNetworkSubtitle': (
        '选择电台型号预置并配置 IP 与 Network User 凭据',
        '選擇電台型號預設並設定 IP 與 Network User 憑證',
        'Pick a radio preset and set the IP and Network User credentials',
        '無線機プリセットを選び、IP と Network User の資格情報を設定します',
        'Elige un preset de radio y configura la IP y las credenciales Network User',
        'Pilih preset radio lalu atur IP dan kredensial Network User',
    ),
    'icomModelPreset': (
        '电台型号预置', '電台型號預設', 'Radio preset', '無線機プリセット',
        'Preset de radio', 'Preset radio',
    ),
    'icomIpHint': (
        '电台 IP 地址', '電台 IP 位址', 'Radio IP address', '無線機の IP アドレス',
        'Dirección IP del radio', 'Alamat IP radio',
    ),
    'icomUserHint': (
        '电台 Network User 名', '電台 Network User 名', 'Radio Network User name',
        '無線機の Network User 名', 'Nombre de Network User del radio', 'Nama Network User radio',
    ),
    'icomPassHint': (
        '电台 Network User 密码', '電台 Network User 密碼', 'Radio Network User password',
        '無線機の Network User パスワード', 'Contraseña de Network User del radio',
        'Kata sandi Network User radio',
    ),
    'icomCredHint': (
        '提示：用户名和密码必须与电台内部 Network User Setting 完全一致。',
        '提示：使用者名稱和密碼必須與電台內部 Network User Setting 完全一致。',
        'Note: the username and password must match the radio\'s internal Network User Setting exactly.',
        'ヒント：ユーザー名とパスワードは無線機本体の Network User Setting と完全に一致させてください。',
        'Nota: el usuario y la contraseña deben coincidir exactamente con el Network User Setting del radio.',
        'Catatan: nama pengguna dan kata sandi harus sama persis dengan Network User Setting di radio.',
    ),
    'icomCivTitle': (
        'CI-V 控制与发射设置', 'CI-V 控制與發射設定', 'CI-V control & transmit',
        'CI-V 制御と送信設定', 'Control CI-V y transmisión', 'Kontrol CI-V & transmisi',
    ),
    'icomCivSubtitle': (
        'PTT 自动控制、前导延时与信标参数', 'PTT 自動控制、前導延遲與信標參數',
        'PTT auto control, TX delay and beacon options',
        'PTT 自動制御・プリアンブル遅延・ビーコン設定',
        'Control automático de PTT, retardo de TX y baliza',
        'Kontrol otomatis PTT, tunda TX, dan beacon',
    ),
    'icomRfBeaconHint': (
        '是否允许通过电台射频自动周期发射信标（半双工，发射时自动静默监听）。',
        '是否允許透過電台射頻自動週期發射信標（半雙工，發射時自動靜默監聽）。',
        'Allow the radio to beacon automatically over RF (half-duplex: listen is muted while transmitting).',
        '無線機の RF で自動的にビーコン送信することを許可します（半二重。送信中は受信をミュート）。',
        'Permite que el radio balice automáticamente por RF (semidúplex: se silencia la escucha al transmitir).',
        'Izinkan radio memancarkan beacon otomatis via RF (half-duplex: dengar dibisukan saat memancar).',
    ),
    'icomTxDelayLabel': (
        '发射前导延迟 (TX Delay, ms)', '發射前導延遲 (TX Delay, ms)',
        'TX preamble delay (TX Delay, ms)', '送信プリアンブル遅延 (TX Delay, ms)',
        'Retardo de preámbulo TX (TX Delay, ms)', 'Tunda preamble TX (TX Delay, ms)',
    ),
    'icomCivAddrLabel': (
        '电台 CI-V 地址 (十六进制)', '電台 CI-V 位址 (十六進位)',
        'Radio CI-V address (hex)', '無線機の CI-V アドレス（16 進）',
        'Dirección CI-V del radio (hex)', 'Alamat CI-V radio (hex)',
    ),
    'icomControllerAddr': (
        '控制器地址', '控制器位址', 'Controller address', 'コントローラアドレス',
        'Dirección del controlador', 'Alamat pengontrol',
    ),
    'icomControllerAddrValue': (
        '0xE0 (默认)', '0xE0 (預設)', '0xE0 (default)', '0xE0（既定）',
        '0xE0 (predeterminado)', '0xE0 (bawaan)',
    ),
    'icomGuideTitle': (
        '电台设置指引', '電台設定指引', 'Radio setup guide', '無線機の設定ガイド',
        'Guía de configuración del radio', 'Panduan setelan radio',
    ),
    'icomGuideSubtitle': (
        '在 Icom 电台上的必要准备步骤', '在 Icom 電台上的必要準備步驟',
        'Required preparation steps on the Icom radio', 'Icom 無線機側で必要な準備手順',
        'Pasos necesarios en el radio Icom', 'Langkah persiapan yang diperlukan di radio Icom',
    ),
    'icomGuide1Title': (
        '网络连接', '網路連線', 'Network connection', 'ネットワーク接続', 'Conexión de red', 'Koneksi jaringan',
    ),
    'icomGuide1Body': (
        'IC-705 可在 MENU → SET → WLAN Set 中选择 Connect to Network 连接路由器 Wi-Fi，或选择 Access Point 开启热点供手机直连；'
        'IC-9700 / IC-7610 / IC-905 可直接连接路由器 LAN 口，或通过无线网桥接入局域网。',
        'IC-705 可在 MENU → SET → WLAN Set 中選擇 Connect to Network 連接路由器 Wi-Fi，或選擇 Access Point 開啟熱點供手機直連；'
        'IC-9700 / IC-7610 / IC-905 可直接連接路由器 LAN 埠，或透過無線網橋接入區域網路。',
        'On the IC-705, choose Connect to Network in MENU → SET → WLAN Set to join your router\'s Wi-Fi, or Access Point to host a hotspot for the phone; '
        'the IC-9700 / IC-7610 / IC-905 can plug into a router LAN port or join via a wireless bridge.',
        'IC-705 は MENU → SET → WLAN Set で Connect to Network を選んでルーターの Wi-Fi に接続するか、Access Point でスマホ直結用のホットスポットを立てます。'
        'IC-9700 / IC-7610 / IC-905 はルーターの LAN ポートに接続するか、無線ブリッジで LAN に参加させます。',
        'En el IC-705, elige Connect to Network en MENU → SET → WLAN Set para unirte a la Wi-Fi del router, o Access Point para crear un punto de acceso para el teléfono; '
        'los IC-9700 / IC-7610 / IC-905 pueden conectarse a un puerto LAN del router o entrar por un puente inalámbrico.',
        'Di IC-705, pilih Connect to Network di MENU → SET → WLAN Set untuk bergabung ke Wi-Fi router, atau Access Point untuk membuat hotspot bagi ponsel; '
        'IC-9700 / IC-7610 / IC-905 dapat tersambung ke port LAN router atau lewat jembatan nirkabel.',
    ),
    'icomGuide2Title': (
        '添加网络用户', '新增網路使用者', 'Add a Network User', 'ネットワークユーザーを追加',
        'Añadir un Network User', 'Tambah Network User',
    ),
    'icomGuide2Body': (
        '进入 WLAN Set / Network Set → Network User Setting，添加一个用户（设置好用户名与密码），并开启允许连接。',
        '進入 WLAN Set / Network Set → Network User Setting，新增一個使用者（設定好使用者名稱與密碼），並開啟允許連線。',
        'Go to WLAN Set / Network Set → Network User Setting, add a user (with username and password) and allow the connection.',
        'WLAN Set / Network Set → Network User Setting でユーザーを追加し（ユーザー名とパスワードを設定）、接続を許可します。',
        'Entra en WLAN Set / Network Set → Network User Setting, añade un usuario (con usuario y contraseña) y permite la conexión.',
        'Masuk ke WLAN Set / Network Set → Network User Setting, tambah pengguna (dengan nama dan kata sandi) lalu izinkan koneksi.',
    ),
    'icomGuide3Title': (
        '确认 CI-V 地址与端口', '確認 CI-V 位址與連接埠', 'Confirm the CI-V address and port',
        'CI-V アドレスとポートを確認', 'Confirma la dirección y el puerto CI-V',
        'Pastikan alamat dan port CI-V',
    ),
    'icomGuide3Body': (
        '进入 MENU → SET → Connectors → CI-V，确认 CI-V Address 与控制端口。',
        '進入 MENU → SET → Connectors → CI-V，確認 CI-V Address 與控制連接埠。',
        'Go to MENU → SET → Connectors → CI-V and confirm the CI-V Address and control port.',
        'MENU → SET → Connectors → CI-V で CI-V Address と制御ポートを確認します。',
        'Entra en MENU → SET → Connectors → CI-V y confirma la CI-V Address y el puerto de control.',
        'Masuk ke MENU → SET → Connectors → CI-V dan pastikan CI-V Address serta port kontrol.',
    ),
    'icomGuide4Title': (
        '设置模式与频率', '設定模式與頻率', 'Set mode and frequency', 'モードと周波数を設定',
        'Configura modo y frecuencia', 'Atur mode dan frekuensi',
    ),
    'icomGuide4Body': (
        '将电台对应频段模式设为 FM-D。', '將電台對應頻段模式設為 FM-D。',
        'Set the radio\'s mode for that band to FM-D.', '該当バンドのモードを FM-D に設定します。',
        'Ajusta el modo del radio en esa banda a FM-D.', 'Setel mode radio pada band itu ke FM-D.',
    ),
    'icomLogTitle': (
        '电台通信诊断日志', '電台通訊診斷日誌', 'Radio comms diagnostic log',
        '無線機通信の診断ログ', 'Registro de diagnóstico', 'Log diagnostik komunikasi radio',
    ),
    'icomLogSubtitle': (
        '查看 Icom 局域网控制包与 CI-V 通信记录', '檢視 Icom 區域網路控制封包與 CI-V 通訊記錄',
        'Inspect Icom LAN control packets and CI-V traffic',
        'Icom LAN 制御パケットと CI-V 通信の記録を表示',
        'Consulta los paquetes de control LAN de Icom y el tráfico CI-V',
        'Lihat paket kontrol LAN Icom dan lalu lintas CI-V',
    ),
    'icomLogEmpty': (
        '暂无通信日志', '尚無通訊日誌', 'No comms log yet', '通信ログはまだありません',
        'Todavía no hay registro', 'Belum ada log komunikasi',
    ),
    'icomPhaseOpeningSockets': (
        '正在打开端口…', '正在開啟連接埠…', 'Opening ports…', 'ポートを開いています…',
        'Abriendo puertos…', 'Membuka port…',
    ),
    'icomPhaseDiscovering': (
        '正在发现电台…', '正在尋找電台…', 'Discovering radio…', '無線機を検出しています…',
        'Buscando el radio…', 'Menemukan radio…',
    ),
    'icomPhaseAuthenticating': (
        '正在登录电台…', '正在登入電台…', 'Signing in to radio…', '無線機にログインしています…',
        'Iniciando sesión en el radio…', 'Masuk ke radio…',
    ),
    'icomPhaseNegotiating': (
        '正在协商音频流…', '正在協商音訊串流…', 'Negotiating audio stream…',
        '音声ストリームをネゴシエーション中…', 'Negociando el flujo de audio…',
        'Menjalin aliran audio…',
    ),
    'icomPhaseOpeningStreams': (
        '正在打开数据流…', '正在開啟資料串流…', 'Opening streams…', 'ストリームを開いています…',
        'Abriendo flujos…', 'Membuka aliran…',
    ),
    'icomPhaseReady': (
        '已连接（等待音频）', '已連線（等待音訊）', 'Connected (awaiting audio)',
        '接続済み（音声待ち）', 'Conectado (esperando audio)', 'Tersambung (menunggu audio)',
    ),
    'icomPhaseReceiving': (
        '已连接（接收中）', '已連線（接收中）', 'Connected (receiving)',
        '接続済み（受信中）', 'Conectado (recibiendo)', 'Tersambung (menerima)',
    ),
    'icomPhaseReconnect': (
        '连接中断，正在重连…', '連線中斷，正在重連…', 'Link dropped — reconnecting…',
        '接続が切れました。再接続中…', 'Enlace perdido: reconectando…',
        'Tautan terputus — menyambung ulang…',
    ),
    'icomPhaseFailed': (
        '连接失败', '連線失敗', 'Connection failed', '接続に失敗しました',
        'Conexión fallida', 'Koneksi gagal',
    ),
    'icomPhaseUnsupported': (
        '当前平台不支持 IC-705 局域网直连', '目前平台不支援 IC-705 區域網路直連',
        'This platform does not support the IC-705 LAN link',
        'このプラットフォームは IC-705 の LAN 直結に対応していません',
        'Esta plataforma no admite la conexión LAN del IC-705',
        'Platform ini tidak mendukung tautan LAN IC-705',
    ),
    'icomSwitchTitle': (
        'WLAN 电台（{model}）', 'WLAN 電台（{model}）', 'WLAN radio ({model})',
        'WLAN 無線機（{model}）', 'Radio WLAN ({model})', 'Radio WLAN ({model})',
    ),
    'icomLanAddr': (
        '电台地址', '電台位址', 'Radio address', '無線機アドレス', 'Dirección del radio', 'Alamat radio',
    ),
    'icomCardActive': (
        '当前已启用 {model} 局域网直连模式。', '目前啟用 {model} 區域網路直連模式。',
        'The {model} LAN direct link is currently active.',
        '現在 {model} の LAN 直結モードが有効です。',
        'El enlace LAN directo con {model} está activo ahora.',
        'Mode LAN langsung {model} sedang aktif.',
    ),
    'icomConnectingTo': (
        '正在连接 {radio}', '正在連線 {radio}', 'Connecting to {radio}', '{radio} に接続中',
        'Conectando con {radio}', 'Menyambungkan ke {radio}',
    ),
    'icomConnectTitle': (
        '连接 {radio} 电台', '連線 {radio} 電台', 'Connect {radio} radio', '{radio} 無線機に接続',
        'Conectar radio {radio}', 'Sambungkan radio {radio}',
    ),
    'icomConnectingSub': (
        '正在连接 {radio}（{tnc}）…', '正在連線 {radio}（{tnc}）…',
        'Connecting to {radio} ({tnc})…', '{radio}（{tnc}）に接続中…',
        'Conectando con {radio} ({tnc})…', 'Menyambungkan ke {radio} ({tnc})…',
    ),
    'icomDescHost': (
        '{host} · 局域网直连电台收发与 CI-V 控制', '{host} · 區域網路直連電台收發與 CI-V 控制',
        '{host} · LAN direct radio RX/TX and CI-V control',
        '{host} · LAN 直結で無線機を送受信・CI-V 制御',
        '{host} · RX/TX por LAN directa y control CI-V',
        '{host} · RX/TX radio via LAN langsung dan kontrol CI-V',
    ),
    'icomDescRadio': (
        '通过局域网直连 {radio} 电台收发报文与控制', '透過區域網路直連 {radio} 電台收發報文與控制',
        'Send/receive and control the {radio} over a direct LAN link',
        'LAN 直結で {radio} 無線機の送受信と制御',
        'Envía/recibe y controla el {radio} por LAN directa',
        'Kirim/terima dan kontrol {radio} via LAN langsung',
    ),
    'modelIc705Desc': (
        '便携全模式 QRP 电台（内置 Wi-Fi AP / STA）', '可攜全模式 QRP 電台（內建 Wi-Fi AP / STA）',
        'Portable all-mode QRP radio (built-in Wi-Fi AP / STA)',
        'ポータブル全モード QRP 無線機（Wi-Fi AP / STA 内蔵）',
        'Radio QRP portátil multimodo (Wi-Fi AP / STA integrado)',
        'Radio QRP portabel semua-mode (Wi-Fi AP / STA bawaan)',
    ),
    'modelIc9700Desc': (
        'VHF/UHF/1.2GHz 全模式基站（以太网 LAN / Wi-Fi）', 'VHF/UHF/1.2GHz 全模式基站（乙太網路 LAN / Wi-Fi）',
        'VHF/UHF/1.2 GHz all-mode base (Ethernet LAN / Wi-Fi)',
        'VHF/UHF/1.2GHz 全モード基地局（Ethernet LAN / Wi-Fi）',
        'Base multimodo VHF/UHF/1.2 GHz (Ethernet LAN / Wi-Fi)',
        'Base semua-mode VHF/UHF/1.2GHz (Ethernet LAN / Wi-Fi)',
    ),
    'modelIc7610Desc': (
        'HF/50MHz 双接收 SDR 基站（以太网 LAN）', 'HF/50MHz 雙接收 SDR 基站（乙太網路 LAN）',
        'HF/50 MHz dual-receiver SDR base (Ethernet LAN)',
        'HF/50MHz デュアル受信 SDR 基地局（Ethernet LAN）',
        'Base SDR de doble receptor HF/50 MHz (Ethernet LAN)',
        'Base SDR penerima ganda HF/50MHz (Ethernet LAN)',
    ),
    'modelIc905Desc': (
        '144MHz~10GHz 全模式微波电台（以太网 LAN）', '144MHz~10GHz 全模式微波電台（乙太網路 LAN）',
        '144 MHz–10 GHz all-mode microwave radio (Ethernet LAN)',
        '144MHz〜10GHz 全モードマイクロ波無線機（Ethernet LAN）',
        'Radio de microondas multimodo 144 MHz–10 GHz (Ethernet LAN)',
        'Radio gelombang mikro semua-mode 144MHz–10GHz (Ethernet LAN)',
    ),
    'modelCustomName': (
        '自定义 / 其他 (Custom)', '自訂 / 其他 (Custom)', 'Custom / other',
        'カスタム / その他 (Custom)', 'Personalizado / otro', 'Kustom / lainnya',
    ),
    'modelCustomDesc': (
        '自定义 Icom 电台 CI-V 地址与端口', '自訂 Icom 電台 CI-V 位址與連接埠',
        'Set a custom Icom CI-V address and port', 'Icom 無線機の CI-V アドレスとポートをカスタム設定',
        'Dirección y puerto CI-V personalizados', 'Alamat dan port CI-V Icom kustom',
    ),
    'assetWindowsPackage': (
        'Windows 安装包', 'Windows 安裝包', 'Windows installer', 'Windows インストーラー',
        'Instalador de Windows', 'Penginstal Windows',
    ),
    'assetApkPackage': (
        'APK 安装包', 'APK 安裝包', 'APK package', 'APK パッケージ',
        'Paquete APK', 'Paket APK',
    ),
    'honorTagPerseverance': (
        '养生', '養生', 'Wellness', '養生', 'Bienestar', 'Kebugaran',
    ),
}

# 带占位符的键 → gen-l10n 需要的占位符声明（一律 String）
META = {
    'icomLinkConnected': '{"placeholders": {"model": {"type": "String"}}}',
    'icomBindHint': '{"placeholders": {"model": {"type": "String"}}}',
    'icomConnectRadio': '{"placeholders": {"model": {"type": "String"}}}',
    'icomSwitchTitle': '{"placeholders": {"model": {"type": "String"}}}',
    'icomCardActive': '{"placeholders": {"model": {"type": "String"}}}',
    'icomConnectingTo': '{"placeholders": {"radio": {"type": "String"}}}',
    'icomConnectTitle': '{"placeholders": {"radio": {"type": "String"}}}',
    'icomConnectingSub':
        '{"placeholders": {"radio": {"type": "String"}, "tnc": {"type": "String"}}}',
    'icomDescHost': '{"placeholders": {"host": {"type": "String"}}}',
    'icomDescRadio': '{"placeholders": {"radio": {"type": "String"}}}',
}

ANCHOR = '"codeContributionTranslation"'


def _params(key):
    raw = META.get(key)
    if not raw:
        return []
    return list(json.loads(raw).get('placeholders', {}).keys())


def member(key):
    ps = _params(key)
    if not ps:
        return 'get %s' % key
    return '%s(%s)' % (key, ', '.join('String ' + x for x in ps))


def interp(key, text):
    for x in _params(key):
        text = text.replace('{%s}' % x, '$%s' % x)
    return text


def class_body(src, name):
    m = re.search(r'(?m)^(?:abstract )?class ' + re.escape(name) + r'\b', src)
    if not m:
        raise SystemExit('找不到类 ' + name)
    j = src.find('\n}\n', m.end())
    if j < 0:
        j = src.rfind('\n}')
    return m.end(), j


def main():
    for lg in LANGS:
        p = os.path.join(ROOT, 'lib', 'l10n', 'app_%s.arb' % lg)
        lines = io.open(p, encoding='utf-8').read().split('\n')
        out = [ln for ln in lines
               if not any(ln.strip().startswith('"%s"' % k) for k in DATA)]
        lines = out
        idx = next((i for i, ln in enumerate(lines)
                    if ln.strip().startswith(ANCHOR)), None)
        assert idx is not None, 'anchor not found in %s' % p
        block = []
        for k, v in DATA.items():
            block.append('  "%s": %s,' % (k, json.dumps(v[IDX[lg]], ensure_ascii=False)))
        for k, m in META.items():
            block.append('  "%s": %s,' % ('@' + k, m))
        lines[idx:idx] = block
        io.open(p, 'w', encoding='utf-8').write('\n'.join(lines))
        json.load(io.open(p, encoding='utf-8'))
        print('%s ok (+%d)' % (p, len(DATA)))

    # 抽象类
    p = os.path.join(ROOT, 'lib', 'l10n', 'app_localizations.dart')
    s = io.open(p, encoding='utf-8').read()
    code = []
    for k, v in DATA.items():
        if re.search(r'String (?:get )?%s\b' % k, s):
            continue
        code.append("  /// No description provided for @%s.\n  ///\n"
                    "  /// In zh, this message translates to:\n  /// **'%s'**\n"
                    "  String %s;\n" % (k, v[0], member(k)))
    if code:
        _, j = class_body(s, 'AppLocalizations')
        s = s[:j] + '\n' + '\n'.join(code) + s[j:]
        io.open(p, 'w', encoding='utf-8').write(s)
    print('抽象类 +%d' % len(code))

    for lg in LANGS:
        fn = ('app_localizations_zh.dart' if lg in ('zh', 'zh_TW')
              else 'app_localizations_%s.dart' % lg)
        p = os.path.join(ROOT, 'lib', 'l10n', fn)
        s = io.open(p, encoding='utf-8').read()
        b0, b1 = class_body(s, CLASSES[lg])
        code = []
        for k, v in DATA.items():
            if re.search(r'String (?:get )?%s\b' % k, s[b0:b1]):
                continue
            code.append('  @override\n  String %s => %s;\n'
                        % (member(k),
                           json.dumps(interp(k, v[IDX[lg]]), ensure_ascii=False)))
        if code:
            s = s[:b1] + '\n' + '\n'.join(code) + s[b1:]
            io.open(p, 'w', encoding='utf-8').write(s)
        print('%s +%d' % (CLASSES[lg], len(code)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
