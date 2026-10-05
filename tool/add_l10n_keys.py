#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""往 6 个语言加 l10n 键（arb 真源 + 抽象类 + gen-l10n 产物），**幂等**。

## 为什么固化成工具

我（AI）在 1.6.165/166 这两轮里手写了 4 次「往 arb 追加键」的临时脚本，
每次都错在**同一个地方**：追加多个键时只在最后一个处理了逗号 ——

  * 追加 2~3 个键 → 第 1 个键行尾少逗号 → 整个 arb **JSON 语法坏掉**
    （`Expecting ',' delimiter`），而 `check_l10n_sync` 会以「解析失败」报出来。

手写这种「字符串拼 JSON」的活**必然**漂。所以做成工具：以后加键只改下面的 KEYS。

## 用法

    python3 tool/add_l10n_keys.py

改 KEYS 里的内容再跑即可；已存在的键会跳过（幂等），所以可以反复跑。
带占位符的键在 META 里声明（gen-l10n 需要 `@key.placeholders`）。
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

# ── 要加的键：key → (zh, zh_TW, en, ja, es, id) ──
KEYS = {
    # ── 强制接受网络定位自动上报（v1.6.177 用户要求：「在信标上报页面留一个按钮，
    # 可开启强制接受网络定位自动上报」）──
    #
    # 背景：v1.6.163 起粗定位（网络/基站/被动）**不自动上报**（粗点常偏几百米，
    # 发出去的是错坐标）。但「手里这台设备没有 GPS」的用户（平板/只有网络定位的
    # 机器/长期室内）就变成「永远不会自动上报」，而界面上只写着「网络定位中」
    # —— 他们没有任何办法打开它。这组文案就是那个开关。
    'beaconForceCoarse': (
        '强制接受网络定位自动上报', '強制接受網路定位自動上報',
        'Beacon network (coarse) fixes anyway',
        'ネットワーク測位でも自動送信する',
        'Balizar también con posición de red (gruesa)',
        'Tetap pancarkan posisi jaringan (kasar)',
    ),
    # 取舍要写清：这个开关换来的是「能发」，代价是「发的是粗坐标」。
    'beaconForceCoarseHint': (
        '默认不开启：网络定位（基站 / Wi-Fi）常偏几百米，自动发出去等于向全网宣告一个错坐标。'
        '只有设备没有 GPS（平板 / 只有网络定位）时才建议打开 —— 打开后粗定位也会自动发射；'
        '地图与轨迹仍按原样过滤粗点，不会因此变乱。手动「立即上报」不受这个开关影响。',
        '預設不開啟：網路定位（基地台 / Wi-Fi）常偏幾百公尺，自動發出去等於向全網宣告一個錯座標。'
        '只有裝置沒有 GPS（平板 / 只有網路定位）時才建議打開 —— 打開後粗定位也會自動發射；'
        '地圖與軌跡仍照原樣過濾粗點，不會因此變亂。手動「立即上報」不受這個開關影響。',
        'Off by default: network fixes (cell / Wi-Fi) are often hundreds of metres off, so beaconing '
        'them announces a wrong coordinate to everyone. Turn this on only when the device has no GPS '
        '(tablet, network-only). Coarse points are still filtered the usual way for the map and '
        'track, so those do not get jumpy. Manual "beacon now" is unaffected.',
        '既定ではオフ：ネットワーク測位（基地局 / Wi-Fi）は数百メートルずれることが多く、'
        '自動送信すると誤った座標を全員に知らせることになります。GPS の無い端末（タブレットなど）'
        'でのみオンにしてください。地図と軌跡は従来どおり粗い点を除外するので乱れません。'
        '手動の「今すぐ送信」はこのスイッチの影響を受けません。',
        'Desactivado por defecto: la posición de red (celda / Wi-Fi) suele fallar cientos de metros, '
        'así que balizarla anuncia una coordenada errónea a todos. Actívalo solo si el dispositivo no '
        'tiene GPS (tableta, solo red). El mapa y la traza siguen filtrando los puntos gruesos como '
        'siempre, así que no se vuelven inestables. El "balizar ahora" manual no se ve afectado.',
        'Mati secara bawaan: posisi jaringan (sel / Wi-Fi) sering meleset ratusan meter, jadi '
        'memancarkannya berarti mengumumkan koordinat yang salah ke semua orang. Nyalakan hanya bila '
        'perangkat tidak punya GPS (tablet, hanya jaringan). Peta dan jejak tetap menyaring titik '
        'kasar seperti biasa, jadi tidak ikut kacau. "Pancarkan sekarang" manual tidak terpengaruh.',
    ),
    # 强制档下的横杠文案：会发射，所以给真实倒计时；要点明「发的是网络定位」。
    'beaconCoarseForced': (
        '网络定位（粗）· {s}', '網路定位（粗）· {s}',
        'Network fix (coarse) · {s}', 'ネットワーク測位（粗）· {s}',
        'Posición de red (gruesa) · {s}', 'Posisi jaringan (kasar) · {s}',
    ),
    # 不带倒计时的短句（沉浸页 / 我的位置面板 / 设置页提示条）。
    'beaconCoarseForcedNote': (
        '正在用网络定位（粗）上报', '正在用網路定位（粗）上報',
        'Beaconing a network (coarse) fix',
        'ネットワーク測位（粗）で送信中',
        'Balizando con posición de red (gruesa)',
        'Memancarkan posisi jaringan (kasar)',
    ),
    # ── 「发射」按钮：填了 PHG 却没有定位时的如实回执 ──
    #
    # 位置报文在 [AppState.sendBeacon] 里被 `!myHasFix` 拦下（没坐标不能发位置包），
    # 而「发射」按钮无条件发状态帧 —— 于是用户填好功率/增益点一下，只发出一帧
    # 状态报文，界面却什么也没说。这一句就是把「位置那半截为什么没发」说出来。
    'txNoFixKeptStatus': (
        '已发射：{parts}（还没有定位，带 PHG 的位置报文没能发出）',
        '已發射：{parts}（還沒有定位，帶 PHG 的位置報文沒能發出）',
        'Sent: {parts} (no fix yet - the position packet with PHG was not sent)',
        '送信しました：{parts}（測位がないため PHG 付きの位置パケットは送信されませんでした）',
        'Enviado: {parts} (sin posición todavía: el paquete de posición con PHG no se envió)',
        'Terkirim: {parts} (belum ada posisi - paket posisi dengan PHG tidak dikirim)',
    ),
    # ── 状态报文自己的连接状态文案 ──
    #
    # 此前 sendStatus() 复用「位置已上报」那三档 → 状态下发出去后主横幅却写着
    # 「位置已上报」，而一个位置包都没发。状态帧与位置帧是两种报文，文案必须分开。
    'connStatusSent': (
        '已连接 · 状态报文已发送 ({call})', '已連線 · 狀態報文已發送 ({call})',
        'Connected · Status packet sent ({call})',
        '接続済み · ステータスパケット送信済み ({call})',
        'Conectado · paquete de estado enviado ({call})',
        'Terhubung · paket status terkirim ({call})',
    ),
    'connTncStatusSent': (
        'TNC 已连接 · 状态报文已发送 ({arg})', 'TNC 已連線 · 狀態報文已發送 ({arg})',
        'TNC connected · status packet sent ({arg})',
        'TNC 接続済み · ステータスパケット送信済み ({arg})',
        'TNC conectado · paquete de estado enviado ({arg})',
        'TNC terhubung · paket status terkirim ({arg})',
    ),
    'connAudioStatusSent': (
        '音频已发射 · 状态报文已发送 ({call})', '音訊已發射 · 狀態報文已發送 ({call})',
        'Sent over audio · status packet sent ({call})',
        'オーディオ送信済み · ステータスパケット送信済み ({call})',
        'Enviado por audio · paquete de estado enviado ({call})',
        'Terkirim via audio · paket status terkirim ({call})',
    ),
    # ── 关于页「代码贡献」里 BH7GZB 那一行的标签 ──
    # 原来那一节的三行标签都是「具体做了什么」（国际化 / 繁体中文界面 / 翻译），
    # 而这位的贡献是**位置报文数据扩展与独立状态报文**（PR #11）—— 没有现成键能覆盖。
    # 为什么不复用 settingsContribCodeOptimization（「代码优化」）：那是清零（BG2HCB）
    # 的专属描述，套到别人身上等于张冠李戴。
    'codeContribution': (
        '贡献代码', '貢獻程式碼', 'Code contribution',
        'コード貢献', 'Contribución de código', 'Kontribusi kode',
    ),
    # ── 更新页「选择安装包」（v2.0.11：安卓改成按 ABI 分三个包发布）──
    #
    # 更新页原来只说一句「APK 安装包 <大小>」，而 Release 里现在有**三个**包
    # （64 位 / 32 位 / x86_64）。32 位老机型与模拟器用户从那句话里看不出还有
    # 适合自己的包，而应用内更新只会下 64 位那个（也装不上）。
    # 这三条就是那个「选择安装包」区：标题、推荐标记、以及一句解释。
    'choosePackage': (
        '选择安装包', '選擇安裝包', 'Choose a package',
        'パッケージを選ぶ', 'Elegir paquete', 'Pilih paket',
    ),
    'pkgRecommended': (
        '推荐', '建議', 'Recommended',
        '推奨', 'Recomendado', 'Disarankan',
    ),
    # 说清「点一行会怎样」，否则用户会以为点一下就在应用内换包下载（不是）。
    'choosePackageHint': (
        '64 位包用于绝大多数手机（应用内更新下的是这个）；带 _armeabi-v7a 的是 32 位老机型；'
        '_x86_64 只用于模拟器 / Chromebook。点一行会打开该包的下载地址。',
        '64 位元套件用於絕大多數手機（應用程式內更新下載的是這個）；帶 _armeabi-v7a 的是 32 位元舊機型；'
        '_x86_64 只用於模擬器 / Chromebook。點一列會開啟該套件的下載網址。',
        'The 64-bit package covers almost every phone (this is what the in-app update fetches); '
        '_armeabi-v7a is for older 32-bit devices; _x86_64 is only for emulators / Chromebooks. '
        'Tapping a row opens that package\'s download URL.',
        '64 ビット版はほとんどのスマホ向け（アプリ内更新が取得するのはこれです）。'
        '_armeabi-v7a は古い 32 ビット機、_x86_64 はエミュレータ / Chromebook 専用です。'
        '行をタップするとそのパッケージのダウンロード先を開きます。',
        'El paquete de 64 bits sirve para casi todos los teléfonos (es el que descarga la '
        'actualización integrada); _armeabi-v7a es para equipos antiguos de 32 bits; _x86_64 '
        'solo para emuladores / Chromebooks. Toca una fila para abrir la descarga de ese paquete.',
        'Paket 64-bit untuk hampir semua ponsel (inilah yang diunduh pembaruan dalam aplikasi); '
        '_armeabi-v7a untuk perangkat 32-bit lama; _x86_64 hanya untuk emulator / Chromebook. '
        'Ketuk satu baris untuk membuka tautan unduhan paket itu.',
    ),
    # ── 生命守护增强（issue #32：强化生命守护 + 优化生命守护算法）──
    #
    # 「强提醒」：说明碰撞/摔倒与心率异常会发**高优先级**通知（响铃/震动/横幅），
    # 因为弹窗在手机放兜里时看不见。
    'lifeGuardStrongHint': (
        '告警会通过**高优先级系统通知**提醒（响铃 / 震动 / 锁屏横幅），不只是应用内弹窗 —— '
        '手机放在兜里或没看屏幕时，弹窗是看不见的。请确保系统允许本应用通知，并关闭该通知渠道的免打扰。',
        '告警會透過**高優先級系統通知**提醒（響鈴 / 震動 / 鎖屏橫幅），不只是應用程式內彈窗 —— '
        '手機放在口袋或沒看螢幕時，彈窗是看不見的。請確認系統允許本應用程式通知，並關閉該通知管道的勿擾。',
        'Alarms also fire a **high-priority system notification** (sound / vibration / '
        'lock-screen banner), not just an in-app dialog — a dialog is invisible with the phone in '
        'your pocket. Please allow notifications for this app and keep this channel out of Do Not Disturb.',
        'アラームは**優先度の高いシステム通知**（音 / 振動 / ロック画面バナー）でも鳴ります。'
        'アプリ内ダイアログだけでは、ポケットの中や画面を見ていないときに気づけません。'
        '本アプリの通知を許可し、このチャンネルをサイレントにしないでください。',
        'Las alarmas también emiten una **notificación de sistema de alta prioridad** '
        '(sonido / vibración / aviso en pantalla de bloqueo), no solo un diálogo dentro de la app: '
        'un diálogo es invisible con el teléfono en el bolsillo. Permite las notificaciones de la '
        'app y mantén este canal fuera de No molestar.',
        'Alarm juga memicu **notifikasi sistem prioritas tinggi** (bunyi / getar / spanduk layar '
        'kunci), bukan sekadar dialog dalam aplikasi — dialog tidak terlihat saat ponsel di saku. '
        'Izinkan notifikasi untuk aplikasi ini dan jangan masukkan kanal ini ke Jangan Ganggu.',
    ),
    # 灵敏度的档位标签与说明。
    'crashSensitivity': (
        '检测灵敏度', '偵測靈敏度', 'Detection sensitivity',
        '検出感度', 'Sensibilidad de detección', 'Sensitivitas deteksi',
    ),
    'crashSensGentle': (
        '灵敏', '靈敏', 'Sensitive',
        '敏感', 'Sensible', 'Peka',
    ),
    'crashSensStandard': (
        '标准', '標準', 'Standard',
        '標準', 'Estándar', 'Standar',
    ),
    'crashSensFirm': (
        '抗颠簸', '抗顛簸', 'Firm',
        '振動に強い', 'Firme', 'Kuat',
    ),
    'crashSensHint': (
        '阈值固定不了：手机放裤兜里骑车，正常颠簸就能越过灵敏档；固定在车把上就该用抗颠簸档，'
        '否则一路都在误报。默认「标准」。灵敏度只影响**检测**（哪个撞击算数），不影响后续的告警动作。',
        '閾值固定不了：手機放褲袋騎車，正常顛簸就能越過靈敏檔；固定在車把上就該用抗顛簸檔，'
        '否則一路都在誤報。預設「標準」。靈敏度只影響**偵測**（哪個撞擊算數），不影響後續的告警動作。',
        'A fixed threshold cannot fit everyone: a phone in a cycling pocket trips the sensitive '
        'setting on every bump, while a bar-mounted phone needs the firm setting or it false-alarms '
        'the whole ride. Default is Standard. Sensitivity only affects **detection** (which impact '
        'counts), not what the alarm does afterwards.',
        '固定のしきい値では合いません。ポケットのスマホは敏感だと段差ごとに反応し、'
        'ハンドル固定なら「振動に強い」にしないと走行中ずっと誤報します。既定は「標準」。'
        '感度は**検出**（どの衝撃を数えるか）だけに効き、その後の動作には影響しません。',
        'Un umbral fijo no sirve para todos: un teléfono en el bolsillo dispara el ajuste sensible '
        'con cada bache, mientras que uno fijado al manillar necesita el ajuste firme o dará falsas '
        'alarmas todo el trayecto. Por defecto: Estándar. La sensibilidad solo afecta a la '
        '**detección** (qué impacto cuenta), no a lo que hace la alarma después.',
        'Ambang tetap tidak cocok untuk semua: ponsel di saku memicu setelan peka pada setiap '
        'guncangan, sedangkan ponsel terpasang di setang perlu setelan kuat agar tidak salah alarm '
        'sepanjang perjalanan. Bawaan: Standar. Sensitivitas hanya memengaruhi **deteksi** '
        '(benturan mana yang dihitung), bukan tindakan alarm setelahnya.',
    ),
    # 摔倒的告警标题/正文（与碰撞区分：冲击前有自由落体）。
    'crashFallAlarmTitle': (
        '检测到疑似摔倒', '偵測到疑似摔倒', 'Possible fall detected',
        '転倒の可能性を検知', 'Posible caída detectada', 'Kemungkinan terjatuh terdeteksi',
    ),
    'crashFallAlarmBody': (
        '手机先自由落体、随后一次落地冲击，再之后一直没有明显移动（约 12 秒）—— 这是摔倒的典型加速度特征。\n\n'
        '如果你没事，按「我没事」即可；如果身体不适或无法行动，请立即拨打急救电话，或向附近 100 公里内的台站发出求助信息。\n\n'
        '**这是启发式判断，不是工程级检测**：手机从口袋/手里掉到地上也可能满足。',
        '手機先自由落體、隨後一次落地衝擊，再之後一直沒有明顯移動（約 12 秒）—— 這是摔倒的典型加速度特徵。\n\n'
        '如果你沒事，按「我沒事」即可；如果身體不適或無法行動，請立即撥打急救電話，或向附近 100 公里內的臺站發出求助訊息。\n\n'
        '**這是啟發式判斷，不是工程級偵測**：手機從口袋/手裡掉到地上也可能滿足。',
        'The phone free-fell, then took a landing impact, then stayed still for about 12 seconds — '
        'the classic acceleration signature of a fall.\n\nIf you are fine, tap "I\'m OK"; if you are '
        'unwell or cannot move, call emergency services now or send a help message to stations '
        'within 100 km.\n\n**This is a heuristic, not engineering-grade detection**: dropping the '
        'phone from a pocket or hand can also match it.',
        'スマホが自由落下したあとに着地衝撃、その後に約 12 秒間ほとんど動かない —— '
        '転倒に典型的な加速度パターンです。\n\n問題なければ「大丈夫」を押してください。体調が悪い、'
        'または動けない場合は、すぐに救急へ電話するか、100 km 以内の局へ救助メッセージを送ってください。\n\n'
        '**これはヒューリスティックであり、工学レベルの検出ではありません**：ポケットや手から'
        '落としただけでも該当します。',
        'El teléfono cayó libremente, luego sufrió un impacto de aterrizaje y después estuvo quieto '
        'unos 12 segundos: la firma de aceleración típica de una caída.\n\nSi estás bien, pulsa '
        '"Estoy bien"; si te encuentras mal o no puedes moverte, llama ahora a emergencias o envía '
        'un mensaje de ayuda a las estaciones a menos de 100 km.\n\n**Es una heurística, no una '
        'detección de nivel ingenieril**: dejarse caer el teléfono desde el bolsillo o la mano '
        'también puede cumplirla.',
        'Ponsel jatuh bebas, lalu menerima benturan saat mendarat, lalu tidak bergerak sekitar 12 '
        'detik — pola akselerasi khas terjatuh.\n\nJika Anda baik-baik saja, ketuk "Saya baik"; '
        'jika Anda tidak enak badan atau tidak bisa bergerak, segera hubungi layanan darurat atau '
        'kirim pesan bantuan ke stasiun dalam 100 km.\n\n**Ini heuristik, bukan deteksi sekelas '
        'rekayasa**: ponsel yang terlepas dari saku atau tangan juga bisa memicunya.',
    ),
    # 算法增强说明（issue #32）：把「摔倒 vs 碰撞」的判据讲清，并点明新增的自由落体段。
    'crashKindHint': (
        '现在会顺便区分**碰撞**与**摔倒**：摔倒几乎总是先有一段自由落体（模接近 0），'
        '再是落地冲击；车祸撞击没有那一段。所以在原有「冲击 + 随后静止」之外，'
        '再看冲击前有没有自由落体 —— 有就按「摔倒」提醒，没有就按「碰撞」。'
        '这只改**提示文字与图标**，两类的处理方式完全一样（都是我没事 / 打电话 / 求助）。',
        '現在會順便區分**碰撞**與**摔倒**：摔倒幾乎總是先有一段自由落體（模接近 0），'
        '再是落地衝擊；車禍撞擊沒有那一段。所以在原有「衝擊 + 隨後靜止」之外，'
        '再看衝擊前有沒有自由落體 —— 有就按「摔倒」提醒，沒有就按「碰撞」。'
        '這只改**提示文字與圖示**，兩類的處理方式完全一樣（都是我沒事 / 打電話 / 求助）。',
        'It now also tells **crashes** and **falls** apart: a fall almost always starts with a '
        'brief free fall (magnitude near 0) before the landing impact, whereas a vehicle crash does '
        'not. So beyond the existing "impact + then still", it also checks for a free fall just '
        'before the impact — present means a fall, absent means a crash. This only changes the '
        '**wording and icon**; both are handled exactly the same (I\'m OK / call / ask for help).',
        '**衝突**と**転倒**も見分けます。転倒は着地衝撃の前にほぼ必ず自由落下（大きさが 0 付近）が'
        'あり、車の衝突にはそれがありません。従来の「衝撃 + その後の静止」に加えて、'
        '衝撃の直前に自由落下があったかを見ます（あれば転倒、なければ衝突）。'
        '変わるのは**文言とアイコン**だけで、対応はどちらも同じ（大丈夫 / 電話 / 救援要請）です。',
        'Ahora también distingue **choques** de **caídas**: una caída casi siempre empieza con una '
        'breve caída libre (magnitud cerca de 0) antes del impacto, mientras que un choque de '
        'vehículo no. Así, además del "impacto + luego quieto", comprueba si hubo caída libre justo '
        'antes del impacto: si la hay, es caída; si no, choque. Solo cambia el **texto y el icono**; '
        'ambos se tratan igual (Estoy bien / llamar / pedir ayuda).',
        'Kini juga membedakan **benturan** dan **terjatuh**: terjatuh hampir selalu dimulai dengan '
        'jatuh bebas singkat (magnitudo mendekati 0) sebelum benturan mendarat, sedangkan benturan '
        'kendaraan tidak. Jadi selain "benturan + lalu diam", sistem juga memeriksa apakah ada jatuh '
        'bebas tepat sebelum benturan — ada berarti terjatuh, tidak ada berarti benturan. Ini hanya '
        'mengubah **teks dan ikon**; keduanya ditangani sama (Saya baik / telepon / minta bantuan).',
    ),
}

