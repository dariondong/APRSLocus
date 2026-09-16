#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 sponsors.json 渲染进官网三个语言页的「赞助」分组（作为**无 JS 兜底**）。

## 为什么要有这个脚本 + 为什么主力是 JS

官网的赞助名单原先在三个语言页里**各手写一份**，于是必然走样 —— 实际就漏了
STUDENT HAMS 群组、BG7PGW（咖啡）与「每一位支持者」。

现在分工是：

* **主力**：`docs/js/main.js` 的 `renderSponsors` 直接 fetch `/sponsors.json`
  渲染 —— 加赞助人只改 sponsors.json，官网自动跟上。
* **兜底**：本脚本把同一份数据渲染成静态 HTML，负责「JS 被禁用 / 取不到数据」
  时的显示。标记块保证幂等：

      <!-- sponsors-sync --> ... <!-- /sponsors-sync -->

跑法：
    python3 tool/sync_sponsors_site.py

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

OPEN, CLOSE = '<!-- sponsors-sync -->', '<!-- /sponsors-sync -->'

# 按赞助类型给头像底色（与页面既有配色同一套渐变风格）
GRAD = {
    'group': '#6366f1,#4338ca',
    'coffee': '#f59e0b,#b45309',
    'jade': '#c9a227,#8a6d1f',
    'school': '#0ea5b7,#0b7285',
    'everyone': '#ec4899,#be185d',
}
FALLBACK_GRAD = GRAD['everyone']


def initial(name):
    """头像里的那个字。

    沿用页面既有习惯：呼号取「地区号后面的字母」（BG7ORC → O、BA4JLD → J），
    其余（群组名 / 「每一位支持者」）取首字。用 Python 的字符串索引即可正确
    处理中文与 emoji（不会切坏代理对）。
    """
    import re
    m = re.match(r'^[A-Za-z]{1,2}\d([A-Za-z])', name or '')
    if m:
        return m.group(1).upper()
    s = (name or '').strip()
    return s[0] if s else '·'


def pick(mapv, base, lang):
    """按语言取文案：该语言 → 中文基准 → 英文。

    刻意**不是**「该语言 → 英文 → 中文基准」：sponsors.json 里 `desc` 本身就是
    中文基准，若把英文插在它前面，中文页会因为条目没写 `zh` 键而显示英文。
    """
    if isinstance(mapv, dict) and mapv.get(lang):
        return mapv[lang]
    if base:
        return base
    if isinstance(mapv, dict) and mapv.get('en'):
        return mapv['en']
    return ''


def esc(v):
    return (str(v).replace('&', '&amp;').replace('<', '&lt;')
            .replace('>', '&gt;').replace('"', '&quot;'))


def render(sponsors, lang):
    out = [OPEN]
    for sp in sponsors:
        name = pick(sp.get('names'), sp.get('name'), lang)
        desc = pick(sp.get('descs'), sp.get('desc'), lang)
        grad = GRAD.get(sp.get('kind'), FALLBACK_GRAD)
        out.append(
            '        <span class="contributor">\n'
            '          <span class="avatar" style="background:linear-gradient(135deg,%s)">%s</span>\n'
            '          <span><span class="c-name">%s</span>'
            '<span class="c-role">%s</span></span>\n'
            '        </span>' % (grad, esc(initial(name)), esc(name), esc(desc)))
    out.append('      ' + CLOSE)
    return '\n'.join(out)


def main():
    src = os.path.join(ROOT, 'docs/sponsors.json')
    data = json.loads(io.open(src, encoding='utf-8').read())
    sponsors = data.get('sponsors') or []
    if not sponsors:
        raise SystemExit('sponsors.json 里没有 sponsors 数组 —— 数据源有问题')

    for lang, rel in PAGES.items():
        path = os.path.join(ROOT, rel)
        s = io.open(path, encoding='utf-8', newline='').read()

        # 定位「赞助」分组的 contributors 容器：赞助组的圆点颜色是 #e6c873（全站唯一）
        dot = s.index('background:#e6c873')
        box = s.index('<div class="contributors"', dot)

        # 幂等：先删掉旧标记块（以及旧的静态 chips）
        if OPEN in s:
            a = s.index(OPEN)
            b = s.index(CLOSE) + len(CLOSE)
            s = s[:a] + s[b:]
            s = s.replace('<div class="contributors" id="sponsorList"',
                          '<div class="contributors"')
            dot = s.index('background:#e6c873')
            box = s.index('<div class="contributors"', dot)

        # 给容器加上 id 与语言标记（JS 靠它找位置、选语言）
        new_tag = '<div class="contributors" id="sponsorList" data-lang="%s">' % lang
        s = s[:box] + new_tag + s[box + len('<div class="contributors">'):]

        # 清掉容器里原有的手写 chips（只含 span，无嵌套 div，第一个 </div> 即闭合）。
        # 注意 open_tag 要落在 new_tag 的 `>` **之后** —— 落在它之前会把 `>` 一起删掉，
        # 生成的 HTML 就坏了（第一次就踩了这个）。
        open_tag = box + len(new_tag)
        close_at = s.index('</div>', open_tag)
        s = s[:open_tag] + '\n' + render(sponsors, lang) + '\n      ' + s[close_at:]

        io.open(path, 'w', encoding='utf-8', newline='').write(s)
        print('%-24s 写入 %d 位赞助者' % (rel, len(sponsors)))

    print('\n✅ 三个语言页已同步（版本 v%s，更新于 %s）'
          % (data.get('version'), data.get('updated')))
    print('   提示：官网运行时仍以 sponsors.json 为准（js/main.js 会覆盖本静态内容），')
    print('   本脚本只负责「没有 JS 时」的兜底。')


if __name__ == '__main__':
    main()
