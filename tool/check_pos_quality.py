#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""打点质量层（lib/pos_quality.dart）的**接线检查**。

为什么需要它：
  算法写好了但**忘了在某条路径上调用**，编译、analyze 全都不会报错 ——
  只是那个功能悄悄不生效。本机跑不了 analyze、更跑不了真机，这类「哑失败」
  只能等用户发现。所以把「哪个文件必须调用哪个入口」变成 CI 里的一条断言。

它拦的都是真发生过/极易发生的回归：
  * `_upsertStation` 是**唯一**的台站入口（IS / TNC / 音频 / PKWDWPL 全走它），
    一旦有人把门控去掉（或改回固定 20m 门限），所有来源一起退化；
  * 平滑只写在瓦片地图、忘了矢量地图 → 两种底图轨迹不一样（最难查的那种）；
  * Station 加了字段却没进 `_saveStationsNow` / `_loadStations` → 重启后
    迟到的旧帧又会被接受（功能「有时好有时坏」）。

注意：只查「有没有接线」，不查算法对不对（那要靠真实语料回归）。
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(rel):
    return io.open(os.path.join(ROOT, rel), encoding='utf-8').read()


def main() -> int:
    errors = []

    def need(rel, needle, why):
        if needle not in read(rel):
            errors.append(f'{rel} 里找不到 `{needle}` —— {why}')

    def forbid(rel, needle, why):
        if needle in read(rel):
            errors.append(f'{rel} 里仍有 `{needle}` —— {why}')

    # ① 状态层：四个数据来源共用的唯一入口必须接上质量层
    need('lib/state.dart', 'PosQuality.bodyOf(raw)',
         '报文指纹要剥掉转发路径，否则跨路径重复帧去不掉')
    need('lib/state.dart', 'PosQuality.dedupe(_fixDedupe',
         '接收侧去重没接上，同一帧经 IS+射频会重复打点')
    need('lib/state.dart', 'FixGate()', '速度门控没接上，错包会画假线')
    need('lib/state.dart', 'PosQuality.maxSpeedKmh(', '速度门控没有速度上限判据')
    need('lib/state.dart', 'PosQuality.trackMinDistM(', '轨迹抽稀没改成按速度自适应')
    need('lib/state.dart', 's.ambiguity = p.posAmbiguity;', '模糊度没写进台站，画不出不确定圈')
    need('lib/state.dart', 'if (ft != null) s.fixTime = ft;', '位置时间戳没落库，旧帧无法识别')

    # 固定 20m 门限是这次要消灭的东西：留着说明抽稀被改回去了
    forbid('lib/state.dart',
           'haversine(s.track.last.lat, s.track.last.lng, p.lat, p.lng) > 0.02',
           '固定 20m 的抽稀门限又回来了（应按速度自适应）')

    # ② 持久化：新字段必须能存能取
    need('lib/state.dart', "'fixTime': s.fixTime!.millisecondsSinceEpoch",
         'fixTime 没进 _saveStationsNow')
    need('lib/state.dart', "'ambiguity': s.ambiguity", 'ambiguity 没进 _saveStationsNow')
    need('lib/state.dart', "m['ambiguity']", 'ambiguity 没在 _loadStations 里恢复')
    need('lib/state.dart', "m['fixTime']", 'fixTime 没在 _loadStations 里恢复')

    # ③ 两条地图都要平滑，否则同一条轨迹在两种底图上不一样
    need('lib/map_page.dart', 'PosQuality.smoothForDraw(points)',
         '自绘瓦片地图的轨迹没平滑')
    need('lib/vector_map.dart', 'PosQuality.smoothForDraw(',
         '矢量地图的轨迹没平滑（两种底图会长得不一样）')

    # ④ 不确定圈 / 推测位置必须在自绘地图上真的画出来
    need('lib/map_page.dart', 'class _FixQualityPainter', '不确定圈画笔没定义')
    if read('lib/map_page.dart').count('_FixQualityPainter(') < 2:
        errors.append('lib/map_page.dart 定义了 _FixQualityPainter 却没有挂进 Stack —— '
                      '不确定圈/推测位置永远不会显示')

    # ⑤ 详情页要把「不确定」说清楚，而不是只显示一个假装精确的坐标
    need('lib/station_detail.dart', 'PosQuality.ambiguityRadiusM(',
         '详情页没展示位置精度')
    need('lib/station_detail.dart', 'PosQuality.coastOf(', '详情页没展示推测位置')

    if errors:
        print('打点质量层接线不完整：')
        for e in errors:
            print('  -', e)
        return 1
    print('打点质量层接线 ok')
    return 0


if __name__ == '__main__':
    sys.exit(main())
