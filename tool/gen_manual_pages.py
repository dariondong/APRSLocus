#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成三语「用户手册」页面 docs/{,zh-TW/,en/}manual.html。

内容全部**从代码里翻出来的事实**（骨架依据）：
    * 5 个页签与顺序  —— lib/shell2.dart `_slots`
    * OOBE 7 步实序    —— lib/oobe_page.dart PageView children
    * 设置 8 分组      —— lib/settings_page.dart title/byKey + *CatDesc
    * 默认值           —— beaconInterval=60、filterRadius=300(min 10)、
                          server=rotate.aprs2.net、msg 67 字符 / 512 字节
    * 数据来源与 iGate —— lib/l10n/app_zh.arb (dataSource*/igate*)

跑法：
    python3 tool/gen_manual_pages.py

⚠️ 与 gen_faq_pages.py 的教训一致：**文案用 T() 字典（zh/zh_TW/en）而非位置下标**，
   位置下标一旦错位就把别家语言填进来了，而数量检查发现不了。
   三语文案分别手写，不做机器转换。
"""
import io
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = 'https://aprslocus.theez.top'

# lang -> (输出相对路径, <html lang>, 页面相对前缀, canonical 后缀)
PAGES = {
    'zh':    ('docs/manual.html',      'zh-CN', '',    'manual.html'),
    'zh_TW': ('docs/zh-TW/manual.html', 'zh-TW', '../', 'zh-TW/manual.html'),
    'en':    ('docs/en/manual.html',    'en',    '../', 'en/manual.html'),
}
LANGS = ('zh', 'zh_TW', 'en')


def T(zh, zh_TW, en):
    """三语文案。刻意要求每次写全三种，漏一种会在自检里报错。"""
    return {'zh': zh, 'zh_TW': zh_TW, 'en': en}


# ─────────────────────────── 页面级文案 ───────────────────────────
HEAD = {
    'zh': dict(
        title='用户手册 — APRSlocus 从上手到进阶',
        desc='APRSlocus 用户手册：快速上手七步引导、五个页签界面导览、四种数据来源与网关、'
             '位置信标、消息与群聊、地图与显示、台站筛选、导出备份、桌面小组件、设置参考与故障排查。',
        h1='用户手册',
        lead='按真实界面与代码行为写成的完整说明书：从第一次启动到射频进阶，12 章带你把每一个开关都用明白。',
        ph='搜索章节，比如「信标」「网关」「离线地图」…',
    ),
    'zh_TW': dict(
        title='使用手冊 — APRSlocus 從上手到進階',
        desc='APRSLocus 使用手冊：快速上手七步引導、五個頁籤介面導覽、四種資料來源與閘道、'
             '位置信標、訊息與群組、地圖與顯示、臺站篩選、匯出備份、桌面小組件、設定參考與故障排除。',
        h1='使用手冊',
        lead='按真實介面與程式碼行為寫成的完整說明書：從第一次啟動到射頻進階，12 章帶你把每一個開關都用明白。',
        ph='搜尋章節，例如「信標」「閘道」「離線地圖」…',
    ),
    'en': dict(
        title='User Guide — APRSlocus from First Launch to RF',
        desc='APRSlocus user guide: the seven-step setup wizard, the five-tab interface, four data '
             'sources and the iGate, position beaconing, messaging and group chat, maps and display, '
             'station filtering, export and backup, home-screen widgets, a settings reference and '
             'troubleshooting.',
        h1='User Guide',
        lead='Written against the real interface and code behaviour: twelve chapters that take you '
             'from first launch to operating on RF, and explain what every switch actually does.',
        ph='Search chapters, e.g. “beacon”, “iGate”, “offline”…',
    ),
}

UI = {
    'zh': dict(home='首页', feat='功能', help='帮助中心', manual='手册', dl='下载',
               burger='菜单', theme='切换深色模式', theme_off='切换浅色模式',
               skip='跳到主要内容', toc='本章导航', search='搜索章节',
               foot_home='首页', foot_help='帮助', foot_manual='手册',
               terms='用户协议',
               disclaimer='本软件仅供业余无线电爱好者学习交流使用，请遵守当地无线电管理法规。'),
    'zh_TW': dict(home='首頁', feat='功能', help='幫助中心', manual='手冊', dl='下載',
                  burger='菜單', theme='切換深色模式', theme_off='切換淺色模式',
                  skip='跳到主要內容', toc='本章導航', search='搜尋章節',
                  foot_home='首頁', foot_help='幫助', foot_manual='手冊',
                  terms='使用者協定',
                  disclaimer='本軟體僅供業餘無線電愛好者學習交流使用，請遵守當地電波法規。'),
    'en': dict(home='Home', feat='Features', help='Help Center', manual='Guide', dl='Download',
               burger='Menu', theme='Switch to dark mode', theme_off='Switch to light mode',
               skip='Skip to main content', toc='On this page', search='Search chapters',
               foot_home='Home', foot_help='Help', foot_manual='Guide',
               terms='Terms',
               disclaimer='For amateur radio study and exchange only — comply with your local '
                          'radio regulations.'),
}

# ─────────────────────────── 章节（三语手写） ───────────────────────────
# 每章: dict(id, title=T, sections=[(h3=T, body=T)])
# body 是 HTML：<p>/<ul>/<ol class="m-steps">/.callout/.doc-table/<code>/<kbd>/<b>
CHAPTERS = [
    # ───────── 1 快速上手 ─────────
    dict(id='start', title=T('快速上手', '快速上手', 'Quick Start'), sections=[
        (T('安装', '安裝', 'Install'),
         T('<p>到 <a href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">GitHub Releases</a> '
           '下载 <b>Android APK</b> 或 <b>Windows 安装包</b>。自 v1.5.2 起 Android 使用正式 release 签名，'
           '直接覆盖安装即可；从更老的版本升级请先卸载再装。</p>',
           '<p>到 <a href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">GitHub Releases</a> '
           '下載 <b>Android APK</b> 或 <b>Windows 安裝程式</b>。自 v1.5.2 起 Android 使用正式 release 簽章，'
           '直接覆蓋安裝即可；從更老的版本升級請先解除安裝再裝。</p>',
           '<p>Grab the <b>Android APK</b> or the <b>Windows installer</b> from '
           '<a href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">GitHub Releases</a>. '
           'Since v1.5.2 Android builds use the official release signature, so installing over the '
           'old version just works; uninstall first when coming from a much older build.</p>')),
        (T('首次启动：七步完成基础配置', '首次啟動：七步完成基礎配置', 'First launch: seven steps'),
         T('<p>第一次打开应用会进入设置向导，每一步都可以随时返回修改；'
           '之后也能在「设置 → 高级」里<b>重新运行向导</b>，当前设置不会丢失。</p>'
           '<ol class="m-steps">'
           '<li><b>选择界面语言</b> —— 六种语言：简体中文 / 繁體中文 / English / 日本語 / Indonesia / Español。</li>'
           '<li><b>用户协议与许可</b> —— 需勾选同意《用户协议》与 GPL-3.0 才能继续；注意 APRS 数据是公开信息，发出后可能被全球网络接收与转发。</li>'
           '<li><b>欢迎页</b> —— 介绍四项核心能力：实时地图、GPS 定位上报、APRS 消息、接入 APRS-IS。</li>'
           '<li><b>呼号与 SSID</b> —— 输入你的完整呼号（含 SSID 后缀，如 <code>BG7LZQ-3</code>），留空无法继续。</li>'
           '<li><b>台站符号</b> —— 符号代表台站类型，会随每一条位置信标一起发送。</li>'
           '<li><b>接收地区</b> —— 勾选要接收的国家/地区；<b>不勾选 = 接收全部</b>，不做限制。</li>'
           '<li><b>APRS-IS 服务器与 Passcode</b> —— 服务器默认 <code>rotate.aprs2.net</code>，可保持默认；'
           'Passcode 务必填对，见下方提示。</li>'
           '</ol>',
           '<p>第一次開啟應用會進入設定引導，每一步都可以隨時返回修改；'
           '之後也能在「設定 → 高級」裡<b>重新執行引導</b>，目前設定不會遺失。</p>'
           '<ol class="m-steps">'
           '<li><b>選擇介面語言</b> —— 六種語言：簡體中文 / 繁體中文 / English / 日本語 / Indonesia / Español。</li>'
           '<li><b>使用者協議與授權</b> —— 需勾選同意《使用者協議》與 GPL-3.0 才能繼續；注意 APRS 資訊是公開資料，發出後可能被全球網路接收與轉發。</li>'
           '<li><b>歡迎頁</b> —— 介紹四項核心能力：即時地圖、GPS 定位上報、APRS 訊息、接入 APRS-IS。</li>'
           '<li><b>呼號與 SSID</b> —— 輸入你的完整呼號（含 SSID 後綴，如 <code>BG7LZQ-3</code>），留空無法繼續。</li>'
           '<li><b>臺站符號</b> —— 符號代表臺站類型，會隨每一則位置信標一起發送。</li>'
           '<li><b>接收地區</b> —— 勾選要接收的國家/地區；<b>不勾選 = 接收全部</b>，不做限制。</li>'
           '<li><b>APRS-IS 伺服器與 Passcode</b> —— 伺服器預設 <code>rotate.aprs2.net</code>，可保持預設；'
           'Passcode 務必填對，見下方提示。</li>'
           '</ol>',
           '<p>The first launch walks you through seven steps; you can go back at any point, and '
           'the wizard can be re-run later from <b>Settings → Advanced</b> without losing your '
           'current setup.</p>'
           '<ol class="m-steps">'
           '<li><b>Pick your language</b> — six UI languages: Simplified Chinese, Traditional '
           'Chinese, English, Japanese, Indonesian, Spanish.</li>'
           '<li><b>Agreement</b> — you must accept the Terms and the GPL-3.0 licence to continue. '
           'Note that APRS data is public: once sent it may be received, stored and relayed worldwide.</li>'
           '<li><b>Welcome</b> — the four core abilities: live map, GPS position reporting, APRS '
           'messaging and the APRS-IS connection.</li>'
           '<li><b>Callsign &amp; SSID</b> — enter your full callsign including the SSID suffix '
           '(e.g. <code>BG7LZQ-3</code>); it cannot be left empty.</li>'
           '<li><b>Station symbol</b> — the symbol states your station type and travels with every '
           'position beacon.</li>'
           '<li><b>Receive area</b> — tick the countries/regions you want to receive; '
           '<b>nothing ticked = receive everything</b>.</li>'
           '<li><b>APRS-IS server &amp; Passcode</b> — the server defaults to '
           '<code>rotate.aprs2.net</code> and can stay as it is; make sure the Passcode is right, '
           'see the note below.</li>'
           '</ol>')),
        (T('Passcode 与后台运行', 'Passcode 與背景執行', 'Passcode and background running'),
         T('<div class="callout warn"><span class="co-ic">⚠️</span><div><p><b>Passcode 是 APRS-IS 的登录验证码</b>，'
           '用于把你的呼号验证到网络。留空或用默认 <code>-1</code> 只能<b>连接</b>，'
           '无法正常收发消息与群组 —— 请到 <a href="https://aprs.cool/AprsPG" target="_blank" rel="noopener">APRS Passcode 查询</a> '
           '用完整呼号生成后填入。填错时主页顶部会出现黄色「未验证」横幅。</p></div></div>'
           '<div class="callout info"><span class="co-ic">🔋</span><div><p><b>想让信标持续上报</b>，请到系统设置里允许 '
           'APRSlocus 后台运行、关闭省电优化、允许自启动；通知栏可一键「退出」应用。</p></div></div>',
           '<div class="callout warn"><span class="co-ic">⚠️</span><div><p><b>Passcode 是 APRS-IS 的登入驗證碼</b>，'
           '用於把你的呼號驗證到網路。留空或用預設 <code>-1</code> 只能<b>連線</b>，'
           '無法正常收發訊息與群組 —— 請到 <a href="https://aprs.cool/AprsPG" target="_blank" rel="noopener">APRS Passcode 查詢</a> '
           '用完整呼號產生後填入。填錯時首頁頂部會出現黃色「未驗證」橫幅。</p></div></div>'
           '<div class="callout info"><span class="co-ic">🔋</span><div><p><b>想讓信標持續上報</b>，請到系統設定裡允許 '
           'APRSLocus 背景執行、關閉省電最佳化、允許自啟動；通知欄可一鍵「結束」應用。</p></div></div>',
           '<div class="callout warn"><span class="co-ic">⚠️</span><div><p><b>The Passcode is the APRS-IS login '
           'validator</b> for your callsign. Leaving it empty or at the default <code>-1</code> lets you '
           '<b>connect</b> only — messaging and group chat will not work. Generate one for your full '
           'callsign at the <a href="https://aprs.cool/AprsPG" target="_blank" rel="noopener">APRS Passcode '
           'generator</a>. A wrong value shows a yellow “unverified” banner on the home page.</p></div></div>'
           '<div class="callout info"><span class="co-ic">🔋</span><div><p><b>For continuous beaconing</b>, allow '
           'APRSlocus to run in the background, disable battery optimisation and allow auto-start in your '
           'system settings; the notification offers a one-tap Exit.</p></div></div>')),
    ]),
    # ───────── 2 界面导览 ─────────
    dict(id='ui', title=T('界面导览', '介面導覽', 'The Interface'), sections=[
        (T('五个页签', '五個頁籤', 'Five tabs'),
         T('<p>底部导航共五项，顺序固定（桌面端会变成侧边栏）：</p>'
           '<table class="doc-table"><thead><tr><th>页签</th><th>里面是什么</th></tr></thead><tbody>'
           '<tr><td><b>地图</b></td><td>应用的底座：台站标记、轨迹、工具列、地图菜单都在这里</td></tr>'
           '<tr><td><b>台站</b></td><td>收到的台站列表：筛选、搜索、详情、收藏、轨迹回放</td></tr>'
           '<tr><td><b>消息</b></td><td>单聊与群聊的统一会话列表，带未读角标</td></tr>'
           '<tr><td><b>数据包</b></td><td>原始报文流（等宽显示、可复制、可按类型筛选）与分级日志</td></tr>'
           '<tr><td><b>设置</b></td><td>八个分组 + 荣誉墙、翻译、ADIF、主题、历史轨迹、备份等入口</td></tr>'
           '</tbody></table>',
           '<p>底部導航共五項，順序固定（桌面端會變成側邊欄）：</p>'
           '<table class="doc-table"><thead><tr><th>頁籤</th><th>裡面是什麼</th></tr></thead><tbody>'
           '<tr><td><b>地圖</b></td><td>應用的底座：臺站標記、軌跡、工具列、地圖選單都在這裡</td></tr>'
           '<tr><td><b>臺站</b></td><td>收到的臺站列表：篩選、搜尋、詳情、收藏、軌跡回放</td></tr>'
           '<tr><td><b>訊息</b></td><td>單聊與群組的統一會話列表，帶未讀角標</td></tr>'
           '<tr><td><b>資料封包</b></td><td>原始封包串流（等寬顯示、可複製、可按類型篩選）與分級日誌</td></tr>'
           '<tr><td><b>設定</b></td><td>八個分組 + 榮譽牆、翻譯、ADIF、主題、歷史軌跡、備份等入口</td></tr>'
           '</tbody></table>',
           '<p>Five tabs, in fixed order (they become a side rail on desktop):</p>'
           '<table class="doc-table"><thead><tr><th>Tab</th><th>What lives there</th></tr></thead><tbody>'
           '<tr><td><b>Map</b></td><td>The base of the app: station markers, tracks, the toolbar and the map menu</td></tr>'
           '<tr><td><b>Stations</b></td><td>The stations you received: filters, search, detail, favourites, trail playback</td></tr>'
           '<tr><td><b>Messages</b></td><td>One conversation list for direct and group chats, with unread badges</td></tr>'
           '<tr><td><b>Packets</b></td><td>The raw packet stream (monospace, copyable, filterable) and the分级 log</td></tr>'
           '<tr><td><b>Settings</b></td><td>Eight categories plus honor wall, translation, ADIF, themes, track history, backup…</td></tr>'
           '</tbody></table>')),
        (T('面板、手势与返回键', '面板、手勢與返回鍵', 'Panels, gestures and Back'),
         T('<ul>'
           '<li><b>地图永远在最底下</b>：点其它页签时面板浮起盖在地图上，再点「地图」收起面板 —— 地图就是底。</li>'
           '<li><b>面板可上下拖动</b>：抓住顶部把手，或者直接拖底部导航条（它又高又宽，最好抓）。</li>'
           '<li><b>返回键只在「地图」页签退出应用</b>；在其它页签先收起面板/返回上级，避免误退。</li>'
           '<li><b>切页不销毁</b>：列表滚动位置、正在看的会话都会保留（页面是缓存的，不是每次重建）。</li>'
           '</ul>',
           '<ul>'
           '<li><b>地圖永遠在最底下</b>：點其它頁籤時面板浮起蓋在地圖上，再點「地圖」收起面板 —— 地圖就是底。</li>'
           '<li><b>面板可上下拖動</b>：抓住頂部把手，或者直接拖底部導航條（它又高又寬，最好抓）。</li>'
           '<li><b>返回鍵只在「地圖」頁籤結束應用</b>；在其它頁籤先收起面板/返回上層，避免誤退。</li>'
           '<li><b>切頁不銷毀</b>：列表捲動位置、正在看的會話都會保留（頁面是快取的，不是每次重建）。</li>'
           '</ul>',
           '<ul>'
           '<li><b>The map is always the base</b>: picking another tab raises a panel over it; tapping '
           'Map again lowers it.</li>'
           '<li><b>Drag the panel</b> with its top handle — or simply drag the bottom navigation bar, '
           'which is the biggest, easiest target.</li>'
           '<li><b>Back only exits the app from the Map tab</b>; elsewhere it first lowers the panel or '
           'goes up a level, so you never quit by accident.</li>'
           '<li><b>Tabs are never torn down</b>: scroll positions and the open conversation survive '
           'switching (pages are cached, not rebuilt).</li>'
           '</ul>')),
    ]),
    # ───────── 3 连接与数据来源 ─────────
    dict(id='link', title=T('连接与数据来源', '連線與資料來源', 'Connections & Data Sources'), sections=[
        (T('四条链路，收发分开', '四條鏈路，收發分開', 'Four links; receiving and transmitting are separate'),
         T('<p>「设置 → 连接」里的<b>数据来源</b>可多选 —— 勾中的链路都会<b>收</b>报文；'
           '但<b>发射只有一条</b>（右侧圆点标记的那条），同一个呼号从两条链路发出去会造成重复报文。</p>'
           '<table class="doc-table"><thead><tr><th>来源</th><th>链路</th><th>收</th><th>发</th></tr></thead><tbody>'
           '<tr><td><b>APRS-IS</b></td><td>互联网 TCP（默认 <code>rotate.aprs2.net:14580</code>）</td><td>✓</td><td>✓</td></tr>'
           '<tr><td><b>TNC</b></td><td>蓝牙 SPP 或 USB 串口（OTG），KISS 协议，接电台</td><td>✓</td><td>✓</td></tr>'
           '<tr><td><b>音频（声卡）</b></td><td>麦克风/耳机口接电台，AFSK 1200（Bell 202）</td><td>✓</td><td>✓</td></tr>'
           '<tr><td><b>PKWDWPL</b></td><td>蓝牙/串口读 Kenwood 电台的 <code>$PKWDWPL</code> 航点语句</td><td>✓</td><td><b>✗ 只读</b></td></tr>'
           '</tbody></table>'
           '<div class="callout info"><span class="co-ic">📶</span><div><p>APRS-IS 断线按 '
           '<b>8 → 16 → 32 → 60 秒</b>渐进重连；接收范围用 <code>r/纬度/经度/半径</code> 过滤，'
           '默认半径 <b>300 km</b>（最小 10 km），在「连接设置」里改，点「保存并应用」生效。</p></div></div>',
           '<p>「設定 → 連線」裡的<b>資料來源</b>可複選 —— 勾中的鏈路都會<b>收</b>封包；'
           '但<b>發射只有一條</b>（右側圓點標記的那條），同一個呼號從兩條鏈路發出去會造成重複封包。</p>'
           '<table class="doc-table"><thead><tr><th>來源</th><th>鏈路</th><th>收</th><th>發</th></tr></thead><tbody>'
           '<tr><td><b>APRS-IS</b></td><td>網際網路 TCP（預設 <code>rotate.aprs2.net:14580</code>）</td><td>✓</td><td>✓</td></tr>'
           '<tr><td><b>TNC</b></td><td>藍牙 SPP 或 USB 序列埠（OTG），KISS 協定，接電臺</td><td>✓</td><td>✓</td></tr>'
           '<tr><td><b>音訊（音效卡）</b></td><td>麥克風/耳機孔接電臺，AFSK 1200（Bell 202）</td><td>✓</td><td>✓</td></tr>'
           '<tr><td><b>PKWDWPL</b></td><td>藍牙/序列埠讀 Kenwood 電臺的 <code>$PKWDWPL</code> 航點語句</td><td>✓</td><td><b>✗ 唯讀</b></td></tr>'
           '</tbody></table>'
           '<div class="callout info"><span class="co-ic">📶</span><div><p>APRS-IS 斷線按 '
           '<b>8 → 16 → 32 → 60 秒</b>漸進重連；接收範圍用 <code>r/緯度/經度/半徑</code> 過濾，'
           '預設半徑 <b>300 km</b>（最小 10 km），在「連線設定」裡改，點「儲存並套用」生效。</p></div></div>',
           '<p>In <b>Settings → Connection</b> the <b>data sources</b> are multi-select — every ticked '
           'link <b>receives</b> packets; but there is only <b>one transmit source</b> (the one marked '
           'with the dot). Transmitting the same callsign over two links would produce duplicate packets.</p>'
           '<table class="doc-table"><thead><tr><th>Source</th><th>Link</th><th>RX</th><th>TX</th></tr></thead><tbody>'
           '<tr><td><b>APRS-IS</b></td><td>Internet TCP (default <code>rotate.aprs2.net:14580</code>)</td><td>✓</td><td>✓</td></tr>'
           '<tr><td><b>TNC</b></td><td>Bluetooth SPP or USB serial (OTG), KISS, into a radio</td><td>✓</td><td>✓</td></tr>'
           '<tr><td><b>Audio</b></td><td>Mic/headphone jack into a radio, AFSK 1202 (Bell 202)</td><td>✓</td><td>✓</td></tr>'
           '<tr><td><b>PKWDWPL</b></td><td>Bluetooth/serial reader of a Kenwood radio’s <code>$PKWDWPL</code> waypoints</td><td>✓</td><td><b>✗ receive-only</b></td></tr>'
           '</tbody></table>'
           '<div class="callout info"><span class="co-ic">📶</span><div><p>APRS-IS reconnects with progressive '
           'backoff (<b>8 → 16 → 32 → 60 s</b>). The receive range uses the <code>r/lat/lng/radius</code> filter, '
           '<b>300 km</b> by default (10 km minimum), changed in Connection settings and applied with Save.</p></div></div>')),
        (T('网关（iGate）', '閘道（iGate）', 'Gateway (iGate)'),
         T('<p>iGate 把<b>射频</b>收到的报文转送到 <b>APRS-IS</b>（自动加 <code>qAr</code>/<code>qAR</code> 与你的呼号标识来路）。'
           '启用条件：上面同时勾选 <b>APRS-IS</b> 和一条射频来源（TNC 或音频），缺一个界面会直接告诉你差什么。</p>'
           '<ul>'
           '<li><b>默认只做 RF → IS</b>：把听到的送上互联网。</li>'
           '<li><b>双向网关</b>打开后会在射频上<b>真实发射</b>：只转「发给最近在射频上听到过的台站」的点对点消息，'
           '位置/天气等广播不转，避免占满信道。</li>'
           '<li><b>环路防护</b>：报文带 <code>TCPIP*</code> 或已有 q 构造的（本来就是从互联网来的）绝不回送；'
           '同一帧 30 秒内只注入一次。</li>'
           '</ul>',
           '<p>iGate 把<b>射頻</b>收到的封包轉送到 <b>APRS-IS</b>（自動加 <code>qAr</code>/<code>qAR</code> 與你的呼號標識來路）。'
           '啟用條件：上面同時勾選 <b>APRS-IS</b> 和一條射頻來源（TNC 或音訊），缺一個介面會直接告訴你差什麼。</p>'
           '<ul>'
           '<li><b>預設只做 RF → IS</b>：把聽到的送上網際網路。</li>'
           '<li><b>雙向閘道</b>打開後會在射頻上<b>真實發射</b>：只轉「發給最近在射頻上聽到過的臺站」的點對點訊息，'
           '位置/天氣等廣播不轉，避免佔滿通道。</li>'
           '<li><b>環路防護</b>：封包帶 <code>TCPIP*</code> 或已有 q 構造的（本來就是從網際網路來的）絕不回送；'
           '同一幀 30 秒內只注入一次。</li>'
           '</ul>',
           '<p>The iGate relays packets heard on <b>RF</b> into <b>APRS-IS</b> (tagging them with '
           '<code>qAr</code>/<code>qAR</code> and your callsign). To enable it, tick <b>APRS-IS</b> and one '
           'RF source (TNC or audio) above — the UI tells you exactly which one is missing.</p>'
           '<ul>'
           '<li><b>RF → IS only by default</b>: what you hear is forwarded to the internet.</li>'
           '<li><b>Two-way mode actually transmits on RF</b>: it only relays point-to-point messages '
           'addressed to stations heard on RF recently — broadcasts like position/weather are never '
           'relayed, so the channel is not flooded.</li>'
           '<li><b>Loop protection</b>: packets carrying <code>TCPIP*</code> or an existing q-construct '
           '(they came from the internet) are never sent back, and the same frame is injected once per 30 s.</li>'
           '</ul>')),
        (T('链路自检与排错顺序', '鏈路自檢與排錯順序', 'Link self-test and diagnosis order'),
         T('<p>设备页里的<b>「链路自检」</b>把 TNC 与音频各做一次分层回路测试；'
           'TNC 侧还有<b>初始化串</b>与<b>发射自检</b>（写入一帧状态包，不含坐标，不会在 aprs.fi 上挪动你的位置）。</p>'
           '<ol class="m-steps">'
           '<li><b>先看链路状态卡</b>：连接是否成立、收发计数是否在涨。</li>'
           '<li><b>TNC「能收不能发」</b>：先发初始化串（很多模块上电停在命令模式，要先收到 <code>KISS ON</code> 才进 KISS）；'
           '再查串口线速（USB 串口与电台数据口必须同速，常见 9600/19200/38400/57600/115200；蓝牙 SPP 无波特率概念）。</li>'
           '<li><b>音频「对方解不出」</b>：看发射电平 —— 峰值太低或削顶都不行；接电台用音频线（耳机口 → 电台数据/话筒口），'
           '别用扬声器对着麦克风。</li>'
           '<li><b>网关数字不涨</b>：按界面提示逐条排除 —— 射频收到=0 说明报文没进来，先查上游电台音量/静噪/天线。</li>'
           '</ol>',
           '<p>裝置頁裡的<b>「鏈路自檢」</b>把 TNC 與音訊各做一次分層回路測試；'
           'TNC 側還有<b>初始化字串</b>與<b>發射自檢</b>（寫入一幀狀態封包，不含座標，不會在 aprs.fi 上移動你的位置）。</p>'
           '<ol class="m-steps">'
           '<li><b>先看鏈路狀態卡</b>：連線是否成立、收發計數是否在漲。</li>'
           '<li><b>TNC「能收不能發」</b>：先送初始化字串（很多模組上電停在命令模式，要先收到 <code>KISS ON</code> 才進 KISS）；'
           '再查序列埠線速（USB 序列埠與電臺資料埠必須同速，常見 9600/19200/38400/57600/115200；藍牙 SPP 無鮑率概念）。</li>'
           '<li><b>音訊「對方解不出」</b>：看發射電平 —— 峰值太低或削波都不行；接電臺用音訊線（耳機孔 → 電臺資料/麥克風孔），'
           '別用喇叭對著麥克風。</li>'
           '<li><b>閘道數字不漲</b>：按介面提示逐條排除 —— 射頻收到=0 代表封包沒進來，先查上游電臺音量/靜噪/天線。</li>'
           '</ol>',
           '<p>The <b>link self-test</b> on the device page runs layered loopback tests for both TNC and '
           'audio; the TNC side also has an <b>init string</b> and a <b>TX self-test</b> (it writes one '
           'status frame with no coordinates, so it never moves you on aprs.fi).</p>'
           '<ol class="m-steps">'
           '<li><b>Start from the link status card</b>: is the link up, are the RX/TX counters moving?</li>'
           '<li><b>TNC receives but will not transmit</b>: send the init string first (many modules boot '
           'into command mode and need <code>KISS ON</code>), then check the serial baud rate — USB serial '
           'and the radio data port must match (9600/19200/38400/57600/115200 are common; Bluetooth SPP has '
           'no baud rate).</li>'
           '<li><b>Audio that others cannot decode</b>: look at the TX level — too low or clipped both fail; '
           'wire the radio with a cable (headphone jack → radio data/mic), never speaker-to-microphone.</li>'
           '<li><b>Gateway counters stay at zero</b>: follow the hints in order — “RF received = 0” means the '
           'packets never arrived, so check radio volume/squelch/antenna first.</li>'
           '</ol>')),
    ]),
    # ───────── 4 位置信标 ─────────
    dict(id='beacon', title=T('位置信标', '位置信標', 'Position Beacon'), sections=[
        (T('上报节奏', '上報節奏', 'Reporting cadence'),
         T('<p>信标按 APRS 1.0 标准格式发送，自动附带高度、速度、航向、电量（可配置），台站符号随信标一起发。'
           '默认间隔 <b>60 秒</b>（APRS-IS 建议移动站不低于 60 秒，最短可到 5 秒）。</p>'
           '<ul>'
           '<li><b>速度分档</b>（最多 5 档）：速度越快上报越频繁；每档可自定义间隔与图标（留空 = 用「我的符号」）。'
           '间隔低于 60 秒会明显增加服务器负载，界面会提醒。</li>'
           '<li><b>首页看得见节奏</b>：下次上报倒计时、已发信标次数都在主页上。</li>'
           '<li><b>手动上报</b>：不想自动发时可关掉自动上报，按需手动点。</li>'
           '</ul>',
           '<p>信標按 APRS 1.0 標準格式發送，自動附帶高度、速度、航向、電量（可設定），臺站符號隨信標一起發。'
           '預設間隔 <b>60 秒</b>（APRS-IS 建議移動站不低於 60 秒，最短可到 5 秒）。</p>'
           '<ul>'
           '<li><b>速度分檔</b>（最多 5 檔）：速度越快上報越頻繁；每檔可自訂間隔與圖示（留空 = 用「我的符號」）。'
           '間隔低於 60 秒會明顯增加伺服器負載，介面會提醒。</li>'
           '<li><b>首頁看得見節奏</b>：下次上報倒數、已發信標次數都在首頁上。</li>'
           '<li><b>手動上報</b>：不想自動發時可關掉自動上報，按需手動點。</li>'
           '</ul>',
           '<p>Beacons use the APRS 1.0 standard format and automatically carry altitude, speed, course '
           'and battery (all configurable); your station symbol travels with them. The default interval is '
           '<b>60 seconds</b> (APRS-IS suggests no faster than 60 s for mobiles; 5 s is the hard minimum).</p>'
           '<ul>'
           '<li><b>Speed tiers</b> (up to five): the faster you go, the more often it reports; each tier '
           'has its own interval and icon (empty = “my symbol”). Intervals under 60 s load the servers '
           'noticeably and the UI warns about it.</li>'
           '<li><b>The home page shows the cadence</b>: countdown to the next beacon and the number sent.</li>'
           '<li><b>Manual beaconing</b>: turn automatic reporting off and send on demand.</li>'
           '</ul>')),
        (T('没有 GPS 怎么办', '沒有 GPS 怎麼辦', 'When there is no GPS'),
         T('<ul>'
           '<li><b>定位来源</b>可在设置里选：GPS / 网络粗定位。</li>'
           '<li><b>手动定位</b>：输入经纬度或在地图上选点，用于信标上报与台站距离计算（室内、桌面演示常用）。</li>'
           '<li><b>演示模式</b>：完全没有定位时也能体验完整界面。</li>'
           '<li><b>自身防抖</b>：站着不动时标记不再原地哆嗦；GPS 新鲜时会丢弃网络粗定位点，'
           '避免位置「飞来飞去」。</li>'
           '</ul>',
           '<ul>'
           '<li><b>定位來源</b>可在設定裡選：GPS / 網路粗定位。</li>'
           '<li><b>手動定位</b>：輸入經緯度或在地圖上選點，用於信標上報與臺站距離計算（室內、桌面示範常用）。</li>'
           '<li><b>示範模式</b>：完全沒有定位時也能體驗完整介面。</li>'
           '<li><b>自身防抖</b>：站著不動時標記不再原地發抖；GPS 新鮮時會丟棄網路粗定位點，'
           '避免位置「飛來飛去」。</li>'
           '</ul>',
           '<ul>'
           '<li><b>Location source</b> is selectable: GPS or coarse network positioning.</li>'
           '<li><b>Manual location</b>: type coordinates or pick a point on the map — used for beaconing '
           'and station distance maths (handy indoors and for demos).</li>'
           '<li><b>Demo mode</b>: explore the full UI even with no positioning at all.</li>'
           '<li><b>Stationary damping</b>: the marker stops jittering while you stand still, and coarse '
           'network fixes are dropped while GPS is fresh, so the position no longer flies around.</li>'
           '</ul>')),
    ]),
    # ───────── 5 消息与群聊 ─────────
    dict(id='msg', title=T('消息与群聊', '訊息與群組', 'Messaging & Group Chat'), sections=[
        (T('单聊、群聊与长度红线', '單聊、群組與長度紅線', 'Direct chat, groups and the length limits'),
         T('<p>单聊与群聊在<b>同一个会话列表</b>里，像聊天软件一样收发；带 ACK 确认、未读角标、顶部气泡提示，'
           '历史自动保存，兼容中文消息（UTF-8 / GBK 自动解码）。</p>'
           '<div class="callout warn"><span class="co-ic">📏</span><div><p><b>两条长度红线：</b>'
           'APRS101 规范消息文本 <b>67 字符</b>（超了多数客户端仍能读，少数按规范截断/拒收）；'
           'APRS-IS 单行 <b>512 字节</b>（整包超了服务器可能直接丢弃，连报头都到不了对方）。'
           '界面会在发送前预检并提示。</p></div></div>'
           '<ul>'
           '<li><b>群聊用群呼号广播</b>：建群后系统自动生成群呼号并邀请成员，所有成员都能收到。</li>'
           '<li><b>射频（TNC）模式下不支持群聊广播</b>，单条长度同样受 67 字符限制 —— 信道是共享资源。</li>'
           '</ul>',
           '<p>單聊與群組在<b>同一個會話列表</b>裡，像聊天軟體一樣收發；帶 ACK 確認、未讀角標、頂部氣泡提示，'
           '歷史自動保存，兼容中文訊息（UTF-8 / GBK 自動解碼）。</p>'
           '<div class="callout warn"><span class="co-ic">📏</span><div><p><b>兩條長度紅線：</b>'
           'APRS101 規範訊息文字 <b>67 字元</b>（超了多數用戶端仍能讀，少數按規範截斷/拒收）；'
           'APRS-IS 單行 <b>512 位元組</b>（整包超了伺服器可能直接丟棄，連封包頭都到不了對方）。'
           '介面會在發送前預先檢查並提示。</p></div></div>'
           '<ul>'
           '<li><b>群組用群呼號廣播</b>：建組後系統自動產生群呼號並邀請成員，所有成員都能收到。</li>'
           '<li><b>射頻（TNC）模式下不支援群組廣播</b>，單條長度同樣受 67 字元限制 —— 通道是共享資源。</li>'
           '</ul>',
           '<p>Direct and group chats share <b>one conversation list</b> and work like a chat app, with '
           'ACK confirmation, unread badges and toast previews; history is persisted and Chinese messages '
           'work (UTF-8 / GBK decoded automatically).</p>'
           '<div class="callout warn"><span class="co-ic">📏</span><div><p><b>Two hard limits:</b> APRS101 '
           'caps the message text at <b>67 characters</b> (most clients still read beyond it, a few '
           'truncate or reject), and APRS-IS caps a line at <b>512 bytes</b> (over that the server may drop '
           'the whole frame, header included). The UI pre-checks and warns before you send.</p></div></div>'
           '<ul>'
           '<li><b>Groups broadcast on a group callsign</b>: creating one generates the callsign and '
           'invites the members you pick.</li>'
           '<li><b>Group broadcast is not available in RF (TNC) mode</b>, and single messages are limited '
           'to 67 characters there too — the channel is shared.</li>'
           '</ul>')),
        (T('双向翻译', '雙向翻譯', 'Two-way translation'),
         T('<p>内置多引擎翻译，默认走免费接口、<b>无需任何密钥</b>。「翻译设置」里可选引擎与语言：</p>'
           '<ul>'
           '<li><b>收到的消息</b>可对照原文显示译文；</li>'
           '<li><b>发送前</b>可把自己的输入先译成对方的语言；</li>'
           '<li>可开自动翻译；译文会做有效性校验，挡掉「把原文原样返回」的假成功。</li>'
           '</ul>',
           '<p>內建多引擎翻譯，預設走免費介面、<b>無需任何金鑰</b>。「翻譯設定」裡可選引擎與語言：</p>'
           '<ul>'
           '<li><b>收到的訊息</b>可對照原文顯示譯文；</li>'
           '<li><b>發送前</b>可把自己的輸入先譯成對方的語言；</li>'
           '<li>可開自動翻譯；譯文會做有效性檢查，擋掉「把原文原樣回傳」的假成功。</li>'
           '</ul>',
           '<p>Built-in multi-engine translation on a free endpoint — <b>no API key required</b>. '
           'Pick engine and languages under Translation settings:</p>'
           '<ul>'
           '<li><b>Incoming messages</b> can show the translation next to the original;</li>'
           '<li><b>Before sending</b> you can translate your own text into the other station’s language;</li>'
           '<li>Auto-translate is optional, and results are validated so a provider echoing the source '
           'back cannot fake success.</li>'
           '</ul>')),
    ]),
    # ───────── 6 地图与显示 ─────────
    dict(id='map', title=T('地图与显示', '地圖與顯示', 'Maps & Display'), sections=[
        (T('图源与坐标', '圖源與座標', 'Tile sources and coordinates'),
         T('<table class="doc-table"><thead><tr><th>图源</th><th>说明</th></tr></thead><tbody>'
           '<tr><td>高德地图 / 高德卫星</td><td>国内定位无缝对齐（GCJ-02）</td></tr>'
           '<tr><td><b>矢量地图</b></td><td>客户端实时渲染，数据量小、缩放清晰，<b>无需 API Key</b>，WGS-84</td></tr>'
           '<tr><td>Carto 浅色 / 深色 / 航行者</td><td>在线瓦片</td></tr>'
           '<tr><td>OSM 标准 / 人道</td><td>在线瓦片</td></tr>'
           '<tr><td>OpenTopo 地形</td><td>等高线地形</td></tr>'
           '<tr><td>Esri 街道 / 影像</td><td>在线瓦片</td></tr>'
           '</tbody></table>'
           '<div class="callout info"><span class="co-ic">🗺️</span><div><p>内置 <b>WGS-84 ↔ GCJ-02</b> 坐标转换：'
           '国内图源用 GCJ-02 对齐，切换图源不会把你的位置挪出 500 米。</p></div></div>',
           '<table class="doc-table"><thead><tr><th>圖源</th><th>說明</th></tr></thead><tbody>'
           '<tr><td>高德地圖 / 高德衛星</td><td>國內定位無縫對齊（GCJ-02）</td></tr>'
           '<tr><td><b>向量地圖</b></td><td>用戶端即時算繪，資料量小、縮放清晰，<b>無需 API Key</b>，WGS-84</td></tr>'
           '<tr><td>Carto 深色 / 淺色 / 航行者</td><td>線上圖磚</td></tr>'
           '<tr><td>OSM 標準 / 人道</td><td>線上圖磚</td></tr>'
           '<tr><td>OpenTopo 地形</td><td>等高線地形</td></tr>'
           '<tr><td>Esri 街道 / 影像</td><td>線上圖磚</td></tr>'
           '</tbody></table>'
           '<div class="callout info"><span class="co-ic">🗺️</span><div><p>內建 <b>WGS-84 ↔ GCJ-02</b> 座標轉換：'
           '國內圖磚用 GCJ-02 對齊，切換圖源不會把你的位置挪出 500 公尺。</p></div></div>',
           '<table class="doc-table"><thead><tr><th>Source</th><th>Notes</th></tr></thead><tbody>'
           '<tr><td>AMap / AMap satellite</td><td>aligns perfectly with Chinese positioning (GCJ-02)</td></tr>'
           '<tr><td><b>Vector map</b></td><td>rendered on the client — small payload, crisp at any zoom, '
           '<b>no API key</b>, WGS-84</td></tr>'
           '<tr><td>Carto light / dark / voyager</td><td>raster tiles</td></tr>'
           '<tr><td>OSM standard / humanitarian</td><td>raster tiles</td></tr>'
           '<tr><td>OpenTopo</td><td>contour terrain</td></tr>'
           '<tr><td>Esri street / imagery</td><td>raster tiles</td></tr>'
           '</tbody></table>'
           '<div class="callout info"><span class="co-ic">🗺️</span><div><p>Built-in <b>WGS-84 ↔ GCJ-02</b> '
           'conversion: Chinese sources are aligned to GCJ-02, so switching layers never shifts your '
           'position by 500 metres.</p></div></div>')),
        (T('界面风格与离线地图', '介面風格與離線地圖', 'Look, feel and offline maps'),
         T('<ul>'
           '<li><b>UI 2.0</b>：以地图为基底的新布局，「显示设置」里可随时切回经典布局；'
           '材质可在<b>磨砂玻璃</b>与<b>云母</b>之间切换。</li>'
           '<li><b>主题</b>：颜色（17 个令牌）、图标、文字、背景图都能改，可导出成 JSON 分享；'
           '界面可缩放 85% ~ 130%。</li>'
           '<li><b>离线地图</b>（设置 → 显示 → 离线地图）：<b>下载范围 = 当前所见那一屏</b>，'
           '断点续传、单区域上限 20 万张（约 3 GB），断网、无信号也能看；'
           '还有「仅离线模式」——一个网络请求都不发。Web 版不提供下载（浏览器没有稳定可写目录）。</li>'
           '</ul>',
           '<ul>'
           '<li><b>UI 2.0</b>：以地圖為基底的新佈局，「顯示設定」裡可隨時切回經典佈局；'
           '材質可在<b>磨砂玻璃</b>與<b>雲母</b>之間切換。</li>'
           '<li><b>主題</b>：顏色（17 個權杖）、圖示、文字、背景圖都能改，可匯出成 JSON 分享；'
           '介面可縮放 85% ~ 130%。</li>'
           '<li><b>離線地圖</b>（設定 → 顯示 → 離線地圖）：<b>下載範圍 = 當前所見那一屏</b>，'
           '斷點續傳、單區域上限 20 萬張（約 3 GB），斷網、無訊號也能看；'
           '還有「僅離線模式」——一個網路請求都不發。Web 版不提供下載（瀏覽器沒有穩定可寫目錄）。</li>'
           '</ul>',
           '<ul>'
           '<li><b>UI 2.0</b>: a map-first layout you can leave at any time from Display settings, back '
           'to the classic one; materials switch between <b>frosted glass</b> and <b>mica</b>.</li>'
           '<li><b>Themes</b>: colours (17 tokens), icons, text and background image are all editable, '
           'exported as JSON to share; UI scaling runs 85%–130%.</li>'
           '<li><b>Offline maps</b> (Settings → Display → Offline map): the <b>download area is exactly '
           'what you see on screen</b>, resumable, capped at 200k tiles (~3 GB) per region, and it keeps '
           'working with no network at all; “offline only” sends zero requests. The web build has no '
           'download (browsers have no stable writable directory).</li>'
           '</ul>')),
    ]),
    # ───────── 7 台站与筛选 ─────────
    dict(id='stations', title=T('台站与筛选', '臺站與篩選', 'Stations & Filtering'), sections=[
        (T('先过滤，再看列表', '先過濾，再看列表', 'Filter first, then browse'),
         T('<p>两层过滤决定你「收到什么」，都在连接相关设置里：</p>'
           '<ul>'
           '<li><b>范围过滤</b>：<code>r/纬度/经度/半径</code>，默认半径 <b>300 km</b>（最小 10 km）；'
           '改完点「保存并应用」生效。</li>'
           '<li><b>接收偏好</b>：按国家/地区分组，或精确到某个呼号 —— 在范围之外也能收指定呼号。</li>'
           '<li>向导里选的「接收地区」就是这里的国家/地区勾选，不勾 = 全部接收。</li>'
           '</ul>'
           '<p>列表侧再做<b>展示筛选</b>：状态（在线/移动/静止）、APRS 类型（车载/固定/中继/气象）、'
           '软件（APRSlocus）、设备类别与具体型号、收藏；搜索支持呼号/类型/备注/网格，台站多也不卡。</p>',
           '<p>兩層過濾決定你「收到什麼」，都在連線相關設定裡：</p>'
           '<ul>'
           '<li><b>範圍過濾</b>：<code>r/緯度/經度/半徑</code>，預設半徑 <b>300 km</b>（最小 10 km）；'
           '改完點「儲存並套用」生效。</li>'
           '<li><b>接收偏好</b>：按國家/地區分組，或精確到某個呼號 —— 在範圍之外也能收指定呼號。</li>'
           '<li>引導裡選的「接收地區」就是這裡的國家/地區勾選，不勾 = 全部接收。</li>'
           '</ul>'
           '<p>列表側再做<b>顯示篩選</b>：狀態（線上/移動/靜止）、APRS 類型（車載/固定/中繼/氣象）、'
           '軟體（APRSLocus）、裝置類別與具體型號、收藏；搜尋支援呼號/類型/備註/網格，臺站多也不卡。</p>',
           '<p>Two layers decide what you <b>receive</b>, both under connection settings:</p>'
           '<ul>'
           '<li><b>Range filter</b>: <code>r/lat/lng/radius</code>, <b>300 km</b> by default '
           '(10 km minimum); press Save &amp; apply after changing it.</li>'
           '<li><b>Receive preferences</b>: group by country/region, or pin exact callsigns — those '
           'arrive even from outside the range.</li>'
           '<li>The “receive area” from the wizard is this same country/region tick list; nothing '
           'ticked = receive everything.</li>'
           '</ul>'
           '<p>The list adds <b>display filters</b> on top: status (online/moving/static), APRS type '
           '(mobile/fixed/relays/weather), software (APRSlocus), device class and exact model, '
           'favourites; search covers callsign/type/comment/grid and stays fast with many stations.</p>')),
        (T('设备识别与详情跳转', '裝置識別與詳情跳轉', 'Device identification and look-ups'),
         T('<ul>'
           '<li><b>官方设备库</b>：接入 aprs.org 的 <code>aprsorg/aprs-deviceid</code>（tocalls），'
           '按报文目的呼号识别<b>厂商 + 型号 + 设备类别</b>（车台/手台/跟踪器/App/iGate/中继/气象站…），'
           '内置快照 + 联网自动更新。</li>'
           '<li><b>同款 APRSlocus 台站</b>自动标记，可看到版本、电量等专属信息；FMO 台站自动识别。</li>'
           '<li><b>详情页可跳转</b>：QRZ 呼号库、aprs.fi 看轨迹、APRS.tv。</li>'
           '<li><b>符号</b>：37 个官方符号表、3571 个标准图标，官方 PNG 优先、Material 图标兜底。</li>'
           '</ul>',
           '<ul>'
           '<li><b>官方裝置資料庫</b>：接入 aprs.org 的 <code>aprsorg/aprs-deviceid</code>（tocalls），'
           '按封包目的呼號識別<b>廠牌 + 型號 + 裝置類別</b>（車臺/手臺/追蹤器/App/iGate/中繼/氣象站…），'
           '內建快取 + 聯網自動更新。</li>'
           '<li><b>同款 APRSLocus 臺站</b>自動標記，可看到版本、電量等專屬資訊；FMO 臺站自動識別。</li>'
           '<li><b>詳情頁可跳轉</b>：QRZ 呼號庫、aprs.fi 看軌跡、APRS.tv。</li>'
           '<li><b>符號</b>：37 個官方符號表、3571 個標準圖示，官方 PNG 優先、Material 圖示備援。</li>'
           '</ul>',
           '<ul>'
           '<li><b>Official device library</b>: aprs.org’s <code>aprsorg/aprs-deviceid</code> (tocalls) '
           'identifies <b>vendor + model + class</b> from the packet’s destination callsign '
           '(mobile/portable/tracker/app/iGate/relay/weather station…) with a bundled snapshot plus '
           'online updates.</li>'
           '<li><b>Other APRSlocus stations</b> are marked automatically (version, battery, …); FMO '
           'stations are recognised too.</li>'
           '<li><b>Detail page jumps out</b> to the QRZ callsign database, aprs.fi for trails, and '
           'APRS.tv.</li>'
           '<li><b>Symbols</b>: 37 official tables, 3571 standard icons — official PNG first, Material '
           'icons as fallback.</li>'
           '</ul>')),
    ]),
    # ───────── 8 导出 · 备份 · 历史轨迹 ─────────
    dict(id='data', title=T('导出 · 备份 · 历史轨迹', '匯出 · 備份 · 歷史軌跡',
                            'Export · Backup · Track History'), sections=[
        (T('导出 ADIF', '匯出 ADIF', 'ADIF export'),
         T('<p>设置里「<b>导出 ADIF</b>」一键导出通联日志 —— ADIF 是业余无线电通用的日志交换格式，'
           '频率可自定义，导出后可直接导入其它日志软件。</p>',
           '<p>設定裡「<b>匯出 ADIF</b>」一鍵匯出通聯日誌 —— ADIF 是業餘無線電通用的日誌交換格式，'
           '頻率可自訂，匯出後可直接匯入其它日誌軟體。</p>',
           '<p><b>Export ADIF</b> in Settings writes your contact log in one tap — ADIF is the standard '
           'amateur-radio log interchange format, the frequency is configurable, and other logging '
           'programs import it directly.</p>')),
        (T('备份与恢复', '備份與恢復', 'Backup & restore'),
         T('<ul>'
           '<li><b>一个 JSON 装下</b>：设置配置（电台、信标、地图、筛选、数据来源、服务器等）与本地数据'
           '导出成一个文件；换机或重装后导入即可，导入后需重启应用生效。</li>'
           '<li><b>白名单导入</b>：只认该分组白名单内的键，来路不明的 JSON 改不了内部设置；'
           '更高版本的备份会被拒绝并提示先升级。</li>'
           '<li><b>平台差异</b>：Android 用系统文件选择器（导出到下载目录）；桌面端选 Documents；'
           'Web 版走剪贴板。读取上限 32 MB。</li>'
           '</ul>',
           '<ul>'
           '<li><b>一個 JSON 裝下</b>：設定組態（電臺、信標、地圖、篩選、資料來源、伺服器等）與本地資料'
           '匯出成一個檔案；換機或重裝後匯入即可，匯入後需重啟應用生效。</li>'
           '<li><b>白名單匯入</b>：只認該分組白名單內的鍵，來路不明的 JSON 改不了內部設定；'
           '更高版本的備份會被拒絕並提示先升級。</li>'
           '<li><b>平台差異</b>：Android 用系統檔案選擇器（匯出到下載目錄）；桌面端選 Documents；'
           'Web 版走剪貼簿。讀取上限 32 MB。</li>'
           '</ul>',
           '<ul>'
           '<li><b>One JSON for everything</b>: settings (station, beacon, map, filters, data sources, '
           'server…) plus local data export into a single file; import it after a reinstall — the app '
           'asks for a restart to apply everything.</li>'
           '<li><b>Whitelisted import</b>: only keys inside that group’s whitelist are accepted, so a '
           'file from someone else cannot rewrite internal preferences; a backup from a newer version '
           'is rejected with “update the app first”.</li>'
           '<li><b>Platform differences</b>: Android uses the system picker (Downloads), desktop saves '
           'to Documents, web uses the clipboard. Reading is capped at 32 MB.</li>'
           '</ul>')),
        (T('历史轨迹与回放', '歷史軌跡與回放', 'Track history and playback'),
         T('<ul>'
           '<li><b>按天落盘</b>：每个本地日期一个文件（<code>tracklog/YYYY-MM-DD.json</code>），'
           '记录经纬度、速度、航向、海拔、精度，退出重进还在。</li>'
           '<li><b>每天一屏</b>：总里程、平均与最高速度、移动时长、轨迹点数；可按天删除或一键清空。'
           '「移动时长」只累计确实在动的段 —— 中途停车吃饭的两小时不会被算进去。</li>'
           '<li><b>点进某天可回放</b>：底图与主地图同一套（同缓存、同坐标纠偏），'
           '轨迹随播放生长、可拖进度、0.5× ~ 4× 倍速、可跟随视角；超过 45 秒的停顿自动快进。</li>'
           '<li>它与地图上那条「我的轨迹」<b>刻意分开</b>：屏幕轨迹只服务本次显示，退出即失。</li>'
           '</ul>',
           '<ul>'
           '<li><b>按天落盤</b>：每個本地日期一個檔案（<code>tracklog/YYYY-MM-DD.json</code>），'
           '記錄經緯度、速度、航向、海拔、精度，退出重進還在。</li>'
           '<li><b>每天一屏</b>：總里程、平均與最高速度、移動時長、軌跡點數；可按天刪除或一鍵清空。'
           '「移動時長」只累計確實在動的段 —— 中途停車吃飯的兩小時不會被算進去。</li>'
           '<li><b>點進某天可回放</b>：底圖與主地圖同一套（同快取、同座標校正），'
           '軌跡隨播放生長、可拖進度、0.5× ~ 4× 倍速、可跟隨視角；超過 45 秒的停頓自動快進。</li>'
           '<li>它與地圖上那條「我的軌跡」<b>刻意分開</b>：螢幕軌跡只服務本次顯示，退出即失。</li>'
           '</ul>',
           '<ul>'
           '<li><b>Saved per local day</b> (<code>tracklog/YYYY-MM-DD.json</code>) with lat/lng, speed, '
           'course, altitude and accuracy — it survives a restart.</li>'
           '<li><b>One screen per day</b>: total distance, average and top speed, moving time and point '
           'count; delete a day or clear everything. “Moving time” only counts segments that genuinely '
           'moved — a two-hour lunch stop is not billed as driving.</li>'
           '<li><b>Tap into a day to replay it</b>: same tile stack as the main map (same cache, same '
           'datum correction), the line grows as it plays, draggable progress, 0.5×–4× speed and a follow '
           'view; stops over 45 s fast-forward.</li>'
           '<li>It is <b>deliberately separate</b> from the on-screen “my track”, which only serves this '
           'session and disappears on exit.</li>'
           '</ul>')),
    ]),
    # ───────── 9 桌面组件与短波 ─────────
    dict(id='widgets', title=T('桌面组件与短波', '桌面小組件與短波', 'Widgets & HF Propagation'), sections=[
        (T('三套桌面组件', '三套桌面小組件', 'Three home-screen widgets'),
         T('<table class="doc-table"><thead><tr><th>组件</th><th>内容</th></tr></thead><tbody>'
           '<tr><td><b>天气</b></td><td>天气主区（图标、温度、现象、今日高低温）+ 指标格 + 火腿建议；'
           '按主屏空间自动切换 4 档布局（主档 / 竖长 / 紧凑 / 单行）</td></tr>'
           '<tr><td><b>短波</b></td><td>各波段「日 → 夜」条件色带，一眼看出现在该用哪一段</td></tr>'
           '<tr><td><b>系统状态</b></td><td>链路、定位与计数的实时快照</td></tr>'
           '</tbody></table>'
           '<div class="callout info"><span class="co-ic">📲</span><div><p>组件<b>不自己联网</b>：'
           '应用把已计算、已本地化的快照单向推给原生渲染（和风天气密钥只在应用侧，不会外泄）。'
           '装好后先打开一次应用；升级后若空白，打开应用刷新即可。</p></div></div>',
           '<table class="doc-table"><thead><tr><th>小組件</th><th>內容</th></tr></thead><tbody>'
           '<tr><td><b>天氣</b></td><td>天氣主區（圖示、溫度、現象、今日高低溫）+ 指標格 + 火腿建議；'
           '按主螢幕空間自動切換 4 檔佈局（主檔 / 豪長 / 緊湊 / 單行）</td></tr>'
           '<tr><td><b>短波</b></td><td>各波段「日 → 夜」條件色帶，一眼看出現在該用哪一段</td></tr>'
           '<tr><td><b>系統狀態</b></td><td>鏈路、定位與計數的即時快照</td></tr>'
           '</tbody></table>'
           '<div class="callout info"><span class="co-ic">📲</span><div><p>小組件<b>不自己連線</b>：'
           '應用把已計算、已本地化的快照單向推給原生算繪（和風天氣金鑰只在應用側，不會外洩）。'
           '裝好後先打開一次應用；升級後若空白，打開應用刷新即可。</p></div></div>',
           '<table class="doc-table"><thead><tr><th>Widget</th><th>Contents</th></tr></thead><tbody>'
           '<tr><td><b>Weather</b></td><td>hero block (icon, temperature, condition, today’s high/low) + '
           'metric cells + ham advice; four layouts chosen from the space you give it (main / tall / '
           'compact / single row)</td></tr>'
           '<tr><td><b>HF</b></td><td>day → night condition bands per pair, so you can see at a glance '
           'which band to try now</td></tr>'
           '<tr><td><b>System status</b></td><td>a live snapshot of link, positioning and counters</td></tr>'
           '</tbody></table>'
           '<div class="callout info"><span class="co-ic">📲</span><div><p>The widgets <b>never open a '
           'connection themselves</b>: the app pushes an already-computed, already-localised snapshot to '
           'native code (the QWeather key never leaves the app side). Open the app once after adding '
           'them; if they go blank after an update, opening the app refreshes them.</p></div></div>')),
        (T('短波传播面板', '短波傳播面板', 'HF propagation panel'),
         T('<ul>'
           '<li><b>数据来源</b>：<code>hamqsl.com</code>（N0NBH 整理，业余界事实标准），'
           '源站约每小时更新，应用缓存 <b>30 分钟</b>。</li>'
           '<li><b>看什么</b>：SFI / Kp / A 指数、黑子、X 射线、太阳风，'
           '四个波段对的<b>日 / 夜</b>条件一目了然；另有 6m 波段预测。</li>'
           '<li><b>诚实说明</b>：hamqsl 的条件是<b>全球/区域平均</b>，不是你所在地的实测值，'
           '出门前请结合本地情况判断。</li>'
           '</ul>',
           '<ul>'
           '<li><b>資料來源</b>：<code>hamqsl.com</code>（N0NBH 整理，業餘界事實標準），'
           '來源約每小時更新，應用快取 <b>30 分鐘</b>。</li>'
           '<li><b>看什麼</b>：SFI / Kp / A 指數、黑子、X 射線、太陽風，'
           '四個波段對的<b>日 / 夜</b>條件一目了然；另有 6m 波段預測。</li>'
           '<li><b>誠實說明</b>：hamqsl 的條件是<b>全球/區域平均</b>，不是你所在地的實測值，'
           '出門前請結合本地情況判斷。</li>'
           '</ul>',
           '<ul>'
           '<li><b>Source</b>: <code>hamqsl.com</code> (compiled by N0NBH, the de-facto standard in '
           'amateur radio); the endpoint updates hourly and the app caches it for <b>30 minutes</b>.</li>'
           '<li><b>What you see</b>: SFI / Kp / A index, sunspots, X-rays, solar wind, plus day/night '
           'conditions for four band pairs at a glance, and a 6 m forecast.</li>'
           '<li><b>Honest note</b>: hamqsl conditions are a <b>global/regional average</b>, not a '
           'measurement of your location — combine them with local knowledge.</li>'
           '</ul>')),
    ]),
    # ───────── 10 设置参考 ─────────
    dict(id='settings', title=T('设置参考', '設定參考', 'Settings Reference'), sections=[
        (T('八个分组', '八個分組', 'The eight categories'),
         T('<p>「设置」页顶部是八个分组卡片，每张点进去是一个子页面：</p>'
           '<table class="doc-table"><thead><tr><th>分组</th><th>副标题</th><th>主要内容</th></tr></thead><tbody>'
           '<tr><td><b>电台</b></td><td>呼号 · SSID · 符号</td><td>身份、备注、符号与我的展示</td></tr>'
           '<tr><td><b>定位上报</b></td><td>GPS · 信标 · 手动定位</td><td>定位来源、上报间隔、速度分档、手动定位</td></tr>'
           '<tr><td><b>连接</b></td><td>服务器 · 过滤范围</td><td>APRS-IS 服务器与 Passcode、数据来源、'
           '过滤半径与接收偏好、网关</td></tr>'
           '<tr><td><b>显示</b></td><td>坐标 · 主题</td><td>地图类型、坐标显示、UI 2.0、材质、离线地图、语言与缩放</td></tr>'
           '<tr><td><b>设备</b></td><td>电台设备 · 待开放</td><td>连接你的电台设备（TNC / 音频 / PKWDWPL 绑定与自检）</td></tr>'
           '<tr><td><b>数据</b></td><td>清除本地数据</td><td>本地数据管理与清除</td></tr>'
           '<tr><td><b>高级</b></td><td>实验室 · 开发者</td><td>实验性功能、调试与测试、<b>重新运行设置向导</b></td></tr>'
           '<tr><td><b>更新</b></td><td>检查新版本</td><td>GitHub / GitCode 双渠道，按平台分流，可装历史版本</td></tr>'
           '</tbody></table>',
           '<p>「設定」頁頂部是八個分組卡片，每張點進去是一個子頁面：</p>'
           '<table class="doc-table"><thead><tr><th>分組</th><th>副標題</th><th>主要內容</th></tr></thead><tbody>'
           '<tr><td><b>電臺</b></td><td>呼號 · SSID · 符號</td><td>身份、備註、符號與我的展示</td></tr>'
           '<tr><td><b>定位上報</b></td><td>GPS · 信標 · 手動定位</td><td>定位來源、上報間隔、速度分檔、手動定位</td></tr>'
           '<tr><td><b>連線</b></td><td>伺服器 · 過濾範圍</td><td>APRS-IS 伺服器與 Passcode、資料來源、'
           '過濾半徑與接收偏好、閘道</td></tr>'
           '<tr><td><b>顯示</b></td><td>座標 · 主題</td><td>地圖類型、座標顯示、UI 2.0、材質、離線地圖、語言與縮放</td></tr>'
           '<tr><td><b>裝置</b></td><td>電臺裝置 · 待開放</td><td>連接你的電臺裝置（TNC / 音訊 / PKWDWPL 綁定與自檢）</td></tr>'
           '<tr><td><b>資料</b></td><td>清除本地資料</td><td>本地資料管理與清除</td></tr>'
           '<tr><td><b>進階</b></td><td>實驗室 · 開發者</td><td>實驗性功能、除錯與測試、<b>重新執行設定引導</b></td></tr>'
           '<tr><td><b>更新</b></td><td>檢查新版本</td><td>GitHub / GitCode 雙管道，按平台分流，可裝歷史版本</td></tr>'
           '</tbody></table>',
           '<p>The Settings page opens with eight category cards, each leading to its own page:</p>'
           '<table class="doc-table"><thead><tr><th>Category</th><th>Subtitle</th><th>Contains</th></tr></thead><tbody>'
           '<tr><td><b>Station</b></td><td>Callsign · SSID · Symbol</td><td>identity, comment, symbol, my display</td></tr>'
           '<tr><td><b>Beacon</b></td><td>GPS · Beacon · Manual location</td><td>location source, interval, speed '
           'tiers, manual fix</td></tr>'
           '<tr><td><b>Connection</b></td><td>Server · Filter range</td><td>APRS-IS server and Passcode, data '
           'sources, filter radius and receive preferences, gateway</td></tr>'
           '<tr><td><b>Display</b></td><td>Coordinates · Theme</td><td>map type, coordinate display, UI 2.0, '
           'materials, offline maps, language and scaling</td></tr>'
           '<tr><td><b>Device</b></td><td>Radio device · to be opened</td><td>connect your radio (TNC / audio / '
           'PKWDWPL binding and self-tests)</td></tr>'
           '<tr><td><b>Data</b></td><td>Clear local data</td><td>local data management and clearing</td></tr>'
           '<tr><td><b>Advanced</b></td><td>Lab · Developer</td><td>experimental features, debug &amp; tests, '
           '<b>re-run the setup wizard</b></td></tr>'
           '<tr><td><b>Update</b></td><td>Check for new versions</td><td>GitHub / GitCode channels, per-platform '
           'downloads, historical versions</td></tr>'
           '</tbody></table>')),
        (T('分组之外的六个入口', '分組之外的六個入口', 'Six entries outside the categories'),
         T('<p>分组卡片下方还有一排直达入口：</p>'
           '<ul>'
           '<li><b>荣誉墙</b> —— 成就与徽章，每枚徽章都写明获得条件；可选一枚在主页常驻展示。</li>'
           '<li><b>翻译设置</b> —— 翻译接口、目标语言与自动翻译开关。</li>'
           '<li><b>导出 ADIF</b> —— 通联日志导出。</li>'
           '<li><b>主题</b> —— 颜色/图标/文字/背景图与 JSON 导出分享。</li>'
           '<li><b>历史轨迹</b> —— 按天的轨迹台账与回放。</li>'
           '<li><b>备份与恢复</b> —— 设置与数据的 JSON 导出导入。</li>'
           '</ul>',
           '<p>分組卡片下方還有一排直達入口：</p>'
           '<ul>'
           '<li><b>榮譽牆</b> —— 成就與徽章，每枚徽章都寫明獲得條件；可選一枚在首頁常駐展示。</li>'
           '<li><b>翻譯設定</b> —— 翻譯介面、目標語言與自動翻譯開關。</li>'
           '<li><b>匯出 ADIF</b> —— 通聯日誌匯出。</li>'
           '<li><b>主題</b> —— 顏色/圖示/文字/背景圖與 JSON 匯出分享。</li>'
           '<li><b>歷史軌跡</b> —— 按天的軌跡臺賬與回放。</li>'
           '<li><b>備份與恢復</b> —— 設定與資料的 JSON 匯出匯入。</li>'
           '</ul>',
           '<p>Below the cards sits a row of direct entries:</p>'
           '<ul>'
           '<li><b>Honor wall</b> — achievements and badges, each stating how to earn it; pick one to '
           'show on the home page.</li>'
           '<li><b>Translation settings</b> — endpoint, target languages, auto-translate.</li>'
           '<li><b>Export ADIF</b> — contact log export.</li>'
           '<li><b>Themes</b> — colours/icons/text/background plus JSON export to share.</li>'
           '<li><b>Track history</b> — the per-day ledger and playback.</li>'
           '<li><b>Backup &amp; restore</b> — JSON export/import of settings and data.</li>'
           '</ul>')),
    ]),
    # ───────── 11 桌面端与平台 ─────────
    dict(id='platform', title=T('平台差异', '平台差異', 'Platform Notes'), sections=[
        (T('Android / Windows / 其它', 'Android / Windows / 其它', 'Android / Windows / others'),
         T('<table class="doc-table"><thead><tr><th>能力</th><th>Android</th><th>Windows</th></tr></thead><tbody>'
           '<tr><td>APRS-IS 收发</td><td>✓</td><td>✓</td></tr>'
           '<tr><td>后台持续定位（前台服务）</td><td>✓</td><td>—（桌面无前台服务概念）</td></tr>'
           '<tr><td>蓝牙 TNC</td><td>✓（需蓝牙权限）</td><td>—（用 USB 串口 COM 口）</td></tr>'
           '<tr><td>USB 串口（OTG）</td><td>✓</td><td>✓（COM 口为独占设备，别被别的软件占着）</td></tr>'
           '<tr><td>音频 AFSK</td><td>✓（需录音权限；发射时拉满音量并暂停麦克风）</td><td>✓</td></tr>'
           '<tr><td>离线地图下载</td><td>✓</td><td>✓</td></tr>'
           '<tr><td>桌面小组件</td><td>✓（3 套）</td><td>—（Android 独有）</td></tr>'
           '<tr><td>WAV 文件模式</td><td colspan="2">所有平台可用：离线解码录音，或把报文导出成音频</td></tr>'
           '</tbody></table>'
           '<div class="callout warn"><span class="co-ic">⚠️</span><div><p>Web 版是「能看、能连」的轻量形态：'
           '不提供离线地图下载，备份走剪贴板；实时音频在不支持的平台会提示，仍可用 WAV 模式。</p></div></div>',
           '<table class="doc-table"><thead><tr><th>能力</th><th>Android</th><th>Windows</th></tr></thead><tbody>'
           '<tr><td>APRS-IS 收發</td><td>✓</td><td>✓</td></tr>'
           '<tr><td>背景持續定位（前景服務）</td><td>✓</td><td>—（桌面無前景服務概念）</td></tr>'
           '<tr><td>藍牙 TNC</td><td>✓（需藍牙權限）</td><td>—（用 USB 序列埠 COM 埠）</td></tr>'
           '<tr><td>USB 序列埠（OTG）</td><td>✓</td><td>✓（COM 埠為獨佔裝置，別被別的軟體佔著）</td></tr>'
           '<tr><td>音訊 AFSK</td><td>✓（需錄音權限；發射時拉滿音量並暫停麥克風）</td><td>✓</td></tr>'
           '<tr><td>離線地圖下載</td><td>✓</td><td>✓</td></tr>'
           '<tr><td>桌面小組件</td><td>✓（3 套）</td><td>—（Android 獨有）</td></tr>'
           '<tr><td>WAV 檔案模式</td><td colspan="2">所有平台可用：離線解碼錄音，或把封包匯出成音訊</td></tr>'
           '</tbody></table>'
           '<div class="callout warn"><span class="co-ic">⚠️</span><div><p>Web 版是「能看、能連」的輕量形態：'
           '不提供離線地圖下載，備份走剪貼簿；即時音訊在不支援的平台會提示，仍可用 WAV 模式。</p></div></div>',
           '<table class="doc-table"><thead><tr><th>Capability</th><th>Android</th><th>Windows</th></tr></thead><tbody>'
           '<tr><td>APRS-IS send/receive</td><td>✓</td><td>✓</td></tr>'
           '<tr><td>Continuous background positioning (foreground service)</td><td>✓</td><td>— (no such concept on desktop)</td></tr>'
           '<tr><td>Bluetooth TNC</td><td>✓ (Bluetooth permission)</td><td>— (use a USB serial COM port)</td></tr>'
           '<tr><td>USB serial (OTG)</td><td>✓</td><td>✓ (COM ports are exclusive — keep other software off them)</td></tr>'
           '<tr><td>Audio AFSK</td><td>✓ (mic permission; TX maxes volume and mutes the mic)</td><td>✓</td></tr>'
           '<tr><td>Offline map download</td><td>✓</td><td>✓</td></tr>'
           '<tr><td>Home-screen widgets</td><td>✓ (three of them)</td><td>— (Android only)</td></tr>'
           '<tr><td>WAV file mode</td><td colspan="2">available everywhere: decode a recording offline, '
           'or export packets as audio</td></tr>'
           '</tbody></table>'
           '<div class="callout warn"><span class="co-ic">⚠️</span><div><p>The web build is the lightweight '
           '“view and connect” shape: no offline map download, backup via clipboard; realtime audio warns '
           'where unsupported while WAV mode still works.</p></div></div>')),
    ]),
    # ───────── 12 故障排查 ─────────
    dict(id='trouble', title=T('故障排查', '故障排除', 'Troubleshooting'), sections=[
        (T('先用这三个入口', '先用這三個入口', 'Start with these three'),
         T('<ol class="m-steps">'
           '<li><b>链路状态卡</b>（主页顶部）：连接状态、收发计数、服务器返回值 —— '
           '<code>unverified</code> 就是 Passcode 问题。</li>'
           '<li><b>链路自检</b>（设备页）：TNC 协议回路、AFSK 调制解调回路，一键分层定位。</li>'
           '<li><b>数据包页</b>：看原始报文有没有进来；能收到但不上图，多是筛选或坐标问题。</li>'
           '</ol>',
           '<ol class="m-steps">'
           '<li><b>鏈路狀態卡</b>（首頁頂部）：連線狀態、收發計數、伺服器回傳值 —— '
           '<code>unverified</code> 就是 Passcode 問題。</li>'
           '<li><b>鏈路自檢</b>（裝置頁）：TNC 協定回路、AFSK 調變解調回路，一鍵分層定位。</li>'
           '<li><b>封包頁</b>：看原始封包有沒有進來；能收到但不上圖，多是篩選或座標問題。</li>'
           '</ol>',
           '<ol class="m-steps">'
           '<li><b>The link status card</b> (top of the home page): state, counters and what the server '
           'returned — <code>unverified</code> means a Passcode problem.</li>'
           '<li><b>Link self-test</b> (device page): TNC protocol loopback and the AFSK modulate/demodulate '
           'loop, layer by layer in one tap.</li>'
           '<li><b>Packets tab</b>: see whether raw packets arrive at all; received but never plotted is '
           'usually a filter or coordinate issue.</li>'
           '</ol>')),
        (T('还是解决不了？', '還是解決不了？', 'Still stuck?'),
         T('<ul>'
           '<li><b>常见问题</b>：23 题按主题分组的完整问答 → <a href="faq.html">帮助中心</a></li>'
           '<li><b>更新记录</b>：你遇到的可能已在新版本修掉 → '
           '<a href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">GitHub Releases</a></li>'
           '<li><b>反馈</b>：提 Issue 或进 QQ 交流群，附上「数据包页」的原始报文与链路日志最快定位 → '
           '<a href="https://github.com/dariondong/APRSLocus/issues" target="_blank" rel="noopener">Issues</a></li>'
           '</ul>',
           '<ul>'
           '<li><b>常見問題</b>：23 題按主題分組的完整問答 → <a href="faq.html">幫助中心</a></li>'
           '<li><b>更新記錄</b>：你遇到的可能已在新版本修掉 → '
           '<a href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">GitHub Releases</a></li>'
           '<li><b>回饋</b>：提 Issue 或進 QQ 交流群，附上「封包頁」的原始封包與鏈路日誌最快定位 → '
           '<a href="https://github.com/dariondong/APRSLocus/issues" target="_blank" rel="noopener">Issues</a></li>'
           '</ul>',
           '<ul>'
           '<li><b>FAQ</b>: 23 questions grouped by topic → <a href="faq.html">Help Center</a></li>'
           '<li><b>Release notes</b>: what bit you may already be fixed → '
           '<a href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">GitHub Releases</a></li>'
           '<li><b>Feedback</b>: open an issue or join the QQ group; attaching the raw packet from the '
           'Packets tab and the link log gets you the fastest diagnosis → '
           '<a href="https://github.com/dariondong/APRSLocus/issues" target="_blank" rel="noopener">Issues</a></li>'
           '</ul>')),
    ]),
]


def esc(s):
    """文案是手写 HTML（含标签），不转义；这里只做存在性自检用。"""
    return s


def render_head(lang):
    p = PAGES[lang][2]
    h = HEAD[lang]
    u = UI[lang]
    hreflangs = '\n'.join(
        '    <link rel="alternate" hreflang="%s" href="%s/%s">' % (fl, SITE, suf)
        for fl, suf in (('zh-CN', 'manual.html'), ('zh-TW', 'zh-TW/manual.html'),
                        ('en', 'en/manual.html'), ('x-default', 'manual.html')))
    return '''<!DOCTYPE html>
<html lang="{html_lang}">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title}</title>
<meta name="description" content="{desc}">
<meta name="theme-color" content="#f3f6fd">
<meta property="og:type" content="article">
<meta property="og:site_name" content="APRSlocus">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{desc}">
<meta property="og:url" content="{site}/{suffix}">
<meta property="og:image" content="{site}/assets/logo.png">
<meta property="og:image:width" content="192">
<meta property="og:image:height" content="192">
<meta property="og:locale" content="{locale}">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="{title}">
<meta name="twitter:description" content="{desc}">
<meta name="twitter:image" content="{site}/assets/logo.png">
<link rel="canonical" href="{site}/{suffix}">
{hreflangs}
<link rel="icon" type="image/png" href="{p}assets/favicon.png">
<link rel="stylesheet" href="{p}css/style.css?v=4">
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
{jsonld}
</script>
<noscript><style>.reveal{{opacity:1;transform:none}}.manual-tools{{display:none}}</style></noscript>
</head>
<body>
'''.format(
        html_lang=PAGES[lang][1], title=h['title'], desc=h['desc'], site=SITE,
        suffix=PAGES[lang][3], locale={'zh': 'zh_CN', 'zh_TW': 'zh_TW', 'en': 'en_US'}[lang],
        hreflangs=hreflangs, p=p, jsonld=render_jsonld(lang))


def render_jsonld(lang):
    h = HEAD[lang]
    data = {
        '@context': 'https://schema.org',
        '@type': 'TechArticle',
        'name': h['title'],
        'description': h['desc'],
        'url': '%s/%s' % (SITE, PAGES[lang][3]),
        'inLanguage': {'zh': 'zh-CN', 'zh_TW': 'zh-TW', 'en': 'en'}[lang],
        'author': {'@type': 'Person', 'name': 'BG7LZQ (Darion)'},
        'publisher': {'@type': 'Organization', 'name': 'APRSlocus',
                      'logo': {'@type': 'ImageObject', 'url': SITE + '/assets/logo.png'}},
        'mainEntityOfPage': {'@type': 'WebPage', '@id': '%s/%s' % (SITE, PAGES[lang][3])},
        'breadcrumb': {
            '@type': 'BreadcrumbList',
            'itemListElement': [
                {'@type': 'ListItem', 'position': 1, 'name': 'APRSlocus',
                 'item': SITE + '/'},
                {'@type': 'ListItem', 'position': 2, 'name': h['h1'],
                 'item': '%s/%s' % (SITE, PAGES[lang][3])},
            ],
        },
    }
    return json.dumps(data, ensure_ascii=False, indent=2)


def render_body(lang):
    p = PAGES[lang][2]
    u = UI[lang]
    h = HEAD[lang]
    # 模板占位符不能内联条件表达式（.format 会把 {...} 当格式字段），这里预先算好
    faq_label = {'zh': '问答', 'zh_TW': '問答', 'en': 'FAQ'}[lang]
    back_label = {'zh': '回到顶部', 'zh_TW': '回到顶部', 'en': 'Back to top'}[lang]

    # 侧栏目录
    toc = '\n'.join(
        '        <a href="#%s">%s</a>' % (c['id'], c['title'][lang]) for c in CHAPTERS)

    # 搜索框 + 目录提示
    tools = '''  <div class="manual-tools reveal">
    <div class="faq-search">
      <i class="fa-solid fa-magnifying-glass" aria-hidden="true"></i>
      <input type="search" id="manualFilter" placeholder="{ph}" aria-label="{search}" autocomplete="off">
    </div>
    <p class="faq-nohit" id="manualNohit" hidden>{nohit}</p>
  </div>
'''.format(ph=h['ph'], search=u['search'],
           nohit={'zh': '没有匹配的章节，换个关键词试试。',
                  'zh_TW': '沒有符合的章節，換個關鍵詞試試。',
                  'en': 'No matching chapter — try another keyword.'}[lang])

    # 章节
    parts = []
    for c in CHAPTERS:
        secs = []
        for hh, body in c['sections']:
            secs.append('      <h3>%s</h3>\n      %s' % (hh[lang], body[lang]))
        parts.append('''  <section class="chapter reveal" id="{cid}">
    <h2>{title}</h2>
{sections}
  </section>'''.format(cid=c['id'], title=c['title'][lang], sections='\n'.join(secs)))

    return '''<div class="scroll-progress" id="scrollProgress"></div>

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
      <a href="{p}">{home}</a>
      <a href="{p}#features">{feat}</a>
      <a href="{p2}faq.html">{help}</a>
      <a href="manual.html" class="active">{manual}</a>
      <a class="nav-cta" href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">{dl}</a>
      <button class="theme-toggle" id="themeToggle" type="button" aria-pressed="false" aria-label="{theme}" title="{theme}" data-label-dark="{theme_off}" data-label-light="{theme}"><i class="fa-solid fa-moon" aria-hidden="true"></i></button>
      <span class="lang-switch-group"><a class="lang-switch{act_zh}" href="../manual.html" hreflang="zh-Hans">简中</a><a class="lang-switch{act_twh}" href="../zh-TW/manual.html" hreflang="zh-Hant">繁中</a><a class="lang-switch{act_en}" href="../en/manual.html" hreflang="en">EN</a></span>
    </nav>
    <button class="nav-burger" id="navBurger" aria-label="{burger}" aria-expanded="false">
      <span></span><span></span><span></span>
    </button>
  </div>
</header>

<main id="main">
<a class="skip-link" href="#main">{skip}</a>

<section class="section" id="manual">
  <div class="section-head reveal">
    <h1>{h1}</h1>
    <p>{lead}</p>
  </div>

{tools}

  <div class="manual-layout">
    <nav class="manual-nav reveal" aria-label="{toc}">
      <div class="mn-title">{toc}</div>
{toc_items}
    </nav>
    <div class="manual-body">
{chapters}
    </div>
  </div>
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
        <a href="{p}">{foot_home}</a>
        <a href="{p}#features">{feat}</a>
        <a href="{p}#faq">{faq_label}</a>
        <a href="{p2}faq.html">{foot_help}</a>
        <a href="manual.html">{foot_manual}</a>
        <a href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">Releases</a>
      </div>
    </div>
    <div class="footer-bottom">
      <span>© <span id="year">2026</span> BG7LZQ (Darion) · <a href="https://github.com/dariondong/APRSLocus/blob/main/LICENSE" target="_blank" rel="noopener">GPL-3.0</a> · <a href="{p}terms.html">{terms}</a></span>
      <span class="disclaimer">{disclaimer}</span>
    </div>
  </div>
</footer>

<a class="backtop" id="backTop" href="#manual" aria-label="{back_label}">
  <svg class="backtop-ring" viewBox="0 0 40 40">
    <circle class="ring-bg" cx="20" cy="20" r="17"/>
    <circle class="ring-fg" id="ringFg" cx="20" cy="20" r="17"/>
  </svg>
  <svg class="backtop-arrow" viewBox="0 0 24 24"><path d="M12 5l7 7-1.4 1.4L13 8.8V20h-2V8.8l-4.6 4.6L5 12l7-7z"/></svg>
</a>

<script src="{p}js/main.js"></script>
<script>
/* 手册专属：章节搜索 + 侧栏 scrollspy（无 JS 时正文照常可读） */
(function () {{
  "use strict";
  var input = document.getElementById('manualFilter');
  var nohit = document.getElementById('manualNohit');
  var chapters = Array.prototype.slice.call(document.querySelectorAll('.chapter'));

  if (input) {{
    input.addEventListener('input', function () {{
      var kw = input.value.trim().toLowerCase();
      var hits = 0;
      chapters.forEach(function (sec) {{
        var ok = !kw || (sec.textContent || '').toLowerCase().indexOf(kw) !== -1;
        sec.hidden = !ok;
        if (ok) hits++;
      }});
      if (nohit) nohit.hidden = hits !== 0;
    }});
  }}

  // 侧栏高亮：当前可见章节
  var tocLinks = Array.prototype.slice.call(document.querySelectorAll('.manual-nav a'));
  if ('IntersectionObserver' in window && tocLinks.length) {{
    var io = new IntersectionObserver(function (entries) {{
      entries.forEach(function (e) {{
        if (!e.isIntersecting) return;
        tocLinks.forEach(function (a) {{
          a.classList.toggle('active', a.getAttribute('href') === '#' + e.target.id);
        }});
      }});
    }}, {{rootMargin: '-30% 0px -60% 0px'}});
    chapters.forEach(function (s) {{ io.observe(s); }});
  }}
}})();
</script>
</body>
</html>
'''.format(
        p=p, p2=p, home=u['home'], feat=u['feat'], help=u['help'], manual=u['manual'],
        dl=u['dl'], theme=u['theme'], theme_off=u['theme_off'], burger=u['burger'],
        skip=u['skip'], toc=u['toc'], h1=h['h1'], lead=h['lead'], tools=tools,
        toc_items=toc, chapters='\n'.join(parts),
        foot_home=u['foot_home'], foot_help=u['foot_help'], foot_manual=u['foot_manual'],
        terms=u['terms'], disclaimer=u['disclaimer'],
        act_zh=' active' if lang == 'zh' else '',
        act_twh=' active' if lang == 'zh_TW' else '',
        act_en=' active' if lang == 'en' else '',
        search=u['search'], faq_label=faq_label, back_label=back_label)


def main():
    # 自检 1：三语文案必须齐全且非空（T() 漏写会在渲染时 KeyError/空串）
    for c in CHAPTERS:
        assert c['id'], 'chapter missing id'
        for f in ('title',):
            for l in LANGS:
                assert c[f].get(l), 'chapter %s 缺 %s 文案' % (c['id'], l)
        for i, (hh, body) in enumerate(c['sections']):
            for l in LANGS:
                assert hh.get(l) and body.get(l), \
                    'chapter %s 第 %d 节缺 %s 文案' % (c['id'], i, l)
    for l in LANGS:
        for f in ('title', 'desc', 'h1', 'lead', 'ph'):
            assert HEAD[l].get(f), 'HEAD[%s] 缺 %s' % (l, f)
        for f in UI[l]:
            assert UI[l][f], 'UI[%s] 缺 %s' % (l, f)

    # 自检 2：章节数固定（三语必须逐章对齐 —— 同一份 CHAPTERS，天然对齐，这里防未来改动漏改）
    n = len(CHAPTERS)
    assert n == 12, '预期 12 章，实际 %d（改了章节数请同步本断言与 lead 文案）' % n

    for lang in LANGS:
        path, _, _, _ = PAGES[lang]
        html = render_head(lang) + render_body(lang)
        out = os.path.join(ROOT, path)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        io.open(out, 'w', encoding='utf-8', newline='\n').write(html)
        n_sec = sum(len(c['sections']) for c in CHAPTERS)
        print('%-6s %2d 章 · %2d 节 · %6d 字节 → %s'
              % (lang, n, n_sec, len(html), path))

    print('\n✅ 三份用户手册已生成（章节/小节逐一对齐，文案三语手写）')


if __name__ == '__main__':
    main()
