import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/app_localizations.dart';
import 'state.dart';
import 'weather.dart';

/// ─── Android 桌面小组件（4 档尺寸自适应：天气 + 业余无线电提示）───
///
/// 数据流向：
///   Flutter（唯一持有和风密钥、唯一实现判定规则的一侧）
///     → [AppWidgetBridge.push] 把一份「已算好、已本地化」的快照 JSON
///     → 原生 `com.aprslocus/app_widget` 通道 → 存进 SharedPreferences
///     → WeatherWidgetProvider.kt 读快照 → 刷新 RemoteViews。
///
/// **为什么不让组件自己请求天气**：
/// ① 和风密钥是构建期注入的（`--dart-define=QWEATHER_KEY`），原生侧拿不到，
///    也不应该为了一个组件把密钥再抄一份进 Kotlin；
/// ② 火腿建议的判定规则（雷电/大风/低温/波导/灰线…）、AQI 的本地化分级、
///    3 日预报的解析全在 Dart 里，在 Kotlin 重写一遍必然与面板产生分歧
///    —— 同一份天气，面板说「注意」而组件说「良好」是最难查的那类 bug。
///
/// **图标为什么传「名字」而不是 emoji**：
/// 组件进程里没有 Material 图标字体，RemoteViews 也不认字体图标与矢量图。
/// 所以构建期用 `tool/gen_app_widget_icons.py` 把 Flutter 自带的图标字体
/// **预渲染成 PNG**，这里只传图标名（如 `"flash_on"`），Kotlin 侧用生成好的
/// `WidgetIcons` 映射表查资源。于是组件上的图标与面板里的 `Icons.xxx` 是
/// **同一套字形** —— 这是「像面板」的关键。
///
/// **分工原则（避免两边分叉）**：排版在原生、内容在 Dart。
/// 原生只知道尺寸，所以由它决定「显示几条」「哪一档用短文案」；
/// 但「哪几条」「每种长度具体是什么字」都由这里算好并排序。
///
/// 设计稿与尺寸核对见 `tool/preview_app_widget.py`（渲染成 PNG 并硬性报溢出）。

/// 组件与原生之间的方法通道名（与 WeatherWidgetBridge.kt 必须一致）
const String kAppWidgetChannel = 'com.aprslocus/app_widget';

/// 快照格式版本：原生侧据此判断能否解析（不匹配则只显示占位）
const int kAppWidgetSnapshotVersion = 1;

/// 提示区最多下发几条（原生侧各档按自己的行数取前 N 条）
const int kAppWidgetMaxTips = 4;

/// 指标格最多下发几项（主档 2×2 = 4 格，竖长档取前 3）
const int kAppWidgetMetricCount = 4;

/// 单行档（3~4×1）用的短文案长度上限（字符数）
///
/// 单行档只有一行、约 150dp 给提示，换算下来中文大约 20 字。超过就会被系统
/// 省略号截断 —— 与其让系统从句子中间切（「雷雨天气：请勿在室…」），
/// 不如在 Dart 侧先切成完整的短句（「请勿在室外架设/操作天线！」）。
const int kAppWidgetShortTextMax = 20;

/// 从天气数据取值：字符串 → 整数（解析失败给 [fallback]）
int _intOf(String v, [int fallback = 0]) => int.tryParse(v) ?? fallback;

/// Color → 0xAARRGGBB。
/// 用新的 `a/r/g/b` 分量（0–1 浮点）而不是已废弃的 `Color.value`，
/// 避免 analyze 刷出一片 deprecation 噪音。
int colorToArgb(Color c) =>
    ((c.a * 255).round() << 24) |
    ((c.r * 255).round() << 16) |
    ((c.g * 255).round() << 8) |
    (c.b * 255).round();

