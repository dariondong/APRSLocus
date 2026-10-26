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
  bool enabled;
  int hits;
  final DateTime createdAt;

  SubRule({
    required this.id,
    required this.kind,
    required this.value,
    this.enabled = true,
    this.hits = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': subKindName(kind),
        'value': value,
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
    return SubRule(
      id: id,
      kind: kind,
      value: value,
      enabled: j['enabled'] != false,
      hits: (j['hits'] as num?)?.toInt() ?? 0,
      createdAt: at is int
          ? DateTime.fromMillisecondsSinceEpoch(at)
          : DateTime.now(),
    );
  }
}

/// 一条命中记录（只留「谁、什么时候、原文」）
class SubHit {
  final String ruleId;
  final String call;
  final String raw;
  final String? info;
  final DateTime time;
  SubHit({
    required this.ruleId,
    required this.call,
    required this.raw,
    this.info,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'rule': ruleId,
        'call': call,
        'raw': raw,
        if (info != null) 'info': info,
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

/// 这条报文是否命中该订阅
bool subMatches(SubRule rule, Packet p) {
  if (!rule.enabled) return false;
  final v = rule.value.trim();
  if (v.isEmpty) return false;
  switch (rule.kind) {
    case SubKind.station:
      final up = v.toUpperCase();
      // `BG7LZQ*` 这种前缀写法：盯一个呼号段
      if (up.endsWith('*')) {
        return p.src.toUpperCase().startsWith(up.substring(0, up.length - 1));
      }
      return subBaseCall(p.src) == subBaseCall(up);
    case SubKind.digi:
      final want = subBaseCall(v.toUpperCase());
      return subPathOf(p.raw).any((h) => subBaseCall(h) == want);
    case SubKind.keyword:
      final q = v.toLowerCase();
      return p.raw.toLowerCase().contains(q) ||
          (p.info?.toLowerCase().contains(q) ?? false);
  }
}

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
