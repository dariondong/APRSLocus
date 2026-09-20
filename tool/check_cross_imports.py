#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""静态检查：用了某个「跨层名字」，就必须导入定义它的那个文件。

## 为什么需要这条检查

同一个坑撞过两次，症状完全相同：

* `state.dart` 用 `C` / `UiMaterial` 却没 `import 'theme.dart'`；
* 五个页面用 `MaterialSurface` 却没 `import 'material.dart'`。

两者都只在 **analyze / 编译**时报 `undefined_method` / `undefined_class`，
而本机唯一的语法检查（`dart format --output=none`）只会说「能解析」——
本机又跑不了 analyze（会把同机服务压垮，用户明确要求）。于是「漏一个 import」
＝白等一轮 CI。这条检查把它搬到本地。

## 判据

Dart 不会因为 A 导入 B、B 导入 C 就让 A 看见 C（没有隐式再导出）。
所以「文件里出现了某名字」⇒「该文件必须直接导入定义它的文件」。

## 我第一版写成了「一屏假失败」，记在这里免得再犯

第一版拿 `\\bC\\b` / `\\bS\\b` / `\\bts\\b` 这样的**裸名字**去搜，整个仓库都在报红：
短名字会命中字符串里的正文、译文、单字母变量。**假失败比真失败更坏** ——
修它的人通常会把规则放宽或删掉说明。所以改成：

1. 先剔掉**字符串字面量**与**行注释**（名字只可能是代码在用，不是文案在用）；
2. 按**用法形状**匹配（`C.` / `ts(` / `S.of(` / `ThemeController.` …），而非裸名字；
3. 跳过生成文件 `lib/l10n/`（里面全是译文，短名字必然当正文出现）。

表格里每行在运行时都会**回头验证**「该名字确实定义在那个文件里」：验不过就报
表格过期 —— 否则表格自己腐烂后会给出错误结论，比不检查更坏。

用法：python3 tool/check_cross_imports.py
退出码 0 = 全部导入正确；1 = 有漏导入（并列出文件与名字）。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, 'lib')

# 名字 → (定义它的文件, 用法形状)。形状见模块说明第 2 条。
NAMES = {
    'C': ('theme.dart', r'\bC\.'),
    'ts': ('theme.dart', r'\bts\s*\('),
    'T': ('theme.dart', r'\bT\.[a-zA-Z]'),
    'softShadow': ('theme.dart', r'\bsoftShadow\s*\('),
    'cardDeco': ('theme.dart', r'\bcardDeco\s*\('),
    'fieldDeco': ('theme.dart', r'\bfieldDeco\s*\('),
    'sheetDeco': ('theme.dart', r'\bsheetDeco\s*\('),
    'UiMaterial': ('theme.dart', r'\bUiMaterial\b'),
    'UiLayout': ('theme.dart', r'\bUiLayout\b'),
    'uiMaterialOf': ('theme.dart', r'\buiMaterialOf\s*\('),
    'uiMaterialName': ('theme.dart', r'\buiMaterialName\s*\('),
    'uiLayoutOf': ('theme.dart', r'\buiLayoutOf\s*\('),
    'uiLayoutName': ('theme.dart', r'\buiLayoutName\s*\('),
    'MaterialSurface': ('material.dart', r'\bMaterialSurface\s*\('),
    'MaterialAppBar': ('material.dart', r'\bMaterialAppBar\s*\('),
    'surfaceTint': ('material.dart', r'\bsurfaceTint\s*\('),
    'S': ('widgets.dart', r'\bS\.of\s*\('),
    'LabelValueRow': ('widgets.dart', r'\bLabelValueRow\s*\('),
    'SoftCard': ('widgets.dart', r'\bSoftCard\s*\('),
    'SectionCard': ('widgets.dart', r'\bSectionCard\s*\('),
    'KV': ('widgets.dart', r'\bKV\s*\('),
    'RoundIconBtn': ('widgets.dart', r'\bRoundIconBtn\s*\('),
    'localizedLocationStatus': ('widgets.dart', r'\blocalizedLocationStatus\s*\('),
    'SettingsNavRow': ('settings_widgets.dart', r'\bSettingsNavRow\s*\('),
    'SettingsRow2': ('settings_widgets.dart', r'\bSettingsRow2\s*\('),
    'SettingsSwitch': ('settings_widgets.dart', r'\bSettingsSwitch\s*\('),
    'SettingsHint': ('settings_widgets.dart', r'\bSettingsHint\s*\('),
    'SettingsSectionCard': ('settings_widgets.dart', r'\bSettingsSectionCard\s*\('),
    'SettingsPageShell': ('settings_widgets.dart', r'\bSettingsPageShell\s*\('),
    'ThemeController': ('theme_store.dart', r'\bThemeController\.'),
    'Tx': ('theme_text.dart', r'\bTx\.of\s*\('),
    'themeIconByName': ('theme_icons.dart', r'\bthemeIconByName\s*\('),
    'ImmersiveMapPage': ('immersive_page.dart', r'\bImmersiveMapPage\s*\('),
    'ConnectionSettingsPage': ('settings_pages.dart', r'\bConnectionSettingsPage\s*\('),
    'DeviceSettingsPage': ('settings_pages.dart', r'\bDeviceSettingsPage\s*\('),
    'AppState': ('state.dart', r'\bAppState\b'),
    'BeaconPhase': ('state.dart', r'\bBeaconPhase\.'),
    'Station': ('models.dart', r'\bStation\b'),
}

