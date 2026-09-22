import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// ─── 个人历史轨迹（按天保存）───
///
/// 与地图上那条「我的轨迹」（`AppState.myTrack`）**不是一回事**，刻意分开：
///
///   * `myTrack` 只服务**当前这一次**显示：只留最近 `maxTrackPts` 个点、
///     确认位置跳变时会整条清空、退出应用就没了。它的目标是「屏幕上这条线好看」。
///   * 这里是**台账**：按天落盘、退出重进还在，用来回答「我今天走了多少路、
///     最高速度多少、几点到几点在动」。它的目标是「翻账」。
///
/// 所以两者**不共用存取**：把台账挂在 myTrack 上的话，跳变清空与点数上限会
/// 静默吃掉历史（用户看到的症状是「昨天明明走过，今天记录没了」）。
///
/// 落盘策略（三个都要，缺一个就会丢数据或卡帧）：
///   1. **写盘节流**：定位回调可能每秒一次，每次都写盘会让存储抖动。
///      这里攒在内存里，最多每 [_flushInterval] 落一次。
///   2. **跨天切分**：按本地日期分文件；0 点后的第一个点触发「封存昨天 + 开新档」。
///   3. **先写临时文件再改名**：直接覆盖写在进程被杀时会留下半截 JSON，
///      下次读就整天空了。临时文件 + rename 是原子的。
///
/// 读盘一律**容错**：某个文件坏了只丢那一天，不影响其它天（历史是只读展示，
/// 宁可少一天，也不要因为一个坏文件让整个页面打不开）。
class TrackLogPoint {
  final double lat, lng;
  final DateTime time;

  /// 该点的瞬时速度（km/h），原样来自定位（多普勒速度），不做平滑
  final double speedKmh;

  /// 航向（度）；平台没给时为 null
  final double? course;

  /// 海拔（米）；平台没给时为 null
  final double? alt;

  /// 水平精度（米）；<=0 表示平台没给
  final double accuracyM;

  const TrackLogPoint({
    required this.lat,
    required this.lng,
    required this.time,
    this.speedKmh = 0,
    this.course,
    this.alt,
    this.accuracyM = 0,
  });

  Map<String, dynamic> toJson() => {
        't': time.millisecondsSinceEpoch,
        'lat': lat,
        'lng': lng,
        if (speedKmh > 0) 'v': double.parse(speedKmh.toStringAsFixed(2)),
        if (course != null) 'c': course!.round(),
        if (alt != null) 'a': double.parse(alt!.toStringAsFixed(1)),
        if (accuracyM > 0) 'acc': accuracyM.round(),
      };

