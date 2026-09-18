/// ─── 聊天翻译 ───
///
/// 支持三家接口：
///   ① Google Cloud Translation v2（API Key）
///   ② 百度翻译开放平台（App ID + 密钥，sign = MD5(appid+q+salt+key)）
///   ③ 自定义 HTTP 接口（URL / 方法 / 请求头 / 请求体模板 / 结果字段路径）
///
/// 设计要点：
///   - **语言码按接口分别映射**：界面内部统一用短码（zh / zh-TW / en / ja / id / es），
///     各接口的写法不同（Google 用 `zh-CN`、百度用 `cht`），映射集中在一处，
///     避免把接口方言散落到 UI。
///   - **结果缓存按「原文 + 语言 + 接口」为键**：同一条消息重复查看不会
///     重复计费；换接口或换目标语言会自然失效。
///   - 三方接口都可能失败，错误一律转成可读文本（含 HTTP 状态与响应片段），
///     不做静默失败 —— 用户点「翻译」必须有反馈。
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'net/http_send.dart';

// ───────────────────────── 语言码 ─────────────────────────

/// 应用内统一使用的短语言码（与 l10n 的 locale 对应，另加少数常用语种）
class TransLang {
  final String code; // 内部短码
  final String label; // 展示名（用各自语言的自称，避免「日语/Japanese」混乱）

  const TransLang(this.code, this.label);

  /// 目标语言候选。**顺序按实用性排**：本应用用户以中文/英文为主。
  static const List<TransLang> all = [
    TransLang('auto', 'Auto'), // 仅用于「原文语言」= 自动检测
    TransLang('zh', '简体中文'),
    TransLang('zh-TW', '繁體中文'),
    TransLang('en', 'English'),
    TransLang('ja', '日本語'),
    TransLang('ko', '한국어'),
    TransLang('es', 'Español'),
    TransLang('fr', 'Français'),
    TransLang('de', 'Deutsch'),
    TransLang('ru', 'Русский'),
    TransLang('pt', 'Português'),
    TransLang('it', 'Italiano'),
    TransLang('id', 'Bahasa Indonesia'),
    TransLang('th', 'ไทย'),
    TransLang('vi', 'Tiếng Việt'),
    TransLang('ar', 'العربية'),
  ];

  static TransLang? byCode(String code) =>
      all.where((l) => l.code == code).firstOrNull;

  /// 该语言是否从右往左书写。
  ///
  /// 需要这个是因为：阿拉伯语语言名混在中文/英文界面里时，
  /// 文本方向不一致会导致标点跳到错误一侧（例如「阿拉伯语 ·
  /// العربية」里的分隔点跑到开头）。显示时给 RTL 标签单独包一层
  /// Directionality 才能正确排版。
  static bool isRtl(String code) => code == 'ar';

  static String labelOf(String code) => byCode(code)?.label ?? code;

  /// → Google 写法
  static String toGoogle(String code) => switch (code) {
        'zh' => 'zh-CN',
        'zh-TW' => 'zh-TW',
        _ => code,
      };

  /// → MyMemory 写法（实测：中文用 zh-CN / zh-TW）
  static String toMyMemory(String code) => switch (code) {
        'zh' => 'zh-CN',
        'zh-TW' => 'zh-TW',
        _ => toGoogle(code),
      };

  /// → LibreTranslate 写法（ISO 639-1；繁体在部分实例是 zt）
  static String toLibre(String code) => switch (code) {
        'zh' => 'zh',
        'zh-TW' => 'zt',
        _ => code,
      };

  /// → 百度写法
  static String toBaidu(String code) => switch (code) {
        'zh' => 'zh',
        'zh-TW' => 'cht',
        'en' => 'en',
        'ja' => 'jp',
        'ko' => 'kor',
        'es' => 'spa',
        'fr' => 'fra',
        'de' => 'de',
        'ru' => 'ru',
        'pt' => 'pt',
        'it' => 'it',
        'id' => 'id',
        'th' => 'th',
        'vi' => 'vie',
        'ar' => 'ara',
        _ => 'auto',
      };

  /// 「对方的语言」哨兵值：表示目标语言不是固定的一种，而是**跟着对方走**。
  /// 实际解析见 [TransDirection]（收到对方消息 → 我的语言；自己发的 → 对方语言）。
  static const String peer = '@peer';

  /// 界面 locale（l10n 的用法，如 zh / zh_TW / en）→ 本模块短码
  static String fromUiLocale(String uiLocale) => switch (uiLocale) {
        'zh' => 'zh',
        'zh_TW' => 'zh-TW',
        'en' => 'en',
        'ja' => 'ja',
        'id' => 'id',
        'es' => 'es',
        _ => 'en',
      };

  /// 界面语言 → 默认翻译目标语言（当前界面语言已是目标时没必要翻译）
  static String defaultTargetFor(String uiLocale) => switch (uiLocale) {
        'zh' => 'en',
        'zh_TW' => 'en',
        'en' => 'zh',
        'ja' => 'zh',
        'id' => 'zh',
        'es' => 'zh',
        _ => 'en',
      };
}

// ───────────────────────── 配置 ─────────────────────────

/// 翻译接口标识。
///
/// 之所以用常量而不是 enum：这些值会落盘到 SharedPreferences，
/// 字符串更利于将来增删而不破坏已存配置（enum 的 index 会错位）。
class TransProvider {
  TransProvider._();

  /// **自动**：按顺序尝试多个免密钥接口，直到拿到「确实翻译过」的结果。
  /// 这是默认值 —— 因为实测表明**任何单一免密钥接口都不可靠**
  /// （Google 公开端点会被限流、MyMemory 对部分语对直接返回原文、
  /// 公共 LibreTranslate 实例已要求密钥且常缺中文）。
  static const String auto = 'auto';

  /// Google 翻译网页端公开端点（免密钥、质量好，但会被限流）
  static const String googlePublic = 'googlePublic';

