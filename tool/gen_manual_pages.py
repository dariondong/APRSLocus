#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成三语**多页用户手册** docs/{,zh-TW/,en/}manual/<page>.html（13 页 × 3 语）。

结构：
    内容   tool/manual_content.py（页面清单 + 每页导语 + 小节标题）
    正文   tool/manual_bodies.py / manual_bodies2.py（三语手写 HTML）
    设置页 tool/extract_settings.py 的抽取结果 → 逐项表格（名称/控件/默认值/说明）
    渲染   本文件

相对上一版（单页 manual.html）的修正：
    * **多页**：每章独立 URL，可单独分享、入 sitemap、带面包屑；
    * **任务式正文**：目标 → 编号步骤（菜单路径）→ 验证 → 坑（见 bodies）；
    * **设置参考**：不再是 8 行摘要，而是代码生成的逐项表。

跑法：python3 tool/gen_manual_pages.py
自检：三语齐全 / 小节 id 与正文一一对应 / 无残留占位符 / 设置抽取非空。
"""
import io
import json
import os
import posixpath
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tool'))

from manual_content import T, PAGES, PAGE_META, RELATED    # noqa: E402
from manual_bodies import BODIES                        # noqa: E402
from manual_bodies2 import BODIES as BODIES2, SETTINGS_INTRO   # noqa: E402
import extract_settings as ES                           # noqa: E402

BODIES.update(BODIES2)

SITE = 'https://aprslocus.theez.top'
LANGS = ('zh', 'zh_TW', 'en')
MOD_DATE = '2026-09-23'          # 内容最后更新日（JSON-LD dateModified、提示条）
# 永久链接 / 互链盒标题（三语）
PERMA = {'zh': '本节永久链接', 'zh_TW': '本節永久連結', 'en': 'Permalink to this section'}
RELT = {'zh': '相关章节', 'zh_TW': '相關章節', 'en': 'Related sections'}
HTML_LANG = {'zh': 'zh-CN', 'zh_TW': 'zh-TW', 'en': 'en'}
LOCALE = {'zh': 'zh_CN', 'zh_TW': 'zh_TW', 'en': 'en_US'}
# lang -> (输出目录, 资源相对前缀(到 docs/), 语言根相对前缀(到 lang 根), lang 路径段)
DEST = {
    'zh':    ('docs/manual',        '../',    '../', ''),
    'zh_TW': ('docs/zh-TW/manual',  '../../', '../', 'zh-TW/'),
    'en':    ('docs/en/manual',     '../../', '../', 'en/'),
}

HEAD = {
    'zh': dict(
        desc='APRSlocus 用户手册（13 页）：快速上手、界面导览、连接与数据来源、位置信标、'
             '消息与群聊、地图与显示、台站与筛选、导出备份轨迹、桌面组件与短波、'
             '设置参考（逐项默认值）、平台差异与故障排查。',
        ph='搜索整本手册，比如「信标」「Passcode」「离线」…',
        toc='本页目录', tree='手册目录', crumb_home='首页', crumb='手册',
        prev='上一页', next='下一页', disclaimer='本软件仅供业余无线电爱好者学习交流使用，请遵守当地无线电管理法规。'),
    'zh_TW': dict(
        desc='APRSLocus 使用手冊（13 頁）：快速上手、介面導覽、連線與資料來源、位置信標、'
             '訊息與群組、地圖與顯示、臺站與篩選、匯出備份軌跡、桌面小組件與短波、'
             '設定參考（逐項預設值）、平台差異與故障排除。',
        ph='搜尋整本手冊，例如「信標」「Passcode」「離線」…',
        toc='本頁目錄', tree='手冊目錄', crumb_home='首頁', crumb='手冊',
        prev='上一頁', next='下一頁', disclaimer='本軟體僅供業餘無線電愛好者學習交流使用，請遵守當地電波法規。'),
    'en': dict(
        desc='The APRSlocus user guide (13 pages): quick start, interface, connections and data '
             'sources, beaconing, messaging, maps and display, stations, export/backup/tracks, '
             'widgets and HF, an item-by-item settings reference, platforms and troubleshooting.',
        ph='Search the whole guide, e.g. “beacon”, “Passcode”, “offline”…',
        toc='On this page', tree='Guide contents', crumb_home='Home', crumb='Guide',
        prev='Previous', next='Next', disclaimer='For amateur radio study and exchange only — comply with your local radio regulations.'),
}

UI = {
    'zh': dict(home='首页', feat='功能', help='帮助中心', manual='手册', dl='下载',
               burger='菜单', theme='切换深色模式', theme_off='切换浅色模式',
               skip='跳到主要内容', search='搜索整本手册', foot_help='帮助中心',
               terms='用户协议', all='全部页面'),
    'zh_TW': dict(home='首頁', feat='功能', help='幫助中心', manual='手冊', dl='下載',
                  burger='菜單', theme='切換深色模式', theme_off='切換淺色模式',
                  skip='跳到主要內容', search='搜尋整本手冊', foot_help='幫助中心',
                  terms='使用者協定', all='全部頁面'),
    'en': dict(home='Home', feat='Features', help='Help Center', manual='Guide', dl='Download',
               burger='Menu', theme='Switch to dark mode', theme_off='Switch to light mode',
               skip='Skip to main content', search='Search the whole guide', foot_help='Help Center',
               terms='Terms', all='All pages'),
}

# 控件类型 → 三语标签
KIND = {
    'SettingsInput':   T('输入框', '輸入框', 'Text input'),
    'SettingsSwitch':  T('开关', '開關', 'Switch'),
    'SettingsMiniSwitch': T('小开关', '小開關', 'Small switch'),
    'SettingsRow2':    T('只读状态', '唯讀狀態', 'Read-only'),
    'SettingsNavRow':  T('入口', '入口', 'Entry'),
    '_custom':         T('选项卡', '選項卡', 'Choice card'),
    '_action':         T('按钮', '按鈕', 'Button'),
    'hub_cat':         T('分组卡', '分組卡', 'Category card'),
    'hub_entry':       T('直达入口', '直達入口', 'Direct entry'),
}
ONOFF = {True: T('开', '開', 'on'), False: T('关', '關', 'off')}
NO_DEFAULT = T('—', '—', '—')
EMPTY_STR = T('（空）', '（空）', '(empty)')


def esc(s):
    return (s or '').replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def page_path(lang, file):
    """输出路径（相对仓库根）。"""
    return '%s/%s.html' % (DEST[lang][0], file)


def site_url(lang, file):
    return '%s/%smanual/%s.html' % (SITE, DEST[lang][3], file)


def rel_url(lang, file):
    return '%smanual/%s.html' % (DEST[lang][3], file)


def cross_href(from_lang, to_lang, file):
    """同一页在另一语言下的相对链接。"""
    a = DEST[from_lang][3] + 'manual/'
    b = DEST[to_lang][3] + 'manual/'
    return posixpath.relpath(b + file + '.html', a) if a != b else file + '.html'


def glyph(hid, lang):
    """标题右侧的 # 永久链接（悬停/聚焦可见，可单条复制分享）。"""
    return ('<a class="hdr-anchor" href="#%s" aria-label="%s" title="%s">#</a>'
            % (hid, PERMA[lang], PERMA[lang]))


