import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'kiss.dart';
import 'net/tnc.dart';

/// ─── TNC 链路：KISS 参数、AX.25 组帧、设备绑定与状态 ───
///
/// 与 APRS-IS 的关系：两者是**并列的数据来源**，由 `AppState.dataSource` 选择。
/// 本类只负责把 TNC2 文本 ↔ KISS 字节互转，收到的报文交给 `AppState._onAprsLine`，
/// 因此台站解析、消息、过滤等逻辑对两个来源完全共用（不会出现「TNC 模式下
/// 台站不上图」这类分叉 bug）。

/// KISS 参数与射频相关设置
class TncConfig {
  /// 发射延时（ms）。KISS 下发单位为 10ms，故发送时除以 10（0-255 → 0-2550ms）
  int txDelayMs;

  /// 发射尾音（ms），同上
  int txTailMs;

  /// P 持续度（0-255）：越小越礼让，共用信道时避免碰撞
  int persistence;

  /// 时隙（ms），同上换算
  int slotTimeMs;

  /// 全双工（1 = 同时收发，一般中继/网关用；普通电台必须 0）
  bool fullDuplex;

  /// KISS 端口 / 信道号（0-15）
  int channel;

  /// 应用侧 AX.25 帧长上限（字节）。1200bd 下 AX.25 单帧上限约 330 字节，
  /// 超过则**不发送**（而不是让 TNC 丢弃或截断）
  int maxFrame;

  /// 射频中继路径（如 `WIDE1-1,WIDE2-1`；留空 = 不指定中继）
  String path;

  /// 收到需要 ack 的消息时自动回复 ack（APRS 层，仅私信有意义）
  bool autoAck;

  /// 是否允许在射频上发送位置信标（安全开关，默认关 —— 射频发射需持照操作）
  bool rfBeacon;

  /// SETHARDWARE（0x06）厂商自定义命令码；-1 表示不下发
  int hardwareCmd;

  /// SETHARDWARE 参数值
  int hardwareVal;

  /// 链路断开后自动重连
  bool autoReconnect;

  /// TNC 初始化串（多行，逐行发送，行尾补 CRLF）。
  ///
  /// 对应 APRSdroid 的 `kiss.init`（见其 KotlinProto/KissProto.scala：
  /// 逐行 write + `\r\n` + sleep(initdelay)）。为什么需要它：
  /// 不少蓝牙/串口 TNC 模块上电后停在**命令模式**，必须先收
  /// `KISS ON` / `RESTART` 之类指令才会进入 KISS 转发状态。
  /// 这类模块的典型症状正是「能收不能发」——收是因为芯片仍在把解调结果
  /// 吐出来，发是因为它根本没在 KISS 模式下监听主机下行。
  String initString;

  /// 初始化串每行之间的等待（ms）。模块处理命令需要时间，太短会丢命令。
  int initDelayMs;

  /// 连接后是否主动下发 KISS 参数（TxDelay/P/SlotTime/TxTail/FullDuplex）。
  ///
  /// **默认关闭**，与 APRSdroid 的行为一致（它默认一个参数帧都不发）。
  /// 原因：这些参数会覆盖 TNC 自己的配置，而每个 TNC 的
  /// TxDelay/Persistence 合理值不同 —— 推错了可能让它在共享信道上
  /// 一直退避而不发射。需要时可在设备页显式打开或手动下发一次。
  bool pushKissParams;

  TncConfig({
    this.txDelayMs = 300,
    this.txTailMs = 50,
    this.persistence = 63,
    this.slotTimeMs = 100,
    this.fullDuplex = false,
    this.channel = 0,
    this.maxFrame = 330,
    this.path = 'WIDE1-1,WIDE2-1',
    this.autoAck = true,
    this.rfBeacon = false,
    this.hardwareCmd = -1,
    this.hardwareVal = 0,
    this.autoReconnect = true,
    this.initString = '',
    this.initDelayMs = 300,
    this.pushKissParams = false,
  });

  /// ms → KISS 值（10ms 单位，封顶 255）
  static int msToKiss(int ms) => (ms / 10).round().clamp(0, 255);

  /// KISS 值 → ms
  static int kissToMs(int v) => v.clamp(0, 255) * 10;

