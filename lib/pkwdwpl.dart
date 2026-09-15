/// ─── PKWDWPL 链路：Kenwood `$PKWDWPL` 航点语句 ───
///
/// 与 TNC / 音频**并列的第三种射频来源**：电台的 PC / GPS 输出口以 NMEA 0183
/// 明文吐 `$PKWDWPL` 语句（每行 `\r\n` 结尾），一句话就带齐了台站呼号、坐标、
/// 高度、航向、图标与时间。
///
/// 与 TNC 链路的关键差别（这些差别决定了本文件的形态）：
/// ```text
///                 TNC 链路                     PKWDWPL 链路
///   线上数据      KISS 帧（二进制）             NMEA 明文行（ASCII）
///   帧头          FEND 0xC0 / 转义             '\r\n' 换行
///   内容          AX.25 → TNC2 文本            $PKWDWPL 字段
///   发射          双向（KISS 回传）            只读（电台单向输出航点）
/// ```
/// 所以这里**不碰 `kiss.dart` / AX.25**：收到字节后按行切分、校验 NMEA XOR、
/// 拆 14 个字段即可。
///
/// 传输层复用 `net/tnc.dart` 的 `createPkwdwplTransport()` —— 蓝牙 SPP / 串口
/// 的字节搬运与 TNC 完全同源（含代次隔离、权限回调等历史修复），
/// 只是通道名不同，因此两条链路可以同时开。
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'net/tnc.dart';

/// 解析失败原因（数据层只给稳定错误码，文案在 UI 层本地化）
enum PkwdwplErrorCode {
  /// 行内没有 `$PKWDWPL` 前缀（可能是电台的其它 NMEA 语句）
  notPkwdwpl,

  /// XOR 校验不符
  checksumMismatch,

  /// 逗号字段太少，取不到坐标/呼号
  tooFewFields,

  /// 度分格式非法或分值 ≥ 60
  badCoordinate,

  /// 取不到呼号
  noCallsign,
}

/// 解析结果：成功时 [fix] 非空，失败时 [error] 非空。
class PkwdwplParseResult {
  const PkwdwplParseResult.ok(PkwdwplFix this.fix)
      : error = null,
        detail = null;
  const PkwdwplParseResult.fail(
    PkwdwplErrorCode this.error, {
    this.detail,
    this.fix,
  });

  final PkwdwplFix? fix;
  final PkwdwplErrorCode? error;

  /// 附加信息（例如校验和的「收到 X / 计算 Y」）
  final String? detail;

  bool get isOk => fix != null;
}

/// 一条 `$PKWDWPL` 语句解析出的台站快照。
///
/// 字段编号与协议文档一致（1 起）：
/// ```text
///  1 $PKWDWPL     固定前缀
///  2 102202       时间 hhmmss (UTC)
///  3 V            状态 A=有效 / V=无效
///  4 3954.98      纬度 ddmm.mm
///  5 N            纬度方向 N/S
///  6 11616.63     经度 dddmm.mm
///  7 E            经度方向 E/W
///  8 7            海拔（米）           ← 常为空
///  9 83           航向（度）           ← 常为空
/// 10 290625       日期 ddmmyy
/// 11 000052       距离（单位待定）      ← 常为空
/// 12 BG1UBU-9     呼号
/// 13 /j           APRS 图标（表 + 码）
/// 14 *2E          校验和
/// ```
/// 实测第 8/9/11 字段**经常为空**（真实采集的 10 条里有 3 种字段数：10/11/12），
/// 所以解析器用「左锚定 + 日期正则定位 + 右侧锚定呼号/图标」容错，
/// 而不是按固定下标硬取 —— 硬取会把 10/11 字段的整条丢掉，
/// 而其中包含校验和正确的正常语句。
class PkwdwplFix {
  const PkwdwplFix({
    required this.raw,
    required this.callsign,
    required this.latitude,
    required this.longitude,
    required this.icon,
    required this.statusRaw,
    required this.utcTime,
    required this.utcDate,
    required this.receivedAt,
    this.altitudeMeters,
    this.courseDegrees,
    this.distanceRaw = '',
    this.checksumClaimed,
    this.checksumComputed = '',
    this.checksumValid = false,
    this.callsignSuspicious = false,
    this.fieldCountAnomaly = false,
    this.parsedFieldCount = 0,
  });

  /// 原始语句（详情页调试用）
  final String raw;

  /// 台站呼号（第 12 字段）
  final String callsign;

