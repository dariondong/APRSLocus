#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成三语「帮助中心」页面 docs/{,zh-TW/,en/}faq.html。

为什么用脚本生成而不是手写三份：
    题目、分组、页面骨架必须**逐题对齐**（结构、题数、顺序），
    手写三份必然走样 —— 这与 tool/sync_site_content.py 是同一个教训。
    ⚠️ 文案本身仍是**三语分别手写**的，不做机器转换（繁体手写，见 sync_site_content.py 的注释）。

跑法：
    python3 tool/gen_faq_pages.py

页面特点：
    * 复用 css/style.css 与 js/main.js（与首页同视觉、同深色模式）
    * 无 JS 也可用：题目是原生 <details>，noscript 兜底 .reveal 直接显示
    * 内置客户端搜索框（过滤 summary/正文）
    * 每页带 FAQPage JSON-LD 与 canonical / hreflang（SEO）
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SITE = 'https://aprslocus.theez.top'

# 语言 → (输出相对路径, <html lang>, 页面相对前缀, canonical 后缀)
PAGES = {
    'zh':    ('docs/faq.html',        'zh-CN', '',      'faq.html'),
    'zh_TW': ('docs/zh-TW/faq.html',  'zh-TW', '../',   'zh-TW/faq.html'),
    'en':    ('docs/en/faq.html',     'en',    '../',   'en/faq.html'),
}
LANGS = ('zh', 'zh_TW', 'en')

# 语言 → (标题, 描述, H1, 搜索框 placeholder, 页脚链接文案, 页脚首页文案)
HEAD = {
    'zh': dict(
        title='帮助中心 — APRSlocus 常见问题与使用指南',
        desc='APRSlocus 帮助中心：连接与 Passcode、四种数据来源与网关 iGate、定位与信标、'
             '界面与离线地图、桌面小组件与短波传播、备份恢复与安装更新，共 23 个常见问题。',
        h1='帮助中心',
        h1sub='从 Passcode 到桌面小组件，按主题分组的完整问答。答案随版本更新，'
              '当前对应 v1.6.150。',
        ph='搜索问题，比如「Passcode」「离线地图」「小组件」…',
        foot_home='首页', foot_help='帮助',
        open_all='全部展开', close_all='全部收起', no_hit='没有匹配的问题，换个关键词试试。',
    ),
    'zh_TW': dict(
        title='幫助中心 — APRSlocus 常見問題與使用指南',
        desc='APRSLocus 幫助中心：連線與 Passcode、四種資料來源與閘道 iGate、定位與信標、'
             '介面與離線地圖、桌面小組件與短波傳播、備份還原與安裝更新，共 23 個常見問題。',
        h1='幫助中心',
        h1sub='從 Passcode 到桌面小組件，按主題分組的完整問答。答案隨版本更新，'
              '目前對應 v1.6.150。',
        ph='搜尋問題，例如「Passcode」「離線地圖」「小組件」…',
        foot_home='首頁', foot_help='幫助',
        open_all='全部展開', close_all='全部收起', no_hit='沒有符合的問題，換個關鍵詞試試。',
    ),
    'en': dict(
        title='Help Center — APRSlocus FAQ & Guides',
        desc='APRSlocus help center: connection and Passcode, the four data sources and the '
             'iGate, positioning and beacon, display and offline maps, home-screen widgets '
             'and HF propagation, backup and updates — 23 frequently asked questions.',
        h1='Help Center',
        h1sub='From Passcode to home-screen widgets, grouped by topic. Answers track the '
              'releases; this page matches v1.6.150.',
        ph='Search, e.g. “Passcode”, “offline map”, “widget”…',
        foot_home='Home', foot_help='Help',
        open_all='Expand all', close_all='Collapse all', no_hit='No matching question — try another keyword.',
    ),
}

UI = {
    'zh': dict(nav_home='首页', nav_feat='功能', nav_dl='下载',
               css_search='搜索问题', g_title='分组导航', burger='菜单',
               theme='切换深色模式', theme_off='切换浅色模式'),
    'zh_TW': dict(nav_home='首頁', nav_feat='功能', nav_dl='下載',
                   css_search='搜尋問題', g_title='分組導覽', burger='菜單',
                   theme='切換深色模式', theme_off='切換淺色模式'),
    'en': dict(nav_home='Home', nav_feat='Features', nav_dl='Download',
               css_search='Search questions', g_title='Jump to a group', burger='Menu',
               theme='Switch to dark mode', theme_off='Switch to light mode'),
}

