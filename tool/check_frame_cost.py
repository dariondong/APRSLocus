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
  4. 面板**自身高度固定**、只裁出可视区（`ClipRect` + `OverflowBox(maxHeight:
     maxSheetH)`）。这一条是「拖起来卡」与「一拖就变白」的共同解法：
     固定高度 ⇒ 模糊层的几何在拖动/动画中不变 ⇒ 可以**一直开着模糊**。
     反过来（让高度跟着变、动画期关模糊）就是老做法：要么卡，要么为了不卡而把
     填色换成不透明的白 —— 那就是用户看到的「莫名其妙变白」。
  5. 传给地图的 `bottomInset` 在动画期必须是**吸附目标值**：逐帧变的话，
     地图每帧重排重绘，正好把第 1 条抵消掉。
  6. 面板内容要做**实例缓存**：否则动画每帧重建四个页面。
  7. 磨砂层要走**共享底**那条路（`BackdropFilter.grouped` + 地图小浮层那一簇的
     `BackdropGroup`）：每个 `BackdropFilter` 都要让引擎「结束当前 render pass →
     采样 → 重开」一次，这是它在移动端最贵的一步。地图页十来个 38px 小浮层各自
     一次的话，列表一滚动就是每秒上千次。这两条一被改回默认构造就白做了，
     而它**不会被编译或测试拦住**，只会回到「开着磨砂就卡」。
  8. **只压在壁纸上的壳**（1.0 的顶栏/侧栏/底栏、各子页 AppBar）要写
     `overWallpaper: true` —— 壁纸是渐变，模糊它零收益却每帧一次 pass 收尾/重开。
     反过来，`extendBodyBehindAppBar: true` 的页面（顶栏背后是地图）**必须**写
     `overWallpaper: false`，否则顶栏变成「半透明但不模糊」，底下的图直接透上来。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(rel):
    return io.open(os.path.join(ROOT, rel), encoding='utf-8').read()


def code_only(text):
    """剔掉整行注释，只留代码 —— 用于 `forbid` 与正则这类**会误伤注释**的判据。

    为什么必需：本文件与源码里的注释会**提到**被禁的名字来解释「为什么不用它」
    （例如 `blurWhen` 的墓志铭）。直接全文件搜索会把这些说明文字当违规 ——
    本检查第一版就因此报了两条假失败（另一条是注释里写 `[_insetSheetH]` 被
    当成「方法当值用」）。假失败比没有检查更坏，因为它会让人把规则放宽。
    """
    return '\n'.join(l for l in text.split('\n')
                     if not l.lstrip().startswith('//'))


def main() -> int:
    errors = []

    def need(rel, needle, why):
        if needle not in read(rel):
            errors.append(f'{rel} 里找不到 `{needle}` —— {why}')

    def forbid(rel, needle, why):
        # 只看代码行：注释里提到被禁的名字是在**解释**，不是违规
        if needle in code_only(read(rel)):
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

    # ⑥ 面板几何必须固定：模糊层的大小在拖动/动画中不能变
    #
    #    为什么不再检查 `blurWhen`：那个开关（动画期关掉模糊）本身就是问题的另一半
    #    —— 关掉模糊必须同时把填色换成不透明的白，于是「一拖就变白」。现在改成
    #    「面板自身高度固定、只裁可视区」，模糊可以一直开着。所以这里守的不变量
    #    换了，而且要**反过来**禁止那两个旧手法再长回来。
    need('lib/shell2.dart', 'minHeight: maxSheetH',
         '面板壳没有固定高度（minHeight: maxSheetH）—— 高度每帧变，模糊层就每帧重做')
    need('lib/shell2.dart', 'maxHeight: maxSheetH',
         '面板壳没有固定高度（maxHeight: maxSheetH）')
    forbid('lib/shell2.dart', '_paneSolid',
           '面板又出现了「过渡用的不透明填色」—— 那正是「一拖就莫名其妙变白」的成因；'
           '正确做法是让面板几何固定、模糊一直开着')
    forbid('lib/material.dart', 'blurWhen',
           'MaterialSurface 又长出了「动画期关模糊」的开关 —— 关掉它就必须换不透明填色，'
           '于是变成「一拖就变白」；责任应在调用点的几何')
    need('lib/shell2.dart', 'addStatusListener',
         '没有状态监听：动画结束后不会按新状态重算（面板会停在旧的让位量上）')

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
    for m in re.finditer(r'_insetSheetH(?![\s(])', code_only(read('lib/shell2.dart'))):
        errors.append('lib/shell2.dart 里 `_insetSheetH` 有被当值用的地方'
                      '（应写成 `_insetSheetH()`）')

    # ⑧ 面板内容实例缓存
    need('lib/shell2.dart', '_contentCache',
         '_content() 没有缓存 —— 面板动画每帧会重建四个页面')

    # ⑨ 磨砂层必须走共享底那条路（见文件顶部第 7 条）
    need('lib/material.dart', 'child: BackdropFilter.grouped(',
         'MaterialSurface 又改回了默认的 BackdropFilter 构造 —— 每个浮层都会各自让'
         '引擎「结束 render pass → 采样 → 重开」一次，共享底白做了')
    forbid('lib/material.dart', 'BackdropFilter(',
           'material.dart 里出现了非 `.grouped` 的 BackdropFilter —— 见文件顶部第 7 条')
    need('lib/map_page.dart', 'child: BackdropGroup(',
         '地图页的小浮层没有共享底（BackdropGroup）—— 十来个 38px 工具钮每帧各自'
         '收尾/重开一次 render pass')

    # ⑩ 「只压在壁纸上的壳」不插模糊层；反之 extendBodyBehindAppBar 必须插
    if read('lib/home_page.dart').count('overWallpaper: true') < 3:
        errors.append('lib/home_page.dart 的壳（侧栏/顶栏/底栏）少了 '
                      '`overWallpaper: true` —— 1.0 布局里它们压在壁纸上，模糊一层'
                      '渐变毫无收益，却每帧多付一次 pass 收尾/重开')
    for base, _dirs, files in os.walk(os.path.join(ROOT, 'lib')):
        for fn in sorted(files):
            if not fn.endswith('.dart'):
                continue
            rel = os.path.relpath(os.path.join(base, fn), ROOT).replace(os.sep, '/')
            # 只看代码行：material.dart 的文档注释里也写着 `extendBodyBehindAppBar: true`，
            # 拿全文搜会把它当成一个「有顶层地图的页面」（第一版就假报了这一条）。
            code = code_only(read(rel))
            if 'extendBodyBehindAppBar: true' not in code:
                continue
            if 'overWallpaper: false' not in code:
                errors.append(f'{rel} 写了 `extendBodyBehindAppBar: true`（顶栏背后是内容），'
                              '但 MaterialAppBar 没写 `overWallpaper: false` —— '
                              '顶栏会变成「半透明但不模糊」')

    if errors:
        print('帧成本检查失败：')
        for e in errors:
            print('  -', e)
        return 1
    print('帧成本 ok（面板开着时地图冻结但仍在画；面板几何固定故模糊可常开；'
          'inset 与内容都做了缓存）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
