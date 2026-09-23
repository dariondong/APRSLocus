#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""手册正文（第 2/2 部分）：maps · stations · data · widgets · platform · troubleshooting

settings 页不在此处 —— 它由 gen_manual_pages.py 从 tool/extract_settings.py 的抽取结果
自动生成逐项表格（设置页文案 = 本文件的 SETTINGS_INTRO）。
"""
from manual_content import T

# ── 设置参考页：每个分组的三语导语（表格外的「怎么用」提示） ──
SETTINGS_INTRO = {
    '设置': T(
        '设置页顶部是 <b>8 张分组卡</b>（点进去是子页面），下面还有 6 个直达入口。'
        '本页把每个子页里的设置项逐条列出：名称、控件、默认值、说明 —— 默认值直接取自代码，'
        '改了代码重新生成即对齐。',
        '設定頁頂部是 <b>8 張分組卡</b>（點進去是子頁面），下面還有 6 個直達入口。'
        '本頁把每個子頁裡的設定項逐條列出：名稱、控件、預設值、說明 —— 預設值直接取自程式碼，'
        '改了程式碼重新產生即對齊。',
        'The Settings page opens with <b>eight category cards</b> (each leading to its own page) '
        'plus six direct entries. Below, every setting is listed: name, control, default, meaning — '
        'defaults are read from the code, so regenerating keeps them honest.'),
    '电台': T(
        '身份是所有报文的根：呼号必须与你的执照一致，SSID 决定台站类型（-9 车载、-7 手持常见）。',
        '身份是所有封包的根：呼號必須與你的執照一致，SSID 決定臺站類型（-9 車載、-7 手持常見）。',
        'Identity is the root of every frame: the callsign must match your licence, and the SSID '
        'states the station type (-9 mobile, -7 handheld are common).'),
    '定位上报': T(
        '三件事：用什么定位（GPS / 网络 / 手动）、多久报一次（默认 60 秒、最短 5 秒）、'
        '报什么（速度/方位角/电量可关）。',
        '三件事：用什麼定位（GPS / 網路 / 手動）、多久報一次（預設 60 秒、最短 5 秒）、'
        '報什麼（速度/方位角/電量可關）。',
        'Three decisions: what fixes you (GPS / network / manual), how often (60 s default, 5 s floor) '
        'and what travels in the frame (speed/course/battery can be switched off).'),
    '连接': T(
        'APRS-IS 服务器与 Passcode、数据来源多选、接收范围（默认 300 km）、数据上限。'
        '改完点「保存并应用」才生效。',
        'APRS-IS 伺服器與 Passcode、資料來源複選、接收範圍（預設 300 km）、資料上限。'
        '改完點「儲存並套用」才生效。',
        'APRS-IS server and Passcode, multi-select data sources, receive range (300 km default) and '
        'data caps. Changes apply only with “Save &amp; apply”.'),
    '显示': T(
        '深色模式、天气组件、单位与网格在这里；地图类型与离线地图在地图菜单与对应子页。'
        '顶部还有一条<b>公告横幅</b>（默认开）：内容取自官网的公告区，改官网就能发通知、不用等新版；'
        '断网时显示上次缓存的那份，不想看到可以关掉（关掉后不再联网）。',
        '深色模式、天氣小組件、單位與網格在這裡；地圖類型與離線地圖在地圖選單與對應子頁。'
        '頂部還有一條<b>公告橫幅</b>（預設開）：內容取自官網的公告區，改官網就能發通知、不用等新版；'
        '斷網時顯示上次快取的那份，不想看到可以關掉（關掉後不再連網）。',
        'Dark mode, weather widget, units and grid live here; tile source and offline maps live in '
        'the map menu and their own sub-page. There is also an <b>announcement banner</b> (on by '
        'default) whose content comes from the website announcement section — publishing a notice '
        'needs no app release; offline it shows the last cached copy, and turning it off stops all '
        'network requests.'),
    '设备': T(
        '设备总览 = 当前链路 + 网关状态 + 三个子页入口（TNC / 音频 / PKWDWPL）+ 链路自检与日志。',
        '裝置總覽 = 當前鏈路 + 網關狀態 + 三個子頁入口（TNC / 音訊 / PKWDWPL）+ 鏈路自檢與日誌。',
        'Device overview = current link, gateway status, the three sub-pages (TNC / audio / PKWDWPL) '
        'plus link self-test and logs.'),
    '数据': T(
        '只读统计与破坏性操作分开摆：清聊天记录是单独按钮，「清除所有数据」会二次确认。',
        '唯讀統計與破壞性操作分開擺：清聊天記錄是單獨按鈕，「清除所有資料」會二次確認。',
        'Read-only stats and destructive actions are kept apart: clearing the chat is its own button, '
        'and “clear all data” asks twice.'),
    '高级': T(
        '横屏开关、演示数据（模拟台站/数据包）、收发计数与重新运行向导都在这里。',
        '橫螢幕開關、示範資料（模擬臺站/封包）、收發計數與重新執行引導都在這裡。',
        'Landscape toggle, demo data (fake stations/packets), RX/TX counters and re-running the wizard.'),
    'TNC 设备与参数': T(
        '接蓝牙/USB TNC 的全部参数：绑定、初始化串、线速、KISS 定时参数、中继路径、发射自检。',
        '接藍牙/USB TNC 的全部參數：綁定、初始化字串、線速、KISS 定時參數、中繼路徑、發射自檢。',
        'Everything for a Bluetooth/USB TNC: binding, init string, baud, KISS timing, digipeat path '
        'and the TX self-test.'),
    '音频（声卡 TNC）': T(
        '把声卡当 TNC：采样率/比特率/音调、发射电平与 CSMA 等待、WAV 文件模式（离线解码录音）。',
        '把音效卡當 TNC：取樣率/鮑率/音調、發射電平與 CSMA 等待、WAV 檔案模式（離線解碼錄音）。',
        'Use the sound card as a TNC: sample rate/baud/tone, TX level and CSMA wait, plus WAV file mode '
        '(decode a recording offline).'),
    'PKWDWPL 设备': T(
        'Kenwood 航点只读链路：绑定与状态、收到的航点计数、严格校验和（默认关，只标注不丢弃）。',
        'Kenwood 航點唯讀鏈路：綁定與狀態、收到的航點計數、嚴格校驗和（預設關，只標註不丟棄）。',
        'Read-only Kenwood waypoint link: binding and status, waypoint counters, strict checksum '
        '(off by default — mismatches are flagged, not dropped).'),
    '翻译设置': T(
        '目标语言、引擎（默认 auto 免密钥）、各引擎的密钥/实例地址、测试翻译。',
        '目標語言、引擎（預設 auto 免金鑰）、各引擎的金鑰/實例位址、測試翻譯。',
        'Target language, engine (auto, no key needed), per-engine keys and instance URLs, test translation.'),
    '主题': T(
        '颜色 / 图标 / 文字 / 背景图四大块，改完可导出 JSON 分享；预设皮肤可一键切换。',
        '顏色 / 圖示 / 文字 / 背景圖四大塊，改完可匯出 JSON 分享；預設皮膚可一鍵切換。',
        'Four blocks — colours, icons, text, background — exportable as JSON to share; preset skins switch in one tap.'),
    '备份与恢复': T(
        '一个 JSON 装下设置与数据；白名单导入防来路不明的文件改配置；导入后需重启生效。',
        '一個 JSON 裝下設定與資料；白名單匯入防來路不明的檔案改設定；匯入後需重啟生效。',
        'One JSON holds settings and data; whitelisted import stops a foreign file from rewriting '
        'your config; restart after importing.'),
    '离线地图': T(
        '瓦片缓存与「仅使用离线瓦片」开关；下载范围 = 当前所见那一屏，入口在地图菜单。',
        '圖磚快取與「僅使用離線圖磚」開關；下載範圍 = 當前所見那一螢，入口在地圖選單。',
        'Tile cache plus the “offline tiles only” switch; the download area is exactly what you see '
        'on screen, entered from the map menu.'),
}

BODIES = {

# ─────────────────────────── 地图与显示 ───────────────────────────
'maps': [
    ('tiles', T('选图源', '選圖源', 'Pick tile sources'), '''
<p>入口：<b>地图页 → 图源/地图菜单</b>。按用途选：</p>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>图源</th><th>什么时候用</th></tr></thead><tbody>
<tr><td>高德 / 高德卫星</td><td>国内定位无缝对齐（GCJ-02）</td></tr>
<tr><td><b>矢量地图</b></td><td>客户端实时渲染、缩放清晰、<b>无需 API Key</b>、WGS-84 —— 首选</td></tr>
<tr><td>Carto 浅色 / 深色 / 航行者</td><td>在线瓦片，深色页配深色图</td></tr>
<tr><td>OSM 标准 / 人道</td><td>通用底图</td></tr>
<tr><td>OpenTopo 地形</td><td>等高线与地形</td></tr>
<tr><td>Esri 街道 / 影像</td><td>街道 / 卫星影像</td></tr>
</tbody></table></div>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>验证：</b>切图源后你的标记位置<b>不应跳动超过 500 米</b> ——
做不到就说明纠偏没生效，见下一节。</p></div></div>
''', '''
<p>入口：<b>地圖頁 → 圖磚/地圖選單</b>。按用途選：</p>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>圖磚</th><th>什麼時候用</th></tr></thead><tbody>
<tr><td>高德 / 高德衛星</td><td>國內定位無縫對齊（GCJ-02）</td></tr>
<tr><td><b>向量地圖</b></td><td>用戶端即時算繪、縮放清晰、<b>無需 API Key</b>、WGS-84 —— 首選</td></tr>
<tr><td>Carto 淺色 / 深色 / 航行者</td><td>線上圖磚，深色頁配深色圖</td></tr>
<tr><td>OSM 標準 / 人道</td><td>通用底圖</td></tr>
<tr><td>OpenTopo 地形</td><td>等高線與地形</td></tr>
<tr><td>Esri 街道 / 影像</td><td>街道 / 衛星影像</td></tr>
</tbody></table></div>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>驗證：</b>切圖磚後你的標記位置<b>不應跳動超過 500 公尺</b> ——
做不到就代表糾正沒生效，見下一節。</p></div></div>
''', '''
<p>Entry: <b>Map tab → tile / map menu</b>. Pick by purpose:</p>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>Source</th><th>When to use it</th></tr></thead><tbody>
<tr><td>AMap / AMap satellite</td><td>aligns perfectly with Chinese positioning (GCJ-02)</td></tr>
<tr><td><b>Vector map</b></td><td>rendered on the client, crisp at any zoom, <b>no API key</b>, WGS-84 — the default pick</td></tr>
<tr><td>Carto light / dark / voyager</td><td>raster tiles; dark tiles for dark mode</td></tr>
<tr><td>OSM standard / humanitarian</td><td>general-purpose base</td></tr>
<tr><td>OpenTopo</td><td>contours and terrain</td></tr>
<tr><td>Esri street / imagery</td><td>streets / satellite imagery</td></tr>
</tbody></table></div>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>Check:</b> after switching, your marker must <b>not jump more than 500 m</b> —
if it does, datum correction is not applied, see next.</p></div></div>
'''),
    ('datum', T('坐标不漂：WGS-84 ↔ GCJ-02', '座標不漂：WGS-84 ↔ GCJ-02', 'No drift: WGS-84 ↔ GCJ-02'), '''
<div class="callout info"><span class="co-ic">🗺️</span><div><p>APRS 全球用 <b>WGS-84</b>；国内图源（高德）用 <b>GCJ-02</b>。
应用内置双向转换：国内图源按 GCJ-02 对齐、切回国际图源还原 —— 所以<b>切换图源不会把你的位置挪出 500 米</b>，
台站、轨迹、我的位置一起对齐。</p></div></div>
<ul>
<li><b>手动定位的坐标</b>按 WGS-84 输入 —— 从地图选点时内部会自动换算。</li>
<li>发现某个图源整体偏移：先确认它属于哪类坐标系，再看是不是用了「仅离线瓦片」混了旧缓存。</li>
</ul>
''', '''
<div class="callout info"><span class="co-ic">🗺️</span><div><p>APRS 全球用 <b>WGS-84</b>；國內圖磚（高德）用 <b>GCJ-02</b>。
應用內建雙向轉換：國內圖磚按 GCJ-02 對齊、切回國際圖磚還原 —— 所以<b>切換圖磚不會把你的位置挪出 500 公尺</b>，
臺站、軌跡、我的位置一起對齊。</p></div></div>
<ul>
<li><b>手動定位的座標</b>按 WGS-84 輸入 —— 從地圖選點時內部會自動換算。</li>
<li>發現某個圖磚整體偏移：先確認它屬於哪類座標系，再看是不是用了「僅離線圖磚」混了舊快取。</li>
</ul>
''', '''
<div class="callout info"><span class="co-ic">🗺️</span><div><p>APRS uses <b>WGS-84</b> worldwide; Chinese sources (AMap) use <b>GCJ-02</b>.
The app converts both ways — Chinese sources are aligned to GCJ-02 and restored when you switch back —
so <b>switching layers never moves you by 500 m</b>; stations, tracks and your own marker move together.</p></div></div>
<ul>
<li><b>Manual coordinates</b> are entered as WGS-84; picking a point on the map converts internally.</li>
<li>A whole layer looks offset: check which datum it uses, then whether “offline tiles only” is serving a stale cache.</li>
</ul>
'''),
    ('offline', T('下载离线地图', '下載離線地圖', 'Download offline maps'), '''
<ol class="m-steps">
<li>先把地图<b>平移缩放到要覆盖的那一屏</b> —— 下载范围 = 当前所见（不是选框）。</li>
<li><b>设置 → 显示 → 离线地图</b>（或地图菜单里的离线入口）→ 开始下载。</li>
<li>支持<b>断点续传</b>；单区域上限 <b>20 万张瓦片（约 3 GB）</b>。</li>
<li>下完开 <b>仅使用离线瓦片</b>：一个网络请求都不发，完全离线可用。</li>
</ol>
<div class="callout warn"><span class="co-ic">⚠️</span><div><p>Web 版<b>不提供下载</b>（浏览器没有稳定可写目录）—— 需要离线图请用 Android / Windows。</p></div></div>
''', '''
<ol class="m-steps">
<li>先把地圖<b>平移縮放到要覆蓋的那一螢</b> —— 下載範圍 = 當前所見（不是選框）。</li>
<li><b>設定 → 顯示 → 離線地圖</b>（或地圖選單裡的離線入口）→ 開始下載。</li>
<li>支援<b>斷點續傳</b>；單區域上限 <b>20 萬張圖磚（約 3 GB）</b>。</li>
<li>下完開 <b>僅使用離線圖磚</b>：一個網路請求都不發，完全離線可用。</li>
</ol>
<div class="callout warn"><span class="co-ic">⚠️</span><div><p>Web 版<b>不提供下載</b>（瀏覽器沒有穩定可寫目錄）—— 需要離線圖請用 Android / Windows。</p></div></div>
''', '''
<ol class="m-steps">
<li>Pan and zoom the map to the <b>screen you want to keep</b> — the download area is exactly what you see (no box selection).</li>
<li><b>Settings → Display → Offline map</b> (or the offline entry in the map menu) → download.</li>
<li><b>Resumable</b>; capped at <b>200k tiles (~3 GB) per region</b>.</li>
<li>Then enable <b>offline tiles only</b>: zero network requests, fully offline.</li>
</ol>
<div class="callout warn"><span class="co-ic">⚠️</span><div><p>The web build offers <b>no download</b> (browsers have no stable writable directory) —
use Android or Windows for offline maps.</p></div></div>
'''),
    ('look', T('界面风格与主题', '介面風格與主題', 'Look and feel'), '''
<ul>
<li><b>UI 2.0</b>：以地图为基底的新布局（默认），「显示设置」里可随时切回经典布局；材质在<b>磨砂玻璃</b>与<b>云母</b>之间切换。</li>
<li><b>深色模式</b>：设置 → 显示 → 深色模式（跟随系统 / 强制开 / 强制关）。</li>
<li><b>主题</b>（设置 → 主题）：17 个颜色令牌、图标、文字、背景图都能改，<b>导出 JSON</b> 可分享；界面缩放 85% ~ 130%。</li>
<li><b>天气组件</b>开关也在这一页 —— 关掉后主页天气卡不再请求数据。</li>
</ul>
''', '''
<ul>
<li><b>UI 2.0</b>：以地圖為基底的新佈局（預設），「顯示設定」裡可隨時切回經典佈局；材質在<b>磨砂玻璃</b>與<b>雲母</b>之間切換。</li>
<li><b>深色模式</b>：設定 → 顯示 → 深色模式（跟隨系統 / 強制開 / 強制關）。</li>
<li><b>主題</b>（設定 → 主題）：17 個顏色權杖、圖示、文字、背景圖都能改，<b>匯出 JSON</b> 可分享；介面縮放 85% ~ 130%。</li>
<li><b>天氣小組件</b>開關也在這一頁 —— 關掉後首頁天氣卡不再請求資料。</li>
</ul>
''', '''
<ul>
<li><b>UI 2.0</b>: the map-first layout (default); Display settings switches back to the classic one at any time; material toggles between <b>frosted glass</b> and <b>mica</b>.</li>
<li><b>Dark mode</b>: Settings → Display → dark mode (follow system / force on / force off).</li>
<li><b>Themes</b> (Settings → Themes): 17 colour tokens, icons, text and background are editable and <b>exportable as JSON</b>; UI scaling runs 85–130%.</li>
<li>The <b>weather widget</b> switch is on the same page — off means the home weather card stops requesting data.</li>
</ul>
'''),
],

# ─────────────────────────── 台站与筛选 ───────────────────────────
'stations': [
    ('receive', T('收什么：范围与接收偏好', '收什麼：範圍與接收偏好', 'What you receive'), '''
<p>两层过滤都在 <b>设置 → 连接</b>，决定「报文到不到得了你」：</p>
<ol class="m-steps">
<li><b>接收范围过滤</b>：<code>r/纬度/经度/半径</code>，默认 <b>300 km</b>（最小 10 km）。
勾「过滤中心跟随我的位置」就以你为圆心；改完点 <b>保存并应用</b>。</li>
<li><b>接收呼号筛选</b>（接收偏好）：按<b>国家/地区</b>勾选；另有总开关决定<b>是否也收未勾选国家</b>的台站。
还可以精确到某个呼号 —— <b>范围之外也收指定呼号</b>。</li>
<li>向导里选的「接收地区」就是这里的国家/地区勾选；<b>不勾 = 全收</b>。</li>
</ol>
<div class="callout warn"><span class="co-ic">🧭</span><div><p>「收不到」先查这两处，再查链路 —— 顺序反了会白折腾：
范围 300 km 之外的台站，链路再通也到不了你。</p></div></div>
''', '''
<p>兩層過濾都在 <b>設定 → 連線</b>，決定「封包到不到得了你」：</p>
<ol class="m-steps">
<li><b>接收範圍過濾</b>：<code>r/緯度/經度/半徑</code>，預設 <b>300 km</b>（最小 10 km）。
勾「過濾中心跟隨我的位置」就以你為圓心；改完點 <b>儲存並套用</b>。</li>
<li><b>接收呼號篩選</b>（接收偏好）：按<b>國家/地區</b>勾選；另有總開關決定<b>是否也收未勾選國家</b>的臺站。
還可以精確到某個呼號 —— <b>範圍之外也收指定呼號</b>。</li>
<li>引導裡選的「接收地區」就是這裡的國家/地區勾選；<b>不勾 = 全收</b>。</li>
</ol>
<div class="callout warn"><span class="co-ic">🧭</span><div><p>「收不到」先查這兩處，再查鏈路 —— 順序反了會白折騰：
範圍 300 km 之外的臺站，鏈路再通也到不了你。</p></div></div>
''', '''
<p>Both filters live under <b>Settings → Connection</b> and decide whether packets can reach you at all:</p>
<ol class="m-steps">
<li><b>Receive range</b>: <code>r/lat/lng/radius</code>, <b>300 km</b> by default (10 km minimum).
“Follow my position” centres it on you; press <b>Save &amp; apply</b> after changing it.</li>
<li><b>Receive preferences</b>: tick countries/regions, plus the master switch for “also receive stations from unticked countries”.
Exact callsigns are received <b>even from outside the range</b>.</li>
<li>The “receive area” from the wizard is this same country list; <b>nothing ticked = receive everything</b>.</li>
</ol>
<div class="callout warn"><span class="co-ic">🧭</span><div><p>“Receiving nothing?” check these two <i>before</i> the link — the other way round wastes an evening:
a station 400 km away cannot reach you through a 300 km filter however healthy the link is.</p></div></div>
'''),
    ('display', T('看什么：列表筛选', '看什麼：列表篩選', 'What you display'), '''
<p><b>台站页签</b>上再做一层<b>展示筛选</b>（不影响接收）：</p>
<ul>
<li><b>状态</b>：在线 / 移动 / 静止 —— 「在线判定时长」在 <b>设置 → 连接 → 数据上限</b>（默认 5 分钟）。</li>
<li><b>类型</b>：APRS 类型（车载/固定/中继/气象）、软件（APRSLocus）、设备类别与具体型号。</li>
<li><b>收藏</b>：标星的台站单独一档。</li>
<li><b>搜索</b>：呼号 / 类型 / 备注 / 网格 —— 台站几万条也不卡（内存上限默认 10 万条，可调）。</li>
<li><b>「在地图查看」会切回地图</b>：列表里那个小地图按钮、或详情页的「在地图查看」，
会回到地图页签、收起内容面板，视野飞到该台站 —— 不用自己再点一次「地图」。</li>
</ul>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>验证：</b>列表顶部应显示当前筛选的命中数；点「清除筛选」应回到全量。
若全量也没有目标台站，那是<b>没收到</b>（回到上一节）而不是没显示。</p></div></div>
''', '''
<p><b>臺站頁籤</b>上再做一層<b>展示篩選</b>（不影響接收）：</p>
<ul>
<li><b>狀態</b>：線上 / 移動 / 靜止 —— 「線上判定時長」在 <b>設定 → 連線 → 資料上限</b>（預設 5 分鐘）。</li>
<li><b>類型</b>：APRS 類型（車載/固定/中繼/氣象）、軟體（APRSLocus）、裝置類別與具體型號。</li>
<li><b>收藏</b>：加星的臺站單獨一檔。</li>
<li><b>搜尋</b>：呼號 / 類型 / 備註 / 網格 —— 臺站幾萬條也不卡（記憶體上限預設 10 萬條，可調）。</li>
<li><b>「在地圖查看」會切回地圖</b>：列表裡那個小地圖按鈕、或詳情頁的「在地圖查看」，
會回到地圖頁籤、收起內容面板，視野飛到該臺站 —— 不用自己再點一次「地圖」。</li>
</ul>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>驗證：</b>列表頂部應顯示當前篩選的命中數；點「清除篩選」應回到全量。
若全量也沒有目標臺站，那是<b>沒收到</b>（回到上一節）而不是沒顯示。</p></div></div>
''', '''
<p>The <b>Stations tab</b> adds a <b>display filter</b> on top (it does not affect receiving):</p>
<ul>
<li><b>Status</b>: online / moving / static — the “online window” is under <b>Settings → Connection → Data caps</b> (5 minutes by default).</li>
<li><b>Type</b>: APRS type (mobile/fixed/relay/weather), software (APRSLocus), device class and exact model.</li>
<li><b>Favourites</b>: starred stations get their own bucket.</li>
<li><b>Search</b>: callsign / type / comment / grid — stays fast at tens of thousands (100k stations in memory by default, adjustable).</li>
<li><b>“View on map” switches back for you</b>: the small map button in the list (or “View on map” in the detail sheet) returns to the Map tab, collapses the content panel and flies to that station — no need to tap “Map” yourself.</li>
</ul>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>Check:</b> the list header shows the hit count; “clear filters” returns to everything.
If the full list still lacks your target, it was <b>never received</b> (previous section), not hidden.</p></div></div>
'''),
    ('detail', T('台站详情与设备识别', '臺站詳情與裝置識別', 'Detail & device ID'), '''
<ul>
<li><b>官方设备库</b>：接入 aprs.org 的 <code>aprsorg/aprs-deviceid</code>（tocall），按报文目的呼号识别
<b>厂商 + 型号 + 设备类别</b>（车台/手台/追踪器/App/iGate/中继/气象站…）；内置快照 + 联网自动更新。</li>
<li><b>同款 APRSlocus 台站</b>自动标记，能看到版本、电量等专属信息；FMO 台站自动识别。</li>
<li><b>详情页可跳转</b>：QRZ 呼号库、<a href="https://aprs.fi" target="_blank" rel="noopener">aprs.fi</a> 看轨迹、APRS.tv。</li>
<li><b>符号</b>：37 个官方符号表、3571 个标准图标 —— 官方 PNG 优先、Material 图标兜底。</li>
<li><b>轨迹回放</b>：详情里可回放该台站的轨迹（数据在本地历史里）。</li>
</ul>
''', '''
<ul>
<li><b>官方裝置資料庫</b>：接入 aprs.org 的 <code>aprsorg/aprs-deviceid</code>（tocall），按封包目的呼號識別
<b>廠牌 + 型號 + 裝置類別</b>（車臺/手臺/追蹤器/App/iGate/中繼/氣象站…）；內建快取 + 聯網自動更新。</li>
<li><b>同款 APRSLocus 臺站</b>自動標記，能看到版本、電量等專屬資訊；FMO 臺站自動識別。</li>
<li><b>詳情頁可跳轉</b>：QRZ 呼號庫、<a href="https://aprs.fi" target="_blank" rel="noopener">aprs.fi</a> 看軌跡、APRS.tv。</li>
<li><b>符號</b>：37 個官方符號表、3571 個標準圖示 —— 官方 PNG 優先、Material 圖示備援。</li>
<li><b>軌跡回放</b>：詳情裡可回放該臺站的軌跡（資料在本地歷史裡）。</li>
</ul>
''', '''
<ul>
<li><b>Official device library</b>: aprs.org’s <code>aprsorg/aprs-deviceid</code> (tocall) resolves
<b>vendor + model + class</b> from the packet’s destination callsign (mobile/portable/tracker/app/iGate/relay/weather…);
bundled snapshot plus online updates.</li>
<li><b>Other APRSlocus stations</b> are marked automatically (version, battery, …); FMO stations are recognised too.</li>
<li><b>Detail page jumps out</b> to the QRZ callsign database, <a href="https://aprs.fi" target="_blank" rel="noopener">aprs.fi</a> for trails, and APRS.tv.</li>
<li><b>Symbols</b>: 37 official tables, 3571 standard icons — official PNG first, Material icons as fallback.</li>
<li><b>Trail playback</b>: play back that station’s track from its detail page (the history is stored locally).</li>
</ul>
'''),
],

# ─────────────────────────── 导出 · 备份 · 轨迹 ───────────────────────────
'data': [
    ('adif', T('导出 ADIF', '匯出 ADIF', 'ADIF export'), '''
<ol class="m-steps">
<li>入口：<b>设置 → 导出 ADIF</b>。</li>
<li>频率可自定义（ADIF 是业余无线电通用日志交换格式）。</li>
<li>导出的文件可直接导入其它日志软件。</li>
</ol>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>验证：</b>导出后用任意日志软件打开，能看到呼号、时间、模式字段即成功。</p></div></div>
''', '''
<ol class="m-steps">
<li>入口：<b>設定 → 匯出 ADIF</b>。</li>
<li>頻率可自訂（ADIF 是業餘無線電通用日誌交換格式）。</li>
<li>匯出的檔案可直接匯入其它日誌軟體。</li>
</ol>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>驗證：</b>匯出後用任意日誌軟體開啟，能看到呼號、時間、模式欄位即成功。</p></div></div>
''', '''
<ol class="m-steps">
<li>Entry: <b>Settings → Export ADIF</b>.</li>
<li>The frequency is configurable (ADIF is the standard amateur log interchange format).</li>
<li>The file imports straight into any other logging program.</li>
</ol>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>Check:</b> open the export anywhere — callsign, date and mode fields should all be there.</p></div></div>
'''),
    ('backup', T('备份与恢复', '備份與恢復', 'Backup & restore'), '''
<ol class="m-steps">
<li><b>导出</b>（设置 → 备份与恢复 → 导出备份）：设置配置（电台、信标、地图、筛选、数据来源、服务器等）
与本地数据进<b>一个 JSON</b>；可勾选是否包含图片。</li>
<li><b>导入</b>：选择备份文件（或从剪贴板粘贴）→ 导入后<b>重启应用</b>生效。</li>
<li>换机 / 重装的顺序：装应用 → 导入 → 重启 → 核对「设置 → 连接」的服务器与 Passcode。</li>
</ol>
<div class="callout warn"><span class="co-ic">🔐</span><div><p><b>白名单导入</b>：只认该分组白名单内的键 —— 来路不明的 JSON 改不了内部设置；
更高版本的备份会被拒绝并提示先升级。<b>备份文件含呼号、服务器口令与 API 密钥，请妥善保管。</b></p>
<p style="margin-top:6px">平台差异：Android 用系统文件选择器（下载目录）；Windows 存 Documents；Web 版走剪贴板。
读取上限 <b>32 MB</b>。</p></div></div>
''', '''
<ol class="m-steps">
<li><b>匯出</b>（設定 → 備份與恢復 → 匯出備份）：設定組態（電臺、信標、地圖、篩選、資料來源、伺服器等）
與本地資料進<b>一個 JSON</b>；可勾選是否包含圖片。</li>
<li><b>匯入</b>：選擇備份檔案（或從剪貼簿貼上）→ 匯入後<b>重啟應用</b>生效。</li>
<li>換機 / 重裝的順序：裝應用 → 匯入 → 重啟 → 核對「設定 → 連線」的伺服器與 Passcode。</li>
</ol>
<div class="callout warn"><span class="co-ic">🔐</span><div><p><b>白名單匯入</b>：只認該分組白名單內的鍵 —— 來路不明的 JSON 改不了內部設定；
更高版本的備份會被拒絕並提示先升級。<b>備份檔案含呼號、伺服器口令與 API 金鑰，請妥善保管。</b></p>
<p style="margin-top:6px">平台差異：Android 用系統檔案選擇器（下載目錄）；Windows 存 Documents；Web 版走剪貼簿。
讀取上限 <b>32 MB</b>。</p></div></div>
''', '''
<ol class="m-steps">
<li><b>Export</b> (Settings → Backup → export): configuration (station, beacon, map, filters, sources, server…)
plus local data into <b>one JSON</b>; images are optional.</li>
<li><b>Import</b>: pick the file (or paste from the clipboard) → <b>restart the app</b> to apply.</li>
<li>New device order: install → import → restart → re-check server and Passcode under Settings → Connection.</li>
</ol>
<div class="callout warn"><span class="co-ic">🔐</span><div><p><b>Whitelisted import</b>: only keys inside that group’s whitelist are accepted, so a file from
someone else cannot rewrite internal settings; a backup from a newer version is rejected with
“update first”. <b>The file contains your callsign, server passwords and API keys — keep it safe.</b></p>
<p style="margin-top:6px">Platform differences: Android uses the system picker (Downloads), Windows saves to
Documents, web uses the clipboard. Reading is capped at <b>32 MB</b>.</p></div></div>
'''),
    ('track', T('历史轨迹与回放', '歷史軌跡與回放', 'Track history & playback'), '''
<ol class="m-steps">
<li>入口：<b>设置 → 历史轨迹</b>。</li>
<li>按天落盘：<code>tracklog/YYYY-MM-DD.json</code>，记录经纬度、速度、航向、海拔、精度 —— 退出重进还在。</li>
<li>每天一屏：总里程、平均与最高速度、<b>移动时长</b>、轨迹点数；可按天删除或一键清空。
移动时长只累计确实在动的段 —— 中途停车吃饭的两小时不算开车。</li>
<li><b>点进某天可回放</b>：底图与主地图同一套（同缓存、同坐标纠偏）；轨迹随播放生长、可拖进度、
<b>0.5× ~ 4×</b> 倍速、可跟随视角；超过 45 秒的停顿自动快进。</li>
<li><b>地图上该怎么看这条线</b>：屏幕轨迹按 GPS <b>1 秒</b>采样，落点还要满足「位移够」或「隔 5 秒且确实挪了」
—— 所以拐弯不会被切成斜线，慢走也不会稀稀拉拉。<b>发到服务器去的那些点</b>另用<b>橙色小菱形</b>标在轨迹上，
数量与间隔一眼可见（轨迹点会被抽稀、封顶，菱形不会：那是已经发出去的事实）。</li>
</ol>
<div class="callout info"><span class="co-ic">🧾</span><div><p>它与地图上那条「我的轨迹」<b>刻意分开</b>：屏幕轨迹只服务本次显示，退出即失；
历史轨迹是留档，可导出、可回放。</p></div></div>
''', '''
<ol class="m-steps">
<li>入口：<b>設定 → 歷史軌跡</b>。</li>
<li>按天落盤：<code>tracklog/YYYY-MM-DD.json</code>，記錄經緯度、速度、航向、海拔、精度 —— 退出重進還在。</li>
<li>每天一屏：總里程、平均與最高速度、<b>移動時長</b>、軌跡點數；可按天刪除或一鍵清空。
移動時長只累計確實在動的段 —— 中途停車吃飯的兩小時不算開車。</li>
<li><b>點進某天可回放</b>：底圖與主地圖同一套（同快取、同座標校正）；軌跡隨播放生長、可拖進度、
<b>0.5× ~ 4×</b> 倍速、可跟隨視角；超過 45 秒的停頓自動快進。</li>
<li><b>地圖上該怎麼看這條線</b>：螢幕軌跡按 GPS <b>1 秒</b>取樣，落點還要滿足「位移夠」或「隔 5 秒且確實挪了」
—— 所以轉彎不會被切成斜線，慢走也不會稀稀落落。<b>發到伺服器去的那些點</b>另用<b>橘色小菱形</b>標在軌跡上，
數量與間隔一眼可見（軌跡點會被抽稀、封頂，菱形不會：那是已經送出去的事實）。</li>
</ol>
<div class="callout info"><span class="co-ic">🧾</span><div><p>它與地圖上那條「我的軌跡」<b>刻意分開</b>：螢幕軌跡只服務本次顯示，退出即失；
歷史軌跡是留檔，可匯出、可回放。</p></div></div>
''', '''
<ol class="m-steps">
<li>Entry: <b>Settings → Track history</b>.</li>
<li>Saved per local day (<code>tracklog/YYYY-MM-DD.json</code>) with lat/lng, speed, course, altitude and accuracy — it survives a restart.</li>
<li>One screen per day: distance, average and top speed, <b>moving time</b>, point count; delete a day or clear all.
Moving time only counts segments that genuinely moved — a two-hour lunch stop is not billed as driving.</li>
<li><b>Tap a day to replay it</b>: same tile stack as the main map (same cache, same correction), the line grows as it plays,
draggable progress, <b>0.5×–4×</b> speed, follow view; stops over 45 s fast-forward.</li>
<li><b>How to read that line on the map</b>: the on-screen track samples GPS at <b>1 s</b> and keeps a point when it moved far enough <em>or</em> five seconds passed with real movement
— so corners are not cut into diagonals and slow walks are not sparse. The points <b>actually sent to the server</b> are marked with <b>small orange diamonds</b>:
count them and check the spacing at a glance (track points get thinned and capped; the diamonds do not, because they already went out).</li>
</ol>
<div class="callout info"><span class="co-ic">🧾</span><div><p>It is <b>deliberately separate</b> from the on-screen “my track”, which only serves this session
and disappears on exit; history is the archive — exportable and replayable.</p></div></div>
'''),
],

# ─────────────────────────── 桌面组件与短波 ───────────────────────────
'widgets': [
    ('home', T('三套桌面组件', '三套桌面小組件', 'Three widgets'), '''
<p>Android 主屏长按 → 小组件 → 找 <b>APRSlocus</b>：</p>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>组件</th><th>内容</th></tr></thead><tbody>
<tr><td><b>天气</b></td><td>图标、温度、现象、今日高低温 + 指标格 + 火腿建议；按主屏空间自动切 4 档布局（主档 / 竖长 / 紧凑 / 单行）</td></tr>
<tr><td><b>短波</b></td><td>各波段「日 → 夜」条件色带，一眼看出现在该用哪一段</td></tr>
<tr><td><b>系统状态</b></td><td>链路、定位与计数的实时快照</td></tr>
</tbody></table></div>
<ol class="m-steps">
<li>添加组件 → <b>先打开一次应用</b>（组件要应用推数据）。</li>
<li>升级后若显示空白：再打开一次应用即可刷新。</li>
</ol>
<div class="callout info"><span class="co-ic">📲</span><div><p><b>组件不自己联网</b>：应用把已计算、已本地化的快照单向推给原生渲染 ——
天气接口密钥只在应用侧，不会外泄到组件。</p></div></div>
''', '''
<p>Android 主螢幕長按 → 小組件 → 找 <b>APRSLocus</b>：</p>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>小組件</th><th>內容</th></tr></thead><tbody>
<tr><td><b>天氣</b></td><td>圖示、溫度、現象、今日高低溫 + 指標格 + 火腿建議；按主螢幕空間自動切 4 檔佈局（主檔 / 豪長 / 緊湊 / 單行）</td></tr>
<tr><td><b>短波</b></td><td>各波段「日 → 夜」條件色帶，一眼看出現在該用哪一段</td></tr>
<tr><td><b>系統狀態</b></td><td>鏈路、定位與計數的即時快照</td></tr>
</tbody></table></div>
<ol class="m-steps">
<li>新增小組件 → <b>先打開一次應用</b>（小組件要應用推資料）。</li>
<li>升級後若顯示空白：再打開一次應用即可刷新。</li>
</ol>
<div class="callout info"><span class="co-ic">📲</span><div><p><b>小組件不自己連線</b>：應用把已計算、已本地化的快照單向推給原生算繪 ——
天氣介面金鑰只在應用側，不會外洩到小組件。</p></div></div>
''', '''
<p>Android home screen → long press → widgets → find <b>APRSlocus</b>:</p>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>Widget</th><th>Contents</th></tr></thead><tbody>
<tr><td><b>Weather</b></td><td>icon, temperature, condition, today’s high/low + metric cells + ham advice; four layouts chosen from the space you give it</td></tr>
<tr><td><b>HF</b></td><td>day → night condition bands per pair, so you see which band to try now</td></tr>
<tr><td><b>System status</b></td><td>a live snapshot of link, positioning and counters</td></tr>
</tbody></table></div>
<ol class="m-steps">
<li>Add the widget → <b>open the app once</b> (widgets are fed by the app).</li>
<li>Blank after an update? Open the app once more to refresh them.</li>
</ol>
<div class="callout info"><span class="co-ic">📲</span><div><p>The widgets <b>never open a connection themselves</b>: the app pushes an already-computed,
already-localised snapshot to native code — the weather API key stays on the app side.</p></div></div>
'''),
    ('hf', T('短波传播面板', '短波傳播面板', 'HF propagation panel'), '''
<ul>
<li><b>数据来源</b>：<code>hamqsl.com</code>（N0NBH 整理，业余界事实标准）；源站约每小时更新，应用缓存 <b>30 分钟</b>。</li>
<li><b>看什么</b>：SFI / Kp / A 指数、黑子、X 射线、太阳风；四个波段对的<b>日 / 夜</b>条件一目了然，另有 6m 预测。</li>
<li><b>怎么看</b>：绿色好、黄色凑合、红色差 —— 先挑「日」或「夜」里颜色最好的那一段。</li>
</ul>
<div class="callout warn"><span class="co-ic">诚实</span><div><p>hamqsl 的条件是<b>全球/区域平均</b>，不是你所在地的实测值 ——
出门前请结合本地时间、天线与噪声底再判断。</p></div></div>
''', '''
<ul>
<li><b>資料來源</b>：<code>hamqsl.com</code>（N0NBH 整理，業餘界事實標準）；來源約每小時更新，應用快取 <b>30 分鐘</b>。</li>
<li><b>看什麼</b>：SFI / Kp / A 指數、黑子、X 射線、太陽風；四個波段對的<b>日 / 夜</b>條件一目了然，另有 6m 預測。</li>
<li><b>怎麼看</b>：綠色好、黃色湊合、紅色差 —— 先挑「日」或「夜」裡顏色最好的那一段。</li>
</ul>
<div class="callout warn"><span class="co-ic">誠實</span><div><p>hamqsl 的條件是<b>全球/區域平均</b>，不是你所在地的實測值 ——
出門前請結合本地時間、天線與雜訊底再判斷。</p></div></div>
''', '''
<ul>
<li><b>Source</b>: <code>hamqsl.com</code> (compiled by N0NBH, the de-facto standard in amateur radio);
the endpoint updates hourly and the app caches it for <b>30 minutes</b>.</li>
<li><b>What you see</b>: SFI / Kp / A index, sunspots, X-rays, solar wind, day/night conditions for four
band pairs, plus a 6 m forecast.</li>
<li><b>How to read it</b>: green good, yellow marginal, red poor — start with the best-coloured half of the pair.</li>
</ul>
<div class="callout warn"><span class="co-ic">honest</span><div><p>hamqsl conditions are a <b>global/regional average</b>, not a measurement of your location —
weigh them against local time, antenna and noise floor.</p></div></div>
'''),
],

# ─────────────────────────── 平台差异 ───────────────────────────
'platform': [
    ('matrix', T('能力矩阵', '能力矩陣', 'Capability matrix'), '''
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>能力</th><th>Android</th><th>Windows</th></tr></thead><tbody>
<tr><td>APRS-IS 收发</td><td>✓</td><td>✓</td></tr>
<tr><td>后台持续定位（前台服务）</td><td>✓</td><td>—（桌面无前台服务概念）</td></tr>
<tr><td>蓝牙 TNC</td><td>✓（需蓝牙权限）</td><td>—（用 USB 串口 COM 口）</td></tr>
<tr><td>USB 串口（OTG）</td><td>✓</td><td>✓（COM 口独占，别被别的软件占着）</td></tr>
<tr><td>音频 AFSK</td><td>✓（需录音权限；发射时拉满音量并暂停麦克风）</td><td>✓</td></tr>
<tr><td>离线地图下载</td><td>✓</td><td>✓</td></tr>
<tr><td>桌面小组件</td><td>✓（3 套）</td><td>—（Android 独有）</td></tr>
<tr><td>WAV 文件模式</td><td colspan="2">所有平台可用：离线解码录音，或把报文导出成音频</td></tr>
</tbody></table></div>
''', '''
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>能力</th><th>Android</th><th>Windows</th></tr></thead><tbody>
<tr><td>APRS-IS 收發</td><td>✓</td><td>✓</td></tr>
<tr><td>背景持續定位（前景服務）</td><td>✓</td><td>—（桌面無前景服務概念）</td></tr>
<tr><td>藍牙 TNC</td><td>✓（需藍牙權限）</td><td>—（用 USB 序列埠 COM 埠）</td></tr>
<tr><td>USB 序列埠（OTG）</td><td>✓</td><td>✓（COM 埠獨占，別被別的軟體佔著）</td></tr>
<tr><td>音訊 AFSK</td><td>✓（需錄音權限；發射時拉滿音量並暫停麥克風）</td><td>✓</td></tr>
<tr><td>離線地圖下載</td><td>✓</td><td>✓</td></tr>
<tr><td>桌面小組件</td><td>✓（3 套）</td><td>—（Android 獨有）</td></tr>
<tr><td>WAV 檔案模式</td><td colspan="2">所有平台可用：離線解碼錄音，或把封包匯出成音訊</td></tr>
</tbody></table></div>
''', '''
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>Capability</th><th>Android</th><th>Windows</th></tr></thead><tbody>
<tr><td>APRS-IS send/receive</td><td>✓</td><td>✓</td></tr>
<tr><td>Continuous background positioning (foreground service)</td><td>✓</td><td>— (no such concept on desktop)</td></tr>
<tr><td>Bluetooth TNC</td><td>✓ (Bluetooth permission)</td><td>— (use a USB serial COM port)</td></tr>
<tr><td>USB serial (OTG)</td><td>✓</td><td>✓ (COM ports are exclusive — keep other software off them)</td></tr>
<tr><td>Audio AFSK</td><td>✓ (mic permission; TX maxes volume and mutes the mic)</td><td>✓</td></tr>
<tr><td>Offline map download</td><td>✓</td><td>✓</td></tr>
<tr><td>Home-screen widgets</td><td>✓ (three of them)</td><td>— (Android only)</td></tr>
<tr><td>WAV file mode</td><td colspan="2">available everywhere: decode a recording offline, or export packets as audio</td></tr>
</tbody></table></div>
'''),
    ('web', T('Web 版的取舍', 'Web 版的取捨', 'Web build trade-offs'), '''
<div class="callout warn"><span class="co-ic">⚠️</span><div><p>Web 版是「能看、能连」的轻量形态：</p>
<ul style="margin-top:6px">
<li><b>不提供离线地图下载</b>（浏览器没有稳定可写目录）；</li>
<li>备份走<b>剪贴板</b>（复制 / 粘贴），不落文件；</li>
<li>实时音频在不支持的平台会提示，仍可用 <b>WAV 模式</b>（上传录音离线解码）；</li>
<li>无桌面小组件、无后台持续定位。</li>
</ul></div></div>
''', '''
<div class="callout warn"><span class="co-ic">⚠️</span><div><p>Web 版是「能看、能連」的輕量形態：</p>
<ul style="margin-top:6px">
<li><b>不提供離線地圖下載</b>（瀏覽器沒有穩定可寫目錄）；</li>
<li>備份走<b>剪貼簿</b>（複製 / 貼上），不落檔案；</li>
<li>即時音訊在不支援的平台會提示，仍可用 <b>WAV 模式</b>（上傳錄音離線解碼）；</li>
<li>無桌面小組件、無背景持續定位。</li>
</ul></div></div>
''', '''
<div class="callout warn"><span class="co-ic">⚠️</span><div><p>The web build is the lightweight “view and connect” shape:</p>
<ul style="margin-top:6px">
<li><b>no offline map download</b> (browsers have no stable writable directory);</li>
<li>backup runs through the <b>clipboard</b> (copy / paste), no files;</li>
<li>realtime audio warns where unsupported while <b>WAV mode</b> still works (upload a recording, decode offline);</li>
<li>no home-screen widgets, no continuous background positioning.</li>
</ul></div></div>
'''),
],

# ─────────────────────────── 故障排查 ───────────────────────────
'troubleshooting': [
    ('entries', T('先用这三个入口', '先用這三個入口', 'Start with these three'), '''
<ol class="m-steps">
<li><b>链路状态卡</b>（主页顶部）——连接是否成立、收发计数、服务器返回值。
返回 <code>unverified</code> = <b>Passcode</b> 问题（<a href="start.html#passcode">去填</a>）。</li>
<li><b>链路自检</b>（设备页）—— TNC 协议回路、AFSK 调制解调回路，一键分层定位；
TNC 另有初始化串与发射自检（状态包，不含坐标）。</li>
<li><b>数据包页</b>—— 原始报文到底有没有进来。<b>能收到但不上图 = 筛选/坐标问题</b>，
<a href="stations.html">回台站与筛选</a>；一条都没有 = 链路问题，回第 1、2 步。</li>
</ol>
''', '''
<ol class="m-steps">
<li><b>鏈路狀態卡</b>（首頁頂部）——連線是否成立、收發計數、伺服器回傳值。
回傳 <code>unverified</code> = <b>Passcode</b> 問題（<a href="start.html#passcode">去填</a>）。</li>
<li><b>鏈路自檢</b>（裝置頁）—— TNC 協定回路、AFSK 調變解調回路，一鍵分層定位；
TNC 另有初始化字串與發射自檢（狀態封包，不含座標）。</li>
<li><b>封包頁</b>—— 原始封包到底有沒有進來。<b>能收到但不上圖 = 篩選/座標問題</b>，
<a href="stations.html">回臺站與篩選</a>；一條都沒有 = 鏈路問題，回第 1、2 步。</li>
</ol>
''', '''
<ol class="m-steps">
<li><b>Link status card</b> (top of the home page) — is the link up, what are the counters, what did
the server return? <code>unverified</code> = <b>Passcode</b> problem
(<a href="start.html#passcode">fix it here</a>).</li>
<li><b>Link self-test</b> (device page) — TNC protocol loopback and the AFSK modulate/demodulate loop,
layer by layer; the TNC side adds the init string and a TX self-test (status frame, no coordinates).</li>
<li><b>Packets tab</b> — did raw frames arrive at all? <b>Received but never plotted = filter/coordinate</b>,
go back to <a href="stations.html">Stations</a>; nothing at all = link problem, back to steps 1–2.</li>
</ol>
'''),
    ('matrix', T('症状 → 原因 → 动作', '症狀 → 原因 → 动作', 'Symptom → cause → action'), '''
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>症状</th><th>最可能的原因</th><th>动作</th></tr></thead><tbody>
<tr><td>黄色「未验证」横幅</td><td>Passcode 空 / 错</td><td>设置 → 连接 → 填正确 Passcode → 保存并应用</td></tr>
<tr><td>连不上服务器</td><td>网络 / 服务器地址 / 端口</td><td>核对 <code>rotate.aprs2.net:14580</code>；断线会自动 8→16→32→60s 重连，等一轮</td></tr>
<tr><td>数据包页一条都没有</td><td>没勾数据来源 / 范围过滤太窄</td><td>设置 → 连接：勾 APRS-IS；范围半径调大 → 保存并应用</td></tr>
<tr><td>收到但地图上看不到</td><td>列表筛选挡住了</td><td>台站页点「清除筛选」；核对状态/类型筛选</td></tr>
<tr><td>自己位置不显示/乱跳</td><td>没定位权限 / 用了网络粗定位</td><td>给定位权限；设置 → 定位上报 → 定位模式选纯 GPS</td></tr>
<tr><td>TNC 能收不能发</td><td>停在命令模式 / 线速不匹配</td><td>发送初始化串（<code>KISS ON</code>）；核对 9600~115200 与电台一致</td></tr>
<tr><td>音频对方解不出</td><td>发射电平过低或削顶 / 用错线</td><td>调整发射电平；耳机口 → 电台数据/话筒口，勿用扬声器对麦克风</td></tr>
<tr><td>消息发出去没反应</td><td>超 67 字符 / 512 字节；对方不在线</td><td>缩短内容；看气泡状态，超时即失败</td></tr>
<tr><td>群聊收不到</td><td>射频模式不支持群广播；Passcode 未验证</td><td>切到 APRS-IS 发；先修 Passcode</td></tr>
<tr><td>网关计数不涨</td><td>缺一个来源（APRS-IS 或射频）/ 射频收到=0</td><td>按界面提示补齐来源；射频收到=0 先查电台音量/静噪/天线</td></tr>
<tr><td>桌面组件空白</td><td>组件没有数据（应用没打开过）</td><td>打开一次应用刷新</td></tr>
<tr><td>离线地图断网打不开</td><td>没下载该屏 / 未开仅离线</td><td>移到目标屏下载；开「仅使用离线瓦片」</td></tr>
</tbody></table></div>
''', '''
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>症狀</th><th>最可能的原因</th><th>動作</th></tr></thead><tbody>
<tr><td>黃色「未驗證」橫幅</td><td>Passcode 空 / 錯</td><td>設定 → 連線 → 填正確 Passcode → 儲存並套用</td></tr>
<tr><td>連不上伺服器</td><td>網路 / 伺服器位址 / 埠</td><td>核對 <code>rotate.aprs2.net:14580</code>；斷線會自動 8→16→32→60s 重連，等一輪</td></tr>
<tr><td>封包頁一條都沒有</td><td>沒勾資料來源 / 範圍過濾太窄</td><td>設定 → 連線：勾 APRS-IS；範圍半徑調大 → 儲存並套用</td></tr>
<tr><td>收到但地圖上看不見</td><td>列表篩選擋住了</td><td>臺站頁點「清除篩選」；核對狀態/類型篩選</td></tr>
<tr><td>自己位置不顯示/亂跳</td><td>沒定位權限 / 用了網路粗定位</td><td>給定位權限；設定 → 定位上報 → 定位模式選純 GPS</td></tr>
<tr><td>TNC 能收不能發</td><td>停在命令模式 / 線速不匹配</td><td>送出初始化字串（<code>KISS ON</code>）；核對 9600~115200 與電臺一致</td></tr>
<tr><td>音訊對方解不出</td><td>發射電平過低或削波 / 用錯線</td><td>調整發射電平；耳機孔 → 電臺資料/麥克風孔，勿用喇叭對麥克風</td></tr>
<tr><td>訊息發出去沒反應</td><td>超 67 字元 / 512 位元組；對方不在线</td><td>縮短內容；看氣泡狀態，逾時即失敗</td></tr>
<tr><td>群組收不到</td><td>射頻模式不支援群廣播；Passcode 未驗證</td><td>切到 APRS-IS 發；先修 Passcode</td></tr>
<tr><td>閘道計數不漲</td><td>缺一個來源（APRS-IS 或射頻）/ 射頻收到=0</td><td>按介面提示補齊來源；射頻收到=0 先查電臺音量/靜噪/天線</td></tr>
<tr><td>桌面小組件空白</td><td>小組件沒有資料（應用沒打開過）</td><td>打開一次應用刷新</td></tr>
<tr><td>離線地圖斷網打不開</td><td>沒下載該螢 / 未開僅離線</td><td>移到目標螢下載；開「僅使用離線圖磚」</td></tr>
</tbody></table></div>
''', '''
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>Symptom</th><th>Likely cause</th><th>Action</th></tr></thead><tbody>
<tr><td>Yellow “unverified” banner</td><td>Passcode empty or wrong</td><td>Settings → Connection → correct it → Save &amp; apply</td></tr>
<tr><td>Cannot reach the server</td><td>network / address / port</td><td>check <code>rotate.aprs2.net:14580</code>; reconnects run 8→16→32→60 s — wait one cycle</td></tr>
<tr><td>Packets tab is empty</td><td>no source ticked / range too narrow</td><td>Settings → Connection: tick APRS-IS, raise the radius → Save &amp; apply</td></tr>
<tr><td>Received but not on the map</td><td>list filter hiding it</td><td>Stations → clear filters; re-check status/type</td></tr>
<tr><td>My position missing or jumping</td><td>no location permission / network fixes</td><td>grant permission; Settings → Beacon → GPS only</td></tr>
<tr><td>TNC receives, never transmits</td><td>command mode / baud mismatch</td><td>send the init string (<code>KISS ON</code>); match 9600–115200 to the radio</td></tr>
<tr><td>Audio nobody decodes</td><td>level too low or clipped / wrong cable</td><td>adjust TX level; headphone jack → radio data/mic, never speaker-to-mic</td></tr>
<tr><td>Message sent, no reply</td><td>over 67 chars / 512 bytes; peer offline</td><td>shorten it; watch the bubble — a timeout means failure</td></tr>
<tr><td>Group messages never arrive</td><td>RF mode has no group broadcast; Passcode unverified</td><td>send over APRS-IS; fix the Passcode first</td></tr>
<tr><td>Gateway counters stay at zero</td><td>a source is missing / RF seen = 0</td><td>tick the missing source; RF seen = 0 → radio volume, squelch, antenna</td></tr>
<tr><td>Widget is blank</td><td>no data pushed yet</td><td>open the app once to refresh</td></tr>
<tr><td>Offline map won’t open offline</td><td>that screen was never downloaded</td><td>pan there and download; enable “offline tiles only”</td></tr>
</tbody></table></div>
'''),
    ('report', T('还是解决不了？', '還是解決不了？', 'Still stuck?'), '''
<ul>
<li><b>常见问题</b>：23 题按主题分组 → <a href="../faq.html">帮助中心</a></li>
<li><b>更新记录</b>：你遇到的可能已在新版本修掉 →
<a href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">GitHub Releases</a></li>
<li><b>反馈</b>：提 Issue 或进 QQ 交流群。附上<b>数据包页的原始报文</b>与<b>链路日志</b>定位最快 →
<a href="https://github.com/dariondong/APRSLocus/issues" target="_blank" rel="noopener">Issues</a></li>
</ul>
<div class="callout tip"><span class="co-ic">📎</span><div><p>报告模板（照抄即可）：① 平台与版本；② 链路状态卡截图；③ 数据包页里
一条完整报文（含报头）；④ 已勾选的数据来源与过滤半径。</p></div></div>
''', '''
<ul>
<li><b>常見問題</b>：23 題按主題分組 → <a href="../faq.html">幫助中心</a></li>
<li><b>更新記錄</b>：你遇到的可能已在新版本修掉 →
<a href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">GitHub Releases</a></li>
<li><b>回饋</b>：提 Issue 或進 QQ 交流群。附上<b>封包頁的原始封包</b>與<b>鏈路日誌</b>定位最快 →
<a href="https://github.com/dariondong/APRSLocus/issues" target="_blank" rel="noopener">Issues</a></li>
</ul>
<div class="callout tip"><span class="co-ic">📎</span><div><p>報告模板（照抄即可）：① 平台與版本；② 鏈路狀態卡截圖；③ 封包頁裡
一則完整封包（含封包頭）；④ 已勾選的資料來源與過濾半徑。</p></div></div>
''', '''
<ul>
<li><b>FAQ</b>: 23 questions grouped by topic → <a href="../faq.html">Help Center</a></li>
<li><b>Release notes</b>: what bit you may already be fixed →
<a href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">GitHub Releases</a></li>
<li><b>Feedback</b>: open an issue or join the QQ group. Fastest diagnosis needs the <b>raw packet</b>
from the Packets tab plus the <b>link log</b> → <a href="https://github.com/dariondong/APRSLocus/issues" target="_blank" rel="noopener">Issues</a></li>
</ul>
<div class="callout tip"><span class="co-ic">📎</span><div><p>Report template: ① platform and version; ② screenshot of the link status card;
③ one complete frame (header included) from the Packets tab; ④ ticked data sources and the filter radius.</p></div></div>
'''),
],
}
