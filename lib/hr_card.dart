import 'package:flutter/material.dart';

import 'ble_hr.dart';
import 'garmin.dart';
import 'garmin_page.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// 信标设置页里的「心率」卡：蓝牙心率带（BLE 标准心率服务）的连接与上报开关。
///
/// 为什么做成**独立组件**而不是塞进设置页的 children：它自己要在扫描/连接状态
/// 变化时重建（扫描结果是异步来的），组件内部挂 ListenableBuilder 最省事，
/// 也不必假设宿主页面有没有在监听 AppState。
class HrSettingsCard extends StatefulWidget {
  final AppState state;
  const HrSettingsCard({super.key, required this.state});

  @override
  State<HrSettingsCard> createState() => _HrSettingsCardState();
}

class _HrSettingsCardState extends State<HrSettingsCard> {
  BleHrService get _hr => widget.state.bleHr;

  @override
  void initState() {
    super.initState();
    // 幂等：挂事件通道 + 问一次本机支不支持（不支持的平台会显示说明）。
    _hr.ensureInit();
  }

  Future<void> _startScan() async {
    // 权限必须先要：Android 12+ 是 BLUETOOTH_SCAN/CONNECT，老系统是定位权限。
    final ok = await _hr.requestPermissions();
    if (!ok) return;
    await _hr.startScan();
  }

  Future<void> _connect(BleHrDevice d) async {
    // 与 TNC 的防冲突在**原生侧**做：只有那里知道「当前哪条 SPP 链路连着、
    // 对端地址是什么」（MainActivity 把地址集合传给 BleHrManager，撞了就回
    // ADDR_IN_USE，见该文件注释）。Dart 侧再挡一道只会挡在信息不全的地方。
    final ok = await _hr.connect(d);
    if (ok && mounted) {
      widget.state.setBleHrDevice(d.id, d.name.isEmpty ? d.id : d.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = widget.state;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final h = _hr;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ① 上报开关（始终可见：没连上心率带也可以先看好这项是什么意思）
              Row(
                children: [
                  Icon(Icons.favorite_rounded, size: 15, color: C.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(s.hrIncludeInBeacon,
                        style: ts(12, c: C.red, w: FontWeight.w700)),
                  ),
                  Switch(
                    value: st.beaconIncludeHr,
                    onChanged: st.setBeaconIncludeHr,
                  ),
                ],
              ),
              if (st.beaconIncludeHr)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(s.hrIncludeHint, style: ts(10.5, c: C.grey, h: 1.5)),
                ),
              // ①b 心率来自**佳明**时的说明（用户要求：「如果链接了佳明就提示从
              // 佳明追踪获取」）。放在设备区之上：它是「这个数字哪来的」的答案，
              // 比「有没有插胸带」更靠前 —— 佳明在供数据时，用户压根不需要插胸带。
              if (st.garminOn && st.garmin.fresh)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: C.redBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Icon(Icons.watch_rounded, size: 14, color: C.red),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          st.myHr == null
                              ? s.hrFromGarmin
                              : '${s.hrFromGarmin} · ${s.hrLineHr('${st.myHr} bpm')}',
                          style: ts(11, c: C.red, w: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                ),
              // ② 设备连接区
              if (!h.isAndroid || !h.supported)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(s.hrNotSupported, style: ts(11, c: C.orange, h: 1.5)),
                )
              else if (h.connected) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: C.redBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.favorite_rounded, size: 18, color: C.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.hrConnected(h.deviceName ?? '--'),
                              style: ts(11.5, w: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              h.bpm == null
                                  ? s.hrWaitReading
                                  : '${h.bpm} bpm'
                                      '${h.batteryPct != null ? ' · 🔋${h.batteryPct}%' : ''}',
                              style: ts(
                                h.bpm == null ? 10.5 : 16,
                                w: FontWeight.w800,
                                c: h.bpm == null ? C.grey : C.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _hr.disconnect(),
                        child: Text(s.hrDisconnect, style: ts(11, c: C.grey)),
                      ),
                      IconButton(
                        tooltip: s.hrForget,
                        icon: Icon(Icons.link_off_rounded, size: 16, color: C.grey),
                        onPressed: () => st.clearBleHrDevice(),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: h.scanning ? () => _hr.stopScan() : _startScan,
                        icon: Icon(
                          h.scanning
                              ? Icons.stop_circle_outlined
                              : Icons.bluetooth_searching_rounded,
                          size: 15,
                        ),
                        label: Text(
                          h.scanning ? s.hrScanning : s.hrSearch,
                          style: ts(11.5, w: FontWeight.w600),
                        ),
                      ),
                    ),
                    // 记住过设备 → 给一个一键重连（省掉再扫一次）
                    if (st.bleHrId.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _connect(
                          BleHrDevice(
                            id: st.bleHrId,
                            name: st.bleHrName,
                            rssi: 0,
                          ),
                        ),
                        child: Text(s.hrConnect, style: ts(11.5, c: C.blue)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // 扫描结果（只有广播标准心率服务的设备才会出现在这里）
                for (final d in h.devices)
                  InkWell(
                    onTap: () => _connect(d),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Icon(Icons.bluetooth_rounded, size: 15, color: C.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              d.name.isEmpty ? d.id : '${d.name}  (${d.id})',
                              style: ts(11.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('${d.rssi} dBm', style: ts(10, c: C.grey)),
                        ],
                      ),
                    ),
                  ),
                if (h.scanning && h.devices.isEmpty)
                  Text(s.hrScanning, style: ts(11, c: C.grey)),
                if (!h.scanning && h.devices.isEmpty && h.lastError.isEmpty)
                  Text(s.hrNoDevice, style: ts(10.5, c: C.grey, h: 1.5)),
              ],
              // ③ 错误与说明
              if (h.lastError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    h.lastError.startsWith('conflict:')
                        ? s.hrConflictWithTnc
                        : h.lastError,
                    style: ts(10.5, c: C.orange, h: 1.5),
                  ),
                ),
              if (h.isAndroid && h.supported)
                Text(s.hrStrapHint, style: ts(10, c: C.greyLight, h: 1.5)),
            ],
          ),
        );
      },
    );
  }
}

/// 信标设置页里通往「佳明 LiveTrack」设置页的入口行。
class GarminTrackEntry extends StatelessWidget {
  final AppState state;
  const GarminTrackEntry({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final g = state.garmin;
        final sub = !state.garminOn
            ? (state.garminUrl.isEmpty ? s.garminUrlHint : state.garminUrl)
            : s.garminStats(
                '${g.forwarded}',
                g.lastFetchAt == null
                    ? '--'
                    : '${g.lastFetchAt!.hour.toString().padLeft(2, '0')}:'
                        '${g.lastFetchAt!.minute.toString().padLeft(2, '0')}',
              );
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GarminTrackPage(state: state)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: state.garminOn ? C.greenBg : C.bgSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.watch_rounded,
                      size: 16, color: state.garminOn ? C.green : C.grey),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.garminCardTitle, style: ts(12, c: C.slate)),
                      const SizedBox(height: 1),
                      Text(
                        sub,
                        style: ts(10, c: state.garminOn ? C.green : C.greyLight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 16, color: C.grey),
              ],
            ),
          ),
        );
      },
    );
  }
}
