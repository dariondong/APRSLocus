#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""l10n 一致性检查：arb（真源）↔ gen-l10n 产物（提交进 git）。

为什么需要它：
  本仓库把 `lib/l10n/app_localizations*.dart` 提交进了 git，而**本机不能跑
  flutter gen-l10n / analyze**（服务同机、内存吃紧），只能等 CI。CI 里
  `generate: true` 会在 pub get 时按 arb 重新生成产物，所以**产物写错也不会
  让 CI 失败** —— 真正会漏出去的是另一种情况：

    「arb 加了键，但代码里用了 S.of(context).xxx，而产物没更新」

  这在**本机开发时**报 undefined_getter（本地没有 regenerate），到 CI 又被
  重新生成掩盖掉 —— 表现是「我这儿明明有错，CI 却是绿的」，最耗人。
  所以这条检查按**未生成产物**的视角校验：arb ↔ 产物必须一一对应。

检查内容：
  1. 模板 arb（app_zh.arb）的每个键，都必须出现在其余 5 个 arb 里；
  2. 模板 arb 的每个键，都必须在 app_localizations.dart 的抽象类里有成员；
  3. 每个语言 arb 的每个键，都必须在对应生成类的文件里有成员；
  4. 反向：产物里不许有 arb 里没有的成员；
  5. **代码里 `s.xxx` / `S.of(context).xxx` 用到的键必须真的存在**。

第 5 条是 v1.6.165 现场加的：我写批量加键的脚本时，重写键表把 `garminUrlHint`
漏掉了，而**代码在用它**。arb 与产物是「一致地缺」的，所以 1~4 条全绿 —— 只有
`flutter analyze` 报 `undefined_getter`，代价是一整轮 CI（三个 job 全红、十几分钟）。
「arb ↔ 产物一致」与「代码用的键存在」是两件事，前者查得再细也盖不住后者。

