import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'weather.dart';

/// ─── 短波传播 / 电离层数据（HF propagation & ionosphere）───
///
/// 数据源：**hamqsl.com/solarxml.php**（N0NBH 整理，业余无线电界事实标准）。
/// 选它的理由：
/// - 逐**波段**给出日间/夜间传播条件（80m/40m、30m/20m、17m/15m、12m/10m），
///   正好对应「各个波段的传播信息」；
/// - 同时给 SFI / A / K 指数 / 太阳黑子 / X 射线通量 / 太阳风速 / 地磁状态 /
///   噪声底噪 / MUF，这些是判断电离层状态的核心量；
/// - **不需要 API key**（这一点很重要：和风天气的 key 是构建期注入的，
///   而这里若再引入一个密钥，就要多一处泄漏面与同步负担）；
/// - 更新频率约每小时一次，适合 30 分钟缓存。
///
/// ⚠ 关于解析方式：Dart 标准库没有 XML 解析器，为这一份**扁平且稳定**的
/// 机器生成 XML 引入 `xml` 依赖并不划算（依赖越少，CI 构建越不容易出意外）。
/// 所以这里用**针对具体标签的正则**提取，并遵守两条纪律：
/// ① 每个字段都有默认值，字段缺失/格式变化**不会抛异常**，只会显示为「--」；
/// ② 解析是纯函数（[parseHamQsl]），由单测盯住 —— 数据源格式真变了，
///    测试会红，而不是线上静默显示空值。
///
/// ⚠ 一处诚实说明：hamqsl 的条件是**全球/区域平均**，不是本地实测。
/// 所以 UI 上不要写成「你这里现在 20m 好」，而应表述为「20m 条件：好」。

/// 数据源地址。测试可注入其它 URL 以验证解析。
const String kHamQslUrl = 'https://www.hamqsl.com/solarxml.php';

/// 缓存时长：hamqsl 约每小时更新一次，30 分钟足够且不会打太勤。
const Duration kHfTtl = Duration(minutes: 30);

/// 一个波段对的传播条件（日间 / 夜间）
class HfBand {
  final String name; // 如 "80m-40m"（源数据用连字符）
  final String day; // Good / Fair / Poor / Band Closed
  final String night;

  const HfBand({required this.name, required this.day, required this.night});

  /// 展示用波段名：把源数据的 "80m-40m" 显示成 "80m/40m"（面板里用斜杠更好读）
  String get label => name.replaceAll('-', '/');

  /// 这一波段今天最好的一面（用于判断「有没有戏」）
  String get best =>
      _rank(day) >= _rank(night) ? day : night;

  static int _rank(String q) => hfQualityRank(q);
}

/// 条件 → 排序权重（越大越好）。给「取最好的一档」这类比较用。
int hfQualityRank(String q) {
  switch (q.trim().toLowerCase()) {
    case 'good':
      return 3;
    case 'fair':
      return 2;
    case 'poor':
      return 1;
    default:
      return 0; // Band Closed / 未知
  }
}

/// 当前短波/电离层状态
class HfNow {
  final String sfi; // 太阳通量指数（Solar Flux Index）
  final String aIndex; // A 指数（日）
  final String kIndex; // K 指数（3 小时）
  final String xray; // X 射线通量等级，如 "B2.2"
  final String sunspots; // 太阳黑子数
  final String solarWind; // 太阳风速 km/s
  final String geomag; // 地磁状态（QUIET / UNSETTLD / ACTIVE / STORM…）
  final String noise; // 噪声底噪，如 "S2-S3"
  final String muf; // 最高可用频率（源数据常为 NoRpt）
  final List<HfBand> bands;
  /// VHF 条件（6m/4m 的 Es 与极光）。源数据缺该节点时 `hasData` 为 false。
  final HfVhf vhf;
  final String updated; // 源数据里的更新时间字符串（GMT）

  const HfNow({
    required this.sfi,
    required this.aIndex,
    required this.kIndex,
    required this.xray,
    required this.sunspots,
    required this.solarWind,
    required this.geomag,
    required this.noise,
    required this.muf,
    required this.bands,
    this.vhf = const HfVhf(),
    required this.updated,
  });

  static const String none = '--';

  int get kValue => int.tryParse(kIndex) ?? -1;
  int get aValue => int.tryParse(aIndex) ?? -1;
  int get sfiValue => int.tryParse(sfi) ?? -1;