def sec_html(sec_id, title, body, lang):
    """章节卡片：h2 带 id + 永久链接；正文 h3 自动补 id 同样带链接。"""
    n = [0]

    def h3repl(m):
        if 'hdr-anchor' in m.group(2):
            return m.group(0)          # 设置页 h3 已在 build_settings 加过，勿重复
        hid = m.group(1) or ('%s-h%d' % (sec_id, n[0] + 1))
        if not m.group(1):
            n[0] += 1
        return '<h3 id="%s">%s%s</h3>' % (hid, m.group(2), glyph(hid, lang))

    body = re.sub(r'<h3(?:\s+id="([^"]+)")?>(.*?)</h3>', h3repl, body, flags=re.S)
    return ('  <section class="chapter reveal" id="%s">\n'
            '    <h2 id="%s">%s%s</h2>\n%s\n  </section>'
            % (sec_id, sec_id, esc(title), glyph(sec_id, lang), body))


def strip_tags(html):
    """HTML → 搜索索引用的纯文本（截 200 字）。"""
    t = re.sub(r'<[^>]+>', ' ', html)
    t = re.sub(r'&(?:amp|lt|gt|quot|#39);', ' ', t)
    return re.sub(r'\s+', ' ', t).strip()[:200]


def related_for(file, lang):
    """本页底部「相关章节」chips（标签自动取目标页/小节的三语标题）。"""
    tpage = {p['file']: p for p in PAGES}
    chips = []
    for tgt, anc in RELATED.get(file, []):
        if anc:
            href = '%s.html#%s' % (tgt, anc)
            label = dict(PAGE_META[tgt]['sections'])[anc][lang]
        else:
            href = '%s.html' % tgt
            label = tpage[tgt]['title'][lang]
        chips.append('<a href="%s">%s</a>' % (href, esc(label)))
    if not chips:
        return ''
    return ('\n    <aside class="m-related reveal" aria-label="%s">\n'
            '      <div class="mr-title">%s</div>\n'
            '      <div class="mr-links">%s</div>\n    </aside>'
            % (RELT[lang], RELT[lang], ''.join(chips)))


