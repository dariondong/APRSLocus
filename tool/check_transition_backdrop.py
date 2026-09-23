#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""转场「底」的静态检查 —— 专治**退出方向**的那一帧空洞。

背景（用户反馈）：「公告横幅怎么显示在设置子页？页面退出动画会闪一下」。

根因与修法都在 `lib/app.dart` 的 [_TransitionBackdrop] 顶部写着，这里只钉住
「**判据不许回到按值判断**」这件事。为什么值得单开一条检查：

  * 「值 == 1」在**推入**时是对的（推入的第一帧值就是 0），所以代码看起来没问题、
    自测推入也正常；只有**弹出**那一帧才会漏（`reverse()` 只改 status，值要等
    下一次 tick 才动，而 ticker 首次回调 elapsed 恒为 0）；
  * 漏出来的表现是「底下的页面整整透出一帧」——一团模糊的闪动，能正常编译、
    能通过 analyze、也能通过所有既有检查器；
  * 而它依赖**三个**前提同时成立（页面底色透明 + 转场期旧路由照常绘制 + 底没画），
    所以「换台机器就复现不了」的概率很高 —— 写死一条检查比靠记忆靠谱。

本检查器只钉**形态**（哪几个 API 必须出现、哪几个必须不出现、顺序对不对），
不钉具体写法：排除法（completed/dismissed 之外都算转场中）与列举法
（forward/reverse）都算对，别把对的误报成错。

用法：python3 tool/check_transition_backdrop.py
退出码 0 = 全在；1 = 有缺失（并说明缺什么）。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(rel):
    return io.open(os.path.join(ROOT, rel), encoding='utf-8').read()


def code_only(rel):
    """剔掉整行注释，只留代码。

    为什么必需：这个文件顶部的说明里**就写着** `v >= 1 ? 不画 : 画`（解释历史写法），
    拿全文去搜「有没有按值判断」会命中的是**说明文字**，于是把代码改回去也照样报绿
    —— check_notice.py 踩过同一个坑（见那里的 code_only 说明）。
    """
    return '\n'.join(l for l in read(rel).split('\n')
                     if not l.lstrip().startswith('//'))


def main() -> int:
    errors = []
    code = code_only('lib/app.dart')

    # ── ① 那份「底」必须由**状态监听**驱动 ──
    #
    # 只断言「有 addStatusListener」是不够的？—— 不，正是它区分了「按值」与「按状态」：
    # `reverse()` 不通知值监听器，所以弹出那一刻只有状态监听器会被叫醒。
    if 'addStatusListener(' not in code:
        errors.append('lib/app.dart 没有给转场动画挂 addStatusListener —— '
                      '`reverse()` 不通知值监听器，弹出那一帧没人叫醒它')
    if 'removeStatusListener(' not in code:
        errors.append('lib/app.dart 挂了 addStatusListener 却没 removeStatusListener '
                      '—— 路由回收后监听器仍被持有（内存泄漏）')
    if 'widget.animation.status' not in code:
        errors.append('lib/app.dart 的转场底不是按 status 判断的 —— '
                      '必须是「转场是否进行中」而不是「值到没到 1」')

    # ── ② 不许再用「值等于 1」当「转场结束」 ──
    #
    # 形态：`v >= 1` / `v == 1` / `animation.value >= 1.0` / `.value == 1`。
    # 这条是**回归样本验过的**：把判断改回 `v >= 1`，本检查器立刻报红。
    bad = re.search(r'\b(?:value|v)\s*(?:>=|>|==)\s*1(?:\.0)?\b', code)
    if bad:
        errors.append(f'lib/app.dart 又出现「{bad.group(0)}」—— 用「值到 1」当'
                      '「转场结束」在**弹出**方向是错的（那一帧值仍然是 1），'
                      '底下那一页会整整透出一帧（公告横幅在设置子页上闪一下）')

    # ── ③ 那份底要真的被用上，而且必须压在转场页面**之下** ──
    if 'class _TransitionBackdrop extends StatefulWidget' not in code:
        errors.append('lib/app.dart 里没有 _TransitionBackdrop —— '
                      '转场期的那份底没了（进/出子页都会透出上一页）')
    use = code.find('child: _TransitionBackdrop(')
    if use < 0:
        errors.append('转场的 Stack 里没有用 _TransitionBackdrop —— '
                      '那份底定义了却没画上')
    inner = code.find('child: transitioned)')
    if use >= 0 and inner >= 0 and not use < inner:
        errors.append('转场里那份底没有画在页面**之下**（Stack 顺序反了）—— '
                      '淡入/缩放会盖住页面，等于页面底色没了')

    # ── ④ 底必须与 `builder` 那份同源 ──
    if 'ThemeController.instance.buildBackdrop()' not in code:
        errors.append('转场的底不是用 ThemeController.buildBackdrop() —— '
                      '与 `builder` 那份不同源就会看到「换了一次底」')

    # ── ⑤ 这套机制的前提：页面底色透明 ──
    #
    # 页面底色若不再透明（`pageFill` 变实色），转场期的旧路由根本透不出来，
    # 这份底就成了多余的一层 —— 那时应该**删掉**它，而不是留着白画。
    # 所以把前提也钉住：条件变了要有人回头看这里。
    th = read('lib/theme.dart')
    if 'pageFill => hasBackdrop ? Colors.transparent : bg' not in th:
        errors.append('lib/theme.dart 的 C.pageFill 不再是「有底时透明」—— '
                      '转场底这套机制的前提变了，请连同 app.dart 一起复核'
                      '（若页面已不透明，这份底应删除）')

    if errors:
        print('转场底检查失败：')
        for e in errors:
            print('  -', e)
        return 1
    print('转场底 ok（按 status 判断、挂在状态监听上、压在页面之下、与 builder 同源）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
