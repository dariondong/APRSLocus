import 'dart:math' as math;

/// ─── 卫星 QSO：星历（TLE）与过境时间 ───
///
/// 这一层是**纯逻辑**：解析 TLE、按二体开普勒外推星下点、算下一次过境。
/// 不碰界面、不碰 AppState、不联网 —— 抓星历在 AppState 里（见
/// `AppState.syncSatEphemeris()`），这里只管算。
///
/// 精度与口径（写在最前面，免得后来的人把它当成精密历表）：
///   * 只解二体问题，忽略 J2 进动、大气阻力与深空摄动。低轨卫星未来 24 小时
///     的过境窗口误差通常在几分钟量级 —— 用来「约一个过境」够用，用来测控不够；
///   * 时间一律 UTC；
///   * 过境判据是「地平高度 > [minElevationDeg]」，默认 0°（地平线），
///     界面按 5° 显示更接近能听到的高度。
class Tle {
  /// 卫星名字，TLE 第一行原样（已去掉首尾空白）。
  final String name;

  /// 两行原始数据，原样留着：调试、转发、写测试都要看。
  final String line1;
  final String line2;

  final double inclinationDeg;
  final double raanDeg;
  final double eccentricity;
  final double argPerigeeDeg;
  final double meanAnomalyDeg;

  /// 平均运动，圈/天。（`revsPerDay` 是同一个值的别名，读起来顺手。）
  final double meanMotion;

  /// 历元（UTC）。
  final DateTime epoch;

  const Tle({
    required this.name,
    required this.line1,
    required this.line2,
    required this.inclinationDeg,
    required this.raanDeg,
    required this.eccentricity,
    required this.argPerigeeDeg,
    required this.meanAnomalyDeg,
    required this.meanMotion,
    required this.epoch,
  });

  /// 一圈多少分钟。
  double get periodMinutes => meanMotion > 0 ? 1440.0 / meanMotion : 0;

  /// 从 TLE 数据块解析；格式不对返回 null（**不抛**，抓回来的一堆星历里
  /// 总有一两条坏的，不能因为一条坏就整份不用）。
  static Tle? parse(String name, String l1, String l2) {
    if (!l1.startsWith('1 ') || !l2.startsWith('2 ')) return null;
    if (l1.length < 63 || l2.length < 63) return null;
    try {
      final yy = int.parse(l1.substring(18, 20).trim());
      final doy = double.parse(l1.substring(20, 32).trim());
      final year = yy < 57 ? 2000 + yy : 1900 + yy;
      final epoch = DateTime.utc(year).add(
        Duration(microseconds: (doy * 86400 * 1000000).round()),
      );
      final inc = double.parse(l2.substring(8, 16).trim());
      final raan = double.parse(l2.substring(17, 25).trim());
      final ecc = double.parse('0.${l2.substring(26, 33).trim()}');
      final argp = double.parse(l2.substring(34, 42).trim());
      final ma = double.parse(l2.substring(43, 51).trim());
      final mm = double.parse(l2.substring(52, 63).trim());
      if (mm <= 0) return null;
      return Tle(
        name: name.trim(),
        line1: l1,
        line2: l2,
        inclinationDeg: inc,
        raanDeg: raan,
        eccentricity: ecc,
        argPerigeeDeg: argp,
        meanAnomalyDeg: ma,
        meanMotion: mm,
        epoch: epoch,
      );
    } catch (_) {
      return null;
    }
  }

  /// 把一份 TLE 文本（每颗卫星三行：名字 + 两行数据）拆成列表。
  ///
  /// 分隔符统一按空白行切：Celestrak 给的 `gp.php` 与 `CATNR` 两种格式都是
  /// 「名字 / 1 行 / 2 行」三行一组，组间空一行。
  static List<Tle> parseList(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trimRight())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final out = <Tle>[];
    for (var i = 0; i + 2 < lines.length; i++) {
      final n = lines[i];
      final l1 = lines[i + 1];
      final l2 = lines[i + 2];
      if (!l1.startsWith('1 ') || !l2.startsWith('2 ')) continue;
      final t = Tle.parse(n, l1, l2);
      if (t != null) out.add(t);
      i += 2;
    }
    return out;
  }
}

