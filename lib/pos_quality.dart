import 'dart:math' as math;

import 'models.dart';

/// ─── 位置质量层（打点算法）───
///
/// 台站位置来自三个来源（APRS-IS / TNC / 音频解码），它们共用同一条
/// `_onAprsLine` 管线；同一次发射还会经多条路径重复到达。原始坐标因此既有
/// **重复**、**乱序**，也有**物理上不可能**的点。以前 `_upsertStation` 是
/// 「收到就覆盖、位移 20m 就记一笔」，于是看到的是：
///
///   * 同一帧经 IS + 射频各来一次 → 轨迹里同一处点两遍；
///   * 迟到的旧帧把台站拉回几百米外 → 轨迹折返；
///   * 一个错包让台站瞬移几十公里 → 地图上一条横跨城市的假线；
///   * 模糊位置（只报到 1′ / 10′）被当成精确点 → 看着很准，其实差几公里。
///
/// 这一层把这四件事逐个挡掉，并且**把不确定度如实画出来** ——
/// 一个诚实标着 ±13km 的点，比一个假装精确的点有用得多。
///
/// 设计原则（都是踩过坑换来的）：
///   * 只挡「物理不可能」，不挡「看起来奇怪」—— 误杀真实移动比放过一个错点更糟；
///   * 门槛全部**按速度自适应**，不用固定米数（固定 20m 在步行时太粗、高速时太细）；
///   * 判不准的时候**保留旧位置**而不是跳到新位置：位置错一半比不动更误导；
///   * 平滑只允许在 [smoothForDraw] 的位移上限内挪点，绝不抹平真实急弯。
class PosQuality {
  PosQuality._();

  // ─────────────────────────── ① 位置模糊度 ───────────────────────────

  /// 模糊 n 位表示上报方只把位置填到第 n 档（更低的位是空格）。
  /// 分辨率（纬度）：n=1 → 0.1′ ≈ 185m，n=2 → 1′ ≈ 1.85km，
  /// n=3 → 10′ ≈ 18.5km，n=4 → 60′ ≈ 111km。
  /// 1′ 纬度 = 1852m；经度方向要乘 cos(lat)。
  static const List<double> _ambSideMin = [0, 0.1, 1, 10, 60];

  /// 模糊方格边长（角分）
  static double ambiguousSideMinutes(int amb) =>
      _ambSideMin[amb.clamp(0, 4).toInt()];

  /// 位置不确定半径（米）：取模糊方格的**半对角**。
  ///
  /// 用半对角而不是半边长：格心点到最坏角点的距离就是半对角，
  /// 这是「保证覆盖」的半径（误报一点总比漏掉真实位置好）。
  static double ambiguityRadiusM(int amb, {double lat = 0}) {
    if (amb <= 0) return 0;
    final sideMin = ambiguousSideMinutes(amb);
    final sideLatM = sideMin * 1852.0;
    final sideLngM = sideLatM * math.cos(lat * math.pi / 180).abs();
    return math.sqrt(sideLatM * sideLatM + sideLngM * sideLngM) / 2;
  }

  // ─────────────────────────── ② 报文去重 ───────────────────────────

  /// 指纹窗口（毫秒）。
  ///
  /// 取 20s：APRS 的重复判定惯例是 30s，但**静止台站本来就每 30~60 秒发一次
  /// 完全相同的内容**——那不是重复，只是照常刷新「听到」。窗口取小一点，
  /// 才能既挡住真正的多路径重复，又不影响「照常刷新」。
  static const int dedupeWindowMs = 20000;

  /// 报文正文（剥掉报头与转发路径）。
  ///
  /// 去重指纹必须**不含路径**：同一帧经 APRS-IS 与射频各来一次时，
  /// 路径段不同、正文完全相同 —— 按整行去重会一点都去不掉。
  /// PKWDWPL 的 NMEA 语句没有 `:`，返回空串（调用方据此跳过去重）。
  static String bodyOf(String raw) {
    final i = raw.indexOf(':');
    return i < 0 ? '' : raw.substring(i + 1).trim();
  }

  /// 指纹去重：返回 true 表示「这是新报文，可以打点」。
  ///
  /// [table] 由调用方持有（key → 上次见到的时间戳毫秒）。
  static bool dedupe(Map<String, int> table, String key, int nowMs) {
    final last = table[key];
    // 顺手清理过期条目，避免台站数很多时这张表无界增长
    if (table.length > 4000) {
      table.removeWhere((_, t) => nowMs - t > dedupeWindowMs * 4);
    }
    table[key] = nowMs;
    return last == null || nowMs - last > dedupeWindowMs;
  }

