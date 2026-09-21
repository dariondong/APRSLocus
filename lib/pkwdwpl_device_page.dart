import 'dart:async';

import 'package:flutter/material.dart';

import 'net/tnc.dart';
import 'pkwdwpl.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── PKWDWPL 设备页（设备页的子页）───
///
/// 只保留这条链路**真的有**的东西：
///   ① 设备绑定 / 连接 / 重启（扫描已配对蓝牙设备或串口）
///   ② 航点接收统计（收了多少条、丢了多少条、校验不符多少条）
///   ③ 校验严格度开关
///
/// 刻意**没有** KISS 参数、初始化串、中继路径、射频信标、发射自检 ——
/// 这条链路是只读的（电台单向输出航点语句）。把这些控件摆在这里，
/// 用户会花时间调一个永远不会生效的参数，比「没有入口」糟糕得多。
/// 需要发射请用 TNC / 音频 / APRS-IS。
class PkwdwplDevicePage extends StatefulWidget {
  final AppState state;
  const PkwdwplDevicePage({super.key, required this.state});

  @override
  State<PkwdwplDevicePage> createState() => _PkwdwplDevicePageState();
}

class _PkwdwplDevicePageState extends State<PkwdwplDevicePage> {
  bool _scanning = false;
  bool _supported = true;
  bool _busy = false;

  AppState get st => widget.state;
  PkwdwplLink get link => widget.state.pkwdwpl;

