/// APRSLocus 的个人数据同步：消息、云端备份、历史轨迹。
///
/// 服务器是 APRSNETCN SERVER（github.com/dariondong/APRSNETCN-SERVER），
/// 接口见那边的 `docs/API.md`。这里只放「怎么跟它说话」与两件纯计算：
/// 一条消息在云端的 id、一次请求失败的原因。
///
/// 账号就是名单里那条记录的账号与口令，登录换一个 90 天的令牌；
/// 令牌存在本机、不进备份。这套令牌与 `/api/v1/stations` 的 12 小时 token
/// 是两套东西，别混。
///
/// **现在是明文 HTTP**：口令与数据都不走 TLS，界面上要如实说这一句。
library;

import 'dart:convert';

import 'aprsnetcn.dart';
import 'models.dart';
import 'net/http_send.dart';

/// 一次同步请求失败的原因。code 是给界面选文案用的，不直接显示。
class SyncException implements Exception {
  final String code;
  final String? detail;
  const SyncException(this.code, [this.detail]);

  @override
  String toString() => 'SyncException($code${detail == null ? '' : ': $detail'})';
}

/// 一条消息在云端的 id。
///
/// 呼号 + 方向 + 时间 + 文本的指纹：两台设备对同一条消息算出来一样，
/// 云端并集时才不会出现两份。用 FNV-1a 而不是 `String.hashCode` ——
/// 后者只保证「同一个进程里稳定」，换版本就可能变。
String syncMessageId(AprsMsg m) {
  final text = '${m.from}>${m.to}|${m.time.millisecondsSinceEpoch}|${m.text}';
  return '${m.time.millisecondsSinceEpoch.toRadixString(36)}-'
      '${_fnv1a32(text).toRadixString(16)}';
}

