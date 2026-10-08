#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 links.json（友情链接）渲染成官网三个语言页的**独立区块**。

## 为什么要有这个脚本

友情链接是「一份真源 + 渲染脚本」：`docs/links.json` 是唯一真源，
本脚本把它渲染进页面，块用标记包起来保证幂等：

    <!-- friends-sync --> ... <!-- /friends-sync -->

最初渲进的是**页脚**一行，几枚 chip 挤在版权上面很难看。现在改成
**独立一整块 section**（介于社区与页脚之间），每枚友链是一张卡片
（logo + 名称 + 简介）。数据源与渲染方式不变，只是版式换了地方。

友情链接是**纯静态**的（没有运行时 fetch），所以改完数据要重跑本脚本：

    python3 tool/sync_friend_links_site.py

之后推送即可（GitHub Pages 会自动部署）。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGES = {
    'zh': 'docs/index.html',
    'zh-TW': 'docs/zh-TW/index.html',
    'en': 'docs/en/index.html',
}

OPEN, CLOSE = '<!-- friends-sync -->', '<!-- /friends-sync -->'

# 区块标题与一句说明，按语言写；换语言时也要改这里
HEAD = {
    'zh': ('友情链接', '与同行者的网站对望，感谢互相链接。'),
    'zh-TW': ('友情連結', '與同行者的網站對望，感謝互相連結。'),
    'en': ('Friendly Links', 'Sites we are glad to link with.'),
}

# 页脚的锚点：新区块插在它**前面**。三语页的注释语言不同，故按语言给。
# 锚点找不到就报错，免得页面结构变了却静默插到别处。
FOOTER_ANCHOR = {
    'zh': '<!-- ═══════════ 页脚 ═══════════ -->',
    'zh-TW': '<!-- ═══════════ 頁腳 ═══════════ -->',
    'en': '<!-- ═══════════ Footer ═══════════ -->',
}


def pick(mapv, lang):
    """按语言取文案：该语言 → 中文基准 → 英文（与 sponsors 的回落一致）。"""
    if isinstance(mapv, dict) and mapv.get(lang):
        return mapv[lang]
    if isinstance(mapv, dict):
        if mapv.get('zh'):
            return mapv['zh']
        if mapv.get('en'):
            return mapv['en']
    return ''


def esc(v):
    return (str(v).replace('&', '&amp;').replace('<', '&lt;')
            .replace('>', '&gt;').replace('"', '&quot;'))


def logo_src(logo, lang):
    """友链 logo 的 src。

    logo 可能是外站 URL，也可能是仓库内资产（本项目给没有图标的站点**自制**
    了一张，放在 docs/assets/）。后者在根页与子目录页引用的相对路径不同：
    根页 `assets/x.png`，子页 `../assets/x.png` —— 与站内其它资产写法一致。
    """
    if not logo:
        return ''
    if logo.startswith(('http://', 'https://', '//', 'data:')):
        return logo
    return ('../' + logo) if lang != 'zh' else logo


def render(links, lang):
    title, note = HEAD[lang]
    out = [OPEN,
           '<section class="section alt" id="friends">',
           '  <div class="section-head reveal">',
           '    <h2>%s</h2>' % esc(title),
           '    <p>%s</p>' % esc(note),
           '  </div>',
           '  <div class="links-grid">']
    for lk in links:
        name = pick(lk.get('name'), lang)
        desc = pick(lk.get('desc'), lang)
        url = lk.get('url') or ''
        logo = logo_src(lk.get('logo') or '', lang)
        img = ('<img class="link-card-logo" src="%s" alt="%s" loading="lazy" '
               'referrerpolicy="no-referrer">' % (esc(logo), esc(name))
               ) if logo else ''
        text = '<span class="flink-name">%s</span>' % esc(name)
        if desc:
            text += '<span class="flink-desc">%s</span>' % esc(desc)
        out.append(
            '    <a class="link-card reveal" href="%s" target="_blank" rel="noopener">\n'
            '      %s\n'
            '      <span class="link-card-text">%s</span>\n'
            '    </a>' % (esc(url), img, text))
    out += ['  </div>', '</section>', CLOSE]
    return '\n'.join(out)


def main():
    src = os.path.join(ROOT, 'docs/links.json')
    data = json.loads(io.open(src, encoding='utf-8').read())
    links = [lk for lk in (data.get('links') or []) if lk.get('url')]
    if not links:
        raise SystemExit('links.json 里没有有效的 links —— 数据源有问题')

    for lang, rel in PAGES.items():
        path = os.path.join(ROOT, rel)
        s = io.open(path, encoding='utf-8', newline='').read()

        # 幂等：先删掉旧的标记块（无论它当初插在页脚还是别处）
        if OPEN in s:
            a = s.index(OPEN)
            b = s.index(CLOSE) + len(CLOSE)
            # 连同其后的换行一起删，避免重复插入后出现空行
            while b < len(s) and s[b] in '\r\n':
                b += 1
            s = s[:a] + s[b:]

        idx = s.find(FOOTER_ANCHOR[lang])
        if idx < 0:
            raise SystemExit('在 %s 里找不到页脚锚点 —— 页面结构变了？' % rel)
        s = s[:idx] + render(links, lang) + '\n\n' + s[idx:]

        io.open(path, 'w', encoding='utf-8', newline='').write(s)
        print('%-24s 写入 %d 个友链（独立区块）' % (rel, len(links)))

    print('\n✅ 三个语言页已同步友情链接区块（更新于 %s）' % data.get('updated'))


if __name__ == '__main__':
    main()
