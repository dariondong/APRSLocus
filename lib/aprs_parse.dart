/// APRS 位置数据包解析
class ParsedPos {
  final double lat, lng;
  final String symbol;
  final String symbolTable; // 符号表字符（默认 '/'）
  final String? comment;
  final double? speed; // km/h
  final double? course; // 度
  final double? alt; // 米
  const ParsedPos({
    required this.lat,
    required this.lng,
    this.symbol = '>',
    this.symbolTable = '/',
    this.comment,
    this.speed,
    this.course,
    this.alt,
  });
}

/// 解析 APRS 位置帧体（支持 !、=、@ 前缀，非压缩与压缩格式）
/// body 示例：!3904.25N/11624.44E>Portable
///           =3904.25N/11624.44E>   （带时间戳）
///           @220517z/3904.25N/11624.44E>
///           !/5L!<*e7>              （压缩格式）
ParsedPos? parseAprsPosition(String body) {
  String s = body;
  if (s.startsWith('@')) {
    // @HHMMSSh/ 时间戳 8 字符（含表标识）
    s = s.length > 8 ? s.substring(8) : '';
  } else if (s.startsWith('=') || s.startsWith('!')) {
    s = s.substring(1);
  } else {
    return null;
  }
  s = s.trim();

  // 非压缩：纬度固定 8 字符 ddmm.mmN/S，分隔符 / 固定在 index 8
  // （不能用 indexOf('/')，备注里的斜杠会干扰）
  if (s.length >= 18 && RegExp(r'^\d{4}\.\d{2}[NS]').hasMatch(s)) {
    final latPart = s.substring(0, 8);
    final rest = s.substring(9);
    final lngPart = rest.substring(0, 9);

    final lat = _parseDeg(latPart, isLat: true);
    final lng = _parseDeg(lngPart, isLat: false);
    if (lat == null || lng == null) return null;

    String symbol = '>';
    String symbolTable = '/';
    String? comment;
    if (rest.length > 9) {
      // APRS 非压缩位置：s[8] 是经纬度间的分隔符，即符号表
      // 经度后第一个字符 rest[9] 是符号码
      symbolTable = s[8];
      symbol = rest[9]; // 符号码
      if (rest.length > 10) comment = rest.substring(10).trim();
    }

    // 解析速度/航向/高度
    double? speed, course, alt;
    if (comment != null) {
      // 高度：/A=ffffff（英尺），转换为米（可能在速度之前）
      final altMatch = RegExp(r'/A=(\d+)').firstMatch(comment);
      if (altMatch != null) {
        final feet = int.tryParse(altMatch.group(1)!);
        if (feet != null) alt = feet * 0.3048;
      }
      // 航向/速度：ddd/sss（航向度数/速度节），如 090/050（可在备注任意位置）
      final csvMatch = RegExp(r'(\d{3})/(\d{2,3})').firstMatch(comment);
      if (csvMatch != null) {
        final c = int.tryParse(csvMatch.group(1)!);
        final s = int.tryParse(csvMatch.group(2)!);
        if (c != null && c >= 1 && c <= 360) course = c.toDouble();
        if (s != null) speed = s * 1.852; // 节 → km/h
      }
    }

    return ParsedPos(
      lat: lat,
      lng: lng,
      symbol: symbol,
      symbolTable: symbolTable,
      comment: _cleanComment(comment),
      speed: speed,
      course: course,
      alt: alt,
    );
  }

  // 压缩格式：可能带前导 / 或 \（表标识）
  String cTable = '/';
  if (s.isNotEmpty && (s[0] == '/' || s[0] == '\\')) {
    cTable = s[0];
    s = s.substring(1);
  }
  if (s.length >= 9) {
    return _parseCompressed(s, symbolTable: cTable);
  }
  return null;
}

/// 清理备注：移除速度/航向/高度等已解析字段，只保留可读文字
String? _cleanComment(String? c) {
  if (c == null || c.isEmpty) return null;
  var s = c;
  // 移除航向/速度 ddd/sss（可在任意位置）
  s = s.replaceAll(RegExp(r'\d{3}/\d{2,3}'), '').trim();
  // 移除高度 /A=ffffff
  s = s.replaceAll(RegExp(r'/A=\d+'), '').trim();
  return s.isEmpty ? null : s;
}

/// Base91 字符集（索引 0-90）
const String _b91 =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    '!#\$%&()*+,-./:;<=>?@[\\]^_`{|}~';

const int _y91 = 68574961; // 91^4

int? _b91v(String c) {
  final i = _b91.indexOf(c);
  return i >= 0 ? i : null;
}

/// 解码压缩坐标（4 字符 Base91）
/// 规范：lat = 90 - n*90/91^4，lng = -180 + n*180/91^4
double? _compressedCoord(String s, {required bool isLat}) {
  if (s.length < 4) return null;
  int n = 0;
  for (var i = 0; i < 4; i++) {
    final v = _b91v(s[i]);
    if (v == null) return null;
    n = n * 91 + v;
  }
  if (isLat) return 90 - n * 90.0 / _y91;
  return -180 + n * 180.0 / _y91;
}

ParsedPos? _parseCompressed(String s, {String symbolTable = '/'}) {
  // s 形如：5L!<*e7>...（lat4+lng4+sym+...）
  if (s.length < 9) return null;
  final lat = _compressedCoord(s.substring(0, 4), isLat: true);
  final lng = _compressedCoord(s.substring(4, 8), isLat: false);
  if (lat == null || lng == null) return null;
  // 校验坐标范围（解码失败会得到荒谬值）
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  String symbol = '>';
  String? comment;
  double? speed, course;
  // 压缩位置：lat4lng4 symbol [cs2] comment
  if (s.length > 8) {
    symbol = s[8];
    if (s.length > 10) {
      // s[9] 航向(1-360 用 1-255 压缩，>255 表示无效)，s[10] 速度节
      final c1 = _b91v(s[9]);
      final c2 = _b91v(s[10]);
      if (c1 != null && c1 <= 254) course = c1 * 1.0;
      if (c2 != null) speed = c2 * 1.852; // 节 → km/h
      if (s.length > 11) comment = s.substring(11).trim();
    }
  }
  return ParsedPos(
    lat: lat,
    lng: lng,
    symbol: symbol,
    symbolTable: symbolTable,
    comment: _cleanComment(comment),
    speed: speed,
    course: course,
  );
}

/// 解析 ddmm.hhN / dddmm.hhE
double? _parseDeg(String part, {required bool isLat}) {
  if (part.length < 4) return null;
  final dir = part[part.length - 1];
  final num = part.substring(0, part.length - 1);
  final degLen = isLat ? 2 : 3;
  if (num.length < degLen + 2) return null;
  final deg = int.tryParse(num.substring(0, degLen));
  final min = double.tryParse(num.substring(degLen));
  if (deg == null || min == null) return null;
  if (min >= 60) return null; // 畸形帧：分钟超过 59 拒绝
  final v = deg + min / 60;
  return (dir == 'S' || dir == 'W') ? -v : v;
}
