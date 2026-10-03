#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把「arb 里有、生成文件里还没有」的键**外科式**补进 gen-l10n 的产物。

## 为什么需要它

仓库里 committed 的 `lib/l10n/app_localizations*.dart` 是"未生成视角"：本机 SDK 的
gen-l10n 风格与它不同，直接 `flutter gen-l10n` 会产出上万行与本次无关的重排噪音。
所以流程是：

  1. 先改 `lib/l10n/app_*.arb`（例如 `tool/add_*_l10n.py`）；
  2. 跑本脚本，把新键按**仓库既有的排版**补进 6 个生成文件；
  3. `python3 tool/check_l10n_sync.py` 核对（模板键数、代码用到的键、生成物成员）。

⚠ 本地跑过 `flutter test` / `flutter gen-l10n` 之后，生成文件会被"重新生成"（顺序全变）。
要提交前先把它们还原成 HEAD 版再跑本脚本，否则会带进整文件重排的噪音。
（`flutter test` 之前记得先备份；见提交信息里的做法。）

幂等：已经在生成文件里的键会跳过。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L10N = os.path.join(ROOT, 'lib', 'l10n')

# 类名 → arb 语言代码
CLASS2LANG = {
    'AppLocalizationsZh': 'zh',
    'AppLocalizationsZhTw': 'zh_TW',
    'AppLocalizationsEn': 'en',
    'AppLocalizationsEs': 'es',
    'AppLocalizationsId': 'id',
    'AppLocalizationsJa': 'ja',
}

# 生成文件的插入锚点：插在它对应成员的后面（与既有排版一致）
ANCHOR = 'dataSourceSwitchHint'

# 需要补的键：这些前缀是本仓库历次脚本陆续加的（都在 arb 末尾附近）
KEYS_PREFIX = ('donate', 'box', 'bl', 'dataNotice', 'icomLan', 'codeContribution',
               'startFrom', 'heat')


def read(p):
    return io.open(p, encoding='utf-8', newline='').read()


def write(p, s):
    io.open(p, 'w', encoding='utf-8', newline='').write(s)


def esc(v):
    """生成文件里是单引号字符串，转义反斜杠、单引号与 $。"""
    return v.replace('\\', '\\\\').replace("'", r"\'").replace('$', r'\$')


def main():
    zh = json.loads(read(os.path.join(L10N, 'app_zh.arb')))
    keys = [k for k in zh if k.startswith(KEYS_PREFIX)]

    # ① 抽象类：补声明
    p = os.path.join(L10N, 'app_localizations.dart')
    s = read(p)
    nl = '\r\n' if '\r\n' in s else '\n'
    missing = [k for k in keys if ('  String get %s;' % k) not in s]
    if missing:
        a = '  String get %s;' % ANCHOR
        assert s.count(a) == 1, '抽象类里找不到唯一锚点 %s' % ANCHOR
        add = []
        for k in missing:
            add += ['', '  /// No description provided for @%s.' % k, '  ///',
                    '  /// In zh, this message translates to:',
                    "  /// **'%s'**" % zh[k].replace('\\', '\\\\').replace('$', r'\$'),
                    '  String get %s;' % k]
        write(p, s.replace(a, a + nl.join(add), 1))
    print('%-30s +%d' % ('app_localizations.dart', len(missing)))

    # ② 六个具体类：按类分段、**从后往前**处理（插入后行号不会失效）
    for fname in ('app_localizations_zh.dart', 'app_localizations_en.dart',
                  'app_localizations_es.dart', 'app_localizations_id.dart',
                  'app_localizations_ja.dart'):
        p = os.path.join(L10N, fname)
        s = read(p)
        nl = '\r\n' if '\r\n' in s else '\n'
        lines = s.split(nl)
        heads = [i for i, l in enumerate(lines) if l.startswith('class AppLocalizations')]
        heads.append(len(lines))
        total = 0
        for a, b in reversed(list(zip(heads, heads[1:]))):
            seg = lines[a:b]
            cname = seg[0].split()[1]
            lang = CLASS2LANG.get(cname, '')
            if not lang:
                continue
            tr = json.loads(read(os.path.join(L10N, 'app_%s.arb' % lang)))
            body = nl.join(seg)
            miss = [k for k in keys if ('String get %s ' % k) not in body]
            if not miss:
                continue
            ai = next(i for i, l in enumerate(seg)
                      if l.strip().startswith('String get %s =>' % ANCHOR))
            while not seg[ai].rstrip().endswith(';'):
                ai += 1
            add = []
            for k in miss:
                add += ['', '  @override',
                        "  String get %s => '%s';" % (k, esc(tr[k]))]
            seg[ai + 1:ai + 1] = add
            lines[a:b] = seg
            total += len(miss)
        write(p, nl.join(lines))
        print('%-30s +%d' % (fname, total))


if __name__ == '__main__':
    main()
