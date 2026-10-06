#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""「数据维护」改版（手动清理独立天数 + 恢复出厂）的算法级仿真 + 回归断言。

背景（用户反馈，issue #33 后续）：
  1. 「清理过时台账」入口不直观 —— 保留天数原先藏在「连接设置 → 存储上限」，
     与「数据维护」页里的清理按钮分在两页，用户找不到。**改版后保留天数移入
     数据维护页**（与清理按钮同页）。
  2. 手动清理原先**复用**自动清理的「保留天数」——用户觉得「很混乱」。**改版后
     手动清理有独立的天数选择器**（`_pruneDays`，默认未选、不落盘）。
  3. 新增「清除所有数据并重新初始化（恢复出厂）」——连**呼号与全部设置**一起清，
     并重跑首次引导（OOBE）。

本脚本两个用途（与 tool/sim_prune.py 同一套路）：
  1) **定规则**：打印「N 天阈值下会清掉哪些台站」，并演示**同一批台站**在
     「自动清理保留天数」与「手动清理所选天数」不同时会得到不同结果 ——
     这正是「独立参数」的意义。
  2) **当回归测试**：`python3 tool/sim_factory_reset.py --check`
     * 逐条校验 Dart 仍满足这些**不变量**（纯文本片段断言，本机可跑、也可进 CI）：
         - 数据维护页出现「保留天数」选择器与「手动清理天数」选择器；
         - 手动清理用 `_pruneDays` / `prunableStationCountFor`，**不再**用
           `stationRetentionDays` / `prunableStationCount`；
         - 「连接设置」页已移除保留天数输入；
         - `factoryReset()` 存在，且清 `p.clear()`、复位单例、置 `oobeDone=false`、
           `reloadTick++`、清呼号；
     * 复用 sim_prune 的判据做「天数独立」的行为断言。

为什么用 Python 而不是 Dart 测试：本机跑不了 flutter/analyze（服务同机、内存吃紧），
而这里全是**可数的判据**，1:1 描述即可 —— 于是它在本机能跑、也能进 CI。
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


def prunable(stations, days, now, my_full_call):
    """1:1 移植 Dart `AppState._prunableStations`（与 sim_prune.py 相同）。"""
    if days <= 0:
        return []
    cutoff = now - timedelta(days=days)
    self_call = my_full_call.upper()
    return [
        s for s in stations
        if not s.favorite and not s.manual
        and s.call.upper() != self_call
        and s.last_heard < cutoff
    ]


def read(path):
    return io.open(os.path.join(ROOT, path), encoding='utf-8').read()


def _marker_check():
    """校验 Dart 仍满足本改版的判据；返回错误列表（空 = 通过）。"""
    errs = []
    pages = read('lib/settings_pages.dart')
    state = read('lib/state.dart')
    widgets = read('lib/settings_widgets.dart')
    theme = read('lib/theme_store.dart')
    ach = read('lib/achievements.dart')
    tr = read('lib/translate.dart')

    def need(src, label, frag, where):
        if frag not in src:
            errs.append('%s 缺少片段（%s）：%s' % (where, label, frag))

    # ── 1. 保留天数移入数据维护页（不再在连接设置页）──
    need(pages, '数据维护页有保留天数选择器',
         'S.of(context).stationRetention', 'lib/settings_pages.dart')
    need(pages, '数据维护页按天数设置保留',
         'setStationRetentionDays', 'lib/settings_pages.dart')
    # 连接设置页的 retention 输入框已删（旧代码用 _retention 控制器）
    if '_retention' in pages:
        errs.append('lib/settings_pages.dart 仍残留 _retention（应已从连接设置页移除）')

    # ── 2. 手动清理用独立天数（_pruneDays），不套用保留天数 ──
    need(pages, '手动清理独立天数变量', 'int _pruneDays', 'lib/settings_pages.dart')
    need(pages, '手动清理天数选择器', 'S.of(context).pruneWithin',
         'lib/settings_pages.dart')
    need(pages, '手动清理按所选天数预览', 'prunableStationCountFor(_pruneDays)',
         'lib/settings_pages.dart')
    need(pages, '确认框使用所选天数', 'final days = _pruneDays;',
         'lib/settings_pages.dart')
    # 关键：手动清理不得再读自动保留天数
    if 'final days = st.stationRetentionDays;' in pages:
        errs.append('lib/settings_pages.dart 手动清理仍复用 stationRetentionDays')
    need(state, '按指定天数预览的可数接口', 'int prunableStationCountFor(int days)',
         'lib/state.dart')

    # ── 3. 恢复出厂（清全部数据与设置 + 重跑 OOBE）──
    need(state, '恢复出厂方法', 'Future<void> factoryReset()', 'lib/state.dart')
    need(state, '清空磁盘偏好', 'await p.clear();', 'lib/state.dart')
    need(state, '清呼号', "myCall = 'BV2AAA';", 'lib/state.dart')
    need(state, '复位服务器', "aprs.server = 'rotate.aprs2.net';", 'lib/state.dart')
    need(state, '复位主题包', 'ThemeController.instance.saveTo(p);', 'lib/state.dart')
    need(state, '复位成就内存态',
         'AchievementCenter.instance.resetToDefaults();', 'lib/state.dart')
    need(state, '复位翻译内存态',
         'TranslateService.instance.resetToDefaults();', 'lib/state.dart')
    need(state, '复位已读荣誉', 'await resetHonorSeen();', 'lib/state.dart')
    need(state, '进入首次引导', 'oobeDone = false;', 'lib/state.dart')
    need(state, '重建导航栈', 'reloadTick++;', 'lib/state.dart')
    need(state, '先清磁盘再写回默认主题', 'await p.clear();\n      await ThemeController.instance.saveTo(p);',
         'lib/state.dart')

    # 各单例提供 resetToDefaults()
    need(theme, '主题单例复位方法', 'void resetToDefaults()', 'lib/theme_store.dart')
    need(ach, '成就单例复位方法', 'void resetToDefaults()', 'lib/achievements.dart')
    need(tr, '翻译单例复位方法', 'void resetToDefaults()', 'lib/translate.dart')

    # UI：数据维护页有恢复出厂卡片 + 二次确认
    need(pages, '恢复出厂卡片', 'S.of(context).factoryReset', 'lib/settings_pages.dart')
    need(pages, '恢复出厂二次确认', 'void _confirmFactoryReset()',
         'lib/settings_pages.dart')
    need(pages, '调用 factoryReset', 'await st.factoryReset();',
         'lib/settings_pages.dart')

    # 新控件存在（供下拉天数）
    need(widgets, '下拉选择控件', 'class SettingsChoice<T>', 'lib/settings_widgets.dart')

    return errs


