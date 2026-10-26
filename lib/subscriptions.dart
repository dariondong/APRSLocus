import 'dart:convert';

import 'models.dart';

/// 订阅：盯住某一类报文，命中就记一条。
///
/// 三种口径（够用且互不重叠）：
///   * [SubKind.station] —— 某个台站发出来的任何报文（呼号省略 SSID 时含它的全部 SSID）；
///   * [SubKind.digi]    —— 经过某个中继/网关转发的报文（报文路径里出现它）；
///   * [SubKind.keyword] —— 报文原文里出现某个词（设备名、地区、`WIDE2` 之类）。
///
/// 订阅是**只看**，不改动任何收发行为：命中只进 [SubHit] 记录，不额外上报、
/// 不影响台站列表与筛选。
enum SubKind { station, digi, keyword }

/// 命中时它是哪个身份：自己发出的，还是只是**经它中继**的。
///
/// 用户：「我订阅这个台上是否发送了信标，或者是传递的信标、中继了信标？」——
/// 同一个呼号的两面必须能分开看：它自己的信标说明它还活着，它转发的信标
/// 说明它在中继链路上干活。两者混在一起，一条订阅就看不出是哪件事。
enum SubRole { source, path }

/// 订阅看哪类报文。信标 = 位置 / 状态 / 天气 / 对象（带位置的观测量），
/// 消息 = 点对点的 `:` 报文。
enum SubPacket { all, beacon, message }

String subRoleName(SubRole r) => r == SubRole.source ? 'source' : 'path';

SubRole? subRoleOf(String s) => switch (s) {
      'source' => SubRole.source,
      'path' => SubRole.path,
      _ => null,
    };

String subPacketName(SubPacket p) => switch (p) {
      SubPacket.all => 'all',
      SubPacket.beacon => 'beacon',
      SubPacket.message => 'message',
    };

SubPacket? subPacketOf(String s) => switch (s) {
      'all' => SubPacket.all,
      'beacon' => SubPacket.beacon,
      'message' => SubPacket.message,
      _ => null,
    };

String subKindName(SubKind k) => switch (k) {
      SubKind.station => 'station',
      SubKind.digi => 'digi',
      SubKind.keyword => 'keyword',
    };

SubKind? subKindOf(String s) {
  for (final k in SubKind.values) {
    if (subKindName(k) == s) return k;
  }
  return null;
}

class SubRule {
  final String id;
  final SubKind kind;

  /// 呼号 / 中继呼号 / 关键词，按用户输入原样保存
  final String value;

  /// 要不要算「它自己发出的」（源呼号就是它）
  bool asSource;

  /// 要不要算「只是经它中继的」（报文路径里出现它）
  bool asPath;

  /// 只看信标 / 只看消息 / 都看
  SubPacket packet;
  bool enabled;
  int hits;
  final DateTime createdAt;

  SubRule({
    required this.id,
    required this.kind,
    required this.value,
    // 默认跟口径走：台站看它自己发的，中继看经它转的；关键词不看身份
    bool? asSource,
    bool? asPath,
    SubPacket? packet,
    this.enabled = true,
    this.hits = 0,
    DateTime? createdAt,
  })  : asSource = asSource ?? kind != SubKind.digi,
        asPath = asPath ?? kind == SubKind.digi,
        packet = packet ?? SubPacket.all,
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': subKindName(kind),
        'value': value,
        'asSource': asSource,
        'asPath': asPath,
        'packet': subPacketName(packet),
        'enabled': enabled,
        'hits': hits,
        'at': createdAt.millisecondsSinceEpoch,
      };

  static SubRule? fromJson(Map<String, dynamic> j) {
    final kind = subKindOf('${j['kind']}');
    final value = '${j['value'] ?? ''}'.trim();
    final id = '${j['id'] ?? ''}';
    if (kind == null || value.isEmpty || id.isEmpty) return null;
    final at = j['at'];
    // 老规则没有身份 / 报文两个字段：按口径的默认值读回来，行为与升级前一致
    final src = j['asSource'];
    final path = j['asPath'];
    return SubRule(
      id: id,
      kind: kind,
      value: value,
      asSource: src is bool ? src : null,
      asPath: path is bool ? path : null,
      packet: j['packet'] is String ? subPacketOf('${j['packet']}') : null,
      enabled: j['enabled'] != false,
      hits: (j['hits'] as num?)?.toInt() ?? 0,
      createdAt: at is int
          ? DateTime.fromMillisecondsSinceEpoch(at)
          : DateTime.now(),
    );
  }
}

/// 一条命中记录（只留「谁、什么时候、原文」，外加这条命中是靠哪个身份进来的）
class SubHit {
  final String ruleId;
  final String call;
  final String raw;
  final String? info;
  final DateTime time;

  /// 命中身份；关键词口径没有身份，为 null
  final SubRole? role;

  /// 报文种类：`beacon` / `message` / `other`
  final String packet;
  SubHit({
    required this.ruleId,
    required this.call,
    required this.raw,
    this.info,
    required this.time,
    this.role,
    this.packet = 'other',
  });