  /// 十进制纬度（度分已换算）
  final double latitude;

  /// 十进制经度
  final double longitude;

  /// APRS 图标，如 `/j`（第 13 字段原样）
  final String icon;

  /// 第 3 字段原文：`A` 有效 / `V` 无效
  final String statusRaw;

  /// 第 2 字段 hhmmss
  final String utcTime;

  /// 第 10 字段 ddmmyy
  final String utcDate;

  /// 本机收到时刻
  final DateTime receivedAt;

  /// 第 8 字段海拔（米）
  final double? altitudeMeters;

  /// 第 9 字段航向（度）
  final double? courseDegrees;

  /// 第 11 字段原文（保留前导零）
  final String distanceRaw;

  final String? checksumClaimed;
  final String checksumComputed;
  final bool checksumValid;

  /// 呼号格式可疑（例如 `BG1UB9` 这种数字跑到字母后的写法）。
  ///
  /// 需要它的原因：XOR **发现不了字符换位** —— `BI4PGN1-1` 与 `BI4PGN-11`
  /// 的 XOR 完全相同。呼号格式检查是补这个短板的第三层兜底。
  final bool callsignSuspicious;

  /// 字段数与标准值不一致（10/11 个逗号字段），坐标仍按容错分支解析
  final bool fieldCountAnomaly;

  final int parsedFieldCount;

  /// 状态是否有效（`A`）
  bool get statusValid => statusRaw.toUpperCase() == 'A';

  /// 图标表字符（`/` 主表、`\` 副表）
  String get symbolTable => icon.isEmpty ? '/' : icon[0];

  /// 图标码字符
  String get symbolCode =>
      icon.length >= 2 ? icon[1] : (icon.isEmpty ? '>' : '>');

  /// 备注（写进台站信息，便于第三方地图与详情页看懂来源）
  String get comment {
    final parts = <String>['PKWDWPL'];
    if (!statusValid) parts.add('status:V');
    if (altitudeMeters != null) {
      parts.add('Alt:${altitudeMeters!.toStringAsFixed(0)}m');
    }
    if (courseDegrees != null) {
      parts.add('Crs:${courseDegrees!.toStringAsFixed(0)}');
    }
    if (distanceRaw.trim().isNotEmpty) parts.add('Dist:${distanceRaw.trim()}');
    if (utcTime.isNotEmpty || utcDate.isNotEmpty) {
      parts.add('T:$utcTime/$utcDate');
    }
    return parts.join(' ');
  }

  /// UTC 日期时间（第 10/2 字段组合），缺字段时返回 null
  DateTime? get utcDateTime => combineUtc(utcDate, utcTime);
}

/// 把 `ddmmyy` + `hhmmss` 组合成 UTC 时间；任一字段非法则返回 null。
///
/// 世纪归属：两位年份按「<= 79 视为 20xx，否则 19xx」处理（与 APRS 惯例一致，
/// 且 2000 年前的采集设备已不会再出现）。
DateTime? combineUtc(String utcDate, String utcTime) {
  final d = utcDate.trim();
  final t = utcTime.trim();
  if (d.length < 6) return null;
  final day = int.tryParse(d.substring(0, 2));
  final month = int.tryParse(d.substring(2, 4));
  final yy = int.tryParse(d.substring(4, 6));
  if (day == null || month == null || yy == null) return null;
  if (day < 1 || day > 31 || month < 1 || month > 12) return null;
  var hour = 0, minute = 0, second = 0;
  if (t.length >= 6) {
    hour = int.tryParse(t.substring(0, 2)) ?? 0;
    minute = int.tryParse(t.substring(2, 4)) ?? 0;
    second = int.tryParse(t.substring(4, 6)) ?? 0;
  }
  final year = yy <= 79 ? 2000 + yy : 1900 + yy;
  if (hour > 23 || minute > 59 || second > 60) return null;
  return DateTime.utc(year, month, day, hour, minute, second);
}

/// `$PKWDWPL` 语句解析器（纯函数，便于单测）。
class PkwdwplParser {
  const PkwdwplParser._();

  /// 标准的逗号字段数（不含 `$PKWDWPL` 前缀）：时间/状态/纬度/纬度方向/
  /// 经度/经度方向/高度/航向/日期/距离/呼号/图标 = 12
  static const int standardFieldCount = 12;
  static const String prefix = r'$PKWDWPL';