  /// MyMemory（免密钥官方接口，但本质是翻译记忆库：无匹配时返回原文）
  static const String mymemory = 'mymemory';

  /// LibreTranslate（开源，理论可自建；公共实例多已要求密钥）
  static const String libre = 'libre';

  /// Google Cloud Translation v2（需 API Key，最稳定）
  static const String google = 'google';

  /// 百度翻译开放平台（需 App ID + 密钥）
  static const String baidu = 'baidu';

  /// 自定义 HTTP 接口
  static const String custom = 'custom';

  /// 「自动」模式按此顺序尝试（前者失败则退到后者）
  static const List<String> autoChain = [googlePublic, mymemory, libre];
}

class TranslateConfig {
  /// 见 [TransProvider]
  ///
  /// 默认 **auto**：见 [TransProvider.auto] 的说明。
  String provider;

  String targetLang;

  String googleApiKey;
  String baiduAppId;
  String baiduKey;

  /// LibreTranslate 实例地址（可自建）。公共实例可能要密钥。
  String libreUrl;

  /// LibreTranslate 的 API Key（公共实例现在需要；自建通常为空）
  String libreApiKey;

  String customUrl;
  String customMethod; // GET / POST
  String customHeaders; // JSON 对象文本
  String customBody; // 含 {text} {from} {to} 占位符
  String customResultPath; // 如 data.translations.0.translatedText
  /// 自定义接口返回「识别出的源语言」的字段路径（可选）。
  /// 留空则该接口不参与「对方语言」的自动学习。
  String customDetectPath;
  /// 自定义接口若把结果放在响应头/纯文本，可把 path 留空 → 直接取整个响应体
  bool customPlainText;

  TranslateConfig({
    this.provider = TransProvider.auto,
    this.targetLang = 'zh',
    this.googleApiKey = '',
    this.baiduAppId = '',
    this.baiduKey = '',
    this.libreUrl = 'https://libretranslate.com',
    this.libreApiKey = '',
    this.customUrl = '',
    this.customMethod = 'POST',
    this.customHeaders = '{"Content-Type": "application/json"}',
    this.customBody = '{"q": "{text}", "source": "{from}", "target": "{to}"}',
    this.customResultPath = '',
    this.customDetectPath = '',
    this.customPlainText = false,
  });

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'targetLang': targetLang,
        'googleApiKey': googleApiKey,
        'baiduAppId': baiduAppId,
        'baiduKey': baiduKey,
        'libreUrl': libreUrl,
        'libreApiKey': libreApiKey,
        'customUrl': customUrl,
        'customMethod': customMethod,
        'customHeaders': customHeaders,
        'customBody': customBody,
        'customResultPath': customResultPath,
        'customDetectPath': customDetectPath,
        'customPlainText': customPlainText,
      };

  static TranslateConfig fromJson(Object? j) {
    final c = TranslateConfig();
    if (j is! Map) return c;
    String s(String k, String fb) => j[k]?.toString() ?? fb;
    return TranslateConfig(
      provider: s('provider', c.provider),
      targetLang: s('targetLang', c.targetLang),
      googleApiKey: s('googleApiKey', c.googleApiKey),
      baiduAppId: s('baiduAppId', c.baiduAppId),
      baiduKey: s('baiduKey', c.baiduKey),
      libreUrl: s('libreUrl', c.libreUrl),
      libreApiKey: s('libreApiKey', c.libreApiKey),
      customUrl: s('customUrl', c.customUrl),
      customMethod: s('customMethod', c.customMethod),
      customHeaders: s('customHeaders', c.customHeaders),
      customBody: s('customBody', c.customBody),
      customResultPath: s('customResultPath', c.customResultPath),
      customDetectPath: s('customDetectPath', c.customDetectPath),
      customPlainText: j['customPlainText'] == true,
    );
  }

  /// 当前接口是否已配置到「可发起请求」的程度
  bool get ready => switch (provider) {
        // 自动模式与免密钥接口都不需要凭据
        TransProvider.auto => true,
        TransProvider.googlePublic => true,
        TransProvider.mymemory => true,
        // 自建实例通常不需要 Key；公共实例需要由用户填，故不强制
        TransProvider.libre => libreUrl.trim().isNotEmpty,
        TransProvider.google => googleApiKey.trim().isNotEmpty,
        TransProvider.baidu =>
          baiduAppId.trim().isNotEmpty && baiduKey.trim().isNotEmpty,
        TransProvider.custom => customUrl.trim().isNotEmpty,
        _ => false,
      };

  /// 配置缺失的具体原因（用于界面提示，非本地化文本 → 由 UI 转文案）
  String get missingField => switch (provider) {
        TransProvider.auto => '',
        TransProvider.googlePublic => '',
        TransProvider.mymemory => '',
        TransProvider.libre => 'libreUrl',
        TransProvider.google => 'googleApiKey',
        TransProvider.baidu =>
          baiduAppId.trim().isEmpty ? 'baiduAppId' : 'baiduKey',
        TransProvider.custom => 'customUrl',
        _ => 'provider',
      };
}

// ───────────────────────── 单条会话的翻译设置 ─────────────────────────

/// 每个会话（私聊按呼号、群聊按 groupId）独立的语言与自动翻译设置
///
/// 双向模型（这是「翻译成对方语言」的基础）：
///   - [peerLang]：**对方的**语言。空串表示还不知道 → 由接口在翻译对方消息时
///     自动识别并回填（见 [TranslateService] 的识别结果），用户也可手动指定。
///     空串 + 自动识别都拿不到时，翻译我方消息会回落到 [targetLang]。
///   - [targetLang]：**我**要看的语言（收到对方消息时翻成它）。
///     默认取当前界面语言，因为用户最可能就是想用界面语言读。
///   - [auto]：收到对方消息时自动翻译（只翻收到的，不翻自己发的）。
///   - [contrast]：对照显示 —— 原文与译文同时保留（关掉则译文替换原文显示）。
class ConvTranslatePref {
  /// 我的语言：收到对方消息翻译成它
  String targetLang;

