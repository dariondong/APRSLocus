import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'achievements.dart';
import 'honor_wall_page.dart';
import 'l10n/app_localizations.dart';

/// ─── APRSlocus 荣誉徽章体系 ───
/// 一个呼号可拥有多个称号徽章；徽章定义/授予/优先徽章均由官网 members.json 维护。
const String kMembersJsonUrl = 'https://aprslocus.theez.top/members.json';

/// 当前界面语言 → 荣誉/成就/赞助文案语言键（'zh' / 'zh-TW' / 'en'）。
///
/// 荣誉、成就、赞助墙的文案目前**只维护 zh / zh-TW / en 三套**（它们由
/// members.json / sponsors.json 下发，不在 l10n 的 ARB 里）。
/// 日语、印尼语等其它语言**统一使用英文**，而不是回落中文。
String honorLangOf(BuildContext context) {
  final l = Localizations.maybeLocaleOf(context);
  if (l == null) return 'zh';
  if (l.languageCode == 'zh') {
    final tw = l.countryCode == 'TW' ||
        l.scriptCode == 'Hant' ||
        l.toString().toLowerCase().contains('tw');
    return tw ? 'zh-TW' : 'zh';
  }
  // 只认 en；ja / id 等其余语言一律走英文
  return 'en';
}
const String kMemberCardBase = 'https://aprslocus.theez.top/member-card.html';

/// 单个徽章
class Honor {
  final String key;
  /// 中文基准名（兼容旧调用与旧缓存；多语言请用 [labelOf]）
  final String label;
  /// 中文基准描述（兼容旧调用与旧缓存；多语言请用 [descOf]）
  final String desc;
  final Color color;
  final IconData icon;
  /// 在线定义可携带的图标名（members.json honors[].icon），无则按 key 映射
  final String? iconName;
  /// 三语名称 / 描述（key: zh / zh-TW / en）。
  /// 可选：未提供时 [labelOf] / [descOf] 回落到 [label] / [desc]（中文）。
  final Map<String, String>? labels;
  final Map<String, String>? descs;

  const Honor(this.key, this.label, this.desc, this.color, this.icon,
      {this.iconName, this.labels, this.descs});

  /// 指定语言下的徽章名。
  /// 回落顺序：该语言 → **英文** → 中文基准（ja/id 无专属文案时取英文）。
  String labelOf(String lang) => labels?[lang] ?? labels?['en'] ?? label;

  /// 指定语言下的徽章描述。
  /// 回落顺序：该语言 → **英文** → 中文基准。
  String descOf(String lang) => descs?[lang] ?? descs?['en'] ?? desc;

  /// 图标名 → Material 图标（key 与 members.json honors[].icon 共用同一命名空间）
  static const Map<String, IconData> iconMap = {
    'kaishan': Icons.terrain_rounded,
    'developer': Icons.code_rounded,
    'earlyMember': Icons.workspace_premium_rounded,
    'mostBrain': Icons.psychology_rounded,
    'firstFix': Icons.military_tech_rounded,
    'jadeGift': Icons.card_giftcard_rounded,
    'sower': Icons.eco_rounded,
    'iSelfReliant': Icons.terminal_rounded, // 亲手编译
  };

  static IconData iconFor(String key) =>
      iconMap[key] ?? Icons.emoji_events_rounded;

  /// 在线定义可带 icon 字段（可选）：映射表命中用之，未命中回退按 key 映射
  static IconData iconForName(String? name, String key) => name == null
      ? iconFor(key)
      : (iconMap[name] ?? iconFor(key));
}

/// 徽章全集本地兜底展示顺序（联网后以 members.json honors 键序优先）
const List<String> kHonorOrder = [
  'kaishan',
  'developer',
  'earlyMember',
  'mostBrain',
  'firstFix',
  'jadeGift',
  'sower',
  'iSelfReliant',
];

/// 当前全量展示顺序：优先在线定义键序（members.json honors 书写顺序），
/// 未加载/缺失时回退本地 kHonorOrder；确保在线新增徽章无需发版即可上墙。
List<String> get displayHonorKeys {
  final keys = <String>[];
  for (final k in _honorDefs.keys) {
    if (!keys.contains(k)) keys.add(k);
  }
  for (final k in kHonorOrder) {
    if (!keys.contains(k)) keys.add(k);
  }
  return keys;
}

