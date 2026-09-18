#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""静态检查：备份分组的白名单必须与代码里真正读写的偏好键一致。

为什么需要这检查：「新增偏好时忘了把它归入备份分组」不会让编译失败、不会让
测试失败，只会在用户换机那天少一项设置。靠人眼对齐两份列表迟早会漂。

检查三个方向：
  1. **精确键**：`getX('key')` / `setX('key')` 里的键必须被某个分组覆盖
     （精确命中，或命中该分组声明的前缀）。
  2. **常量键**：`getX(SomeConst)` 里常量的字面量值也必须被覆盖。
  3. **动态键**：`setX('${_kPrefPrefix}$k')` 这类拼接求不出完整键，
     但它暴露了**前缀**；该前缀必须被某个分组用 `prefixes:` 声明。
  再加一个反向检查：白名单里的键必须在 lib/ 里真的还有人用
  （否则是删代码后留下的死项，会让导出多带一个永远为空的键）。

三条踩过的坑（都写在代码注释里，因为下一个人会重复踩）：

* **只扫字面量 = 对常量写法失明**。第一版没看 `getX(kPrefsKey)`，
  于是主题键 `themeBundle` 这种写法完全不在检查范围 —— 正是要防的场景
  可以堂而皇之地通过。检查器对某类写法失明，等于对这类写法没有检查。
* **常量必须按文件作用域解析**。Dart 里 `static const _kConfig` 是每个库
  各自一份，而 `tnc.dart` / `audio.dart` / `pkwdwpl.dart` 三个文件都有这个
  名字、值却不同。坦名表会让其中两个的键被算成第三个的值 → 真实漏组
  （TNC/音频/PKWDWPL 配置没进备份）反而被报成别的键缺失。
  ← 这个 bug 是靠「修完还剩下对不上的名字」才发现的，所以：**别急着把
  报出来的名字当成事实，先确认检查器没有张冠李戴。**
* **参数必须用「配对括号 + 顶层逗号」切**，不能 `\\(([^)]*)\\)`。
  后者遇到 `jsonEncode(x, y)` 会在第一个 `)` 截断，把整串实参当第一个参数，
  于是一堆普通字面量被误判成动态前缀 → 一屏假失败。
  假失败比真失败更坏：修它的人通常会把规则放宽或删掉说明。

用法：python3 tool/check_backup_keys.py   （CI 的 analyze 作业里会跑）
退出码 0 = 一致；1 = 有漂移（并列出具体键）。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 有意不进备份的键：键 → 理由（必须写清楚，否则下一个人只会把它当噪声删掉）
EXCLUDE = {
    # 翻译缓存：导入旧缓存会把新翻译顶掉，而且它随时可以再生成。
    'translateCacheJson': '可再生的翻译缓存',
    # APRS 设备识别库快照 + 更新时间戳：随应用发布并会静默从官方源更新，
    # 属于「可再生」数据；备份它只会让新装的设备把旧库盖回去。
    'deviceDbJsonV1': '网络可再生的设备识别库快照',
    'deviceDbUpdatedAtV1': '设备识别库的更新时间戳',
}

GETSET = re.compile(r"\.(?:get|set)(?:String|Bool|Int|Double|StringList)\(")
CONST_DECL = re.compile(
    r"static const (?:String )?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"
    r"('(?:[^']*)'|[A-Za-z_][A-Za-z0-9_]*)\s*;"
)
IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def dart_sources(skip_backup=True):
    """lib/ 下的 Dart 源文件。

    [skip_backup] 默认 True：跳过 backup.dart 自己 —— 白名单就写在里面，
    把它算进来会让「这个键还有人用吗」被它自己的声明回答成「有」，
    反向检查直接失效。
    """
    for base, _dirs, files in os.walk(os.path.join(ROOT, 'lib')):
        for f in files:
            if f.endswith('.dart') and not (skip_backup and f == 'backup.dart'):
                yield os.path.join(base, f)


