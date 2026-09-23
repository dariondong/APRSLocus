import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// ─── 公告横幅的内容来源：官网上一份 Markdown ───
///
/// 用户需求：「在设置里添加一个公告横幅用户可以打开，公告内容从官网文件夹拉取，
/// md 应用内支持渲染 MD 和超链接」。
///
/// 设计取舍（三条都跟「用户可能在任何网络环境下」有关）：
///
/// 1. **按语言取、带兜底链**：`notice/<lang>.md` → `notice/en.md` → 本地缓存。
///    官网放的是**多语言各自一份**，而不是一份里塞六种语言 —— 后者要在客户端
///    做「按标记切段落」的解析，一旦作者格式写歪就整份读不出来。
/// 2. **缓存最后一次成功的内容**（SharedPreferences）：公告的价值在于「用户能
///    看到」，而不是「必须实时」。断网/官网抖动时用上次那份，比什么都不显示好；
///    同时**从不删除**缓存 —— 官网临时 404 不该让所有人看到空白。
/// 3. **失败要如实说**：全都拿不到时返回 `null`，界面写「暂无公告」，
///    而不是留一片空白让人以为功能坏了（与 v1.6.109 只读模式同一条原则）。
///
/// 为什么不复用 `terms_page` 的写法：那个是**一次性读**，没有缓存需求；
/// 公告要长期显示、要能在重启后立刻出现，所以这里多一层本地缓存。
class NoticeDoc {
  /// Markdown 原文
  final String body;

  /// 拉取成功的时间（缓存命中时是**上次成功**的时间，不是现在）
  final DateTime? fetchedAt;

  /// 本次是网络拉到的，还是用的缓存
  final bool fromCache;

  const NoticeDoc(this.body, {this.fetchedAt, this.fromCache = false});
}

class NoticeStore {
  NoticeStore._();
  static final NoticeStore instance = NoticeStore._();

  /// 官网根地址（与 `terms_page` 同一处来源，改域名时两处要一起改）
  static const String base = 'https://aprslocus.theez.top';

  /// 请求超时。公告是**顺带**显示的东西，不该让用户等 ——
  /// 6 秒与 `terms_page` 一致；超时就退回缓存。
  static const Duration _timeout = Duration(seconds: 6);

  static const String _kCacheBody = 'noticeCacheBody';
  static const String _kCacheLang = 'noticeCacheLang';
  static const String _kCacheAt = 'noticeCacheAt';

  /// 上次拉取失败的原因（供界面如实显示；成功时为 null）
  String? lastError;

  String _urlFor(String lang) =>
      '$base/notice/${lang.isEmpty ? 'en' : lang}.md';

  /// 拉公告。先网络、后缓存；两者都没有返回 null。
  ///
  /// [lang] 用应用内的语言码（'zh' / 'zh_TW' / 'en' / 'ja' / 'es' / 'id'）。
  Future<NoticeDoc?> load({required String lang}) async {
    lastError = null;
    // ① 网络（先当前语言，再英文兜底）
    final tried = <String>[lang, 'en'];
    for (final l in tried) {
      final body = await _fetch(_urlFor(l));
      if (body != null && body.trim().isNotEmpty) {
        await _saveCache(body, l);
        return NoticeDoc(body, fetchedAt: DateTime.now());
      }
    }
    // ② 缓存（不限语言：用户切了语言但还没联网时，有旧语言的公告也好过空白）
    final cached = await _loadCache();
    if (cached != null) {
      lastError = 'offline';
      return cached;
    }
    lastError = 'unavailable';
    return null;
  }

  /// 读缓存里那份（不联网）。用于「打开设置时先立刻显示」。
  Future<NoticeDoc?> cachedOnly() => _loadCache();

  Future<String?> _fetch(String url) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = _timeout;
      final req = await client.getUrl(Uri.parse(url));
      // 带上 UA：与 aprs_device / terms_page 一致，方便服务端（我）看来源
      req.headers.set(HttpHeaders.userAgentHeader, 'APRSlocus');
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      return await resp.transform(utf8.decoder).join();
    } catch (_) {
      // 断网、DNS、超时、证书……一律当作「这次没拿到」，交给缓存兜底
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  Future<void> _saveCache(String body, String lang) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kCacheBody, body);
      await p.setString(_kCacheLang, lang);
      await p.setInt(_kCacheAt, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<NoticeDoc?> _loadCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final body = p.getString(_kCacheBody);
      if (body == null || body.trim().isEmpty) return null;
      final ms = p.getInt(_kCacheAt);
      return NoticeDoc(
        body,
        fetchedAt:
            ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// 公告的**第一行标题**（横幅上那一行摘要用）。
  ///
  /// 只认开头的 `#` 标题；没有标题就退回第一行非空文字（并去掉行内的
  /// Markdown 记号，否则横幅上会出现 `**v1.6.156**` 这种带星号的东西）。
  static String summaryOf(String markdown) {
    for (final raw in markdown.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line == '---') continue;
      final text = stripInlineMarkdown(line.replaceFirst(RegExp(r'^#+\s*'), ''));
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  /// 去掉行内 Markdown 记号（粗体/斜体/代码/链接语法），只留可读文字。
  ///
  /// 用于摘要这类**不渲染 Markdown** 的地方。刻意只处理这几个最常见的记号：
  /// 真正的渲染由 `lib/markdown_view.dart` 用解析器做，这里只是「别让星号露出来」。
  static String stripInlineMarkdown(String s) {
    var t = s;
    // [文字](链接) → 文字
    t = t.replaceAllMapped(
        RegExp(r'\[([^\]]*)\]\(([^)]*)\)'), (m) => m.group(1)!);
    // `代码` / **粗体** / *斜体* / ~~删除~~ 的记号
    t = t.replaceAll('`', '');
    t = t.replaceAll('**', '');
    t = t.replaceAll('~~', '');
    t = t.replaceAll(RegExp(r'(?<![*\w])\*(?!\*)'), '');
    return t.trim();
  }
}
