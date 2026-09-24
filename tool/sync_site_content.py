#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把「功能卡片 + 更新日志重点版本」同步到官网三个语言页。

背景：官网的功能卡片与更新日志是**静态手写**的（页面本身只由
`docs/js/main.js` 动态替换版本号），所以每次发版都要人来补 —— 实践下来
就落后了：v1.6.19~v1.6.107 的功能官网全没有，更新日志停在 v1.6.18。

这个脚本用「标记块」做幂等写入：
    <!-- site-sync:features -->...<!-- /site-sync:features -->
    <!-- site-sync:changelog -->...<!-- /site-sync:changelog -->
每次执行先删掉旧标记块再插入新内容，因此可以反复运行、不会重复叠加。

跑法：
    python3 tool/sync_site_content.py

⚠️ 文案是**三种语言分别手写**的，不做机器转换。
   早先版本试过「简体 → 繁体」字符映射，结果转出 `主頁「手动上報」与「连接」`
   这种半简半繁的句子 —— 比放英文还糟。繁体必须手写。
"""
import io
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGES = {
    'zh': 'docs/index.html',
    'zh_TW': 'docs/zh-TW/index.html',
    'en': 'docs/en/index.html',
}

F_OPEN, F_CLOSE = '<!-- site-sync:features -->', '<!-- /site-sync:features -->'
C_OPEN, C_CLOSE = '<!-- site-sync:changelog -->', '<!-- /site-sync:changelog -->'

LANGS = ('zh', 'zh_TW', 'en')


def T(zh, zh_TW, en):
    """三语文案。刻意要求每次都写全三种，漏一种会直接报错。"""
    return {'zh': zh, 'zh_TW': zh_TW, 'en': en}


# ─────────────────────────── 功能卡片 ───────────────────────────
# 顺序即展示顺序；图标类名 c1~c18 见 docs/css/style.css。
# 总数 18：4 列时 4×4+2（末行 2 张）、2 列时 9 行，两种断点都不会剩孤零零一张。
CARDS = [
    {
        'icon': 'c9', 'fa': 'fa-tower-cell',
        'title': T('四种数据来源', '四種資料來源', 'Four Data Sources'),
        'desc': T(
            '互联网（APRS-IS）、蓝牙 / 串口 TNC（KISS）、声卡音频 AFSK 1200（Bell 202 软 TNC），'
            '以及读取 Kenwood 电台输出的 <code>$PKWDWPL</code> 航点语句（只收不发）。'
            '几条链路可以同时收报文，发射来源单独指定一条。',
            '網際網路（APRS-IS）、藍牙 / 串列埠 TNC（KISS）、音效卡音訊 AFSK 1200（Bell 202 軟 TNC），'
            '以及讀取 Kenwood 電台輸出的 <code>$PKWDWPL</code> 航點語句（唯讀、不發射）。'
            '數條鏈路可以同時收報文，發射來源單獨指定一條。',
            'Internet (APRS-IS), Bluetooth / serial TNC over KISS, a sound-card AFSK 1200 '
            '(Bell 202) software TNC, and reading the <code>$PKWDWPL</code> waypoint sentences '
            'a Kenwood radio outputs (receive-only). Several links can receive at once, while '
            'the transmit source is picked separately.'),
        'tags': {'zh': ['APRS-IS', 'TNC', '音频', 'PKWDWPL'],
                 'zh_TW': ['APRS-IS', 'TNC', '音訊', 'PKWDWPL'],
                 'en': ['APRS-IS', 'TNC', 'Audio', 'PKWDWPL']},
    },
    {
        'icon': 'c10', 'fa': 'fa-right-left',
        'title': T('网关（iGate）', '閘道（iGate）', 'Gateway (iGate)'),
        'desc': T(
            '把射频收到的报文转到 APRS-IS，自动带 <code>qAr</code> / <code>qAR</code> 来路标识；'
            '带环路防护（含 <code>TCPIP*</code> 或已有 q 构造的报文绝不送回），'
            '同一帧 30 秒内只注入一次。可选双向模式会把网络侧发给「刚在射频上听到过」的台站的消息送到射频。',
            '把射頻收到的報文轉到 APRS-IS，自動帶 <code>qAr</code> / <code>qAR</code> 來路標識；'
            '具備環路防護（含 <code>TCPIP*</code> 或已有 q 構造的報文絕不送回），'
            '同一幀 30 秒內只注入一次。可選雙向模式會把網路側發給「剛在射頻上聽到過」的台站的訊息送到射頻。',
            'Relays RF packets into APRS-IS, tagging them with <code>qAr</code> / <code>qAR</code>; '
            'loop protection is built in (packets already carrying <code>TCPIP*</code> or a '
            'q-construct are never echoed back), and the same frame is injected once per 30 '
            'seconds. Optional two-way mode sends messages to stations recently heard on RF.'),
        'tags': {'zh': ['RF→IS', '防环', '去重'],
                 'zh_TW': ['RF→IS', '防環', '去重'],
                 'en': ['RF→IS', 'Loop-safe', 'De-duplication']},
    },
    {
        'icon': 'c11', 'fa': 'fa-language',
        'title': T('双向聊天翻译', '雙向聊天翻譯', 'Two-way Chat Translation'),
        'desc': T(
            '内置多引擎翻译，默认走免费接口、<b>无需任何密钥</b>。收到的和发出的消息都能译，'
            '可对照原文，也能在发送前先把自己的输入译成对方的语言。',
            '內建多引擎翻譯，預設走免費介面、<b>無需任何金鑰</b>。收到的和發出的訊息都能譯，'
            '可對照原文，也能在發送前先把自己的輸入譯成對方的語言。',
            'Built-in multi-engine translation that works out of the box on a free endpoint, '
            '<b>no API key required</b>. Translate both incoming and outgoing messages, compare '
            'against the original, or translate your text into the other station\'s language '
            'before sending.'),
        'tags': {'zh': ['免密钥', '对照翻译', '发送前翻译'],
                 'zh_TW': ['免金鑰', '對照翻譯', '發送前翻譯'],
                 'en': ['No API key', 'Side-by-side', 'Pre-send']},
    },
    {
        'icon': 'c12', 'fa': 'fa-compass',
        'title': T('沉浸地图（导航风格）', '沉浸地圖（導航風格）', 'Immersive Drive View'),
        'desc': T(
            '专为「边开车边看」设计的导航风格页面：大字号方向 / 距离 / 速度，'
            '左侧「附近台站」面板，目标台站居中，Android 与 Windows 都能用。',
            '專為「邊開車邊看」設計的導航風格頁面：大字號方向 / 距離 / 速度，'
            '左側「附近台站」面板，目標台站居中，Android 與 Windows 都能用。',
            'A navigation-style page built for glancing at while driving: large heading / '
            'distance / speed readouts, a nearby-stations panel, and the target station centred.'),
        'tags': {'zh': ['导航风格', '附近台站', '大字号'],
                 'zh_TW': ['導航風格', '附近台站', '大字號'],
                 'en': ['Navigation style', 'Nearby stations', 'Large type']},
    },
    {
        'icon': 'c13', 'fa': 'fa-chart-line',
        'title': T('天气 · 统计 · 荣誉', '天氣 · 統計 · 榮譽', 'Weather · Statistics · Honors'),
        'desc': T(
            '天气面板（动态背景跟随实时天气强度变化）、台站统计面板（最近上报 / 最远距离 / 报文速率），'
            '以及荣誉墙。',
            '天氣面板（動態背景跟即時天氣強度變化）、台站統計面板（最近上報 / 最遠距離 / 報文速率），'
            '以及榮譽牆。',
            'A weather panel whose dynamic background follows the actual conditions, station '
            'statistics (latest spot, farthest distance, packet rate), and an honors wall.'),
        'tags': {'zh': ['天气面板', '统计面板', '荣誉墙'],
                 'zh_TW': ['天氣面板', '統計面板', '榮譽牆'],
                 'en': ['Weather', 'Statistics', 'Honors']},
    },
    {
        'icon': 'c14', 'fa': 'fa-file-export',
        'title': T('数据导出', '資料匯出', 'Data Export'),
        'desc': T(
            '一键导出 ADIF —— 业余无线电通用的日志交换格式，频率可自定义，'
            '导出后可直接导入其它日志软件。',
            '一鍵匯出 ADIF —— 業餘無線電通用的日誌交換格式，頻率可自訂，'
            '匯出後可直接匯入其它日誌軟體。',
            'One-tap ADIF export — the standard amateur-radio log interchange format — with a '
            'configurable frequency, ready to import into other logging software.'),
        'tags': {'zh': ['ADIF', '频率自定义'],
                 'zh_TW': ['ADIF', '頻率自訂'],
                 'en': ['ADIF', 'Custom frequency']},
    },
    {
        'icon': 'c15', 'fa': 'fa-table-cells-large',
        'title': T('桌面小组件', '桌面小組件', 'Home-screen Widgets'),
        'desc': T(
            'Android 桌面小组件：天气（4 档自适应尺寸）、短波传播、系统状态三套；'
            '组件不自己联网，由应用单向推送快照，省电可控。',
            'Android 桌面小組件：天氣（4 種自適應尺寸）、短波傳播、系統狀態三套；'
            '小組件不自己連線，由應用單向推送快照，省電可控。',
            'Android home-screen widgets: weather (four adaptive sizes), HF propagation and '
            'system status. The widgets never open a connection themselves — the app pushes '
            'a snapshot to them, which keeps them cheap on battery.'),
        'tags': {'zh': ['Android', '4 档自适应', '不自行联网'],
                 'zh_TW': ['Android', '4 種自適應', '不自行連線'],
                 'en': ['Android', '4 adaptive sizes', 'No direct network']},
    },
    {
        'icon': 'c16', 'fa': 'fa-satellite-dish',
        'title': T('短波与电离层传播', '短波與電離層傳播', 'HF & Ionospheric Propagation'),
        'desc': T(
            '短波面板与独立组件：SFI / Kp / A 指数、黑子、X 射线、太阳风，'
            '四个波段对的「日 / 夜」条件一眼看清；数据来自 hamqsl.com（N0NBH），30 分钟缓存。',
            '短波面板與獨立元件：SFI / Kp / A 指數、黑子、X 射線、太陽風，'
            '四個波段對的「日 / 夜」條件一眼看清；資料來自 hamqsl.com（N0NBH），30 分鐘快取。',
            'An HF panel plus a standalone widget: SFI / Kp / A index, sunspots, X-rays, solar '
            'wind, and day/night conditions for four band pairs at a glance. Data comes from '
            'hamqsl.com (N0NBH) with a 30-minute cache.'),
        'tags': {'zh': ['SFI / Kp / A', '日 · 夜', '30 分钟缓存'],
                 'zh_TW': ['SFI / Kp / A', '日 · 夜', '30 分鐘快取'],
                 'en': ['SFI / Kp / A', 'Day / night', '30-min cache']},
    },
    {
        'icon': 'c17', 'fa': 'fa-map-location-dot',
        'title': T('离线地图', '離線地圖', 'Offline Maps'),
        'desc': T(
            '把当前视图整片瓦片下到本机（断点续传、单区域上限 20 万张），断网、无信号也能看；'
            '四级降级保证地图始终可看可点。',
            '把當前視圖整片瓦片下載到本機（斷點續傳、單區域上限 20 萬張），斷網、無訊號也能看；'
            '四級降級保證地圖始終可看可點。',
            'Download the tiles of the current view to the device (resumable, 200k tiles per '
            'region) and keep the map with no network at all; a four-step fallback keeps it '
            'readable and clickable.'),
        'tags': {'zh': ['按视图下载', '断点续传', '四级降级'],
                 'zh_TW': ['按視圖下載', '斷點續傳', '四級降級'],
                 'en': ['Download view', 'Resumable', '4-step fallback']},
    },
    {
        'icon': 'c18', 'fa': 'fa-paintbrush',
        'title': T('主题与备份', '主題與備份', 'Themes & Backup'),
        'desc': T(
            '主题不只是换色：颜色、图标、文字、背景图都能改（17 个颜色令牌），可导出成 JSON 分享；'
            '设置与数据可整体备份，换机一键导入。',
            '主題不只是換色：顏色、圖示、文字、背景圖都能改（17 個顏色權杖），可匯出成 JSON 分享；'
            '設定與資料可整體備份，換機一鍵匯入。',
            'Themes go beyond colour: icons, text and your own background image (17 colour '
            'tokens), exported as JSON to share; settings and data back up as one file for a '
            'one-tap restore.'),
        'tags': {'zh': ['17 色令牌', 'JSON 分享', '一键备份'],
                 'zh_TW': ['17 色權杖', 'JSON 分享', '一鍵備份'],
                 'en': ['17 tokens', 'JSON export', 'One-tap backup']},
    },
]

# ─────────────────────────── 更新日志重点版本 ───────────────────────────
# new / up / fix 对应页面既有的三个圆点颜色（绿 / 琥珀 / 红）。
# 只列「重点版本」：中间几十个纯修 bug 的版本归纳进文字说明，完整记录指向 Releases。
CL = [
    {
        'ver': 'v1.6.169', 'date': '2026-09-24',
        'items': [
            ('fix',
             T('**1.0 布局下「佳明分享」依然毫无反应**：上一版把「分享里没有链接」也做成'
               '可见提示，但那个回调只注册在 2.0 外壳 —— 用 1.0 的用户分享完还是什么都'
               '看不到，和「没识别」一模一样。现在 1.0 两个回调都注册：收到链接给提示 +'
               '「去设置」，没找到链接也如实说一句（**失败也看得见**）',
               '**1.0 佈局下「佳明分享」依然毫無反應**：上一版把「分享裡沒有連結」也做成'
               '可見提示，但那個回呼只註冊在 2.0 外殼 —— 用 1.0 的使用者分享完還是什麼都'
               '看不到，和「沒識別」一模一樣。現在 1.0 兩個回呼都註冊：收到連結給提示 +'
               '「去設定」，沒找到連結也如實說一句（**失敗也看得見**）',
               '**Garmin sharing was still silent in the 1.0 layout**: the previous release made '
               '"the shared content has no link" visible too, but that callback was registered only '
               'in the 2.0 shell — so on 1.0 sharing still showed nothing, exactly like "not '
               'recognised". The 1.0 shell now registers both callbacks: a link shows a notice plus '
               'an "Open settings" action, and a share without a link says so plainly (failures are '
               'visible too).')),
        ],
    },
    {
        'ver': 'v1.6.168', 'date': '2026-09-24',
        'items': [
            ('fix',
             T('**「位置来源」改成如实的状态行，不再是二选一**（用户实测指出）：没启动追踪时，'
               '「手机 GPS」照样画着实心选中圆点（其实什么都没在跑），「佳明」那行也能被'
               '「选中」——只看开关、没看追踪有没有启动。而且佳明与手机 GPS 本来不是二选一：'
               '手表直播时优先用手表，超过 120s 没新点自动交回手机。现在按实际情况显示：'
               '「未追踪（未启动定位）」/「追踪中」/「追踪中（手机 GPS 已让位）」/'
               '「链接有效，但佳明没有新点」；心率那行也显示当前 bpm',
               '**「位置來源」改成如實的狀態列，不再是二選一**（使用者實測指出）：沒啟動追蹤時，'
               '「手機 GPS」照樣畫著實心選取圓點（其實什麼都沒在跑），「佳明」那列也能被'
               '「選取」——只看開關、沒看追蹤有沒有啟動。而且佳明與手機 GPS 本來不是二選一：'
               '手錶直播時優先用手錶，超過 120s 沒新點自動交回手機。現在按實際情況顯示：'
               '「未追蹤（未啟動定位）」/「追蹤中」/「追蹤中（手機 GPS 已讓位）」/'
               '「連結有效，但佳明沒有新點」；心率那列也顯示目前 bpm',
               '**"Position source" is now an honest status row, not a two-way choice** (pointed '
               'out from a real device): with tracking not started, "Phone GPS" still showed a '
               'filled selection dot (nothing was running) and "Garmin" could be "selected" — the '
               'state only looked at the switch, never at whether tracking was running. Garmin and '
               'the phone GPS are not a choice at all: while the watch is live it wins, and after '
               '120s without a fresh point the phone takes over. It now reports reality: "Not '
               'tracking (location off)" / "Tracking" / "Tracking (phone GPS stepped aside)" / '
               '"Link set, but Garmin has no fresh points"; the heart-rate row shows the current '
               'bpm too.')),
        ],
    },
    {
        'ver': 'v1.6.167', 'date': '2026-09-24',
        'items': [
            ('up',
             T('**佳明接管时的上报 UI 说清了来源**：位置来自手表时，上报横杠显示'
               '「佳明上报 · 45s · ❤128」（红色），而不是看不出差别的普通倒计时 —— '
               '两者可能差几十公里。并且**挡住粗定位覆盖手表位置**：佳明断流后手机 GPS '
               '会接回来，但基站/WiFi 粗点不行（它会拿偏几百米的质心替换手表位置，而横杠'
               '当时显示的是正常倒计时，用户完全看不出正在发错坐标）。'
               '另外**佳明/心率成为「数据来源」里的可选来源**（位置来源：手机 GPS / 佳明；'
               '心率来源：蓝牙心率带），与报文链路分开列；**手动上报的提示现在会列出'
               '实际附带的内容**（如「网格 FN20xx · 心率 128 bpm」）',
               '**佳明接管時的上報 UI 說清了來源**：位置來自手錶時，上報橫槓顯示'
               '「佳明上報 · 45s · ❤128」（紅色），而不是看不出差別的普通倒數 —— '
               '兩者可能差幾十公里。並且**擋住粗定位覆蓋手錶位置**：佳明斷流後手機 GPS '
               '會接回來，但基地台/WiFi 粗點不行（它會拿偏幾百公尺的質心替換手錶位置，而橫槓'
               '當時顯示的是正常倒數，使用者完全看不出正在發錯座標）。'
               '另外**佳明/心率成為「資料來源」裡的可選來源**（位置來源：手機 GPS / 佳明；'
               '心率來源：藍牙心率帶），與報文鏈路分開列；**手動上報的提示現在會列出'
               '實際附帶的內容**（如「網格 FN20xx · 心率 128 bpm」）',
               '**The beacon UI now says where the position comes from.** While Garmin is live the '
               'beacon bar shows "Garmin · 45s · ❤128" in red instead of an indistinguishable '
               'countdown (the two positions can be tens of kilometres apart). A coarse (cell/Wi-Fi) '
               'fix is now blocked from replacing the watch position: once Garmin goes stale the '
               'phone GPS rightly takes over, but a cell-tower centroid must not — the bar would '
               'still show a normal countdown, so nothing on screen reveals a wrong coordinate is '
               'being transmitted. **Garmin and the strap also became selectable "data sources"** '
               '(position source: phone GPS / Garmin; heart-rate source: the BLE strap), listed '
               'separately from the packet links, and **the manual-beacon toast now lists what was '
               'actually attached** (e.g. "Grid FN20xx · HR 128 bpm").')),
        ],
    },
    {
        'ver': 'v1.6.166', 'date': '2026-09-24',
        'items': [
            ('fix',
             T('**修：佳明 App 分享的短链（`gar.mn/…`）之前根本进不来**。佳明 App 的「分享」给的是'
               '短链，而应用只认长链（`livetrack.garmin.com/session/…/token/…`）、Android 分享'
               '入口也只放行那个域名 —— 于是「分享 → 选 APRSlocus」什么都没发生。现在两种链接都认'
               '（含只复制到 `gar.mn/xxx` 没有 `https://` 的情况），抓取时跟随 301 跳转；'
               '写日志前把 token 打码 —— 分享链接本身就是读取实时位置的凭据',
               '**修：佳明 App 分享的短鏈（`gar.mn/…`）之前根本進不來**。佳明 App 的「分享」給的是'
               '短鏈，而應用只認長鏈（`livetrack.garmin.com/session/…/token/…`）、Android 分享'
               '入口也只放行那個域名 —— 於是「分享 → 選 APRSlocus」什麼都沒發生。現在兩種連結都認'
               '（含只複製到 `gar.mn/xxx` 沒有 `https://` 的情況），抓取時跟隨 301 跳轉；'
               '寫日誌前把 token 打碼 —— 分享連結本身就是讀取即時位置的憑據',
               '**Fix: the short link the Garmin app shares (`gar.mn/…`) never got through.** '
               'Garmin\'s Share button produces a short link, but the app only accepted the long '
               'form and the Android share target only allowed that host — so "Share → APRSlocus" '
               'did nothing. Both forms are recognised now (including a bare `gar.mn/xxx` with no '
               'scheme), redirects are followed, and the token is masked before logging, because a '
               'share link is the credential for reading a live position.')),
        ],
    },
    {
        'ver': 'v1.6.165', 'date': '2026-09-24',
        'items': [
            ('new',
             T('**蓝牙心率带**（BLE 标准心率服务 0x180D）：信标设置页可搜索/连接/看当前心率，'
               '新增「信标附带心率」开关（默认开）——位置包备注里加 `HR=nn`，没有读数时**什么都不发**'
               '（发 HR=0 会被读成「心率 0」）。**与 TNC 的蓝牙通道不冲突**：TNC 走经典蓝牙 SPP、'
               '心率走 BLE GATT，本来就并行；并且绝不做经典蓝牙发现（那会打断 TNC 的 SPP 连接），'
               '同一台设备被两条链路抢占时会直接拒绝并说明原因',
               '**藍牙心率帶**（BLE 標準心率服務 0x180D）：信標設定頁可搜尋／連線／看目前心率，'
               '新增「信標附帶心率」開關（預設開）——位置包備註裡加 `HR=nn`，沒有讀數時**什麼都不發**'
               '（發 HR=0 會被讀成「心率 0」）。**與 TNC 的藍牙通道不衝突**：TNC 走經典藍牙 SPP、'
               '心率走 BLE GATT，本來就並行；並且絕不做經典藍牙發現（那會打斷 TNC 的 SPP 連線），'
               '同一台裝置被兩條鏈路搶占時會直接拒絕並說明原因',
               '**Bluetooth heart-rate straps** (standard BLE service 0x180D): the beacon settings '
               'page can scan/connect and show the current BPM, with a new "Send heart rate in '
               'beacon" switch (on by default) that adds `HR=nn` to the position comment — and '
               'sends **nothing** without a reading (HR=0 would read as "pulse 0"). It does not '
               'fight with the TNC link: TNC uses classic Bluetooth SPP while heart rate uses BLE '
               'GATT, they run in parallel, classic discovery (which would tear down the SPP '
               'link) is never used, and a device already held by TNC is rejected with a reason.')),
            ('new',
             T('**佳明 LiveTrack**：手表的活动位置可以直接接进来。两条路——① 在佳明 Connect App 里'
               '「分享」选 APRSlocus（已注册系统分享入口），链接自动填入并开始追踪；② 信标设置页'
               '的「佳明 LiveTrack」里手动粘贴链接（也可从剪贴板取）。抓公开分享页的 trackPoints，'
               '取经纬度/海拔/速度/心率；只接受 120 秒内的点、积压超 60 秒跳点、两次转发至少隔 '
               '10 秒；佳明在跑时手机 GPS 自动让位',
               '**佳明 LiveTrack**：手錶的活動位置可以直接接進來。兩條路——① 在佳明 Connect App 裡'
               '「分享」選 APRSlocus（已註冊系統分享入口），連結自動填入並開始追蹤；② 信標設定頁'
               '的「佳明 LiveTrack」裡手動貼上連結（也可從剪貼簿取）。抓公開分享頁的 trackPoints，'
               '取經緯度／海拔／速度／心率；只接受 120 秒內的點、積壓超 60 秒跳點、兩次轉發至少隔 '
               '10 秒；佳明在跑時手機 GPS 自動讓位',
               '**Garmin LiveTrack**: your watch activity can feed straight in — either share it '
               'from the Garmin Connect app to APRSlocus (a registered system share target), or '
               'paste the link on the new "Garmin LiveTrack" page (clipboard button included). It '
               'reads trackPoints from the public share page (position, altitude, speed, heart '
               'rate) and accepts only points up to 120s old, skips to the newest past a 60s '
               'backlog, and forwards at most one point every 10s; while Garmin is live the phone '
               'GPS steps aside automatically.')),
            ('up',
             T('**心率显示在主屏幕**（地图左上第一个胶囊，带 BLE / Garmin 来源标记，没有读数时'
               '整块不显示）；**佳明接管期间补齐两处**：① 航向——佳明的点没有航向字段，之前会'
               '沿用手机 GPS 的旧值（指南针停在旧方向），现用前后两点算出来；② 历史台账——之前'
               '没写而手机 GPS 又正让位，那段历史是空白，现已与 GPS 同一套落盘。'
               '另外设备页新增「其他数据来源」卡（心率带 + 佳明两个入口），'
               '与报文链路互不影响、可同时使用',
               '**心率顯示在主畫面**（地圖左上第一個膠囊，帶 BLE / Garmin 來源標記，沒有讀數時'
               '整塊不顯示）；**佳明接管期間補齊兩處**：① 航向——佳明的點沒有航向欄位，之前會'
               '沿用手機 GPS 的舊值（指南針停在舊方向），現用前後兩點算出來；② 歷史台帳——之前'
               '沒寫而手機 GPS 又正讓位，那段歷史是空白，現已與 GPS 同一套落盤。'
               '另外裝置頁新增「其他資料來源」卡（心率帶 + 佳明兩個入口），'
               '與報文鏈路互不影響、可同時使用',
               '**Heart rate on the main screen** (the first chip in the map top-left column, '
               'tagged BLE or Garmin, and hidden entirely with no reading). Two gaps while '
               'Garmin is driving are closed: the heading was not computed at all (Garmin points '
               'carry none, so the compass froze on the phone GPS last value) and it is now '
               'derived from the previous point; and the daily history log was not written while '
               'the phone GPS was standing down, leaving a blank stretch — it now records like '
               'the GPS path. The device page also gained an "Other data sources" card (strap + '
               'Garmin), which is independent of the packet links and can run alongside them.')),
        ],
    },
    {
        'ver': 'v1.6.164', 'date': '2026-09-24',
        'items': [
            ('fix',
             T('**修三处「挤 / 没填满 / 显示不全」**：① 关于页分享弹层的标题与副标题'
               '原来零间隙地贴在一起，现在留 3px，头部与选项之间 14→18、选项之间 8→10；'
               '② 关于页封面——原来「容器宽/卡高 > 1.62」就改走 `contain`（怕裁掉火山），'
               '但卡高有 300 上限、容器宽到 600，于是**任何 ≥600 宽的屏幕上都会走**：'
               '照片缩成中间一条、两侧各空 75px，横屏时 Logo 卡正坐在左边空白上'
               '（就是「logo 背景没填满」）；改成 cover + topCenter，铺满并保住雪顶；'
               '③ 消息页换栏原来按**朝向**判（只要横屏就走双栏），而 2.0 横屏把消息页装进'
               '≤560 的左面板（手机常 200~280），固定 280 的列表栏把会话区挤成负宽度 —— '
               '现在只看可用宽度换栏、列表栏宽度跟着容器走，并新增窄容器行内降级'
               '（呼号可省略 / 群聊操作胶囊换行排，一个都不藏）',
               '**修三處「擠 / 沒填滿 / 顯示不全」**：① 關於頁分享彈層的標題與副標題'
               '原來零間隙地貼在一起，現在留 3px，頭部與選項之間 14→18、選項之間 8→10；'
               '② 關於頁封面——原來「容器寬/卡高 > 1.62」就改走 `contain`（怕裁掉火山），'
               '但卡高有 300 上限、容器寬到 600，於是**任何 ≥600 寬的畫面上都會走**：'
               '照片縮成中間一條、兩側各空 75px，橫屏時 Logo 卡正坐在左邊空白上'
               '（就是「logo 背景沒填滿」）；改成 cover + topCenter，鋪滿並保住雪頂；'
               '③ 訊息頁換欄原來按**朝向**判（只要橫屏就走雙欄），而 2.0 橫屏把訊息頁裝進'
               '≤560 的左面板（手機常 200~280），固定 280 的列表欄把會話區擠成負寬度 —— '
               '現在只看可用寬度換欄、列表欄寬度跟著容器走，並新增窄容器行內降級'
               '（呼號可省略 / 群聊操作膠囊換行排，一個都不藏）',
               '**Three layout fixes.** (1) In the About share sheet the title and subtitle sat '
               'flush against each other (0 gap); now 3px, with 14→18px above the option '
               'list and 8→10px between options. (2) The About cover switched to `contain` '
               'whenever "container width / card height > 1.62" — but the card height is '
               'capped at 300 while the container reaches 600, so that held on **every screen '
               '600 wide or more**: the photo shrank to a band in the middle with 75px of blank '
               'space on each side, and in landscape the logo card sat on that left gap (the '
               '"logo backdrop isn\'t filled" report). It is now cover + topCenter, filling the '
               'card while keeping the snow-capped summit. (3) The messages page switched '
               'columns by **orientation** (any landscape screen got two columns), but the '
               '2.0 landscape shell puts it in the ≤560 left pane (often 200–280 on a phone), '
               'where the fixed 280 list column squeezed the chat column to a negative width. '
               'Column switching now looks only at the available width, the list column '
               'follows its container, and a new narrow-container degradation lets the '
               'callsign ellipsise and wraps the group action chips onto their own row '
               '(nothing hidden).')),
        ],
    },
    {
        'ver': 'v1.6.163', 'date': '2026-09-24',
        'items': [
            ('up',
             T('**网络定位整体降权：粗定位（基站/Wi-Fi）不再自动上报**。'
               '自动上报是「我在这里」的公开宣告，而粗点常年偏几百米、还会原地漂 —— '
               '报出去就是个错坐标。地图上报横幅 / 沉浸地图 / 首页 / 设置页都会如实说明'
               '「网络定位中 · 暂不自动上报」，GPS 一回来立即恢复（手动「立即上报」不受影响）。'
               '三个门槛同时收紧：GPS 停更 120s→300s 才允许粗点兜底、粗点自身位移上限 '
               '8km→3km、粗点精度显示下限 150m→300m；粗点也不再推动 APRS-IS 过滤中心'
               '（过滤串按 0.01° 取整，一动就可能触发整条链路重连）',
               '**網路定位整體降權：粗定位（基地台／Wi-Fi）不再自動上報**。'
               '自動上報是「我在這裡」的公開宣告，而粗點長年偏幾百公尺、還會原地漂 —— '
               '報出去就是個錯座標。地圖上報橫幅 / 沉浸地圖 / 首頁 / 設定頁都會如實說明'
               '「網路定位中 · 暫不自動上報」，GPS 一回來立即恢復（手動「立即上報」不受影響）。'
               '三個門檻同時收緊：GPS 停更 120s→300s 才允許粗點兜底、粗點自身位移上限 '
               '8km→3km、粗點精度顯示下限 150m→300m；粗點也不再推動 APRS-IS 過濾中心'
               '（過濾字串按 0.01° 取整，一動就可能觸發整條連結重連）',
               '**Network positioning is de-emphasised overall: coarse (cell/Wi-Fi) fixes are '
               'never transmitted automatically.** An automatic beacon is a public statement '
               'of "I am here", and a coarse fix is routinely hundreds of metres off and '
               'wanders in place — what goes out is a wrong coordinate. The map beacon bar, '
               'immersive map, home page and settings all say "network fix · auto beacon '
               'paused", and reporting resumes the moment GPS is back (manual "beacon now" '
               'is unaffected). Three thresholds were tightened at the same time: a coarse '
               'fix is only used once GPS has been stale for 300s (was 120s), its self-jump '
               'limit is 3km (was 8km), and its accuracy floor is 300m (was 150m). Coarse '
               'fixes no longer move the APRS-IS filter centre either — the filter string is '
               'rounded to 0.01°, so a drift could trigger a full link reconnect.')),
            ('fix',
             T('**横屏在手机 / 平板 / 桌面三端的打磨**：① 面板内的宽度不再按屏幕宽度算 —— '
               '消息气泡原来取「屏幕宽 × 0.55」，桌面 1920 会算成 1056px，超出面板的部分'
               '被默默裁掉，长消息读不全（现在按消息区实际宽度）；② 左上统计条在窄地图区'
               '自动降级为「在线 + 台站」（横屏面板展开时地图区常只剩 200 出头）；'
               '③「矮横屏」改按顶栏之下的可用高度判断（未连接 / 公告横幅会各占一行），'
               '不再漏判「工具列最下面的定位按钮被裁掉、点不到」；'
               '④ 桌面端自绘按钮统一给鼠标手型指针（包一层 ClickCursor —— '
               'GestureDetector 没有 mouseCursor 参数）',
               '**橫屏在手機 / 平板 / 電腦三端的打磨**：① 面板內的寬度不再按螢幕寬度算 —— '
               '訊息氣泡原來取「螢幕寬 × 0.55」，桌面 1920 會算成 1056px，超出面板的部分'
               '被默默裁掉，長訊息讀不全（現在按訊息區實際寬度）；② 左上統計列在窄地圖區'
               '自動降級為「線上 + 臺站」（橫屏面板展開時地圖區常只剩 200 出頭）；'
               '③「矮橫屏」改按頂欄之下的可用高度判斷（未連線 / 公告橫幅會各佔一行），'
               '不再漏判「工具列最下面的定位按鈕被裁掉、點不到」；'
               '④ 桌面端自繪按鈕統一給滑鼠手型指標（包一層 ClickCursor —— '
               'GestureDetector 沒有 mouseCursor 參數）',
               '**Landscape polish for phone, tablet and desktop.** (1) Widths inside the pane '
               'are no longer computed from the screen — message bubbles used to take '
               '"screen width × 0.55", which on a 1920 desktop is 1056px, silently clipped by '
               'the pane so long messages were cut off (they now use the message area\'s '
               'actual width). (2) The top-left station chip degrades to "online + stations" '
               'when the map area is narrow (landscape with the pane open often leaves only '
               'about 200px). (3) "Short landscape" is now judged by the height actually '
               'available below the top bar — the disconnected and notice banners each take '
               'a row — so the clipped, unreachable locate button at the bottom of the tool '
               'column is no longer missed. (4) Self-drawn buttons on desktop are wrapped in '
               'ClickCursor (MouseRegion + SystemMouseCursors.click), because GestureDetector '
               'has no mouseCursor parameter, so a hover shows a hand cursor.')),
            ('fix',
             T('**关于页名片卡不再挤**：头部内边距加大、标题与副标题间距 2→4px、'
               '标题 13.5→14.5、分享行更宽松、官网图标 32→34 并加了悬停说明（桌面端）',
               '**關於頁名片卡不再擠**：頭部內距加大、標題與副標題間距 2→4px、'
               '標題 13.5→14.5、分享列更寬鬆、官網圖示 32→34 並加了懸停說明（桌面端）',
               '**About page: the name card is no longer cramped** — bigger header padding, '
               'title/subtitle gap 2→4px, title 13.5→14.5, a roomier share row, and the '
               'website icon went 32→34 with a hover tooltip on desktop.')),
        ],
    },
    {
        'ver': 'v1.6.162', 'date': '2026-09-23',
        'items': [
            ('fix',
             T('**功能引导与地图浮层的重叠已修**：上一版引导卡硬写 `topBase+46`，正好糊住'
               '「沉浸地图」入口。先改成同一竖列顺序排布，但按真实几何量过发现它与右上'
               '图例**只差 1px 就相交**（靠「差一点」压住的布局换个语言/缩放必翻车）—— '
               '最终**地图页与沉浸地图改用一次性底部弹层**：全屏地图四周都是浮层，浮卡片'
               '找不到一定不重叠的位置；弹层只在页面真的在前台时才弹',
               '**功能導覽與地圖浮層的重疊已修**：上一版引導卡硬寫 `topBase+46`，正好'
               '糊住「沉浸地圖」入口。先改成同一直列順序排布，但按真實幾何量過發現它與'
               '右上圖例**只差 1px 就相交**（靠「差一點」壓住的佈局換個語言／縮放必翻車）—— '
               '最終**地圖頁與沉浸地圖改用一次性底部彈層**：全屏地圖四周都是浮層，浮卡片'
               '找不到一定不重疊的位置；彈層只在頁面真的在前台時才彈',
               '**Guide/overlay overlap on the map is fixed.** The previous build hard-coded '
               'the guide card at `topBase+46`, right on top of the immersive-map entry. '
               'Merging it into the same column fixed that, but measuring the real geometry '
               'showed it was **one pixel** from intersecting the legend — a layout that '
               'relies on "it just barely fits" breaks with a longer language or a different '
               'text scale. So both full-screen map views now use a **one-off bottom sheet**: '
               'with overlays on every side there is no position where a floating card is '
               'safe. The sheet only fires when the page is actually in the foreground.')),
            ('up',
             T('引导卡做小做安静：底色 8%→6%、描边 22%→16%、图标底托 30→28；右侧 × 改成'
               '**「知道了」文字按钮**；地图那条文案改短（卡片在地图左侧列里只有约 '
               '300px 宽，原句会折四行）。另外把 `check_landscape_layout.py` 的判据从'
               '「数 leftInset 出现次数」改成按结构判 —— 数实现细节会误伤重构（这次就'
               '报了个假失败）',
               '引導卡做小做安靜：底色 8%→6%、描邊 22%→16%、圖示底托 30→28；右側 × 改成'
               '**「知道了」文字按鈕**；地圖那條文案改短（卡片在地圖左側列裡只有約 '
               '300px 寬，原句會折四行）。另外把 `check_landscape_layout.py` 的判據從'
               '「數 leftInset 出現次數」改成按結構判 —— 數實作細節會誤傷重構（這次就'
               '報了個假失敗）',
               'The card is smaller and quieter: tint 8%→6%, border 22%→16%, icon chip '
               '30→28, and the lone × became a **"Got it" text button**. The map copy was '
               'shortened (the card is only ~300px wide there and used to wrap to four '
               'lines). `check_landscape_layout.py` no longer counts occurrences of '
               '`leftInset` but judges the structure instead — counting implementation '
               'details punishes refactoring, and it produced a false failure this time.')),
        ],
    },
    {
        'ver': 'v1.6.161', 'date': '2026-09-23',
        'items': [
            ('new',
             T('**功能引导**：16 个功能页首次进入时，正文顶部会显示一张可关闭的小提示卡'
               '（一句话说明这页能干什么、从哪下手）；关掉即记为「已看」，之后不再出现、'
               '也不占位置。设置类子页顶栏另有「重看本页引导」按钮。覆盖地图、台站列表、'
               '沉浸地图、消息、数据包、设备、设置、离线地图、日志、备份、轨迹回放、主题、'
               '翻译、声卡 TNC、蓝牙 TNC、PKWDWPL',
               '**功能導覽**：16 個功能頁首次進入時，正文頂部會顯示一張可關閉的小提示卡'
               '（一句話說明這頁能做什麼、從哪裡下手）；關掉即記為「已看」，之後不再出現、'
               '也不佔位置。設定類子頁頂欄另有「重看本頁導覽」按鈕。涵蓋地圖、臺站列表、'
               '沉浸地圖、訊息、資料封包、裝置、設定、離線地圖、日誌、備份、軌跡回放、主題、'
               '翻譯、音效卡 TNC、藍牙 TNC、PKWDWPL',
               '**Feature guides**: sixteen pages now show a dismissible one-off tip card at '
               'the top of the body on first visit, saying in one line what the page does and '
               'where to start. Closing it records "seen", after which it never appears and '
               'takes up no space. Sub-pages built on the settings shell also gain a "show '
               'this guide again" button in the app bar. Covered: map, station list, '
               'immersive map, messages, packets, devices, settings, offline maps, log, '
               'backup, track replay, theme, translation, sound-card TNC, Bluetooth TNC and '
               'PKWDWPL')),
            ('up',
             T('引导的「已看」记录存进设置并**纳入备份**（换机后不该把看过的提示卡再弹'
               '一遍）；设置里新增「重新查看功能引导」，确认后清空记录、各页提示卡重新出现。'
               '新增 `tool/check_guides.py` 静态检查：引导表 ↔ 6 语言文案 ↔ 生成产物 ↔ '
               '页面接入点四处一一对应（漏任一处都不会编译失败，只会「引导永远不出现」）；'
               '该检查写完当次就抓出三处真问题',
               '引導的「已看」記錄存進設定並**納入備份**（換機後不該把看過的提示卡再彈'
               '一遍）；設定裡新增「重新查看功能導覽」，確認後清空記錄、各頁提示卡重新出現。'
               '新增 `tool/check_guides.py` 靜態檢查：引導表 ↔ 6 語言文案 ↔ 產生產物 ↔ '
               '頁面接入點四處一一對應（漏任一處都不會編譯失敗，只會「引導永遠不出現」）；'
               '該檢查寫完當次就抓出三處真問題',
               'The "seen" record is stored in settings and **included in backups** (a '
               'restored device should not replay guides the user already read), and settings '
               'gained "show all feature guides again", which clears the record. A new static '
               'check, `tool/check_guides.py`, ties the guide table, the six-locale text, the '
               'generated l10n output and the page call-sites together — missing any one of '
               'them breaks neither the build nor the tests, it just means the guide never '
               'appears. The check caught three real problems the moment it was written')),
        ],
    },
    {
        'ver': 'v1.6.160', 'date': '2026-09-23',
        'items': [
            ('fix',
             T('关于页名片卡不再**压住封面**：上一版让它上骑 14px 压住照片下缘，实机看'
               '照片底部被挡掉一条、圆角切在图上，像没对齐；现在退回封面下方、中间留 '
               '12px 间隙，封面是一张完整的照片',
               '關於頁名片卡不再**壓住封面**：上一版讓它上騎 14px 壓住照片下緣，實機看'
               '照片底部被擋掉一條、圓角切在圖上，像沒對齊；現在退回封面下方、中間留 '
               '12px 間隙，封面是一張完整的照片',
               'The About page business card no longer **overlaps the hero**: the previous '
               'build lifted it 14px onto the bottom edge of the photo, which on a real '
               'device hid a strip of the image and cut the card\'s rounded corners into '
               'it, looking like a misalignment. The card now sits below the hero with a '
               '12px gap, leaving the photo intact')),
        ],
    },
    {
        'ver': 'v1.6.159', 'date': '2026-09-23',
        'items': [
            ('new',
             T('关于页重做：封面从 Logo 底图换成**泰德峰实景照片**，版本号收进右上角玻璃胶囊、'
               'Logo 与标题落到左下角压在渐变上；封面高度随窗口宽度走'
               '（`(宽 × 0.64)`，196~300），超宽屏改「整体装入」，不再把火山裁掉；'
               '桌面宽屏下封面与正文套**同一个限宽容器**（600）',
               '關於頁重做：封面從 Logo 底圖換成**泰德峰實景照片**，版本號收進右上角玻璃膠囊、'
               'Logo 與標題落到左下角壓在漸層上；封面高度隨視窗寬度走'
               '（`(寬 × 0.64)`，196~300），超寬螢幕改「整體裝入」，不再把火山裁掉；'
               '桌面寬螢幕下封面與正文套**同一個限寬容器**（600）',
               'About page redesigned: the hero cover is now a **real photograph of Pico del '
               'Teide** instead of the logo backdrop, with the version in a glass pill at the '
               'top-right and the logo and title anchored to the lower-left over a gradient. '
               'The hero height now follows the window width (`width × 0.64`, 196–300) and '
               'switches to “fit entirely” on ultra-wide screens so the volcano is never '
               'cropped; the hero and body now share **one width-capped container** (600) on '
               'desktop')),
            ('up',
             T('关于页删掉「功能特性」一节（实时地图 / GPS / 信标 / 消息 / 自动连接 / '
               '图层过滤 / FMO 七行 —— App 里已经看得见的功能不必再列一遍）；'
               '「分享」从描边小胶囊改成整行可点的入口，分节标题加淡色底托图标与'
               '右侧细横线，页脚加分割线并标出封面摄影署名',
               '關於頁刪掉「功能特性」一節（即時地圖 / GPS / 信標 / 訊息 / 自動連線 / '
               '圖層過濾 / FMO 七行 —— App 裡已經看得見的功能不必再列一遍）；'
               '「分享」從描邊小膠囊改成整行可點的入口，分節標題加淡色底托圖示與'
               '右側細橫線，頁腳加分割線並標出封面攝影署名',
               'Removed the Features section from the About page (the seven rows for live map, '
               'GPS, beacon, messages, auto-connect, layer filter and FMO duplicated what the '
               'app already shows). The share entry became a **full-width tappable** row, '
               'section headers gained a tinted icon chip and a trailing hairline rule, and the '
               'footer gained a divider plus a photo credit for the cover')),
            ('up',
             T('关于页版式改成**名片式**：封面下缘骑一张名片卡（呼号 · 名字 + 官网图标 + '
               '整行分享入口），分节从 8 个并成 5 个 —— 「开源致谢 + 许可证声明」并为'
               '「开源与许可」（四个开源项排 2×2 网格），「测试成员 + AI 算力支持 + '
               '赞助与鸣谢」并为「致谢名单」（呼号做成可折行的 chip）；**去掉作者个人站 '
               'theez.top 与「站长」字样**，官网按钮改指 App 官网（用户反馈里本来就有）',
               '關於頁版式改成**名片式**：封面下緣騎一張名片卡（呼號 · 名字 + 官網圖示 + '
               '整列分享入口），分節從 8 個併成 5 個 —— 「開源致謝 + 授權宣告」併為'
               '「開源與授權」（四個開源項目排 2×2 網格），「測試成員 + AI 算力支援 + '
               '贊助與鳴謝」併為「致謝名單」（呼號做成可折行的 chip）；**移除作者個人站 '
               'theez.top 與「站長」字樣**，官網按鈕改指 App 官網（使用者回饋裡本來就有）',
               'About page relaid out as a **business card**: a card now rides the bottom edge '
               'of the hero (callsign and name, a globe button and a full-width share row), '
               'and the section count drops from 8 to 5 — "Open source thanks + License" '
               'became "Open source & licence" (the four projects in a 2×2 grid) and '
               '"Test members + AI compute support + Sponsor entry" became "Credits" '
               '(callsigns as wrapping chips). The author\'s personal site `theez.top` and '
               'the "site owner" label are **removed**, and the globe button now opens the '
               'app\'s own website (already listed under Feedback)')),
        ],
    },
    {
        'ver': 'v1.6.158', 'date': '2026-09-23',
        'items': [
            ('fix',
             T('修「退出设置子页时公告横幅闪一下」：转场那份「底」原来用「值到 1 没有」'
               '判断转场结没结束 —— 而弹出时 `reverse()` 只改状态、**值要下一帧才动**，'
               '于是底下的页面整整透出一帧（开的材质或背景图时才看得见）',
               '修「退出設定子頁時公告橫幅閃一下」：轉場那份「底」原來用「值到 1 沒有」'
               '判斷轉場結沒結束 —— 而彈出時 `reverse()` 只改狀態、**值要下一帧才動**，'
               '於是底下的頁面整整透出一帧（開材質或背景圖時才看得見）',
               'Fixed the flash when leaving a Settings sub-page: the transition backdrop '
               'decided “is the transition over” from the value, but on pop `reverse()` only '
               'changes the status — the **value moves a frame later** — so the page '
               'underneath showed through for one full frame (visible only with the material '
               'or a background image enabled)')),
            ('up',
             T('公告入口搬到**设置主页最底下**（备份之后、关于之前）；设置子页里不再放横幅、'
               '只留开关。入口**点它才联网**，所以开关关着也能用 —— 不妨碍'
               '「关了就不在后台联网」那个承诺',
               '公告入口搬到**設定首頁最底下**（備份之後、關於之前）；設定子頁裡不再放橫幅、'
               '只留開關。入口**點它才連網**，所以開關關著也能用 —— 不妨礙'
               '「關了就不在後台連網」那個承諾',
               'The announcement entry moved to the **bottom of the Settings home screen** '
               '(after Backup, before About); the Settings sub-page no longer shows a banner, '
               'only the toggle. The entry **only goes online when tapped**, so it still '
               'works with the toggle off — without breaking the “off means no background '
               'network requests” promise')),
        ],
    },
    {
        'ver': 'v1.6.157', 'date': '2026-09-23',
        'items': [
            ('new',
             T('公告横幅挪到**主页**（地图上方，1.0/2.0 都有），设置页也各留一条；'
               '点开改成**底部弹层**（长文可滚、可拖动关闭），横幅自带**关闭按钮**'
               '（关掉后设置里再打开即可）',
               '公告橫幅挪到**主頁**（地圖上方，1.0/2.0 都有），設定頁也各留一條；'
               '點開改成**底部彈層**（長文可捲、可拖曳關閉），橫幅自帶**關閉按鈕**'
               '（關掉後設定裡再打開即可）',
               'The announcement banner moved to the **home screen** (above the map, in both '
               '1.0 and 2.0) with another copy in Settings; it now opens in a **bottom sheet** '
               '(scrollable, drag to dismiss) and carries its own **close button** — switch it '
               'back on in Settings any time')),
            ('fix',
             T('修「主界面底图选择面板弹不出来」：那颗按钮的回调**漏了括号**'
               '（只是返回函数本身、从不调用）—— v1.6.151 起一直如此，'
               '编译与 analyze 都不会报',
               '修「主介面底圖選擇面板彈不出來」：那顆按鈕的回呼**漏了括號**'
               '（只是回傳函式本身、從不呼叫）—— v1.6.151 起一直如此，'
               '編譯與 analyze 都不會報',
               'Fixed the base-map panel that would not open: that button\'s callback was '
               '**missing its parentheses** (returning the function instead of calling it) — '
               'broken since v1.6.151, and neither the compiler nor analyze reports it')),
        ],
    },
    {
        'ver': 'v1.6.156', 'date': '2026-09-23',
        'items': [
            ('new',
             T('新增**公告横幅**（设置 → 显示，默认开）：内容直接取自官网首页的公告区，'
               '改官网就能发通知、不用等新版；应用内渲染 Markdown（标题/列表/表格/图片）'
               '与超链接，断网时显示上次缓存的那份',
               '新增**公告橫幅**（設定 → 顯示，預設開）：內容直接取自官網首頁的公告區，'
               '改官網就能發通知、不用等新版；應用內渲染 Markdown（標題/列表/表格/圖片）'
               '與超連結，斷網時顯示上次快取的那份',
               'New **announcement banner** (Settings → Display, on by default): its content '
               'is taken straight from the website homepage announcement, so publishing a '
               'notice needs no app release. Markdown (headings, lists, tables, images) and '
               'hyperlinks are rendered in-app, with the last cached copy shown offline')),
            ('new',
             T('智能信标新增**第三路判据：按转弯打点** —— 转过设定角度就补一个点，'
               '角度每档可自定义（10~180°，0 = 关闭）。盘山路上车速慢、距离门限很久才够，'
               '而连续发卡弯正是最该有轨迹的地方',
               '智能信標新增**第三路判據：按轉彎打點** —— 轉過設定角度就補一個點，'
               '角度每檔可自訂（10~180°，0 = 關閉）。山路上車速慢、距離門檻很久才夠，'
               '而連續髮夾彎正是最該有軌跡的地方',
               'Smart beaconing gains a **third trigger: turning** — a point is added once you '
               'turn past the configured angle, set **per tier** (10–180°, 0 = off). On mountain '
               'roads you are slow, so the distance threshold takes ages to reach, yet those '
               'hairpins are exactly where the track matters most')),
            ('fix',
             T('「台站备注」现在看得出能输入了：那一行原来是**一片空白**（无边框、无占位提示），'
               '和静态的「标签 + 值」行长得一样。现在空值有占位提示、输入区有底色与描边、'
               '聚焦时描边变蓝 —— 全仓 42 处输入行一起受益',
               '「臺站備註」現在看得出能輸入了：那一行原來是**一片空白**（無邊框、無佔位提示），'
               '和靜態的「標籤 + 值」行長得一樣。現在空值有佔位提示、輸入區有底色與描邊、'
               '聚焦時描邊變藍 —— 全倉 42 處輸入行一起受益',
               'The station comment field now **looks editable**: that row used to be entirely '
               'blank (no border, no placeholder), indistinguishable from the static '
               '"label + value" rows. Empty fields now show a placeholder, the input area has a '
               'fill and border, and the border turns blue on focus — all 42 input rows benefit')),
        ],
    },
    {
        'ver': 'v1.6.155', 'date': '2026-09-23',
        'items': [
            ('fix',
             T('修「地图上的按钮点了没反应」：图层、缩放那一列按钮原来只有中间那个小图标能点，现在整块都能点',
               '修「地圖上的按鈕點了沒反應」：圖層、縮放那一列按鈕原來只有中間那個小圖示能點，現在整塊都能點',
               'Fixed map buttons that “did nothing”: the layers and zoom buttons only responded on the small centre icon — now the whole button works')),
            ('new',
             T('未连接提示强化：地图上方会出现一条橙色横幅，整条可点即连，不再只靠右上角那颗小胶囊',
               '未連線提示強化：地圖上方會出現一條橘色橫幅，整條可點即連，不再只靠右上角那顆小膠囊',
               'A much clearer offline notice: an orange bar above the map, tappable anywhere to connect — no longer just a tiny pill in the corner')),
            ('fix',
             T('进会话自动把面板升到最高档（输入框不再藏在底下）；台站页「在地图查看」会切回地图并收起面板',
               '進會話自動把面板升到最高檔（輸入框不再藏在底下）；臺站頁「在地圖查看」會切回地圖並收起面板',
               'Opening a chat now raises the panel by itself (the input box is no longer hidden below the fold); “View on map” from the station list switches back to the map and collapses the panel')),
        ],
    },
    {
        'ver': 'v1.6.154', 'date': '2026-09-23',
        'items': [
            ('new',
             T('实时轨迹采样从 10 秒细化到 1 秒，拐弯不再被切成斜线；发到服务器去的那些点用橙色小菱形标在轨迹上，数量与间隔一眼可见',
               '即時軌跡取樣從 10 秒細化到 1 秒，轉彎不再被切成斜線；送到伺服器去的那些點用橘色小菱形標在軌跡上，數量與間隔一眼可見',
               'Live track sampling refined from 10 s to 1 s so corners are no longer cut into diagonals; the points actually sent to the server are marked with small orange diamonds, so count and spacing are visible at a glance')),
            ('new',
             T('智能信标支持「按距离打点」：每档可设「或移动 N 米」，走得快就补点、停下来退回纯定时',
               '智能信標支援「按距離打點」：每檔可設「或移動 N 公尺」，走得快就補點、停下來退回純定時',
               'Smart beaconing can now trigger by distance: each tier takes an “or N metres” value, so fast movement adds points while standing still falls back to pure timing')),
        ],
    },
    {
        'ver': 'v1.6.153', 'date': '2026-09-22',
        'items': [
            ('fix',
             T('修 2.0 卡片面板「下沿被切成直角」：裁口改成底边圆角，半开时也是一张完整的圆角卡',
               '修 2.0 卡片面板「下沿被切成直角」：裁口改成底邊圓角，半開時也是一張完整的圓角卡',
               'Fixed the UI 2.0 sheet having its bottom edge cut into right angles: the clip now rounds the bottom corners, so a half-open panel still looks like a complete rounded card')),
        ],
    },
    {
        'ver': 'v1.6.152', 'date': '2026-09-22',
        'items': [
            ('up',
             T('磨砂玻璃再优化：同一簇浮层共享一次背景采样，只压在壁纸上的壳不再插模糊层 —— 列表滚动更顺，观感逐像素不变',
               '霧面玻璃再優化：同一簇浮層共享一次背景取樣，只壓在底圖上的外殼不再插模糊層 —— 列表捲動更順，觀感逐像素不變',
               'Frosted glass optimised again: surfaces over the same backdrop share a single sample, and shells that only sit on the wallpaper no longer blur — smoother list scrolling, pixel-identical looks')),
        ],
    },
    {
        'ver': 'v1.6.151', 'date': '2026-09-22',
        'items': [
            ('fix',
             T('2.0 横屏收拾五处只有真机才看得出的毛病：左侧竖条压住地图控件、右侧工具列被裁掉「定位」、底部让位把安全区算了两遍等',
               '2.0 橫向螢幕收拾五處只有真機才看得出的毛病：左側直條壓住地圖控件、右側工具列被裁掉「定位」、底部讓位把安全區算了兩遍等',
               'UI 2.0 landscape: five defects that only show up on a real device, including the rail covering the map’s controls, the tool column clipping “locate”, and the bottom inset counting the safe area twice')),
        ],
    },
    {
        'ver': 'v1.6.150', 'date': '2026-09-22',
        'items': [
            ('new',
             T('历史轨迹可点进某一天：地图上回放当天路线（轨迹随播放生长、'
               '0.5×~4× 倍速、跟随视角；超过 45 秒的停顿自动快进）',
               '歷史軌跡可點進某一天：地圖上回放當日路線（軌跡隨播放生長、'
               '0.5×~4× 倍速、跟隨視角；超過 45 秒的停頓自動快進）',
               'Tap into a day in track history and replay it on the map (the line grows as '
               'it plays, 0.5×–4× speed, follow view; stops over 45 s are fast-forwarded)')),
            ('fix',
             T('网络定位不再让位置飞来飞去：GPS 新鲜时粗定位点一律丢弃，'
               'GPS 停更 2 分钟以上才允许兜底',
               '網路定位不再讓位置飛來飛去：GPS 新鮮時粗定位點一律丟棄，'
               'GPS 停更 2 分鐘以上才允許兜底',
               'Network fixes no longer make the marker fly around: coarse points are dropped '
               'while GPS is fresh, and only allowed as a fallback after 2 minutes without an '
               'GPS update')),
        ],
    },
    {
        'ver': 'v1.6.149', 'date': '2026-09-22',
        'items': [
            ('new',
             T('去掉台站聚合：矢量地图与自绘地图都回到「一台站一个标记」，低缩放的密度信息交给热力图（开关保留）',
               '去掉臺站聚合：向量圖與自繪地圖都回到「一台站一個標記」，低縮放的密度資訊交給熱力圖（開關保留）',
               'Clustering removed: both maps are back to one marker per station, with low-zoom '
               'density left to the heatmap (its toggle stays)')),
            ('new',
             T('轨迹打点更准（Android）：低速时用指南针补航向、用加速度计判断「有没有在动」，默认开启、可关',
               '軌跡打點更準（Android）：低速時用指南針補航向、用加速度計判斷「有沒有在動」，預設開啟、可關',
               'More accurate track points (Android): the compass fills in heading at low speed '
               'and the accelerometer decides whether you are moving; on by default, switchable')),
            ('new',
             T('个人历史轨迹：按天保存在本地，设置页里看总里程 / 平均与最高速度 / 移动时长，可按天删除或一键清空',
               '個人歷史軌跡：按天保存在本機，設定頁裡看總里程 / 平均與最高速度 / 移動時長，可按天刪除或一鍵清空',
               'Personal track history: saved per day on the device, with total distance, average '
               'and top speed and moving time in Settings; delete a day or clear all')),
            ('up',
             T('去掉「视野内无台站」提示浮条：地图上已有信息条与工具列，不再多挂一条挡内容',
               '去掉「視野內無臺站」提示浮條：地圖上已有資訊條與工具列，不再多掛一條擋內容',
               'The "no stations in view" pill is gone: the map already has an info chip and a toolbar')),
        ],
    },
    {
        'ver': 'v1.6.139', 'date': '2026-09-21',
        'items': [
            ('new',
             T('UI 2.0：以地图为基底的新布局，「显示设置」里可随时切回经典布局',
               'UI 2.0：以地圖為基底的新佈局，「顯示設定」裡可隨時切回經典佈局',
               'UI 2.0: a new map-first layout, switchable back to the classic one in Display settings')),
        ],
    },
    {
        'ver': 'v1.6.138', 'date': '2026-09-20',
        'items': [
            ('new',
             T('界面材质：磨砂玻璃与云母两种材质，「显示设置」里可切换',
               '介面材質：磨砂玻璃與雲母兩種材質，「顯示設定」裡可切換',
               'UI materials: frosted glass and mica, switchable in Display settings')),
        ],
    },
    {
        'ver': 'v1.6.136', 'date': '2026-09-19',
        'items': [
            ('new',
             T('新增「硬件串口」：Android 支持 USB-OTG 串口线接电台，桌面端可调串口参数',
               '新增「硬體串列埠」：Android 支援 USB-OTG 串列埠線接電臺，桌面端可調串列埠參數',
               'New "hardware serial": USB-OTG serial on Android to wire a radio, with desktop '
               'serial parameters you can tune')),
        ],
    },
    {
        'ver': 'v1.6.135', 'date': '2026-09-19',
        'items': [
            ('fix',
             T('音频发射对方解不出：发射期间拉满音量、暂停麦克风，并给出接线与电平提示',
               '音訊發射對方解不出：發射期間拉滿音量、暫停麥克風，並給出接線與電平提示',
               'On-air audio that others could not decode: media volume is maxed and the mic '
               'muted during TX, with wiring and level hints')),
        ],
    },
    {
        'ver': 'v1.6.128', 'date': '2026-09-18',
        'items': [
            ('new',
             T('离线地图：把当前视图的瓦片一次下到本机（断点续传、单区域上限 20 万张），断网、无信号也能看',
               '離線地圖：把當前視圖的瓦片一次下載到本機（斷點續傳、單區域上限 20 萬張），斷網、無訊號也能看',
               'Offline maps: download the tiles of the current view once (resumable, 200k tiles '
               'per region) and keep the map with no network at all')),
        ],
    },
    {
        'ver': 'v1.6.124', 'date': '2026-09-18',
        'items': [
            ('new',
             T('主题：界面的颜色、图标、文字都能自己改，还能导出成 JSON 分享给别人',
               '主題：介面的顏色、圖示、文字都能自己改，還能匯出成 JSON 分享給別人',
               'Themes: recolour the UI, replace icons and text, and export the result as JSON to share')),
            ('new',
             T('主题可以带背景图，用自己照片当界面底；导出也可带上图片（v1.6.125–126）',
               '主題可以帶背景圖，用自己照片當介面底；匯出也可帶上圖片（v1.6.125–126）',
               'Themes can carry a background image — your own photo behind the UI; exports can '
               'include it too (v1.6.125–126)')),
        ],
    },
    {
        'ver': 'v1.6.123', 'date': '2026-09-18',
        'items': [
            ('new',
             T('备份与恢复：设置与数据导出成一个 JSON，换机或重装后导入即可',
               '備份與復原：設定與資料匯出成一個 JSON，換機或重裝後匯入即可',
               'Backup and restore: settings and data export to a single JSON, import it after a reinstall')),
        ],
    },
    {
        'ver': 'v1.6.121', 'date': '2026-09-17',
        'items': [
            ('new',
             T('短波组件新增 6m 波段预测；桌面组件支持暗黑模式；新增「系统状态」组件',
               '短波元件新增 6m 波段預測；桌面元件支援暗黑模式；新增「系統狀態」元件',
               'The HF widget gained 6 m band forecasts, widgets gained dark mode, and a '
               'system-status widget was added')),
        ],
    },
    {
        'ver': 'v1.6.117', 'date': '2026-09-17',
        'items': [
            ('new',
             T('短波与电离层传播：面板新增区块 + 独立桌面组件，SFI / Kp / A 指数与四个波段对的日 / 夜条件一眼看清',
               '短波與電離層傳播：面板新增區塊 + 獨立桌面元件，SFI / Kp / A 指數與四個波段對的日 / 夜條件一眼看清',
               'HF and ionospheric propagation: a new panel section plus a standalone widget, '
               'with SFI / Kp / A and day/night conditions for four band pairs at a glance')),
        ],
    },
    {
        'ver': 'v1.6.114', 'date': '2026-09-17',
        'items': [
            ('new',
             T('新增 Android 桌面小组件：天气 + 业余无线电提示，4 档尺寸自适应',
               '新增 Android 桌面小組件：天氣 + 業餘無線電提示，4 種尺寸自適應',
               'New Android home-screen widgets: weather plus ham-radio tips, in four adaptive sizes')),
        ],
    },
    {
        'ver': 'v1.6.113', 'date': '2026-09-15',
        'items': [
            ('fix',
             T('修「越用越卡」：APRS-IS 连接被反复重建导致 socket 泄漏，长时间运行不再越来越慢',
               '修「越用越卡」：APRS-IS 連線被反覆重建導致 socket 洩漏，長時間執行不再越來越慢',
               'Fixed "the longer it runs the slower it gets": the APRS-IS connection was '
               'rebuilt repeatedly, leaking sockets')),
        ],
    },
    {
        'ver': 'v1.6.109', 'date': '2026-09-15',
        'items': [
            ('up',
             T('主页「手动上报」与「连接」按钮加大（高度 44、字号 13，更好点按）',
               '主頁「手動上報」與「連接」按鈕加大（高度 44、字號 13，更好點按）',
               'Bigger home-page beacon / connect buttons (44px tall, 13px label)')),
            ('new',
             T('可以只留 PKWDWPL 一条来源：拿电台当纯接收机用，地图 / 台账照常，界面会明说「本机不会发射」',
               '可以只留 PKWDWPL 一條來源：拿電台當純接收機用，地圖 / 台賬照常，介面會明說「本機不會發射」',
               'A PKWDWPL-only setup is now allowed: use the radio as a pure receiver; the UI '
               'states plainly that nothing is transmitted')),
        ],
    },
    {
        'ver': 'v1.6.108', 'date': '2026-09-15',
        'items': [
            ('new',
             T('新增第 4 条数据来源「PKWDWPL」：读取 Kenwood 电台输出的 $PKWDWPL 航点语句，'
               '收到的台站直接上图（只读链路，不会发射）',
               '新增第 4 條資料來源「PKWDWPL」：讀取 Kenwood 電台輸出的 $PKWDWPL 航點語句，'
               '收到的台站直接上圖（唯讀鏈路，不會發射）',
               'New fourth data source "PKWDWPL": reads the $PKWDWPL waypoint sentences a Kenwood '
               'radio emits, plotting heard stations directly (receive-only, never transmits)')),
        ],
    },
    {
        'ver': 'v1.6.107', 'date': '2026-09-15',
        'items': [
            ('new',
             T('新增网关（iGate）：把射频收到的报文转到 APRS-IS，带 qAr / qAR 来路标识、'
               '环路防护与 30 秒去重',
               '新增閘道（iGate）：把射頻收到的報文轉到 APRS-IS，帶 qAr / qAR 來路標識、'
               '環路防護與 30 秒去重',
               'New gateway (iGate): relays RF packets into APRS-IS with qAr / qAR tagging, '
               'loop protection and 30-second de-duplication')),
            ('new',
             T('数据来源改为多选：几条链路可以一起收报文，发射来源仍单独指定一条',
               '資料來源改為多選：數條鏈路可以一起收報文，發射來源仍單獨指定一條',
               'Data sources became multi-select: several links can receive at once, while the '
               'transmit source stays a single choice')),
        ],
    },
    {
        'ver': 'v1.6.106', 'date': '2026-09-14',
        'items': [
            ('fix',
             T('真正修好「蓝牙 TNC 只能接收、不能发射」（Android）',
               '真正修好「藍牙 TNC 只能接收、不能發射」（Android）',
               'The actual fix for "Bluetooth TNC receives but will not transmit" (Android)')),
        ],
    },
    {
        'ver': 'v1.6.105', 'date': '2026-09-14',
        'items': [
            ('up',
             T('设备设置页重构：从「一个什么都有的大页面」改为按问题分层的三页',
               '裝置設定頁重構：從「一個什麼都有的大頁面」改為按問題分層的三頁',
               'Device settings split from one catch-all page into three pages grouped by the '
               'question you are asking')),
            ('up',
             T('群聊协议层收口成一个状态机（此前逻辑散落，边界情况容易出错）',
               '群聊協定層收口成一個狀態機（此前邏輯散落，邊界情況容易出錯）',
               'Group-chat protocol consolidated into a single state machine')),
        ],
    },
    {
        'ver': 'v1.6.104', 'date': '2026-09-14',
        'items': [
            ('new',
             T('新增数据来源「音频（声卡 TNC）」：用麦克风 / 扬声器接电台收发 AFSK 1200',
               '新增資料來源「音訊（音效卡 TNC）」：用麥克風 / 揚聲器接電台收發 AFSK 1200',
               'New "Audio (sound-card TNC)" data source: AFSK 1200 through your mic / speaker '
               'and a radio')),
            ('new',
             T('新增「链路自检」：TNC 与音频都能一键分层排查',
               '新增「鏈路自檢」：TNC 與音訊都能一鍵分層排查',
               'New link self-test: layered one-tap diagnosis for both TNC and audio')),
        ],
    },
    {
        'ver': 'v1.6.100', 'date': '2026-09-13',
        'items': [
            ('new',
             T('新增数据来源：蓝牙 TNC（含完整 KISS 控制）—— 从纯网络走向射频',
               '新增資料來源：藍牙 TNC（含完整 KISS 控制）—— 從純網路走向射頻',
               'New data source: Bluetooth TNC with full KISS control — the move from '
               'network-only towards RF')),
            ('new',
             T('聊天翻译：可双向、可对照、发送前先译成对方的语言',
               '聊天翻譯：可雙向、可對照、發送前先譯成對方的語言',
               'Chat translation: two-way, side-by-side, and pre-send into the other '
               'station\'s language')),
        ],
    },
]

# ─────────────────────────── 零散文案修正 ───────────────────────────
# (旧片段, {lang: 新片段})。改的是官网上已经说得不准的地方。
PATCHES = [
    ('简体中文 / 繁體中文 / English 可切换',
     {'zh': '简体中文 / 繁體中文 / English / 日本語 / Indonesia / Español 可切换'}),
    ('簡體中文 / 繁體中文 / English 可切換',
     {'zh_TW': '簡體中文 / 繁體中文 / English / 日本語 / Indonesia / Español 可切換'}),
    ('Simplified Chinese / Traditional Chinese / English UI',
     {'en': 'Simplified Chinese / Traditional Chinese / English / Japanese / Indonesian / '
            'Spanish UI'}),
    ('<li>简 / 繁 / 英</li>', {'zh': '<li>六种语言</li>'}),
    ('<li>簡 / 繁 / 英</li>', {'zh_TW': '<li>六種語言</li>'}),
    ('<li>ZH / ZH-TW / EN</li>', {'en': '<li>Six Languages</li>'}),
    # 更新日志只列重点版本 —— 必须说明清楚，否则从 v1.6.18 跳到 v1.6.100 看起来像漏了版本
    ('<p>近几个版本的主要变化。</p>',
     {'zh': '<p>近期重点版本的主要变化（中间数十个以修复为主的版本已合并，'
            '完整记录见 <a href="https://github.com/dariondong/APRSLocus/releases" '
            'target="_blank" rel="noopener">GitHub Releases</a>）。</p>'}),
    ('<p>近幾個版本的主要變化。</p>',
     {'zh_TW': '<p>近期重點版本的主要變化（中間數十個以修復為主的版本已合併，'
               '完整記錄見 <a href="https://github.com/dariondong/APRSLocus/releases" '
               'target="_blank" rel="noopener">GitHub Releases</a>）。</p>'}),
    ('<p>Recent changes across the latest releases.</p>',
     {'en': '<p>Highlights of recent releases — dozens of maintenance releases in between are '
            'folded in; see <a href="https://github.com/dariondong/APRSLocus/releases" '
            'target="_blank" rel="noopener">GitHub Releases</a> for the full history.</p>'}),
    # Hero 下方那行来源说明：只写 APRS-IS 已经不准了
    ('<span>APRS-IS 自动连接</span>',
     {'zh': '<span>APRS-IS · TNC · 音频 · PKWDWPL 四种来源</span>'}),
    ('<span>APRS-IS 自動連接</span>',
     {'zh_TW': '<span>APRS-IS · TNC · 音訊 · PKWDWPL 四種來源</span>'}),
    ('<span>APRS-IS Auto Connect</span>',
     {'en': '<span>APRS-IS · TNC · Audio · PKWDWPL</span>'}),
    # v1.6.149 移除了台站聚合 —— 功能卡里还写着「按呼号聚合」，已经不成立
    ('台站按呼号聚合，也能看轨迹回放。',
     {'zh': '一台站一个标记（v1.6.149 起去掉聚合），也能看轨迹回放，低缩放密度看热力图。'}),
    ('臺站按呼號聚合，也能看軌跡回放。',
     {'zh_TW': '一臺站一個標記（v1.6.149 起去掉聚合），也能看軌跡回放，低縮放密度看熱力圖。'}),
    ('Stations are grouped by callsign, with trail playback support.',
     {'en': 'One marker per station (clustering removed in v1.6.149), with trail playback '
            'support; the heatmap shows density when zoomed out.'}),
    ('<li>台站聚合</li>', {'zh': '<li>热力图</li>'}),
    ('<li>臺站聚合</li>', {'zh_TW': '<li>熱力圖</li>'}),
    ('<li>Station Clustering</li>', {'en': '<li>Heatmap</li>'}),
]


def strip_block(s, open_m, close_m):
    """删掉旧标记块（含标记本身），保证幂等。"""
    pat = re.compile(re.escape(open_m) + r'.*?' + re.escape(close_m) + r'\n?', re.S)
    return pat.sub('', s)


def render_cards(lang):
    out = [F_OPEN]
    for c in CARDS:
        tags = ''.join('<li>%s</li>' % t for t in c['tags'][lang])
        out.append(
            '    <article class="card reveal">\n'
            '      <div class="card-icon {icon}"><i class="fa-solid {fa}"></i></div>\n'
            '      <h3>{title}</h3>\n'
            '      <p>{desc}</p>\n'
            '      <ul class="card-tags">{tags}</ul>\n'
            '    </article>'.format(icon=c['icon'], fa=c['fa'],
                                   title=c['title'][lang], desc=c['desc'][lang],
                                   tags=tags))
    out.append('  ' + F_CLOSE)
    return '\n'.join(out)


def render_changelog(lang):
    out = [C_OPEN]
    for e in CL:
        out.append('    <div class="cl-version reveal">')
        out.append('      <div class="cl-head">')
        out.append('        <span class="cl-tag">%s</span>' % e['ver'])
        out.append('        <span class="cl-date">%s</span>' % e['date'])
        out.append('      </div>')
        out.append('      <div class="cl-body">')
        for kind, txt in e['items']:
            out.append('        <div class="cl-item"><span class="cl-dot %s"></span>%s</div>'
                       % (kind, txt[lang]))
        out.append('      </div>')
        out.append('    </div>')
    out.append('  ' + C_CLOSE)
    return '\n'.join(out)


def main():
    # 先自检文案表本身：三种语言必须齐全，否则漏写会静默少字（很难发现）
    for c in CARDS:
        for field in ('title', 'desc'):
            missing = [l for l in LANGS if not c[field].get(l)]
            assert not missing, '卡片 %s 缺 %s 文案：%s' % (c['title']['zh'], field, missing)
        for l in LANGS:
            assert c['tags'].get(l), '卡片 %s 缺 %s 标签' % (c['title']['zh'], l)
    for e in CL:
        for kind, txt in e['items']:
            missing = [l for l in LANGS if not txt.get(l)]
            assert not missing, '%s 的条目缺 %s 文案' % (e['ver'], missing)
            # 半简半繁是上次踩过的坑：繁体文案里不该出现这几个常用简体字
            # 注意：黑名单必须是「简体才有、繁体不同形」的字。
            # `率` 曾是成员，但它在简繁里同形（`頻率` 的繁体只差 `頻`）—— 
            # 于是「心率」这种完全正确的繁体写法被误判成混入简体字（v1.6.165 现场踩到）。
            # 假失败比没有检查更坏：修它的人只会把规则整个删掉。
            bad = [ch for ch in '连发条来设备页题单网络报频识环钥译对开关机边缘错击码'
                   if ch in txt['zh_TW']]
            assert not bad, '%s 的繁体文案混入简体字：%s' % (e['ver'], bad)

    counts = {}
    for lang, rel in PAGES.items():
        path = os.path.join(ROOT, rel)
        s = io.open(path, encoding='utf-8', newline='').read()
        before = len(s)

        # 1) 零散文案修正（命中 0 次=已改过；>1 次=结构变了，必须报错）
        for old, repl in PATCHES:
            new = repl.get(lang)
            if new is None:
                continue
            n = s.count(old)
            if n == 1:
                s = s.replace(old, new)
            elif n > 1:
                raise SystemExit('[%s] 片段出现 %d 次，无法安全替换：%s' % (lang, n, old[:40]))

        # 2) 功能卡片：追加到 #features 的 cards 容器末尾
        s = strip_block(s, F_OPEN, F_CLOSE)
        fi = s.index('id="features"')
        close = s.index('\n  </div>\n</section>', fi)
        s = s[:close] + '\n' + render_cards(lang) + s[close:]

        # 3) 更新日志：插到 changelog-list 容器开头（新的在前）
        s = strip_block(s, C_OPEN, C_CLOSE)
        anchor = '<div class="changelog-list">'
        ci = s.index(anchor) + len(anchor)
        s = s[:ci] + '\n' + render_changelog(lang) + s[ci:]

        io.open(path, 'w', encoding='utf-8', newline='').write(s)

        counts[lang] = (s.count('<article class="card reveal">'),
                        s.count('<div class="cl-version reveal">'))
        print('%-6s 卡片 %d · 更新日志 %d 条 · %d → %d 字节'
              % (lang, counts[lang][0], counts[lang][1], before, len(s)))

    if len(set(counts.values())) != 1:
        raise SystemExit('三个语言页数量不一致：%s' % counts)
    cards, cls = next(iter(set(counts.values())))
    print('\n✅ 三页一致：%d 张功能卡片（新增 %d），%d 条更新日志（新增 %d）'
          % (cards, len(CARDS), cls, len(CL)))


if __name__ == '__main__':
    main()