def read_all():
    return {p: io.open(p, encoding='utf-8').read() for p in dart_sources()}


def _resolve(raw):
    """「名字 → 字面量或另一个名字」解析成「名字 → 字面量」（支持链式）"""
    resolved = {}

    def walk(name, seen):
        if name in resolved:
            return resolved[name]
        if name in seen:
            return None  # 环
        seen.add(name)
        v = raw.get(name)
        if v is None:
            return None
        out = v[1:-1] if v.startswith("'") else (
            walk(v, set(seen)) if IDENT.match(v) else None)
        if out is not None:
            resolved[name] = out
        return out

    for k in raw:
        walk(k, set())
    return resolved


def const_tables(sources):
    """返回 (每文件常量表, 全局常量表)。

    按文件解析是必须的：`static const _kConfig` 在每个库里各有一份，
    tnc.dart 是 'tncConfigJson'、audio.dart 是 'audioConfigJson'、
    pkwdwpl.dart 是 'pkwdwplConfigJson'。用一张全局表会让后写的覆盖先写的，
    于是另外两个键被判成「别的键缺失」—— 真问题被改名，白跑一趟。
    另留全局表是因为确有跨库引用（如 ThemeController.kPrefsKey）。
    """
    per_file, global_raw = {}, {}
    for path, src in sources.items():
        raw = {}
        for m in CONST_DECL.finditer(src):
            raw[m.group(1)] = m.group(2)
        per_file[path] = _resolve(raw)
        global_raw.update(raw)
    return per_file, _resolve(global_raw)


def split_top_level(s):
    """按顶层逗号切实参（忽略括号/方括号/花括号内与字符串内的逗号）"""
    out, depth, buf, quote = [], 0, [], None
    for ch in s:
        if quote:
            buf.append(ch)
            if ch == quote:
                quote = None
            continue
        if ch in "'\"":
            quote = ch
            buf.append(ch)
        elif ch in '([{':
            depth += 1
            buf.append(ch)
        elif ch in ')]}':
            depth -= 1
            buf.append(ch)
        elif ch == ',' and depth == 0:
            out.append(''.join(buf))
            buf = []
        else:
            buf.append(ch)
    if buf:
        out.append(''.join(buf))
    return [x.strip() for x in out]


def extract_args(src, open_paren_idx):
    """从 '(' 起配对取实参串（嵌套括号安全）"""
    depth, i = 0, open_paren_idx
    while i < len(src):
        if src[i] == '(':
            depth += 1
        elif src[i] == ')':
            depth -= 1
            if depth == 0:
                return src[open_paren_idx + 1:i]
        i += 1
    return ''


