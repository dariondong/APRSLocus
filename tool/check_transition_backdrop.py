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

    # ── ② 不许再用「值到没到 1」当「转场结束」 ──
    #
    # 两种写法都要抓：
    #   * `v >= 1` / `v == 1` —— 把「值到 1」当「停稳」；
    #   * `v < 1` / `v <= 1`  —— 反过来说「值没到 1 就还在转场中」。
    # 它们在**弹出**方向是**同一个错误**：`reverse()` 只改 status，值要等下一个
    # tick 才动，而 ticker 首次回调 elapsed 恒为 0 —— 这一帧里 value 仍然是 1。
    # 于是那份底不画，底下的页面整整透出一帧（用户看到的公告横幅在设置子页上闪一下）。
    #
    # ⚠ 第二类（`< 1`）是**回归样本验证时才发现漏掉的**：第一版只写了 `>= 1`，
    # 把判据改成 `value < 1 && …` 照样报绿 —— 而行为与 bug 版一模一样。
    # 假绿比没有检查更坏（它会让人以为这条已经钉住了）。
    for pat, why in (
        (r'\b(?:value|v)\s*(?:>=|>|==)\s*1(?:\.0)?\b', '把「值到 1」当「转场结束」'),
        (r'\b(?:value|v)\s*(?:<=|<)\s*1(?:\.0)?\b', '把「值小于 1」当「还在转场中」'),
    ):
        bad = re.search(pat, code)
        if bad:
            errors.append(f'lib/app.dart 出现「{bad.group(0)}」—— {why}，'
                          '在**弹出**方向都是错的（那一帧值仍然是 1），'
                          '底下那一页会整整透出一帧（公告横幅在设置子页上闪一下）')

    # ── ③ 那份底要真的被用上，而且必须包在页面子树里（参与动画）──
    #
    # ⚠ v2.0.7 改过一次形状：原来是「转场 Stack 的一层、压在页面外面」——
    # 那样它**不参与动画**，整段退出期间都把底下的页面盖着，用户看到的是
    # 「什么都不动、一片纯色然后消失」（issue #16 的追加反馈）。
    # 现在它是**包住页面的包装层**，包完再交给平台转场做动画。
    if 'class _TransitionBackdrop extends StatefulWidget' not in code:
        errors.append('lib/app.dart 里没有 _TransitionBackdrop —— '
                      '转场期的那份底没了（进/出子页都会透出上一页）')
    if '_TransitionBackdrop(animation: animation, child: child)' not in code:
        errors.append('lib/app.dart 里的 _TransitionBackdrop 没有把页面当 child 包起来 —— '
                      '包在页面子树里才会跟着动画一起动；'
                      '当成转场 Stack 的独立一层会让退出看起来「一片纯色然后消失」')
    if 'required this.child' not in code:
        errors.append('lib/app.dart 的 _TransitionBackdrop 不收 child —— '
                      '它必须是一个包装层（见上一条）')
    if 'StackFit.passthrough' not in code:
        errors.append('lib/app.dart 包页面那层的 Stack 不是 StackFit.passthrough —— '
                      '`expand` 会强制拉满，对话框 / 底部弹层这类节点会被撑坏')
    # 包装层必须真的**交给平台转场当 child**，否则它只是个没人用的局部变量。
    #
    # ⚠ 这里比的是「实参序列」而不是「行号先后」：第一版写的是
    # 「_TransitionBackdrop 的位置是否在 inner.buildTransitions 之前」，而
    # 「插入一行局部变量、实参依旧传 child」的写法照样报绿 —— 那个变量谁也没用，
    # 退出依旧没动画（也是回归样本验证时抓出来的假绿）。
    flat = re.sub(r'\s+', '', code)
    if ('inner.buildTransitions<T>(route,context,animation,secondaryAnimation,backed,)'
            not in flat):
        errors.append('lib/app.dart 没有把包好的 backed 传给 inner.buildTransitions —— '
                      '平台转场动画的必须是那个包装层，否则它不参与动画，'
                      '退出会变成「一片纯色然后消失」')
    if 'Positioned.fill(\n          child: _TransitionBackdrop(' in code:
        errors.append('lib/app.dart 又把这份底当成转场 Stack 的独立一层了 —— '
                      '那样它不参与动画，退出会变成「一片纯色然后消失」')

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