  /// 对方的语言：'' = 未知（自动识别）；也可手填
  String peerLang;

  bool auto;

  /// 对照显示（原文 + 译文同屏）
  bool contrast;

  /// 发送前把输入译成对方的语言再发出。
  ///
  /// 默认**关闭**：这会改变真正发到空中的内容，属「会发出去的不可撤销操作」，
  /// 必须由用户显式开启（并可在发送前预览）。
  bool translateOutgoing;

  ConvTranslatePref({
    required this.targetLang,
    this.peerLang = '',
    this.auto = false,
    this.contrast = true,
    this.translateOutgoing = false,
  });

  Map<String, dynamic> toJson() => {
        'targetLang': targetLang,
        'peerLang': peerLang,
        'auto': auto,
        'contrast': contrast,
        'translateOutgoing': translateOutgoing,
      };

  static ConvTranslatePref fromJson(Object? j, String fallbackLang) {
    if (j is! Map) return ConvTranslatePref(targetLang: fallbackLang);
    return ConvTranslatePref(
      targetLang: j['targetLang']?.toString() ?? fallbackLang,
      peerLang: j['peerLang']?.toString() ?? '',
      auto: j['auto'] == true,
      contrast: j['contrast'] != false,
      translateOutgoing: j['translateOutgoing'] == true,
    );
  }
}

/// 翻译方向 → 实际目标语言。
///
/// 抽成纯函数是为了可单测：这里一旦算错，表现是「翻译出来是同一个语言」
/// 或「拿自己的语言当对方语言」，都不是一眼能看出来的错误。
class TransDirection {
  /// 翻译**对方发来的**消息 → 目标是我的语言
  static String targetForIncoming(ConvTranslatePref p, String fallback) =>
      p.targetLang.isNotEmpty ? p.targetLang : fallback;

  /// 翻译**我发出的**消息 → 目标是对方的语言（未知时回落）
  static String targetForOutgoing(ConvTranslatePref p, String fallback) =>
      p.peerLang.isNotEmpty ? p.peerLang : fallback;

  /// 该会话是否值得自动翻译（不知道对方说什么、也还没配过目标语言时，
  /// 自动翻出来可能是同一种语言，白费一次请求）
  static bool worthAuto(ConvTranslatePref p) =>
      p.targetLang.isNotEmpty && p.targetLang != 'auto';

  /// 能否把「我写的内容」译成对方的语言：必须知道对方的语言，
  /// 且不能等于我自己要读的语言（否则译了等于没译）。
  static bool canTranslateOutgoing(ConvTranslatePref p) =>
      p.peerLang.isNotEmpty && p.peerLang != p.targetLang;

  /// 译文的长度是否超出当前模式的上限（0 = 不限）
  static bool exceedsLimit(String text, int limit) =>
      limit > 0 && text.trim().length > limit;
}

// ───────────────────────── 翻译服务 ─────────────────────────

/// 译文处理策略。
///
/// 这里记录两条**实测得来**的教训，改动前请先读完：
///
/// 1. **「返回原文」不能当成失败，更不能因此切换接口。**
///    原文与译文相同有两种完全正当的情形：
///      - 内容本来就不需要翻译（数字、坐标、呼号、URL、纯符号）
///      - 源语言已经是目标语言（中文群里中文用户看中文消息）
///    曾经把 echo 判为失败并自动跳到下一个接口，结果是：中文群聊里
///    每条消息都会「翻译失败 → 跳接口 → 三个都失败」，群聊看起来完全不能用。
///    现在 echo 只作为一个**软标记**交给界面如实说明，绝不触发跳接口。
///
/// 2. **连接口都不该调的输入要提前拦掉**：数字/符号/呼号调翻译 API
///    既浪费额度又必然拿到 echo。
class TransSanity {
  TransSanity._();

  /// 归一化：去掉空白、标点、符号，并统一小写
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '');

  /// 输出是否与输入实质相同（忽略大小写/标点/空白）
  static bool isEcho(String src, String out) {
    final a = _norm(src);
    final b = _norm(out);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b;
  }

  /// 是否像业余无线电呼号（含 SSID）：`BG7LZQ` / `BG7LZQ-9` / `JA1XYZ`
  ///
  /// APRS 消息里大量出现呼号，这类内容翻不出东西，
  /// 提前识别可省掉一次注定无用的请求。
  static final RegExp _callsign =
      RegExp(r'^[A-Za-z]{1,2}[0-9][A-Za-z]{1,4}(-[0-9]{1,2})?$');

  static bool looksLikeCallsign(String s) =>
      _callsign.hasMatch(s.trim());

  /// 该内容是否**需要**翻译。
  ///
  /// 返回 false 时调用方应直接使用原文、不请求任何接口。
  /// 判据：里面得至少有一个字母；纯数字/标点/符号/emoji 没有可翻译的内容。
  static bool needsTranslation(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    // 纯呼号直接跳过（本应用场景高频出现）
    if (looksLikeCallsign(t)) return false;
    // 需要至少一个「字母类」字符（任何文种，含中日韩）
    return RegExp(r'[\p{L}]', unicode: true).hasMatch(t);
  }

  /// 目标语言是否属「非拉丁文字」体系
  static bool needsNonLatin(String lang) =>
      const {'zh', 'zh-TW', 'ja', 'ko', 'th', 'ar', 'ru'}.contains(lang);

  /// **仅供参考**的「看起来没有真正翻译」判断。
  ///
  /// 注意：**绝不可以用它来判失败或切换接口** —— 它无法区分
  /// 「接口没翻」与「本来就该一样」（数字、同语言）。仅用于在界面上
  /// 给用户一句如实的说明。
  static bool looksUntranslated(String src, String out, String target) {
    if (out.trim().isEmpty) return true;
    if (isEcho(src, out)) return true;
    // 目标是中日韩等文种，却只回来 ASCII 字母 → 很可能没翻
    if (needsNonLatin(target) &&
        !RegExp(r'[^\x00-\x7F]').hasMatch(out) &&
        RegExp(r'[A-Za-z]').hasMatch(out) &&
        !looksLikeCallsign(src)) {
      return true;
    }
    return false;
  }
}