  // ─────────────────────── ③ 速度门控（物理不可能）───────────────────────

  /// 空中/高速台站符号（主表）：飞机、直升机、气球、卫星、航天器。
  /// 这些必须给极高的上限，否则每一帧都会被判「物理不可能」。
  static const Map<String, double> _fastSymbols = {
    '^': 2000, // 大型飞机
    'X': 2000, // 直升机
    'O': 2000, // 气球
    'S': 2000, // 卫星（ISS 常用）
    'P': 2000, // 航天器
  };

  /// 慢速台站符号：步行 / 自行车 / 固定台。
  /// 给它们较低的上限，可以挡住「步行台站瞬移几公里」这类错包。
  static const Map<String, double> _slowSymbols = {
    '[': 15, // 步行
    'b': 30, // 自行车
    'p': 30, // 宠物/慢速
    's': 20, // 其它慢速
    '-': 15, // 室内固定（HF）
    'U': 100, // 公交
  };

  /// 该类台站不可能超过的地速（km/h）。
  ///
  /// 报文自带速度时以它为准并放宽 40% + 40km/h —— 有人用汽车符号跑高铁、
  /// 也有人用便携设备上天。宁松勿紧：漏掉一个错点的代价，远小于把真实
  /// 高速台站永久冻在地图上。
  static double maxSpeedKmh(String symbol, String symbolTable,
      {double? declaredKmh}) {
    double v = 250; // 未识别符号的默认上限（民用地面移动）
    // 下面两张表只对**主符号表**成立：反斜杠表里同一个字符含义完全不同
    // （例如主表 'S' 是卫星，反斜杠表另有定义），套用会误判整类台站。
    if (symbolTable != '\\') {
      if (_fastSymbols.containsKey(symbol)) {
        v = _fastSymbols[symbol]!;
      } else if (_slowSymbols.containsKey(symbol)) {
        v = _slowSymbols[symbol]!;
      }
    }
    final d = declaredKmh;
    if (d != null && d > 0) {
      final relaxed = d * 1.4 + 40;
      if (relaxed > v) v = relaxed;
    }
    return v;
  }

  // ─────────────────────── ④ 轨迹抽稀（按速度自适应）───────────────────────

  /// 记轨迹点的最小位移（米）。
  ///
  /// 固定 20m 的问题：步行时点太稀（丢细节），高速时又太密（GPS 抖动
  /// 变成锯齿，还白占 maxTrackPts）。改成「一个采样周期内走过距离的 35%」：
  /// 步行 → 下限 15m（低于 GPS 噪声没意义），汽车 60km/h → ≈58m，
  /// 飞机 → 上限 250m（这个尺度上逐点画没有意义）。
  static double trackMinDistM({double? speedKmh, double dtSec = 10}) {
    final v = (speedKmh ?? 0).clamp(0.0, 400.0);
    final dt = dtSec.clamp(1.0, 300.0);
    final travel = v * 1000 / 3600 * dt;
    return (travel * 0.35).clamp(15.0, 250.0);
  }

  // ─────────────────────── ⑤ 轨迹平滑（仅绘制用）───────────────────────

  /// 三点加权平均（1-2-1）平滑轨迹，**只用于绘制，不改真实数据**。
  ///
  /// 关键是每个点最多挪 [maxShiftM] 米：GPS 抖动只有十几米，会被抹掉；
  /// 真实的急弯在几十米尺度上，挪不动它 —— 不会出现「平滑把立交抹成直线」。
  static List<TrackPt> smoothForDraw(List<TrackPt> pts,
      {double maxShiftM = 25}) {
    if (pts.length < 3 || maxShiftM <= 0) return pts;
    final out = <TrackPt>[pts.first];
    for (var i = 1; i < pts.length - 1; i++) {
      final a = pts[i - 1], b = pts[i], c = pts[i + 1];
      final lat = (a.lat + 2 * b.lat + c.lat) / 4;
      final lng = (a.lng + 2 * b.lng + c.lng) / 4;
      final dM = haversine(b.lat, b.lng, lat, lng) * 1000;
      if (dM <= maxShiftM) {
        out.add(TrackPt(lat, lng, b.time));
      } else {
        // 挪过头就按比例截断，保证位移不超过上限
        final t = maxShiftM / dM;
        out.add(TrackPt(
          b.lat + (lat - b.lat) * t,
          b.lng + (lng - b.lng) * t,
          b.time,
        ));
      }
    }
    out.add(pts.last);
    return out;
  }

