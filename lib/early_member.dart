import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'achievements.dart';
import 'honor_wall_page.dart';

/// ─── APRSlocus 荣誉徽章体系 ───
/// 一个呼号可拥有多个称号徽章；徽章定义/授予/优先徽章均由官网 members.json 维护。
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
        'kaishan' => Icons.terrain_rounded,
        'developer' => Icons.code_rounded,
        'earlyMember' => Icons.workspace_premium_rounded,
        'mostBrain' => Icons.psychology_rounded,
        _ => Icons.emoji_events_rounded,
      };
}

/// 徽章全集展示顺序
const List<String> kHonorOrder = [
  'kaishan',
  'developer',
  'earlyMember',
  'mostBrain',
];

/// 默认徽章定义（联网兜底）
final Map<String, Honor> _defaultHonorDefs = {
  'kaishan': const Honor('kaishan', '开山', '群山之始，你我曾一同点亮第一座灯塔；山高水长，此呼号为证。',
      Color(0xFFE67E22), Icons.terrain_rounded),
  'developer': const Honor('developer', '开发人员', '以代码为桨、翻译为桥，一砖一瓦把 APRSlocus 推向更远的频率。',
      Color(0xFF1D6FF2), Icons.code_rounded),
  'earlyMember': const Honor('earlyMember', '早期成员', '在最朦胧的电波里守候回响，陪它从微弱信号长成清晰呼号。',
      Color(0xFFB08A34), Icons.workspace_premium_rounded),
  'mostBrain': const Honor('mostBrain', '最强大脑',
      '隐藏成就：于无声处托举算力洪流——为项目点亮超半数的光。', Color(0xFF0EA5C4), Icons.psychology_rounded),
};

Map<String, Honor> _honorDefs = Map.of(_defaultHonorDefs);
Map<String, List<String>> _honorsCache = {};
Map<String, String> _primariesCache = {};
/// 用户手动选择的默认徽章（key=基呼号）
Map<String, String> _userPrimary = {};
int _loadSeq = 0;

final ValueNotifier<int> memberListVersion = ValueNotifier<int>(0);

String _base(String call) => call.trim().toUpperCase().split('-').first;
String _norm(String s) => s.trim().toUpperCase();

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
    'BA3RZL': ['earlyMember', 'mostBrain'],
  };
  _primariesCache = {
    'BG7LZQ': 'kaishan',
    'BG2HCB': 'kaishan',
    'BA4UAX': 'kaishan',
    'BD3QID': 'kaishan',
    'BG7PGW': 'kaishan',
    'BG7LMW': 'kaishan',
    'BG7OSL': 'kaishan',
    'imThree': 'earlyMember',
    'BA3RZL': 'earlyMember',
  };
}

List<String> memberHonorKeys(String call) {
  final base = _base(call);
  final got = _honorsCache[base] ?? const <String>[];
  final set = got.toSet();
  return kHonorOrder.where(set.contains).toList();
}

bool hasAnyHonor(String call) => memberHonorKeys(call).isNotEmpty;

List<Honor> honorsOf(String call) =>
    memberHonorKeys(call).map((k) => _honorDefs[k]).whereType<Honor>().toList();

List<({Honor honor, bool owned})> allHonorsWithState(String call) {
  final owned = memberHonorKeys(call).toSet();
  return [
    for (final k in kHonorOrder)
      if (_honorDefs[k] != null)
        (honor: _honorDefs[k]!, owned: owned.contains(k)),
  ];
}

/// 用户手动选择的默认徽章 key；未选/无效返回 null
String? userPrimaryKeyOf(String call) {
  final base = _base(call);
  final v = _userPrimary[base];
  if (v != null && memberHonorKeys(call).contains(v)) return v;
  return null;
}

/// 设置用户默认展示徽章（仅可从未获得? 不：仅可从已获得中选择）
Future<void> setUserPrimary(String call, String honorKey) async {
  final base = _base(call);
  if (!memberHonorKeys(call).contains(honorKey)) return;
  _userPrimary[base] = honorKey;
  memberListVersion.value++;
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString('honorPrimary_$base', honorKey);
  } catch (_) {}
}