/// 翻译结果 + 接口识别出的源语言/// 翻译结果 + 接口识别出的源语言
///
/// 为什么要带识别结果：本应用支持「翻译成**对方的**语言」，而对方说什么
/// 语言用户通常并不知道。三家接口在 `from=auto` 时都会回传识别结果
/// （Google 的 `detectedSourceLanguage`、百度的 `from`），
/// 于是「对方的语言」可以自己学出来，无需用户手填。
class TranslateResult {
  /// 译文
  final String text;

  /// 接口识别出的源语言（内部短码）；接口未回传时为 null
  final String? detected;

  /// **无需翻译**（数字/符号/呼号等），[text] 即原文，未请求任何接口
  final bool skipped;

  /// 接口返回的内容与原文实质相同（可能是正常的，也可能未翻译）
  final bool sameAsSource;

  const TranslateResult(
    this.text, {
    this.detected,
    this.skipped = false,
    this.sameAsSource = false,
  });
}

class TranslateException implements Exception {
  final String message;
  TranslateException(this.message);
  @override
  String toString() => message;
}

class TranslateService {
  TranslateService._();
  static final TranslateService instance = TranslateService._();

  static const _kConfig = 'translateConfigJson';
  /// 翻译缓存键。对外可见（`kCachePrefKey`）是因为备份要**显式**把它排除：
  /// 缓存随时能再生成，导入旧缓存会把新翻译顶掉。
  static const kCachePrefKey = 'translateCacheJson';
  static const _kCache = kCachePrefKey;
  static const _kPrefPrefix = 'transPref_';

  final TranslateConfig config = TranslateConfig();

  /// 结果缓存：`接口|目标语言|原文` → 译文
  final Map<String, String> _cache = {};
  static const int _maxCache = 800;

  /// 每个会话的偏好（运行时缓存 + 落盘）
  final Map<String, ConvTranslatePref> _prefs = {};

  /// 是否已从磁盘加载
  bool loaded = false;

  /// 当前界面语言（l10n 的 locale 写法）。
  ///
  /// 用来给新会话的「我的语言」取默认值：**必须跟随界面语言**，
  /// 否则中文界面 + 默认 targetLang=zh 时，把中文消息翻成中文
  /// = 原文照抄，用户会以为「翻译没生效」。
  String uiLocale = 'zh';

  void setUiLocale(String locale) {
    if (locale.isEmpty || locale == uiLocale) return;
    uiLocale = locale;
  }

  /// 新会话的默认目标语言（= 我的语言 = 界面语言）
  String get defaultTarget => TransLang.fromUiLocale(uiLocale);

  /// 统计（供设置页展示，让用户对「有没有真的在调接口」有感知）
  int requestCount = 0;
  int failureCount = 0;

