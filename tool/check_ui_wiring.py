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

用法：python3 tool/check_ui_wiring.py
退出码 0 = 全在；1 = 有缺失。
"""
import io
import os
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
    if 'final topInset = _topInset() + linkBannerH;' not in sl:
        errors.append('lib/shell2.dart 的顶部让位量没有算上未连接横幅 —— '
                      '横幅会压住地图的信息条/图例/工具列')
    if '_kLinkBannerH' not in sl:
        errors.append('lib/shell2.dart 缺 `_kLinkBannerH`（固定高度）—— '
                      '让位量必须是确定的数，量出来的高度会抖一下')

    if errors:
        print('交互接线检查失败：')
        for e in errors:
            print('  -', e)
        return 1
    print('交互接线 ok（自绘按钮整块可点、外壳接三种跨页请求、未连接横幅占让位量）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
