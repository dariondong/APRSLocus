#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""帧成本检查：面板展开/拖动时不产出多余帧，也不把磨砂弄坏。

为什么需要它：这几条优化**全都不会让编译失败、也不会让测试失败** ——
它们只是「不做某件事」。一旦有人在后续改动里顺手把某一行还原（或者把地图
换成 `Offstage`「反正看不见」），面板就会悄悄回到一展开就卡，
而且**只有真机上才看得出来**。本机跑不了真机、跑不了 analyze，所以钉在这里。

守的是这几条（每条都对应一次真实的卡顿原因）：

  1. 地图在面板开着时**冻结**（`MapPage.frozen`）：停脉冲动画、数据变化不重建
     标记 —— 但**继续画**。因为磨砂的 `BackdropFilter` 背后必须有内容，
     换成 `Offstage`/`Visibility` 就是「把磨砂弄坏」而不是优化。
  2. 冻结要**双向**：视图（拖动/缩放/选中）变化必须跟随，否则拖地图时标记僵住。
  3. 解冻要**补一次重建**，否则会短暂显示冻结前的旧标记。
  4. 动画期不做离屏模糊（`MaterialSurface(blurWhen:)`），但**动画结束要恢复**
     （少了状态监听就会一直没磨砂，用户以为材质坏了）。
  5. 传给地图的 `bottomInset` 在动画期必须是**吸附目标值**：逐帧变的话，
     地图每帧重排重绘，正好把第 1 条抵消掉。
  6. 面板内容要做**实例缓存**：否则动画每帧重建四个页面。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(rel):
    return io.open(os.path.join(ROOT, rel), encoding='utf-8').read()


def main() -> int:
    errors = []

    def need(rel, needle, why):
        if needle not in read(rel):
            errors.append(f'{rel} 里找不到 `{needle}` —— {why}')

    def forbid(rel, needle, why):
        if needle in read(rel):
            errors.append(f'{rel} 里出现了 `{needle}` —— {why}')

    shell = read('lib/shell2.dart')
    map_page = read('lib/map_page.dart')
    material = read('lib/material.dart')

    # ① MapPage 必须有 frozen，且冻结分支真的停掉脉冲
    need('lib/map_page.dart', 'final bool frozen;',
         'MapPage 没有 frozen 参数（面板开着时地图会继续产出帧）')
    need('lib/map_page.dart', 'if (widget.frozen) {',
         'frozen 没有在 build 里生效')
    need('lib/map_page.dart', '_pulse.stop();',
         '冻结时没有停脉冲动画 —— 那是地图这边唯一的每帧重绘来源')

    # ② 冻结必须仍然跟随视图变化（否则拖地图时标记僵在原地）
    need('lib/map_page.dart', 'viewHash == _markerViewHash',
         '冻结期间不再跟随视图变化 —— 拖地图会看到标记不动')

    # ③ 解冻补一次重建
    need('lib/map_page.dart', 'if (old.frozen && !widget.frozen)',
         '解冻时没有补一次标记重建（会短暂显示冻结前的旧标记）')

    # ④ 磨砂背后必须有内容：不许把地图隐藏掉
    for bad in ('Offstage(', 'Visibility(', 'SizedBox.shrink()'):
        if bad in shell and 'MapPage' in shell:
            # 只拦「出现在地图附近」的情况：粗略但够用 —— 这两处都不该有。
            idx = shell.find('MapPage(')
            seg = shell[max(0, idx - 400):idx + 400]
            if bad in seg:
                errors.append(f'lib/shell2.dart 在地图附近用了 `{bad}` —— '
                              f'磨砂背后必须留着地图（隐藏地图＝把磨砂弄坏）')

    # ⑤ 两处（竖屏/横屏）都要传 frozen
    if shell.count('frozen:') < 2:
        errors.append('lib/shell2.dart 只在一处传了 frozen —— 竖屏与横屏都要传')

    # ⑥ 动画期不做模糊，但必须有状态监听恢复
    need('lib/material.dart', 'final bool blurWhen;',
         'MaterialSurface 没有 blurWhen（动画期会每帧做整屏离屏模糊）')
    need('lib/material.dart', 'if (!blurWhen) return child;',
         'blurWhen 没有在 build 里生效')
    if shell.count('blurWhen: !_paneAnimating') < 2:
        errors.append('lib/shell2.dart 里面板壳没有（或只有一处）用 '
                      '`blurWhen: !_paneAnimating` —— 动画期仍会每帧离屏模糊')
    need('lib/shell2.dart', 'addStatusListener',
         '没有状态监听：动画结束后不会恢复磨砂（面板会一直没磨砂）')

    # ⑦ inset 在动画期必须是吸附目标值
    need('lib/shell2.dart', 'double _insetSheetH()',
         '没有 _insetSheetH —— bottomInset 会逐帧变，地图每帧重排重绘')
    # ⚠ 断言里必须带 `()`：第一版写的是 `_kGutter + _insetSheetH`（少了括号），
    # 于是它把「方法当值用」这个**编译错误**当成了正确实现 —— 检查通过、CI 编译红。
    # 教训：静态断言要断言**能编译的字符串**，不要把「看起来像」当「是对的」。
    need('lib/shell2.dart', '_kGutter + _insetSheetH()',
         'bottomInset 没用 _insetSheetH()（动画期仍然逐帧变化）')
    forbid('lib/shell2.dart', '_kGutter + _insetSheetH ',
           '_insetSheetH 少了括号（方法当值用，编译不过）')
    forbid('lib/shell2.dart', '_kGutter + _insetSheetH:',
           '_insetSheetH 少了括号（方法当值用，编译不过）')
    for m in re.finditer(r'_insetSheetH(?![\s(])', read('lib/shell2.dart')):
        errors.append('lib/shell2.dart 里 `_insetSheetH` 有被当值用的地方'
                      '（应写成 `_insetSheetH()`）')

    # ⑧ 面板内容实例缓存
    need('lib/shell2.dart', '_contentCache',
         '_content() 没有缓存 —— 面板动画每帧会重建四个页面')

    if errors:
        print('帧成本检查失败：')
        for e in errors:
            print('  -', e)
        return 1
    print('帧成本 ok（面板开着时地图冻结但仍在画；动画期不模糊且会恢复；'
          'inset 与内容都做了缓存）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
