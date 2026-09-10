import 'dart:math' as math;

/// APRS 位置数据包解析
///
/// 支持的数据类型标识（DTI）：
///   `!` / `=`  无时间戳位置（= 具备消息能力）
///   `/` / `@`  带时间戳位置（@ 具备消息能力）
///   `'` / `` ` `` Mic-E 编码位置（位置在目的呼号 + 信息字段中编码，需传入 dest）
///
/// 位置格式：非压缩（DDMM.mmN/DDDMM.mmW>）与压缩（Base91）。
/// 解析逻辑对齐 APRS101 规范与 aprslib 参考实现（已用真实 APRS-IS 报文验证）。
class ParsedPos {
  final double lat, lng;
  final String symbol;
  final String symbolTable; // 符号表字符（默认 '/'）
  final String? comment;
  final double? speed; // km/h
  final double? course; // 度（1-360）
  final double? alt; // 米
  final int posAmbiguity; // 位置模糊位数（0-4）
  final String format; // uncompressed / compressed / mic-e

  const ParsedPos({
    required this.lat,
    required this.lng,
    this.symbol = '>',
    this.symbolTable = '/',
    this.comment,
    this.speed,
    this.course,
    this.alt,
    this.posAmbiguity = 0,
    this.format = 'uncompressed',
  });
}

/// 解析 APRS 位置帧体
/// [dest] 目的呼号地址（Mic-E 必需：纬度数字与 N/S、E/W 编码在其中）
ParsedPos? parseAprsPosition(String body, {String? dest}) {
  if (body.isEmpty) return null;
  final dti = body[0];

  // ── Mic-E：位置编码在目的呼号 + 信息字段中 ──
  if (dti == "'" || dti == '`') {
    final d = dest;
    if (d == null || d.isEmpty) return null;
    return parseMice(d, body);
  }

  if (dti != '!' && dti != '=' && dti != '/' && dti != '@') return null;

  var s = body.substring(1);

  // 带时间戳的位置包：7 字符时间戳（DDHHMMz / HHMMSSh / DDHHMM/）
  if (dti == '/' || dti == '@') {
    if (s.length < 8) return null;
    s = s.substring(7);
  }
  if (s.isEmpty) return null;

  // 压缩格式优先（其首字符为符号表，非压缩首字符为纬度数字，不会冲突）
  final c = _parseCompressed(s);
  if (c != null) return c;

  return _parseNormal(s);
}

// ─────────────────────────── 非压缩格式 ───────────────────────────

/// 非压缩位置：DDMM.mmN/DDDMM.mmW>备注
/// 允许模糊位置（数字位为空格）与小写 N/S/E/W
final RegExp _normalRe = RegExp(
  r'^(\d{2})([0-9 ]{2}\.[0-9 ]{2})([NnSs])([/\\0-9A-Z])'
  r'(\d{3})([0-9 ]{2}\.[0-9 ]{2})([EeWw])([\x21-\x7e])([\s\S]*)$',
);

ParsedPos? _parseNormal(String s) {
  final m = _normalRe.firstMatch(s);
  if (m == null) return null;

  final latDeg = int.parse(m.group(1)!);
  var latMin = m.group(2)!;
  final latDir = m.group(3)!;
  final symbolTable = m.group(4)!;
  final lngDeg = int.parse(m.group(5)!);
  var lngMin = m.group(6)!;
  final lngDir = m.group(7)!;
  final symbol = m.group(8)!;
  final rawComment = m.group(9)!;

  // 位置模糊：数字位为空格，取模糊格中心
  final amb = latMin.split('').where((c) => c == ' ').length;
  if (amb != lngMin.split('').where((c) => c == ' ').length) return null;
  if (amb >= 4) {
    latMin = '30';
    lngMin = '30';
  } else if (amb > 0) {
    latMin = latMin.replaceFirst(' ', '5');
    lngMin = lngMin.replaceFirst(' ', '5');
  }

  if (latDeg > 89 || lngDeg > 179) return null;

  var lat = latDeg + double.parse(latMin) / 60.0;
  var lng = lngDeg + double.parse(lngMin) / 60.0;
  if (latDir == 'S' || latDir == 's') lat = -lat;
  if (lngDir == 'W' || lngDir == 'w') lng = -lng;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;

  final ex = _parseExtras(rawComment);
  return ParsedPos(
    lat: lat,
    lng: lng,
    symbol: symbol,
    symbolTable: symbolTable,
    comment: ex.comment,
    speed: ex.speed,
    course: ex.course,
    alt: ex.alt,
    posAmbiguity: amb,
    format: 'uncompressed',
  );
}