# ─────────────────────────── 设置页数据 ───────────────────────────
# 中文标题 → 导语键（SETTINGS_INTRO 只有中文键；其它语言按 zh 标题回查）
_ZH_TITLES = None


def zh_titles():
    global _ZH_TITLES
    if _ZH_TITLES is None:
        _ZH_TITLES = [pg['title'] for pg in ES.render(ES.build(), 'zh')]
    return _ZH_TITLES


def build_settings(lang):
    """extract_settings 的抽取结果 → 页面小节（id/标题/表格 HTML）。"""
    data = ES.render(ES.build(), lang)
    zhs = zh_titles()
    secs = []
    for i, pg in enumerate(data):
        sid = 'g%d' % i
        title = pg['title'] or pg['cls']
        zt = zhs[i] if i < len(zhs) else pg['title']
        intro = SETTINGS_INTRO.get(zt) or SETTINGS_INTRO.get(
            (zt or '').split(' · ')[-1])
        parts = ['      <h3 id="%s">%s<a class="hdr-anchor" href="#%s" aria-label="%s" '
                 'title="%s">#</a></h3>' % (sid, esc(title), sid, PERMA[lang], PERMA[lang])]
        if pg['subtitle'] and pg['subtitle'] != title:
            parts.append('      <p class="m-grp-sub">%s</p>' % esc(pg['subtitle']))
        if intro:
            parts.append('      <p>%s</p>' % intro[lang])
        for sec in pg['sections']:
            rows, seen = [], {}
            # 同一字段的多项合并为一行（选项），状态/按钮类各占一行
            for it in sec['items']:
                key = it['field'] or ('lbl:' + it['label'])
                if key in seen:
                    prev = seen[key]
                    if it['label'] and it['label'] not in prev['opts']:
                        prev['opts'].append(it['label'])
                        if it['sub']:
                            prev['subsub'].append('%s：%s' % (it['label'], it['sub']))
                    continue
                row = dict(it, opts=[], subsub=[])
                seen[key] = row
                rows.append(row)
            if not sec['title'] and not rows and not sec['note']:
                continue
            parts.append('      <div class="m-sub">')
            if sec['title']:
                parts.append('        <h4>%s</h4>' % esc(sec['title']))
            if sec['subtitle']:
                parts.append('        <p class="m-grp-sub">%s</p>' % esc(sec['subtitle']))
            if sec['note']:
                parts.append('        <div class="callout info"><span class="co-ic">ℹ️</span>'
                             '<div><p>%s</p></div></div>' % esc(sec['note']))
            if rows:
                parts.append('        <div class="doc-table-wrap"><table class="doc-table set-table">'
                             '<thead><tr><th>%s</th><th>%s</th><th>%s</th><th>%s</th></tr></thead><tbody>'
                             % (T('设置项', '設定項', 'Setting')[lang],
                                T('控件', '控件', 'Control')[lang],
                                T('默认值', '預設值', 'Default')[lang],
                                T('说明', '說明', 'Description')[lang]))
                for r in rows:
                    kind = KIND.get(r['kind'], T('控件', '控件', 'Control'))[lang]
                    # 默认值：只有可编辑控件才显示（状态/计数显示默认值会误导）
                    editable = r['kind'] in ('SettingsInput', 'SettingsSwitch',
                                             'SettingsMiniSwitch', '_custom')
                    d = NO_DEFAULT[lang]
                    if editable and r['field']:
                        dv = r['default']
                        if dv in ('true', 'false'):
                            d = ONOFF[dv == 'true'][lang]
                        elif dv == '':
                            d = EMPTY_STR[lang]
                        elif dv == 'TransProvider.auto':
                            d = 'auto'
                        else:
                            d = '<code>%s</code>' % esc(dv)
                    label = esc(r['label'])
                    if r['opts']:
                        label += '<span class="m-opts">%s</span>' % \
                            ' · '.join(esc(o) for o in r['opts'])
                    desc = ' / '.join(x for x in (r['tip'] or r['hint'] or '',
                                                  r['sub'], *r['subsub']) if x)
                    fld = '<code class="m-field">%s</code>' % esc(r['field']) if r['field'] and editable else ''
                    parts.append(
                        '<tr><td><b>%s</b>%s</td><td><span class="m-kind">%s</span></td>'
                        '<td class="m-def">%s</td><td>%s</td></tr>'
                        % (label, (' ' + fld) if fld else '', kind, d, esc(desc)))
                parts.append('</tbody></table></div>')
            parts.append('      </div>')
        secs.append(dict(id=sid, title=title, html='\n'.join(parts)))
    return secs