  Map<String, dynamic> toJson() => {
        'txDelayMs': txDelayMs,
        'txTailMs': txTailMs,
        'persistence': persistence,
        'slotTimeMs': slotTimeMs,
        'fullDuplex': fullDuplex,
        'channel': channel,
        'maxFrame': maxFrame,
        'path': path,
        'autoAck': autoAck,
        'rfBeacon': rfBeacon,
        'hardwareCmd': hardwareCmd,
        'hardwareVal': hardwareVal,
        'autoReconnect': autoReconnect,
        'initString': initString,
        'initDelayMs': initDelayMs,
        'pushKissParams': pushKissParams,
      };

  static TncConfig fromJson(Object? j) {
    final c = TncConfig();
    if (j is! Map) return c;
    int i(String k, int fb) => (j[k] as num?)?.toInt() ?? fb;
    bool b(String k, bool fb) => j[k] is bool ? j[k] as bool : fb;
    String s(String k, String fb) => j[k]?.toString() ?? fb;
    return TncConfig(
      txDelayMs: i('txDelayMs', c.txDelayMs),
      txTailMs: i('txTailMs', c.txTailMs),
      persistence: i('persistence', c.persistence).clamp(0, 255),
      slotTimeMs: i('slotTimeMs', c.slotTimeMs),
      fullDuplex: b('fullDuplex', c.fullDuplex),
      channel: i('channel', c.channel).clamp(0, 15),
      maxFrame: i('maxFrame', c.maxFrame).clamp(0, 2048),
      path: s('path', c.path),
      autoAck: b('autoAck', c.autoAck),
      rfBeacon: b('rfBeacon', c.rfBeacon),
      hardwareCmd: i('hardwareCmd', -1),
      hardwareVal: i('hardwareVal', 0).clamp(0, 255),
      autoReconnect: b('autoReconnect', c.autoReconnect),
      initString: s('initString', ''),
      initDelayMs: i('initDelayMs', c.initDelayMs).clamp(0, 5000),
      pushKissParams: b('pushKissParams', c.pushKissParams),
    );
  }
}

/// 链路状态码（UI 负责本地化，避免把中文写进数据层）
class TncStatus {
  static const String idle = 'idle';
  static const String connecting = 'connecting';
  static const String connected = 'connected';
  static const String noDevice = 'no-device';
  static const String unsupported = 'unsupported';
  static const String noPermission = 'no-permission';
  static const String openFailed = 'open-failed';
  static const String closed = 'closed';
  static const String error = 'error';
}

class TncLink {
  /// [transport] 仅测试注入用；生产环境走条件导入的平台实现。
  TncLink({TncTransport? transport})
      : _t = transport ?? createTncTransport() {
    _t.onBytes = _onBytes;
    _t.onClosed = _onClosed;
    _t.onStatus = (s) {
      lastDetail = s;
    };
    _t.onTxFailed = (reason) {
      txErrors++;
      lastTxError = reason;
      // 进链路日志：这是排查「发不出去」最关键的一条，必须留痕
      _log('发送失败：$reason');
      onStateChanged?.call();
    };
  }

  final TncTransport _t;
  final KissDecoder _dec = KissDecoder();

  final TncConfig config = TncConfig();

  /// 已绑定的设备（下次启动自动带出）
  TncDevice? device;

  /// 最近一次扫描到的设备列表（绑定 UI 用）
  List<TncDevice> devices = const [];

  bool connecting = false;
  bool connected = false;

  /// 状态码，见 [TncStatus]
  String status = TncStatus.idle;

  /// 状态补充说明（原生/系统错误原文，未本地化）
  String lastDetail = '';

  int rxFrames = 0;
  int txFrames = 0;
  int rxBytes = 0;
  int txBytes = 0;
  DateTime? lastRxAt;
  DateTime? lastTxAt;

  /// 最近一次失败原因（'frame-too-long' / 'not-connected' 等）
  String lastError = '';

  /// 链路层写入失败次数（原生拒收 / 串口异常）。
  ///
  /// 与 [lastError] 的区别：lastError 是**调用前**的校验失败（格式、长度、
  /// 未连接），而这个是「已经交给链路、但字节没送出去」——两者混在一起
  /// 会让「发射不出去」无从定位。
  int txErrors = 0;
  String lastTxError = '';

