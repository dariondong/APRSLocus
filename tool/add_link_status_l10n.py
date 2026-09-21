#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为「连接状态提示」补 l10n 键（6 语言）。

背景：2.0 的那颗状态胶囊原来显示「37 在线」—— 那是**台站数**，不是连接状态，
而台站数在地图信息条里已经显示了。用户反馈「连接的提示很不明确」。
改法是显示「来源 · 状态」（APRS-IS · 未连接 / TNC · 已连接 / PKWDWPL · 只收不发）。

需要两个新键：
* `linkNotConnected`：通用的「未连接」。刻意**不**复用 `notConnectedAprsServer`
  （那句写死了 APRS-IS，而来源可能是 TNC / 音频）；与来源名拼起来读
  「TNC · 未连接」才准确。
* `linkTapForSettings`：告诉用户这颗胶囊可以点（原来没有任何暗示可点）。

写入约定与 tool/add_ui_layout_l10n.py 一致：幂等、追加到 ARB 末尾，随后 gen-l10n。
"""
import io
import json
import os
import re
import sys

KEYS = {
    'linkNotConnected': ('未连接', '未連線', 'Not connected', '未接続',
                         'Sin conexión', 'Tidak terhubung'),
    'linkTapForSettings': ('点一下查看连接设置', '點一下查看連線設定',
                           'Tap to open connection settings',
                           'タップして接続設定を開く',
                           'Toca para abrir los ajustes de conexión',
                           'Ketuk untuk membuka pengaturan koneksi'),
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    arb_dir = os.path.join(root, 'lib', 'l10n')
    total = 0
    for lg in LANGS:
        p = os.path.join(arb_dir, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8').read()
        add = []
        for key, vals in KEYS.items():
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
        print(f'{lg}: 追加 {len(add)} 行')
    print(f'\n共写入 {total} 行')
    return 0


if __name__ == '__main__':
    sys.exit(main())
