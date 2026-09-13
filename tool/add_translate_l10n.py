#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""向 6 个 ARB 注入「连接状态结构化」与「聊天翻译」文案键。

文本级插入（保持原 ARB 的键序与格式，不做整文件重排），幂等可重复执行。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATA = {
    # ── 连接状态（结构化，替换原先的中文哨兵） ──
    'connTncConnected': {
        'zh': 'TNC 已连接 · {arg}', 'zh_TW': 'TNC 已連線 · {arg}',
        'en': 'TNC connected · {arg}', 'ja': 'TNC 接続済み · {arg}',
        'id': 'TNC terhubung · {arg}', 'es': 'TNC conectado · {arg}',
    },
    'connTncPositionSent': {
        'zh': 'TNC 已连接 · 位置已发送 ({arg})',
        'zh_TW': 'TNC 已連線 · 位置已傳送 ({arg})',
        'en': 'TNC connected · position sent ({arg})',
        'ja': 'TNC 接続済み · 位置を送信しました ({arg})',
        'id': 'TNC terhubung · posisi terkirim ({arg})',
        'es': 'TNC conectado · posición enviada ({arg})',
    },
    'connRetryTnc': {
        'zh': 'TNC 连接失败 · {n}s 后重试…',
        'zh_TW': 'TNC 連線失敗 · {n}s 後重試…',
        'en': 'TNC connection failed · retrying in {n}s…',
        'ja': 'TNC 接続失敗 · {n} 秒後に再試行…',
        'id': 'Koneksi TNC gagal · mencoba lagi dalam {n}s…',
        'es': 'Falló la conexión TNC · reintentando en {n}s…',
    },
    'connRetryTncDetail': {
        'zh': 'TNC 连接失败（{e}）· {n}s 后重试…',
        'zh_TW': 'TNC 連線失敗（{e}）· {n}s 後重試…',
        'en': 'TNC connection failed ({e}) · retrying in {n}s…',
        'ja': 'TNC 接続失敗（{e}）· {n} 秒後に再試行…',
        'id': 'Koneksi TNC gagal ({e}) · mencoba lagi dalam {n}s…',
        'es': 'Falló la conexión TNC ({e}) · reintentando en {n}s…',
    },
    'connTncLinkLost': {
        'zh': 'TNC 链路断开 · {n}秒后自动重连…',
        'zh_TW': 'TNC 鏈路中斷 · {n}秒後自動重連…',
        'en': 'TNC link lost · reconnecting in {n}s…',
        'ja': 'TNC リンク切断 · {n} 秒後に自動再接続…',
        'id': 'Tautan TNC terputus · menyambung ulang dalam {n}s…',
        'es': 'Enlace TNC perdido · reconectando en {n}s…',
    },
    # ── TNC 链路错误码 → 人话（否则用户看到 open-write-failed 无从下手） ──
    'tncErrNoDevice': {
        'zh': '未绑定 TNC 设备', 'zh_TW': '未綁定 TNC 裝置',
        'en': 'no TNC device bound', 'ja': 'TNC デバイスが未登録',
        'id': 'belum ada perangkat TNC', 'es': 'ningún dispositivo TNC emparejado',
    },
    'tncErrUnsupported': {
        'zh': '当前平台不支持', 'zh_TW': '目前平台不支援',
        'en': 'unsupported on this platform',
        'ja': 'このプラットフォームは未対応',
        'id': 'tidak didukung di platform ini',
        'es': 'no compatible con esta plataforma',
    },
    'tncErrNotConnected': {
        'zh': '链路未连接', 'zh_TW': '鏈路未連線', 'en': 'link not connected',
        'ja': 'リンク未接続', 'id': 'tautan belum tersambung',
        'es': 'enlace sin conectar',
    },
    'tncErrOpenRead': {
        'zh': '无法打开设备（读）', 'zh_TW': '無法開啟裝置（讀）',
        'en': 'cannot open device for reading',
        'ja': 'デバイスを読み取り用に開けません',
        'id': 'tidak bisa membuka perangkat untuk membaca',
        'es': 'no se puede abrir el dispositivo para lectura',
    },
    'tncErrOpenWrite': {
        'zh': '无法打开设备（写）—— Windows 的 COM 口是独占设备，检查是否被其他软件占用',
        'zh_TW': '無法開啟裝置（寫）—— Windows 的 COM 埠是獨佔裝置，檢查是否被其他軟體佔用',
        'en': 'cannot open device for writing — Windows COM ports are exclusive; check for another app holding it',
        'ja': 'デバイスを書き込み用に開けません。Windows の COM ポートは占有型です。他のソフトが使用していないか確認してください',
        'id': 'tidak bisa membuka perangkat untuk menulis — port COM Windows bersifat eksklusif; periksa aplikasi lain',
        'es': 'no se puede abrir el dispositivo para escritura: los puertos COM son exclusivos; comprueba si otra app lo usa',
    },
    'tncErrBadFormat': {
        'zh': '报文格式不合法', 'zh_TW': '報文格式不合法',
        'en': 'malformed packet', 'ja': 'パケット形式が不正',
        'id': 'paket tidak valid', 'es': 'paquete mal formado',
    },
    'tncErrFrameTooLong': {
        'zh': '帧长超出上限', 'zh_TW': '幀長超出上限',
        'en': 'frame exceeds the size limit',
        'ja': 'フレーム長が上限を超えています',
        'id': 'bingkai melebihi batas ukuran',
        'es': 'la trama supera el límite de tamaño',
    },
    'tncErrTimeout': {
        'zh': '连接超时', 'zh_TW': '連線逾時', 'en': 'timed out',
        'ja': 'タイムアウト', 'id': 'waktu habis', 'es': 'tiempo agotado',
    },
    # ── 翻译：通用 ──
    'translate': {
        'zh': '翻译', 'zh_TW': '翻譯', 'en': 'Translate',
        'ja': '翻訳', 'id': 'Terjemahkan', 'es': 'Traducir',
    },
    'translateText': {
        'zh': '翻译文本', 'zh_TW': '翻譯文字', 'en': 'Translate text',
        'ja': 'テキストを翻訳', 'id': 'Terjemahkan teks',
        'es': 'Traducir texto',
    },
    'translateSettings': {
        'zh': '翻译设置', 'zh_TW': '翻譯設定', 'en': 'Translation settings',
        'ja': '翻訳設定', 'id': 'Pengaturan terjemahan',
        'es': 'Ajustes de traducción',
    },
    'translateSettingsSubtitle': {
        'zh': '翻译接口、语言与自动翻译',
        'zh_TW': '翻譯介面、語言與自動翻譯',
        'en': 'Provider, languages and auto-translate',
        'ja': '翻訳プロバイダ、言語、自動翻訳',
        'id': 'Penyedia, bahasa, dan terjemahan otomatis',
        'es': 'Proveedor, idiomas y traducción automática',
    },
    'translateProvider': {
        'zh': '翻译接口', 'zh_TW': '翻譯介面', 'en': 'Provider',
        'ja': '翻訳プロバイダ', 'id': 'Penyedia',
        'es': 'Proveedor',
    },
    'translateProviderGoogle': {
        'zh': 'Google 翻译', 'zh_TW': 'Google 翻譯', 'en': 'Google Translate',
        'ja': 'Google 翻訳', 'id': 'Google Terjemahan',
        'es': 'Google Translate',
    },
    'translateProviderBaidu': {
        'zh': '百度翻译', 'zh_TW': '百度翻譯', 'en': 'Baidu Translate',
        'ja': 'Baidu 翻訳', 'id': 'Baidu Terjemahan',
        'es': 'Baidu Translate',
    },
    'translateProviderCustom': {
        'zh': '自定义', 'zh_TW': '自訂', 'en': 'Custom',
        'ja': 'カスタム', 'id': 'Kustom', 'es': 'Personalizado',
    },
    'translateGoogleKey': {
        'zh': 'Google API Key', 'zh_TW': 'Google API Key',
        'en': 'Google API key', 'ja': 'Google API キー',
        'id': 'Kunci API Google', 'es': 'Clave de API de Google',
    },
    'translateGoogleKeyTip': {
        'zh': 'Google Cloud Translation v2 的 API Key，需要自行到 Google Cloud 控制台申请',
        'zh_TW': 'Google Cloud Translation v2 的 API Key，需自行到 Google Cloud 主控台申請',
        'en': 'API key for Google Cloud Translation v2 — create one in the Google Cloud console',
        'ja': 'Google Cloud Translation v2 の API キー。Google Cloud コンソールで取得してください',
        'id': 'Kunci API untuk Google Cloud Translation v2 — buat di konsol Google Cloud',
        'es': 'Clave de API de Google Cloud Translation v2: créala en la consola de Google Cloud',
    },
    'translateBaiduAppId': {
        'zh': '百度 App ID', 'zh_TW': '百度 App ID', 'en': 'Baidu App ID',
        'ja': 'Baidu App ID', 'id': 'App ID Baidu', 'es': 'App ID de Baidu',
    },
    'translateBaiduKey': {
        'zh': '百度密钥', 'zh_TW': '百度密鑰', 'en': 'Baidu secret key',
        'ja': 'Baidu シークレットキー', 'id': 'Kunci rahasia Baidu',
        'es': 'Clave secreta de Baidu',
    },
    'translateBaiduTip': {
        'zh': '在百度翻译开放平台申请「通用文本翻译」，密钥只保存在本机',
        'zh_TW': '在百度翻譯開放平台申請「通用文本翻譯」，密鑰只保存在本機',
        'en': 'Apply for general text translation on the Baidu Translate platform; the key stays on this device',
        'ja': 'Baidu 翻訳オープンプラットフォームで「汎用テキスト翻訳」を申請してください。キーは端末内のみに保存されます',
        'id': 'Ajukan terjemahan teks umum di platform Baidu Translate; kunci hanya disimpan di perangkat ini',
        'es': 'Solicita traducción de texto general en la plataforma de Baidu; la clave se guarda solo en este dispositivo',
    },
    'translateCustomUrl': {
        'zh': '接口地址', 'zh_TW': '介面網址', 'en': 'Endpoint URL',
        'ja': 'エンドポイント URL', 'id': 'URL endpoint',
        'es': 'URL del endpoint',
    },
    'translateCustomMethod': {
        'zh': '请求方式', 'zh_TW': '請求方式', 'en': 'HTTP method',
        'ja': 'HTTP メソッド', 'id': 'Metode HTTP',
        'es': 'Método HTTP',
    },
    'translateCustomHeaders': {
        'zh': '请求头 (JSON)', 'zh_TW': '請求標頭 (JSON)',
        'en': 'Headers (JSON)', 'ja': 'ヘッダー (JSON)',
        'id': 'Header (JSON)', 'es': 'Cabeceras (JSON)',
    },
    'translateCustomBody': {
        'zh': '请求体模板', 'zh_TW': '請求主體範本', 'en': 'Body template',
        'ja': 'ボディテンプレート', 'id': 'Templat body',
        'es': 'Plantilla del cuerpo',
    },
    # 注意：这里刻意把 {text}/{from}/{to} 写成「真实占位符」，调用方传入的
    # 实参就是 "{text}" 这样的字面量。原因是 gen-l10n 会把字符串里的
    # {xxx} 一律解析为占位符（'{xxx}' 的单引号转义无效，实测仍会生成方法），
    # 与其绕开不如顺势用它 —— 译者看到的是有意义的占位符名，译文也能调语序。
    'translateCustomBodyTip': {
        'zh': '可用占位符：{text} 原文、{from} 源语言、{to} 目标语言。选择 GET 时忽略此项',
        'zh_TW': '可用佔位符：{text} 原文、{from} 來源語言、{to} 目標語言。選擇 GET 時忽略此項',
        'en': 'Placeholders: {text}, {from}, {to}. Ignored when the method is GET',
        'ja': '使用可能なプレースホルダ：{text} 原文、{from} 元の言語、{to} 翻訳先の言語。GET の場合は無視されます',
        'id': 'Placeholder: {text}, {from}, {to}. Diabaikan bila metode GET',
        'es': 'Marcadores: {text}, {from}, {to}. Se ignora con el método GET',
    },
    'translateCustomResultPath': {
        'zh': '结果字段路径', 'zh_TW': '結果欄位路徑', 'en': 'Result JSON path',
        'ja': '結果の JSON パス', 'id': 'Jalur JSON hasil',
        'es': 'Ruta JSON del resultado',
    },
    'translateCustomResultPathTip': {
        'zh': '用点号表示层级，数组用序号，如 data.translations.0.translatedText',
        'zh_TW': '用點號表示層級，陣列用序號，如 data.translations.0.translatedText',
        'en': 'Dot-separated path with array indexes, e.g. data.translations.0.translatedText',
        'ja': 'ドット区切りのパス、配列は番号。例 data.translations.0.translatedText',
        'id': 'Jalur dengan titik dan indeks larik, mis. data.translations.0.translatedText',
        'es': 'Ruta con puntos e índices de array, p. ej. data.translations.0.translatedText',
    },
    'translateTest': {
        'zh': '测试翻译', 'zh_TW': '測試翻譯', 'en': 'Test translation',
        'ja': '翻訳をテスト', 'id': 'Uji terjemahan',
        'es': 'Probar traducción',
    },
    'translateTestOk': {
        'zh': '接口可用：{text}', 'zh_TW': '介面可用：{text}',
        'en': 'Provider works: {text}', 'ja': 'プロバイダは利用可能：{text}',
        'id': 'Penyedia berfungsi: {text}',
        'es': 'El proveedor funciona: {text}',
    },
    'translateNeedConfig': {
        'zh': '请先填写翻译接口配置', 'zh_TW': '請先填寫翻譯介面設定',
        'en': 'Configure the translation provider first',
        'ja': '先に翻訳プロバイダを設定してください',
        'id': 'Konfigurasikan penyedia terjemahan lebih dulu',
        'es': 'Configura primero el proveedor de traducción',
    },
    'translateFailed': {
        'zh': '翻译失败：{e}', 'zh_TW': '翻譯失敗：{e}',
        'en': 'Translation failed: {e}', 'ja': '翻訳に失敗：{e}',
        'id': 'Terjemahan gagal: {e}', 'es': 'Falló la traducción: {e}',
    },
    'translateTargetLang': {
        'zh': '翻译为', 'zh_TW': '翻譯為', 'en': 'Translate into',
        'ja': '翻訳先', 'id': 'Terjemahkan ke',
        'es': 'Traducir a',
    },
    'translateSourceLang': {
        'zh': '原文语言', 'zh_TW': '原文語言', 'en': 'Source language',
        'ja': '原文の言語', 'id': 'Bahasa sumber',
        'es': 'Idioma de origen',
    },
    'translateAuto': {
        'zh': '自动翻译收到的消息', 'zh_TW': '自動翻譯收到的訊息',
        'en': 'Auto-translate incoming messages',
        'ja': '受信メッセージを自動翻訳',
        'id': 'Terjemahkan pesan masuk otomatis',
        'es': 'Traducir automáticamente los mensajes entrantes',
    },
    'translateAutoTip': {
        'zh': '仅对本会话生效；只翻译对方发来的消息',
        'zh_TW': '僅對本對話生效；只翻譯對方傳來的訊息',
        'en': 'Applies to this conversation only; translates received messages only',
        'ja': 'この会話のみに適用されます。受信メッセージだけを翻訳します',
        'id': 'Berlaku hanya untuk percakapan ini; hanya menerjemahkan pesan masuk',
        'es': 'Se aplica solo a esta conversación y solo traduce los mensajes recibidos',
    },
    'translateShowOriginal': {
        'zh': '显示原文', 'zh_TW': '顯示原文', 'en': 'Show original',
        'ja': '原文を表示', 'id': 'Tampilkan asli',
        'es': 'Ver original',
    },
    'translateShowTranslation': {
        'zh': '显示译文', 'zh_TW': '顯示譯文', 'en': 'Show translation',
        'ja': '訳文を表示', 'id': 'Tampilkan terjemahan',
        'es': 'Ver traducción',
    },
    'translateRetry': {
        'zh': '重新翻译', 'zh_TW': '重新翻譯', 'en': 'Translate again',
        'ja': '再翻訳', 'id': 'Terjemahkan ulang',
        'es': 'Traducir de nuevo',
    },
    'translateTranslating': {
        'zh': '正在翻译…', 'zh_TW': '正在翻譯…', 'en': 'Translating…',
        'ja': '翻訳中…', 'id': 'Menerjemahkan…', 'es': 'Traduciendo…',
    },
    'translateCopyOriginal': {
        'zh': '复制原文', 'zh_TW': '複製原文', 'en': 'Copy original',
        'ja': '原文をコピー', 'id': 'Salin asli',
        'es': 'Copiar original',
    },
    'translateCopyResult': {
        'zh': '复制译文', 'zh_TW': '複製譯文', 'en': 'Copy translation',
        'ja': '訳文をコピー', 'id': 'Salin terjemahan',
        'es': 'Copiar traducción',
    },
    'translateLangAuto': {
        'zh': '自动检测', 'zh_TW': '自動偵測', 'en': 'Auto detect',
        'ja': '自動検出', 'id': 'Deteksi otomatis',
        'es': 'Detectar automáticamente',
    },
    'translateSameLang': {
        'zh': '原文已是目标语言', 'zh_TW': '原文已是目標語言',
        'en': 'Already in the target language',
        'ja': 'すでに翻訳先の言語です',
        'id': 'Sudah dalam bahasa target',
        'es': 'Ya está en el idioma de destino',
    },
    'translateBubbleCount': {
        'zh': '已翻译 {n} 条', 'zh_TW': '已翻譯 {n} 條',
        'en': '{n} translated', 'ja': '{n} 件を翻訳',
        'id': '{n} diterjemahkan', 'es': '{n} traducidos',
    },
    'translatePrivacyNote': {
        'zh': '翻译会把消息文本发送到你选择的第三方接口，请自行评估隐私',
        'zh_TW': '翻譯會把訊息文字傳送到你選擇的第三方介面，請自行評估隱私',
        'en': 'Translation sends message text to the third-party provider you choose; assess privacy accordingly',
        'ja': '翻訳はメッセージ本文を選択した第三者のサービスへ送信します。プライバシーはご自身でご判断ください',
        'id': 'Terjemahan mengirim teks pesan ke penyedia pihak ketiga pilihan Anda; pertimbangkan privasi',
        'es': 'La traducción envía el texto de los mensajes al proveedor externo que elijas; valora la privacidad',
    },
}

PLACEHOLDERS = {
    'connTncConnected': {'arg': 'String'},
    'connTncPositionSent': {'arg': 'String'},
    'connRetryTnc': {'n': 'int'},
    'connRetryTncDetail': {'e': 'String', 'n': 'int'},
    'connTncLinkLost': {'n': 'int'},
    'translateCustomBodyTip': {
        'text': 'String',
        'from': 'String',
        'to': 'String',
    },
    'translateTestOk': {'text': 'String'},
    'translateFailed': {'e': 'String'},
    'translateBubbleCount': {'n': 'int'},
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
ANCHOR = '"codeContributionTranslation"'


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
            block.append('  "%s": %s,' % (key, json.dumps(tr[lang], ensure_ascii=False)))
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
