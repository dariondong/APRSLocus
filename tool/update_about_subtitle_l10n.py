#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：把「关于页」副标题里的「本机 / local」限定词去掉。

背景：`aboutSubtitle` 原本写作「本机 APRS 客户端 · 定位与地图」
（en: Local APRS client …）。「本机」会让人误以为这个客户端只在
本机/桌面跑，实际上它就是个 APRS 客户端，并没有「本机」这一层含义。
六种语言一起去掉这个限定词，保持各语言语义一致（只改中文会让
en/es 仍显示 Local/lokal，问题依旧）。

同时更新 arb（真源）与提交进 git 的 gen-l10n 产物，写完由
tool/check_l10n_sync.py 校验一一对应。
"""
import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L10N = os.path.join(ROOT, 'lib', 'l10n')

# 语言 → (旧文案, 新文案)
CHANGES = {
    'zh': (
        '本机 APRS 客户端 · 定位与地图',
        'APRS 客户端 · 定位与地图',
    ),
    'zh_TW': (
        '本機 APRS 用戶端 · 定位與地圖',
        'APRS 用戶端 · 定位與地圖',
    ),
    'en': (
        'Local APRS client · tracking & map',
        'APRS client · tracking & map',
    ),
    'ja': (
        '本機 APRS クライアント・位置情報と地図',
        'APRS クライアント・位置情報と地図',
    ),
    'es': (
        'Cliente APRS local · seguimiento y mapa',
        'Cliente APRS · seguimiento y mapa',
    ),
    'id': (
        'Klien APRS lokal · pelacakan & peta',
        'Klien APRS · pelacakan & peta',
    ),
}

# arb 文件名后缀（zh 是模板）
ARB = {'zh': 'app_zh.arb', 'zh_TW': 'app_zh_TW.arb', 'en': 'app_en.arb',
       'ja': 'app_ja.arb', 'es': 'app_es.arb', 'id': 'app_id.arb'}
# 生成类所在文件
GEN = {'zh': 'app_localizations_zh.dart', 'zh_TW': 'app_localizations_zh.dart',
       'en': 'app_localizations_en.dart', 'ja': 'app_localizations_ja.dart',
       'es': 'app_localizations_es.dart', 'id': 'app_localizations_id.dart'}


def replace_in(path, old, new, occurrences=1):
    src = io.open(path, encoding='utf-8').read()
    if old not in src:
        raise SystemExit(f'找不到旧文案：{os.path.basename(path)} :: {old!r}')
    n = src.count(old)
    src = src.replace(old, new)
    io.open(path, 'w', encoding='utf-8').write(src)
    return n


def main():
    for lg, (old, new) in CHANGES.items():
        # arb：JSON 字符串里的文案
        replace_in(os.path.join(L10N, ARB[lg]), old, new)
        # 生成产物：String get aboutSubtitle => '…';
        replace_in(os.path.join(L10N, GEN[lg]), old, new)
        print(f'{lg:6} {old}  →  {new}')
    print('\n✅ aboutSubtitle 已更新（arb + 生成产物）；请跑 tool/check_l10n_sync.py 校验')


if __name__ == '__main__':
    main()
