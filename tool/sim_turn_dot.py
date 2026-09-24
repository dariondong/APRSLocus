#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""「按航向变化打点」（转弯补点）的算法级仿真 + 回归断言。

两条用途（与 tool/sim_selffix.py 同一套路）：

  1) **定参数**：`python3 tool/sim_turn_dot.py` 把「旧算法（v1.6.156 起）」与
     「新算法」逐场景、逐配置对比。`lib/turn_dot.dart` 里的常量就是这么定的
     —— 那边注释里的数字都出自这里。
  2) **当回归测试**：`python3 tool/sim_turn_dot.py --check`：校验 Dart 常量与
     本文一致、状态层真的接上了线，并断言几条可数的不变量。

为什么用 Python 而不是 Dart 测试：本机跑不了 flutter/analyze（服务同机、内存
吃紧），而这是**纯算法**、1:1 移植即可 —— 于是它在本机能跑、也能进 CI。

## 判据（都可数，不靠「看着对不对」）

* `dots` 转弯触发的点数。APRS 是共享信道，**点多就是坏**，所以它是成本。
* `sag`  地图上的**错**：相邻两个发出的点连成直线后，中间那段真实路径离这条
        直线的最大垂距（米）。也就是「拐弯被拉直」的量化版本 —— 一个 200m 的
        发卡弯被一根直线取代，弦高就是 100m 量级，用户一眼就能看出来。
* `base` 同一档位、**关掉转弯判据**（只用定时+距离）时的同一组数字。转弯判据的
        全部价值就是把 sag 从 base 压下来；没有 base 就没法说明它到底有没有用。

## 两个必须一起看的坑（第一版仿真就栽在这两条上）

* **噪声会伪造精度**：旧算法在直路/连续弯上会**被 2 帧的多径野值触发**，
  多发的那几个点让 sag 变小 —— 看起来「更准」，实际是花信道买了个假精度。
  所以每个场景都要跑「无噪声」和「含噪声」两遍，分开下结论。
* **仿真自己也要被验证**：`--check` 里的自检断言「新流程在退化配置
  （门=∞、不平滑、不确认）下与旧算法**逐点相同**」。第一版仿真把噪声加在了
  *真实*航向上，于是「弯顶」被噪声凭空造出来，直路场景也能数出 20 多个弯 ——
  指标全是假的，而且看起来毫无异常。