按「有成员」判定（不比对文案），因为文案会正常改动。
"""
import io
import json
import os
import re
import sys

# 语言 arb → 产物文件里的类名
TARGETS = [
    ('zh', 'app_localizations_zh.dart', 'AppLocalizationsZh'),
    ('zh_TW', 'app_localizations_zh.dart', 'AppLocalizationsZhTw'),
    ('en', 'app_localizations_en.dart', 'AppLocalizationsEn'),
    ('ja', 'app_localizations_ja.dart', 'AppLocalizationsJa'),
    ('es', 'app_localizations_es.dart', 'AppLocalizationsEs'),
    ('id', 'app_localizations_id.dart', 'AppLocalizationsId'),
]
TEMPLATE = 'zh'


def arb_keys(path):
    """返回 (有序键列表, 原始文本)。跳过 @@locale 与 @说明 键。"""
    src = io.open(path, encoding='utf-8').read()
    data = json.loads(src)
    keys = [k for k in data if not k.startswith('@')]
    return keys, src


def class_body(src, name):
    m = re.search(r'(?m)^(?:abstract )?class ' + re.escape(name) + r'\b', src)
    if not m:
        return None
    end = src.find('\n}', m.end())
    return src[m.end():end] if end > 0 else None


def has_member(body, key):
    return re.search(r'String (?:get )?' + re.escape(key) + r'\s*[;(<={]',
                     body) is not None


def code_only(src):
    """剥掉注释与字符串字面量。

    做「代码里用了什么名字」这类判断**必须**先剥：注释里写着示例
    （`s.xxx`）、字符串里有文案，按全文匹配就会把说明文字当成用法 ——
    本次 settings_pages.dart 报的 `xxx` 就是这么来的（一条注释里的示例）。
    """
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '/' and src[i + 1:i + 2] == '/':
            j = src.find('\n', i)
            i = n if j < 0 else j
            continue
        if c == '/' and src[i + 1:i + 2] == '*':
            j = src.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        if c in '\'"':
            q = c
            i += 1
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src[i] == q:
                    break
                i += 1
            i += 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    l10n = os.path.join(root, 'lib', 'l10n')
    errors = []

    template_keys, _ = arb_keys(os.path.join(l10n, f'app_{TEMPLATE}.arb'))
    if not template_keys:
        print('模板 arb 里一个键都没有，检查本身可能坏了')
        return 1

    # ① 各语言 arb 键集合必须与模板一致
    for lg, _, _ in TARGETS:
        keys, _ = arb_keys(os.path.join(l10n, f'app_{lg}.arb'))
        missing = [k for k in template_keys if k not in keys]
        extra = [k for k in keys if k not in template_keys]
        if missing:
            errors.append(f'app_{lg}.arb 缺少模板里的键：{missing[:8]}'
                          f'（共 {len(missing)}）')
        if extra:
            errors.append(f'app_{lg}.arb 有模板里没有的键：{extra[:8]}'
                          f'（共 {len(extra)}）')

    # ② 抽象类必须有全部键
    base = io.open(os.path.join(l10n, 'app_localizations.dart'),
                   encoding='utf-8').read()
    body = class_body(base, 'AppLocalizations')
    if body is None:
        errors.append('app_localizations.dart 里找不到抽象类 AppLocalizations')
    else:
        miss = [k for k in template_keys if not has_member(body, k)]
        if miss:
            errors.append(f'app_localizations.dart 抽象类缺成员：{miss[:8]}'
                          f'（共 {len(miss)}）')

    # ③ 每个语言类必须有该语言 arb 的全部键
    for lg, fname, cname in TARGETS:
        src = io.open(os.path.join(l10n, fname), encoding='utf-8').read()
        body = class_body(src, cname)
        if body is None:
            errors.append(f'{fname} 里找不到类 {cname}')
            continue
        keys, _ = arb_keys(os.path.join(l10n, f'app_{lg}.arb'))
        miss = [k for k in keys if not has_member(body, k)]
        if miss:
            errors.append(f'{fname}/{cname} 缺成员：{miss[:8]}'
                          f'（共 {len(miss)}）')

    # ④ 反向：产物 / 抽象类里**不许有多余成员** —— arb 删了键却忘了删产物时，
    #    本机编译不会报错（多余成员无害），但它会一直漂下去，而且
    #    「arb 没有的键在界面里被人用了」会变成运行期异常。CI 重新生成会掩盖它。
    for lg, fname, cname in TARGETS:
        src = io.open(os.path.join(l10n, fname), encoding='utf-8').read()
        body = class_body(src, cname)
        if body is None:
            continue
        keys, _ = arb_keys(os.path.join(l10n, f'app_{lg}.arb'))
        # 只认真正的 l10n 成员：`String get xxx =>` / `String xxx(...)`。
        # 不能写成 `String (\w+)\s*[;=(]`——那会把 gen-l10n 产物里的
        # `final String locale;`（运行时字段）与带参方法内部的
        # `final String _temp0 = ...`（局部变量）也算成“成员”，误报一片。
        got = set(re.findall(r'String get (\w+)\s*(?:=>|;)', body))
        got |= set(re.findall(r'String (\w+)\(', body))
        got = {g for g in got if not g.startswith('_')}
        extra = sorted(got - set(keys))
        if extra:
            errors.append(f'{fname}/{cname} 有 arb 里没有的成员：{extra[:8]}'
                          f'（共 {len(extra)}）—— arb 删键后产物没跟着删')

    # ⑤ 代码里用到的键必须存在（见模块说明第 5 条）。
    #
    # ⚠ 这里是**按名字**匹配，所以必须把「同名但含义不同」的用法排除掉：
    # `s.xxx` 在有些文件里是台站对象（`final s = stations[i]`、`for (final s in …)`），
    # 在另一些文件里才是 `final s = S.of(context)`。第一版没区分，一次报了 8 个文件、
    # 其中 7 个是假失败（`s.lat`、`s.call` 全是台站字段）—— 假失败比没有检查更坏。
    #
    # 判据收紧成三条：
    #   * `S.of(context).xxx` / `S.of(ctx).xxx` —— 接收者是明确的单例表达式，永远安全；
    #   * `l10n.xxx` —— 只在文件里**只有一种** l10n 绑定（`AppLocalizations get l10n`）
    #     且没有任何 `final l10n = …` 重新绑定时才查；
    #   * `s.xxx` 这类简写 —— 只有当该名字在文件里**唯一的绑定就是 l10n**
    #     （不存在 `for (final s in …)`、`final s = 别的`）时才查。
    if body is not None:
        lib = os.path.join(root, 'lib')
        l10n_recv_re = re.compile(
            r'\bfinal\s+(?:AppLocalizations\s+)?(\w+)\s*=\s*'
            r'(?:S\.of\(context\)|S\.of\(ctx\)|l10n)\s*;')
        # 任何「别的绑定」都算：`for (final s in …)` 与 `final s = 别的`
        other_bind_re = r'(?:for\s*\(\s*final\s+{n}\s+in|final\s+{n}\s*=)'
        simple = [r'S\.of\(context\)\.(\w+)', r'S\.of\(ctx\)\.(\w+)']
        for dirpath, _dirs, files in os.walk(lib):
            if os.path.basename(dirpath) == 'l10n':
                continue  # 产物自己不查（它就是定义）
            for fn in sorted(files):
                if not fn.endswith('.dart'):
                    continue
                fp = os.path.join(dirpath, fn)
                src = code_only(io.open(fp, encoding='utf-8').read())
                # 排除 `extension X on AppLocalizations` 里定义的方法：它们长得
                # 和 arb 键一模一样（`s.transLangName(code)`），但**不是**键。
                # 不排除就会报假失败（chat_translate_ui.dart 现场踩到）。
                ext_names = set()
                if 'on AppLocalizations' in src:
                    ext_names = set(re.findall(r'String\s+(\w+)\s*\(', src))
                used = set()
                for pat in simple:
                    used |= set(re.findall(pat, src))
                for recv in set(l10n_recv_re.findall(src)):
                    # 该名字是否还有「别的绑定」（同名不同义）。
                    # ⚠ 不能用「搜到 final s = 就跳过」—— l10n 那个绑定本身就长这样，
                    # 那样写会让这条检查**永远不生效**（第一版就是这样：加进去的
                    # garminUrlHint 缺失居然查不出来）。要**数个数**：
                    # `final s =` 的总次数 > l10n 形式的次数 ⇒ 还有别的含义。
                    n_all = len(re.findall(
                        r'\bfinal\s+(?:\w+\s+)?{}\s*='.format(re.escape(recv)), src))
                    n_l10n = len(re.findall(
                        r'\bfinal\s+(?:AppLocalizations\s+)?{}\s*=\s*'
                        r'(?:S\.of\(context\)|S\.of\(ctx\)|l10n)\s*;'
                        .format(re.escape(recv)), src))
                    has_for = re.search(
                        r'for\s*\(\s*final\s+{}\s+in'.format(re.escape(recv)), src)
                    if n_all > n_l10n or has_for:
                        continue  # 同名歧义：跳过这个名字的简写检查
                    used |= set(re.findall(
                        r'\b{}\s*\.(\w+)'.format(re.escape(recv)), src))
                # `l10n.xxx`（AppState 的 getter）：文件里不许再有 `final l10n = …`
                if re.search(r'AppLocalizations\s+get\s+l10n', src) and not re.search(
                        r'final\s+\w+\s+l10n\s*=', src):
                    used |= set(re.findall(r'\bl10n\.(\w+)', src))
                bad = sorted(k for k in used
                             if not has_member(body, k) and k not in ext_names)
                if bad:
                    rel = os.path.relpath(fp, root).replace(os.sep, '/')
                    errors.append(f'{rel} 用了不存在的 l10n 键：{bad[:6]}'
                                  f'（共 {len(bad)}）—— 会报 undefined_getter，'
                                  f'本机查不出、只有 CI 的 analyze 会红')

    # ⑥ 带占位符的键：产物必须是**带参数的方法**，不能是 getter + 字面量 `{x}`
    #
    # 真实案例（v1.6.177）：`add_l10n_keys.py` 只会写 getter，于是
    # `String get beaconCoarseForced => "网络定位（粗）· {s}";` —— 成员在、文案在，
    # 只有**形态**不对。本机 `S.of(context).beaconCoarseForced(x)` 报 not_a_function；
    # 而 CI 的 pub get 会按 arb 重新生成 → 全绿。跟「我这儿有错、CI 却是绿的」
    # 是同一类问题，只有按 arb 的 @key.placeholders 对照产物才看得出来。
    tmpl = json.loads(io.open(os.path.join(l10n, f'app_{TEMPLATE}.arb'),
                              encoding='utf-8').read())
    ph_keys = [k for k in template_keys if isinstance(tmpl.get('@' + k), dict)
               and tmpl['@' + k].get('placeholders')]
    if not ph_keys:
        errors.append('模板 arb 里居然没有带占位符的键 —— 检查器自己可能坏了')
    # 抽象类
    #
    # ⚠ 必须**重新取一次**抽象类，不能复用上面那个 `body` —— ③ 的循环里
    # `body = class_body(src, cname)` 把它覆盖成了**最后一个语言类**（Id）。
    # 第一版就是复用 `body`，于是这一条永远在检查 Id 那个类：**改坏抽象类它不报**
    # （回归样本当场抓到；这类「变量被上一个循环覆盖」的假通过，写检查器时
    #  比正则写错更难看出来 —— 代码读起来完全正常）。
    abs_body = class_body(base, 'AppLocalizations')
    if abs_body is not None:
        for k in ph_keys:
            m = re.search(r'String (?:get )?' + re.escape(k) + r'\s*([;(])',
                          abs_body)
            if m and m.group(1) == ';':
                errors.append(f'抽象类里 {k} 是 getter，但 arb 声明了占位符 '
                              f'{sorted(tmpl["@" + k]["placeholders"])} —— 必须是'
                              f' `String {k}(...)`，否则本机调用处报 not_a_function')
    # 各语言实现
    for lg, fname, cname in TARGETS:
        src = io.open(os.path.join(l10n, fname), encoding='utf-8').read()
        b = class_body(src, cname)
        if b is None:
            continue
        for k in ph_keys:
            if re.search(r'String get ' + re.escape(k) + r'\s*=>', b):
                errors.append(f'{fname} 的 {k} 被写成 `String get {k} => ...`，'
                              f'但 arb 声明了占位符 —— 产物里会留着字面量 '
                              f'{{{{x}}}} 且调用处编译不过（与 gen-l10n 不同形）')

    if errors:
        print('l10n 不同步（arb 是，产物不是）：')
        for e in errors:
            print('  -', e)
        print('\n修法：python3 tool/add_*_l10n.py 之类脚本要同时写 arb 与产物；'
              '\n或在能跑 flutter 的机器上执行 `flutter gen-l10n` 后提交产物。')
        return 1
    print(f'l10n 同步 ok（模板 {len(template_keys)} 键 × 6 语言；'
          f'代码用到的键都存在）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
