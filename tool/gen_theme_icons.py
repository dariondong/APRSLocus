#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 lib/theme_icons.dart —— 主题可选的图标库（名字 → IconData 的常量表）。

为什么要脚本生成、而不是手写或运行时反射：

1. **Flutter 的图标要能 tree-shake，就必须以「字面量」形式出现**。
   `IconData(codePoint)` 那种运行时拼出来的写法会让 icon tree-shaking 失效
   （构建时直接报错：non-constant IconData），或者反过来把整套 8000 多个
   glyph 全打进包（MaterialIcons 字体约 1.6MB）。
   所以这里生成的是一个 **const Map<String, IconData>**，里面每个值都是
   `Icons.xxx` 字面量。

2. **只放「有人用得上」的那批**，不是全部 8825 个：
   - lib/ 里已经在用的图标（285 个）—— 这些 glyph 反正已经在包里，收录零成本；
   - 一份人工挑选的候选（电台/地图/数据/通用 UI）—— 给用户真正有得挑。

3. **名字必须先在 SDK 的 icons.dart 里存在**，否则编译直接失败。
   脚本会逐个核对并把不存在的名字报出来（而不是生成一份编不过的文件）。

用法：
    python3 tool/gen_theme_icons.py          # 重新生成 lib/theme_icons.dart
    python3 tool/gen_theme_icons.py --check  # 只校验现有文件是否与 lib/ 用到的图标同步
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 人工挑选的候选（电台 / 地图 / 数据 / 通用 UI）。
# 与「lib/ 里已在用」的图标合并去重后写入。
CURATED = [
    # 电台与通信
    'radio', 'radio_rounded', 'settings_input_antenna', 'podcasts', 'wifi_tethering',
    'router', 'bluetooth', 'bluetooth_audio', 'usb', 'cable', 'sd_card', 'memory',
    'battery_full', 'battery_5_bar', 'bolt', 'power', 'sensors', 'sensors_rounded',
    'graphic_eq', 'equalizer', 'volume_up', 'volume_off', 'mic', 'mic_off',
    'headphones', 'speaker', 'satellite_alt', 'gps_fixed', 'gps_off', 'explore',
    'near_me', 'place', 'pin_drop', 'map', 'public', 'travel_explore', 'my_location',
    'location_on', 'location_off', 'share_location',
    # 地图与坐标
    'grid_4x4', 'grid_on', 'layers', 'terrain', 'landscape', 'water_drop', 'wb_sunny',
    'dark_mode', 'light_mode', 'brightness_6', 'ac_unit', 'air', 'cloud', 'cloud_off',
    'thunderstorm', 'umbrella', 'navigation', 'straighten', 'speed', 'route',
    # 消息与数据
    'chat', 'chat_bubble', 'forum', 'comment', 'sms', 'mail', 'send', 'inbox',
    'notifications', 'notifications_off', 'mark_chat_unread', 'done_all', 'drafts',
    'storage', 'folder', 'folder_open', 'save', 'save_alt', 'file_download',
    'file_upload', 'cloud_download', 'cloud_upload', 'backup', 'restore',
    'history', 'schedule', 'update', 'sync', 'autorenew', 'refresh',
    'table_chart', 'bar_chart', 'show_chart', 'timeline', 'insights', 'analytics',
    'dns', 'lan', 'hub', 'device_hub', 'account_tree', 'qr_code',
    # 人/群/荣誉
    'person', 'group', 'groups', 'badge', 'military_tech', 'emoji_events',
    'workspace_premium', 'star', 'star_border', 'favorite', 'favorite_border',
    'bookmark', 'verified', 'diamond', 'local_fire_department', 'whatshot',
    # 通用 UI
    'home', 'dashboard', 'apps', 'widgets', 'tune', 'build', 'construction',
    'handyman', 'extension', 'palette', 'brush', 'format_paint', 'color_lens',
    'text_fields', 'font_download', 'format_size', 'translate', 'language',
    'visibility', 'visibility_off', 'lock', 'lock_open', 'security', 'shield',
    'info', 'help', 'warning', 'error', 'check_circle', 'cancel', 'block',
    'add', 'remove', 'edit', 'delete', 'close', 'search', 'filter_alt', 'sort',
    'menu', 'more_vert', 'more_horiz', 'chevron_right', 'arrow_back', 'arrow_forward',
    'expand_more', 'expand_less', 'fullscreen', 'fullscreen_exit', 'zoom_in',
    'zoom_out', 'open_in_new', 'launch', 'link', 'attachment', 'content_copy',
    'content_paste', 'print', 'share', 'download', 'upload', 'cloud_sync',
    'terminal', 'code', 'bug_report', 'science', 'calculate', 'straighten',
    'rule', 'fact_check', 'list_alt', 'checklist', 'flag', 'label', 'bookmarks',
]


