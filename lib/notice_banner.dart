import 'package:flutter/material.dart';

import 'markdown_view.dart';
import 'material.dart';
import 'notice.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 公告横幅（**主页 + 设置页**各一条）+ 全文（**底部弹层**）───
///
/// 需求沿革（三次）：
///  1. 「在设置里加一个公告横幅用户可以打开，内容从官网拉，md 支持渲染与超链接」；
///  2. 「位置改一下……在主页显示横幅，打开就不能以弹窗的形式？」→ 横幅搬到主页，
///     打开改成**底部弹层**；
///  3. 「在设置页也留，但是能够再次开启和关闭。横幅也能关闭。」
///     → **两处都放**横幅；开关可反复开关；**横幅自带关闭按钮**
///       （关掉 = 把开关置为 off，于是两处的横幅一起收起，用户可在设置里再打开 ——
///        一个来源、两种入口，避免出现「关掉了但它明天又回来」）。
///
/// ## 这个组件负责什么
///
/// * **开关关掉时：什么都不做** —— 关键的一条。开关的意义不只是「藏起来」，
///   而是**不再发起网络请求**：用户关它多半就是因为不想让它联网。
///   所以 `initState` 里就先 return，连一次 `load()` 都不发起。
/// * **打开时**：先用缓存立刻显示（有内容就不会闪空白），再后台刷新；
///   刷新到了就换掉，没刷到就留着旧的。
/// * **拿不到任何内容**：如实写「暂无公告」+ 一个「重试」，而不是留白 ——
///   留白会让人以为功能坏了（与 v1.6.109 只读模式同一条原则）。
///
/// ## 为什么是「一条窄条」而不是卡片
///
/// 主页那条贴在**地图上方**：地图是主角，公告只是一条通知。窄条只占
/// [stripHeight] 像素、一行文字（标题 + 摘要，超出省略），点开才是完整 Markdown。
/// 高度是**常量**：外壳要用它算地图的顶部让位量（见 shell2），
/// 而让位量参与地图控件与面板的几何，不能是一个量出来会抖的值。
class NoticeBanner extends StatefulWidget {
  final AppState state;

  const NoticeBanner({super.key, required this.state});

  /// 窄条高度（外壳用它算顶部让位量）
  static const double stripHeight = 34;

  @override
  State<NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends State<NoticeBanner> {
  NoticeDoc? _doc;
  bool _loading = false;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (!widget.state.noticeBanner) return; // 关掉 → 一次请求都不发
    // ① 先上缓存：有旧公告时立刻可见，不必等网络
    final cached = await NoticeStore.instance.cachedOnly();
    if (!mounted) return;
    if (cached != null) setState(() => _doc = cached);
    // ② 再联网刷新
    await _refresh();
  }