/// 和风 icon code → 图标名（与 [kAppWidgetIconNames] 里的名字对应）
///
/// 刻意不按「一个图标打天下」：白天/夜间要分（150 是夜间晴），雨/雪/雾/霾
/// 也要分，否则组件上「雷雨」和「大雨」同形，等于没传达信息。
String widgetWeatherIconName(String code) {
  final n = int.tryParse(code) ?? -1;
  if (n == 150) return 'nights_stay'; // 晴（夜间）
  if (n == 151 || n == 152 || n == 153) return 'wb_cloudy'; // 多云/阴（夜间）
  if (n == 100) return 'wb_sunny'; // 晴
  if (n == 101 || n == 102 || n == 103) return 'wb_cloudy'; // 多云/少云
  if (n == 104) return 'cloud'; // 阴
  if (n >= 300 && n < 400) {
    // 302 雷阵雨 / 303 强雷雨 / 304 雷雨冰雹 → 雷；其余按雨量分档
    if (n == 302 || n == 303 || n == 304) return 'thunderstorm';
    if (n == 305 || n == 309 || n == 313 || n == 314) return 'grain'; // 小雨
    return 'water_drop'; // 其余雨量级
  }
  if (n >= 400 && n < 500) return 'ac_unit'; // 雪 / 雨夹雪
  if (n == 503 || n == 504 || n == 507 || n == 508) return 'grain'; // 沙尘
  if (n >= 500 && n < 600) return 'blur_on'; // 雾 / 霾
  return 'cloud'; // 未知
}

/// `HamTip.icon`（Material 图标）→ 图标名。
///
/// 键是 `Icons.*` 常量，`IconData` 重载了 `==`（按 codePoint + fontFamily 比较），
/// 所以能直接拿它当 Map 的键。
///
/// 注意：**不能**写成 `const` map —— `IconData` 覆写了 `==`/`hashCode`，
/// 而常量 map 的键要在编译期规范化，语言层面禁止这种键
/// （analyzer 报 `const_map_key_not_primitive_equality`）。用 `final` 即可。
///
/// ⚠ 名字必须与 `tool/gen_app_widget_icons.py` 的 `ICONS_WITH_CONST` 一致
/// （那边同时产出 PNG 与 Kotlin 的 `WidgetIcons.kt` 映射表）。名字对不上时
/// Kotlin 会回退到兜底图标 —— 不报错、只是显示错图标，所以由测试盯住。
final Map<IconData, String> kAppWidgetIconNames = <IconData, String>{
  // 雷电 / 浪涌
  Icons.flash_on_rounded: 'flash_on',
  Icons.power_off_rounded: 'power_off',
  Icons.warning_amber_rounded: 'warning_amber',
  Icons.graphic_eq_rounded: 'graphic_eq',
  Icons.water_rounded: 'water',
  Icons.air_rounded: 'air',
  // 天气防护
  Icons.umbrella_rounded: 'umbrella',
  Icons.wifi_tethering_rounded: 'wifi_tethering',
  Icons.ac_unit_rounded: 'ac_unit',
  Icons.icecream_rounded: 'icecream',
  Icons.device_thermostat_rounded: 'device_thermostat',
  Icons.flag_rounded: 'flag',
  Icons.local_fire_department_rounded: 'local_fire_department',
  Icons.thermostat_rounded: 'thermostat',
  Icons.water_drop_rounded: 'water_drop',
  Icons.blur_on_rounded: 'blur_on',
  Icons.grain_rounded: 'grain',
  Icons.masks_rounded: 'masks',
  Icons.opacity_rounded: 'opacity',
  Icons.wb_sunny_rounded: 'wb_sunny',
  // 传播机会
  Icons.trending_down_rounded: 'trending_down',
  Icons.waves_rounded: 'waves',
  Icons.wb_twilight_rounded: 'wb_twilight',
  Icons.nightlight_round: 'nightlight',
  Icons.rss_feed_rounded: 'rss_feed',
};

/// 兜底图标名（映射表没覆盖到的新图标）
const String kAppWidgetIconFallback = 'rss_feed';

String widgetTipIconName(IconData icon) =>
    kAppWidgetIconNames[icon] ?? kAppWidgetIconFallback;

/// 与面板 `_fxKindOf()` 同口径的天气档位（决定组件背景渐变）。
/// 面板那份是私有的，这里给组件用的公开版本；两处若不一致会「面板在下雨、
/// 组件是大晴天」，所以改动其一务必同步另一处。
String widgetWeatherKind(WeatherNow w) {
  final n = _intOf(w.icon, -1);
  if (n >= 300 && n < 305) return 'storm';
  if (n >= 300 && n < 400) return 'rain';
  if (n >= 400 && n < 500) return 'snow';
  if (n >= 500 && n < 600) return 'fog';
  if (n == 104 || n == 154) return 'overcast';
  if ((n >= 101 && n <= 103) || (n >= 151 && n <= 153)) return 'cloudy';
  return 'clear'; // 100 / 150 晴（含夜间晴）
}