  Map<String, dynamic> toJson() => {
        'rule': ruleId,
        'call': call,
        'raw': raw,
        if (info != null) 'info': info,
        if (role != null) 'role': subRoleName(role!),
        if (packet != 'other') 'packet': packet,
        'at': time.millisecondsSinceEpoch,
      };

  static SubHit? fromJson(Map<String, dynamic> j) {
    final raw = '${j['raw'] ?? ''}';
    if (raw.isEmpty) return null;
    return SubHit(
      ruleId: '${j['rule'] ?? ''}',
      call: '${j['call'] ?? ''}',
      raw: raw,
      info: j['info'] == null ? null : '${j['info']}',
      role: j['role'] == null ? null : subRoleOf('${j['role']}'),
      packet: '${j['packet'] ?? 'other'}',
      time: DateTime.fromMillisecondsSinceEpoch(
          (j['at'] as num?)?.toInt() ?? 0),
    );
  }
}

/// 呼号的「基础呼号」：`BG7LZQ-7` → `BG7LZQ`
String subBaseCall(String call) {
  final i = call.indexOf('-');
  return (i < 0 ? call : call.substring(0, i)).toUpperCase();
}

/// 从 TNC2 原始行里取转发路径（源/目标之后的那些，去掉 `*` 与 `qA?` 之外的杂项）
List<String> subPathOf(String raw) {
  final colon = raw.indexOf(':');
  final head = colon < 0 ? raw : raw.substring(0, colon);
  final comma = head.indexOf(',');
  if (comma < 0) return const [];
  return head
      .substring(comma + 1)
      .split(',')
      .map((e) => e.replaceAll('*', '').trim().toUpperCase())
      .where((e) => e.isNotEmpty)
      .toList();
}

/// 报文种类（命中记录与筛选共用）：只有这三档
String subPacketKindOf(Packet p) {
  switch (p.type) {
    case 'position':
    case 'status':
    case 'weather':
    case 'object':
      return 'beacon';
    case 'message':
      return 'message';
  }
  return 'other';
}

/// 这条报文是否属于该订阅看的报文种类
bool _packetOk(SubRule rule, Packet p) => switch (rule.packet) {
      SubPacket.all => true,
      SubPacket.beacon => subPacketKindOf(p) == 'beacon',
      SubPacket.message => subPacketKindOf(p) == 'message',
    };

/// 这条报文是否命中该订阅；命中时告诉调用方是哪个身份命中的
///
/// 台站与中继两个口径的**匹配规则是同一份**（呼号对上 + 身份开关），
/// 区别只在新建时的默认身份：台站默认看它自己发的，中继默认看经它转的。
/// 用户可以把两者都打开 —— 那时同一个呼号的自发报文与转发报文都会记下来，
/// 一条一条标清楚是「发出」还是「中继」。
SubRole? subMatch(SubRule rule, Packet p) {
  if (!rule.enabled) return null;
  final v = rule.value.trim();
  if (v.isEmpty) return null;
  if (!_packetOk(rule, p)) return null;
  switch (rule.kind) {
    case SubKind.station:
    case SubKind.digi:
      final up = v.toUpperCase();
      final src = p.src.toUpperCase();
      // `BG7LZQ*` 这种前缀写法：盯一个呼号段
      final byPrefix = up.endsWith('*');
      bool hit(String call) => byPrefix
          ? call.startsWith(up.substring(0, up.length - 1))
          : subBaseCall(call) == subBaseCall(up);
      if (rule.asSource && hit(src)) return SubRole.source;
      if (rule.asPath && subPathOf(p.raw).any(hit)) return SubRole.path;
      return null;
    case SubKind.keyword:
      final q = v.toLowerCase();
      final ok = p.raw.toLowerCase().contains(q) ||
          (p.info?.toLowerCase().contains(q) ?? false);
      return ok ? SubRole.source : null;
  }
}

/// 兼容写法：只要「命中没命中」
bool subMatches(SubRule rule, Packet p) => subMatch(rule, p) != null;

/// 订阅与命中记录的序列化（存成一条 prefs 字符串）
String encodeSubscriptions(List<SubRule> rules, List<SubHit> hits) =>
    jsonEncode({
      'rules': [for (final r in rules) r.toJson()],
      'hits': [for (final h in hits) h.toJson()],
    });

({List<SubRule> rules, List<SubHit> hits}) decodeSubscriptions(String raw) {
  final rules = <SubRule>[];
  final hits = <SubHit>[];
  try {
    final m = jsonDecode(raw);
    if (m is! Map) return (rules: rules, hits: hits);
    for (final e in (m['rules'] as List? ?? const [])) {
      if (e is Map) {
        final r = SubRule.fromJson(Map<String, dynamic>.from(e));
        if (r != null) rules.add(r);
      }
    }
    for (final e in (m['hits'] as List? ?? const [])) {
      if (e is Map) {
        final h = SubHit.fromJson(Map<String, dynamic>.from(e));
        if (h != null) hits.add(h);
      }
    }
  } catch (_) {
    // 坏了就当没有：订阅是附加功能，不能拖累启动
  }
  return (rules: rules, hits: hits);
}