# ─────────────────────────── 渲染 ───────────────────────────
def render_head(lang, file, title, desc, anchors):
    out_dir, asset, _langroot, langseg = DEST[lang]
    canonical = site_url(lang, file)
    hreflangs = '\n'.join(
        '    <link rel="alternate" hreflang="%s" href="%s">' % (fl, site_url(l, file))
        for fl, l in (('zh-CN', 'zh'), ('zh-TW', 'zh_TW'), ('en', 'en'),
                      ('x-default', 'zh')))
    ld = {
        '@context': 'https://schema.org', '@type': 'TechArticle',
        'name': title, 'description': desc, 'url': canonical,
        'inLanguage': HTML_LANG[lang],
        'dateModified': MOD_DATE, 'articleSection': title,
        'author': {'@type': 'Person', 'name': 'BG7LZQ (Darion)'},
        'publisher': {'@type': 'Organization', 'name': 'APRSlocus',
                      'logo': {'@type': 'ImageObject', 'url': SITE + '/assets/logo.png'}},
        'mainEntityOfPage': {'@type': 'WebPage', '@id': canonical},
        'breadcrumb': {'@type': 'BreadcrumbList', 'itemListElement': [
            {'@type': 'ListItem', 'position': 1, 'name': 'APRSlocus', 'item': SITE + '/'},
            {'@type': 'ListItem', 'position': 2, 'name': HEAD[lang]['crumb'],
             'item': SITE + '/' + rel_url(lang, 'index')},
            {'@type': 'ListItem', 'position': 3, 'name': title, 'item': canonical},
        ]},
    }
    title_esc = esc(title)
    desc_esc = esc(desc)
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
<meta property="og:url" content="{canonical}">
<meta property="og:image" content="{site}/assets/logo.png">
<meta property="og:locale" content="{locale}">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="{title}">
<meta name="twitter:description" content="{desc}">
<link rel="canonical" href="{canonical}">
{hreflangs}
<link rel="icon" type="image/png" href="{asset}assets/favicon.png">
<link rel="stylesheet" href="{asset}css/style.css?v=5">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.6.0/css/all.min.css">
<script>
/* 主题：localStorage 优先，否则跟随系统；首帧前执行防闪白 */
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
{ld}
</script>
<noscript><style>.reveal{{opacity:1;transform:none}}.manual-tools{{display:none}}</style></noscript>
</head>
<body>
'''.format(html_lang=HTML_LANG[lang], title=title_esc, desc=desc_esc,
           canonical=canonical, site=SITE, locale=LOCALE[lang],
           hreflangs=hreflangs, asset=asset,
           ld=json.dumps(ld, ensure_ascii=False, indent=2))


def render_chrome(lang, file, idx, anchors):
    """nav + 面包屑 + 侧栏 + 正文容器 + 页脚 + 页内脚本（正文由 body 参数传入）。"""
    out_dir, asset, langroot, langseg = DEST[lang]
    u, h = UI[lang], HEAD[lang]

    # 语言切换（同一页面跨语言）
    langsw = ''.join(
        '<a class="lang-switch%s" href="%s" hreflang="%s">%s</a>' % (
            ' active' if l == lang else '', cross_href(lang, l, file),
            'zh-Hans' if l == 'zh' else ('zh-Hant' if l == 'zh_TW' else 'en'),
            {'zh': '简中', 'zh_TW': '繁中', 'en': 'EN'}[l])
        for l in LANGS)

    # 侧栏：全书树 + 本页锚点
    tree = []
    for i, p in enumerate(PAGES):
        cur = ' class="active"' if i == idx else ''
        tree.append('        <a href="%s"%s>%s</a>' % (
            p['file'] + '.html', cur, p['title'][lang]))
    anchors_html = ''
    if anchors:
        items = '\n'.join('        <a href="#%s">%s</a>' % (a, t) for a, t in anchors)
        anchors_html = '\n      <div class="mn-title">%s</div>\n%s' % (h['toc'], items)

    prev_p = PAGES[idx - 1] if idx > 0 else None
    next_p = PAGES[idx + 1] if idx + 1 < len(PAGES) else None
    pager = ''
    if prev_p or next_p:
        pl = ('<a class="pg-prev" href="%s">← %s</a>' % (prev_p['file'] + '.html', esc(prev_p['title'][lang]))
              if prev_p else '<span></span>')
        nl = ('<a class="pg-next" href="%s">%s →</a>' % (next_p['file'] + '.html', esc(next_p['title'][lang]))
              if next_p else '<span></span>')
        pager = '\n  <nav class="doc-pager" aria-label="%s">%s%s</nav>' % (h['next'], pl, nl)

    return dict(
        langsw=langsw, tree='\n'.join(tree), anchors=anchors_html, pager=pager,
        asset=asset, langroot=langroot, u=u, h=h,
        home_href=langroot + 'index.html', faq_href=langroot + 'faq.html',
        manual_href='index.html')


def render_page(lang, file, idx, title, lead, body_html, related, anchors):
    ch = render_chrome(lang, file, idx, anchors)
    u, h, asset = ch['u'], ch['h'], ch['asset']
    body = '''<div class="scroll-progress" id="scrollProgress"></div>