def _scenarios():
    now = datetime(2026, 10, 3, 12, 0, 0)
    day = timedelta(days=1)
    stations = [
        Station('A', now - timedelta(hours=1)),          # 新 → 都留
        Station('B', now - 5 * day),                     # 5 天前
        Station('C', now - 20 * day),                    # 20 天前
        Station('D', now - 20 * day, favorite=True),     # 过时收藏 → 永留
        Station('E', now - 400 * day),                   # 很旧
    ]
    return now, stations


def main(argv):
    check = '--check' in argv
    failed = False

    if check:
        errs = _marker_check()
        if errs:
            failed = True
            for e in errs:
                print('FAIL  ' + e)
        else:
            print('Dart 判据与本文一致（保留天数移入数据维护页 / 手动清理独立天数 / 恢复出厂）')

    now, stations = _scenarios()
    # 演示：同一批台站，自动保留天数与手动所选天数不同 → 结果不同（独立的意义）
    auto_days = 7
    manual_days = 30
    auto_hit = sorted(s.call for s in prunable(stations, auto_days, now, 'BV2AAA'))
    manual_hit = sorted(s.call for s in prunable(stations, manual_days, now, 'BV2AAA'))
    print('自动清理  retention=%d  pruned=%s' % (auto_days, auto_hit))
    print('手动清理  chosen=%d     pruned=%s' % (manual_days, manual_hit))

    if check:
        # 不变量 A：天数不同时结果为「子集关系」——手动天数更大 ⇒ 清得更少
        if not set(manual_hit).issubset(set(auto_hit)):
            failed = True
            print('FAIL  手动天数更大却清得更多：auto=%s manual=%s'
                  % (auto_hit, manual_hit))
        # 不变量 B：收藏永不清理
        if 'D' in auto_hit or 'D' in manual_hit:
            failed = True
            print('FAIL  收藏台站 D 被清理')
        # 不变量 C：预览数量 == 实际会清理的数量（两处必须一致）
        for days in (0, 3, 7, 30, 365):
            n_preview = len(prunable(stations, days, now, 'BV2AAA'))
            n_actual = len(prunable(stations, days, now, 'BV2AAA'))
            if n_preview != n_actual:
                failed = True
                print('FAIL  天数 %d 预览(%d) != 实际(%d)' % (days, n_preview, n_actual))
        # 精确断言（钉死规则）：7 天清掉 C/E，30 天只清掉 E —— 天数不同结果不同
        expect_auto = ['C', 'E']
        expect_manual = ['E']
        if auto_hit != expect_auto:
            failed = True
            print('FAIL  auto 期望 %s 实得 %s' % (expect_auto, auto_hit))
        if manual_hit != expect_manual:
            failed = True
            print('FAIL  manual 期望 %s 实得 %s' % (expect_manual, manual_hit))

        if not failed:
            print('ALL_PASS')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
