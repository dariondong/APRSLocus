import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'map_math.dart';
import 'tile_cache.dart';
import 'net/http_send.dart';

/// ─── 离线地图：区域模型 / 持久化 / 下载引擎（无 Widget，可单测）───
///
/// 三块职责分开写，因为它们各自有独立的坑：
///
/// * [OfflineRegion] —— **元数据与瓦片分家**。区域记录很小（KB 级）存
///   SharedPreferences；瓦片是几十 MB 的二进制，只存文件系统。若把瓦片
///   塞进 prefs，一开始能用，攒到几百 MB 时会以「读设置变慢」的形式
///   慢慢表现出来，最后写不进去直接丢新记录。
///
/// * [OfflineMapStore] —— 记录的增删改查 + 进度落盘。落盘必须**节流**：
///   一张瓦片写一次 prefs，等于在一次下载里做几万次磁盘写 + JSON 编码。
///
/// * [OfflineDownloader] —— 真正的下载。三条约束缺一不可：
///     ① 并发上限（6）+ 速率限制（20 张/秒）：别把图源当自己的服务器用；
///     ② 暂停/取消要在**每个瓦片之间**生效，否则点了取消还得等几百张；
///     ③ 断点续传靠「已存在就跳过」，所以任何时刻中断都能接着下。

/// 区域状态
enum OfflineStatus { pending, running, paused, done, canceled, failed }

extension OfflineStatusX on OfflineStatus {
  String get key => name;

  bool get active => this == OfflineStatus.running || this == OfflineStatus.paused;

  /// 未完成、且可以继续下载
  bool get resumable =>
      this == OfflineStatus.pending ||
      this == OfflineStatus.paused ||
      this == OfflineStatus.canceled ||
      this == OfflineStatus.failed;

  static OfflineStatus parse(String s) => OfflineStatus.values.firstWhere(
        (e) => e.name == s,
        orElse: () => OfflineStatus.pending,
      );
}

/// 一个离线区域（下载范围 + 进度）
class OfflineRegion {
  final String id;
  String name;

  /// 图源名（MapType.name；存名字不存序号 —— 将来在图源列表中间插入一项
  /// 也不会让老用户的记录指向错误的图源）
  final String mapType;

  /// WGS-84 经纬范围
  final GeoBounds bounds;

  final int minZoom, maxZoom;
  final DateTime createdAt;

  /// 最近一次下载动作的时间（用于界面排序/显示）
  DateTime updatedAt;

  /// 本次/历次累计的进度
  int total;
  int done;
  int bytes;
  int failed;

  /// 最近一次失败原因（界面提示用，不参与逻辑）
  String error;

  OfflineStatus status;

  OfflineRegion({
    required this.id,
    required this.name,
    required this.mapType,
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.total = 0,
    this.done = 0,
    this.bytes = 0,
    this.failed = 0,
    this.error = '',
    this.status = OfflineStatus.pending,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  MapType get type => mapTypeByName(mapType);

  /// 瓦片编号所用的坐标范围：国内图源（高德/腾讯）是 GCJ-02 瓦片，
  /// 用 WGS-84 的范围去算编号会整体偏移（>500 m），下回来的图与地图对不上。
  GeoBounds get tileSpaceBounds =>
      isGcjMapType(type) ? bounds.toGcj() : bounds;

  /// 该区域需要下载的瓦片张数
  int get tileCount => countTilesIn(tileSpaceBounds, minZoom, maxZoom);

  /// 进度 0..1
  double get progress => total <= 0 ? 0 : (done / total).clamp(0.0, 1.0);

  /// 已占用/预计占用字节
  int get sizeBytes =>
      bytes > 0 ? bytes : (total > 0 ? total : tileCount) * kTileBytesEstimate;

  bool get finished => status == OfflineStatus.done;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mapType': mapType,
        'bounds': bounds.toJson(),
        'minZoom': minZoom,
        'maxZoom': maxZoom,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'total': total,
        'done': done,
        'bytes': bytes,
        'failed': failed,
        'error': error,
        'status': status.name,
      };

  static OfflineRegion fromJson(Map<String, dynamic> j) {
    final status = OfflineStatusX.parse('${j['status']}');
    return OfflineRegion(
      id: '${j['id']}',
      name: '${j['name']}',
      mapType: '${j['mapType']}',
      bounds: GeoBounds.fromJson((j['bounds'] as Map).cast<String, dynamic>()),
      minZoom: (j['minZoom'] as num).toInt(),
      maxZoom: (j['maxZoom'] as num).toInt(),
      createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${j['updatedAt']}') ?? DateTime.now(),
      total: (j['total'] as num?)?.toInt() ?? 0,
      done: (j['done'] as num?)?.toInt() ?? 0,
      bytes: (j['bytes'] as num?)?.toInt() ?? 0,
      failed: (j['failed'] as num?)?.toInt() ?? 0,
      error: '${j['error'] ?? ''}',
      // 应用被杀掉时状态会停在 running；重启后它其实没在跑，
      // 显示「下载中」会让用户一直等一个不存在的任务 → 回落成「已暂停」
      status: status == OfflineStatus.running ? OfflineStatus.paused : status,
    );
  }
}

/// 区域记录存储
class OfflineMapStore extends ChangeNotifier {
  /// SharedPreferences 键。**新增/改名必须同步 backup.dart 的 settings 分组**
  /// （tool/check_backup_keys.py 会拦下漏登记）。
  static const String kRegionsKey = 'offlineRegions';

