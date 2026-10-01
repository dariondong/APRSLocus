#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""用户协议（terms）静态检查：两处副本同源 + 三语条款号一致 + 版本一致。

## 为什么需要它

协议正文有**两份手工副本**：
  * `assets/terms_*.txt`     —— 打包进 App，断网时的兜底；
  * `docs/assets/terms_*.txt` —— 官网在线加载的那一份（页面优先用它）。

这两份必须**逐字节一致**：不一致就会出现「同一个版本，联网看到 A、断网看到 B」，
而且**不会报任何错**（页面照常显示）—— 与 notice 踩过的坑同一个形状，所以那边有
`check_notice.py`，这边有它。

第二条判据是**三语条款号必须一致**：`3.5` 只加在中文里、英文漏了，用户切一下语言
就会看到两份不同的协议 —— 同样是"不报错但错"的类型。只比"条款条数"抓不到它
（条数可以一样而编号不同），所以这里比**编号集合**。

用法：python3 tool/check_terms.py
退出码 0 = 一致；1 = 有漂移（列出具体是哪一项）。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ['terms_zh.txt', 'terms_zh_TW.txt', 'terms_en.txt']
APP_DIR = os.path.join(ROOT, 'assets')
WEB_DIR = os.path.join(ROOT, 'docs', 'assets')

RE_CLAUSE = re.compile(r'(?m)^(\d+\.\d+)\s')
RE_ZH_CHAPTER = re.compile(r'(?m)^[一二三四五六七八九十]+、')
RE_EN_CHAPTER = re.compile(r'(?m)^\d+\.\s+[A-Z]')
RE_VERSION = re.compile(r'(?m)^(?:版本|Version)\s*[:：]\s*(V\d+\.\d+)')


def read(p):
    return io.open(p, encoding='utf-8', newline='').read()


def main() -> int:
    errors = []
    clauses = {}
    versions = {}
    chapters = {}

    for name in LANGS:
        ap = os.path.join(APP_DIR, name)
        wp = os.path.join(WEB_DIR, name)
        if not os.path.exists(ap) or not os.path.exists(wp):
            errors.append('缺文件：%s 或 docs/assets/%s' % (name, name))
            continue
        a, b = read(ap), read(wp)
        if a != b:
            errors.append('`assets/%s` 与 `docs/assets/%s` **不一致** —— '
                          '联网看到的与断网兜底的会是两份不同的协议（改一处要两边同步）'
                          % (name, name))
        if len(a.strip()) < 200:
            errors.append('%s 太短（<200 字符）—— 正文被截断了？' % name)
        clauses[name] = sorted(set(RE_CLAUSE.findall(a)))
        m = RE_VERSION.search(a)
        versions[name] = m.group(1) if m else ''
        chapters[name] = (len(RE_ZH_CHAPTER.findall(a)) if name != 'terms_en.txt'
                          else len(RE_EN_CHAPTER.findall(a)))

    # ⚠ 各判据**互不遮蔽**：副本不一致时也要把三语的问题一起报出来 ——
    #   （踩过：`if not errors` 一挡，真正的原因被"副本不一致"盖住，
    #    自测看到的是"红了，但理由不对"。）
    base = LANGS[0]
    if all(n in clauses for n in LANGS):
        for name in LANGS[1:]:
            if clauses[name] != clauses[base]:
                only_a = sorted(set(clauses[base]) - set(clauses[name]))
                only_b = sorted(set(clauses[name]) - set(clauses[base]))
                errors.append('条款号不一致：%s 有而 %s 没有 %s；反之 %s —— '
                              '切一次语言就是两份不同的协议'
                              % (base, name, only_a or '无', only_b or '无'))
            if chapters[name] != chapters[base]:
                errors.append('章节数不一致：%s=%d，%s=%d'
                              % (base, chapters[base], name, chapters[name]))
            if versions[name] != versions[base]:
                errors.append('版本号不一致：%s=%s，%s=%s —— 三语必须同版本'
                              % (base, versions[base] or '?', name,
                                 versions[name] or '?'))
        if not versions[base]:
            errors.append('找不到版本号行（应为「版本：Vx.y」/「Version: Vx.y」）')
        # 关键条款必须在（防止"改着改着把整节删掉"）
        must_have = ['3.5', '3.6', '5.3', '7.6', '7.7']
        for name in LANGS:
            for k in must_have:
                if k not in clauses.get(name, []):
                    errors.append('%s 缺条款 %s（iGate 责任 / 未成年人 / 第三方功能 / '
                                  '生命守护 / 第三方数据免责）' % (name, k))
        # 这三件事的关键词至少得出现
        words = {
            'terms_zh.txt': ['未成年人', '第三方', '生命守护'],
            'terms_zh_TW.txt': ['未成年人', '第三方', '生命守護'],
            'terms_en.txt': ['Minors', 'third-party', 'medical devices'],
        }
        for name, ws in words.items():
            text = read(os.path.join(APP_DIR, name))
            for w in ws:
                if w not in text:
                    errors.append('%s 里找不到关键字 `%s` —— 该小节可能被误删' % (name, w))

    # ── 版本号的另外几处：Dart 常量 + 官网三个页面的 meta ──
    # 它们与正文是**同一个事实**写在不同地方；不管，就一定会漂
    # （V1.0→V1.1 这次就是正文改了、另外 5 处全停在旧版本）。
    if all(versions.get(n) for n in LANGS) and versions.get(LANGS[0]):
        want = versions[LANGS[0]]
        tv = os.path.join(ROOT, 'lib', 'terms_version.dart')
        if not os.path.exists(tv):
            errors.append('缺 lib/terms_version.dart —— App 里显示的协议版本应有单一来源')
        else:
            m = re.search(r"kTermsVersion\s*=\s*'([^']+)'", read(tv))
            got = m.group(1) if m else ''
            if got != want:
                errors.append('lib/terms_version.dart 的 kTermsVersion=%s，而协议正文是 %s '
                              '—— 两处必须同版本' % (got or '?', want))
        for rel in ('docs/terms.html', 'docs/en/terms.html', 'docs/zh-TW/terms.html'):
            fp = os.path.join(ROOT, *rel.split('/'))
            if not os.path.exists(fp):
                errors.append('缺 %s（官网的协议页）' % rel)
                continue
            if want not in read(fp):
                errors.append('%s 的 meta 里没有 %s —— 页面描述会停在旧版本' % (rel, want))

    if errors:
        print('用户协议检查失败：')
        for e in errors:
            print('  -', e)
        return 1
    print('用户协议 ok（三语 %d 条条款、版本 %s；两处副本逐字节一致）'
          % (len(clauses[LANGS[0]]), versions[LANGS[0]]))
    return 0


if __name__ == '__main__':
    sys.exit(main())
