#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把官网首页的「公告」区**生成**为 `docs/notice/<语言>.md`（应用内的公告横幅读它）。

> ⚠️ **已废弃（DEPRECATED）**：公告现在改为**手写 Markdown**
> （`docs/notice/<lang>.md` 就是唯一来源，见 `tool/check_notice.py`），
> 因为公告越来越长（多级标题、`@video` 内嵌视频），固定字段的生成式表达不了。
> **不要再跑本脚本** —— 它会用官网首页那段固定字段把整篇手写公告覆盖掉。
> 保留此文件仅供历史参考。

## 为什么是「生成」而不是「再手写一份」

用户的要求是：把官网那条公告搬进公告文件夹，让**官网与应用共一份内容**
（官网发什么，应用横幅就显示什么）。

如果两边各写一份，它们一定会漂 —— 而公告恰恰是「改了就要立刻生效、没人会核对
两份」的东西。所以这里定下**唯一手写处 = 官网首页的 `<section id="announce">`**
（作者按原来的方式改 HTML，样式、按钮那些都在原地），
`docs/notice/*.md` 由本脚本从它生成，应用只读生成出来的 Markdown。

漂移由 `tool/check_notice.py` 在 CI 里盯着：它会把「本脚本生成的内容」与
「仓库里那份 .md」逐字节比对，不一致就报红（提示跑一次本脚本）。

## 语言对应

只生成官网真正有的三种：`docs/index.html` → `zh`、`docs/zh-TW/index.html` →
`zh_TW`、`docs/en/index.html` → `en`。
其它语言（ja / es / id）**不生成**：应用的兜底链会退回 `en.md` —— 与官网
本身只有三语是一致的；将来某语言要单独发公告，手写一份 `docs/notice/ja.md`
即可（本脚本不会删它）。

## 映射规则（有意保持简单）

    kicker（小字）          → **加粗一行**（应用里就是一行小标题）
    title（+ 右侧小字）      → `# 标题 · 小字`（应用横幅用它当摘要）
    sub（导语）              → 普通段落
    greet / 正文段落          → 普通段落（`<b>` → `**粗体**`）
    announce-quote          → 引用块（`<br>` → Markdown 硬换行）
    announce-sign 三行       → 引用块三行（同上）
    底部按钮（非锚点）        → 末尾「相关链接」列表（去掉 `#community` 这种页内锚点：
                             应用里没有对应位置，留着就是个点不动的死链）

跑法：python3 tool/sync_notice_md.py
退出码 0 = 已同步（含「本来就已经一致」）；1 = 官网公告区解析失败（并说明缺了什么）。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 语言 → 官网页面（只生成官网真正有的三种）
PAGES = [
    ('zh', 'docs/index.html'),
    ('zh_TW', 'docs/zh-TW/index.html'),
    ('en', 'docs/en/index.html'),
]

SECTION_RE = re.compile(
    r'<section class="section announce" id="announce">(?P<body>[\s\S]*?)</section>')
FIELD = {
    'kicker': r'<p class="announce-kicker">([\s\S]*?)</p>',
    'title': r'<h2 class="announce-title">([\s\S]*?)</h2>',
    'title_en': r'<span class="announce-en">([\s\S]*?)</span>',
    'sub': r'<p class="announce-sub">([\s\S]*?)</p>',
    'greet': r'<p class="announce-greet">([\s\S]*?)</p>',
    'quote': r'<p class="announce-quote">([\s\S]*?)</p>',
    'sign': r'<div class="announce-sign">([\s\S]*?)</div>',
}


def read(rel):
    return io.open(os.path.join(ROOT, rel), encoding='utf-8').read()


def write(rel, text):
    p = os.path.join(ROOT, rel)
    io.open(p, 'w', encoding='utf-8', newline='').write(text)


def inline(html):
    """行内 HTML → Markdown（只处理公告里实际会出现的几种）。

    两处曾经写错、值得记下来：
      * `<br>` 必须变成**真换行**。第一版把它换成一个占位符 `\x00`，但后面又用
        **原始 html**（不含占位符）去做粗体替换，占位符被丢掉 —— 结果是引用里的
        换行整段消失，两句话挤成一行。
      * 粗体直接按「成对标签」替换：`</?b>` → `**`，`<b>x</b>` 正好得到
        `**x**`。不要去判断「是不是整段包住」——公告里本来就是。
    """
    t = re.sub(r'<br\s*/?>', '\n', html)
    t = re.sub(r'</?b>|</?strong>', '**', t)
    t = re.sub(r'<[^>]+>', '', t)
    return unescape(t).strip()