  /// 呼号格式：`前缀 数字 字母 后缀`（如 `BG7LZQ` / `BG1UBU-9` / `BI4PGN-11`）
  static final RegExp callsignRe =
      RegExp(r'^[A-Z0-9]{1,3}[0-9][A-Z]{1,3}(-[0-9]{1,2})?$');

  static final RegExp _dateRe = RegExp(r'^\d{6}$');

  /// 解析一行。宽松模式（[strictChecksum] = false）下校验和不符仍返回结果，
  /// 但 [PkwdwplFix.checksumValid] 为 false 供界面标注。
  static PkwdwplParseResult parse(
    String line, {
    DateTime? now,
    bool strictChecksum = false,
  }) {
    final raw = line.trim();
    if (raw.isEmpty) {
      return const PkwdwplParseResult.fail(PkwdwplErrorCode.tooFewFields);
    }
    if (!raw.toUpperCase().startsWith(prefix)) {
      return const PkwdwplParseResult.fail(PkwdwplErrorCode.notPkwdwpl);
    }

    // 拆校验和：`$PKWDWPL,...,*XX`
    var body = raw.substring(1); // 去掉 '$'
    String? claimed;
    final star = body.lastIndexOf('*');
    if (star >= 0) {
      claimed = body.substring(star + 1).trim().toUpperCase();
      body = body.substring(0, star);
    }
    final computed = PkwdwplChecksum.compute(body);
    final computedHex = PkwdwplChecksum.format(computed);
    final claimedLooksValid =
        claimed != null && RegExp(r'^[0-9A-F]{2}$').hasMatch(claimed);
    final valid =
        claimedLooksValid && int.parse(claimed, radix: 16) == computed;
    if (!valid && strictChecksum) {
      return PkwdwplParseResult.fail(
        PkwdwplErrorCode.checksumMismatch,
        detail: '${claimed ?? '-'} != $computedHex',
      );
    }

    final parts = body.split(',');
    // parts[0] = 'PKWDWPL'；左锚定 6 个定位字段
    if (parts.length < 9) {
      return const PkwdwplParseResult.fail(PkwdwplErrorCode.tooFewFields);
    }
    final utcTime = parts[1].trim();
    final status = parts[2].trim();
    final latRaw = parts[3].trim();
    final ns = parts[4].trim().toUpperCase();
    final lonRaw = parts[5].trim();
    final ew = parts[6].trim().toUpperCase();

    final lat = dmToDecimal(latRaw, ns);
    final lng = dmToDecimal(lonRaw, ew);
    if (lat == null || lng == null) {
      return PkwdwplParseResult.fail(
        PkwdwplErrorCode.badCoordinate,
        detail: '$latRaw$ns/$lonRaw$ew',
      );
    }

    // 右锚定：图标是最后一个字段，呼号在它前面
    final icon = parts.last.trim();
    var callIdx = parts.length - 2;
    // 图标为空（部分固件不发图标）时，呼号就是最后一个字段
    if (icon.isEmpty && callIdx >= 0) {
      // 保持 callIdx 指向倒数第二个（此时它才是呼号）
    }
    final callsign = callIdx >= 0 ? parts[callIdx].trim() : '';
    if (callsign.isEmpty) {
      return const PkwdwplParseResult.fail(PkwdwplErrorCode.noCallsign);
    }

    // 中间段：用「6 位 ddmmyy」把高度/航向 与 距离 分开
    int dateIdx = -1;
    for (var i = 7; i < callIdx; i++) {
      if (_dateRe.hasMatch(parts[i].trim())) {
        dateIdx = i;
        break;
      }
    }
    final middleEnd = dateIdx >= 0 ? dateIdx : callIdx;
    final altRaw = 7 < middleEnd ? parts[7].trim() : '';
    final crsRaw = 8 < middleEnd ? parts[8].trim() : '';
    final distanceRaw =
        dateIdx >= 0 && dateIdx + 1 < callIdx ? parts[dateIdx + 1].trim() : '';
    final utcDate = dateIdx >= 0 ? parts[dateIdx].trim() : '';

    final fieldCount = parts.length - 1; // 不含前缀
    return PkwdwplParseResult.ok(PkwdwplFix(
      raw: raw,
      callsign: callsign.toUpperCase(),
      latitude: lat,
      longitude: lng,
      icon: icon,
      statusRaw: status,
      utcTime: utcTime,
      utcDate: utcDate,
      receivedAt: now ?? DateTime.now(),
      altitudeMeters: double.tryParse(altRaw),
      courseDegrees: double.tryParse(crsRaw),
      distanceRaw: distanceRaw,
      checksumClaimed: claimedLooksValid ? claimed : null,
      checksumComputed: computedHex,
      checksumValid: valid,
      callsignSuspicious: !callsignRe.hasMatch(callsign.toUpperCase()),
      fieldCountAnomaly: fieldCount != standardFieldCount,
      parsedFieldCount: fieldCount,
    ));
  }