<div class="bg-blobs" aria-hidden="true">
  <span class="blob b1"></span><span class="blob b2"></span>
  <span class="blob b3"></span><span class="blob b4"></span>
</div>

<header class="nav" id="nav">
  <div class="nav-inner">
    <a class="brand" href="{langroot}">
      <img class="brand-logo" src="{asset}assets/logo.png" alt="APRSlocus">
      <span class="brand-name">APRSlocus</span>
    </a>
    <nav class="nav-links" id="navLinks">
      <a href="{langroot}">{home}</a>
      <a href="{langroot}#features">{feat}</a>
      <a href="{faq}">{help}</a>
      <a href="index.html" class="active">{manual}</a>
      <a class="nav-cta" href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">{dl}</a>
      <button class="theme-toggle" id="themeToggle" type="button" aria-pressed="false" aria-label="{theme}" title="{theme}" data-label-dark="{theme_off}" data-label-light="{theme}"><i class="fa-solid fa-moon" aria-hidden="true"></i></button>
      <span class="lang-switch-group">{langsw}</span>
    </nav>
    <button class="nav-burger" id="navBurger" aria-label="{burger}" aria-expanded="false">
      <span></span><span></span><span></span>
    </button>
  </div>
</header>

<main id="main">
<a class="skip-link" href="#main">{skip}</a>