  /// 地磁是否活跃（K ≥ 4，或源数据直接说 ACTIVE/STORM）。
  /// 这是短波受影响最直接的一个量：地磁扰动会抬高低纬吸收、并让极区路径衰减。
  bool get geomagActive {
    final g = geomag.toUpperCase();
    if (g.contains('STORM') || g.contains('ACTIVE') || g.contains('UNSETTLD')) {
      return true;
    }
    return kValue >= 4;
  }

  /// 是否地磁暴（K ≥ 5）—— 此时高纬度短波路径基本中断
  bool get geomagStorm => kValue >= 5 || geomag.toUpperCase().contains('STORM');

  /// 太阳活动是否偏低（SFI < 100 时高波段白天机会少）
  bool get lowSolarFlux => sfiValue >= 0 && sfiValue < 100;

  /// 底噪是否偏高（S3 及以上）。
  ///
  /// 源数据给的是**范围**（如 "S2-S3"），所以要取所有 S 值里**最差**的那个：
  /// 用 firstMatch 只会取到 "S2"，于是「S2-S3」被判成底噪正常 ——
  /// 这正是单测抓出来的错（读起来像对的，跑起来是反的）。
  bool get highNoise {
    final all = RegExp(r'S(\d)').allMatches(noise);
    var worst = -1;
    for (final m in all) {
      final n = int.tryParse(m.group(1)!) ?? -1;
      if (n > worst) worst = n;
    }
    return worst >= 3;
  }

  /// 取某个波段的传播条件（按源数据的连字符名匹配，容错 "/" 写法）
  HfBand? band(String name) {
    final want = name.replaceAll('/', '-').toLowerCase();
    for (final b in bands) {
      if (b.name.toLowerCase() == want) return b;
    }
    return null;
  }

  /// 当前（按本地时间）最有戏的波段：日间看 day、夜间看 night
  HfBand? bestBandAt(DateTime t) {
    final isDay = hfIsDaytime(t);
    HfBand? best;
    var bestRank = 0;
    for (final b in bands) {
      final q = isDay ? b.day : b.night;
      final r = HfBand._rank(q);
      if (r > bestRank) {
        bestRank = r;
        best = b;
      }
    }
    return best;
  }
}

/// 解析 hamqsl 的 solarxml.php 响应（纯函数，便于单测）。
///
/// 任何字段缺失都退化成 [HfNow.none] / 空列表，**不抛异常** ——
/// 数据源改格式时应该「少显示一点」，而不是让整个面板炸掉。
HfNow? parseHamQsl(String xml) {
  if (xml.trim().isEmpty) return null;
  final root = RegExp(r'<solar>', caseSensitive: false).firstMatch(xml);
  if (root == null) return null;

  String tag(String name) {
    final m = RegExp('<$name\\s*>(.*?)</$name\\s*>',
            caseSensitive: false, dotAll: true)
        .firstMatch(xml);
    final v = m?.group(1)?.trim() ?? '';
    return v.isEmpty || v.toLowerCase().contains('norpt') ? HfNow.none : v;
  }

  // 逐波段条件：<band name="80m-40m" time="day">Poor</band>
  // 按 name 归组，day/night 配对。
  final bands = <String, Map<String, String>>{};
  final bandRe = RegExp(
    r'<band\s+name="([^"]+)"\s+time="([^"]+)"\s*>([^<]*)</band\s*>',
    caseSensitive: false,
  );
  for (final m in bandRe.allMatches(xml)) {
    final name = m.group(1)!.trim();
    final time = m.group(2)!.trim().toLowerCase();
    final cond = m.group(3)!.trim();
    bands.putIfAbsent(name, () => {})[time] = cond;
  }

  // VHF 条件：<phenomenon name="E-Skip" location="europe_6m">Band Closed</phenomenon>
  // name 有两种：'E-Skip'（含 6m/4m 专门项）与 'vhf-aurora'。
  final es = <String, String>{};
  var aurora = '';
  final phRe = RegExp(
    r'<phenomenon\s+name="([^"]+)"\s+location="([^"]+)"\s*>([^<]*)</phenomenon\s*>',
    caseSensitive: false,
  );
  for (final m in phRe.allMatches(xml)) {
    final name = m.group(1)!.trim();
    final loc = m.group(2)!.trim();
    final cond = m.group(3)!.trim();
    if (cond.isEmpty) continue;
    if (name.toLowerCase().contains('aurora')) {
      aurora = cond;
    } else if (name.toLowerCase().contains('e-skip')) {
      es[loc] = cond;
    }
  }
  final vhf = HfVhf(eSkip: es, aurora: aurora);

  final list = <HfBand>[
    for (final e in bands.entries)
      if (e.value.containsKey('day') || e.value.containsKey('night'))
        HfBand(
          name: e.key,
          day: e.value['day'] ?? HfNow.none,
          night: e.value['night'] ?? HfNow.none,
        ),
  ];
  // 源数据顺序本身是从低到高波段，保持它（不要按字典序，否则 80m 会跑到 12m 后面）
  list.sort((a, b) => _bandOrder(a.name).compareTo(_bandOrder(b.name)));

  return HfNow(
    sfi: tag('solarflux'),
    aIndex: tag('aindex'),
    kIndex: tag('kindex'),
    xray: tag('xray'),
    sunspots: tag('sunspots'),
    solarWind: tag('solarwind'),
    geomag: tag('geomagfield'),
    noise: tag('signalnoise'),
    muf: tag('muf'),
    bands: list,
    vhf: vhf,
    updated: tag('updated'),
  );
}