# 生成文件不参与检查（详见模块说明第 3 条）
SKIP_PATHS = ('lib/l10n/',)


def strip_code(text):
    """剔掉字符串字面量与行注释，只留代码（见模块说明第 1 条）。"""
    out = []
    for line in text.split('\n'):
        if line.strip().startswith('//'):
            continue
        line = re.sub(r"'(?:\\.|[^'\\])*'", "''", line)
        line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
        out.append(line)
    return '\n'.join(out)


def defined_in(path, name):
    """该文件里是否**定义**了这个名字（用来验证表格没过期）"""
    text = io.open(path, encoding='utf-8').read()
    pats = [
        r'^\s*(?:abstract\s+)?class\s+%s\b',
        r'^\s*enum\s+%s\b',
        r'^\s*typedef\s+%s\b',
        r'^\s*[A-Za-z_][A-Za-z0-9_<>?,\s]*%s\s*\(',
        r'^\s*(?:static\s+)?(?:final\s+)?[A-Za-z_][A-Za-z0-9_<>]*\s+%s\s*[=;]',
    ]
    return any(re.search(p % re.escape(name), text, re.M) for p in pats)


def main() -> int:
    # ① 先验证表格自身，避免表格腐烂后给出错误结论
    stale = []
    for name, (rel, _pat) in NAMES.items():
        path = os.path.join(LIB, rel)
        if not os.path.exists(path):
            stale.append((name, rel, '文件不存在'))
        elif not defined_in(path, name):
            stale.append((name, rel, '该文件里找不到定义'))
    if stale:
        print('检查表已过期（表里的名字与代码对不上）——请先修表，'
              '否则本检查的结论不可信：')
        for name, rel, why in stale:
            print('  STALE  %-24s → lib/%-22s %s' % (name, rel, why))
        return 1

    # ② 逐个文件查漏导入
    problems = []
    for base, _dirs, files in os.walk(LIB):
        for fn in sorted(files):
            if not fn.endswith('.dart'):
                continue
            path = os.path.join(base, fn)
            rel = os.path.relpath(path, ROOT).replace(os.sep, '/')
            if rel.startswith(SKIP_PATHS):
                continue
            text = io.open(path, encoding='utf-8').read()
            code = strip_code(text)
            for name, (rel_def, pat) in NAMES.items():
                # 定义文件自己用它，不需要导入自己
                if rel == 'lib/' + rel_def:
                    continue
                if not re.search(pat, code):
                    continue
                # 也要认 `import 'x.dart' show S;`（show/hide/as 组合子）：
                # theme_text.dart 就是 `import 'widgets.dart' show S;`，
                # 只认裸 import 会把它误报成漏导入 —— 这是本检查遇到的最后一个
                # 假失败，记在这儿免得下次又把组合子形式当漏导入。
                if re.search(
                    r"import '%s'(?:\s+(?:show|hide|as)\s+[^;]+)?;"
                    % re.escape(rel_def),
                    text,
                ):
                    continue
                problems.append((rel, name, rel_def))

    if not problems:
        print('cross imports ok: 跨层名字都用到了定义它们的文件，且已导入')
        return 0

    print('以下文件用了跨层名字，却没导入定义它的文件 —— analyze/编译会报 '
          'undefined（本地 dart format 看不出来）：')
    for rel, name, rel_def in problems:
        print("  MISSING  %-30s 用了 %-20s 需 import '%s'" % (rel, name, rel_def))
    return 1


if __name__ == '__main__':
    sys.exit(main())
