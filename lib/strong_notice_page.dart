import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'state.dart';
import 'strong_notice.dart';
import 'theme.dart';
import 'widgets.dart';

/// 强提醒的整页：打开应用时直接盖住主界面，读完那一条才放人进去。
///
/// 为什么用整页而不是对话框：这条东西的意义就是「不看不行」，而对话框会被
/// 点外面关掉、被返回键跳过。整页把出口收成一个按钮，也顺手把「这一版要说
/// 什么」摆成一张能读完的板面（正文再长也自己滚，按钮永远在底下）。
///
/// 内容全部来自官网那份 JSON（见 `lib/strong_notice.dart`），这里只管排版：
/// 级别决定那一道颜色，其余用应用自己的 token，深色浅色都跟着走。
class StrongNoticePage extends StatelessWidget {
  final AppState state;
  final StrongNotice notice;

  const StrongNoticePage({
    super.key,
    required this.state,
    required this.notice,
  });

  Color get _accent => switch (notice.level) {
        'critical' => C.red,
        'warn' => C.orange,
        _ => C.blue,
      };

  Color get _accentBg => switch (notice.level) {
        'critical' => C.redBg,
        'warn' => C.orangeBg,
        _ => C.blueBg,
      };

  IconData get _icon => switch (notice.level) {
        'critical' => Icons.report_gmailerrorred_rounded,
        'warn' => Icons.campaign_rounded,
        _ => Icons.notifications_active_rounded,
      };

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _close(BuildContext context) {
    state.dismissStrongNotice(notice);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // hard：返回键不关（只能点那个按钮）。软的那种允许返回键，方便一把就想看
      // 一眼的人 —— 但**软也得点一下**才走，不做「点外面自动消失」。
      canPop: !notice.hard,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close(context);
      },
      child: Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _accentBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_icon, size: 22, color: _accent),
                ),
                const SizedBox(height: 16),
                Text(
                  notice.title,
                  style: ts(22, w: FontWeight.w800, h: 1.35),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(notice.body, style: ts(14, h: 1.75)),
                  ),
                ),
                const SizedBox(height: 12),
                for (final a in notice.actions) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (a.url.isEmpty) {
                          _close(context);
                          return;
                        }
                        await _open(a.url);
                      },
                      child: Text(
                        a.label,
                        style: ts(14, c: Colors.white, w: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.slate,
                      side: BorderSide(color: C.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _close(context),
                    child: Text(S.of(context).gotIt, style: ts(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