  /// 度分（`ddmm.mm` / `dddmm.mm`）→ 十进制。
  ///
  /// 取整数部分的**末两位**当「分」，因此对 `3954.98`、`11616.63`、
  /// 以及省略前导零的写法都成立；分值 ≥ 60 视为语句损坏（返回 null）。
  static double? dmToDecimal(String raw, String hemisphere) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final dot = s.indexOf('.');
    final intPart = dot >= 0 ? s.substring(0, dot) : s;
    final frac = dot >= 0 ? s.substring(dot) : '';
    if (intPart.length < 3 || !RegExp(r'^\d+$').hasMatch(intPart)) return null;
    final deg = int.tryParse(intPart.substring(0, intPart.length - 2));
    final minutes = double.tryParse(intPart.substring(intPart.length - 2) + frac);
    if (deg == null || minutes == null) return null;
    if (minutes >= 60) return null;
    var v = deg + minutes / 60;
    if (hemisphere == 'S' || hemisphere == 'W') v = -v;
    return v;
  }

  /// 十进制 → `ddmm.mm`（与 [dmToDecimal] 互逆；分必须补足两位小数）
  static String decimalToDm(double value, {required bool isLatitude}) {
    final abs = value.abs();
    var deg = abs.floor();
    var min = (abs - deg) * 60;
    // 四舍五入到两位小数后可能进位到 60.00，需要进到度
    min = (min * 100).round() / 100;
    if (min >= 60) {
      deg += 1;
      min -= 60;
    }
    final degWidth = isLatitude ? 2 : 3;
    final degStr = deg.toString().padLeft(degWidth, '0');
    final minStr = min.toStringAsFixed(2).padLeft(5, '0');
    return '$degStr$minStr';
  }
}

/// NMEA 0183 XOR 校验和。
///
/// 规则：`$` 之后、`*` 之前的**每个字符（含逗号）**逐字符 XOR，取两位大写十六进制。
/// 权威示例：`$GPGGA,123519,4807.038,N,...*47` → `0x47`。
class PkwdwplChecksum {
  const PkwdwplChecksum._();

  /// 计算 body（不含 `$` 与 `*XX`）的 XOR。
  static int compute(String body) {
    var xor = 0;
    for (final unit in body.codeUnits) {
      xor ^= unit & 0xFF;
    }
    return xor & 0xFF;
  }

  static String format(int value) =>
      value.toRadixString(16).toUpperCase().padLeft(2, '0');
}

/// 把**字节流**切成一行行文本。
///
/// 为什么必须要有它：蓝牙/串口回调**不按行对齐** —— 一条语句可能被切成
/// 两三块送达，一次回调也可能挤进好几条。少了分帧就会出现「时好时坏、
/// 偶尔整条丢」这种最难查的症状。
///
/// 兼容 `\r\n` / `\n` / `\r`（Kenwood 用 `\r\n`，但不同固件有差异），
/// 并有缓冲上限：线路噪声会产生超长「行」，无上限的话内存会被吃光。
class NmeaLineSplitter {
  NmeaLineSplitter({this.maxBuffer = 8192});

  /// 单行缓冲上限（字节）。超出即丢弃并计数，避免噪声吃光内存。
  final int maxBuffer;

  final List<int> _buf = <int>[];

  /// 因超长被丢弃的字节数（界面/日志可据此判断线路质量）
  int overflows = 0;

  /// 溢出后是否处于「重新同步」状态。
  ///
  /// 为什么要这个状态：溢出时只清空缓冲**不够** —— 那条超长垃圾行的**剩余
  /// 字节**会继续往缓冲里塞，于是下一个正常语句会被拼上垃圾尾巴
  /// （症状：收到 `A$PKWDWPL,X` 这种前面多一两个字符的句子，校验和必然不符，
  /// 而线路本身是好的）。噪声行往往**不带行结束符**，靠 `\r\n` 定位也pin
  /// 不上。NMEA 语句只可能以 `$` 开头，所以「看见 `$` 就当新语句开始」是
  /// 这个场景下唯一可靠的重新同步锚点。
  bool _resync = false;

