import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'net/tnc.dart';

/// ─── APRSlocusBOX（APRS 小盒子）链路 ───
///
/// 盒子（ESP32 + ST7735 + EC11）自己就能上 WiFi/APRS-IS、自己组报文，
/// 所以它对手机的意义**不是「又来一条报文来源」**（那会与 TNC/APRS-IS
/// 重复），而是「**一台要用手机去管的设备**」：
///
///   * 读它的配置（`CFG` → 23 行 `CFG key=value`）；
///   * 改它的配置（`CFG key=value`）；
///   * 看它的动作结果（盒子会推 `EVT TX|BEACON|RXMSG|ACK|CFG|ERR` 事件行）；
///   * 催它动作（`BEACON` / `STATUS` / `NET` / `CLEAR` / `TEST` / `REBOOT`）；
///   * **把手机的位置喂给它**（`POS lat lon [alt] [spd] [crs]`）——
///     盒子的位置来源是「GPS › 手机喂 › 手动」，出门带手机就能用。
///
/// 字节搬运与 TNC / PKWDWPL 完全一样（蓝牙 SPP / USB-OTG 串口 / 桌面串口），
/// 走**独立通道**（见 `net/tnc_io.dart` 的 `createBoxTransport`）：原生
/// `TncManager` 一次只维护一个 socket，共用通道会把正在工作的 TNC 顶掉。
///
/// 线上协议是**明文行**（不是 KISS、也不是 NMEA）：行尾 `\n`，盒子按
/// `\n`/`\r` 断行（见固件的 `pollStream`）。所以这里只需要一个「分行的
/// 拆包器」+ 一个「把命令写出去」的发送口。

/// 链路状态字符串。刻意与 [PkwdwplStatus] 同名同义 —— 设备页的文案映射
/// 可以直接复用，不必再写一套。
class BoxStatus {
  static const String idle = 'idle';
  static const String connecting = 'connecting';
  static const String connected = 'connected';
  static const String noDevice = 'no-device';
  static const String unsupported = 'unsupported';
  static const String openFailed = 'open-failed';
  static const String closed = 'closed';
  static const String error = 'error';
}

/// 盒子配置里「密码类」的值：盒子回读时**不回显**，只给这个掩码。
///
/// 为什么要专门认它：如果把 `***` 当成真值回填进输入框，用户点一下「确定」
/// 就会把密码**改成三个星号**（APRSlocus 上真实踩过的坑：掩码被当成内容）。
const String kBoxMaskedValue = '***';

/// 明文行拆包器：字节流 → 一行行文本。
///
/// 与 PKWDWPL 的 `NmeaLineSplitter` 的差别：那个要按 `$` 重新同步（NMEA 有
/// 半截行的概念），盒子的行是**命令回显**，没有重同步的必要；这里只需要
/// 「遇到 `\n`/`\r` 就断行」+ 一个防跑飞的上限。
class BoxLineSplitter {
  BoxLineSplitter({this.maxBuffer = 512});

  /// 单行上限（字节）。盒子自己的缓冲是 159 字符，这里给足余量；
  /// 超了说明线路在吐垃圾或对端不是盒子 —— 丢掉整行并计数，不要无限增长。
  final int maxBuffer;

  final List<int> _buf = <int>[];

  /// 因超长被丢掉的行数（排查「对端接错」用）
  int overflows = 0;

  List<String> feed(List<int> bytes) {
    final out = <String>[];
    for (final b in bytes) {
      if (b == 0x0A || b == 0x0D) {
        if (_buf.isNotEmpty) {
          out.add(_decode(_buf));
          _buf.clear();
        }
        continue;
      }
      _buf.add(b);
      if (_buf.length > maxBuffer) {
        _buf.clear();
        overflows++;
      }
    }
    return out;
  }

  void reset() => _buf.clear();

  static String _decode(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }
}

