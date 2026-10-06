#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""碰撞/摔倒检测的**算法级仿真 + 回归断言**（issue #32 的误报修正）。

## 为什么要有它

本机跑不了 Flutter/analyze（服务同机、内存吃紧），而检测逻辑是**纯算法**，1:1 移植即可。
于是照 `sim_selffix.py` 的成例：用 Python 把判据重写一遍，喂人造加速度波形，
断言「什么该报、什么不该报」。

它盯住的核心回归（v2.0.28 → v2.0.29）：**把手机放在桌上稍微使劲，不该触发提醒。**
旧判据「冲击尖峰 + 之后静止」恰好被放手机同时满足；而且旧代码判失重用的是**去重力**
的线性加速度（静止时恒为 0），把「不动」当成了「一直在自由落体」。

## 用法

    python3 tool/sim_crash.py          # 打印各场景判定，供人看
    python3 tool/sim_crash.py --check  # 只跑回归断言（CI 用），退出码非 0 即不过

## 与源码的一致性

判据一旦和 Android(`MotionManager.kt`)/iOS(`MotionPlugin.swift`) 漂移，
这个仿真验的就是「另一个算法」，比没有更坏 —— 所以 --check 会先把常量从两处
原生源码里抠出来逐项比对（也顺带守住 Android↔iOS 的同步）。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANDROID = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'kotlin',
                       'com', 'aprslocus', 'aprslocus', 'MotionManager.kt')
IOS = os.path.join(ROOT, 'ios', 'Runner', 'MotionPlugin.swift')

G = 9.80665

# 仿真用「墙钟」基准（ms）。必须远大于任何冷却/宽限时长，因为真机时间戳是 epoch 量级
# （毫秒 13 位）；若从 0 起算，`t - last_crash` 这种差值会被冷却判据永远挡住。
CLOCK = 1_700_000_000_000

# ── 判据常量（真值取自原生源码，见 load_consts）──
SENS = {}


def _read(p):
    return io.open(p, encoding='utf-8').read()


def _kfind(src, name):
    m = re.search(r'\b' + re.escape(name) + r'\s*=\s*([0-9.]+)', src)
    return float(m.group(1)) if m else None


def load_consts():
    """从 Android/iOS 源码里读常量；两处必须都有且一致。"""
    a = _read(ANDROID)
    i = _read(IOS)
    pairs = [
        # (键, Android 名, iOS 名)
        ('gentle', 'SENS_GENTLE', 'sensGentle'),
        ('standard', 'SENS_STANDARD', 'sensStandard'),
        ('firm', 'SENS_FIRM', 'sensFirm'),
        ('freefallG', 'FREEFALL_G', 'freefallG'),
        ('freefallMinMs', 'FREEFALL_MIN_MS', 'freefallMinMs'),
        ('freefallWatchMs', 'FREEFALL_WATCH_MS', 'freefallWatchMs'),
        ('stillMs', 'STILL_MS', 'stillMs'),
        ('crashBarMult', 'CRASH_BAR_MULT', 'crashBarMult'),
        ('moveG', 'MOVE_G', 'impactMoveG'),
        ('cooldownMs', 'CRASH_COOLDOWN_MS', 'cooldownMs'),
        ('startGraceMs', 'START_GRACE_MS', 'startGraceMs'),
    ]
    bad = []
    out = {}
    for key, an, inn in pairs:
        av, iv = _kfind(a, an), _kfind(i, inn)
        if av is None:
            bad.append('Android 找不到 %s' % an)
            continue
        if iv is None:
            bad.append('iOS 找不到 %s' % inn)
            continue
        if abs(av - iv) > 1e-9:
            bad.append('%s: Android=%s iOS=%s' % (key, av, iv))
            continue
        out[key] = av
    return out, bad


def threshold(sens):
    return SENS.get(sens, SENS['standard'])


