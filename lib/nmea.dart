/// ─── NMEA 0183 解析（外接 GPS / 北斗模块的通用件）───
///
/// 起因：位置来源里要加「外接 GPS 模块」。这类模块只有一种说话方式 ——
/// 通过蓝牙 SPP / 串口往外吐 ASCII 行（每条以 `$` 开头、`\r\n` 结尾），
/// 而 **SPP 本身只是字节流**：没有消息边界、不分行、不管协议。
/// 所以这里要干两件事：**分帧**（字节流 → 行）与**解析**（行 → 定位）。
///
/// 为什么单独一个文件，而不是塞进 `nmea_gps.dart`：解析是**纯函数** ——
/// 不碰传输层、不碰应用状态，可以直接喂字符串做单测（`test/nmea_test.dart`），
/// 不必造字节流或假链路。仓库里已有先例：`pkwdwpl.dart` 把解析器与链路分开写。
///
/// 覆盖范围是「外接模块真的会发的几条语句」：
/// ```text
///   $--RMC  时间 / 日期 / 坐标 / 对地速度 / 航向   ← 定位的主力
///   $--GGA  坐标 / 定位质量 / 卫星数 / HDOP / 海拔  ← 精度与海拔的来源
///   $--GLL  坐标 / 时间（部分模块只发它）
///   $--ZDA  日期时间（RMC 缺失时的日期来源）
///   $--GSA  定位模式 / HDOP（拿不到 GGA 时的精度来源）
///   $--VTG  对地速度 / 航向（RMC 缺失时的替代）
/// ```
/// 其余语句（GSV 星历、GBS 误差…）按「认识但不使用」处理：**不算错误**，
/// 只是没有定位信息。GSV 是每条最长的语句（一次要拆成好几条才发得完），
/// 把它当解析失败会让统计一片红，用户反而看不出真正的问题。
///
/// talker（`$GP` / `$GN` / `$BD` / `$GL` / `$GA` / `$GB` …）**一律不区分**：
/// 双模模块会按当前定位来源切换前缀（北斗 `BD`、多系统联合定位 `GN`），
/// 只认 `GP` 就会出现「换了颗卫星就收不到定位」。语义在语句类型（RMC/GGA）里。
library;

import 'dart:convert';

/// 把**字节流**切成一行行文本。
///
/// 为什么必须要有它：蓝牙/串口回调**不按行对齐** —— 一条语句可能被切成
/// 两三块送达，一次回调也可能挤进好几条。少了分帧就会出现「时好时坏、
/// 偶尔整条丢」这种最难查的症状。
///
/// 兼容 `\r\n` / `\n` / `\r`（不同固件有差异），并有缓冲上限：
/// 线路噪声会产生超长「行」，无上限的话内存会被吃光。
///
/// ⚠ 这个类原本写在 `pkwdwpl.dart` 里（当时只有那一条链路要分帧）。
/// 外接 GPS 链路要的是**同一件事**，所以搬到这里共用 —— 复制一份的话，
/// 下面「看见 `$` 就重新同步」这类踩出来的修复必然只留在其中一边。
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

/// NMEA 语句类型。只区分我们真正会用到的那几种。
enum NmeaKind {
  /// 推荐最小定位信息：时间/坐标/速度/航向/日期
  rmc,

  /// 全球定位系统定位数据：坐标/质量/卫星数/HDOP/海拔
  gga,

  /// 地理定位（只有坐标与时间）
  gll,

  /// 日期时间
  zda,

  /// 当前卫星精度因子与定位模式
  gsa,

  /// 对地航向与对地速度
  vtg,

  /// 认识但不用（GSV 星历 / GBS 误差 / TXT 文本 …）
  other,
}

/// 解析失败的原因（数据层只给稳定错误码，文案由 UI 层本地化）。
enum NmeaErrorCode {
  /// 不是 `$` 开头的语句（噪声、或者把别的协议喂进来了）
  notNmea,

  /// XOR 校验和不符
  checksumMismatch,

  /// 语句类型不认识（例如厂商私有语句）
  unknownSentence,

  /// 逗号字段太少，按协议取不到需要的段
  tooFewFields,

  /// 度分格式非法（非数字 / 分值 ≥ 60）
  badCoordinate,