  Future<void> load() async {
    if (loaded) return;
    loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      final c = p.getString(_kConfig);
      if (c != null && c.isNotEmpty) {
        _copy(TranslateConfig.fromJson(jsonDecode(c)), config);
      }
      final cache = p.getString(_kCache);
      if (cache != null && cache.isNotEmpty) {
        final m = jsonDecode(cache);
        if (m is Map) {
          m.forEach((k, v) => _cache['$k'] = '$v');
        }
      }
      for (final key in p.getKeys()) {
        if (!key.startsWith(_kPrefPrefix)) continue;
        final raw = p.getString(key);
        if (raw == null || raw.isEmpty) continue;
        try {
          _prefs[key.substring(_kPrefPrefix.length)] = ConvTranslatePref.fromJson(
            jsonDecode(raw),
            defaultTarget,
          );
        } catch (_) {}
      }
    } catch (_) {}
  }

  static void _copy(TranslateConfig from, TranslateConfig to) {
    to
      ..provider = from.provider
      ..targetLang = from.targetLang
      ..googleApiKey = from.googleApiKey
      ..baiduAppId = from.baiduAppId
      ..baiduKey = from.baiduKey
      ..libreUrl = from.libreUrl
      ..libreApiKey = from.libreApiKey
      ..customUrl = from.customUrl
      ..customMethod = from.customMethod
      ..customHeaders = from.customHeaders
      ..customBody = from.customBody
      ..customResultPath = from.customResultPath
      ..customDetectPath = from.customDetectPath
      ..customPlainText = from.customPlainText;
  }

  Future<void> saveConfig() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kConfig, jsonEncode(config.toJson()));
    } catch (_) {}
  }

  // ─── 会话偏好 ───

  ConvTranslatePref prefFor(String convKey) => _prefs.putIfAbsent(
        convKey,
        // 默认「我的语言」= 界面语言；「对方的语言」留空由接口识别
        () => ConvTranslatePref(targetLang: defaultTarget),
      );

  Future<void> savePref(String convKey) async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = _prefs[convKey];
      if (v == null) return;
      await p.setString('$_kPrefPrefix$convKey', jsonEncode(v.toJson()));
    } catch (_) {}
  }

  // ─── 主入口 ───

  String _cacheKey(String text, String from, String to) =>
      '${config.provider}|$from|$to|$text';

  /// 取缓存（不发起请求）
  String? cached(String text, String from, String to) =>
      _cache[_cacheKey(text, from, to)];

  /// 翻译。失败抛 [TranslateException]（消息已是可读文本）。
  ///
  /// 流程（顺序很重要）：
  ///   ① **预检**：数字/符号/呼号等无需翻译的内容直接返回原文，
  ///      **连接口都不调**（省额度、也避免拿到无意义的 echo）
  ///   ② 自动模式按候选链尝试；**只在硬失败（网络/HTTP/解析）时才换下一个接口**
  ///   ③ 结果与原文相同时**不判失败**，只标记 `sameAsSource` 交给界面说明
  Future<TranslateResult> translate(
    String text, {
    String from = 'auto',
    String? to,
  }) async {
    final target = to ?? config.targetLang;
    final src = text.trim();
    if (src.isEmpty) return const TranslateResult('');
    // ① 预检：没有可翻译的内容（纯数字/符号/呼号）→ 原样返回，不发请求
    if (!TransSanity.needsTranslation(src)) {
      return TranslateResult(src, skipped: true, detected: from == 'auto' ? null : from);
    }
    if (!config.ready) {
      throw TranslateException('not-configured:${config.missingField}');
    }
    final cacheKey = _cacheKey(src, from, target);
    final hit = _cache[cacheKey];
    if (hit != null) {
      return TranslateResult(
        hit,
        sameAsSource: TransSanity.looksUntranslated(src, hit, target),
      );
    }

    requestCount++;
    try {
      final r = config.provider == TransProvider.auto
          ? await _viaAutoChain(src, from, target)
          : await _viaOne(config.provider, src, from, target);
      final out = r.text.trim();
      _cache[cacheKey] = out;
      unawaited(_persistCache());
      // ③ echo 只作软标记：绝大多数情况是「本来就无需翻译」或
      //    「源语言已是目标语言」，不该报错、更不该换接口
      return TranslateResult(
        out,
        detected: r.detected,
        sameAsSource:
            TransSanity.looksUntranslated(src, out, target),
      );
    } catch (e) {
      failureCount++;
      rethrow;
    }
  }

  /// 自动模式：按候选链尝试，返回第一个**硬成功**的结果。
  ///
  /// **只在硬失败时才换下一个接口**（超时/网络/HTTP 错误/解析失败）。
  /// 不因为「译文与原文相同」而换接口 —— 那种情况往往是内容本来就无需
  /// 翻译（数字、呼号）或源语言已是目标语言，换接口既浪费额度，
  /// 还会把本来正常的结果变成「全部失败」。详见 [TransSanity] 的说明。
  Future<TranslateResult> _viaAutoChain(
      String text, String from, String to) async {
    final tried = <String>[];
    for (final p in TransProvider.autoChain) {
      if (p == TransProvider.libre && config.libreUrl.trim().isEmpty) continue;
      try {
        final r = await _viaOne(p, text, from, to);
        lastProviderUsed = p;
        return r;
      } catch (e) {
        tried.add('$p:${_short(e)}');
      }
    }
    lastProviderUsed = '';
    throw TranslateException('auto-all-failed:${tried.join(', ')}');
  }

  /// 最近一次成功使用的接口（自动模式下让用户知道实际用了谁）
  String lastProviderUsed = '';

  static String _short(Object e) {
    final s = '$e'.replaceAll('TranslateException: ', '');
    return s.length > 60 ? '${s.substring(0, 60)}…' : s;
  }

  Future<TranslateResult> _viaOne(
      String provider, String text, String from, String to) async {
    final TranslateResult r;
    try {
      r = switch (provider) {
        TransProvider.googlePublic => await _googlePublic(text, from, to),
        TransProvider.mymemory => await _mymemoryOnly(text, from, to),
        TransProvider.libre => await _libre(text, from, to),
        TransProvider.google => await _google(text, from, to),
        TransProvider.baidu => await _baidu(text, from, to),
        TransProvider.custom => await _custom(text, from, to),
        _ => throw TranslateException('unknown-provider:$provider'),
      };
    } on TranslateException catch (e) {
      // 把「该接口不支持这个语言」从一堆 HTTP 细节里识别出来。
      //
      // 各接口语种范围不同（百度标准版支持印尼语 id，但并非所有方向都支持），
      // 这类失败若不单独归类，用户只会看到「400 Invalid Value」，
      // 完全不知道换一个接口就能解决 —— 这是最需要可行动提示的场景。
      final msg = e.message;
      final http4xx = msg.startsWith('400') || msg.startsWith('404');
      final mentionsLang = msg.contains('Invalid Value') ||
          msg.contains('invalid target') ||
          msg.toLowerCase().contains('language') ||
          msg.toLowerCase().contains('unsupported');
      if (http4xx && mentionsLang) {
        throw TranslateException('lang-unsupported:$provider:$to');
      }
      rethrow;
    }
    // 注意：这里**不再**因为「译文与原文相同」而判失败或换接口。
    // 那会把「数字/呼号/同语言」这类正常情况误报成失败，
    // 并在自动模式下连锁跳到全部接口失败。软标记交给上层（见 translate）。
    lastProviderUsed = provider;
    return r;
  }

  /// 只要译文的便捷入口  /// 只要译文的便捷入口
  Future<String> translateText(String text, {String from = 'auto', String? to}) async =>
      (await translate(text, from: from, to: to)).text;

  Future<void> _persistCache() async {
    try {
      // 缓存无上限增长会拖慢启动；裁剪到最近 _maxCache 条
      if (_cache.length > _maxCache) {
        final keys = _cache.keys.take(_cache.length - _maxCache).toList();
        for (final k in keys) {
          _cache.remove(k);
        }
      }
      final p = await SharedPreferences.getInstance();
      await p.setString(_kCache, jsonEncode(_cache));
    } catch (_) {}
  }

  void clearCache() {
    _cache.clear();
    unawaited(() async {
      try {
        final p = await SharedPreferences.getInstance();
        await p.remove(_kCache);
      } catch (_) {}
    }());
  }

  // ─── 各接口实现 ───

  /// MyMemory（免密钥；**翻译记忆库**，无匹配语料时返回原文 ——
  /// 因此调用方必须用 [TransSanity] 校验，不能直接采信）
  Future<TranslateResult> _mymemoryOnly(
      String text, String from, String to) async {
    // MyMemory 不支持自动识别：拿不到源语言就没法用（这也是它不能
    // 单独当默认接口的原因之一）
    if (from == 'auto') {
      throw TranslateException('mymemory-needs-source');
    }
    return _myMemory(text, from, to);
  }

  /// Google 公开端点（网页版 translate.googleapis.com）
  ///
  /// 响应是嵌套数组：`[[["译文","原文",...],...],null,"en",...]`
  /// 长文本会被拆成多段（`root[0]` 是段落数组），必须**全部拼接**，
  /// 只取第一段会得到半截译文。
  /// 识别出的源语言在 `root[2]`。
  Future<TranslateResult> _googlePublic(
      String text, String from, String to) async {
    final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
      'client': 'gtx',
      'sl': from == 'auto' ? 'auto' : TransLang.toGoogle(from),
      'tl': TransLang.toGoogle(to),
      'dt': 't',
      'q': text,
    });
    final resp = await _send('GET', uri);
    Object? root;
    try {
      root = jsonDecode(resp);
    } catch (e) {
      throw TranslateException('free-bad-json:$e');
    }
    if (root is! List || root.isEmpty) {
      throw TranslateException('free-bad-shape:${_trunc(resp)}');
    }
    final segs = root[0];
    if (segs is! List || segs.isEmpty) {
      throw TranslateException('free-empty:${_trunc(resp)}');
    }
    final sb = StringBuffer();
    for (final seg in segs) {
      if (seg is List && seg.isNotEmpty && seg[0] != null) {
        sb.write('${seg[0]}');
      }
    }
    final out = sb.toString();
    if (out.trim().isEmpty) {
      throw TranslateException('free-empty:${_trunc(resp)}');
    }
    final det = root.length > 2 ? root[2]?.toString() : null;
    return TranslateResult(out, detected: _googleToShort(det));
  }

  /// MyMemory（免密钥，需明确源语言；匿名额度有限）
  Future<TranslateResult> _myMemory(
      String text, String from, String to) async {
    final uri = Uri.https('api.mymemory.translated.net', '/get', {
      'q': text,
      // MyMemory 的中文是 zh-CN / zh-TW（与 Google 同形但不完全等价）
      'langpair': '${TransLang.toMyMemory(from)}|${TransLang.toMyMemory(to)}',
    });
    final resp = await _send('GET', uri);
    final map = _decodeJson(resp);
    final data = map['responseData'];
    if (data is Map && data['translatedText'] != null) {
      final t = '${data['translatedText']}';
      if (t.trim().isNotEmpty) {
        return TranslateResult(t, detected: from);
      }
    }
    throw TranslateException('mymemory-empty:${_trunc(resp)}');
  }

  /// LibreTranslate（开源，建议自建；公共实例现在多要求 API Key）
  ///
  /// 与其它接口的关键差异：**支持的语言由实例决定**（自建时尤其如此，
  /// 只装了几种语言的实例翻译不了别的语种）。而 /languages 接口可以
  /// 列出该实例的真实能力 —— 所以这里先探测再翻译，避免发出注定 400 的请求。
  Future<TranslateResult> _libre(String text, String from, String to) async {
    final base = config.libreUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) throw TranslateException('libre-url-empty');
    final key = config.libreApiKey.trim();
    final target = TransLang.toLibre(to);

    // ① 能力探测（带缓存）：不支持就直接报「此实例不支持该语言」，
    //    这比让用户看到一条 400/500 有用得多
    final langs = await _libreLanguages(base);
    if (langs != null && langs.isNotEmpty && !langs.contains(target)) {
      throw TranslateException('libre-unsupported-lang:$target');
    }

    final body = <String, dynamic>{
      'q': text,
      'source': from == 'auto' ? 'auto' : TransLang.toLibre(from),
      'target': target,
      'format': 'text',
    };
    if (key.isNotEmpty) body['api_key'] = key;

    final resp = await _send(
      'POST',
      Uri.parse('$base/translate'),
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body),
    );
    final map = _decodeJson(resp);
    final t = map['translatedText'];
    if (t == null) {
      final err = map['error'] ?? map['message'] ?? _trunc(resp);
      throw TranslateException('libre-error:$err');
    }
    // LibreTranslate 在 source=auto 时会回传 detectedLanguage
    final det = map['detectedLanguage'] ?? map['detected_language'];
    final detected = det is Map ? det['language']?.toString() : det?.toString();
    return TranslateResult('$t',
        detected: detected == null ? null : _libreToShort(detected));
  }

  /// 实例支持的语言码集合（按 base URL 缓存；探测失败返回 null 表示
  /// 「不知道」，此时仍继续翻译而不是直接判死）
  final Map<String, Set<String>> _libreLangs = {};

  Future<Set<String>?> _libreLanguages(String base) async {
    final cached = _libreLangs[base];
    if (cached != null) return cached;
    try {
      final resp = await _send('GET', Uri.parse('$base/languages'));
      final list = jsonDecode(resp);
      if (list is List) {
        final set = <String>{};
        for (final it in list) {
          if (it is Map && it['code'] != null) set.add('${it['code']}');
        }
        if (set.isNotEmpty) {
          _libreLangs[base] = set;
          return set;
        }
      }
    } catch (_) {
      // 探测失败不阻断：有些实例禁用了 /languages
    }
    return null;
  }

  /// LibreTranslate 语言码 → 内部短码（[toLibre] 的逆映射）
  static String? _libreToShort(String code) {
    for (final l in TransLang.all) {
      if (l.code == 'auto') continue;
      if (TransLang.toLibre(l.code) == code) return l.code;
    }
    return TransLang.byCode(code) != null ? code : null;
  }

  /// Google Cloud Translation v2：
  /// POST https://translation.googleapis.com/language/translate/v2?key=KEY
  /// body {q, target, format, [source]}
  /// → data.translations[0].translatedText（HTML 实体需反转义）
  Future<TranslateResult> _google(String text, String from, String to) async {
    final uri = Uri.parse(
      'https://translation.googleapis.com/language/translate/v2'
      '?key=${Uri.encodeQueryComponent(config.googleApiKey.trim())}',
    );
    final body = <String, dynamic>{
      'q': text,
      'target': TransLang.toGoogle(to),
      'format': 'text',
    };
    if (from != 'auto') body['source'] = TransLang.toGoogle(from);
    final resp = await _send(
      'POST',
      uri,
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body),
    );
    final map = _decodeJson(resp);
    final list = _dig(map, 'data.translations');
    if (list is List && list.isNotEmpty) {
      final first = list.first as Map;
      final t = first['translatedText'];
      if (t != null) {
        // from=auto 时 Google 会回传 detectedSourceLanguage，用它学习对方语言
        final det = first['detectedSourceLanguage']?.toString();
        return TranslateResult(
          _unescapeHtml('$t'),
          detected: _googleToShort(det),
        );
      }
    }
    throw TranslateException(_fail('google', resp));
  }

  /// 百度通用文本翻译：
  /// GET/POST https://fanyi-api.baidu.com/api/trans/vip/translate
  /// q / from / to / appid / salt / sign=MD5(appid+q+salt+密钥)
  /// → trans_result[0].dst
  Future<TranslateResult> _baidu(String text, String from, String to) async {
    final appid = config.baiduAppId.trim();
    final key = config.baiduKey.trim();
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    final sign = md5Hex('$appid$text$salt$key');
    final params = {
      'q': text,
      'from': from == 'auto' ? 'auto' : TransLang.toBaidu(from),
      'to': TransLang.toBaidu(to),
      'appid': appid,
      'salt': salt,
      'sign': sign,
    };
    // 用 POST 表单：GET 会把整条消息放进 URL，长文本容易被网关截断
    final resp = await _send(
      'POST',
      Uri.parse('https://fanyi-api.baidu.com/api/trans/vip/translate'),
      headers: const {
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
      },
      body: params.entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}='
              '${Uri.encodeQueryComponent(e.value)}')
          .join('&'),
    );
    final map = _decodeJson(resp);
    if (map['error_code'] != null) {
      final code = '${map['error_code']}';
      // 语言的「支持范围」是各接口最实际的差异：百度标准版就支持印尼语（id），
      // 但并非所有语种/方向都支持。58001 就是「该语言方向不支持」——
      // 这类失败最容易被误读成「应用坏了」，必须给出可行动的提示。
      if (code == '58001') {
        throw TranslateException(
          'lang-unsupported:baidu:'
          '${TransLang.toBaidu(from)}->${TransLang.toBaidu(to)}',
        );
      }
      throw TranslateException(
        'baidu $code: ${_baiduErrorText(code)}'
        '${map['error_msg'] == null ? '' : ' (${map['error_msg']})'}',
      );
    }
    final list = _dig(map, 'trans_result');
    if (list is List && list.isNotEmpty) {
      final d = (list.first as Map)['dst'];
      if (d != null) {
        // 百度的识别结果在响应根的 from 字段
        return TranslateResult('$d', detected: _baiduToShort(map['from']?.toString()));
      }
    }
    throw TranslateException(_fail('baidu', resp));
  }

  /// 自定义接口：URL / 方法 / 请求头 / 请求体模板 / 结果字段路径全部由用户给定
  Future<TranslateResult> _custom(String text, String from, String to) async {
    final url = config.customUrl.trim();
    if (url.isEmpty) throw TranslateException('custom-url-empty');
    String subst(String tpl) => tpl
        .replaceAll('{text}', text)
        .replaceAll('{from}', from == 'auto' ? TransLang.toBaidu(from) : from)
        .replaceAll('{to}', to);
    final target = Uri.parse(subst(url));
    final method = config.customMethod.trim().toUpperCase();
    Map<String, String> headers = {};
    final rawHeaders = config.customHeaders.trim();
    if (rawHeaders.isNotEmpty) {
      try {
        final m = jsonDecode(rawHeaders);
        if (m is Map) {
          m.forEach((k, v) => headers['$k'] = '$v');
        }
      } catch (e) {
        throw TranslateException('custom-headers-invalid: $e');
      }
    }
    final body = method == 'GET' ? null : subst(config.customBody);
    final resp = await _send(method, target, headers: headers, body: body);
    if (config.customPlainText || config.customResultPath.trim().isEmpty) {
      // 未指定路径 → 整个响应体就是译文（部分自建接口如此）
      return TranslateResult(resp);
    }
    final decoded = _decodeJson(resp);
    final v = _dig(decoded, config.customResultPath.trim());
    if (v == null) {
      throw TranslateException(
        'custom-path-miss:${config.customResultPath} in ${_trunc(resp)}',
      );
    }
    // 自定义接口若按同一约定返回识别语言，也能参与「对方语言」学习
    String? det;
    final p = config.customDetectPath.trim();
    if (p.isNotEmpty) {
      det = _dig(decoded, p)?.toString();
    }
    return TranslateResult(v is String ? v : jsonEncode(v), detected: det);
  }

  // ─── HTTP 与工具 ───

  /// 统一 HTTP 调用（实现见 net/http_send.dart，按平台条件导入）
  Future<String> _send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    String? body,
  }) async {
    try {
      return await httpSend(method, uri, headers: headers, body: body);
    } on HttpStatusError catch (e) {
      throw TranslateException('${e.status} ${_trunc(e.body)}');
    } on TimeoutException {
      throw TranslateException('timeout');
    } on TranslateException {
      rethrow;
    } catch (e) {
      throw TranslateException('$e');
    }
  }

  static String _trunc(String s) =>
      s.length <= 200 ? s : '${s.substring(0, 200)}…';

  String _fail(String provider, String resp) =>
      '$provider empty response: ${_trunc(resp)}';

  /// 解析 JSON 响应对象。
  ///
  /// 三家接口的响应体都是 JSON **对象**（结果字段路径可能指向数组元素，
  /// 但根一定是对象），所以这里固定返回 Map —— 调用点无需对 Object?
  /// 做索引后再判空，少一层易错的类型体操。
  static Map<String, dynamic> _decodeJson(String s) {
    Object? d;
    try {
      d = jsonDecode(s);
    } catch (e) {
      throw TranslateException('invalid-json: $e');
    }
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return d.map((k, v) => MapEntry('$k', v));
    throw TranslateException('invalid-json-shape:${_trunc(s)}');
  }

  /// 点号路径取值，支持数组序号：`data.translations.0.translatedText`
  static Object? _dig(Object? root, String path) {
    Object? cur = root;
    for (final seg in path.split('.')) {
      if (seg.isEmpty) continue;
      if (cur is Map) {
        cur = cur[seg];
      } else if (cur is List) {
        final i = int.tryParse(seg);
        if (i == null || i < 0 || i >= cur.length) return null;
        cur = cur[i];
      } else {
        return null;
      }
      if (cur == null) return null;
    }
    return cur;
  }

  /// 百度常见错误码 → 人话。
  ///
  /// 官方只给数字码，用户看到「error_code 54001」完全无从下手。
  /// 这些是官方文档明确记载的码，映射固定、不会漂移。
  static String _baiduErrorText(String code) => switch (code) {
        '52001' => 'request timeout',
        '52002' => 'system error',
        '52003' => 'unauthorized: check App ID / key',
        '54000' => 'missing required parameter',
        '54001' => 'invalid signature: check App ID and secret',
        '54003' => 'rate limited: slow down or upgrade quota',
        '54004' => 'insufficient balance',
        '54005' => 'too many long queries at once',
        '58000' => 'client IP not allowed',
        '58001' => 'language direction not supported',
        '58002' => 'service disabled',
        '90107' => 'auth not effective yet',
        _ => 'baidu error',
      };

  /// Google 的语言码（zh-CN / zh-TW / en …）→ 内部短码
  static String? _googleToShort(String? code) {
    if (code == null || code.isEmpty) return null;
    final c = code.replaceAll('_', '-');
    if (c == 'zh-CN' || c == 'zh-Hans' || c == 'zh') return 'zh';
    if (c == 'zh-TW' || c == 'zh-Hant' || c == 'zh-HK') return 'zh-TW';
    // 其余（en / ja / es / ko / fr …）两边写法一致
    return TransLang.byCode(c) != null ? c : c.split('-').first;
  }

  /// 百度的语言码（zh / cht / jp / kor / spa …）→ 内部短码（[toBaidu] 的逆映射）
  static String? _baiduToShort(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final l in TransLang.all) {
      if (l.code == 'auto') continue;
      if (TransLang.toBaidu(l.code) == code) return l.code;
    }
    return TransLang.byCode(code) != null ? code : null;
  }

  /// Google 在 format=text 下仍可能返回 HTML 实体（&quot; &#39; 等）
  static String _unescapeHtml(String s) => s
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
}

