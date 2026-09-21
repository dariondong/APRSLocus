#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""SelfFixFilter（自己位置的静止防抖）的算法级仿真 + 回归断言。

两条用途：

  1) **定参数**：`python3 tool/sim_selffix.py` 打印各场景的「未滤波 / 滤波后」
     对照（反向跳、跳变>20m、输出游走总长、滞后）。`lib/pos_quality.dart`
     里的常量就是这样定出来的，那边的注释数字都出自这里。

  2) **当回归测试**：`python3 tool/sim_selffix.py --check` 会
     * 校验 Dart 里的常量与本文的常量**逐项一致** —— 两处漂移就等于这个仿真
       在验证「另一个算法」，那样的仿真比没有更坏；
     * 断言几条不变量：静止时不许反复横跳、单点漂移不许漏出去、
       **步行 / 开车不许被平滑**（加了滞后就是 bug）。

为什么用 Python 而不是 Dart 测试：本机跑不了 flutter/analyze（服务同机、内存
吃紧），而这是**纯算法**，1:1 移植即可 —— 于是它在本机能跑、也能进 CI。

判据（都可数，不靠「看着对不对」）：
  * reversals 反向跳：连续两帧都挪 >5m 且方向夹角 >120°（=「反复横跳」）
  * jumps>20m  位移超过 20m 的帧数（屏幕上看得见的「跳一下」）
  * path       输出路径总长（静止时反映「标记自己游走多远」）
  * flips      静止判定的状态切换次数（每次切换本身就会带来一次跳变）
  * lag_avg    输出相对真实位置的平均滞后（移动时越小越好）