  /// 语句本身说「这次定位无效」（RMC 状态 V、GGA 质量为 0）——
  /// **不是解析失败**，而是模块诚实地说「还没定上」。
  /// 必须和上面几种分开：它在冷启动时是正常的，界面不该报错。
  noFix,
}

/// 一行 NMEA 的解析结果：成功时 [sentence] 非空，失败时 [error] 非空。
class NmeaParseResult {
  const NmeaParseResult.ok(NmeaSentence this.sentence)
      : error = null,
        detail = null;
  const NmeaParseResult.fail(
    NmeaErrorCode this.error, {
    this.detail,
    this.sentence,
  });

  final NmeaSentence? sentence;
  final NmeaErrorCode? error;

  /// 附加信息（校验和的「收到 X / 计算 Y」、语句 id 等）
  final String? detail;

  bool get isOk => sentence != null;
}

/// 一条 NMEA 语句解析出的原始字段（**只做单条语句内的事**：
/// 不合并其它语句、不判断整机是否已定位 —— 那是 [NmeaAssembler] 的活）。
class NmeaSentence {
  const NmeaSentence({
    required this.id,
    required this.talker,
    required this.type,
    required this.raw,
    required this.kind,
    required this.positionValid,
    this.checksumValid = false,
    this.checksumClaimed,
    this.checksumComputed = '',
    this.utcTime = '',
    this.utcDate = '',
    this.latitude,
    this.longitude,
    this.altitudeM,
    this.speedKnots,
    this.speedKmh,
    this.courseDegrees,
    this.hdop,
    this.satellites,
    this.fixQuality,
    this.fixType = '',
    this.status = '',
    this.mode = '',
    this.utc,
  });

  /// 语句 id（talker + 类型），如 `GNRMC` / `BDGGA`
  final String id;

  /// 两位 talker（`GP` / `GN` / `BD` / `GL` / `GA` …）
  final String talker;

  /// 三位类型（`RMC` / `GGA` …）
  final String type;

  final NmeaKind kind;

  /// 原始行（详情页/日志用）
  final String raw;

  /// 这条语句里的坐标是不是**可用**的。
  ///
  /// 判据按语句类型走：RMC/GLL 看状态位（`A` 有效 / `V` 无效），
  /// GGA 看定位质量（0 = 无效）。其余类型本身不带坐标，恒为 false。
  final bool positionValid;

  final bool checksumValid;
  final String? checksumClaimed;
  final String checksumComputed;

  /// 原生时间字段原文：RMC/GGA/GLL 是 `hhmmss`，ZDA 也是 `hhmmss`
  final String utcTime;

  /// 原生日期字段原文 `ddmmyy`（GGA/GLL 不带日期，恒为空）
  final String utcDate;

  final double? latitude;
  final double? longitude;
  final double? altitudeM;

  /// 对地速度（节）。RMC 给的是节，VTG 两个都给了。
  final double? speedKnots;

  /// 对地速度（km/h）。只有 VTG 直接给，其余场合由节换算。
  final double? speedKmh;

  final double? courseDegrees;

  /// 水平精度因子（GGA / GSA）
  final double? hdop;

  /// 参与定位的卫星数（GGA）
  final int? satellites;

  /// GGA 的定位质量：0 无效 / 1 单点 / 2 差分 / 4 RTK 固定 / 5 RTK 浮动 / 6 估算
  final int? fixQuality;

  /// GSA 的定位类型：1 未定位 / 2 二维 / 3 三维
  final String fixType;

  /// RMC/GLL 的状态位（`A` / `V`）
  final String status;

  /// RMC 的定位模式（`A` 自主 / `D` 差分 / `E` 估算 / `N` 无效）
  final String mode;

  /// 由本语句单独就能确定的 UTC 时刻（只有 RMC / ZDA 给得出 ——
  /// 另外几条没有日期，要等装配器把日期补上）
  final DateTime? utc;

  bool get statusValid => status.isEmpty || status.toUpperCase() == 'A';
}