/// 星下点（卫星正下方那一点）。
class SatSubPoint {
  final double lat;
  final double lng;

  /// 高度（km，相对 6371 km 的球）。
  final double altKm;
  const SatSubPoint(this.lat, this.lng, this.altKm);
}

/// 一次过境。
class SatPass {
  /// 上升（地平高度越过 [minElevationDeg]）。
  final DateTime aos;

  /// 最高点。
  final DateTime tca;

  /// 落下。
  final DateTime los;

  /// 最高仰角（度）。
  final double maxElevation;

  const SatPass({
    required this.aos,
    required this.tca,
    required this.los,
    required this.maxElevation,
  });

  Duration get duration => los.difference(aos);
}

const double _mu = 398600.4418; // km^3 / s^2
const double _earthR = 6378.137; // km，WGS84 赤道半径
const double _flat = 1 / 298.257223563;
const double _deg = 180 / math.pi;

/// 格林尼治平恒星时（度）。二体之外唯一必须要的「地球自转」项。
double _gmstDeg(DateTime utc) {
  final jd = _julian(utc);
  final d = jd - 2451545.0;
  final t = d / 36525.0;
  var th = 280.46061837 +
      360.98564736629 * d +
      0.000387933 * t * t -
      t * t * t / 38710000.0;
  th %= 360.0;
  if (th < 0) th += 360.0;
  return th;
}

double _julian(DateTime utc) {
  final u = utc.toUtc();
  final y = u.year;
  final m = u.month;
  final d = u.day +
      (u.hour + u.minute / 60.0 + (u.second + u.millisecond / 1000.0) / 3600.0) /
          24.0;
  var yy = y;
  var mm = m;
  if (mm <= 2) {
    yy -= 1;
    mm += 12;
  }
  final a = (yy / 100).floor();
  final b = 2 - a + (a / 4).floor();
  return (365.25 * (yy + 4716)).floor() +
      (30.6001 * (mm + 1)).floor() +
      d +
      b -
      1524.5;
}

/// 卫星在给定时刻的地心坐标（km，ECEF）。
List<double> _ecef(Tle t, DateTime at) {
  final dt = at.toUtc().difference(t.epoch).inMicroseconds / 1000000.0;
  final n = t.meanMotion * 2 * math.pi / 86400.0; // rad/s
  final a = math.pow(_mu / (n * n), 1 / 3).toDouble();
  final m = t.meanAnomalyDeg / _deg + n * dt;
  final e = t.eccentricity;
  // 解开普勒方程：E - e sinE = M
  var ecc = m;
  for (var i = 0; i < 8; i++) {
    final f = ecc - e * math.sin(ecc) - m;
    final fp = 1 - e * math.cos(ecc);
    final step = f / fp;
    ecc -= step;
    if (step.abs() < 1e-12) break;
  }
  final r = a * (1 - e * math.cos(ecc));
  final nu = 2 *
      math.atan2(
        math.sqrt(1 + e) * math.sin(ecc / 2),
        math.sqrt(1 - e) * math.cos(ecc / 2),
      );
  final u = t.argPerigeeDeg / _deg + nu; // 纬度幅角
  final i = t.inclinationDeg / _deg;
  final om = t.raanDeg / _deg;
  // 近焦点 → 轨道面
  final xp = r * math.cos(u);
  final yp = r * math.sin(u);
  // 轨道面 → 惯性系
  final x = xp * math.cos(om) - yp * math.cos(i) * math.sin(om);
  final y = xp * math.sin(om) + yp * math.cos(i) * math.cos(om);
  final z = yp * math.sin(i);
  // 惯性系 → 地固系（只转经度）
  final th = _gmstDeg(at) / _deg;
  return [
    x * math.cos(th) + y * math.sin(th),
    -x * math.sin(th) + y * math.cos(th),
    z,
  ];
}