  /// 链路日志（环形，最多 100 条；供「设备」页排查用）
  final List<String> log = [];

  /// 解出的 TNC2 报文
  void Function(String line)? onLine;

  /// 链路断开（被动）
  void Function()? onClosed;

  /// 状态变化（已连接/断开/错误）
  void Function()? onStateChanged;

  bool get up => connected;

  void _log(String s) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    log.insert(0, '$ts  $s');
    if (log.length > 100) log.removeRange(100, log.length);
  }

  List<String> get logs => List.unmodifiable(log);

  // ─── 生命周期 ───

  Future<bool> supported() => _t.supported;

  /// 请求平台权限（Android 蓝牙运行时权限）
  Future<bool> requestPermissions() => _t.requestPermissions();

  Future<List<TncDevice>> scan() async {
    devices = await _t.listDevices();
    _log('扫描到 ${devices.length} 个设备');
    onStateChanged?.call();
    return devices;
  }

  /// 绑定设备（不连接）
  void bind(TncDevice? d) {
    device = d;
    lastError = '';
    _log(d == null ? '解除绑定' : '绑定 ${d.label}');
    unawaited(_persistDevice());
    onStateChanged?.call();
  }

  Future<bool> connect([TncDevice? d]) async {
    final target = d ?? device;
    if (target == null) {
      status = TncStatus.noDevice;
      lastError = 'no-device';
      onStateChanged?.call();
      return false;
    }
    if (!await supported()) {
      status = TncStatus.unsupported;
      lastError = 'unsupported';
      _log('平台不支持 TNC 链路');
      onStateChanged?.call();
      return false;
    }
    device = target;
    unawaited(_persistDevice());
    connecting = true;
    status = TncStatus.connecting;
    lastError = '';
    _dec.reset();
    onStateChanged?.call();
    _log('连接 ${target.label} …');
    final err = await _t.connect(target);
    connecting = false;
    if (err != null) {
      connected = false;
      lastError = err;
      lastDetail = err;
      status = err.startsWith('open-') ? TncStatus.openFailed : TncStatus.error;
      _log('连接失败：$err');
      onStateChanged?.call();
      return false;
    }
    connected = true;
    status = TncStatus.connected;
    lastError = '';
    _log('已连接 ${target.label}');
    // ① 初始化串必须在最前面：不少模块上电停在命令模式，要先收到
    //    `KISS ON`/`RESTART` 之类指令才会进入 KISS 转发（否则能收不能发）。
    await sendInitString();
    // ② KISS 参数**默认不下发**（与 APRSdroid 一致）：这些参数会覆盖
    //    TNC 自己的配置，推错值可能让它在共享信道上一直退避而不发射。
    //    需要统一管理时可由用户在设备页显式打开。
    if (config.pushKissParams) {
      applyKiss();
    } else {
      _log('跳过 KISS 参数下发（可在设备页打开「连接后下发 KISS 参数」）');
    }
    onStateChanged?.call();
    return true;
  }

  Future<void> disconnect({bool manual = true}) async {
    await _t.disconnect();
    connected = false;
    connecting = false;
    status = TncStatus.idle;
    if (manual) _log('已断开');
    onStateChanged?.call();
  }

  void _onClosed() {
    final was = connected;
    connected = false;
    status = TncStatus.closed;
    if (was) _log('链路断开');
    onStateChanged?.call();
    onClosed?.call();
  }

  // ─── 收 ───

  void _onBytes(List<int> bytes) {
    rxBytes += bytes.length;
    for (final f in _dec.feed(bytes)) {
      if (!f.isData) {
        // 参数回显 / 命令响应：仅记录，不影响数据通路
        _log('KISS 响应 cmd=0x${f.command.toRadixString(16)}'
            '${f.payload.isEmpty ? '' : ' val=${f.payload.first}'}');
        continue;
      }
      final tnc2 = Ax25.decodeToTnc2(f.payload);
      if (tnc2 == null) {
        _log('丢弃非法 AX.25 帧（${f.payload.length}B）');
        continue;
      }
      rxFrames++;
      lastRxAt = DateTime.now();
      onLine?.call(tnc2);
    }
    onStateChanged?.call();
  }

  // ─── 发 ───

  /// 发送一条 TNC2 报文；返回错误描述，null 表示已交给链路
  String? sendTnc2(String tnc2) {
    if (!connected) {
      lastError = 'not-connected';
      return lastError;
    }
    final frame = Ax25.encodeTnc2(tnc2);
    if (frame == null) {
      lastError = 'bad-format';
      return lastError;
    }
    if (config.maxFrame > 0 && frame.length > config.maxFrame) {
      lastError = 'frame-too-long';
      _log('帧过长 ${frame.length}B > ${config.maxFrame}B，未发送');
      onStateChanged?.call();
      return lastError;
    }
    final bytes = Kiss.dataFrame(config.channel, frame);
    _t.send(bytes);
    txFrames++;
    txBytes += bytes.length;
    lastTxAt = DateTime.now();
    lastError = '';
    onStateChanged?.call();
    return null;
  }

  /// 发送 TNC 初始化串（多行，逐行 + CRLF + 行间延时）。
  ///
  /// 对齐 APRSdroid 的 `kiss.init` 行为（KissProto.scala：逐行
  /// `write(line)` + `write('\r')` + `write('\n')` + `Thread.sleep(initdelay)`）。
  /// 返回实际发出的行数（0 = 未配置）。
  Future<int> sendInitString() async {
    if (!connected) {
      lastError = 'not-connected';
      return 0;
    }
    final raw = config.initString.trim();
    if (raw.isEmpty) return 0;
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    for (final line in lines) {
      // 初始化串是**明文命令**（不进 KISS 转义），TNC 只在命令模式下认它。
      // 同样必须是 Uint8List，理由见 Kiss.escape 的注释。
      _t.send(Uint8List.fromList(<int>[...utf8.encode(line), 0x0D, 0x0A]));
      _log('初始化：$line');
      final d = config.initDelayMs;
      if (d > 0) await Future.delayed(Duration(milliseconds: d));
    }
    _log('已发送 ${lines.length} 行 TNC 初始化串');
    onStateChanged?.call();
    return lines.length;
  }

  /// 发射自检：发一帧测试包，报告「链路层到底有没有把字节送出去」。
  ///
  /// 为什么需要：用户报「能收不能发」时，症状无法区分下面几种原因，
  /// 这个自检把它们分开：
  ///   * 没连上 / 帧长超限 / 报文格式错 → 立刻返回错误码；
  ///   * **字节没送出去**（原生拒收，例如 Dart 传的字节类型不对使
  ///     Kotlin 取不到 ByteArray）→ 等 [settle] 纳秒内捕获到
  ///     `onTxFailed`，返回 'send-failed'；
  ///   * 写成功但电台不发射 → 自检通过，说明问题在 TNC 侧（未进 KISS
  ///     模式 / 参数不对 / 模块问题），据此提示配置初始化串。
  ///
  /// ⚠️ 必须等这一拍：写入是异步的。此前直接看 `txFrames++`
  /// （发送后无条件自增）会**误报成功** —— 明明一个字节都没出去。
  ///
  /// 用的是**状态包**（不含坐标），不会把台站挪到某个位置。
  Future<String?> txSelfTest(
    String fullCall,
    String path, {
    Duration settle = const Duration(milliseconds: 400),
  }) async {
    if (!connected) return 'not-connected';
    final errsBefore = txErrors;
    final raw = '$fullCall>$path:>APRSlocus TXTEST';
    final err = sendTnc2(raw);
    if (err != null) return err;
    // 等链路层回话：有错就是没出去，没错才算递交成功
    await Future.delayed(settle);
    if (txErrors > errsBefore) {
      _log('发射自检失败：链路层报错（$lastTxError）');
      return 'send-failed: $lastTxError';
    }
    _log('发射自检：链路层已接收一帧（累计 $txFrames 帧 / $txBytes 字节，'
        '写入失败 $txErrors 次）');
    return null;
  }

  /// 下发全部 KISS 参数（TxDelay/Persistence/SlotTime/TxTail/FullDuplex
  /// + 可选的 SETHARDWARE）
  void applyKiss() {
    if (!connected) {
      lastError = 'not-connected';
      return;
    }
    void param(int cmd, int value) =>
        _t.send(Kiss.paramFrame(config.channel, cmd, value));
    param(Kiss.cmdTxDelay, TncConfig.msToKiss(config.txDelayMs));
    param(Kiss.cmdPersistence, config.persistence);
    param(Kiss.cmdSlotTime, TncConfig.msToKiss(config.slotTimeMs));
    param(Kiss.cmdTxTail, TncConfig.msToKiss(config.txTailMs));
    param(Kiss.cmdFullDuplex, config.fullDuplex ? 1 : 0);
    if (config.hardwareCmd >= 0) {
      param(config.hardwareCmd, config.hardwareVal);
    }
    lastError = '';
    _log('已下发 KISS 参数'
        '（TxDelay ${config.txDelayMs}ms / P ${config.persistence}'
        ' / Slot ${config.slotTimeMs}ms / TxTail ${config.txTailMs}ms'
        ' / FullDuplex ${config.fullDuplex ? 1 : 0}'
        ' / 信道 ${config.channel}）');
    onStateChanged?.call();
  }

  /// 自定义 KISS 命令（高级：厂商自定义 SETHARDWARE 等）
  void sendKissCommand(int cmd, [int? value]) {
    if (!connected) {
      lastError = 'not-connected';
      return;
    }
    if (value == null) {
      _t.send(Kiss.commandFrame(config.channel, cmd));
    } else {
      _t.send(Kiss.paramFrame(config.channel, cmd, value));
    }
    _log('自定义 KISS cmd=0x${cmd.toRadixString(16)}'
        '${value == null ? '' : ' val=$value'}');
  }

  /// RETURN（0x0F）：让 TNC 退出 KISS 回到命令模式。
  /// 注意：多数 KISS-only TNC 会因此停止转发数据，需断电或重启链路恢复。
  void kissReturn() {
    if (!connected) {
      lastError = 'not-connected';
      return;
    }
    _t.send(Kiss.commandFrame(config.channel, Kiss.cmdReturn));
    _log('已发送 RETURN（退出 KISS 命令模式）');
    onStateChanged?.call();
  }

  /// 重启链路（TNC 复位最可靠的通用做法：断开重连 + 重下发参数）
  Future<bool> restart() async {
    _log('重启链路…');
    await disconnect(manual: false);
    await Future.delayed(const Duration(milliseconds: 400));
    return connect();
  }

  // ─── 持久化 ───

  static const _kConfig = 'tncConfigJson';
  static const _kDevice = 'tncDeviceJson';

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final c = p.getString(_kConfig);
      if (c != null && c.isNotEmpty) {
        final parsed = TncConfig.fromJson(jsonDecode(c));
        _copy(parsed, config);
      }
      final d = p.getString(_kDevice);
      if (d != null && d.isNotEmpty) device = TncDevice.fromJson(jsonDecode(d));
    } catch (_) {}
  }

  static void _copy(TncConfig from, TncConfig to) {
    to
      ..txDelayMs = from.txDelayMs
      ..txTailMs = from.txTailMs
      ..persistence = from.persistence
      ..slotTimeMs = from.slotTimeMs
      ..fullDuplex = from.fullDuplex
      ..channel = from.channel
      ..maxFrame = from.maxFrame
      ..path = from.path
      ..autoAck = from.autoAck
      ..rfBeacon = from.rfBeacon
      ..hardwareCmd = from.hardwareCmd
      ..hardwareVal = from.hardwareVal
      ..autoReconnect = from.autoReconnect
      ..initString = from.initString
      ..initDelayMs = from.initDelayMs
      ..pushKissParams = from.pushKissParams;
  }

  Future<void> persistConfig() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kConfig, jsonEncode(config.toJson()));
    } catch (_) {}
  }

  Future<void> _persistDevice() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (device == null) {
        await p.remove(_kDevice);
      } else {
        await p.setString(_kDevice, jsonEncode(device!.toJson()));
      }
    } catch (_) {}
  }

  void dispose() {
    _t.onBytes = null;
    _t.onClosed = null;
    _t.onStatus = null;
    unawaited(_t.disconnect());
  }
}