  /// 语句起始符 `$`
  static const int _dollar = 0x24;

  /// 喂入一段字节，返回本次切出的完整行（已去空白，跳过空行）。
  List<String> feed(List<int> bytes) {
    final out = <String>[];
    for (final b in bytes) {
      final isTerminator = b == 0x0A || b == 0x0D;
      if (_resync) {
        // 垃圾行到此为止；或遇到 `$`（新语句开头）→ 恢复正常累积
        if (isTerminator) {
          _resync = false;
        } else if (b == _dollar) {
          _resync = false;
          _buf.add(b);
        }
        continue;
      }
      if (isTerminator) {
        if (_buf.isEmpty) continue;
        final line = _decode(_buf);
        _buf.clear();
        final t = line.trim();
        if (t.isNotEmpty) out.add(t);
        continue;
      }
      _buf.add(b & 0xFF);
      if (_buf.length > maxBuffer) {
        overflows += _buf.length;
        _buf.clear();
        _resync = true;
      }
    }
    return out;
  }

  /// 丢弃未成行的残留（断开重连时调用，避免半条语句跨链路拼出乱码）
  void reset() {
    _buf.clear();
    _resync = false;
  }

  static String _decode(List<int> bytes) {
    try {
      return latin1.decode(bytes, allowInvalid: true);
    } catch (_) {
      return '';
    }
  }
}

/// 链路状态码（UI 负责本地化）
class PkwdwplStatus {
  static const String idle = 'idle';
  static const String connecting = 'connecting';
  static const String connected = 'connected';
  static const String noDevice = 'no-device';
  static const String unsupported = 'unsupported';
  static const String openFailed = 'open-failed';
  static const String closed = 'closed';
  static const String error = 'error';
}

/// PKWDWPL 链路的可配置项。
///
/// 刻意**没有** KISS 参数、中继路径、射频信标这些发射相关项：
/// 这条链路是**只读**的（电台单向输出航点语句），
/// 留着那些开关只会让人以为「配好了就能发」。
class PkwdwplConfig {
  /// 校验和不符时是否丢弃该条。
  ///
  /// 默认 **false（不丢弃，只标注）**，与 PKWDWPL Lite 的严格默认刻意不同：
  /// 这条链路是「电台 → 手机」的本地线缆，出现校验不符通常说明固件的
  /// 语句格式与手册有出入（而不是路上被干扰坏了），此时**整条丢弃**会让
  /// 用户面对一个「什么都不显示」的界面，比标注出来更难排查。
  /// 需要严格校验时可在设备页打开。
  bool strictChecksum;

  /// 断开后自动重连
  bool autoReconnect;

  PkwdwplConfig({
    this.strictChecksum = false,
    this.autoReconnect = true,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'strictChecksum': strictChecksum,
        'autoReconnect': autoReconnect,
      };

  static PkwdwplConfig fromJson(Object? j) {
    final c = PkwdwplConfig();
    if (j is! Map) return c;
    if (j['strictChecksum'] is bool) c.strictChecksum = j['strictChecksum'] as bool;
    if (j['autoReconnect'] is bool) c.autoReconnect = j['autoReconnect'] as bool;
    return c;
  }
}

/// PKWDWPL 链路（只收不发）。
///
/// 生命周期与 [TncLink] 对齐（`scan` → `bind` → `connect` → `disconnect`
/// → `restart`），这样 UI 侧能直接复用同一套交互；差别在于：
///   * 收到的是 NMEA 明文行 → 分帧 → XOR 校验 → 解析；
///   * **没有发送路径**（[send] 一律拒绝），因此也绝不会碰射频。
class PkwdwplLink {
  /// [transport] 仅测试注入用；生产环境走条件导入的平台实现。
  PkwdwplLink({TncTransport? transport})
      : _t = transport ?? createPkwdwplTransport() {
    _t.onBytes = _onBytes;
    _t.onClosed = _onClosed;
    _t.onStatus = (s) => lastDetail = s;
  }

  final TncTransport _t;

  final PkwdwplConfig config = PkwdwplConfig();

  /// 已绑定的设备（下次启动自动带出）
  TncDevice? device;

  /// 最近一次扫描到的设备列表
  List<TncDevice> devices = const [];

  bool connecting = false;
  bool connected = false;

  String status = PkwdwplStatus.idle;
  String lastDetail = '';
  String lastError = '';

  int rxFrames = 0;
  int rxBytes = 0;
  DateTime? lastRxAt;

