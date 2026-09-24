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

  6. **面板内的宽度不许按屏幕宽度算**（v1.6.163）。
     2.0 横屏把消息页装进左侧面板（宽 ≤560，手机上常 200~280）。消息气泡原来取
     「屏幕宽 × 0.55」：桌面上屏幕 1920 时会算成 1056，而面板外面套着 `ClipRect`
     —— 超出的部分被默默裁掉，长消息读不全（编译、analyze、其它检查全绿）。
     判据：气泡宽度必须用消息区**实际宽度**（布局期记下的 `_availW`），
     且不许再出现屏幕宽度 × 0.55。

  7. **地图左上统计条在窄地图区不许撑爆**（v1.6.163）。
     横屏 + 内容面板展开时，地图左上控件能拿到的宽度可能只剩 200 出头，而统计条
     三段计数都是**定宽子项**（一个图标一个 Text，没有弹性）—— 必然溢出
     （debug 下溢出条纹、release 下直接被截）。
     判据：`_infoChip` 必须按可用宽度分档（`compact`），每个计数再用 `Flexible` 兜底。

  8. **「矮横屏」要按顶栏之下的可用高度判断**（v1.6.163）。
     顶部让位量会被未连接横幅 / 公告横幅各顶掉一行（合计 +84），桌面上又常有
     「很宽但很矮」的窗口；按**裸屏高**判断会漏判 —— 而漏判的表现正是本文件第 2 条
     要防的「工具列最下面的『定位』被裁掉、点不到」。
     判据：先算 `availH = size.height - widget.topInset - widget.bottomInset`，
     `shortWide` 用它跟 `_kToolbarColH`（单列工具列的实际高度）比。

  9. **换栏／降级不许按「朝向」判**（v1.6.164，真实缺陷）。
     消息页原写作 `!landscape && maxWidth < 720` —— 等价于「只要是横屏就走双栏」，
     而 2.0 横屏把消息页装进**左侧面板**（≤560，手机常 200~280）：双栏里固定 280 的
     列表栏把会话区挤成负宽度，两栏一起溢出、右侧被裁 —— 用户报的「手机的消息面板
     显示不全」。此外单聊标题行（返回 + 头像 + 译发 + 星标 + 网格）与群聊标题行
     （5 个操作胶囊）在窄容器里也会撑爆 Row（release 下不报错，只是默默少东西）。
     判据：`narrow` 必须只看 `constraints.maxWidth`；窄容器要有 `_compactPane` 降级
     （呼号可省略 / 群聊操作换行 `Wrap`）。

 10. **关于页封面必须铺满整张卡**（v1.6.164）。
     早先超宽屏走 `BoxFit.contain`（怕裁掉火山），但卡片高度上限 300、容器宽到 600
     —— 「容器比例 2.0 > 图片比例 1.5」在**任何 ≥600 宽**的屏幕上都成立，于是每次
     都走 contain：照片缩成中间一条、两侧各空 75px，**Logo 那张玻璃卡坐在左边空白上**
     （用户报的「横屏 logo 背景没有完全填充」）。
     判据：封面必须 `BoxFit.cover` + `Alignment.topCenter`（铺满并保住雪顶，
     裁掉的是信息量最低的近景岩石），且不得再出现 `tooWide` 这条 contain 分支。
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

    # ⑥ 面板内的宽度不许按屏幕宽度算（消息页在横屏是被装进 ≤560 的面板里的）
    msgs = code_only(read('lib/messages_page.dart'))
    if 'MediaQuery.of(context).size.width * 0.55' in msgs:
        errors.append('消息气泡仍按屏幕宽度取 0.55 —— 2.0 横屏下面板 ≤560'
                      '（手机常 200~280），桌面上会算成 1056 并被面板的 ClipRect '
                      '裁掉，长消息读不全')
    if 'double _availW = 0;' not in msgs:
        errors.append('消息页没有记下「消息区实际宽度」(_availW) —— 气泡宽度只能'
                      '退回按屏幕宽度算')
    if 'maxWidth: (_availW > 0' not in msgs:
        errors.append('消息气泡的最大宽度没有用 _availW 算')

    # ⑦ 地图左上统计条在窄地图区必须能降级
    i = map_code.find('Widget _infoChip(')
    j = map_code.find('Widget _mapTypeGroup(', i + 1) if i >= 0 else -1
    seg = map_code[i:j] if (i >= 0 and j > i) else ''
    if not seg:
        errors.append('_infoChip 没了（或检查器自己坏了：找不到它到 _mapTypeGroup 之间）')
    else:
        if 'final compact = cons.maxWidth <' not in seg:
            errors.append('_infoChip 没有按可用宽度降级的 compact 档 —— 横屏面板'
                          '展开时（地图区常只剩 200 出头）三段计数会撑爆 Row')
        if seg.count('Flexible(') < 3:
            errors.append('_infoChip 的计数没有**全部**(≥3) 用 Flexible + ellipsis '
                          '兜底 —— 西语/日语的长文案（`120 en movimiento`）会溢出')

    # ⑧ 「矮横屏」按顶栏之下的可用高度判断，而不是裸屏高
    if ('final double availH =' not in map_code
            or 'size.height - widget.topInset - widget.bottomInset' not in map_code):
        errors.append('MapPage 没有按「顶栏之下的可用高度」(availH) 判断矮横屏 —— '
                      '横幅占位/桌面矮窗口会漏判，工具列最下面的按钮被裁')
    if 'availH < _kToolbarColH + 54' not in map_code:
        errors.append('shortWide 没有用 _kToolbarColH（单列工具列高度）判断 —— '
                      '阈值又变回与按钮尺寸脱钩的魔数了')

    # ⑨ 换栏/降级不许按「朝向」判（2.0 横屏的面板只有 200~280 宽）
    if '!landscape && constraints.maxWidth < 720' in msgs:
        errors.append('消息页还在按「朝向」决定双栏 —— 2.0 横屏把消息页装进 ≤560 的'
                      '左侧面板（手机常 200~280），双栏里固定 280 的列表栏会把会话区'
                      '挤成负宽度，两栏一起溢出（「面板显示不全」）')
    if 'final narrow = constraints.maxWidth < 640;' not in msgs:
        errors.append('消息页的 narrow 没有按可用宽度判（应 `constraints.maxWidth < 640`）')
    if 'width: 280,' in msgs:
        errors.append('消息页双栏的列表栏又变回写死的 280 —— 窄容器里会挤掉会话区')
    if 'width: (constraints.maxWidth * 0.34)' not in msgs:
        errors.append('消息页列表栏宽度没有跟着容器走（应为 maxWidth * 0.34 clamp 240~280）')
    if '_compactPane = constraints.maxWidth < 520;' not in msgs:
        errors.append('消息页没有「窄容器行内降级」(_compactPane) —— 标题行那串固定宽度'
                      '的控件会撑爆 Row，右侧被裁')
    if 'child: _compactPane' not in msgs:
        errors.append('群聊标题行没按 _compactPane 拆两行 —— 5 个操作胶囊在窄面板里必然溢出')
    if 'WrapAlignment.end' not in msgs:
        errors.append('群聊操作胶囊没有换行容器（Wrap）—— 窄面板下会被裁掉')

    # ⑩ 关于页封面必须铺满（contain 会让 Logo 坐在空白上）
    about = read('lib/about_page.dart')
    if 'fit: tooWide ?' in about or 'final tooWide' in about:
        errors.append('关于页封面又走了 tooWide/contain 分支 —— 卡片高度上限 300、容器宽到'
                      '600，contain 会在任何 ≥600 宽的屏幕上成立：照片缩成中间一条，'
                      '两侧留空，Logo 卡坐在空白上（「logo 背景没有完全填充」）')
    i = about.find('child: Image.asset(')
    if i < 0:
        errors.append('关于页封面 Image.asset 没了')
    else:
        seg = about[i:i + 2000]
        if 'fit: BoxFit.cover,' not in seg:
            errors.append('关于页封面不是 BoxFit.cover —— 铺不满整张卡')
        if 'alignment: Alignment.topCenter,' not in seg:
            errors.append('关于页封面没给 topCenter 对齐 —— cover 后会从中间裁，'
                          '雪顶有被裁掉的风险')
    # 分享弹层：标题与副标题之间必须有间隙（用户报的「APRSlocus 的下面太挤」）
    a = about.find('S.of(context).shareApp,')
    b = about.find("'APRSlocus \u00b7 v" + '$' + "{AppState.appVersion}',")
    if a < 0 or b < 0 or b < a:
        errors.append('分享弹层的标题/副标题结构变了，检查器自己失效（请更新检查）')
    elif 'SizedBox(' not in about[a:b]:
        errors.append('分享弹层的标题与副标题之间没有间隙 —— 两行贴着，看着就是被挤在一起')

    if errors:
        print('横屏布局检查失败：')
        for e in errors:
            print('  -', e)
        return 1
    print(f'横屏布局 ok（贴左控件让开竖条与面板 {n_left} 处；工具列矮横屏分两列；'
          f'底部让位不含安全区；竖条卡可收缩；左右安全区都让；'
          f'面板内宽度按局部约束；统计条可降级；矮横屏按可用高度判；'
          f'消息页按宽度换栏+行内降级；关于页封面铺满）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
