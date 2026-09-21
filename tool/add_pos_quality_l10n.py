#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""为「打点质量层」补 l10n 键（6 语言）+ 同步写入 gen-l10n 产物。

背景：v1.6.147 起只有**自己的位置**需要这两个键：
  * `posAccuracy` —— 「我的位置」面板显示实测精度（±40 m）；
  * `locationStill` —— 静止防抖判定为静止时的定位状态串。

（v1.6.145 加过的 posAccuracyExact / posAccuracyApprox / posCoasting 已在 v1.6.147
随接收侧质量层一起撤掉 —— 保留这里会让脚本把它们再加回来。）

为什么连 gen-l10n 的产物一起写：
  本仓库把 `lib/l10n/app_localizations*.dart` **提交进了 git**，但本机
  不能跑 flutter/analyze（服务同机、内存吃紧），所以不能靠 `flutter gen-l10n`
  更新它们。CI 里 `generate: true` 会在 pub get / build 时重新生成，
  产物以 arb 为准 —— 但如果不同时更新，本机就没有任何东西能校验
  「arb 有键、代码却拿不到 getter」这种错，只能等 CI。
  因此这里按 gen-l10n 的输出格式一并写入，并由
  `tool/check_l10n_sync.py` 在 CI 里守住「arb ↔ 产物」一致。

约定：幂等（按类边界判重，不是按整个文件 —— zh 文件里有两个类）、
追加到 arb / 各类末尾，与 tool/add_*_l10n.py 一致。
"""
import io
import json
import os
import re
import sys

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}

# key -> (各语言文案, 占位符列表)
KEYS = [
    ('posAccuracy', (
        '位置精度',
        '位置精度',
        'Position accuracy',
        '位置精度',
        'Precisión de la posición',
        'Akurasi posisi',
    ), []),
    # 自己的位置被静止防抖判为静止时的定位状态串。
    # ⚠ locStatus 是**白名单映射**（widgets.dart 的 localizedLocationStatus）：
    # 新增状态串必须同时在 arb + 该映射里登记，否则英文/日文界面会直接漏出中文。
    # tool/check_pos_quality.py 会把这条当断言查。
    ('locationStill', (
        '静止',
        '靜止',
        'Stationary',
        '静止',
        'Estacionario',
        'Diam',
    ), []),
]

# 生成文件 → [(类名, 语言)]
GEN_FILES = {
    'app_localizations_zh.dart': [('AppLocalizationsZh', 'zh'),
                                  ('AppLocalizationsZhTw', 'zh_TW')],
    'app_localizations_en.dart': [('AppLocalizationsEn', 'en')],
    'app_localizations_ja.dart': [('AppLocalizationsJa', 'ja')],
    'app_localizations_es.dart': [('AppLocalizationsEs', 'es')],
    'app_localizations_id.dart': [('AppLocalizationsId', 'id')],
}

CLASS_RE = r'(?m)^(?:abstract )?class {name}\b'


def class_span(src, name):
    """返回类体的 [body_start, end) —— end 指向结尾 `}` 之前"""
    m = re.search(CLASS_RE.format(name=re.escape(name)), src)
    if not m:
        raise SystemExit(f'找不到类 {name}')
    end = src.find('\n}', m.end())
    if end < 0:
        raise SystemExit(f'找不到类 {name} 的结尾')
    return m.end(), end


def has_member(body, key):
    return re.search(r'String (?:get )?' + re.escape(key) + r'\s*[;(<={]', body) is not None


def dart_str(s, params):
    for p in params:
        s = s.replace('{' + p + '}', '$' + p)
    return s.replace('\\', '\\\\').replace("'", "\\'")


def member(key, text, params, abstract=False):
    if not params:
        if abstract:
            return f'  String get {key};'
        return f"  @override\n  String get {key} => '{dart_str(text, params)}';"
    sig = ', '.join(f'String {p}' for p in params)
    if abstract:
        return f'  String {key}({sig});'
    return (f'  @override\n'
            f'  String {key}({sig}) {{\n'
            f"    return '{dart_str(text, params)}';\n"
            f'  }}')


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    l10n = os.path.join(root, 'lib', 'l10n')

    # ① arb：追加缺失的键
    total = 0
    for lg in LANGS:
        p = os.path.join(l10n, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8').read()
        add = []
        for key, vals, _ in KEYS:
            if re.search(r'^\s*"' + re.escape(key) + r'":', src, re.M):
                print(f'  {lg}/{key}: 已存在，跳过')
                continue
            add.append(f'  {json.dumps(key, ensure_ascii=False)}: '
                       f'{json.dumps(vals[IDX[lg]], ensure_ascii=False)},')
        if not add:
            continue
        i = src.rstrip().rfind('}')
        head = src[:i].rstrip()
        if not head.endswith(','):
            head += ','
        src = head + '\n' + '\n'.join(add).rstrip(',') + '\n' + src[i:]
        io.open(p, 'w', encoding='utf-8').write(src)
        total += len(add)
        print(f'{lg}: arb 追加 {len(add)} 行')
    print(f'arb 共写入 {total} 行\n')

    # ② gen-l10n 产物：每个类各写自己的 getter
    for fname, classes in GEN_FILES.items():
        p = os.path.join(l10n, fname)
        for cname, lg in classes:
            src = io.open(p, encoding='utf-8').read()
            bs, be = class_span(src, cname)
            body = src[bs:be]
            block = [member(key, vals[IDX[lg]], params)
                     for key, vals, params in KEYS
                     if not has_member(body, key)]
            if not block:
                print(f'  {fname}/{cname}: 已存在，跳过')
                continue
            # 与 gen-l10n 的输出格式一致：成员之间空一行，末尾紧接 `}`
            src = src[:be] + '\n\n' + '\n\n'.join(block) + src[be:]
            io.open(p, 'w', encoding='utf-8').write(src)
            print(f'{fname}/{cname}: 写入 {len(block)} 个成员')

    # ③ app_localizations.dart：抽象签名
    p = os.path.join(l10n, 'app_localizations.dart')
    src = io.open(p, encoding='utf-8').read()
    bs, be = class_span(src, 'AppLocalizations')
    block = [member(key, '', params, abstract=True)
             for key, _, params in KEYS
             if not has_member(src[bs:be], key)]
    if block:
        src = src[:be] + '\n\n' + '\n\n'.join(block) + src[be:]
        io.open(p, 'w', encoding='utf-8').write(src)
        print(f'app_localizations.dart/AppLocalizations: 写入 {len(block)} 个抽象签名')
    return 0


if __name__ == '__main__':
    sys.exit(main())
