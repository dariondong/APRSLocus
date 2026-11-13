import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// ─── 强提醒：打开应用时整页弹出来的那一张 ───
///
/// 内容**不在包里**，由官网下发（`docs/assets/strong_notice.json`）：
/// 要说什么、什么级别、能不能跳过、发到哪天，全在那份文件里。这样改一句话
/// 不用发版，也就不必为了"提醒一句"去推一个包。
///
/// ── 三条自律（与限制名单、最低版本同一套）──
///
///  1. **拉不到就什么都不弹**：没联网、文件坏了、一条都不合格 → 安静进主界面。
///     弹窗拦人是重型手段，不能因为一次网络抖动把所有人挡在门外。
///  2. **弹过的记下来**：默认同一条只弹一次（`every: true` 才每次打开都弹），
///     否则用户每开一次应用就被拦一次。
///  3. **过期就不弹**：`until` 写成 `2026-12-01` 这种日期，过完那天自动失效 ——
///     省得哪天忘了删，旧公告一直糊在人脸上。
///
/// ── 文件格式 ──
/// ```json
/// { "updated": "2026-11-13",
///   "items": [
///     { "id": "261113a",                        // 换个 id = 当成一条新提醒
///       "level": "warn",                        // info / warn / critical
///       "title": {"zh": "…", "en": "…"},        // 也可以是纯字符串
///       "body":  {"zh": "…", "en": "…"},        // \n 分段
///       "actions": [{"label": {"zh": "去更新"}, "url": "https://…"}],
///       "hard": true,                           // 只能点按钮关掉
///       "every": false,                         // 每次打开都弹
///       "until": "2026-12-01" } ] }
/// ```
/// 文本可以是纯字符串，也可以是按语言分开的 map（认 `zh_TW` / `zh` 再退到 `en`，
/// 都没有就取第一个非空值）。缺 `title` 或缺 `body` 的条目整条作废 ——
/// 弹出来一片空白的"强提醒"比不弹更糟。
class StrongNotice {
  final String id;

  /// `info` / `warn` / `critical`，认不出的一律当 `info`。
  final String level;
  final String title;

  /// 标题下面那行小字（比如「Audit complete · 12 Nov 2026」），可空。
  final String subtitle;

  /// 正文。行首标记决定排版（见 [parseNoticeBody]）：
  /// `【…】` 是小标题、`- ` 是条目、`…` 包起来的是等宽块、其余是段落。
  final String body;
  final List<StrongNoticeAction> actions;

  /// 不能点外面 / 按返回键跳过，只能点按钮关掉。
  final bool hard;

  /// 每次打开应用都弹（默认只弹一次）。
  final bool every;

  /// 截止日期（北京时间，含当天）。空 = 长期有效。
  final String until;

  const StrongNotice({
    required this.id,
    required this.level,
    required this.title,
    required this.body,
    this.subtitle = '',
    this.actions = const [],
    this.hard = true,
    this.every = false,
    this.until = '',
  });

  /// 官网那份文件的地址（与最低版本、限制名单、更新渠道同一个站点）。
  static const String url = 'https://aprslocus.theez.top/assets/strong_notice.json';

  /// 多久重新拉一次（同一会话内节流；换一次启动必拉）。
  static const Duration refresh = Duration(hours: 6);

  /// 这次该不该弹：过期的不弹，弹过的不弹（`every` 除外）。
  bool worthShowing(Set<String> seen, {DateTime? now}) {
    if (id.isEmpty || title.trim().isEmpty || body.trim().isEmpty) return false;
    if (_expired(now ?? DateTime.now())) return false;
    if (!every && seen.contains(id)) return false;
    return true;
  }

