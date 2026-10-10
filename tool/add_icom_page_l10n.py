#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 Icom 设备页里写死的中文换成 l10n 调用，并把缺的键写进 6 份 arb。

为什么单开一个脚本而不是手改 arb：6 种语言的 arb 必须**逐键**同步（check_l10n_sync
会拦），手改必漏。脚本化后重跑即可对齐。

已被上一次会话加好、但从未被调用的键（icomPhase*、model*Desc、modelCustomName）
这里不再重复写入；本脚本只补 ic705_device_page.dart 真正用到的其余键。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARB_DIR = os.path.join(ROOT, 'lib', 'l10n')
LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']

# key -> {locale: value}。zh 为基准模板。
D = {
    'icomLinkStatusTitle': {
        'zh': '电台链路状态',
        'zh_TW': '電台鏈路狀態',
        'en': 'Radio link status',
        'ja': '無線機リンク状態',
        'es': 'Estado del enlace de radio',
        'id': 'Status tautan radio',
    },
    'icomLinkHandshaking': {
        'zh': '未连接或正在握手',
        'zh_TW': '未連線或正在握手',
        'en': 'Not connected or handshaking',
        'ja': '未接続またはハンドシェイク中',
        'es': 'Sin conexión o negociando',
        'id': 'Tidak terhubung atau handshake',
    },
    'icomRfStats': {
        'zh': '射频收发统计',
        'zh_TW': '射頻收發統計',
        'en': 'RF RX/TX stats',
        'ja': 'RF 送受信統計',
        'es': 'Estadísticas RF RX/TX',
        'id': 'Statistik RF RX/TX',
    },
    'icomAudioSampleRate': {
        'zh': '音频采样率',
        'zh_TW': '音訊取樣率',
        'en': 'Audio sample rate',
        'ja': 'オーディオサンプルレート',
        'es': 'Frecuencia de muestreo de audio',
        'id': 'Laju sampel audio',
    },
    'icomAudioFmtValue': {
        'zh': '12000 Hz (LPCM 16-bit 单声道)',
        'zh_TW': '12000 Hz (LPCM 16-bit 單聲道)',
        'en': '12000 Hz (LPCM 16-bit mono)',
        'ja': '12000 Hz (LPCM 16-bit モノラル)',
        'es': '12000 Hz (LPCM 16 bits mono)',
        'id': '12000 Hz (LPCM 16-bit mono)',
    },
    'icomNetworkTitle': {
        'zh': '电台网络参数',
        'zh_TW': '電台網路參數',
        'en': 'Radio network settings',
        'ja': '無線機ネットワーク設定',
        'es': 'Parámetros de red de la radio',
        'id': 'Pengaturan jaringan radio',
    },
    'icomNetworkSubtitle': {
        'zh': '选择电台型号预置并配置 IP 与 Network User 凭据',
        'zh_TW': '選擇電台型號預設並設定 IP 與 Network User 憑證',
        'en': 'Pick a radio preset and configure IP and Network User credentials',
        'ja': '無線機プリセットを選択し、IP と Network User 認証情報を設定',
        'es': 'Elige un preset de radio y configura la IP y las credenciales de Network User',
        'id': 'Pilih preset radio dan atur IP serta kredensial Network User',
    },
    'icomModelPreset': {
        'zh': '电台型号预置',
        'zh_TW': '電台型號預設',
        'en': 'Radio preset',
        'ja': '無線機プリセット',
        'es': 'Preset de radio',
        'id': 'Preset radio',
    },
    'icomIpHint': {
        'zh': '电台 IP 地址',
        'zh_TW': '電台 IP 位址',
        'en': 'Radio IP address',
        'ja': '無線機 IP アドレス',
        'es': 'Dirección IP de la radio',
        'id': 'Alamat IP radio',
    },
    'icomUserHint': {
        'zh': '电台 Network User 名',
        'zh_TW': '電台 Network User 名稱',
        'en': 'Radio Network User name',
        'ja': '無線機 Network User 名',
        'es': 'Usuario Network User de la radio',
        'id': 'Nama Network User radio',
    },
    'icomPassHint': {
        'zh': '电台 Network User 密码',
        'zh_TW': '電台 Network User 密碼',
        'en': 'Radio Network User password',
        'ja': '無線機 Network User パスワード',
        'es': 'Contraseña Network User de la radio',
        'id': 'Kata sandi Network User radio',
    },
    'icomCredHint': {
        'zh': '提示：用户名和密码必须与电台内部 Network User Setting 完全一致。',
        'zh_TW': '提示：使用者名稱與密碼必須與電台內部 Network User Setting 完全一致。',
        'en': 'Tip: the user name and password must match the radio\'s Network User Setting exactly.',
        'ja': 'ヒント：ユーザー名とパスワードは無線機側の Network User Setting と完全に一致させてください。',
        'es': 'Consejo: el usuario y la contraseña deben coincidir exactamente con el Network User Setting de la radio.',
        'id': 'Tips: nama pengguna dan kata sandi harus sama persis dengan Network User Setting di radio.',
    },
    'icomCivTitle': {
        'zh': 'CI-V 控制与发射设置',
        'zh_TW': 'CI-V 控制與發射設定',
        'en': 'CI-V control & transmit',
        'ja': 'CI-V 制御と送信設定',
        'es': 'Control CI-V y transmisión',
        'id': 'Kontrol CI-V & transmisi',
    },
    'icomCivSubtitle': {
        'zh': 'PTT 自动控制、前导延时与信标参数',
        'zh_TW': 'PTT 自動控制、前導延遲與信標參數',
        'en': 'PTT auto control, TX delay and beacon parameters',
        'ja': 'PTT 自動制御、送信ディレイ、ビーコンパラメータ',
        'es': 'Control automático de PTT, retardo TX y parámetros de baliza',
        'id': 'Kontrol otomatis PTT, tunda TX, dan parameter beacon',
    },
    'icomRfBeaconHint': {
        'zh': '是否允许通过电台射频自动周期发射信标（半双工，发射时自动静默监听）。',
        'zh_TW': '是否允許透過電台射頻自動週期發射信標（半雙工，發射時自動靜默監聽）。',
        'en': 'Allow periodic RF beacon transmission via the radio (half-duplex; listening is muted while transmitting).',
        'ja': '無線機の RF でビーコンを定期送信することを許可します（半二重、送信中は受信をミュート）。',
        'es': 'Permitir el envío periódico de balizas por RF de la radio (semidúplex; la escucha se silencia al transmitir).',
        'id': 'Izinkan pancaran beacon RF berkala lewat radio (half-duplex; penerimaan dibisukan saat memancar).',
    },
    'icomTxDelayLabel': {
        'zh': '发射前导延迟 (TX Delay, ms)',
        'zh_TW': '發射前導延遲 (TX Delay, ms)',
        'en': 'TX delay (ms)',
        'ja': '送信ディレイ (TX Delay, ms)',
        'es': 'Retardo TX (ms)',
        'id': 'Tunda TX (ms)',
    },
    'icomCivAddrLabel': {
        'zh': '电台 CI-V 地址 (十六进制)',
        'zh_TW': '電台 CI-V 位址 (十六進位)',
        'en': 'Radio CI-V address (hex)',
        'ja': '無線機 CI-V アドレス (16 進)',
        'es': 'Dirección CI-V de la radio (hex)',
        'id': 'Alamat CI-V radio (hex)',
    },
    'icomControllerAddr': {
        'zh': '控制器地址',
        'zh_TW': '控制器位址',
        'en': 'Controller address',
        'ja': 'コントローラアドレス',
        'es': 'Dirección del controlador',
        'id': 'Alamat pengendali',
    },
    'icomControllerAddrValue': {
        'zh': '0xE0 (默认)',
        'zh_TW': '0xE0 (預設)',
        'en': '0xE0 (default)',
        'ja': '0xE0 (デフォルト)',
        'es': '0xE0 (predeterminado)',
        'id': '0xE0 (bawaan)',
    },
    'icomGuideTitle': {
        'zh': '电台设置指引',
        'zh_TW': '電台設定指引',
        'en': 'Radio setup guide',
        'ja': '無線機設定ガイド',
        'es': 'Guía de configuración de la radio',
        'id': 'Panduan penyiapan radio',
    },
    'icomGuideSubtitle': {
        'zh': '在 Icom 电台上的必要准备步骤',
        'zh_TW': '在 Icom 電台上的必要準備步驟',
        'en': 'Required preparation steps on the Icom radio',
        'ja': 'Icom 無線機側で必要な準備手順',
        'es': 'Pasos de preparación necesarios en la radio Icom',
        'id': 'Langkah persiapan yang diperlukan di radio Icom',
    },
    'icomGuide1Title': {
        'zh': '网络连接',
        'zh_TW': '網路連線',
        'en': 'Network connection',
        'ja': 'ネットワーク接続',
        'es': 'Conexión de red',
        'id': 'Koneksi jaringan',
    },
    'icomGuide1Body': {
        'zh': 'IC-705 可在 MENU → SET → WLAN Set 中选择 Connect to Network 连接路由器 Wi-Fi，或选择 Access Point 开启热点供手机直连；IC-9700 / IC-7610 / IC-905 可直接连接路由器 LAN 口，或通过无线网桥接入局域网。',
        'zh_TW': 'IC-705 可在 MENU → SET → WLAN Set 中選擇 Connect to Network 連接路由器 Wi-Fi，或選擇 Access Point 開啟熱點供手機直連；IC-9700 / IC-7610 / IC-905 可直接連接路由器 LAN 埠，或透過無線橋接器接入區域網路。',
        'en': 'On the IC-705, choose Connect to Network in MENU → SET → WLAN Set to join your router\'s Wi-Fi, or choose Access Point to broadcast a hotspot for a direct phone connection; the IC-9700 / IC-7610 / IC-905 can connect directly to a router LAN port or join the LAN through a wireless bridge.',
        'ja': 'IC-705 は MENU → SET → WLAN Set で Connect to Network を選んでルーターの Wi-Fi に接続するか、Access Point を選んでスマホ直結用のホットスポットを開けます。IC-9700 / IC-7610 / IC-905 はルーターの LAN ポートに直接接続するか、無線ブリッジ経由で LAN に参加できます。',
        'es': 'En el IC-705, elige Connect to Network en MENU → SET → WLAN Set para unirte al Wi-Fi del router, o Access Point para emitir un punto de acceso y conectar el teléfono directamente; el IC-9700 / IC-7610 / IC-905 pueden conectarse directamente a un puerto LAN del router o unirse a la LAN mediante un puente inalámbrico.',
        'id': 'Di IC-705, pilih Connect to Network di MENU → SET → WLAN Set untuk bergabung ke Wi-Fi router, atau pilih Access Point untuk memancarkan hotspot bagi koneksi langsung ponsel; IC-9700 / IC-7610 / IC-905 dapat terhubung langsung ke port LAN router atau bergabung ke LAN melalui jembatan nirkabel.',
    },
    'icomGuide2Title': {
        'zh': '添加网络用户',
        'zh_TW': '新增網路使用者',
        'en': 'Add a network user',
        'ja': 'ネットワークユーザーを追加',
        'es': 'Añadir un usuario de red',
        'id': 'Tambah pengguna jaringan',
    },
    'icomGuide2Body': {
        'zh': '进入 WLAN Set / Network Set → Network User Setting，添加一个用户（设置好用户名与密码），并开启允许连接。',
        'zh_TW': '進入 WLAN Set / Network Set → Network User Setting，新增一個使用者（設定好名稱與密碼），並開啟允許連線。',
        'en': 'Go to WLAN Set / Network Set → Network User Setting, add a user (set a name and password), and enable connection permission.',
        'ja': 'WLAN Set / Network Set → Network User Setting に進み、ユーザーを追加して（名前とパスワードを設定）接続許可を有効にします。',
        'es': 'Ve a WLAN Set / Network Set → Network User Setting, añade un usuario (define nombre y contraseña) y habilita el permiso de conexión.',
        'id': 'Buka WLAN Set / Network Set → Network User Setting, tambahkan pengguna (atur nama dan kata sandi), lalu aktifkan izin koneksi.',
    },
    'icomGuide3Title': {
        'zh': '确认 CI-V 地址与端口',
        'zh_TW': '確認 CI-V 位址與埠',
        'en': 'Check the CI-V address and port',
        'ja': 'CI-V アドレスとポートを確認',
        'es': 'Comprueba la dirección y el puerto CI-V',
        'id': 'Periksa alamat dan port CI-V',
    },
    'icomGuide3Body': {
        'zh': '进入 MENU → SET → Connectors → CI-V，确认 CI-V Address 与控制端口。',
        'zh_TW': '進入 MENU → SET → Connectors → CI-V，確認 CI-V Address 與控制埠。',
        'en': 'Go to MENU → SET → Connectors → CI-V and check the CI-V Address and control port.',
        'ja': 'MENU → SET → Connectors → CI-V に進み、CI-V Address と制御ポートを確認します。',
        'es': 'Ve a MENU → SET → Connectors → CI-V y comprueba la CI-V Address y el puerto de control.',
        'id': 'Buka MENU → SET → Connectors → CI-V dan periksa CI-V Address serta port kontrol.',
    },
    'icomGuide4Title': {
        'zh': '设置模式与频率',
        'zh_TW': '設定模式與頻率',
        'en': 'Set mode and frequency',
        'ja': 'モードと周波数を設定',
        'es': 'Configura el modo y la frecuencia',
        'id': 'Atur mode dan frekuensi',
    },
    'icomGuide4Body': {
        'zh': '将电台对应频段模式设为 FM-D。',
        'zh_TW': '將電台對應頻段模式設為 FM-D。',
        'en': 'Set the radio\'s mode for the relevant band to FM-D.',
        'ja': '該当バンドのモードを FM-D に設定します。',
        'es': 'Configura el modo de la radio para la banda correspondiente en FM-D.',
        'id': 'Atur mode radio pada band terkait ke FM-D.',
    },
    'icomLogTitle': {
        'zh': '电台通信诊断日志',
        'zh_TW': '電台通訊診斷日誌',
        'en': 'Radio communication log',
        'ja': '無線機通信ログ',
        'es': 'Registro de comunicación de la radio',
        'id': 'Log komunikasi radio',
    },
    'icomLogSubtitle': {
        'zh': '查看 Icom 局域网控制包与 CI-V 通信记录',
        'zh_TW': '檢視 Icom 區域網路控制封包與 CI-V 通訊記錄',
        'en': 'View Icom LAN control packets and CI-V traffic',
        'ja': 'Icom LAN 制御パケットと CI-V 通信記録を表示',
        'es': 'Ver los paquetes de control LAN de Icom y el tráfico CI-V',
        'id': 'Lihat paket kontrol LAN Icom dan lalu lintas CI-V',
    },
    'icomLogEmpty': {
        'zh': '暂无通信日志',
        'zh_TW': '尚無通訊日誌',
        'en': 'No communication log yet',
        'ja': '通信ログはまだありません',
        'es': 'Aún no hay registro de comunicación',
        'id': 'Belum ada log komunikasi',
    },
}