// ─────────────────────────── 压缩格式 ───────────────────────────

/// 压缩位置固定段共 13 字符：
/// [0] 符号表 [1..4] 纬度 [5..8] 经度 [9] 符号 [10..11] 航向/速度 [12] 类型
final RegExp _compRe = RegExp(r'^[/\\A-Za-j][!-|]{8}[!-{}][ -|]{3}');

ParsedPos? _parseCompressed(String s) {
  if (!_compRe.hasMatch(s) || s.length < 13) return null;
  final c = s.substring(0, 13);
  final rest = s.length > 13 ? s.substring(13) : '';

  final lat = 90 - (_b91Dec(c.substring(1, 5)) / 380926.0);
  final lng = -180 + (_b91Dec(c.substring(5, 9)) / 190463.0);
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;

  // csT：直接取 ASCII 值 −33（非 Base91 索引）
  final c1 = c.codeUnitAt(10) - 33;
  final s1 = c.codeUnitAt(11) - 33;
  final ctype = c.codeUnitAt(12) - 33;

  double? course, speed, alt;
  if (c1 != -1 && s1 != -1) {
    if ((ctype & 0x18) == 0x10) {
      // 该字段为海拔（英尺 → 米）
      alt = (math.pow(1.002, c1 * 91 + s1) * 0.3048).toDouble();
    } else if (c1 >= 0 && c1 <= 89) {
      // 航向 4° 递增；速度按 1.08^n 指数增长（节 → km/h）
      course = c1 == 0 ? 360.0 : (c1 * 4).toDouble();
      speed = ((math.pow(1.08, s1) - 1) * 1.852).toDouble();
    }
  }

  return ParsedPos(
    lat: lat,
    lng: lng,
    symbol: c[9],
    symbolTable: c[0],
    comment: _cleanComment(rest),
    speed: speed,
    course: course,
    alt: alt,
    format: 'compressed',
  );
}

/// APRS Base91 → 十进制
/// 取值即 `ASCII 码 − 33`（可打印字符 0x21..0x7B，等价于「!'#…z{|」连续序列），
/// 并非自定字符表——错用字符表会使经纬度完全偏移
int _b91Dec(String s) {
  var n = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c < 0x21 || c > 0x7B) return 0;
    n = n * 91 + (c - 33);
  }
  return n;
}

// ─────────────────────────── Mic-E ───────────────────────────

