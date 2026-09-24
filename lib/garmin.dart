import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'garmin_fetch_io.dart'
    if (dart.library.html) 'garmin_fetch_web.dart' as fetch;

/// 由前后两个点算**初始方位角**（度，0~360）。
///
/// 为什么必须自己算：佳明 LiveTrack 的点里**没有航向字段**（只有经纬度/海拔/
/// 速度/心率），而 APRS 位置包的 `ddd/sss` 与界面上的航向都靠 `myCourse`。
/// 不补这一项的话，佳明接管期间航向会**沿用手机 GPS 的旧值** —— 指南针上停在上次
/// 的方向不动，比不显示更误导。参考实现（garmin-livetrack-aprs-openwrt）也是这么算的。
///
/// 用的是大圆航线的初始方位角公式；两点重合时返回 null（没有方向可言）。
double? bearingDeg(double lat1, double lng1, double lat2, double lng2) {
  const rad = 0.017453292519943295;
  final phi1 = lat1 * rad, phi2 = lat2 * rad;
  final dLambda = (lng2 - lng1) * rad;
  final y = math.sin(dLambda) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
  if (x.abs() < 1e-12 && y.abs() < 1e-12) return null;
  return (math.atan2(y, x) / rad + 360) % 360;
}

/// 当前平台能不能抓取佳明分享页（Web 版不能：浏览器的跨域限制）。
bool get garminFetchSupported => fetch.supported;

/// 佳明 LiveTrack 的一个轨迹点（心跳、位置、速度…）。
class GarminPoint {
  final DateTime at; // UTC
  final double lat;
  final double lng;
  final double? altM; // 米
  final double? speedMps; // 米/秒
  final int? hr; // bpm
  const GarminPoint({
    required this.at,
    required this.lat,
    required this.lng,
    this.altM,
    this.speedMps,
    this.hr,
  });
}

/// 佳明 LiveTrack 分享链接的正则（uuid + token 两段都必须有）。
///
/// 形如：`https://livetrack.garmin.com/session/<uuid>/token/<HEX>`
final RegExp _longRe = RegExp(
  r'https?://livetrack\.garmin\.com/session/[0-9a-fA-F-]{36}/token/[0-9A-Fa-f]+',
);

/// 短链：**佳明 App 的「分享」按钮给出的就是这个**（形如 `gar.mn/3nN1LAZebB`）。
///
/// 参考项目（garmin-livetrack-aprs-openwrt）从来没有这个问题 —— 它只从 **Gmail 邮件**
/// 里抠长链，而邮件里给的是完整的 `livetrack.garmin.com/session/…/token/…`。
/// 手机上的「分享」面板给的是短链，所以这条路是我们自己补的。
///
/// 实测（2026-09-24）：`https://gar.mn/<code>` → `301` →
/// `https://livetrack.garmin.com/session/<uuid>/token/<hex>` → `200`，页面与直接访问
/// 长链完全一致。所以**不需要**自己去解短链 —— 抓取时跟随跳转即可（见 garmin_fetch_io）。
final RegExp _shortRe = RegExp(r'https?://gar\.mn/[A-Za-z0-9_-]{4,32}');

/// 用户可能只复制到 `gar.mn/xxx`（分享面板里显示的常常没有 scheme）。
final RegExp _bareShortRe = RegExp(r'(?<![\w./-])gar\.mn/[A-Za-z0-9_-]{4,32}');

/// 把链接里的 token 打码，供日志/界面使用。
///
/// 分享链接本身就是**读取位置与心率的凭据** —— 原样写进日志或截图里，等于把
/// 自己的实时位置公开出去（参考项目的文档也专门强调了「token 只应存在于运行时」）。
String maskLiveTrackUrl(String url) => url.replaceAllMapped(
      RegExp(r'(token/)([0-9A-Fa-f]+)'),
      (m) => '${m[1]}${m[2]!.substring(0, m[2]!.length < 8 ? m[2]!.length : 8)}…',
    );

/// 从任意文本里抽出 LiveTrack 链接（用户可能整段粘贴分享文案，不止是链接）。
String? extractLiveTrackUrl(String raw) {
  final text = raw.trim();
  // 长链优先：它自带 session/token，最明确。
  final long = _longRe.firstMatch(text);
  if (long != null) return long.group(0);
  // 短链（佳明 App 分享）：带 scheme 的先用，其次补上 https:// ——
  // 分享面板里复制出来的往往就是 `gar.mn/xxx` 这样没有 scheme 的一段。
  final short = _shortRe.firstMatch(text);
  if (short != null) return short.group(0);
  final bare = _bareShortRe.firstMatch(text);
  if (bare != null) return 'https://${bare.group(0)}';
  // 兜底：任何**佳明域名**的链接都先收下。
  //
  // 为什么需要它：佳明的分享形式改过（邮件里是长链、App 里是 `gar.mn` 短链），
  // 而且还有 `connect.garmin.com/...` 这类页面 —— 只认死两种形态的话，佳明一改
  // 用户就会遇到「分享过来没反应」，而我们在代码里连一次网络请求都没有发出，
  // 也就没有任何错误可看。收下之后抓不到点会走「还没有取到点 / 抓取失败」的
  // 提示，失败至少是**可见**的。
  final anyGarmin =
      RegExp(r"https?://[\w.-]*\bgarmin\.com/[^\s<>'\x22]+")
          .firstMatch(text);
  if (anyGarmin != null) return anyGarmin.group(0);
  return null;
}

