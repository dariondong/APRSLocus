import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// ─── APRSlocus 荣誉称号（HONOR / DEVELOPER / EARLY MEMBER）───
///
/// 一个呼号可拥有多个称号。数据默认内置一份兜底，启动时从官网 members.json
/// 拉取最新（结构见 docs/members.json）：
///   honors: { key: {zh, "zh-TW", en, color} }        称号定义
///   developers / earlyMembers: [{call, honors:[...], ...}] 成员
/// 称号归属均由官网 JSON 维护，无需发版即可更新。

const String kMembersJsonUrl = 'https://aprslocus.theez.top/members.json';
const String kMemberCardBase = 'https://aprslocus.theez.top/member-card.html';

/// 单个称号定义
class Honor {
  final String key;
  final String label;
  final Color color;
  final IconData icon;
  const Honor(this.key, this.label, this.color, this.icon);

  static IconData iconFor(String key) => switch (key) {
        'developer' => Icons.code_rounded,
        'earlyMember' => Icons.workspace_premium_rounded,
        'aiCompute' => Icons.memory_rounded,
        _ => Icons.emoji_events_rounded,
      };
}

/// 默认称号定义（联网失败 / 首次加载前兜底，与官网 json 默认一致）
final Map<String, Honor> _defaultHonorDefs = {
  'developer':
      const Honor('developer', '开发人员', Color(0xFF1D6FF2), Icons.code_rounded),
  'earlyMember': const Honor(
      'earlyMember', '早期成员', Color(0xFFB08A34), Icons.workspace_premium_rounded),
  'aiCompute':
      const Honor('aiCompute', 'AI 算力支持', Color(0xFF7C3AED), Icons.memory_rounded),
  'kaishan':
      const Honor('kaishan', '开山', Color(0xFFE67E22), Icons.emoji_events_rounded),
};

/// 运行时称号定义（联网更新后替换）
Map<String, Honor> _honorDefs = Map.of(_defaultHonorDefs);
int _loadSeq = 0;

/// 徽标重建通知
final ValueNotifier<int> memberListVersion = ValueNotifier<int>(0);

/// 取基呼号（去 SSID 后缀，转大写）
String _base(String call) => call.trim().toUpperCase().split('-').first;

/// 运行时“呼号 -> 称号 key 列表”缓存（联网更新后替换）
Map<String, List<String>> _honorsCache = {};

String _normalize(String s) => s.trim().toUpperCase();

/// 内置兜底：默认称号映射（开发者：开山+开发+早期；BA3RZL 额外 AI 算力）
void _seedDefaults() {
  _honorsCache = {
    'BG7LZQ': ['kaishan', 'developer', 'earlyMember'],
    'BG2HCB': ['kaishan', 'developer', 'earlyMember'],
    'BA4UAX': ['kaishan', 'developer', 'earlyMember'],
    'BD3QID': ['kaishan', 'developer', 'earlyMember'],
    'BG7PGW': ['kaishan', 'earlyMember'],
    'BG7LMW': ['kaishan', 'earlyMember'],
    'BG7OSL': ['kaishan', 'earlyMember'],
    'imThree': ['earlyMember'],
    'BA3RZL': ['earlyMember', 'aiCompute'],
  };
}

/// 判断某呼号命中的称号 key（可多个）
List<String> memberHonorsOf(String call) {
  final base = _base(call);
  return _honorsCache[base] ?? const [];
}

/// 从 members.json 解析称号
void _parseMembers(Map d) {
  // 1) 称号定义
  final hDefs = d['honors'];
  if (hDefs is Map && hDefs.isNotEmpty) {
    final m = <String, Honor>{};
    hDefs.forEach((k, v) {
      if (v is Map) {
        final zh = v['zh'] ?? k;
        final color = _parseColor(v['color']);
        m[k.toString()] =
            Honor(k.toString(), zh.toString(), color, Honor.iconFor(k.toString()));
      }
    });
    if (m.isNotEmpty) _honorDefs = m;
  }
  // 2) 成员 -> 称号
  final dev = (d['developers'] as List?) ?? const [];
  final early = (d['earlyMembers'] as List?) ?? const [];
  final cache = <String, List<String>>{};
  void addMember(dynamic it, String defaultHonor) {
    if (it is String) {
      cache[it.toUpperCase()] = [defaultHonor];
    } else if (it is Map) {
      final c = it['call'];
      if (c is String) {
        final key = c.toUpperCase();
        final honors = it['honors'];
        if (honors is List && honors.isNotEmpty) {
          cache[key] = honors.map((h) => h.toString()).toList();
        } else {
          cache[key] = [defaultHonor];
        }
      }
    }
  }

  for (final m in dev) {
    addMember(m, 'developer');
  }
  for (final m in early) {
    addMember(m, 'earlyMember');
  }
  if (cache.isNotEmpty) _honorsCache = cache;
}

