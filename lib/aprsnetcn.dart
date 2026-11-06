/// APRSNETCN SERVER（国内的一台 APRS-IS 兼容服务器）在客户端这侧要知道的那些值。
///
/// 服务器是另一个项目（github.com/dariondong/APRSNETCN-SERVER），协议上是
/// APRS-IS 的超集：标准登录行照旧可用，另外多认一对「名单账号 + 口令」
/// （`auth <账号> <口令>`，排在 `filter` 之前）和一套 HTTP 接口。
///
/// 一个地址都不预填：界面里的服务器地址留空，用户自己填。这里只留旧版本
/// 预填过的那台机器 —— 更新时认出老地址，把账号与口令带到新的链路设置里。
library;

import 'dart:convert';

import 'net/http_send.dart';

/// 接入点地址（APRS-IS 兼容的 TCP 端口）
const String kAcnServerHost = '8.138.199.11';

/// APRS-IS 兼容的 TCP 端口
const int kAcnServerPort = 14580;

/// 界面里填的 APRS 地址 → HTTP 接口入口。
///
/// 那台机器上 APRS 端口（14580）与 HTTP 端口（8899）是分开的两个设置，界面
/// 只让人填 APRS 那一个，所以这里补上 8899。
///
/// 地址空着就返回空串：一个地址都不预填，也不拿任何内置地址当兜底（
/// 用户没填地址时，软件不该自己去连一台服务器，调用方据此跳过 HTTP 请求）。
String acnHttpBaseHost(String host) {
  final h = host.trim();
  return h.isEmpty ? '' : 'http://$h:8899';
}

/// 一台台站在服务器那侧的 24 小时概况（= 该呼号最后一次位置 + 收到几帧）。
///
/// 字段与 `/api/v1/stations` 的响应一一对应，但这里**全部容错**：缺一个字段
/// 就让那台站整台丢掉，比带一个 0,0 的坐标进地图好得多 —— 后者会在地图原点
/// （几内亚湾）堆出一片假台站。
class AcnStation {
  final String call;
  final double lat;
  final double lng;
  final String symbolTable;
  final String symbol;
  final double? speed;
  final double? course;
  final double? alt;
  final String comment;
  final DateTime lastSeen;
  final int packets;

  const AcnStation({
    required this.call,
    required this.lat,
    required this.lng,
    required this.symbolTable,
    required this.symbol,
    required this.speed,
    required this.course,
    required this.alt,
    required this.comment,
    required this.lastSeen,
    required this.packets,
  });

  /// 解析一条；坐标/时间是必需项，缺了返回 null。
  static AcnStation? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final call = (raw['call'] as String?)?.trim().toUpperCase() ?? '';
    if (call.isEmpty) return null;
    final lat = _num(raw['lat']);
    final lng = _num(raw['lon']);
    final at = _parseBeijing((raw['last_seen'] as String?) ?? '');
    if (lat == null || lng == null || at == null) return null;
    final sym = raw['symbol'];
    var table = '/';
    var code = '/';
    if (sym is Map) {
      table = (sym['table'] as String?) ?? '/';
      code = (sym['code'] as String?) ?? '/';
    }
    return AcnStation(
      call: call,
      lat: lat,
      lng: lng,
      symbolTable: table,
      symbol: code,
      speed: _num(raw['speed']),
      course: _num(raw['course']),
      alt: _num(raw['alt']),
      comment: (raw['comment'] as String?) ?? '',
      lastSeen: at,
      packets: (raw['packets'] as num?)?.toInt() ?? 0,
    );
  }

  static double? _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static final RegExp _zoneTail = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

  /// 服务器写的是北京时间（形如 `2026-10-17T23:44:01`），字符串里没有偏移。
  ///
  /// 直接交给 `DateTime.tryParse` 会按**本机时区**解释：出了国门，「多久前听到」
  /// 就差几个小时，在线与离线会判反。缺偏移就按 +08:00 补上，再转成本机时间。
  static DateTime? _parseBeijing(String text) {
    final s = text.trim();
    if (s.isEmpty) return null;
    final filled = _zoneTail.hasMatch(s) ? s : '$s+08:00';
    return DateTime.tryParse(filled)?.toLocal();
  }
}

/// 服务器自己公布的那几条策略（`/api/v1/version`，不用 token）。
///
/// 草案要求服务器明确写出自己实际采用的策略：passcode 怎么验、位置留多久、
/// 没带过滤器的连接收到什么。客户端照实显示，不自己猜。
class AcnInfo {
  final String proto;
  final int retentionHours;
  final String passcodeMode;
  final int whitelistMaxAgeHours;
  final String defaultFilter;
  final List<String> filters;

  const AcnInfo({
    required this.proto,
    required this.retentionHours,
    required this.passcodeMode,
    required this.whitelistMaxAgeHours,
    required this.defaultFilter,
    required this.filters,
  });

  /// 没带过滤器的连接收到什么。`all` = 全收。
  bool get feedAll => defaultFilter == 'all';