// ───────────────────────── 纯 Dart MD5 ─────────────────────────

/// 百度接口要求 `sign = MD5(appid + q + salt + key)`（小写十六进制）。
///
/// 仓库里没有 crypto 依赖，而这里只需要一个固定算法 —— 自己实现 64 步
/// MD5 比为了一个签名引入依赖更划算，且可单测（见 test/translate_test.dart）。
String md5Hex(String input) {
  final bytes = utf8.encode(input);
  final padded = <int>[...bytes];
  final bitLen = bytes.length * 8;
  padded.add(0x80);
  while (padded.length % 64 != 56) {
    padded.add(0);
  }
  for (var i = 0; i < 8; i++) {
    padded.add((bitLen >> (8 * i)) & 0xFF);
  }

  const s = [
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
  ];
  // K 表：MD5 标准常量（floor(2^32 * |sin(i+1)|)），直接查表避免浮点误差
  const kTable = [
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
    0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
    0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
    0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
    0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
    0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
    0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
    0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
    0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
  ];

  var a0 = 0x67452301;
  var b0 = 0xefcdab89;
  var c0 = 0x98badcfe;
  var d0 = 0x10325476;

  assert(kTable.length == 64, 'MD5 K 表必须是 64 项');
  assert(s.length == 64, 'MD5 位移表必须是 64 项');

  for (var chunk = 0; chunk < padded.length; chunk += 64) {
    final m = List<int>.generate(16, (i) {
      final o = chunk + i * 4;
      return padded[o] |
          (padded[o + 1] << 8) |
          (padded[o + 2] << 16) |
          (padded[o + 3] << 24);
    });
    var a = a0, b = b0, c = c0, d = d0;
    for (var i = 0; i < 64; i++) {
      int f;
      int g;
      if (i < 16) {
        f = (b & c) | (~b & d);
        g = i;
      } else if (i < 32) {
        f = (d & b) | (~d & c);
        g = (5 * i + 1) % 16;
      } else if (i < 48) {
        f = b ^ c ^ d;
        g = (3 * i + 5) % 16;
      } else {
        f = c ^ (b | ~d);
        g = (7 * i) % 16;
      }
      f = (f + a + kTable[i] + m[g]) & 0xFFFFFFFF;
      a = d;
      d = c;
      c = b;
      b = (b + _rotl(f, s[i])) & 0xFFFFFFFF;
    }
    a0 = (a0 + a) & 0xFFFFFFFF;
    b0 = (b0 + b) & 0xFFFFFFFF;
    c0 = (c0 + c) & 0xFFFFFFFF;
    d0 = (d0 + d) & 0xFFFFFFFF;
  }

  String le(int v) {
    final sb = StringBuffer();
    for (var i = 0; i < 4; i++) {
      sb.write(((v >> (8 * i)) & 0xFF).toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  return '${le(a0)}${le(b0)}${le(c0)}${le(d0)}';
}

int _rotl(int x, int n) => ((x << n) | (x >> (32 - n))) & 0xFFFFFFFF;
