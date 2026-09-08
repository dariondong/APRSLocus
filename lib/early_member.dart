import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// ─── APRSlocus 早期成员（FIRST MEMBER）───
/// 名单与官网纪念会员卡页 docs/member-card.html 保持一致。
const List<String> kEarlyMembers = [
  'BG7LZQ', // 作者 · 全栈
  'BG2HCB', // 清零 · 设置页优化
  'BA4UAX', // 繁体翻译
  'BD3QID', // 英文翻译·测试
  'BG7PGW', // 测试·赞助
  'BG7LMW', // 功能测试
  'BG7OSL', // 功能测试
  'imThree', // Bug 反馈
  'BA3RZL', // 算力支持
];

/// 官网纪念卡页：?call= 直达该成员专属卡
const String kMemberCardBase = 'https://aprslocus.theez.top/member-card.html';

/// 是否早期成员（忽略大小写；可传带 SSID 的完整呼号，自动取基呼号）
bool isEarlyMember(String call) {
  final base = call.trim().toUpperCase().split('-').first;
  for (final c in kEarlyMembers) {
    if (c.toUpperCase() == base) return true;
  }
  return false;
}

/// 打开该成员的专属会员卡网页（浏览器）
Future<void> openMemberCard(String call) async {
  final base = call.trim().toUpperCase().split('-').first;
  final url = '$kMemberCardBase?call=$base';
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    // 无法打开浏览器时静默
  }
}

/// 「早期成员」小徽标：呼号命中名单时显示，点击打开专属会员卡网页。
class EarlyMemberBadge extends StatelessWidget {
  final String call; // 呼号（可含 SSID）
  final bool compact; // 紧凑模式只显示徽章图标
  const EarlyMemberBadge(this.call, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (!isEarlyMember(call)) return const SizedBox.shrink();
    const gold = Color(0xFFB08A34);
    return GestureDetector(
      onTap: () => openMemberCard(call),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 9,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6E0),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: gold.withValues(alpha: 0.55)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.workspace_premium_rounded, size: compact ? 12 : 13, color: gold),
          if (!compact) ...[
            SizedBox(width: 3),
            Text(
              '早期成员',
              style: ts(9.5, c: gold, w: FontWeight.w800),
            ),
          ],
        ]),
      ),
    );
  }
}
