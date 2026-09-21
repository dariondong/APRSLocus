#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""为「打点质量层」补 l10n 键（6 语言）+ 同步写入 gen-l10n 产物。

背景：v1.6.145 起台站详情页会显示**位置精度**（模糊位置的真实误差半径）
与**推测位置**（移动台站安静后按最后速度/航向外推），需要 4 个键。

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
    ('posAccuracyExact', (
        '精确（未声明模糊）',
        '精確（未宣告模糊）',
        'Exact (no ambiguity declared)',
        '正確（あいまいさの申告なし）',
        'Exacta (sin ambigüedad declarada)',
        'Presisi (tanpa ambiguitas)',
    ), []),
    ('posAccuracyApprox', (
        '±{r}（模糊 {n} 位）',
        '±{r}（模糊 {n} 位）',
        '±{r} (ambiguous to {n} digits)',
        '±{r}（{n} 桁のあいまいさ）',
        '±{r} (ambigüedad de {n} dígitos)',
        '±{r} (ambiguitas {n} digit)',
    ), ['r', 'n']),
    ('posCoasting', (
        '推测位置',
        '推測位置',
        'Estimated position',
        '推定位置',
        'Posición estimada',
        'Perkiraan posisi',
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