<section class="section" id="manual">
  <nav class="doc-crumb reveal" aria-label="{crumb}">
    <a href="{langroot}">{crumb_home}</a><span aria-hidden="true">/</span>
    <a href="index.html">{crumb}</a><span aria-hidden="true">/</span>
    <span aria-current="page">{crumb_now}</span>
  </nav>
  <div class="section-head reveal">
    <h1>{h1}</h1>
    <p>{lead}</p>
  </div>

  <div class="manual-tools reveal">
    <div class="faq-search">
      <i class="fa-solid fa-magnifying-glass" aria-hidden="true"></i>
      <input type="search" id="manualFilter" placeholder="{ph}" aria-label="{search}" autocomplete="off">
    </div>
    <p class="faq-nohit" id="manualNohit" hidden>{nohit}</p>
    <ul class="ms-results" id="manualResults" hidden></ul>
    <p class="ms-none" id="manualNone" hidden>{msnone}</p>
  </div>

  <div class="manual-layout">
    <nav class="manual-nav reveal" aria-label="{tree_label}">
      <div class="mn-title">{tree_title}</div>
{tree}{anchors}
    </nav>
    <div class="manual-body">
{body}
{related}
    </div>
  </div>
{pager}
</section>
</main>

<footer class="footer">
  <div class="footer-inner">
    <div class="footer-top">
      <div class="footer-brand">
        <img src="{asset}assets/logo.png" alt="APRSlocus">
        <div><b>APRSlocus</b><span>APR Tracking &amp; Mapping</span></div>
      </div>
      <div class="footer-links">
        <a href="{langroot}">{home}</a>
        <a href="{langroot}#features">{feat}</a>
        <a href="{langroot}#faq">{faq_anchor}</a>
        <a href="{faq}">{foot_help}</a>
        <a href="index.html">{foot_manual}</a>
        <a href="https://github.com/dariondong/APRSLocus/releases" target="_blank" rel="noopener">Releases</a>
      </div>
    </div>
    <div class="footer-bottom">
      <span>© <span id="year">2026</span> BG7LZQ (Darion) · <a href="https://github.com/dariondong/APRSLocus/blob/main/LICENSE" target="_blank" rel="noopener">GPL-3.0</a> · <a href="{langroot}terms.html">{terms}</a></span>
      <span class="disclaimer">{disclaimer}</span>
    </div>
  </div>
</footer>

<a class="backtop" id="backTop" href="#manual" aria-label="{back}">
  <svg class="backtop-ring" viewBox="0 0 40 40">
    <circle class="ring-bg" cx="20" cy="20" r="17"/>
    <circle class="ring-fg" id="ringFg" cx="20" cy="20" r="17"/>
  </svg>
  <svg class="backtop-arrow" viewBox="0 0 24 24"><path d="M12 5l7 7-1.4 1.4L13 8.8V20h-2V8.8l-4.6 4.6L5 12l7-7z"/></svg>
</a>