/// 盒子链路的可配置项（**手机侧**的偏好，不是盒子的配置）。
///
/// 盒子自己的配置一律走 `CFG key=value` 存在盒子里（`cfg` 表），
/// 这里只放「手机怎么对待这条链路」的三件事。
class BoxConfig {
  /// 用户是否**启用**了这条链路（持久化）。
  ///
  /// 与 TNC/PKWDWPL 的「来源启用」分开：盒子不是报文来源，不进
  /// `enabledSources`（否则它会被算进「正在收报文」，也会参与发射来源编排）。
  bool enabled;

  /// 掉线后自动重连（与 PKWDWPL 同名同义）
  bool autoReconnect;

  /// 连接时把手机的位置自动喂给盒子（30 秒一次）
  ///
  /// ⚠ 与 [pushStatus] 是**两件事**：
  ///   * `feedPos` 喂的是**坐标** —— 盒子拿它当自己的位置来源（会进信标）；
  ///   * `pushStatus` 推的是**手机那侧看到的状态** —— 只给界面看，不上射频。
  bool feedPos;

  /// 把手机状态推给盒子（速度 / 方位 / 海拔 / 未读 + 附近台站列表）。
  ///
  /// 为什么默认开：这是盒子在 `link = bt`（自己不上 APRS-IS）时「旁边有谁」
  /// 的唯一来源，也是「手机端的定位质量」在盒子上的唯一体现 —— 用户连上盒子
  /// 就是想让盒子显示这些。它**不会**让盒子发任何报文（只写屏幕）。
  bool pushStatus;

  /// 串口线速。**只管 USB-OTG / 桌面串口**；蓝牙 SPP 没有波特率概念。
  /// 盒子固件是 `Serial.begin(115200)`，所以默认 115200 ——
  /// 桌面串口上填错就是一屏乱码（比「连不上」更难判断）。
  int baud;

  BoxConfig({
    this.enabled = false,
    this.autoReconnect = true,
    this.feedPos = false,
    this.pushStatus = true,
    this.baud = 115200,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'autoReconnect': autoReconnect,
        'feedPos': feedPos,
        'pushStatus': pushStatus,
        'baud': baud,
      };

  static BoxConfig fromJson(Object? j) {
    final c = BoxConfig();
    if (j is! Map) return c;
    if (j['enabled'] is bool) c.enabled = j['enabled'] as bool;
    if (j['autoReconnect'] is bool) c.autoReconnect = j['autoReconnect'] as bool;
    if (j['feedPos'] is bool) c.feedPos = j['feedPos'] as bool;
    if (j['pushStatus'] is bool) c.pushStatus = j['pushStatus'] as bool;
    if (j['baud'] is int) c.baud = j['baud'] as int;
    return c;
  }
}

/// 推给盒子的一条「附近台站」。
///
/// 字段刻意与固件的 `PhoneStation` 一一对应（距离米 / 方位度 / 年龄秒），
/// 换算在调用方一次做完 —— 线上只传约定的单位，免得两边各换算一次。
class BoxNearRow {
  final String call;
  final int distM;
  final int brg;      // -1 = 未知
  final int ageSec;   // -1 = 未知
  final String comment;

  const BoxNearRow({
    required this.call,
    required this.distM,
    this.brg = -1,
    this.ageSec = -1,
    this.comment = '',
  });
}

/// APRSlocusBOX 链路。
///
/// 生命周期与 [TncLink] / [PkwdwplLink] 对齐（`scan` → `bind` → `connect`
/// → `disconnect` → `restart`），UI 侧因此可以直接复用同一套交互。
class BoxLink {
  /// [transport] 仅测试注入用；生产环境走条件导入的平台实现。
  BoxLink({TncTransport? transport})
      : _t = transport ?? createBoxTransport() {
    _t.onBytes = _onBytes;
    _t.onClosed = _onClosed;
    _t.onStatus = (s) => lastDetail = s;
  }

  final TncTransport _t;

  final BoxConfig config = BoxConfig();

  /// 已绑定的设备（下次启动自动带出）
  TncDevice? device;

  /// 最近一次扫描到的设备列表
  List<TncDevice> devices = const [];

  bool connecting = false;
  bool connected = false;

  String status = BoxStatus.idle;
  String lastDetail = '';
  String lastError = '';

  // ─── 盒子配置（`CFG key=value` 读回来的那张表）───