# ── 占位符声明（可空）──
META = {
    'beaconCoarseForced': '{"placeholders": {"s": {"type": "String"}}}',
    'txNoFixKeptStatus': '{"placeholders": {"parts": {"type": "String"}}}',
    'connStatusSent': '{"placeholders": {"call": {"type": "String"}}}',
    'connTncStatusSent': '{"placeholders": {"arg": {"type": "String"}}}',
    'connAudioStatusSent': '{"placeholders": {"call": {"type": "String"}}}',
}


def _params(key):
    """从 META 里抠出这个键的占位符名字。"""
    raw = META.get(key)
    if not raw:
        return []
    try:
        return list(json.loads(raw).get('placeholders', {}).keys())
    except Exception:
        return []


def member(key):
    """产出的成员签名：无占位符 → `get key`；有 → `key(String a, String b)`。

    ⚠ 这是一处真实缺陷的修法（v1.6.177）：本函数以前一律写 getter，于是带占位符
    的键被写成 `String get x => "... {s}";` —— **本机** `S.of(context).x(y)` 报
    not_a_function，而 CI 的 `pub get` 会按 arb 重新生成产物，于是 CI 全绿、
    问题被盖住（正是本仓库最熟悉的「我这儿有错、CI 却是绿的」）。
    产物必须与 gen-l10n 同形：带占位符就是**带参数的方法**。
    """
    ps = _params(key)
    if not ps:
        return 'get %s' % key
    return '%s(%s)' % (key, ', '.join('String ' + x for x in ps))


