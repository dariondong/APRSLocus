#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""交互接线检查：小按钮的命中区、跨页请求、未连接横幅。

为什么需要：这一组问题**全都能正常编译、也能通过 analyze**，只在真机上
（手指按下去的那一刻）才看得出来：

  1. **小按钮的命中区**：按钮底色来自 `BoxDecoration`，而它对应的
     `DecoratedBox`（`RenderDecoratedBox extends RenderProxyBox`）**不重写
     `hitTestSelf`** —— 也就是不吸收点击，命中全交给子节点。于是默认的
     `deferToChild` 把 38px 按钮的可点区域缩到中间那个 20px 图标上：
     按到边缘/圆角**完全没反应**。用户报的「地图图层选择面板打不开」就是
     这么来的（他按的是按钮，不是图标）。
     ⚠ 这条不是"风格偏好"：Flutter 自己的 IconButton/InkWell 都是 opaque，
     自绘按钮必须显式补上。

  2. **跨页请求**：「在地图查看」只改了状态（`focusOnMap`），**外壳还得把页签
     切回地图**。1.0 里这段在 `HomePage._onStateChanged`，2.0 外壳漏了 ——
     地图在背后飞过去了，用户却还停在台面，看着像「点了没反应」。

  3. **会话页要露出输入框**：2.0 的面板按最高档高度布局、只裁出可视区，
     半屏档下页面最底部的输入框正好在裁切线之下 → 必须请求展开。

  4. **未连接横幅**：只由一颗小胶囊表达「未连接」时，整屏看起来一切正常，
     而实际上发送/信标/消息全都发不出去。横幅还必须**算进地图顶部让位量**，
     否则它会压住地图自己的顶部浮层。

  5. **回调「只返回函数、不调用」**：`onTap: () => _showMapTypeMenu`（**漏了括号**）
     只是返回这个函数本身，从不调用 —— 点下去等于什么都不做。
     而 Dart 允许把 `void Function() Function()` 赋给 `VoidCallback`
     （返回值位置的 `void` 是顶类型），所以**编译与 analyze 都不会报**。
     用户报的「底图选择面板弹不出来」就是这么来的（一直坏到 v1.6.156）。
     判据落在**箭头函数体是裸标识符**这一形态上（`=>` 后面没有 `(`）。

