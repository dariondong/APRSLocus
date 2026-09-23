import 'package:flutter/material.dart';

import 'markdown_view.dart';
import 'material.dart';
import 'notice.dart';
import 'state.dart';
import 'theme.dart';
import 'theme_text.dart';
import 'widgets.dart';

/// ─── 公告横幅（设置 → 显示）───
///
/// 用户需求：「在设置里添加一个公告横幅用户可以打开，公告内容从官网文件夹拉取，
/// md 应用内支持渲染 MD 和超链接」。
///
/// ## 这个组件负责什么
///
/// * **开关关掉时：什么都不做** —— 关键的一条。开关的意义不只是「藏起来」，
///   而是**不再发起网络请求**：用户关它多半就是因为不想让它联网。
///   所以这里在 `build` 最前面就 return，连一次 `load()` 都不发起。
/// * **打开时**：先用缓存立刻显示（有内容就不会闪空白），再后台刷新；
///   刷新到了就换掉，没刷新到就留着旧的。
/// * **拿不到任何内容**：如实写「暂无公告」+ 一个「重试」，而不是留白 ——
///   留白会让人以为功能坏了（与 v1.6.109 只读模式同一条原则）。
///
/// ## 为什么横幅只显示标题 + 前几行
///
/// 设置页是「一眼扫过去找一个开关」的地方，不是阅读器。横幅给**一行摘要**，
/// 点进去才是完整 Markdown（那里有表格、代码块、图片的空间）。
class NoticeBanner extends StatefulWidget {
  final AppState state;

  /// 点标题时打开全文（由调用方决定用页面还是弹层）
  final void Function(String markdown) onOpen;

  const NoticeBanner({super.key, required this.state, required this.onOpen});

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
    final d = await NoticeStore.instance.load(lang: _lang());
    if (!mounted) return;
    setState(() {
      _loading = false;
      _tried = true;
      // 刷新失败时**不要**把已有的内容清掉（宁可显示旧的）
      if (d != null) _doc = d;
    });
  }

  /// 当前界面语言码（与 `notice/<lang>.md` 的文件名一致）
  String _lang() {
    final code = Localizations.localeOf(context).toString();
    switch (code) {
      case 'zh':
      case 'zh_TW':
      case 'en':
      case 'ja':
      case 'es':
      case 'id':
        return code;
    }
    return 'en';
  }

  @override
  Widget build(BuildContext context) {
    // 关掉开关 = 不显示、也不联网
    if (!widget.state.noticeBanner) return const SizedBox.shrink();
    final s = S.of(context);
    final doc = _doc;
    final summary =
        doc == null ? '' : NoticeStore.summaryOf(doc.body);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MaterialSurface(
        radius: 16,
        child: Container(
          decoration: BoxDecoration(
            color: C.sheetFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: C.cyan.withValues(alpha: 0.4)),
            boxShadow: elev2(),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: C.cyanBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.campaign_rounded, size: 18, color: C.cyan),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(s.noticeTitle,
                            style: ts(12, w: FontWeight.w800)),
                        if (_loading) ...[
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.6, color: C.cyan),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (summary.isNotEmpty) ...[
                      Text(summary,
                          style: ts(11.5, c: C.ink, w: FontWeight.w600, h: 1.45),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      GestureDetector(
                        // 整行都可点：与 _toolBtn 同一个坑 —— 底色来自
                        // BoxDecoration 时不显式 opaque 就只有文字能点
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onOpen(doc!.body),
                        child: Row(
                          children: [
                            Text(s.noticeReadMore,
                                style:
                                    ts(11, c: C.cyan, w: FontWeight.w700)),
                            Icon(Icons.chevron_right_rounded,
                                size: 14, color: C.cyan),
                          ],
                        ),
                      ),
                      if (doc.fromCache && doc.fetchedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          s.noticeCached(_ago(doc.fetchedAt!)),
                          style: ts(9, c: C.greyLight),
                        ),
                      ],
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _loading ? s.noticeLoading : s.noticeEmpty,
                              style: ts(11, c: C.grey, h: 1.4),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 「3 分钟前 / 2 小时前 / 3 天前」—— 缓存时间要如实标出来，
  /// 否则用户看到一条旧公告会以为是最新的
  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    final s = S.of(context);
    if (d.inMinutes < 1) return s.timeJustNow;
    if (d.inHours < 1) return s.minutesAgo('${d.inMinutes}');
    if (d.inDays < 1) return s.hoursAgo('${d.inHours}');
    return s.daysAgo('${d.inDays}');
  }
}

/// 公告全文页：完整渲染 Markdown（表格 / 代码块 / 图片 / 可点链接）
class NoticePage extends StatefulWidget {
  final String markdown;
  final DateTime? fetchedAt;
  final bool fromCache;

  const NoticePage(this.markdown,
      {super.key, this.fetchedAt, this.fromCache = false});

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  late String _md = widget.markdown;
  DateTime? _at = widget.fetchedAt;
  bool _cache = widget.fromCache;
  bool _loading = false;

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    final d = await NoticeStore.instance.load(lang: _lang());
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

  String _lang() {
    final code = Localizations.localeOf(context).toString();
    const known = {'zh', 'zh_TW', 'en', 'ja', 'es', 'id'};
    return known.contains(code) ? code : 'en';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: C.pageFill,
      appBar: MaterialAppBar(AppBar(
        backgroundColor: C.surfaceFillStrong,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: C.slate),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(s.noticeTitle, style: ts(16, w: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: s.refresh,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.refresh_rounded, color: C.grey),
            onPressed: _refresh,
          ),
        ],
      )),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            // 缓存的公告要标出来：用户据此知道「这是上次联网时的那份」
            if (_cache && _at != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: C.orangeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 14, color: C.orange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(s.noticeOfflineCache(_at!.toString().substring(0, 16)),
                            style: ts(10, c: C.orange, w: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            MarkdownView(_md, baseUrl: NoticeStore.base),
          ],
        ),
      ),
    );
  }
}