class Detector:
    """Android MotionManager.checkImpact 的 1:1 移植（时间单位 ms）。"""

    def __init__(self, sens='standard', started_at=CLOCK):
        self.sens = sens
        self.started_at = started_at
        self.freefall_start = 0
        self.last_freefall_end = 0
        self.impact_at = 0
        self.impact_kind = ''
        self.last_crash = 0
        self.seq = 0
        self.last_kind = ''

    def feed(self, t, total_g, linear_g):
        tg, lg = total_g, linear_g
        if tg <= SENS['freefallG']:
            if self.freefall_start == 0:
                self.freefall_start = t
        else:
            if self.freefall_start != 0:
                if t - self.freefall_start >= SENS['freefallMinMs']:
                    self.last_freefall_end = t
                self.freefall_start = 0

        if self.impact_at == 0:
            fall_window = (self.last_freefall_end != 0 and
                           t - self.last_freefall_end <= SENS['freefallWatchMs'])
            bar = threshold(self.sens) if fall_window else threshold(self.sens) * SENS['crashBarMult']
            if (lg >= bar and t - self.last_crash > SENS['cooldownMs'] and
                    t - self.started_at > SENS['startGraceMs']):
                self.impact_at = t
                self.impact_kind = 'fall' if fall_window else 'crash'
            return
        if lg >= SENS['moveG']:
            self.impact_at = 0
            self.impact_kind = ''
            return
        if t - self.impact_at >= SENS['stillMs']:
            self.seq += 1
            self.last_crash = t
            self.last_kind = self.impact_kind or 'crash'
            self.impact_at = 0
            self.impact_kind = ''


# ───────────────────────── 波形构造 ─────────────────────────
# 每个样本是 (t_ms, total_g, linear_g)。静止 = (1.0, 0.0)。
REST = (1.0, 0.0)


def _steps(t0, dur, dt=10):
    return list(range(t0, t0 + dur, dt))


def wave_rest(t0, dur, dt=10):
    return [(t, REST[0], REST[1]) for t in _steps(t0, dur, dt)]


def wave_impact_no_fall(t0, peak_g):
    """一次**尖锐**冲击：单个采样到 peak_g 的线性加速度，且**不失重**
    （总加速度 = 1g + 峰值，模拟「压/撞」而非「掉」）。

    为什么只给一个采样：判据里冲击后只要再出现一个 ≥ MOVE_G 的线性加速度就**撤销候选**
    （见真机「人还在动」那条）。真实尖锐冲击只占一个采样、下一拍就回到静止 ——
    这也正是「放手机」的波形，所以这里如实建模。
    """
    return [(t0, 1.0 + peak_g, peak_g)]


def wave_freefall(t0, dur=120, dt=10):
    """自由落体：总加速度接近 0（失重），线性也接近 0。"""
    return [(t, 0.12, 0.10) for t in _steps(t0, dur, dt)]


def feed_all(det, samples):
    for s in samples:
        det.feed(*s)


