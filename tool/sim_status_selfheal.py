#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""自定义状态帧「被吞就自愈」的算法级仿真 + 回归断言。

背景（用户实测）：填了自定义状态却「有时还显示 CONNECT」。状态报文是一对
（内置 `APRSlocus CONNECT` + 自定义状态），第二帧若 `write` 失败（socket
抖动 / 半开），aprs.fi 的「台站状态」就停在 CONNECT 上；而每轮保活都先发
CONNECT —— 等于每 15s 把错误文本又续一次。

修法（本轮）：连接器 `send` 回传成败，保活记住「上次自定义帧丢了」，下个 tick
无视发报门槛立刻补发**自定义帧本身**（不重复发 CONNECT），直到写成功。

两条用途（与 tool/sim_prune.py 同一套路）：

  1) **定规则**：`python3 tool/sim_status_selfheal.py` 打印各场景下的动作序列。
  2) **当回归测试**：`--check`
     * 校验 Dart 判据与本文逐项一致（两处漂移等于在验证另一个算法）；
     * 断言不变量：
         - 丢帧后**下一拍**补的是自定义帧，且**不**再发 CONNECT；
         - 补发持续失败 → 每拍重试；一旦成功 → 清除标记、不再补；
         - 自定义文本为空 → 清标记、不发（避免无限空转）；
         - 链路正常时不会误报「丢了」（healthy 路径不置位）。