  /// 因校验不符被标注（或丢弃）的条数
  int checksumMismatches = 0;

  /// 解析成功但因坐标/字段非法被丢弃的条数
  int rejected = 0;

  /// 收到但非 `$PKWDWPL` 的语句数（电台同时输出 GGA/RMC 时会有）
  int ignoredLines = 0;

  /// 分帧缓冲溢出次数（线路噪声的指标）
  int get frameOverflows => _splitter.overflows;

  final NmeaLineSplitter _splitter = NmeaLineSplitter();

  /// 链路日志（环形，最多 100 条）
  final List<String> log = [];

  /// 解析成功的一条台站快照
  void Function(PkwdwplFix fix)? onFix;

  /// 被动断开
  void Function()? onClosed;

  /// 状态变化
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
      status = PkwdwplStatus.noDevice;
      lastError = 'no-device';
      onStateChanged?.call();
      return false;
    }
    if (!await supported()) {
      status = PkwdwplStatus.unsupported;
      lastError = 'unsupported';
      _log('平台不支持 PKWDWPL 链路');
      onStateChanged?.call();
      return false;
    }
    device = target;
    unawaited(_persistDevice());
    connecting = true;
    status = PkwdwplStatus.connecting;
    lastError = '';
    _splitter.reset();
    onStateChanged?.call();
    _log('连接 ${target.label} …');
    final err = await _t.connect(target);
    connecting = false;
    if (err != null) {
      connected = false;
      lastError = err;
      lastDetail = err;
      status =
          err.startsWith('open-') ? PkwdwplStatus.openFailed : PkwdwplStatus.error;
      _log('连接失败：$err');
      onStateChanged?.call();
      return false;
    }
    connected = true;
    status = PkwdwplStatus.connected;
    lastError = '';
    _log('已连接 ${target.label}（等待 \$PKWDWPL 语句）');
    onStateChanged?.call();
    return true;
  }

  Future<void> disconnect({bool manual = true}) async {
    // 先置 false 再拆传输层：拆卸过程中会异步抛 closed 事件，
    // 若此时仍为 true 会被当成「链路意外丢失」而触发上层自动重连
    // （症状就是「用户点了断开，几秒后自己又连上」）。
    connected = false;
    connecting = false;
    status = PkwdwplStatus.idle;
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
    status = PkwdwplStatus.closed;
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

  /// 一行 → 一条台站快照。公开给测试直接调用（不必造字节流）。
  void _handleLine(String line) {
    if (!line.toUpperCase().startsWith(PkwdwplParser.prefix)) {
      // 电台通常还会吐 $GPGGA/$GPRMC，静默忽略但计数
      ignoredLines++;
      return;
    }
    final r = PkwdwplParser.parse(line, strictChecksum: config.strictChecksum);
    if (!r.isOk) {
      rejected++;
      if (r.error == PkwdwplErrorCode.checksumMismatch) {
        checksumMismatches++;
        _log('丢弃语句（校验不符 ${r.detail}）');
      } else {
        _log('丢弃语句（${r.error!.name}${r.detail == null ? '' : ' ${r.detail}'}）');
      }
      return;
    }
    final fix = r.fix!;
    if (!fix.checksumValid) {
      checksumMismatches++;
      _log('校验不符（收到 ${fix.checksumClaimed ?? '-'} / 计算 '
          '${fix.checksumComputed}）· 已按宽松模式解析 ${fix.callsign}');
    }
    rxFrames++;
    lastRxAt = DateTime.now();
    onFix?.call(fix);
  }

  // ─── 只读守卫 ───

  /// PKWDWPL 链路**不能发射**（电台只单向输出航点语句）。
  ///
  /// 显式提供这个方法而不是省略：省略的话上层调用 `send` 会编译不过，
  /// 有人就会在别处偷偷绕过；这里明确返回错误码，让「发不出去」在
  /// 界面上有据可查。
  String? send(String raw) {
    lastError = 'read-only';
    _log('PKWDWPL 链路为只读，已拒绝发送：$raw');
    return lastError;
  }

  // ─── 持久化 ───

  static const _kConfig = 'pkwdwplConfigJson';
  static const _kDevice = 'pkwdwplDeviceJson';

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final c = p.getString(_kConfig);
      if (c != null && c.isNotEmpty) {
        final parsed = PkwdwplConfig.fromJson(jsonDecode(c));
        config
          ..strictChecksum = parsed.strictChecksum
          ..autoReconnect = parsed.autoReconnect;
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
