#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""桌面三平台的插件注册表检查：pubspec 里的原生插件必须真的被注册。

为什么要有这条：`windows/flutter/generated_plugin_registrant.cc`、
`windows/flutter/generated_plugins.cmake`、`linux/flutter/generated_*`、
`macos/Flutter/GeneratedPluginRegistrant.swift` 这几个文件在 flutter_tools 里
**只有 `flutter create` 会写**（`injectPlugins` 的唯一调用点是 create）：
`flutter pub get` 与 `flutter build windows|linux|macos` 都不重新生成它们。

于是新加一个原生插件之后：分析照样过、CI 照样绿、装出来的程序里那个插件根本
没注册 —— 方法通道调用抛 MissingPluginException，被功能自己的 try/catch 咽掉，
表现成「这个功能一点反应都没有」。2.1.33 的系统托盘就是这么没的。

判据取 `.flutter-plugins-dependencies`（`flutter pub get` 的产物，CI 里跑完
pub get 就在）：它把每个插件在每个平台是原生（`native_build: true`）还是纯 Dart
区分得很清楚，这里只查原生那些。文件不存在时直接跳过（沙箱里没有 pub get）。
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEPS = os.path.join(ROOT, '.flutter-plugins-dependencies')

# 每个平台：注册表里必须出现插件名字的那几个文件
FILES = {
    'windows': [
        'windows/flutter/generated_plugin_registrant.cc',
        'windows/flutter/generated_plugins.cmake',
    ],
    'linux': [
        'linux/flutter/generated_plugin_registrant.cc',
        'linux/flutter/generated_plugins.cmake',
    ],
    'macos': [
        'macos/Flutter/GeneratedPluginRegistrant.swift',
    ],
}


def main():
    if not os.path.exists(DEPS):
        print('插件注册表检查跳过（没有 .flutter-plugins-dependencies，先跑 flutter pub get）')
        return 0

    with open(DEPS, encoding='utf-8') as f:
        data = json.load(f)
    plugins = data.get('plugins', {})

    bad = []
    counted = 0
    for platform, files in FILES.items():
        native = [p['name'] for p in plugins.get(platform, []) if p.get('native_build')]
        texts = {}
        for rel in files:
            path = os.path.join(ROOT, rel)
            if not os.path.exists(path):
                bad.append('%s：%s 不存在' % (platform, rel))
                continue
            with open(path, encoding='utf-8') as f:
                texts[rel] = f.read()
        for name in sorted(native):
            counted += 1
            for rel, text in texts.items():
                if name not in text:
                    bad.append('%s：%s 里没有 %s（`flutter create` 才会重写这几个文件）'
                               % (platform, rel, name))

    if bad:
        print('插件注册表检查失败：')
        for line in bad:
            print('  ' + line)
        return 1
    print('插件注册表检查 ok（%d 项：插件 × 文件 全在册）' % counted)
    return 0


if __name__ == '__main__':
    sys.exit(main())
