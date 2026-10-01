#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""远程限制名单（`docs/assets/blacklist.json`）的静态检查。

## 为什么需要它

这份名单是**手写的 JSON**，而它一旦写坏，后果不成比例：

  * 条目里 `call` / `device` 都忘了写 → 在应用里是"永不命中"（不会误伤，但也白写）；
  * 写成小写呼号 / 带空格的标识 → 应用里**静默不命中**（用户明明在名单上却能用）；
  * JSON 语法坏掉 → 应用侧解析失败 → **放行**（名单形同虚设，而且不报错）。

最要命的是：这三种情况在应用里**都不报错**，只是"名单没生效"。所以钉在这里，
并且把"应用到底从哪里取这份文件"也一并核对（路径改了而这里没改 = 取不到）。
另外把**自伤**也挡在门外：条目必须至少有一项、标识必须是应用生成的那种 32 位十六进制
（`lib/blacklist.dart` 的 `deviceId()`）—— 格式不对的标识写了也不会命中。

用法：python3 tool/check_blacklist.py
退出码 0 = 一致；1 = 有问题（列出具体哪一条）。
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSON_PATH = os.path.join(ROOT, 'docs', 'assets', 'blacklist.json')
APP = os.path.join(ROOT, 'lib', 'blacklist.dart')

RE_CALL = re.compile(r'^[A-Z0-9]{1,6}(-[0-9]{1,2})?$')
RE_DEVICE = re.compile(r'^[0-9a-f]{32}$')
RE_DATE = re.compile(r'^\d{4}-\d{2}-\d{2}$')


def main() -> int:
    errors = []

    if not os.path.exists(JSON_PATH):
        print('缺 docs/assets/blacklist.json（应用要从这里取名单）')
        return 1
    text = io.open(JSON_PATH, encoding='utf-8').read()
    try:
        data = json.loads(text)
    except Exception as e:
        print('blacklist.json 不是合法 JSON：%s' % e)
        print('  ⚠ 应用侧会**放行**（不拦人），名单形同虚设 —— 而且不会有任何提示')
        return 1
    if not isinstance(data, dict):
        print('blacklist.json 顶层必须是对象')
        return 1

    if not RE_DATE.match(str(data.get('updated', ''))):
        errors.append('`updated` 必须是 YYYY-MM-DD（现在是 %r）' % data.get('updated'))
    entries = data.get('entries')
    if not isinstance(entries, list):
        errors.append('`entries` 必须是数组')

    seen = {}
    for i, e in enumerate(entries if isinstance(entries, list) else []):
        where = 'entries[%d]' % i
        if not isinstance(e, dict):
            errors.append('%s 必须是对象' % where)
            continue
        call = e.get('call')
        dev = e.get('device')
        if not call and not dev:
            errors.append('%s 既没有 call 也没有 device —— 这条**永远不会生效**' % where)
        if call is not None:
            if not RE_CALL.match(str(call)):
                errors.append('%s 的 call=%r 不合法（大写字母数字 + 可选 -SSID；'
                              '小写或带空格在应用里会**静默不命中**）' % (where, call))
            elif str(call) in seen:
                errors.append('%s 的 call=%s 与 %s 重复' % (where, call, seen[str(call)]))
            else:
                seen[str(call)] = where
        if dev is not None:
            if not RE_DEVICE.match(str(dev)):
                errors.append('%s 的 device=%r 不是 32 位小写十六进制 —— 应用生成的'
                              '安装标识就是这个形状，格式不对永远不会命中' % (where, dev))
            elif str(dev) in seen:
                errors.append('%s 的 device=%s 与 %s 重复' % (where, dev, seen[str(dev)]))
            else:
                seen[str(dev)] = where
        if 'reason' not in e:
            errors.append('%s 缺 reason —— 拦截页会没有原因可显示' % where)
        if 'at' in e and not RE_DATE.match(str(e.get('at'))):
            errors.append('%s 的 at=%r 不是 YYYY-MM-DD' % (where, e.get('at')))

    # 应用必须从这份文件取（路径写错 = 名单取不到，而应用只会"静默放行"）
    if not os.path.exists(APP):
        errors.append('缺 lib/blacklist.dart')
    else:
        app = io.open(APP, encoding='utf-8').read()
        if 'assets/blacklist.json' not in app:
            errors.append('lib/blacklist.dart 里找不到 `assets/blacklist.json` —— '
                          '应用取的地址与这份文件不一致')
        # "失败放行"是设计要求（写错就会把所有人挡在门外），代码里必须有说明
        if '失败放行' not in app:
            errors.append('lib/blacklist.dart 里没有"失败放行"的说明 —— '
                          '这条是安全底线（拉不到名单时绝不能不让人用）')

    if errors:
        print('限制名单检查失败：')
        for e in errors:
            print('  -', e)
        return 1
    print('限制名单 ok（%d 条；格式与应用的取址一致）'
          % len(entries if isinstance(entries, list) else []))
    return 0


if __name__ == '__main__':
    sys.exit(main())
