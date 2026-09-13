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
    # ── 双向翻译 + 对照显示 ──
    'translateMyLang': {
        'zh': '我的语言', 'zh_TW': '我的語言', 'en': 'My language',
        'ja': '自分の言語', 'id': 'Bahasa saya', 'es': 'Mi idioma',
    },
    'translateMyLangHint': {
        'zh': '对方发来的消息翻成它',
        'zh_TW': '對方傳來的訊息翻成它',
        'en': 'Messages from the other side are translated into this',
        'ja': '相手からのメッセージはこれを訳先にします',
        'id': 'Pesan dari lawan bicara diterjemahkan ke bahasa ini',
        'es': 'Los mensajes recibidos se traducen a este idioma',
    },
    'translatePeerLang': {
        'zh': '对方的语言', 'zh_TW': '對方的語言',
        'en': "The other party's language",
        'ja': '相手の言語', 'id': 'Bahasa lawan bicara',
        'es': 'Idioma de la otra parte',
    },
    'translatePeerUnknownHint': {
        'zh': '收到对方消息后由翻译接口自动识别',
        'zh_TW': '收到對方訊息後由翻譯介面自動識別',
        'en': 'Detected automatically from their messages',
        'ja': '相手のメッセージから自動判定します',
        'id': 'Dikenali otomatis dari pesan mereka',
        'es': 'Se detecta automáticamente en sus mensajes',
    },
    'translateLearned': {
        'zh': '已自动识别', 'zh_TW': '已自動識別',
        'en': 'Auto-detected', 'ja': '自動判定済み',
        'id': 'Terdeteksi otomatis', 'es': 'Detectado automáticamente',
    },
    'translatePeerUnknown': {
        'zh': '还不知道对方使用什么语言 · 先在翻译设置里指定，或收几条对方消息后会自动识别',
        'zh_TW': '還不知道對方使用什麼語言 · 先在翻譯設定裡指定，或收幾條對方訊息後會自動識別',
        'en': "The other party's language is still unknown — set it in translation settings, or it will be detected after a few of their messages",
        'ja': '相手の言語が不明です。翻訳設定で指定するか、相手のメッセージを数件受信すると自動判定されます',
        'id': 'Bahasa lawan bicara belum diketahui — atur di pengaturan terjemahan, atau akan terdeteksi setelah beberapa pesan mereka',
        'es': 'Aún no se conoce el idioma de la otra parte: indícalo en los ajustes de traducción o se detectará tras varios mensajes suyos',
    },
    'translateSideIncoming': {
        'zh': '对方发来', 'zh_TW': '對方傳來', 'en': 'received',
        'ja': '受信', 'id': 'diterima', 'es': 'recibido',
    },
    'translateSideOutgoing': {
        'zh': '我发出', 'zh_TW': '我發出', 'en': 'sent',
        'ja': '送信', 'id': 'terkirim', 'es': 'enviado',
    },
    'translateToMeTag': {
        'zh': '译给我看', 'zh_TW': '譯給我看', 'en': 'for me',
        'ja': '自分向け', 'id': 'untuk saya', 'es': 'para mí',
    },
    'translateToPeerTag': {
        'zh': '对方将读到', 'zh_TW': '對方將讀到',
        'en': 'what they read', 'ja': '相手が読む文',
        'id': 'yang mereka baca', 'es': 'lo que leerán',
    },
    'translateContrast': {
        'zh': '对照显示原文与译文', 'zh_TW': '對照顯示原文與譯文',
        'en': 'Show original and translation together',
        'ja': '原文と訳文を並べて表示',
        'id': 'Tampilkan asli dan terjemahan bersama',
        'es': 'Mostrar original y traducción juntos',
    },
    'translateContrastTip': {
        'zh': '关闭后只显示译文（原文仍可通过长按查看）',
        'zh_TW': '關閉後只顯示譯文（原文仍可透過長按查看）',
        'en': 'When off only the translation shows (long-press still reveals the original)',
        'ja': 'オフにすると訳文のみ表示（原文は長押しで確認できます）',
        'id': 'Jika mati hanya terjemahan yang tampil (aslinya lewat tekan lama)',
        'es': 'Si está desactivado solo se ve la traducción (el original sigue en pulsación larga)',
    },
    'translateProviderFree': {
        'zh': '免费接口（无需密钥）', 'zh_TW': '免費介面（無需密鑰）',
        'en': 'Free (no key needed)', 'ja': '無料（キー不要）',
        'id': 'Gratis (tanpa kunci)', 'es': 'Gratis (sin clave)',
    },
    'translateProviderFreeDesc': {
        'zh': '开箱即用 · 使用公开端点，可能被限流或不稳定',
        'zh_TW': '開箱即用 · 使用公開端點，可能被限流或不穩定',
        'en': 'Works out of the box · uses a public endpoint that may be rate-limited or unstable',
        'ja': 'すぐ使えます · 公開エンドポイントのため制限や不安定さがあります',
        'id': 'Langsung pakai · memakai endpoint publik yang bisa dibatasi atau tidak stabil',
        'es': 'Funciona sin configurar · usa un endpoint público que puede limitarse o ser inestable',
    },
    'translateFreeFailed': {
        'zh': '免费接口暂时不可用（{e}）· 可在设置里改用 Google / 百度 / 自定义接口',
        'zh_TW': '免費介面暫時無法使用（{e}）· 可在設定裡改用 Google / 百度 / 自訂介面',
        'en': 'The free endpoint is unavailable ({e}) · switch to Google / Baidu / a custom endpoint in settings',
        'ja': '無料エンドポイントが利用できません（{e}）· 設定で Google / Baidu / カスタムに切り替えられます',
        'id': 'Endpoint gratis sedang tidak tersedia ({e}) · ganti ke Google / Baidu / kustom di pengaturan',
        'es': 'El endpoint gratuito no está disponible ({e}) · cambia a Google / Baidu / personalizado en los ajustes',
    },
    'translateProviderAuto': {
        'zh': '自动（推荐）', 'zh_TW': '自動（推薦）', 'en': 'Automatic (recommended)',
        'ja': '自動（推奨）', 'id': 'Otomatis (disarankan)', 'es': 'Automático (recomendado)',
    },
    'translateProviderAutoDesc': {
        'zh': '依次尝试多个免密钥接口，取第一个真正翻译成功的结果',
        'zh_TW': '依次嘗試多個免密鑰介面，取第一個真正翻譯成功的結果',
        'en': 'Tries several keyless endpoints in turn and keeps the first real translation',
        'ja': '複数のキー不要エンドポイントを順に試し、実際に翻訳できた結果を採用します',
        'id': 'Mencoba beberapa endpoint tanpa kunci dan memakai hasil terjemahan pertama yang válid',
        'es': 'Prueba varios endpoints sin clave y usa la primera traducción válida',
    },
    'translateProviderGooglePublic': {
        'zh': 'Google 公开端点（免密钥）', 'zh_TW': 'Google 公開端點（免密鑰）',
        'en': 'Google public endpoint (keyless)',
        'ja': 'Google 公開エンドポイント（キー不要）',
        'id': 'Endpoint publik Google (tanpa kunci)',
        'es': 'Endpoint público de Google (sin clave)',
    },
    'translateProviderGooglePublicDesc': {
        'zh': '质量较好，但可能被限流（实测会返回 429）',
        'zh_TW': '品質較好，但可能被限流（實測會回傳 429）',
        'en': 'Good quality, but may be rate-limited (observed 429)',
        'ja': '品質は良好ですが、レート制限（429）を受けることがあります',
        'id': 'Kualitas baik, tetapi bisa dibatasi (teramati 429)',
        'es': 'Buena calidad, pero puede limitarse (se observó 429)',
    },
    'translateProviderMyMemory': {
        'zh': 'MyMemory（免密钥）', 'zh_TW': 'MyMemory（免密鑰）',
        'en': 'MyMemory (keyless)', 'ja': 'MyMemory（キー不要）',
        'id': 'MyMemory (tanpa kunci)', 'es': 'MyMemory (sin clave)',
    },
    'translateProviderMyMemoryDesc': {
        'zh': '官方免费接口，但本质是翻译记忆库：无匹配语料时会返回原文',
        'zh_TW': '官方免費介面，但本質是翻譯記憶庫：無匹配語料時會回傳原文',
        'en': 'Official free API, but it is a translation memory: returns the source text when it has no match',
        'ja': '公式の無料 API ですが翻訳メモリであり、一致がないと原文をそのまま返します',
        'id': 'API gratis resmi, tetapi berupa memori terjemahan: mengembalikan teks asli bila tidak ada kecocokan',
        'es': 'API gratuita oficial, pero es una memoria de traducción: devuelve el original si no hay coincidencia',
    },
    'translateProviderLibre': {
        'zh': 'LibreTranslate（可自建）', 'zh_TW': 'LibreTranslate（可自建）',
        'en': 'LibreTranslate (self-hostable)',
        'ja': 'LibreTranslate（自前ホスト可）',
        'id': 'LibreTranslate (bisa self-host)',
        'es': 'LibreTranslate (autoalojable)',
    },
    'translateProviderLibreDesc': {
        'zh': '开源、可自建最可靠；公共实例现已要求密钥且常不支持中文',
        'zh_TW': '開源、可自建最可靠；公共實例現已要求密鑰且常不支援中文',
        'en': 'Open source and most reliable self-hosted; public instances now need a key and often lack Chinese',
        'ja': 'オープンソースで自前ホストが最も確実。公共インスタンスはキーが必要で中国語非対応のことも多い',
        'id': 'Open source; paling andal bila di-self-host. Instans publik kini butuh kunci dan sering tanpa bahasa Tionghoa',
        'es': 'Código abierto; lo más fiable es autoalojarlo. Las instancias públicas ya piden clave y a menudo no tienen chino',
    },
    'translateLibreUrl': {
        'zh': '实例地址', 'zh_TW': '實例網址', 'en': 'Instance URL',
        'ja': 'インスタンス URL', 'id': 'URL instans', 'es': 'URL de la instancia',
    },
    'translateLibreKey': {
        'zh': '实例 API Key（公共实例需要，自建可留空）',
        'zh_TW': '實例 API Key（公共實例需要，自建可留空）',
        'en': 'Instance API key (needed for public instances; leave empty when self-hosted)',
        'ja': 'インスタンス API キー（公共は必要、自前ホストは空で可）',
        'id': 'Kunci API instans (perlu untuk publik; kosongkan bila self-host)',
        'es': 'Clave de API de la instancia (necesaria en públicas; vacía si es propia)',
    },
    'translateUsedProvider': {
        'zh': '本次实际使用', 'zh_TW': '本次實際使用', 'en': 'Actually used',
        'ja': '今回の使用先', 'id': 'Yang dipakai', 'es': 'Usado realmente',
    },
    'translateUntranslated': {
        'zh': '接口没有真正翻译（返回了原文）· 已自动尝试下一个接口',
        'zh_TW': '介面沒有真正翻譯（回傳了原文）· 已自動嘗試下一個介面',
        'en': 'The endpoint did not actually translate (it returned the source text) — tried the next one',
        'ja': 'エンドポイントが実際には翻訳していません（原文を返しました）。次の候補を試しました',
        'id': 'Endpoint tidak benar-benar menerjemahkan (mengembalikan teks asli) — mencoba yang berikutnya',
        'es': 'El endpoint no tradujo realmente (devolvió el original); se probó el siguiente',
    },
    'translateAutoAllFailed': {
        'zh': '所有免密钥接口都不可用（{e}）· 建议在设置里改用 Google / 百度密钥或自建实例',
        'zh_TW': '所有免密鑰介面都無法使用（{e}）· 建議在設定裡改用 Google / 百度密鑰或自建實例',
        'en': 'All keyless endpoints failed ({e}) · switch to a Google/Baidu key or your own instance in settings',
        'ja': 'キー不要のエンドポイントがすべて失敗しました（{e}）· 設定で Google / Baidu のキーか自前インスタンスに切り替えてください',
        'id': 'Semua endpoint tanpa kunci gagal ({e}) · beralih ke kunci Google/Baidu atau instans sendiri di pengaturan',
        'es': 'Fallaron todos los endpoints sin clave ({e}) · usa una clave de Google/Baidu o tu propia instancia en los ajustes',
    },
    'translateLangUnsupported': {
        'zh': '该接口不支持翻译成这一语言 · 可改用「自动」或其它接口',
        'zh_TW': '該介面不支援翻譯成這一語言 · 可改用「自動」或其它介面',
        'en': 'This provider cannot translate into that language · try “Automatic” or another provider',
        'ja': 'このプロバイダはその言語への翻訳に対応していません · 「自動」か別のプロバイダをお試しください',
        'id': 'Penyedia ini tidak bisa menerjemahkan ke bahasa itu · coba “Otomatis” atau penyedia lain',
        'es': 'Este proveedor no puede traducir a ese idioma · prueba «Automático» u otro proveedor',
    },
    'translateLangScopeNote': {
        'zh': '各接口支持的语种范围不同（例如百度标准版支持印尼语 id，但并非所有方向都支持）· 遇到不支持时会提示改用自动或其它接口',
        'zh_TW': '各介面支援的語種範圍不同（例如百度標準版支援印尼語 id，但並非所有方向都支援）· 遇到不支援時會提示改用自動或其它介面',
        'en': 'Providers differ in language coverage (e.g. Baidu standard supports Indonesian “id”, but not every direction) — when unsupported, the app suggests Automatic or another provider',
        'ja': 'プロバイダごとに対応語種が異なります（例：Baidu 標準版はインドネシア語 id に対応。ただし全方向ではありません）。非対応の場合は自動か別プロバイダを案内します',
        'id': 'Cakupan bahasa tiap penyedia berbeda (mis. Baidu standar mendukung bahasa Indonesia “id”, tetapi tidak semua arah) — bila tidak didukung, aplikasi menyarankan Otomatis atau penyedia lain',
        'es': 'Cada proveedor cubre idiomas distintos (p. ej. Baidu estándar admite indonesio «id», pero no todas las direcciones) — si no se admite, la app sugiere Automático u otro proveedor',
    },
    # ── 语言名称（跟随界面语言，而非永远显示自称） ──
    'langNameZh': {
        'zh': "简体中文",
        'zh_TW': "簡體中文",
        'en': "Chinese (Simplified)",
        'ja': "中国語（簡体）",
        'id': "Tionghoa Sederhana",
        'es': "chino simplificado",
    },
    'langNameZhTw': {
        'zh': "繁体中文",
        'zh_TW': "繁體中文",
        'en': "Chinese (Traditional)",
        'ja': "中国語（繁体）",
        'id': "Tionghoa Tradisional",
        'es': "chino tradicional",
    },
    'langNameEn': {
        'zh': "英语",
        'zh_TW': "英語",
        'en': "English",
        'ja': "英語",
        'id': "Inggris",
        'es': "inglés",
    },
    'langNameJa': {
        'zh': "日语",
        'zh_TW': "日語",
        'en': "Japanese",
        'ja': "日本語",
        'id': "Jepang",
        'es': "japonés",
    },
    'langNameKo': {
        'zh': "韩语",
        'zh_TW': "韓語",
        'en': "Korean",
        'ja': "韓国語",
        'id': "Korea",
        'es': "coreano",
    },
    'langNameEs': {
        'zh': "西班牙语",
        'zh_TW': "西班牙語",
        'en': "Spanish",
        'ja': "スペイン語",
        'id': "Spanyol",
        'es': "español",
    },
    'langNameFr': {
        'zh': "法语",
        'zh_TW': "法語",
        'en': "French",
        'ja': "フランス語",
        'id': "Prancis",
        'es': "francés",
    },
    'langNameDe': {
        'zh': "德语",
        'zh_TW': "德語",
        'en': "German",
        'ja': "ドイツ語",
        'id': "Jerman",
        'es': "alemán",
    },
    'langNameRu': {
        'zh': "俄语",
        'zh_TW': "俄語",
        'en': "Russian",
        'ja': "ロシア語",
        'id': "Rusia",
        'es': "ruso",
    },
    'langNamePt': {
        'zh': "葡萄牙语",
        'zh_TW': "葡萄牙語",
        'en': "Portuguese",
        'ja': "ポルトガル語",
        'id': "Portugis",
        'es': "portugués",
    },
    'langNameIt': {
        'zh': "意大利语",
        'zh_TW': "義大利語",
        'en': "Italian",
        'ja': "イタリア語",
        'id': "Italia",
        'es': "italiano",
    },
    'langNameId': {
        'zh': "印尼语",
        'zh_TW': "印尼語",
        'en': "Indonesian",
        'ja': "インドネシア語",
        'id': "Indonesia",
        'es': "indonesio",
    },
    'langNameTh': {
        'zh': "泰语",
        'zh_TW': "泰語",
        'en': "Thai",
        'ja': "タイ語",
        'id': "Thai",
        'es': "tailandés",
    },
    'langNameVi': {
        'zh': "越南语",
        'zh_TW': "越南語",
        'en': "Vietnamese",
        'ja': "ベトナム語",
        'id': "Vietnam",
        'es': "vietnamita",
    },
    'langNameAr': {
        'zh': "阿拉伯语",
        'zh_TW': "阿拉伯語",
        'en': "Arabic",
        'ja': "アラビア語",
        'id': "Arab",
        'es': "árabe",
    },
    # ── 发送前翻译（把输入译成对方语言后发出） ──
    'translateOutgoing': {
        'zh': '发送前翻译成对方的语言', 'zh_TW': '傳送前翻譯成對方的語言',
        'en': "Translate into their language before sending",
        'ja': '送信前に相手の言語へ翻訳',
        'id': 'Terjemahkan ke bahasa mereka sebelum mengirim',
        'es': 'Traducir a su idioma antes de enviar',
    },
    'translateOutgoingTip': {
        'zh': '开启后按发送会先把内容译成对方的语言再发出；请确认对方能读懂该语言',
        'zh_TW': '開啟後按傳送會先把內容譯成對方的語言再發出；請確認對方能讀懂該語言',
        'en': 'With this on, sending first translates the text into their language — make sure they can read it',
        'ja': 'オンにすると送信時に相手の言語へ翻訳してから送信します。相手が読める言語か確認してください',
        'id': 'Jika aktif, teks diterjemahkan ke bahasa mereka sebelum dikirim — pastikan mereka bisa membacanya',
        'es': 'Si está activado, al enviar se traduce el texto a su idioma: comprueba que puedan leerlo',
    },
    'translateInput': {
        'zh': '翻译输入内容', 'zh_TW': '翻譯輸入內容',
        'en': 'Translate the input', 'ja': '入力を翻訳',
        'id': 'Terjemahkan isi', 'es': 'Traducir lo escrito',
    },
    'translateOutPreview': {
        'zh': '将发送：{text}', 'zh_TW': '將傳送：{text}',
        'en': 'Will send: {text}', 'ja': '送信内容：{text}',
        'id': 'Akan dikirim: {text}', 'es': 'Se enviará: {text}',
    },
    'translateOutPreviewHint': {
        'zh': '已译为 {lang} · 点发送即按此发出',
        'zh_TW': '已譯為 {lang} · 點傳送即按此發出',
        'en': 'Translated into {lang} · tap send to transmit this',
        'ja': '{lang} に翻訳済み · 送信でこの内容を発信します',
        'id': 'Diterjemahkan ke {lang} · ketuk kirim untuk mengirim ini',
        'es': 'Traducido a {lang} · toca enviar para transmitir esto',
    },
    'translateOutCancel': {
        'zh': '取消翻译', 'zh_TW': '取消翻譯', 'en': 'Cancel translation',
        'ja': '翻訳を取消', 'id': 'Batalkan terjemahan',
        'es': 'Cancelar traducción',
    },
    'translateOutNeedPeer': {
        'zh': '还不知道对方使用什么语言 · 先在会话翻译设置里指定',
        'zh_TW': '還不知道對方使用什麼語言 · 先在對話翻譯設定裡指定',
        'en': "Their language is still unknown — set it in the conversation's translation settings",
        'ja': '相手の言語が不明です。会話の翻訳設定で指定してください',
        'id': 'Bahasa mereka belum diketahui — atur di pengaturan terjemahan percakapan',
        'es': 'Aún no se conoce su idioma: indícalo en los ajustes de traducción de la conversación',
    },
    'translateSentAs': {
        'zh': '已按对方语言发出：{text}',
        'zh_TW': '已按對方語言發出：{text}',
        'en': 'Sent in their language: {text}',
        'ja': '相手の言語で送信：{text}',
        'id': 'Dikirim dalam bahasa mereka: {text}',
        'es': 'Enviado en su idioma: {text}',
    },
    'translateTooLongAfter': {
        'zh': '译文超出长度上限（{n} 字符），未发送',
        'zh_TW': '譯文超出長度上限（{n} 字元），未傳送',
        'en': 'Translation exceeds the length limit ({n} chars) — not sent',
        'ja': '訳文が長さ上限（{n} 文字）を超えたため送信しません',
        'id': 'Terjemahan melebihi batas panjang ({n} karakter) — tidak dikirim',
        'es': 'La traducción supera el límite ({n} caracteres); no se envió',
    },
    # ── 聊天日期分界线 ──
    'dateToday': {
        'zh': '今天', 'zh_TW': '今天', 'en': 'Today',
        'ja': '今日', 'id': 'Hari ini', 'es': 'Hoy',
    },
    'dateYesterday': {
        'zh': '昨天', 'zh_TW': '昨天', 'en': 'Yesterday',
        'ja': '昨日', 'id': 'Kemarin', 'es': 'Ayer',
    },
    'dateDividerFull': {
        'zh': '{y}年{m}月{d}日 {w}', 'zh_TW': '{y}年{m}月{d}日 {w}',
        'en': '{m}/{d}/{y} {w}', 'ja': '{y}年{m}月{d}日 {w}',
        'id': '{d}/{m}/{y} {w}', 'es': '{d}/{m}/{y} {w}',
    },
    'dateWeekday': {
        'zh': '{d, select, 1 {周一} 2 {周二} 3 {周三} 4 {周四} 5 {周五} 6 {周六} 7 {周日} other {—}}',
        'zh_TW': '{d, select, 1 {週一} 2 {週二} 3 {週三} 4 {週四} 5 {週五} 6 {週六} 7 {週日} other {—}}',
        'en': '{d, select, 1 {Mon} 2 {Tue} 3 {Wed} 4 {Thu} 5 {Fri} 6 {Sat} 7 {Sun} other {—}}',
        'ja': '{d, select, 1 {月} 2 {火} 3 {水} 4 {木} 5 {金} 6 {土} 7 {日} other {—}}',
        'id': '{d, select, 1 {Sen} 2 {Sel} 3 {Rab} 4 {Kam} 5 {Jum} 6 {Sab} 7 {Min} other {—}}',
        'es': '{d, select, 1 {lun} 2 {mar} 3 {mié} 4 {jue} 5 {vie} 6 {sáb} 7 {dom} other {—}}',
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
    'translateFreeFailed': {'e': 'String'},
    'translateAutoAllFailed': {'e': 'String'},
    'translateOutPreview': {'text': 'String'},
    'translateOutPreviewHint': {'lang': 'String'},
    'translateSentAs': {'text': 'String'},
    'translateTooLongAfter': {'n': 'int'},
    'translateTestOk': {'text': 'String'},
    'translateFailed': {'e': 'String'},
    'translateBubbleCount': {'n': 'int'},
    'dateDividerFull': {'y': 'int', 'm': 'int', 'd': 'int', 'w': 'String'},
    # gen-l10n 要求 select 的占位符是 String（与既有 weatherWeekday 一致），
    # 所以 weekday 以字符串形式传入
    'dateWeekday': {'d': 'String'},
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
            # 兼容早期下划线键名（langName_xx）——改用 camelCase 后需清掉旧键
            if st.startswith('"langName_') or st.startswith('"langNamezhTw"'):
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