# 带占位符的键（放在末尾，避免上面的大表里混 @ 元数据）。
PLURAL = {
    'icomLinkConnected': {
        'zh': '已与 {model} 建立局域网直连',
        'zh_TW': '已與 {model} 建立區域網路直連',
        'en': 'Connected to {model} over LAN',
        'ja': '{model} と LAN 直結しました',
        'es': 'Conectado a {model} por LAN',
        'id': 'Terhubung ke {model} via LAN',
    },
    'icomBindHint': {
        'zh': '开启后，APRS 音频收发数据源将直接绑定至 {model} 局域网直连',
        'zh_TW': '開啟後，APRS 音訊收發資料來源將直接綁定至 {model} 區域網路直連',
        'en': 'When on, APRS audio will bind directly to the {model} LAN link',
        'ja': 'オンにすると、APRS オーディオは {model} の LAN 直結に接続されます',
        'es': 'Al activarlo, el audio APRS se vinculará directamente al enlace LAN de {model}',
        'id': 'Saat aktif, audio APRS akan langsung terikat ke tautan LAN {model}',
    },
    'icomConnectRadio': {
        'zh': '立即连接 {model}',
        'zh_TW': '立即連接 {model}',
        'en': 'Connect to {model} now',
        'ja': '今すぐ {model} に接続',
        'es': 'Conectar a {model} ahora',
        'id': 'Hubungkan ke {model} sekarang',
    },
    'icomCardActive': {
        'zh': '当前已启用 {model} 局域网直连模式。',
        'zh_TW': '目前已啟用 {model} 區域網路直連模式。',
        'en': 'The {model} LAN direct mode is currently enabled.',
        'ja': '現在 {model} の LAN 直結モードが有効です。',
        'es': 'El modo directo por LAN de {model} está activado.',
        'id': 'Mode langsung LAN {model} sedang aktif.',
    },
}


def main():
    for lang in LANGS:
        path = os.path.join(ARB_DIR, f'app_{lang}.arb')
        with io.open(path, encoding='utf-8') as f:
            data = json.load(f, object_pairs_hook=dict)
        for k, vals in D.items():
            # 已存在的键（上一次会话加过的）保持原译文，只补缺失的 —— 避免
            # 本脚本重跑时把别处已在用的译文改掉。
            if k not in data:
                data[k] = vals[lang]
        for k, vals in PLURAL.items():
            if k not in data:
                data[k] = vals[lang]
            data.setdefault('@' + k, {'placeholders': {'model': {'type': 'String'}}})
        with io.open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print(f'{lang}: {len(D) + len(PLURAL)} keys written')


if __name__ == '__main__':
    main()
