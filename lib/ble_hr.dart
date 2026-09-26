import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

/// 一个扫描到的 BLE 心率设备（广播里带标准心率服务 0x180D 的那些）。
class BleHrDevice {
  final String id; // MAC 地址（Android 上同时是连接用的标识）
  final String name; // 可能是空串：很多胸带不广播名字
  final int rssi;
  const BleHrDevice({required this.id, required this.name, required this.rssi});
}

/// 蓝牙**心率广播**设备（BLE，标准心率服务 0x180D）。
///
/// ── 与 TNC 的蓝牙通道是什么关系（用户明确要求「不要起冲突」）──
///
/// 两条链路走的是**两套完全不同的栈**：
///   * TNC / PKWDWPL 用的是**经典蓝牙 SPP**（RFCOMM，`createRfcommSocketToServiceRecord`），
///     面向「已配对设备」；
///   * 心率用的是 **BLE GATT**（扫描 + 连接 + 订阅通知），面向「广播设备」。
/// 系统层面互不抢占，可以同时工作（心率带与电台是两台设备）。
///
/// 真正会造成冲突的只有两件事，两边都已经避开：
///   1. **经典发现 `BluetoothAdapter.startDiscovery()` 会打断正在工作的 SPP 连接**
///      （发现过程会占住蓝牙控制通道）。原生侧只用 `BluetoothLeScanner`，绝不做经典发现。
///   2. **同一台设备不能同时当两者**：Android 给双模设备的经典地址与 BLE 地址是
///      同一个 MAC，把正在给 TNC 用的电台选成心率设备会两边都坏。原生 `connect()`
///      会拿「当前正被 SPP 占用的地址」比对并直接拒绝（见 BleHrManager 的 ADDR_IN_USE），
///      Dart 侧在这里再挡一道，给出人话原因。
///
/// ── 为什么是「广播设备」而不是「手机 App 的心率」──
/// 国标/行业里的心率带（Polar H10、Garmin HRM、迈金、Coospo…）全都广播标准
/// 心率服务，所以只要实现这一个服务就能覆盖绝大多数设备，不需要为每家写适配。
class BleHrService {
  BleHrService._();
  static final BleHrService instance = BleHrService._();

  static const MethodChannel _ch = MethodChannel('com.aprslocus/blehr');
  static const EventChannel _ev = EventChannel('com.aprslocus/blehr_events');

  /// 本平台是否实现了 BLE 心率原生侧。
  ///
  /// Android（`android/.../BleHrManager.kt`）与 iOS（`ios/Runner/BleHrPlugin.swift`）
  /// 都有实现；桌面与 Web 没有。与 TNC/PKWDWPL 同一口径：**有原生链路的平台才可用**。
  bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// 原生侧 `isSupported()` 的结果（没有蓝牙适配器时为 false）。
  bool supported = false;
  bool initialized = false;

  /// 扫描状态与扫描结果。
  bool scanning = false;
  final List<BleHrDevice> devices = [];

  /// 连接状态。
  bool connecting = false;
  bool connected = false;
  String? deviceId;
  String? deviceName;
  bool deviceBonded = false;

  /// 最近一次心率（bpm）。`null` = 还没收到过心跳。
  int? bpm;
  /// 电极接触状态（有些带子会报「没贴身」——这种读数不该信）。
  bool contact = true;
  /// 设备电量（有些心率带会通过标准电池服务报；拿不到就是 null）。
  int? batteryPct;
  DateTime? lastBeatAt;

  /// 人话错误（UI 直接显示；空串表示没有错误）。
  String lastError = '';

  /// 任何状态变化都回调一次（AppState 借此 `_notify()` 让界面刷新）。
  void Function()? onChanged;

  StreamSubscription? _sub;

  void _changed() => onChanged?.call();

  /// 幂等初始化：挂事件通道 + 问一次 isSupported。
  Future<void> ensureInit() async {
    if (initialized) return;
    initialized = true;
    if (!platformSupported) {
      supported = false;
      return;
    }
    _sub ??= _ev.receiveBroadcastStream().listen(_onEvent, onError: (e) {
      lastError = '心率事件流异常: $e';
      _changed();
    });
    try {
      supported = await _ch.invokeMethod<bool>('isSupported') ?? false;
    } catch (e) {
      supported = false;
      lastError = '心率通道不可用: $e';
    }
    _changed();
  }