  // ─────────────────────── ⑥ 推测定位（coasting）───────────────────────

  /// 推测定位：移动台站安静下来后，按最后的速度/航向外推现在大概在哪，
  /// 并把不确定圈随时间放大。
  ///
  /// 只外推 [maxAgeSec] 以内、且**当前仍算在线**的台站：离线台站的推测
  /// 位置只会比最后已知点更误导（用户会以为它还在跑）。
  /// 速度 < 3km/h 视为静止，没有外推价值，返回 null（此时应该看最后已知点）。
  static CoastFix? coastOf(Station s,
      {DateTime? now, double maxAgeSec = 900, double maxDistanceKm = 20}) {
    final t = now ?? DateTime.now();
    final age = t.difference(s.lastHeard).inSeconds.toDouble();
    if (age <= 60 || age > maxAgeSec) return null;
    if (s.effectiveStatus == St.offline) return null;
    final sp = s.speed, co = s.course;
    if (sp == null || co == null || sp < 3) return null;
    final distKm = math.min(sp * age / 3600.0, maxDistanceKm);
    final rad = co * math.pi / 180;
    final dLat = distKm / 111.32;
    final cosLat = math.cos(s.lat * math.pi / 180).abs().clamp(0.02, 1.0);
    final dLng = distKm / (111.32 * cosLat);
    // 不确定度 = 已有的模糊圈 + 已走路程的 25% + 每分钟 30m 的时间项
    // （上限 10km：再大就只是「不知道在哪」，画出来没有信息量）
    final unc = ambiguityRadiusM(s.ambiguity, lat: s.lat) +
        distKm * 1000 * 0.25 +
        math.min(age / 60.0 * 30.0, 10000.0);
    return CoastFix(
      lat: s.lat + dLat * math.cos(rad),
      lng: s.lng + dLng * math.sin(rad),
      ageSec: age,
      uncertaintyM: unc,
    );
  }
}

/// 推测定位结果：推测位置 + 已推测时长 + 不确定半径（米）
class CoastFix {
  final double lat, lng, ageSec, uncertaintyM;
  const CoastFix({
    required this.lat,
    required this.lng,
    required this.ageSec,
    required this.uncertaintyM,
  });
}

/// 单台站的打点门控状态。
///
/// 「物理不可能」不能一次就否决：错包是一次性的，而**真实的高速台站
/// （飞机、卫星）每一个点看起来都「物理不可能」** —— 如果按单点否决，
/// ISS 会被永久冻在地图角落。所以规则是：
///
///   * 单点可疑 → 先相信旧位置（不动标记、不记轨迹）；
///   * 连续 [need] 个点都物理不可能 → 说明参考点已经过时了，
///     接受新位置并**清空轨迹从新位置重画**（不画横跨两地的假线）；
///   * 只要有一个点落回合理范围 → 计数清零，一次性的错包就这样被吃掉。
enum FixVerdict { accept, hold, confirmedMove }

class FixGate {
  DateTime? _lastSeen;
  int _suspicious = 0;

  FixVerdict evaluate({
    required double lat,
    required double lng,
    required double prevLat,
    required double prevLng,
    required DateTime now,
    required double vmaxKmh,
    bool free = false,
    int need = 3,
  }) {
    final last = _lastSeen;
    _lastSeen = now;
    if (free || last == null) {
      _suspicious = 0;
      return FixVerdict.accept;
    }
    final dtH = now.difference(last).inSeconds / 3600.0;
    // 空档超过 30 分钟：中间本来就没数据，多大的位移都可能是真的
    if (dtH <= 0 || dtH > 0.5) {
      _suspicious = 0;
      return FixVerdict.accept;
    }
    final dKm = haversine(prevLat, prevLng, lat, lng);
    // 1km 以内不判：这是 GPS 抖动与位置微调的地盘
    if (dKm < 1.0) {
      _suspicious = 0;
      return FixVerdict.accept;
    }
    // 容差 1.5 倍 + 500m：速度字段取整、转发延迟都会吃掉一点余量
    if (dKm <= vmaxKmh * dtH * 1.5 + 0.5) {
      _suspicious = 0;
      return FixVerdict.accept;
    }
    _suspicious++;
    if (_suspicious >= need) {
      _suspicious = 0;
      return FixVerdict.confirmedMove;
    }
    return FixVerdict.hold;
  }

  /// 台站被移除/清空时复位，避免 next 复用时带着旧状态
  void reset() {
    _lastSeen = null;
    _suspicious = 0;
  }
}
