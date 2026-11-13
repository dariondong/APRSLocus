#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""官网强提醒文件（`docs/assets/strong_notice.json`）的静态检查。

## 为什么需要它

这份文件是**手写的一份 JSON**，而它在应用里会**整页盖住主界面**。写坏的后果
全都**不报错**，只是「弹出来的东西不是你想的那样」：

  * JSON 语法坏 / 字段名拼错（`titel`）→ 应用侧解析成「一条都没有」→ **永远不弹**；
  * 少了 `title` 或 `body` → 应用侧整条丢掉（空白的强提醒比不弹更糟）；
  * `until` 写成 `2026/12/01` → 应用按「没写」处理 → **旧公告一直糊在人脸上**；
  * `until` 写成一个已经过去的日子 → 这条**永远不弹**（常常是忘了改）；
  * `level` 拼错（`warning`）→ 退成 `info`，红色警告变成蓝色提示；
  * `every` 忘了关（默认 false）→ 每开一次应用弹一次，用户会被拦烦；
  * `actions` 里的地址不是 http(s) → 点了打不开。

所以钉在这里：格式、语言文案、日期，以及「应用到底从哪里取这份文件」。
`items` 允许为空数组（空 = 什么都不弹，这是默认状态），空不是错。

用法：python3 tool/check_strong_notice.py
退出码 0 = 一致；1 = 有问题（列出具体哪一条）。
"""
import datetime
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSON_PATH = os.path.join(ROOT, 'docs', 'assets', 'strong_notice.json')
APP = os.path.join(ROOT, 'lib', 'strong_notice.dart')

RE_DATE = re.compile(r'^\d{4}-\d{2}-\d{2}$')
LEVELS = ('info', 'warn', 'critical')


def _text_ok(v):
    """一段文本可以写纯字符串，也可以写成按语言分开的 map（至少一条非空）。"""
    if isinstance(v, str):
        return bool(v.strip())
    if isinstance(v, dict):
        return any(isinstance(x, str) and x.strip() for x in v.values())
    return False


def main() -> int:
    errors = []
    warnings = []

    if not os.path.exists(JSON_PATH):
        print('缺 docs/assets/strong_notice.json（应用要从这里取强提醒内容）')
        return 1
    try:
        data = json.loads(io.open(JSON_PATH, encoding='utf-8').read())
    except Exception as e:
        print('strong_notice.json 不是合法 JSON：%s' % e)
        print('  ⚠ 应用侧会当成「一条都没有」 —— 永远不弹，而且不会有任何提示')
        return 1
    if not isinstance(data, dict):
        print('strong_notice.json 顶层必须是对象')
        return 1

    if not RE_DATE.match(str(data.get('updated', ''))):
        errors.append('`updated` 必须是 YYYY-MM-DD（现在是 %r）' % (data.get('updated'),))

    items = data.get('items')
    if not isinstance(items, list):
        errors.append('缺 `items` 数组（没有提醒也要显式写空数组）')
        items = []

    today = datetime.datetime.now(datetime.timezone.utc).date()
    ids = set()
    for i, it in enumerate(items):
        where = 'items[%d]' % i
        if not isinstance(it, dict):
            errors.append('%s 必须是对象' % where)
            continue
        sid = str(it.get('id', '')).strip()
        if not sid:
            errors.append('%s 缺 `id`（换个 id = 当成一条新提醒，所以它不能空）' % where)
        elif sid in ids:
            errors.append('%s 的 `id`=%r 与前面重复 —— 后弹的那条会被当成「已经弹过」'
                          % (where, sid))
        else:
            ids.add(sid)
            where = '%s(id=%s)' % (where, sid)
        if not _text_ok(it.get('title')):
            errors.append('%s 缺 `title`，或它不是非空字符串 / 非空的语言 map' % where)
        if not _text_ok(it.get('body')):
            errors.append('%s 缺 `body`，或它不是非空字符串 / 非空的语言 map' % where)
        lvl = str(it.get('level', 'info')).strip().lower()
        if lvl not in LEVELS:
            errors.append('%s 的 `level`=%r 不认识（只能是 info / warn / critical）'
                          % (where, it.get('level')))
        for key in ('hard', 'every'):
            if key in it and not isinstance(it.get(key), bool):
                errors.append('%s 的 `%s` 必须是 true / false' % (where, key))
        until = str(it.get('until', '')).strip()
        if until:
            if not RE_DATE.match(until):
                errors.append('%s 的 `until`=%r 不是 YYYY-MM-DD —— 应用会当成「没写」，'
                              '这条就永远不过期' % (where, until))
            else:
                try:
                    d = datetime.date(*[int(x) for x in until.split('-')])
                except Exception:
                    errors.append('%s 的 `until`=%r 不是有效日期' % (where, until))
                    d = None
                if d is not None:
                    if d < today:
                        errors.append('%s 的 `until`=%s 已经过去了 —— 这条永远不弹'
                                      % (where, until))
                    elif (d - today).days <= 3:
                        warnings.append('%s 的 `until`=%s 快到了（%d 天后失效）'
                                        % (where, until, (d - today).days))
        acts = it.get('actions')
        if acts is not None:
            if not isinstance(acts, list):
                errors.append('%s 的 `actions` 必须是数组' % where)
            else:
                for j, a in enumerate(acts):
                    if not isinstance(a, dict):
                        errors.append('%s.actions[%d] 必须是对象' % (where, j))
                        continue
                    if not _text_ok(a.get('label')):
                        errors.append('%s.actions[%d] 缺 `label`' % (where, j))
                    url = str(a.get('url', '')).strip()
                    if url and not re.match(r'^https?://', url):
                        errors.append('%s.actions[%d] 的 `url`=%r 不是 http(s) 地址，'
                                      '点了打不开' % (where, j, url))

    # 应用必须从这份文件取（路径写错 = 取不到，而应用只会「安静进主界面」）
    if not os.path.exists(APP):
        errors.append('缺 lib/strong_notice.dart')
    else:
        src = io.open(APP, encoding='utf-8').read()
        if 'assets/strong_notice.json' not in src:
            errors.append('lib/strong_notice.dart 里找不到 `assets/strong_notice.json` —— '
                          '应用取的地址与这份文件不一致')
        if 'dart:convert' not in src:
            errors.append('lib/strong_notice.dart 没有解析 JSON（dart:convert）')

    if warnings:
        for w in warnings:
            print('提示：', w)
    if errors:
        print('强提醒检查失败：')
        for e in errors:
            print('  -', e)
        return 1
    print('强提醒 ok（%d 条；%s）'
          % (len(items), '当前没有要弹的提醒' if not items else
             '最近一条要到 ' + str(items[-1].get('until') or '长期')))
    return 0


if __name__ == '__main__':
    sys.exit(main())