  Future<bool> requestPermissions() async {
    if (!platformSupported) return false;
    try {
      return await _ch.invokeMethod<bool>('requestPermissions') ?? false;
    } catch (e) {
      lastError = '申请蓝牙权限失败: $e';
      _changed();
      return false;
    }
  }

  /// 开始扫描。**只在用户主动挑选设备时扫描**：BLE 扫描是持续射频活动，
  /// 开着不放既费电、也会与正在工作的链路争用天线。
  Future<bool> startScan() async {
    if (!platformSupported || !supported) return false;
    lastError = '';
    try {
      final ok = await _ch.invokeMethod<bool>('startScan') ?? false;
      if (ok) {
        devices.clear();
        scanning = true;
        _changed();
      }
      return ok;
    } catch (e) {
      lastError = '扫描失败: $e';
      scanning = false;
      _changed();
      return false;
    }
  }

  Future<void> stopScan() async {
    if (!platformSupported) return;
    try {
      await _ch.invokeMethod<void>('stopScan');
    } catch (_) {
      // 停扫描失败无所谓（原生侧 15 秒也会自动停）
    }
    scanning = false;
    _changed();
  }

  Future<bool> connect(BleHrDevice d, {Set<String> busySppAddresses = const {}}) async {
    if (!platformSupported || !supported) return false;
    // 与 TNC 的显式防冲突（见类注释第 2 条）：双模设备的经典地址与 BLE 地址相同。
    if (busySppAddresses.contains(d.id.toUpperCase())) {
      lastError = 'conflict:${d.id}';
      _changed();
      return false;
    }
    lastError = '';
    connecting = true;
    _changed();
    try {
      final ok = await _ch.invokeMethod<bool>('connect', {'address': d.id}) ?? false;
      if (!ok) connecting = false;
      _changed();
      return ok;
    } catch (e) {
      connecting = false;
      lastError = '连接失败: $e';
      _changed();
      return false;
    }
  }

  Future<void> disconnect() async {
    if (!platformSupported) return;
    try {
      await _ch.invokeMethod<void>('disconnect');
    } catch (_) {}
    connected = false;
    connecting = false;
    bpm = null;
    deviceId = null;
    deviceName = null;
    _changed();
  }

  /// 忘了这台设备（清掉记住的地址，下次不自动重连）。
  void forget() {
    deviceId = null;
    deviceName = null;
    connected = false;
    bpm = null;
    lastError = '';
    _changed();
  }

  /// 断开重连用：把记住的设备重新连上（失败不抛，只置错误）。
  Future<void> reconnectRemembered() async {
    final id = deviceId;
    if (id == null || connected) return;
    await connect(BleHrDevice(id: id, name: deviceName ?? '', rssi: 0));
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'];
    switch (type) {
      case 'scan':
        scanning = event['scanning'] == true;
        if (!scanning) {
          // 原生 15 秒自动停
        }
        break;
      case 'device':
        final id = event['id'] as String?;
        if (id == null || id.isEmpty) return;
        final name = (event['name'] as String?) ?? '';
        final rssi = (event['rssi'] as num?)?.toInt() ?? 0;
        final i = devices.indexWhere((d) => d.id == id);
        final dev = BleHrDevice(id: id, name: name, rssi: rssi);
        if (i >= 0) {
          devices[i] = dev;
        } else {
          devices.add(dev);
        }
        break;
      case 'state':
        final st = event['state'] as String? ?? '';
        connecting = st == 'connecting';
        connected = st == 'connected';
        if (connected) {
          scanning = false;
          deviceBonded = event['bonded'] == true;
          if (deviceId == null) deviceId = event['id'] as String?;
          if (deviceName == null) deviceName = event['name'] as String?;
        } else if (st == 'disconnected') {
          bpm = null;
          lastBeatAt = null;
          final reason = event['reason'] as String?;
          if (reason != null && reason.isNotEmpty) lastError = reason;
        }
        break;
      case 'hr':
        final v = (event['bpm'] as num?)?.toInt();
        if (v != null && v > 0) {
          bpm = v;
          lastBeatAt = DateTime.now();
        }
        contact = event['contact'] != false;
        break;
      case 'battery':
        batteryPct = (event['level'] as num?)?.toInt();
        break;
    }
    _changed();
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    onChanged = null;
  }
}
