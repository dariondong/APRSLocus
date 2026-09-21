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
    迟到的旧帧又会被接受（功能「有时好有时坏」）；
  * `locStatus` 是**白名单映射**（widgets.dart），新增状态串忘了登记 →
    英文/日文界面直接漏出中文；
  * 自己的定位防抖（SelfFixFilter）忘了接、或忘了把 accuracy 从原生接回来 →
    「静止时轨迹画成一团毛线球」的旧问题原样复现。

注意：只查「有没有接线」，不查算法对不对（那要靠真实语料回归）。
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

    def forbid(rel, needle, why):
        if needle in read(rel):
            errors.append(f'{rel} 里仍有 `{needle}` —— {why}')

    # ① 接收台站：四个数据来源共用的唯一入口必须接上质量层
    need('lib/state.dart', 'PosQuality.bodyOf(raw)',
         '报文指纹要剥掉转发路径，否则跨路径重复帧去不掉')
    need('lib/state.dart', 'PosQuality.dedupe(_fixDedupe',
         '接收侧去重没接上，同一帧经 IS+射频会重复打点')
    need('lib/state.dart', 'FixGate()', '速度门控没接上，错包会画假线')
    need('lib/state.dart', 'PosQuality.maxSpeedKmh(', '速度门控没有速度上限判据')
    need('lib/state.dart', 'PosQuality.trackMinDistM(', '轨迹抽稀没改成按速度自适应')
    need('lib/state.dart', 's.ambiguity = p.posAmbiguity;', '模糊度没写进台站，画不出不确定圈')
    need('lib/state.dart', 'if (ft != null) s.fixTime = ft;', '位置时间戳没落库，旧帧无法识别')

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

    # ───────── 自己位置的防抖（A+B）─────────
    # ⑥ accuracy 必须从原生接回 Dart：以前原生算了、Dart 侧没读，等于白算
    need('lib/services.dart', "(event['accuracy'] as num?)?.toDouble()",
         '原生上报的 accuracy 没被解析（精度信息在传输途中丢掉了）')
    need('lib/services.dart', 'double accuracyM)? onFix;',
         'onFix 回调签名缺 accuracy 参数')
    need('lib/state.dart', 'double accuracy,\n  ) {',
         'AppState._onFix 没接收 accuracy')
    need('lib/state.dart', 'myAccuracy = accuracy > 0 ? accuracy : 0;',
         'myAccuracy 没落库')

    # ⑦ 静止防抖必须真的作用在实时定位上
    need('lib/state.dart', '_selfFilter.feed(', '静止防抖滤波器没接上')
    need('lib/state.dart', 'final SelfFixFilter _selfFilter',
         '静止防抖滤波器实例没定义')
    # 自己轨迹的旧固定门限（> 0.02）也必须消失：与接收台站同一套自适应
    forbid('lib/state.dart', 'haversine(last.lat, last.lng, lat, lng) > 0.02',
           '自己轨迹的固定 20m 门限又回来了（应改为按速度自适应）')

    # ───────── 「还会不会跳回初始点」的三条闸门 ─────────
    # ⑨ 缓存位置：一旦有过实时定位，之后到达的系统缓存点必须被丢弃。
    #    原生侧前台服务重启会让它的 hasLiveFix 归零，所以上层必须自己记。
    need('lib/state.dart', 'if (lastKnown && _hadLiveFix) {',
         '缓存位置闸门没了 —— 前台服务重启后，几分钟前的缓存点会把标记拉回旧位置')

    # ⑩ 跳变守卫的参照点必须是「上次被接受的实时定位」，不能用 myTrack.last：
    #    静止时不再写轨迹点，myTrack.last 可能已是几小时前的点（守卫会整个失效），
    #    而且 myTrack 为空时（刚启动/清空后）原本完全没有守卫。
    need('lib/state.dart', 'haversine(_lastFixLat!, _lastFixLng!, lat, lng)',
         '跳变守卫的参照点不是「上次可信位置」')
    forbid('lib/state.dart', 'haversine(last.lat, last.lng, lat, lng)',
           '跳变守卫又用回 myTrack.last 当参照点（静止久了会失效）')

    # ⑪ 定位状态复位必须集中在一处，并在三个入口都被调用
    need('lib/state.dart', 'void _resetSelfFix() {', '定位状态复位方法没了')
    n_reset = read('lib/state.dart').count('_resetSelfFix();')
    if n_reset < 3:
        errors.append(f'_resetSelfFix() 只被调用 {n_reset} 次 —— 停止定位 / '
                      f'切模拟位置 / 清空数据三处都要复位（实际要 ≥3）')
    state_src = read('lib/state.dart')
    i = state_src.find('void clearAllData() {')
    if i < 0:
        errors.append('找不到 clearAllData()')
    elif 'myTrack.clear();' not in state_src[i:i + 400]:
        errors.append('clearAllData() 没清 myTrack —— 清空数据后自己的轨迹会残留')

    # ⑧ locStatus 白名单：所有赋值过的状态串都必须已登记。
    #
    # ⚠ 不能只抓 `locStatus = 'xxx';` 这种直接赋值 —— 三元表达式
    # （`locStatus = still ? '静止' : '已定位';`）里的字面量会全漏掉。
    # 第一版就是这么写的，结果它声称「已登记 6 个」而恰好漏掉了新加的
    # '静止' —— **检查器自己犯了它要检查的那类错**。所以改成：取整个赋值
    # 表达式，把里面所有字面量都收进来。
    src_state = read('lib/state.dart')
    status_vals = set()
    for m in re.finditer(r'locStatus\s*=\s*([^;]+);', src_state):
        for lit in re.findall(r"'([^']+)'", m.group(1)):
            if lit:
                status_vals.add(lit)
    # 正则自己也要有回归：至少应抓到已知的这几个状态串
    for probe in ('未定位', '已定位', '静止'):
        if probe not in status_vals:
            errors.append(f'检查器未能从代码里抽到状态串 {probe} —— '
                          '状态白名单检查已失效（它自己就是坏的）')
    widgets = read('lib/widgets.dart')
    for v in sorted(status_vals):
        if f"value == '{v}'" not in widgets:
            errors.append(f"locStatus 新增了 '{v}' 但 widgets.dart 的 "
                          f'localizedLocationStatus 里没登记 —— 非中文界面会漏出中文')

    if errors:
        print('打点质量层接线不完整：')
        for e in errors:
            print('  -', e)
        return 1
    print(f'打点质量层接线 ok（含 {len(status_vals)} 个定位状态串已登记）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