/// 一条指标格的展示二元组（label 左 / value 右，与面板 `_kvPair` 同构）
typedef WidgetMetricTile = ({String label, String value});

/// 按当前天气排出「此刻最该看的指标」，**越靠前越要紧**。
///
/// 组件格子少（主档 2×2 = 4 格，竖长档 3 格），必须分主次：
/// 雾天把能见度顶上来、雨天把降水量顶上来…… 面板里这些指标是平铺的通用清单，
/// 组件里得按当前天气重排。
///
/// 注意只用**已有**的 l10n 文案（`weatherDew` 等都有独立键），不去蹭带占位符的
/// `weatherFeels`（"体感 {v}°"）—— 那个键里没有可单独取出的「体感」二字，
/// 硬切字符串在别的语言下必崩。
List<WidgetMetricTile> widgetMetricTiles(WeatherNow w, AppLocalizations s) {
  final n = _intOf(w.icon, -1);
  final t = _intOf(w.temp);
  final wind = _intOf(w.windScale);
  final vis = double.tryParse(w.vis) ?? 30;
  final precip = double.tryParse(w.precip) ?? 0;
  final isRain = (n >= 300 && n < 400) || precip > 0;
  final isSnow = n >= 400 && n < 500;
  // 500–599 里 503/504/507/508 是扬沙/浮尘/沙尘暴，按沙尘处理而非雾
  final isFog = n >= 500 && n < 600 && n != 503 && n != 504;

  final windTile = (label: s.weatherWindScale, value: '$wind 级');
  final humTile = (label: s.weatherHumidity, value: '${w.humidity}%');
  final pressTile = (label: s.weatherPressure, value: '${w.pressure} hPa');
  final visTile = (label: s.weatherVis, value: '${w.vis} km');
  final precipTile = (label: s.weatherPrecip, value: '${w.precip} mm');
  final dewTile = (label: s.weatherDew, value: '${w.dew}°');
  final cloudTile = (label: s.weatherCloud, value: '${w.cloud}%');

  // 雾 / 能见度低：能见度是第一信息（直接关系到能不能出门架台）
  if (isFog || vis < 5) {
    return [visTile, humTile, windTile, pressTile];
  }
  // 降水：降水量顶到最前（馈线防水、1.2GHz 以上雨衰判断）
  if (isRain || isSnow) {
    return [precipTile, humTile, windTile, visTile];
  }
  // 低温 / 结冰：露点顶到最前（接近饱和易结露短路，比体感实用）
  if (t <= 5) {
    return [dewTile, humTile, windTile, pressTile];
  }
  // 高温：湿度与气压变要紧（对流天气与设备散热降额）
  if (t >= 30) {
    return [humTile, pressTile, windTile, cloudTile];
  }
  // 常规：气压（大气波导与天气转折）优先
  return [pressTile, humTile, windTile, visTile];
}

