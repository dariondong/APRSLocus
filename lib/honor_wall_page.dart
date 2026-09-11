import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'achievements.dart';
import 'early_member.dart';
import 'models.dart';
import 'widgets.dart';

/// 打开官网徽章专属页（badge.html?honor=key）
Future<void> openBadgePage(String honorKey) async {
  try {
    await launchUrl(
        Uri.parse('https://aprslocus.theez.top/badge.html?honor=$honorKey'),
        mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// ─── 荣誉墙（专属页面）：呼号 + 徽章墙 + 成就墙 ───
class HonorWallPage extends StatelessWidget {
  final String call;
  final String? symbol;
  final String? symbolTable;
  /// 是否展示“我的成就”（仅查看自己呼号时 true；查看他人只显示徽章荣誉）
  final bool showAchievements;
  const HonorWallPage(this.call,
      {super.key, this.symbol, this.symbolTable,
      this.showAchievements = true});

  @override
  Widget build(BuildContext context) {
    final base =
        call.contains('-') ? call.substring(0, call.indexOf('-')) : call;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F6FB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1B253C)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(children: [
          Text(base,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 1.2)),
          const SizedBox(width: 8),
          Text('· ${S.of(context).honorWall}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF98A2B8))),
        ]),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: memberListVersion,
          builder: (context, _, _) {
            final wall = allHonorsWithState(call);
            final ownedCount = wall.where((w) => w.owned).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 18,
                          offset: Offset(0, 6)),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE4E8F1)),
                      ),
                      child: Center(child: _userAvatar()),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(base,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                    letterSpacing: 1.5)),
                            const SizedBox(height: 4),
                            Text(
                                showAchievements
                                    ? '${S.of(context).honoredBadges('$ownedCount', '${wall.length}')}'
                                      ' · '
                                      '${S.of(context).achievementsProgress('${AchievementCenter.instance.unlockedCount}', '${AchievementCenter.all.length}')}'
                                    : S.of(context).honoredBadges(
                                        '$ownedCount', '${wall.length}'),
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF98A2B8))),
                          ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                // 账号荣誉区
                Row(children: [
                  const Icon(Icons.workspace_premium_rounded,
                      size: 16, color: Color(0xFFB08A34)),
                  const SizedBox(width: 6),
                  Text(S.of(context).accountHonors,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4B5873))),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Divider(color: Color(0xFFE4E8F1), height: 1)),
                ]),
                const SizedBox(height: 12),
                for (final w in wall) _honorTile(call, w.honor, w.owned),
                if (showAchievements) ...[
                  const SizedBox(height: 18),
                  // 成就区（仅查看自己时显示）
                  Row(children: [
                    const Icon(Icons.emoji_events_outlined,
                        size: 16, color: Color(0xFFE67E22)),
                    const SizedBox(width: 6),
                    Text(S.of(context).achievementsSection,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4B5873))),
                    SizedBox(width: 8),
                    Expanded(
                        child: Divider(color: Color(0xFFE4E8F1), height: 1)),
                  ]),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<int>(
                    valueListenable: AchievementCenter.instance.version,
                    builder: (context, _, _) => Column(children: [
                      for (final a in AchievementCenter.all)
                        _achTile(a, AchievementCenter.instance.isUnlocked(a.key)),
                    ]),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// 头像：使用用户当前 APRS 符号 PNG（无符号才回退首字母）
  Widget _userAvatar() {
    final sym = symbol ?? '>';
    final table = symbolTable ?? '/';
    Widget? img;
    try {
      final asset = AprsSym.iconAsset(table, sym);
      if (asset != null) {
        img = Image.asset(asset,
            width: 40, height: 40, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.place_rounded,
                size: 24, color: Color(0xFF14203A)));
      }
    } catch (_) {}
    if (img == null) {
      final base = call.contains('-') ? call.substring(0, call.indexOf('-')) : call;
      return Text(base[0],
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF14203A),
              fontFamily: 'monospace'));
    }
    return img;
  }

  Widget _honorTile(String call, Honor h, bool owned) {
    final lang = honorLangOf(context);
    final c = owned ? h.color : const Color(0xFFC2CAD8);
    final col = owned ? h.color : const Color(0xFFAEB7C7);
    return GestureDetector(
      // 点已点亮徽章 → 打开官网徽章专属页 badge.html?honor=xxx
      onTap: owned ? () => openBadgePage(h.key) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
            child:
                Icon(owned ? h.icon : Icons.lock_rounded, color: col, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.labelOf(lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: owned
                          ? const Color(0xFF1B253C)
                          : const Color(0xFF98A2B8))),
              const SizedBox(height: 3),
              Text(owned ? h.descOf(lang) : S.of(context).notLit,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: owned
                          ? const Color(0xFF68748F)
                          : const Color(0xFFB4BCCB))),
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

  Widget _achTile(Achievement a, bool unlocked) {
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
            color:
                unlocked ? c.withValues(alpha: 0.35) : const Color(0xFFEBEEF5)),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: unlocked
                ? c.withValues(alpha: 0.13)
                : const Color(0xFFF0F2F7),
            borderRadius: BorderRadius.circular(14),
          ),
          child:
              Icon(unlocked ? a.icon : Icons.lock_rounded, color: col, size: 23),
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
                    color: unlocked
                        ? const Color(0xFF1B253C)
                        : const Color(0xFF98A2B8))),
            const SizedBox(height: 3),
            Text(a.descOf(lang),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: unlocked
                        ? const Color(0xFF68748F)
                        : const Color(0xFFB4BCCB))),
          ]),
        ),
        const SizedBox(width: 10),
        if (unlocked)
          const Icon(Icons.check_circle_rounded,
              size: 18, color: Color(0xFF7FC98A))
        else
          const Icon(Icons.circle_outlined, color: Color(0xFFD5DAE5), size: 18),
      ]),
    );
  }
}
