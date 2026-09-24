#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""蓝牙心率带 + 佳明 LiveTrack 的接线检查。

为什么需要它：这两块**全都是「只在真机上才看得出来」的接线**，编译、analyze、
其它检查都不会报：

  * 心率带：CCCD 描述符不写 → 一条通知都收不到（心率一直是空的）；flags 的位没按
    位算偏移 → 心率偶尔是 3000；事件从 binder 线程直接发 → 部分机型静默丢事件；
  * 与 TNC 的冲突：**经典蓝牙发现（startDiscovery）会打断正在工作的 SPP 连接**，
    写了它就会出现「开心率带扫描 → TNC 断流」这种极难归因的问题；
  * 佳明：ACTION_SEND 的 intent-filter 没注册 → 佳明 App 的分享面板里没有我们；
    singleTop 不重写 onNewIntent → 第二次分享静默丢失；不按 livetrack 域名过滤 →
    任何 App 分享任何文本都会看到 APRSlocus；不解析 Next.js 的 trackPoints →
    「页面上明明有点，应用里一个都没有」；
  * `HR=nn` 只在**真有读数**时才发（发 HR=0 会被收端读成「心率 0」）。

判据分两类：
  * 「必须有」——漏了功能就不生效（接线、权限、过滤、聚合）；
  * 「必须没有」——写了就会坏事（经典发现、adapter.disable、HR=0）。

用法：python3 tool/check_hr_garmin.py
退出码 0 = 全部就位；1 = 有缺失（并列出具体位置）。
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KT = 'android/app/src/main/kotlin/com/aprslocus/aprslocus'


def read(rel):
    return io.open(os.path.join(ROOT, rel), encoding='utf-8').read()