/// 波段排序权重（低波段在前，和业余界的习惯一致）
int _bandOrder(String name) {
  const order = ['160m', '80m', '40m', '30m', '20m', '17m', '15m', '12m', '10m',
    '6m'];
  final first = name.split('-').first.toLowerCase();
  final i = order.indexOf(first);
  return i < 0 ? order.length : i;
}


/// VHF 条件（hamqsl 的 `calculatedvhfconditions`）。
///
/// 6m 与 4m 的传播机理与 HF 完全不同，**不能**沿用「日间/夜间」那套：
///  - **Es（ sporadic-E，偶发 E 层）**：夏季最常见，单跳可跨 1000–2000km，
///    是 6m 的主要开通方式；源数据里按区域给（europe / north_america / …，
///    以及 6m/4m 专门项）。
///  - **极光（aurora）**：地磁活跃时高纬出现，用 CW/SSB 有特征性的
///    嘶哑音色 —— 这是「地磁越差、极光路径反而越好」的少数情况。
///  - **F2**：需要 MUF ≥ 50MHz（太阳活动高年偶发），源数据用 muf 字段判断。
class HfVhf {
  /// 各区 E-skip 状态：区域名 → 条件（Good/Fair/Poor/Band Closed…）
  final Map<String, String> eSkip;

  /// 极光状态（北半球）
  final String aurora;

  const HfVhf({this.eSkip = const {}, this.aurora = ''});

  bool get hasData => eSkip.isNotEmpty || aurora.isNotEmpty;

  /// 6m 的 Es 取值：优先 6m 专门项，其次取所有区域里最好的一档。
  ///
  /// 为什么取「最好」而不是平均：Es 是**局地**现象，某区开通就说明当天
  /// 有 Es 活动层。全球平均会把「开了」抹成「关着」，反而更没用。
  String get es6m {
    for (final e in eSkip.entries) {
      if (e.key.contains('6m')) return e.value;
    }
    var best = '';
    for (final v in eSkip.values) {
      if (hfQualityRank(v) > hfQualityRank(best)) best = v;
    }
    return best;
  }

  String get es4m {
    for (final e in eSkip.entries) {
      if (e.key.contains('4m')) return e.value;
    }
    return '';
  }
}

/// 6m 展望的构成（给 UI 用：分项 + 合成结论）。
class HfSixMeter {
  /// Es（偶发 E 层）—— 6m 的主要开通方式
  final String es;
  /// 极光路径
  final String aurora;
  /// F2（需 MUF ≥ 50MHz）
  final bool f2;
  final HfQuality quality;
  const HfSixMeter({
    required this.es,
    required this.aurora,
    required this.f2,
    required this.quality,
  });
}

/// 传播质量 → 级别（给 UI 选色，也用于生成建议）
/// 日间的小时区间 `[from, to)`（本地时间）—— 07:00–19:00。
///
/// 这两个数字会**随桌面组件的快照一起下发**，由 Kotlin 侧按本机时钟实时判断：
/// 组件每 30 分钟自刷新时只重绘已存的快照，若把「现在算日间还是夜间」在 Dart
/// 侧算死，用户一整天不开 App 就会出现「19:00 之后组件还指着日间」——
/// 而「一眼看出当前时段」正是这个组件要解决的问题，判错时段比不显示更糟。
/// 规则仍只在这里定义一处，Kotlin 只用不猜。
const int kHfDayFromHour = 7;
const int kHfDayToHour = 19;

/// 「现在算日间还是夜间」—— 见 [kHfDayFromHour] / [kHfDayToHour]。
///
/// **必须是唯一判据**：面板的「最有戏的波段」、给用户的建议、以及桌面组件上
/// 的「现在」游标都要落在同一个时段上。此前这段表达式在文件里抄了两遍
/// （bestBandAt 与建议生成各一份），多一个调用方就多一处漂移的地方 ——
/// 而漂移的表现是「面板说 20m 好、组件游标却指在日间」，最难解释的那种不一致。
bool hfIsDaytime(DateTime t) =>
    t.hour >= kHfDayFromHour && t.hour < kHfDayToHour;