  /// 盒子当前配置：`bsec` → `300`。键名与盒子 README 的配置表**逐字一致**，
  /// 界面直接显示原始键名（技术项不翻译，翻译必然与固件漂）。
  final Map<String, String> cfg = <String, String>{};

  /// 最近一次收到配置行的时间（null = 还没读到过）
  DateTime? cfgAt;

  /// 收到过多少行配置（一次 `CFG` 回读约 23 行）
  int cfgLines = 0;

  // ─── 动作/事件统计（盒子推 EVT 行，这里分类计数）───

  /// 盒子发出去的报文数（`EVT TX`，含信标）
  int txCount = 0;

  /// 信标数（`EVT BEACON`，比 TX 更能说明「它在报位置」）
  int beaconCount = 0;

  /// 收到的消息数（`EVT RXMSG`）
  int rxMsgCount = 0;

  /// 收到的 ack 数（`EVT ACK`）
  int ackCount = 0;

  /// 盒子报告的失败次数（`EVT ERR`）
  int errCount = 0;

  /// 最近一条事件原文（`TX …` / `BEACON auto` / `ERR no-fix`…）
  String lastEvent = '';
  DateTime? lastEventAt;

  /// 收到过多少行 / 多少字节（链路健康度）
  int rxLines = 0;
  int rxBytes = 0;

  /// 发出去多少条命令
  int txCmds = 0;

  /// 最近一次收到任何数据的时间
  DateTime? lastRxAt;

  /// 分帧缓冲溢出次数（对端可能不是盒子）
  int get lineOverflows => _splitter.overflows;

  final BoxLineSplitter _splitter = BoxLineSplitter();

  /// 链路日志（环形，最多 200 条）
  final List<String> log = [];

  /// 被动断开
  void Function()? onClosed;

  /// 状态/数据变化（界面据此重建）
  void Function()? onStateChanged;

  /// 一条事件（kind = TX/BEACON/RXMSG/ACK/CFG/ERR，text = 其余部分）
  void Function(String kind, String text)? onEvent;

  bool get up => connected;

  void _log(String s) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    log.insert(0, '$ts  $s');
    if (log.length > 200) log.removeRange(200, log.length);
  }

  List<String> get logs => List.unmodifiable(log);

  // ─── 生命周期 ───

  Future<bool> supported() => _t.supported;

  Future<bool> requestPermissions() => _t.requestPermissions();

  Future<List<TncDevice>> scan() async {
    devices = await _t.listDevices();
    _log('扫描到 ${devices.length} 个设备');
    onStateChanged?.call();
    return devices;
  }

  void bind(TncDevice? d) {
    device = d;
    lastError = '';
    _log(d == null ? '解除绑定' : '绑定 ${d.label}');
    unawaited(_persistDevice());
    onStateChanged?.call();
  }

  Future<bool> connect([TncDevice? d]) async {
    final target = d ?? device;
    if (connecting) {
      lastError = 'busy';
      _log('已在连接中，忽略本次连接请求');
      return false;
    }
    if (connected && target != null && device?.id == target.id) return true;
    if (target == null) {
      status = BoxStatus.noDevice;
      lastError = 'no-device';
      onStateChanged?.call();
      return false;
    }
    if (!await supported()) {
      status = BoxStatus.unsupported;
      lastError = 'unsupported';
      _log('平台不支持串口/蓝牙链路');
      onStateChanged?.call();
      return false;
    }
    device = target;
    unawaited(_persistDevice());
    connecting = true;
    status = BoxStatus.connecting;
    lastError = '';
    _splitter.reset();
    onStateChanged?.call();
    _log('连接 ${target.label} …');
    // 线速是**配置**里的（不随设备持久化，与 TNC 同一套做法）：
    // 蓝牙忽略它，USB/桌面串口靠它 —— 盒子是 115200。
    final err = await _t.connect(target.copyWith(baud: config.baud));
    connecting = false;
    if (err != null) {
      connected = false;
      lastError = err;
      lastDetail = err;
      status =
          err.startsWith('open-') ? BoxStatus.openFailed : BoxStatus.error;
      _log('连接失败：$err');
      onStateChanged?.call();
      return false;
    }
    connected = true;
    status = BoxStatus.connected;
    lastError = '';
    _log('已连接 ${target.label}');
    onStateChanged?.call();
    // 连上就先回读一次配置：界面立刻有内容，也顺带证明「对端确实是盒子」
    // （不是盒子的话不会有 CFG 行，界面会如实显示「还没读到配置」）。
    readCfg();
    return true;
  }

