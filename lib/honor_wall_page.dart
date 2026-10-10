import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'achievements.dart';
import 'early_member.dart';
import 'models.dart';
import 'widgets.dart';
import 'material.dart';

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
      backgroundColor: C.bg,
      appBar: MaterialAppBar(
        AppBar(
          backgroundColor: C.surfaceFillStrong,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: C.ink,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Row(
            children: [
              Text(
                base,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  fontFamilyFallback: kCjkFallback,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· ${S.of(context).honorWall}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: C.slate,
                ),
              ),
            ],
          ),
          centerTitle: false,
        ),
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
                    color: C.white,
                    borderRadius: BorderRadius.circular(24),
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
                        color: C.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: C.border),
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
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                    fontFamilyFallback: kCjkFallback,
                                    letterSpacing: 1.5)),
                            const SizedBox(height: 4),
                            Text(
                                showAchievements
                                    ? '${S.of(context).honoredBadges('$ownedCount', '${wall.length}')}'
                                      ' · '
                                      '${S.of(context).achievementsProgress('${AchievementCenter.instance.unlockedCount}', '${AchievementCenter.all.length}')}'
                                    : S.of(context).honoredBadges(
                                        '$ownedCount', '${wall.length}'),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: C.grey)),
                          ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                // 账号荣誉区
                Row(children: [
                  Icon(Icons.workspace_premium_rounded,
                      size: 16, color: C.yellow),
                  const SizedBox(width: 6),
                  Text(S.of(context).accountHonors,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: C.slate)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Divider(color: C.border, height: 1)),
                ]),
                const SizedBox(height: 12),
                for (final w in wall)
                  _honorTile(context, call, w.honor, w.owned),
                if (showAchievements) ...[
                  const SizedBox(height: 18),
                  // 成就区（仅查看自己时显示）
                  Row(children: [
                    Icon(Icons.emoji_events_outlined,
                        size: 16, color: C.orange),
                    const SizedBox(width: 6),
                    Text(S.of(context).achievementsSection,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: C.slate)),
                    SizedBox(width: 8),
                    Expanded(
                        child: Divider(color: C.border, height: 1)),
                  ]),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<int>(
                    valueListenable: AchievementCenter.instance.version,
                    builder: (context, _, _) => Column(children: [
                      for (final a in AchievementCenter.all)
                        _achTile(context, a,
                            AchievementCenter.instance.isUnlocked(a.key)),
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
            errorBuilder: (_, __, ___) => Icon(Icons.place_rounded,
                size: 24, color: C.ink));
      }
    } catch (_) {}
    if (img == null) {
      final base = call.contains('-') ? call.substring(0, call.indexOf('-')) : call;
      return Text(base[0],
          style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: C.ink,
              fontFamily: 'monospace',
              fontFamilyFallback: kCjkFallback));
    }
    return img;
  }

  // 注意：本类为 StatelessWidget，自身没有 `context` getter，
  // 故必须把 context 作为参数显式传入（否则 analyze 报 undefined_identifier）
  Widget _honorTile(
      BuildContext context, String call, Honor h, bool owned) {
    final lang = honorLangOf(context);
    final c = owned ? h.color : C.greyLight;
    final col = owned ? h.color : C.grey;
    return GestureDetector(
      // 点已点亮徽章 → 打开官网徽章专属页 badge.html?honor=xxx
      onTap: owned ? () => openBadgePage(h.key) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: owned ? c.withValues(alpha: 0.35) : C.border),
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: owned ? c.withValues(alpha: 0.13) : C.greyBg,
              borderRadius: BorderRadius.circular(16),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: owned ? C.ink : C.grey)),
              const SizedBox(height: 3),
              Text(owned ? h.descOf(lang) : S.of(context).notLit,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: owned ? C.slate : C.greyLight)),
              // 获得条件（怎么拿到这枚徽章）—— 未点亮时是最有用的信息，
              // 已点亮时也一并展示（与官网 badge.html 口径一致）。
              // 无 criteria 时整行隐藏，不显示空白占位。
              if (h.criteriaOf(lang).isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  S.of(context).honorCriteriaLine(h.criteriaOf(lang)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    // 单一颜色兼顾两种状态：
                    // 已点亮时比 desc 淡（层级更低）；
                    // 未点亮时比「未点亮」深（它是可执行的信息，该更显眼）。
                    color: C.grey,
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(width: 10),
          if (owned)
            Icon(Icons.open_in_new_rounded,
                size: 16, color: C.grey)
          else
            Icon(Icons.circle_outlined, color: C.borderStrong, size: 18),
        ]),
      ),
    );
  }

  Widget _achTile(BuildContext context, Achievement a, bool unlocked) {
    final lang = honorLangOf(context);
    final Color c = unlocked ? a.color : C.greyLight;
    final Color col = unlocked ? a.color : C.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: unlocked ? c.withValues(alpha: 0.35) : C.border),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: unlocked ? c.withValues(alpha: 0.13) : C.greyBg,
            borderRadius: BorderRadius.circular(16),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: unlocked ? C.ink : C.grey)),
            const SizedBox(height: 3),
            Text(a.descOf(lang),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: unlocked ? C.slate : C.greyLight)),
          ]),
        ),
        const SizedBox(width: 10),
        if (unlocked)
          Icon(Icons.check_circle_rounded,
              size: 18, color: C.green)
        else
          Icon(Icons.circle_outlined, color: C.borderStrong, size: 18),
      ]),
    );
  }
}