enum HfQuality { good, fair, poor, closed, unknown }

HfQuality hfQualityOf(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'good':
      return HfQuality.good;
    case 'fair':
      return HfQuality.fair;
    case 'poor':
      return HfQuality.poor;
    case 'band closed':
      return HfQuality.closed;
    default:
      return HfQuality.unknown;
  }
}

/// 质量文字（本地化）
String hfQualityLabel(HfQuality q, AppLocalizations s) {
  switch (q) {
    case HfQuality.good:
      return s.hfQGood;
    case HfQuality.fair:
      return s.hfQFair;
    case HfQuality.poor:
      return s.hfQPoor;
    case HfQuality.closed:
      return s.hfQClosed;
    case HfQuality.unknown:
      return HfNow.none;
  }
}

/// 质量 → 颜色。与面板的级别色同一套取向（好=绿、一般=橙、差=红、关闭=灰）。
Color hfQualityColor(HfQuality q) {
  switch (q) {
    case HfQuality.good:
      return const Color(0xFF16A34A);
    case HfQuality.fair:
      return const Color(0xFFD97706);
    case HfQuality.poor:
      return const Color(0xFFE11D48);
    case HfQuality.closed:
    case HfQuality.unknown:
      return const Color(0xFF94A3B8);
  }
}


/// 6m 展望：把 Es / 极光 / F2 三条路径合成为一个结论。
///
/// 三条路径的**成因完全不同**，所以要分别判断再合成，不能只看一个数：
///   1. **Es（偶发 E 层）** —— 6m 的主要开通方式，源数据直接给（[HfVhf.es6m]）；
///   2. **极光** —— 地磁活跃（K≥4）时高纬出现；注意这是「地磁差反而有戏」
///      的少数情况，所以判据是「Kp 高 **且** 源数据说极光开通」；
///   3. **F2** —— 需要 MUF ≥ 50MHz（太阳活动高年偶发），源数据 muf 常为 NoRpt。
///
/// 合成取三者中**最好**的一档：这三条是**并列**的通路，任一条开通就值得上机，
/// 取平均会把「开了」抹平（和 [HfVhf.es6m] 取最好的理由一致）。
HfSixMeter hfSixMeter(HfNow? hf) {
  if (hf == null) {
    return const HfSixMeter(
        es: HfNow.none, aurora: HfNow.none, f2: false, quality: HfQuality.unknown);
  }
  final es = hf.vhf.es6m.isEmpty ? HfNow.none : hf.vhf.es6m;
  final auroraRaw = hf.vhf.aurora;
  // 极光只在「地磁活跃」时才有意义 —— 平静时源数据也会写 Band Closed，
  // 但若源数据说开通而 Kp 低，那是数据滞后，仍按开通处理（宁可提示上机）。
  final aurora = auroraRaw.isEmpty ? HfNow.none : auroraRaw;

  // F2：MUF ≥ 50MHz。源数据常为 NoRpt，此时无法判断，按「不成立」处理，
  // 而不是猜 —— 猜错会让用户白等一晚。
  final muf = double.tryParse(hf.muf);
  final f2 = muf != null && muf >= 50;

  // 合成：取三条通路里最好的一档（Band Closed / 未知 的自带权重为 0，
  // 所以「关着」的那几条不会把开通的那条压下去）。
  var q = hfQualityOf(es);
  final qa = hfQualityOf(aurora);
  if (_qualityRankOf(qa) > _qualityRankOf(q)) q = qa;
  if (f2) q = HfQuality.good;

  return HfSixMeter(es: es, aurora: aurora, f2: f2, quality: q);
}

int _qualityRankOf(HfQuality q) {
  switch (q) {
    case HfQuality.good:
      return 3;
    case HfQuality.fair:
      return 2;
    case HfQuality.poor:
      return 1;
    case HfQuality.closed:
    case HfQuality.unknown:
      return 0;
  }
}