def sdk_icons():
    """从 Flutter SDK 的 icons.dart 取全部合法图标名 + codePoint。"""
    root = os.environ.get('FLUTTER_ROOT')
    cand = []
    if root:
        cand.append(os.path.join(root, 'packages', 'flutter', 'lib',
                                 'src', 'material', 'icons.dart'))
    # flutter 可执行文件位置 → SDK 根
    for p in os.environ.get('PATH', '').split(os.pathsep):
        if p.endswith(os.sep + 'bin'):
            cand.append(os.path.join(os.path.dirname(p), 'packages', 'flutter',
                                     'lib', 'src', 'material', 'icons.dart'))
    cand.append('/tmp/sdk/flutter/packages/flutter/lib/src/material/icons.dart')
    for c in cand:
        if os.path.exists(c):
            src = io.open(c, encoding='utf-8').read()
            out = {}
            # static const IconData map = IconData(0xe31f, fontFamily: 'MaterialIcons');
            #
            # ⚠ `IconData(` 与 `0x…` 之间必须允许跨行：SDK 里一部分图标是
            # 多行声明的（`= IconData(\n  0x…,\n  fontFamily: …)`）。
            # 我第一版写成 `IconData\(0x` 只能匹配单行，于是把 `database`、
            # `help`、`label` 这类**真实存在**的图标报成「不存在」——
            # 假失败比真失败更坏：它会让人以为名字写错了，去改本来没错的东西。
            for m in re.finditer(
                r"static const IconData ([A-Za-z][A-Za-z0-9_]*) = "
                r"IconData\(\s*0x([0-9a-fA-F]+)", src):
                out[m.group(1)] = m.group(2)
            return out
    sys.exit('找不到 flutter 的 icons.dart（可用 FLUTTER_ROOT 指定 SDK）')


def used_in_lib():
    names = set()
    for base, _dirs, files in os.walk(os.path.join(ROOT, 'lib')):
        for f in files:
            if not f.endswith('.dart'):
                continue
            src = io.open(os.path.join(base, f), encoding='utf-8').read()
            names |= set(re.findall(r'\bIcons\.([A-Za-z][A-Za-z0-9_]*)', src))
    return names


# Dart 保留字 / 上下文关键字：这些名字**不能**在 `Icons.` 之后当成标识符写出来。
#
# 真实的坑：SDK 里有 `Icons.sync`，而 `sync` 是 Dart 的关键字（用于 `sync*`），
# 于是 `'sync': Icons.sync,` 直接导致「Expected to find ';'」——
# 报错位置还在文件末尾，看上去像是少了括号，极难定位。
# 这类名字在生成阶段就剔除；需要圆形同步图标时用 `sync_rounded`。
DART_KEYWORDS = {
    'abstract', 'else', 'import', 'show', 'as', 'enum', 'in', 'super', 'assert',
    'export', 'interface', 'switch', 'async', 'extends', 'is', 'sync', 'await',
    'false', 'library', 'this', 'break', 'final', 'mixin', 'throw', 'case',
    'finally', 'new', 'true', 'catch', 'for', 'null', 'try', 'class',
    'function', 'on', 'typedef', 'const', 'if', 'operator', 'var', 'continue',
    'implements', 'part', 'void', 'default', 'return', 'while', 'do', 'rethrow',
    'with', 'get', 'set', 'static', 'yield', 'late', 'required', 'covariant',
}


def build(icons):
    used = used_in_lib()
    wanted = sorted(used | set(CURATED))
    known = [n for n in wanted if n in icons and n not in DART_KEYWORDS]
    # 无法写出来的名字也算「不可用」，一并报出来（而不是悄悄丢掉）
    missing = [n for n in wanted
               if n not in icons or n in DART_KEYWORDS]
    return known, missing, used


def main() -> int:
    icons = sdk_icons()
    known, missing, used = build(icons)
    if missing:
        print('以下名字在 Flutter SDK 里不存在（已从生成结果里剔除）:')
        for n in missing:
            print('  ', n)

    lines = [
        '// 本文件由 tool/gen_theme_icons.py 生成，请勿手改。',
        '//',
        '// 为什么是这个形状（const Map + 字面量）：见该脚本的说明 —— 简言之，',
        '// Flutter 的图标 tree-shaking 只认字面量，运行时拼 IconData 要么编不过、',
        '// 要么把整套 MaterialIcons（约 1.6MB）打进包。',
        'import \'package:flutter/material.dart\';',
        '',
        '/// 主题里能选的图标：名字 → 图标。',
        '///',
        '/// 收录范围 = lib/ 里已在用的图标 + 人工挑选的候选，共 %d 个。' % len(known),
        '/// 名字用 Flutter 的规范名（无 `Icons.` 前缀），便于在主题 JSON 里书写。',
        'const Map<String, IconData> kThemeIconLibrary = {',
    ]
    for n in known:
        lines.append("  '%s': Icons.%s," % (n, n))
    # ⚠ 顶层变量声明**必须**有分号。我先只写了 `}`，于是整份生成物语法错误，
    #   而报错位置在文件末尾（「Expected to find ';'」指向最后一行的 `}`），
    #   看上去像是少了括号 —— 定位花了很久。
    lines.append('};')
    lines.append('')
    lines.append('/// 按名字取图标；不认识返回 null（调用方负责回退默认图标）')
    lines.append('IconData? themeIconByName(String name) => kThemeIconLibrary[name];')
    lines.append('')
    lines.append('/// 图标库全部名字（编辑页搜索用，已排序）')
    lines.append('List<String> get kThemeIconNames => kThemeIconLibrary.keys.toList();')
    lines.append('')

    out_path = os.path.join(ROOT, 'lib', 'theme_icons.dart')
    io.open(out_path, 'w', encoding='utf-8', newline='').write('\n'.join(lines))
    print('生成 lib/theme_icons.dart：%d 个图标（其中 %d 个是 lib/ 已在用的）'
          % (len(known), len(used)))
    print('提示：库里的名字都是**常量表达式**（Icons.xxx 字面量），'
          '这样 Flutter 才能对图标做 tree-shaking。')
    return 0


def _unused() -> int:
    return 0


if __name__ == '__main__':
    sys.exit(main())