  static AcnInfo? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final proto = (raw['proto'] as String?)?.trim() ?? '';
    if (proto.isEmpty) return null;
    final list = raw['filters'];
    return AcnInfo(
      proto: proto,
      retentionHours: (raw['retention_hours'] as num?)?.toInt() ?? 24,
      passcodeMode: (raw['passcode_mode'] as String?) ?? '',
      whitelistMaxAgeHours:
          (raw['whitelist_max_age_hours'] as num?)?.toInt() ?? 0,
      defaultFilter: (raw['default_filter'] as String?) ?? '',
      filters: [
        if (list is List)
          for (final item in list) '$item',
      ],
    );
  }
}

/// 一次同步的结果（给界面/日志用，不抛异常）
class AcnSyncResult {
  final int added;
  final int total;
  final String? error;

  const AcnSyncResult({required this.added, required this.total, this.error});

  bool get ok => error == null;

  @override
  String toString() =>
      ok ? '同步 $total 台，新增 $added' : '同步失败：$error';
}

/// 24 小时台站接口的客户端。
///
/// token 只放在内存里：换一台机器、重启一次就要重新用账号口令换一个，这本来
/// 就是一两百毫秒的事，落盘一份 token 反而要在备份里处理它。
class AcnClient {
  AcnClient({required this.base});

  /// 接口入口。换一台服务器就是换这个值。
  ///
  /// 没有默认值：一个地址都不预填，地址空着就不该构造出客户端。
  final String base;
  String _token = '';
  String _tokenFor = '';
  DateTime _expires = DateTime.fromMillisecondsSinceEpoch(0);

  /// token 剩下的有效期（服务器发 12 小时，这里按下限保守算 11 小时，
  /// 免得正好卡在过期那一刻发请求）
  static const Duration _ttl = Duration(hours: 11);

  bool _tokenOk(String account) =>
      _token.isNotEmpty &&
      _tokenFor == account.trim().toLowerCase() &&
      DateTime.now().isBefore(_expires);

  /// 用名单账号口令换一个 token。账号或口令错会抛 HttpStatusError。
  Future<void> login(String account, String password) async {
    final body = await httpSend(
      'POST',
      Uri.parse('$base/api/v1/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'account': account.trim(), 'password': password}),
      timeout: const Duration(seconds: 15),
    );
    final map = jsonDecode(body);
    final token = (map is Map) ? (map['token'] as String?) ?? '' : '';
    if (token.isEmpty) throw StateError('no-token');
    _token = token;
    _tokenFor = account.trim().toLowerCase();
    _expires = DateTime.now().add(_ttl);
  }

  /// 服务器公布的能力与策略。不用 token，地址写错只是这一条失败。
  Future<AcnInfo> info() async {
    final body = await httpSend(
      'GET',
      Uri.parse('$base/api/v1/version'),
      timeout: const Duration(seconds: 10),
    );
    final parsed = AcnInfo.fromJson(jsonDecode(body));
    if (parsed == null) throw StateError('no-info');
    return parsed;
  }

  /// 一次拉 24 小时台站，按页把整份拉完。
  ///
  /// 接口的 `limit` 有上限，服务器不会一次给完（现在一天下来两千多台），所以
  /// 拿完一页就拿下一页，拿到不满一页为止。旧版写死 2000，超过的那部分人在地图
  /// 上根本没有。
  ///
  /// 没 token 就先换一个；401 时换一次再重试。
  Future<List<AcnStation>> stations({
    required String account,
    required String password,
    int hours = 24,
  }) async {
    if (!_tokenOk(account)) await login(account, password);
    final rows = await _get(account, password, hours);
    final out = <AcnStation>[];
    for (final row in rows) {
      final s = AcnStation.fromJson(row);
      if (s != null) out.add(s);
    }
    return out;
  }

  /// 一页多少台：服务器允许到 5000，这里取 2000 平衡单次响应和往返次数。
  static const int _pageLimit = 2000;

  /// 翻页上限。台站真多到这个数时宁可少拿，也不一直转下去。
  static const int _maxPages = 20;

  Future<List<Object?>> _get(
    String account,
    String password,
    int hours,
  ) async {
    final all = <Object?>[];
    for (var page = 0; page < _maxPages; page++) {
      final rows = await _getPage(account, password, hours, all.length);
      all.addAll(rows);
      if (rows.length < _pageLimit) break;
    }
    return all;
  }

  /// 取一页。401 换一次 token 再来，其余错误直接抛。
  Future<List<Object?>> _getPage(
    String account,
    String password,
    int hours,
    int offset,
  ) async {
    final uri = Uri.parse('$base/api/v1/stations').replace(
      queryParameters: {
        'window': '${hours}h',
        'limit': '$_pageLimit',
        'offset': '$offset',
      },
    );
    Future<String> call() => httpSend(
          'GET',
          uri,
          headers: {'Authorization': 'Bearer $_token'},
          timeout: const Duration(seconds: 20),
        );
    String body;
    try {
      body = await call();
    } on HttpStatusError catch (e) {
      if (e.status != 401) rethrow;
      await login(account, password);
      body = await call();
    }
    final map = jsonDecode(body);
    final rows = (map is Map) ? map['stations'] : null;
    return rows is List ? rows : const <Object?>[];
  }
}
