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
# 顺序即展示顺序；图标类名 c1~c14 见 docs/css/style.css。
# 总数 14：4 列时末行 2 张、2 列时 7 行，两种断点都不会剩孤零零一张。
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
]

# ─────────────────────────── 更新日志重点版本 ───────────────────────────
# new / up / fix 对应页面既有的三个圆点颜色（绿 / 琥珀 / 红）。
# 只列「重点版本」：中间几十个纯修 bug 的版本归纳进文字说明，完整记录指向 Releases。
CL = [
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
            bad = [ch for ch in '连发条来设备页题单网络报频率识环钥译对开关机边缘错击码'
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