def classify_arg(arg, consts):
    """('exact', 键) / ('prefix', 前缀) / ('unresolved', 原文)"""
    a = arg.strip()
    if not a:
        return ('unresolved', a)

    # 整段就是一个字面量（键里不可能有 $）
    m = re.fullmatch(r"'([^'$]*)'", a)
    if m:
        return ('exact', m.group(1))

    # 纯标识符 → 查常量表
    if IDENT.match(a):
        lit = consts.get(a)
        return ('exact', lit) if lit is not None else ('unresolved', a)

    # 插值：取第一个片段作为静态前缀，两种写法都认
    #   'honorPrimary_$base'  → honorPrimary_
    #   '${_kPrefPrefix}$k'   → 常量 _kPrefPrefix 的值
    # 注意结尾那个 `'` 不能漏：漏了的话整条分支永远不匹配，
    # 「动态前缀」这一类就**静默失效**（检查器看上去还在跑，实际什么都没查）。
    m = re.match(
        r"'((?:[^'$]|\$[A-Za-z_][A-Za-z0-9_]*|\$\{[A-Za-z_][A-Za-z0-9_]*\})+)'$", a)
    if m:
        frag = m.group(1)
        cut = frag.split('$')[0]
        if cut:
            return ('prefix', cut)
        m2 = re.match(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?", frag)
        if m2:
            lit = consts.get(m2.group(1))
            if lit is not None:
                return ('prefix', lit)
        return ('unresolved', a)

    return ('unresolved', a)


def scan(sources):
    per_file, globals_ = const_tables(sources)
    exact, prefixes, unresolved = {}, {}, {}
    for path, src in sources.items():
        consts = dict(globals_)
        consts.update(per_file.get(path, {}))  # 本文件优先
        for m in GETSET.finditer(src):
            args = split_top_level(extract_args(src, m.end() - 1))
            kind, val = classify_arg(args[0] if args else '', consts)
            where = '%s:%d' % (os.path.basename(path),
                               src[:m.start()].count('\n') + 1)
            {'exact': exact, 'prefix': prefixes,
             'unresolved': unresolved}[kind].setdefault(val, []).append(where)
    return exact, prefixes, unresolved


def mentioned_keys(sources):
    """lib/ 里出现过的任意带引号字符串（反向检查用，宽松即可）"""
    out = set()
    for src in sources.values():
        out.update(re.findall(r"'([A-Za-z0-9_]+)'", src))
    return out


def backup_groups():
    """解析 lib/backup.dart 里的分组白名单（配对括号切块）"""
    src = io.open(os.path.join(ROOT, 'lib', 'backup.dart'), encoding='utf-8').read()
    block = src[src.index('const List<BackupGroupSpec> kBackupGroups'):
                src.index('BackupGroupSpec backupGroupSpec')]
    groups = {}
    for m in re.finditer(r'BackupGroupSpec\(', block):
        chunk = extract_args(block, m.end() - 1)
        cat = re.match(r"\s*BackupCategory\.([a-z]+)", chunk)
        if not cat:
            continue
        prefixes = set(re.findall(r"prefixes: \[\s*'([A-Za-z0-9_]+)'", chunk))
        keys = set(re.findall(r"'([A-Za-z0-9_]+)'", chunk)) - prefixes
        groups[cat.group(1)] = (keys, prefixes)
    return groups


def main() -> int:
    sources = read_all()
    exact, prefixes, unresolved = scan(sources)
    mentioned = mentioned_keys(sources)
    groups = backup_groups()

    covered, declared_prefixes = set(), set()
    for _cat, (keys, pfs) in groups.items():
        covered |= keys
        declared_prefixes |= pfs

    def prefix_ok(p):
        return any(p.startswith(d) or d.startswith(p) for d in declared_prefixes)

    missing = sorted(k for k in exact if k not in covered and k not in EXCLUDE)
    orphan = sorted(p for p in prefixes if not prefix_ok(p))
    dead = sorted(k for k in covered if k not in mentioned)

    ok = True
    if missing:
        ok = False
        print('以下偏好键没有归入任何备份分组（新增偏好时要同步 lib/backup.dart）:')
        for k in missing:
            print('  MISSING    %-26s %s' % (k, exact[k][0]))
    if orphan:
        ok = False
        print('以下「动态键前缀」没有任何分组声明（说明一整类键游离在备份之外）:')
        for p in orphan:
            print("  PREFIX     %-26s %s（应在分组里写 prefixes: ['%s']）"
                  % (p, prefixes[p][0], p))
    if dead:
        ok = False
        print('以下白名单键在 lib/ 里已无人读写（删代码后忘删白名单？）:')
        for k in dead:
            print('  DEAD       %s' % k)
    if unresolved:
        print('以下调用无法静态求出键或前缀，请人工确认已归入分组:')
        for a, where in sorted(unresolved.items()):
            print('  UNRESOLVED %-26s %s' % (a[:26], where[0]))

    if not ok:
        print('\n如果某个键是**有意**不进备份的，请把它加进本脚本的 EXCLUDE 并写明理由。')
        return 1
    print('backup keys ok: %d 个精确键 + %d 个动态前缀全部归入 %d 个分组（白名单 %d 项）'
          % (len(exact), len(prefixes), len(groups), len(covered)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
