#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""静态检查：功能引导（lib/guide.dart）↔ l10n 键 ↔ 页面接入点，三者必须对得上。

为什么需要它：加一条引导要同时动**四个地方** ——
  ① lib/guide.dart 里的一条 `Guide(id: 'x', ...)` 并引用 `t.guideXTitle` / `t.guideXBody`；
  ② tool/add_guide_l10n.py 里补 `guideXTitle` / `guideXBody` × 6 语言；
  ③ 页面里放 `GuideTipCard(guideId: 'x', ...)`（或 `SettingsPageShell(guideId: 'x')`）；
  ④ gen-l10n 产物（本仓库把它们提交进 git）。

漏掉任何一处**都不会让编译失败、也不会让测试失败**：
  * 漏 ②：CI 的 `generate: true` 会按 arb 重新生成产物，于是本机报 undefined_getter、
    CI 却是绿的（最耗人的那种）；漏了某一种语言则只在那一种语言下**运行时**崩。
  * 漏 ③：引导写好了但**永远不出现** —— 看起来一切正常，只是用户没被引导过。
  * 多出一个没人用的 id：白写一条文案，且 `GuideTipCard` 会静默返回空
    （`guideOf` 找不到就返回 null，这是刻意的容错）。

所以这一条检查按「四个地方一一对应」来判，两个方向都查：
  * **正向**：每条 Guide 都要有 6 语言的标题+说明键、都要有产物 getter、都要有页面在用；
  * **反向**：页面里出现的每个 guideId 都必须真的存在。

用法：python3 tool/check_guides.py
退出码 0 = 一致；1 = 有漂移（并列出具体是哪条、缺哪一步）。
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, 'lib')

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
GEN_TARGETS = [
    ('zh', 'app_localizations_zh.dart', 'AppLocalizationsZh'),
    ('zh_TW', 'app_localizations_zh.dart', 'AppLocalizationsZhTw'),
    ('en', 'app_localizations_en.dart', 'AppLocalizationsEn'),
    ('ja', 'app_localizations_ja.dart', 'AppLocalizationsJa'),
    ('es', 'app_localizations_es.dart', 'AppLocalizationsEs'),
    ('id', 'app_localizations_id.dart', 'AppLocalizationsId'),
]


def read(rel):
    return io.open(os.path.join(ROOT, rel), encoding='utf-8').read()


def key_for(guide_id, suffix):
    """id 'offlineMap' → 'guideOfflineMapTitle'"""
    return 'guide' + guide_id[0].upper() + guide_id[1:] + suffix


def guide_ids(src):
    """lib/guide.dart 里声明了哪些 id（保持出现顺序）"""
    return re.findall(r"\bid:\s*'([A-Za-z0-9_]+)'", src)


def class_body(src, cls):
    m = re.search(r'(?m)^(?:abstract )?class ' + re.escape(cls) + r'\b', src)
    if not m:
        return None
    end = src.find('\n}', m.end())
    return src[m.end():end] if end > 0 else None


def has_getter(text, key):
    return re.search(r'String (?:get )?' + re.escape(key) + r'\s*[;(<={]',
                     text) is not None


def main() -> int:
    errors = []

    guide_src = read('lib/guide.dart')
    ids = guide_ids(guide_src)
    if not ids:
        print('引导检查失败：\n  - lib/guide.dart 里一条 Guide 都没解析到'
              '（要么写法变了，要么文件被搬走 —— 本检查需要跟着改）')
        return 1
    dup = {i for i in ids if ids.count(i) > 1}
    if dup:
        errors.append('lib/guide.dart 里 id 重复：%s' % '、'.join(sorted(dup)))

    # ① guide.dart 里必须**引用了**那两条键（否则键写对了但没接上）
    for gid in ids:
        for suffix in ('Title', 'Body'):
            k = key_for(gid, suffix)
            if not re.search(r'\bt\.' + re.escape(k) + r'\b', guide_src):
                errors.append(f"lib/guide.dart 的 '{gid}' 没有引用 t.{k}")

    # ② arb：6 语言都要有这两个键
    for lg in LANGS:
        rel = f'lib/l10n/app_{lg}.arb'
        src = read(rel)
        data = json.loads(src)
        for gid in ids:
            for suffix in ('Title', 'Body'):
                k = key_for(gid, suffix)
                if k not in data:
                    errors.append(f"{rel} 缺键 {k}（'{gid}' 的{suffix}）")

    # ③ 产物：抽象类 + 6 个语言类都要有 getter
    abs_src = read('lib/l10n/app_localizations.dart')
    for gid in ids:
        for suffix in ('Title', 'Body'):
            k = key_for(gid, suffix)
            if not has_getter(abs_src, k):
                errors.append(f'lib/l10n/app_localizations.dart 缺 {k} 声明')
    for lg, fname, cls in GEN_TARGETS:
        rel = f'lib/l10n/{fname}'
        src = read(rel)
        body = class_body(src, cls)
        if body is None:
            errors.append(f'{rel}: 找不到 {cls}')
            continue
        for gid in ids:
            for suffix in ('Title', 'Body'):
                k = key_for(gid, suffix)
                if not has_getter(body, k):
                    errors.append(f'{rel}/{cls} 缺 {k}')

    # ④ 页面接入点：正向（每条都要有页面在用）+ 反向（用到的 id 必须存在）
    used = {}
    for base, _dirs, files in os.walk(LIB):
        for fn in sorted(files):
            if not fn.endswith('.dart'):
                continue
            path = os.path.join(base, fn)
            rel = os.path.relpath(path, ROOT).replace(os.sep, '/')
            if rel == 'lib/guide.dart' or rel.startswith('lib/l10n/'):
                continue
            text = io.open(path, encoding='utf-8').read()
            for m in re.finditer(r"guideId:\s*'([A-Za-z0-9_]+)'", text):
                used.setdefault(m.group(1), []).append(rel)

    for gid, where in sorted(used.items()):
        if gid not in ids:
            errors.append("引导 id '%s' 在 %s 里被用，但 lib/guide.dart 里没有它"
                          % (gid, '、'.join(sorted(set(where)))))
    # guide.dart 自己的文案表里，未被任何页面引用的那条
    for gid in ids:
        if gid not in used:
            errors.append("引导 '%s' 没有任何页面在用 —— 文案白写，用户也永远不会看到"
                          % gid)

    if errors:
        print('引导检查失败：')
        for e in errors:
            print('  -', e)
        print('\n（加引导的四处改动见本文件顶部说明）')
        return 1

    print(f'引导检查 ok（{len(ids)} 条 × 6 语言 × 标题/说明，'
          f'产物 getter 齐全，页面接入点 {len(used)} 处）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