"""
import io
import math
import os
import random
import re
import sys

# ───────── 与 lib/turn_dot.dart 的 TurnDotDetector 逐行对应 ─────────
# --check 会拿这些值与 Dart 源码比对，两处必须同步改。
DART_CONSTS = [
    ('maxStepDeg', 40.0, 'double'),
    ('maxDrops', 3, 'int'),
]

# 物理门：[maxStepDeg] = 1Hz 采样下「一帧航向变化」的物理上限，超过它的帧一律
# 当成野值丢掉；[maxDrops] = 连续丢多少帧后强制重新同步（不设上限会永久失明）。
MAX_STEP_DEG = 40.0
MAX_DROPS = 3

# 转弯打点的最小间隔（秒）。**本次不动它**：与 v1.6.156 起的取值一致，
# 仿真里 5s/10s/20s 都试过，收紧它只会在 mountain/hairpin 上多花信道、弦高无改善。
TURN_MIN_GAP_SEC = 20.0
MIN_SPEED_KMH = 5.0


def fold180(d):
    """折到 0~180（最小夹角）：359° → 1° 是转了 2°，不是 358°。"""
    d = abs(d) % 360.0
    return 360.0 - d if d > 180.0 else d


def _signed(d):
    d = d % 360.0
    return d - 360.0 if d > 180.0 else d


def circ_median(v):
    """环绕安全的中位数：以**最新**样本为参考折算后再取中位数。

    直接对角度排序会在 0/360 接缝上错（[350, 5, 8] 的中位数会算成 350）。
    """
    if not v:
        return None
    ref = v[-1]
    rel = sorted(_signed(a - ref) for a in v)
    return (ref + rel[len(rel) // 2]) % 360.0


class Detector:
    """新算法：**只加一道物理门**（与 lib/turn_dot.dart 1:1）。

    判据本身（基准航向、阈值、20s 闸门、5km/h 速度闸）一律**不动** —— 仿真里
    逐项比过：动它们中的任何一个，都会在某个弯道场景上把弦高做坏
    （见 main() 打印的对照表与 CHANGELOG）。这里只干一件事：

      把「物理上不可能的一帧航向」丢掉（低速多径、地库出口、静止时 GPS 报 0°）。

    两个不变量：

    * **航向干净时它是直通的**：无噪声场景下，开关这道门的结果**逐点相同**
      （自检会断言）；所以它不可能把「本来就准」的场景改坏。
    * **连续丢弃有上限**（[maxDrops]）：一个持续 >40°/s 的真实转向会让每一帧
      都相对上一个可信值超限 —— 不设上限就会**永久失明**（`last` 卡在转向前
      的航向上，之后再也不会更新，整个功能彻底失效）。到上限就重新同步。
    """

    def __init__(self, gate=MAX_STEP_DEG, max_drops=MAX_DROPS):
        self.gate, self.max_drops = gate, max_drops
        self.last, self.ref, self.dev, self.drops = None, None, 0.0, 0

    def on_course(self, course, threshold=0, dt=1.0):
        """[dt] = 距上一帧多少秒；门按 gate × max(1, dt) 折算（1Hz 时就是 gate）。"""
        if course is None:
            return
        if self.last is not None and \
                fold180(course - self.last) > self.gate * max(1.0, dt):
            self.drops += 1
            if self.drops < self.max_drops:
                return                     # 丢帧，且**不动 last**
        self.drops = 0                     # 重新同步
        self.last = course
        if self.ref is None:
            self.ref, self.dev = course, 0.0
            return
        self.dev = fold180(course - self.ref)

    def mark_sent(self):
        """真的发出去之后调用：基准 ← **上一个可信航向**，判据归零。

        基准取 `self.last`（过了物理门的那一帧）而不是调用方手里的原始航向：
        否则「发出这一帧时航向正好是野值」会把野值钉成基准 —— 之后真实航向与
        它相差 60°，于是凭空触发一轮补点。野值不该有机会成为基准，
        这与物理门是同一件事的两面。
        """
        if self.last is not None:
            self.ref = self.last
        self.dev = 0.0


def m2d(lat, dn, de):
    return dn / 111320.0, de / (111320.0 * math.cos(math.radians(lat)))


# ───────────────────────── 场景 ─────────────────────────
# 每个场景带上它该用的档位：转弯判据的效果**强依赖档位**（同一段路跑 30 与
# 90 km/h 落在不同档上，阈值/间隔/距离门限都不同）。
# tier = (intervalSec, minDistM, minTurnDeg)，取 defaultSmartTiers() 的默认值。
SCENES = {
    'straight_urban': dict(sigma=8.0, burst_p=0.02, burst_deg=60.0, burst_n=2,
                           tier=(60.0, 400.0, 45.0)),
    'straight_high': dict(sigma=5.0, burst_p=0.005, burst_deg=45.0, burst_n=1,
                          tier=(30.0, 700.0, 30.0)),
    'hairpin': dict(sigma=7.0, burst_p=0.01, burst_deg=40.0, burst_n=1,
                    tier=(60.0, 400.0, 45.0)),
    'mountain': dict(sigma=7.0, burst_p=0.02, burst_deg=40.0, burst_n=2,
                     tier=(60.0, 400.0, 45.0)),
    'ramp_high': dict(sigma=5.0, burst_p=0.005, burst_deg=40.0, burst_n=1,
                      tier=(30.0, 700.0, 30.0)),
    'scurve': dict(sigma=7.0, burst_p=0.01, burst_deg=40.0, burst_n=1,
                   tier=(60.0, 400.0, 45.0)),
    'stopped': dict(sigma=25.0, burst_p=0.05, burst_deg=70.0, burst_n=2,
                    tier=(300.0, 200.0, 0.0)),
}
CASES = ['straight_urban', 'straight_high', 'hairpin', 'mountain', 'ramp_high',
         'scurve', 'stopped']
TURN_CASES = ['hairpin', 'mountain', 'ramp_high', 'scurve']
CLEAN_CASES = ['straight_urban', 'straight_high', 'stopped']
N_FRAMES = 960          # 960 帧 = 16 分钟（1Hz）


def heading_profile(kind, n):
    """(真实航向°, 速度km/h) —— 1Hz。"""
    out = []
    for i in range(n):
        t = float(i)
        if kind == 'straight_urban':
            h, v = 0.0, 32.0
        elif kind == 'straight_high':
            h, v = 90.0, 90.0
        elif kind == 'hairpin':
            # 60 秒一个 90° 发卡弯（弯本身 4 秒）。**航向必须连续**：
            # 每过一个周期再减 90°，而不是回到 0 —— 第一版就是让它回到 0，
            # 于是无噪声场景里也有 15 帧「一帧跳 90°」的物理不可能跳变，
            # 而物理门把这些帧全丢了 —— 量出来的「新算法变差」全是这个 bug。
            ph = t % 60.0
            base = -90.0 * (t // 60)
            if 20.0 <= ph < 24.0:
                h = base - 90.0 * (ph - 20.0) / 4.0
            else:
                h = base - (90.0 if ph >= 24.0 else 0.0)
            v = 30.0
        elif kind == 'mountain':
            h = 60.0 * math.sin(2 * math.pi * t / 40.0)   # ±60°、周期 40 秒
            v = 25.0
        elif kind == 'ramp_high':
            # 90km/h 出口匝道：30° 用了 4 秒（同样要连续，见 hairpin 的注释）
            ph = t % 50.0
            base = -30.0 * (t // 50)
            if 10.0 <= ph < 14.0:
                h = base - 30.0 * (ph - 10.0) / 4.0
            else:
                h = base - (30.0 if ph >= 14.0 else 0.0)
            v = 90.0
        elif kind == 'scurve':
            ph = t % 40.0                       # 40km/h：先左 50° 再右 50°，共 8 秒
            if 10.0 <= ph < 14.0:
                h = -50.0 * (ph - 10.0) / 4.0
            elif 14.0 <= ph < 18.0:
                h = -50.0 + 50.0 * (ph - 14.0) / 4.0
            else:
                h = 0.0
            v = 40.0
        elif kind == 'stopped':
            h, v = 0.0, 0.0
        else:
            raise ValueError(kind)
        out.append((h % 360.0, v))
    return out


def make_run(kind, n=N_FRAMES, seed=11, clean=False):
    """(真实纬度, 真实经度, 上报航向, 上报速度)。

    [clean] = True 时关掉一切噪声（σ=0、无野值）—— 把「算法本身的行为」与
    「噪声带来的假象」分开看（见文件头「噪声会伪造精度」）。
    噪声只加在**上报**航向上，位置始终按真实航向推进。
    """
    rnd = random.Random(seed)
    cfg = dict(SCENES[kind])
    if clean:
        cfg['sigma'], cfg['burst_p'] = 0.0, 0.0
    lat, lng = 39.9042, 116.4074
    rows = []
    burst_left, burst_val = 0, 0.0
    for (h_true, v) in heading_profile(kind, n):
        rep = h_true
        if burst_left > 0:
            rep += burst_val
            burst_left -= 1
        elif rnd.random() < cfg['burst_p']:
            burst_val = rnd.choice([-1, 1]) * cfg['burst_deg']
            burst_left = cfg['burst_n'] - 1
            rep += burst_val
        rows.append((lat, lng, (rep + rnd.gauss(0, cfg['sigma'])) % 360.0,
                     max(0.0, v + rnd.gauss(0, 0.6))))
        dm = v * 1000 / 3600.0
        dla, dlo = m2d(lat, dm * math.cos(math.radians(h_true)),
                       dm * math.sin(math.radians(h_true)))
        lat += dla
        lng += dlo
    return rows


def run_algo(rows, algo, tier, gap_sec, det=None):
    """「定时 / 距离 / 转弯」三路判据 → (发出的帧号, 其中转弯触发的帧号)。"""
    interval, min_dist_m, min_turn_deg = tier
    if algo == 'new' and det is None:
        det = Detector()
    old_ref = [rows[0][2] if rows else None]
    since = 0.0
    last_pos = (rows[0][0], rows[0][1])
    sends, turn_sends = [], []
    for i, (lat, lng, rep_h, v) in enumerate(rows):
        since += 1.0
        if algo == 'new' and v >= MIN_SPEED_KMH:
            det.on_course(rep_h, min_turn_deg)
        if min_turn_deg <= 0 or since < gap_sec or v < MIN_SPEED_KMH:
            due_turn = False
        elif algo == 'old':
            due_turn = fold180(rep_h - old_ref[0]) >= min_turn_deg
        elif algo == 'none':
            due_turn = False
        else:
            due_turn = det.dev >= min_turn_deg
        moved = math.hypot(lat - last_pos[0], lng - last_pos[1]) * 111320.0
        due = (since >= interval) or (min_dist_m > 0 and moved >= min_dist_m) or due_turn
        if due:
            sends.append(i)
            if due_turn:
                turn_sends.append(i)
            since = 0.0
            last_pos = (lat, lng)
            if algo == 'old':
                old_ref[0] = rep_h
            elif algo == 'new':
                det.mark_sent()
    return sends, turn_sends


def sag_stats(rows, sends):
    """(最大弦高, 平均弦高)（米）。

    用「最大」单个数字会失真：它是所有区间里的**极值**，一个长区间（比如刚好
    跨过一个弯）就能定调 —— 含噪声场景里新旧算法点数只差几个，却会让最大弦高
    从 83m 跳到 229m，读起来像是「新算法坏了」。平均弦高用来交叉验证；
    两个指标方向不一致时就回去看逐帧轨迹，不要直接下结论。
    """
    def xy(i):
        return (rows[i][1] * 111320.0 * math.cos(math.radians(rows[i][0])),
                rows[i][0] * 111320.0)
    worst, tot, n = 0.0, 0.0, 0
    for a, b in zip(sends, sends[1:]):
        if b - a < 2:
            continue
        ax, ay = xy(a)
        bx, by = xy(b)
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        if L2 <= 0:
            continue
        seg = 0.0
        for k in range(a + 1, b):
            px, py = xy(k)
            t = ((px - ax) * dx + (py - ay) * dy) / L2
            t = 0.0 if t < 0 else (1.0 if t > 1 else t)
            d = math.hypot(px - (ax + t * dx), py - (ay + t * dy))
            if d > seg:
                seg = d
        if seg > worst:
            worst = seg
        tot += seg
        n += 1
    return worst, (tot / n if n else 0.0)


def analyse(kind, rows, algo, gap_sec, det=None, tier=None):
    tier = tier or SCENES[kind]['tier']
    sends, turn = run_algo(rows, algo, tier, gap_sec, det)
    worst, avg = sag_stats(rows, sends)
    return dict(dots=len(turn), total=len(sends), sag=worst, sag_avg=avg)


def cells(kind, clean, spec):
    """spec = (algo, gap, (gate, window, confirm) or None)"""
    algo, gap, cfg = spec
    rows = make_run(kind, clean=clean)
    det = None if cfg is None else Detector(*cfg)
    r = analyse(kind, rows, algo, gap, det)
    return r


def check_dart_consts():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = os.path.join(root, 'lib', 'turn_dot.dart')
    if not os.path.exists(path):
        return ['lib/turn_dot.dart 不存在']
    src = io.open(path, encoding='utf-8').read()
    bad = []
    for name, val, ty in DART_CONSTS:
        m = re.search(r'static const ' + ty + r'\s+' + name + r'\s*=\s*([0-9.]+)', src)
        if not m:
            bad.append('%s 在 lib/turn_dot.dart 里找不到' % name)
            continue
        if abs(float(m.group(1)) - float(val)) > 1e-9:
            bad.append('%s: Dart=%s 仿真=%s' % (name, m.group(1), val))
    st = io.open(os.path.join(root, 'lib', 'state.dart'), encoding='utf-8').read()
    for needle, why in (
        ('TurnDotDetector', '状态层没有用 TurnDotDetector —— 算法没接线'),
        ('_turnDot.onCourse', '没有把 1Hz 航向喂进检测器 —— 这道门等于没上'),
        ('_turnDot.markSent', '发送后没有复位检测器 —— 基准航向会一直是旧的'),
    ):
        if needle not in st:
            bad.append('lib/state.dart 里找不到 `%s`：%s' % (needle, why))
    return bad


def main() -> int:
    do_check = '--check' in sys.argv
    if do_check:
        bad = check_dart_consts()
        if bad:
            print('仿真与 Dart 不一致（两处必须同步改）：')
            for b in bad:
                print('  -', b)
            return 1
        print('常量与接线一致 ok')

    # ───────── 自检：退化配置必须复现旧算法 ─────────
    fails = []

    def want(cond, msg):
        if not cond:
            fails.append(msg)

    print('=== 自检：把物理门放到无穷大（等于没有它）时，新流程与旧算法逐点比对 ===')
    mismatch = 0
    for clean in (False, True):
        for k in CASES:
            rows = make_run(k, clean=clean)
            a = analyse(k, rows, 'old', TURN_MIN_GAP_SEC)
            b = analyse(k, rows, 'new', TURN_MIN_GAP_SEC,
                        Detector(gate=1e9, max_drops=10 ** 9))
            if (a['dots'], a['total']) != (b['dots'], b['total']) or \
                    abs(a['sag'] - b['sag']) > 1e-6:
                mismatch += 1
                print('  不一致 %-15s clean=%-5s 旧 %2d/%2d %6.1fm  新 %2d/%2d %6.1fm'
                      % (k, clean, a['dots'], a['total'], a['sag'],
                         b['dots'], b['total'], b['sag']))
    want(mismatch == 0, '退化配置没能复现旧算法（%d 处）—— 仿真本身不可信' % mismatch)
    print('  自检 %s' % ('通过' if mismatch == 0 else '失败'))

    # 只改**噪声过滤**（物理门），闸门与档位全部保持不变 ——
    # 这样表里每一行的差异都只归因于这道门。
    CONFIGS = [
        ('旧 20s（现状）', 'old', TURN_MIN_GAP_SEC, None),
        ('新 门40', 'new', TURN_MIN_GAP_SEC, (40.0, 3)),
        ('新 门25', 'new', TURN_MIN_GAP_SEC, (25.0, 3)),
        ('新 门60', 'new', TURN_MIN_GAP_SEC, (60.0, 3)),
        ('新 门40 不重同步', 'new', TURN_MIN_GAP_SEC, (40.0, 10 ** 9)),
    ]

    for clean in (False, True):
        print('\n===== %s =====' % ('无噪声：只看算法本身' if clean else '含噪声：真机'))
        print('%-18s' % '配置' + ''.join('%-18s' % k for k in CASES))
        print('%-18s' % '' + ''.join('%-18s' % '点/sag' for k in CASES))
        for label, algo, gap, cfg in CONFIGS:
            line = '%-18s' % label
            for k in CASES:
                r = cells(k, clean, (algo, gap, cfg))
                line += '%-20s' % ('%2d点 %6.1f/%5.1fm'
                                   % (r['dots'], r['sag'], r['sag_avg']))
            print(line)

    # 基线（关掉转弯判据）——「转弯判据到底有没有用」的唯一参照
    base = {}
    for clean in (False, True):
        for k in CASES:
            base[(k, clean)] = analyse(k, make_run(k, clean=clean), 'none',
                                       TURN_MIN_GAP_SEC)
    print('\n=== 基线（关掉转弯判据，只用定时+距离）===')
    for clean in (False, True):
        tag = '无噪声' if clean else '含噪声'
        print('  %s: %s' % (tag, '  '.join(
            '%s %2d点 %6.1f/%5.1fm' % (k, base[(k, clean)]['total'],
                                       base[(k, clean)]['sag'],
                                       base[(k, clean)]['sag_avg'])
            for k in CASES)))

    if not do_check:
        return 0

    # ───────── 不变量断言（最终配置）─────────
    final = ('new', TURN_MIN_GAP_SEC, (MAX_STEP_DEG, MAX_DROPS))
    res = {(k, c): cells(k, c, final) for k in CASES for c in (False, True)}

    # ① **航向干净时直通**：无噪声场景下开关这道门必须**逐点相同**。
    #    这条是「不可能把本来就准的场景改坏」的形式化保证，比任何均值都硬。
    for k in CASES:
        r = res[(k, True)]
        o = cells(k, True, ('old', TURN_MIN_GAP_SEC, None))
        want((r['dots'], r['total']) == (o['dots'], o['total']) and
             abs(r['sag'] - o['sag']) < 1e-9,
             '%s(无噪声) 新算法与旧算法不一致（%d/%d %.1fm vs %d/%d %.1fm）'
             % (k, r['dots'], r['total'], r['sag'], o['dots'], o['total'], o['sag']))

    # ② 含噪声：直路上不许再有多余的补点（旧算法在这里是真的会发）
    old_urban = cells('straight_urban', False, ('old', TURN_MIN_GAP_SEC, None))
    want(old_urban['dots'] > 0,
         'straight_urban 场景旧算法居然不误触发 —— 这条改动就失去了主要依据，'
         '先复核场景本身')
    for k in CLEAN_CASES:
        want(res[(k, False)]['dots'] == 0,
             '%s(含噪声) 还有 %d 个补点（应当为 0）'
             % (k, res[(k, False)]['dots']))

    # ③ 含噪声：不许比旧算法花更多信道，也不许把弦高做坏（两个指标都要看）
    for k in TURN_CASES:
        r, o = res[(k, False)], cells(k, False, ('old', TURN_MIN_GAP_SEC, None))
        want(r['dots'] <= o['dots'] * 1.2 + 2,
             '%s(含噪声) 新算法 %d 点，比旧算法 %d 点明显多（花的是共享信道）'
             % (k, r['dots'], o['dots']))
        want(r['sag_avg'] <= o['sag_avg'] * 1.10,
             '%s(含噪声) 平均弦高 %.1fm 比旧算法 %.1fm 明显变差'
             % (k, r['sag_avg'], o['sag_avg']))

    # ④ 门的取值要有**两侧**依据，证明 40° 不是随手挑的：
    #    * 太小（25°）：真实转向（发卡弯 22.5°/s）叠上 σ=7° 的噪声常常一帧就
    #      超过 25°，于是连真实的弯也被丢掉 —— hairpin 的平均弦高立刻变差。
    #    * 太大（60°）：60° 的野值正好被放行，直路上又出现十几个无用补点。
    g25 = cells('hairpin', False, ('new', TURN_MIN_GAP_SEC, (25.0, 3)))
    g60 = cells('straight_urban', False, ('new', TURN_MIN_GAP_SEC, (60.0, 3)))
    want(g25['sag_avg'] > res[('hairpin', False)]['sag_avg'],
         '门 25° 在 hairpin 上平均弦高 %.1fm 反而比 40° 的 %.1fm 好 —— '
         '那 40° 就缺少下界依据' % (g25['sag_avg'], res[('hairpin', False)]['sag_avg']))
    want(g60['dots'] > 0,
         '门 60° 在直路上一个野值都没放行 —— 那 40° 就缺少上界依据')

    # ⑤ 重同步上限同样要有依据：不设上限（=10 亿）会在一个持续超限的真实转向后
    #    **永久失明** —— hairpin 上少一半的点、平均弦高大一倍。
    nosync = cells('hairpin', False, ('new', TURN_MIN_GAP_SEC, (MAX_STEP_DEG, 10 ** 9)))
    want(nosync['dots'] < res[('hairpin', False)]['dots'],
         '不设重同步上限时 hairpin 点数没有变少 —— 那 maxDrops 就缺少依据')

    if fails:
        print('\n转弯打点回归失败：')
        for f in fails:
            print('  -', f)
        return 1
    print('\n转弯打点回归 ok（航向干净时逐点直通 / 直路不再被野值触发 / '
          '含噪声时不多花信道且平均弦高不退化 / 门的取值有两侧依据）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