用法：python3 tool/check_ui_wiring.py
退出码 0 = 全在；1 = 有缺失。
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

    def need(rel, needle, why, count=1):
        if read(rel).count(needle) < count:
            errors.append(f'{rel} 里 `{needle}` 不足 {count} 处 —— {why}')

    # ── ① 自绘小按钮必须 opaque ──
    need('lib/map_page.dart', 'behavior: HitTestBehavior.opaque',
         '地图工具钮没显式 opaque —— DecoratedBox 不吸收点击，'
         '38px 按钮只有中心 20px 图标能点（「面板打不开」的成因）', count=5)
    # _toolBtn 是这一组里最关键的一个（工具列 8 颗按钮都走它）
    mp = read('lib/map_page.dart')
    i = mp.find('Widget _toolBtn(')
    if i < 0:
        errors.append('lib/map_page.dart 找不到 `_toolBtn(` —— 工具列按钮的命中区无从确认')
    elif 'HitTestBehavior.opaque' not in mp[i:i + 900]:
        errors.append('lib/map_page.dart 的 `_toolBtn` 没有 `HitTestBehavior.opaque` '
                      '—— 工具列按钮只有图标能点')
    iw = read('lib/widgets.dart')
    j = iw.find('class RoundIconBtn')
    if j < 0:
        errors.append('lib/widgets.dart 找不到 `class RoundIconBtn`')
    elif 'HitTestBehavior.opaque' not in iw[j:j + 900]:
        errors.append('lib/widgets.dart 的 `RoundIconBtn` 没有 `HitTestBehavior.opaque` '
                      '—— 缩放/轨迹那一列按钮只有图标能点')

    # ── ② 跨页请求：外壳要接「在地图查看 / 在地图选点」 ──
    need('lib/shell2.dart', 'st.mapFocusSeq != _lastFocusSeq',
         '外壳没接「在地图查看」—— 点完还停在原来那页（用户报的「点了没反应」）')
    need('lib/shell2.dart', 'st.pickSeq != _lastPickSeq',
         '外壳没接「在地图选点」—— 选点后不会切回地图')
    need('lib/shell2.dart', '_select(0)',
         '外壳接是接了，但没有切回地图页')
    # 必须在「显示值没变就 return」之前处理：这些请求不改变外壳显示的值
    so = read('lib/shell2.dart')
    k = so.find('st.mapFocusSeq != _lastFocusSeq')
    k2 = so.find("if (key == _stateKey) return;")
    if k > 0 and k2 > 0 and k > k2:
        errors.append('lib/shell2.dart 的跨页请求处理写在了 '
                      '`if (key == _stateKey) return;` **之后** —— '
                      '它不改变外壳显示的值，会被那行提前返回吃掉，等于没写')

    # ── ③ 会话页请求展开 ──
    need('lib/state.dart', 'void requestSheetExpand()',
         '没有「请求展开面板」这个跨页请求')
    need('lib/shell2.dart', 'st.sheetExpandSeq != _lastExpandSeq',
         '外壳没接「展开面板」的请求 —— 会话页的输入框仍然藏在裁切线之下')
    need('lib/messages_page.dart', 'widget.state.requestSheetExpand()',
         '会话页没有请求展开 —— 输入框在半屏档下看不见')

    # ── ④ 未连接横幅 ──
    need('lib/shell2.dart', 'bool _showLinkBanner(AppState st)',
         '没有未连接横幅的判定')
    need('lib/shell2.dart', '_linkBanner(widget.state)', '未连接横幅没有接线', count=2)
    sl = read('lib/shell2.dart')
    b = sl.find('bool _showLinkBanner(AppState st) =>')
    if b < 0:
        errors.append('lib/shell2.dart 找不到 `_showLinkBanner` 的定义')
    else:
        body = sl[b:b + 200]
        if 'readOnlyMode' not in body:
            errors.append('lib/shell2.dart 的 `_showLinkBanner` 没排除只读模式 —— '
                          '只启用只收来源时「没有发射链路」是正常的，'
                          '挂一条「未连接」会让人白去点连接（v1.6.109 的口径）')
    # 横幅要算进顶部让位量，否则压住地图自己的顶部浮层
    # 两个横幅（未连接 + 公告）都必须算进让位量 —— 断言的是**那一行表达式**，
    # 不是「变量名出现过」：只查名字的话，把某一项从求和里删掉仍然报绿。
    m_top = re.search(r'final topInset = ([^;]+);', sl)
    top_expr = m_top.group(1) if m_top else ''
    for term, what in (('linkBannerH', '未连接横幅'), ('noticeH', '公告横幅')):
        if term not in top_expr:
            errors.append(f'lib/shell2.dart 的顶部让位量没有算上{what}'
                          f'（`final topInset = {top_expr.strip()}` 里缺 `{term}`）—— '
                          '横幅会压住地图的信息条/图例/工具列')
    if '_kLinkBannerH' not in sl:
        errors.append('lib/shell2.dart 缺 `_kLinkBannerH`（固定高度）—— '
                      '让位量必须是确定的数，量出来的高度会抖一下')

    # ── ⑤ 「看得出这是个输入框」──
    #
    # 用户反馈「台站备注，用户都不知道那里是可以输入的」：那个字段默认是空的，
    # 而输入框原来是 `border: none` + 无背景 + **无占位符** —— 右边整片空白，
    # 和静态的「标签 + 值」行长得一样。
    #
    # 这条只能靠眼睛发现，编译/analyze/测试全绿，所以钉在这里。判据落在
    # **真正起作用的三行**上（与上面那两道闸同一个教训：别只断言参数名）。
    sw = read('lib/settings_widgets.dart')
    i = sw.find('class SettingsInput')
    if i < 0:
        errors.append('lib/settings_widgets.dart 找不到 `class SettingsInput`')
    else:
        body = sw[i:sw.find('\n}', i)]
        if 'hintText:' not in body:
            errors.append('SettingsInput 没有占位提示（hintText）—— 空字段那一行'
                          '会是整片空白，用户不知道能输入')
        if 'inputTapHint' not in body:
            errors.append('SettingsInput 的占位提示没有默认值（inputTapHint）'
                          '—— 没传 hint 的字段又会变回一片空白')
        if 'filled: true' not in body:
            errors.append('SettingsInput 的输入区没有底色（filled: true）—— '
                          '没有「框」就不像输入框')
    # 台站备注这一行要给更直白的提示（它默认就是空的，是用户点名的那一处）
    need('lib/settings_pages.dart', 'hint: S.of(context).callCommentEmpty',
         '「台站备注」没用专门的占位提示 —— 那正是用户说「不知道能输入」的那一行')

    # ── ⑥ 回调不能「只返回函数、不调用」──
    #
    # 形态很具体：`onXxx: () => someName`（或换行后的同一个东西），
    # `=>` 后面是**裸标识符**、紧接着 `,` 或 `)` —— 也就是没有调用。
    #
    # ⚠ 判据里的 `on[A-Za-z]+:` **不能省**（另一个会话的版本已经写对了，
    #   我最初的宽版本就是栽在这里）：放开成「`=>` 后面跟裸标识符」会误报
    #   `builder: (_, __) => icon`（builder 返回一个局部 widget 变量，完全合法）——
    #   实测在 settings_pages.dart 上就报了一次假失败。限定在 `on*` 回调参数上，
    #   既精确又不误伤。
    # 编译能过（`void` 在返回值位置是顶类型）、analyze 也不报，
    # 运行时表现是「点了完全没反应」，最难查。
    bare = re.compile(
        r'on[A-Za-z]+\s*:\s*\(\s*\)\s*=>\s*'
        r'([A-Za-z_][A-Za-z0-9_]*)\s*(?=[,)])', re.S)
    for base, _dirs, files in os.walk(os.path.join(ROOT, 'lib')):
        for fn in sorted(files):
            if not fn.endswith('.dart'):
                continue
            rel = os.path.relpath(os.path.join(base, fn), ROOT).replace(os.sep, '/')
            # 剔掉整行注释：注释里会**提到**这个坏写法来解释为什么不能这么写
            code = '\n'.join(l for l in read(rel).split('\n')
                             if not l.lstrip().startswith('//'))
            seen = set()
            for m in bare.finditer(code):
                name = m.group(1)
                if name in seen:
                    continue
                seen.add(name)
                line = code[:m.start()].count('\n') + 1
                errors.append(f'{rel}:{line} 的手势/按键回调写成 `() => {name}` —— '
                              '**漏了括号**（只是返回函数本身、从不调用），'
                              f'点了不会有反应；应写成 `() => {name}()` 或直接传 `{name}`')

    # ── ⑦ 外壳状态 key 的多行字符串拼接必须以 `;` 收尾 ──
    #
    # 真实事故（v1.6.157 的 CI）：给 `final key = 'a|b|' 'c|'` 这种多行拼接
    # 追加一项时，新那一行末尾漏了 `;` —— 括号是平衡的，所以本地那套
    # 「括号平衡」检查看不出问题，只有 analyze 报 `Expected to find ';'`。
    # 本机跑不了 analyze，于是又白等一轮 CI。
    #
    # 判据很窄但准确：定位 state key 那一行，往后扫到第一条「不是续行」的行，
    # 要求**上一行以 `;` 结尾**。（续行 = 注释，或以引号/括号/运算符开头的行。）
    lines = sl.split('\n')
    ki = next((i for i, l in enumerate(lines) if 'final key = ' in l), -1)
    if ki < 0:
        errors.append('lib/shell2.dart 里找不到 `final key = ` —— 外壳的状态 key 无从确认')
    else:
        ok_semi = False
        for j in range(ki, min(ki + 40, len(lines))):
            s = lines[j].strip()
            if j > ki:
                # 续行特征：注释 / 以引号 / 括号 / 运算符开头
                if not (s.startswith('//') or s[:1] in ("'", '"', '+', ')', '(', '[')
                        or s == ''):
                    ok_semi = lines[j - 1].rstrip().endswith(';')
                    break
            if s.endswith(';'):
                ok_semi = True
                break
        if not ok_semi:
            errors.append('lib/shell2.dart 的多行状态 key 拼接没有以 `;` 收尾 —— '
                          'analyze 会报 `Expected to find \';\'`（本机看不出，'
                          '括号是平衡的）')

    if errors:
        print('交互接线检查失败：')
        for e in errors:
            print('  -', e)
        return 1
    print('交互接线 ok（自绘按钮整块可点、外壳接三种跨页请求、未连接横幅占让位量、'
          '回调都真的被调用）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
