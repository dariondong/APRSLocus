#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把「app 内公告」（docs/notice/<lang>.md）同步为官网首页的公告区（#announce）。

## 为什么需要它

用户的要求是「**改一处，两边同源**」：app 内公告读的是 `docs/notice/<lang>.md`，
官网首页那条公告是 HTML —— 两边各写一份必然漂移（改了 app 忘了官网、或反过来）。
本脚本让 **Markdown 成为唯一源**，官网公告区由它生成。

## 方向

    docs/notice/{zh,zh_TW,en}.md   （唯一手写处：app 与官网共用）
                │  sync_notice_site.py
                ▼
    docs/{index.html, zh-TW/index.html, en/index.html} 的 #announce 区

> 注意：这与 `tool/sync_notice_md.py`（**已废弃**，HTML→md）方向相反。
> 现在唯一正确的方向是 **md → 官网**。

## 只支持公告用到的 Markdown 子集（有意保持简单）

    # 标题            → 不渲染（标题走 HEAD 配置，见下）
    ## / ### 小节      → 加粗段落
    ---               → 忽略
    **粗体**           → <b>
    [文字](链接)       → <a target=_blank rel=noopener>
    - 列表项           → <ul><li>…
    > 引用             → 引用块（同一段连续引用合并为一行，<br> 连接）
    @video <URL>      → 内嵌 B 站播放器 iframe

## 幂等

按标记块替换：只重写 `<header class="announce-head">` 与
`<div class="announce-body">…</div>`（到 `<div class="announce-actions">` 为止），
可反复运行、不会叠加。

跑法：python3 tool/sync_notice_site.py
退出码 0 = 已同步；1 = 结构不对（页面里找不到公告区标记）。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 语言 → (官网页面, app 公告 md)
PAGES = [
    ('zh', 'docs/index.html', 'docs/notice/zh.md'),
    ('zh_TW', 'docs/zh-TW/index.html', 'docs/notice/zh_TW.md'),
    ('en', 'docs/en/index.html', 'docs/notice/en.md'),
]

# 官网公告卡片的头部（kicker / 标题 / 英文小字 / 导语）。
# 为什么不从 md 的 `#` 标题推：md 标题是「📡 APRSLocus 2.0 已上线 · TOUCH SKY」，
# 而卡片标题要的是「TOUCH SKY」+ 右侧小字，推不出来（也不该推）。
HEAD = {
    'zh': {
        'kicker': '1.5.8 → 2.0 · 322 次更新',
        'title': 'TOUCH SKY',
        'en': "2.0 已上线 · What's New",
        'sub': '从 FIRST FIX 到 TOUCH SKY：1.0 让我们站稳，2.0 让我们仰望。这一次，我们把坐标点亮到了天上。',
    },
    'zh_TW': {
        'kicker': '1.5.8 → 2.0 · 322 次更新',
        'title': 'TOUCH SKY',
        'en': "2.0 已上線 · What's New",
        'sub': '從 FIRST FIX 到 TOUCH SKY：1.0 讓我們站穩，2.0 讓我們仰望。這一次，我們把座標點亮到了天上。',
    },
    'en': {
        'kicker': '1.5.8 → 2.0 · 322 updates',
        'title': 'TOUCH SKY',
        'en': "2.0 is out · What's New",
        'sub': 'From FIRST FIX to TOUCH SKY: 1.0 made us stand firm, 2.0 made us look up. This time, we lit our coordinates into the sky.',
    },
}

VIDEO_TPL = (
    '<div style="position:relative;width:100%;max-width:760px;margin:6px auto;'
    'aspect-ratio:16/9;border-radius:14px;overflow:hidden;background:#000">\n'
    '<iframe src="{url}" scrolling="no" border="0" frameborder="no" '
    'framespacing="0" allowfullscreen="true" '
    'style="position:absolute;inset:0;width:100%;height:100%"></iframe>\n'
    '</div>'
)


def read(rel):
    return io.open(os.path.join(ROOT, rel), encoding='utf-8', newline='').read()


def write(rel, text):
    io.open(os.path.join(ROOT, rel), 'w', encoding='utf-8', newline='').write(text)


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def inline(s):
    """行内 Markdown → HTML。先转义再替换，顺序不能反。"""
    t = esc(s)
    t = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', t)
    t = re.sub(r'\[([^\]]+)\]\(([^)]+)\)',
               r'<a href="\2" target="_blank" rel="noopener">\1</a>', t)
    return t


