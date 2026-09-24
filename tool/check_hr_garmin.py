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
    # 佳明接管期间必须补齐的两件事，**限定在 _onGarminPoint 函数体内**查：
    # 全文件搜索会被 GPS 那条路径里的同名调用满足（`TrackLogStore.instance.record(`
    # 两边都有），于是「佳明不写台账」这种缺陷永远抓不到 —— 回归样本当场证明过。
    gseg = st[st.find('void _onGarminPoint'):]
    gseg = gseg[:gseg.find('\n  /// 收到分享进来的文本')]
    if not gseg:
        errors.append('lib/state.dart 里找不到 _onGarminPoint 的函数体 —— 检查器自己失效')
    if 'TrackLogStore.instance.record(' not in gseg:
        errors.append('_onGarminPoint 里没有写历史台账 —— 佳明接管期间的历史记录会是'
                      '一段空白（手机 GPS 正被让位，两边都不记）')
    if 'bearingDeg(' not in gseg:
        errors.append('_onGarminPoint 里没有算航向 —— 佳明点没有航向字段，不自己算'
                      '就会沿用手机 GPS 的旧值（指南针停在旧方向）')
    if '_lastGarminPoint' not in gseg:
        errors.append('_onGarminPoint 没有记上一个点 —— 算不出航向')
    need('lib/state.dart', 'int? myHr;', '没有存心率 —— 界面与信标都拿不到读数')
    # ⚠ 心率带是**两个数据源之一**（另一个是佳明）。`myHr` 是界面与信标共用的那个值，
    # 所以**每个来源都必须往它同步**。曾经漏掉 BLE 这一处：设置页显示「已连接、128 bpm」
    # （那张卡直接读 bleHr.bpm），而主屏幕的心率胶囊一直不出现、信标也不带 HR=。
    # 判据：`bleHr.onChanged` 处理函数体内必须出现 `myHr =`。
    _i = read('lib/state.dart').find('bleHr.onChanged = () {')
    if _i < 0:
        errors.append('找不到 bleHr.onChanged 的接线')
    else:
        _blk = read('lib/state.dart')[_i:_i + 1200]
        _end = _blk.find('};')
        _blk = _blk[:_end] if _end > 0 else _blk
        if 'myHr =' not in _blk:
            errors.append('bleHr.onChanged 里没有把读数同步到 myHr —— '
                          '设置页会显示已连接/有读数，而主屏幕心率胶囊与信标 HR= 都拿不到值')
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
    # **佳明 App 的「分享」给的是短链 `gar.mn/xxx`**，参考项目（从 Gmail 邮件取长链）
    # 里根本没有这条分支 —— 只认长链的话，用户在佳明 App 里点分享选 APRSlocus
    # 会「什么都没发生」（Dart 与 Android 的域名闸门两处都会把它挡掉）。
    need('lib/garmin.dart', r'gar\.mn',
         '没有识别佳明 App 分享的短链 gar.mn —— 分享过来的链接会被判为无效')
    need('lib/garmin_fetch_io.dart', 'followRedirects = true',
         '抓取没有显式跟随跳转 —— 短链靠 301 跳到长链，关掉就再也抓不到数据'
         '（而长链照常，极难归因）')
    need('android/app/src/main/kotlin/com/aprslocus/aprslocus/MainActivity.kt',
         '"gar.mn"',
         'Android 分享入口的域名闸门没有放行 gar.mn —— 佳明 App 分享的短链会被挡掉')
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
    # 佳明点必须把「航向」与「历史台账」一起补上：佳明的点里没有航向字段，
    # 不自己算就会沿用手机 GPS 的旧值（指南针停在旧方向）；不写台账则佳明接管
    # 期间的历史记录是一段空白（手机 GPS 正被让位，两边都不记）。
    need('lib/garmin.dart', 'double? bearingDeg(',
         '没有「两点算方位角」—— 佳明接管期间航向会沿用手机 GPS 的旧值')
    # `TrackLogStore.instance.record(` 在 GPS 那条路径里也有一模一样的调用，


    # 连接佳明时的上报横杠必须**说明来源并带上心率**（用户原话：
    # 「如果连接了佳明，定位上报 UI 是不是应该写好一点」）。
    # 只写倒计时的话，用户会以为发的是手机定位 —— 两者可能差几十公里。
    need('lib/state.dart', 'if (garmin.on && garmin.fresh) return BeaconPhase.garmin;',
         '佳明没有自己的上报档 —— 横杠只会显示普通倒计时，看不出位置来自手表')
    need('lib/map_page.dart', 'BeaconPhase.garmin =>',
         '上报横杠没有佳明档的文案（应带来源与心率）')
    need('lib/l10n/app_zh.arb', 'beaconGarminNext',
         '缺少 beaconGarminNext 文案 —— 横杠上的「佳明 · 倒计时 · 心率」拼不出来')
    # 粗定位点绝不许覆盖「佳明给的位置」：那一刻横杠显示的是正常倒计时，
    # 用户完全看不出正在发一个偏几百米的坐标。
    if 'if (coarse && garmin.on) return;' not in read('lib/state.dart'):
        errors.append('粗定位点没有被拦住去覆盖佳明的位置 —— 佳明断流后，'
                      '一个基站质心会在横杠显示「正常倒计时」的情况下被上报出去')

    # **手动上报必须与自动上报共用同一段组包代码**（只有一个 AprsFmt.position 调用点）。
    # 用户问过「手动上报…没有附带心率？」—— 当时确实带了（共用同一处），但这类
    # 「两条路径各拼一份报文」的写法一旦分叉，就会变成「手动发的不带备注」这种
    # 只有真机才发现的缺陷。这里把它钉住。
    if read('lib/state.dart').count('AprsFmt.position(') != 1:
        errors.append('lib/state.dart 里组位置包的地方不止一处 —— 手动/自动上报会分叉，'
                      '备注与 HR= 可能只在其中一条上')
    need('lib/state.dart', 'void sendBeacon() {\n    _sendBeaconNow(force: true);',
         '手动上报没有走 _sendBeaconNow(force: true) —— 与自动上报不是同一条路径')
    need('lib/state.dart', 'comment: _beaconComment(),',
         '组包时没有带上 _beaconComment() —— 备注与 HR= 会丢')
    # 手动上报的提示必须说清「带了什么」（用户看不出时就会来问）
    need('lib/state.dart', 'String get beaconAttachedDetail',
         '缺少「实际附带内容」的拼装 —— 手动上报后用户无法确认心率高没带上')
    need('lib/map_page.dart', 'st.beaconAttachedDetail',
         '手动上报的提示没有列出实际附带的内容')

    # 心率必须显示在**主屏幕（地图页）**上（需求原话）
    need('lib/map_page.dart', 'Widget _hrChip()',
         '地图页没有心率胶囊 —— 心率只在设置页可见，主屏幕看不到')
    need('lib/map_page.dart', '_hrChip(),',
         '心率胶囊没有挂进地图左上竖列')

    # 心率带与佳明的入口位置：**必须在「设备」页的子页入口列表里**。
    #
    # 用户原话：「应该把这些链接放在设置设备列表里面，而不是…信标」——
    # 它们的语义是**设备**（要搜、要连、会掉线），与「信标怎么发」是两件事。
    # 一开始我放在信标设置页，位置就是错的。
    # 「位置来源」必须是**状态行**而不是二选一（用户实测指出：没启动追踪时
    # 「手机 GPS」也显示已选中、佳明那行也能被「选中」）。
    # 判据：位置来源那一行必须用 _statusRow（无选中圆点，只反映 loc.running），
    # 且它的文案必须区分「未追踪」。
    need('lib/tnc_page.dart', 'Widget _statusRow(',
         '位置来源没有用只读状态行 —— 会退化成「二选一」，未启动追踪时也显示已选中')
    need('lib/tnc_page.dart', 's.posSourceIdle',
         '位置来源没有显示「未追踪」状态 —— 用户看不出定位其实没在跑')
    need('lib/tnc_page.dart', '!state.loc.running',
         '位置来源没有参考 loc.running —— 未启动追踪时仍会显示成在跑')

    need('lib/device_page.dart', 'page: HrDevicePage(state: state)',
         '设备页的子页入口里没有「心率」—— 用户找不到连心率带的地方')
    need('lib/device_page.dart', 'page: GarminTrackPage(state: state)',
         '设备页的子页入口里没有「佳明 LiveTrack」')
    need('lib/hr_page.dart', 'HrSettingsCard(state: state)',
         '心率页没有复用 HrSettingsCard（不要另写一套，两处必然会漂）')
    # 反向：信标设置页里**不许**再塞这两样（放错了地方）
    if 'HrSettingsCard' in read('lib/settings_pages.dart') or \
            'GarminTrackEntry' in read('lib/settings_pages.dart'):
        errors.append('lib/settings_pages.dart 里又出现了心率卡 / 佳明入口 —— '
                      '它们的入口在「设置 → 设备」，不要塞进信标设置页')

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