/// Next.js 的流式数据块：页面把服务端渲染的数据塞在
/// `<script>self.__next_f.push([1,"...json..."])</script>` 里。
final RegExp _fragRe = RegExp(
  r'<script>self\.__next_f\.push\((.*?)\)</script>',
  dotAll: true,
);

/// 从 LiveTrack 分享页 HTML 里取出 `trackPoints` 数组。
///
/// ── 为什么抓**公开分享页**而不是佳明那个私有 GraphQL ──
/// 参考实现（garmin-livetrack-aprs-openwrt）就是这么做的，理由很实在：GraphQL
/// 接口的 schema 与 CSRF 要求改过好几次，而分享页是给人看的、结构稳定得多。
/// 代价是「页面格式一变我们就拿不到点」—— 所以解析失败时给出的错误文案必须
/// 说明「链接可能已过期或页面格式变了」，而不是一句「网络错误」。
List<GarminPoint> parseTrackPoints(String document) {
  for (final m in _fragRe.allMatches(document)) {
    final encoded = m.group(1);
    if (encoded == null) continue;
    dynamic fragment;
    try {
      fragment = jsonDecode(encoded);
    } catch (_) {
      continue;
    }
    if (fragment is! List || fragment.length < 2) continue;
    final text = fragment[1];
    if (text is! String) continue;
    final i = text.indexOf('"trackPoints":');
    if (i < 0) continue;
    final arr = _decodeFirstJsonValue(text.substring(i + '"trackPoints":'.length));
    if (arr is! List) continue;
    final out = <GarminPoint>[];
    for (final e in arr) {
      if (e is! Map) continue;
      final p = _pointOf(e);
      if (p != null) out.add(p);
    }
    if (out.isNotEmpty) return out;
  }
  return const [];
}

/// 从某个位置起解出**第一个完整的 JSON 值**（Dart 没有 Python 的 raw_decode，
/// 而这一大段文本后面还接着别的字段，直接 jsonDecode 整段必然失败）。
dynamic _decodeFirstJsonValue(String s) {
  final start = s.indexOf('[');
  if (start < 0) return null;
  var depth = 0;
  var inStr = false;
  var esc = false;
  for (var i = start; i < s.length; i++) {
    final c = s[i];
    if (inStr) {
      if (esc) {
        esc = false;
      } else if (c == r'\') {
        esc = true;
      } else if (c == '"') {
        inStr = false;
      }
      continue;
    }
    if (c == '"') {
      inStr = true;
    } else if (c == '[' || c == '{') {
      depth++;
    } else if (c == ']' || c == '}') {
      depth--;
      if (depth == 0) {
        try {
          return jsonDecode(s.substring(start, i + 1));
        } catch (_) {
          return null;
        }
      }
    }
  }
  return null;
}

/// 佳明页面里的字段偶尔是 `"$undefined"` 这种**字符串哨兵**（Next.js 序列化的
/// undefined），必须当成「没有这个值」——直接 `as num` 会抛异常，而那一抛会把
/// 整批点都丢掉（表现是「页面上明明有点，应用里一个都没有」）。
double? _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? _intOrNull(dynamic v) {
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v);
  return null;
}

GarminPoint? _pointOf(Map e) {
  final pos = e['position'];
  if (pos is! Map) return null;
  final lat = _num(pos['lat']);
  final lng = _num(pos['lon']);
  if (lat == null || lng == null) return null;
  final at = DateTime.tryParse('${e['dateTime']}');
  if (at == null) return null;
  return GarminPoint(
    at: at.toUtc(),
    lat: lat,
    lng: lng,
    altM: _num(e['altitude']),
    speedMps: _num(e['speedMetersPerSec'] ?? e['speed']),
    hr: _intOrNull(e['heartRateBeatsPerMin']),
  );
}

