import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// ─── APRSlocus 荣誉徽章体系 ───
///
/// 一个呼号可拥有多个称号徽章。徽章定义/授予均由官网 members.json 维护：
///   honors: { key: { zh, "zh-TW", en, desc:{...}, color } }  全集（含未点亮项）
///   developers / earlyMembers: [{call, honors:[key,...]}]
/// App 启动拉取 + 缓存；离线用内置兜底。
const String kMembersJsonUrl = 'https://aprslocus.theez.top/members.json';
const String kMemberCardBase = 'https://aprslocus.theez.top/member-card.html';

/// 单个徽章
class Honor {
  final String key;
  final String label;
  final String desc;
  final Color color;
  final IconData icon;
  const Honor(this.key, this.label, this.desc, this.color, this.icon);

  static IconData iconFor(String key) => switch (key) {
        'kaishan' => Icons.terrain_rounded, // 开山
        'developer' => Icons.code_rounded, // 开发
        'earlyMember' => Icons.workspace_premium_rounded, // 早期成员
        'aiCompute' => Icons.memory_rounded, // AI 算力
        'mostBrain' => Icons.psychology_rounded, // 最强大脑
        _ => Icons.emoji_events_rounded,
      };
}

/// 徽章全集展示顺序
const List<String> kHonorOrder = [
  'kaishan',
  'developer',
  'earlyMember',
  'aiCompute',
  'mostBrain',
];

/// 默认徽章定义（兜底，与官网 json 一致）
final Map<String, Honor> _defaultHonorDefs = {
  'kaishan': const Honor('kaishan', '开山', '极早期内测成员，项目最开始的参与与建设者。',
      Color(0xFFE67E22), Icons.terrain_rounded),
  'developer': const Honor('developer', '开发人员', '参与代码 / 翻译 / PR 的开发伙伴。',
      Color(0xFF1D6FF2), Icons.code_rounded),
  'earlyMember': const Honor('earlyMember', '早期成员', '早期公测阶段加入，陪伴 APRSlocus 成长。',
      Color(0xFFB08A34), Icons.workspace_premium_rounded),
  'aiCompute': const Honor('aiCompute', 'AI 算力支持', '以 AI 算力支持开发与测试。',
      Color(0xFF7C3AED), Icons.memory_rounded),
  'mostBrain': const Honor('mostBrain', '最强大脑', '项目理念与架构的核心大脑。',
      Color(0xFF0EA5C4), Icons.psychology_rounded),
};

/// 运行时徽章定义
Map<String, Honor> _honorDefs = Map.of(_defaultHonorDefs);
Map<String, List<String>> _honorsCache = {};
int _loadSeq = 0;

final ValueNotifier<int> memberListVersion = ValueNotifier<int>(0);

String _base(String call) => call.trim().toUpperCase().split('-').first;
String _norm(String s) => s.trim().toUpperCase();

/// 兜底归属
void _seedDefaults() {
  _honorsCache = {
    'BG7LZQ': ['mostBrain', 'kaishan', 'developer', 'earlyMember'],
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

/// 某呼号已获得的徽章 key（保持 kHonorOrder 顺序）
List<String> memberHonorKeys(String call) {
  final base = _base(call);
  final got = _honorsCache[base] ?? const <String>[];
  final set = got.toSet();
  return kHonorOrder.where(set.contains).toList();
}

bool hasAnyHonor(String call) => memberHonorKeys(call).isNotEmpty;

/// 某呼号已获得的徽章对象
List<Honor> honorsOf(String call) {
  return memberHonorKeys(call)
      .map((k) => _honorDefs[k])
      .whereType<Honor>()
      .toList();
}

/// 徽章全集（含未获得，用于面板展示；lock=未点亮）
List<({Honor honor, bool owned})> allHonorsWithState(String call) {
  final owned = memberHonorKeys(call).toSet();
  return [
    for (final k in kHonorOrder)
      if (_honorDefs[k] != null)
        (honor: _honorDefs[k]!, owned: owned.contains(k)),
  ];
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

void _parseMembers(Map d) {
  final hDefs = d['honors'];
  if (hDefs is Map && hDefs.isNotEmpty) {
    final m = <String, Honor>{};
    hDefs.forEach((k, v) {
      if (v is Map) {
        final zh = v['zh'] ?? k;
        final descMap = v['desc'];
        String desc = '';
        if (descMap is Map) {
          desc = (descMap['zh'] ?? descMap.values.firstOrNull ?? '').toString();
        }
        m[k.toString()] = Honor(k.toString(), zh.toString(), desc,
            _parseColor(v['color']), Honor.iconFor(k.toString()));
      }
    });
    if (m.isNotEmpty) _honorDefs = m;
  }
  final cache = <String, List<String>>{};
  void addMember(dynamic it, String defHonor) {
    String? call;
    List<dynamic>? honors;
    if (it is String) {
      call = it;
    } else if (it is Map) {
      call = it['call'] as String?;
      honors = it['honors'] as List?;
    }
    if (call == null || call.toString().isEmpty) return;
    if (honors != null && honors.isNotEmpty) {
      cache[call.toString().toUpperCase()] =
          honors.map((h) => h.toString()).toList();
    } else {
      cache[call.toString().toUpperCase()] = [defHonor];
    }
  }

  for (final m in (d['developers'] as List?) ?? const []) {
    addMember(m, 'kaishan');
  }
  for (final m in (d['earlyMembers'] as List?) ?? const []) {
    addMember(m, 'earlyMember');
  }
  if (cache.isNotEmpty) _honorsCache = cache;
}

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
      'desc': h.desc,
      'color': '#${h.color.value.toRadixString(16).padLeft(8, '0').substring(2)}',
    }));

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
              (v['desc'] ?? '').toString(),
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