/// Mic-E 解码（对齐 aprslib/APRS101，已用 82 条真实报文验证）
/// 纬度数字与 N/S、E/W 由目的呼号编码，经度与航向/速度在信息字段中
ParsedPos? parseMice(String destRaw, String body) {
  final dest = destRaw.split('-')[0];
  if (dest.length != 6) return null;
  if (!RegExp(r'^[0-9A-Z]{3}[0-9L-Z]{3}$').hasMatch(dest)) return null;
  if (body.isEmpty) return null;
  // 去掉 DTI（' 或 `）：其后字段才是经纬度/速度/航向
  final info = body.substring(1);
  if (info.length < 8) return null;

  // ── 纬度：目的呼号 6 字符各映射 1 位数字 ──
  final b = StringBuffer();
  for (var i = 0; i < 6; i++) {
    final ch = dest[i];
    final o = ch.codeUnitAt(0);
    if (ch == 'K' || ch == 'L' || ch == 'Z') {
      b.write(' '); // 模糊位
    } else if (o > 76) {
      // 'M'-'Z' → 数字（P=0 … Y=9）
      b.write(String.fromCharCode(o - 32));
    } else if (o > 57) {
      // 'A'-'J' → 0-9
      b.write(String.fromCharCode(o - 17));
    } else {
      b.write(ch);
    }
  }
  final ambM = RegExp(r'^(\d+)( *)$').firstMatch(b.toString());
  if (ambM == null) return null;
  final amb = ambM.group(2)!.length;
  final dl = b.toString().split('');
  if (amb > 0) {
    if (amb >= 4) {
      dl[2] = '3';
    } else {
      dl[6 - amb] = '5';
    }
  }
  final d = dl.join();
  final latMin =
      double.parse('${d.substring(2, 4)}.${d.substring(4, 6)}'.replaceAll(' ', '0'));
  var lat = int.parse(d.substring(0, 2)) + latMin / 60.0;
  if (dest.codeUnitAt(3) <= 0x4C) lat = -lat; // 'L' 及以下 → 南纬

  // ── 经度 ──
  var lng = (info.codeUnitAt(0) - 28).toDouble();
  if (dest.codeUnitAt(4) >= 0x50) lng += 100;
  if (lng >= 180 && lng <= 189) lng -= 80;
  if (lng >= 190 && lng <= 199) lng -= 190;
  var lngMin = (info.codeUnitAt(1) - 28).toDouble();
  if (lngMin >= 60) lngMin -= 60;
  lngMin += (info.codeUnitAt(2) - 28) / 100.0;
  if (amb == 4) {
    lngMin = 30;
  } else if (amb == 3) {
    lngMin = ((lngMin ~/ 10) + 0.5) * 10;
  } else if (amb == 2) {
    lngMin = lngMin.floorToDouble() + 0.5;
  } else if (amb == 1) {
    lngMin = ((lngMin * 10).floorToDouble() + 0.5) / 10.0;
  }
  lng = lng + lngMin / 60.0;
  if (dest.codeUnitAt(5) >= 0x50) lng = -lng; // 'P' 及以上 → 西经
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;

  // ── 航向 / 速度 ──
  var speed = (info.codeUnitAt(3) - 28) * 10.0;
  var course = (info.codeUnitAt(4) - 28).toDouble();
  final q = (course / 10).floor();
  course = course - q * 10;
  course = course * 100 + (info.codeUnitAt(5) - 28);
  speed += q;
  if (speed >= 800) speed -= 800;
  if (course >= 400) course -= 400;
  speed *= 1.852; // 节 → km/h

  final symbol = info[6];
  final symbolTable = info[7];
  var rest = info.substring(8);
  // 遥测前缀：' + 10 位十六进制 / ` + 4 位十六进制
  final tel = RegExp(r"^('[0-9a-fA-F]{10}|`[0-9a-fA-F]{4})").firstMatch(rest);
  if (tel != null) rest = rest.substring(tel.group(0)!.length);
  // Mic-E 能力标志字节（']' / '}' 之类）不属于可读备注，去掉
  if (rest.isNotEmpty && (rest[0] == ']' || rest[0] == '}')) {
    rest = rest.substring(1);
  }

  return ParsedPos(
    lat: lat,
    lng: lng,
    symbol: symbol,
    symbolTable: symbolTable,
    comment: _cleanComment(rest),
    speed: speed,
    course: course,
    posAmbiguity: amb,
    format: 'mic-e',
  );
}

// ─────────────────────────── 备注与附加字段 ───────────────────────────

class _Extras {
  final String? comment;
  final double? speed;
  final double? course;
  final double? alt;
  const _Extras(this.comment, this.speed, this.course, this.alt);
}

/// 从备注中提取 航向/速度（ddd/sss，位于备注开头）与高度（/A=ffffff）
_Extras _parseExtras(String c) {
  var body = c;
  double? alt;
  // 高度：/A= 后 5-6 位数字（英尺），限定长度避免贪婪吞掉后续数字
  final am = RegExp(r'^(.*?)/A=(-?\d{5,6})(.*)$').firstMatch(body);
  if (am != null) {
    final ft = int.tryParse(am.group(2)!);
    if (ft != null) alt = ft * 0.3048;
    body = am.group(1)! + am.group(3)!;
  }
  // 航向/速度：ddd/sss（度 / 节）。规范要求位于备注开头，但部分第三方/旧版
  // 固件（含本应用旧版信标）把 /A= 放在前面，因此兼容“任意位置”：
  // 前后不得紧邻数字，避免误吃 PHG3280/1K2 这类文本。000 表示无效。
  double? course, speed;
  final cm = RegExp(r'(?<![0-9])(\d{3})/(\d{2,3})(?![0-9])').firstMatch(body);
  if (cm != null) {
    final cs = cm.group(1)!;
    final sp = cm.group(2)!;
    final v = int.parse(cs);
    final spv = int.parse(sp);
    if (v >= 1 && v <= 360) course = v.toDouble();
    if (spv != 0) speed = spv * 1.852;
    // 无论值是否有效（000/000 表示无航向/速度），该字段都应从备注中移除
    body = body.replaceRange(cm.start, cm.end, '');
  }
  final s = body.trim();
  return _Extras(s.isEmpty ? null : s, speed, course, alt);
}

bool _allDigits(String s) {
  if (s.isEmpty) return false;
  for (var i = 0; i < s.length; i++) {
    final o = s.codeUnitAt(i);
    if (o < 0x30 || o > 0x39) return false;
  }
  return true;
}

/// 清理备注：仅保留可读文字（附加字段已在 _parseExtras 中剥离）
String? _cleanComment(String? c) {
  if (c == null) return null;
  final s = c.trim();
  return s.isEmpty ? null : s;
}
