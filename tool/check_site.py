# -*- coding: utf-8 -*-
"""推送前终检：结构 / 内容一致性 / SEO / 无障碍 / 主题 / CSS·JS 完整性。
跑法：python3 tool/check_site.py （仓库根目录）退出码非 0 即不过。
"""
import io
import json
import os
import re
import xml.etree.ElementTree as ET
from html.parser import HTMLParser

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VOID = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
        'link', 'meta', 'param', 'source', 'track', 'wbr'}
FAILS = []


class P(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.err = []

    def handle_starttag(self, t, a):
        if t not in VOID:
            self.stack.append((t, self.getpos()))

    def handle_endtag(self, t):
        if t in VOID:
            return
        if not self.stack:
            self.err.append('extra </%s> %s' % (t, self.getpos()))
            return
        if self.stack[-1][0] != t:
            self.err.append('mismatch </%s> %s vs <%s> %s'
                            % (t, self.getpos(), self.stack[-1][0], self.stack[-1][1]))
            for i in range(len(self.stack) - 1, -1, -1):
                if self.stack[i][0] == t:
                    del self.stack[i:]
                    return
        else:
            self.stack.pop()


def chk(name, cond, extra=''):
    if not cond:
        FAILS.append(name)
    print(('  OK  ' if cond else '  FAIL') + ' ' + name + ((' | ' + str(extra)) if extra else ''))


def read(rel):
    return io.open(os.path.join(ROOT, rel), encoding='utf-8').read()


def main():
    print('[home x3]')
    for f in ['docs/index.html', 'docs/zh-TW/index.html', 'docs/en/index.html']:
        s = read(f)
        p = P()
        p.feed(s)
        print(' ' + f)
        chk('html structure', not p.err and not p.stack, p.err[:1])
        chk('18 cards / 27 cl',
            s.count('<article class="card reveal">') == 18
            and s.count('<div class="cl-version reveal">') == 27)
        chk('latest release in cl', 'v1.6.150' in s)
        chk('a11y set', all(x in s for x in
                            ['skip-link', 'heroCanvas" aria-hidden="true"',
                             'aria-expanded="false"', 'id="themeToggle"']))
        chk('theme script + canonical',
            "localStorage.getItem('theme')" in s and 'rel="canonical"' in s)
        chk('faq entry link', 'href="faq.html"' in s)

    print('[help center x3]')
    for f in ['docs/faq.html', 'docs/zh-TW/faq.html', 'docs/en/faq.html']:
        s = read(f)
        p = P()
        p.feed(s)
        ld = re.search(r'<script type="application/ld\+json">\s*(\{.*?\})\s*</script>', s, re.S)
        ldq = len(json.loads(ld.group(1))['mainEntity']) if ld else 0
        print(' ' + f)
        chk('html structure', not p.err and not p.stack, p.err[:1])
        chk('23 q / 5 groups / ld23',
            s.count('<details class="faq') == 23
            and s.count('<h3 class="faq-group"') == 5 and ldq == 23)
        chk('release line =150', 'v1.6.150' in s and '当前对应 v1.6.149' not in s
            and '目前對應 v1.6.149' not in s and 'matches v1.6.149' not in s)
        chk('skip-link + main + theme',
            'skip-link' in s and 'id="main"' in s and 'id="themeToggle"' in s)

    # 语言不得串页：各自特征句只应在自己那页
    lang_probe = {
        'docs/faq.html': [('回放当天路线', True), ('回放當日路線', False), ('replays that', False)],
        'docs/zh-TW/faq.html': [('回放當日路線', True), ('回放当天路线', False), ('replays that', False)],
        'docs/en/faq.html': [('replays that', True), ('回放当天路线', False), ('回放當日路線', False)],
    }
    print('[language isolation]')
    for f, ts in lang_probe.items():
        s = read(f)
        for t, want in ts:
            n = s.count(t)
            chk('%s : %s' % (os.path.basename(f), t), (n > 0) == want, 'count=%d' % n)

    print('[seo]')
    ns = {'s': 'http://www.sitemaps.org/schemas/sitemap/0.9'}
    locs = [u.find('s:loc', ns).text
            for u in ET.parse(os.path.join(ROOT, 'docs/sitemap.xml')).getroot().findall('s:url', ns)]
    missing = []
    for l in locs:
        rel = l.replace('https://aprslocus.theez.top/', '') or 'index.html'
        if rel.endswith('/'):
            rel += 'index.html'
        if not os.path.exists(os.path.join(ROOT, 'docs', rel)):
            missing.append(rel)
    chk('sitemap entries reachable (%d)' % len(locs), not missing, missing)
    chk('robots -> sitemap',
        'Sitemap: https://aprslocus.theez.top/sitemap.xml' in read('docs/robots.txt'))

    print('[css / js]')
    css = read('docs/css/style.css')
    cssb = re.sub(r'/\*.*?\*/', '', css, flags=re.S)
    chk('css braces balanced', cssb.count('{') == cssb.count('}'))
    chk('contrast fixes present',
        all(x in css for x in ['--text-faint: #5b6b85', '--cyan: #0369a1',
                               '--grad-text', 'font-size: 16px; color']))
    chk('dark theme rules >= 40', css.count('[data-theme="dark"]') >= 40,
        css.count('[data-theme="dark"]'))
    chk('new card grads c15-c18', all(('.c%d {' % i) in css for i in (15, 16, 17, 18)))
    chk('help-center styles', all(x in css for x in ['.skip-link', '.faq-search', '.faq-group']))

    js = read('docs/js/main.js')
    j = re.sub(r'/\*.*?\*/', '', js, flags=re.S)
    # 必须同时剥离单行注释：main.js 的 // 注释里有未闭合括号（HEAD 就有），
    # 不剥会把注释里的括号计入，产生假 FAIL
    j = re.sub(r'//[^\n]*', '', j)
    j = re.sub(r'`(?:[^`\\]|\\.)*`', '``', j)
    j = re.sub(r'"(?:[^"\\]|\\.)*"', '""', j)
    j = re.sub(r"'(?:[^'\\]|\\.)*'", "''", j)
    chk('js braces/parens balanced',
        j.count('{') == j.count('}') and j.count('(') == j.count(')'))
    chk('js theme + aria + null-safe canvas',
        all(x in js for x in ['themeToggle', 'aria-expanded', 'canvas ? canvas.getContext']))

    print()
    if FAILS:
        print('FAIL (%d): %s' % (len(FAILS), '; '.join(FAILS)))
        return 1
    print('ALL PASS')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
