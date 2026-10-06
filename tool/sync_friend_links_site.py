#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 links.json（友情链接）渲染进官网三个语言页的**页脚**。

## 为什么要有这个脚本

页脚在 `docs/index.html` / `docs/zh-TW/index.html` / `docs/en/index.html`
三处**各手写一份**。友情链接若也手写三份，加一个站必然漏一两个语言
（赞助名单当初就是这样走样的，最后改为「一份真源 + 渲染脚本」）。
所以这里沿用同一套做法：

* **唯一真源**：`docs/links.json`；
* 本脚本把它渲染成静态 HTML 插进三语页脚，块用标记包起来保证幂等：

      <!-- friends-sync --> ... <!-- /friends-sync -->

友情链接是**纯静态**的（没有运行时 fetch），所以两个入口都要跑：
新增/修改友链后，重新跑本脚本再推送。

跑法：
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

# 页脚里那三个字，按语言写；换语言时也要改这里
LABEL = {'zh': '友情链接', 'zh-TW': '友情連結', 'en': 'Friendly Links'}


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


def render(links, lang):
    out = [OPEN, '    ' + '<div class="footer-friends">',
           '      <span class="footer-friends-label">%s</span>' % esc(LABEL[lang])]
    for lk in links:
        name = pick(lk.get('name'), lang)
        desc = pick(lk.get('desc'), lang)
        url = lk.get('url') or ''
        logo = lk.get('logo') or ''
        img = ('<img class="flink-logo" src="%s" alt="%s" loading="lazy" '
               'referrerpolicy="no-referrer">' % (esc(logo), esc(name))
               ) if logo else ''
        text = '<span class="flink-name">%s</span>' % esc(name)
        if desc:
            text += '<span class="flink-desc">%s</span>' % esc(desc)
        out.append(
            '      <a class="flink" href="%s" target="_blank" rel="noopener">\n'
            '        %s\n'
            '        <span class="flink-text">%s</span>\n'
            '      </a>' % (esc(url), img, text))
    out += ['    </div>', CLOSE]
    return '\n'.join(out)


def main():
    src = os.path.join(ROOT, 'docs/links.json')
    data = json.loads(io.open(src, encoding='utf-8').read())
    links = [lk for lk in (data.get('links') or []) if lk.get('url')]
    if not links:
        raise SystemExit('links.json 里没有有效的 links —— 数据源有问题')

    anchor = '    <div class="footer-bottom">'
    for lang, rel in PAGES.items():
        path = os.path.join(ROOT, rel)
        s = io.open(path, encoding='utf-8', newline='').read()

        # 幂等：先删掉旧的标记块
        if OPEN in s:
            a = s.index(OPEN)
            b = s.index(CLOSE) + len(CLOSE)
            # 连同其后的换行一起删，避免重复插入后出现空行
            while b < len(s) and s[b] in '\r\n':
                b += 1
            s = s[:a] + s[b:]

        idx = s.find(anchor)
        if idx < 0:
            raise SystemExit('在 %s 里找不到 footer-bottom 锚点 —— 页脚结构变了？' % rel)
        s = s[:idx] + render(links, lang) + '\n' + s[idx:]

        io.open(path, 'w', encoding='utf-8', newline='').write(s)
        print('%-24s 写入 %d 个友链' % (rel, len(links)))

    print('\n✅ 三个语言页页脚已同步友情链接（更新于 %s）' % data.get('updated'))


if __name__ == '__main__':
    main()