# ───────────────────────── 场景 ─────────────────────────
def scenarios(sens='standard'):
    """返回 {name: (detector 结果, 期望结果)}。'' 表示不报。"""
    S = CLOCK + 25000  # 初始静止，且已过启动宽限期（20s）

    def run(samples):
        d = Detector(sens=sens, started_at=CLOCK)
        feed_all(d, samples)
        return d.last_kind if d.seq else ''

    out = {}

    # 1) 放手机（轻）：2.5g 尖峰、不失重，然后一直不动
    out['setdown_light'] = (run(wave_rest(S, 500) +
                               wave_impact_no_fall(S + 500, 2.5) +
                               wave_rest(S + 600, 14000)), '')

    # 2) 放手机（稍微使劲）：5g 尖峰、不失重 —— 旧算法会误报，新算法必须不报
    out['setdown_firm_5g'] = (run(wave_rest(S, 500) +
                                 wave_impact_no_fall(S + 500, 5.0) +
                                 wave_rest(S + 600, 14000)), '')

    # 3) 很狠地放手机：8g 尖峰、不失重（标准 bar=6 达阈值 → 报「碰撞」；抗颠簸 bar=8 也达）
    out['setdown_hard_8g'] = (run(wave_rest(S, 500) +
                                 wave_impact_no_fall(S + 500, 8.0) +
                                 wave_rest(S + 600, 14000)), 'crash')

    # 4) 摔倒：自由落体 → 落地冲击 → 静止
    out['fall'] = (run(wave_rest(S, 500) +
                       wave_freefall(S + 500, 120) +
                       wave_impact_no_fall(S + 620, 6.5) +
                       wave_rest(S + 700, 14000)), 'fall')

    # 5) 车祸：无失重、强烈冲击（8g，标准 bar=6）→ 静止
    out['crash'] = (run(wave_rest(S, 500) +
                        wave_impact_no_fall(S + 500, 8.0) +
                        wave_rest(S + 600, 14000)), 'crash')

    # 6) 中等冲击、不失重（4g < 标准 bar 6）→ 不报（避免日常磕碰）
    out['moderate_bump'] = (run(wave_rest(S, 500) +
                                wave_impact_no_fall(S + 500, 4.0) +
                                wave_rest(S + 600, 14000)), '')

    # 7) 冲击后**还在动**（撤销候选）：8g 冲击后继续有明显运动 → 不报
    moved = (wave_rest(S, 500) + wave_impact_no_fall(S + 500, 8.0) +
             [(t, 1.6, 1.5) for t in _steps(S + 600, 3000, 50)] +
             wave_rest(S + 3600, 14000))
    out['impact_then_moving'] = (run(moved), '')

    # 8) 只有失重、没有落地冲击 → 不报
    out['freefall_only'] = (run(wave_rest(S, 500) +
                                wave_freefall(S + 500, 120) +
                                wave_rest(S + 700, 14000)), '')

    # 9) 冷却：一次车祸后 3 分钟内第二次强冲击不再报（seq 只能 +1）。
    #    注意第二次冲击后要补满 12s 静止，且时间要落在冷却窗内（< 180s）。
    d = Detector(sens=sens, started_at=CLOCK)
    feed_all(d, wave_rest(S, 500) + wave_impact_no_fall(S + 500, 9.0) +
             wave_rest(S + 600, 14000) +
             wave_impact_no_fall(S + 30000, 9.0) + wave_rest(S + 31000, 14000))
    out['cooldown'] = (d.seq, 1)

    # 10) 启动宽限期：开始 20 秒内的冲击不报（冲击后补满静止）
    d = Detector(sens=sens, started_at=CLOCK)
    feed_all(d, wave_rest(CLOCK, 300) + wave_impact_no_fall(CLOCK + 1000, 9.0) +
             wave_rest(CLOCK + 1100, 14000))
    out['start_grace'] = (d.seq, 0)

    return out


def check_consts():
    consts, bad = load_consts()
    SENS.clear()
    SENS.update(consts)
    return bad


def main():
    do_check = '--check' in sys.argv
    bad = check_consts()
    if bad:
        print('仿真与原生源码常量不一致（必须同步改）：')
        for b in bad:
            print('  -', b)
        return 1
    print('常量一致 ok（Android ↔ iOS ↔ 本仿真）')

    fails = []
    for sens in ('standard', 'firm'):
        res = scenarios(sens)
        print('\n[灵敏度=%s]' % sens)
        for name, (got, want) in res.items():
            if want is None:
                continue
            mark = 'ok' if got == want else 'FAIL'
            print('  %-24s got=%-8r want=%-8r %s' % (name, got, want, mark))
            if got != want:
                fails.append('%s/%s: got=%r want=%r' % (sens, name, got, want))

    if not do_check:
        return 0

    if fails:
        print('\n回归失败：')
        for f in fails:
            print('  -', f)
        return 1
    print('\n全部回归通过。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
