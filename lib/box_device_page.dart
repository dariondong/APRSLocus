import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'box.dart';
import 'net/tnc.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── APRSlocusBOX 设备页（设备页的子页）───
///
/// 这个页面回答的是「**我那台小盒子现在怎么样、我要它做什么**」，所以按
/// 「先连上 → 再看清 → 再动手」排：
///
///   ① 连接（扫码/绑定/连接/断开，和 TNC·PKWDWPL 同一套交互）
///   ② 状态（盒子自己报回来的配置 + 事件计数：它到底在不在发、收了多少）
///   ③ 配置（`CFG key=value`，键名与盒子 README 逐字一致 —— 技术项不翻译）
///   ④ 喂位置（手机当盒子的位置源：`POS lat lon …`）
///   ⑤ 动作（信标 / 状态 / 重连 / 清空 / 自检 / 重启）
///   ⑥ 事件日志（盒子推的 `EVT …` 行，出问题时的唯一证据）
///
/// ⚠ 这里**刻意不做的两件事**：
///   * 不把盒子列成「数据来源」—— 报文是盒子自己上 APRS-IS 的，本应用再收一遍
///     只会与 APRS-IS / TNC 重复；盒子对手机的意义是「一台要管的设备」；
///   * 不自动发任何**会占用信道**的东西（信标/状态报文）—— 那些必须由人点，
///     与 APRSlocus 里「射频发射永远要显式」的那条规矩一致。
class BoxDevicePage extends StatefulWidget {
  final AppState state;
  const BoxDevicePage({super.key, required this.state});

  @override
  State<BoxDevicePage> createState() => _BoxDevicePageState();
}

class _BoxDevicePageState extends State<BoxDevicePage> {
  bool _scanning = false;
  bool _supported = true;
  bool _busy = false;
  late final TextEditingController _baud;

  AppState get st => widget.state;
  BoxLink get link => st.box;

  @override
  void initState() {
    super.initState();
    _baud = TextEditingController(text: '${link.config.baud}');
    unawaited(_probe());
  }

  @override
  void dispose() {
    _baud.dispose();
    super.dispose();
  }

  Future<void> _probe() async {
    final ok = await link.supported();
    if (mounted) setState(() => _supported = ok);
  }