def code_only(rel):
    """剥掉注释与字符串字面量，只留代码。

    ⚠ 这一步不能省：本仓库的注释会**提到**被禁的东西来解释「为什么不用它」
    （BleHrManager 里就写着「绝不调用 startDiscovery」「不调用 adapter.disable」），
    对全文做「必须没有」检查会把说明文字当成违规 —— 一屏假失败，比没有检查更坏。
    """
    src = read(rel)
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '/' and src[i + 1:i + 2] == '/':
            j = src.find('\n', i)
            i = n if j < 0 else j
            continue
        if c == '/' and src[i + 1:i + 2] == '*':
            j = src.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        if c in '\'"':
            q = c
            i += 1
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src[i] == q:
                    break
                i += 1
            i += 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def main() -> int:
    errors = []

    def need(rel, needle, why):
        try:
            if needle not in read(rel):
                errors.append(f'{rel} 里找不到 `{needle}` —— {why}')
        except IOError:
            errors.append(f'{rel} 打不开（文件被改名/删了？）—— {why}')

    def forbid(rel, needle, why):
        try:
            if needle in code_only(rel):
                errors.append(f'{rel} 里出现了 `{needle}` —— {why}')
        except IOError:
            errors.append(f'{rel} 打不开（文件被改名/删了？）')

    ble = f'{KT}/BleHrManager.kt'
    act = f'{KT}/MainActivity.kt'
    man = 'android/app/src/main/AndroidManifest.xml'

    # ── ① 原生：BLE 心率带 ──
    need(ble, '0000180d-0000-1000-8000-00805f9b34fb',
         '标准心率服务（0x180D）的 UUID 没了 —— 收不到任何心率带的数据')
    need(ble, '00002902-0000-1000-8000-00805f9b34fb',
         'CCCD 的 UUID 没了 —— 不写这个描述符外设不会推通知（心率一直是空的）')
    need(ble, 'writeDescriptor',
         '没有写 CCCD —— setCharacteristicNotification 只是本地开关')
    need(ble, 'TRANSPORT_LE',
         '连接没用 TRANSPORT_LE —— 双模设备可能被当成经典设备连上，收不到 GATT 通知')
    need(ble, 'ArrayList<Int>',
         'RR 间期不是 ArrayList<Int> —— StandardMessageCodec 不支持 IntArray，Dart 侧收不到')
    need(ble, 'main.post', '事件没有切回主线程 —— EventSink 只能在主线程用，部分机型会静默丢事件')
    need(ble, 'PERM_REQUEST = 4919',
         '权限请求码被改了/没了 —— 与其它请求码撞车会把对方尚未完成的 Result 误 resolve')
    forbid(ble, 'startDiscovery(',
           '**经典蓝牙发现会打断正在工作的 SPP（TNC）连接** —— 心率扫描必须只用 BluetoothLeScanner')
    forbid(ble, 'adapter.disable', 'adapter.disable 会把 TNC 的蓝牙链路一起弄断')
    forbid(ble, '.enable()', 'adapter.enable 会把 TNC 的蓝牙链路一起弄断')

    # ── ② 原生：接线与防冲突 ──
    need(act, 'BleHrManager(', 'MainActivity 没建心率管理器 —— 通道是空的')
    need(act, 'busySppAddresses', '没把「正被 SPP 占用的地址」传下去 —— 同一台设备会被两条链路抢')
    need(act, 'connectedAddress()',
         'TncManager 没有暴露当前对端地址 —— 防冲突判定无从下手')
    need(act, 'refreshBtActive', '前台服务的 connectedDevice 类型没有统一汇总（会互相误清）')
    need(act, 'bleHr?.onRequestPermissionsResult', 'BLE 的权限结果没有转发 —— 申请完永远不返回')

    # ── ③ 原生：分享入口 ──
    need(man, 'android.intent.action.SEND', '没有注册 ACTION_SEND —— 佳明 App 的分享面板里不会有我们')
    need(man, 'text/plain', 'ACTION_SEND 没有限定 text/plain')
    need(man, 'android.hardware.bluetooth_le',
         '没有声明 BLE 特性（required=false）—— 没有 BLE 的设备会被应用市场过滤掉')
    need(act, 'onNewIntent', '**没有重写 onNewIntent —— singleTop 下第二次分享会被静默丢掉**')
    need(act, 'livetrack.garmin.com',
         '没有按 livetrack 域名过滤 —— 任意 App 分享任意文本都会看到 APRSlocus')
    need(act, 'takePendingSharedText', '冷启动那条分享路径没了（Flutter 起来前事件没人收）')

    # ── ④ Dart：心率与信标 ──
    st = read('lib/state.dart')
    need('lib/state.dart', 'int? myHr;', '没有存心率 —— 界面与信标都拿不到读数')
    need('lib/state.dart', "'HR=$myHr'", '信标备注里没有 HR=nn（需求：信标附带心率）')
    if 'HR=0' in code_only('lib/state.dart'):
        errors.append('lib/state.dart 里出现了 HR=0 —— 没有读数时应该**不发** HR，'
                      '发 0 会被收端读成「心率 0」而不是「没测」')
    need('lib/widgets.dart', '佳明 LiveTrack',
         'locStatus 新增的状态串没在 widgets.dart 登记 —— 非中文界面会漏出中文')
    need('lib/backup.dart', "'beaconIncludeHr'", '心率开关没进备份分组（换机会丢）')
    need('lib/backup.dart', "'garminUrl'", '佳明链接没进备份分组（换机要重新找）')
    need('lib/ble_hr.dart', 'com.aprslocus/blehr', '心率通道名变了')
    need('lib/share_in.dart', 'com.aprslocus/share_in', '分享入口通道名变了')

    # ── ⑤ Dart：佳明 LiveTrack ──
    g = read('lib/garmin.dart')
    need('lib/garmin.dart', r'livetrack\.garmin\.com',
         'LiveTrack 链接的正则没了 —— 用户粘贴的链接永远判为无效')
    need('lib/garmin.dart', 'self\\.__next_f\\.push',
         '没有解析 Next.js 的流式数据块 —— 抓到的页面里找不到 trackPoints')
    need('lib/garmin.dart', '"trackPoints":', '没有取 trackPoints —— 拿不到任何点')
    need('lib/garmin.dart', 'kMaxAgeSec = 120', '没有「只接受 120 秒内的点」这条策略')
    need('lib/garmin.dart', 'kBacklogResyncSec = 60',
         '没有「积压超过 60 秒就跳点」—— 会补发一串过时轨迹')
    need('lib/garmin.dart', 'kMinForwardGapSec = 10',
         '没有最小转发间隔 —— 会把 APRS 信道刷满')
    need('lib/state.dart', 'if (garmin.on && garmin.fresh) return;',
         '佳明在跑时手机 GPS 没有让位 —— 两路会互相把标记拉来拉去')
    need('lib/state.dart', 'onGarminShared', '分享进来的链接没有回调出去（用户看不到任何提示）')
    need('lib/garmin_page.dart', 'GarminTrackPage',
         '佳明设置页没了 —— 手贴链接那条路就断了')

    # ── ⑥ l10n：六个语言都要有这两组键 ──
    for lg in ('zh', 'zh_TW', 'en', 'ja', 'es', 'id'):
        arb = read(f'lib/l10n/app_{lg}.arb')
        for k in ('hrCardTitle', 'hrIncludeInBeacon', 'garminCardTitle', 'garminHowTo',
                  'garminBadUrl', 'hrForTncNote'):
            if f'"{k}"' not in arb:
                errors.append(f'app_{lg}.arb 缺键 {k} —— 该语言的设置页会缺文案')

    if errors:
        print('心率/佳明检查失败：')
        for e in errors:
            print('  -', e)
        return 1
    print('心率/佳明 ok（BLE：标准心率服务+CCCD+主线程事件+防 SPP 冲突；'
          '佳明：分享入口+冷热启动两条路+trackPoints 解析+节流策略；'
          'HR= 只在有读数时发；6 语言键齐）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
