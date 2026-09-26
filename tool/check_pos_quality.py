#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""位置处理的接线与「不许回退」检查。

背景与口径（v1.6.147 定下，改动前先读这段）：

  代码里现在有**两件不同的事**，检查它们的方式完全相反 ——

  ① **自己的位置**（`SelfFixFilter` 静止防抖、精度显示、精度圈）—— **要守住**。
     它们是每天看得见的东西，漏接线就是「功能悄悄不生效」，编译与 analyze 都不报。

  ② **接收台站的位置质量层**（报文去重、位置时间戳判旧帧、速度门控、模糊位置的
     不确定圈、轨迹平滑、推测定位）—— **要拦住不许回来**。
     v1.6.145 加过，v1.6.147 按用户反馈（「不要给别人加防抖，浪费」）全部撤掉，
     因为它们的代价发生在**绘制期**：轨迹平滑每次重绘重建整条列表、推测定位每秒
     对每个可见台站算三角函数、那一层还每秒强制重绘，而它叠在磨砂面板的离屏模糊上
     （面板一展开就每帧重算）。收益却是「别人的点准不准」。

  所以本脚本对 ① 做「必须存在」断言，对 ② 做「必须不存在」断言。
  想把 ② 加回来，请先在 CHANGELOG 里回答「它能省下多少帧」——
  这条检查就是那道门槛，不是随手可以删掉的麻烦。
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
            errors.append(f'{rel} 里出现了 `{needle}` —— {why}')

    state = read('lib/state.dart')
    map_page = read('lib/map_page.dart')

    # ═══════════ ① 自己的位置：必须接线完整 ═══════════

    # accuracy 从原生接回 Dart（以前原生算了、Dart 侧没读，等于白算）
    need('lib/services.dart', "(event['accuracy'] as num?)?.toDouble()",
         '原生上报的 accuracy 没被解析（精度信息在传输途中丢掉了）')
    need('lib/services.dart', "String source)? onFix;",
         'onFix 回调签名缺 source（定位来源）参数')
    need('lib/services.dart', "(event['provider'] as String?) ?? ''",
         "原生发的 provider 没被解析 —— 上层就分不出「GPS 实测」和「基站/Wi-Fi "
         '粗定位」，用户报的「网络让定位飞来飞去」会原样回来')
    need('lib/state.dart', 'String source,\n',
         'AppState._onFix 没接收 source')
    need('lib/state.dart', 'myAccuracy = coarse',
         'myAccuracy 没有区分粗定位（会照抄系统那个过于乐观的 accuracy）')
    need('lib/state.dart', 'myFixCoarse = coarse;',
         'myFixCoarse 没落库 —— 界面无法区分粗定位与 GPS')

    # 粗定位（网络/基站）的两道闸：缺任何一道，标记都会在 GPS 一闪一断时横跳。
    #
    # 闸的阈值在**策略层**（这两个常量），而原生 LocationService.kt 里的
    # NET_FALLBACK_GAP_MS=20s 只是**传输层**的「别刷屏」门槛 —— 两者是不同的事，
    # 不要为了「看起来一致」把它们对齐：20s 一断就用粗点顶上去，正是横跳的成因。
    need('lib/state.dart', 'final coarse = !lastKnown && '
         "(source == 'network' || source == 'passive');",
         '粗定位判定没了（网络/被动定位会被当成 GPS）')
    need('lib/state.dart', 'if (gapSec < _kCoarseHoldSec || jumpKm > _kCoarseJumpKm) {',
         '粗定位的两道闸（GPS 新鲜度 / 自身位移）没了 —— 「飞来飞去」会回来')
    need('lib/state.dart', 'static const int _kCoarseHoldSec = 300;',
         '粗定位的 GPS 新鲜度门槛没了/被改成了别的值（v1.6.163 定为 300s：'
         '粗点不再自动上报，只做「GPS 真没了」时的分钟级兜底）')
    need('lib/state.dart', 'static const double _kCoarseJumpKm = 3.0;',
         '粗定位的自身位移上限没了/被改了（v1.6.163 收到 3.0：基站/Wi-Fi 的'
         '单跳误差本来就在公里级，8km 等于不设防）')
    need('lib/state.dart', 'static const double _kCoarseAccuracyFloorM = 300.0;',
         '粗定位的精度显示下限没了/被改了 —— 精度圈会画得跟 GPS 一样小'
         '（比不画更骗人）')
    # 粗点绝不许：进防抖滑窗、推进跳变参照点、写轨迹/历史台账
    need('lib/state.dart', 'final out = (lastKnown || coarse)',
         '粗定位点进了静止防抖滑窗 —— 会把中位数拉跑')
    need('lib/state.dart', 'if (filterFollow && !coarse) {',
         '粗定位点仍在推动 APRS-IS 过滤中心 —— 过滤串按 0.01° 取整，粗点漂移'
         '越过一条边界就会触发一次整链路 reconnect（见 _refreshFilter）')
    # 粗点绝不许自动上报（v1.6.163 用户明确要求「网络定位时不自动发定位包」）
    #
    # ⚠ v1.6.177 改过这条：用户要「信标上报页留一个按钮，可开启强制接受网络
    # 定位自动上报」。判据于是从「排除粗点」升级成「**默认**排除粗点，唯一的
    # 例外是那个用户显式开关」—— 守的还是同一件事：不许**代码**替用户默认把
    # 一个偏几百米的坐标发出去。
    need('lib/state.dart',
         "      (!myFixCoarse || beaconForceCoarse || locationMode == 'network') &&",
         'canAutoBeacon 不再默认排除粗定位 —— 网络定位下会自动发出一个偏几百米'
         '的坐标（收端看到的是一条乱跳的轨迹）。只允许两种**用户显式选择**的例外：'
         "beaconForceCoarse，或纯网络定位模式（locationMode == 'network'）")
    # 开关打开时**不能**退回普通的 counting：界面上会变成一个正常的绿色倒计时，
    # 用户再也看不出「现在发出去的是网络定位」（两者常差几百米）。
    #
    # 纯网络模式例外：位置本来就只能来自网络（用户显式选择），此时走普通倒计时
    # 才是诚实的 —— 它不是「粗点被放行」，而是「没有别的定位可用」。
    need('lib/state.dart',
         "    if (myFixCoarse && locationMode != 'network') {\n      return beaconForceCoarse\n          ? BeaconPhase.coarseForced\n          : BeaconPhase.coarseFix;\n    }",
         'beaconPhase 的粗定位分支没了/被拆散 —— 要么界面继续显示一个不会生效的'
         '倒计时（老毛病），要么强制档与普通倒计时混成一样（看不出发的是粗坐标）')
    need('lib/state.dart', 'coarseFix,', 'BeaconPhase 里没有 coarseFix 枚举项')
    need('lib/state.dart', 'coarseForced,',
         'BeaconPhase 里没有 coarseForced 枚举项 —— 强制接受网络定位时无法与正常'
         '倒计时区分（界面会显示成一切正常）')
    # 这个开关只放开「自动上报」，**绝不许顺手放宽位置质量闸**：
    # 否则地图/轨迹会重新「飞来飞去」（v1.6.163 修的就是它）。
    for probe, why in (
        ('if (coarse && garmin.on) return;',
         '粗定位点又允许覆盖佳明给的位置了 —— 会拿基站质心替换手表的位置'),
        ('if (gapSec < _kCoarseHoldSec || jumpKm > _kCoarseJumpKm) {',
         '粗定位的两道闸（GPS 新鲜度 / 自身位移）被绕过 —— 这个开关不该影响它们，'
         '「飞来飞去」会回来'),
        ('if (filterFollow && !coarse) {',
         '强制开关放开了「粗点推动 APRS-IS 过滤中心」—— 过滤串按 0.01° 取整，'
         '粗点漂移越过一条边界就会触发一次整链路 reconnect'),
    ):
        need('lib/state.dart', probe, why)
    # 开关本身要落盘 + 进备份：丢了它，换机后自动上报会静默变回「一直不报」，
    # 而用户很可能正是因为设备没有 GPS 才需要它。
    need('lib/state.dart', "await p.setBool('beaconForceCoarse', beaconForceCoarse);",
         'beaconForceCoarse 没落盘 —— 重启后开关回到默认关，用户以为设置没生效')
    need('lib/backup.dart', "'beaconForceCoarse'",
         'beaconForceCoarse 没进备份白名单 —— 换机后这个选择会丢')
    # ── 开关的**接线**：字段/逻辑对了，但控件没接上照样等于没做 ──
    # 编译、analyze、测试都不会因此失败，用户看到的只是「页面里没这个选项」
    # 或「拨了不动」—— 本仓库已有多次「功能写好了但没接上」的前科。
    need('lib/settings_pages.dart', 'SettingsSwitch(S.of(context).beaconForceCoarse,',
         '信标上报页上没有这个开关 —— 功能等于不存在')
    need('lib/settings_pages.dart', 'onChanged: st.setBeaconForceCoarse)',
         '开关没接上 setter —— 拨了不会生效（编译全绿，只是没用）')
    need('lib/settings_pages.dart',
         'if (st.beaconPhase == BeaconPhase.coarseForced)',
         '开着强制且当前就是粗点时没有如实提示 —— 页面上的倒计时与 GPS 正常时'
         '一模一样，用户看不出「正在发一个偏几百米的坐标」')
    need('lib/state.dart', 'if (!lastKnown && !coarse) {',
         '粗定位点会推进跳变守卫的参照点（GPS 回来时会被误判成跳变）')
    need('lib/state.dart', '    if (!lastKnown &&\n        !coarse &&\n        !still &&',
         '粗定位点能写进自己的轨迹与历史台账')
    if "coarse ? '网络定位（粗）'" not in state:
        errors.append('粗定位时没有如实的 locStatus —— 用户会以为 GPS 坏了')

    # 静止防抖
    need('lib/state.dart', '_selfFilter.feed(', '静止防抖滤波器没接上')
    need('lib/state.dart', 'final SelfFixFilter _selfFilter',
         '静止防抖滤波器实例没定义')
    need('lib/pos_quality.dart', 'class SelfFixFilter {',
         'SelfFixFilter 没了（自己的静止防抖靠它）')

    # 轨迹抽稀：自己用自适应门限（固定 20m 在步行时太粗、高速时太细）
    need('lib/state.dart', 'PosQuality.trackMinDistM(', '自己轨迹没按速度自适应抽稀')
    forbid('lib/state.dart', 'haversine(last.lat, last.lng, lat, lng) > 0.02',
           '自己轨迹的固定 20m 门限又回来了（应改为按速度自适应）')

    # 「还会不会跳回初始点」的两条闸门
    need('lib/state.dart', 'if (lastKnown && _hadLiveFix) {',
         '缓存位置闸门没了 —— 前台服务重启后，几分钟前的缓存点会把标记拉回旧位置')
    need('lib/state.dart', 'haversine(_lastFixLat!, _lastFixLng!, lat, lng)',
         '跳变守卫的参照点不是「上次可信位置」（静止久了会失效）')
    need('lib/state.dart', 'void _resetSelfFix() {', '定位状态复位方法没了')
    n_reset = state.count('_resetSelfFix();')
    if n_reset < 3:
        errors.append(f'_resetSelfFix() 只被调用 {n_reset} 次 —— 停止定位 / '
                      f'切模拟位置 / 清空数据三处都要复位（要 ≥3）')
    i = state.find('void clearAllData() {')
    if i < 0:
        errors.append('找不到 clearAllData()')
    elif 'myTrack.clear();' not in state[i:i + 400]:
        errors.append('clearAllData() 没清 myTrack —— 清空数据后自己的轨迹会残留')

    # 自己的精度圈（只在数据变化时重绘，不按秒重绘）
    need('lib/map_page.dart', 'class _MyAccuracyPainter', '自己的精度圈画笔没了')
    need('lib/map_page.dart', 'painter: _MyAccuracyPainter(',
         'precision 圈没挂进地图 Stack')

    # locStatus 白名单：所有赋值过的状态串都必须已登记
    # ⚠ 不能只抓 `locStatus = 'xxx';` —— 三元表达式里的字面量会全漏掉
    #   （第一版就是这么写的，结果恰好漏掉了新加的 '静止'）
    status_vals = set()
    for m in re.finditer(r'locStatus\s*=\s*([^;]+);', state):
        for lit in re.findall(r"'([^']+)'", m.group(1)):
            if lit:
                status_vals.add(lit)
    for probe in ('未定位', '已定位', '静止'):
        if probe not in status_vals:
            errors.append(f'检查器未能从代码里抽到状态串 {probe} —— '
                          '状态白名单检查已失效（它自己就是坏的）')
    widgets = read('lib/widgets.dart')
    for v in sorted(status_vals):
        if f"value == '{v}'" not in widgets:
            errors.append(f"locStatus 新增了 '{v}' 但 widgets.dart 的 "
                          f'localizedLocationStatus 里没登记 —— 非中文界面会漏出中文')

    # ═══════════ ② 接收台站的质量层：必须不存在 ═══════════
    #
    # 这里拦的是「绘制期开销」那一类。每包只算一次的 O(1) 校验也在内 ——
    # 用户要的是接收侧整体回到朴素行为，不区分成本。
    RECEIVER_FORBIDDEN = [
        ('lib/state.dart', 'PosQuality.dedupe(', '接收侧报文去重'),
        ('lib/state.dart', 'PosQuality.bodyOf(', '接收侧报文指纹'),
        ('lib/state.dart', 'FixGate(', '接收侧速度门控'),
        ('lib/state.dart', 'FixVerdict.', '接收侧门控判定'),
        ('lib/pos_quality.dart', 'class FixGate', '接收侧速度门控类'),
        ('lib/pos_quality.dart', 'coastOf(', '接收侧推测定位'),
        ('lib/pos_quality.dart', 'ambiguityRadiusM(', '接收侧模糊圈半径'),
        ('lib/pos_quality.dart', 'smoothForDraw(', '轨迹平滑（每帧重建列表）'),
        ('lib/pos_quality.dart', 'maxSpeedKmh(', '接收侧速度上限判据'),
        ('lib/map_page.dart', 'smoothForDraw(', '地图上还在做轨迹平滑'),
        ('lib/map_page.dart', 'coastOf(', '地图上还在算推测位置'),
        ('lib/map_page.dart', 'ambiguityRadiusM(', '地图上还在画台站模糊圈'),
        ('lib/vector_map.dart', 'smoothForDraw(', '矢量地图还在做轨迹平滑'),
    ]
    for rel, needle, what in RECEIVER_FORBIDDEN:
        forbid(rel, needle,
               f'{what}在 v1.6.147 已撤掉（绘制期开销换不来别人的点更准，'
               f'见 pos_quality.dart 顶部）。要加回来请先说明它能省下多少帧')
    # Station 也不许再挂这两个字段
    forbid('lib/models.dart', 'DateTime? fixTime;', 'Station.fixTime（接收侧时序）')
    forbid('lib/models.dart', 'int ambiguity;', 'Station.ambiguity（接收侧模糊度）')

    # 接收侧必须仍是「位移 > 20m 记一点」的朴素行为
    if 'p.lat, p.lng) > 0.02' not in state:
        errors.append('lib/state.dart 里找不到接收台站的朴素抽稀（位移 > 20m）—— '
                      '要么被改成别的判据了，要么这段被删了')

    if errors:
        print('位置处理检查失败：')
        for e in errors:
            print('  -', e)
        return 1
    print(f'位置处理 ok（自己侧接线完整；接收侧已回退为朴素行为；'
          f'{len(status_vals)} 个定位状态串已登记）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
