#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""静态检查：State 里用到的 `widget.X`，必须在同文件的 Widget 类里有声明。

## 为什么需要它（同一类坑撞了三次）

「只有 analyze/编译能发现、本机语法解析看得过去」的错误：

1. 五个页面用 `MaterialSurface` 却没 `import 'material.dart'` → undefined_method；
2. 拼接文档时把 `final double bottomInset;` 写成两次 → duplicate_field；
3. **用跨块正则改注释时，把中间那个 `final double topInset;` 字段一起吞掉了**
   → initializing_formal_for_non_existent_field + 四处 undefined_getter。

第 3 种最阴：字段被删掉之后，`this.topInset = 0,` 与 `widget.topInset` 都还在，
代码读起来完全正常。本机跑不了 analyze（会压垮同机服务），于是每撞一次就白等
一轮 CI。这条检查专门盯它，本机几秒可跑。

## 判据

* 扫出所有 `widget.<名字>` 与构造里的 `this.<名字> =`；
* 每个名字必须在同文件里找到**声明**：2 空格缩进（类成员层）的一行里，
  名字后面跟 `;` / `=` / `(`；
* 排除含 `this.` 的行 —— 否则构造初始化 `this.topInset = 0,` 会被误当成声明，
  而我正是要抓「声明被删、初始化还在」这种情况（**宽松版漏报过一次**）；
* `_` 开头的名字跳过。

用法：python3 tool/check_widget_members.py
退出码 0 = 全部有声明；1 = 有名字没声明（并列出文件与行号）。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, 'lib')


def decl_pattern(name):
    """2 空格缩进、且**不含 this.** 的一行里，名字后跟 `;` / `=` / `(`。

    两点都是踩出来的：
    * 类型部分不能去枚举合法字符 —— 第一版用 `[A-Za-z_][\\w<>?,\\s\\[\\]]*`，
      `final double? centerLat;`（带问号）与函数类型 `void Function(...)? onTap;`
      全匹配不上，整个仓库冒出 12 条假失败。改成「行首到名字之间什么都允许」，
      靠 2 空格缩进把范围限制在类成员层（这一层不会有调用语句）。
    * 但也不能宽到把构造初始化算进去，否则 `this.topInset = 0,` 会被当成声明，
      「声明被删、初始化还在」这种要抓的情况反而漏报。
    """
    n = re.escape(name)
    # 终止符要把 `,` 也算上：本仓库不少字段是**同行逗号声明多个**
    # （`final double minZoom, maxZoom;` / `double? lat, lng;`），
    # 漏了逗号就会把这 5 处真声明误报成缺失 —— 假失败会把整条检查废掉。
    return re.compile(
        r'^  (?!.*\bthis\.)[^\n]*?(?<![\w.])' + n + r'\s*(?:[;=,()])', re.M
    )


def main() -> int:
    problems = []
    scanned = 0
    for base, _d, fs in os.walk(LIB):
        for f in sorted(fs):
            if not f.endswith('.dart'):
                continue
            p = os.path.join(base, f)
            rel = os.path.relpath(p, ROOT).replace(os.sep, '/')
            if rel.startswith('lib/l10n/'):
                continue
            text = io.open(p, encoding='utf-8').read()
            if 'widget.' not in text:
                continue
            scanned += 1
            names = {}
            for i, line in enumerate(text.split('\n'), 1):
                if line.strip().startswith('//'):
                    continue
                for m in re.finditer(r'\bwidget\.([A-Za-z_]\w*)', line):
                    names.setdefault(m.group(1), i)
                m = re.search(r'\bthis\.([A-Za-z_]\w*)\s*=', line)
                if m:
                    names.setdefault(m.group(1), i)
            for name, ln in sorted(names.items(), key=lambda kv: kv[1]):
                if name.startswith('_'):
                    continue
                if decl_pattern(name).search(text):
                    continue
                problems.append((rel, name, ln))

    if not problems:
        print('widget members ok: %d 个文件里的 widget.X 都有声明' % scanned)
        return 0

    print('以下名字被 `widget.` 用到、却在同文件里找不到声明 —— analyze 会报 '
          'undefined_getter / initializing_formal_for_non_existent_field：')
    for rel, name, ln in problems:
        print('  MISSING  %-30s widget.%s（第 %d 行首次出现）' % (rel, name, ln))
    print('\n典型成因：用「跨块正则」改注释时，把中间的字段声明一起删掉了。')
    return 1


if __name__ == '__main__':
    sys.exit(main())