/// 默认徽章定义（联网兜底）
final Map<String, Honor> _defaultHonorDefs = {
  // 三语文案与官网 members.json 保持一致（离线兜底）
  'kaishan': const Honor('kaishan',
      '开山', '群山之始，你我曾一同点亮第一座灯塔；山高水长，此呼号为证。',
      Color(0xFFE67E22), Icons.terrain_rounded,
      labels: {
        'zh': '开山',
        'zh-TW': '開山',
        'en': 'Founding pioneer',
      },
      descs: {
        'zh': '群山之始，你我曾一同点亮第一座灯塔；山高水长，此呼号为证。',
        'zh-TW': '群山之始，你我曾一同點亮第一座燈塔；山高水長，此呼號為證。',
        'en': 'Where the peaks begin — we lit the first beacon together; the callsign bears witness across the hills.',
      },
      iconName: 'kaishan'),
  // 三语文案与官网 members.json 保持一致（离线兜底）
  'developer': const Honor('developer',
      '开发人员', '以代码为桨、翻译为桥，一砖一瓦把 APRSlocus 推向更远的频率。',
      Color(0xFF1D6FF2), Icons.code_rounded,
      labels: {
        'zh': '开发人员',
        'zh-TW': '開發人員',
        'en': 'Developer',
      },
      descs: {
        'zh': '以代码为桨、翻译为桥，一砖一瓦把 APRSlocus 推向更远的频率。',
        'zh-TW': '以程式為槳、翻譯為橋，一磚一瓦把 APRSlocus 推向更遠的頻率。',
        'en': 'Oars of code and bridges of translation — brick by brick, tuned APRSlocus to farther frequencies.',
      },
      iconName: 'developer'),
  // 三语文案与官网 members.json 保持一致（离线兜底）
  'earlyMember': const Honor('earlyMember',
      '早期成员', '在最朦胧的电波里守候回响，陪它从微弱信号长成清晰呼号。',
      Color(0xFFB08A34), Icons.workspace_premium_rounded,
      labels: {
        'zh': '早期成员',
        'zh-TW': '早期成員',
        'en': 'Early member',
      },
      descs: {
        'zh': '在最朦胧的电波里守候回响，陪它从微弱信号长成清晰呼号。',
        'zh-TW': '在最朦朧的電波裡守候迴響，陪它從微弱訊號長成清晰呼號。',
        'en': 'Kept watch in the faintest signals, growing with it from a whisper to a clear call.',
      },
      iconName: 'earlyMember'),
  // 三语文案与官网 members.json 保持一致（离线兜底）
  'mostBrain': const Honor('mostBrain',
      '最强大脑', '隐藏成就：于无声处托举算力洪流——为项目点亮超半数的光。',
      Color(0xFF0EA5C4), Icons.psychology_rounded,
      labels: {
        'zh': '最强大脑',
        'zh-TW': '最強大腦',
        'en': 'Brightest mind',
      },
      descs: {
        'zh': '隐藏成就：于无声处托举算力洪流——为项目点亮超半数的光。',
        'zh-TW': '隱藏成就：於無聲處托舉算力洪流——為專案點亮超過半數的光。',
        'en': 'Hidden: silently channeled the tide of compute — lighting more than half the project\'s sky.',
      },
      iconName: 'mostBrain'),
  // 三语文案与官网 members.json 保持一致（离线兜底）
  'firstFix': const Honor('firstFix',
      'FIRST FIX · 至高荣誉', 'APRSlocus 1.7.0 开放 —— 完成全部成就后向开发团队申请，获颁至高荣誉。',
      Color(0xFFC9A227), Icons.military_tech_rounded,
      labels: {
        'zh': 'FIRST FIX · 至高荣誉',
        'zh-TW': 'FIRST FIX · 至高榮譽',
        'en': 'FIRST FIX · Supreme Honor',
      },
      descs: {
        'zh': 'APRSlocus 1.7.0 开放 —— 完成全部成就后向开发团队申请，获颁至高荣誉。',
        'zh-TW': 'APRSlocus 1.7.0 開放 —— 完成全部成就後向開發團隊申請，獲頒至高榮譽。',
        'en': 'Opening in APRSlocus 1.7.0 — complete every achievement, then apply to the dev team for this supreme honor.',
      },
      iconName: 'firstFix'),
  // 三语文案与官网 members.json 保持一致（离线兜底）
  'jadeGift': const Honor('jadeGift',
      '赠我以琼琚', '承君厚赠，藏之于心；唯有砥砺，以报清音。',
      Color(0xFF0EA5B7), Icons.card_giftcard_rounded,
      labels: {
        'zh': '赠我以琼琚',
        'zh-TW': '贈我以瓊琚',
        'en': 'Gifted with Jade',
      },
      descs: {
        'zh': '承君厚赠，藏之于心；唯有砥砺，以报清音。',
        'zh-TW': '承君厚贈，藏之於心；唯有砥礪，以報清音。',
        'en': 'Your gift is treasured in my heart; the only return I can offer is to strive, and answer your kindness with good work.',
      },
      iconName: 'jadeGift'),
  // 三语文案与官网 members.json 保持一致（离线兜底）
  'sower': const Honor('sower',
      '播种', '在旷野埋下种子，等待遍地开花。',
      Color(0xFF2E9E5B), Icons.eco_rounded,
      labels: {
        'zh': '播种',
        'zh-TW': '播種',
        'en': 'Sower',
      },
      descs: {
        'zh': '在旷野埋下种子，等待遍地开花。',
        'zh-TW': '在曠野埋下種子，等待遍地開花。',
        'en': 'Sowing seeds in the open field — waiting for blossoms everywhere.',
      },
      iconName: 'sower'),
  // 三语文案与官网 members.json 保持一致（离线兜底）
  'iSelfReliant': const Honor('iSelfReliant',
      'i力更生', '不求现成的果实，亲手编译一粒种子，让它在苹果的园子里长成一座信标。',
      Color(0xFF8E8E93), Icons.terminal_rounded,
      labels: {
        'zh': 'i力更生',
        'zh-TW': 'i力更生',
        'en': 'iSelf-Reliant',
      },
      descs: {
        'zh': '不求现成的果实，亲手编译一粒种子，让它在苹果的园子里长成一座信标。',
        'zh-TW': '不求現成的果實，親手編譯一粒種子，讓它在蘋果的園子裡長成一座信標。',
        'en': 'Rather than wait for ripened fruit, they compiled the seed themselves — and let it grow into a beacon in Apple’s orchard.',
      },
      iconName: 'iSelfReliant'),
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
    'BG4LZY': ['earlyMember'],
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
    'BG4LZY': 'earlyMember',
    'BA3RZL': 'earlyMember',
  };
}

