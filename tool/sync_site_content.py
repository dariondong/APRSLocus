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
        'title': T('五种数据来源', '五種資料來源', 'Five Data Sources'),
        'desc': T(
            '互联网（APRS-IS）、蓝牙 / 串口 TNC（KISS）、声卡音频 AFSK 1200（Bell 202 软 TNC）、'
            'Kenwood 航点 <code>$PKWDWPL</code>（只收不发），以及 WLAN 电台直连（支持 IC-705 / IC-9700 / IC-7610 / IC-905 等 Wi-Fi / 以太网型号，CI-V 控制与局域网音频）。'
            '多条链路可以同时收报文，发射来源单独指定一条。',
            '網際網路（APRS-IS）、藍牙 / 串列埠 TNC（KISS）、音效卡音訊 AFSK 1200（Bell 202 軟 TNC）、'
            'Kenwood 航點 <code>$PKWDWPL</code>（唯讀、不發射），以及 WLAN 電台直連（支援 IC-705 / IC-9700 / IC-7610 / IC-905 等 Wi-Fi / 乙太網路型號，CI-V 控制與區域網路音訊）。'
            '數條鏈路可以同時收報文，發射來源單獨指定一條。',
            'Internet (APRS-IS), Bluetooth / serial TNC (KISS), sound-card AFSK 1200 (Bell 202 software TNC), '
            'Kenwood <code>$PKWDWPL</code> waypoints (receive-only), and WLAN radio direct link (supporting IC-705 / IC-9700 / IC-7610 / IC-905 over Wi-Fi / Ethernet with CI-V and LAN audio). '
            'Multiple links can receive simultaneously, while the transmit link is picked separately.'),
        'tags': {'zh': ['APRS-IS', 'TNC', '音频', 'PKWDWPL', 'WLAN 电台'],
                 'zh_TW': ['APRS-IS', 'TNC', '音訊', 'PKWDWPL', 'WLAN 電台'],
                 'en': ['APRS-IS', 'TNC', 'Audio', 'PKWDWPL', 'WLAN Radio']},
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
        'ver': 'v2.0.47', 'date': '2026-10-09',
        'items': [
            ('fix',
             T('**点空白收起键盘**：点聊天框以外任意处即取消输入聚焦；'
               '**设置页整理对齐**（图标底座 / 图标 / 箭头尺寸统一，说明文字'
               '左端对齐）；「关于」下方新增「**用户反馈**」入口，直达'
               '**仓库 Issue**。',
               '**點空白收起鍵盤**：點聊天框以外任意處即取消輸入聚焦；'
               '**設定頁整理對齊**（圖示底座 / 圖示 / 箭頭尺寸統一，說明文字'
               '左端對齊）；「關於」下方新增「**使用者回饋**」入口，直達'
               '**倉庫 Issue**。',
               '**Tap outside to dismiss the keyboard**: tapping anywhere outside '
               'the compose box clears focus; the **settings page is aligned** '
               '(unified icon-tile / icon / chevron sizes, descriptions start at '
               'the same x); a new "**Feedback**" entry under "About" opens the '
               '**repo issues**.')),
        ],
    },
    {
        'ver': 'v2.0.46', 'date': '2026-10-09',
        'items': [
            ('up',
             T('**输入框更顺手**：主操作键平时是「＋」（发位置点），**一点进输入框就'
               '变成「发送」**；「**译发**」也从「＋」里**挪到外面常驻**，一键可用。'
               '分享出去的位置点点一下会弹**小面板**，可直接选**在地图查看**或'
               '**导航**。',
               '**輸入框更順手**：主操作鍵平時是「＋」（傳位置點），**一點進輸入框就'
               '變成「傳送」**；「**譯發**」也從「＋」裡**挪到外面常駐**，一鍵可用。'
               '分享出去的位置點點一下會彈**小面板**，可直接選**在地圖檢視**或'
               '**導航**。',
               '**A handier compose bar**: the main key is "+" (send a location) by '
               'default and **turns into "send" as soon as you tap into the field**; '
               '**"translate" moved out** of the "+" sheet to a **permanent button**. '
               'Tapping a shared location opens a **small sheet** to **view it on the '
               'map** or **navigate** to it.')),
        ],
    },
    {
        'ver': 'v2.0.45', 'date': '2026-10-09',
        'items': [
            ('new',
             T('**选台站，能搜能翻页**：私聊「+ → 发送位置点」里新增「选择台站」，'
               '**按呼号 / 别名搜索**、**分页浏览**（每页 20 条、上/下页带文字按钮），'
               '有定位时按**近 → 远**排序；行尾可先看台站详情。'
               '台站详情「更多」里也能**把这个台站分享到其它会话**。',
               '**選台站，能搜能翻頁**：私聊「+ → 傳送位置點」裡新增「選擇台站」，'
               '**按呼號 / 別名搜尋**、**分頁瀏覽**（每頁 20 筆、上/下頁帶文字按鈕），'
               '有定位時按**近 → 遠**排序；行尾可先看台站詳情。'
               '台站詳情「更多」裡也能**把這個台站分享到其它會話**。',
               '**Pick a station — search & paging**: the private-chat "+ → send '
               'location" menu now offers "Pick a station" with **search by callsign / '
               'alias** and **paged browsing** (20 rows per page, labelled prev/next '
               'buttons), sorted **near → far** when a position is known; each row can '
               'open station details first. A station\'s "More" menu can also **share '
               'that station to other chats**.')),
            ('up',
             T('**位置点自由选、样式统一**：分享位置点在地图上**任取坐标**（或「我的'
               '位置」）；点按后**套用台站面板**，可直接**呼出导航**。'
               '对话里的**呼号识别修正**：只要形如呼号即可点击，已在台站列表用实线、'
               '暂未收到的用虚线，点开都能看台站面板。',
               '**位置點自由選、樣式統一**：分享位置點在地圖上**任取座標**（或「我的'
               '位置」）；點按後**套用台站面板**，可直接**呼出導航**。'
               '對話裡的**呼號識別修正**：只要形如呼號即可點擊，已在台站列表用實線、'
               '暫未收到的用虛線，點開都能看台站面板。',
               '**Free-picked locations, unified panel**: pick any point on the map (or '
               '"My position") to share a location; tapping it **reuses the station '
               'panel**, putting **navigation** one tap away. **Callsign recognition '
               'fixed** in messages: any callsign-looking word is clickable — solid '
               'underline for known stations, dotted for not-yet-heard ones, all opening '
               'the station panel.')),
        ],
    },
    {
        'ver': 'v2.0.44', 'date': '2026-10-09',
        'items': [
            ('new',
             T('**私聊也能发位置**：一对一会话里点输入栏「+」即可**在私聊发送位置点**'
               '——拖动地图任取坐标，或直接「我的位置」；还能**分享某个台站**。'
               '对方收到后是一条专用卡片消息。',
               '**私聊也能傳位置**：一對一會話裡點輸入欄「+」即可**在私聊傳送位置點**'
               '——拖動地圖任取座標，或直接「我的位置」；還能**分享某個台站**。'
               '對方收到後是一條專用卡片訊息。',
               '**Send a location in a private chat**: in a one-to-one conversation tap the '
               'compose "+" to **send a location** — drag the map to pick any point, or use '
               '"My position"; you can also **share a station**. The peer receives it as a '
               'dedicated card message.')),
            ('up',
             T('**消息里的呼号可点击**：对话中识别到的台站呼号像超链接一样，点一下即'
               '打开台站详情；分享台站的位置卡片点按同样是打开台站面板（自由选点则跳'
               '主地图）。输入栏也收敛成微信式的一个「+」。',
               '**訊息裡的呼號可點擊**：對話中識別到的台站呼號像超連結一樣，點一下即'
               '開啟台站詳情；分享台站的位置卡片點按同樣是開啟台站面板（自由選點則跳'
               '主地圖）。輸入欄也收斂成微信式的一個「+」。',
               '**Clickable callsigns in messages**: a station callsign recognized in a '
               'conversation behaves like a hyperlink and opens station details; the shared '
               'station card does the same, while a free-picked location jumps to the main '
               'map. The compose bar is collapsed into a single WeChat-style "+".')),
        ],
    },
    {
        'ver': 'v2.0.43', 'date': '2026-10-09',
        'items': [
            ('new',
             T('**策略地图更顺手**：点队友/自己标点直接打开**台站详细面板**；'
               '「导航」交给手机地图应用（高德 → 系统地图 → 浏览器 OSM）；地图上新增'
               '**「我」的位置**（蓝点 + 呼号 + 方位角）与「定位到我」一键回位。',
               '**策略地圖更順手**：點隊友/自己標點直接開啟**台站詳細面板**；'
               '「導航」交給手機地圖 App（高德 → 系統地圖 → 瀏覽器 OSM）；地圖上新增'
               '**「我」的位置**（藍點 + 呼號 + 方位角）與「定位到我」一鍵回位。',
               '**Strategy map, easier to use**: tapping a teammate/self marker opens the '
               '**station detail panel**; "navigate" hands off to the phone\'s map app '
               '(AMap → system maps → browser OSM); the map now draws **your own '
               'position** (blue dot + callsign + bearing) with a one-tap "locate me".')),
            ('up',
             T('**策略变动在群聊留痕**：新增 / 改动 / 删除 / 清空图层都会在群聊留一条'
               '提示，队友点一下即跳进策略地图；**群聊发送不再弹确认**，直接发'
               '（未连接服务器会先拦下提示）。',
               '**策略變動在群聊留痕**：新增 / 改動 / 刪除 / 清空圖層都會在群聊留一條'
               '提示，隊友點一下即跳進策略地圖；**群聊傳送不再彈確認**，直接傳'
               '（未連接伺服器會先攔下提示）。',
               '**Strategy changes leave a trail**: add / edit / delete / clear all leave a '
               'notice in group chat, and a tap jumps into the strategy map; **group send '
               'no longer asks for confirmation** and just sends (with a pre-check when the '
               'server is offline).')),
        ],
    },
    {
        'ver': 'v2.0.42', 'date': '2026-10-09',
        'items': [
            ('new',
             T('**策略地图升级**：地图上新增**队友位置 + 方位角小角标**（按去 SSID 的'
               '基呼号匹配群成员台站，静止/无航向就不画），**线 / 圈可选颜色**（全网'
               '一致六色调色板），画点等**策略消息在群聊留可点击提示**，点一下直接跳进'
               '对应群的策略地图。',
               '**策略地圖升級**：地圖上新增**隊友位置 + 方位角小角標**（按去 SSID 的'
               '基呼號匹配群成員台站，靜止/無航向就不畫），**線 / 圈可選顏色**（全網'
               '一致六色調色盤），畫點等**策略訊息在群聊留可點擊提示**，點一下直接跳進'
               '對應群的策略地圖。',
               '**Strategy map upgrades**: the map now shows **teammate positions with a '
               'bearing badge** (matched to group members by SSID-stripped base callsign; no '
               'badge when stationary or without a heading), **lines/circles get selectable '
               'colors** (a network-wide six-color palette), and a strategy element leaves a '
               '**clickable notice in group chat** that jumps straight into that group\'s '
               'strategy map.')),
            ('up',
             T('**射频也能用群聊与策略地图**：`groupChatAllowed` 放开为始终可用，'
               '射频（TNC / 音频）下策略帧改用带 ack 格式，借队友的标准自动 ack 判断'
               '送达；90 秒未确认视为「不确认」（队友可能关了自动 ack），可在策略地图页'
               '手动重发。',
               '**射頻也能用群聊與策略地圖**：`groupChatAllowed` 放開為始終可用，'
               '射頻（TNC / 音訊）下策略幀改用帶 ack 格式，借隊友的標準自動 ack 判斷'
               '送達；90 秒未確認視為「不確認」（隊友可能關了自動 ack），可在策略地圖頁'
               '手動重發。',
               '**Group chat and the strategy map now work on RF**: `groupChatAllowed` is '
               'always on; on RF (TNC / audio) strategy frames are sent ack-requesting and '
               'delivery is judged by teammates\' standard auto-ack; unacked after 90s is '
               'treated as "unconfirmed" (a peer may have auto-ack off) and can be resent '
               'manually from the strategy map page.')),
            ('fix',
             T('**修复策略点「跳转导航」**：策略点不在台站表里，补画一枚焦点标记，'
               '跳转改为瞬时落位（不再走过渡动画），不会再停在「飞了一半」的中间态。',
               '**修復策略點「跳轉導航」**：策略點不在台站表裡，補畫一枚焦點標記，'
               '跳轉改為瞬時落位（不再走過渡動畫），不會再停在「飛了一半」的中間態。',
               '**Fixed strategy-point "jump to navigation"**: a strategy point is not in '
               'the station list, so a focus marker is now painted; the jump snaps '
               'instantly instead of animating and stalling mid-flight.')),
        ],
    },
    {
        'ver': 'v2.0.41', 'date': '2026-10-03',
        'items': [
            ('new',
             T('**群内「策略地图」**：与队友 / 群组共享**标点、线、圈、集合点**，'
               '复用现有群组、数据经 APRS 消息传输（帧前缀 `$M`，超长的线自动分片，'
               '任何帧都 ≤ 67 字符）；元素支持**跳转导航**与编辑附带信息，可「清空'
               '图层」同步全群。',
               '**群內「策略地圖」**：與隊友 / 群組共享**標點、線、圈、集合點**，'
               '複用現有群組、資料經 APRS 訊息傳輸（幀前綴 `$M`，過長的線自動分片，'
               '任何幀都 ≤ 67 字元）；元素支援**跳轉導航**與編輯附帶資訊，可「清空'
               '圖層」同步全群。',
               '**In-group "Strategy Map"**: share **points, lines, circles and rally '
               'points** with teammates/groups, reusing existing groups and transported '
               'over APRS messages (frame prefix `$M`, long lines auto-chunked, every '
               'frame ≤ 67 chars); elements support **jump-to-navigation** and editing '
               'attached info, and "clear layer" syncs to the whole group.')),
            ('new',
             T('**地图长按快捷消息**：长按 beacon / 台站弹出快捷消息面板，'
               '复用现有发送链路。',
               '**地圖長按快捷訊息**：長按 beacon / 台站彈出快捷訊息面板，'
               '複用現有傳送鏈路。',
               '**Long-press quick message**: long-pressing a beacon/station opens a '
               'quick-message sheet, reusing the existing send path.')),
            ('up',
             T('**移除 OOBE Passcode 提示**：首次启动引导里不再出现「获取 Passcode」'
               '提示。',
               '**移除 OOBE Passcode 提示**：首次啟動引導裡不再出現「取得 Passcode」'
               '提示。',
               '**Removed the OOBE passcode hint**: the first-run guide no longer shows '
               'a "get Passcode" hint.')),
        ],
    },
    {
        'ver': 'v2.0.40', 'date': '2026-10-08',
        'items': [
            ('new',
             T('**消息页「发射位置信标」按钮**：消息页大标题右侧新增一键按钮，'
               '随手手动发射一次位置信标（与地图页「立即上报」同一动作），'
               '不改动自动上报开关；位置还没就绪时如实提示「等待定位」，'
               '窄面板下自动缩为图标。',
               '**訊息頁「發射位置信標」按鈕**：訊息頁大標題右側新增一鍵按鈕，'
               '隨手手動發射一次位置信標（與地圖頁「立即上報」同一動作），'
               '不改動自動上報開關；位置還沒就緒時如實提示「等待定位」，'
               '窄面板下自動縮為圖示。',
               '**"Transmit position beacon" button on Messages**: a one-tap button '
               'sits to the right of the Messages page title, firing a single position '
               'beacon on demand (the same action as the map page\'s "Beacon now") '
               'without touching the automatic-report toggle; when no fix is ready it '
               'says "waiting for a fix" honestly, and collapses to an icon in narrow '
               'panels.')),
        ],
    },
    {
        'ver': 'v2.0.39', 'date': '2026-10-08',
        'items': [
            ('new',
             T('**备份包含历史轨迹**：导出备份时，「设置配置」分组会一并带上**历史轨迹**'
               '（按天原样搬运），换机导入后轨迹照常保留、可继续翻账。备份格式升到 **v2**，'
               '旧备份（v1）仍可导入；轨迹在导入时**按天合并**，本机较新的一天不会被旧'
               '备份顶掉。轨迹是不带类型标签的独立载荷，不参与偏好白名单校验。',
               '**備份包含歷史軌跡**：匯出備份時，「設定」分組會一併帶上**歷史軌跡**'
               '（按天原樣搬運），換機匯入後軌跡照常保留、可繼續翻帳。備份格式升到 **v2**，'
               '舊備份（v1）仍可匯入；軌跡在匯入時**按天合併**，本機較新的一天不會被舊'
               '備份蓋掉。軌跡是不帶型別標籤的獨立酬載，不參與偏好白名單檢查。',
               '**Backups include track history**: exporting a backup now folds **track '
               'history** into the "Settings" group (moved verbatim, day by day), so the '
               'history survives a device move and can still be reviewed. The backup schema '
               'goes to **v2** while old v1 backups still import; on import, days are '
               '**merged**, so a newer local day is not overwritten by an older backup. '
               'Tracks travel as a separate, untyped payload outside the preference '
               'whitelist.')),
            ('up',
             T('**关于页文案**：副标题去掉「本机」限定词，六语言统一为'
               '「APRS 客户端 · 定位与地图」，不再让人误以为只在本机运行。',
               '**關於頁文案**：副標題去掉「本機」限定詞，六語言統一為'
               '「APRS 用戶端 · 定位與地圖」，不再讓人誤以為只在本機執行。',
               '**About wording**: the subtitle drops the "Local" qualifier in all six '
               'locales, now "APRS client · tracking & map", so it no longer implies the '
               'app only runs locally.')),
        ],
    },
    {
        'ver': 'v2.0.38', 'date': '2026-10-07',
        'items': [
            ('new',
             T('**天地图图层**：底图新增「天地图」分组，共三张 —— `天地图 矢量`（vec）、'
               '`天地图 影像`（img）、`天地图 地形`（ter）。天地图的底图**本身不含地名**，'
               '文字在单独的透明注记层（cva/cia/cta），因此每张底图都会**叠上对应注记**'
               '（矢量叠 cva、影像叠 cia、地形叠 cta）；底图与注记分开缓存、离线时一起'
               '下载，不会出现「有图无地名」。天地图实测为 **WGS-84**（与 Esri/OSM 影像'
               '零偏移），因此不做 GCJ 纠偏，可与 OSM 互为兜底；瓦片支持到 z18。Key 走'
               '构建期注入（CI Secret `TIANDITU_KEY`），源码不落 key；未配置时自动退到'
               ' OSM，地图照常可用。',
               '**天地圖圖層**：底圖新增「天地圖」分組，共三張 —— `天地圖 向量`（vec）、'
               '`天地圖 影像`（img）、`天地圖 地形`（ter）。天地圖的底圖**本身不含地名**，'
               '文字在單獨的透明註記層（cva/cia/cta），因此每張底圖都會**疊上對應註記**'
               '（向量疊 cva、影像疊 cia、地形疊 cta）；底圖與註記分開快取、離線時一起'
               '下載，不會出現「有圖無地名」。天地圖實測為 **WGS-84**（與 Esri/OSM 影像'
               '零偏移），因此不做 GCJ 糾偏，可與 OSM 互為兜底；圖磚支援到 z18。Key 走'
               '建置期注入（CI Secret `TIANDITU_KEY`），原始碼不落 key；未設定時自動退到'
               ' OSM，地圖照常可用。',
               '**Tianditu layers**: the basemaps gain a "Tianditu" group with three '
               'layers — `Tianditu Vector` (vec), `Tianditu Imagery` (img) and '
               '`Tianditu Terrain` (ter). Their base tiles carry **no place labels**; text '
               'lives in separate transparent annotation layers (cva/cia/cta), so each '
               'basemap is **composited with its matching overlay** (vector+cva, '
               'imagery+cia, terrain+cta). Base and annotation are cached separately and '
               'downloaded together offline, so you never get a map with no place names. '
               'Tianditu is measured as **WGS-84** (zero offset vs Esri/OSM imagery), so '
               'it is not GCJ-shifted and falls back to OSM; tiles go up to z18. The key '
               'is injected at build time (CI Secret `TIANDITU_KEY`), never committed to '
               'source; when absent the map falls back to OSM and stays usable.')),
        ],
    },
    {
        'ver': 'v2.0.37', 'date': '2026-10-07',
        'items': [
            ('new',
             T('**地形 / 等高线图图层**：地图底图新增「地形」分组，一次给到四张对登山友好的'
               '地形底图 —— `OpenTopo 地形`（带等高线，从「其他」移入）、`Esri 地形(等高线)`'
               '（路网 + 地名 + 等高线，最像纸质等高线地形图）、`Esri 地形浮雕`（纯浮雕，'
               '看整体地形最干净）、`Esri 山体阴影`（只看沟壑走向）。四张都免 Key、可离线'
               '下载、与 OSM 互为兜底；它们本就是 WGS-84 国际瓦片，因此不做 GCJ 纠偏，'
               '不会整体偏位。',
               '**地形 / 等高線圖圖層**：地圖底圖新增「地形」分組，一次給到四張對登山友善'
               '的地形底圖 —— `OpenTopo 地形`（帶等高線，從「其他」移入）、`Esri 地形(等高線)`'
               '（路網 + 地名 + 等高線，最像紙本等高線地形圖）、`Esri 地形浮雕`（純浮雕，'
               '看整體地形最乾淨）、`Esri 山體陰影`（只看溝壑走向）。四張都免 Key、可離線'
               '下載、與 OSM 互為兜底；它們本就是 WGS-84 國際圖磚，因此不做 GCJ 糾偏，'
               '不會整體偏位。',
               '**Terrain / contour layers**: the basemaps gain a "Terrain" group with four '
               'hiking-friendly layers — `OpenTopo Terrain` (with contours, moved out of '
               '"Others"), `Esri Topo (contours)` (roads + labels + contours, closest to a '
               'paper contour map), `Esri Shaded Relief` (pure relief, cleanest for overall '
               'terrain) and `Esri Hillshade` (valley direction only). All four are key-free, '
               'offline-downloadable and fall back to OSM; being native WGS-84 international '
               'tiles, they are not GCJ-shifted and will not offset.')),
        ],
    },
    {
        'ver': 'v2.0.36', 'date': '2026-10-03',
        'items': [
            ('up',
             T('**连上服务器后手动确认再上报**：无论用哪种方式定位，连上服务器后都'
               '**不再自动上报位置**。主界面上报动作组给出一枚正式的「开始上报」'
               '按钮 —— 拿到本轮有效定位前置灰显示「等待定位」，确认坐标有效后点一下'
               '才开始按间隔自动上报，并立刻补发一次让用户在地图上看到自己。断开 / '
               '重连 / 重开 App 都会复位这个确认，绝不回到「连上就自动上报」；'
               '顺带去掉了连接成功后自动弹出的询问弹窗，改为这枚按钮（不打扰）。',
               '**連上伺服器後手動確認再上報**：無論用哪種方式定位，連上伺服器後都'
               '**不再自動上報位置**。主介面上報動作組給出一枚正式的「開始上報」'
               '按鈕 —— 拿到本輪有效定位前置灰顯示「等待定位」，確認座標有效後點一下'
               '才開始按間隔自動上報，並立刻補發一次讓使用者在地圖上看到自己。斷線 / '
               '重連 / 重開 App 都會復位這個確認，絕不回到「連上就自動上報」；'
               '順帶去掉了連線成功後自動彈出的詢問彈窗，改為這枚按鈕（不打擾）。',
               '**Manual confirmation before reporting**: whatever positioning method is '
               'used, the app **no longer auto-reports the position after connecting**. The '
               'report action group now shows a formal "Start reporting" button — disabled as '
               '"Waiting for fix" until a valid fix for this round arrives, then one tap starts '
               'interval reporting and sends an immediate beacon so you can see yourself on the '
               'map. Disconnect / reconnect / restart all reset this confirmation, never falling '
               'back to "auto-report on connect"; the post-connect popup was also replaced by '
               'this button (non-intrusive).')),
            ('up',
             T('**荣誉墙更好看**：成员荣誉墙加上工具条 —— 搜索框（按姓名 / 呼号 / 称号'
               '过滤）、实时概览（多少位伙伴、多少枚徽章）、以及可横向滚动的徽章图例'
               '（点一下直达对应分组）。卡片、分组标题与响应式布局一并打磨，键盘也能'
               '导航；**荣誉卡的导出样式（PNG）保持原样不变**。',
               '**榮譽牆更好看**：成員榮譽牆加上工具列 —— 搜尋框（依姓名 / 呼號 / 稱號'
               '篩選）、即時概覽（多少位夥伴、多少枚徽章）、以及可橫向捲動的徽章圖例'
               '（點一下直達對應分組）。卡片、分組標題與響應式版面一併打磨，鍵盤也能'
               '導覽；**榮譽卡的匯出樣式（PNG）維持原樣不變**。',
               '**Nicer honor wall**: the member honor wall gains a toolbar — a search box '
               '(filter by name / callsign / honor), a live overview (members, badges) and a '
               'horizontally scrollable badge legend that jumps to each group. Cards, group '
               'headings and the responsive layout were polished, and it is keyboard '
               'navigable; **the exported honor-card (PNG) style is left untouched**.')),
        ],
    },
    {
        'ver': 'v2.0.35', 'date': '2026-10-06',
        'items': [
            ('fix',
             T('**模拟位置重启后不自动生效**：选了「模拟位置 + 手动定位」并保存了坐标后，'
               '下次启动 App 虽然把坐标装了回来，上报闸却一直关着 —— 界面停在「等待定位」，'
               '必须再点一次「应用坐标」才能定位上报。原因：启动时把保存的坐标一律当成'
               '「上次的实时定位」关闸（GPS 模式下这是对的，防止定位没开就报旧坐标），'
               '而 GPS 的自动定位路径又会被「模拟位置」挡掉，于是这个闸永远开不了。现在'
               '模拟位置下保存的坐标**就是**用户选定的坐标，启动即放行、并同步过滤中心；'
               '顺带把模拟位置的保活前台服务也在启动时拉起（与 GPS 模式对称）。',
               '**模擬位置重啟後不自動生效**：選了「模擬位置 + 手動定位」並儲存座標後，'
               '下次啟動 App 雖然把座標裝了回來，上報閘卻一直關著 —— 介面停在「等待定位」，'
               '必須再點一次「套用座標」才能定位上報。原因：啟動時把儲存的座標一律當成'
               '「上次的即時定位」關閘（GPS 模式下這是對的，避免定位沒開就報舊座標），'
               '而 GPS 的自動定位路徑又會被「模擬位置」擋掉，於是這個閘永遠開不了。現在'
               '模擬位置下儲存的座標**就是**使用者選定的座標，啟動即放行、並同步過濾中心；'
               '順帶把模擬位置的保活前景服務也在啟動時拉起（與 GPS 模式對稱）。',
               '**Simulated location not applied after restart**: after choosing '
               '"simulated location + manual fix" and saving coordinates, the next launch '
               'restored the coordinates but kept the reporting gate closed — the UI sat at '
               '"waiting for location" and you had to tap "Apply coordinates" again. Cause: '
               'startup treated any saved coordinates as "last round\'s live fix" and closed '
               'the gate (correct for GPS, to avoid reporting a stale position with location '
               'off), while the GPS auto-locate path is skipped in simulated mode — so the '
               'gate never opened. Now, in simulated mode the saved coordinates **are** the '
               'chosen position: they are accepted on startup and the filter center follows; '
               'the simulated-mode keep-alive foreground service is also started at boot, '
               'symmetric with GPS mode.')),
        ],
    },
    {
        'ver': 'v2.0.34', 'date': '2026-10-03',
        'items': [
            ('fix',
             T('**非整数缩放级别下地图发糊**：实测各图源返回的像素后发现，除了高德街道'
               '（wprd 主机 + `scl=2`）给 512px，Carto / OSM / Esri / 腾讯 / 高德卫星**都只有 '
               '256px** —— 图源本身不是主因。真正的问题在选层级：地图用 `zoom.floor()` 取瓦片级，'
               '于是整档 `[z, z+1)` 都取 z 级瓦片，越接近 `z+1` 源图被拉得越大（z=12.9 时 '
               '**1.93×**），再乘屏幕像素密度 2~3 倍，物理上放大 4~6 倍，必然糊。改用 '
               '`zoom.round()`：放大封顶在 √2≈1.41×，后半档转为缩小，**对所有图源**都生效。',
               '**非整數縮放級別下地圖發糊**：實測各圖源回傳的像素後發現，除了高德街道'
               '（wprd 主機 + `scl=2`）給 512px，Carto / OSM / Esri / 騰訊 / 高德衛星**都只有 '
               '256px** —— 圖源本身不是主因。真正的問題在選層級：地圖用 `zoom.floor()` 取瓦片級，'
               '於是整檔 `[z, z+1)` 都取 z 級瓦片，越接近 `z+1` 源圖被拉得越大（z=12.9 時 '
               '**1.93×**），再乘螢幕像素密度 2~3 倍，物理上放大 4~6 倍，必然糊。改用 '
               '`zoom.round()`：放大封頂在 √2≈1.41×，後半檔轉為縮小，**對所有圖源**都生效。',
               '**Blurry map at fractional zoom levels**: measuring the pixels each source returns '
               'showed that apart from Gaode street (wprd host + `scl=2`, 512px), Carto / OSM / '
               'Esri / Tencent / Gaode satellite **only serve 256px** — the source was not the '
               'cause. The real issue was level selection: the map used `zoom.floor()`, so the '
               'whole `[z, z+1)` band pulled level-`z` tiles, stretching the source up to **1.93×** '
               'at z=12.9 and then 2–3× more by screen pixel density — a 4–6× physical upscale, '
               'hence blur. It now uses `zoom.round()`: the upscale is capped at √2≈1.41× and the '
               'upper half downscales. **Applies to every source.**')),
        ],
    },
    {
        'ver': 'v2.0.33', 'date': '2026-10-03',
        'items': [
            ('up',
             T('**上报界面合并，一处开关两处按钮**：把分散在地图状态栏、我的面板、沉浸页的'
               '「立即上报」收进共用的 `ReportActions`（自动上报开关 + 立即上报按钮），删掉重复实现与'
               '「上报成功」的假提示；设置里统一叫「自动上报」并加了指回主界面的说明。',
               '**上報介面合併，一處開關兩處按鈕**：把分散在地圖狀態列、我的面板、沉浸頁的'
               '「立即上報」收進共用的 `ReportActions`（自動上報開關 + 立即上報按鈕），刪掉重複實作與'
               '「上報成功」的假提示；設定裡統一叫「自動上報」並加了指回主介面的說明。',
               '**One reporting control, two buttons**: the scattered "report now" actions on the '
               'map status bar, the My panel and the immersive page are consolidated into a shared '
               '`ReportActions` (auto-report switch + report-now button); the duplicate '
               'implementations and the false "reported" toast are gone. Settings now use the '
               'unified "自动上报" wording with a hint pointing back to the main UI.')),
        ],
    },
    {
        'ver': 'v2.0.32', 'date': '2026-10-03',
        'items': [
            ('new',
             T('**数据维护页重排 + 恢复出厂**：把「台站保留天数」从「连接设置 → 存储上限」'
               '移进「数据维护」页、与清理按钮同页（改为下拉选择）；手动清理不再复用自动清理的'
               '天数，而是**当场选一个独立天数**；新增**「清除所有数据并重新初始化」**——连呼号、'
               '服务器、信标、界面等全部设置一起清除，并重新运行首次引导。',
               '**資料維護頁重排 + 恢復出廠**：把「台站保留天數」從「連線設定 → 儲存上限」'
               '移進「資料維護」頁、與清理按鈕同頁（改為下拉選擇）；手動清理不再複用自動清理的'
               '天數，而是**當場選一個獨立天數**；新增**「清除所有資料並重新初始化」**——連呼號、'
               '伺服器、信標、介面等全部設定一起清除，並重新執行首次引導。',
               '**Data-maintenance page rework + factory reset**: retention days moved from '
               '*Connection → Storage limits* onto the *Data maintenance* page next to the prune '
               'button (as a dropdown); manual pruning no longer reuses the auto-prune days — you '
               '**pick its own days** on the spot; and a new **"Erase all data and start over"** '
               'clears **all settings including callsign, server, beacon and UI** and re-runs the '
               'first-run wizard.')),
        ],
    },
    {
        'ver': 'v2.0.31', 'date': '2026-10-03',
        'items': [
            ('fix',
             T('**自定义状态「有时还显示 CONNECT」**：状态报文是「内置身份帧 + 自定义状态」一对，'
               '写的是 aprs.fi 上同一个「台站状态」栏、后到者覆盖。补发那一帧原本是「发射即忘」，'
               'socket 抖动时可能静默写失败，于是 aprs.fi 停在 CONNECT 上、每轮保活又续一次。'
               '现在连接器**回传发送成败**，保活记住「上次自定义帧丢了」，**下一拍立刻补发自定义帧'
               '本身**（不再发 CONNECT）直到成功 —— 状态不会再被内置文本顶掉。',
               '**自訂狀態「有時還顯示 CONNECT」**：狀態報文是「內建身份幀 + 自訂狀態」一對，'
               '寫的是 aprs.fi 上同一個「台站狀態」欄、後到者覆蓋。補發那一幀原本是「發射即忘」，'
               'socket 抖動時可能靜默寫入失敗，於是 aprs.fi 停在 CONNECT 上、每輪保活又續一次。'
               '現在連接器**回傳發送成敗**，保活記住「上次自訂幀丟了」，**下一拍立刻補發自訂幀'
               '本身**（不再發 CONNECT）直到成功 —— 狀態不會再被內建文字頂掉。',
               '**Custom status "sometimes still shows CONNECT"**: a status report is a pair — the '
               'built-in identity frame plus your custom status — and both write the **same "station '
               'status" field** on aprs.fi, last one wins. The compensating frame was fire-and-forget, '
               'so a socket hiccup could drop it silently and leave aprs.fi stuck on CONNECT while each '
               'keep-alive renewed it. The connector now **reports send success**, and keep-alive '
               'remembers a lost custom frame and **re-sends the custom frame itself on the next tick** '
               '(no extra CONNECT) until it goes through — your status can no longer be overwritten by '
               'the built-in text.')),
        ],
    },
    {
        'ver': 'v2.0.30', 'date': '2026-10-03',
        'items': [
            ('new',
             T('**数据维护：按天数清理过时台站**（issue #33）：设置里可设「台站保留天数」，'
               '超过该天数**没再听到**的台站会在启动时自动清理；「数据维护」页还提供**立即清理**'
               '入口，并先显示会清掉多少个。**只清普通台站** —— 收藏 / 手动添加 / 你自己的台站'
               '永不被清理，恰好卡在阈值上的也保留；保留天数 0 = 关闭自动清理。清理不可恢复，'
               '所以绝不静默全清。',
               '**資料維護：依天數清理過時台站**（issue #33）：設定裡可設「台站保留天數」，'
               '超過該天數**沒再聽到**的台站會在啟動時自動清理；「資料維護」頁還提供**立即清理**'
               '入口，並先顯示會清掉多少個。**只清一般台站** —— 收藏 / 手動新增 / 你自己的台站'
               '永不被清理，恰好卡在閾值上的也保留；保留天數 0 = 關閉自動清理。清理不可恢復，'
               '所以絕不靜默全清。',
               '**Data maintenance: prune stale stations by age** (issue #33): a **station retention '
               '(days)** setting prunes stations **not heard from** for longer than that at startup, '
               'and the Data maintenance page adds a **prune now** action that first shows how many '
               'will be removed. **Only ordinary stations are pruned** — favorites, manual contacts '
               'and your own station are never pruned, and stations exactly at the threshold are '
               'kept; retention 0 = auto-prune off. Pruning is irreversible, so there is never a '
               'silent full wipe.')),
        ],
    },
    {
        'ver': 'v2.0.29', 'date': '2026-10-03',
        'items': [
            ('fix',
             T('**稍微使劲放手机就触发碰撞提醒**（issue #32 后续）：旧判据是「一个冲击尖峰 + 之后 '
               '12 秒不动」，而放手机恰好同时满足这两条。阈值调高也救不了 —— 这是判据本身的问题。'
               '现在把两种事件的要求**分开**：**摔倒**要有自由落体（失重）再落地冲击；**碰撞**没有'
               '失重可依据，就要求冲击**明显更狠**（约两倍阈值）。真实车祸峰值动辄 20g 以上，照样抓得到，'
               '轻放手机的 3~8g 被挡掉。',
               '**稍微使勁放手機就觸發碰撞提醒**（issue #32 後續）：舊判據是「一個衝擊尖峰 + 之後 '
               '12 秒不動」，而放手機恰好同時滿足這兩條。閾值調高也救不了 —— 這是判據本身的問題。'
               '現在把兩種事件的要求**分開**：**摔倒**要有自由落體（失重）再落地衝擊；**碰撞**沒有'
               '失重可依據，就要求衝擊**明顯更狠**（約兩倍閾值）。真實車禍峰值動輒 20g 以上，照樣抓得到，'
               '輕放手機的 3~8g 被擋掉。',
               '**Setting the phone down a bit firmly triggered a crash alert** (issue #32 follow-up): '
               'the old rule was "an impact spike + then 12 s of stillness", and setting the phone down '
               'satisfies both at once. Raising the threshold cannot help — it is a flaw in the rule '
               'itself. The two events now have **separate** requirements: a **fall** needs a free fall '
               '(weightlessness) before the landing impact; a **crash**, with no weightlessness to rely '
               'on, must be **much harder** (about twice the threshold). A real vehicle crash peaks at '
               '20 g or more and still triggers, while a 3–8 g set-down is rejected.')),
            ('fix',
             T('**修一个自由落体判据的 bug**：此前判「失重」用的是**去掉重力**的线性加速度，而它在'
               '静止时恒为 0 —— 于是「放着不动」被当成了「一直在自由落体」，每次冲击都被判成摔倒。'
               '现在改用**含重力的总加速度**（静止≈1g，只有真失重才趋近 0）。说明卡也据实更新了。',
               '**修一個自由落體判據的 bug**：此前判「失重」用的是**去掉重力**的線性加速度，而它在'
               '靜止時恆為 0 —— 於是「放著不動」被當成了「一直在自由落體」，每次衝擊都被判成摔倒。'
               '現在改用**含重力的總加速度**（靜止≈1g，只有真失重才趨近 0）。說明卡也據實更新了。',
               '**Fixed a free-fall detection bug**: weightlessness used to be judged from the '
               '**gravity-removed** linear acceleration, which is always 0 at rest — so "sitting still" '
               'was mistaken for "in free fall" and every impact was labelled a fall. It now uses the '
               '**gravity-included total acceleration** (~1 g at rest; only true weightlessness tends '
               'to 0). The explainer card was updated to match.')),
        ],
    },
    {
        'ver': 'v2.0.28', 'date': '2026-10-03',
        'items': [
            ('new',
             T('**生命守护「强提醒」**：碰撞 / 摔倒、心率异常触发时，除了应用内弹窗，'
               '还会发一条**高优先级系统通知**（响铃 + 震动 + 锁屏/抬头横幅）。此前告警只挂在'
               '那条安静（`IMPORTANCE_LOW`）的常驻通知上，系统不为它震动也不弹横幅 —— '
               '手机放兜里（摔倒或开车时最常见的状态）根本察觉不到。强提醒走**单独**的高优先级'
               '通道；Android 需要 `VIBRATE` 权限（已加）。',
               '**生命守護「強提醒」**：碰撞 / 摔倒、心率異常觸發時，除了應用程式內彈窗，'
               '還會發一條**高優先級系統通知**（響鈴 + 震動 + 鎖屏/抬頭橫幅）。此前告警只掛在'
               '那條安靜（`IMPORTANCE_LOW`）的常駐通知上，系統不為它震動也不彈橫幅 —— '
               '手機放口袋（摔倒或開車時最常見的狀態）根本察覺不到。強提醒走**單獨**的高優先級'
               '通道；Android 需要 `VIBRATE` 權限（已加）。',
               '**Life-guard "strong reminder"**: when a crash/fall or an abnormal heart rate '
               'fires, besides the in-app dialog the app now posts a **high-priority system '
               'notification** (sound + vibration + lock-screen/heads-up banner). Previously '
               'alarms only went to the quiet (`IMPORTANCE_LOW`) persistent notification, which '
               'the system neither vibrates nor banners for — so with the phone in a pocket (the '
               'usual state during a fall or while driving) it was not noticed at all. The strong '
               'reminder uses its **own** high-priority channel; Android needs the `VIBRATE` '
               'permission (added).')),
            ('up',
             T('**碰撞 / 摔倒检测算法优化**：在原有「冲击 + 随后约 12 秒静止」之外，再看冲击前'
               '有没有**自由落体**（加速度模 ≤ 0.35 g 持续 ≥ 80 毫秒）—— 摔倒几乎总是先自由'
               '落体再落地冲击，车祸撞击则没有那一段。据此把告警区分为**摔倒**与**碰撞**，'
               '标题、图标与说明文字随之变化。两类告警的**处理方式完全一样**，这只是把判断'
               '说得更准；仍然是启发式，弹窗里照旧写明「不是工程级检测」。',
               '**碰撞 / 摔倒偵測演算法優化**：在原有「衝擊 + 隨後約 12 秒靜止」之外，再看衝擊前'
               '有沒有**自由落體**（加速度模 ≤ 0.35 g 持續 ≥ 80 毫秒）—— 摔倒幾乎總是先自由'
               '落體再落地衝擊，車禍撞擊則沒有那一段。據此把告警區分為**摔倒**與**碰撞**，'
               '標題、圖示與說明文字隨之變化。兩類告警的**處理方式完全一樣**，這只是把判斷'
               '說得更準；仍然是啟發式，彈窗裡照舊寫明「不是工程級偵測」。',
               '**Better crash/fall detection algorithm**: on top of the existing "impact + then '
               '~12 s of stillness", it now also looks for a **free fall** just before the impact '
               '(acceleration magnitude ≤ 0.35 g for ≥ 80 ms) — a fall almost always starts with a '
               'free fall before the landing impact, whereas a vehicle crash does not. Alarms are '
               'therefore split into **fall** and **crash**, changing the title, icon and '
               'explanatory text. Both kinds are **handled exactly the same**; this only makes the '
               'wording more accurate. It is still a heuristic, and the dialog still says so '
               '("not engineering-grade detection").')),
            ('new',
             T('**检测灵敏度三档**：设置 → 生命守护新增「灵敏 / 标准 / 抗颠簸」。原来阈值写死，'
               '适配不了不同携带方式 —— 手机放裤兜里骑车，正常颠簸就能越过阈值；固定在车把上'
               '又一路误报。灵敏度只影响**检测**（哪个撞击算数），不影响告警动作；随备份一起走。'
               '同时 **iOS 补齐**了本地通知与同款碰撞/摔倒检测。',
               '**偵測靈敏度三檔**：設定 → 生命守護新增「靈敏 / 標準 / 抗顛簸」。原來閾值寫死，'
               '適配不了不同攜帶方式 —— 手機放褲袋騎車，正常顛簸就能越過閾值；固定在車把上'
               '又一路誤報。靈敏度只影響**偵測**（哪個撞擊算數），不影響告警動作；隨備份一起走。'
               '同時 **iOS 補齊**了本機通知與同款碰撞/摔倒偵測。',
               '**Three detection-sensitivity levels**: Settings → Life Guard now offers Sensitive '
               '/ Standard / Firm. The threshold used to be hard-coded, which cannot fit every way '
               'of carrying the phone — in a cycling pocket an ordinary bump crosses it, while a '
               'bar-mounted phone then false-alarms the whole ride. Sensitivity only affects '
               '**detection** (which impact counts), not what the alarm does; it travels with '
               'backups. **iOS parity** was added too: local notifications and the same '
               'crash/fall detection.')),
        ],
    },
    {
        'ver': 'v2.0.27', 'date': '2026-10-05',
        'items': [
            ('fix',
             T('**连接成功时用户自定义状态包被内置身份帧顶掉**（issue #31）：连上 '
               'APRS-IS 会先发一帧身份状态帧宣告在线，它会把 aprs.fi 上「台站状态」那一栏'
               '改成内置文本。此前只有 15 秒保活帧会补一帧自定义状态，连接成功这条路径'
               '**漏了** —— 于是每次重连都把用户设的状态顶掉一次。现在两处都补发。',
               '**連線成功時使用者自訂狀態包被內建身分幀頂掉**（issue #31）：連上 '
               'APRS-IS 會先發一幀身分狀態幀宣告在線，它會把 aprs.fi 上「臺站狀態」那一欄'
               '改成內建文字。此前只有 15 秒保活幀會補一幀自訂狀態，連線成功這條路徑'
               '**漏了** —— 於是每次重連都把使用者設的狀態頂掉一次。現在兩處都補發。',
               '**The custom status packet was overwritten by the built-in identity frame on '
               'connect** (issue #31): connecting to APRS-IS first sends an identity status '
               'frame to announce presence, which rewrites the "station status" field on '
               'aprs.fi with the built-in text. Only the 15-second keep-alive frame used to '
               're-send the custom status, and the connect-success path **missed it** — so '
               'every reconnect wiped the user\'s status once. Both paths now re-send it.')),
        ],
    },
    {
        'ver': 'v2.0.26', 'date': '2026-10-04',
        'items': [
            ('new',
             T('**地图「我的位置」标记显示方位角**：圆环上多出一个朝航向的三角箭头'
               '（蓝底白边，与圆点同一套视觉语言），一眼就能看出自己朝哪边走。'
               '纯网络定位 / 静止未取得航向时不画，不拿猜的方向误导。',
               '**地圖「我的位置」標記顯示方位角**：圓環上多出一個朝航向的三角箭頭'
               '（藍底白邊，與圓點同一套視覺語言），一眼就能看出自己朝哪邊走。'
               '純網路定位 / 靜止未取得航向時不畫，不拿猜的方向誤導。',
               '**The map\'s my-location marker now shows heading**: a triangular arrow '
               '(blue fill, white outline, matching the dot\'s visual language) points along '
               'your course so you can tell at a glance which way you are facing. It is not '
               'drawn for network-only fixes or when no course is known, rather than guessing '
               'a direction.')),
            ('fix',
             T('**左下角「我的位置」面板显示的上报间隔与倒计时不一致**：面板那行'
               '「自动上报中 · 每 Ns」读的是**固定间隔**字段，而右边的倒计时读的是'
               '**当前生效间隔**。纯网络模式下两者不同（生效值 = 网络间隔，默认 300 秒），'
               '于是间隔卡在 GPS 模式留下的旧值不动。现在两处都改用生效间隔。',
               '**左下角「我的位置」面板顯示的上報間隔與倒數不一致**：面板那行'
               '「自動上報中 · 每 Ns」讀的是**固定間隔**欄位，而右邊的倒數讀的是'
               '**目前生效間隔**。純網路模式下兩者不同（生效值 = 網路間隔，預設 300 秒），'
               '於是間隔卡在 GPS 模式留下的舊值不動。現在兩處都改用生效間隔。',
               '**The interval shown in the bottom-left my-location panel disagreed with the '
               'countdown next to it**: the panel\'s "auto-reporting · every Ns" line read the '
               '*fixed* interval field while the countdown read the *effective* one. In '
               'network-only mode the two differ (effective = the network interval, 300 s by '
               'default), so the label sat on a stale value left over from GPS mode. Both now '
               'use the effective interval.')),
        ],
    },
    {
        'ver': 'v2.0.25', 'date': '2026-10-04',
        'items': [
            ('new',
             T('**群发前提示一次确认**：无论从消息页选中群聊发送，还是从群跟踪页的'
               '快捷聊天面板发给整个群，发送前都会弹一次「确认发送到 &lt;群呼号&gt;？」。'
               '群发是一键发给全体成员，发出去收不回来，值得先问一句。',
               '**群發前提示一次確認**：無論從訊息頁選中群聊發送，還是從群追蹤頁的'
               '快捷聊天面板發給整個群，發送前都會彈一次「確認發送到 &lt;群呼號&gt;？」。'
               '群發是一鍵發給全體成員，發出去收不回來，值得先問一句。',
               '**Confirm once before a group mass-send**: whether you send from the messages '
               'page with a group selected or from the tracker\'s quick-chat panel to the whole '
               'group, a single "Send to &lt;group call&gt;?" prompt appears first. A mass-send goes '
               'to every member at once and cannot be recalled.')),
            ('new',
             T('**邀请前提示一次确认**：单成员邀请（手动输入呼号或点成员旁的对勾）与'
               '建群时的批量邀请，都会先弹一次确认（建群那句会写明「将邀请 N 位成员」）。',
               '**邀請前提示一次確認**：單成員邀請（手動輸入呼號或點成員旁的對勾）與'
               '建群時的批次邀請，都會先彈一次確認（建群那句會寫明「將邀請 N 位成員」）。',
               '**Confirm once before inviting**: single-member invites (typing a call or '
               'tapping the check beside a member) and the batch invites fired when creating a '
               'group both ask once first (the create-group prompt states how many members will '
               'be invited).')),
            ('fix',
             T('**升级 / 更改文件重装后「今日步数」归零**（issue #22-2）：今日步数此前只'
               '存在内存里、从不落盘，任何一次冷启动、覆盖安装或改文件重编译都会先回到 0，'
               '若一直没等到传感器读数就永远停在 0。现在**每次步数变化即落盘**，启动时把'
               '今日步数接回来；跨天照常按日期归零，同一天内设备重启则把重启前已累计的'
               '部分接续上，不再凭空少一截。',
               '**升級 / 更改檔案重裝後「今日步數」歸零**（issue #22-2）：今日步數此前只'
               '存在記憶體裡、從不落盤，任何一次冷啟動、覆蓋安裝或改檔重編譯都會先回到 0，'
               '若一直沒等到感測器讀數就永遠停在 0。現在**每次步數變化即落盤**，啟動時把'
               '今日步數接回來；跨天照常按日期歸零，同一天內裝置重啟則把重啟前已累計的'
               '部分接續上，不再憑空少一截。',
               '**"Steps today" resetting to zero after an upgrade / reinstall** (issue #22-2): '
               'the count only ever lived in memory and was never written to disk, so any cold '
               'start, in-place upgrade or rebuild began at 0 and stayed there until a sensor '
               'reading arrived. The count is now **written on every change** and restored on '
               'launch; it still resets across a date change, and a same-day device reboot '
               'resumes the pre-reboot accumulation instead of losing it.')),
        ],
    },
    {
        'ver': 'v2.0.24', 'date': '2026-10-04',
        'items': [
            ('fix',
             T('**荣誉庆祝不再区分新老用户**：此前「只有被新授予的称号才弹」，自己'
               '本来已有的荣誉从不展示。现在改为：**本地没有「已阅读」记录，就把当前'
               '已拥有的全部荣誉依次弹一遍**（全新安装、旧版本升级、记录被清除都算'
               '无记录）；看过一次即落盘，之后不再重复（除非该账号新获荣誉）。',
               '**榮譽慶祝不再區分新舊使用者**：此前「只有被新授予的稱號才彈」，自己'
               '本來已有的榮譽從不顯示。現在改為：**本機沒有「已閱讀」記錄，就把目前'
               '已擁有的全部榮譽依序彈一遍**（全新安裝、舊版升級、記錄被清除都算'
               '無記錄）；看過一次即落盤，之後不再重複（除非該帳號新獲榮譽）。',
               '**Honor celebration no longer distinguishes new and existing users**: '
               'previously only a freshly granted title would show, and honors you already '
               'had were never shown. Now: **with no local "read" record, every honor you '
               'currently own is shown in turn** (a fresh install, an upgrade from an older '
               'version, or a cleared record all count as no record); once seen, the record '
               'is written and it will not repeat - unless the account is granted a new honor.')),
            ('fix',
             T('**步数排行榜点「我」那一行，弹出的提示条黑乎乎一片**：提示文字用了 '
               '`ts(12)`，其默认取色是深色，压在同样是深色的提示条底上 —— 深字叠深底，'
               '一个字都看不清。改为显式白字（设置页里同类的一处一并修）。',
               '**步數排行榜點「我」那一列，彈出的提示條黑壓壓一片**：提示文字用了 '
               '`ts(12)`，其預設取色是深色，壓在同樣是深色的提示條底上 —— 深字疊深底，'
               '一個字都看不清楚。改為明確白字（設定頁裡同類的一處一併修）。',
               '**Tapping your own row in the steps leaderboard showed a black-on-black '
               'toast**: the text used `ts(12)`, whose default color is dark, on an equally '
               'dark background - dark on dark and unreadable. It is now explicit white text '
               '(one more instance of the same bug in the settings pages is fixed too).')),
            ('new',
             T('**开发者选项新增「清除已阅读荣誉」**（设置 → 实验室与开发者工具）：'
               '清掉本机「已阅读」记录，下次判定会把当前已拥有的荣誉重新展示一遍，'
               '方便预览与自测。',
               '**開發者選項新增「清除已閱讀榮譽」**（設定 → 實驗室與開發者工具）：'
               '清掉本機「已閱讀」記錄，下次判定會把目前已擁有的榮譽重新顯示一遍，'
               '方便預覽與自測。',
               '**New developer option "Clear read honors"** (Settings → Lab & developer '
               'tools): wipes the local "read" record so the next check replays every honor '
               'you currently own - handy for previewing and for self-testing.')),
        ],
    },
    {
        'ver': 'v2.0.23', 'date': '2026-10-04',
        'items': [
            ('new',
             T('**显示设置新增「始终显示地图标签」**：打开后，无论台站多密、缩得多小，'
               '地图上都会显示每个台站的呼号标签（栅格与矢量两套地图都生效）。默认关，'
               '沿用原取舍（台站 ≤ 60 个或放大到 13 级以上才显示）—— 打开会明显变密、'
               '标签也可能互相重叠，渲染也更费；该偏好随备份一起走。',
               '**顯示設定新增「永遠顯示地圖標籤」**：開啟後，無論台站多密、縮得多小，'
               '地圖上都會顯示每個台站的呼號標籤（格狀與向量兩套地圖都生效）。預設關，'
               '沿用原取捨（台站 ≤ 60 個或放大到 13 級以上才顯示）—— 開啟會明顯變密、'
               '標籤也可能互相重疊，渲染也更費；該偏好隨備份一起走。',
               '**New display setting: "Always show map labels"**: when on, every station\'s '
               'callsign label is drawn on the map regardless of station count or zoom (both the '
               'raster and vector maps). Off by default, keeping the original trade-off (labels '
               'only when there are 60 or fewer stations or zoom is 13+) - turning it on gets '
               'crowded, labels may overlap, and it costs more to render. The preference travels '
               'with backups.')),
            ('fix',
             T('**拦截页「长按解封」按不出来**：远程限制名单里**软封**的隐藏解封入口'
               '（长按本机安装标识）此前被两处手势抢走 —— 标识用的是可选中文本，长按会弹出'
               '系统选区工具栏；旁边的复制图标又因长按提示抢走同一手势。于是长按永远不是'
               '「解封」，用户看到的就是「变成复制/选择工具栏」。现在标识行是**单一手势区**：'
               '点一下 = 复制、长按 = 解封（软封有效；硬封仍按设计静默无反应）。',
               '**攔截頁「長按解封」按不出來**：遠端限制名單裡**軟封**的隱藏解封入口'
               '（長按本機安裝識別）此前被兩處手勢搶走 —— 識別用的是可選取文字，長按會彈出'
               '系統選區工具列；旁邊的複製圖示又因長按提示搶走同一手勢。於是長按永遠不是'
               '「解封」，使用者看到的就是「變成複製/選取工具列」。現在識別列是**單一手勢區**：'
               '點一下 = 複製、長按 = 解封（軟封有效；硬封仍按設計靜默無反應）。',
               '**The intercept page\'s "unblock on long-press" never fired**: the soft-ban hidden '
               'unblock (long-press the install ID) was swallowed by two other gestures on the same '
               'row - the ID used selectable text, so a long-press raised the system selection '
               'toolbar, and the copy icon\'s long-press tooltip claimed the same gesture. The '
               'long-press was therefore never the unblock. The ID row is now a **single gesture '
               'area**: tap = copy, long-press = unblock (works for soft bans; hard bans stay '
               'silent by design).')),
        ],
    },
    {
        'ver': 'v2.0.22', 'date': '2026-10-04',
        'items': [
            ('fix',
             T('**修好「老用户看不到新荣誉庆祝」**：上一版的新荣誉庆祝只在你关闭过动画后'
               '才记录「已见」，而旧版本没有这个功能 —— 升级后设备上只有荣誉表、没有已见记录，'
               '旧逻辑把这种情况当成全新安装、「等第一份在线名单再建基线」，而那份名单'
               '**已经含刚授予的称号**，于是新荣誉被算进基线、**永远不弹**。现在按「本地是否已有'
               '荣誉表」区分：老用户升级时立刻用本地缓存建基线，同一会话内到达的在线新授予即可正常弹出；'
               '全新安装仍等在线名单，不会把已有荣誉狂弹一遍。'
               '**一次授予多枚只弹一枚**也修了：现在按顺序逐枚弹，关闭一枚自动补下一枚。',
               '**修好「老用戶看不到新榮譽慶祝」**：上一版的新榮譽慶祝只在你關閉過動畫後'
               '才記錄「已見」，而舊版本沒有這個功能 —— 升級後裝置上只有榮譽表、沒有已見記錄，'
               '舊邏輯把這種情況當成全新安裝、「等第一份線上名單再建基線」，而那份名單'
               '**已經含剛授予的稱號**，於是新榮譽被算進基線、**永遠不彈**。現在按「本機是否已有'
               '榮譽表」區分：老用戶升級時立刻用本機快取建基線，同一工作階段內到達的線上新增即可正常彈出；'
               '全新安裝仍等線上名單，不會把已有榮譽狂彈一遍。'
               '**一次授予多枚只彈一枚**也修了：現在依序逐枚彈，關閉一枚自動補下一枚。',
               '**Fixed: existing users never saw the new-honor celebration**: the previous '
               'release only recorded a "seen" snapshot after you dismissed the animation - and '
               'older versions had no such feature, so after upgrading the device held a roster but '
               'no seen-record. The old logic treated that as a fresh install and waited for the '
               'first online roster to build the baseline - but that roster **already contained the '
               'newly granted honor**, so it was folded into the baseline and **never celebrated**. '
               'It now tells existing users from fresh installs by whether a local roster is '
               'stored: on upgrade the baseline is built immediately, so a genuinely new online '
               'grant in the same session still pops, while a fresh install still waits for the '
               'online roster and never replays honors you already had. '
               '**Several honors granted at once only celebrated one** is fixed too: they are now '
               'queued and shown one after another.')),
            ('up',
             T('**首次运行的向导不再预填连接参数**：服务器、端口与 Passcode 一律留空'
               '（仅以灰色提示常值），不再默认填好 `rotate.aprs2.net` / `14580` / `-1` —— '
               '软件不预置、也不推荐任何服务器地址；重新运行向导时仍会回填你保存过的值。',
               '**首次執行的嚮導不再預填連線參數**：伺服器、連接埠與 Passcode 一律留空'
               '（僅以灰色提示常值），不再預設填好 `rotate.aprs2.net` / `14580` / `-1` —— '
               '軟體不預置、也不推薦任何伺服器位址；重新執行嚮導時仍會回填你儲存過的值。',
               '**The first-run wizard no longer prefills connection fields**: server, port and '
               'Passcode are left empty (common values only show as grey hints) instead of '
               'defaulting to `rotate.aprs2.net` / `14580` / `-1` - the app presets and recommends '
               'no server; re-running the wizard still restores your saved values.')),
        ],
    },
    {
        'ver': 'v2.0.21', 'date': '2026-10-04',
        'items': [
            ('new',
             T('**新获荣誉时弹出「恭喜获得」庆祝动画**：打开软件后若检测到账号**被新授予**荣誉'
               '（成员称号或 FIRST FIX），会弹出一屏庆祝：半透明遮罩上金箔粒子四散，中央白底卡片里'
               '徽章带光环 / 射线浮现，随后荣誉名、描述与主按钮依次淡入。造型沿用全 App 的浅色卡片语言，'
               '徽章配色与荣誉墙一致；点按任意处或按钮关闭，**同一枚荣誉只弹一次**。'
               '判定只在**在线名单**到达后进行，全新安装不会把已有荣誉误当新授予弹一遍。',
               '**新獲榮譽時彈出「恭喜獲得」慶祝動畫**：開啟軟體後若偵測到帳號**被新授予**榮譽'
               '（成員稱號或 FIRST FIX），會彈出一幕慶祝：半透明遮罩上金箔粒子四散，中央白底卡片裡'
               '徽章帶著光環 / 射線浮現，隨後榮譽名、描述與主按鈕依序淡入。造型沿用全 App 的淺色卡片語言，'
               '徽章配色與榮譽牆一致；點按任意處或按鈕關閉，**同一枚榮譽只彈一次**。'
               '判定只在**線上名單**到達後進行，全新安裝不會把已有榮譽誤當新授予彈一遍。',
               '**A "Congratulations" celebration when you earn a new honor**: after the app starts, '
               'if your account has been **newly granted** an honor (a member title or FIRST FIX), a '
               'celebration pops up - gold-foil particles scatter over a dimmed backdrop while a badge '
               'emerges with rings and rays inside a white card, then the honor name, description and '
               'the primary button fade in. It follows the app light-card language and the badge color '
               'matches the honor wall; tap anywhere or the button to dismiss, **each honor is '
               'celebrated only once**. Detection waits for the **online roster**, so a fresh install '
               'never replays honors you already had as if they were new.')),
        ],
    },
    {
        'ver': 'v2.0.20', 'date': '2026-10-03',
        'items': [
            ('fix',
             T('**手指落在台站上时地图无法缩放/拖动**：台站标记的手势会把地图的手势挡掉'
               '（`HitTestBehavior.opaque`），改成 `translucent` 后标记与地图都收到指针 —— '
               '点 = 选中台站，拖动/捏合 = 地图；栅格与矢量两套地图都改了。'
               '**矢量地图的热力图失效**也修了：原来被 `!_usePluginMap` 整个排除，'
               '现在矢量地图也画热力（用 flutter_map 相机投影）。'
               '**「从收藏台站开始」新建会话黑屏**也修了：它会先把「新建会话」对话框关掉，'
               '选完人后又关了一次，把整个消息页弹掉 —— 现在只有对话框还开着时才关。'
               '**手动选点（模拟位置）没有系统通知**也修了：手动设坐标会停掉前台服务却没把保活起回来 —— 现在会起回来。',
               '**手指落在臺站上時地圖無法縮放/拖曳**：臺站標記的手勢會把地圖的手勢擋掉'
               '（`HitTestBehavior.opaque`），改成 `translucent` 後標記與地圖都收到指標 —— '
               '點 = 選中臺站，拖曳/捏合 = 地圖；點陣與向量兩套地圖都改了。'
               '**向量地圖的熱力圖失效**也修了：原本被 `!_usePluginMap` 整個排除，'
               '現在向量地圖也畫熱力（用 flutter_map 相機投影）。'
               '**「從收藏臺站開始」新建會話黑屏**也修了：它會先把「新建會話」對話框關掉，'
               '選完人後又關了一次，把整個訊息頁彈掉 —— 現在只有對話框還開著時才關。'
               '**手動選點（模擬位置）沒有系統通知**也修了：手動設座標會停掉前景服務卻沒把保活起回來 —— 現在會起回來。',
               '**Map cannot be zoomed/panned when a finger lands on a station**: the marker '
               'swallowed the map gestures (`HitTestBehavior.opaque`); with `translucent` both '
               'receive the pointer - tap selects the station, drag/pinch moves the map; applied '
               'to both the raster and vector map. **The vector-map heatmap never worked** '
               'either (it was excluded by `!_usePluginMap`); the vector map draws it now, '
               'projected with the flutter_map camera. '
               '**"Start from a favourite station" opening a black screen** was fixed too: '
               'it closes the New conversation dialog first and then closed one again after '
               'picking, popping the whole messages page - now the dialog is only closed when '
               'one is open. '
               '**No system notification when picking a simulated point** was fixed too: setting the '
               'position manually stopped the foreground service without restarting keep-alive - it is '
               'restarted now.')),
            ('new',
             T('**热力图档位**（设置 → 显示 → 地图）：弱 / 中 / 强，调整热力光斑的大小与浓度，'
               '两套地图共用同一个值。**台站详情重新显示 PHG**（功率 / 天线高度 / 增益 / 方向），'
               '这次是独立一行、不再挤进三列指标。',
               '**熱力圖檔位**（設定 → 顯示 → 地圖）：弱 / 中 / 強，調整熱力光斑的大小與濃度，'
               '兩套地圖共用同一個值。**臺站詳情重新顯示 PHG**（功率 / 天線高度 / 增益 / 方向），'
               '這次是獨立一行、不再擠進三欄指標。',
               '**Heatmap level** (Settings -> Display -> Map): Light / Medium / Strong, scaling '
               'the heat blobs size and density, shared by both maps. **PHG is back in the '
               'station detail** (power / antenna height / gain / direction), now on its own '
               'line instead of crammed into the three metrics.')),
        ],
    },
    {
        'ver': 'v2.0.19', 'date': '2026-10-03',
        'items': [
            ('fix',
             T('**地图不再卡**（三处根因）：矢量地图原来**完全没有视口裁剪**、还把全世界台站'
               '塞进 MarkerLayer，而台站版本号每个报文都 +1 —— 于是每个报文都重建几千个标记；'
               '现在只建视口内的 + 标记带 `key` 按身份复用 + 台站密时不画呼号标签。'
               '**瓦片拖动不丝滑**也修了：手势期间压住新瓦片的下载与解码，手停再补。'
               '**数据包页**每行重播淡入动画（时长还随行号无限增长）也改成只播一次。',
               '**地圖不再卡**（三處根因）：向量地圖原本**完全沒有視窗裁剪**、還把全世界臺站'
               '塞進 MarkerLayer，而臺站版本號每個封包都 +1 —— 於是每個封包都重建幾千個標記；'
               '現在只建視窗內的 + 標記帶 `key` 按身分重用 + 臺站密時不畫呼號標籤。'
               '**圖磚拖曳不順**也修了：手勢期間壓住新圖磚的下載與解碼，手停再補。'
               '**封包頁**每列重播淡入動畫（時長還隨列號無限增長）也改成只播一次。',
               '**The map no longer stutters** (three root causes): the vector map had no '
               'viewport culling and pushed every station in the world into a MarkerLayer, '
               'while the station version bumps on every packet - so every packet rebuilt '
               'thousands of markers. Only viewport stations are built now, markers carry a '
               '`key` for identity reuse, and callsign labels are skipped when dense. Tile '
               'dragging was fixed too (tile loads are deferred until the gesture ends), as '
               'was the packet page (each row restarted a fade-in whose duration grew with '
               'the row index).')),
            ('new',
             T('**新增**：设置主页的连接状态面板点一下 → 弹出「链路方式」浮动面板（数据来源'
               '快捷切换，与「连接 → 设备」页同一张卡片）；「新建会话」下面加「从收藏台站'
               '开始」；台站列表加「收藏」筛选，收藏视图下每行一颗星标点一下即取消收藏；'
               '**运动排行榜把自己排进列表**。另外修好：佳明链接断开时请求堆叠（可能卡顿/'
               '闪退）、盒子「连接 TNC」的错误文案、设置主页过时的「待开放」、地图图例已去掉。',
               '**新增**：設定主頁的連線狀態面板點一下 → 彈出「鏈路方式」浮動面板（資料來源'
               '快速切換，與「連線 → 裝置」頁同一張卡片）；「新建會話」下面加「從收藏臺站'
               '開始」；臺站列表加「收藏」篩選，收藏檢視下每列一顆星號點一下即取消收藏；'
               '**運動排行榜把自己排進列表**。另外修好：Garmin 連結中斷時請求堆疊（可能卡頓/'
               '閃退）、盒子「連接 TNC」的錯誤文案、設定主頁過時的「待開放」、地圖圖例已移除。',
               '**New**: tapping the connection banner on the settings home page opens a '
               'floating link-method panel (same card as the Connection -> Device page); '
               '"Start from a favourite station" under New session; a Favourites filter in the '
               'station list (tap a row star to un-favourite); and **you now appear in the activity '
               'leaderboard**. Also fixed: Garmin link-drop request pile-up (stutter/crash '
               'risk), the box calling itself a TNC, the stale "coming soon" on the settings '
               'home page, and the map legend was removed.')),
        ],
    },
    {
        'ver': 'v2.0.18', 'date': '2026-10-02',
        'items': [
            ('new',
             T('**新增：WLAN 电台直连**（支持 IC-705 / IC-9700 / IC-7610 / IC-905 等 Wi-Fi 与以太网型号）。'
               '手机与电台在同一局域网即可收发 APRS 音频，不用声卡或 TNC；PTT 与频率控制走 '
               'CI-V、音频走网络，不占用音频口；新增独立的电台设备页与并列的数据来源入口，'
               '并带 19 个新测试。由社区贡献者 nimenhagg 实现（PR #29）。',
               '**新增：WLAN 電台直連**（支援 IC-705 / IC-9700 / IC-7610 / IC-905 等 Wi-Fi 與乙太網路型號）。'
               '手機與電台在同一區域網路即可收發 APRS 音訊，不需音效卡或 TNC；PTT 與頻率控制走 '
               'CI-V、音訊走網路，不佔用音訊埠；新增獨立的電台裝置頁與並列的資料來源入口，'
               '並帶 19 個新測試。由社群貢獻者 nimenhagg 實作（PR #29）。',
               '**New: WLAN radio direct link over Wi-Fi / Ethernet** (supporting IC-705, IC-9700, IC-7610, '
               'IC-905). With the phone and radio on the same LAN you can send and receive APRS '
               'audio with no sound card or TNC; PTT and tuning go over CI-V while audio goes '
               'over the network, leaving the audio port free. Adds a dedicated radio page, a '
               'parallel data source entry, and 19 new test files. Contributed by nimenhagg '
               '(PR #29).')),
        ],
    },
    {
        'ver': 'v2.0.17', 'date': '2026-10-02',
        'items': [
            ('up',
             T('**用户协议更新到 V1.2**：明确"不预置、不推荐任何服务器地址，默认不连接任何 '
               'APRS-IS / iGate / 网络服务器"，并补齐自行配置的责任、合法使用与数据安全条款；'
               '首次引导里服务器留空即不联网（不再预填公共服务器、不再自动连接）。',
               '**使用者條款更新到 V1.2**：明確「不預置、不推薦任何伺服器位址，預設不連線任何 '
               'APRS-IS / iGate / 網路伺服器」，並補齊自行設定的責任、合法使用與資料安全條款；'
               '首次引導裡伺服器留空即不連網（不再預填公共伺服器、不再自動連線）。',
               '**Terms of Use updated to V1.2**: the app neither provides nor recommends any '
               'server address and connects to no APRS-IS / iGate / network server by default, '
               'with added clauses on configuring your own server, lawful use, and data safety. '
               'In the first-run guide an empty server means no connection at all (no pre-filled '
               'public server, no automatic connect).')),
        ],
    },
    {
        'ver': 'v2.0.16', 'date': '2026-10-02',
        'items': [
            ('fix',
             T('**启动时的远程检查更及时**：现在每次启动都会检查一次（原来要等最长 6 小时）。',
               '**啟動時的遠端檢查更及時**：現在每次啟動都會檢查一次（原本要等最長 6 小時）。',
               '**Remote checks are timely at launch**: the app now checks on every launch '
               '(it used to take up to 6 hours).')),
        ],
    },
    {
        'ver': 'v2.0.15', 'date': '2026-10-01',
        'items': [
            ('up',
             T('**用户协议更新到 V1.1（含赞赏声明）**。三语同步、34 → 41 条，把'
               '「软件实际会做的事」补齐了：网关转发等于**代表他人在业余频段上发射**'
               '（3.5）；未成年人需监护人同意、无资格不得发射（3.6）；发出内容要真实、'
               '准确、合法并尊重各国法律与文化习俗（3.7）；与哪些第三方通信（天气发送'
               '位置、翻译发送文本、更新向 GitHub 请求…，不使用即不发生，5.3）；'
               '「生命守护」等不是医疗设备、不是紧急救援（7.6）；数据可能传入第三方软件'
               '服务的免责（7.7）；**关于赞赏**（自愿、不换取功能、不予退还、未成年人需'
               '监护人同意，9.4）。应用内公告与赞赏页都有同一口径的说明。'
               '同版还修了三处：**蓝牙连不上就闪退**（阻塞的连接跑在主线程 → 系统判定'
               '无响应）、**电量半天不动**（只在有定位时才读）、**运动排行榜**的占位'
               '文字与排序口径（只统计今天，且自己也在榜上并标出）。',
               '**使用者條款更新到 V1.1（含贊賞聲明）**。三語同步、34 → 41 條，把'
               '「軟體實際會做的事」補齊了：閘道轉發等於**代表他人在業餘頻段上發射**'
               '（3.5）；未成年人需監護人同意、無資格不得發射（3.6）；送出的內容要真實、'
               '準確、合法並尊重各國法律與文化習俗（3.7）；與哪些第三方通訊（天氣傳送'
               '位置、翻譯傳送文字、更新向 GitHub 請求…，不使用即不發生，5.3）；'
               '「生命守護」等不是醫療設備、不是緊急救援（7.6）；資料可能傳入第三方軟體'
               '服務的免責（7.7）；**關於贊賞**（自願、不換取功能、不予退還、未成年人需'
               '監護人同意，9.4）。應用程式內公告與贊賞頁都有同一口徑的說明。'
               '同版還修了三處：**藍牙連不上就閃退**（阻塞的連線跑在主執行緒 → 系統判定'
               '無回應）、**電量半天不動**（只在有定位時才讀）、**運動排行榜**的佔位'
               '文字與排序口徑（只統計今天，且自己也在榜上並標出）。',
               '**Terms of Use updated to V1.1 (with a donation clause).** All three '
               'languages, 34 -> 41 clauses, documenting what the software actually does: '
               'gateway forwarding means transmitting on amateur bands on behalf of others '
               '(3.5); minors need a guardian consent and must not transmit unqualified '
               '(3.6); what you send must be truthful, accurate, lawful and respectful of '
               'local laws and customs (3.7); which third parties see what (weather sends a '
               'location, translation sends text, update checks query GitHub - none of it '
               'happens unless you use the feature, 5.3); Life Guard etc. are not medical '
               'devices and not an emergency service (7.6); a disclaimer that data may be '
               'passed to third-party software services (7.7); and about tips and donations '
               '(voluntary, no feature in return, non-refundable, minors need a guardian, '
               '9.4). The in-app notice and the sponsor page state the same. '
               'The same release fixes three things: the **crash when Bluetooth fails to '
               'connect** (the blocking connect ran on the main thread, so the system killed '
               'the app), a **phone battery that never updated** (it was only read when a '
               'location fix arrived), and the **sport ranking** placeholder text and '
               'counting rule (today only, and you now appear on the board, marked). ')),
        ],
    },
    {
        'ver': 'v2.0.14', 'date': '2026-10-01',
        'items': [
            ('new',
             T('**新：盒子上的「APRSLOCUS」实时仪表盘**。接着上一版的盒子支持，'
               '这一版把**手机那侧的实时状态**也推给盒子：心率、速度、方位、'
               '**自动上报倒计时**（带进度条）、里程（本次/累计）、电量、步数、定位精度、'
               'APRS-IS 与未读 —— 跑步骑车时手机在包里，挂在车把上的盒子一眼就能看到。'
               '心率测到就放大当主角，没测到自动换成速度；附近台站另拆一页 **NEARBY**'
               '（整屏 8 行）。协议改用 `TEL k=v …`：应用以后加字段**不用动固件**'
               '（不认识的键静默跳过；空值不发，盒子写 `--`，绝不显示假的 0）。'
               '另：`IS rx-only` 现在三处写清原因（首页 `set pass`、SYS 页的服务器原话、'
               '应用事件日志）并给出修法（`pass` 填**基础呼号**的 passcode）；'
               '倒计时改为**盒子本地每秒递减**，状态推送收紧到 5 秒。',
               '**新：盒子上的「APRSLOCUS」即時儀表板**。接著上一版的盒子支援，'
               '這一版把**手機那側的即時狀態**也推給盒子：心率、速度、方位、'
               '**自動上報倒數**（帶進度條）、里程（本次/累計）、電量、步數、定位精度、'
               'APRS-IS 與未讀 —— 跑步騎車時手機在包包裡，掛在車把上的盒子一眼就能看到。'
               '心率測到就放大當主角，沒測到自動換成速度；附近台站另拆一頁 **NEARBY**'
               '（整屏 8 行）。協定改用 `TEL k=v …`：應用程式以後加欄位**不用動韌體**'
               '（不認識的鍵靜默跳過；空值不送，盒子寫 `--`，絕不顯示假的 0）。',
               '**New: an "APRSLOCUS" live dashboard on the box.** Building on the box '
               'support from the previous release, the phone live status is now pushed to '
               'the box too: heart rate, speed, course, the **auto-report countdown** with '
               'a progress bar, mileage (trip / total), battery, steps, GPS accuracy, '
               'APRS-IS state and unread messages - visible at a glance on the bar-mounted '
               'box while the phone stays in the bag. Heart rate takes the lead when '
               'available, otherwise speed does; nearby stations moved to their own '
               '**NEARBY** page (8 rows). The protocol now uses `TEL k=v ...`, so the app '
               'can add fields without touching the firmware (unknown keys are skipped, '
               'empty values are not sent, and the box shows `--`, never a fake 0). '
               'Also: `IS rx-only` now explains itself in three places (home `set pass`, '
               'the server own words on the SYS page, and the app event log) with the fix '
               '(use the passcode of the base callsign), and countdowns now tick locally '
               'on the box with status pushed every 5 s.')),
        ],
    },
    {
        'ver': 'v2.0.13', 'date': '2026-10-01',
        'items': [
            ('new',
             T('**新：APRSlocusBOX（APRS 小盒子）—— 用手机管你那台小盒子**。'
               '「设备」页多了一条 **APRSlocusBOX**：连上盒子之后，手机上就能读它的配置、'
               '改它的配置、把手机的位置喂给它、催它发一帧信标、看它到底在干什么。'
               '连接走**蓝牙 SPP 或 USB 串口**（独立通道，管盒子不会打断正在收发的 TNC）；'
               '配置是全部 23 个键（键名与盒子文档逐字一致），改完还会自动回读 —— '
               '显示的是**盒子里的真值**；盒子推回来的 `EVT …` 事件与命令回执一并显示，'
               '可一键复制。'
               '这一版还把**手机这侧看到的东西**推给盒子：自己的速度/方位/海拔/有没有定位/'
               'APRS-IS 通不通/未读消息，以及**附近台站列表**（按距离，最多 8 条）—— '
               '盒子新增的 **PHONE 页**显示这些。盒子只跑蓝牙（自己不上 APRS-IS）时，'
               '「旁边有谁」在它上面本来是空的，现在这份数据能顶上去。'
               '两条刻意的规矩：盒子**不是**「数据来源」（它自己就上 APRS-IS，本应用再收一遍'
               '只会重复），且**绝不自动发射** —— 信标与状态报文必须人点，自动的只有本地的'
               '位置喂养与状态推送（都不上射频）。',
               '**新：APRSlocusBOX（APRS 小盒子）—— 用手機管你那台小盒子**。'
               '「裝置」頁多了一條 **APRSlocusBOX**：連上盒子之後，手機上就能讀它的設定、'
               '改它的設定、把手機的位置餵給它、催它發一幀信標、看它到底在幹什麼。'
               '連線走**藍牙 SPP 或 USB 串列埠**（獨立通道，管盒子不會打斷正在收發的 TNC）；'
               '設定是全部 23 個鍵（鍵名與盒子文件逐字一致），改完還會自動回讀 —— '
               '顯示的是**盒子裡的真值**；盒子推回來的 `EVT …` 事件與指令回執一併顯示，'
               '可一鍵複製。'
               '這一版還把**手機這側看到的東西**推給盒子：自己的速度/方位/海拔/有沒有定位/'
               'APRS-IS 通不通/未讀訊息，以及**附近台站列表**（按距離，最多 8 條）—— '
               '盒子新增的 **PHONE 頁**顯示這些。盒子只跑藍牙（自己不上 APRS-IS）時，'
               '「旁邊有誰」在它上面本來是空的，現在這份資料能頂上去。'
               '兩條刻意的規矩：盒子**不是**「資料來源」（它自己就上 APRS-IS，本應用再收一遍'
               '只會重複），且**絕不自動發射** —— 信標與狀態報文必須人點，自動的只有本地的'
               '位置餵養與狀態推送（都不上射頻）。',
               '**New: APRSlocusBOX - manage your little APRS box from the phone.** '
               'The Device page has a new entry, **APRSlocusBOX**: once connected you can read '
               'the box config, change it, feed it your position, trigger a beacon and see what '
               'it is actually doing. It connects over **Bluetooth SPP or USB serial** on its own '
               'channel, so managing the box never interrupts a TNC. Config covers all 23 keys '
               '(names match the box documentation) and the app re-reads after each change, so '
               'what you see is the real value in the box. This release also pushes what the '
               'phone sees - speed, course, altitude, fix, APRS-IS up/down, unread messages and '
               'the nearby station list (by distance, up to 8) - to the box PHONE page. In '
               'Bluetooth-only mode the box has no APRS-IS of its own, so that list is the only '
               'way it can show who is nearby. Two deliberate rules: the box is not a data '
               'source, and nothing is transmitted automatically - beacons and status packets '
               'must be tapped.')),
        ],
    },
    {
        'ver': 'v2.0.12', 'date': '2026-10-01',
        'items': [
            ('fix',
             T('**修：更新页不再让你自己选包，也不再跳浏览器**。上一版把三个包的名单摆出来、'
               '点一行去浏览器下载 —— 这是错的：绝大多数人只知道「我要更新」，让他去理解'
               '`armeabi-v7a` 是什么、该选哪一个，等于把应用该做的事推给用户。现在更新页'
               '**按本机 CPU 自动挑好对应的包**（`Abi.current()`，无需原生通道）并'
               '**直接在应用内下载**：32 位老机型自动拿到 32 位包、模拟器拿到 x86_64，'
               '不会再出现「下完提示与设备不兼容」；认不出架构时回退到分架构之前的行为，'
               '所以也不会变成「挑不到包」。',
               '**修：更新頁不再讓你自己選包，也不再跳瀏覽器**。上一版把三個包的名單擺出來、'
               '點一列去瀏覽器下載 —— 這是錯的：絕大多數人只知道「我要更新」，讓他去理解'
               '`armeabi-v7a` 是什麼、該選哪一個，等於把應用該做的事推給使用者。現在更新頁'
               '**按本機 CPU 自動挑好對應的包**（`Abi.current()`，無需原生通道）並'
               '**直接在應用程式內下載**：32 位元舊機型自動拿到 32 位元包、模擬器拿到 x86_64，'
               '不會再出現「下載完提示與裝置不相容」；認不出架構時回退到分架構之前的行為，'
               '所以也不會變成「挑不到包」。',
               '**Fix: the update page no longer asks you to pick a package and never opens a '
               'browser.** The previous build listed the three packages and sent a tap to the '
               'browser — that was wrong: almost everyone only knows "I want to update", and '
               'making them work out what `armeabi-v7a` means (or which row to choose) pushes the '
               'app\'s job onto the user. The page now **picks the package matching this device\'s '
               'CPU by itself** (`Abi.current()`, no platform channel needed) and **downloads it '
               'in-app**: a 32-bit device gets the 32-bit build, an emulator gets x86_64, and no '
               'one sees "incompatible with this device" after downloading. When the architecture '
               'cannot be determined it falls back to the pre-split behaviour, so an unknown '
               'device never ends up with no package at all.')),
        ],
    },
    {
        'ver': 'v2.0.11', 'date': '2026-10-01',
        'items': [
            ('up',
             T('**安卓安装包按 CPU 架构分包：81.6 MB → 约 30 MB**。实测上一版 81.6 MB 里'
               '**76.6 MB（94%）是三套原生库**（应用代码编译出的机器码 + Flutter 引擎，'
               '分别对应 arm64-v8a / armeabi-v7a / x86_64），而一台手机只用得上其中一套。'
               '现在 Release 里有**三个各约 30 MB** 的包：64 位沿用原来的文件名'
               '（**应用内更新默认下这个，逻辑一行没改**）、32 位、x86_64（模拟器 / Chromebook）。'
               '「64 位沿用原名」是刻意的：更新取资产列表里第一个 `.apk`，而资产按名字升序'
               '返回，`.` 比 `_` 小 —— 所以它永远排第一，这条不变量有专门的检查与自测盯着。',
               '**安卓安裝包按 CPU 架構分包：81.6 MB → 約 30 MB**。實測上一版 81.6 MB 裡'
               '**76.6 MB（94%）是三套原生函式庫**（應用程式碼編譯出的機器碼 + Flutter 引擎，'
               '分別對應 arm64-v8a / armeabi-v7a / x86_64），而一台手機只用得上其中一套。'
               '現在 Release 裡有**三個各約 30 MB** 的包：64 位元沿用原來的檔案名稱'
               '（**應用程式內更新預設下這個，邏輯一行沒改**）、32 位元、x86_64（模擬器 / Chromebook）。'
               '「64 位元沿用原名」是刻意的：更新取資產清單裡第一個 `.apk`，而資產按名稱升序'
               '回傳，`.` 比 `_` 小 —— 所以它永遠排第一，這條不變量有專門的檢查與自測盯著。',
               '**Android packages are now split per CPU architecture: 81.6 MB → about 30 MB.** '
               'In the previous build, **76.6 MB of the 81.6 MB — 94% — was three sets of native '
               'libraries** (the machine code compiled from the app plus the Flutter engine, for '
               'arm64-v8a / armeabi-v7a / x86_64), while a phone only ever uses one of them. A '
               'release now carries **three packages of about 30 MB each**: 64-bit keeps the '
               'original file name (**this is what the in-app update downloads; that logic is '
               'untouched**), plus 32-bit and x86_64 (emulators / Chromebooks). Keeping the plain '
               'name is deliberate: the updater takes the first `.apk` in the asset list and '
               'assets come back in ascending name order, where `.` sorts before `_` — so the '
               '64-bit build is always first, an invariant with a dedicated check and self-test.')),
            ('new',
             T('**更新页新增「选择安装包」**：该版本有多个包时，一行一个（**文件名 · 架构 · 大小**），'
               '第一个标「推荐」= 应用内更新会挑的那个；**点一行在浏览器打开该包的下载地址**，'
               '方便只支持 32 位的老机型直接取 `_armeabi-v7a`。顺带修掉一处显示问题：'
               '下载中以前英雄卡与下方卡片**各画一条进度条**（同一个下载看着像两个任务），现在只留一条。',
               '**更新頁新增「選擇安裝包」**：該版本有多個包時，一列一個（**檔案名稱 · 架構 · 大小**），'
               '第一個標「建議」= 應用程式內更新會挑的那個；**點一列在瀏覽器開啟該包的下載網址**，'
               '方便只支援 32 位元的舊機型直接取 `_armeabi-v7a`。順帶修掉一處顯示問題：'
               '下載中以前英雄卡與下方卡片**各畫一條進度列**（同一個下載看著像兩個任務），現在只留一條。',
               '**A "choose a package" block on the update page**: when a release has more than one '
               'package it lists one row per file (**name · architecture · size**), the first '
               'marked "Recommended" — the one the in-app update fetches — and **tapping a row '
               'opens that package\'s download URL in the browser**, so 32-bit-only devices can '
               'grab `_armeabi-v7a` directly. One display fix came along: while downloading, the '
               'hero card and the card below it **each drew a progress bar** for the same download '
               '(it read as two tasks); now there is one.')),
        ],
    },
    {
        'ver': 'v2.0.10', 'date': '2026-09-30',
        'items': [
            ('new',
             T('**新：支持国区（中国大陆）佳明 LiveTrack**。佳明的账号体系分国际区与国区两套服务器：'
               '国际区在 `livetrack.garmin.com`、国区在 `livetrack.garmin.cn`。此前只认国际区域名 —— '
               '国区用户从佳明 App 分享过来只会看到「没有找到 LiveTrack 链接」，而且**连一次网络请求都没发出**，'
               '功能是静默失效的。现在三种域名写法都认（`.com` / `.cn` / `.com.cn`），'
               '**没有 `https://` 的一段链接也认**（从聊天窗口里复制出来的常常就是那样），'
               '并补了两处兜底：解析时会在**整篇文档**里找 `trackPoints`（国区与老版分享页不是 Next.js 的'
               '流式块形态），抓取时照旧跟随 301 跳转。',
               '**新：支援國區（中國大陸）佳明 LiveTrack**。佳明的帳號體系分國際區與國區兩套伺服器：'
               '國際區在 `livetrack.garmin.com`、國區在 `livetrack.garmin.cn`。此前只認國際區域名 —— '
               '國區使用者從佳明 App 分享過來只會看到「沒有找到 LiveTrack 連結」，而且**連一次網路請求都沒送出**，'
               '功能是靜默失效的。現在三種網域寫法都認（`.com` / `.cn` / `.com.cn`），'
               '**沒有 `https://` 的一段連結也認**（從聊天視窗裡複製出來的常常就是那樣），'
               '並補了兩處兜底：解析時會在**整篇文件**裡找 `trackPoints`（國區與舊版分享頁不是 Next.js 的'
               '串流區塊形態），抓取時照舊跟隨 301 跳轉。',
               '**New: LiveTrack from China-region Garmin accounts.** Garmin runs **two separate '
               'account systems** on two sets of servers: the international one at '
               '`livetrack.garmin.com` and the China-region (mainland) one at '
               '`livetrack.garmin.cn`. Only the international host was recognised, so a link shared '
               'from the China-region app just said "no LiveTrack link found" — and **not a single '
               'network request was ever made**, making the feature silently dead. All three host '
               'forms are accepted now (`.com` / `.cn` / `.com.cn`), including a link **without '
               '`https://`** (which is what copying from a chat window usually gives), and two '
               'fallbacks were added: parsing searches the **whole document** for `trackPoints` '
               '(the China-region and older share pages are not Next.js streaming chunks), and '
               'fetching still follows the 301 redirect.')),
            ('fix',
             T('**修：macOS 上主界面中文乱码**。正文几乎全部走同一个文字样式，而它的「主字体」在 macOS 上'
               '被写死成一个 CoreText **私有字体名**（`.SF NS Text`）—— 这个名字解析不到时，中文就'
               '**没有可回退的字体**，于是地图页、设置页的中文整片乱码。现在 macOS 交回系统默认字体'
               '（本来就是 SF，观感一致，但「挑字体 + 中文回退」交给系统做），并把中文回退表补全'
               '（`PingFang SC` / `Microsoft YaHei` / `Noto Sans CJK SC` …）；等宽区域（报文、日志、'
               '荣誉墙）也补上了中文回退 —— 等宽字体同样不含中文字形。新增判据：不许再出现那个私有'
               '字体名，回退表必须含三平台的中文字体。',
               '**修：macOS 上主介面中文亂碼**。正文幾乎全部走同一個文字樣式，而它的「主字體」在 macOS 上'
               '被寫死成一個 CoreText **私有字體名**（`.SF NS Text`）—— 這個名字解析不到時，中文就'
               '**沒有可回退的字體**，於是地圖頁、設定頁的中文整片亂碼。現在 macOS 交回系統預設字體'
               '（本來就是 SF，觀感一致，但「挑字體 + 中文回退」交給系統做），並把中文回退表補全'
               '（`PingFang SC` / `Microsoft YaHei` / `Noto Sans CJK SC` …）；等寬區域（報文、日誌、'
               '榮譽牆）也補上了中文回退 —— 等寬字體同樣不含中文字形。新增判據：不許再出現那個私有'
               '字體名，回退表必須含三平台的中文字體。',
               '**Fix: Chinese text was garbled across the macOS UI.** Almost all body text goes '
               'through one shared text style, and on macOS its "primary font" was pinned to a '
               'CoreText **private** family name (`.SF NS Text`). When that name fails to resolve, '
               '**no fallback is left for Chinese**, so the map page and the settings pages came out '
               'as garbage. macOS now uses the system default font instead (it is SF either way, so '
               'nothing looks different — the OS just does the font picking and CJK fallback), and '
               'the CJK fallback list was completed (`PingFang SC` / `Microsoft YaHei` / '
               '`Noto Sans CJK SC` …). Monospace areas (packets, logs, the honour wall) got CJK '
               'fallbacks as well — monospace faces carry no Chinese glyphs either. A new check '
               'refuses that private family name and requires the three platforms\' CJK families.')),
            ('fix',
             T('**修：聊天输入框上方的「字符数 / 整包字节」计数器不实时**（用户上报：要等输入框失去焦点'
               '才更新）。根因是它在页面构建时读一次输入内容，而打字只会重建输入框自己、不会重建它旁边'
               '的计数器；「失焦」恰好也是一次重建，所以看起来像是失焦才刷新。现在它**自己监听输入**'
               '（打字时只重建这一行，不在每次按键时重建整个消息页），译发预览的判定（预览原文 == 当前'
               '输入）也一并搬进去；并补了回归测试 —— 把监听去掉时测试立刻报红。',
               '**修：聊天輸入框上方的「字元數 / 整包位元組」計數器不即時**（使用者回報：要等輸入框失去'
               '焦點才更新）。根因是它在頁面建構時讀一次輸入內容，而打字只會重建輸入框自己、不會重建它'
               '旁邊的計數器；「失焦」恰好也是一次重建，所以看起來像是失焦才刷新。現在它**自己監聽輸入**'
               '（打字時只重建這一列，不在每次按鍵時重建整個訊息頁），譯發預覽的判定（預覽原文 == 目前'
               '輸入）也一併搬進去；並補了回歸測試 —— 把監聽去掉時測試立刻報紅。',
               '**Fix: the length counter above the chat input was not live** (reported: it only '
               'updated once the field lost focus). It was computed by reading the field during a '
               'page build, and typing only rebuilds the text field itself, never the counter beside '
               'it; losing focus happens to be one such rebuild, which is why it looked '
               'focus-driven. It now **listens to the input** (typing rebuilds just that one row, '
               'not the whole messages page), the translation-preview rule (the preview counts only '
               'while its source still matches what is typed) moved in with it, and a regression '
               'test goes red the moment that subscription is removed.')),
        ],
    },
    {
        'ver': 'v2.0.9', 'date': '2026-09-28',
        'items': [
            ('fix',
             T('**新：生命守护增加「碰撞与摔倒检测」（测试）** —— 用手机加速度判断，检测到就弹提醒（我没事 / 拨打急救 / 向附近台站求助），通知栏也会提示。判据是**两段式**：加速度出现很陡的尖峰**且**之后连续 12 秒几乎没动。只报尖峰的话，过减速带、手机掉桌上都会响，一天几次就没人看了；代价是「轻微碰撞（人还能动）不提醒」——它管的是「人已经动不了了」。它会误报（过减速带+等红灯），所以第一个按钮就是「我没事」，页面上也写明这是启发式判断，不是工程级碰撞检测。',
               '**新：生命守護增加「碰撞與摔倒偵測」（測試）** —— 用手機加速度判斷，偵測到就彈提醒（我沒事 / 撥打急救 / 向附近臺站求助），通知列也會提示。判據是**兩段式**：加速度出現很陡的尖峰**且**之後連續 12 秒幾乎沒動。只報尖峰的話，過減速帶、手機掉桌上都會響，一天幾次就沒人看了；代價是「輕微碰撞（人還能動）不提醒」——它管的是「人已經動不了了」。它會誤報（過減速帶+等紅燈），所以第一個按鈕就是「我沒事」，頁面上也寫明這是啟發式判斷，不是工程級碰撞偵測。',
               '**New: crash and fall detection in Life guard (beta)** — judged from the phone accelerometer; it raises an alert (I am fine / call emergency services / ask nearby stations) and also shows in the notification. The test is **two-stage**: a sharp spike **and** then almost no movement for 12 seconds. With the spike alone, speed bumps and a phone dropped on a desk all qualify, and an alert that fires several times a day gets ignored; the trade-off is that a minor impact (where you can still move) will not alert — this is about "I cannot move". It can false-alarm (speed bump plus a red light), so the first button is "I am fine" and the page states it is a heuristic, not engineering-grade crash detection.')),
            ('fix',
             T('**修：步数一直显示「请授权」，但其实已授权**。读数为 -1 有三种原因：没有传感器 / 没有活动识别权限 / **还没收到第一个硬件事件**（没权限时系统只是不派发事件、不报错），之前混为一谈，于是「刚授权还没走过路」被显示成「请授权」。现在原生单独上报权限，四态（不支持/需授权/**等待数据**/正常）只留一个判定出口；顺带修掉「计步依赖传感器辅助开关」与「等待数据也显示授权按钮」。**修：生命守护页的开关点了没反应**（`SettingsPageShell.state` 只管引导卡，并不让页面跟随状态刷新）。**修：速度档编辑弹层的「保存」被三大金刚键压住** —— 底部现在同时让出键盘与系统导航栏，取值取 padding 与 viewPadding 的较大者（有些 ROM 只报后者）。',
               '**修：步數一直顯示「請授權」，但其實已授權**。讀數為 -1 有三種原因：沒有感測器 / 沒有活動辨識權限 / **還沒收到第一個硬體事件**（沒權限時系統只是不派發事件、不報錯），之前混為一談，於是「剛授權還沒走過路」被顯示成「請授權」。現在原生單獨上報權限，四態（不支援/需授權/**等待資料**/正常）只留一個判定出口；順帶修掉「計步依賴感測器輔助開關」與「等待資料也顯示授權按鈕」。**修：生命守護頁的開關點了沒反應**（`SettingsPageShell.state` 只管引導卡，並不讓頁面跟隨狀態刷新）。**修：速度檔編輯彈層的「儲存」被三大金剛鍵壓住** —— 底部現在同時讓出鍵盤與系統導覽列，取值取 padding 與 viewPadding 的較大者（有些 ROM 只報後者）。',
               '**Fix: steps always showed "permission needed" even after granting it.** A reading of -1 has three causes — no sensor / no activity-recognition permission / **no hardware event yet** (without permission the system just does not dispatch events, with no error). They were conflated, so "granted but has not walked yet" read as "permission needed". The native side now reports the permission separately and steps have four states (unsupported / needs permission / **waiting for data** / ok) behind one decision point; the step counting depending on the sensor-assist switch, and the grant button appearing while merely waiting, were fixed too. **Fix: switches on the Life guard page did nothing** (SettingsPageShell.state only serves the guide card; it does not make the page follow state changes). **Fix: the speed-tier editor Save button was covered by the navigation bar** — the sheet now reserves both the keyboard and the system navigation bar, taking the larger of padding and viewPadding (some ROMs only report the latter).')),
        ],
    },
    {
        'ver': 'v2.0.8', 'date': '2026-09-28',
        'items': [
            ('new',
             T('**新：运动步数与排行榜** —— 读手机硬件计步传感器，今日步数可随信标附带（`STEPS=`，'
               '默认关）。设置页荣誉墙上方新增**运动排行榜**：今日步数排行，点一行进台站详情。'
               '**自己不开上传就看不到榜单** —— 榜上每个数字都是别人主动发出来的，'
               '只收不发不该白拿别人的。页面上写明这只是「你听得到的邻居」而不是全网排行。',
               '**新：運動步數與排行榜** —— 讀手機硬體計步感測器，今日步數可隨信標附帶（`STEPS=`，'
               '預設關）。設定頁榮譽牆上方新增**運動排行榜**：今日步數排行，點一列進臺站詳情。'
               '**自己不開上傳就看不到榜單** —— 榜上每個數字都是別人主動發出來的，'
               '只收不發不該白拿別人的。頁面上寫明這只是「你聽得到的鄰居」而不是全網排行。',
               '**New: step counting and a leaderboard** — steps come from the phone\'s hardware '
               'counter and can ride along in the beacon (`STEPS=`, off by default). A new '
               '**activity leaderboard** sits above the honour wall in Settings: today\'s steps, and '
               'tapping a row opens the station detail. **You cannot see the board without '
               'contributing** — every number there was sent by someone else, and receiving without '
               'sending should not get you other people\'s data for free. The page states plainly '
               'that it ranks the neighbours you can hear, not the whole network.')),
            ('new',
             T('**新：「生命守护」页与更新包后台下载**。心率异常告警从「设备 → 心率」搬进独立的'
               '**生命守护**页，说清它是什么、开启条件、以及「向附近台站求助」的口径，并标注'
               '这是测试功能（判定只基于心率数值，无医学依据）。更新包下载现在**支持后台**：'
               '离开页面或切到后台继续下载，通知栏显示进度，可取消；先写 `.part` 再原子改名，'
               '断掉不会留下一个装不上的包。',
               '**新：「生命守護」頁與更新包背景下載**。心率異常告警從「裝置 → 心率」搬進獨立的'
               '**生命守護**頁，說清它是什麼、開啟條件、以及「向附近臺站求助」的口徑，並標註'
               '這是測試功能（判定只基於心率數值，無醫學依據）。更新包下載現在**支援背景**：'
               '離開頁面或切到背景繼續下載，通知列顯示進度，可取消；先寫 `.part` 再原子改名，'
               '中斷不會留下一個裝不上的包。',
               '**New: a "Life guard" page, and background downloads.** The heart-rate alarm moved '
               'into its own **Life guard** page that states what it is, the exact trigger '
               'conditions, and what "ask nearby stations" does — clearly marked as beta (the '
               'judgement uses the heart-rate number only, with no medical basis). Update downloads '
               'now **run in the background**: leaving the page or backgrounding the app keeps it '
               'going, progress shows in the notification, and it can be cancelled. It writes a '
               '`.part` file and renames atomically, so an interrupted download never leaves an '
               'uninstallable package behind.')),
            ('fix',
             T('**修：心率告警的上/下限改不动** —— 输入框原来只在按回车时才保存，失焦不保存，'
               '改完随手点别处就等于没改。现在输入即保存，卡片里还会显示「当前生效 40 ~ 150 bpm」。',
               '**修：心率告警的上/下限改不動** —— 輸入框原來只在按 Enter 時才儲存，失焦不儲存，'
               '改完隨手點別處就等於沒改。現在輸入即儲存，卡片裡還會顯示「目前生效 40 ~ 150 bpm」。',
               '**Fix: the heart-rate alarm limits could not be changed** — the fields only saved on '
               'the keyboard\'s enter key, not on focus loss, so editing and tapping elsewhere saved '
               'nothing. Input now saves as you type, and the card shows "Currently active 40 ~ 150 '
               'bpm".')),
        ],
    },
    {
        'ver': 'v2.0.7', 'date': '2026-09-28',
        'items': [
            ('fix',
             T('**修：沉浸地图一拖就跳回北京**。跟随时用的视野偏移从来没有交给手动模式，'
               '拖动那一瞬间地图平移到了投影基准点；现在先从当前视野接手再切手动，'
               '并把地图旋转一并算进去（横屏航向朝上时位移要换算回画布方向）。',
               '**修：沉浸地圖一拖就跳回北京**。跟隨時用的視野偏移從來沒有交給手動模式，'
               '拖動那一瞬間地圖平移到了投影基準點；現在先從目前視野接手再切手動，'
               '並把地圖旋轉一併算進去（橫屏航向朝上時位移要換算回畫布方向）。',
               '**Fix: dragging the immersive map jumped to Beijing.** The follow-mode viewport '
               'offset was never handed to manual mode, so a drag snapped the map to the '
               'projection base point. It now picks up the current viewport first, and the map '
               'rotation is accounted for (with the heading up, a screen drag must be converted '
               'back to canvas space).')),
            ('new',
             T('**新：上报状态栏可切「详细」** —— 多一行当前触发条件：哪一档、还有多少秒、'
               '距离打点还差多少米、转弯还差多少度（转弯那两个闸也如实摆出来）。'
               '**新：心率异常告警** —— 读数越界弹警告并进通知栏，可拨紧急电话或向 100 公里内'
               '最近的 5 个台站发一条求助；只提醒，不代替你行动。'
               '**新：外置 GPS 优先时手机 GPS 待机** —— 外置失效自动切回并明说是谁在供位。',
               '**新：上報狀態列可切「詳細」** —— 多一行目前觸發條件：哪一檔、還剩多少秒、'
               '距離打點還差多少公尺、轉彎還差多少度（轉彎那兩道閘也如實擺出來）。'
               '**新：心率異常告警** —— 讀數越界彈警告並進通知列，可撥緊急電話或向 100 公里內'
               '最近的 5 個臺站發一則求助；只提醒，不代替你行動。'
               '**新：外接 GPS 優先時手機 GPS 待機** —— 外接失效自動切回並明說是誰在供位。',
               '**New: a "Detailed" beacon status bar** showing what will actually trigger the '
               'next report (active tier, seconds left, metres until the distance trigger, degrees '
               'until the turn trigger). **New: heart-rate alarm** — an out-of-range reading raises '
               'a warning and a notification, offering an emergency call or a help message to the 5 '
               'closest stations within 100 km; it only warns, never acts for you. '
               '**New: idle the phone GPS while an external GPS feeds data**, switching back and '
               'saying so when the external source goes stale.')),
            ('fix',
             T('**修：公告更新后横幅重新出现；纯网络定位可单独选台站图标；2.0 未连接提示会说清'
               '缺什么；赞助入口挪到「关于」上方**。**更新页三处**：渠道文案跟着当前渠道、'
               '长日志默认折叠（可展开）、下载完成后按钮变成「安装」。**浮动面板与退出动画**：'
               '面板高度与底部胶囊改用系统 UI 内边距（某些 ROM 上以前算成 0），'
               '退出设置子页的「一片纯色然后消失」也修好了。',
               '**修：公告更新後橫幅重新出現；純網路定位可單獨選臺站圖示；2.0 未連線提示會說清'
               '缺什麼；贊助入口挪到「關於」上方**。**更新頁三處**：管道文案跟著目前管道、'
               '長日誌預設摺叠（可展開）、下載完成後按鈕變成「安裝」。**浮動面板與退出動畫**：'
               '面板高度與底部膠囊改用系統 UI 內距（某些 ROM 上以前算成 0），'
               '退出設定子頁的「一片純色然後消失」也修好了。',
               '**Fixes**: the notice banner reappears when the notice changes; network-only '
               'positioning can use its own station icon; the 2.0 connection banner says what is '
               'missing; the sponsors entry moved above "About". **Update page**: the channel text '
               'follows the current channel, long release notes are collapsed by default, and the '
               'button turns into "Install" after downloading. **Floating panels and the exit '
               'animation**: panels and the bottom pill now use the system-UI inset (it used to '
               'compute as 0 on some ROMs), and the "flat colour then gone" exit is fixed.')),
        ],
    },
    {
        'ver': 'v2.0.6', 'date': '2026-09-28',
        'items': [
            ('new',
             T('**历史轨迹新增心率记录与折线图**。轨迹点开始记心率（来源与信标里的 `HR=` 一致：'
               '蓝牙心率带或佳明 LiveTrack），历史轨迹详情页多了**心率 / 速度 / 里程**三条折线，'
               '可逐条开关、也可整块隐藏；播放时有竖起指示线对着当前位置，心率那一栏还显示当天的最低–最高。'
               '没有心率读数的时间段曲线会**断开**（不连成直线）。一天最多 4 万个点，曲线进页时一次性'
               '分桶到 240 个点，播放时不掉帧。',
               '**歷史軌跡新增心率記錄與折線圖**。軌跡點開始記心率（來源與信標裡的 `HR=` 一致：'
               '藍牙心率帶或 Garmin LiveTrack），歷史軌跡詳情頁多了**心率 / 速度 / 里程**三條折線，'
               '可逐條開關、也可整塊隱藏；播放時有豎起指示線對著目前位置，心率那一欄還顯示當天的最低–最高。'
               '沒有心率讀取的時間段曲線會**斷開**（不連成直線）。一天最多 4 萬個點，曲線進頁時一次性'
               '分桶到 240 個點，播放時不掉格。',
               '**Heart-rate logging and charts on the history track page.** Track points now record '
               'heart rate (from the same source as `HR=` in the beacon comment: a BLE chest strap or '
               'Garmin LiveTrack), and the day detail page gains three polylines — **heart rate / '
               'speed / distance** — each of which can be toggled, or the whole panel hidden. A vertical '
               'cursor follows playback, and the heart-rate row shows the day\'s min–max. Gaps with no '
               'reading are drawn as **breaks**, not straight lines. A day can hold 40,000 points, so '
               'the curves are bucketed once to 240 points on entry; playback stays smooth.')),
            ('new',
             T('**Windows 可选音频设备与发射串口**。音频页现在能选**播放设备 / 采集设备**，'
               '不再只能用系统默认 —— 这直接决定接到电台的是哪一路信号；TNC 设备页可以选**发射串口**，'
               '默认仍与接收共用一个口，分成两个口可以避开 Windows 上同一 COM 口读写互相打架的问题。'
               '（Android / iOS 不显示音频设备选择器：那里音频路由由系统决定，摆一个假开关只会误导人。）',
               '**Windows 可選音訊裝置與發射串口**。音訊頁現在能選**播放裝置 / 擷取裝置**，'
               '不再只能用系統預設 —— 這直接決定接到電台的是哪一路訊號；TNC 裝置頁可以選**發射串口**，'
               '預設仍與接收共用一個埠，分成兩個埠可以避開 Windows 上同一 COM 埠讀寫互相打架的問題。'
               '（Android / iOS 不顯示音訊裝置選擇器：那裡音訊路由由系統決定，擺一個假開關只會誤導人。）',
               '**Selectable audio devices and TX serial port on Windows.** The audio page can now pick '
               'the **playback and capture device** instead of being stuck with the system default — '
               'which decides what actually feeds your radio. The TNC device page can pick a **separate '
               'TX serial port**; the default is still one port for both directions, and splitting them '
               'avoids two handles fighting over one COM port on Windows. (Android/iOS hide the audio '
               'picker: routing there is the OS\'s job, and a fake switch would only mislead.)')),
            ('fix',
             T('**修一轮用户反馈（#12 / #13 / #15 / #16 / #18 / #19）**。'
               '① 电台身份卡片「更多附加」里的海拔 / 功率 / 天线高度 / 增益设过就删不掉 —— 留空的语义是'
               '「不发送」，但保存时只是跳过写入，旧值一直留在本地、重启又回来，现在留空会真的把它清掉；'
               '② 自定义状态会被 15 秒一次的心跳包顶掉，现在填了自定义状态就紧跟着补发一帧；'
               '③ Android 15 强制 edge-to-edge，三大金刚键压住页面底部按钮，现在滚动内容底部让出导航栏高度；'
               '④ 设置详情页面板展开 / 收起会闪一下或突然填充，现在高度与透明度一起动；'
               '⑤ 下载完成后「立即下载」按钮还在（拿文件名里的 `2.0.5` 去比 tag 的 `v2.0.5`，永远不相等），'
               '现在比较时忽略 `v` 前缀；⑥ 更新渠道默认改为 GitHub（更新页仍可一键切回镜像）。',
               '**修一輪使用者回報（#12 / #13 / #15 / #16 / #18 / #19）**。'
               '① 電台身份卡片「更多附加」裡的海拔 / 功率 / 天線高度 / 增益設過就刪不掉 —— 留空的語意是'
               '「不傳送」，但儲存時只是跳過寫入，舊值一直留在本機、重啟又回來，現在留空會真的把它清掉；'
               '② 自訂狀態會被 15 秒一次的心跳包頂掉，現在填了自訂狀態就緊跟著補發一幀；'
               '③ Android 15 強制 edge-to-edge，三大金剛鍵壓住頁面底部按鈕，現在捲動內容底部讓出導覽列高度；'
               '④ 設定詳情頁面板展開 / 收起會閃一下或突然填充，現在高度與透明度一起動；'
               '⑤ 下載完成後「立即下載」按鈕還在（拿檔案名稱裡的 `2.0.5` 去比 tag 的 `v2.0.5`，永遠不相等），'
               '現在比較時忽略 `v` 前綴；⑥ 更新渠道預設改為 GitHub（更新頁仍可一鍵切回鏡像）。',
               '**A round of user-reported fixes (#12, #13, #15, #16, #18, #19).** (1) The "Advanced" '
               'extras on the station identity card could not be cleared: empty means "do not send", '
               'but saving merely skipped the write, so the old value stayed on disk and came back after '
               'a restart — clearing now removes it. (2) A custom status was overwritten by the '
               '15-second keep-alive frame; a custom status is now re-sent right after it. (3) Android '
               '15 forces edge-to-edge, so the navigation bar covered buttons at the bottom of a page — '
               'scrollable content now reserves that inset. (4) Expand/collapse on settings pages '
               'flashed or snapped; height and opacity now animate together. (5) The download button '
               'stayed after finishing (a file-name version `2.0.5` was compared against the tag '
               '`v2.0.5`, which never matches); the comparison now ignores the `v` prefix. (6) The update '
               'channel now defaults to GitHub (one tap switches back to the mirror).')),
        ],
    },
    {
        'ver': 'v2.0.5', 'date': '2026-09-27',
        'items': [
            ('fix',
             T('**修：2.0.4 的 PHG 在第三方侧其实没生效**。2.0.4 发出的报文里，数据扩展被空格分隔'
               '（`000/000 PHG2130 /A=000033`），用参考实现 aprslib 解出来 `phg` **完全缺失**、'
               '`PHG2130` 被当成普通备注文字 —— 也就是说第三方地图上看不到覆盖范围，这个功能等于没做。'
               '根因是**两个独立的坑**：① APRS101 把 PHG / `/A=` / CsT 定义为**固定长度的数据扩展**，'
               '必须紧贴符号、彼此之间不用空格（真实台站都是 `…ErPHG1460/A=000071` 这样）；'
               '② CsT 与 PHG 争同一个「注释开头」，解析器先匹配 `^\\d{3}/\\d{3}`，一旦命中就'
               '**只再看 DF 测向报文，根本不再去找 PHG**，所以哪怕紧贴，只要 `000/000` 在前 PHG 也读不出来。',
               '**修：2.0.4 的 PHG 在第三方端其實沒生效**。2.0.4 送出的報文裡，資料擴充被空格分隔'
               '（`000/000 PHG2130 /A=000033`），用參考實作 aprslib 解出來 `phg` **完全缺失**、'
               '`PHG2130` 被當成普通備註文字 —— 也就是說第三方地圖上看不到涵蓋範圍，這個功能等於沒做。'
               '根因是**兩個獨立的坑**：① APRS101 把 PHG / `/A=` / CsT 定義為**固定長度的資料擴充**，'
               '必須緊貼符號、彼此之間不用空格（真實臺站都是 `…ErPHG1460/A=000071` 這樣）；'
               '② CsT 與 PHG 爭同一個「註解開頭」，解析器先匹配 `^\\d{3}/\\d{3}`，一旦命中就'
               '**只再看 DF 測向報文，根本不再去找 PHG**，所以哪怕緊貼，只要 `000/000` 在前 PHG 也讀不出來。',
               '**Fix: 2.0.4\'s PHG never actually took effect for third parties.** In 2.0.4 the data '
               'extensions were space-separated (`000/000 PHG2130 /A=000033`), and the reference '
               'implementation (aprslib) reports `phg` as **missing entirely** with `PHG2130` left as '
               'ordinary comment text — meaning third-party maps showed no coverage and the feature did '
               'nothing. Two independent traps caused it: (1) APRS101 defines PHG / `/A=` / CsT as '
               '**fixed-length data extensions** that must be glued to the symbol with no separators '
               '(real stations look like `…ErPHG1460/A=000071`); (2) CsT and PHG compete for the same '
               '"start of comment" slot — parsers match `^\\d{3}/\\d{3}` first and, once it hits, **only '
               'look for a DF report and never search for PHG**, so even glued together PHG stays '
               'unreadable while `000/000` comes first.')),
            ('up',
             T('**修法**：扩展块**整块紧贴**，且**首位让给 PHG** —— 填了 PHG 时 CsT 不再随位置报文发送。'
               '修好后：`!2155.17N/11052.40EbPHG2130/A=000033 Bat:22%`（空格只出现在扩展块与备注之间）。'
               '**一个取舍**：同时填了 PHG 的移动台，aprs.fi 上就没有速度/方位角了 —— 两者都要'
               '「注释开头」这一个位置，无法共存；没填 PHG 的台站一切照旧。'
               '另把信标报文的第三方兼容性测试纳入 CI，这类「编译过、analyze 绿、第三方读不出」的'
               '问题从此有测试兜底。',
               '**修法**：擴充區塊**整塊緊貼**，且**首位讓給 PHG** —— 填了 PHG 時 CsT 不再隨位置報文發送。'
               '修好後：`!2155.17N/11052.40EbPHG2130/A=000033 Bat:22%`（空格只出現在擴充區塊與備註之間）。'
               '**一個取捨**：同時填了 PHG 的移動臺，aprs.fi 上就沒有速度/方位角了 —— 兩者都要'
               '「註解開頭」這一個位置，無法共存；沒填 PHG 的臺站一切照舊。'
               '另把信標報文的第三方相容性測試納入 CI，這類「編譯過、analyze 綠、第三方讀不出」的'
               '問題從此有測試把關。',
               '**The fix**: keep the extension block **glued together** and **give the first slot to '
               'PHG** — when PHG is present, CsT is no longer sent with the position packet. Afterwards: '
               '`!2155.17N/11052.40EbPHG2130/A=000033 Bat:22%` (spaces appear only between the block and '
               'the comment). **One trade-off**: a mobile station that also fills in PHG shows no '
               'speed/bearing on aprs.fi — both need that single "start of comment" slot and cannot '
               'coexist; stations without PHG are unaffected. The beacon packet\'s third-party '
               'compatibility test now runs in CI, so this class of "compiles, analyze is green, '
               'third parties cannot read it" bug has a guard.')),
        ],
    },
    {
        'ver': 'v2.0.4', 'date': '2026-09-27',
        'items': [
            ('new',
             T('**位置报文数据扩展（PHG · APRS101 第 9 章）**：电台设置的「台站备注」下多了「高级设置」，'
               '可填功率（瓦）/ 天线高度（英尺）/ 增益（dB）。填任一项就附上固定 7 字节的 `PHGphgd`，'
               '留空则完全不发。量化照规范做：功率只取**不超过实际值的最大档**（25 W 报 25、30 W 也只报 25'
               ' —— 报大了等于虚报覆盖范围），天线高度按 10×2ⁿ 英尺取档；设置页把**真正会被编进报文的'
               '结果**回显出来（量化过程用户看不见，不摆出来就无从知道到底发了什么）。报文里的位置也照'
               '规范来：`PHGphgd` **紧跟符号**（`!坐标/符号` 之后，排在 `/A=` 海拔与其它备注文字之前），'
               '与标准报文 `…:!2216.45N/11113.90ErPHG5950` 形状一致 —— 第三方解析器按「注释开头的数据'
               '扩展」识别 PHG，插在后面就读不出来。',
               '**位置報文資料擴充（PHG · APRS101 第 9 章）**：電台設定的「臺站備註」下多了「進階設定」，'
               '可填功率（瓦）/ 天線高度（英尺）/ 增益（dB）。填任一項就附上固定 7 位元組的 `PHGphgd`，'
               '留空則完全不送。量化照規範做：功率只取**不超過實際值的最大檔**（25 W 報 25、30 W 也只報 25'
               ' —— 報大了等於虛報涵蓋範圍），天線高度按 10×2ⁿ 英尺取檔；設定頁把**真正會被編進報文的'
               '結果**回顯出來（量化過程使用者看不見，不擺出來就無從得知到底送出了什麼）。報文裡的位置也'
               '照規範來：`PHGphgd` **緊跟符號**（`!座標/符號` 之後，排在 `/A=` 海拔與其它備註文字之前），'
               '與標準報文 `…:!2216.45N/11113.90ErPHG5950` 形狀一致 —— 第三方解析器依「註解開頭的資料'
               '擴充」辨識 PHG，插在後面就讀不出來。',
               '**Position packet data extension (PHG, APRS101 chapter 9)**: under Radio settings → '
               '"Station comment" there is now an "Advanced" section taking power (W) / antenna height (ft) / '
               'gain (dB). Filling in any one of them appends the fixed 7-byte `PHGphgd`; leaving them empty '
               'sends nothing at all. The encoding follows the spec: power uses the **largest step that does '
               'not exceed the real value** (25 W reports 25, and 30 W still reports 25 — over-reporting '
               'claims coverage you do not have) and antenna height snaps to 10×2ⁿ feet. The settings page '
               '**echoes back what will actually be encoded**, since quantisation is invisible and there '
               'would otherwise be no way to know what went out. In the packet the extension sits where the '
               'spec puts it: `PHGphgd` comes **immediately after the symbol** (right after `!lat/lon/symbol`, '
               'ahead of the `/A=` altitude and any other comment text), matching the standard packet '
               '`…:!2216.45N/11113.90ErPHG5950` — third-party parsers look for PHG as a data extension at the '
               'start of the comment, and reading it after other fields fails.')),
            ('new',
             T('**独立状态报文**：高级设置里可填状态文本，与位置报文共用一个「发射」按钮 —— 哪个有内容'
               '就发哪个，状态文本留空时发内置的 `APRSlocus CONNECT vX.Y.Z 平台` 在线帧。状态报文是'
               '**独立一帧**（`>` 开头、不含坐标、不会移动你在 aprs.fi 上的位置），所以没有定位也能发。'
               '发送时一律直接读输入框当前内容，不依赖输入事件的时序 —— 中文输入法组合输入时曾出现'
               '「明明填了，却发出默认帧」。此外新增手填海拔：留空跟随定位（默认行为不变），'
               '设置页显示当前将发出的 `/A=aaaaaa` 片段。',
               '**獨立狀態報文**：進階設定裡可填狀態文字，與位置報文共用一個「發射」按鈕 —— 哪個有內容'
               '就送哪個，狀態文字留空時送內建的 `APRSlocus CONNECT vX.Y.Z 平台` 在線幀。狀態報文是'
               '**獨立一幀**（`>` 開頭、不含座標、不會移動你在 aprs.fi 上的位置），所以沒有定位也能送。'
               '發射時一律直接讀輸入框目前內容，不依賴輸入事件的時序 —— 中文輸入法組合輸入時曾出現'
               '「明明填了，卻送出預設幀」。此外新增手填海拔：留空跟隨定位（預設行為不變），'
               '設定頁會顯示目前將送出的 `/A=aaaaaa` 片段。',
               '**Standalone status packets**: the Advanced section takes a status text, sharing one '
               '"Transmit" button with the position packet — whichever has content is sent, and an empty '
               'status text sends the built-in `APRSlocus CONNECT vX.Y.Z` online frame. A status '
               'packet is a **frame of its own** (`>`-prefixed, carrying no coordinates, and it does not '
               'move you on aprs.fi), so it can be sent even without a fix. Transmitting reads the current '
               'contents of the field directly instead of relying on input-event timing — with an IME '
               'composing text the app used to send the default frame although the user had typed '
               'something. A manually entered altitude was added too: empty follows the fix (the default '
               'is unchanged), and the settings page shows the `/A=aaaaaa` fragment that will be sent.')),
            ('new',
             T('**台站详情与地图信息窗**：台站详情多出一行**独立状态报文**（紫色 + 播报图标），与'
               '「位置备注」分开显示 —— 两者来源不同（频点常写在位置备注里、设备来源常写在状态报文里），'
               '混成一行就分不出哪个是哪个；此前这类文本只进数据包页的原文，台站详情里彻底看不到。'
               '地图标记信息窗新增**高度**、**位置备注**、**状态文本**三行，且**按需出现**而不是常驻'
               '占位 —— 绝大多数台站没有这些字段，常驻只会给出两行 `--`，把「没有」和「没收到」'
               '显示成同一个样子。',
               '**臺站詳情與地圖資訊窗**：臺站詳情多出一列**獨立狀態報文**（紫色 + 播報圖示），與'
               '「位置備註」分開顯示 —— 兩者來源不同（頻點常寫在位置備註裡、裝置來源常寫在狀態報文裡），'
               '混成一列就分不出哪個是哪個；此前這類文字只進資料封包頁的原文，臺站詳情裡徹底看不到。'
               '地圖標記資訊窗新增**高度**、**位置備註**、**狀態文字**三列，且**按需出現**而不是常駐'
               '佔位 —— 絕大多數臺站沒有這些欄位，常駐只會給出兩列 `--`，把「沒有」和「沒收到」'
               '顯示成同一個樣子。',
               '**Station details and the map info window**: station details gained a line for the '
               '**standalone status packet** (purple, with a megaphone icon), shown separately from the '
               'position comment — the two come from different packets (frequencies usually live in the '
               'position comment, device provenance in the status packet), and merging them makes it '
               'impossible to tell which is which. That text used to appear only in the raw packet console '
               'and never on the station. The map marker info window gained **altitude**, **position '
               'comment** and **status text** lines, each **appearing only when present** rather than as a '
               'permanent placeholder — few stations carry these fields, and placeholders would print two '
               'rows of `--`, making "absent" and "not received" look identical.')),
            ('fix',
             T('**本版修正**：①「发射」按钮会**先查链路**，未连接时直接说明「请先连接链路」，不再静默'
               '只做本地记录；②填了 PHG 却还没有定位时，如实回执「带 PHG 的位置报文没能发出」；'
               '③状态报文**改用自己的连接文案**（此前只发状态帧，界面却写着「位置已上报」）；'
               '④地图页「距下次上报」的秒数改为**每秒刷新**（此前没有台站刷新时会停住）；'
               '⑤设备页「链路自检」不再出现两遍标题与副标题；⑥手机电量开关**保持在信标页'
               '「信标上报内容」**，默认值不变。',
               '**本版修正**：①「發射」按鈕會**先查連結**，未連線時直接說明「請先連接連結」，不再靜默'
               '只做本機記錄；②填了 PHG 卻還沒有定位時，如實回執「帶 PHG 的位置報文沒能送出」；'
               '③狀態報文**改用自己的連線文案**（此前只送狀態幀，介面卻寫著「位置已上報」）；'
               '④地圖頁「距下次上報」的秒數改為**每秒刷新**（此前沒有臺站刷新時會停住）；'
               '⑤裝置頁「連結自檢」不再出現兩遍標題與副標題；⑥手機電量開關**保持在信標頁'
               '「信標上報內容」**，預設值不變。',
               '**Fixes in this build**: (1) the Transmit button **checks the link first** and says '
               '"connect the link first" instead of silently recording locally; (2) PHG without a fix is '
               'reported honestly — the receipt says the position packet with PHG was not sent; '
               '(3) status packets **use their own connection text** (previously the banner claimed '
               '"position beacon sent" when only a status frame had gone out); (4) the countdown for the '
               'next report on the map page now **ticks every second** (it used to freeze when no station '
               'update arrived); (5) the link self-test on the device page no longer shows its title and '
               'subtitle twice; (6) the phone-battery switch **stays on the beacon page** ("Beacon '
               'contents") with unchanged defaults.')),
        ],
    },
    {
        'ver': 'v2.0.2', 'date': '2026-09-26',
        'items': [
            ('new',
             T('**新增百度地图 / 百度卫星图源**：百度不是 Web Mercator（BD-09 坐标 + 自有投影、'
               '瓦片 y 轴朝北），为此把「按图源切换投影」做到全链路 —— 渲染、标记 / 轨迹、沉浸地图、'
               '跟踪、历史回放、离线下载共用同一套投影，标记与瓦片不再错开。',
               '**新增百度地圖 / 百度衛星圖源**：百度不是 Web Mercator（BD-09 座標 + 自有投影、'
               '圖磚 y 軸朝北），為此把「依圖源切換投影」做到全鏈路 —— 渲染、標記 / 軌跡、沉浸地圖、'
               '追蹤、歷史回放、離線下載共用同一套投影，標記與圖磚不再錯開。',
               '**New Baidu Map / Baidu Satellite sources**: Baidu is not Web Mercator (BD-09 '
               'coordinates plus its own projection, tiles with a north-pointing y-axis), so a '
               'per-source projection now runs through the whole chain — rendering, markers / '
               'tracks, the immersive map, the tracker, track replay and offline downloads share '
               'one projection, and markers no longer drift against the tiles.')),
            ('new',
             T('**新增「纯网络」定位模式**：只用基站 / Wi-Fi（不注册 GPS），适合没有 GPS 的设备，'
               '也用于极端省电；自动上报使用专用固定间隔（默认 300 秒、可调），不必再开强制开关，'
               '也不走智能信标（网络没有可靠速度）。',
               '**新增「純網路」定位模式**：只用基地台 / Wi-Fi（不註冊 GPS），適合沒有 GPS 的裝置，'
               '也用於極端省電；自動上報使用專用固定間隔（預設 300 秒、可調），不必再開強制開關，'
               '也不走智慧信標（網路沒有可靠速度）。',
               '**New "Network only" location mode**: cell / Wi-Fi only (GPS not registered), for '
               'devices without GPS and for extreme battery saving; auto-beaconing uses a dedicated '
               'fixed interval (default 300s, configurable) — no force switch needed, and smart '
               'beaconing does not apply because network fixes have no reliable speed.')),
            ('new',
             T('**公告支持内嵌视频**：应用内公告改为手写 Markdown（简中 / 繁中 / 英文），'
               '`@video` 标记可在应用内播放（Android / iOS / macOS；Windows / Linux / Web 回退为'
               '在浏览器打开）。旧版本读到那行只会当普通文字（仍是可点链接）。',
               '**公告支援內嵌影片**：應用內公告改為手寫 Markdown（簡中 / 繁中 / 英文），'
               '`@video` 標記可在應用內播放（Android / iOS / macOS；Windows / Linux / Web 回退為'
               '在瀏覽器開啟）。舊版本讀到那行只會當普通文字（仍是可點連結）。',
               '**Notices can embed video**: the in-app notice is now hand-written Markdown '
               '(Simplified Chinese / Traditional Chinese / English) and an `@video` marker plays '
               'in-app (Android / iOS / macOS; Windows / Linux / Web fall back to the external '
               'browser). Older versions simply show that line as plain text (still a link).')),
            ('new',
             T('**启动检查新版本**：启动后检查一次，有新版时弹提醒（每版本只提醒一次、可稍后）。',
               '**啟動檢查新版本**：啟動後檢查一次，有新版時彈提醒（每版本只提醒一次、可稍後）。',
               '**Update check on launch**: the app checks once on start and shows a reminder when '
               'a new version exists (once per version, dismissible).')),
            ('fix',
             T('**修**：地图信息窗仍显示「点击查看」—— 2.0.1 只改了生成的 l10n 产物、漏改 ARB 源，'
               '构建时被覆盖，现已改到位（六语言）；Windows 构建移除与当前工具链不兼容的 '
               'webview_windows，改走外部浏览器。',
               '**修**：地圖資訊窗仍顯示「點選檢視」—— 2.0.1 只改了生成的 l10n 產物、漏改 ARB 源，'
               '建置時被覆蓋，現已改到位（六語言）；Windows 建置移除與當前工具鏈不相容的 '
               'webview_windows，改走外部瀏覽器。',
               '**Fixes**: the map info window still showed "Tap to view" (2.0.1 only changed the '
               'generated l10n output and missed the ARB source, so the build reverted it; fixed in '
               'all six languages); the Windows build now drops the webview_windows plugin that is '
               'incompatible with the current toolchain and opens such links externally.')),
        ],
    },
    {
        'ver': 'v2.0.0', 'date': '2026-09-25',
        'items': [
            ('new',
             T('**TOUCH SKY · 2.0 正式版**：1.5.8 → 2.0 的 **322 次更新**在这一版合流 —— 全新 UI 2.0（地图基底 + 可拖拽面板、底部胶囊导航、横屏三端统一）、磨砂玻璃与云母材质、沉浸地图与多图源、离线地图与轨迹回放、官方设备库识别、群聊与 7 家翻译、蓝牙 TNC 与声卡 TNC、iGate 与 PKWDWPL、iOS / macOS 原生定位、按转弯与按距离的智能信标、天气与短波传播建议、Android 桌面小组件、ADIF 导出与数据包控制台、佳明分享与蓝牙心率带、6 种界面语言。',
               '**TOUCH SKY · 2.0 正式版**：1.5.8 → 2.0 的 **322 次更新**在這一版合流 —— 全新 UI 2.0（地圖基底 + 可拖曳面板、底部膠囊導覽、橫向三端統一）、磨砂玻璃與雲母材質、沉浸地圖與多圖源、離線地圖與軌跡回放、官方裝置庫辨識、群組聊天與 7 家翻譯、藍牙 TNC 與音效卡 TNC、iGate 與 PKWDWPL、iOS / macOS 原生定位、按轉彎與按距離的智慧信標、天氣與短波傳播建議、Android 桌面小工具、ADIF 匯出與封包主控台、Garmin 分享與藍牙心率帶、6 種介面語言。',
               '**TOUCH SKY · 2.0**: the **322 updates** from 1.5.8 to 2.0 land together — the new UI 2.0 (a map-first layout with a draggable sheet, bottom capsule nav, landscape unified across phone / tablet / desktop), frosted-glass and mica materials, the immersive map with many sources, offline maps and track replay, aprs.org device identification, group chat and 7 translation providers, Bluetooth and sound-card TNCs, iGate and PKWDWPL, native iOS / macOS location, smart beaconing by turn and by distance, weather and HF propagation advice, Android home-screen widgets, ADIF export and the packet console, Garmin sharing and BLE heart-rate straps, and six UI languages.')),
        ],
    },
    {
        'ver': 'v1.6.173', 'date': '2026-09-24',
        'items': [
            ('fix',
             T('**佳明页补齐了「自动填充 / 确定按钮 / 状态显示」**（用户实测反馈）：'
               '① 链接框原来只在页面初始化时读一次，分享进来时页面已经开着就**不会自动填充** —— '
               '现在跟随状态同步，并显示「已自动填入分享链接」；'
               '② 原来只有一个含义模糊的开关（标签写着「追踪中」是状态不是动作）—— '
               '现在是明确的 **[开始追踪] / [停止追踪]** 按钮；'
               '③ 新增状态卡：未开启追踪 / 追踪中（含已转发点数与最后更新时间）/ 抓取失败（含原因），'
               '链接框下面还会实时显示「链接有效」。'
               '分享到达的提示也从 4 秒延长到 8 秒，不容易错过',
               '**佳明頁補齊了「自動填入 / 確定按鈕 / 狀態顯示」**（使用者實測回饋）：'
               '① 連結框原來只在頁面初始化時讀一次，分享進來時頁面已經開著就**不會自動填入** —— '
               '現在跟隨狀態同步，並顯示「已自動填入分享連結」；'
               '② 原來只有一個含義模糊的開關（標籤寫著「追蹤中」是狀態不是動作）—— '
               '現在是明確的 **[開始追蹤] / [停止追蹤]** 按鈕；'
               '③ 新增狀態卡：未開啟追蹤 / 追蹤中（含已轉發點數與最後更新時間）/ 抓取失敗（含原因），'
               '連結框下面還會即時顯示「連結有效」。'
               '分享到達的提示也從 4 秒延長到 8 秒，不容易錯過',
               '**The Garmin page now has auto-fill, a confirm button and a status display** '
               '(reported from a real device). (1) The URL field used to read the state once at init, '
               'so a share arriving while the page was already open would never fill it in — it now '
               'follows the state and says "Share link filled in automatically". (2) There used to be '
               'only an ambiguous switch (labelled "Tracking", a state rather than an action) — it is '
               'now explicit **[Start tracking] / [Stop tracking]** buttons. (3) A new status card '
               'shows Not tracking / Tracking (with forwarded-point count and last update time) / '
               'Fetch failed (with the reason), and the field shows "Link is valid" live. The share '
               'toast also lasts 8s instead of 4s so it is not missed.')),
        ],
    },
    {
        'ver': 'v1.6.172', 'date': '2026-09-24',
        'items': [
            ('fix',
             T('**关于页名片卡不再贴着下面板块**：原来名片卡下面**直接**就是「代码贡献」的节标题'
               '（间距 0），现在留 22（与其它节间距一致）。'
               '另外**位置来源「听谁的」说清楚了**：界面原来把来源拆成两半说'
               '（上报页「定位 / 模拟位置」、设备页「手机 GPS / 佳明」），看着像两件事。'
               '现在判断只有一处（`positionSourceNow`），两处都写明优先级：'
               '**模拟/手动位置 › 佳明（手表有实时数据时）› 手机 GPS**，'
               '上报页的选项也改名成「手机 GPS」（与设备页同名），并显示「当前使用：…」',
               '**關於頁名片卡不再貼著下面板塊**：原來名片卡下面**直接**就是「程式碼貢獻」的節標題'
               '（間距 0），現在留 22（與其它節間距一致）。'
               '另外**位置來源「聽誰的」說清楚了**：介面原來把來源拆成兩半說'
               '（上報頁「定位 / 模擬位置」、裝置頁「手機 GPS / 佳明」），看著像兩件事。'
               '現在判斷只有一處（`positionSourceNow`），兩處都寫明優先順序：'
               '**模擬/手動位置 › 佳明（手錶有即時資料時）› 手機 GPS**，'
               '上報頁的選項也改名成「手機 GPS」（與裝置頁同名），並顯示「目前使用：…」',
               '**The About page name card no longer touches the section below** — the "Code '
               'contributions" header used to start immediately after it (0 gap); it now has 22, '
               'matching the other sections. Also, **"which position source wins?" is now stated**: '
               'the UI used to describe it in two halves (beacon page "Location / Simulated", '
               'Devices page "Phone GPS / Garmin"), which read as two different things. There is now '
               'one decision (`positionSourceNow`) whose priority is written in both places — '
               '**simulated/manual › Garmin (while the watch has live data) › phone GPS** — and the '
               'beacon page option is renamed to "Phone GPS" (matching the Devices page), with an '
               '"In use now: …" line.')),
        ],
    },
    {
        'ver': 'v1.6.171', 'date': '2026-09-24',
        'items': [
            ('fix',
             T('**佳明分享「有时候行有时候不行」修好了**：① 取分享文本只读 `EXTRA_TEXT`，'
               '而不少应用（部分佳明版本 / 浏览器）把文本放在 `clipData` 里 —— 读到 null 就'
               '整条静默，这正是「时好时坏」的机制；② 读不到文本时直接静默返回，用户既没提示'
               '也没日志；③ **冷启动竞态**：应用启动时那次分享可能在界面注册回调**之前**就'
               '到达，回调为 null 被丢掉（就是「跳转之后还是没有反馈」）—— 现在改成'
               '「有回调就调、没有就存起来」，界面起来后主动取一次。'
               '顺带把识别放宽：短链码长度不限 + 大小写不敏感',
               '**佳明分享「有時候行有時候不行」修好了**：① 取分享文字只讀 `EXTRA_TEXT`，'
               '而不少應用（部分佳明版本 / 瀏覽器）把文字放在 `clipData` 裡 —— 讀到 null 就'
               '整條靜默，這正是「時好時壞」的機制；② 讀不到文字時直接靜默返回，使用者既沒提示'
               '也沒日誌；③ **冷啟動競態**：應用啟動時那次分享可能在介面註冊回呼**之前**就'
               '到達，回呼為 null 被丟掉（就是「跳轉之後還是沒有回饋」）—— 現在改成'
               '「有回呼就調、沒有就存起來」，介面起來後主動取一次。'
               '順帶把識別放寬：短鏈碼長度不限 + 大小寫不敏感',
               '**Garmin sharing "sometimes works, sometimes doesn\'t" is fixed.** (1) Share text '
               'was only read from `EXTRA_TEXT`, while plenty of apps (some Garmin versions, '
               'browsers) put it in `clipData` — a null read made the whole share go silent, which '
               'is exactly the intermittent mechanism. (2) No text meant a silent return, with '
               'neither a message nor a log line. (3) A **cold-start race**: the share can arrive '
               '**before** the UI registers the callback, so the callback is null and the event is '
               'dropped (the "still no feedback after the hand-off") — it is now "call if present, '
               'otherwise store", with the UI consuming it once it is up. Link detection was widened '
               'too: the short code is unbounded in length and case-insensitive.')),
        ],
    },
    {
        'ver': 'v1.6.170', 'date': '2026-09-24',
        'items': [
            ('up',
             T('**心率会说明来源**（用户要求「如果链接了佳明就提示从佳明追踪获取」）：心率有两个来源'
               '（BLE 胸带 / 佳明点里的心率）。佳明在供数据时，心率卡与「数据来源」卡的心率行都会写明'
               '「心率来自佳明 LiveTrack（手表）· 128 bpm」——没插胸带也不会再显示成「未连接」，'
               '数字是哪来的摆在明面上。'
               '另外**关于页空隙**（用户反馈「一些组件空隙不够」）：节标题与卡片之间 8→12，'
               '致谢卡里「测试成员」标签到呼号胶囊 8→11、胶囊之间 8→10，`BA3RZL` 那组标签到胶囊 6→8',
               '**心率會說明來源**（使用者要求「如果連結了佳明就提示從佳明追蹤獲取」）：心率有兩個來源'
               '（BLE 胸帶／佳明點裡的心率）。佳明在供資料時，心率卡與「資料來源」卡的心率列都會寫明'
               '「心率來自佳明 LiveTrack（手錶）· 128 bpm」——沒插胸帶也不會再顯示成「未連線」，'
               '數字是哪來的擺在明面上。'
               '另外**關於頁空隙**（使用者回報「一些元件空隙不夠」）：節標題與卡片之間 8→12，'
               '致謝卡裡「測試成員」標籤到呼號膠囊 8→11、膠囊之間 8→10，`BA3RZL` 那組標籤到膠囊 6→8',
               '**Heart rate now names its source** (on request): there are two sources (a BLE strap / '
               'the heart rate carried in Garmin points), so while Garmin is supplying data both the '
               'heart-rate card and the heart-rate row of the data-sources card say "Heart rate from '
               'Garmin LiveTrack (watch) · 128 bpm" — no strap required, and it is obvious where the '
               'number comes from. Also **About page spacing** (reported as too tight): section '
               'header → card 8 → 12, and inside the credits card the "test members" label → callsign '
               'chips 8 → 11 with chip gaps 8 → 10, and the BA3RZL group 6 → 8.')),
        ],
    },
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


def md_inline(s):
    """将内联 markdown（`代码`、**粗体**、*斜体*）转换为 HTML 标签。"""
    if not s:
        return ''
    s = re.sub(r'`([^`]+)`', r'<code>\1</code>', s)
    s = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', s)
    s = re.sub(r'(?<![*\w])\*([^\s*]+)\*(?![*\w])', r'<em>\1</em>', s)
    return s


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
                                   title=md_inline(c['title'][lang]),
                                   desc=md_inline(c['desc'][lang]),
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
                       % (kind, md_inline(txt[lang])))
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
        # 归一成 LF 再处理：Windows 下 git（core.autocrlf）把工作区检出成 CRLF，
        # 而下面所有锚点都是按 LF 写的 —— 不归一就会"找不到锚点"直接崩。写回时
        # newline='' 保证输出还是 LF，与仓库里存的形态一致（diff 才干净）。
        s = s.replace('\r\n', '\n').replace('\r', '\n')
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
