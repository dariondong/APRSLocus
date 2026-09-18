#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""静态检查：备份分组的白名单必须与代码里真正读写的偏好键一致。

为什么需要这检查：「备份能导出、但恢复后某项设置没回来」不会报错、
不会崩、不会在测试里露头 —— 只会在用户换机那天被发现。而漏一个键的
典型原因是「新增偏好时忘了把它加进 lib/backup.dart 的分组」，靠人眼对齐
两份列表迟早会漂。

检查两个方向：
  1. lib/ 里所有 `getX('key')` / `setX('key')` 的键，都必须被某个分组覆盖
     （精确命中，或命中该分组的前缀）。例外要写进 EXCLUDE 并注明理由。
  2. 分组里写下的键，必须在 lib/ 里真的被用到 —— 否则是删代码后留下的
     死白名单项（它会让导出多带一个永远为空的键，也会误导后来人）。

用法：python3 tool/check_backup_keys.py   （CI 的 analyze 作业里会跑）
退出码 0 = 一致；1 = 有漂移（输出会列出具体键）。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 有意不进备份的键：键 → 理由（必须写清楚，否则下一个人只会把它当噪声删掉）
# 注意：这里只影响「必须归入分组」的方向；这些键在 lib/ 里仍然被读写。
EXCLUDE = {
    # 翻译缓存：导入旧缓存会把新翻译顶掉，而且它随时可以再生成。
    'translateCacheJson': '可再生的翻译缓存',
}

KEY_RE = re.compile(
    r"\.(?:get|set)(?:String|Bool|Int|Double|StringList)\(\s*'([A-Za-z0-9_]+)'"
)


def dart_sources():
    """lib/ 下的 Dart 源文件，**不含 backup.dart 自己**。

    排除它是因为白名单就写在里面：一旦把它算进来，「这个键有人用吗」
    这个问题会被它自己的声明回答成「有」，反向检查直接失效。
    """
    for base, _dirs, files in os.walk(os.path.join(ROOT, 'lib')):
        for f in files:
            if f.endswith('.dart') and f != 'backup.dart':
                yield os.path.join(base, f)


def used_keys():
    keys = set()
    for path in dart_sources():
        src = io.open(path, encoding='utf-8').read()
        keys.update(KEY_RE.findall(src))
    return keys


def mentioned_keys():
    """lib/ 里出现过的**任意带引号的字符串**。

    反向检查（白名单键是否还有人用）不能只找 `getX('key')`：有些键是通过
    常量间接读写的（例如 translate.dart 的 `_kConfig`），那类键在 get/set
    调用处只见常量名。用「字面量是否还出现在源码里」来判更宽松 —— 它可能有
    假阴性（键名恰好写在注释里），但它只是提醒，不是证明。
    """
    out = set()
    for path in dart_sources():
        src = io.open(path, encoding='utf-8').read()
        out.update(re.findall(r"'([A-Za-z0-9_]+)'", src))
    return out


def backup_groups():
    """解析 lib/backup.dart 里的分组白名单。

    用 -- 配对括号切块，而不是 `\\(([^)]*)\\)` 那种一旦遇到嵌套括号就截断的写法：
    截断的解析器会漏掉后半段键，从而报出一堆假失败（假失败比真失败更坏，
    因为修它的人通常会放宽规则）。
    """
    src = io.open(os.path.join(ROOT, 'lib', 'backup.dart'), encoding='utf-8').read()
    start = src.index('const List<BackupGroupSpec> kBackupGroups')
    end = src.index('BackupGroupSpec backupGroupSpec')
    block = src[start:end]

    groups = {}
    # 逐个 BackupGroupSpec(...) 块提取：从 "BackupGroupSpec(" 开始配对到对应的 ')'
    for m in re.finditer(r'BackupGroupSpec\(', block):
        i = m.end() - 1  # 指向 '('
        depth = 0
        j = i
        while j < len(block):
            if block[j] == '(':
                depth += 1
            elif block[j] == ')':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        chunk = block[i:j + 1]
        cat = re.match(r"\(\s*BackupCategory\.([a-z]+)", chunk)
        if not cat:
            continue
        keys = set(re.findall(r"'([A-Za-z0-9_]+)'", chunk))
        prefixes = set(re.findall(r"prefixes: \[\s*'([A-Za-z0-9_]+)'", chunk))
        groups[cat.group(1)] = (keys - prefixes, prefixes)
    return groups


def main() -> int:
    used_all = used_keys()
    mentioned = mentioned_keys()
    used = used_all - set(EXCLUDE)
    groups = backup_groups()
    covered = set()
    for _cat, (keys, prefixes) in groups.items():
        covered |= keys

    def is_covered(k):
        if k in covered:
            return True
        for _cat, (_keys, prefixes) in groups.items():
            for p in prefixes:
                if k.startswith(p):
                    return True
        return False

    missing = sorted(k for k in used if not is_covered(k))
    dead = sorted(k for k in covered if k not in mentioned)

    ok = True
    if missing:
        ok = False
        print('以下偏好键没有归入任何备份分组（新增偏好时要同步 lib/backup.dart）:')
        for k in missing:
            print('  MISSING  %s' % k)
    if dead:
        ok = False
        print('以下白名单键在 lib/ 里已无人读写（删代码后忘删白名单？）:')
        for k in dead:
            print('  DEAD     %s' % k)
    if not ok:
        print('\n如果某个键是**有意**不进备份的，请把它加进本脚本的 EXCLUDE 并写明理由。')
        return 1
    print('backup keys ok: %d 个偏好键全部归入 %d 个分组（白名单 %d 项）'
          % (len(used), len(groups), len(covered)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
