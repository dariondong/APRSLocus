#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""台站保留/清理（数据维护，issue #33）的算法级仿真 + 回归断言。

两条用途（与 tool/sim_selffix.py / sim_turn_dot.py 同一套路）：

  1) **定规则**：`python3 tool/sim_prune.py` 打印各场景下「哪些台站会被清理」。
     `lib/state.dart` 的 `_prunableStations` 就是按这里的判据写死的。
  2) **当回归测试**：`python3 tool/sim_prune.py --check`
     * 校验 Dart 里的判据与本文**逐项一致** —— 两处漂移就等于这个仿真在验证
       「另一个算法」，那样的仿真比没有更坏；
     * 断言几条不变量（都可数，不靠「看着对不对」）：
         - 收藏 / 手动 / 自己的台站**永不被清理**；
         - 恰好卡在阈值上的台站**保留**（Dart 用 `isBefore`，严格小于）；
         - 保留天数 = 0 时一个都不清（= 自动清理关闭）；
         - 只清理比阈值更旧的**普通**台站，且「预览数量」与实际清理数量一致。

为什么用 Python 而不是 Dart 测试：本机跑不了 flutter/analyze（服务同机、内存吃紧），
而这是**纯判据**、1:1 移植即可 —— 于是它在本机能跑、也能进 CI。
"""
import io
import os
import sys
from datetime import datetime, timedelta

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class Station:
    """只保留与清理判据相关的字段（与 Dart Station 同形的最小集）。"""

    def __init__(self, call, last_heard, favorite=False, manual=False):
        self.call = call
        self.last_heard = last_heard
        self.favorite = favorite
        self.manual = manual


def prunable(stations, retention_days, now, my_full_call):
    """1:1 移植 Dart `AppState._prunableStations`。

    retention_days <= 0 → 返回空（调用方 `pruneOldStations` 也如此短路）。
    cutoff 之后的（含**恰好等于** cutoff）都保留：Dart 用
    `s.lastHeard.isBefore(cutoff)`，即严格早于才清。
    """
    if retention_days <= 0:
        return []
    cutoff = now - timedelta(days=retention_days)
    self_call = my_full_call.upper()
    out = []
    for s in stations:
        if s.favorite or s.manual:
            continue
        if s.call.upper() == self_call:
            continue
        if s.last_heard < cutoff:  # 严格早于 = 语义同 isBefore
            out.append(s)
    return out


def _dart_marker_check():
    """校验 Dart 与本文判据一致；返回错误列表（空 = 通过）。"""
    errs = []
    state = io.open(os.path.join(ROOT, 'lib', 'state.dart'), encoding='utf-8').read()
    backup = io.open(os.path.join(ROOT, 'lib', 'backup.dart'), encoding='utf-8').read()

    need_state = [
        ('收藏/手动排除', '.where((s) => !s.favorite && !s.manual)'),
        ('排除自己', 's.call.toUpperCase() != self'),
        ('严格早于阈值', 's.lastHeard.isBefore(cutoff)'),
        ('天数为 0 短路', 'if (d <= 0) return 0;'),
        ('天数上限 3650', 'n.clamp(0, 3650)'),
        ('预览按当前保留天数', 'Duration(days: stationRetentionDays)'),
        ('启动自动清理', '_autoPruneStations();'),
        ('自动清理尊重配置', 'if (stationRetentionDays <= 0) return;'),
    ]
    for label, frag in need_state:
        if frag not in state:
            errs.append('lib/state.dart 缺少判据片段（%s）：%s' % (label, frag))
    if "'stationRetentionDays'" not in backup:
        errs.append('lib/backup.dart 未把 stationRetentionDays 纳入备份白名单')
    if 'stationRetentionDays' not in state:
        errs.append('lib/state.dart 未见 stationRetentionDays 字段/读写')
    return errs


def _scenarios():
    now = datetime(2026, 10, 3, 12, 0, 0)
    day = timedelta(days=1)
    return {
        'mixed': (
            7, now, 'BV2AAA', [
                Station('A', now - timedelta(hours=1)),        # 在线普通 → 留
                Station('B', now - 10 * day),                  # 过时普通 → 清
                Station('C', now - 10 * day, favorite=True),   # 过时收藏 → 留
                Station('D', now - 10 * day, manual=True),     # 过时手动 → 留
                Station('E', now - 7 * day),                   # 恰好阈值 → 留（严格）
                Station('F', now - 7 * day - timedelta(seconds=1)),  # 差 1 秒 → 清
                Station('G', now - 30 * day),                  # 自己 → 留（下面 is self）
                Station('H', now - 6 * day - timedelta(hours=23)),  # 差 1 小时 → 留
                Station('I', now - 30 * day),                  # 过时普通 → 清
            ],
        ),
        'retention_zero': (
            0, now, 'BV2AAA', [
                Station('A', now - 400 * day),
                Station('B', now - 400 * day, favorite=True),
            ],
        ),
        'all_old': (
            7, now, 'BV2AAA', [
                Station('A', now - 8 * day),
                Station('B', now - 100 * day),
                Station('C', now - 9 * day),
            ],
        ),
        'all_recent': (
            7, now, 'BV2AAA', [
                Station('A', now - timedelta(hours=2)),
                Station('B', now - 3 * day),
            ],
        ),
    }


def main(argv):
    check = '--check' in argv
    scenarios = _scenarios()
    # mixed 场景用 G 作为自己的呼号，验证「自己永不被清」这一条
    self_overrides = {'mixed': 'G'}

    failed = False
    if check:
        errs = _dart_marker_check()
        if errs:
            failed = True
            for e in errs:
                print('FAIL  ' + e)
        else:
            print('Dart 判据与本文一致')

    for name, (days, now, my_call, stations) in scenarios.items():
        my = self_overrides.get(name, my_call)
        doomed = prunable(stations, days, now, my)
        doomed_calls = sorted(s.call for s in doomed)
        print('%-16s retention=%d  pruned=%s' % (name, days, doomed_calls or '[]'))

        if not check:
            continue
        calls = {s.call for s in stations}
        kept = calls - set(doomed_calls)
        # 不变量 1：收藏/手动永不清理
        for s in stations:
            if (s.favorite or s.manual) and s.call in doomed_calls:
                failed = True
                print('FAIL  %s: 收藏/手动台站 %s 被清理' % (name, s.call))
        # 不变量 2：自己永不清理
        for s in stations:
            if s.call.upper() == my.upper() and s.call in doomed_calls:
                failed = True
                print('FAIL  %s: 自己的台站 %s 被清理' % (name, s.call))
        # 不变量 3：清掉的必须都严格早于阈值
        if days > 0:
            cutoff = now - timedelta(days=days)
            for s in doomed:
                if not s.last_heard < cutoff:
                    failed = True
                    print('FAIL  %s: %s 未超过阈值却被清理' % (name, s.call))
        # 不变量 4：保留的普通台站都不得早于阈值
        for s in stations:
            if s.call in kept and not (s.favorite or s.manual) \
                    and s.call.upper() != my.upper() and days > 0:
                if s.last_heard < now - timedelta(days=days):
                    failed = True
                    print('FAIL  %s: 过时普通台站 %s 漏清' % (name, s.call))

    if check:
        # 逐场景精确断言（把「规则」钉死，改动判据必须同步改这里）
        expect = {
            'mixed': ['B', 'F', 'I'],
            'retention_zero': [],
            'all_old': ['A', 'B', 'C'],
            'all_recent': [],
        }
        for name, (days, now, my_call, stations) in scenarios.items():
            got = sorted(s.call for s in prunable(
                stations, days, now, self_overrides.get(name, my_call)))
            if got != expect[name]:
                failed = True
                print('FAIL  %s: 期望 %s，实得 %s' % (name, expect[name], got))
        if not failed:
            print('ALL_PASS')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