/// NMEA 0183 XOR 校验和。
///
/// 规则：`$` 之后、`*` 之前的**每个字符（含逗号）**逐字符 XOR，取两位大写十六进制。
/// 权威示例：`$GPGGA,123519,4807.038,...*47` → `0x47`。
///
/// （与 `pkwdwpl.dart` 的 `PkwdwplChecksum` 是同一套算法。没有合并它们是因为
/// 那样会让 PKWDWPL 的解析器依赖本文件，而它的产物与判据都被 CI 钉着；
/// 二十行纯函数不值得为它动那条链路。改算法时**两处都要改**。）
class NmeaChecksum {
  const NmeaChecksum._();

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

/// `度分` 格式转十进制度：`4807.038` + `N` → `48.1173`。
///
/// 为什么必须单独换算：NMEA 的经纬度**不是十进制度**，而是
/// `ddmm.mmmm` / `dddmm.mmmm`（纬度 2 位度、经度 3 位度，后面跟分）。
/// 直接当十进制度用会出现「北纬 4807 度」这种坐标，地图上直接把点扔到天外。
///
/// `dot` 的定位**必须在去符号之前**做对：拿字符串长度推位数在
/// `4807.038`（7 位有效数字）这种写法上是错的，而带小数点的写法才是规范。
double? nmeaDegrees(String raw, String hemisphere) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final dot = s.indexOf('.');
  final intPart = dot >= 0 ? s.substring(0, dot) : s;
  final frac = dot >= 0 ? s.substring(dot) : '';
  if (intPart.length < 3 || !RegExp(r'^\d+$').hasMatch(intPart)) return null;
  final deg = int.tryParse(intPart.substring(0, intPart.length - 2));
  final minutes = double.tryParse(intPart.substring(intPart.length - 2) + frac);
  if (deg == null || minutes == null) return null;
  if (minutes >= 60) return null; // 分值 ≥ 60 → 语句是坏的
  var v = deg + minutes / 60;
  final h = hemisphere.trim().toUpperCase();
  if (h == 'S' || h == 'W') v = -v;
  return v;
}