/// 打开该呼号专属会员卡网页（浏览器）
Future<void> openMemberCard(String call) async {
  final url = '$kMemberCardBase?call=${_base(call)}';
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// 奖牌入口：显示已获徽章数量，点击弹出「徽章墙」面板
class HonorBadge extends StatelessWidget {
  final String call;
  const HonorBadge(this.call, {super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: memberListVersion,
      builder: (context, _, _) {
        final owned = memberHonorKeys(call);
        if (owned.isEmpty) return const SizedBox.shrink();
        const gold = Color(0xFFE67E22);
        return GestureDetector(
          onTap: () => _showHonorWall(context, call),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)]),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: gold.withValues(alpha: 0.6)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.emoji_events_rounded, size: 13, color: gold),
              // 仅 1 枚徽章时不显示数量，保持简洁
              if (owned.length > 1) ...[const SizedBox(width: 3),
                Text('×${owned.length}',
                    style: ts(10, c: gold, w: FontWeight.w800)),
              ],
            ]),
          ),
        );
      },
    );
  }

  void _showHonorWall(BuildContext context, String call) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollCtrl) => _HonorWallSheet(call: call, scrollCtrl: scrollCtrl),
      ),
    );
  }
}

/// 徽章墙面板：右上角呼号，逐行展示全部徽章（点亮彩色 + 说明 / 未点亮灰显）
class _HonorWallSheet extends StatefulWidget {
  final String call;
  final ScrollController scrollCtrl;
  const _HonorWallSheet({required this.call, required this.scrollCtrl});

  @override
  State<_HonorWallSheet> createState() => _HonorWallSheetState();
}

class _HonorWallSheetState extends State<_HonorWallSheet> {
  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final base = _base(call);
    final wall = allHonorsWithState(call);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FD),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(width: 40, height: 4, decoration: BoxDecoration(
              color: const Color(0xFFD9DEEB), borderRadius: BorderRadius.circular(2))),
        ),
        const SizedBox(height: 6),
        // 右上呼号
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
          child: Row(children: [
            const Text('徽章墙', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(base,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    letterSpacing: 1.2)),
          ]),
        ),
        const SizedBox(height: 4),
        Text(
          '已点亮 ${wall.where((w) => w.owned).length}/${wall.length}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF98A2B8)),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: memberListVersion,
            builder: (context, _, _) => ListView(
              controller: widget.scrollCtrl,
              children: [
                for (final w in wall) _badgeTile(w.honor, w.owned),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

Widget _badgeTile(Honor h, bool owned) {
  final c = owned ? h.color : const Color(0xFFC3CBD8);
  final col = owned ? h.color : const Color(0xFFADB6C8);
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: owned ? c.withValues(alpha: 0.4) : const Color(0xFFECEEF5)),
    ),
    child: Row(children: [
      // 徽章图标
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: owned ? c.withValues(alpha: 0.14) : const Color(0xFFF0F2F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(owned ? h.icon : Icons.lock_rounded, color: col, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(h.label,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: owned ? const Color(0xFF1B253C) : const Color(0xFF9AA3B7))),
          const SizedBox(height: 2),
          Text(owned ? h.desc : '未点亮',
              style: TextStyle(fontSize: 12, color: owned ? const Color(0xFF6A7590) : const Color(0xFFB8C0D0))),
        ]),
      ),
      if (owned)
        Icon(Icons.check_circle_rounded, color: c, size: 18)
      else
        const Icon(Icons.circle_outlined, color: Color(0xFFD5DAE5), size: 18),
    ]),
  );
}