int _fnv1a32(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = (hash ^ (unit & 0xff)) & 0xffffffff;
    hash = (hash * 0x01000193) & 0xffffffff;
    hash = (hash ^ ((unit >> 8) & 0xff)) & 0xffffffff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// 一条消息上传时带的那几个字段（与服务端的列一一对应）。
Map<String, dynamic> syncMessagePayload(AprsMsg m) => {
      'mid': syncMessageId(m),
      'ts': m.time.millisecondsSinceEpoch,
      'peer': m.sent ? m.to : m.from,
      'dir': m.sent ? 'out' : 'in',
      'text': m.text,
      'acked': m.acked,
      if (m.groupId != null && m.groupId!.isNotEmpty) 'grp': m.groupId!,
    };

/// 登录回包。
class SyncLogin {
  final String token;
  final String call;
  final String device;
  final DateTime? expires;

  const SyncLogin({
    required this.token,
    required this.call,
    required this.device,
    this.expires,
  });
}

/// 同步接口的客户端。`base` 形如 `http://host:8899`（末尾没有斜杠）。
class SyncApi {
  SyncApi({required this.base, this.token = ''});

  final String base;
  String token;

  /// 用哪个地址：云同步页自己填的那台，空着就用项目自带的那台。
  ///
  /// 地址跟着「APRSNETCN」链路走是一种看不见的耦合 —— 页面上没有地址框，
  /// 用户既不知道数据发去了哪台机器，也没法换成自己架的那台。
  ///
  /// 两种写法都收：带协议的（`https://sync.example.com`）原样用，不带协议的
  /// （`1.2.3.4`）补上 `http://` 与 8899，与「APRSNETCN」页那张卡同一口径。
  /// 末尾的斜杠先去掉，否则拼出来就是 `…8899//api/v1/…`。
  static String baseFor(String server) {
    var host = server.trim();
    if (host.isEmpty) return kAcnHttpBase;
    while (host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }
    if (host.contains('://')) return host;
    final hasPort = RegExp(r':\d+$').hasMatch(host);
    return 'http://$host${hasPort ? '' : ':8899'}';
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$base$path');
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> _call(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    String text;
    try {
      text = await httpSend(
        method,
        _uri(path, query),
        headers: _headers,
        body: body == null ? null : jsonEncode(body),
        timeout: timeout,
      );
    } on HttpStatusError catch (error) {
      throw SyncException(_codeOf(error), error.body);
    } catch (error) {
      throw SyncException('network', '$error');
    }
    if (text.trim().isEmpty) return {};
    try {
      final data = jsonDecode(text);
      return data is Map<String, dynamic> ? data : {};
    } catch (error) {
      throw SyncException('bad-response', '$error');
    }
  }

  /// 服务端回的 `error` 字段就是原因（`bad-credentials` 之类）；
  /// 没有就按状态码给一个。
  String _codeOf(HttpStatusError error) {
    try {
      final data = jsonDecode(error.body);
      if (data is Map && data['error'] is String) {
        final code = data['error'] as String;
        final reason = data['reason'];
        return reason is String && reason.isNotEmpty ? '$code:$reason' : code;
      }
    } catch (_) {}
    if (error.status == 401) return 'unauthorized';
    if (error.status == 403) return 'forbidden';
    if (error.status == 404) return 'missing';
    if (error.status == 429) return 'rate-limited';
    return 'http-${error.status}';
  }

  Future<SyncLogin> login({
    required String account,
    required String password,
    required String device,
    String ver = '',
    String platform = '',
    String abi = '',
  }) async {
    final data = await _call('POST', '/api/v1/sync/login', body: {
      'account': account,
      'password': password,
      'device': {
        'id': device,
        'ver': ver,
        'platform': platform,
        'abi': abi,
      },
    });
    final issued = (data['token'] as String?) ?? '';
    if (issued.isEmpty) throw const SyncException('bad-response');
    token = issued;
    return SyncLogin(
      token: issued,
      call: (data['call'] as String?) ?? '',
      device: (data['device'] as String?) ?? '',
      expires: DateTime.tryParse((data['expires'] as String?) ?? ''),
    );
  }

  Future<Map<String, dynamic>> state() => _call('GET', '/api/v1/sync/state');

  Future<void> logout() => _call('POST', '/api/v1/sync/logout');

  /// 推一批消息，返回云端新增的条数。
  Future<int> pushMessages(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return 0;
    final data = await _call('POST', '/api/v1/sync/messages',
        body: {'items': items});
    return (data['added'] as num?)?.toInt() ?? 0;
  }

  /// 拉 [since] 毫秒之后的消息，一页一页拉到不满一页为止。
  Future<List<Map<String, dynamic>>> pullMessages(int since) async {
    const page = 500;
    final out = <Map<String, dynamic>>[];
    var offset = 0;
    while (offset < 10000) {
      final data = await _call('GET', '/api/v1/sync/messages', query: {
        'since': '$since',
        'limit': '$page',
        'offset': '$offset',
      });
      final rows = (data['messages'] as List?) ?? const [];
      for (final row in rows) {
        if (row is Map) out.add(Map<String, dynamic>.from(row));
      }
      if (rows.length < page) break;
      offset += rows.length;
    }
    return out;
  }

  /// 上传某一天，返回服务端这一天（这台设备）合并后的点数。
  Future<int> pushTrack(String day, List<Map<String, dynamic>> points) async {
    final data = await _call('PUT', '/api/v1/sync/tracks/$day',
        body: {'points': points});
    return (data['points'] as num?)?.toInt() ?? 0;
  }

  /// 云端有哪些天：`[{day, points, devices}]`。
  Future<List<Map<String, dynamic>>> trackDays() async {
    final data = await _call('GET', '/api/v1/sync/tracks');
    final rows = (data['days'] as List?) ?? const [];
    return [
      for (final row in rows)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  /// 拉某一天（多台设备已经在服务端合成一条）。没有这一天返回空表。
  Future<List<Map<String, dynamic>>> pullTrack(String day) async {
    try {
      final data = await _call('GET', '/api/v1/sync/tracks/$day');
      final rows = (data['points'] as List?) ?? const [];
      return [
        for (final row in rows)
          if (row is Map) Map<String, dynamic>.from(row),
      ];
    } on SyncException catch (error) {
      if (error.code == 'missing') return const [];
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> backups() async {
    final data = await _call('GET', '/api/v1/sync/backup');
    final rows = (data['backups'] as List?) ?? const [];
    return [
      for (final row in rows)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  /// 上传一份备份（`text` 就是备份 JSON 本身）。返回新那份的 id。
  Future<String> pushBackup(String text, String label) async {
    Object? doc;
    try {
      doc = jsonDecode(text);
    } catch (_) {
      throw const SyncException('bad-backup');
    }
    final data = await _call(
      'PUT',
      '/api/v1/sync/backup',
      body: doc,
      query: {'label': label},
      timeout: const Duration(seconds: 60),
    );
    final info = data['backup'];
    return info is Map ? ((info['id'] as String?) ?? '') : '';
  }

  Future<Map<String, dynamic>> pullBackup(String id) =>
      _call('GET', '/api/v1/sync/backup/$id',
          timeout: const Duration(seconds: 60));

  /// 清空云端数据（令牌不动）。返回删掉的行数。
  Future<int> clearAll() async {
    final data = await _call('DELETE', '/api/v1/sync');
    return (data['removed'] as num?)?.toInt() ?? 0;
  }

  Future<void> dropDevice(String device) =>
      _call('DELETE', '/api/v1/sync/devices/$device');
}