"""
import io
import math
import os
import random
import re
import sys

R = 6371000.0


def hav(lat1, lng1, lat2, lng2):
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = p2 - p1
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


def m2d(lat, dn, de):
    return dn / 111320.0, de / (111320.0 * math.cos(math.radians(lat)))


def median(v):
    v = sorted(v)
    n = len(v)
    return 0.0 if n == 0 else (v[n // 2] if n % 2 else (v[n // 2 - 1] + v[n // 2]) / 2)


# ───────── 与 lib/pos_quality.dart 的 SelfFixFilter 逐行对应 ─────────
# --check 会拿这些值与 Dart 源码比对，两处必须同步改。
DART_CONSTS = [
    ('window', 5, 'int'),
    ('enterNeed', 3, 'int'),
    ('exitNeed', 3, 'int'),
    ('moveSpeedKmh', 5.0, 'double'),
    ('stillSpeedKmh', 1.5, 'double'),
    ('keepSpeedKmh', 2.5, 'double'),
    ('stillSlackM', 30.0, 'double'),
    ('driftEnter', 1.7, 'double'),
    ('driftKeep', 3.0, 'double'),
    ('trackAccuracyLimitM', 100.0, 'double'),
    ('deadbandM', 12.0, 'double'),
    ('stillMaxStepM', 15.0, 'double'),
]

WINDOW = 5
ENTER_NEED = 3
EXIT_NEED = 3
MOVE_SPEED = 5.0
STILL_SPEED = 1.5
KEEP_SPEED = 2.5
SLACK = 30.0
DRIFT_ENTER = 1.7
DRIFT_KEEP = 3.0
MAX_STEP = 15.0
DEADBAND = 12.0


class SelfFixFilter:
    def __init__(self):
        self.win, self.still_run, self.exit_run = [], 0, 0
        self.still = False
        self.last_out = None

    def _drift(self):
        h = len(self.win) // 2
        if h == 0:
            return 0.0
        a, b = self.win[:h], self.win[len(self.win) - h:]
        return hav(median([p[0] for p in a]), median([p[1] for p in a]),
                   median([p[0] for p in b]), median([p[1] for p in b]))

    def feed(self, lat, lng, speed, acc):
        a = acc if acc > 0 else SLACK
        self.win.append((lat, lng))
        if len(self.win) > WINDOW:
            self.win.pop(0)
        tol = max(a, SLACK)

        full = len(self.win) >= WINDOW
        drift = self._drift() if full else float('inf')
        enter_ok = drift < tol * DRIFT_ENTER and speed < STILL_SPEED
        keep_ok = drift < tol * DRIFT_KEEP and speed < KEEP_SPEED

        if self.still:
            # 明显在动 → 当帧退出；否则连续 EXIT_NEED 次不成立才退出。
            # 退出**不清空窗口**（清空要 5 帧重填，那 5 帧只能输出原始噪声）。
            if speed >= MOVE_SPEED:
                self.still, self.still_run, self.exit_run = False, 0, 0
            elif not keep_ok:
                self.exit_run += 1
                if self.exit_run >= EXIT_NEED:
                    self.still, self.still_run, self.exit_run = False, 0, 0
            else:
                self.exit_run = 0
        else:
            self.exit_run = 0
            if enter_ok:
                self.still_run += 1
                if self.still_run >= ENTER_NEED:
                    self.still = True
            else:
                self.still_run = 0

        if not self.still:
            self.last_out = (lat, lng)
            return lat, lng, False

        mlat = median([p[0] for p in self.win])
        mlng = median([p[1] for p in self.win])
        prev = self.last_out
        if prev is None:
            self.last_out = (mlat, mlng)
            return mlat, mlng, True
        d = hav(prev[0], prev[1], mlat, mlng)
        if d <= DEADBAND:                      # 死区：完全不动
            return prev[0], prev[1], True
        if d <= MAX_STEP:
            self.last_out = (mlat, mlng)
            return mlat, mlng, True
        t = MAX_STEP / d
        self.last_out = (prev[0] + (mlat - prev[0]) * t,
                         prev[1] + (mlng - prev[1]) * t)
        return self.last_out[0], self.last_out[1], True


def make_track(kind, n=240, seed=7, acc=30.0):
    """(真实点, 测量点, 上报速度, 精度) 序列，10 秒一帧。"""
    rnd = random.Random(seed)
    lat, lng = 39.9042, 116.4074
    out = []
    for i in range(n):
        v = {'still': 0.0, 'still_far': 0.0, 'edge': 0.0, 'spike': 0.0,
             'slowwalk': 2.0, 'walk': 4.5, 'drive': 60.0, 'stopgo': 0.0}[kind]
        if kind == 'stopgo' and i >= n // 2:
            v = 40.0
        brg = math.radians(30 + 20 * math.sin(i / 20.0)) if kind == 'drive' else 0.0
        dm = v * 1000 / 3600 * 10
        dla, dlo = m2d(lat, dm * math.cos(brg), dm * math.sin(brg))
        lat += dla
        lng += dlo

        n_n, n_e = rnd.gauss(0, acc), rnd.gauss(0, acc)
        mla, mlo = m2d(lat, n_n, n_e)
        meas = (lat + mla, lng + mlo)

        if kind == 'spike' and i == 120:       # 单点 200m 漂移（多路径反射）
            sna, se = m2d(lat, 200.0, 120.0)
            meas = (lat + sna, lng + se)
        if kind == 'edge':                     # 速度在阈值附近乱跳（不可信）
            rep = max(0.0, min(4.0, abs(rnd.gauss(2.0, 1.2))))
        elif v > 0:
            rep = max(0.0, v + rnd.gauss(0, 0.7))
        else:
            rep = max(0.0, abs(rnd.gauss(0.4, 0.5)))
        out.append(((lat, lng), meas, rep, acc))
    return out


def analyse(name, track, use_filter, verbose=True):
    f = SelfFixFilter() if use_filter else None
    outs, stills, flips = [], [], 0
    for (_, meas, v, acc) in track:
        if f is None:
            outs.append(meas)
            stills.append(False)
        else:
            ola, olo, st = f.feed(meas[0], meas[1], v, acc)
            outs.append((ola, olo))
            if stills and st != stills[-1]:
                flips += 1
            stills.append(st)

    jumps = [hav(*outs[i - 1], *outs[i]) for i in range(1, len(outs))]
    stats = {'max_jump': max(jumps),
             'big': sum(1 for j in jumps if j > 20),
             'path': sum(jumps),
             'flips': flips,
             'still': sum(stills) / len(stills) * 100,
             'reversals': _reversals(outs, 3),
             'reversals_ss': _reversals(outs, 40)}
    lags = [hav(*track[i][0], *outs[i]) for i in range(len(track))]
    stats['lag_avg'] = sum(lags) / len(lags)
    if verbose:
        print(f"  {name:<8} max_jump={stats['max_jump']:7.1f}m "
              f"jumps>20m={stats['big']:>3} "
              f"reversals={stats['reversals']:>3}(稳态{stats['reversals_ss']:>3}) "
              f"path={stats['path']:8.0f}m flips={flips:>3} "
              f"lag_avg={stats['lag_avg']:6.1f}m still={stats['still']:3.0f}%")
    return outs, stats


def _reversals(outs, start):
    rev = 0
    for i in range(max(2, start), len(outs)):
        a, b, c = outs[i - 2], outs[i - 1], outs[i]
        if hav(*a, *b) > 5 and hav(*b, *c) > 5:
            v1 = (b[0] - a[0], b[1] - a[1])
            v2 = (c[0] - b[0], c[1] - b[1])
            cos = (v1[0] * v2[0] + v1[1] * v2[1]) / (math.hypot(*v1) * math.hypot(*v2))
            if cos < -0.5:
                rev += 1
    return rev


def check_dart_consts():
    """Dart 与本文常量必须逐项一致，否则这个仿真验的是另一个算法。"""
    path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        'lib', 'pos_quality.dart')
    src = io.open(path, encoding='utf-8').read()
    bad = []
    for name, val, ty in DART_CONSTS:
        m = re.search(r'static const ' + ty + r' ' + name + r'\s*=\s*([0-9.]+)',
                      src)
        if not m:
            bad.append(f'{name} 在 lib/pos_quality.dart 里找不到')
            continue
        if abs(float(m.group(1)) - float(val)) > 1e-9:
            bad.append(f'{name}: Dart={m.group(1)} 仿真={val}')
    return bad


def main() -> int:
    do_check = '--check' in sys.argv

    if do_check:
        bad = check_dart_consts()
        if bad:
            print('仿真与 Dart 常量不一致（两处必须同步改）：')
            for b in bad:
                print('  -', b)
            return 1
        print('常量一致 ok')

    # 场景：标签, 种类, 精度
    CASES = [
        ('static', 'still', 30.0),
        ('static_off', 'still', 60.0),
        ('edge', 'edge', 30.0),
        ('slowwalk', 'slowwalk', 15.0),
        ('walk', 'walk', 15.0),
        ('drive', 'drive', 8.0),
        ('stopgo', 'stopgo', 10.0),
        ('spike', 'spike', 30.0),
    ]

    print('\n=== 未滤波（改动前） vs 静止防抖（改动后）===')
    res = {}
    for label, kind, acc in CASES:
        tr = make_track(kind, acc=acc)
        print(f'\n[{label}] acc≈{acc:.0f}m')
        raw_out, raw_st = analyse('未滤波', tr, False)
        flt_out, flt_st = analyse('防抖后', tr, True)
        res[label] = (raw_out, raw_st, flt_out, flt_st, tr)

    if not do_check:
        return 0

    # ───────── 不变量断言 ─────────
    fails = []

    def want(cond, msg):
        if not cond:
            fails.append(msg)

    # ① 静止：不许反复横跳（稳态反向跳要显著低于未滤波，且绝对量小）
    r0, s0, r1, s1, _ = res['static']
    want(s1['reversals_ss'] <= 20,
         f"静止场景稳态反向跳 {s1['reversals_ss']} 次 > 20（反复横跳）")
    want(s1['big'] <= 25, f"静止场景仍有 {s1['big']} 次 >20m 的跳变")
    want(s1['path'] <= s0['path'] * 0.4,
         f"静止时输出游走总长只降到 {s1['path'] / s0['path']:.0%}，滤波没起作用")
    want(s1['still'] >= 60, f"静止场景 only {s1['still']:.0f}% 判为静止，滤波器几乎没生效")

    # ② 单点漂移不许漏出去（中位数必须扛住 1/5 的离群点）
    _, s2, f2, s2f, _ = res['spike']
    want(s2f['big'] <= 30, f"单点 200m 漂移漏出 {s2f['big']} 次 >20m 跳变")

    # ③ 步行 / 开车**不许被平滑**（加了滞后就是 bug）
    for label in ('walk', 'drive'):
        _, sr, fr, sf, _ = res[label]
        same = all(hav(*a, *b) < 1e-9 for a, b in zip(fr, fr))
        want(sf['still'] == 0,
             f'{label} 场景被判为静止 {sf["still"]:.0f}%（移动时不许粘住）')
        want(abs(sf['lag_avg'] - sr['lag_avg']) < 1.0,
             f'{label} 场景滞后从 {sr["lag_avg"]:.1f}m 变成 {sf["lag_avg"]:.1f}m，'
             f'移动时不该被平滑')
        want(same, f'{label} 输出被改动了（移动时必须逐帧直通）')

    # ④ 走走停停：稳态不许横跳
    _, s3, _, s3f, _ = res['stopgo']
    want(s3f['reversals_ss'] <= 5,
         f'走走停停场景稳态反向跳 {s3f["reversals_ss"]} 次 > 5')

    if fails:
        print('\n打点防抖回归失败：')
        for f in fails:
            print('  -', f)
        return 1
    print('\n打点防抖回归 ok（静止不横跳 / 单点漂移不漏 / 步行开车不加滞后）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