/// 把一条建议切成逐级变短的若干版本（供单行档挑一个「完整短句」）。
///
/// 建议文案的写法天然适合这样切：先给结论再给理由，例如
/// 「雷雨天气：请勿在室外架设/操作天线！断开天线馈线，谨防雷击感应损坏设备」
/// → 「雷雨天气：请勿在室外架设/操作天线！」→「请勿在室外架设/操作天线！」
/// → 「雷雨天气…」
/// 返回顺序是**从长到短**（`shortTipText` 依赖这个顺序）。
/// 公开出来是为了可测：这些切分规则是纯字符串逻辑，值得单测盯住。
List<String> compactTipVariants(String text) {
  final t = text.trim();
  if (t.isEmpty) return const [];
  final out = <String>[];

  // ① 首个句末标点之前（「！」/「。」/「；」等）—— 中文建议的结论句几乎都在这里
  final m = RegExp(r'[^！。；;!?？]+[！。；;!?？]?').firstMatch(t);
  if (m != null && m.group(0)!.trim().isNotEmpty) {
    final head = m.group(0)!.trim();
    if (head != t) out.add(head);
  }
  // ② 冒号后的一半（「雷雨天气：」后面的正文）
  for (final sep in const ['：', ':']) {
    final i = t.indexOf(sep);
    if (i > 0 && i + 1 < t.length) {
      out.add(t.substring(i + 1).trim());
      break;
    }
  }
  // ③ 冒号前的一半（「雷雨天气」）
  for (final sep in const ['：', ':']) {
    final i = t.indexOf(sep);
    if (i > 2) {
      out.add(t.substring(0, i).trim());
      break;
    }
  }

  final seen = <String>{};
  final uniq = <String>[];
  for (final v in out) {
    if (v.isEmpty || seen.contains(v)) continue;
    seen.add(v);
    uniq.add(v);
  }
  if (uniq.isEmpty) return [t];

  // **按长度降序**，而不是按生成顺序：生成顺序是「句末标点前 → 冒号后 → 冒号前」，
  // 三者之间**没有**长度关系（「冒号后」常比「句末标点前」长）。
  // shortTipText 依赖「从长到短」逐个试配宽度，顺序错了就会挑到放不下的长句。
  uniq.sort((a, b) => b.length.compareTo(a.length));

  // 除最长那条外都补省略号，让人看出「还有下文」而不是以为漏字了
  final longest = uniq.first.length;
  return [
    for (final v in uniq)
      if (v.length == longest || v.endsWith('…')) v else '$v…',
  ];
}

/// 单行档用的短文案：取「不超过 [kAppWidgetShortTextMax] 字的最长完整短句」。
///
/// 为什么不直接让 Android 省略号截断：那会从句子中间切（「雷雨天气：请勿在室…」），
/// 而切成完整短句（「请勿在室外架设/操作天线！」）信息量完全不同。
/// 切分规则涉及全角冒号与句末标点，属于本地化范畴，所以放在 Dart 而不是 Kotlin。
String shortTipText(String text) {
  final variants = compactTipVariants(text);
  if (variants.isEmpty) return text;
  for (final v in variants) {
    if (v.length <= kAppWidgetShortTextMax) return v;
  }
  return variants.last; // 都超长：用最短的那个，交给系统省略号
}