def render_head(lang):
    h = HEAD[lang]
    return ('    <header class="announce-head">\n'
            '      <p class="announce-kicker">%s</p>\n'
            '      <h2 class="announce-title">%s<span class="announce-en">%s</span></h2>\n'
            '      <p class="announce-sub">%s</p>\n'
            '    </header>' % (esc(h['kicker']), esc(h['title']), esc(h['en']), esc(h['sub'])))


def render_body(md_text):
    """公告 Markdown → 卡片正文 HTML（缩进 6 空格，与页面既有排版一致）。"""
    lines = md_text.replace('\r\n', '\n').split('\n')
    out = []
    i = 0
    n = len(lines)
    while i < n:
        raw = lines[i]
        s = raw.strip()
        if not s:
            i += 1
            continue
        if s.startswith('# '):          # 标题走 HEAD，正文里跳过
            i += 1
            continue
        if s.startswith('## ') or s.startswith('### '):
            out.append('<p><b>%s</b></p>' % inline(s.lstrip('#').strip()))
            i += 1
            continue
        if s == '---':
            i += 1
            continue
        if s.startswith('@video '):
            url = s[len('@video '):].strip()
            out.append(VIDEO_TPL.format(url=esc(url)))
            i += 1
            continue
        if s.startswith('>'):
            buf = []
            while i < n and lines[i].strip().startswith('>'):
                buf.append(inline(lines[i].strip()[1:].strip()))
                i += 1
            out.append('<p class="announce-quote">%s</p>' % '<br>'.join(buf))
            continue
        if s.startswith('- '):
            items = []
            while i < n and lines[i].strip().startswith('- '):
                items.append('<li>%s</li>' % inline(lines[i].strip()[2:].strip()))
                i += 1
            out.append('<ul class="announce-list">%s</ul>' % ''.join(items))
            continue
        out.append('<p>%s</p>' % inline(s))
        i += 1
    # 每个块整体缩进 6 空格（多行块逐行加，避免只缩进首行）
    return '\n'.join('\n'.join('      ' + ln for ln in b.split('\n')) for b in out)


# 旧版简中页曾有过 2.0 倒计时脚本：公告改为「已上线」后不再需要，同步时顺手清掉。
_COUNTDOWN_RE = re.compile(
    r'\s*<script>\s*\(function\(\)\{\s*var target = new Date\(2026, 8, 25[\s\S]*?</script>')


def sync_page(lang, page_rel, md_rel):
    page = read(page_rel)
    md_text = read(md_rel)

    if '<header class="announce-head">' not in page or \
            '<div class="announce-body">' not in page or \
            '<div class="announce-actions">' not in page:
        return False, '找不到公告区标记（announce-head / announce-body / announce-actions）'

    # 1) 头部（从**行首**替换：否则前缀空白会在每次运行时累加）
    h0 = page.index('<header class="announce-head">')
    hs = page.rfind('\n', 0, h0) + 1
    h1 = page.index('</header>', h0) + len('</header>')
    page = page[:hs] + render_head(lang) + page[h1:]

    # 2) 正文（保留 wrappers；到 actions 之前；同样从行首替换）
    b0 = page.index('<div class="announce-body">')
    bs = page.rfind('\n', 0, b0) + 1
    b1 = page.index('<div class="announce-actions">')
    av = page.rfind('\n', 0, b1) + 1
    body = render_body(md_text)
    page = (page[:bs] + '    <div class="announce-body">\n' + body
            + '\n    </div>\n\n' + page[av:])

    # 3) 清掉旧倒计时脚本（幂等：没有就什么都不做）
    page = _COUNTDOWN_RE.sub('', page)

    write(page_rel, page)
    return True, None


def main():
    ok = True
    for lang, page_rel, md_rel in PAGES:
        done, err = sync_page(lang, page_rel, md_rel)
        if done:
            print('✓ %s ← %s' % (page_rel, md_rel))
        else:
            ok = False
            print('✗ %s: %s' % (page_rel, err))
    if not ok:
        return 1
    print('\n同步完成：官网三语公告区已由 docs/notice/*.md 生成（改 md 后重跑本脚本）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
