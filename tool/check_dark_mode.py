#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""静态检查：弹窗 / 底部面板 / 卡片**不许**用写死的 `Colors.white` 表面色。

## 为什么需要它

本应用的深色模式是**运行时换调色板**：`ThemeController.applyTheme` 会把 `C.white`
重新指派成深色（`0xFF1E2530`），所以凡是走 `C.white` 的地方，切到深色会自动变。
而 `Colors.white` 是 Flutter 的**编译期常量**，永远是纯白 —— 一旦有人顺手写了它，
深色模式下那张弹窗就是一块刺眼的白板在发亮，浅色模式却完全正常，
所以「自己看浅色版」永远发现不了。用户报的「更新页等页面不兼容暗黑模式」
就是这一类。

本机跑不了 analyze、也跑不了真机（约束），而它**能编译、能过 analyze、能过所有
其它检查器**，只有切到深色模式肉眼才看得出来 —— 所以必须钉成检查。

## 判据（只认三条，避免假失败）

  * `backgroundColor: Colors.white` —— 弹窗/面板的**表面**底色。这是最高的
    信号量：它一定是「一个会发白的表面」。
  * `BoxDecoration(color: Colors.white)` 里**顶层**的 `color:`（不是嵌套在
    `Border.all(...)` / `BoxShadow(...)` 里的那种）。嵌套的白色是描边/光晕，
    属于**强调**而不是表面，深色下本来就该是白的，不在检查范围。
  * 另外两条同类：`backgroundColor:` 直接写死成常量色（`const Color(0xFF...)`），
    以及 `surfaceTint(Colors.white)` / `surfaceTint(const Color(0x...))` ——
    `surfaceTint` 只在材质开启时才调透明度，材质关闭时**原样返回**那个常量，
    于是「更新页顶栏」这类表面在深色下永远是一块白板（v2.0.57 修的就是它）。
    表面色必须走 `C.*` 主题 token，才能跟着运行时调色板变。

⭐ 允许的写法：`C.white`（跟随主题）、`Colors.white.withValues(...)`（本身
就带透明度，多用于彩色横幅上的按钮/进度条，不是纯白表面）、
`C.surfaceFillStrong` / `C.bg` / `C.mapBg`（主题 token）。

用法：python3 tool/check_dark_mode.py
退出码 0 = 没有；1 = 有（并列出文件与行号）。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, 'lib')

PAIRS = {'(': ')', '[': ']', '{': '}'}
CLOSE = set(')]}')

# 弹窗/面板的表面底色（`backgroundColor:` 只出现在这类表面或进度条上，
# 后者用的是 `Colors.whiteXX` / `withValues`，不会被这条正则命中）。
BG = re.compile(r'backgroundColor\s*:\s*Colors\.white\s*[,)]')
# BoxDecoration 里的顶层颜色（嵌套的靠括号深度排除）。
BOX = re.compile(r'BoxDecoration\s*\(')
COLOR_WHITE = re.compile(r'(?<![\w.])color\s*:\s*Colors\.white\s*[,)]')
# 写死的**不透明**表面底色（`const Color(0xFFRRGGBB)`）—— 运行时换调色板改不到它。
BG_LITERAL = re.compile(r'backgroundColor\s*:\s*(?:const\s+)?Color\(0xFF[0-9A-Fa-f]{6}\)\s*[,)]')
# surfaceTint(常量)：材质关时 surfaceTint 原样返回该常量 → 深色下仍是实色白板。
TINT = re.compile(r'surfaceTint\s*\(\s*(?:const\s+)?(?:Color\(0xFF[0-9A-Fa-f]{6}\)|Colors\.white)\s*[,)]')

# 有意的例外：路径 → (允许出现的次数, 理由)。这些白色**不是表面**，而是
# 「压在彩色渐变横幅/卡片上的白底按钮」—— 横幅本身是固定彩色（不随主题变），
# 所以白底按钮在亮/暗两种模式下都正确。理由不写清楚的话，下一个人只会把它
# 当噪声删掉。
ALLOW = {
    'lib/check_update_page.dart': (
        2, '版本卡是固定彩色渐变，上面两个白底按钮刻意保持白色'),
    'lib/home_page.dart': (
        1, '蓝色连接横幅是固定彩色渐变，上面的白底按钮刻意保持白色'),
}


