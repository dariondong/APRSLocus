# -*- coding: utf-8 -*-
"""内嵌 JS 的语法体检 —— 官网静态页里的 `<script>` 是手写维护的，
最常出、也最不容易被现有检查发现的错是：

    往一个「对象数组」里手加一条，**忘了给上一条补逗号**。

它的表现不是「少一条」，而是**整个 `<script>` 解析失败 → 页面整块空白**；
而 HTML 结构、括号个数、`check_site.py` 的「js braces/parens balanced」全都还是对的
（那个检查只数括号，数不出逗号）。

真实事故：`docs/member-card.html` 从 **v2.0.4** 起就有这个问题 ——
追加 BH7GZB 时漏了 BG2EFX 那条末尾的逗号，于是会员卡页
「一个人都不显示、整片空白」，一路带到 v2.0.5 才被发现。

本检查**纯 Python、零依赖**（CI 里没有 node / esprima 可用），做法：

1. 掩码掉字符串 / 模板串 / 正则字面量 / 注释（保留换行，所以行号不乱）
2. 在掩码文本上校括号配对（比原来「数个数」更准：能定位到行）
3. 数组字面量里，若某个元素以 `{` 开头、而它前面（跳过空白与注释）**是 `}` / `]` / `)`**，
   那就说明「上一个值结束了却没有逗号」→ 判失败

第 3 条只在「当前容器是数组」时生效 —— 因为 `if(x){...}` 这种
「`)` 紧跟 `{`」在语句位置完全合法，不能在对象/块上下文里误报。

跑法：python3 tool/check_embedded_js.py   （仓库根目录）退出码非 0 即不过。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 正则字面量合法的「前一个有效字符」：运算符/分隔符位置，`/` 才可能是正则开头
_REGEX_PREV = set("([{,;:=!&|?+-*%~^<>")
# `return /x/` 这类：前一个「词」是关键字时，`/` 也是正则开头
_REGEX_PREV_WORDS = {
    'return', 'typeof', 'instanceof', 'in', 'of', 'new', 'delete', 'void',
    'do', 'else', 'case', 'yield', 'await',
}
_IDENT = re.compile(r'[A-Za-z0-9_$]')


def mask(code):
    """把字符串/模板串/正则/注释换成空格（**换行保留**），返回等长文本。

    返回 (masked, err)：err 为块注释未闭合时的一句话说明（可能为空）。

    ⚠️ 模板串必须**按状态栈**处理：模板里可以嵌模板
    （`${people.map(p => `...`)}`），只做「从反引号扫到下一个反引号」
    会把内层的开场反引号也吃掉，之后整段代码就被当成模板文本掩掉 ——
    括号与逗号的判断会连带失真（第一版就是这么误报的）。
    """
    out = list(code)
    n = len(code)

    def blank(a, b):
        for k in range(a, min(b, n)):
            if out[k] != '\n':
                out[k] = ' '

    # 帧：[mode, brace_depth]；mode 取 'code' | 'tpl'
    frames = [['code', 0]]
    i = 0
    prev_sig = None      # 上一个有效字符（不含空白/注释/被掩码内容）
    prev_word = ''       # 上一个标识符（用于 return / typeof 这类）
    while i < n:
        c = code[i]
        if frames[-1][0] == 'tpl':
            # —— 模板文本：一律掩掉（但保留换行）——
            if c == '\\':
                blank(i, i + 2)
                i += 2
                continue
            if c == '`':
                blank(i, i + 1)
                frames.pop()
                prev_sig, prev_word = '`', ''
                i += 1
                continue
            if c == '$' and i + 1 < n and code[i + 1] == '{':
                blank(i, i + 2)
                frames.append(['code', 0])
                i += 2
                continue
            blank(i, i + 1)
            i += 1
            continue
        # —— code ——
        if c in ' \t\r\n':
            i += 1
            continue
        if c == '{':
            frames[-1][1] += 1
            prev_sig, prev_word = '{', ''
            i += 1
            continue
        if c == '}':
            if frames[-1][1] > 0:
                frames[-1][1] -= 1
            elif len(frames) > 1:
                # 关掉的是 `${ }` —— 这个 `}` 属于**模板语法**，
                # 开场那个 `$`+`{` 已经被掩掉，这里也必须一起掩掉，
                # 否则它会变成「多出来的一个 }」（第一版就是这么误报的）
                blank(i, i + 1)
                frames.pop()
            prev_sig, prev_word = '}', ''
            i += 1
            continue
        if c == '`':
            blank(i, i + 1)
            frames.append(['tpl', 0])
            prev_sig, prev_word = '`', ''
            i += 1
            continue
        # 行注释
        if c == '/' and i + 1 < n and code[i + 1] == '/':
            j = code.find('\n', i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
            continue
        # 块注释
        if c == '/' and i + 1 < n and code[i + 1] == '*':
            j = code.find('*/', i + 2)
            if j < 0:
                blank(i, n)
                return ''.join(out), '块注释 /* 没有闭合'
            blank(i, j + 2)
            i = j + 2
            continue
        # 单/双引号字符串
        if c in ('"', "'"):
            q = c
            j = i + 1
            while j < n:
                if code[j] == '\\':
                    j += 2
                    continue
                if code[j] == q:
                    j += 1
                    break
                if code[j] == '\n':      # 换行即未闭合（正常 JS 就是这样）
                    break
                j += 1
            else:
                j = n
            blank(i, j)
            prev_sig, prev_word = q, ''
            i = j
            continue
        # `/`：正则字面量 还是 除号
        if c == '/':
            if prev_sig is None or prev_sig in _REGEX_PREV or prev_word in _REGEX_PREV_WORDS:
                j = i + 1
                in_class = False
                closed = False
                while j < n:
                    ch = code[j]
                    if ch == '\\':
                        j += 2
                        continue
                    if ch == '\n':
                        break
                    if in_class:
                        if ch == ']':
                            in_class = False
                    elif ch == '[':
                        in_class = True
                    elif ch == '/':
                        j += 1
                        while j < n and code[j].isalpha():
                            j += 1
                        closed = True
                        break
                    j += 1
                if closed:
                    blank(i, j)
                    prev_sig, prev_word = '/', ''
                    i = j
                    continue
            prev_sig, prev_word = '/', ''
            i += 1
            continue
        # 普通有效字符
        if _IDENT.match(c):
            j = i
            while j < n and _IDENT.match(code[j]):
                j += 1
            prev_word = code[i:j]
            prev_sig = code[j - 1]
            i = j
            continue
        prev_sig, prev_word = c, ''
        i += 1
    return ''.join(out), ''


def line_of(text, idx):
    return text.count('\n', 0, idx) + 1


def snippet(text, idx, width=70):
    a = text.rfind('\n', 0, idx) + 1
    b = text.find('\n', idx)
    b = len(text) if b < 0 else b
    line = text[a:b]
    return line[:width]


def check_script(path, code, offset_line=0):
    """返回 (problems, masked)。problems 是 (行号, 说明) 列表。"""
    masked, err = mask(code)
    problems = []
    if err:
        problems.append((1, err))
        return problems, masked

    # --- 1) 括号配对（在掩码文本上，报第一处 ---
    stack = []
    pairs = {')': '(', ']': '[', '}': '{'}
    for idx, ch in enumerate(masked):
        if ch in '([{':
            stack.append((ch, idx))
        elif ch in ')]}':
            if not stack or stack[-1][0] != pairs[ch]:
                problems.append((offset_line + line_of(code, idx),
                                 '括号不配对：多出一个 %r -> %s' % (ch, snippet(code, idx).strip())))
                return problems, masked
            stack.pop()
    if stack:
        ch, idx = stack[0]
        problems.append((offset_line + line_of(code, idx),
                         '括号不配对：%r 没有闭合 -> %s' % (ch, snippet(code, idx).strip())))
        return problems, masked

    # --- 2) 数组元素之间漏逗号 ---
    # 「上一个值刚刚结束（} ] )）就直接来一个 {」= 漏逗号。
    # 只在数组字面量里判，避免把 `if(x){...}` 这种语句位置的 `){` 误杀。
    container = []           # 只记 [ { 两种（() 与元素分隔无关）
    last_sig = ''            # 掩码文本里的上一个有效字符
    for idx, ch in enumerate(masked):
        if ch in ' \t\r\n':
            continue
        if ch == '{' and container and container[-1] == '[' and last_sig in '}])':
            problems.append((offset_line + line_of(code, idx),
                             '数组元素之间漏了逗号（%r 后面直接跟 {）-> %s'
                             % (last_sig, snippet(code, idx).strip())))
        if ch == '[':
            container.append('[')
        elif ch == '{':
            container.append('{')
        elif ch in ']}':
            if container and container[-1] == ('[' if ch == ']' else '{'):
                container.pop()
        last_sig = ch
    return problems, masked


def iter_inline_js(html):
    """yield (起始行号, 代码)。跳过 src= 外链与 JSON-LD 等非 JS 类型。"""
    for m in re.finditer(r'<script([^>]*)>(.*?)</script>', html, re.S | re.I):
        attrs, body = m.group(1), m.group(2)
        if re.search(r'\bsrc\s*=', attrs, re.I):
            continue
        tm = re.search(r'\btype\s*=\s*["\']([^"\']+)["\']', attrs, re.I)
        if tm and tm.group(1).strip().lower() not in (
                'text/javascript', 'application/javascript', 'module'):
            continue          # application/ld+json 等：不是 JS，别当 JS 解析
        if not body.strip():
            continue
        yield html.count('\n', 0, m.start(2)) + 1, body


def html_files():
    out = []
    for base, _dirs, files in os.walk(os.path.join(ROOT, 'docs')):
        for f in sorted(files):
            if f.endswith('.html'):
                out.append(os.path.join(base, f))
    return sorted(out)


def main():
    fails = 0
    checked = 0
    for path in html_files():
        rel = os.path.relpath(path, ROOT)
        html = io.open(path, encoding='utf-8').read()
        for start_line, body in iter_inline_js(html):
            checked += 1
            problems, _ = check_script(path, body, offset_line=start_line - 1)
            for ln, why in problems:
                fails += 1
                print('  FAIL %s:%d  %s' % (rel, ln, why))
    if fails:
        print('\n内嵌 JS 体检：%d 处问题（共查 %d 段 <script>）' % (fails, checked))
        return 1
    print('内嵌 JS 体检 ok：%d 段 <script> 语法与「数组元素逗号」都没问题' % checked)
    return 0


if __name__ == '__main__':
    sys.exit(main())
