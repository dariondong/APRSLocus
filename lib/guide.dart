import 'package:flutter/material.dart';

import 'material.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// 功能引导：首次进入某个页面时显示的一张**小提示卡**。
///
/// 为什么要有：OOBE 只解决了「装完第一次怎么配」，而各功能页（设备链路、离线地图、
/// 日志导出）是**用着用着才会遇到**的 —— 用户第一次进这些页面时，屏幕上全是控件，
/// 没人告诉他「先点哪里」。这里给每页配一条一句话说明，看过就不再打扰。
///
/// 与「官网手册 / FAQ」的分工：这里是**入口级**的一句话，不是文档；细节仍然指向手册。
class Guide {
  /// 稳定 id。**它就是「已读」持久化的键** —— 发布后改 id 等于让所有用户重看一遍。
  final String id;
  final IconData icon;
  final Color color;
  /// 这页是干什么的
  final String title;
  /// 从哪下手（一到两句，不要写成功能清单）
  final String body;

  const Guide({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}

/// 全部引导。文案走 l10n，所以必须带 context 现取。
///
/// 加新引导的顺序：① 这里加一条（id 用驼峰短名）② tool/add_guide_l10n.py 里补
/// `guide<Id>Title` / `guide<Id>Body` 两键 × 6 语言 ③ 在页面里放
/// `GuideTipCard(guideId: ..., state: ...)`。
/// `tool/check_guides.py` 会核对这三件事一一对应。
List<Guide> allGuides(BuildContext context) {
  final t = S.of(context);
  return [
    Guide(
      id: 'home',
      icon: Icons.map_rounded,
      color: C.blue,
      title: t.guideHomeTitle,
      body: t.guideHomeBody,
    ),
    Guide(
      id: 'immersive',
      icon: Icons.fullscreen_rounded,
      color: C.indigo,
      title: t.guideImmersiveTitle,
      body: t.guideImmersiveBody,
    ),
    Guide(
      id: 'messages',
      icon: Icons.forum_rounded,
      color: C.blue,
      title: t.guideMessagesTitle,
      body: t.guideMessagesBody,
    ),
    Guide(
      id: 'device',
      icon: Icons.devices_other_rounded,
      color: C.indigo,
      title: t.guideDeviceTitle,
      body: t.guideDeviceBody,
    ),
    Guide(
      id: 'settings',
      icon: Icons.settings_rounded,
      color: C.slate,
      title: t.guideSettingsTitle,
      body: t.guideSettingsBody,
    ),
    Guide(
      id: 'offlineMap',
      icon: Icons.download_for_offline_rounded,
      color: C.green,
      title: t.guideOfflineMapTitle,
      body: t.guideOfflineMapBody,
    ),
    Guide(
      id: 'log',
      icon: Icons.receipt_long_rounded,
      color: C.slate,
      title: t.guideLogTitle,
      body: t.guideLogBody,
    ),
    Guide(
      id: 'backup',
      icon: Icons.backup_rounded,
      color: C.purple,
      title: t.guideBackupTitle,
      body: t.guideBackupBody,
    ),
    Guide(
      id: 'packets',
      icon: Icons.list_alt_rounded,
      color: C.purple,
      title: t.guidePacketsTitle,
      body: t.guidePacketsBody,
    ),
    Guide(
      id: 'stations',
      icon: Icons.format_list_bulleted_rounded,
      color: C.green,
      title: t.guideStationsTitle,
      body: t.guideStationsBody,
    ),
    Guide(
      id: 'trackHistory',
      icon: Icons.route_rounded,
      color: C.green,
      title: t.guideTrackHistoryTitle,
      body: t.guideTrackHistoryBody,
    ),
    Guide(
      id: 'theme',
      icon: Icons.palette_rounded,
      color: C.purple,
      title: t.guideThemeTitle,
      body: t.guideThemeBody,
    ),
    Guide(
      id: 'translate',
      icon: Icons.translate_rounded,
      color: C.cyan,
      title: t.guideTranslateTitle,
      body: t.guideTranslateBody,
    ),
    Guide(
      id: 'audio',
      icon: Icons.graphic_eq_rounded,
      color: C.cyan,
      title: t.guideAudioTitle,
      body: t.guideAudioBody,
    ),
    Guide(
      id: 'tncDevice',
      icon: Icons.settings_input_antenna_rounded,
      color: C.indigo,
      title: t.guideTncDeviceTitle,
      body: t.guideTncDeviceBody,
    ),
    Guide(
      id: 'pkwdwpl',
      icon: Icons.cable_rounded,
      color: C.green,
      title: t.guidePkwdwplTitle,
      body: t.guidePkwdwplBody,
    ),
  ];
}

/// 按 id 取一条引导；id 不存在时返回 null（不抛异常 —— 引导是**锦上添花**，
/// 缺一条不该让页面白屏）。
Guide? guideOf(BuildContext context, String id) {
  for (final g in allGuides(context)) {
    if (g.id == id) return g;
  }
  return null;
}

/// 首次进入该页时显示的小提示卡；已读（或本次已关掉）时**不占任何位置**。
class GuideTipCard extends StatelessWidget {
  final String guideId;
  final AppState state;
  /// 页面外侧边距（部分页面自己已经有 20 的 padding，就传 EdgeInsets.zero）
  final EdgeInsetsGeometry margin;

  const GuideTipCard({
    super.key,
    required this.guideId,
    required this.state,
    this.margin = const EdgeInsets.fromLTRB(12, 6, 12, 0),
  });

  @override
  Widget build(BuildContext context) {
    if (state.isGuideSeen(guideId)) return const SizedBox.shrink();
    final g = guideOf(context, guideId);
    if (g == null) return const SizedBox.shrink();
    return Padding(
      padding: margin,
      child: GuideCardView(
        guide: g,
        onClose: () => state.markGuideSeen(guideId),
      ),
    );
  }
}

/// 引导卡本体（不含「已读」状态）—— 首次进入的提示卡与「重看」弹层共用一套样子。
class GuideCardView extends StatelessWidget {
  final Guide guide;
  final VoidCallback? onClose;
  final bool showClose;

  const GuideCardView({
    super.key,
    required this.guide,
    this.onClose,
    this.showClose = true,
  });

  @override
  Widget build(BuildContext context) {
    // 刻意做得**小且安静**：它是「看一眼就知道该点哪」的提示，不是公告。
    // 早先那版用大面积彩色底 + 描边 + 右侧 × 图标，一页一个还算清楚，但页页都有
    // 就显得吵（用户反馈「小引导有点乱了」）—— 现在只留图标底托的颜色、底色压到 6%。
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        color: guide.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: guide.color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: guide.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(guide.icon, size: 15, color: guide.color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(guide.title, style: ts(12.5, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(guide.body, style: ts(11.5, c: C.slate, h: 1.45)),
              ],
            ),
          ),
          // 「知道了」比一个孤零零的 × 更好按，也把「关掉 = 看过」说清楚了
          if (showClose && onClose != null)
            TextButton(
              onPressed: onClose,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: guide.color,
              ),
              child: Text(
                S.of(context).guideGotIt,
                style: ts(11.5, c: guide.color, w: FontWeight.w700),
              ),
            )
          else
            const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// 全屏地图类页面（四角都是 HUD）用一次性弹层，**不浮卡片**。
///
/// 为什么这两种页面特殊：沉浸地图的四角全是控件（左上返回+定位、右侧一列按钮、
/// 左下信标倒计时、右下速度卡），任何浮卡片都会压住其中之一 —— 用户已经报过一次
/// 「地图页 UI 重叠」。这类页面进入时弹一次底部弹层，关掉即记为已看。
///
/// 用 `SizedBox.shrink()` 参与布局，所以直接丢进页面 Stack 里即可。
class GuideSheetOnce extends StatefulWidget {
  final String guideId;
  final AppState state;

  /// 当前页面是否真的在前台。
  ///
  /// 地图页在 `IndexedStack` 里（1.0 布局的五个 tab 一次全建、2.0 布局地图当底），
  /// 不带这个开关的话，用户刚启动应用、还停在别的 tab 上时弹层就会抢着冒出来。
  final bool enabled;

  const GuideSheetOnce({
    super.key,
    required this.guideId,
    required this.state,
    this.enabled = true,
  });
  @override
  State<GuideSheetOnce> createState() => _GuideSheetOnceState();
}

class _GuideSheetOnceState extends State<GuideSheetOnce> {
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _maybeFire();
  }

  @override
  void didUpdateWidget(covariant GuideSheetOnce old) {
    super.didUpdateWidget(old);
    // 从后台切到前台的那一刻才弹（见 `enabled` 的说明）
    if (widget.enabled && !old.enabled) _maybeFire();
  }

  void _maybeFire() {
    if (_fired || !widget.enabled) return;
    if (widget.state.isGuideSeen(widget.guideId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _fired || !context.mounted) return;
      _fired = true;
      // 先记「已看」再弹：点弹层外部关闭也算看过了，不该下次再弹一次
      widget.state.markGuideSeen(widget.guideId);
      showGuideSheet(context, widget.guideId);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// 顶栏上的「重看本页引导」按钮。
///
/// 放在 AppBar 的 actions 里：提示卡关掉之后，用户临时想再看一眼时不必去设置里
/// 重置全部引导。
class GuideHelpButton extends StatelessWidget {
  final String guideId;

  const GuideHelpButton({super.key, required this.guideId});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: S.of(context).guideShowAgain,
      icon: const Icon(Icons.help_outline_rounded, size: 20),
      onPressed: () => showGuideSheet(context, guideId),
    );
  }
}

/// 以底部弹层「重看」某条引导。id 不存在时静默什么都不做。
Future<void> showGuideSheet(BuildContext context, String guideId) async {
  final g = guideOf(context, guideId);
  if (g == null) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => MaterialSurface(
      radius: 24,
      topOnly: true,
      child: Container(
        decoration: BoxDecoration(
          color: C.sheetFill,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: g.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(g.icon, size: 19, color: g.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(ctx).guideTitle,
                          style: ts(11, c: C.grey, w: FontWeight.w600, ls: 0.6),
                        ),
                        const SizedBox(height: 1),
                        Text(g.title, style: ts(15, w: FontWeight.w800)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: C.grey, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(g.body, style: ts(13, c: C.slate, h: 1.7)),
              const SizedBox(height: 10),
              // 看完了怎么再看一眼 —— 沉浸地图这类页面没有顶栏，这里是唯一的提示
              Text(
                S.of(ctx).guideMoreInSettings,
                style: ts(11, c: C.grey, h: 1.5),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: g.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    S.of(ctx).guideGotIt,
                    style: ts(13, c: Colors.white, w: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}