"""
import io
import os
import sys
from datetime import datetime, timedelta

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CONNECT_FRAME = '>APRSlocus CONNECT vX.Y.Z test'
TICK = 15          # 保活定时器周期（秒）
TX_GATE = 25       # 「距上次发报 ≥25s 才发」门槛（秒）


class Sim:
    """1:1 移植保活 tick 里与状态自愈相关的分支。"""

    def __init__(self, status_text, now):
        self.status_text = status_text
        self.custom_lost = False
        self.last_tx = now
        self.sent = []  # 已写进链路的内容

    def _frame(self):
        return ('>' + self.status_text) if self.status_text else None

    def _try(self, raw, ok):
        if ok:
            self.sent.append(raw)
        return ok

    def tick(self, now, custom_write_ok=True):
        """返回本拍动作标签。custom_write_ok 只影响自定义帧的写入成败。"""
        lost = self.custom_lost
        if not lost and (now - self.last_tx).total_seconds() < TX_GATE:
            return 'skip'
        if lost:
            re = self._frame()
            if re is None:
                self.custom_lost = False
                return 'clear-empty'
            if self._try(re, custom_write_ok):
                self.custom_lost = False
                self.last_tx = now
                return 'heal-custom'
            return 'heal-retry'
        self.sent.append(CONNECT_FRAME)
        frame = self._frame()
        if frame is not None:
            self.custom_lost = not self._try(frame, custom_write_ok)
        self.last_tx = now
        return 'keepalive'


def _dart_marker_check():
    errs = []
    base = io.open(os.path.join(ROOT, 'lib', 'net', 'aprs_base.dart'),
                   encoding='utf-8').read()
    io_ = io.open(os.path.join(ROOT, 'lib', 'net', 'aprs_io.dart'),
                  encoding='utf-8').read()
    web = io.open(os.path.join(ROOT, 'lib', 'net', 'aprs_web.dart'),
                  encoding='utf-8').read()
    state = io.open(os.path.join(ROOT, 'lib', 'state.dart'),
                    encoding='utf-8').read()

    need = [
        (base, '连接器 send 回传成败', 'bool send(String raw);'),
        (io_, 'io: 未连接返回 false', 'if (!connected || sock == null) return false;'),
        (io_, 'io: 写失败收掉连接', '_handleGone();'),
        (web, 'web: 未连接返回 false', 'if (!connected || _ch == null) return false;'),
        (state, '丢帧标记字段', 'bool _customStatusLost = false;'),
        (state, '保活自愈分支', 'final lost = _customStatusLost;'),
        (state, '自愈无视门槛', 'if (!lost && DateTime.now().difference(_lastTx).inSeconds < 25) return;'),
        (state, '自愈补自定义帧', 'final re = _customStatusFrame();'),
        (state, '空文本清标记', '_customStatusLost = false;'),
        (state, '补发成功清标记', '} else if (aprs.send(re)) {'),
        (state, '保活记录失败', '_customStatusLost = !aprs.send(frame);'),
        (state, '连接时记录失败', 'if (customFrame != null) _customStatusLost = !aprs.send(customFrame);'),
    ]
    for src, label, frag in need:
        if frag not in src:
            errs.append('缺少判据片段（%s）：%s' % (label, frag))
    return errs


def _scenarios():
    t0 = datetime(2026, 1, 1, 0, 0, 0)
    out = []

    # ① 连接时自定义帧被吞 → 下一拍（15s）补自定义，且不发 CONNECT
    s = Sim('IN SHACK', t0)
    s.custom_lost = True
    a1 = s.tick(t0 + timedelta(seconds=TICK), custom_write_ok=True)
    out.append(('① 丢帧→下拍自愈', a1, s.sent, s.custom_lost))

    # ② 补发持续失败 → 每拍重试；第 3 拍成功
    s = Sim('IN SHACK', t0)
    s.custom_lost = True
    acts = [s.tick(t0 + timedelta(seconds=TICK * (i + 1)), custom_write_ok=(i >= 2))
            for i in range(3)]
    out.append(('② 连败→重试到成功', acts, s.sent, s.custom_lost))

    # ③ 自定义文本为空 → 清标记、不发（不空转）
    s = Sim('', t0)
    s.custom_lost = True
    a = s.tick(t0 + timedelta(seconds=TICK))
    out.append(('③ 空文本→清标记不发', a, s.sent, s.custom_lost))

    # ④ 链路正常：正常保活置 lost=False
    s = Sim('IN SHACK', t0)
    a = s.tick(t0 + timedelta(seconds=60))
    out.append(('④ 正常保活', a, s.sent, s.custom_lost))

    # ⑤ 未到门槛且未丢帧 → skip（不打扰）
    s = Sim('IN SHACK', t0)
    a = s.tick(t0 + timedelta(seconds=10))
    out.append(('⑤ 未到门槛', a, s.sent, s.custom_lost))
    return out


def _run_asserts():
    errs = []
    scen = {name: (a, sent, lost) for name, a, sent, lost in _scenarios()}

    a, sent, lost = scen['① 丢帧→下拍自愈']
    if a != 'heal-custom':
        errs.append('① 动作应为 heal-custom，实为 %s' % a)
    if sent != ['>IN SHACK']:
        errs.append('① 应只补自定义帧，实为 %r' % (sent,))
    if lost:
        errs.append('① 补发成功后标记应为 False')
    if any(CONNECT_FRAME in x for x in sent):
        errs.append('① 自愈时不该再发 CONNECT')

    a, sent, lost = scen['② 连败→重试到成功']
    if a != ['heal-retry', 'heal-retry', 'heal-custom']:
        errs.append('② 动作序列应为 两次 retry 后成功，实为 %r' % (a,))
    if sent != ['>IN SHACK'] or lost:
        errs.append('② 只应成功写一次并清标记，实为 sent=%r lost=%s' % (sent, lost))

    a, sent, lost = scen['③ 空文本→清标记不发']
    if a != 'clear-empty' or sent or lost:
        errs.append('③ 应清标记不发，实为 a=%s sent=%r lost=%s' % (a, sent, lost))

    a, sent, lost = scen['④ 正常保活']
    if a != 'keepalive' or lost:
        errs.append('④ 正常保活不该置 lost，实为 a=%s lost=%s' % (a, lost))
    if sent != [CONNECT_FRAME, '>IN SHACK']:
        errs.append('④ 正常保活应发 CONNECT+自定义，实为 %r' % (sent,))

    a, sent, lost = scen['⑤ 未到门槛']
    if a != 'skip' or sent:
        errs.append('⑤ 未到门槛应 skip，实为 a=%s sent=%r' % (a, sent))
    return errs


def main():
    check = '--check' in sys.argv
    for name, a, sent, lost in _scenarios():
        print('%-22s action=%-12s sent=%r lost=%s' % (name, a, sent, lost))
    if not check:
        print('\n（加 --check 作为回归测试）')
        return 0
    errs = _dart_marker_check() + _run_asserts()
    if errs:
        print('\nFAIL')
        for e in errs:
            print('  -', e)
        return 1
    print('\nALL_PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
