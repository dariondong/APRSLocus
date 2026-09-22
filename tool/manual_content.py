#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""手册站的**全部三语文案**（内容与渲染分离；渲染见 tool/gen_manual_pages.py）。

写作原则（针对上一版「像功能概述、不是文档」的批评）：
  * **任务式**：每节 = 目标 → 编号步骤（菜单路径用 <code>设置 → 连接</code>）→
    「怎么算成功」→ 常见坑；不写「是什么/有什么特点」的空话。
  * **真实素材**：报文示例取自 test/ 里的真实帧（beacon_format_test / afsk_test /
    aprs_parse_test），默认值取自 lib/state.dart 与各 Config 类构造参数。
  * **可核对**：菜单路径、页签顺序、默认值全部对得上代码。

⚠️ 三语文案分别手写（T(zh, zh_TW, en)），**不用位置下标**——gen_faq_pages.py 曾因
   索引错位把别家语言填进答案位，数量检查还发现不了。
"""

def T(zh, zh_TW, en):
    """三语文案。刻意要求每次写全三种，漏一种会在自检里报错。"""
    return {'zh': zh, 'zh_TW': zh_TW, 'en': en}


# ─────────────────────────── 页面清单（顺序 = 侧栏顺序 = 学习顺序） ───────────────────────────
# file: 输出 docs/<lang 前缀>manual/<file>.html
PAGES = [
    dict(file='index',          title=T('手册首页', '手冊首頁', 'Guide Home')),
    dict(file='start',          title=T('快速上手', '快速上手', 'Quick Start')),
    dict(file='interface',      title=T('界面导览', '介面導覽', 'Interface')),
    dict(file='connections',    title=T('连接与数据来源', '連線與資料來源', 'Connections')),
    dict(file='beacon',         title=T('位置信标', '位置信標', 'Beaconing')),
    dict(file='messaging',      title=T('消息与群聊', '訊息與群組', 'Messaging')),
    dict(file='maps',           title=T('地图与显示', '地圖與顯示', 'Maps & Display')),
    dict(file='stations',       title=T('台站与筛选', '臺站與篩選', 'Stations')),
    dict(file='data',           title=T('导出 · 备份 · 轨迹', '匯出 · 備份 · 軌跡', 'Export & Backup')),
    dict(file='widgets',        title=T('桌面组件与短波', '桌面小組件與短波', 'Widgets & HF')),
    dict(file='settings',       title=T('设置参考', '設定參考', 'Settings Reference')),
    dict(file='platform',       title=T('平台差异', '平台差異', 'Platforms')),
    dict(file='troubleshooting', title=T('故障排查', '故障排除', 'Troubleshooting')),
]

# 页面 lead（任务目标）+ 章内小节（id → 标题）
PAGE_META = {
    'index': dict(
        lead=T('不知道从哪开始？按下面五条路径走，每条都指向具体页面。',
               '不知從哪開始？按下面五條路徑走，每條都指向具體頁面。',
               'Not sure where to start? Five paths, each pointing at a concrete page.'),
        sections=[('paths', T('按目标选路径', '按目標選路徑', 'Pick a path by goal')),
                  ('all', T('全部章节', '全部章節', 'All chapters'))]),
    'start': dict(
        lead=T('目标：装好应用、跑完七步向导，让 APRS-IS 显示「已验证」并收到第一条报文。',
               '目標：裝好應用、跑完七步引導，讓 APRS-IS 顯示「已驗證」並收到第一則封包。',
               'Goal: install, finish the seven-step wizard, get APRS-IS to “verified” and receive your first packet.'),
        sections=[('install', T('安装', '安裝', 'Install')),
                  ('wizard', T('首次启动：七步向导', '首次啟動：七步引導', 'First launch: seven steps')),
                  ('passcode', T('Passcode 与后台运行', 'Passcode 與背景執行', 'Passcode & background')),
                  ('firstpacket', T('验证：收到第一条报文', '驗證：收到第一則封包', 'Verify: first packet'))]),
    'interface': dict(
        lead=T('目标：认识五个页签与面板手势，知道每个界面该干什么。',
               '目標：認識五個頁籤與面板手勢，知道每個介面該幹什麼。',
               'Goal: learn the five tabs and the panel gestures, and know what each screen is for.'),
        sections=[('tabs', T('五个页签', '五個頁籤', 'Five tabs')),
                  ('gestures', T('面板手势与返回键', '面板手勢與返回鍵', 'Panels & Back key'))]),
    'connections': dict(
        lead=T('目标：选对数据来源、把 APRS-IS 连上并验证，必要时接上电台跑通射频链路。',
               '目標：選對資料來源、把 APRS-IS 連上並驗證，必要時接上電臺跑通射頻鏈路。',
               'Goal: pick the data sources, connect and verify APRS-IS, then get the RF link working.'),
        sections=[('sources', T('四条链路：收可以多选，发只有一条', '四條鏈路：收可複選，發只有一條', 'Four links: many RX, one TX')),
                  ('aprsis', T('接上 APRS-IS', '接上 APRS-IS', 'Connect APRS-IS')),
                  ('rf', T('接电台：TNC / 音频 / PKWDWPL', '接電臺：TNC / 音訊 / PKWDWPL', 'Into a radio: TNC / audio / PKWDWPL')),
                  ('igate', T('网关 iGate', '閘道 iGate', 'iGate')),
                  ('selftest', T('链路自检与排错顺序', '鏈路自檢與排錯順序', 'Self-test & order of diagnosis'))]),
    'beacon': dict(
        lead=T('目标：让别人在地图上看到你 —— 间隔、速度分档、射频开关一次配好。',
               '目標：讓別人在地圖上看到你 —— 間隔、速度分檔、射頻開關一次配好。',
               'Goal: show up on other people’s maps — interval, speed tiers and the RF switch in one pass.'),
        sections=[('interval', T('上报节奏：先定间隔', '上報節奏：先定間隔', 'Cadence: pick the interval')),
                  ('tiers', T('移动起来：速度分檔', '移動起來：速度分檔', 'On the move: speed tiers')),
                  ('nofix', T('没有 GPS 怎么办', '沒有 GPS 怎麼辦', 'When there is no GPS')),
                  ('packet', T('一帧信标长什么样', '一幀信標長什麼樣', 'What a beacon frame looks like'))]),
    'messaging': dict(
        lead=T('目标：发出第一条消息并确认送达，再按需开群聊与翻译。',
               '目標：發出第一條訊息並確認送達，再按需開群組與翻譯。',
               'Goal: send your first message and see it confirmed, then add group chat and translation.'),
        sections=[('send', T('发一条消息', '發一則訊息', 'Send a message')),
                  ('limits', T('两条长度红线', '兩條長度紅線', 'Two hard limits')),
                  ('group', T('建群与群聊', '建組與群組', 'Group chat')),
                  ('translate', T('双向翻译', '雙向翻譯', 'Two-way translation'))]),
    'maps': dict(
        lead=T('目标：选好图源、确认坐标不漂，需要时下载离线地图。',
               '目標：選好圖源、確認座標不漂，需要時下載離線地圖。',
               'Goal: choose a tile source, make sure coordinates do not drift, download offline tiles when needed.'),
        sections=[('tiles', T('选图源', '選圖源', 'Pick tile sources')),
                  ('datum', T('坐标不漂：WGS-84 ↔ GCJ-02', '座標不漂：WGS-84 ↔ GCJ-02', 'No drift: WGS-84 ↔ GCJ-02')),
                  ('offline', T('下载离线地图', '下載離線地圖', 'Download offline maps')),
                  ('look', T('界面风格与主题', '介面風格與主題', 'Look and feel'))]),
    'stations': dict(
        lead=T('目标：先收得到（范围过滤），再看得清（列表筛选与详情）。',
               '目標：先收得到（範圍過濾），再看得清（列表篩選與詳情）。',
               'Goal: receive the right things (range filter), then read them clearly (list filters and detail).'),
        sections=[('receive', T('收什么：范围与接收偏好', '收什麼：範圍與接收偏好', 'What you receive')),
                  ('display', T('看什么：列表筛选', '看什麼：列表篩選', 'What you display')),
                  ('detail', T('台站详情与设备识别', '臺站詳情與裝置識別', 'Detail & device ID'))]),
    'data': dict(
        lead=T('目标：把日志导出成 ADIF、把整机设置打包备份、翻看历史轨迹。',
               '目標：把日誌匯出成 ADIF、把整機設定打包備份、翻看歷史軌跡。',
               'Goal: export logs to ADIF, back up every setting, and browse your track history.'),
        sections=[('adif', T('导出 ADIF', '匯出 ADIF', 'ADIF export')),
                  ('backup', T('备份与恢复', '備份與恢復', 'Backup & restore')),
                  ('track', T('历史轨迹与回放', '歷史軌跡與回放', 'Track history & playback'))]),
    'widgets': dict(
        lead=T('目标：放好三套桌面组件，看懂短波传播面板。',
               '目標：放好三套桌面小組件，看懂短波傳播面板。',
               'Goal: place the three home-screen widgets and read the HF propagation panel.'),
        sections=[('home', T('三套桌面组件', '三套桌面小組件', 'Three widgets')),
                  ('hf', T('短波传播面板', '短波傳播面板', 'HF propagation panel'))]),
    'settings': dict(
        lead=T('设置的逐项参考：名称、控件、默认值、说明 —— 全部由代码与官方文案生成，'
               '改了代码重新生成即可对齐。',
               '設定的逐項參考：名稱、控件、預設值、說明 —— 全部由程式碼與官方文案產生，'
               '改了程式碼重新產生即可對齊。',
               'Item-by-item reference: name, control, default, description — generated from the '
               'code and the official strings, so it stays in sync.'),
        sections=[]),
    'platform': dict(
        lead=T('同一个应用在 Android / Windows / Web 上能力不同，先看这张表再动手。',
               '同一個應用在 Android / Windows / Web 上能力不同，先看這張表再動手。',
               'The same app behaves differently on Android, Windows and the web — check before you start.'),
        sections=[('matrix', T('能力矩阵', '能力矩陣', 'Capability matrix')),
                  ('web', T('Web 版的取舍', 'Web 版的取捨', 'Web build trade-offs'))]),
    'troubleshooting': dict(
        lead=T('目标：用三个入口把问题定位到「链路 / 筛选 / 配置」中的哪一层。',
               '目標：用三個入口把問題定位到「鏈路 / 篩選 / 配置」中的哪一層。',
               'Goal: use three entry points to localise a problem to link, filter or configuration.'),
        sections=[('entries', T('先用这三个入口', '先用這三個入口', 'Start with these three')),
                  ('matrix', T('症状 → 原因 → 动作', '症狀 → 原因 → 動作', 'Symptom → cause → action')),
                  ('report', T('还是解决不了？', '還是解決不了？', 'Still stuck?'))]),
}