def interp(key, text):
    """把 `{x}` 换成 Dart 插值 `$x`（与 gen-l10n 的产物一致）。"""
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


def add_lines(text, lines):
    """把若干 `  "key": value` 行插到顶层 } 之前。

    ⚠ 逗号规则是这里唯一的坑：插入的每一行**之间**都要有逗号，
    而**最后一行后面不能有**（紧接着就是 }）。
    """
    if not lines:
        return text
    i = text.rstrip().rfind('}')
    head = text[:i].rstrip()
    if head.endswith(','):
        head = head[:-1]          # 去掉原末尾逗号，最后统一按需补
    body = ',\n'.join(l.rstrip().rstrip(',') for l in lines)
    return head + ',\n' + body + '\n' + text[i:]


def main() -> int:
    if not KEYS:
        print('KEYS 是空的 —— 请先在脚本里填要加的键')
        return 0
    for lg in LANGS:
        p = os.path.join(ROOT, 'lib', 'l10n', 'app_%s.arb' % lg)
        t = io.open(p, encoding='utf-8', newline='').read()
        add = []
        for k, v in KEYS.items():
            if '"%s":' % k in t:
                continue
            add.append('  %s: %s' % (json.dumps(k, ensure_ascii=False),
                                     json.dumps(v[IDX[lg]], ensure_ascii=False)))
        for k, m in META.items():
            if '"@%s":' % k in t:
                continue
            add.append('  %s: %s' % (json.dumps('@' + k, ensure_ascii=False), m))
        if add:
            t = add_lines(t, add)
            io.open(p, 'w', encoding='utf-8', newline='').write(t)
        # 立刻验 JSON：拼错了就在这里炸，不要留到 check 脚本里才发现
        try:
            json.load(io.open(p, encoding='utf-8'))
        except Exception as e:
            print('%s arb 拼坏了: %s' % (lg, e))
            return 1
        print('%s arb ok（新增 %d 行）' % (lg, len(add)))

    # 抽象类
    p = os.path.join(ROOT, 'lib', 'l10n', 'app_localizations.dart')
    s = io.open(p, encoding='utf-8').read()
    code = []
    for k, v in KEYS.items():
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

    # 各语言实现
    for lg in LANGS:
        fn = ('app_localizations_zh.dart' if lg in ('zh', 'zh_TW')
              else 'app_localizations_%s.dart' % lg)
        p = os.path.join(ROOT, 'lib', 'l10n', fn)
        s = io.open(p, encoding='utf-8').read()
        b0, b1 = class_body(s, CLASSES[lg])
        code = []
        for k, v in KEYS.items():
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
