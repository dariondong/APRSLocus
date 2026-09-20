#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""静态检查：半透明的「壳」表面，必须真的套了材质壳（否则磨砂只做了一半）。

为什么需要这检查：「漏了一个面板」不会让编译失败、不会让测试失败，只有在
材质开着的时候才能用眼睛看出来 —— 而那两个面板恰好就是没人会天天点开的。
它的典型症状正是**半透明了但没有模糊**：底下的地图瓦片直接透过表面，字和瓦片
糊在一起，看起来像「这个面板坏掉了」。

判据（刻意只认两件事，避免假失败）：
  * `C.sheetFill` / `C.surfaceFillStrong` —— 这两个 getter 的语义**就是**
    「压在内容之上的半透明表面」（见 theme.dart 的注释），所以它必须落在某个
    `MaterialSurface(...)` / `MaterialAppBar(...)` 的参数范围内；
  * `C.surfaceFill`（卡片）**不在**检查范围：卡片背后只有一层已经画好的底，
    刻意不套 BackdropFilter（每个都是一次整屏 saveLayer，一屏十几张卡片就是
    十几层）。把卡片也纳入检查会逼着人给卡片加模糊，那是性能倒退。

所以每条报红都有明确的处置方式：要么套壳，要么把它换成 `C.surfaceFill`
（说明它不是「压在内容上」的表面），要么进 ALLOW 并写清理由。

用法：python3 tool/check_material_coverage.py
退出码 0 = 全部覆盖；1 = 有壳没套上（并列出具体位置）。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, 'lib')

# 有意的例外：路径 → (允许出现的次数, 理由)。理由不写清楚的话，下一个人
# 只会把它当噪声删掉 —— 那这条检查就白加了。
#
# 教训：例外额度是**会过期**的。settings_pages 当初登记了 2（材质小样），
# 修完那两处之后额度却留着 —— 而留着等于「这个文件允许有 2 处漏网不报」，
# 比没有例外更坏（真正的漏网会被它吞掉）。所以额度一旦不再需要就删掉。
ALLOW = {
    # theme.dart 是这些 getter 的**定义**处，不是使用处
    'lib/theme.dart': (99, 'getter 定义本身'),
}

CHROME = ('C.sheetFill', 'C.surfaceFillStrong')
SHELLS = ('MaterialSurface(', 'MaterialAppBar(')
PAIRS = {'(': ')', '[': ']', '{': '}'}
CLOSE = set(')]}')


def shell_ranges(lines):
    """返回所有材质壳覆盖的行号区间 [(start, end), ...]（0-indexed）。"""
    out = []
    for i, l in enumerate(lines):
        for op in SHELLS:
            if op in l:
                out.append(match_range(lines, i, op))
                break
    return out


def match_range(lines, start, opener):
    depth, instr = 0, None
    for i in range(start, len(lines)):
        line = lines[i]
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
                    return (start, i)
            k += 1
    raise AssertionError('材质壳未闭合（第 %d 行）' % (start + 1))


def import_problems():
    """用了材质壳却没 `import 'material.dart';` 的文件。

    为什么把这条也放进这个脚本：它和我自己撞过两次的同一种错一模一样 ——
    “本地语法解析看得过去（`dart format` 只判语法），只有 analyze/编译会报
    undefined_method”。本机跑不了 analyze（会压垮同机的服务），所以每次都得
    等 CI 跑一轮才知道。把它变成一个本地就能跑的检查，一轮 CI 就省下来了。
    """
    need = ('MaterialSurface(', 'MaterialAppBar(', 'surfaceTint(')
    out = []
    for base, _dirs, files in os.walk(LIB):
        for fn in sorted(files):
            if not fn.endswith('.dart'):
                continue
            path = os.path.join(base, fn)
            rel = os.path.relpath(path, ROOT).replace(os.sep, '/')
            if rel == 'lib/material.dart':
                continue  # 定义处
            text = io.open(path, encoding='utf-8').read()
            lines = text.split('\n')
            used = sorted({n for n in need if any(n in l and not l.strip().startswith('//')
                                                 for l in lines)})
            if not used:
                continue
            if "import 'material.dart';" in text:
                continue
            out.append((rel, used))
    return out


def main() -> int:
    bad_imports = import_problems()
    if bad_imports:
        print('以下文件用了材质壳/函数，却没 import material.dart —— 会报 '
              'undefined_method（本地 dart format 看不出来）：')
        for rel, used in bad_imports:
            print('  NO-IMPORT  %-30s 用到 %s' % (rel, '、'.join(used)))
        print()

    problems = []
    for base, _dirs, files in os.walk(LIB):
        for fn in sorted(files):
            if not fn.endswith('.dart'):
                continue
            path = os.path.join(base, fn)
            rel = os.path.relpath(path, ROOT).replace(os.sep, '/')
            lines = io.open(path, encoding='utf-8').read().split('\n')
            zones = shell_ranges(lines)
            hits = []
            for i, l in enumerate(lines):
                stripped = l.strip()
                if stripped.startswith('//') or stripped.startswith('///'):
                    continue
                if not any(c in l for c in CHROME):
                    continue
                if any(lo <= i <= hi for lo, hi in zones):
                    continue
                hits.append(i + 1)
            if not hits:
                continue
            limit, reason = ALLOW.get(rel, (0, ''))
            if len(hits) <= limit:
                continue
            problems.append((rel, hits, reason))

    if not problems and not bad_imports:
        print('material coverage ok: 所有半透明壳表面都在材质壳内，且都 import 了 material.dart')
        return 0
    if not problems:
        print('（半透明壳表面的包裹本身是齐的）')
        return 1

    print('以下「半透明壳表面」没有套材质壳（材质开着时会半透明但不模糊，'
          '底下的内容直接透出来）：')
    for rel, hits, reason in problems:
        print('  MISSING  %-30s 行 %s' % (rel, ', '.join(map(str, hits))))
        if reason:
            print('           （该文件已登记理由：%s）' % reason)
    print('\n处置方式：① 套 MaterialSurface/MaterialAppBar；'
          '② 换成 C.surfaceFill（若它其实不压内容）；'
          '③ 加进本脚本 ALLOW 并写明理由。')
    return 1


if __name__ == '__main__':
    sys.exit(main())
