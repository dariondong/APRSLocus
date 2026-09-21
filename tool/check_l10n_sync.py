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
  3. 每个语言 arb 的每个键，都必须在对应生成类的文件里有成员。

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

    if errors:
        print('l10n 不同步（arb 是，产物不是）：')
        for e in errors:
            print('  -', e)
        print('\n修法：python3 tool/add_*_l10n.py 之类脚本要同时写 arb 与产物；'
              '\n或在能跑 flutter 的机器上执行 `flutter gen-l10n` 后提交产物。')
        return 1
    print(f'l10n 同步 ok（模板 {len(template_keys)} 键 × 6 语言）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