/// 星下点。
SatSubPoint subPoint(Tle t, DateTime at) {
  final p = _ecef(t, at);
  final rxy = math.sqrt(p[0] * p[0] + p[1] * p[1]);
  final lat = math.atan2(p[2], rxy) * _deg;
  final lng = math.atan2(p[1], p[0]) * _deg;
  final r = math.sqrt(p[0] * p[0] + p[1] * p[1] + p[2] * p[2]);
  return SatSubPoint(lat, lng, r - _earthR);
}

/// 观测点（经纬度，度）的地固坐标（km）。
List<double> _observer(double latDeg, double lngDeg) {
  final lat = latDeg / _deg;
  final lng = lngDeg / _deg;
  final e2 = _flat * (2 - _flat);
  final n = _earthR / math.sqrt(1 - e2 * math.sin(lat) * math.sin(lat));
  return [
    n * math.cos(lat) * math.cos(lng),
    n * math.cos(lat) * math.sin(lng),
    n * (1 - e2) * math.sin(lat),
  ];
}

/// 卫星在观测点看来的地平高度（度）。负 = 在地平线以下。
double elevationDeg(Tle t, double obsLat, double obsLng, DateTime at) {
  final p = _ecef(t, at);
  final o = _observer(obsLat, obsLng);
  final dx = p[0] - o[0];
  final dy = p[1] - o[1];
  final dz = p[2] - o[2];
  final lat = obsLat / _deg;
  final lng = obsLng / _deg;
  final sinLat = math.sin(lat);
  final cosLat = math.cos(lat);
  final sinLng = math.sin(lng);
  final cosLng = math.cos(lng);
  // 东 / 北 / 天 三个分量
  final east = -sinLng * dx + cosLng * dy;
  final north = -sinLat * cosLng * dx -
      sinLat * sinLng * dy +
      cosLat * dz;
  final up = cosLat * cosLng * dx + cosLat * sinLng * dy + sinLat * dz;
  final range = math.sqrt(east * east + north * north + up * up);
  if (range == 0) return 90;
  return math.asin(up / range) * _deg;
}

/// 下一次过境。没有（[within] 之内一直不出现）返回 null。
///
/// [minElevationDeg] 默认 0：地平线上就算过境开始，界面另按 5° 显示「能听到」。
/// 搜索步长 30 s、找到起点后二分到 1 s、最高点在区间内 10 s 粗扫后二分。
SatPass? nextPass(
  Tle t,
  double obsLat,
  double obsLng, {
  DateTime? from,
  Duration within = const Duration(hours: 24),
  double minElevationDeg = 0,
}) {
  final start = (from ?? DateTime.now()).toUtc();
  final end = start.add(within);
  const step = Duration(seconds: 30);
  double elAt(DateTime x) => elevationDeg(t, obsLat, obsLng, x);

  DateTime? aos;
  var prev = start;
  var prevEl = elAt(start);
  if (prevEl >= minElevationDeg) {
    // 已经在上空：从「上一次越过 minEl」倒着找不稳，这里直接当本次过境开始。
    aos = start;
  }
  var cur = start;
  while (aos == null && cur.isBefore(end)) {
    cur = cur.add(step);
    final e = elAt(cur);
    if (prevEl < minElevationDeg && e >= minElevationDeg) {
      aos = _bisect(t, obsLat, obsLng, prev, cur, minElevationDeg);
      break;
    }
    prev = cur;
    prevEl = e;
  }
  if (aos == null) return null;

  // 落下点
  var los = end;
  var p = aos;
  var pEl = elAt(aos);
  var found = false;
  while (p.isBefore(end)) {
    final q = p.add(step);
    final qEl = elAt(q);
    if (qEl < minElevationDeg) {
      los = _bisect(t, obsLat, obsLng, p, q, minElevationDeg);
      found = true;
      break;
    }
    p = q;
    pEl = qEl;
  }
  if (!found && pEl < minElevationDeg) los = p;

  // 最高点：区间内 10 s 粗扫，取最大再二分加细
  var best = aos;
  var bestEl = elAt(aos);
  var s = aos;
  while (s.isBefore(los)) {
    s = s.add(const Duration(seconds: 10));
    if (s.isAfter(los)) break;
    final e = elAt(s);
    if (e > bestEl) {
      bestEl = e;
      best = s;
    }
  }
  var tca = best;
  var lo = best.subtract(const Duration(seconds: 10));
  var hi = best.add(const Duration(seconds: 10));
  if (lo.isBefore(aos)) lo = aos;
  if (hi.isAfter(los)) hi = los;
  for (var i = 0; i < 6; i++) {
    final m1 = lo.add(Duration(microseconds: hi.difference(lo).inMicroseconds ~/ 3));
    final m2 = hi.subtract(Duration(microseconds: hi.difference(lo).inMicroseconds ~/ 3));
    if (elAt(m1) < elAt(m2)) {
      lo = m1;
      tca = m2;
    } else {
      hi = m2;
      tca = m1;
    }
  }
  bestEl = elAt(tca);
  return SatPass(aos: aos, tca: tca, los: los, maxElevation: bestEl);
}

