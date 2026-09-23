#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""2.0 横屏布局检查：竖条不再压住地图控件、工具列不被裁掉。

为什么需要它：这几条**全都能正常编译、也能通过 analyze**，只在真机横屏下才看得出来
（而且手机的横屏是「矮」的那一维，问题最明显）。本机既没有模拟器也没有 Android SDK，
所以把判据钉在这里 —— 与 check_frame_cost.py 同一套思路：守的是「不做某件事」。

守的是这几条（每条都对应一个真实缺陷）：

  1. **竖条/面板压住地图贴左控件**。
     横屏时 2.0 外壳把导航竖条（以及展开时的内容面板）摆在左边，而地图仍是整屏铺满的。
     地图的贴左控件（信息条、沉浸入口、上报横杠、底部比例尺/坐标条）如果不让开，
     就会**糊在那张半透明磨砂卡背后** —— 卡是 58% 透明的，所以不是「被挡住」这么干脆，
     而是控制条在卡片后面若隐若现，看着像渲染坏了。
     判据：`MapPage` 必须真的把 `leftInset` 用在贴左控件上，且 `HomeShell2` 的
     横屏布局必须把 `leftInset` 传下去。

     ⚠ 判据改过一次，记在这里：原来是**数 `14 + widget.leftInset` 的出现次数**
     （要求 ≥4），那是在数实现细节、不是在守意图 —— 把「信息条 + 沉浸入口」合并成
     同一个左上竖列之后，入口自己不再需要 `leftInset`（它跟着列走），计数掉到 3 就
     报了假失败。假失败比没有检查更坏（人会顺手把规则放宽）。现在改成按**结构**判：
     竖列本身要让开、**沉浸入口必须真的在那个竖列里**、上报横杠与底部条各自让开。

  2. **右侧工具列在手机横屏被裁掉**。
     单列是 8 个按钮 ≈ 346px（3 个小工具钮 3×38+2×6=126，5 个缩放钮 5×38+4×6=214，
     加上两组之间的 6），而手机横放的可用高度常常只有 300px 出头。`Stack` 默认
     `Clip.hardEdge`，于是**最下面的「定位」被剪掉且点不到** —— 偏偏那是横屏看地图时
     最常用的按钮。横屏横向空间宽裕，分成两列即可。
     判据：右侧工具列必须走 `_rightToolbar(shortWide)` 这个分派函数，
     且 `shortWide` 分支里必须有 `Row(`（两列）。

  3. **底部让位量把安全区算了两遍**。
     `MapPage` 的口径是「相对底部安全区」——它自己会加一次 `MediaQuery.padding.bottom`。
     竖屏那边是**减掉** `pad.bottom` 再传的；横屏曾经直接传 `_kGutter + pad.bottom`，
     于是横屏（尤其带手势条/刘海的机器）底部控件会凭空抬高一个安全区的高度。
     判据：横屏传给地图的必须是 `bottomInset: _kGutter,`（不含安全区）。

  4. **收起时的竖条卡被撑成通高**。
     `_railItems()` 是 `SingleChildScrollView`（为极矮横屏准备的），而它**没有
     `shrinkWrap`** —— 在高度有界的父约束下会直接填满可用高度，于是「只剩一张竖条卡
     并垂直居中」的设计失效：卡片变成通高空框、导航项全挤在上沿（正是注释里说
     「贴顶会显得像掉在上面」的样子）。需要 `IntrinsicHeight` 才能既收缩又可滚。
     判据：`_railCard()` 里必须有 `IntrinsicHeight`。

  5. **两个轴的安全区都要让**（横屏的刘海/挖孔在**左、右**两侧，不在顶部）。
     判据：横屏的竖条与顶栏用 `safeL` / `safeR`（= `pad.left/right + _kGutter`）而不是
     裸的 `_kGutter`。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(rel):
    return io.open(os.path.join(ROOT, rel), encoding='utf-8').read()


def code_only(text):
    """剔掉整行注释 —— 注释里会**提到**这些名字来解释「为什么这么做」，
    直接搜全文件会把这些说明文字当成违规（check_frame_cost.py 踩过这个假失败）。"""
    return '\n'.join(l for l in text.split('\n')
                     if not l.lstrip().startswith('//'))


