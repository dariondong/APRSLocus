import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// ─── APRSlocus 荣誉成员（DEVELOPER / EARLY MEMBER）───
///
/// 名单默认内置一份兜底；启动 / 刷新时会从官网 members.json 拉取最新，
/// 解析后覆盖。members.json 结构：
///   developers / earlyMembers: 元素可为 {call, who:{...}, ...} 或纯呼号字符串
/// 名单归属（开发 / 早期成员）由官网 JSON 维护，无需发版即可更新。
const String kMembersJsonUrl = 'https://aprslocus.theez.top/members.json';
const String kMemberCardBase = 'https://aprslocus.theez.top/member-card.html';

/// 默认内置名单（联网失败 / 首次加载前兜底，与官网 json 默认一致）
const List<String> _defaultDevelopers = [
  'BG7LZQ', // 作者
  'BG2HCB', // 代码优化
  'BA4UAX', // 繁体翻译
  'BD3QID', // 英文翻译
];
const List<String> _defaultEarly = [
  'BG7PGW', // 测试·赞助
  'BG7LMW', // 测试
  'BG7OSL', // 测试
  'imThree', // 反馈
  'BA3RZL', // 算力
];

/// 运行时名单（联网更新后替换）
List<String> _developers = List.of(_defaultDevelopers);
List<String> _earlyMembers = List.of(_defaultEarly);
int _loadSeq = 0;

/// 徽标重建通知
final ValueNotifier<int> memberListVersion = ValueNotifier<int>(0);

/// 取基呼号（去 SSID 后缀，转大写）
String _base(String call) => call.trim().toUpperCase().split('-').first;

enum MemberKind { none, developer, early }

/// 判断呼号荣誉类型（开发 / 早期成员 / 无）
MemberKind memberKindOf(String call) {
  final base = _base(call);
  for (final c in _developers) {
    if (c.toUpperCase() == base) return MemberKind.developer;
  }
  for (final c in _earlyMembers) {
    if (c.toUpperCase() == base) return MemberKind.early;
  }
  return MemberKind.none;
}

String _normalize(String s) => s.trim().toUpperCase();

/// 从 json 元素提取呼号：兼容字符串或 {call}
String _callOf(dynamic it) {
  if (it is String) return it;
  if (it is Map) {
    final c = it['call'];
    if (c is String) return c;
  }
  return '';
}

/// 从官网拉取并合并名单（幂等；失败静默保留现有/默认）
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
      final dev = (d['developers'] as List?) ?? const [];
      final early = (d['earlyMembers'] as List?) ?? const [];
      if (dev.isEmpty && early.isEmpty) return; // 非法内容忽略
      _developers = dev.map(_callOf).where((s) => s.isNotEmpty).map(_normalize).toList();
      _earlyMembers = early.map(_callOf).where((s) => s.isNotEmpty).map(_normalize).toList();
      memberListVersion.value++;
      // 缓存便于离线读取
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString('membersDev', jsonEncode(_developers));
        await p.setString('membersEarly', jsonEncode(_earlyMembers));
      } catch (_) {}
    } finally {
      client.close(force: true);
    }
  } catch (_) {}
}

/// 首次加载：读缓存 → 若空用默认 → 后台联网刷新
Future<void> ensureMembersLoaded() async {
  if (_loadSeq > 0) return;
  _loadSeq++;
  try {
    final p = await SharedPreferences.getInstance();
    final dev = p.getString('membersDev');
    final early = p.getString('membersEarly');
    if (dev != null && early != null) {
      try {
        _developers =
            (jsonDecode(dev) as List).cast<String>().map(_normalize).toList();
        _earlyMembers = (jsonDecode(early) as List)
            .cast<String>()
            .map(_normalize)
            .toList();
      } catch (_) {}
    }
  } catch (_) {}
  unawaited(refreshMembers());
}

/// 打开该呼号的专属会员卡网页（浏览器）
Future<void> openMemberCard(String call) async {
  final url = '$kMemberCardBase?call=${_base(call)}';
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// 荣誉徽标：分「开发人员」/「早期成员」两类，点击打开专属卡页。
class HonorBadge extends StatelessWidget {
  final String call;
  final bool compact;
  const HonorBadge(this.call, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: memberListVersion,
      builder: (context, _, _) {
        final kind = memberKindOf(call);
        if (kind == MemberKind.none) return const SizedBox.shrink();
        final developer = kind == MemberKind.developer;
        final Color c =
            developer ? const Color(0xFF1D6FF2) : const Color(0xFFB08A34);
        final Color bg =
            developer ? const Color(0xFFE8F0FE) : const Color(0xFFFFF6E0);
        final String label = developer ? '开发人员' : '早期成员';
        final IconData icon =
            developer ? Icons.code_rounded : Icons.workspace_premium_rounded;
        return GestureDetector(
          onTap: () => openMemberCard(call),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 9,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.withValues(alpha: 0.55)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: compact ? 12 : 13, color: c),
              if (!compact) ...[
                SizedBox(width: 3),
                Text(label, style: ts(9.5, c: c, w: FontWeight.w800)),
              ],
            ]),
          ),
        );
      },
    );
  }
}