/// 组装给桌面小组件的快照（纯函数，不碰平台通道，便于单测）。
///
/// 所有面向用户的文案都在这里由 [AppLocalizations] 取好，原生侧**不做**任何
/// 条件判断与本地化 —— Kotlin 只负责「把字符串放进对应的格子」。
Map<String, Object?> buildAppWidgetSnapshot({
  required WeatherCenter wc,
  required AppLocalizations s,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final w = wc.now;
  final d0 = wc.daily.isNotEmpty ? wc.daily.first : null;
  final aqi = wc.air?.aqiValue ?? -1;

  final snap = <String, Object?>{
    'v': kAppWidgetSnapshotVersion,
    // 快照生成时刻（调试与「无数据兜底」用）
    'ts': t.millisecondsSinceEpoch,
    'hasData': false,
    // 背景渐变档位：clear / cloudy / overcast / rain / storm / snow / fog
    'kind': 'cloudy',
    'header': <String, Object?>{
      'city': '',
      'aqi': '',
      'aqiLabel': '',
      'aqiColor': 0,
      'observed': '',
    },
    'hero': <String, Object?>{
      'iconName': 'cloud',
      'temp': '--',
      'cond': '',
      'range': '',
    },
    'metrics': <Map<String, Object?>>[],
    'tipsLabel': s.hamTitle,
    'tips': <Map<String, Object?>>[],
    'tipTotal': 0,
    // 组件的空状态：直接复用「暂无定位」提示（它就是此刻最该说的一句话）
    'emptyLabel': s.weatherNoLoc,
  };

  if (w == null) return snap;

  final tips = hamTips(wc, s);

  snap['hasData'] = true;
  snap['kind'] = widgetWeatherKind(w);
  snap['header'] = <String, Object?>{
    'city': (w.city == null || w.city!.trim().isEmpty)
        ? s.weatherCurLoc
        : w.city!,
    'aqi': aqi < 0 ? '' : '$aqi',
    'aqiLabel': aqi < 0 ? '' : airLabel(aqi, s),
    'aqiColor': aqi < 0 ? 0 : colorToArgb(wc.air!.levelColor),
    // 用「观测 HH:mm」而不是本机当前时间：数据不新鲜时一眼可见，
    // 这比显示一个永远等于「现在」的时间戳诚实得多。
    'observed': s.weatherObserved(w.obsTimeShort),
  };
  snap['hero'] = <String, Object?>{
    'iconName': widgetWeatherIconName(w.icon),
    'temp': '${w.tempDisplay}°',
    'cond': w.text,
    'range': d0 == null
        ? ''
        : '${_intOf(d0.tempMin)}° / ${_intOf(d0.tempMax)}°',
  };
  snap['metrics'] = <Map<String, Object?>>[
    for (final m in widgetMetricTiles(w, s))
      <String, Object?>{'label': m.label, 'value': m.value},
  ];
  snap['tips'] = <Map<String, Object?>>[
    for (final tip in tips.take(kAppWidgetMaxTips))
      <String, Object?>{
        'iconName': widgetTipIconName(tip.icon),
        // 组件宽度不够时退化成「圆点 + 级别 + 图标」，靠这一行仍然能看懂
        'levelLabel': hamLevelLabel(tip.level, s),
        'color': widgetTipTextArgb(tip.color),
        'level': tip.level.name,
        'text': tip.text,
        // 单行档（3~4×1）用的完整短句
        'shortText': shortTipText(tip.text),
      },
  ];
  snap['tipTotal'] = tips.length;
  return snap;
}

/// 提示文字/圆点/图标的显示色。
///
/// 面板里提示压在**深色半透明卡片**上，直接用级别原色没问题；组件里文字与图标
/// 直接压在**天气渐变**上（晴天那段是 #2E86D6→#79C4F2，很亮），原色里的深蓝
/// #2563EB / 深绿 #16A34A 会与渐变糊在一起。所以统一往白色提亮 35%：
/// 只保留色相用于区分级别，亮度交给渐变。
///
/// ⚠ **必须与 `tool/preview_app_widget.py` 的 `LEVEL_LIT` 一致**：预览图与真机
/// 用的是同一组色，否则预览会骗人。
///
/// 刻意用**整数分量运算**而不是 `Color.lerp(c, Colors.white, 0.35)`：
/// 后者走浮点通道，235.5 这类边界值会因浮点表示差 1（实测 danger 得 #EB6C88，
/// 而 Python 侧算出 #EC6C88）。整数运算两边结果确定一致，于是这个跨语言契约
/// 可以精确断言（见 test 里的「与预览同色」）。
int widgetTipTextArgb(Color c) {
  int mix(int channel) => (channel * 0.65 + 255 * 0.35).round();
  final argb = colorToArgb(c);
  return (0xFF << 24) |
      (mix((argb >> 16) & 0xFF) << 16) |
      (mix((argb >> 8) & 0xFF) << 8) |
      mix(argb & 0xFF);
}

/// 桌面小组件 ↔ Flutter 的桥。
class AppWidgetBridge {
  AppWidgetBridge._();

  static const MethodChannel _ch = MethodChannel(kAppWidgetChannel);

  /// 已推送快照的指纹：完全一致就不重复过通道。
  ///
  /// 这一条就够用了，**不要**再加「节流用的 Future.delayed」：
  /// - 同一份数据重复推送本来就不会发生（指纹挡住了）；
  /// - 而天气加载前后的两次 `version.value++` 里，第一次快照内容没变、
  ///   同样被指纹挡住，节流并没有额外收益；
  /// - 却会留下一个不受 dispose 管辖的定时器，在 widget 测试里表现为
  ///   「A Timer is still pending」，是那种越查越远的假失败。
  static String? _lastFingerprint;

  /// 组装当前快照并推给原生（落盘 + 刷新 RemoteViews）。
  static Future<void> push({
    required AppLocalizations s,
    required WeatherCenter wc,
  }) async {
    final payload = jsonEncode(buildAppWidgetSnapshot(wc: wc, s: s));
    if (payload == _lastFingerprint) return;

    try {
      await _ch.invokeMethod<void>('update', payload);
      _lastFingerprint = payload;
    } on MissingPluginException {
      // 非 Android（Windows / Web / 桌面调试）没有这个通道。
      // 照样记下指纹：否则每次依赖变化都会重算一遍再白跑一次通道。
      _lastFingerprint = payload;
    } on PlatformException {
      // 刷新失败不记指纹，下次状态变化时还会再试（不静默丢掉这次数据）
    }
  }

  /// 清空已保存的快照（组件会回到占位态）
  static Future<void> clear() async {
    _lastFingerprint = null;
    try {
      await _ch.invokeMethod<void>('clear');
    } on MissingPluginException {
      // 非 Android：忽略
    } on PlatformException {
      // 忽略
    }
  }
}

/// 快照同步挂件：挂在 `MaterialApp.builder` 里。
///
/// 位置很关键 —— `MaterialApp.builder` 的 context 位于 `Localizations` **之下**，
/// 因此这里 `AppLocalizations.of(context)` 拿到的是**当前真正生效**的语言
/// （包括「跟随系统」那一档）。换个位置就得自己重算 locale，一旦算错，
/// 组件上的文字会和界面差一个语言。
///
/// 触发时机：
/// ① 首帧（App 启动 / 切语言后重建）；
/// ② `WeatherCenter.version` 变化（天气拉到、模拟天气切换）；
/// ③ 依赖变化（`didChangeDependencies` 在语言或 MediaQuery 变化时触发）。
class AppWidgetSync extends StatefulWidget {
  const AppWidgetSync({super.key, required this.state, required this.child});

  final AppState state;
  final Widget child;

  @override
  State<AppWidgetSync> createState() => _AppWidgetSyncState();
}

class _AppWidgetSyncState extends State<AppWidgetSync>
    with WidgetsBindingObserver {
  /// 上次「无数据兜底加载」的时间（防自激，见下）
  DateTime? _lastAutoLoad;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WeatherCenter.instance.version.addListener(_sync);
    // 首帧之后再推：此时 Localizations 已就绪
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 切到后台前再同步一次：用户回到桌面时看到的就是最新的那份
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _sync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WeatherCenter.instance.version.removeListener(_sync);
    super.dispose();
  }

  /// 完全没有天气数据时，顺手触发一次加载。
  ///
  /// 为什么不无条件调 `load()`（像顶栏胶囊 `WeatherBadge` 那样）：
  /// 胶囊在 `build()` 里调，靠 `WeatherCenter` 内部 15 分钟 TTL 拦重复请求。
  /// 但 TTL 的判据是 `updated != null` —— **拉取失败时 `updated` 不会被更新**，
  /// 而失败后 `load()` 仍会 `version.value++`；本类的 `version` 监听器又是
  /// `_sync()`，于是会转成「通知 → 加载 → 失败 → 通知」的无限重试。
  /// 所以这里加一道时间戳（不是节流优化，是防自激，也顺便不把用户流量烧在
  /// 「没定位 / 服务器宕了」这类必然失败的场景上）。
  ///
  /// 注意：**只处理「一点数据都没有」的情况**。数据过期（超过 TTL）的刷新
  /// 交给 `WeatherBadge` —— 用户点组件打开 App 时它自然会拉，拉完
  /// `version` 变化再驱动本类把新快照推给组件。
  void _maybeLoad() {
    final st = widget.state;
    final wc = WeatherCenter.instance;
    // loading 也不能省：load() 会在开头 version.value++，
    // 不拦住就变成「load → 通知 → load」。
    if (wc.simulating || wc.loading || wc.now != null) return;
    if (!st.myHasFix || st.myLat == null || st.myLng == null) return;

    final now = DateTime.now();
    final last = _lastAutoLoad;
    if (last != null && now.difference(last) < const Duration(minutes: 2)) {
      return;
    }
    _lastAutoLoad = now;
    wc.load(st.myLat!, st.myLng!);
  }

  void _sync() {
    if (!mounted) return;
    _maybeLoad();
    final s = AppLocalizations.of(context);
    // 不 await：推送是副作用，不该拖慢首帧
    AppWidgetBridge.push(s: s, wc: WeatherCenter.instance);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