  Future<void> disconnect({bool manual = true}) async {
    // 先置 false 再拆传输层：拆卸过程中会异步抛 closed 事件，
    // 若此时仍为 true 会被当成「链路意外丢失」而触发上层自动重连
    // （症状就是「用户点了断开，几秒后自己又连上」）。
    connected = false;
    connecting = false;
    status = BoxStatus.idle;
    _splitter.reset();
    await _t.disconnect();
    if (manual) _log('已断开');
    onStateChanged?.call();
  }

  Future<bool> restart() async {
    _log('重启链路…');
    await disconnect(manual: false);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return connect();
  }

  void _onClosed() {
    if (!connected) return; // 预期内的拆卸，不上报
    connected = false;
    status = BoxStatus.closed;
    _log('链路断开');
    onStateChanged?.call();
    onClosed?.call();
  }

  // ─── 收 ───

  void _onBytes(List<int> bytes) {
    rxBytes += bytes.length;
    for (final line in _splitter.feed(bytes)) {
      _handleLine(line);
    }
    onStateChanged?.call();
  }

  /// 一行 → 解析。**公开给测试直接调用**（不必造字节流）。
  void handleLine(String line) => _handleLine(line);

  void _handleLine(String raw) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) return;
    rxLines++;
    lastRxAt = DateTime.now();

    // ① 配置回读：`CFG key=value`
    if (line.startsWith('CFG ')) {
      final kv = line.substring(4);
      final i = kv.indexOf('=');
      if (i > 0) {
        cfg[kv.substring(0, i)] = kv.substring(i + 1);
        cfgLines++;
        cfgAt = DateTime.now();
      }
      onStateChanged?.call();
      return;
    }

    // ② 事件：`EVT TX <原文>` / `EVT BEACON auto` / `EVT ERR no-fix` …
    if (line.startsWith('EVT ')) {
      _handleEvent(line.substring(4), line);
      return;
    }

    // ③ 命令回执与其它输出（`OK` / `usage: …` / `unknown …` /
    //    `selftest OK` / 开机横幅 `[boot] …`）：如实进日志，不猜。
    _log(line);
    if (line.startsWith('unknown') || line.startsWith('usage')) {
      lastError = line;
    }
    onStateChanged?.call();
  }

  void _handleEvent(String body, String fullLine) {
    final sp = body.indexOf(' ');
    final kind = (sp < 0 ? body : body.substring(0, sp)).toUpperCase();
    final text = sp < 0 ? '' : body.substring(sp + 1);
    switch (kind) {
      case 'TX':
        txCount++;
        break;
      case 'BEACON':
        beaconCount++;
        break;
      case 'RXMSG':
        rxMsgCount++;
        break;
      case 'ACK':
        ackCount++;
        break;
      case 'ERR':
        errCount++;
        break;
      default:
        break; // CFG 事件只是「某项刚被改过」，没有单独计数
    }
    lastEvent = body;
    lastEventAt = DateTime.now();
    _log(fullLine);
    onEvent?.call(kind, text);
    onStateChanged?.call();
  }

  // ─── 发 ───

  /// 写一条命令（自动补行尾 `\n`）。返回 false = 现在没连着（没发出去）。
  bool send(String cmd) {
    if (!connected) {
      lastError = 'not-connected';
      return false;
    }
    final line = cmd.trim();
    if (line.isEmpty) return false;
    _t.send(Uint8List.fromList(utf8.encode('$line\n')));
    txCmds++;
    _log('> $line');
    return true;
  }

  /// 回读盒子的全部配置（固件的 `CFG` 不带参数就打印全部；`CFG?` 在
  /// 新固件里也认，这里发 `CFG` —— 老固件同样能用）。
  bool readCfg() => send('CFG');

  /// 改一项并保存（盒子会回 `OK` 与 `EVT CFG <key>`）
  bool setCfg(String key, String value) => send('CFG $key=$value');

  bool beacon() => send('BEACON');
  bool sendStatusPacket() => send('STATUS');
  bool reconnectNet() => send('NET');
  bool rebootBox() => send('REBOOT');
  bool clearStations() => send('CLEAR');
  bool selfTest() => send('TEST');
  bool say(String text) => send('SAY $text');

  /// 把位置喂给盒子：`POS lat lon [alt] [spd] [crs]`
  ///
  /// 单位按固件（`box_pos.h`）：**高度米、速度 m/s、航向度**。
  /// 固件用 `sscanf` 顺序解析并靠参数个数判断有没有后一项，所以
  /// **中间项不能跳过**：没有高度就不发速度/航向（宁可少报，也不要
  /// 让「缺高度」被当成「高度=0」）。
  bool feedPos({
    required double lat,
    required double lon,
    double? altM,
    double? speedMps,
    double? courseDeg,
  }) {
    final b = StringBuffer(
        'POS ${lat.toStringAsFixed(5)} ${lon.toStringAsFixed(5)}');
    if (altM != null) {
      b.write(' ${altM.toStringAsFixed(1)}');
      if (speedMps != null) {
        b.write(' ${speedMps.toStringAsFixed(2)}');
        if (courseDeg != null) b.write(' ${courseDeg.toStringAsFixed(0)}');
      }
    }
    return send(b.toString());
  }

  /// 清除喂进去的位置（盒子会回落到 GPS / 手动）
  bool clearPos() => send('POS OFF');

  /// 手机自身状态：`APP <spdKmh> <crsDeg> <altM> <fix> <isUp> <unread>`
  ///
  /// 未知值一律发 **-1**：固件是 `sscanf` 顺序解析，跳过字段会让后面的数字
  /// 整体错位（与 `POS` 同一条教训）。盒子拿它显示在 PHONE 页与首页底行。
  bool pushApp({
    required bool fix,
    required bool isUp,
    required int unread,
    double? speedKmh,
    double? courseDeg,
    double? altM,
  }) {
    String n(double? v, int dp) => v == null ? '-1' : v.toStringAsFixed(dp);
    return send('APP ${n(speedKmh, 1)} ${n(courseDeg, 0)} ${n(altM, 0)} '
        '${fix ? 1 : 0} ${isUp ? 1 : 0} $unread');
  }

  /// 附近台站列表（一条一行）。
  ///
  /// `idx` 从 1 开始；固件收到 `idx == total` 才算整轮完整（半截列表一闪
  /// 而过，看着像"台站突然少了一半"）。空列表发 `NEAR 0` = 让盒子清空 ——
  /// 不清的话，手机没定位时盒子会一直显示上一次的旧列表。
  bool pushNear(List<BoxNearRow> rows) {
    if (!connected) {
      lastError = 'not-connected';
      return false;
    }
    if (rows.isEmpty) return send('NEAR 0');
    var ok = true;
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      // 备注是单行协议的一部分：换行会把它劈成两条命令（直接污染下一条）
      final cmt = r.comment.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
      ok = send('NEAR ${rows.length} ${i + 1} ${r.call} ${r.distM} '
              '${r.brg} ${r.ageSec}${cmt.isEmpty ? '' : ' $cmt'}') &&
          ok;
    }
    return ok;
  }

  // ─── 持久化 ───

  static const _kConfig = 'boxConfigJson';
  static const _kDevice = 'boxDeviceJson';

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final c = p.getString(_kConfig);
      if (c != null && c.isNotEmpty) {
        final parsed = BoxConfig.fromJson(jsonDecode(c));
        config
          ..enabled = parsed.enabled
          ..autoReconnect = parsed.autoReconnect
          ..feedPos = parsed.feedPos
          ..pushStatus = parsed.pushStatus
          ..baud = parsed.baud;
      }
      final d = p.getString(_kDevice);
      if (d != null && d.isNotEmpty) device = TncDevice.fromJson(jsonDecode(d));
    } catch (_) {}
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