/// 把 `ddmmyy` + `hhmmss` 组合成 UTC 时间；任一字段非法则返回 null。
///
/// 世纪归属：两位年份按「<= 79 视为 20xx，否则 19xx」处理（与 APRS 惯例一致，
/// 且 2000 年前的采集设备已不会再出现）。
DateTime? nmeaCombineUtc(String utcDate, String utcTime) {
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

/// NMEA 语句解析器（纯函数，便于单测）。
class NmeaParser {
  const NmeaParser._();

  /// `$` + 两位 talker + 三位类型 + 逗号。talker 不区分，但**必须**是字母。
  static final RegExp _idRe = RegExp(r'^\$([A-Za-z]{2})([A-Za-z]{3}),');
  static final RegExp _hex2Re = RegExp(r'^[0-9A-F]{2}$');

  /// 认识但用不上的语句：**不算解析失败**（否则统计里全是「丢弃」，
  /// 用户就分不清「线路坏了」和「这条语句本来就不带定位」）。
  static const Set<String> knownUnused = {
    'GSV', 'GSA', 'VTG', 'ZDA', 'GLL', // 后四条在下面按类型处理，列在这里只为可读
  };

  static NmeaKind kindOf(String type) {
    switch (type.toUpperCase()) {
      case 'RMC':
        return NmeaKind.rmc;
      case 'GGA':
        return NmeaKind.gga;
      case 'GLL':
        return NmeaKind.gll;
      case 'ZDA':
        return NmeaKind.zda;
      case 'GSA':
        return NmeaKind.gsa;
      case 'VTG':
        return NmeaKind.vtg;
      default:
        return NmeaKind.other;
    }
  }

  /// 解析一行。
  ///
  /// 宽松模式（[strictChecksum] = false）下校验和不符仍返回结果，
  /// 但 `checksumValid` 为 false 供界面/链路计数。
  static NmeaParseResult parse(
    String line, {
    DateTime? now,
    bool strictChecksum = false,
  }) {
    final raw = line.trim();
    if (raw.length < 7 || !raw.startsWith(r'$')) {
      return const NmeaParseResult.fail(NmeaErrorCode.notNmea);
    }

    // 拆校验和：`$XXX,...,*XX`
    var body = raw.substring(1);
    String? claimed;
    final star = body.lastIndexOf('*');
    if (star >= 0) {
      claimed = body.substring(star + 1).trim().toUpperCase();
      body = body.substring(0, star);
    }
    final computed = NmeaChecksum.compute(body);
    final computedHex = NmeaChecksum.format(computed);
    final claimedOk = claimed != null && _hex2Re.hasMatch(claimed);
    final checksumValid =
        claimedOk && int.parse(claimed, radix: 16) == computed;
    if (!checksumValid && strictChecksum) {
      return NmeaParseResult.fail(
        NmeaErrorCode.checksumMismatch,
        detail: '${claimed ?? '-'} != $computedHex',
      );
    }

    final m = _idRe.firstMatch(raw);
    if (m == null) {
      return const NmeaParseResult.fail(NmeaErrorCode.notNmea);
    }
    final talker = m.group(1)!.toUpperCase();
    final type = m.group(2)!.toUpperCase();
    final kind = kindOf(type);
    if (kind == NmeaKind.other && !knownUnused.contains(type)) {
      // 完全不认识的三字母类型（含厂商私有语句）：这是「协议不对」的信号，
      // 要让用户看得见，不能悄悄当成正常语句。
      return NmeaParseResult.fail(
        NmeaErrorCode.unknownSentence,
        detail: '$talker$type',
      );
    }

    final f = body.split(',');
    return _fields(kind, f, raw, talker, type, computedHex, checksumValid,
        claimed);
  }

  static String _f(List<String> f, int i) => i < f.length ? f[i].trim() : '';

  static double? _d(String s) => s.isEmpty ? null : double.tryParse(s);

  static int? _i(String s) => s.isEmpty ? null : int.tryParse(s);

  static NmeaParseResult _fields(
    NmeaKind kind,
    List<String> f,
    String raw,
    String talker,
    String type,
    String computedHex,
    bool checksumValid,
    String? claimedRaw,
  ) {
    NmeaSentence build({
      bool positionValid = false,
      String utcTime = '',
      String utcDate = '',
      double? lat,
      double? lng,
      double? altM,
      double? speedKnots,
      double? speedKmh,
      double? course,
      double? hdop,
      int? sats,
      int? quality,
      String fixType = '',
      String status = '',
      String mode = '',
      DateTime? utc,
    }) =>
        NmeaSentence(
          id: '$talker$type',
          talker: talker,
          type: type,
          raw: raw,
          kind: kind,
          positionValid: positionValid,
          checksumValid: checksumValid,
          checksumClaimed: claimedRaw,
          checksumComputed: computedHex,
          utcTime: utcTime,
          utcDate: utcDate,
          latitude: lat,
          longitude: lng,
          altitudeM: altM,
          speedKnots: speedKnots,
          speedKmh: speedKmh,
          courseDegrees: course,
          hdop: hdop,
          satellites: sats,
          fixQuality: quality,
          fixType: fixType,
          status: status,
          mode: mode,
          utc: utc,
        );

    switch (kind) {
      case NmeaKind.rmc:
        if (f.length < 10) {
          return NmeaParseResult.fail(
            NmeaErrorCode.tooFewFields,
            detail: '$talker$type/${f.length}',
          );
        }
        final status = _f(f, 2);
        final lat = nmeaDegrees(_f(f, 3), _f(f, 4));
        final lng = nmeaDegrees(_f(f, 5), _f(f, 6));
        // 空坐标是合法的（模块还没定上时会发空字段），非空却算不出来才是坏语句
        if (_f(f, 3).isNotEmpty && lat == null) {
          return NmeaParseResult.fail(
            NmeaErrorCode.badCoordinate,
            detail: '${_f(f, 3)}${_f(f, 4)}',
          );
        }
        if (_f(f, 5).isNotEmpty && lng == null) {
          return NmeaParseResult.fail(
            NmeaErrorCode.badCoordinate,
            detail: '${_f(f, 5)}${_f(f, 6)}',
          );
        }
        final utcTime = _f(f, 1);
        final utcDate = _f(f, 9);
        return NmeaParseResult.ok(build(
          positionValid:
              status.toUpperCase() == 'A' && lat != null && lng != null,
          utcTime: utcTime,
          utcDate: utcDate,
          lat: lat,
          lng: lng,
          speedKnots: _d(_f(f, 7)),
          course: _d(_f(f, 8)),
          status: status,
          mode: _f(f, 12),
          utc: nmeaCombineUtc(utcDate, utcTime),
        ));

      case NmeaKind.gga:
        if (f.length < 10) {
          return NmeaParseResult.fail(
            NmeaErrorCode.tooFewFields,
            detail: '$talker$type/${f.length}',
          );
        }
        final lat = nmeaDegrees(_f(f, 2), _f(f, 3));
        final lng = nmeaDegrees(_f(f, 4), _f(f, 5));
        if (_f(f, 2).isNotEmpty && lat == null) {
          return NmeaParseResult.fail(
            NmeaErrorCode.badCoordinate,
            detail: '${_f(f, 2)}${_f(f, 3)}',
          );
        }
        if (_f(f, 4).isNotEmpty && lng == null) {
          return NmeaParseResult.fail(
            NmeaErrorCode.badCoordinate,
            detail: '${_f(f, 4)}${_f(f, 5)}',
          );
        }
        final quality = _i(_f(f, 6));
        return NmeaParseResult.ok(build(
          positionValid:
              quality != null && quality > 0 && lat != null && lng != null,
          utcTime: _f(f, 1),
          lat: lat,
          lng: lng,
          quality: quality,
          sats: _i(_f(f, 7)),
          hdop: _d(_f(f, 8)),
          altM: _d(_f(f, 9)),
        ));

      case NmeaKind.gll:
        if (f.length < 7) {
          return NmeaParseResult.fail(
            NmeaErrorCode.tooFewFields,
            detail: '$talker$type/${f.length}',
          );
        }
        final lat = nmeaDegrees(_f(f, 1), _f(f, 2));
        final lng = nmeaDegrees(_f(f, 3), _f(f, 4));
        if (lat == null || lng == null) {
          return NmeaParseResult.fail(
            NmeaErrorCode.badCoordinate,
            detail: '${_f(f, 1)}${_f(f, 2)}/${_f(f, 3)}${_f(f, 4)}',
          );
        }
        final status = _f(f, 6);
        return NmeaParseResult.ok(build(
          positionValid: status.toUpperCase() == 'A',
          utcTime: _f(f, 5),
          lat: lat,
          lng: lng,
          status: status,
          mode: _f(f, 7),
        ));

      case NmeaKind.zda:
        if (f.length < 5) {
          return NmeaParseResult.fail(
            NmeaErrorCode.tooFewFields,
            detail: '$talker$type/${f.length}',
          );
        }
        final day = _i(_f(f, 2));
        final month = _i(_f(f, 3));
        final year = _i(_f(f, 4));
        DateTime? utc;
        if (day != null && month != null && year != null) {
          final t = _f(f, 1);
          final hh = t.length >= 2 ? int.tryParse(t.substring(0, 2)) ?? 0 : 0;
          final mm = t.length >= 4 ? int.tryParse(t.substring(2, 4)) ?? 0 : 0;
          final ss = t.length >= 6 ? int.tryParse(t.substring(4, 6)) ?? 0 : 0;
          if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
            utc = DateTime.utc(year, month, day, hh, mm, ss);
          }
        }
        return NmeaParseResult.ok(build(
          utcTime: _f(f, 1),
          utcDate: (day != null && month != null && year != null)
              ? '${day.toString().padLeft(2, '0')}'
                  '${month.toString().padLeft(2, '0')}'
                  '${(year % 100).toString().padLeft(2, '0')}'
              : '',
          utc: utc,
        ));

      case NmeaKind.gsa:
        // 字段固定 18 段（含 id），末尾还可能有 systemId。缺尾部就只取到多少算多少：
        // HDOP 的位置是稳定的（倒数第三），北斗模块多一个 systemId 也不影响前面。
        if (f.length < 18) {
          return NmeaParseResult.fail(
            NmeaErrorCode.tooFewFields,
            detail: '$talker$type/${f.length}',
          );
        }
        return NmeaParseResult.ok(build(
          mode: _f(f, 1),
          fixType: _f(f, 2),
          hdop: _d(_f(f, 16)),
        ));

      case NmeaKind.vtg:
        if (f.length < 8) {
          return NmeaParseResult.fail(
            NmeaErrorCode.tooFewFields,
            detail: '$talker$type/${f.length}',
          );
        }
        return NmeaParseResult.ok(build(
          course: _d(_f(f, 1)),
          speedKnots: _d(_f(f, 5)),
          speedKmh: _d(_f(f, 7)),
        ));

      case NmeaKind.other:
        // 认识但不带定位（GSV / GBS / TXT …）。照样返回一条语句对象，
        // 让上层能按「忽略」而不是「丢弃」计数。
        return NmeaParseResult.ok(build());
    }
  }
}

