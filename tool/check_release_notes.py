#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Release 说明的提取检查：**直接跑工作流里那段 awk**，看它取到了什么。

为什么需要：Release 页的正文不是手写的，而是在打 tag 时由
`.github/workflows/build-release.yml` 里的 awk 从 CHANGELOG.md 抽出来的。
那段 awk 一改错，不会有任何东西失败 —— 只是 Release 页少半篇内容，
而**打 tag 之后才发现**（Release 已经发出去了，改它要重发版本）。

真实案例：原来的判据是「遇到下一个 `##` 就停」。而更新日志从 v1.6.78 起要求
中英双语，同一个版本有**两个** `## [x.y.z]` 标题（中文 + `(English)`）——
于是英文条目被整个丢掉，v1.6.78 到 v1.6.153 的 Release 页一直只有中文，
谁都没发现（因为中文那半看起来是完整的）。

这个脚本不做「再实现一遍」——那等于测我自己的理解，而不是测线上那段代码。
它把 awk 程序**从工作流文件里抠出来**，喂给系统的 awk 跑，再检查结果：

  * 该版本的中文条目在里面；
  * 该版本的英文条目（`(English)`）也在里面；
  * **没有**混入相邻版本的标题（多取）。

用法：python3 tool/check_release_notes.py
退出码 0 = 提取正确；1 = 有问题（并说明缺了什么）。
"""
import io
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKFLOW = '.github/workflows/build-release.yml'


def read(rel):
    return io.open(os.path.join(ROOT, rel), encoding='utf-8').read()


def extract_awk_program(yml):
    """把工作流里 `body=$(awk -v v="$ver" ' ... ' CHANGELOG.md | head -n -1)` 的
    awk 程序原样抠出来。

    刻意按**首尾标记**取而不是正则匹配整个表达式：这段程序里既有单引号又有
    `[`，用正则写只会写成「看起来对」的一团，而出错时它自己就成了新的问题源。
    """
    start_mark = "awk -v v=\"$ver\" '"
    i = yml.find(start_mark)
    if i < 0:
        return None
    i += len(start_mark)
    end_mark = "' CHANGELOG.md"
    j = yml.find(end_mark, i)
    if j < 0:
        return None
    return yml[i:j]


def newest_version(changelog):
    m = re.search(r'(?m)^## \[([0-9]+\.[0-9]+\.[0-9]+)\]', changelog)
    return m.group(1) if m else None


def run_awk(program, ver, changelog):
    """跑 awk（不透传 head -n -1：那只是去掉末尾空行，不影响本检查）。"""
    proc = subprocess.run(
        ['awk', '-v', f'v={ver}', program, os.path.join(ROOT, 'CHANGELOG.md')],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        return None, proc.stderr.strip()
    return proc.stdout, None


def main() -> int:
    errors = []
    yml = read(WORKFLOW)
    changelog = read('CHANGELOG.md')

    program = extract_awk_program(yml)
    if not program:
        print('release 说明检查失败：\n  - 在 %s 里找不到那段 awk 提取程序 —— '
              '要么它被改名/搬走了，要么写法变了（本检查需要跟着改）' % WORKFLOW)
        return 1

    ver = newest_version(changelog)
    if not ver:
        print('release 说明检查失败：\n  - CHANGELOG.md 里找不到 `## [x.y.z]` 标题')
        return 1

    out, err = run_awk(program, ver, changelog)
    if out is None:
        print(f'release 说明检查失败：\n  - awk 跑不起来：{err}')
        return 1
    if not out.strip():
        print(f'release 说明检查失败：\n  - awk 对最新版本 {ver} 什么都没提取到 '
              '—— Release 页会是空的')
        return 1

    # ① 中文条目在
    if not re.search(r'(?m)^## \[' + re.escape(ver) + r'\]', out):
        errors.append(f'提取结果里没有 {ver} 的中文条目标题')
    # ② 英文条目也在（同一版本的 `(English)` 标题）
    if not re.search(r'(?m)^## \[' + re.escape(ver) + r'\] .*\(English\)', out):
        errors.append(f'提取结果里没有 {ver} 的英文条目 —— 更新日志是中英双语的，'
                      'Release 页不该只有中文（v1.6.78~v1.6.153 就是这么丢的）')
    # ③ 没混入别的版本
    others = set(re.findall(r'(?m)^## \[([0-9]+\.[0-9]+\.[0-9]+)\]', out))
    others.discard(ver)
    if others:
        errors.append('提取结果里混入了别的版本：%s —— awk 的停止判据太宽'
                      % '、'.join(sorted(others)))

    if errors:
        print('release 说明检查失败：')
        for e in errors:
            print('  -', e)
        print('\n（这段 awk 在 %s 的 "Extract release notes from CHANGELOG"，'
              '改动后请用本脚本复核）' % WORKFLOW)
        return 1

    lines = len(out.rstrip('\n').split('\n'))
    print(f'release 说明 ok（{ver}：中英条目都在，{lines} 行，未混入其它版本）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