# ─────────────────────────── 问答内容（三语手写） ───────────────────────────
# 每题：(zh, zh_TW, en) 的 q 与 a。顺序即展示顺序。
GROUPS = [
    ('连接与消息', '連線與訊息', 'Connection & Messaging', [
        (
            '为什么收不到消息 / 无法收发消息？',
            '為什麼收不到訊息 / 無法收發訊息？',
            'Cannot send or receive messages?',
            '绝大多数情况是 Passcode 未验证。密码填 <code>-1</code> 只能连接，不能正常收发消息。'
            '请到 <a href="https://aprs.cool/AprsPG" target="_blank" rel="noopener">APRS Passcode 查询</a> '
            '生成自己的 Passcode 并填入「连接设置」；若服务器返回 <code>unverified</code>，'
            '主页顶部会出现黄色警告横幅，点「去设置」即可直达。',
            '絕大多數情況是 Passcode 未驗證。密碼填 <code>-1</code> 只能連接，不能正常收發訊息。'
            '請到 <a href="https://aprs.cool/AprsPG" target="_blank" rel="noopener">APRS Passcode 查詢</a> '
            '生成自己的 Passcode 並填入「連線設定」；若伺服器回傳 <code>unverified</code>，'
            '首頁頂部會出現黃色警告橫幅，點「去設定」即可直達。',
            'Most likely an unverified Passcode. Entering <code>-1</code> only lets you connect — '
            'messaging needs your own Passcode from the '
            '<a href="https://aprs.cool/AprsPG" target="_blank" rel="noopener">APRS Passcode generator</a>, '
            'entered in Connection Settings. If the server returns <code>unverified</code>, a yellow '
            'banner appears at the top of the home page — tap “Go to settings”.',
        ),
        (
            'Passcode 该怎么设置？',
            'Passcode 該怎麼設定？',
            'How do I set up a Passcode?',
            '在引导第 6 步或「设置 → 连接」中，用你的<b>完整呼号（含 SSID 后缀，如 BG7LZQ-3）</b>'
            '查询生成 Passcode 后填入即可。',
            '在引導第 6 步或「設定 → 連線」中，用你的<b>完整呼號（含 SSID 後綴，如 BG7LZQ-3）</b>'
            '查詢生成 Passcode 後填入即可。',
            'In step 6 of the wizard or under Settings → Connection, generate one from your '
            '<b>full callsign (including the SSID suffix, e.g. BG7LZQ-3)</b> and paste it in.',
        ),
        (
            '连接失败 / 频繁掉线？',
            '連線失敗 / 頻繁斷線？',
            'Connection fails or keeps dropping?',
            '应用内置渐进式重连（8 → 16 → 32 → 60 秒）。若持续失败，请检查网络、'
            '确认服务器地址（默认 <code>rotate.aprs2.net:14580</code>）与端口是否被拦截，'
            '或在「连接设置」中更换服务器后点「重新连接」。',
            '應用內建漸進式重連（8 → 16 → 32 → 60 秒）。若持續失敗，請檢查網路、'
            '確認伺服器位址（預設 <code>rotate.aprs2.net:14580</code>）與埠是否被封鎖，'
            '或在「連線設定」中更換伺服器後點「重新連線」。',
            'The app reconnects with progressive backoff (8 → 16 → 32 → 60 s). If it keeps '
            'failing, check your network, confirm the server (default '
            '<code>rotate.aprs2.net:14580</code>) and port are not blocked, or switch servers '
            'in Connection Settings and tap Reconnect.',
        ),
        (
            '支持哪些数据来源？我该怎么选？',
            '支援哪些資料來源？該怎麼選？',
            'Which data sources are supported?',
            '四条：互联网 APRS-IS、蓝牙 / 串口 TNC（KISS）、声卡音频 AFSK 1200，'
            '以及 Kenwood 电台的 <code>$PKWDWPL</code>（只收不发）。刚上手选 APRS-IS 即可；'
            '有电台想听射频，再加 TNC 或音频。几条链路可同时收报文，发射来源单独指定一条。',
            '四條：網際網路 APRS-IS、藍牙 / 串列埠 TNC（KISS）、音效卡音訊 AFSK 1200，'
            '以及 Kenwood 電台的 <code>$PKWDWPL</code>（只收不發）。剛上手選 APRS-IS 即可；'
            '有電台想聽射頻，再加 TNC 或音訊。數條鏈路可同時收報文，發射來源單獨指定一條。',
            'Four: internet (APRS-IS), Bluetooth / serial TNC over KISS, sound-card AFSK 1200, '
            'and Kenwood’s <code>$PKWDWPL</code> (receive-only). Start with APRS-IS; add TNC or '
            'audio once you have a radio. Several links can receive at once — the transmit '
            'source is picked separately.',
        ),
        (
            '网关（iGate）是什么？需要开吗？',
            '閘道（iGate）是什麼？需要開嗎？',
            'What is the gateway (iGate)? Do I need it?',
            'iGate 把你在射频上听到的报文转到 APRS-IS，让全球网络看到你附近的台站。'
            '只有「在听射频、且愿意贡献」时才需要。带环路防护（含 <code>TCPIP*</code> 或已有 '
            'q 构造的报文绝不回送）与 30 秒去重，默认关闭。',
            'iGate 把你在射頻上聽到的報文轉到 APRS-IS，讓全球網路看到你附近的臺站。'
            '只有「在聽射頻、且願意貢獻」時才需要。具備環路防護（含 <code>TCPIP*</code> 或已有 '
            'q 構造的報文絕不回送）與 30 秒去重，預設關閉。',
            'The iGate relays what you hear on RF into APRS-IS, so the global network sees the '
            'stations around you. You only need it if you are listening on RF and want to '
            'contribute. Loop protection (packets carrying <code>TCPIP*</code> or an existing '
            'q-construct are never echoed back) and 30-second de-duplication are built in; off '
            'by default.',
        ),
        (
            '蓝牙 TNC 连上了，但收不到 / 发不出？',
            '藍牙 TNC 連上了，但收不到 / 發不出？',
            'Bluetooth TNC connects but receives or transmits nothing?',
            '先升级到最新版：v1.6.110 修了「TNC 与 PKWDWPL 绑定同一台设备、互相瓜分接收数据」，'
            'v1.6.112 找到「能发不能收」的真正原因。升级后仍异常，用「链路自检」分层排查，'
            '并确认 Android 已授予蓝牙与定位权限。',
            '先升級到最新版：v1.6.110 修了「TNC 與 PKWDWPL 綁定同一臺設備、互相瓜分接收資料」，'
            'v1.6.112 找到「能發不能收」的真正原因。升級後仍異常，用「鏈路自檢」分層排查，'
            '並確認 Android 已授予藍牙與定位權限。',
            'Update first: v1.6.110 fixed “TNC and PKWDWPL bound to the same device split the '
            'received data”, and v1.6.112 found the real cause of “transmits but receives '
            'nothing”. If it persists, use the link self-test for layered diagnosis and make '
            'sure Bluetooth and location permissions are granted on Android.',
        ),
        (
            '声卡音频（AFSK）怎么接？对方解不出怎么办？',
            '音效卡音訊（AFSK）怎麼接？對方解不出怎麼辦？',
            'How do I wire sound-card AFSK? Others cannot decode me.',
            '耳机 / 麦克风口接电台的 SPK / MIC，设置好 PTT。发射时应用会把媒体音量拉满并'
            '暂停麦克风，链路自检里能看到电平；对方解不出，先查电平与接线。',
            '耳機 / 麥克風埠接電台的 SPK / MIC，設定好 PTT。發射時應用會把媒體音量拉滿並'
            '暫停麥克風，鏈路自檢裡能看到電平；對方解不出，先查電平與接線。',
            'Wire the headphone / mic jack to the radio’s SPK / MIC and set up PTT. During '
            'transmission the app maxes media volume and mutes the mic; the link self-test '
            'shows the audio level. If others cannot decode you, check level and wiring first.',
        ),
    ]),
    ('定位与信标', '定位與信標', 'Positioning & Beacon', [
        (
            '手机上收不到周边台站？',
            '手機上收不到周邊臺站？',
            'Cannot see nearby stations on mobile?',
            '检查「接收筛选」是否勾选了目标国家 / 地区，并确认接收范围（经纬度 + 半径）'
            '覆盖你的位置。默认只接收中国（B 开头）台站。',
            '檢查「接收篩選」是否勾選了目標國家 / 地區，並確認接收範圍（經緯度 + 半徑）'
            '覆蓋你的位置。預設只接收中國（B 開頭）臺站。',
            'Check if your target country/region is selected in the Receive Filter, and verify '
            'that the receive range (lat/lon + radius) covers your location. By default only '
            'Chinese (B-prefix) stations are received.',
        ),
        (
            '后台定位会一直耗电吗？',
            '背景定位會一直耗電嗎？',
            'Does background positioning drain the battery?',
            'Android 端使用前台服务持续定位以保持 APRS 在线，可在「定位 / 信标」设置中'
            '调整上报间隔，或关闭信标上报、按需手动上报来降低耗电。通知栏可一键「退出」应用。',
            'Android 端使用前景服務持續定位以保持 APRS 在線，可在「定位 / 信標」設定中'
            '調整上報間隔，或關閉信標上報、按需手動上報來降低耗電。通知欄可一鍵「結束」應用。',
            'Android uses a foreground service for continuous positioning. Adjust the report '
            'interval in Location / Beacon settings, or switch to manual reporting to reduce '
            'power usage. The notification bar has a one-tap Exit.',
        ),
        (
            '站着不动时我的标记乱跳 / 轨迹有毛刺？',
            '站著不動時我的標記亂跳 / 軌跡有毛刺？',
            'My marker jitters while I stand still?',
            'v1.6.146 给自身定位加了「静止防抖」；v1.6.149 再用加速度计判断「有没有在动」、'
            '低速时用指南针补航向（Android，默认开启，可在「设置 → 信标 → 定位」关）。'
            '升级到最新版即可。',
            'v1.6.146 給自身定位加了「靜止防抖」；v1.6.149 再用加速度計判斷「有沒有在動」、'
            '低速時用指南針補航向（Android，預設開啟，可在「設定 → 信標 → 定位」關）。'
            '升級到最新版即可。',
            'v1.6.146 added stationary debounce for your own fix; v1.6.149 goes further — the '
            'accelerometer decides whether you are moving and the compass fills in heading at '
            'low speed (Android, on by default, switchable in Settings → Beacon → Location). '
            'Updating fixes it.',
        ),
        (
            '历史轨迹在哪看？和地图上那条有什么区别？',
            '歷史軌跡在哪看？和地圖上那條有什麼區別？',
            'Where is my track history, and how is it different?',
            '「设置 → 历史轨迹」按天保存在本地，可看总里程、平均与最高速度、移动时长，'
            '退出重进还在；点某一天还能在地图上<b>回放当天路线</b>（可拖进度、0.5×~4× 倍速）。'
            '它与地图上那条「我的轨迹」<b>刻意分开</b>：那条只服务本次显示，'
            '退出即失、确认位置跳变时整条清空。',
            '「設定 → 歷史軌跡」按天保存在本機，可看總里程、平均與最高速度、移動時長，'
            '退出重進還在；點某一天還能在地圖上<b>回放當日路線</b>（可拖進度、0.5×~4× 倍速）。'
            '它與地圖上那條「我的軌跡」<b>刻意分開</b>：那條只服務本次顯示，'
            '退出即失、確認位置跳變時整條清空。',
            'Settings → Track history keeps days on disk, with total distance, average and top '
            'speed and moving time — it survives a restart, and tapping a day replays that '
            'day’s route on the map (draggable, 0.5×–4× speed). It is <b>deliberately '
            'separate</b> from the on-screen “my track”, which serves this session only (gone '
            'on exit, cleared on a confirmed jump).',
        ),
    ]),
    ('界面与地图', '介面與地圖', 'Display & Maps', [
        (
            'Windows 上地图显示异常？',
            'Windows 上地圖顯示異常？',
            'Map display issues on Windows?',
            '建议在「显示 → 地图类型」中切换为<b>矢量地图</b>（无需 API Key，兼容性最好），'
            '或使用 Carto / OSM / Esri 等国际图源。',
            '建議在「顯示 → 地圖類型」中切換為<b>向量地圖</b>（無需 API Key，相容性最好），'
            '或使用 Carto / OSM / Esri 等國際圖源。',
            'For best compatibility on Windows, switch to <b>Vector Map</b> (no API key needed) '
            'or use Carto / OSM / Esri layers in Display → Map Type.',
        ),
        (
            '怎么换界面风格 / 切回旧布局？',
            '怎麼換介面風格 / 切回舊佈局？',
            'How do I switch the UI style?',
            '「设置 → 显示」里可切 UI 2.0（以地图为基底）与经典布局，还能选磨砂玻璃 / 云母材质'
            '（v1.6.138）。主题支持颜色、图标、文字与背景图（17 个颜色令牌），可导出 JSON 分享。',
            '「設定 → 顯示」裡可切 UI 2.0（以地圖為基底）與經典佈局，還能選磨砂玻璃 / 雲母材質'
            '（v1.6.138）。主題支援顏色、圖示、文字與背景圖（17 個顏色權杖），可匯出 JSON 分享。',
            'Settings → Display switches between UI 2.0 (map-first) and the classic layout, and '
            'picks frosted glass or mica (v1.6.138). Themes cover colour, icons, text and '
            'background image (17 colour tokens) and export as JSON to share.',
        ),
        (
            '台站为什么不再合并成一颗球？',
            '臺站為什麼不再合併成一顆球？',
            'Why are stations no longer clustered?',
            'v1.6.149 起去掉聚合：矢量地图与自绘地图都是一台站一个标记。低缩放时的密度交给'
            '热力图，工具列里有开关。',
            'v1.6.149 起去掉聚合：向量地圖與自繪地圖都是一臺站一個標記。低縮放時的密度交給'
            '熱力圖，工具列裡有開關。',
            'Clustering was removed in v1.6.149: both the vector and self-drawn maps show one '
            'marker per station. Density at low zoom belongs to the heatmap — its toggle is in '
            'the toolbar.',
        ),
        (
            '离线地图怎么用？断网能看吗？',
            '離線地圖怎麼用？斷網能看嗎？',
            'How do offline maps work? Do they survive no network?',
            '「设置 → 显示 → 离线地图」把当前视图的瓦片一次下到本机（断点续传、'
            '单区域上限 20 万张），断网、无信号也能看，另有「仅离线模式」。Web 版不提供下载。',
            '「設定 → 顯示 → 離線地圖」把當前視圖的瓦片一次下載到本機（斷點續傳、'
            '單區域上限 20 萬張），斷網、無訊號也能看，另有「僅離線模式」。Web 版不提供下載。',
            'Settings → Display → Offline map downloads the tiles of the current view once '
            '(resumable, 200k tiles per region) so the map works with no network; there is also '
            'an Offline-only mode. The web build has no download.',
        ),
        (
            '支持哪些语言？翻译要密钥吗？',
            '支援哪些語言？翻譯要金鑰嗎？',
            'Which languages? Does translation need a key?',
            '界面六种语言：简体中文、繁體中文、English、日本語、Indonesia、Español。'
            '聊天翻译默认走免费接口、<b>无需任何密钥</b>，可双向、可对照，'
            '也能发送前先把输入译成对方的语言。',
            '介面六種語言：簡體中文、繁體中文、English、日本語、Indonesia、Español。'
            '聊天翻譯預設走免費介面、<b>無需任何金鑰</b>，可雙向、可對照，'
            '也能發送前先把輸入譯成對方的語言。',
            'Six UI languages: Simplified Chinese, Traditional Chinese, English, Japanese, '
            'Indonesian and Spanish. Chat translation works out of the box on a free endpoint — '
            '<b>no API key</b> — two-way, side-by-side, and pre-send.',
        ),
    ]),
    ('桌面小组件与短波', '桌面小組件與短波', 'Widgets & HF Propagation', [
        (
            '桌面小组件怎么添加？为什么是空的？',
            '桌面小組件怎麼添加？為什麼是空的？',
            'How do I add the widgets? Why are they empty?',
            '长按桌面 → 添加小部件 → APRSlocus，有天气、短波、系统状态三套。组件'
            '<b>不自己联网</b>，数据由应用单向推送 —— 装好后先打开一次应用；'
            '升级后若空白，打开应用刷新即可。',
            '長按桌面 → 新增小工具 → APRSlocus，有天氣、短波、系統狀態三套。小組件'
            '<b>不自己連線</b>，資料由應用單向推送 —— 裝好後先打開一次應用；'
            '升級後若空白，打開應用刷新即可。',
            'Long-press the home screen → Widgets → APRSlocus: weather, HF and system status. '
            'The widgets <b>never open a connection themselves</b> — the app pushes a snapshot. '
            'Open the app once after adding them; if they go blank after an update, open the '
            'app to refresh.',
        ),
        (
            '短波面板的数据准吗？多久更新？',
            '短波面板的資料準嗎？多久更新？',
            'How good is the HF data? How fresh is it?',
            '来自 hamqsl.com（N0NBH 整理，业余界事实标准），源站约每小时更新，'
            '应用缓存 30 分钟。注意它是<b>全球 / 区域平均</b>，不是你所在地的实测值。',
            '來自 hamqsl.com（N0NBH 整理，業餘界事實標準），來源約每小時更新，'
            '應用快取 30 分鐘。注意它是<b>全球 / 區域平均</b>，不是你所在地的實測值。',
            'It comes from hamqsl.com (compiled by N0NBH, the de-facto standard in amateur '
            'radio); the source updates hourly and the app caches for 30 minutes. Note it is a '
            '<b>global/regional average</b>, not a local measurement.',
        ),
        (
            '小组件能调大小吗？',
            '小組件能調大小嗎？',
            'Can I resize the widgets?',
            '天气组件四档自适应；v1.6.133 起短波与系统状态也能拖拽缩放，拉高会自动换「加高档」。',
            '天氣小組件四檔自適應；v1.6.133 起短波與系統狀態也能拖曳縮放，拉高會自動換「加高檔」。',
            'The weather widget has four adaptive sizes; since v1.6.133 the HF and '
            'system-status widgets resize too, switching to a taller tier when you drag them up.',
        ),
    ]),
    ('数据、备份与安装', '資料、備份與安裝', 'Data, Backup & Install', [
        (
            '换手机 / 重装怎么迁移？',
            '換手機 / 重裝怎麼遷移？',
            'How do I migrate to a new device?',
            '「设置 → 备份与恢复」把设置与数据导出成一个 JSON，新设备导入即可（v1.6.123）。'
            '导入后需重启应用生效。',
            '「設定 → 備份與還原」把設定與資料匯出成一個 JSON，新裝置匯入即可（v1.6.123）。'
            '匯入後需重啟應用生效。',
            'Settings → Backup & restore exports settings and data as a single JSON; import it '
            'on the new device (v1.6.123). Restart the app afterwards for everything to take '
            'effect.',
        ),
        (
            '怎么导出通联日志？',
            '怎麼匯出通聯日誌？',
            'How do I export my log?',
            '数据导出为 ADIF —— 业余无线电通用的日志交换格式，频率可自定义，'
            '导出后可直接导入其它日志软件。',
            '資料匯出為 ADIF —— 業餘無線電通用的日誌交換格式，頻率可自訂，'
            '匯出後可直接匯入其它日誌軟體。',
            'One-tap ADIF export — the standard amateur-radio log interchange format — with a '
            'configurable frequency, ready to import into other logging software.',
        ),
        (
            '覆盖安装提示签名冲突 / 版本降级？',
            '覆蓋安裝提示簽名衝突 / 版本降級？',
            'Signature conflict or version downgrade on install?',
            '自 1.5.2 起 Android 使用正式 release 签名，CI 与本地签名一致，直接覆盖安装即可。'
            '若从更老版本升级，请卸载后重装。',
            '自 1.5.2 起 Android 使用正式 release 簽章，CI 與本地簽章一致，直接覆蓋安裝即可。'
            '若從更老版本升級，請解除安裝後重裝。',
            'Since v1.5.2 Android builds use the official release signature (CI and local '
            'builds match) — install straight over the old version. Coming from a much older '
            'build, uninstall and reinstall first.',
        ),
        (
            '在哪里下载？怎么更新？',
            '在哪裡下載？怎麼更新？',
            'Where do I download? How do updates work?',
            'GitHub Releases 与 GitCode 双渠道；应用内「检查更新」按平台分流，'
            '也能安装历史版本。本站导航「下载」直达最新版。',
            'GitHub Releases 與 GitCode 雙管道；應用內「檢查更新」按平台分流，'
            '也能安裝歷史版本。本站導覽「下載」直達最新版。',
            'GitHub Releases and GitCode; in-app “Check for updates” picks the right build per '
            'platform and can install past versions. The Download button in the navigation goes '
            'straight to the latest release.',
        ),
    ]),
]