/// 一次可用的定位（由多条语句**合并**而成，见 [NmeaAssembler]）。
///
/// 为什么要合并而不是「一条语句一个点」：定位所需的信息分散在不同语句里 ——
/// 坐标与速度在 RMC、海拔与精度在 GGA、日期只可能来自 RMC/ZDA。
/// 只取其中一条会出现「有坐标但没海拔」「有速度但没精度」，界面上看着像缺数据。
class NmeaFix {
  const NmeaFix({
    required this.at,
    required this.lat,
    required this.lng,
    required this.source,
    required this.raw,
    this.altM,
    this.speedKmh,
    this.courseDeg,
    this.hdop,
    this.satellites,
    this.fixQuality,
    this.accuracyM,
    this.utc,
    this.checksumValid = true,
  });

  /// 本机收到这条语句的时刻（本地时钟）。
  ///
  /// 与 [utc] 分开保存是有意的：模块的时间来自卫星（可能还没同步上、
  /// 也可能整机没有电池而回到 2000 年），而「这条定位是不是新鲜」
  /// 必须按本机时钟判断，不能信模块。
  final DateTime at;

  final double lat;
  final double lng;
  final double? altM;

  /// 对地速度（km/h）
  final double? speedKmh;

  /// 对地航向（度，0~360）
  final double? courseDeg;