<script src="{asset}js/main.js"></script>
<script>
/* 手册页专属：小节搜索 + 侧栏 scrollspy（无 JS 时正文照常可读） */
(function () {{
  "use strict";
  var input = document.getElementById('manualFilter');
  var nohit = document.getElementById('manualNohit');
  var res = document.getElementById('manualResults');
  var none = document.getElementById('manualNone');
  var chapters = Array.prototype.slice.call(document.querySelectorAll('.chapter'));
  var here = (location.pathname.split('/').pop()) || 'index.html';
  var idx = null, loading = false;
  function esc(s) {{
    return String(s).replace(/[&<>"]/g, function (c) {{
      return {{'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;'}}[c];
    }});
  }}
  function loadIdx() {{
    if (idx || loading) return;
    loading = true;
    fetch('_index.json')
      .then(function (r) {{ return r.json(); }})
      .then(function (d) {{ idx = d; drawOthers(); }})
      .catch(function () {{ idx = []; }});
  }}
  function drawOthers() {{
    if (!res || !idx) return;
    var kw = input.value.trim().toLowerCase();
    res.innerHTML = '';
    if (!kw) {{ res.hidden = true; if (none) none.hidden = true; return; }}
    var hits = idx.filter(function (e) {{
      if (e.u.split('#')[0] === here) return false;
      return (e.s || '').toLowerCase().indexOf(kw) !== -1 ||
             (e.p || '').toLowerCase().indexOf(kw) !== -1 ||
             (e.t || '').toLowerCase().indexOf(kw) !== -1;
    }}).slice(0, 8);
    var frag = document.createDocumentFragment();
    hits.forEach(function (e) {{
      var li = document.createElement('li');
      var a = document.createElement('a');
      a.href = e.u;
      a.innerHTML = '<b>' + esc(e.s || e.p) + '</b>' +
        (e.s ? '<span>' + esc(e.p) + '</span>' : '');
      li.appendChild(a);
      frag.appendChild(li);
    }});
    res.appendChild(frag);
    res.hidden = hits.length === 0;
    if (none) none.hidden = hits.length !== 0;
  }}
  if (input) {{
    input.addEventListener('focus', loadIdx);
    input.addEventListener('input', function () {{
      var kw = input.value.trim().toLowerCase();
      var hits = 0;
      chapters.forEach(function (sec) {{
        var ok = !kw || (sec.textContent || '').toLowerCase().indexOf(kw) !== -1;
        sec.hidden = !ok;
        if (ok) hits++;
      }});
      if (nohit) nohit.hidden = hits !== 0;
      loadIdx();
      drawOthers();
    }});
    document.addEventListener('click', function (ev) {{
      if (res && !res.contains(ev.target) && ev.target !== input) res.hidden = true;
    }});
  }}
  var tocLinks = Array.prototype.slice.call(document.querySelectorAll('.manual-nav a[href^="#"]'));
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
        asset=asset, langroot=ch['langroot'], faq=ch['faq_href'],
        home=u['home'], feat=u['feat'], help=u['help'], manual=u['manual'],
        dl=u['dl'], theme=u['theme'], theme_off=u['theme_off'], langsw=ch['langsw'],
        burger=u['burger'], skip=u['skip'], crumb=h['crumb'], crumb_home=h['crumb_home'],
        crumb_now=esc(title), h1=esc(title), lead=esc(lead),
        ph=HEAD[lang]['ph'], search=u['search'],
        nohit={'zh': '没有匹配的小节，换个关键词试试。',
               'zh_TW': '沒有符合的小節，換個關鍵詞試試。',
               'en': 'No matching section — try another keyword.'}[lang],
        tree_label=h['tree'], tree_title=h['tree'], tree=ch['tree'], anchors=ch['anchors'],
        body=body_html, related=related, pager=ch['pager'],
        msnone={'zh': '手册其它页面也没有匹配。',
                'zh_TW': '手冊其它頁面也沒有符合。',
                'en': 'No matches elsewhere in the guide.'}[lang],
        foot_help=u['foot_help'], foot_manual=u['manual'],
        faq_anchor={'zh': '问答', 'zh_TW': '問答', 'en': 'FAQ'}[lang],
        terms=u['terms'], disclaimer=h['disclaimer'],
        back={'zh': '回到顶部', 'zh_TW': '回到頂部', 'en': 'Back to top'}[lang])
    # head 之外还要带 body：由 main 拼接
    return body


def lead_of(lang, meta, title):
    return meta['lead'][lang] if meta and meta.get('lead') else ''


def main():
    # ── 自检：三语齐全、小节 id 对齐 ──
    for p in PAGES:
        meta = PAGE_META[p['file']]
        for f in ('title',):
            for l in LANGS:
                assert p[f].get(l), '%s 缺 %s' % (p['file'], f)
        for l in LANGS:
            assert meta['lead'].get(l), '%s 缺 lead(%s)' % (p['file'], l)
        sec_ids = [s[0] for s in meta['sections']]
        if p['file'] != 'settings':
            bodies = BODIES[p['file']]
            body_ids = [b[0] for b in bodies]
            assert sec_ids == body_ids, \
                '%s 小节不一致: meta=%s body=%s' % (p['file'], sec_ids, body_ids)
            for row in bodies:
                assert len(row) == 5, '%s 小节元组应为 (id, T, zh, zh_TW, en)，实际 %d 元' % (
                    p['file'], len(row))
                sid, h3 = row[0], row[1]
                for l in LANGS:
                    assert h3.get(l), '%s/%s 缺标题 %s' % (p['file'], sid, l)
                for bi, l in enumerate(LANGS, start=2):
                    assert row[bi].strip(), '%s/%s 缺 %s 正文' % (p['file'], sid, l)
        for l in LANGS:
            assert not re.search(r'\bNone\b', str(meta)), 'meta 含 None'

    settings_secs = {l: build_settings(l) for l in LANGS}
    for l in LANGS:
        assert settings_secs[l], '设置页抽取为空'
    n_items = sum(len(s['items']) for p in ES.build() for s in p['sections'])
    print('设置抽取：%d 页 · %d 项' % (len(ES.build()), n_items))

    index_pages = {l: [] for l in LANGS}
    for lang in LANGS:
        written = 0
        for idx, p in enumerate(PAGES):
            file = p['file']
            meta = PAGE_META[file]
            title = '%s — %s' % (p['title'][lang], 'APRSlocus')
            desc = meta['lead'][lang]
            if file == 'settings':
                secs = settings_secs[lang]
                body_html = '\n'.join(
                    sec_html(s['id'], s['title'], s['html'], lang) for s in secs)
                anchors = [(s['id'], s['title']) for s in secs]
            else:
                chunks, anchors = [], []
                for sid, h3, *langs in BODIES[file]:
                    m = dict(meta['sections'])[sid]
                    anchors.append((sid, m[lang]))
                    body = dict(zip(LANGS, langs))[lang]
                    chunks.append(sec_html(sid, m[lang], body.strip(), lang))
                body_html = '\n'.join(chunks)
            # 跨页搜索索引：页面级 + 小节级（标题命中权重最高，文本命中兜底）
            index_pages[lang].append({'u': file + '.html', 'p': p['title'][lang],
                                      's': '', 't': strip_tags(meta['lead'][lang])})
            if file == 'settings':
                for s in secs:
                    index_pages[lang].append({'u': '%s.html#%s' % (file, s['id']),
                                              'p': p['title'][lang], 's': s['title'],
                                              't': strip_tags(s['html'])})
            else:
                for sid2, _h3, *lgs in BODIES[file]:
                    index_pages[lang].append({
                        'u': '%s.html#%s' % (file, sid2), 'p': p['title'][lang],
                        's': dict(meta['sections'])[sid2][lang],
                        't': strip_tags(dict(zip(LANGS, lgs))[lang])})
            related_html = related_for(file, lang)
            html = render_head(lang, file, title, desc, anchors) + \
                render_page(lang, file, idx, p['title'][lang], meta['lead'][lang],
                            body_html, related_html, anchors)
            out = os.path.join(ROOT, page_path(lang, file))
            os.makedirs(os.path.dirname(out), exist_ok=True)
            io.open(out, 'w', encoding='utf-8', newline='\n').write(html)
            written += 1
        out_idx = os.path.join(ROOT, DEST[lang][0], '_index.json')
        json.dump(index_pages[lang], io.open(out_idx, 'w', encoding='utf-8'),
                  ensure_ascii=False)
        print('%-6s %2d 页 · %3d 条搜索索引 → %s/_index.json'
              % (lang, written, len(index_pages[lang]), DEST[lang][0]))

    # 旧单页 URL → 跳转桩（已分享出去的链接不 404；重跑生成器不会误删）
    stubs = {
        'docs/manual.html': ('manual/index.html', 'zh-CN', '用户手册'),
        'docs/zh-TW/manual.html': ('index.html', 'zh-TW', '使用手冊'),
        'docs/en/manual.html': ('index.html', 'en', 'User Guide'),
    }
    for path, (dest, ld, ttl) in stubs.items():
        if path.startswith('docs/zh-TW/'):
            base = SITE + '/zh-TW/manual/index.html'
        elif path.startswith('docs/en/'):
            base = SITE + '/en/manual/index.html'
        else:
            base = SITE + '/manual/index.html'
        html = ('<!DOCTYPE html>\n<html lang="%s">\n<head>\n<meta charset="UTF-8">\n'
                '<meta name="viewport" content="width=device-width, initial-scale=1.0">\n'
                '<title>%s — APRSlocus</title>\n<meta name="robots" content="noindex">\n'
                '<link rel="canonical" href="%s">\n'
                '<meta http-equiv="refresh" content="0; url=%s">\n'
                '<script>location.replace("%s");</script>\n</head>\n'
                '<body>\n<p><a href="%s">%s</a></p>\n</body>\n</html>\n'
                % (ld, ttl, base, dest, dest, dest, ttl))
        io.open(os.path.join(ROOT, path), 'w', encoding='utf-8', newline='\n').write(html)
        print('stub', path, '→', dest)
    print('\n✅ 三语多页手册已生成（13 页 × 3 语，含代码生成的设置逐项表）')


if __name__ == '__main__':
    main()