  void _toast(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? C.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _scan() async {
    final S s = S.of(context);
    setState(() => _scanning = true);
    // Android 12+ 的蓝牙运行时权限：先请求再扫描，否则列表恒为空
    if (!await link.requestPermissions()) {
      if (mounted) {
        setState(() => _scanning = false);
        _toast(s.tncNeedPermission, color: C.red);
      }
      return;
    }
    await link.scan();
    if (mounted) setState(() => _scanning = false);
  }

  /// 连接 / 断开。盒子的「启用」状态也在这里翻转（持久化）——
  /// 启用之后 AppState 会像对待 PKWDWPL 一样在掉线时自动重连。
  Future<void> _toggleLink() async {
    final S s = S.of(context);
    setState(() => _busy = true);
    if (link.connected) {
      link.config.enabled = false;
      await link.persistConfig();
      await link.disconnect();
      st.adoptBoxLink(false);
    } else {
      if (link.device == null) {
        setState(() => _busy = false);
        _toast(s.tncNotBound, color: C.orange);
        return;
      }
      if (!await link.requestPermissions()) {
        setState(() => _busy = false);
        _toast(s.tncNeedPermission, color: C.red);
        return;
      }
      // 设备冲突守卫必须在 connect **之前**（设备页绕过 AppState 直接连）
      final conflict = await st.guardDeviceConnect(AppState.srcBox);
      if (conflict != null) {
        setState(() => _busy = false);
        _toast(s.deviceConflictTitle, color: C.red);
        return;
      }
      final ok = await link.connect();
      // ⚠ **连上之后才记「启用」**：以前先写 `enabled = true` 再连 —— 连不上时它
      // 仍被记成启用，自动重连定时器于是**永远**在试，而每试一次都是一次会阻塞
      // 十几秒的 RFCOMM 连接（把"连不上"放大成"反复卡主线程 → ANR/闪退"）。
      link.config.enabled = ok;
      await link.persistConfig();
      st.adoptBoxLink(ok);
      if (!ok) {
        if (link.status == BoxStatus.openFailed) {
          _toast(s.tncOpenFailedHint, color: C.red);
        } else {
          _toast('${s.connectFailedCheckConfig} ${link.lastDetail}',
              color: C.red);
        }
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  String _statusText(S s) {
    switch (link.status) {
      case BoxStatus.connected:
        return s.connected;
      case BoxStatus.connecting:
        return s.connecting;
      case BoxStatus.noDevice:
        return s.tncNotBound;
      case BoxStatus.unsupported:
        return s.tncSupportedNo;
      case BoxStatus.openFailed:
        return s.tncOpenFailedHint;
      case BoxStatus.closed:
        return s.disconnected;
      case BoxStatus.error:
        return s.connectFailedCheckConfig;
      default:
        return s.disconnected;
    }
  }

  /// 盒子上报的 `link` 值 → 人话。返回 null = 还不知道。
  String? _linkModeName(String? v) {
    switch (v) {
      case '0':
        return 'wifi';
      case '1':
        return 'bt';
      case '2':
        return 'both';
      default:
        return null;
    }
  }

  /// 盒子的 APRS-IS passcode 是不是 `-1`（= 只收不发）。
  ///
  /// 为什么要专门判它：盒子上会显示 `IS RX-only`，而**原因在盒子那一侧**：
  /// 服务器对 `pass -1` 或错误的 passcode 只给收。用户看不到原因，只会以为
  /// "盒子收不到数据/坏了"。这里直接把结论和修法写在配置卡片上。
  bool get _passIsRxOnly => (link.cfg['pass'] ?? '') == '-1';

  /// 蓝牙管理只在盒子的 `link` 是 `bt`/`both` 时可用 —— 这是**最容易
  /// 误判成「蓝牙坏了」**的一条，所以单独拎出来提前说清楚。
  bool get _btWontWork {
    final m = _linkModeName(link.cfg['link']);
    return link.device != null && link.device!.isBluetooth && m == 'wifi';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => SettingsPageShell(
        guideId: 'device',
        state: widget.state,
        title: s.boxDeviceTitle,
        subtitle: s.boxDeviceDesc,
        icon: Icons.developer_board_rounded,
        color: C.indigo,
        body: Column(children: [
          _bindCard(s),
          const SizedBox(height: 16),
          _statCard(s),
          const SizedBox(height: 16),
          _cfgCard(s),
          const SizedBox(height: 16),
          _pushCard(s),
          const SizedBox(height: 16),
          _feedCard(s),
          const SizedBox(height: 16),
          _actCard(s),
          const SizedBox(height: 16),
          _evtCard(s),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  // ─── ① 连接 ───

  Widget _bindCard(S s) {
    return SettingsSectionCard(
      title: s.boxBindTitle,
      subtitle: s.boxDeviceDesc,
      icon: Icons.bluetooth_rounded,
      color: C.indigo,
      children: [
        SettingsHint(s.boxModeTip, color: C.indigo),
        if (_btWontWork) SettingsHint(s.boxBtLinkWarn, color: C.orange),
        SettingsRow2(
          s.tncBoundDevice,
          link.device?.label ?? s.tncNotBound,
          valueColor: link.device == null ? C.grey : C.ink,
        ),
        SettingsRow2(
          s.connection,
          link.connected
              ? '${_statusText(s)} · ${link.txCount}/${link.rxLines}'
              : _statusText(s),
          valueColor: link.connected
              ? C.green
              : (link.connecting ? C.blue : C.slate),
        ),
        if (!_supported) SettingsHint(s.tncSupportedNo, color: C.orange),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _scanning || !_supported ? null : _scan,
                icon: _scanning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded, size: 16),
                label: Text(s.tncScanPaired),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.indigo,
                  side: BorderSide(color: C.indigo.withValues(alpha: 0.5)),
                  textStyle: ts(12, w: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy || !_supported ? null : _toggleLink,
                icon: Icon(
                  link.connected
                      ? Icons.link_off_rounded
                      : Icons.link_rounded,
                  size: 16,
                ),
                label: Text(link.connected ? s.disconnect : s.tncConnectAction),
                style: FilledButton.styleFrom(
                  backgroundColor: link.connected ? C.red : C.indigo,
                  textStyle: ts(12, c: Colors.white, w: FontWeight.w600),
                ),
              ),
            ),
          ]),
        ),
        // 串口线速：只对需要波特率的设备显示（蓝牙 SPP 没有这个概念）。
        // 填错的表现是「连上了但全是乱码」，比连不上更难判断，所以给它一个
        // 明确的入口，默认值就是盒子固件的 115200。
        if (link.device?.needsBaud == true)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Row(children: [
              Expanded(child: Text(s.boxBaud, style: ts(12, c: C.slate))),
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _baud,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: ts(13, w: FontWeight.w600),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (v) async {
                    final n = int.tryParse(v.trim());
                    if (n == null || n <= 0) return;
                    link.config.baud = n;
                    await link.persistConfig();
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ]),
          ),
        if (link.device != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Row(children: [
              TextButton.icon(
                onPressed: () async {
                  link.bind(null);
                  setState(() {});
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 15),
                label: Text(s.tncUnbind, style: ts(12)),
                style: TextButton.styleFrom(foregroundColor: C.grey),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  setState(() => _busy = true);
                  await link.restart();
                  st.reloadUi();
                  if (mounted) setState(() => _busy = false);
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 15),
                label: Text(s.tncRestart, style: ts(12)),
                style: TextButton.styleFrom(foregroundColor: C.orange),
              ),
            ]),
          ),
        if (link.devices.isNotEmpty) ...[
          Divider(height: 1, color: C.border),
          for (final d in link.devices) _deviceTile(d),
        ] else if (!_scanning)
          SettingsHint(s.tncNoPaired, icon: Icons.bluetooth_disabled_rounded),
      ],
    );
  }

  Widget _deviceTile(TncDevice d) {
    final s = S.of(context);
    final selected = link.device?.id == d.id;
    // 同一台设备被别的链路绑走？直接不允许重复绑定 —— 两条链路连同一台
    // 设备会把接收字节流瓜分（串口各读一半 / 蓝牙第二条 RFCOMM 顶掉第一条），
    // 症状是「能发不能收」，从界面上根本看不出原因。
    final owner = st.deviceBoundBy(d.id);
    final usedByOther = !selected && owner != null && owner != AppState.srcBox;
    final ownerName = owner == AppState.srcTnc
        ? 'TNC'
        : (owner == AppState.srcPkwdwpl ? 'PKWDWPL' : '');
    return InkWell(
      onTap: usedByOther
          ? null
          : () async {
              link.bind(d);
              if (mounted) setState(() {});
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? C.indigo.withValues(alpha: 0.10) : Colors.transparent,
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(children: [
          Icon(
            d.isBluetooth ? Icons.bluetooth_rounded : Icons.usb_rounded,
            size: 16,
            color: usedByOther ? C.greyLight : (selected ? C.indigo : C.grey),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.label,
                    style: ts(12,
                        w: selected ? FontWeight.w700 : FontWeight.w500,
                        c: usedByOther ? C.grey : null),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (usedByOther)
                  Text('${s.deviceInUseByTnc} · $ownerName',
                      style: ts(10, c: C.orange)),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, size: 16, color: C.indigo),
        ]),
      ),
    );
  }

  // ─── ② 状态 ───

  Widget _statCard(S s) {
    final cfg = link.cfg;
    final call = (cfg['call'] ?? '').trim();
    final ssid = (cfg['ssid'] ?? '').trim();
    final full = call.isEmpty
        ? '—'
        : (ssid.isEmpty || ssid == '0' ? call : '$call-$ssid');
    final mode = _linkModeName(cfg['link']);
    final host = cfg['host'] ?? '';
    final port = cfg['port'] ?? '';
    final bsec = cfg['bsec'] ?? '';
    return SettingsSectionCard(
      title: s.boxStatTitle,
      subtitle: link.cfgAt == null
          ? s.boxCfgEmpty
          : s.boxCfgRead,
      icon: Icons.insights_rounded,
      color: C.cyan,
      children: [
        SettingsRow2(
          s.callsign,
          full,
          valueColor: call.isEmpty ? C.grey : C.ink,
        ),
        SettingsRow2(
          s.boxStatLinkMode,
          mode == null
              ? '—'
              : (mode == 'wifi' ? 'wifi (no BT)' : mode),
          valueColor: mode == null
              ? C.grey
              : (mode == 'wifi' ? C.orange : C.green),
        ),
        SettingsRow2(
          s.boxStatBeacon,
          bsec.isEmpty || bsec == '0'
              ? '—'
              : '$bsec s',
          valueColor: C.ink,
        ),
        SettingsRow2(
          s.boxStatHost,
          (host.isEmpty && port.isEmpty) ? '—' : '$host:$port',
          valueColor: C.ink,
        ),
        SettingsRow2(
          s.boxStatGps,
          (cfg['gps'] ?? '').isEmpty || cfg['gps'] == '0'
              ? 'off'
              : '${cfg['gps']} bd',
          valueColor: C.ink,
        ),
        SettingsRow2(
          s.boxStatEvents,
          'TX ${link.txCount} · BEACON ${link.beaconCount} · '
              'RXMSG ${link.rxMsgCount} · ACK ${link.ackCount}'
              '${link.errCount > 0 ? ' · ERR ${link.errCount}' : ''}',
          valueColor: link.errCount > 0 ? C.orange : C.slate,
        ),
        SettingsRow2(
          s.boxLastEvent,
          link.lastEvent.isEmpty ? s.boxNoEventYet : link.lastEvent,
          valueColor: link.lastEvent.isEmpty ? C.grey : C.ink,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: Row(children: [
            TextButton.icon(
              onPressed: link.connected
                  ? () {
                      link.readCfg();
                      setState(() {});
                    }
                  : null,
              icon: const Icon(Icons.download_rounded, size: 15),
              label: Text(s.boxCfgRead, style: ts(12)),
              style: TextButton.styleFrom(foregroundColor: C.cyan),
            ),
          ]),
        ),
      ],
    );
  }

  // ─── ③ 配置 ───

  Widget _cfgCard(S s) {
    final keys = link.cfg.keys.toList();
    return SettingsSectionCard(
      title: s.boxCfgTitle,
      subtitle: s.boxCfgSubtitle,
      icon: Icons.tune_rounded,
      color: C.indigo,
      children: [
        SettingsHint(s.boxCfgRebootHint, color: C.orange),
        // `pass=-1`（默认）→ 盒子连上 APRS-IS 也只会收到 "RX-only"：
        // 这条不写在明处，用户会以为盒子坏了。
        if (link.cfg.isNotEmpty && _passIsRxOnly)
          SettingsHint(s.boxPassHint, color: C.orange),
        if (keys.isEmpty)
          SettingsHint(s.boxCfgEmpty)
        else
          for (final k in keys)
            InkWell(
              onTap: link.connected ? () => unawaited(_editValue(k)) : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: C.border, width: 0.4)),
                ),
                child: Row(children: [
                  Text(k,
                      style: ts(12, w: FontWeight.w600, c: C.slate)
                          .copyWith(fontFamily: 'monospace')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      link.cfg[k] ?? '',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(12, w: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_rounded,
                      size: 13, color: link.connected ? C.indigo : C.greyLight),
                ]),
              ),
            ),
      ],
    );
  }

  Future<void> _editValue(String key) async {
    final s = S.of(context);
    final cur = link.cfg[key] ?? '';
    final masked = cur == kBoxMaskedValue;
    final ctl = TextEditingController(text: masked ? '' : cur);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${s.boxCfgEditTitle} · $key', style: ts(15, w: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctl,
            autofocus: true,
            style: ts(14).copyWith(fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: masked ? s.boxCfgMasked : cur,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(s.boxCfgEditHint, style: ts(11, c: C.slate)),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctl.text),
            style: FilledButton.styleFrom(backgroundColor: C.indigo),
            child: Text(s.ok),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (v == null) return;
    // 密码类：盒子回读是 `***`。留空 = 不改（空值写回去会把密码变成空）。
    if (masked && v.isEmpty) {
      _toast(s.boxCfgNoChange, color: C.grey);
      return;
    }
    if (link.setCfg(key, v)) {
      _toast('${s.boxCfgSent} · $key=$v', color: C.green);
      // 改完立刻回读：界面显示的是**盒子里的真值**，而不是我们以为写进去的值
      await Future<void>.delayed(const Duration(milliseconds: 400));
      link.readCfg();
      if (mounted) setState(() {});
    } else {
      _toast(s.disconnected, color: C.orange);
    }
  }

  // ─── ④ 手机状态推给盒子 ───

  /// 把**手机这侧看到的东西**推给盒子：自己的速度/方位/海拔/未读 + 附近台站。
  ///
  /// 与「喂位置」是两件事，所以放在两张卡片里：
  ///   * 这里推的只写盒子的**屏幕**（PHONE 页），不上射频；
  ///   * 喂位置喂的是**坐标**，盒子拿它当位置来源（会进信标）。
  /// 混在一个开关里，用户会以为"关了就不发信标了"。
  Widget _pushCard(S s) {
    return SettingsSectionCard(
      title: s.boxPushTitle,
      subtitle: s.boxPushHint,
      icon: Icons.upload_rounded,
      color: C.cyan,
      children: [
        SettingsSwitch(
          s.boxPushStatus,
          value: link.config.pushStatus,
          color: C.cyan,
          onChanged: (v) async {
            link.config.pushStatus = v;
            await link.persistConfig();
            if (mounted) setState(() {});
          },
        ),
      ],
    );
  }

  // ─── ⑤ 喂位置 ───

  Widget _feedCard(S s) {
    return SettingsSectionCard(
      title: s.boxFeedTitle,
      subtitle: s.boxFeedSubtitle,
      icon: Icons.my_location_rounded,
      color: C.green,
      children: [
        SettingsSwitch(
          s.boxFeedAuto,
          value: link.config.feedPos,
          color: C.green,
          onChanged: (v) async {
            link.config.feedPos = v;
            await link.persistConfig();
            if (mounted) setState(() {});
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: link.connected && st.myHasFix
                    ? () {
                        final ok = _feedNow();
                        _toast(ok ? s.boxCfgSent : s.disconnected,
                            color: ok ? C.green : C.orange);
                      }
                    : null,
                icon: const Icon(Icons.send_rounded, size: 15),
                label: Text(s.boxFeedSend),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.green,
                  side: BorderSide(color: C.green.withValues(alpha: 0.5)),
                  textStyle: ts(12, w: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: link.connected
                    ? () {
                        link.clearPos();
                        _toast(s.boxFeedStop, color: C.orange);
                      }
                    : null,
                icon: const Icon(Icons.location_off_rounded, size: 15),
                label: Text(s.boxFeedStop),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.orange,
                  side: BorderSide(color: C.orange.withValues(alpha: 0.5)),
                  textStyle: ts(12, w: FontWeight.w600),
                ),
              ),
            ),
          ]),
        ),
        if (!st.myHasFix) SettingsHint(s.boxFeedNoFix, color: C.orange),
      ],
    );
  }

  /// 把手机**当前**位置喂过去。单位换算在这里一次做完：
  /// `mySpeed` 是 km/h，盒子要 m/s；`myAlt` 是米（盒子也是米）。
  bool _feedNow() {
    if (!st.myHasFix) return false;
    return link.feedPos(
      lat: st.myLat!,
      lon: st.myLng!,
      altM: st.myAlt,
      speedMps: (st.mySpeed ?? 0) / 3.6,
      courseDeg: st.myCourse,
    );
  }

  // ─── ⑤ 动作 ───

  Widget _actCard(S s) {
    final on = link.connected;
    Widget btn(IconData icon, String label, Future<void> Function() fn,
        Color color) {
      return OutlinedButton.icon(
        onPressed: on ? () => unawaited(fn()) : null,
        icon: Icon(icon, size: 15),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          textStyle: ts(12, w: FontWeight.w600),
        ),
      );
    }

    return SettingsSectionCard(
      title: s.boxActTitle,
      icon: Icons.sports_esports_rounded,
      color: C.orange,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            btn(Icons.cell_tower_rounded, s.boxActBeacon, () async {
              link.beacon();
            }, C.orange),
            btn(Icons.info_outline_rounded, s.boxActStatus, () async {
              link.sendStatusPacket();
            }, C.orange),
            btn(Icons.wifi_rounded, s.boxActNet, () async {
              link.reconnectNet();
            }, C.cyan),
            btn(Icons.cleaning_services_rounded, s.boxActClear, () async {
              link.clearStations();
            }, C.grey),
            btn(Icons.rule_rounded, s.boxActTest, () async {
              link.selfTest();
            }, C.green),
            btn(Icons.restart_alt_rounded, s.boxActReboot, () async {
              link.rebootBox();
            }, C.red),
          ]),
        ),
      ],
    );
  }

  // ─── ⑥ 事件日志 ───

  Widget _evtCard(S s) {
    final logs = link.logs;
    return SettingsSectionCard(
      title: s.boxEvtTitle,
      subtitle: s.boxDeviceDesc,
      icon: Icons.receipt_long_rounded,
      color: C.slate,
      children: [
        if (logs.isEmpty)
          SettingsHint(s.tncLogEmpty)
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(children: [
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: logs.join('\n'))),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: Text(s.copyAllLogs, style: ts(11)),
                style: TextButton.styleFrom(
                  foregroundColor: C.slate,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 30),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in logs.take(30))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      l,
                      style: ts(10, c: C.slate, h: 1.35)
                          .copyWith(fontFamily: 'monospace'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