  /// 水平精度因子（原始值，来自 GGA/GSA）
  final double? hdop;

  /// 参与定位的卫星数（GGA）。双模模块会把各系统相加，见
  /// [NmeaAssembler] 的 `_combinedSats`。
  final int? satellites;

  /// GGA 定位质量（0~8；null = 该模块不发 GGA）
  final int? fixQuality;

  /// 由 HDOP **估算**出的水平精度（米，1σ）；null = 没有 HDOP，无从估算。
  ///
  /// 估算方式与依据：`精度 ≈ HDOP × UERE`，UERE（等效测距误差）取 5 m 是
  /// 民用单频接收机的常见量级（1σ）。它有量纲、能被界面上「±N m」用、
  /// 也能进轨迹台账；但它**是估算不是实测** —— 所以字段名与注释都写着。
  /// 不用它做任何「这个点要不要」的闸门，只用来如实显示。
  final double? accuracyM;

  /// 模块给出的 UTC 时刻（RMC/ZDA/GGA+缓存日期合成）；可能为 null
  final DateTime? utc;

  /// 触发这次定位的语句 id（`GNRMC` / `BDGGA` …），日志与详情页用
  final String source;

  /// 触发这次定位的原始语句
  final String raw;

  /// 这条定位来自的语句校验和是否相符。
  ///
  /// 只有**关掉严格校验**（[NmeaAssembler.strictChecksum] = false）时才可能为
  /// false —— 那时坐标照用，但链路必须能把它计数并显示出来（模组发错校验和
  /// 是少数杂牌货的通病，用户有权知道「现在这个点是在宽松模式下拿到的」）。
  final bool checksumValid;
}

/// 把一串 NMEA 语句**装配**成一条条可用的定位。
///
/// 为什么需要它（而不只是逐条解析）：定位信息天生分散在多条语句里，
/// 而且**每条到达的顺序不保证**（有的模块先发 GGA 再发 RMC，有的相反；
/// 有的只发其中一条）。所以这里做两件事：
///   * 记住最近一次见到的「配角字段」（海拔/精度/卫星数/日期/速度航向）；
///   * 只在**带着可用坐标**的那条语句到达时才产出一条 [NmeaFix]，
///     并把配角字段补齐。
/// 由此得到的频率是「每秒 1~10 次定位」（取决于模块的语句频率），
/// 而不是「每条语句一次」—— 后者会让上层拿同一秒的位置重复入轨迹。
class NmeaAssembler {
  NmeaAssembler({this.strictChecksum = true});

