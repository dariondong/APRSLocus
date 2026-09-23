#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""轨迹采样 + 信标打点的静态检查。

为什么需要：这三组改动**全都在真机上才看得出来**，编译、analyze、测试都是绿的：

  1. **采样率**（Android `requestLocationUpdates` 的 minTime）：改成 10000L 之后
     一切照常编译，只是轨迹每 10 秒才一个点 —— 用户看到的是「轨迹像拐直角」。
  2. **落点判据**：`state.dart` 里那条「距离够了 **或** 隔了最大间隔且确实挪了」
     的保底。少了后半句，慢速轨迹会明显偏疏（速度越低越疏），而这正是用户
     最想看清细节的时候。
  3. **信标点**（`beaconMarks`）：只在真的发出去（connected）时才记、清空数据时
     要一起清、地图上要有独立图层。少任何一条的表现分别是「标了没发出去的点」、
     「清空后剩一串孤点」、「功能等于不存在」—— 都不会报错。
  4. **智能信标的距离打点**：档位要有 `minDistM`、要落盘、触发条件要
     「定时 **或** 距离」。只留定时那条时，用户在国道上看到的还是被拉直的轨迹。

用法：python3 tool/check_beacon_track.py
退出码 0 = 全在；1 = 有缺失（并列出具体位置）。
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

    def need(rel, needle, why):
        if needle not in read(rel):
            errors.append(f'{rel} 里找不到 `{needle}` —— {why}')

    def codes_only(text):
        """剔掉整行注释：本仓库的注释会**提到**被禁的名字来解释为什么不用它。"""
        return '\n'.join(l for l in text.split('\n')
                         if not l.lstrip().startswith('//'))

    # ── ① 采样率：GPS 必须按 1s 注册 ──
    kt = read('android/app/src/main/kotlin/com/aprslocus/aprslocus/LocationService.kt')
    gps = re.search(r'GPS_PROVIDER,\s*(\d+)L', kt)
    if not gps:
        errors.append('LocationService.kt 里找不到 GPS_PROVIDER 的注册 —— '
                      '定位采样率无从确认')
    elif int(gps.group(1)) > 2000:
        errors.append(f'GPS 采样 minTime = {gps.group(1)}ms（> 2000）—— '
                      '用户反馈过「实时轨迹采样率低」，应保持 1s 级')
    # 网络辅助定位保持低频率（只做兜底，不该跟着 1s 轮询）
    net = re.search(r'NETWORK_PROVIDER,\s*(\d+)L', kt)
    if not net:
        errors.append('LocationService.kt 里找不到 NETWORK_PROVIDER 的注册')
    elif int(net.group(1)) < 5000:
        errors.append(f'网络定位 minTime = {net.group(1)}ms（< 5000）—— '
                      '它只做 GPS 停更时的兜底，按 1s 轮询白耗电')

    # ── ② 落点判据：距离门限 **或** 最大间隔保底 ──
    pq = read('lib/pos_quality.dart')
    for name in ('refWindowSec', 'trackMaxGapSec', 'trackMinMoveM'):
        if f'static const double {name}' not in pq:
            errors.append(f'lib/pos_quality.dart 缺 `{name}` —— '
                          '落点判据少了参照量（详见该文件注释）')
    st = codes_only(read('lib/state.dart'))
    need('lib/state.dart', 'PosQuality.trackMaxGapSec',
         '落点判据里没有「最大间隔」那条 —— 慢速轨迹会明显偏疏')
    need('lib/state.dart', 'keepAlive', '保底落点那段被删了')
    need('lib/state.dart', 'PosQuality.trackMinDistM(', '自己轨迹没按速度自适应抽稀')

    # ── ③ 信标点（发到服务器去的点）──
    need('lib/state.dart', 'final List<TrackPt> beaconMarks',
         '没有单独存「已上报的点」—— 地图上就标不出来')
    need('lib/state.dart', 'beaconMarks.clear()',
         '清空数据时没清信标标记 —— 会剩一串没有轨迹穿过的孤点')
    # 只记「真的发出去」的点：`if (connected) { ... }` 这个分支里必须有
    # beaconMarks.add。**必须按大括号配对取整块**：第一版用了个「最多 800 字符」
    # 的懒惰正则，而那个分支有一千多字符（中间还有嵌套的 if），于是它在那段里
    # 找不到 add 就报了假失败 —— 与 check_frame_cost 里那两条「断言必须断言能编译
    # 的字符串」是同一类教训：判据本身要按结构取，不能按长度猜。
    src = read('lib/state.dart')
    idx = src.find('if (connected) {')
    branch = None
    if idx >= 0:
        depth = 0
        for i in range(idx + len('if (connected)'), len(src)):
            c = src[i]
            if c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    branch = src[idx:i]
                    break
    if branch is None:
        errors.append('lib/state.dart 里找不到 `if (connected) {` 分支 —— '
                      '信标是否「真的发出去」的判据无从确认')
    elif 'beaconMarks.add' not in branch:
        errors.append('lib/state.dart 的 connected 分支里没有记信标点 —— '
                      '未连接时只是本地记录，不该算「发送到服务器的点」')
    mp = codes_only(read('lib/map_page.dart'))
    need('lib/map_page.dart', '_BeaconMarkPainter',
         '地图上没有信标点图层 —— 用户看不到「哪些点发到服务器了」')
    need('lib/map_page.dart', 'widget.state.beaconMarks',
         '信标点图层没接上 beaconMarks')

    # ── ④ 智能信标的距离打点 ──
    need('lib/state.dart', 'int get beaconMinDistNow',
         '取不到「当前档位的距离门限」')
    need('lib/state.dart', 'double get beaconDistMovedM',
         '没有「自上次上报走了多远」的计算 —— 距离打点无从判断')
    need('lib/state.dart', 'dueByDist', '上报触发条件里没有距离那条')
    if 'dueByTime || dueByDist' not in st:
        errors.append('lib/state.dart 的上报判据不是「定时 **或** 距离」—— '
                      '少了距离那条，走得快时拐弯仍会被拉直')
    for field in ("'minDistM': minDistM", "minDistM: ((j['minDistM'] as num?)"):
        if field not in read('lib/state.dart'):
            errors.append(f'SmartBeaconTier 的 minDistM 没有落盘/读回（缺 `{field}`）—— '
                          '重启后用户的设置会丢')
    need('lib/settings_pages.dart', 'dsCtrl',
         '设置页没有距离打点的输入框 —— 功能不可配置')
    need('lib/settings_pages.dart', 'minDistM: int.tryParse(dsCtrl.text.trim())',
         '设置页读了这个字段却没写回档位')

    if errors:
        print('轨迹采样/信标打点检查失败：')
        for e in errors:
            print('  -', e)
        return 1
    print('轨迹采样/信标打点 ok（GPS 1s、落点有保底、信标点只记已发送且可清、'
          '智能信标支持定时或距离）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