/// 佳明 LiveTrack → 本应用的位置来源。
///
/// ── 语义（与参考实现 garmin-livetrack-aprs-openwrt 对齐的地方）──
///   * 页面每 [pollSec] 秒抓一次（默认 5s，参考实现是 2s；手机端没必要那么密）；
///   * **转发间隔 ≥ 10 秒**：GPS 点比这密，而 APRS 信道是共享资源；
///   * **只接受 120 秒内的点**：更旧的点到 APRS 已经没有意义；
///   * **积压超过 60 秒就跳到最新点**，不补发过时轨迹（补出来的是一条时间错误的线）。
///
/// 与参考实现不同的地方：不做 SQLite 去重台账（那是为了跨重启不重发），
/// 这里用内存里的「已见 dateTime 集合」——应用重启后重新开始，宁可重复一条，
/// 也不引入一个要维护的数据库。
class GarminTrackService {
  GarminTrackService._();
  static final GarminTrackService instance = GarminTrackService._();

  /// 只接受这么新的点（秒）。参考实现取 2 分钟，同。
  static const int kMaxAgeSec = 120;
  /// 最旧的待发点超过这个年龄就跳点（秒）。
  static const int kBacklogResyncSec = 60;
  /// 两次转发之间的最小间隔（秒）。
  static const int kMinForwardGapSec = 10;

  String url = '';
  bool on = false;
  int pollSec = 5;

  DateTime? lastFetchAt;
  DateTime? lastPointAt;
  int forwarded = 0;
  int failedPolls = 0;
  /// 空串 = 没有错误。
  String lastError = '';
  GarminPoint? latest;

  /// 每收到一个新点回调一次（AppState 用它更新「我的位置」）。
  void Function(GarminPoint p)? onPoint;
  /// 状态变化（UI 刷新）。
  void Function()? onChanged;

  Timer? _timer;
  final Map<String, DateTime> _seen = {}; // dateTime 字符串 → 时间（用于清理）
  DateTime? _lastForwardAt;

  void _changed() => onChanged?.call();

  /// 最近的抓取还新鲜吗（用来决定「手机 GPS 要不要让位」，见 AppState._onFix）。
  bool get fresh {
    final at = lastPointAt ?? lastFetchAt;
    if (at == null) return false;
    return DateTime.now().difference(at).inSeconds <= kMaxAgeSec;
  }

  /// 开启（返回 false 表示链接无效，UI 直接显示 `badUrl`）。
  Future<bool> start(String raw, {bool persist = true}) async {
    final u = extractLiveTrackUrl(raw);
    if (u == null) {
      lastError = 'badurl';
      _changed();
      return false;
    }
    url = u;
    on = true;
    lastError = '';
    failedPolls = 0;
    _seen.clear();
    _lastForwardAt = null;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: pollSec), (_) => _tick());
    _changed();
    await _tick();
    return true;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    on = false;
    _changed();
  }

  /// 设置轮询间隔（秒）：只认 2~60，越界就夹住 —— 1 秒会把佳明页面打爆。
  void setPollSec(int s) {
    final v = s.clamp(2, 60);
    if (v == pollSec) return;
    pollSec = v;
    if (on) {
      _timer?.cancel();
      _timer = Timer.periodic(Duration(seconds: pollSec), (_) => _tick());
    }
    _changed();
  }

  Future<void> _tick() async {
    if (!on || url.isEmpty) return;
    try {
      final doc = await fetch.httpGetText(url);
      final points = parseTrackPoints(doc);
      lastFetchAt = DateTime.now();
      failedPolls = 0;
      if (points.isEmpty) {
        // 抓到了页面但没有点：活动刚开或刚结束，不算错误
        _changed();
        return;
      }
      points.sort((a, b) => a.at.compareTo(b.at));
      _pruneSeen();
      final now = DateTime.now().toUtc();
      final fresh = points
          .where((p) =>
              !_seen.containsKey(p.at.toIso8601String()) &&
              now.difference(p.at).inSeconds <= kMaxAgeSec)
          .toList();
      if (fresh.isEmpty) {
        _changed();
        return;
      }
      // 积压太久：只发最新的那一个，别补发过时轨迹
      var target = fresh.last;
      if (now.difference(fresh.first.at).inSeconds > kBacklogResyncSec) {
        target = fresh.last;
      }
      // 间隔闸：不到最小间隔就等下一轮（但把点标记为已见，避免它反复排队）
      final last = _lastForwardAt;
      if (last != null &&
          now.difference(last).inSeconds < kMinForwardGapSec) {
        _changed();
        return;
      }
      for (final p in fresh) {
        _seen[p.at.toIso8601String()] = p.at;
      }
      _lastForwardAt = DateTime.now();
      lastPointAt = DateTime.now();
      latest = target;
      forwarded++;
      onPoint?.call(target);
      _changed();
    } catch (e) {
      failedPolls++;
      lastFetchAt = DateTime.now();
      lastError = '$e';
      _changed();
    }
  }

  /// 只留最近的 300 个已见时间戳（48 小时那种台账在这里没必要）。
  void _pruneSeen() {
    if (_seen.length < 300) return;
    final keys = _seen.keys.toList()..sort();
    for (final k in keys.take(_seen.length - 200)) {
      _seen.remove(k);
    }
  }
}