List<String> memberHonorKeys(String call) {
  final base = _base(call);
  final got = _honorsCache[base] ?? const <String>[];
  final set = got.toSet();
  // FIRST FIX：在线授勋名单命中即拥有（作为徽章展示/可选主页徽章）
  if (AchievementCenter.instance.isFirstFixHolder(base)) set.add('firstFix');
  return displayHonorKeys.where(set.contains).toList();
}

bool hasAnyHonor(String call) => memberHonorKeys(call).isNotEmpty;

List<Honor> honorsOf(String call) =>
    memberHonorKeys(call).map((k) => _honorDefs[k]).whereType<Honor>().toList();

List<({Honor honor, bool owned})> allHonorsWithState(String call) {
  final owned = memberHonorKeys(call).toSet();
  return [
    for (final k in displayHonorKeys)
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
        // 名称与描述都取三语（zh 为基准，缺失回落 zh）
        String pick(Map src, String lang, String fb) =>
            (src[lang] ?? fb).toString();
        final zh = pick(v, 'zh', k.toString());
        final dm = v['desc'];
        final dmap = dm is Map ? dm : const {};
        final descZh = pick(dmap, 'zh', '');
        m[k.toString()] = Honor(k.toString(), zh, descZh,
            _parseColor(v['color']),
            Honor.iconForName(v['icon']?.toString(), k.toString()),
            iconName: v['icon']?.toString(),
            labels: {
              'zh': zh,
              'zh-TW': pick(v, 'zh-TW', zh),
              'en': pick(v, 'en', zh),
            },
            descs: {
              'zh': descZh,
              'zh-TW': pick(dmap, 'zh-TW', descZh),
              'en': pick(dmap, 'en', descZh),
            });
      }
    });
    if (m.isNotEmpty) {
      // 在线定义键序优先；本地兜底中未被覆盖的定义追加在尾部
      for (final e in _defaultHonorDefs.entries) {
        m.putIfAbsent(e.key, () => e.value);
      }
      _honorDefs = m;
    }
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
      // 三语一并持久化，离线也能按界面语言显示
      'label': h.label,
      'labelZhTw': h.labelOf('zh-TW'),
      'labelEn': h.labelOf('en'),
      'desc': h.desc,
      'descZhTw': h.descOf('zh-TW'),
      'descEn': h.descOf('en'),
      'color': '#${h.color.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'icon': h.iconName ?? k,
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
            String t(String key, String fb) => (v[key] ?? fb).toString();
            final lzh = t('label', k.toString());
            final dzh = t('desc', '');
            dm[k.toString()] = Honor(
              k.toString(),
              lzh,
              dzh,
              _parseColor(v['color']),
              Honor.iconForName(v['icon']?.toString(), k.toString()),
              iconName: v['icon']?.toString(),
              labels: {
                'zh': lzh,
                'zh-TW': t('labelZhTw', lzh),
                'en': t('labelEn', lzh),
              },
              descs: {
                'zh': dzh,
                'zh-TW': t('descZhTw', dzh),
                'en': t('descEn', dzh),
              },
            );
          }
        });
        if (dm.isNotEmpty) {
          // 旧缓存可能缺新徽章定义；补本地兜底，保证新徽章离线也能显示
          for (final e in _defaultHonorDefs.entries) {
            dm.putIfAbsent(e.key, () => e.value);
          }
          _honorDefs = dm;
        }
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
    // 徽章来源：members.json 荣誉 + FIRST FIX 在线授勋，两处变更都刷新
    return ListenableBuilder(
      listenable: Listenable.merge(
          [memberListVersion, AchievementCenter.instance.version]),
      builder: (context, _) {
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
              Text(
                  pri?.labelOf(honorLangOf(context)) ??
                      AppLocalizations.of(context).badgeFallback,
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
          Text(AppLocalizations.of(context).badgeWall,
              style: const TextStyle(
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
              Text(
                  AppLocalizations.of(context)
                      .honoredBadges('$ownedCount', '${wall.length}'),
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF98A2B8))),
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
                        for (final w in wall)
                          _badgeTile(context, call, w.honor, w.owned),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.emoji_events_outlined,
                              size: 15, color: Color(0xFF9AA3B7)),
                          const SizedBox(width: 6),
                          Text(AppLocalizations.of(context).achievementWall,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6A7590))),
                          SizedBox(width: 8),
                          Expanded(
                              child: Divider(color: Color(0xFFE4E8F1), height: 1)),
                        ]),
                        const SizedBox(height: 10),
                        for (final a in AchievementCenter.all)
                          _achievementTile(context, a, ach.isUnlocked(a.key)),
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
///
/// 顶层函数没有 `context`，必须显式传入（否则 analyze 报 undefined_identifier）
Widget _badgeTile(BuildContext context, String call, Honor h, bool owned) {
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
            Text(h.labelOf(honorLangOf(context)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: owned ? const Color(0xFF1B253C) : const Color(0xFF98A2B8))),
            const SizedBox(height: 3),
            Text(
                owned
                    ? h.descOf(honorLangOf(context))
                    : AppLocalizations.of(context).notLit,
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
Widget _achievementTile(
    BuildContext context, Achievement a, bool unlocked) {
  final lang = honorLangOf(context);
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
          Text(a.titleOf(lang),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: unlocked ? const Color(0xFF1B253C) : const Color(0xFF98A2B8))),
          const SizedBox(height: 3),
          Text(a.descOf(lang),
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