  @override
  void initState() {
    super.initState();
    unawaited(_probe());
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
    // 先把界面文案取好：await 之后再用 context 会被 lint 拦
    // （而且真出现「页面已销毁」时下面 setState 会一并被 mounted 拦住）
    final S s = S.of(context);
    setState(() => _scanning = true);
    // Android 12+ 需要运行时蓝牙权限，先请求再扫描，否则列表恒为空
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

  Future<void> _toggleLink() async {
    final S s = S.of(context);
    setState(() => _busy = true);
    if (link.connected) {
      await link.disconnect();
      st.adoptDeviceLink(AppState.srcPkwdwpl, false);
      st.setConnStatus(ConnPhase.manual);
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
      // 设备冲突守卫必须在 connect **之前**：设备页绕过 AppState 直接连，
      // 只把守卫放在 _connectPkwdwpl 里对这里无效。
      // PKWDWPL 是只读链路 —— 冲突时不让路（TNC 优先），直接拒绝。
      final conflict = await st.guardDeviceConnect(AppState.srcPkwdwpl);
      if (conflict != null) {
        setState(() => _busy = false);
        _toast(s.deviceConflictTitle, color: C.red);
        return;
      }
      final ok = await link.connect();
      // 记回 AppState（_linkUp 表 + 来源启用）—— 否则会出现
      // 「已连上但界面全说未连接」（「当前链路」卡不渲染、横幅说未连接）。
      st.adoptDeviceLink(AppState.srcPkwdwpl, ok);
      if (ok) {
        st.setConnStatus(ConnPhase.pkwdwplConnected,
            arg: link.device?.label ?? '');
      } else if (link.status == PkwdwplStatus.openFailed) {
        _toast(s.tncOpenFailedHint, color: C.red);
      } else {
        _toast('${s.connectFailedCheckConfig} ${link.lastDetail}',
            color: C.red);
      }
    }
    st.reloadUi();
    if (mounted) setState(() => _busy = false);
  }

  String _statusText(S s) {
    switch (link.status) {
      case PkwdwplStatus.connected:
        return s.connected;
      case PkwdwplStatus.connecting:
        return s.connecting;
      case PkwdwplStatus.noDevice:
        return s.tncNotBound;
      case PkwdwplStatus.unsupported:
        return s.tncSupportedNo;
      case PkwdwplStatus.openFailed:
        return s.tncOpenFailedHint;
      case PkwdwplStatus.closed:
        return s.disconnected;
      case PkwdwplStatus.error:
        return s.connectFailedCheckConfig;
      default:
        return s.disconnected;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => SettingsPageShell(
        title: s.pkwdwplDeviceTitle,
        subtitle: s.pkwdwplDeviceDesc,
        icon: Icons.route_rounded,
        color: C.green,
        body: Column(children: [
          _bindCard(s),
          const SizedBox(height: 16),
          _statCard(s),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  /// ① 设备绑定与状态
  Widget _bindCard(S s) {
    final statusValue = link.connected
        ? '${_statusText(s)} · ${s.pkwdwplStats('${link.rxFrames}')}'
        : _statusText(s);
    return SettingsSectionCard(
      title: s.pkwdwplBindTitle,
      subtitle: s.pkwdwplBindSubtitle,
      icon: Icons.bluetooth_rounded,
      color: C.green,
      children: [
        // 冲突警告置顶：两条链路指向同一台设备时，先把话说清楚，
        // 否则用户只会看到「TNC 收不到报文」而不知道是自己的配置造成的。
        if (st.tncPkwdwplConflict)
          SettingsHint('${s.deviceConflictTitle}：${s.deviceConflictDesc}',
              color: C.red),
        SettingsHint(s.pkwdwplTip, color: C.green),
        SettingsRow2(
          s.tncBoundDevice,
          link.device?.label ?? s.tncNotBound,
          valueColor: link.device == null ? C.grey : C.ink,
        ),
        SettingsRow2(
          s.connection,
          statusValue,
          valueColor: link.connected
              ? C.green
              : (link.connecting ? C.blue : C.slate),
        ),
        // 「只收不发」必须写在明面上：这是它和 TNC 最大的区别
        SettingsRow2(
          s.dataSourcePkwdwpl,
          s.pkwdwplRxOnly,
          valueColor: C.orange,
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
                  foregroundColor: C.green,
                  side: BorderSide(color: C.green.withValues(alpha: 0.5)),
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
                  backgroundColor: link.connected ? C.red : C.green,
                  textStyle: ts(12, c: Colors.white, w: FontWeight.w600),
                ),
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
                  st.adoptDeviceLink(AppState.srcPkwdwpl, link.connected);
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
    // 该设备已被 TNC 绑定？两条链路连同一台设备会把**接收**字节流瓜分
    // （串口两个句柄各读一部分 / 蓝牙第二条 RFCOMM 顶掉第一条），
    // 症状是「TNC 能发不能收」—— 所以这里直接不允许重复绑定。
    final usedByTnc = !selected && st.deviceBoundBy(d.id) == AppState.srcTnc;
    return InkWell(
      onTap: usedByTnc
          ? null
          : () async {
              link.bind(d);
              if (mounted) setState(() {});
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? C.green.withValues(alpha: 0.10) : Colors.transparent,
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(children: [
          Icon(
            d.isBluetooth ? Icons.bluetooth_rounded : Icons.usb_rounded,
            size: 16,
            color: usedByTnc ? C.greyLight : (selected ? C.green : C.grey),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.label,
                    style: ts(12,
                        w: selected ? FontWeight.w700 : FontWeight.w500,
                        c: usedByTnc ? C.grey : null),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (usedByTnc)
                  Text(s.deviceInUseByTnc, style: ts(10, c: C.orange)),
              ],
            ),
          ),
          if (selected) Icon(Icons.check_circle_rounded, size: 16, color: C.green),
        ]),
      ),
    );
  }

  /// ② 航点接收统计 + 校验严格度
  ///
  /// 为什么要单列「丢弃/校验不符/其它 NMEA」：这条链路上「收不到台站」只有
  /// 三种可能（不是 `$PKWDWPL`、校验不符被丢、坐标非法），三个计数能把它们
  /// 分开 —— 否则用户只能靠猜。
  Widget _statCard(S s) {
    return SettingsSectionCard(
      title: s.pkwdwplStatTitle,
      subtitle: s.pkwdwplDeviceDesc,
      icon: Icons.insights_rounded,
      color: C.cyan,
      children: [
        SettingsRow2(
          s.pkwdwplStats('${link.rxFrames}'),
          '${link.rxBytes} B',
        ),
        SettingsRow2(
          s.pkwdwplStatRejected,
          '${link.rejected}',
          valueColor: link.rejected > 0 ? C.orange : C.grey,
        ),
        SettingsRow2(
          s.pkwdwplStatMismatch,
          '${link.checksumMismatches}',
          valueColor: link.checksumMismatches > 0 ? C.orange : C.grey,
        ),
        SettingsRow2(
          s.pkwdwplStatIgnored,
          '${link.ignoredLines}',
          valueColor: C.slate,
        ),
        if (link.frameOverflows > 0)
          SettingsHint('帧缓冲溢出 ${link.frameOverflows} 字节', color: C.red),
        SettingsSwitch(
          s.pkwdwplStrictChecksum,
          value: link.config.strictChecksum,
          color: C.cyan,
          onChanged: (v) async {
            link.config.strictChecksum = v;
            await link.persistConfig();
            if (mounted) setState(() {});
          },
        ),
        SettingsHint(s.pkwdwplStrictChecksumTip),
        SettingsSwitch(
          s.kissAutoReconnect,
          value: link.config.autoReconnect,
          color: C.green,
          onChanged: (v) async {
            link.config.autoReconnect = v;
            await link.persistConfig();
            if (mounted) setState(() {});
          },
        ),
        if (link.logs.isEmpty)
          SettingsHint(s.pkwdwplLogEmpty)
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in link.logs.take(12))
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
    );
  }
}