def unescape(s):
    for a, b in (('&amp;', '&'), ('&lt;', '<'), ('&gt;', '>'),
                 ('&quot;', '"'), ('&#39;', "'"), ('&nbsp;', ' ')):
        s = s.replace(a, b)
    return s


def paras(html):
    """body 里的全部 `<p>`（按出现顺序），保留各自的 class 供后续分类。"""
    out = []
    for m in re.finditer(r'<p(?:\s+class="([^"]*)")?>([\s\S]*?)</p>', html):
        out.append((m.group(1) or '', m.group(2)))
    return out


def render_md(page_html):
    m = SECTION_RE.search(page_html)
    if not m:
        return None, '找不到 `<section id="announce">`'
    sect = m.group('body')
    got = {}
    for k, pat in FIELD.items():
        mm = re.search(pat, sect)
        got[k] = mm.group(1).strip() if mm else None
    if not got['title']:
        return None, '公告区里没有 `<h2 class="announce-title">`'

    lines = []
    # ① 标题（应用横幅的摘要就是它）
    #    必须**先剥掉 `<span class="announce-en">`** 再 inline：否则小字会被
    #    当成标题正文拼进去，再在下面重复一遍（第一版就是这么写出
    #    「TOUCH SKY感谢公告 · A Thank-You Letter · 感谢公告 · A Thank-You Letter」的）
    title = inline(re.sub(r'<span class="announce-en">[\s\S]*?</span>', '',
                          got['title']))
    if got['title_en']:
        title = f"{title} · {inline(got['title_en'])}"
    lines.append(f'# {title}')
    lines.append('')
    # ② kicker / 导语
    if got['kicker']:
        lines.append(f'**{inline(got["kicker"])}**')
        lines.append('')
    if got['sub']:
        lines.append(inline(got['sub']))
        lines.append('')
    # ③ 正文：greet + 普通段落（跳过上面已单独处理的 kicker/sub/quote）
    for cls, body in paras(sect):
        if cls in ('announce-kicker', 'announce-sub', 'announce-quote'):
            continue
        text = inline(body).strip()
        if not text:
            continue
        lines.append(text)
        lines.append('')
    # ④ 引用段落
    if got['quote']:
        q = inline(got['quote'])
        parts = [p.strip() for p in q.split('\n') if p.strip()]
        for p in parts:
            lines.append(f'> {p}' + ('  ' if p is not parts[-1] else ''))
        lines.append('')
    # ⑤ 落款（三行，同为引用块）
    if got['sign']:
        spans = re.findall(r'<span[^>]*>([\s\S]*?)</span>', got['sign'])
        spans = [inline(s) for s in spans if inline(s)]
        for i, s in enumerate(spans):
            lines.append(f'> {s}' + ('  ' if i < len(spans) - 1 else ''))
        lines.append('')
    # ⑥ 相关链接（底部按钮；跳过页内锚点）
    links = []
    for mm in re.finditer(r'<a class="btn[^"]*" href="([^"]+)"[^>]*>([\s\S]*?)</a>',
                          sect):
        href, label = mm.group(1), mm.group(2)
        label = inline(re.sub(r'<svg[\s\S]*?</svg>', '', label))
        label = re.sub(r'<[^>]+>', '', label).strip()
        if href.startswith('#') or not label:
            continue
        links.append((label, href))
    if links:
        for label, href in links:
            lines.append(f'- [{label}]({href})')
        lines.append('')

    md = '\n'.join(lines).rstrip('\n') + '\n'
    return md, None


def main() -> int:
    changed = 0
    for lang, page in PAGES:
        rel = f'docs/notice/{lang}.md'
        page_html = read(page)
        md, err = render_md(page_html)
        if md is None:
            print(f'✗ {page}: {err}')
            return 1
        old = read(rel) if os.path.exists(os.path.join(ROOT, rel)) else None
        if old == md:
            print(f'= {rel}: 已是最新（{len(md)} 字节）')
            continue
        write(rel, md)
        changed += 1
        print(f'✓ {rel}: {"新建" if old is None else "更新"}（{len(md)} 字节）')
    print(f'\n同步完成：{changed} 个文件有改动 / {len(PAGES)} 个语言'
          f'（其余语言由应用的兜底链退回 en.md）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