Color _parseColor(dynamic v) {
  if (v is String) {
    final s = v.replaceFirst('#', '');
    if (s.length == 6) {
      final val = int.tryParse(s, radix: 16);
      if (val != null) return Color(0xFF000000 | val);
    }
  }
  return const Color(0xFF7A879D);
}

/// 从官网拉取并合并（幂等；失败静默保留现有/默认）
Future<void> refreshMembers() async {
  try {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client
          .getUrl(Uri.parse(kMembersJsonUrl))
          .timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.userAgentHeader, 'APRSlocus');
      final resp = await req.close().timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return;
      final body = await resp.transform(utf8.decoder).join();
      final d = jsonDecode(body);
      if (d is! Map) return;
      _parseMembers(d);
      memberListVersion.value++;
      // 缓存便于离线读取
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString('honorDefsJson', jsonEncode(_serializeDefs()));
        await p.setString('honorsCacheJson', jsonEncode(_honorsCache));
      } catch (_) {}
    } finally {
      client.close(force: true);
    }
  } catch (_) {}
}

Map<String, dynamic> _serializeDefs() => _honorDefs.map((k, h) => MapEntry(k, {
      'label': h.label,
      'color': '#${h.color.value.toRadixString(16).padLeft(8, '0').substring(2)}',
    }));

/// 首次加载：读缓存 → 若空用默认 → 后台联网刷新
Future<void> ensureMembersLoaded() async {
  if (_loadSeq > 0) return;
  _seedDefaults();
  _loadSeq++;
  try {
    final p = await SharedPreferences.getInstance();
    final defs = p.getString('honorDefsJson');
    final cache = p.getString('honorsCacheJson');
    if (defs != null && cache != null) {
      try {
        final dd = jsonDecode(defs) as Map;
        final dm = <String, Honor>{};
        dd.forEach((k, v) {
          if (v is Map) {
            dm[k.toString()] = Honor(
              k.toString(),
              (v['label'] ?? k).toString(),
              _parseColor(v['color']),
              Honor.iconFor(k.toString()),
            );
          }
        });
        if (dm.isNotEmpty) _honorDefs = dm;
        final cc = jsonDecode(cache) as Map;
        final cm = <String, List<String>>{};
        cc.forEach((k, v) {
          if (v is List) cm[k.toString()] = v.map((x) => x.toString()).toList();
        });
        if (cm.isNotEmpty) _honorsCache = cm;
      } catch (_) {}
    }
  } catch (_) {}
  unawaited(refreshMembers());
}

/// 该呼号的称号列表（供徽标/详情展示）
List<Honor> honorsOf(String call) {
  final keys = memberHonorsOf(call);
  final out = <Honor>[];
  for (final k in keys) {
    final h = _honorDefs[k];
    if (h != null) out.add(h);
  }
  return out;
}

/// 打开该呼号的专属会员卡网页（浏览器）
Future<void> openMemberCard(String call) async {
  final url = '$kMemberCardBase?call=${_base(call)}';
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// 荣誉徽标组：同一呼号可有多个称号，全部展示。点击任意徽章打开专属卡页。
class HonorBadge extends StatelessWidget {
  final String call;
  final bool compact;
  const HonorBadge(this.call, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: memberListVersion,
      builder: (context, _, _) {
        final honors = honorsOf(call);
        if (honors.isEmpty) return const SizedBox.shrink();
        return Wrap(
          spacing: 4,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final h in honors)
              GestureDetector(
                onTap: () => openMemberCard(call),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: h.color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: h.color.withValues(alpha: 0.55)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(h.icon, size: compact ? 12 : 13, color: h.color),
                    if (!compact) ...[
                      SizedBox(width: 3),
                      Text(h.label, style: ts(9.5, c: h.color, w: FontWeight.w800)),
                    ],
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}