/// 在 [a]（低于阈值）与 [b]（不低于阈值）之间二分到 1 秒。
DateTime _bisect(
  Tle t,
  double lat,
  double lng,
  DateTime a,
  DateTime b,
  double minEl,
) {
  var lo = a;
  var hi = b;
  for (var i = 0; i < 12; i++) {
    final mid = lo.add(Duration(microseconds: hi.difference(lo).inMicroseconds ~/ 2));
    if (elevationDeg(t, lat, lng, mid) >= minEl) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return hi;
}

/// ─── 过境声明（写进信标备注）───
///
/// 卫星 QSO 时两个人要约的是同一个过境，所以「哪颗星、哪个过境」要能写出去。
/// 单独一个标记，不塞进 `OAF:` 的附加参数：附加参数是自由文本，混进机器字段
/// 以后两边都读不准。
///
///     OAS:IO-117:0234Z       IO-117，02:34 UTC 的过境
///
/// 时间只写 HHMM + `Z`（UTC）：过境是当天的事，日期写进来既长又没必要。
class SatQso {
  /// 卫星名（已归一成 `[A-Z0-9-]`、最多 12 字）。
  final String name;

  /// 过境时间（UTC 的 HHMM，`Z` 在编码时补）。
  final String hhmm;

  const SatQso({required this.name, required this.hhmm});

  static const String mark = 'OAS:';

  /// 从卫星名与一个时刻做出来；名字归一后为空返回 null。
  static SatQso? of(String name, DateTime at) {
    final n = normalizeSatName(name);
    if (n.isEmpty) return null;
    final u = at.toUtc();
    final hh = u.hour.toString().padLeft(2, '0');
    final mm = u.minute.toString().padLeft(2, '0');
    return SatQso(name: n, hhmm: '$hh$mm');
  }

  String encode() => '$mark$name:${hhmm}Z';

  /// `02:34Z` 这样的读法。
  String get label =>
      hhmm.length == 4 ? '${hhmm.substring(0, 2)}:${hhmm.substring(2)}Z' : hhmm;

  static SatQso? decode(String? comment) {
    if (comment == null) return null;
    final i = comment.indexOf(mark);
    if (i < 0) return null;
    final rest = comment.substring(i + mark.length).trim();
    final c = rest.indexOf(':');
    if (c <= 0) return null;
    final name = normalizeSatName(rest.substring(0, c));
    if (name.isEmpty) return null;
    var time = rest.substring(c + 1).trim();
    final sp = time.indexOf(' ');
    if (sp > 0) time = time.substring(0, sp);
    time = time.toUpperCase().replaceAll('Z', '');
    if (!RegExp(r'^\d{4}$').hasMatch(time)) return null;
    final hh = int.parse(time.substring(0, 2));
    final mm = int.parse(time.substring(2));
    if (hh > 23 || mm > 59) return null;
    return SatQso(name: name, hhmm: time);
  }
}

/// 卫星名归一：去掉括号里的注记（`ISS (ZARYA)` → `ISS`）、只留字母数字与横杠、
/// 大写、最多 12 字。备注是有长度上限的，名字不该把频率挤掉。
String normalizeSatName(String raw) {
  var t = raw.trim().toUpperCase();
  final p = t.indexOf('(');
  if (p > 0) t = t.substring(0, p);
  t = t.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
  if (t.length > 12) t = t.substring(0, 12);
  return t;
}
