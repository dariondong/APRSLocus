#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""静态检查：`const` 构造里不能引用 `C.<字段>`（非常量）。

## 为什么需要它

`C` 里的颜色都是 `static Color xxx`（**非常量**字段），所以
`const Padding(color: C.blue)` 会报 `invalid_constant` —— 只 analyze/编译能发现，
`dart format` 一律放行；而本机跑不了 analyze。

仓库里早就踩过这个坑（`station_detail.dart` 还留着一句注释「不能加 const：
C.white 是 static 字段（非常量）」），但我写 2.0 的连接按钮时又踩了一次。
这是同一类「只有 analyze 能发现」的错误第四次漏到 CI，而这一种的判据是
**完全确定的**（不像字段被删那种要靠启发式），所以值得做成检查。

## 判据

找到 `const <构造>(`，扫到与它配对的那个 `)`，若其中出现 `C.<小写字段>`
（或 `C.white` / `C.black` 这类），就报。逐字符配对，带字符串与注释跳过 ——
用正则跨行匹配会在嵌套括号处出错。

注意 `const EdgeInsets.all(8)` 这类**不含 C** 的写法不受影响。

用法：python3 tool/check_const_colors.py
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
CONST_CALL = re.compile(r'\bconst\s+[A-Z][A-Za-z0-9_]*\s*\(')
C_FIELD = re.compile(r'\bC\.[a-zA-Z_]\w*')


def mask_comments_and_strings(text):
    """把行注释与字符串字面量按**等长空格**遮蔽，保留所有下标与行号。

    为什么必须这么做：第一版直接拿原文匹配，结果把我**注释里**写的示例
    （`// const Padding(... color: C.blue)`）当成真代码报了出来 —— 假失败。
    也不能「删掉注释行」：那会让行号整体偏移，报出来的位置对不上文件
    （这个坑我在别的检查里踩过）。
    """
    out = list(text)
    i = 0
    n = len(text)
    instr = None
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


def scan(text, start):
    """从 text[start] 的 `(` 起配对，返回配对 `)` 的下标（找不到返回 None）。"""
    depth, instr = 0, None
    i = start
    while i < len(text):
        ch = text[i]
        if instr is not None:
            if ch == '\\':
                i += 2
                continue
            if ch == instr:
                instr = None
            i += 1
            continue
        if ch == '/' and i + 1 < len(text) and text[i + 1] == '/':
            j = text.find('\n', i)
            i = len(text) if j < 0 else j
            continue
        if ch in ("'", '"'):
            instr = ch
            i += 1
            continue
        if ch in PAIRS:
            depth += 1
        elif ch in CLOSE:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return None


def main() -> int:
    problems = []
    for base, _d, fs in os.walk(LIB):
        for f in sorted(fs):
            if not f.endswith('.dart'):
                continue
            p = os.path.join(base, f)
            rel = os.path.relpath(p, ROOT).replace(os.sep, '/')
            if rel.startswith('lib/l10n/'):
                continue
            text = io.open(p, encoding='utf-8').read()
            if 'const' not in text or 'C.' not in text:
                continue
            # 在「遮蔽过的副本」上匹配：下标与行号与原文一致，但注释与字符串
            # 已被抹成空格 —— 否则注释里的示例会被当成真代码（第一版就那样）。
            masked = mask_comments_and_strings(text)
            for m in CONST_CALL.finditer(masked):
                end = scan(masked, m.end() - 1)
                if end is None:
                    continue
                hit = C_FIELD.search(masked[m.end():end])
                if not hit:
                    continue
                ln = text.count('\n', 0, m.start()) + 1
                problems.append((rel, ln, hit.group(0)))

    if not problems:
        print('const colors ok: 没有 `const` 构造引用非常量的 C.<字段>')
        return 0

    print('以下 `const` 构造里引用了 `C.<字段>`（非常量 static 字段）—— '
          'analyze 会报 invalid_constant：')
    for rel, ln, name in problems:
        print('  BAD  %-30s 第 %-5d 行引用了 %s' % (rel, ln, name))
    print('\n修法：去掉那个 const（只保留内层确实常量参数上的 const）。')
    return 1


if __name__ == '__main__':
    sys.exit(main())