def esc(s):
    return s  # 文案是手写 HTML（含 <code>/<b>），不再转义


def render(lang, path):
    p = PAGES[lang][2]          # 相对前缀 '' 或 '../'
    h = HEAD[lang]
    u = UI[lang]

    # 分组导航 chips
    chips = '\n'.join(
        '        <a href="#g%d">%s</a>' % (i, esc(g[0] if lang == 'zh' else
                                                  g[1] if lang == 'zh_TW' else g[2]))
        for i, g in enumerate(GROUPS))

    blocks, ld_items = [], []
    for i, g in enumerate(GROUPS):
        title = g[0] if lang == 'zh' else g[1] if lang == 'zh_TW' else g[2]
        qs = []
        for j, item in enumerate(g[3]):
            # item = [zh题, 繁题, en题, zh答, 繁答, en答] → 题 0-2 / 答 3-5
            qi, ai = {'zh': (0, 3), 'zh_TW': (1, 4), 'en': (2, 5)}[lang]
            q, a = item[qi], item[ai]
            qs.append(
                '      <details class="faq reveal"%s>\n'
                '        <summary>%s<span class="chev"></span></summary>\n'
                '        <p>%s</p>\n'
                '      </details>' % (' open' if (i, j) == (0, 0) else '', q, a))
            ld_items.append({'@type': 'Question', 'name': _strip(q),
                             'acceptedAnswer': {'@type': 'Answer', 'text': _strip(a)}})
        blocks.append(
            '    <h3 class="faq-group" id="g%d">%s</h3>\n'
            '    <div class="faq-list">\n%s\n    </div>' % (i, title, '\n'.join(qs)))

    ld = {
        '@context': 'https://schema.org',
        '@type': 'FAQPage',
        'name': h['title'],
        'description': h['desc'],
        'url': '%s/%s' % (SITE, PAGES[lang][3]),
        'mainEntity': ld_items,
    }

    hreflangs = '\n'.join(
        '    <link rel="alternate" hreflang="%s" href="%s/%s">' % (fl, SITE, suf)
        for fl, suf in (('zh-CN', 'faq.html'), ('zh-TW', 'zh-TW/faq.html'),
                        ('en', 'en/faq.html'), ('x-default', 'faq.html')))

    html = f'''<!DOCTYPE html>
<html lang="{PAGES[lang][1]}">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{h['title']}</title>
<meta name="description" content="{h['desc']}">
<meta name="theme-color" content="#f3f6fd">
<meta property="og:type" content="website">
<meta property="og:site_name" content="APRSlocus">
<meta property="og:title" content="{h['title']}">
<meta property="og:description" content="{h['desc']}">
<meta property="og:url" content="{SITE}/{PAGES[lang][3]}">
<meta property="og:image" content="{SITE}/assets/logo.png">
<meta property="og:image:width" content="192">
<meta property="og:image:height" content="192">
<meta property="og:image:alt" content="APRSlocus logo">
<meta property="og:locale" content="{'zh_CN' if lang == 'zh' else 'zh_TW' if lang == 'zh_TW' else 'en_US'}">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="{h['title']}">
<meta name="twitter:description" content="{h['desc']}">
<meta name="twitter:image" content="{SITE}/assets/logo.png">
<link rel="canonical" href="{SITE}/{PAGES[lang][3]}">
{hreflangs}
<link rel="icon" type="image/png" href="{p}assets/favicon.png">
<link rel="stylesheet" href="{p}css/style.css?v=5">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.6.0/css/all.min.css">
<script>
/* 主题：localStorage 优先，否则跟随系统。必须在首帧前执行，
   否则深色偏好用户会先闪一下白屏（CSS 键在 <html data-theme> 上）。 */
(function () {{
  try {{
    var t = localStorage.getItem('theme');
    if (t !== 'dark' && t !== 'light')
      t = window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', t);
    var m = document.querySelector('meta[name="theme-color"]');
    if (m) m.setAttribute('content', t === 'dark' ? '#0b1220' : '#f3f6fd');
  }} catch (e) {{}}
}})();
</script>
<script type="application/ld+json">
{json.dumps(ld, ensure_ascii=False, indent=2)}
</script>
<noscript><style>.reveal{{opacity:1;transform:none}}.faq-tools{{display:none}}</style></noscript>
</head>
<body>

<div class="scroll-progress" id="scrollProgress"></div>

<div class="bg-blobs" aria-hidden="true">
  <span class="blob b1"></span>
  <span class="blob b2"></span>
  <span class="blob b3"></span>
  <span class="blob b4"></span>
</div>

<!-- ═══════════ 导航栏（子页：锚点回到首页） ═══════════ -->
<header class="nav" id="nav">
  <div class="nav-inner">
    <a class="brand" href="{p}">
      <img class="brand-logo" src="{p}assets/logo.png" alt="APRSlocus">
      <span class="brand-name">APRSlocus</span>
    </a>
    <nav class="nav-links" id="navLinks">
      <a href="{p}">{u['nav_home']}</a>
      <a href="{p}#features">{u['nav_feat']}</a>
      <a href="faq.html">{'帮助' if lang != 'en' else 'Help'}</a>
      <a href="manual/index.html">{'手册' if lang == 'zh' else '手冊' if lang == 'zh_TW' else 'Guide'}</a>
      <a class="nav-cta" href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">{u['nav_dl']}</a>
      <button class="theme-toggle" id="themeToggle" type="button" aria-pressed="false" aria-label="{u['theme']}" title="{u['theme']}" data-label-dark="{u['theme_off']}" data-label-light="{u['theme']}"><i class="fa-solid fa-moon" aria-hidden="true"></i></button>
      <span class="lang-switch-group"><a class="lang-switch{' active' if lang == 'zh' else ''}" href="../faq.html" hreflang="zh-Hans">简中</a><a class="lang-switch{' active' if lang == 'zh_TW' else ''}" href="../zh-TW/faq.html" hreflang="zh-Hant">繁中</a><a class="lang-switch{' active' if lang == 'en' else ''}" href="../en/faq.html" hreflang="en">EN</a></span>
    </nav>
    <button class="nav-burger" id="navBurger" aria-label="{u['burger']}">
      <span></span><span></span><span></span>
    </button>
  </div>
</header>

<main id="main">
<a class="skip-link" href="#main">{'跳到主要内容' if lang == 'zh' else '跳到主要內容' if lang == 'zh_TW' else 'Skip to main content'}</a>
<section class="section" id="help">
  <div class="section-head reveal">
    <h1>{h['h1']}</h1>
    <p>{h['h1sub']}</p>
  </div>

  <div class="faq-tools reveal">
    <div class="faq-search">
      <i class="fa-solid fa-magnifying-glass" aria-hidden="true"></i>
      <input type="search" id="faqFilter" placeholder="{h['ph']}" aria-label="{u['css_search']}" autocomplete="off">
    </div>
    <div class="faq-chips" aria-label="{u['g_title']}">
{chips}
    </div>
    <button class="faq-toggle" id="faqToggle" aria-expanded="false">{h['open_all']}</button>
    <p class="faq-nohit" id="faqNohit" hidden>{h['no_hit']}</p>
  </div>

{chr(10).join(blocks)}
</section>
</main>

<footer class="footer">
  <div class="footer-inner">
    <div class="footer-top">
      <div class="footer-brand">
        <img src="{p}assets/logo.png" alt="APRSlocus">
        <div>
          <b>APRSlocus</b>
          <span>APR Tracking &amp; Mapping</span>
        </div>
      </div>
      <div class="footer-links">
        <a href="{p}">{h['foot_home']}</a>
        <a href="{p}#features">{'功能' if lang != 'en' else 'Features'}</a>
        <a href="{p}#faq">{'问答' if lang == 'zh' else '問答' if lang == 'zh_TW' else 'FAQ'}</a>
        <a href="faq.html">{h['foot_help']}</a>
        <a href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">Releases</a>
      </div>
    </div>
    <div class="footer-bottom">
      <span>© <span id="year">2026</span> BG7LZQ (Darion) · <a href="https://github.com/dariondong/APRSLocus/blob/main/LICENSE" target="_blank" rel="noopener">GPL-3.0</a> · <a href="{p}terms.html">{'用户协议' if lang == 'zh' else '使用者協定' if lang == 'zh_TW' else 'Terms'}</a></span>
      <span class="disclaimer">{'本软件仅供业余无线电爱好者学习交流使用，请遵守当地无线电管理法规。' if lang == 'zh' else '本軟體僅供業餘無線電愛好者學習交流使用，請遵守當地電波法規。' if lang == 'zh_TW' else 'For amateur radio study and exchange only — comply with your local radio regulations.'}</span>
    </div>
  </div>
</footer>

<a class="backtop" id="backTop" href="#help" aria-label="{'回到顶部' if lang != 'en' else 'Back to top'}">
  <svg class="backtop-ring" viewBox="0 0 40 40">
    <circle class="ring-bg" cx="20" cy="20" r="17"/>
    <circle class="ring-fg" id="ringFg" cx="20" cy="20" r="17"/>
  </svg>
  <svg class="backtop-arrow" viewBox="0 0 24 24"><path d="M12 5l7 7-1.4 1.4L13 8.8V20h-2V8.8l-4.6 4.6L5 12l7-7z"/></svg>
</a>

<script src="{p}js/main.js"></script>
<script>
/* 帮助中心专属：客户端搜索 + 全部展开/收起（无 JS 时题目仍是原生 details，可正常使用） */
(function () {{
  "use strict";
  var input = document.getElementById('faqFilter');
  var nohit = document.getElementById('faqNohit');
  var toggle = document.getElementById('faqToggle');
  var groups = Array.prototype.slice.call(document.querySelectorAll('.faq-list'));
  var OPEN = {json.dumps(h['open_all'], ensure_ascii=False)};
  var CLOSE = {json.dumps(h['close_all'], ensure_ascii=False)};

  if (input) {{
    input.addEventListener('input', function () {{
      var kw = input.value.trim().toLowerCase();
      var hits = 0;
      groups.forEach(function (list) {{
        var groupHit = 0;
        Array.prototype.forEach.call(list.querySelectorAll('.faq'), function (d) {{
          var text = (d.textContent || '').toLowerCase();
          var ok = !kw || text.indexOf(kw) !== -1;
          d.hidden = !ok;
          if (ok) {{ groupHit++; hits++; }}
        }});
        var head = list.previousElementSibling;
        if (head && head.classList.contains('faq-group')) head.hidden = groupHit === 0;
        list.hidden = groupHit === 0;
      }});
      if (nohit) nohit.hidden = hits !== 0;
    }});
  }}

  if (toggle) {{
    toggle.addEventListener('click', function () {{
      var expand = toggle.getAttribute('aria-expanded') !== 'true';
      toggle.setAttribute('aria-expanded', String(expand));
      toggle.textContent = expand ? CLOSE : OPEN;
      Array.prototype.forEach.call(document.querySelectorAll('.faq'), function (d) {{
        if (!d.hidden) d.open = expand;
      }});
    }});
  }}
}})();
</script>
</body>
</html>
'''
    out = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    io.open(out, 'w', encoding='utf-8', newline='\n').write(html)
    n_q = sum(len(g[3]) for g in GROUPS)
    return n_q, len(html)


def _strip(s):
    """JSON-LD 里要纯文本。"""
    import re
    s = re.sub(r'<[^>]+>', '', s)
    return (s.replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
             .replace('&quot;', '"').replace('&nbsp;', ' '))


def main():
    for lang in LANGS:
        n, size = render(lang, PAGES[lang][0])
        print('%-6s %2d 题 · %6d 字节 → %s' % (lang, n, size, PAGES[lang][0]))
    print('\n✅ 三份帮助中心已生成（题目与分组逐题对齐）')


if __name__ == '__main__':
    main()
