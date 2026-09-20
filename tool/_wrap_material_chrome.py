#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把「压在内容上的表面」套上材质壳（一次性脚本）。

为什么用括号配对而不是正则替换：要包住的都是 `Container(...)`，里面嵌套着
`S.of(context).xxx(...)` 与多层 BoxDecoration / Row / Column。用正则
（例如 ``\\(([^)]*)\\)``）会在**第一个右括号**处截断 —— 仓库里
check_backup_keys.py 的注释记过同一个坑。所以这里做真正的括号配对，
并跳过字符串字面量与行注释。

缩进同样是这里的活儿：套一层壳等于**整块往里缩两格**。只加壳不缩进，
`dart format` 会把参数对齐到更长的那个开括号上，产出一段谁都不敢改的锯齿
（第一版就是这样，推翻重做了）。生成后再由 _fmt_touched.py 只对这几处
取 formatter 的结果 —— 仓库整体不是 format 干净的，整文件格式化会淹掉 diff。

两种壳：
  surface —— MaterialSurface（半透明 + 背后真模糊）
  appbar  —— MaterialAppBar（转发 preferredSize 的 AppBar 壳）
"""
import io
import re
import sys

PAIRS = {'(': ')', '[': ']', '{': '}'}
CLOSE = set(')]}')

# ── 浮层（MaterialSurface）──
# 文件 → [(锚点行(忽略缩进), 圆角, 小尺寸模糊或 None, 表面色替换或 None, 仅上圆角)]
SURFACES = {
    'lib/map_page.dart': [
        ('boxShadow: softShadow(blur: 14, alpha: 0.09),', 14, None, 'C.sheetFill', False),   # _infoChip
        ('boxShadow: softShadow(blur: 12, alpha: 0.07),', 12, None, 'C.sheetFill', False),   # _legend
        ('boxShadow: softShadow(blur: 12, y: 3, alpha: 0.08),', 12, 14.0, None, False),      # _toolBtn
        ('boxShadow: softShadow(blur: 10, alpha: 0.15),', 10, 12.0, 'C.sheetFill', False),   # _infoWindow
        ('boxShadow: softShadow(),', 12, None, 'C.sheetFill', False),                        # 搜索命中提示
        ('boxShadow: softShadow(blur: 14, alpha: 0.15),', 12, None, 'C.sheetFill', False),   # 无台站提示
        ('boxShadow: softShadow(blur: 10, alpha: 0.12),', 10, None, 'C.sheetFill', False),   # 信标通栏
        ('boxShadow: softShadow(blur: 12, alpha: 0.08),', 12, None, 'C.sheetFill', False),   # 底部控制条
        ('boxShadow: softShadow(blur: 16, alpha: 0.18),', 14, None, 'C.sheetFill', False),   # 图层面板
        ('borderRadius: BorderRadius.vertical(top: Radius.circular(20)),', 20, None,
         'C.sheetFill', True),                                                              # 我的位置面板
        ('borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),', 20, None,
         'C.sheetFill', True),                                                              # 站台面板
    ],
    'lib/tracker_page.dart': [
        ('boxShadow: softShadow(blur: 16, alpha: 0.12),', 16, None, None, False),            # 成员横条（本来就只有 0.6）
        ('boxShadow: softShadow(blur: 10, alpha: 0.08),', 14, None,
         ('C.white.withValues(alpha: 0.92),', 'C.sheetFill,'), False),                       # 页头
        ('boxShadow: softShadow(blur: 12, alpha: 0.15),', 12, None,
         ('withValues(alpha: compact ? 0.98 : 0.95)', 'withValues(alpha: 1)'), False),       # 会话浮层
    ],
}

# ── 顶栏（MaterialAppBar）──
# 文件 → 帧颜色替换（保留原色相，只让它随材质变透）
APPBARS = {
    'lib/about_page.dart': None,
    'lib/check_update_page.dart': ('Colors.white', 'surfaceTint(Colors.white)'),
    'lib/export_adif_page.dart': ('Colors.white', 'surfaceTint(Colors.white)'),
    'lib/honor_wall_page.dart': (
        'const Color(0xFFF4F6FB)', 'surfaceTint(const Color(0xFFF4F6FB))'),
    'lib/log_page.dart': None,
    'lib/offline_map_page.dart': None,
    'lib/sponsor_page.dart': None,
    'lib/terms_page.dart': None,
    'lib/settings_widgets.dart': None,
}


def _detach_semicolon(newblock, indent):
    """把被包裹语句结尾的 `;` 挪到壳外面。

    `return Container(...);` 这种写法，Container 的配对右括号那行是 `    );` ——
    直接往里缩两格会变成 `      );`，而后面再补一层壳的 `),` 就成了
    「先结束语句、再补一个括号」，语法直接崩（报的是「Expected to find ')'」，
    看着像少括号，其实是分号位置错了）。
    """
    last = newblock[-1]
    stripped = last.rstrip()
    if stripped.endswith(');'):
        # return Container(...);  → 分号挪到壳外面
        newblock = newblock[:-1] + [re.sub(r'\)\s*;\s*$', '),', last)]
        return newblock, indent + ');'
    if stripped.endswith('),'):
        # 集合里的元素（if (x) Container(...), / children 里的一项）
        return newblock, indent + '),'
    if stripped.endswith(')'):
        # `if (x) Container(...) else ...` 这种没有逗号的收尾：壳也不能带逗号，
        # 否则 else 之前多出一个逗号，语法就崩了
        return newblock, indent + ')'
    raise AssertionError('不认识被包裹块的收尾：%r' % last)


def find_matching(lines, start, opener):
    """从 lines[start] 中的 opener（如 'MaterialSurface('）起配对，返回止行号。"""
    depth = 0
    instr = None
    for i in range(start, len(lines)):
        line = lines[i]
        # 起始行要从 opener 自己的 '(' 开始数（少算它的话，第一个右括号就会
        # 把深度打成 0，于是「配对」会落在第一行参数上 —— 这个 bug 真发生过）
        k = (line.index(opener) + len(opener) - 1) if i == start else 0
        while k < len(line):
            ch = line[k]
            if instr is not None:
                if ch == '\\':
                    k += 2
                    continue
                if ch == instr:
                    instr = None
                k += 1
                continue
            if ch == '/' and k + 1 < len(line) and line[k + 1] == '/':
                break
            if ch in ("'", '"'):
                instr = ch
                k += 1
                continue
            if ch in PAIRS:
                depth += 1
            elif ch in CLOSE:
                depth -= 1
                if depth == 0:
                    return i
            k += 1
    raise AssertionError('未闭合（第 %d 行起）' % (start + 1))


def unique_line(lines, text):
    hits = [i for i, l in enumerate(lines) if l.strip() == text.strip()]
    return hits[0] if len(hits) == 1 else None


def wrap_surfaces(path, items):
    lines = io.open(path, encoding='utf-8').read().split('\n')
    plan = []
    for anchor, radius, blur, fill, top_only in items:
        a = unique_line(lines, anchor)
        if a is None:
            print('  ✗ 锚点不唯一或找不到：%s' % anchor)
            return False
        start = None
        for i in range(a - 1, max(-1, a - 60), -1):
            if 'Container(' in lines[i]:
                start = i
                break
        if start is None or any('Container(' in lines[j] for j in range(start + 1, a)):
            print('  ✗ 认不出容器起始行：%s' % anchor)
            return False
        end = find_matching(lines, start, 'Container(')
        if end < a:
            print('  ✗ 配对括号出现在锚点之前：%s' % anchor)
            return False
        color_line = None
        if fill:
            needle = fill[0] if isinstance(fill, tuple) else 'color: C.white,'
            for j in range(start, end + 1):
                if needle in lines[j]:
                    color_line = j
                    break
            if color_line is None:
                print('  ✗ 没找到要替换的表面色（%s）：%s' % (needle, anchor))
                return False
        plan.append((start, end, radius, blur, fill, top_only, color_line))

    for _s, _e, _r, _b, fill, _t, color_line in plan:
        if color_line is not None:
            old, new = fill if isinstance(fill, tuple) else ('color: C.white,',
                                                             'color: %s,' % fill)
            lines[color_line] = lines[color_line].replace(old, new)

    for start, end, radius, blur, _f, top_only, _c in sorted(plan, key=lambda p: -p[0]):
        indent = ' ' * (len(lines[start]) - len(lines[start].lstrip()))
        idx = lines[start].index('Container(')
        head = [lines[start][:idx] + 'MaterialSurface(', '%s  radius: %s,' % (indent, radius)]
        if blur:
            head.append('%s  blurSigma: %s,' % (indent, blur))
        if top_only:
            head.append('%s  topOnly: true,' % indent)
        head.append('%s  child: Container(' % indent)
        newblock = head + [
            '  ' + l if l.strip() else l for l in lines[start + 1:end + 1]]
        newblock, closer = _detach_semicolon(newblock, indent)
        lines[start:end + 1] = newblock
        # 插入位置必须是**替换之后**这一段的末尾（头多了 3 行，用旧的 end+1
        # 会落进替换区内部）；而结尾那行可能是 `);`（return Container(...) 的
        # 收尾），分号必须挪到壳外面 —— 见 _detach_semicolon。
        lines.insert(start + len(newblock), closer)
    io.open(path, 'w', encoding='utf-8').write('\n'.join(lines))
    print('  ✓ 包裹 %d 处' % len(plan))
    return True


def wrap_appbar(path, tint):
    lines = io.open(path, encoding='utf-8').read().split('\n')
    a = unique_line(lines, 'appBar: AppBar(')
    if a is None:
        print('  ✗ 找不到唯一的 appBar: AppBar(')
        return False
    if tint is not None:
        old, new = tint
        hits = [i for i in range(a, a + 12) if old in lines[i]]
        if len(hits) != 1:
            print('  ✗ 顶栏底色替换目标不唯一：%s' % old)
            return False
        lines[hits[0]] = lines[hits[0]].replace(old, new)
    end = find_matching(lines, a, 'AppBar(')
    indent = ' ' * (len(lines[a]) - len(lines[a].lstrip()))
    idx = lines[a].index('AppBar(')
    head = [lines[a][:idx] + 'MaterialAppBar(', lines[a][idx:]]
    newblock = head + [
        '  ' + l if l.strip() else l for l in lines[a + 1:end + 1]]
    newblock, closer = _detach_semicolon(newblock, indent)
    lines[a:end + 1] = newblock
    lines.insert(a + len(newblock), closer)
    io.open(path, 'w', encoding='utf-8').write('\n'.join(lines))
    print('  ✓ 顶栏已套壳')
    return True


def ensure_import(path):
    """把 `import 'material.dart';` 插到 import 块末尾（幂等）。"""
    lines = io.open(path, encoding='utf-8').read().split('\n')
    if any("import 'material.dart';" in l for l in lines):
        return
    starts = [i for i, l in enumerate(lines) if l.startswith('import ')]
    if not starts:
        print('  ✗ 找不到 import 块')
        return
    last = starts[-1]
    lines.insert(last + 1, "import 'material.dart';")
    io.open(path, 'w', encoding='utf-8').write('\n'.join(lines))


def main() -> int:
    ok = True
    for path, items in SURFACES.items():
        print(path)
        ok &= wrap_surfaces(path, items)
        ensure_import(path)
    for path, tint in APPBARS.items():
        print(path)
        ok &= wrap_appbar(path, tint)
        ensure_import(path)
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