  static final OfflineMapStore instance = OfflineMapStore();

  List<OfflineRegion> _regions = [];
  bool _loaded = false;
  Future<void>? _loading;
  Timer? _saveTimer;

  List<OfflineRegion> get regions => List.unmodifiable(_regions);

  bool get loaded => _loaded;

  /// 供外部（下载进度）触发界面刷新
  void touch() => notifyListeners();

  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    final pending = _loading;
    if (pending != null) return pending;
    _loading = _doLoad();
    await _loading;
    _loading = null;
  }

  Future<void> _doLoad() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(kRegionsKey);
      if (raw == null || raw.isEmpty) {
        _regions = [];
      } else {
        final list = (jsonDecode(raw) as List).cast<Map>();
        _regions = list
            .map((e) => OfflineRegion.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {
      // 记录坏了不能让整个离线功能废掉：当作没有记录，用户可以重新下载
      _regions = [];
    }
    // 新记录排在前面
    _regions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _loaded = true;
    notifyListeners();
  }

  OfflineRegion? byId(String id) {
    for (final r in _regions) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// 落盘（节流：下载途中每张瓦片都写一次会把 IO 打满）
  void saveDebounced() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      save();
    });
  }

  Future<void> save() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        kRegionsKey,
        jsonEncode(_regions.map((r) => r.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> add(OfflineRegion r) async {
    _regions.insert(0, r);
    notifyListeners();
    await save();
  }

  Future<void> remove(String id) async {
    _regions.removeWhere((r) => r.id == id);
    notifyListeners();
    await save();
  }

  /// 累计统计（界面顶部展示）
  (int, int) get totals {
    var tiles = 0;
    var bytes = 0;
    for (final r in _regions) {
      tiles += r.done;
      bytes += r.bytes;
    }
    return (tiles, bytes);
  }
}

/// 生成区域 id（时间戳 + 随机后缀，避免同一秒内两次创建撞号）
String newOfflineRegionId() =>
    '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
    '-${math.Random().nextInt(1 << 20).toRadixString(36)}';

/// 下载并发上限
const int kOfflineConcurrency = 6;

/// 每秒最多请求的瓦片数（含重试）。太高的速率会被图源限流甚至封禁，
/// 而限流后的重试又会让速率更高 —— 这是个正反馈，必须从源头掐住。
const double kOfflineTilesPerSecond = 20;

/// 低于该体积的响应视为「占位图/错误图」，不入库也不计成功。
///
/// 有的图源对不存在的瓦片返回一张很小的全透明 PNG，看着成功、
/// 实际是空白；这种瓦片混进离线包之后，用户会以为「地图下坏了」。
///
/// 阈值取 300 而不是更高：低层级的海洋/荒漠瓦片本身就是压缩得很小的
/// 合法图片（实测 300–600 B），阈值定高了会把它们整片误判成失败，
/// 反而在界面上显示一个吓人的失败数。
const int kMinTileBytes = 300;

/// 批量删除瓦片时的并发
const int kDeleteConcurrency = 16;

/// 令牌桶限速
class _RateLimiter {
  _RateLimiter(this.rps, {double? burst}) : _tokens = burst ?? rps;

  final double rps;
  double _tokens;
  DateTime _last = DateTime.now();

  Future<void> acquire() async {
    while (true) {
      final now = DateTime.now();
      final dt = now.difference(_last).inMicroseconds / 1e6;
      _last = now;
      _tokens = math.min(rps, _tokens + dt * rps);
      if (_tokens >= 1) {
        _tokens -= 1;
        return;
      }
      final waitMs = ((1 - _tokens) / rps * 1000).ceil();
      await Future.delayed(Duration(milliseconds: waitMs.clamp(5, 500)));
    }
  }
}

/// 信号量（并发上限）
class _Semaphore {
  _Semaphore(this._free);

  int _free;
  final List<Completer<void>> _waiters = [];

  Future<void> acquire() {
    if (_free > 0) {
      _free--;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else {
      _free++;
    }
  }
}

class _Task {
  _Task(this.region);

  final OfflineRegion region;
  final _RateLimiter rate = _RateLimiter(kOfflineTilesPerSecond);
  bool paused = false;
  bool canceled = false;
  int failStreak = 0;
  Completer<void>? _resumeGate;
  Timer? notifyTimer;
  Timer? saveTimer;

  Future<void> gate() {
    if (!paused) return Future.value();
    _resumeGate ??= Completer<void>();
    return _resumeGate!.future;
  }

  void pause() {
    if (canceled) return;
    paused = true;
  }

  void resume() {
    paused = false;
    final g = _resumeGate;
    _resumeGate = null;
    if (g != null && !g.isCompleted) g.complete();
  }

  void cancel() {
    canceled = true;
    resume();
  }

  void disposeTimers() {
    notifyTimer?.cancel();
    notifyTimer = null;
    saveTimer?.cancel();
    saveTimer = null;
  }
}

/// 离线下载引擎（单任务：同时只跑一个区域的下载）
///
/// 为什么是单任务而不是多任务队列：瓦片下载的瓶颈在共享的图源与带宽，
/// 并行下载多个区域只会让每个区域都变慢，还会让「暂停」的语义变得含糊
/// （暂停哪一个？界面上得画两套进度）。单任务 + 断点续传已经够用。
class OfflineDownloader extends ChangeNotifier {
  static final OfflineDownloader instance = OfflineDownloader._();

  OfflineDownloader._();

  _Task? _task;

  OfflineRegion? get active => _task?.region;

  bool get busy => _task != null;

  bool get paused => _task?.paused ?? false;

  bool get canceling => _task?.canceled ?? false;

  /// 启动一个区域的下载。已有任务在跑时返回 false（界面提示先等/取消）。
  bool start(OfflineRegion r) {
    if (_task != null) return false;
    final t = _Task(r);
    _task = t;
    notifyListeners();
    unawaited(_run(t));
    return true;
  }

  void pause() {
    final t = _task;
    if (t == null || t.paused || t.canceled) return;
    t.pause();
    t.region.status = OfflineStatus.paused;
    t.region.updatedAt = DateTime.now();
    OfflineMapStore.instance.touch();
    OfflineMapStore.instance.saveDebounced();
    notifyListeners();
  }

  void resume() {
    final t = _task;
    if (t == null || !t.paused) return;
    t.resume();
    t.region.status = OfflineStatus.running;
    OfflineMapStore.instance.touch();
    notifyListeners();
  }

  void cancel() {
    final t = _task;
    if (t == null) return;
    t.cancel();
    t.region.status = OfflineStatus.canceled;
    t.region.updatedAt = DateTime.now();
    OfflineMapStore.instance.touch();
    OfflineMapStore.instance.saveDebounced();
    notifyListeners();
  }

  void _bumpNotify(_Task t) {
    if (t.notifyTimer?.isActive ?? false) return;
    t.notifyTimer = Timer(const Duration(milliseconds: 150), () {
      if (t.canceled) return;
      OfflineMapStore.instance.touch();
      notifyListeners();
    });
    if (t.saveTimer?.isActive ?? false) return;
    t.saveTimer = Timer(const Duration(seconds: 3), () {
      OfflineMapStore.instance.save();
    });
  }

  Future<void> _run(_Task t) async {
    final r = t.region;
    final store = OfflineMapStore.instance;
    r.status = OfflineStatus.running;
    r.error = '';
    r.total = r.tileCount;
    r.done = 0;
    r.bytes = 0;
    r.failed = 0;
    r.updatedAt = DateTime.now();
    store.touch();
    notifyListeners();

    final sem = _Semaphore(kOfflineConcurrency);
    final inflight = <Future<void>>[];

    Future<void> drain() async {
      if (inflight.length < kOfflineConcurrency * 2) return;
      final batch = inflight.sublist(0, kOfflineConcurrency);
      inflight.removeRange(0, kOfflineConcurrency);
      await Future.wait(batch);
    }

    Future<void> one(int z, int x, int y) async {
      if (t.canceled) return;
      if (TileCache.available &&
          await TileCache.get(r.mapType, z, x, y) != null) {
        r.done++;
        _bumpNotify(t);
        return;
      }
      if (t.canceled) return;
      final url = tileUrl(r.type, x, y, z);
      if (url.isEmpty) {
        r.failed++;
        return;
      }
      await t.rate.acquire();
      if (t.canceled) return;
      try {
        final bytes = await httpGetBytes(
          Uri.parse(url),
          headers: tileHeaders,
          timeout: const Duration(seconds: 20),
        );
        if (t.canceled) return;
        if (bytes.length < kMinTileBytes || !looksLikeImage(bytes)) {
          r.failed++;
          return;
        }
        final ok = await TileCache.put(r.mapType, z, x, y, bytes);
        if (!ok) {
          r.failed++;
          return;
        }
        t.failStreak = 0;
        r.done++;
        r.bytes += bytes.length;
        _bumpNotify(t);
      } on HttpStatusError catch (e) {
        t.failStreak++;
        if (e.status == 429 || e.status == 503) {
          // 被限流：退避（上限 30s），让限速桶重新攒回余量
          final ms = math.min(30000, 1500 * t.failStreak * t.failStreak);
          await Future.delayed(Duration(milliseconds: ms));
        }
        r.failed++;
        _bumpNotify(t);
      } catch (e) {
        t.failStreak++;
        if (t.failStreak >= 12) {
          // 连续失败说明网络/图源整体不可用，继续跑只会把剩余瓦片全标成失败
          r.error = 'network';
        }
        r.failed++;
        _bumpNotify(t);
      }
    }

    try {
      final tb = r.tileSpaceBounds;
      outer:
      for (var z = r.minZoom; z <= r.maxZoom; z++) {
        final n = 1 << z;
        final rng = tileRange(tb, z);
        for (var y = rng.y0; y <= rng.y1; y++) {
          for (var x = rng.x0; x <= rng.x1; x++) {
            if (t.canceled) break outer;
            final wx = ((x % n) + n) % n;
            await t.gate();
            if (t.canceled) break outer;
            await drain();
            await sem.acquire();
            inflight.add(one(z, wx, y).whenComplete(sem.release));
          }
        }
      }
      await Future.wait(inflight);
    } catch (e) {
      r.error = '$e';
    } finally {
      t.disposeTimers();
      if (t.canceled) {
        r.status = OfflineStatus.canceled;
      } else if (r.failed > 0 && r.done == 0) {
        r.status = OfflineStatus.failed;
      } else {
        r.status = OfflineStatus.done;
      }
      r.updatedAt = DateTime.now();
      _task = null;
      await store.save();
      store.touch();
      notifyListeners();
    }
  }

  /// 删除某个区域已下载的瓦片（记录可另行保留）
  ///
  /// 只删该区域范围内的瓦片，而不是整层目录 —— 后者会顺手删掉邻居区域
  /// 的缓存，属于「删一个区域，坏另一个区域」的隐形破坏。
  Future<void> deleteTiles(OfflineRegion r,
      {void Function(int done, int total)? onProgress}) async {
    if (!TileCache.available) return;
    final tb = r.tileSpaceBounds;
    final total = r.tileCount;
    var done = 0;
    final pending = <Future<void>>[];
    Future<void> flush() async {
      if (pending.length < kDeleteConcurrency * 2) return;
      final batch = pending.sublist(0, kDeleteConcurrency);
      pending.removeRange(0, kDeleteConcurrency);
      await Future.wait(batch);
    }

    for (var z = r.minZoom; z <= r.maxZoom; z++) {
      final n = 1 << z;
      final rng = tileRange(tb, z);
      for (var y = rng.y0; y <= rng.y1; y++) {
        for (var x = rng.x0; x <= rng.x1; x++) {
          final wx = ((x % n) + n) % n;
          pending.add(TileCache.remove(r.mapType, z, wx, y));
          await flush();
          done++;
          if (done % 200 == 0) {
            onProgress?.call(done, total);
            await Future.delayed(Duration.zero);
          }
        }
      }
    }
    await Future.wait(pending);
    onProgress?.call(total, total);
    r.bytes = 0;
    r.done = 0;
    r.total = total;
    r.status = OfflineStatus.pending;
    r.updatedAt = DateTime.now();
  }
}