  /// 校验和不符时是否丢弃该条。
  ///
  /// 默认 **true（丢弃）**，与 `PkwdwplConfig.strictChecksum` 的默认刻意不同：
  /// 那条链路是「电台 → 手机」的本地线缆，出现校验不符通常说明固件与手册有出入，
  /// 丢光会让用户面对一个空界面；而外接 GPS 模块是**按标准发语句**的，
  /// 校验不符几乎只有一个原因 —— 线路上真的被插入了噪声（接错线、
  /// 波特率不匹配、蓝牙被别的设备抢带宽）。那种字节宁可丢，不该当成坐标用。
  /// 少数杂牌模块确实会发错校验和：设备页有关掉它的开关，且丢弃条数一直显示。
  bool strictChecksum;

  /// 估算精度时假设的等效测距误差（米，1σ，民用单频）
  static const double uereM = 5.0;

  /// 最近一次解析失败的原因（null = 上一次是好的/被忽略的语句）
  NmeaErrorCode? lastError;

  /// 上一次失败/忽略的细节（语句 id 或校验和的收到/计算值）
  String lastDetail = '';

  double? _speedKnots;
  double? _speedKmh;
  double? _course;
  double? _altM;
  double? _hdop;
  int? _satellites;
  int? _fixQuality;

  /// 一个 talker 的颗数算「这一轮」多久。
  ///
  /// 模块每轮 1 秒发一遍 GGA，15 秒是留给丢包与低频输出的余量；
  /// 超过它还不再报的系统就是真的掉了，继续留着只会把合计撑大。
  static const Duration _satsFresh = Duration(seconds: 15);

  /// 每个 talker 最近一次 GGA 报的「参与解算颗数」（`GP` / `BD` / `GL` / `GA` / `GB` / `GN`）。
  ///
  /// 为什么按 talker 分开记：双模模块每轮会**各发一条** GGA，每条只报自己那个
  /// 系统的颗数（`$GPGGA` 报 10、`$BDGGA` 报 10）。只留最后一条看到的值，
  /// 界面上就会出现「模组明明 20 颗、软件只显示 10 颗」。
  final Map<String, int> _satsByTalker = <String, int>{};

  /// 上面每个数是什么时候收到的（本机时钟），过期的系统不再计入合计。
  final Map<String, DateTime> _satsAt = <String, DateTime>{};

  String _fixType = '';
  String _utcTime = '';
  String _date = '';

  /// ZDA 给的完整时刻（RMC 缺日期时用它兜底）
  DateTime? _zdaUtc;

  /// 喂一行。返回非空表示**这一行带来了一次可用的定位**。
  NmeaFix? feed(String line, {DateTime? now}) {
    final r = NmeaParser.parse(line, strictChecksum: strictChecksum);
    if (!r.isOk) {
      lastError = r.error;
      lastDetail = r.detail ?? '';
      return null;
    }
    return accept(r.sentence!, now: now);
  }