/// 根据电离层状态生成**附加**的业余无线电建议。
///
/// 为什么要「附加」而不是替换：天气类建议（雷击、馈线防水、结冰…）与传播类
/// 建议是**两个独立维度**，都该看。所以这里返回额外几条，由调用方决定展示顺序
/// （当前做法：传播机会放到「通联机会」一档，反而让天气的安全警示继续排在前面 ——
/// 安全永远优先）。
///
/// 分级原则（与 weather.dart 的 `_hamTips` 一致）：
///   danger = 会损坏设备或危及人身（这里没有；地磁暴不损坏设备）
///   warn   = 传播明显变差，值得改计划
///   good   = 传播机会
///   tip    = 操作提示
List<HamTip> hfTips(HfNow? hf, AppLocalizations s, {DateTime? now}) {
  if (hf == null) return const [];
  final t = now ?? DateTime.now();
  const cGood = Color(0xFF16A34A);
  const cWarn = Color(0xFFD97706);
  const cTip = Color(0xFF2563EB);
  const cViolet = Color(0xFF7C3AED);

  final warn = <HamTip>[];
  final good = <HamTip>[];
  final tip = <HamTip>[];

  // ── 地磁 ──
  if (hf.geomagStorm) {
    warn.add(HamTip(Icons.public_off_rounded, s.hfTipStorm, cWarn,
        TipLevel.warn));
  } else if (hf.geomagActive) {
    tip.add(HamTip(Icons.public_rounded, s.hfTipGeomagActive, cTip,
        TipLevel.tip));
  }

  // ── 太阳活动 ──
  if (hf.lowSolarFlux) {
    tip.add(HamTip(Icons.wb_twilight_rounded, s.hfTipLowSfi, cTip,
        TipLevel.tip));
  } else if (hf.sfiValue >= 150) {
    good.add(HamTip(Icons.auto_awesome_rounded, s.hfTipHighSfi, cGood,
        TipLevel.good));
  }

  // ── 底噪 ──
  if (hf.highNoise) {
    tip.add(HamTip(Icons.hearing_disabled_rounded, s.hfTipHighNoise, cViolet,
        TipLevel.tip));
  }

  // ── 当前时段最有戏的波段（这是「各个波段传播信息」落到建议上的一步）──
  final best = hf.bestBandAt(t);
  if (best != null) {
    final q = hfQualityOf(hfIsDaytime(t) ? best.day : best.night);
    if (q == HfQuality.good) {
      good.add(HamTip(Icons.cell_tower_rounded,
          s.hfTipBandGood(best.label), cGood, TipLevel.good));
    } else if (q == HfQuality.poor || q == HfQuality.closed) {
      tip.add(HamTip(Icons.trending_down_rounded,
          s.hfTipBandPoor(best.label), cTip, TipLevel.tip));
    }
  }

  return [...warn, ...good, ...tip];
}

/// 短波数据单例：拉取 / 缓存 / 通知 UI。
///
/// 结构与 `WeatherCenter` 保持一致（version notifier + load + TTL），
/// 但**有意更简单**：这里没有定位、没有逐日预报、也没有本地化判定 ——
/// 短波数据是「一个地方一份」的全球量。
class HfCenter {
  HfCenter._();
  static final HfCenter instance = HfCenter._();

  final ValueNotifier<int> version = ValueNotifier<int>(0);

  HfNow? now;
  bool loading = false;
  /// 0=无错误 1=数据获取失败 2=连接失败（用于本地化展示）
  int errorCode = 0;

  DateTime? _fetchedAt;
  bool _busy = false;

  bool get hasData => now != null;

  /// 是否还在缓存有效期内
  bool get fresh {
    final at = _fetchedAt;
    if (at == null || now == null) return false;
    return DateTime.now().difference(at) < kHfTtl;
  }

  /// 拉取（命中缓存直接返回）。失败只记 errorCode，不抛异常 ——
  /// 短波数据是「锦上添花」，它拿不到不该影响天气面板本身。
  Future<void> load({bool force = false}) async {
    if (_busy) return;
    if (!force && fresh) return;
    _busy = true;
    loading = true;
    version.value++;
    try {
      final xml = await _fetch(kHamQslUrl);
      final parsed = parseHamQsl(xml);
      if (parsed != null) {
        now = parsed;
        errorCode = 0;
        _fetchedAt = DateTime.now();
      } else {
        // 拿到了响应但解析不出（数据源改格式了？）—— 保留旧数据、只标记失败，
        // 比清空更有用：用户至少还能看到上次的有效值。
        errorCode = 1;
      }
    } catch (_) {
      errorCode = 2;
    } finally {
      _busy = false;
      loading = false;
      version.value++;
    }
  }

  Future<String> _fetch(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.userAgentHeader, 'APRSLocus');
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      // hamqsl 声明 UTF-8，但历史上有过 latin1 混入；用 utf8 容错解码
      final bytes = await res
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk))
          .timeout(const Duration(seconds: 15));
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      client.close(force: true);
    }
  }
}