  Future<void> _refresh() async {
    if (!widget.state.noticeBanner || _loading) return;
    setState(() => _loading = true);
    final d = await NoticeStore.instance.load(lang: noticeLangOf(context));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _tried = true;
      // 刷新失败时**不要**把已有的内容清掉（宁可显示旧的）
      if (d != null) _doc = d;
    });
  }

  void _open() {
    final d = _doc;
    if (d == null) return;
    showNoticeSheet(context,
        markdown: d.body, fetchedAt: d.fetchedAt, fromCache: d.fromCache);
  }

  /// 横幅上的「关闭」：把**开关**置为 off。
  ///
  /// 为什么不只隐藏这一条：开关是唯一的持久状态。只隐藏的话，用户下次打开
  /// 应用它又回来了（「我明明关了」），而若另存一个「已忽略」标记，就又多出
  /// 一个没人知道的状态。置 off 之后：两处横幅一起收起、设置里的开关同步变成
  /// 「关」，想再看打开即可 —— 行为闭环、可解释。
  void _dismiss() => widget.state.setNoticeBanner(false);

  @override
  Widget build(BuildContext context) {
    // 关掉开关 = 不显示、也不联网
    if (!widget.state.noticeBanner) return const SizedBox.shrink();
    final s = S.of(context);
    final doc = _doc;
    final summary = doc == null ? '' : NoticeStore.summaryOf(doc.body);
    final hasContent = doc != null && summary.isNotEmpty;

    return SizedBox(
      height: NoticeBanner.stripHeight,
      child: MaterialSurface(
        radius: 12,
        blurSigma: C.chipBlur,
        child: GestureDetector(
          // 整条可点（与 _toolBtn 同一个坑：底色来自 BoxDecoration 时不显式
          // opaque 就只有图标那点能点）
          behavior: HitTestBehavior.opaque,
          onTap: hasContent ? _open : null,
          child: Container(
            padding: const EdgeInsets.only(left: 10, right: 2),
            decoration: BoxDecoration(
              color: C.chipFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.cyan.withValues(alpha: 0.4)),
              boxShadow: elev2(),
            ),
            child: Row(
              children: [
                Icon(Icons.campaign_rounded, size: 15, color: C.cyan),
                const SizedBox(width: 8),
                Expanded(
                  child: hasContent
                      ? Text.rich(
                          TextSpan(children: [
                            TextSpan(
                                text: '${s.noticeTitle} · ',
                                style: ts(11, c: C.cyan, w: FontWeight.w700)),
                            TextSpan(
                                text: summary,
                                style: ts(11, c: C.ink, w: FontWeight.w600)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                _loading ? s.noticeLoading : s.noticeEmpty,
                                style: ts(11, c: C.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!_loading && _tried)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _refresh,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  child: Text(s.retry,
                                      style: ts(11,
                                          c: C.blue, w: FontWeight.w700)),
                                ),
                              ),
                          ],
                        ),
                ),
                if (_loading)
                  Padding(
                    // ⚠ 不能写 const：C.cyan 是非常量（check_const_colors 会报）
                    padding: const EdgeInsets.only(left: 6),
                    child: SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.6, color: C.cyan),
                    ),
                  ),
                if (hasContent) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 15, color: C.cyan),
                ],
                // 缓存的那份要标出来：用户据此知道「这不是最新的」
                if (hasContent && doc.fromCache && doc.fetchedAt != null) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.cloud_off_rounded, size: 12, color: C.orange),
                ],
                // ── 关闭按钮 ──
                // 触摸区做到 30×30（窄条只有 34 高，用 IconButton 的 48 会撑破），
                // 并且**必须显式 opaque**：否则只有那个 15px 图标能点中。
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismiss,
                  child: SizedBox(
                    width: 30,
                    height: NoticeBanner.stripHeight,
                    child: Icon(Icons.close_rounded,
                        size: 15, color: C.grey.withValues(alpha: 0.8)),
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

/// 打开公告全文（**底部弹层**）
///
/// 为什么是弹层而不是整页（用户第 2 次调整的原话：「打开就不能以弹窗的形式？」）：
/// 公告是「顺手看一眼」的东西，整页会把用户从地图上完全带走、还得按返回；
/// 弹层读完一划或点一下就回去了。内容用 [MarkdownView] 渲染
/// （表格/代码块/图片/可点链接），长内容整层可滚。
Future<void> showNoticeSheet(
  BuildContext context, {
  required String markdown,
  DateTime? fetchedAt,
  bool fromCache = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // 长公告可以拉到接近全屏，但不占满 —— 留一条能看到背后的地图/页面，
    // 用户知道自己是「盖上来的」而不是「跳到别处了」。
    // ⚠ NoticeSheet 的第一个参数是**位置参数**（`const NoticeSheet(this.markdown, …)`），
    //   写成 `markdown: markdown` 会报「1 positional argument expected but 0 found」+
    //   「named parameter 'markdown' isn't defined」两条 —— 本机跑不了 analyze，
    //   这种错只能等 CI。构造改成具名当然也行，但那要同时改两处，位置参数更短。
    builder: (_) => NoticeSheet(
      markdown,
      fetchedAt: fetchedAt,
      fromCache: fromCache,
    ),
  );
}

/// 当前界面语言码（与 `notice/<lang>.md` 的文件名一致）。
///
/// 抽成顶层函数：横幅与弹层两处都要用，各写一份必然漂。
String noticeLangOf(BuildContext context) {
  final code = Localizations.localeOf(context).toString();
  const known = {'zh', 'zh_TW', 'en', 'ja', 'es', 'id'};
  return known.contains(code) ? code : 'en';
}

/// 公告全文（弹层内容，**不是整页**：没有 Scaffold / AppBar）
class NoticeSheet extends StatefulWidget {
  final String markdown;
  final DateTime? fetchedAt;
  final bool fromCache;

  const NoticeSheet(this.markdown,
      {super.key, this.fetchedAt, this.fromCache = false});

  @override
  State<NoticeSheet> createState() => _NoticeSheetState();
}

class _NoticeSheetState extends State<NoticeSheet> {
  // 不能在初始化器里引用 `widget`（implicit_this_reference_in_initializer），
  // 所以统一在 initState 里赋值。
  late String _md;
  DateTime? _at;
  bool _cache = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _md = widget.markdown;
    _at = widget.fetchedAt;
    _cache = widget.fromCache;
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    final d = await NoticeStore.instance.load(lang: noticeLangOf(context));
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (d != null) {
        _md = d.body;
        _at = d.fetchedAt;
        _cache = d.fromCache;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final maxH = MediaQuery.of(context).size.height * 0.85;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: MaterialSurface(
          radius: 24,
          topOnly: true,
          child: Container(
            decoration: BoxDecoration(
              color: C.sheetFill,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 把手：与外壳面板一致的「可以往下划」暗示
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 2),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: C.grey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const SizedBox(width: 18),
                    Icon(Icons.campaign_rounded, size: 17, color: C.cyan),
                    const SizedBox(width: 8),
                    Text(s.noticeTitle,
                        style: ts(15, w: FontWeight.w800, c: C.ink)),
                    const Spacer(),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          // 这里没有 C.*，所以 const 合法
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: s.refresh,
                        icon: Icon(Icons.refresh_rounded,
                            size: 18, color: C.grey),
                        onPressed: _refresh,
                      ),
                    IconButton(
                      tooltip: s.close,
                      icon:
                          Icon(Icons.close_rounded, size: 18, color: C.grey),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
                    shrinkWrap: true,
                    children: [
                      // 缓存的公告要标出来：用户据此知道「这是上次联网时的那份」
                      if (_cache && _at != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: C.orangeBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.cloud_off_rounded,
                                    size: 14, color: C.orange),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                      s.noticeOfflineCache(
                                          _at!.toString().substring(0, 16)),
                                      style: ts(10,
                                          c: C.orange, w: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      MarkdownView(_md, baseUrl: NoticeStore.base),
                    ],
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