  bool _expired(DateTime now) {
    final u = until.trim();
    if (u.isEmpty) return false;
    // 只认 yyyy-MM-dd：写别的就当没写（宁可弹出来，也不要因为格式错而永远不弹）
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(u)) return false;
    final today = _beijingDate(now);
    return today.compareTo(u) > 0;
  }

  /// 解析整份文件，返回所有**可用**的条目（缺标题/正文的丢掉）。
  static List<StrongNotice> parseAll(String? text, String lang) {
    if (text == null || text.trim().isEmpty) return const [];
    try {
      final data = jsonDecode(text);
      if (data is! Map) return const [];
      final items = data['items'];
      if (items is! List) return const [];
      final out = <StrongNotice>[];
      for (final e in items) {
        if (e is! Map) continue;
        final n = _one(e, lang);
        if (n != null) out.add(n);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// 这一次该弹哪一条：取文件里第一条「没过期、没弹过」的。
  static StrongNotice? pick(
    String? text,
    String lang,
    Set<String> seen, {
    DateTime? now,
  }) {
    for (final n in parseAll(text, lang)) {
      if (n.worthShowing(seen, now: now)) return n;
    }
    return null;
  }

  static StrongNotice? _one(Map raw, String lang) {
    final id = (raw['id'] ?? '').toString().trim();
    final title = textOf(raw['title'], lang);
    final subtitle = textOf(raw['subtitle'], lang);
    final body = textOf(raw['body'], lang);
    if (id.isEmpty || title.isEmpty || body.isEmpty) return null;
    final level = (raw['level'] ?? 'info').toString().trim().toLowerCase();
    final actions = <StrongNoticeAction>[];
    final rawActions = raw['actions'];
    if (rawActions is List) {
      for (final a in rawActions) {
        if (a is! Map) continue;
        final label = textOf(a['label'], lang);
        final url = (a['url'] ?? '').toString().trim();
        if (label.isEmpty) continue;
        actions.add(StrongNoticeAction(label: label, url: url));
      }
    }
    return StrongNotice(
      id: id,
      level: const ['info', 'warn', 'critical'].contains(level) ? level : 'info',
      title: title,
      subtitle: subtitle,
      body: body,
      actions: actions,
      hard: raw['hard'] is bool ? raw['hard'] as bool : true,
      every: raw['every'] is bool ? raw['every'] as bool : false,
      until: (raw['until'] ?? '').toString().trim(),
    );
  }

  /// 一段文本：纯字符串直接用；map 就按语言取（见 [_langChain]）。
  static String textOf(Object? v, String lang) {
    if (v == null) return '';
    if (v is String) return v.trim();
    if (v is Map) {
      for (final k in _langChain(lang)) {
        final t = v[k];
        if (t is String && t.trim().isNotEmpty) return t.trim();
      }
      for (final e in v.values) {
        if (e is String && e.trim().isNotEmpty) return e.trim();
      }
    }
    return '';
  }

  /// 语言链：`zh_TW` → [`zh_TW`, `zh`, `en`]；空 locale（跟随系统）按 `zh` 起。
  static List<String> _langChain(String lang) {
    final l = lang.trim();
    if (l.isEmpty) return const ['zh', 'en'];
    final base = l.split(RegExp('[-_]')).first;
    final chain = <String>[l];
    if (base != l) chain.add(base);
    if (!chain.contains('en')) chain.add('en');
    return chain;
  }

  /// 北京时间的日期串（`until` 按它比较）。
  static String _beijingDate(DateTime now) {
    final bj = now.toUtc().add(const Duration(hours: 8));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${bj.year}-${two(bj.month)}-${two(bj.day)}';
  }
}

class StrongNoticeAction {
  final String label;

  /// 空 = 只当一句"我知道了"，点了就关。
  final String url;

  const StrongNoticeAction({required this.label, this.url = ''});
}

/// 拉一次官网那份强提醒文件。失败返回 null（调用方沿用缓存 / 什么都不弹）。
Future<String?> fetchStrongNoticeJson({
  required String userAgent,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final req = await client
        .getUrl(Uri.parse(StrongNotice.url))
        .timeout(timeout);
    req.headers.set(HttpHeaders.userAgentHeader, userAgent);
    // 强提醒必须拿到最新那份：中间那层 CDN 缓存十分钟，改完马上要能生效。
    req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    final resp = await req.close().timeout(timeout);
    if (resp.statusCode != 200) {
      await resp.drain<void>();
      return null;
    }
    return await resp.transform(utf8.decoder).join().timeout(timeout);
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// 强提醒正文里的一行块：小标题 / 段落 / 条目 / 等宽块。
enum NoticeBlockKind { heading, paragraph, bullet, mono }

class NoticeBlock {
  final NoticeBlockKind kind;
  final String text;

  const NoticeBlock(this.kind, this.text);
}

/// 把正文按**行首标记**切块，规则少到能一眼记住：
///
///   * `【一、审计结论】` → 小标题（去掉方括号，加粗、上下留白）
///   * `- 一句话`        → 条目（前面加圆点，可换行不缩进）
///   * `` `SHA-1: …` ``  → 等宽块（指纹、版本号这类要一个字符一个字符对的）
///   * 其余每一行        → 段落
///
/// 为什么用行首标记而不是把 body 写成结构化数组：这份文件是**手写**的，
/// 写数组要记括号层级，写错一个逗号整条都不弹；而 `【】`、`- `、反引号
/// 就算哪天渲染没跟上，读起来也还是正常文字。
List<NoticeBlock> parseNoticeBody(String raw) {
  final out = <NoticeBlock>[];
  for (final line in raw.split('\n')) {
    final t = line.trim();
    if (t.isEmpty) continue;
    if (t.startsWith('【') && t.endsWith('】') && t.length > 2) {
      out.add(NoticeBlock(NoticeBlockKind.heading, t.substring(1, t.length - 1)));
      continue;
    }
    if ((t.startsWith('- ') || t.startsWith('· ')) && t.length > 2) {
      out.add(NoticeBlock(NoticeBlockKind.bullet, t.substring(2).trim()));
      continue;
    }
    if (t.startsWith('`') && t.endsWith('`') && t.length > 2) {
      out.add(NoticeBlock(NoticeBlockKind.mono, t.substring(1, t.length - 1)));
      continue;
    }
    out.add(NoticeBlock(NoticeBlockKind.paragraph, t));
  }
  return out;
}