  /// 接受一条已解析好的语句。
  NmeaFix? accept(NmeaSentence s, {DateTime? now}) {
    lastError = null;
    lastDetail = '';
    switch (s.kind) {
      case NmeaKind.rmc:
        if (s.utcTime.isNotEmpty) _utcTime = s.utcTime;
        if (s.utcDate.isNotEmpty) _date = s.utcDate;
        if (s.speedKnots != null) _speedKnots = s.speedKnots;
        if (s.courseDegrees != null) _course = s.courseDegrees;
      case NmeaKind.gga:
        // GGA 的时间比 RMC 的粗（有的模块只给到整秒），但有日期时以 RMC 为准；
        // 这里仅在还没有时间时兜底，避免用 GGA 覆盖掉更完整的 RMC 时间。
        if (_utcTime.isEmpty && s.utcTime.isNotEmpty) _utcTime = s.utcTime;
        if (s.altitudeM != null) _altM = s.altitudeM;
        if (s.hdop != null) _hdop = s.hdop;
        if (s.satellites != null) {
          _satellites = s.satellites;
          _satsByTalker[s.talker] = s.satellites!;
          _satsAt[s.talker] = now ?? DateTime.now();
        }
        if (s.fixQuality != null) _fixQuality = s.fixQuality;
      case NmeaKind.gll:
        if (_utcTime.isEmpty && s.utcTime.isNotEmpty) _utcTime = s.utcTime;
      case NmeaKind.zda:
        if (s.utcTime.isNotEmpty) _utcTime = s.utcTime;
        if (s.utcDate.isNotEmpty) _date = s.utcDate;
        if (s.utc != null) _zdaUtc = s.utc;
      case NmeaKind.gsa:
        if (s.hdop != null) _hdop = s.hdop;
        if (s.fixType.isNotEmpty) _fixType = s.fixType;
      case NmeaKind.vtg:
        if (s.speedKnots != null) _speedKnots = s.speedKnots;
        if (s.speedKmh != null) _speedKmh = s.speedKmh;
        if (s.courseDegrees != null) _course = s.courseDegrees;
      case NmeaKind.other:
        return null;
    }

    if (!s.positionValid) {
      // 模块**明确说**这次定位无效（RMC 状态 V / GGA 质量为 0）。
      // 冷启动、进隧道、天线被遮住时都会这样 —— 不是错误，如实记下来即可。
      lastError = NmeaErrorCode.noFix;
      lastDetail = s.id;
      return null;
    }

    final hdop = s.hdop ?? _hdop;
    // 速度：优先**本条语句**自己的值（它是刚到的），其次才是缓存里上一条的 ——
    // 反过来写会出现「VTG 关掉之后速度还停在最后一帧」这种粘滞。
    final double? speedKmh;
    if (s.speedKmh != null) {
      speedKmh = s.speedKmh;
    } else if (s.speedKnots != null) {
      speedKmh = s.speedKnots! * 1.852;
    } else {
      speedKmh =
          _speedKmh ?? (_speedKnots != null ? _speedKnots! * 1.852 : null);
    }
    return NmeaFix(
      at: now ?? DateTime.now(),
      lat: s.latitude!,
      lng: s.longitude!,
      altM: s.altitudeM ?? _altM,
      speedKmh: speedKmh,
      courseDeg: s.courseDegrees ?? _course,
      hdop: hdop,
      satellites: _combinedSats(now ?? DateTime.now()) ?? s.satellites,
      fixQuality: s.fixQuality ?? _fixQuality,
      accuracyM: (hdop != null && hdop > 0) ? hdop * uereM : null,
      utc: s.utc ?? _zdaUtc ?? nmeaCombineUtc(_date, _utcTime),
      source: s.id,
      raw: s.raw,
      checksumValid: s.checksumValid,
    );
  }

  /// 最近一次 GSA 的定位类型（1 未定位 / 2 二维 / 3 三维），供界面显示
  String get fixType => _fixType;

  /// 各系统 GGA 报的参与解算颗数合计。
  ///
  /// 双模模块每轮分别发 `$GPGGA` / `$BDGGA`，每条只含**自己系统**的数（10 + 10），
  /// 所以这里按 talker 分别记、再相加。
  /// `GN` 是模块自己算出的联合解，本身就是合计，它在就只取它 —— 再加一遍
  /// 会变成 10 + 10 + 20 这种荒唐数。
  int? _combinedSats(DateTime now) {
    if (_satsByTalker.isEmpty) return _satellites;
    bool fresh(String talker) {
      final at = _satsAt[talker];
      return at == null || now.difference(at) <= _satsFresh;
    }

    final gn = _satsByTalker['GN'];
    if (gn != null && fresh('GN')) return gn;
    var sum = 0;
    var any = false;
    _satsByTalker.forEach((talker, n) {
      if (talker == 'GN' || !fresh(talker)) return;
      sum += n;
      any = true;
    });
    return any ? sum : _satellites;
  }

  /// 断开重连时清空缓存：跨链路残留的日期/海拔会把新链路的头几条定位
  /// 拼成一条「跨设备」的怪数据（症状是刚连上时海拔/速度明显是上一次的值）。
  void reset() {
    _speedKnots = null;
    _speedKmh = null;
    _course = null;
    _altM = null;
    _hdop = null;
    _satellites = null;
    _satsByTalker.clear();
    _satsAt.clear();
    _fixQuality = null;
    _fixType = '';
    _utcTime = '';
    _date = '';
    _zdaUtc = null;
    lastError = null;
    lastDetail = '';
  }
}
