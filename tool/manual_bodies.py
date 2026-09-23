#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""手册正文（第 1/2 部分）：index · start · interface · connections · beacon · messaging

结构约定：BODIES[页面 file] = [(小节 id, T(zh, zh_TW, en)), ...]
小节 id 必须与 manual_content.PAGE_META 里的 sections 对齐（生成时自检）。
"""
from manual_content import T

BODIES = {

# ─────────────────────────── 手册首页 ───────────────────────────
'index': [
    ('paths', T('按目标选路径', '按目標選路徑', 'Pick a path by goal'), '''
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>我想…</th><th>去哪</th></tr></thead><tbody>
<tr><td><b>第一次用</b>，从零跑到收到报文</td><td><a href="start.html">快速上手</a></td></tr>
<tr><td><b>接上电台</b>（蓝牙/USB TNC、音频、Kenwood）</td><td><a href="connections.html#rf">连接 → 接电台</a></td></tr>
<tr><td><b>让别人看到我</b>（信标上报）</td><td><a href="beacon.html">位置信标</a></td></tr>
<tr><td><b>发消息</b>、建群、跨语言聊天</td><td><a href="messaging.html">消息与群聊</a></td></tr>
<tr><td><b>做网关</b>（把射频听到的送上互联网）</td><td><a href="connections.html#igate">网关 iGate</a></td></tr>
<tr><td><b>查某一项设置</b>到底什么意思、默认多少</td><td><a href="settings.html">设置参考</a></td></tr>
<tr><td><b>出了问题</b>，不知道卡在哪一层</td><td><a href="troubleshooting.html">故障排查</a></td></tr>
</tbody></table></div>
''', '''
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>我想…</th><th>去哪</th></tr></thead><tbody>
<tr><td><b>第一次用</b>，從零跑到收到封包</td><td><a href="start.html">快速上手</a></td></tr>
<tr><td><b>接上電臺</b>（藍牙/USB TNC、音訊、Kenwood）</td><td><a href="connections.html#rf">連線 → 接電臺</a></td></tr>
<tr><td><b>讓別人看到我</b>（信標上報）</td><td><a href="beacon.html">位置信標</a></td></tr>
<tr><td><b>發訊息</b>、建組、跨語言聊天</td><td><a href="messaging.html">訊息與群組</a></td></tr>
<tr><td><b>做閘道</b>（把射頻聽到的送上網際網路）</td><td><a href="connections.html#igate">閘道 iGate</a></td></tr>
<tr><td><b>查某一項設定</b>到底什麼意思、預設多少</td><td><a href="settings.html">設定參考</a></td></tr>
<tr><td><b>出了問題</b>，不知卡在哪一層</td><td><a href="troubleshooting.html">故障排除</a></td></tr>
</tbody></table></div>
''', '''
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>I want to…</th><th>Go to</th></tr></thead><tbody>
<tr><td><b>Use it for the first time</b>, from zero to a received packet</td><td><a href="start.html">Quick Start</a></td></tr>
<tr><td><b>Hook up a radio</b> (Bluetooth/USB TNC, audio, Kenwood)</td><td><a href="connections.html#rf">Connections → into a radio</a></td></tr>
<tr><td><b>Be seen</b> by others (position beacon)</td><td><a href="beacon.html">Beaconing</a></td></tr>
<tr><td><b>Send messages</b>, run a group, chat across languages</td><td><a href="messaging.html">Messaging</a></td></tr>
<tr><td><b>Run an iGate</b> (relay RF onto the internet)</td><td><a href="connections.html#igate">iGate</a></td></tr>
<tr><td><b>Look up one setting</b> — what it means and its default</td><td><a href="settings.html">Settings Reference</a></td></tr>
<tr><td><b>Something broke</b> and I don’t know which layer</td><td><a href="troubleshooting.html">Troubleshooting</a></td></tr>
</tbody></table></div>
'''),
    ('all', T('全部章节', '全部章節', 'All chapters'), '''
<ul class="m-index-list">
<li><a href="start.html">快速上手</a> —— 安装、七步向导、Passcode、收第一条报文</li>
<li><a href="interface.html">界面导览</a> —— 五个页签、面板手势、返回键</li>
<li><a href="connections.html">连接与数据来源</a> —— 四条链路、APRS-IS、接电台、iGate、链路自检</li>
<li><a href="beacon.html">位置信标</a> —— 间隔、速度分档、无 GPS、报文示例</li>
<li><a href="messaging.html">消息与群聊</a> —— 单聊、67/512 红线、群聊、翻译</li>
<li><a href="maps.html">地图与显示</a> —— 图源、坐标纠偏、离线地图、主题</li>
<li><a href="stations.html">台站与筛选</a> —— 范围过滤、列表筛选、设备识别</li>
<li><a href="data.html">导出 · 备份 · 轨迹</a> —— ADIF、JSON 备份、按天轨迹与回放</li>
<li><a href="widgets.html">桌面组件与短波</a> —— 三套组件、hamqsl 面板</li>
<li><a href="settings.html">设置参考</a> —— 逐项：名称 / 控件 / 默认值 / 说明</li>
<li><a href="platform.html">平台差异</a> —— Android / Windows / Web 能力矩阵</li>
<li><a href="troubleshooting.html">故障排查</a> —— 三个入口、症状决策表</li>
</ul>
<div class="callout info"><span class="co-ic">💡</span><div><p>只想搜常见问题？
直接去 <a href="../faq.html">帮助中心</a>（23 题按主题分组）；本手册按<b>任务</b>组织，
适合「我要完成一件事」。</p></div></div>
''', '''
<ul class="m-index-list">
<li><a href="start.html">快速上手</a> —— 安裝、七步引導、Passcode、收第一則封包</li>
<li><a href="interface.html">介面導覽</a> —— 五個頁籤、面板手勢、返回鍵</li>
<li><a href="connections.html">連線與資料來源</a> —— 四條鏈路、APRS-IS、接電臺、iGate、鏈路自檢</li>
<li><a href="beacon.html">位置信標</a> —— 間隔、速度分檔、無 GPS、封包示例</li>
<li><a href="messaging.html">訊息與群組</a> —— 單聊、67/512 紅線、群組、翻譯</li>
<li><a href="maps.html">地圖與顯示</a> —— 圖磚、座標校正、離線地圖、主題</li>
<li><a href="stations.html">臺站與篩選</a> —— 範圍過濾、列表篩選、裝置識別</li>
<li><a href="data.html">匯出 · 備份 · 軌跡</a> —— ADIF、JSON 備份、按天軌跡與回放</li>
<li><a href="widgets.html">桌面小組件與短波</a> —— 三套小組件、hamqsl 面板</li>
<li><a href="settings.html">設定參考</a> —— 項：名稱 / 控件 / 預設值 / 說明</li>
<li><a href="platform.html">平台差異</a> —— Android / Windows / Web 能力矩陣</li>
<li><a href="troubleshooting.html">故障排除</a> —— 三個入口、症狀決策表</li>
</ul>
<div class="callout info"><span class="co-ic">💡</span><div><p>只想搜常見問題？
直接去 <a href="../faq.html">幫助中心</a>（23 題按主題分組）；本手冊按<b>任務</b>組織，
適合「我要完成一件事」。</p></div></div>
''', '''
<ul class="m-index-list">
<li><a href="start.html">Quick Start</a> — install, seven-step wizard, Passcode, first packet</li>
<li><a href="interface.html">Interface</a> — five tabs, panel gestures, the Back key</li>
<li><a href="connections.html">Connections</a> — four links, APRS-IS, radio hookup, iGate, self-test</li>
<li><a href="beacon.html">Beaconing</a> — interval, speed tiers, no GPS, frame example</li>
<li><a href="messaging.html">Messaging</a> — direct chat, the 67/512 limits, groups, translation</li>
<li><a href="maps.html">Maps &amp; Display</a> — tiles, datum correction, offline maps, themes</li>
<li><a href="stations.html">Stations</a> — range filter, list filters, device identification</li>
<li><a href="data.html">Export · Backup · Tracks</a> — ADIF, JSON backup, per-day tracks</li>
<li><a href="widgets.html">Widgets &amp; HF</a> — three widgets, the hamqsl panel</li>
<li><a href="settings.html">Settings Reference</a> — item: name / control / default / meaning</li>
<li><a href="platform.html">Platforms</a> — Android / Windows / Web capability matrix</li>
<li><a href="troubleshooting.html">Troubleshooting</a> — three entry points, symptom table</li>
</ul>
<div class="callout info"><span class="co-ic">💡</span><div><p>Just after quick answers?
The <a href="../faq.html">Help Center</a> has 23 questions grouped by topic; this guide is
organised by <b>task</b> — for “I need to get one thing done”.</p></div></div>
'''),
],

# ─────────────────────────── 快速上手 ───────────────────────────
'start': [
    ('install', T('安装', '安裝', 'Install'), '''
<ol class="m-steps">
<li>打开 <a href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">GitHub Releases</a>，按平台取包：<b>Android</b> → <code>*.apk</code>；<b>Windows</b> → 安装包。</li>
<li>Android 自 v1.5.2 起使用正式 release 签名，<b>直接覆盖安装</b>即可；从更老的版本升级请先卸载再装（签名不同会装不上）。</li>
<li>装完先别急着点 —— 下一步要准备 <b>Passcode</b>，没有它只能连上、收不到消息。</li>
</ol>
<div class="callout info"><span class="co-ic">🧩</span><div><p>桌面端是绿色安装：装完在开始菜单找 <b>APRSlocus</b>；解压版直接运行 <code>aprslocus.exe</code>。</p></div></div>
''', '''
<ol class="m-steps">
<li>打開 <a href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">GitHub Releases</a>，按平台取包：<b>Android</b> → <code>*.apk</code>；<b>Windows</b> → 安裝程式。</li>
<li>Android 自 v1.5.2 起使用正式 release 簽章，<b>直接覆蓋安裝</b>即可；從更老的版本升級請先解除安裝（簽章不同會裝不上）。</li>
<li>裝完先別急著點 —— 下一步要準備 <b>Passcode</b>，沒有它只能連上、收不到訊息。</li>
</ol>
<div class="callout info"><span class="co-ic">🧩</span><div><p>桌面端是綠色安裝：裝完在開始功能表找 <b>APRSLocus</b>；解壓版直接執行 <code>aprslocus.exe</code>。</p></div></div>
''', '''
<ol class="m-steps">
<li>Grab the build for your platform from <a href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">GitHub Releases</a>: <b>Android</b> → <code>*.apk</code>; <b>Windows</b> → installer.</li>
<li>Android builds have used the official release signature since v1.5.2, so <b>install over the old one</b>; coming from a much older build, uninstall first (mismatched signatures refuse to install).</li>
<li>Before you tap anything: prepare your <b>Passcode</b> — without it you can connect, but you will receive no messages.</li>
</ol>
<div class="callout info"><span class="co-ic">🧩</span><div><p>The desktop build is portable: find <b>APRSlocus</b> in the Start menu, or run <code>aprslocus.exe</code> from the unpacked folder.</p></div></div>
'''),
    ('wizard', T('首次启动：七步向导', '首次啟動：七步引導', 'First launch: seven steps'), '''
<p>向导每一步都能返回修改；之后随时可在 <b>设置 → 高级</b> 里<b>重新运行</b>，当前设置不会丢。</p>
<ol class="m-steps">
<li><b>界面语言</b> —— 简体 / 繁體 / English / 日本語 / Indonesia / Español。</li>
<li><b>用户协议</b> —— 必须勾选同意《用户协议》与 GPL-3.0；注意 APRS 数据是公开的，发出后可能被全球接收与转发。</li>
<li><b>欢迎页</b> —— 实时地图、GPS 上报、APRS 消息、APRS-IS 四项能力。</li>
<li><b>呼号与 SSID</b> —— 输入完整呼号（含 SSID，如 <code>BG7LZQ-3</code>）；<b>留空无法继续</b>。</li>
<li><b>台站符号</b> —— 代表台站类型，随每条信标发送。</li>
<li><b>接收地区</b> —— 勾选要收的国家/地区；<b>不勾 = 全收</b>。</li>
<li><b>服务器与 Passcode</b> —— 服务器默认 <code>rotate.aprs2.net</code> 可不动；Passcode 见下一节。</li>
</ol>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>怎么算完成：</b>向导最后一页点完成后，主页顶部的链路状态卡应显示<b>已连接</b>；
若显示黄色「未验证」，说明 Passcode 还没填对，继续看下一节。</p></div></div>
''', '''
<p>引導每一步都能返回修改；之後隨時可在 <b>設定 → 進階</b> 裡<b>重新執行</b>，目前設定不會丟。</p>
<ol class="m-steps">
<li><b>介面語言</b> —— 簡體 / 繁體 / English / 日本語 / Indonesia / Español。</li>
<li><b>使用者協議</b> —— 必須勾選同意《使用者協議》與 GPL-3.0；注意 APRS 資料是公開的，發出後可能被全球接收與轉發。</li>
<li><b>歡迎頁</b> —— 即時地圖、GPS 上報、APRS 訊息、APRS-IS 四項能力。</li>
<li><b>呼號與 SSID</b> —— 輸入完整呼號（含 SSID，如 <code>BG7LZQ-3</code>）；<b>留空無法繼續</b>。</li>
<li><b>臺站符號</b> —— 代表臺站類型，隨每一則信標發送。</li>
<li><b>接收地區</b> —— 勾選要收的國家/地區；<b>不勾 = 全收</b>。</li>
<li><b>伺服器與 Passcode</b> —— 伺服器預設 <code>rotate.aprs2.net</code> 可不動；Passcode 見下一節。</li>
</ol>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>怎麼算完成：</b>引導最後一頁點完成后，首頁頂部的鏈路狀態卡應顯示<b>已連線</b>；
若顯示黃色「未驗證」，代表 Passcode 還沒填對，繼續看下一節。</p></div></div>
''', '''
<p>Every step can be revisited, and the wizard can be re-run any time from
<b>Settings → Advanced</b> without losing the current setup.</p>
<ol class="m-steps">
<li><b>Language</b> — Simplified Chinese, Traditional Chinese, English, Japanese, Indonesian, Spanish.</li>
<li><b>Agreement</b> — you must accept the Terms and GPL-3.0; APRS data is public: once sent it may be received and relayed worldwide.</li>
<li><b>Welcome</b> — live map, GPS reporting, APRS messaging, APRS-IS.</li>
<li><b>Callsign &amp; SSID</b> — full callsign including the SSID (e.g. <code>BG7LZQ-3</code>); <b>it cannot be left empty</b>.</li>
<li><b>Station symbol</b> — states your station type and travels with every beacon.</li>
<li><b>Receive area</b> — tick the countries/regions you want; <b>nothing ticked = receive everything</b>.</li>
<li><b>Server &amp; Passcode</b> — the server defaults to <code>rotate.aprs2.net</code>; Passcode next.</li>
</ol>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>Done when:</b> after the last page the link status card at the top reads <b>connected</b>.
A yellow “unverified” banner means the Passcode is still wrong — next section.</p></div></div>
'''),
    ('passcode', T('Passcode 与后台运行', 'Passcode 與背景執行', 'Passcode & background'), '''
<div class="callout warn"><span class="co-ic">⚠️</span><div><p><b>Passcode 是 APRS-IS 的登录验证码</b>，把你的呼号验证到网络。
留空或默认 <code>-1</code> 只能<b>连接</b>，消息与群组都收发不了。到
<a href="https://aprs.cool/AprsPG" target="_blank" rel="noopener">APRS Passcode 查询</a>
用<b>完整呼号</b>生成后填入 <b>设置 → 连接 → Passcode</b>。
填错时主页顶部会出现黄色「未验证」横幅 —— 那就是它。</p></div></div>
<ul>
<li><b>改完要保存</b>：连接页的改动点「保存并应用」才生效。</li>
<li><b>要它一直上报</b>：系统设置里允许 APRSlocus 后台运行、关掉省电优化、允许自启动；通知栏可一键退出。</li>
</ul>
''', '''
<div class="callout warn"><span class="co-ic">⚠️</span><div><p><b>Passcode 是 APRS-IS 的登入驗證碼</b>，把你的呼號驗證到網路。
留空或預設 <code>-1</code> 只能<b>連線</b>，訊息與群組都收發不了。到
<a href="https://aprs.cool/AprsPG" target="_blank" rel="noopener">APRS Passcode 查詢</a>
用<b>完整呼號</b>產生後填入 <b>設定 → 連線 → Passcode</b>。
填錯時首頁頂部會出現黃色「未驗證」橫幅 —— 那就是它。</p></div></div>
<ul>
<li><b>改完要儲存</b>：連線頁的改动點「儲存並套用」才生效。</li>
<li><b>要它一直上報</b>：系統設定裡允許 APRSLocus 背景執行、關掉省電最佳化、允許自啟動；通知欄可一鍵結束。</li>
</ul>
''', '''
<div class="callout warn"><span class="co-ic">⚠️</span><div><p><b>The Passcode is the APRS-IS login validator</b> for your callsign.
Left empty or at the default <code>-1</code> you can only <b>connect</b> — no messaging, no groups.
Generate one for your <b>full callsign</b> at the
<a href="https://aprs.cool/AprsPG" target="_blank" rel="noopener">APRS Passcode generator</a>
and put it into <b>Settings → Connection → Passcode</b>. A wrong value shows the yellow
“unverified” banner on the home page.</p></div></div>
<ul>
<li><b>Save after editing</b>: connection changes apply only with “Save &amp; apply”.</li>
<li><b>Keep beaconing</b>: allow background running, disable battery optimisation and allow auto-start in your system settings; the notification offers a one-tap Exit.</li>
</ul>
'''),
    ('firstpacket', T('验证：收到第一条报文', '驗證：收到第一則封包', 'Verify: first packet'), '''
<ol class="m-steps">
<li>主页顶部<b>链路状态卡</b>：状态为「已连接」，收包计数在涨。</li>
<li>切到 <b>数据包</b> 页签：几秒内应出现原始报文（等宽字体、可长按复制）。</li>
<li>看不懂没关系 —— 下面是一帧<b>真实位置报文</b>的逐段拆解（取自项目测试用例）。</li>
</ol>
<pre class="pkt">BG7LZG-9&gt;APALOC,TCPIP*:!3904.25N/11624.44E&gt;123/045/A=000100 Bat:88% APRSlocus v1.6.67</pre>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>片段</th><th>含义</th></tr></thead><tbody>
<tr><td><code>BG7LZG-9</code></td><td>发信人呼号（含 SSID）</td></tr>
<tr><td><code>APALOC</code></td><td>目的呼号 / tocall —— APRSlocus 的软件标识</td></tr>
<tr><td><code>TCPIP*</code></td><td>路径：走互联网，星号 = 本设备最后一次中继</td></tr>
<tr><td><code>!3904.25N/11624.44E&gt;</code></td><td>定位串：纬度 / 经度 / 台站符号（车）</td></tr>
<tr><td><code>123/045</code></td><td>航向 123°、速度 45 节</td></tr>
<tr><td><code>A=000100</code></td><td>高度 100 英尺</td></tr>
<tr><td><code>Bat:88% …</code></td><td>注释：电量与软件版本（紧跟定位串，无空格）</td></tr>
</tbody></table></div>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>怎么算成功：</b>数据包页有报文 + 收包计数增长 = 接收链路通。
若计数一直为 0，去 <a href="troubleshooting.html">故障排查</a>。</p></div></div>
''', '''
<ol class="m-steps">
<li>首頁頂部<b>鏈路狀態卡</b>：狀態為「已連線」，收包計數在漲。</li>
<li>切到 <b>資料封包</b> 頁籤：幾秒內應出現原始封包（等寬字型、可長按複製）。</li>
<li>看不懂沒關係 —— 下面是一幀<b>真實位置封包</b>的逐段拆解（取自專案測試用例）。</li>
</ol>
<pre class="pkt">BG7LZG-9&gt;APALOC,TCPIP*:!3904.25N/11624.44E&gt;123/045/A=000100 Bat:88% APRSlocus v1.6.67</pre>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>片段</th><th>含義</th></tr></thead><tbody>
<tr><td><code>BG7LZG-9</code></td><td>發信人呼號（含 SSID）</td></tr>
<tr><td><code>APALOC</code></td><td>目的呼號 / tocall —— APRSLocus 的軟體標識</td></tr>
<tr><td><code>TCPIP*</code></td><td>路徑：走網際網路，星號 = 本裝置最後一次中繼</td></tr>
<tr><td><code>!3904.25N/11624.44E&gt;</code></td><td>定位串：緯度 / 經度 / 臺站符號（車）</td></tr>
<tr><td><code>123/045</code></td><td>航向 123°、速度 45 節</td></tr>
<tr><td><code>A=000100</code></td><td>高度 100 英尺</td></tr>
<tr><td><code>Bat:88% …</code></td><td>註釋：電量與軟體版本（緊跟定位串，無空格）</td></tr>
</tbody></table></div>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>怎麼算成功：</b>封包頁有封包 + 收包計數增長 = 接收鏈路通。
若計數一直為 0，去 <a href="troubleshooting.html">故障排除</a>。</p></div></div>
''', '''
<ol class="m-steps">
<li>The <b>link status card</b> at the top reads “connected” and the RX counter climbs.</li>
<li>Open the <b>Packets</b> tab: raw packets appear within seconds (monospace, long-press to copy).</li>
<li>Never seen one? Here is a <b>real position frame</b> taken from the project’s tests, taken apart:</li>
</ol>
<pre class="pkt">BG7LZG-9&gt;APALOC,TCPIP*:!3904.25N/11624.44E&gt;123/045/A=000100 Bat:88% APRSlocus v1.6.67</pre>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>Part</th><th>Meaning</th></tr></thead><tbody>
<tr><td><code>BG7LZG-9</code></td><td>sender callsign (with SSID)</td></tr>
<tr><td><code>APALOC</code></td><td>destination / tocall — APRSlocus’s software ID</td></tr>
<tr><td><code>TCPIP*</code></td><td>path: over the internet, asterisk = last retransmitter</td></tr>
<tr><td><code>!3904.25N/11624.44E&gt;</code></td><td>position: latitude / longitude / station symbol (car)</td></tr>
<tr><td><code>123/045</code></td><td>course 123°, speed 45 knots</td></tr>
<tr><td><code>A=000100</code></td><td>altitude 100 ft</td></tr>
<tr><td><code>Bat:88% …</code></td><td>comment: battery and version (directly after the position, no space)</td></tr>
</tbody></table></div>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>Done when:</b> the Packets tab shows frames and the counter grows.
Still zero? Go to <a href="troubleshooting.html">Troubleshooting</a>.</p></div></div>
'''),
],

# ─────────────────────────── 界面导览 ───────────────────────────
'interface': [
    ('tabs', T('五个页签', '五個頁籤', 'Five tabs'), '''
<p>底部导航固定五项（桌面端变成侧边栏），<b>顺序不会变</b>：</p>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>#</th><th>页签</th><th>进去能做什么</th></tr></thead><tbody>
<tr><td>1</td><td><b>地图</b></td><td>应用底座：台站标记、轨迹、工具列、地图菜单</td></tr>
<tr><td>2</td><td><b>台站</b></td><td>收到的台站：筛选、搜索、详情、收藏、轨迹回放</td></tr>
<tr><td>3</td><td><b>消息</b></td><td>单聊与群聊的统一会话列表，带未读角标</td></tr>
<tr><td>4</td><td><b>数据包</b></td><td>原始报文流（可复制、可按类型筛选）与分级日志</td></tr>
<tr><td>5</td><td><b>设置</b></td><td>八个分组 + 荣誉墙、翻译、ADIF、主题、轨迹、备份入口</td></tr>
</tbody></table></div>
<div class="callout info"><span class="co-ic">🗺️</span><div><p><b>地图永远在最底下</b>：点其它页签时面板是「浮」在地图上的，再点「地图」就把面板收起来 ——
所以任何时候你其实都能回到地图。</p></div></div>
''', '''
<p>底部導航固定五項（桌面端變成側邊欄），<b>順序不會變</b>：</p>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>#</th><th>頁籤</th><th>進去能做什麼</th></tr></thead><tbody>
<tr><td>1</td><td><b>地圖</b></td><td>應用底座：臺站標記、軌跡、工具列、地圖選單</td></tr>
<tr><td>2</td><td><b>臺站</b></td><td>收到的臺站：篩選、搜尋、詳情、收藏、軌跡回放</td></tr>
<tr><td>3</td><td><b>訊息</b></td><td>單聊與群組的統一會話列表，帶未讀角標</td></tr>
<tr><td>4</td><td><b>資料封包</b></td><td>原始封包串流（可複製、可按類型篩選）與分級日誌</td></tr>
<tr><td>5</td><td><b>設定</b></td><td>八個分組 + 榮譽牆、翻譯、ADIF、主題、軌跡、備份入口</td></tr>
</tbody></table></div>
<div class="callout info"><span class="co-ic">🗺️</span><div><p><b>地圖永遠在最底下</b>：點其它頁籤時面板是「浮」在地圖上的，再點「地圖」就把面板收起來 ——
所以任何時候你其實都能回到地圖。</p></div></div>
''', '''
<p>Five tabs in a fixed order (a side rail on desktop) — <b>the order never changes</b>:</p>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>#</th><th>Tab</th><th>What you do there</th></tr></thead><tbody>
<tr><td>1</td><td><b>Map</b></td><td>the base: station markers, tracks, toolbar, map menu</td></tr>
<tr><td>2</td><td><b>Stations</b></td><td>stations you received: filter, search, detail, favourites, playback</td></tr>
<tr><td>3</td><td><b>Messages</b></td><td>one list for direct and group chats, with unread badges</td></tr>
<tr><td>4</td><td><b>Packets</b></td><td>raw packet stream (copyable, filterable) and the graded log</td></tr>
<tr><td>5</td><td><b>Settings</b></td><td>eight categories plus honor wall, translation, ADIF, themes, tracks, backup</td></tr>
</tbody></table></div>
<div class="callout info"><span class="co-ic">🗺️</span><div><p><b>The map is always the base</b>: other tabs raise a panel <i>over</i> the map, and tapping
Map again lowers it — so you can always get back to the map.</p></div></div>
'''),
    ('gestures', T('面板手势与返回键', '面板手勢與返回鍵', 'Panels & Back key'), '''
<ul>
<li><b>拖面板</b>：抓住面板顶部把手，或直接拖底部导航条（又高又宽，最好抓）。</li>
<li><b>列表滚到边也能拖面板</b>：列表<b>到顶继续下拉</b>会收面板、<b>到底继续上推</b>会展开面板。
列表在中间时照常滚动 —— 那一段必须留给滚动。</li>
<li><b>进会话自动展开</b>：打开某个会话或群聊时，面板会自己升到最高档，输入框就在最下面；退回列表时复位。</li>
<li><b>未连接横幅</b>：没连上时地图上方会有一条<b>橙色横幅</b>（整条可点，点一下即连）。
未连接时发送、信标、消息<b>全都出不去</b>，别被「界面看着正常」骗了。</li>
<li><b>返回键</b>：只在「地图」页签会退出应用；其它页签先收面板 / 返回上级 —— 防误退。</li>
<li><b>切页不销毁</b>：列表滚动位置、正在看的会话都会保留（页面是缓存的，不是每次重建）。</li>
<li><b>横屏</b>：Android 默认锁竖屏，要在 <b>设置 → 高级</b> 打开「允许手机横屏显示」。</li>
</ul>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>验证手势：</b>在「台站」页把列表滚到中间 → 点「消息」→ 再点回「台站」，
滚动位置应该还在。</p></div></div>
''', '''
<ul>
<li><b>拖面板</b>：抓住面板頂部把手，或直接拖底部導航條（又高又寬，最好抓）。</li>
<li><b>列表捲到邊也能拖面板</b>：列表<b>到頂繼續下拉</b>會收面板、<b>到底繼續上推</b>會展開面板。
列表在中間時照常捲動 —— 那一段必須留給捲動。</li>
<li><b>進會話自動展開</b>：打開某個會話或群組時，面板會自己升到最高檔，輸入框就在最下面；退回列表時復位。</li>
<li><b>未連線橫幅</b>：沒連上時地圖上方會有一條<b>橘色橫幅</b>（整條可點，點一下即連）。
未連線時傳送、信標、訊息<b>全都出不去</b>，別被「介面看著正常」騙了。</li>
<li><b>返回鍵</b>：只在「地圖」頁籤會結束應用；其它頁籤先收面板 / 返回上層 —— 防誤退。</li>
<li><b>切頁不銷毀</b>：列表捲動位置、正在看的會話都會保留（頁面是快取的，不是每次重建）。</li>
<li><b>橫螢幕</b>：Android 預設鎖直螢幕，要在 <b>設定 → 進階</b> 打開「允許手機橫螢幕顯示」。</li>
</ul>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>驗證手勢：</b>在「臺站」頁把列表捲到中間 → 點「訊息」→ 再點回「臺站」，
捲動位置應該還在。</p></div></div>
''', '''
<ul>
<li><b>Drag the panel</b> with its top handle — or simply drag the bottom navigation bar, the biggest target on screen.</li>
<li><b>Drag from a list edge too</b>: pull past the top of a list to lower the panel, push past the bottom to raise it.
In the middle of a list, scrolling wins — that range must stay scrollable.</li>
<li><b>Chats expand by themselves</b>: opening a conversation or group raises the panel to full height so the input box is visible; going back to the list restores it.</li>
<li><b>Offline banner</b>: while disconnected an <b>orange bar</b> sits above the map (the whole bar is tappable and connects).
Sending, beaconing and messages are <b>all dead</b> then, so don't be fooled by a normal-looking screen.</li>
<li><b>Back key</b>: only exits the app from the Map tab; elsewhere it lowers the panel or goes up a level, so you never quit by accident.</li>
<li><b>Tabs are never torn down</b>: scroll positions and the open conversation survive switching (pages are cached, not rebuilt).</li>
<li><b>Landscape</b>: Android locks portrait by default — enable “allow landscape” under <b>Settings → Advanced</b>.</li>
</ul>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>Check the gestures:</b> scroll the station list halfway → tap Messages → tap Stations again;
the scroll position should still be there.</p></div></div>
'''),
],

# ─────────────────────────── 连接与数据来源 ───────────────────────────
'connections': [
    ('sources', T('四条链路：收可以多选，发只有一条', '四條鏈路：收可複選，發只有一條', 'Four links: many RX, one TX'), '''
<p>路径 <b>设置 → 连接 → 数据来源</b>。勾中的链路都会<b>收</b>报文，但<b>发射只有一条</b> ——
右侧圆点标记的那条。同一个呼号从两条链路发出去会造成重复报文。</p>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>来源</th><th>链路</th><th>收</th><th>发</th></tr></thead><tbody>
<tr><td><b>APRS-IS</b></td><td>互联网 TCP，默认 <code>rotate.aprs2.net:14580</code></td><td>✓</td><td>✓</td></tr>
<tr><td><b>TNC</b></td><td>蓝牙 SPP / USB 串口（OTG），KISS 协议，接电台</td><td>✓</td><td>✓</td></tr>
<tr><td><b>音频</b></td><td>耳机口接电台，AFSK 1200（Bell 202）</td><td>✓</td><td>✓</td></tr>
<tr><td><b>PKWDWPL</b></td><td>蓝牙/串口读 Kenwood 的 <code>$PKWDWPL</code> 航点语句</td><td>✓</td><td><b>✗ 只读</b></td></tr>
</tbody></table></div>
<div class="callout warn"><span class="co-ic">📡</span><div><p><b>接收范围默认 300 km</b>（最小 10 km），用 <code>r/纬度/经度/半径</code> 过滤 ——
改完必须点 <b>「保存并应用」</b> 才生效。想收全球就把半径调大或关掉过滤中心跟随。</p></div></div>
''', '''
<p>路徑 <b>設定 → 連線 → 資料來源</b>。勾中的鏈路都會<b>收</b>封包，但<b>發射只有一條</b> ——
右側圓點標記的那條。同一個呼號從兩條鏈路發出去會造成重複封包。</p>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>來源</th><th>鏈路</th><th>收</th><th>發</th></tr></thead><tbody>
<tr><td><b>APRS-IS</b></td><td>網際網路 TCP，預設 <code>rotate.aprs2.net:14580</code></td><td>✓</td><td>✓</td></tr>
<tr><td><b>TNC</b></td><td>藍牙 SPP / USB 序列埠（OTG），KISS 協定，接電臺</td><td>✓</td><td>✓</td></tr>
<tr><td><b>音訊</b></td><td>耳機孔接電臺，AFSK 1200（Bell 202）</td><td>✓</td><td>✓</td></tr>
<tr><td><b>PKWDWPL</b></td><td>藍牙/序列埠讀 Kenwood 的 <code>$PKWDWPL</code> 航點語句</td><td>✓</td><td><b>✗ 唯讀</b></td></tr>
</tbody></table></div>
<div class="callout warn"><span class="co-ic">📡</span><div><p><b>接收範圍預設 300 km</b>（最小 10 km），用 <code>r/緯度/經度/半徑</code> 過濾 ——
改完必須點 <b>「儲存並套用」</b>才生效。想收全球就把半徑調大或關掉過濾中心跟隨。</p></div></div>
''', '''
<p>Path: <b>Settings → Connection → Data sources</b>. Every ticked link <b>receives</b>, but there is
only <b>one transmit source</b> — the one marked with the dot. Transmitting the same callsign over
two links produces duplicate packets.</p>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>Source</th><th>Link</th><th>RX</th><th>TX</th></tr></thead><tbody>
<tr><td><b>APRS-IS</b></td><td>internet TCP, default <code>rotate.aprs2.net:14580</code></td><td>✓</td><td>✓</td></tr>
<tr><td><b>TNC</b></td><td>Bluetooth SPP / USB serial (OTG), KISS, into a radio</td><td>✓</td><td>✓</td></tr>
<tr><td><b>Audio</b></td><td>headphone jack into a radio, AFSK 1200 (Bell 202)</td><td>✓</td><td>✓</td></tr>
<tr><td><b>PKWDWPL</b></td><td>Bluetooth/serial reader of a Kenwood radio’s <code>$PKWDWPL</code> waypoints</td><td>✓</td><td><b>✗ receive-only</b></td></tr>
</tbody></table></div>
<div class="callout warn"><span class="co-ic">📡</span><div><p><b>The receive range defaults to 300 km</b> (10 km minimum), filtered with
<code>r/lat/lng/radius</code> — press <b>“Save &amp; apply”</b> after changing it. For worldwide
reception, raise the radius or stop following your position.</p></div></div>
'''),
    ('aprsis', T('接上 APRS-IS', '接上 APRS-IS', 'Connect APRS-IS'), '''
<ol class="m-steps">
<li><b>设置 → 连接</b>，确认服务器 <code>rotate.aprs2.net</code>、端口 <code>14580</code>（默认即可）。</li>
<li>填入 <b>Passcode</b>（用完整呼号生成，见 <a href="start.html#passcode">快速上手</a>）。</li>
<li>点 <b>「保存并应用」</b> —— 连接页的改动不保存不会生效。</li>
<li>回主页看链路状态卡：变成「已连接」、收包计数开始增长。</li>
</ol>
<ul>
<li><b>断线会自己重连</b>：按 <b>8 → 16 → 32 → 60 秒</b> 渐进退避，不用手动重连。</li>
<li><b>服务器返回 <code>unverified</code></b> = Passcode 没通过，回到第 2 步。</li>
<li>想用自建中转 / WebSocket：同一处填 <b>WebSocket URL（可选）</b>，留空走标准 TCP。</li>
</ul>
''', '''
<ol class="m-steps">
<li><b>設定 → 連線</b>，確認伺服器 <code>rotate.aprs2.net</code>、埠 <code>14580</code>（預設即可）。</li>
<li>填入 <b>Passcode</b>（用完整呼號產生，見 <a href="start.html#passcode">快速上手</a>）。</li>
<li>點 <b>「儲存並套用」</b> —— 連線頁的改动不儲存不會生效。</li>
<li>回首頁看鏈路狀態卡：變成「已連線」、收包計數開始增長。</li>
</ol>
<ul>
<li><b>斷線會自己重連</b>：按 <b>8 → 16 → 32 → 60 秒</b> 漸進退避，不用手動重連。</li>
<li><b>伺服器回傳 <code>unverified</code></b> = Passcode 沒通過，回到第 2 步。</li>
<li>想用自建中轉 / WebSocket：同一處填 <b>WebSocket URL（可選）</b>，留空走標準 TCP。</li>
</ul>
''', '''
<ol class="m-steps">
<li><b>Settings → Connection</b>: leave the server at <code>rotate.aprs2.net</code>, port <code>14580</code>.</li>
<li>Enter your <b>Passcode</b> (generated for the full callsign, see <a href="start.html#passcode">Quick Start</a>).</li>
<li>Press <b>“Save &amp; apply”</b> — connection edits do nothing until you save.</li>
<li>Back on the home page the link card reads “connected” and the counter climbs.</li>
</ol>
<ul>
<li><b>It reconnects by itself</b>: progressive backoff of <b>8 → 16 → 32 → 60 s</b>.</li>
<li><b>Server replies <code>unverified</code></b> = the Passcode failed — go back to step 2.</li>
<li>Custom relay / WebSocket: fill <b>WebSocket URL (optional)</b> in the same place; empty = plain TCP.</li>
</ul>
'''),
    ('rf', T('接电台：TNC / 音频 / PKWDWPL', '接電臺：TNC / 音訊 / PKWDWPL', 'Into a radio: TNC / audio / PKWDWPL'), '''
<p>三条射频路径的入口都在 <b>设置 → 设备</b>（设备总览页列出当前链路与三个子页）：</p>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>路径</th><th>子页</th><th>关键参数</th></tr></thead><tbody>
<tr><td><b>蓝牙/USB TNC</b></td><td>设备 → TNC 设备与参数</td><td>初始化串、串口线速、KISS 参数（txDelay 300ms、txTail 50ms、P=63、时隙 100ms、帧长 330B）、中继路径 <code>WIDE1-1,WIDE2-1</code></td></tr>
<tr><td><b>音频（声卡）</b></td><td>设备 → 音频（声卡 TNC）</td><td>采样率 22050、比特率 1200、标号 1200Hz / 空号 2200Hz、发射电平、CSMA 等待 3000ms</td></tr>
<tr><td><b>Kenwood 航点</b></td><td>设备 → PKWDWPL 设备</td><td>只读链路；严格校验和默认关（不符只标注不丢弃）</td></tr>
</tbody></table></div>
<ol class="m-steps">
<li><b>绑定设备</b>：子页里点「扫描设备」（蓝牙已配对 + USB 串口），选中后绑定。</li>
<li><b>TNC「能收不能发」</b>：先点「立即发送初始化串」—— 很多模块上电停在命令模式，要收到 <code>KISS ON</code> 才进 KISS；再核对<b>串口线速</b>（USB 串口与电台数据口必须同速：9600/19200/38400/57600/115200；蓝牙 SPP 无波特率概念）。</li>
<li><b>音频「对方解不出」</b>：看出去的<b>发射电平</b> —— 峰值太低或削顶都解不出；用音频线（耳机口 → 电台数据/话筒口），<b>别用扬声器对着麦克风</b>。</li>
<li><b>想只收不发</b>：关掉「允许发射 / 允许射频信标」—— 只听信标最省心，也避免误触 PTT。</li>
</ol>
<div class="callout warn"><span class="co-ic">⚠️</span><div><p>射频发射需持照操作，请遵守当地法规；<b>允许射频信标</b>默认关，打开前确认你的执照与本地规则允许。</p></div></div>
''', '''
<p>三條射頻路徑的入口都在 <b>設定 → 裝置</b>（裝置總覽頁列出當前鏈路與三個子頁）：</p>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>路徑</th><th>子頁</th><th>關鍵參數</th></tr></thead><tbody>
<tr><td><b>藍牙/USB TNC</b></td><td>裝置 → TNC 裝置與參數</td><td>初始化字串、序列埠線速、KISS 參數（txDelay 300ms、txTail 50ms、P=63、時隙 100ms、幀長 330B）、中繼路徑 <code>WIDE1-1,WIDE2-1</code></td></tr>
<tr><td><b>音訊（音效卡）</b></td><td>裝置 → 音訊（音效卡 TNC）</td><td>取樣率 22050、鮑率 1200、標號 1200Hz / 空號 2200Hz、發射電平、CSMA 等待 3000ms</td></tr>
<tr><td><b>Kenwood 航點</b></td><td>裝置 → PKWDWPL 裝置</td><td>唯讀鏈路；嚴格校驗和預設關（不符只標註不丟棄）</td></tr>
</tbody></table></div>
<ol class="m-steps">
<li><b>綁定裝置</b>：子頁裡點「掃描裝置」（藍牙已配對 + USB 序列埠），選中後綁定。</li>
<li><b>TNC「能收不能發」</b>：先點「立即送出初始化字串」—— 很多模組上電停在命令模式，要收到 <code>KISS ON</code> 才進 KISS；再核對<b>序列埠線速</b>（USB 序列埠與電臺資料埠必須同速：9600/19200/38400/57600/115200；藍牙 SPP 無鮑率概念）。</li>
<li><b>音訊「對方解不出」</b>：看出去的<b>發射電平</b> —— 峰值太低或削波都解不出；用音訊線（耳機孔 → 電臺資料/麥克風孔），<b>別用喇叭對著麥克風</b>。</li>
<li><b>想只收不發</b>：關掉「允許發射 / 允許射頻信標」—— 只聽信標最省心，也避免誤觸 PTT。</li>
</ol>
<div class="callout warn"><span class="co-ic">⚠️</span><div><p>射頻發射需照證操作，請遵守當地法規；<b>允許射頻信標</b>預設關，打開前確認你的執照與本地規則允許。</p></div></div>
''', '''
<p>All three RF paths live under <b>Settings → Device</b> (the overview lists the current link and
three sub-pages):</p>
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>Path</th><th>Sub-page</th><th>Key parameters</th></tr></thead><tbody>
<tr><td><b>Bluetooth/USB TNC</b></td><td>Device → TNC</td><td>init string, serial baud, KISS params (txDelay 300 ms, txTail 50 ms, P=63, slot 100 ms, 330 B frames), path <code>WIDE1-1,WIDE2-1</code></td></tr>
<tr><td><b>Audio (soundcard)</b></td><td>Device → Audio</td><td>22050 sample rate, 1200 baud, mark 1200 Hz / space 2200 Hz, TX level, 3000 ms CSMA wait</td></tr>
<tr><td><b>Kenwood waypoints</b></td><td>Device → PKWDWPL</td><td>read-only link; strict checksum off by default (mismatches are flagged, not dropped)</td></tr>
</tbody></table></div>
<ol class="m-steps">
<li><b>Bind the device</b>: tap “Scan devices” (paired Bluetooth + USB serial) in the sub-page and pick yours.</li>
<li><b>TNC receives but will not transmit</b>: send the init string first — many modules boot into command mode and need <code>KISS ON</code>; then match the <b>serial baud</b> on both ends (9600/19200/38400/57600/115200 are common; Bluetooth SPP has no baud rate).</li>
<li><b>Audio nobody can decode</b>: check the <b>TX level</b> — too low or clipped both fail; wire it (headphone jack → radio data/mic), <b>never speaker-to-microphone</b>.</li>
<li><b>Receive-only</b>: switch off “allow TX / allow RF beacon” — listening only is the calmest setup and never keys the PTT by mistake.</li>
</ol>
<div class="callout warn"><span class="co-ic">⚠️</span><div><p>RF transmission requires a licence — follow local regulations. <b>RF beaconing</b> is off by default; confirm your licence allows it before enabling.</p></div></div>
'''),
    ('igate', T('网关 iGate', '閘道 iGate', 'iGate'), '''
<p>iGate 把<b>射频</b>收到的报文转送 <b>APRS-IS</b>（自动加 <code>qAr</code>/<code>qAR</code> 与你的呼号标识来路）。
入口在 <b>设置 → 设备 → 网关（iGate）</b>。</p>
<ol class="m-steps">
<li><b>先满足条件</b>：同时勾选 <b>APRS-IS</b> + 一条射频来源（TNC 或音频），缺哪个界面会直接告诉你。</li>
<li>打开 <b>启用网关</b> —— 默认只做 <b>RF → IS</b>（把听到的送上互联网）。</li>
<li>按需打开 <b>双向网关</b>：它会在射频上<b>真实发射</b>，但只转「发给最近在射频上听到过的台站」的点对点消息；位置/天气等广播不转，避免占满信道。</li>
</ol>
<div class="callout info"><span class="co-ic">🔁</span><div><p><b>环路防护（自动，无需配置）：</b>报文带 <code>TCPIP*</code> 或已有 q 构造的（本来就是互联网来的）
绝不回送；同一帧 <b>30 秒内只注入一次</b>。分节里的计数（射频收到 / 已转递 / 重复丢弃 / 环路拒收）
就是这四道闸的实时读数。</p></div></div>
''', '''
<p>iGate 把<b>射頻</b>收到的封包轉送 <b>APRS-IS</b>（自動加 <code>qAr</code>/<code>qAR</code> 與你的呼號標識來路）。
入口在 <b>設定 → 裝置 → 網關（iGate）</b>。</p>
<ol class="m-steps">
<li><b>先滿足條件</b>：同時勾選 <b>APRS-IS</b> + 一條射頻來源（TNC 或音訊），缺哪個介面會直接告訴你。</li>
<li>打開 <b>啟用網關</b> —— 預設只做 <b>RF → IS</b>（把聽到的送上網際網路）。</li>
<li>按需打開 <b>雙向網關</b>：它會在射頻上<b>真實發射</b>，但只轉「發給最近在射頻上聽到過的臺站」的點對點訊息；位置/天氣等廣播不轉，避免佔滿通道。</li>
</ol>
<div class="callout info"><span class="co-ic">🔁</span><div><p><b>環路防護（自動，無需設定）：</b>封包帶 <code>TCPIP*</code> 或已有 q 構造的（本來就是網際網路來的）
絕不回送；同一幀 <b>30 秒內只注入一次</b>。分節裡的計數（射頻收到 / 已轉遞 / 重複丟棄 / 環路拒收）
就是這四道閘的即時讀數。</p></div></div>
''', '''
<p>The iGate relays packets heard on <b>RF</b> into <b>APRS-IS</b> (adding <code>qAr</code>/<code>qAR</code>
and your callsign). Entry: <b>Settings → Device → Gateway (iGate)</b>.</p>
<ol class="m-steps">
<li><b>Meet the conditions</b>: tick <b>APRS-IS</b> <i>and</i> one RF source (TNC or audio) — the UI names whichever is missing.</li>
<li>Turn on <b>Enable gateway</b> — RF → IS only by default.</li>
<li>Optionally enable <b>two-way</b>: it really transmits on RF, but only relays point-to-point messages addressed to stations heard on RF recently; broadcasts like position/weather are never relayed.</li>
</ol>
<div class="callout info"><span class="co-ic">🔁</span><div><p><b>Loop protection (automatic):</b> packets carrying <code>TCPIP*</code> or an existing
q-construct (they came from the internet) are never sent back, and the same frame is injected once
per 30 s. The counters in that section (RF seen / gated / duplicates dropped / loops blocked) are
the live readings of those four gates.</p></div></div>
'''),
    ('selftest', T('链路自检与排错顺序', '鏈路自檢與排錯順序', 'Self-test & order of diagnosis'), '''
<p>出问题时<b>按这个顺序查</b>，一层一层来，别跳：</p>
<ol class="m-steps">
<li><b>链路状态卡</b>（主页顶部）：连接是否成立、收发计数是否在涨、服务器返回什么。</li>
<li><b>链路自检</b>（设备页）：TNC 协议回路 + AFSK 调制解调回路，一键分层定位；TNC 侧另有<b>初始化串</b>与<b>发射自检</b>（写一帧状态包，<b>不含坐标</b>，不会在 aprs.fi 上挪动你的位置）。</li>
<li><b>数据包页</b>：报文到底有没有进来。能收到但不上图 = 筛选或坐标问题（见 <a href="stations.html">台站与筛选</a>）。</li>
<li><b>网关计数不涨</b>：按界面提示逐条排除 —— 「射频收到 = 0」说明报文根本没进来，先查电台音量/静噪/天线。</li>
</ol>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>反馈时最有效的证据</b>：数据包页的原始报文 + 链路日志，附上它们定位最快。</p></div></div>
''', '''
<p>出問題時<b>按這個順序查</b>，一層一層來，別跳：</p>
<ol class="m-steps">
<li><b>鏈路狀態卡</b>（首頁頂部）：連線是否成立、收發計數是否在漲、伺服器回傳什麼。</li>
<li><b>鏈路自檢</b>（裝置頁）：TNC 協定回路 + AFSK 調變解調回路，一鍵分層定位；TNC 側另有<b>初始化字串</b>與<b>發射自檢</b>（寫一幀狀態封包，<b>不含座標</b>，不會在 aprs.fi 上移動你的位置）。</li>
<li><b>封包頁</b>：封包到底有沒有進來。能收到但不上圖 = 篩選或座標問題（見 <a href="stations.html">臺站與篩選</a>）。</li>
<li><b>閘道計數不漲</b>：按介面提示逐條排除 —— 「射頻收到 = 0」代表封包根本沒進來，先查電臺音量/靜噪/天線。</li>
</ol>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>回報時最有效的證據</b>：封包頁的原始封包 + 鏈路日誌，附上它們定位最快。</p></div></div>
''', '''
<p>When something breaks, <b>work down this order</b> — one layer at a time:</p>
<ol class="m-steps">
<li><b>Link status card</b> (top of the home page): is the link up, are the counters moving, what did the server reply?</li>
<li><b>Link self-test</b> (device page): TNC protocol loopback plus the AFSK modulate/demodulate loop; the TNC side also offers an <b>init string</b> and a <b>TX self-test</b> that writes one status frame with <b>no coordinates</b> (it never moves you on aprs.fi).</li>
<li><b>Packets tab</b>: did the frames arrive at all? Received but never plotted = filter or coordinate issue (see <a href="stations.html">Stations</a>).</li>
<li><b>Gateway counters stay flat</b>: follow the hints — “RF seen = 0” means nothing arrived: check radio volume, squelch and antenna first.</li>
</ol>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>Best evidence when reporting:</b> the raw packet from the Packets tab plus the link log.</p></div></div>
'''),
],

# ─────────────────────────── 位置信标 ───────────────────────────
'beacon': [
    ('interval', T('上报节奏：先定间隔', '上報節奏：先定間隔', 'Cadence: pick the interval'), '''
<ol class="m-steps">
<li><b>设置 → 定位上报 → 启用位置信标</b> 打开（默认开）。</li>
<li><b>上报间隔</b>默认 <b>60 秒</b> —— APRS-IS 建议移动站不低于 60 秒，<b>最短 5 秒</b>（输入更小会被校验拦下）。APRS 网络是共享资源，间隔拉太短会明显增加服务器负载，界面会提醒。</li>
<li>按需关掉 <b>速度 / 方位角 / 手机电量</b> 三个附加字段 —— 关掉报文更短，也少暴露一点信息。</li>
<li>不想自动发就关掉自动上报，用主页的<b>手动上报</b>按需点。</li>
</ol>
<div class="callout info"><span class="co-ic">⏱️</span><div><p><b>主页看得见节奏</b>：下次上报倒计时、已发信标次数都在主页上 ——
停在这两个数字上就能判断「它到底在不在发」。</p></div></div>
''', '''
<ol class="m-steps">
<li><b>設定 → 定位上報 → 啟用位置信標</b> 打開（預設開）。</li>
<li><b>上報間隔</b>預設 <b>60 秒</b> —— APRS-IS 建議移動站不低於 60 秒，<b>最短 5 秒</b>（輸入更小會被校驗攔下）。APRS 網路是共享資源，間隔拉太短會明顯增加伺服器負載，介面會提醒。</li>
<li>按需關掉 <b>速度 / 方位角 / 手機電量</b> 三個附加欄位 —— 關掉封包更短，也少暴露一點資訊。</li>
<li>不想自動發就關掉自動上報，用首頁的<b>手動上報</b>按需點。</li>
</ol>
<div class="callout info"><span class="co-ic">⏱️</span><div><p><b>首頁看得見節奏</b>：下次上報倒數、已發信標次數都在首頁上 ——
停在這兩個數字上就能判斷「它到底在不在發」。</p></div></div>
''', '''
<ol class="m-steps">
<li><b>Settings → Beacon → Enable position beacon</b> (on by default).</li>
<li><b>Interval</b> defaults to <b>60 s</b> — APRS-IS asks mobiles not to go below 60 s; the <b>hard minimum is 5 s</b> (smaller values are rejected by validation). APRS is a shared network: much faster noticeably loads the servers and the UI warns you.</li>
<li>Turn off <b>speed / course / battery</b> if you prefer shorter frames and less exposure.</li>
<li>Hate timers? Disable automatic reporting and use <b>manual beacon</b> on the home page.</li>
</ol>
<div class="callout info"><span class="co-ic">⏱️</span><div><p><b>The home page shows the cadence</b>: countdown to the next beacon and the number sent —
watch those two numbers to know whether it is still beaconing.</p></div></div>
'''),
    ('tiers', T('移动起来：速度分档', '移動起來：速度分檔', 'On the move: speed tiers'), '''
<ol class="m-steps">
<li><b>设置 → 定位上报 → 智能信标（按速度分档）</b> 打开。</li>
<li>配置最多 <b>5 档</b>：速度越快上报越频繁；每档自定义<b>间隔</b>与<b>图标</b>（图标留空 = 用「我的符号」）。</li>
<li>每档还能设<b>移动距离</b>（米，<b>0 = 关闭</b>）：<b>定时到了</b>或<b>走够了</b>，任一满足就上报。</li>
<li>每档还能设<b>航向变化</b>（度，<b>0 = 关闭</b>）：<b>转过这个角度</b>也补一个点 —— 只在行驶中生效（停着不动时航向本身就是噪声），且两次之间至少隔 20 秒。</li>
<li>停车时档位自动落到低速档，间隔拉长 —— 不用每次手动改。</li>
</ol>
<div class="callout info"><span class="co-ic">📏</span><div><p><b>为什么还要「或距离」</b>：定时上报有个先天缺口 —— 走了多远，和「过了多久」无关。
堵车时 300 秒一个点完全够用，而 60 km/h 在 60 秒里能走 1 公里，中间那段在 aprs.fi 上就是一条直线、拐弯全被抹平。
默认值按「该档速度在一个上报间隔内走的路程」给：静止 200 / 步行 250 / 城市 400 / 高速 700 米。
走得快就按距离补点，停下来距离不动、自然退回纯定时。</p><p><b>「或转弯」治的是另一种路</b>：盘山路上车速慢，距离门限很久才够，而连续发卡弯正是最该有轨迹的地方；直路巡航时航向不变，它一次都不会触发，不占信道。</p></div></div>
<div class="callout warn"><span class="co-ic">⚠️</span><div><p>分档间隔同样受 5 秒下限与服务器负载约束；把某一档设成 3 秒，校验会拦下来。</p></div></div>
''', '''
<ol class="m-steps">
<li><b>設定 → 定位上報 → 智能信標（按速度分檔）</b> 打開。</li>
<li>配置最多 <b>5 檔</b>：速度越快上報越頻繁；每檔自訂<b>間隔</b>與<b>圖示</b>（圖示留空 = 用「我的符號」）。</li>
<li>每檔還能設<b>移動距離</b>（公尺，<b>0 = 關閉</b>）：<b>定時到了</b>或<b>走夠了</b>，任一滿足就上報。</li>
<li>每檔還能設<b>航向變化</b>（度，<b>0 = 關閉</b>）：<b>轉過這個角度</b>也補一個點 —— 只在行駛中生效（停著不動時航向本身就是雜訊），且兩次之間至少隔 20 秒。</li>
<li>停車時檔位自動落到低速檔，間隔拉長 —— 不用每次手動改。</li>
</ol>
<div class="callout info"><span class="co-ic">📏</span><div><p><b>為什麼還要「或距離」</b>：定時上報有個先天缺口 —— 走了多遠，和「過了多久」無關。
塞車時 300 秒一個點完全夠用，而 60 km/h 在 60 秒裡能走 1 公里，中間那段在 aprs.fi 上就是一條直線、轉彎全被抹平。
預設值按「該檔速度在一個上報間隔內走的路程」給：靜止 200 / 步行 250 / 城市 400 / 高速 700 公尺。
走得快就按距離補點，停下來距離不動、自然退回純定時。</p><p><b>「或轉彎」治的是另一種路</b>：山路上車速慢，距離門檻很久才夠，而連續髮夾彎正是最該有軌跡的地方；直路巡航時航向不變，它一次都不會觸發，不佔頻道。</p></div></div>
<div class="callout warn"><span class="co-ic">⚠️</span><div><p>分檔間隔同樣受 5 秒下限與伺服器負載約束；把某一檔設成 3 秒，校驗會攔下來。</p></div></div>
''', '''
<ol class="m-steps">
<li><b>Settings → Beacon → Smart beaconing (speed tiers)</b> on.</li>
<li>Configure up to <b>five tiers</b>: the faster you go, the more often it reports; each tier has its own <b>interval</b> and <b>icon</b> (empty icon = “my symbol”).</li>
<li>Each tier also takes a <b>distance</b> (metres, <b>0 = off</b>): it beacons when <b>the timer expires</b> <em>or</em> <b>you have moved far enough</b>.</li>
<li>…and a <b>turn</b> threshold (degrees, <b>0 = off</b>): a point is also added once you <b>turn past it</b> — only while moving (heading is noise when parked) and at most once every 20 s.</li>
<li>Park and it drops to the slow tier by itself — no manual switching.</li>
</ol>
<div class="callout info"><span class="co-ic">📏</span><div><p><b>Why “or by distance” at all?</b> Timed beaconing has an inherent gap: how far you travelled has nothing to do with how long it took.
A 300 s interval is plenty in a traffic jam, while 60 km/h covers a kilometre in 60 s — and that stretch becomes a straight line on aprs.fi with every corner flattened.
Defaults follow “the distance this tier's speed covers in one interval”: 200 m stationary / 250 m walking / 400 m city / 700 m highway.
Fast, and points are added by distance; stopped, the distance stops growing and it falls back to pure timing.</p><p><b>The turn trigger covers a different road</b>: on mountain roads you are slow, so the distance threshold takes ages to reach, yet hairpins are exactly where the track matters most — while cruising straight the heading never changes and it never fires.</p></div></div>
<div class="callout warn"><span class="co-ic">⚠️</span><div><p>Tier intervals obey the same 5 s floor and server-load concern; a 3 s tier is rejected by validation.</p></div></div>
'''),
    ('nofix', T('没有 GPS 怎么办', '沒有 GPS 怎麼辦', 'When there is no GPS'), '''
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>场景</th><th>用什么</th><th>在哪</th></tr></thead><tbody>
<tr><td>室内 / 桌面演示</td><td><b>手动定位</b>：输入经纬度或在地图上选点</td><td>设置 → 定位上报 → 定位来源（模拟位置）</td></tr>
<tr><td>GPS 弱、有基站</td><td><b>GPS + 网络</b></td><td>设置 → 定位上报 → 定位模式</td></tr>
<tr><td>完全没有定位</td><td><b>启用模拟数据</b>（演示台站/数据包）</td><td>设置 → 高级</td></tr>
</tbody></table></div>
<div class="callout warn"><span class="co-ic">📍</span><div><p><b>网络定位的诚实说明：</b>基站/Wi-Fi 定位本来就有几百米误差，「位置飞来飞去」不是 bug。
应用的行为是「GPS 停更 2 分钟后才用网络兜底，且<b>不写轨迹</b>」，并且 GPS 新鲜时会丢弃网络点。
要准就选<b>纯 GPS</b>。</p></div></div>
<ul>
<li><b>静止防抖</b>：站着不动时标记不会原地哆嗦（滑动窗口中位数 + 漂移判据），移动时完全不平滑、逐帧如实。</li>
</ul>
''', '''
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>場景</th><th>用什麼</th><th>在哪</th></tr></thead><tbody>
<tr><td>室內 / 桌面示範</td><td><b>手動定位</b>：輸入經緯度或在地圖上選點</td><td>設定 → 定位上報 → 定位來源（模擬位置）</td></tr>
<tr><td>GPS 弱、有基站</td><td><b>GPS + 網路</b></td><td>設定 → 定位上報 → 定位模式</td></tr>
<tr><td>完全沒有定位</td><td><b>啟用模擬資料</b>（示範臺站/封包）</td><td>設定 → 進階</td></tr>
</tbody></table></div>
<div class="callout warn"><span class="co-ic">📍</span><div><p><b>網路定位的誠實說明：</b>基站/Wi-Fi 定位本來就有幾百公尺誤差，「位置飛來飛去」不是 bug。
應用的行為是「GPS 停更 2 分鐘後才用網路兜底，且<b>不寫軌跡</b>」，並且 GPS 新鮮時會丟棄網路點。
要準就選<b>純 GPS</b>。</p></div></div>
<ul>
<li><b>靜止防抖</b>：站著不動時標記不會原地發抖（滑動窗口中位數 + 漂移判據），移動時完全不平滑、逐幀如實。</li>
</ul>
''', '''
<div class="doc-table-wrap"><table class="doc-table">
<thead><tr><th>Situation</th><th>Use</th><th>Where</th></tr></thead><tbody>
<tr><td>Indoors / desktop demo</td><td><b>Manual location</b>: type coordinates or pick a point on the map</td><td>Settings → Beacon → Location source (simulated)</td></tr>
<tr><td>Weak GPS, cell coverage</td><td><b>GPS + network</b></td><td>Settings → Beacon → Location mode</td></tr>
<tr><td>No positioning at all</td><td><b>Demo data</b> (fake stations/packets)</td><td>Settings → Advanced</td></tr>
</tbody></table></div>
<div class="callout warn"><span class="co-ic">📍</span><div><p><b>Honest note on network positioning:</b> cell/Wi-Fi fixes are hundreds of metres off by nature,
so “my position flies around” is not a bug. The app only falls back to network <b>after GPS has been
quiet for 2 minutes</b>, never writes those fixes to your track, and drops them while GPS is fresh.
Want accuracy? Pick <b>GPS only</b>.</p></div></div>
<ul>
<li><b>Stationary damping</b>: the marker stops jittering while you stand still (sliding-median plus a drift test); when moving, nothing is smoothed — every frame is shown as it arrived.</li>
</ul>
'''),
    ('packet', T('一帧信标长什么样', '一幀信標長什麼樣', 'What a beacon frame looks like'), '''
<p>本应用发出的位置帧（示例取自测试用例 <code>beacon_format_test</code> / <code>afsk_test</code>）：</p>
<pre class="pkt"># 走 APRS-IS：
BG7LZG-9&gt;APALOC,TCPIP*:!3904.25N/11624.44E&gt;123/045/A=000100 Bat:88% APRSlocus v1.6.67
# 走射频（TNC）：
BG7LZQ-9&gt;APALOC,WIDE1-1,WIDE2-1:!2230.00N/11400.00E&gt;测试</pre>
<ul>
<li><code>APALOC</code> 是 APRSlocus 的 tocall —— 第三方统计站按它订阅就能看到「同款台站」。</li>
<li>射频路径用你在 TNC 页配的 <b>中继路径</b>（默认 <code>WIDE1-1,WIDE2-1</code>）；APRS-IS 侧自动是 <code>TCPIP*</code>。</li>
<li>注释（电量/版本）<b>紧跟定位串、中间无空格</b> —— APRS101 规范要求，解析器按此对齐。</li>
</ul>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>验证：</b>发一次手动上报 → 数据包页应看到自己那帧；几分钟后在
<a href="https://aprs.fi" target="_blank" rel="noopener">aprs.fi</a> 用呼号搜，能看到同一坐标。</p></div></div>
''', '''
<p>本應用發出的位置幀（示例取自測試用例 <code>beacon_format_test</code> / <code>afsk_test</code>）：</p>
<pre class="pkt"># 走 APRS-IS：
BG7LZG-9&gt;APALOC,TCPIP*:!3904.25N/11624.44E&gt;123/045/A=000100 Bat:88% APRSlocus v1.6.67
# 走射頻（TNC）：
BG7LZQ-9&gt;APALOC,WIDE1-1,WIDE2-1:!2230.00N/11400.00E&gt;測試</pre>
<ul>
<li><code>APALOC</code> 是 APRSLocus 的 tocall —— 第三方統計站按它訂閱就能看到「同款臺站」。</li>
<li>射頻路徑用你在 TNC 頁配的 <b>中繼路徑</b>（預設 <code>WIDE1-1,WIDE2-1</code>）；APRS-IS 側自動是 <code>TCPIP*</code>。</li>
<li>註釋（電量/版本）<b>緊跟定位串、中間無空格</b> —— APRS101 規範要求，解析器按此對齊。</li>
</ul>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>驗證：</b>發一次手動上報 → 封包頁應看到自己那幀；幾分鐘後在
<a href="https://aprs.fi" target="_blank" rel="noopener">aprs.fi</a> 用呼號搜，能看到同一座標。</p></div></div>
''', '''
<p>Position frames this app sends (examples taken from <code>beacon_format_test</code> and <code>afsk_test</code>):</p>
<pre class="pkt"># over APRS-IS:
BG7LZG-9&gt;APALOC,TCPIP*:!3904.25N/11624.44E&gt;123/045/A=000100 Bat:88% APRSlocus v1.6.67
# over RF (TNC):
BG7LZQ-9&gt;APALOC,WIDE1-1,WIDE2-1:!2230.00N/11400.00E&gt;test</pre>
<ul>
<li><code>APALOC</code> is APRSlocus’s tocall — subscribe to it on third-party trackers to find “same app” stations.</li>
<li>The RF path is the <b>digipeater path</b> you configured on the TNC page (default <code>WIDE1-1,WIDE2-1</code>); over APRS-IS it is automatically <code>TCPIP*</code>.</li>
<li>The comment (battery/version) follows the position string <b>with no space</b> — required by APRS101 and assumed by parsers.</li>
</ul>
<div class="callout tip"><span class="co-ic">✅</span><div><p><b>Verify:</b> send one manual beacon → the Packets tab shows your frame; a few minutes later
search your callsign on <a href="https://aprs.fi" target="_blank" rel="noopener">aprs.fi</a> — same coordinates.</p></div></div>
'''),
],

# ─────────────────────────── 消息与群聊 ───────────────────────────
'messaging': [
    ('send', T('发一条消息', '發一則訊息', 'Send a message'), '''
<ol class="m-steps">
<li>切到 <b>消息</b> 页签 → 右上新建（或从台站详情里点「发消息」，会自动带入呼号）。</li>
<li>输入收方呼号（<b>含 SSID，收方字段按 9 字符补位</b>，APRS101 固定字段）与内容。</li>
<li>发送后看气泡状态：<b>✓ 已确认</b> = 对方客户端回了 ACK；转圈 = 还在等；✗ = 超时。</li>
<li>历史自动保存，中文消息没问题（UTF-8 / GBK 自动解码）。</li>
</ol>
<p>消息帧长这样（取自 <code>afsk_test</code>；<code>::</code> 后是<b>收件人字段</b>，右对齐补空格到 9 字符）：</p>
<pre class="pkt">BG7LZQ-9&gt;APALOC::BA7KSM   :你好，这里是中文消息</pre>
''', '''
<ol class="m-steps">
<li>切到 <b>訊息</b> 頁籤 → 右上新增（或從臺站詳情裡點「發訊息」，會自動帶入呼號）。</li>
<li>輸入收方呼號（<b>含 SSID，收方欄位按 9 字元補位</b>，APRS101 固定欄位）與內容。</li>
<li>發送後看氣泡狀態：<b>✓ 已確認</b> = 對方用戶端回了 ACK；轉圈 = 還在等；✗ = 逾時。</li>
<li>歷史自動保存，中文訊息沒問題（UTF-8 / GBK 自動解碼）。</li>
</ol>
<p>訊息幀長這樣（取自 <code>afsk_test</code>；<code>::</code> 後是<b>收件人欄位</b>，右對齊補空格到 9 字元）：</p>
<pre class="pkt">BG7LZQ-9&gt;APALOC::BA7KSM   :你好，這裡是中文訊息</pre>
''', '''
<ol class="m-steps">
<li>Open the <b>Messages</b> tab → new conversation (or “send message” from a station detail — it fills the callsign).</li>
<li>Enter the recipient callsign (<b>with SSID; the addressee field is space-padded to 9 characters</b>, a fixed APRS101 field) and your text.</li>
<li>Watch the bubble: <b>✓ confirmed</b> = the other client returned an ACK; spinner = waiting; ✗ = timed out.</li>
<li>History is persisted and Chinese text works (UTF-8 / GBK decoded automatically).</li>
</ol>
<p>A message frame looks like this (from <code>afsk_test</code>; after <code>::</code> comes the
<b>addressee field</b>, right-aligned and padded to 9 characters):</p>
<pre class="pkt">BG7LZQ-9&gt;APALOC::BA7KSM   :Hello from APRSlocus</pre>
'''),
    ('limits', T('两条长度红线', '兩條長度紅線', 'Two hard limits'), '''
<div class="callout warn"><span class="co-ic">📏</span><div><p><b>发送前界面会预检并提示，两条都要记住：</b></p>
<ul style="margin-top:6px">
<li><b>67 字符</b> —— APRS101 的消息文本上限。超了多数客户端仍能读，少数按规范截断/拒收。</li>
<li><b>512 字节</b> —— APRS-IS 单行上限。<b>整包</b>（含报头）超了服务器可能直接丢弃，连报头都到不了对方。</li>
</ul></div></div>
<div class="callout info"><span class="co-ic">🈶</span><div><p>中文按 UTF-8 编码，<b>1 个汉字 = 3 字节</b> —— 67 字符的中文消息会更早撞上 512 字节红线。
界面按字符与字节<b>双红线</b>同时预检。</p></div></div>
''', '''
<div class="callout warn"><span class="co-ic">📏</span><div><p><b>發送前介面會預先檢查，兩條都要記住：</b></p>
<ul style="margin-top:6px">
<li><b>67 字元</b> —— APRS101 的訊息文字上限。超了多數用戶端仍能讀，少數按規範截斷/拒收。</li>
<li><b>512 位元組</b> —— APRS-IS 單行上限。<b>整包</b>（含封包頭）超了伺服器可能直接丟棄，連封包頭都到不了對方。</li>
</ul></div></div>
<div class="callout info"><span class="co-ic">🈶</span><div><p>中文用 UTF-8 編碼，<b>1 個漢字 = 3 位元組</b> —— 67 字元的中文訊息會更早撞上 512 位元組紅線。
介面按字元與位元組<b>雙紅線</b>同時預先檢查。</p></div></div>
''', '''
<div class="callout warn"><span class="co-ic">📏</span><div><p><b>The UI pre-checks both — remember them:</b></p>
<ul style="margin-top:6px">
<li><b>67 characters</b> — the APRS101 message-text cap. Most clients read beyond it; a few truncate or reject.</li>
<li><b>512 bytes</b> — the APRS-IS line cap. Over that the server may drop the <b>whole frame</b>, header included.</li>
</ul></div></div>
<div class="callout info"><span class="co-ic">🈶</span><div><p>UTF-8 makes every non-ASCII character cost more than one byte, so long messages hit the
512-byte line first. The composer pre-checks <b>both</b> limits.</p></div></div>
'''),
    ('group', T('建群与群聊', '建組與群組', 'Group chat'), '''
<ol class="m-steps">
<li>消息页新建 → 选<b>群组</b> → 起名并挑成员。</li>
<li>系统<b>自动生成群呼号</b>并发邀请，所有成员都能收到 —— 之后发言走群呼号广播。</li>
<li>群聊列表与单聊在<b>同一个会话列表</b>，用图标区分，带未读角标。</li>
</ol>
<div class="callout warn"><span class="co-ic">⚠️</span><div><p><b>射频（TNC）模式下不支持群聊广播</b>，单条长度同样受 67 字符限制 ——
信道是共享资源，一条群发会占用所有人的频点。</p></div></div>
''', '''
<ol class="m-steps">
<li>訊息頁新增 → 選<b>群組</b> → 起名並挑成員。</li>
<li>系統<b>自動產生群呼號</b>並發邀請，所有成員都能收到 —— 之後發言走群呼號廣播。</li>
<li>群組列表與單聊在<b>同一個會話列表</b>，用圖示區分，帶未讀角標。</li>
</ol>
<div class="callout warn"><span class="co-ic">⚠️</span><div><p><b>射頻（TNC）模式下不支援群組廣播</b>，單條長度同樣受 67 字元限制 ——
通道是共享資源，一條群發會佔用所有人的頻點。</p></div></div>
''', '''
<ol class="m-steps">
<li>Messages → new → <b>Group</b> → name it and pick members.</li>
<li>The app <b>generates a group callsign</b> and invites everyone — later posts broadcast on it.</li>
<li>Groups live in the <b>same conversation list</b> as direct chats, marked with an icon and unread badge.</li>
</ol>
<div class="callout warn"><span class="co-ic">⚠️</span><div><p><b>Group broadcast is unavailable in RF (TNC) mode</b> and single messages are capped at
67 characters there too — the channel is shared and one broadcast occupies everyone’s frequency.</p></div></div>
'''),
    ('translate', T('双向翻译', '雙向翻譯', 'Two-way translation'), '''
<p>路径 <b>设置 → 翻译设置</b>。多引擎、默认走免费接口、<b>无需任何密钥</b>。</p>
<ol class="m-steps">
<li><b>翻译为</b>：选目标语言（默认中文）。</li>
<li><b>翻译接口</b>：默认 auto 自动挑；可固定为 Google 公共 / MyMemory / LibreTranslate / 百度 / 自定义。
公共实例需要密钥的会标红提示，自建 Libre 可留空。</li>
<li>打开<b>自动翻译</b>：收到的消息对照原文显示译文；发送前可把自己的输入先译成对方语言。</li>
<li>点 <b>测试翻译</b> 确认链路通（译文会做有效性校验，挡掉「把原文原样返回」的假成功）。</li>
</ol>
<div class="callout info"><span class="co-ic">🔒</span><div><p>翻译请求只在应用侧发出；桌面组件那类原生界面<b>拿不到</b>你的接口密钥（它们只接收应用推的快照）。</p></div></div>
''', '''
<p>路徑 <b>設定 → 翻譯設定</b>。多引擎、預設走免費介面、<b>無需任何金鑰</b>。</p>
<ol class="m-steps">
<li><b>翻譯為</b>：選目標語言（預設中文）。</li>
<li><b>翻譯介面</b>：預設 auto 自動挑；可固定為 Google 公共 / MyMemory / LibreTranslate / 百度 / 自訂。
公共實例需要金鑰的會標紅提示，自建 Libre 可留空。</li>
<li>打開<b>自動翻譯</b>：收到的訊息對照原文顯示譯文；發送前可把自己的輸入先譯成對方語言。</li>
<li>點 <b>測試翻譯</b> 確認鏈路通（譯文會做有效性檢查，擋掉「把原文原樣回傳」的假成功）。</li>
</ol>
<div class="callout info"><span class="co-ic">🔒</span><div><p>翻譯請求只在應用側發出；桌面小組件那類原生介面<b>拿不到</b>你的介面金鑰（它們只接收應用推的快照）。</p></div></div>
''', '''
<p>Path: <b>Settings → Translation</b>. Several engines, a free endpoint by default, <b>no API key required</b>.</p>
<ol class="m-steps">
<li><b>Translate to</b>: pick the target language (Chinese by default).</li>
<li><b>Engine</b>: “auto” picks for you, or pin Google public / MyMemory / LibreTranslate / Baidu / custom. Public instances that need a key are highlighted; a self-hosted Libre can stay empty.</li>
<li>Enable <b>auto-translate</b>: incoming messages show a translation next to the original; outgoing text can be translated before sending.</li>
<li>Hit <b>test translation</b> to confirm the path works — results are validated, so a provider echoing the source back cannot fake success.</li>
</ol>
<div class="callout info"><span class="co-ic">🔒</span><div><p>Translation requests leave from the app side only; native surfaces like home-screen widgets
<b>never see</b> your API keys — they only receive snapshots the app pushes to them.</p></div></div>
'''),
],
}