/// 默认展示徽章：用户选择 > member.json primary > 第一个已获
Honor? primaryHonorOf(String call) {
  final keys = memberHonorKeys(call);
  if (keys.isEmpty) return null;
  final base = _base(call);
  final user = _userPrimary[base];
  if (user != null && keys.contains(user) && _honorDefs[user] != null) {
    return _honorDefs[user];
  }
  final p = _primariesCache[base];
  if (p != null && _honorDefs[p] != null && keys.contains(p)) return _honorDefs[p];
  return _honorDefs[keys.first];
}

/// 当前用户已获得的所有徽章对象（供选择器用）
List<Honor> ownedHonorsOf(String call) => honorsOf(call);

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
        var desc = '';
        final dm = v['desc'];
        if (dm is Map) desc = (dm['zh'] ?? '').toString();
        m[k.toString()] = Honor(k.toString(), zh.toString(), desc,
            _parseColor(v['color']), Honor.iconFor(k.toString()));
      }
    });
    if (m.isNotEmpty) _honorDefs = m;
  }
  final cache = <String, List<String>>{};
  final prim = <String, String>{};
  void addMember(dynamic it, String defHonor) {
    String? call;
    List? honors;
    Object? primary;
    if (it is String) {
      call = it;
    } else if (it is Map) {
      call = it['call'] as String?;
      honors = it['honors'] as List?;
      primary = it['primary'];
    }
    if (call == null || call.toString().isEmpty) return;
    final key = call.toString().toUpperCase();
    if (honors != null && honors.isNotEmpty) {
      cache[key] = honors.map((x) => x.toString()).toList();
    } else {
      cache[key] = [defHonor];
    }
    if (primary != null) prim[key] = primary.toString();
  }

  for (final m in (d['developers'] as List?) ?? const []) {
    addMember(m, 'kaishan');
  }
  for (final m in (d['earlyMembers'] as List?) ?? const []) {
    addMember(m, 'earlyMember');
  }
  if (cache.isNotEmpty) _honorsCache = cache;
  if (prim.isNotEmpty) _primariesCache = prim;
}

Future<void> refreshMembers() async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req =
          await client.getUrl(Uri.parse(kMembersJsonUrl)).timeout(const Duration(seconds: 8));
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
        await p.setString('primariesJson', jsonEncode(_primariesCache));
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
    final prim = p.getString('primariesJson');
    if (defs != null && cache != null) {
      try {
        _userPrimary.clear();
        final allKeys = p.getKeys();
        for (final k in allKeys) {
          if (k.startsWith('honorPrimary_')) {
            final base = k.substring('honorPrimary_'.length);
            final v = p.getString(k);
            if (base != null && v != null) _userPrimary[base] = v;
          }
        }
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
        if (prim != null) {
          final pm = jsonDecode(prim) as Map;
          _primariesCache =
              pm.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {}
    }
  } catch (_) {}
  unawaited(refreshMembers());
}

Future<void> openMemberCard(String call) async {
  final url = '$kMemberCardBase?call=${_base(call)}';
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// 入口：显示优先徽章（primary）图标+颜色，点击打开徽章墙面板。
class HonorBadge extends StatelessWidget {
  final String call;
  final String? symbol; // 用户当前 APRS 符号（用于荣誉墙头像）
  final String? symbolTable;
  const HonorBadge(this.call, {super.key, this.symbol, this.symbolTable});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: memberListVersion,
      builder: (context, _, _) {
        final keys = memberHonorKeys(call);
        if (keys.isEmpty) return const SizedBox.shrink();
        final pri = primaryHonorOf(call);
        final col = pri?.color ?? const Color(0xFFE67E22);
        final ic = pri?.icon ?? Icons.emoji_events_rounded;
        return GestureDetector(
          onTap: () => _showHonorWall(context, call),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: col.withValues(alpha: 0.6)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ic, size: 14, color: col),
              const SizedBox(width: 4),
              // 显示具体徽章名（可读性优先，不画成纯图标）
              Text(pri?.label ?? '徽章',
                  style: ts(11, c: col, w: FontWeight.w800)),
              if (keys.length > 1) ...[const SizedBox(width: 3),
                Text('+${keys.length - 1}',
                    style: ts(9.5, c: col.withValues(alpha: 0.7), w: FontWeight.w700)),
              ],
            ]),
          ),
        );
      },
    );
  }

  void _showHonorWall(BuildContext context, String call) {
    // 进入 App 内荣誉墙页面（徽章+成就），其中点具体徽章再跳官网徽章页
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => HonorWallPage(call,
              symbol: symbol, symbolTable: symbolTable)),
    );
  }
}