def main() -> int:
    errors = []
    shell = read('lib/shell2.dart')
    map_page = read('lib/map_page.dart')
    shell_code = code_only(shell)
    map_code = code_only(map_page)

    # ① 竖条/面板不许压住地图贴左控件
    if 'final double leftInset;' not in map_page:
        errors.append('MapPage 没有 leftInset 参数 —— 横屏时贴左控件会糊在竖条/面板背后')
    n_left = map_code.count('14 + widget.leftInset')
    if n_left < 3:
        errors.append(f'MapPage 里只有 {n_left} 处用了 `14 + widget.leftInset`（要 ≥3：'
                      '左上竖列（信息条 + 沉浸入口）/ 上报横杠 / 底部坐标条）—— '
                      '漏掉的那些在横屏会被竖条压住')
    # 沉浸入口必须**挂在左上竖列里**：它自己算 Positioned 时会被同列其它控件盖住
    # （真发生过：引导卡硬写 topBase+46，正好糊在这个入口上）。
    if '_immersiveEntry(),' not in map_code:
        errors.append('沉浸入口没挂在「左上竖列」里 —— 它自己算 Positioned 就会被'
                      '同列控件盖住，也拿不到 leftInset 的让位')
    if 'left: widget.leftInset,' not in map_code:
        errors.append('搜索提示条没有按 leftInset 对齐 —— 横屏时它会偏向左侧、压到卡片边缘')
    if 'leftInset: mapLeftInset' not in shell:
        errors.append('横屏布局没有把 leftInset 传给地图 —— 竖条会重新压住地图左侧控件')
    # 竖条 + 面板都要算进去：面板展开时是**压在地图上**的卡片
    if 'final double mapLeftInset = occupied + (showPane ? paneW : 0.0);' not in shell:
        errors.append('mapLeftInset 没把内容面板的宽度算进去 —— 面板展开时地图的左半边控件'
                      '仍然在卡片背后')

    # ② 右侧工具列在矮横屏必须分两列
    if 'child: _rightToolbar(shortWide)' not in map_page:
        errors.append('右侧工具列没走 `_rightToolbar(shortWide)` —— 手机横屏下最下面的'
                      '「定位」会被 Stack 裁掉且点不到')
    if 'Widget _rightToolbar(bool shortWide)' not in map_page:
        errors.append('_rightToolbar 没了')
    else:
        seg = map_code[map_code.find('Widget _rightToolbar(bool shortWide)'):]
        end = seg.find('Widget _zoomCtrl()')
        if end > 0:
            seg = seg[:end]
        if 'Row(' not in seg:
            errors.append('_rightToolbar 的 shortWide 分支没有 Row( —— 矮横屏还是单列，'
                          '仍会被裁掉')
        if 'crossAxisAlignment: CrossAxisAlignment.start' not in seg:
            errors.append('_rightToolbar 两列没有 start 对齐 —— 矮的那列会被推居中，'
                          '两列上沿不齐')

    # ③ 底部让位量不许重复计入安全区
    if 'bottomInset: _kGutter,' not in shell:
        errors.append('横屏传给地图的 bottomInset 不是 `_kGutter` —— 若含 pad.bottom，'
                      '地图会再加一次安全区，底部控件凭空抬高')

    # ④ 收起时的竖条卡必须能收缩（否则通高空框）
    i = shell.find('Widget _railCard()')
    if i < 0:
        errors.append('_railCard() 没了')
    elif 'IntrinsicHeight(' not in shell[i:i + 1200]:
        errors.append('_railCard() 里没有 IntrinsicHeight —— SingleChildScrollView 没有 '
                      'shrinkWrap，卡片会被撑成通高空框，「垂直居中」失效')

    # ⑤ 横屏两个轴的安全区都要让（刘海在左右，不在顶部）
    for probe, why in (
        ('final safeL = pad.left + _kGutter;', '横屏没有让开左侧安全区（刘海/挖孔）'),
        ('final safeR = pad.right + _kGutter;', '横屏没有让开右侧安全区'),
    ):
        if probe not in shell:
            errors.append(f'{why} —— 少了 `{probe}`')
    # 工作区与顶栏都要用 safeL/safeR，而不是裸的 _kGutter
    n_safe = shell_code.count('safeL')
    if n_safe < 2:
        errors.append(f'只有 {n_safe} 处用了 safeL（顶栏与工作区都要用）')

    if errors:
        print('横屏布局检查失败：')
        for e in errors:
            print('  -', e)
        return 1
    print(f'横屏布局 ok（贴左控件让开竖条与面板 {n_left} 处；工具列矮横屏分两列；'
          f'底部让位不含安全区；竖条卡可收缩；左右安全区都让）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