def mask_comments_and_strings(text):
    """把行注释与字符串字面量按**等长空格**遮蔽，保留下标与行号。

    不遮蔽就会把文档注释里写的反例（本文件顶部到处都是 `Colors.white`）当成
    真代码报出来 —— 这是这类检查最常见的一种假失败。
    """
    out = list(text)
    i, n, instr = 0, len(text), None
    while i < n:
        ch = text[i]
        if instr is not None:
            if ch == '\\':
                out[i] = ' '
                if i + 1 < n:
                    out[i + 1] = ' '
                i += 2
                continue
            if ch == instr:
                instr = None
            else:
                out[i] = ' '
            i += 1
            continue
        if ch == '/' and i + 1 < n and text[i + 1] == '/':
            while i < n and text[i] != '\n':
                out[i] = ' '
                i += 1
            continue
        if ch in ("'", '"'):
            instr = ch
            out[i] = ' '
            i += 1
            continue
        i += 1
    return ''.join(out)


def box_decoration_bodies(masked):
    """返回每个 `BoxDecoration(` 的顶层区间文本（不含嵌套括号内容的位置信息）。

    直接返回 (start_off, body_text)，body_text 是括号**内**的原始（已被遮蔽）文本。
    """
    out = []
    for m in BOX.finditer(masked):
        open_idx = m.end() - 1  # '(' 的下标
        depth, i, n = 0, open_idx, len(masked)
        while i < n:
            c = masked[i]
            if c in PAIRS:
                depth += 1
            elif c in CLOSE:
                depth -= 1
                if depth == 0:
                    out.append((m.start(), masked[open_idx + 1:i]))
                    break
            i += 1
    return out


def line_of(text, off):
    return text.count('\n', 0, off) + 1


def main():
    problems = []
    for base, _dirs, files in os.walk(LIB):
        for fn in sorted(files):
            if not fn.endswith('.dart'):
                continue
            path = os.path.join(base, fn)
            rel = os.path.relpath(path, ROOT).replace(os.sep, '/')
            raw = io.open(path, encoding='utf-8').read()
            masked = mask_comments_and_strings(raw)
            lines = masked.split('\n')

            for m in BG.finditer(masked):
                problems.append((rel, line_of(masked, m.start()),
                                 'backgroundColor: Colors.white'))

            for m in BG_LITERAL.finditer(masked):
                problems.append((rel, line_of(masked, m.start()),
                                 'backgroundColor: 写死常量色（未走主题 token）'))

            for m in TINT.finditer(masked):
                problems.append((rel, line_of(masked, m.start()),
                                 'surfaceTint(常量)：材质关闭时该表面不随主题变'))

            for start, body in box_decoration_bodies(masked):
                # 顶层 `color: Colors.white`：body 里嵌套的 Border.all/BoxShadow
                # 已经不在 body 文本的最外层 —— 但它们仍在 body 里，所以要按
                # 括号深度过滤：只统计**深度 0**（body 顶层）的 `color:`。
                depth, i, n = 0, 0, len(body)
                while i < n:
                    c = body[i]
                    if c in PAIRS:
                        depth += 1
                    elif c in CLOSE:
                        depth -= 1
                    elif depth == 0:
                        cm = COLOR_WHITE.match(body, i)
                        if cm:
                            problems.append((
                                rel,
                                line_of(masked, start + 1 + i),
                                'BoxDecoration(color: Colors.white)'))
                            i = cm.end()
                            continue
                    i += 1

    if not problems:
        print('暗色模式表面色检查：OK（弹窗/面板/卡片无写死的 Colors.white 表面）')
        return 0

    # 先按文件归组，再扣掉该文件的例外额度；多出来的才算失败。
    by_file = {}
    for rel, ln, what in problems:
        by_file.setdefault(rel, []).append((ln, what))
    real = []
    for rel, hits in by_file.items():
        allowed, _reason = ALLOW.get(rel, (0, ''))
        for ln, what in sorted(hits):
            if allowed > 0:
                allowed -= 1
                continue
            real.append((rel, ln, what))

    if not real:
        print('暗色模式表面色检查：OK（仅剩固定彩色横幅上的白底按钮，已登记例外）')
        return 0

    print('暗色模式表面色检查：发现 %d 处写死的 Colors.white 表面 —— '
          '深色模式下会是一块白板，请改用 C.white：' % len(real))
    for rel, ln, what in real:
        print('  %s:%d  %s' % (rel, ln, what))
    return 1


if __name__ == '__main__':
    sys.exit(main())