  static TrackLogPoint? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final t = raw['t'];
    final lat = raw['lat'];
    final lng = raw['lng'];
    if (t is! num || lat is! num || lng is! num) return null;
    return TrackLogPoint(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      time: DateTime.fromMillisecondsSinceEpoch(t.toInt()),
      speedKmh: (raw['v'] as num?)?.toDouble() ?? 0,
      course: (raw['c'] as num?)?.toDouble(),
      alt: (raw['a'] as num?)?.toDouble(),
      accuracyM: (raw['acc'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 一天的历史轨迹 + 由点列算出来的统计量。
///
/// 统计量**每次读都现算**（不落盘）：点数量在一天里最多也就几千，
/// 现算的代价远小于「存了统计量却和点对不上」的风险（比如旧版本写的统计
/// 口径变了，落盘值就成了错的，而且没人会发现）。
class DayTrack {
  /// 本地日期，`YYYY-MM-DD`
  final String day;
  final List<TrackLogPoint> points;

  const DayTrack(this.day, this.points);

  bool get isEmpty => points.isEmpty;
  int get count => points.length;

  DateTime? get startTime => points.isEmpty ? null : points.first.time;
  DateTime? get endTime => points.isEmpty ? null : points.last.time;

  /// 总里程（公里）：相邻点球面距离之和。
  /// 静止时的 GPS 抖动点已经被上游挡在门外（见 [TrackLogStore.record] 的调用点），
  /// 所以这里不需要再做去抖；再平滑一次反而会把真实的短距离抹掉。
  double get distanceKm {
    if (points.length < 2) return 0;
    var sum = 0.0;
    for (var i = 1; i < points.length; i++) {
      sum += haversine(
        points[i - 1].lat,
        points[i - 1].lng,
        points[i].lat,
        points[i].lng,
      );
    }
    return sum;
  }

  double get maxSpeedKmh {
    var m = 0.0;
    for (final p in points) {
      if (p.speedKmh > m) m = p.speedKmh;
    }
    return m;
  }

  /// 移动时长：只累计「这段确实在动」的相邻点间隔。
  ///
  /// 为什么不用「末点 - 首点」：中间停下来吃饭的两小时会被算成移动时长，
  /// 平均速度就被稀释成毫无意义的数字。判据用这一段的平均速度 > 1.5 km/h。
  Duration get movingTime {
    var sec = 0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final dt = b.time.difference(a.time).inSeconds;
      if (dt <= 0 || dt > 3600) continue; // 断档（应用被杀/没信号）不计
      final d = haversine(a.lat, a.lng, b.lat, b.lng); // km
      if (d * 3600 / dt > 1.5) sec += dt;
    }
    return Duration(seconds: sec);
  }

  /// 平均速度（km/h）：总里程 / 移动时长。没有移动时间时为 0。
  double get avgSpeedKmh {
    final h = movingTime.inSeconds / 3600;
    return h <= 0 ? 0 : distanceKm / h;
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'points': points.map((p) => p.toJson()).toList(),
      };

  static DayTrack? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final day = raw['day'];
    if (day is! String || day.isEmpty) return null;
    final list = raw['points'];
    final pts = <TrackLogPoint>[];
    if (list is List) {
      for (final e in list) {
        final p = TrackLogPoint.fromJson(e);
        if (p != null) pts.add(p);
      }
    }
    pts.sort((a, b) => a.time.compareTo(b.time));
    return DayTrack(day, pts);
  }
}

/// 按天保存的历史轨迹仓库。全局单例，由 `main()` 初始化目录。
class TrackLogStore {
  TrackLogStore._();
  static final TrackLogStore instance = TrackLogStore._();

  /// 落盘节流：最密每 8 秒写一次（定位回调约 1Hz，攒 8 个点写一次足够）
  static const Duration _flushInterval = Duration(seconds: 8);

  /// 单天点数上限：防止某个异常进程一天写爆存储。
  /// 1Hz × 24h = 86400，取 40000 仍然富余（10 秒一个点也能存 4.6 天）。
  static const int maxPointsPerDay = 40000;

  Directory? _dir;
  bool get available => _dir != null;

  DayTrack? _today;
  DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _pending;

  static String dayKey(DateTime t) {
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '${t.year}-$m-$d';
  }

  /// 初始化存储目录；失败不抛错（历史功能只是不可用，不能拖垮启动）。
  Future<void> ensureInit() async {
    if (_dir != null) return;
    try {
      final base = await getApplicationSupportDirectory();
      final d = Directory('${base.path}${Platform.pathSeparator}tracklog');
      if (!await d.exists()) await d.create(recursive: true);
      _dir = d;
    } catch (_) {
      _dir = null;
    }
  }

  File? _fileFor(String day) {
    final d = _dir;
    if (d == null) return null;
    return File('${d.path}${Platform.pathSeparator}$day.json');
  }

  /// 记录一个点。非阻塞：只做内存追加 + 必要时触发一次异步落盘。
  void record({
    required double lat,
    required double lng,
    required double speedKmh,
    double? course,
    double? alt,
    double accuracyM = 0,
  }) {
    if (!available) return;
    final now = DateTime.now();
    final key = dayKey(now);
    // 跨天：先把昨天封存（异步），再开新档
    if (_today != null && _today!.day != key) {
      unawaited(flush());
      _today = DayTrack(key, <TrackLogPoint>[]);
      _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);
    }
    final day = _today ??= DayTrack(key, <TrackLogPoint>[]);
    if (day.points.length >= maxPointsPerDay) return;
    final p = TrackLogPoint(
      lat: lat,
      lng: lng,
      time: now,
      speedKmh: speedKmh,
      course: course,
      alt: alt,
      accuracyM: accuracyM,
    );
    // 与上一个点的间隔 < 1 秒且没挪动时合并（定位偶发重复回调）
    if (day.points.isNotEmpty) {
      final last = day.points.last;
      final dt = now.difference(last.time).inMilliseconds;
      if (dt < 900 &&
          haversine(last.lat, last.lng, lat, lng) * 1000 < 3) {
        return;
      }
    }
    day.points.add(p);
    if (now.difference(_lastFlush) >= _flushInterval) {
      unawaited(flush());
    }
  }

  /// 把当前内存里那一天写盘（先写临时文件再原子改名）。
  Future<void> flush() async {
    final day = _today;
    if (day == null || !available) return;
    final prev = _pending;
    final task = () async {
      if (prev != null) await prev;
      final f = _fileFor(day.day);
      if (f == null) return;
      try {
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(jsonEncode(day.toJson()), flush: true);
        await tmp.rename(f.path);
        _lastFlush = DateTime.now();
      } catch (_) {
        // 写盘失败不影响内存里的这份；下一次 flush 会再试
      }
    }();
    _pending = task;
    await task;
  }

  /// 读取全部天的历史（不含内存里尚未落盘的今天之外的改动），按日期倒序。
  ///
  /// 会先把内存里的今天落盘再读，避免「刚记的点在页面里看不到」。
  Future<List<DayTrack>> loadAll() async {
    await flush();
    final d = _dir;
    if (d == null) {
      final t = _today;
      return t == null || t.isEmpty ? const [] : [t];
    }
    final out = <DayTrack>[];
    try {
      if (!await d.exists()) return const [];
      await for (final e in d.list()) {
        if (e is! File || !e.path.endsWith('.json')) continue;
        try {
          final raw = jsonDecode(await e.readAsString());
          final day = DayTrack.fromJson(raw);
          if (day != null) out.add(day);
        } catch (_) {
          // 单个坏文件只丢这一天
        }
      }
    } catch (_) {}
    out.sort((a, b) => b.day.compareTo(a.day));
    return out;
  }

  /// 删除某一天
  Future<void> deleteDay(String day) async {
    if (_today?.day == day) _today = null;
    final f = _fileFor(day);
    if (f == null) return;
    try {
      if (await f.exists()) await f.delete();
      final tmp = File('${f.path}.tmp');
      if (await tmp.exists()) await tmp.delete();
    } catch (_) {}
  }

  /// 清空全部历史
  Future<void> clearAll() async {
    _today = null;
    final d = _dir;
    if (d == null) return;
    try {
      if (!await d.exists()) return;
      await for (final e in d.list()) {
        if (e is File) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}

/// 里程 → 人类可读：1 km 以下用米（「800 m」比「0.8 km」好读）
String fmtKm(double km) {
  if (km <= 0) return '0 m';
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(km >= 100 ? 0 : 1)} km';
}

/// 时长 → 人类可读：有小时就给 `2h 13m`，否则 `13m` / `42s`
String fmtDur(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m';
  return '${d.inSeconds}s';
}