/// 徽章墙面板：头部靠左大呼号，逐行徽章；已点亮徽章点击打开官网专属卡
class _HonorWallSheet extends StatelessWidget {
  final String call;
  final ScrollController scrollCtrl;
  const _HonorWallSheet({required this.call, required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    final base = _base(call);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(width: 40, height: 4, decoration: BoxDecoration(
              color: const Color(0xFFD5DBE8),
              borderRadius: BorderRadius.circular(2))),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Text(base,
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 1.5,
                  height: 1.1)),
          const SizedBox(width: 12),
          const Text('徽章墙',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF98A2B8))),
        ]),
        const SizedBox(height: 4),
        ValueListenableBuilder<int>(
          valueListenable: memberListVersion,
          builder: (context, _, _) {
            final wall = allHonorsWithState(call);
            final ownedCount = wall.where((w) => w.owned).length;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('已点亮 $ownedCount/${wall.length}',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF98A2B8))),
              const SizedBox(height: 12),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.62,
                child: ValueListenableBuilder<int>(
                  valueListenable: AchievementCenter.instance.version,
                  builder: (context, _, _) {
                    // 徽章行 + “成就”小节标题 + 成就行
                    final ach = AchievementCenter.instance;
                    return ListView(
                      controller: scrollCtrl,
                      children: [
                        for (final w in wall) _badgeTile(call, w.honor, w.owned),
                        const SizedBox(height: 8),
                        Row(children: const [
                          Icon(Icons.emoji_events_outlined, size: 15, color: Color(0xFF9AA3B7)),
                          SizedBox(width: 6),
                          Text('成就墙',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6A7590))),
                          SizedBox(width: 8),
                          Expanded(
                              child: Divider(color: Color(0xFFE4E8F1), height: 1)),
                        ]),
                        const SizedBox(height: 10),
                        for (final a in AchievementCenter.all)
                          _achievementTile(a, ach.isUnlocked(a.key)),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              ),
            ]);
          },
        ),
      ]),
    );
  }
}

/// 单行徽章（固定 72 高 icon 46 框，统一样式；点亮可点开专属卡）
Widget _badgeTile(String call, Honor h, bool owned) {
  final c = owned ? h.color : const Color(0xFFC2CAD8);
  final col = owned ? h.color : const Color(0xFFAEB7C7);
  return GestureDetector(
    onTap: owned ? () => openMemberCard(call) : null,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: owned ? c.withValues(alpha: 0.35) : const Color(0xFFEBEEF5)),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: owned ? c.withValues(alpha: 0.13) : const Color(0xFFF0F2F7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(owned ? h.icon : Icons.lock_rounded, color: col, size: 23),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: owned ? const Color(0xFF1B253C) : const Color(0xFF98A2B8))),
            const SizedBox(height: 3),
            Text(owned ? h.desc : '未点亮',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: owned ? const Color(0xFF68748F) : const Color(0xFFB4BCCB))),
          ]),
        ),
        const SizedBox(width: 10),
        if (owned)
          const Icon(Icons.open_in_new_rounded,
              size: 16, color: Color(0xFFAAB4C6))
        else
          const Icon(Icons.circle_outlined, color: Color(0xFFD5DAE5), size: 18),
      ]),
    ),
  );
}


/// 成就行：已解锁点亮（图标+标题+说明），未解锁灰显锁
Widget _achievementTile(Achievement a, bool unlocked) {
  final Color c = unlocked ? a.color : const Color(0xFFC2CAD8);
  final Color col = unlocked ? a.color : const Color(0xFFAEB7C7);
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: unlocked ? c.withValues(alpha: 0.35) : const Color(0xFFEBEEF5)),
    ),
    child: Row(children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: unlocked ? c.withValues(alpha: 0.13) : const Color(0xFFF0F2F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(unlocked ? a.icon : Icons.lock_rounded, color: col, size: 23),
      ),
      const SizedBox(width: 13),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: unlocked ? const Color(0xFF1B253C) : const Color(0xFF98A2B8))),
          const SizedBox(height: 3),
          Text(a.desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: unlocked ? const Color(0xFF68748F) : const Color(0xFFB4BCCB))),
        ]),
      ),
      const SizedBox(width: 10),
      if (unlocked)
        const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF7FC98A))
      else
        const Icon(Icons.circle_outlined, color: Color(0xFFD5DAE5), size: 18),
    ]),
  );
}
