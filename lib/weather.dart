import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'state.dart';
import 'widgets.dart';
import 'l10n/app_localizations.dart';

/// ─── 天气组件（和风天气 QWeather）───
/// 数据：和风「实时天气」+「城市定位」；顶栏默认显示 图标+温度，点击弹浮动面板。
/// 配置见 https://dev.qweather.com/docs
/// 和风 API 配置：构建时由环境注入（GitHub Actions Secrets: QWEATHER_KEY），
/// 避免把密钥硬编码进源码。本地调试可在 pubspec 或 --dart-define 提供。
const String kQwHost = String.fromEnvironment('QWEATHER_HOST',
    defaultValue: 'pf4ewvjfqj.re.qweatherapi.com');
const String kQwKey = String.fromEnvironment('QWEATHER_KEY',
    defaultValue: '');

/// 实时天气（/v7/weather/now 返回的 now 对象 + 逆地理城市名）
class WeatherNow {
  final String temp; // 温度 ℃
  final String text; // 天气现象文字
  final String icon; // 和风图标代码（如 "100"）
  final String feelsLike; // 体感温度
  final String humidity; // 相对湿度 %
  final String windDir; // 风向
  final String windScale; // 风力等级
  final String windSpeed; // 风速 km/h
  final String pressure; // 气压 hPa
  final String vis; // 能见度 km
  final String precip; // 降水量 mm
  final String cloud; // 云量 %
  final String dew; // 露点 ℃
  final String obsTime; // 观测时间
  final String? city; // 城市名（geoapi 反查，失败为 null）

  const WeatherNow({
    required this.temp,
    required this.text,
    required this.icon,
    required this.feelsLike,
    required this.humidity,
    required this.windDir,
    required this.windScale,
    required this.windSpeed,
    required this.pressure,
    required this.vis,
    required this.precip,
    required this.cloud,
    required this.dew,
    required this.obsTime,
    this.city,
  });

  IconData get iconData {
    final c = icon;
    final n = int.tryParse(c) ?? -1;
    // 夜间晴 / 夜间多云
    if (c == '150') return Icons.nights_stay_rounded;
    if (c == '151' || c == '152' || c == '153') {
      return Icons.nights_stay_rounded;
    }
    if (n >= 100 && n <= 104) {
      if (n == 100) return Icons.wb_sunny_rounded;
      if (n == 104) return Icons.cloud_rounded;
      return Icons.wb_cloudy_rounded;
    }
    // 300-399 雨
    if (n >= 300 && n < 400) {
      if (n == 302 || n == 303 || n == 304) {
        return Icons.thunderstorm_rounded;
      }
      return Icons.grain_rounded;
    }
    // 400-499 雪 / 雨夹雪
    if (n >= 400 && n < 500) return Icons.ac_unit_rounded;
    // 500+ 雾 / 霾 / 沙尘
    if (n >= 500 && n < 600) return Icons.blur_on_rounded;
    // 未知天气
    return Icons.cloud_rounded;
  }

  /// 观测时间 → "HH:mm"（本地化显示；解析失败返回原串）
  String get obsTimeShort {
    final t = DateTime.tryParse(obsTime);
    if (t == null) return obsTime;
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  String get tempDisplay => temp;
}

/// 天气数据单例：拉取 / 缓存 / 通知 UI
class WeatherCenter {
  WeatherCenter._();
  static final WeatherCenter instance = WeatherCenter._();

  final ValueNotifier<int> version = ValueNotifier<int>(0);

  WeatherNow? now;
  bool loading = false;
  /// 0=无错误 1=数据获取失败 2=连接失败（用于本地化展示）
  int errorCode = 0;
  double? lat, lng;
  bool _busy = false;

  // ── 天气模拟（开发者选项）──
  String? simIcon; // 模拟用和风 icon code；null=跟随实时
  String simText = '模拟';
  String simTemp = '24';
  String simPrecip = '0';

  bool get simulating => simIcon != null;

  /// 设置天气模拟（icon code 见和风文档；null=恢复实时）
  void setSimulation(String? icon, {String text = '模拟', String temp = '24', String precip = '0'}) {
    if (icon == null) {
      simIcon = null;
      version.value++;
      return;
    }
    simIcon = icon;
    simText = text;
    simTemp = temp;
    simPrecip = precip;
    _applySimToNow();
    version.value++;
  }

  void _applySimToNow() {
    final nowT = DateTime.now();
    now = WeatherNow(
      temp: simTemp,
      text: simText,
      icon: simIcon!,
      feelsLike: simTemp,
      humidity: '50',
      windDir: '--',
      windScale: '2',
      windSpeed: '8',
      pressure: '1013',
      vis: '20',
      precip: simPrecip,
      cloud: '40',
      dew: simTemp,
      obsTime: nowT.toIso8601String(),
      city: null,
    );
    updated = nowT;
    errorCode = 0;
    loading = false;
  }

  bool get hasData => now != null;

  /// 是否命中缓存：同坐标且 15 分钟内自动刷新（仅前台渲染时触发，后台不轮询）
  bool _withinTtl(double lat, double lng) {
    final n = now;
    if (n == null || updated == null) return false;
    if (DateTime.now().difference(updated!) > const Duration(minutes: 15)) {
      return false;
    }
    if (this.lat == null || this.lng == null) return false;
    final d = _haversineKm(this.lat!, this.lng!, lat, lng);
    return d < 3.0; // 位移 3km 内视为同地
  }

  DateTime? updated;

  /// 拉取天气（幂等）：同坐标缓存有效期内直接返回；移动超过 3km 或 15 分钟后重拉
  Future<void> load(double lat, double lng, {bool force = false}) async {
    if (simulating) return; // 模拟模式不走网络
    if (_busy) return;
    if (!force && _withinTtl(lat, lng)) return;
    _busy = true;
    loading = true;
    errorCode = 0;
    this.lat = lat;
    this.lng = lng;
    version.value++;
    try {
      final city = await _fetchCity(lat, lng);
      final n = await _fetchNow(lat, lng);
      if (n != null) {
        now = WeatherNow(
          temp: n.temp,
          text: n.text,
          icon: n.icon,
          feelsLike: n.feelsLike,
          humidity: n.humidity,
          windDir: n.windDir,
          windScale: n.windScale,
          windSpeed: n.windSpeed,
          pressure: n.pressure,
          vis: n.vis,
          precip: n.precip,
          cloud: n.cloud,
          dew: n.dew,
          obsTime: n.obsTime,
          city: city ?? n.city,
        );
        updated = DateTime.now();
      } else {
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

  static double _haversineKm(double la1, double lo1, double la2, double lo2) {
    const r = 6371.0;
    final dLat = (la2 - la1) * math.pi / 180;
    final dLon = (lo2 - lo1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1 * math.pi / 180) *
            math.cos(la2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// 逆地理：经纬度 → 城市名（geoapi；失败静默返回 null，不阻塞天气主流程）
  Future<String?> _fetchCity(double lat, double lng) async {
    try {
      // 地理编码路径为同一 Host 下的 /geo/v2/city/lookup（已验证；默认 geoapi 域名对本 Key 404）
      final url =
          'https://$kQwHost/geo/v2/city/lookup?location=$lng,$lat&key=$kQwKey';
      final d = await _getJson(url);
      if (d == null) return null;
      final list = d['location'];
      if (list is List && list.isNotEmpty) {
        final loc = list.first;
        if (loc is Map) {
          final name = loc['name']?.toString();
          final adm1 = loc['adm1']?.toString();
          final adm2 = loc['adm2']?.toString();
          // 直辖市 adm1==name 时省略省名，避免 "北京市北京市"
          if (adm1 != null && adm1 != name && adm2 != null && adm2 != name) {
            return '$adm1 $name';
          }
          return name ?? adm1;
        }
      }
    } catch (_) {}
    return null;
  }

  /// 实时天气
  Future<WeatherNow?> _fetchNow(double lat, double lng) async {
    final url =
        'https://$kQwHost/v7/weather/now?location=$lng,$lat&key=$kQwKey';
    final d = await _getJson(url);
    if (d == null) return null;
    if ((d['code']?.toString() ?? '') != '200') return null;
    final now = d['now'];
    if (now is! Map) return null;
    String s(Object? v) => (v ?? '').toString();
    return WeatherNow(
      temp: s(now['temp']),
      text: s(now['text']),
      icon: s(now['icon']),
      feelsLike: s(now['feelsLike']),
      humidity: s(now['humidity']),
      windDir: s(now['windDir']),
      windScale: s(now['windScale']),
      windSpeed: s(now['windSpeed']),
      pressure: s(now['pressure']),
      vis: s(now['vis']),
      precip: s(now['precip']),
      cloud: s(now['cloud']),
      dew: s(now['dew']),
      obsTime: s(now['obsTime']),
    );
  }

  Future<Map<String, dynamic>?> _getJson(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.userAgentHeader, 'APRSlocus');
      final resp = await req.close().timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final body = await resp.transform(utf8.decoder).join();
      final d = jsonDecode(body);
      if (d is Map) {
        // jsonDecode 返回 Map<dynamic,dynamic>，显式转 Map<String,dynamic>
        final m = <String, dynamic>{};
        d.forEach((k, v) => m[k.toString()] = v);
        return m;
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// ─── 顶栏天气胶囊（图标 + 温度；点击弹出浮动面板）───
class WeatherBadge extends StatelessWidget {
  final AppState state;
  const WeatherBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final sim = WeatherCenter.instance.simulating;
    final hasPos = sim ||
        (state.myHasFix && state.myLat != null && state.myLng != null);
    if (!sim && hasPos) {
      // 幂等加载：命中缓存直接返回，不重复请求
      WeatherCenter.instance.load(state.myLat!, state.myLng!);
    }
    return ValueListenableBuilder<int>(
      valueListenable: WeatherCenter.instance.version,
      builder: (context, _, _) {
        final wc = WeatherCenter.instance;
        final col = Theme.of(context).brightness == Brightness.dark
            ? Colors.cyanAccent
            : C.cyan;
        final IconData icon;
        final String label;
        if (wc.hasData && wc.now != null) {
          icon = wc.now!.iconData;
          label = '${wc.now!.tempDisplay}°';
        } else {
          icon = Icons.cloud_outlined;
          label = wc.loading ? '--' : '';
        }
        return GestureDetector(
          onTap: () => showWeatherPanel(context, state),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: col.withValues(alpha: 0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (wc.loading && !wc.hasData)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: col),
                )
              else
                Icon(icon, size: 15, color: col),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(label,
                    style: ts(12, c: col, w: FontWeight.w800)),
              ],
            ]),
          ),
        );
      },
    );
  }
}

/// 天气视觉类型（用于背景渐变与粒子特效）
enum _FxKind { clear, cloudy, overcast, rain, storm, snow, fog }

_FxKind _fxKindOf(WeatherNow w) {
  final n = int.tryParse(w.icon) ?? -1;
  if (n >= 300 && n < 305) return _FxKind.storm; // 雷雨
  if (n >= 300 && n < 400) return _FxKind.rain;
  if (n >= 400 && n < 500) return _FxKind.snow;
  if (n >= 500 && n < 600) return _FxKind.fog;
  if (n == 104 || n == 154) return _FxKind.overcast;
  if ((n >= 101 && n <= 103) || (n >= 151 && n <= 153)) return _FxKind.cloudy;
  return _FxKind.clear; // 100 / 150 晴（含夜间晴）
}

/// 降雨强度 0..1（供背景/粒子随雨量变化）
double _rainLevel(WeatherNow w) {
  final n = int.tryParse(w.icon) ?? -1;
  double base;
  switch (n) {
    case 305: case 309: case 313: case 314:
      base = 0.25; // 小雨/毛毛雨/冻雨/小到中雨
    case 300: case 306: case 315:
      base = 0.5; // 阵雨/中雨
    case 301: case 307: case 316:
      base = 0.75; // 强阵雨/大雨/中到大雨
    default:
      // 302 雷阵雨 / 303 / 304 / 308 极端 / 310-312 / 317-318 暴雨级
      base = (n >= 302 && n <= 304) || (n >= 310 && n <= 312) || n == 308 || n == 317 || n == 318
          ? 1.0
          : 0.4;
  }
  // 用降水量微调
  final p = double.tryParse(w.precip);
  if (p != null && p > 0) {
    final pm = (p / 25.0).clamp(0.0, 0.35);
    base = (base + pm).clamp(0.15, 1.0);
  }
  return base;
}

/// 面板背景渐变（按天气类型 + 明暗主题 + 降雨强度）
List<Color> _fxGradient(_FxKind k, bool dark, {double rain = 0}) {
  const light = <_FxKind, List<Color>>{
    _FxKind.clear: [Color(0xFFE8F6FF), Color(0xFFCFE8FF)],
    _FxKind.cloudy: [Color(0xFFEEF3F9), Color(0xFFD8E4F0)],
    _FxKind.overcast: [Color(0xFFE6ECF3), Color(0xFFC9D6E4)],
    _FxKind.rain: [Color(0xFFDCE9F7), Color(0xFFAFCBE6)],
    _FxKind.storm: [Color(0xFFC7D4E2), Color(0xFF8FA8BE)],
    _FxKind.snow: [Color(0xFFF0F6FB), Color(0xFFDCEDF7)],
    _FxKind.fog: [Color(0xFFE7ECEF), Color(0xFFC3CED6)],
  };
  const darkc = <_FxKind, List<Color>>{
    _FxKind.clear: [Color(0xFF26374A), Color(0xFF141F2E)],
    _FxKind.cloudy: [Color(0xFF2A3444), Color(0xFF161D28)],
    _FxKind.overcast: [Color(0xFF313B49), Color(0xFF1A212B)],
    _FxKind.rain: [Color(0xFF1F3143), Color(0xFF0F1924)],
    _FxKind.storm: [Color(0xFF232E3A), Color(0xFF0D131B)],
    _FxKind.snow: [Color(0xFF2C3642), Color(0xFF171E27)],
    _FxKind.fog: [Color(0xFF2B3138), Color(0xFF171B21)],
  };
  final List<Color> base = dark ? darkc[k]! : light[k]!;
  // 降雨强度：加深/压低渐变色，雨越大越暗沉
  if (rain > 0.01 && (k == _FxKind.rain || k == _FxKind.storm)) {
    final deep = dark
        ? const Color(0xFF05080D)
        : const Color(0xFF42586E);
    return [
      Color.lerp(base[0], deep, rain * 0.55)!,
      Color.lerp(base[1], deep, rain * 0.7)!,
    ];
  }
  return base;
}

/// 单条火腿建议
class _HamTip {
  final IconData icon;
  final String text;
  final Color color;
  const _HamTip(this.icon, this.text, this.color);
}

/// 根据天气生成业余无线电操作建议（无数据时返回通用提示）
List<_HamTip> _hamTips(WeatherNow? w, AppLocalizations s) {
  if (w == null) {
    return [
      _HamTip(Icons.info_outline_rounded, s.hamNoData, const Color(0xFF94A0B2)),
    ];
  }
  final n = int.tryParse(w.icon) ?? -1;
  final t = int.tryParse(w.temp) ?? 0;
  final wind = int.tryParse(w.windScale) ?? 0;
  final hum = int.tryParse(w.humidity) ?? 0;
  final vis = double.tryParse(w.vis) ?? 30;
  final tips = <_HamTip>[];
  // 雷雨：最关键，排最前
  if (n >= 300 && n < 305) {
    tips.add(_HamTip(Icons.flash_on_rounded, s.hamStorm1, const Color(0xFFE11D48)));
    tips.add(_HamTip(Icons.warning_amber_rounded, s.hamStorm2, const Color(0xFFD97706)));
  }
  // 降雨
  final precip = double.tryParse(w.precip);
  if ((n >= 300 && n < 400) || (precip != null && precip > 0)) {
    tips.add(_HamTip(Icons.umbrella_rounded, s.hamRain, const Color(0xFF2563EB)));
  }
  // 雪 / 低温
  if (n >= 400 && n < 500 || t <= 2) {
    tips.add(_HamTip(Icons.ac_unit_rounded, s.hamCold, const Color(0xFF0E7490)));
  }
  // 大风
  if (wind >= 5) {
    tips.add(_HamTip(Icons.air_rounded, s.hamWind('$wind'), const Color(0xFFEA580C)));
  }
  // 高温
  if (n < 300 && t >= 33) {
    tips.add(_HamTip(Icons.local_fire_department_rounded, s.hamHot('$t'), const Color(0xFFD97706)));
  }
  // 高湿
  if (hum >= 85) {
    tips.add(_HamTip(Icons.water_drop_rounded, s.hamHumid('$hum'), const Color(0xFF0EA5B7)));
  }
  // 低能见度（雾/霾）
  if (vis < 3) {
    tips.add(_HamTip(Icons.blur_on_rounded, s.hamFog(w.vis), const Color(0xFF7C3AED)));
  }
  // 天气良好
  if (tips.isEmpty) {
    tips.add(_HamTip(Icons.rss_feed_rounded, s.hamGood, const Color(0xFF16A34A)));
    if (wind >= 4) {
      tips.add(_HamTip(Icons.flag_rounded, s.hamWindExtra('$wind'), const Color(0xFFEA580C)));
    }
  }
  return tips.length > 4 ? tips.sublist(0, 4) : tips;
}

/// 物理特效画笔：按天气类型绘制飘雨/落雪/光斑/雾
/// 蓬松云团绘制：多个模糊圆叠加 → 边缘柔和、透气，取代生硬椭圆
class _CloudPuffPainter {
  /// 性能版云朵：用 1 个模糊椭圆主体 + 顶部模糊圆鼓包（2 次 mask 绘制），
  /// 取代原先 6-7 个模糊圆逐圆绘制，视觉相近但开销大幅下降。
  static void paint(Canvas canvas, double cx, double cy, double scale,
      double alpha, {Color? tint}) {
    final color = (tint ?? Colors.white);
    final blurA = Paint()
      ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    final blurB = Paint()
      ..color = color.withValues(alpha: (alpha * 0.9).clamp(0.0, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    // 扁椭圆云身（底部较平）
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, cy + 4 * scale),
            width: 108 * scale,
            height: 52 * scale),
        blurA);
    // 顶部一个鼓包圆，增强蓬松感
    canvas.drawCircle(Offset(cx - 6 * scale, cy - 14 * scale), 22 * scale, blurB);
    canvas.drawCircle(Offset(cx + 12 * scale, cy - 8 * scale), 18 * scale, blurB);
    // 高光（无 blur 实色，几乎不耗）
    final core = Paint()
      ..color = Colors.white.withValues(alpha: (alpha * 0.6).clamp(0.0, 0.6));
    canvas.drawCircle(Offset(cx - 2 * scale, cy - 4 * scale), 6 * scale, core);
  }
}

class _FxPainter extends CustomPainter {
  final _FxKind kind;
  final double t;
  final bool dark;
  final double rain;
  _FxPainter({required this.kind, required this.t, required this.dark, this.rain = 0});

  // ── 粒子参数缓存：位置/相位/速度/外形在首帧确定后复用（不再每帧重建 Random+数组）──
  List<double>? _rxs, _rph, _rsp, _rsh; // 近雨
  List<double>? _fxs, _fph, _fsp, _fsh; // 远雨
  int _rcN = 0;
  int _fcN = 0;

  void _ensureRain(bool storm) {
    final nearN = storm ? 52 : 44;
    final farN = storm ? 34 : 42;
    if (_rcN == nearN && _rxs != null) return;
    _rcN = nearN;
    _fcN = farN;
    final rnd = math.Random(7);
    List<double> gen(int n) => [for (var i = 0; i < n; i++) rnd.nextDouble()];
    _rxs = gen(nearN);
    _rph = gen(nearN);
    _rsp = [for (var i = 0; i < nearN; i++) 0.5 + rnd.nextDouble() * 0.5];
    _rsh = gen(nearN);
    _fxs = gen(farN);
    _fph = gen(farN);
    _fsp = [for (var i = 0; i < farN; i++) 0.2 + rnd.nextDouble() * 0.4];
    _fsh = gen(farN);
  }

  // 正弦摆动（往复、不 wrap）
  double _sway(double seed, double cyc, double amp) =>
      math.sin(2 * math.pi * cyc * seed + t * 2 * math.pi) * amp;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cloudDark = dark ? const Color(0xFF5B6B7C) : const Color(0xFFC9D6E4);

    switch (kind) {
      case _FxKind.rain:
      case _FxKind.storm:
        final storm = kind == _FxKind.storm;
        // 积雨云：2 朵，来回游弋
        final cloudTint = storm ? const Color(0xFF46586B) : cloudDark;
        final cloudA = storm ? (dark ? 0.30 : 0.5) : (dark ? 0.20 : 0.45);
        for (var i = 0; i < 2; i++) {
          final cx = w * (0.3 + i * 0.42) + _sway(i * 0.41, 0.12 + i * 0.05, w * 0.16);
          final cy = 26.0 + i * 8.0;
          _CloudPuffPainter.paint(canvas, cx, cy, 1.2 + i * 0.3,
              cloudA - i * 0.03, tint: cloudTint);
        }
        _ensureRain(storm);
        // ── 近景雨丝：合并为一条 Path 绘制（一次 raster，不再逐滴 drawLine）──
        final nearPaint = Paint()
          ..color = Colors.white.withValues(alpha: (dark ? 0.16 : 0.45).clamp(0.0, 0.9))
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (1.2 + rain * 1.6).clamp(1.2, 3.0);
        final np = Path();
        for (var i = 0; i < _rcN; i++) {
          final p = (t * _rsp![i] + _rph![i]) % 1.0;
          final y = p * (h + 40) - 20;
          final x = _rxs![i] * w + _sway(_rsh![i], 0.35 + rain * 0.3, 5);
          final len = (7 + _rsh![i] * 9) * (1 + rain * 0.6);
          final slant = 1.4 + rain * 1.6;
          np.moveTo(x, y);
          np.lineTo(x - slant, y + len);
        }
        canvas.drawPath(np, nearPaint);
        // ── 远景雨幕：细淡，一条 Path ──
        final farPaint = Paint()
          ..color = Colors.white.withValues(alpha: dark ? 0.05 : 0.12)
          ..strokeWidth = 0.6;
        final fp = Path();
        for (var i = 0; i < _fcN; i++) {
          final p = (t * _fsp![i] + _fph![i]) % 1.0;
          final y = p * (h + 30) - 15;
          final x = _fxs![i] * w + _sway(_fsh![i], 0.3, 3);
          final len = 3 + _fsh![i] * 5;
          fp.moveTo(x, y);
          fp.lineTo(x - 1, y + len);
        }
        canvas.drawPath(fp, farPaint);
        // 雷雨闪电
        if (storm) {
          final phase = math.sin(t * math.pi * 2);
          if (phase > 0.74 || (phase < -0.6 && math.sin(t * 40) > 0.75)) {
            final lp = Paint()
              ..color = const Color(0xFFFFF6D8).withValues(alpha: 0.4)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..strokeJoin = StrokeJoin.round;
            final bx = w * 0.68 + _sway(0.3, 0.7, 12);
            final path = Path()
              ..moveTo(bx, h * 0.26)
              ..lineTo(bx - 9, h * 0.38)
              ..lineTo(bx + 4, h * 0.4)
              ..lineTo(bx - 6, h * 0.52);
            canvas.drawPath(path, lp);
          }
        }
        break;

      case _FxKind.snow:
        // 雪：无 blur 实色圆 + 复用单一 Paint；数量 34（原 60），减轻重绘
        final rnd = math.Random(9);
        final pnt = Paint()..color = Colors.white;
        final n = 34;
        for (var i = 0; i < n; i++) {
          final px = rnd.nextDouble();
          final ph = rnd.nextDouble();
          final sp = 0.06 + rnd.nextDouble() * 0.12;
          final shp = rnd.nextDouble();
          final p = (t * sp + ph) % 1.0;
          final y = p * (h + 30) - 15;
          final x = px * w + _sway(shp, 0.5 + sp, 7);
          final near = shp > 0.7;
          final r = near ? 1.5 + shp : 1.0;
          pnt.color = Colors.white.withValues(
              alpha: near ? (dark ? 0.5 : 0.8) : (dark ? 0.2 : 0.4));
          canvas.drawCircle(Offset(x, y), r, pnt);
        }
        break;

      case _FxKind.fog:
        // 雾：少量径向渐变团 + 无 blur 细雾纹（去掉 7px blur 的 20 次 drawOval 开销）
        for (var i = 0; i < 4; i++) {
          final cx = w * (0.1 + i * 0.26) + _sway(i * 0.53, 0.05, w * 0.22);
          final cy = (0.18 + (i % 3) * 0.3) * h;
          final rr = 60.0 + (i % 2) * 40;
          final g = RadialGradient(colors: [
            Colors.white.withValues(alpha: dark ? 0.05 : 0.14),
            Colors.white.withValues(alpha: 0),
          ]);
          final p = Paint()
            ..shader = g.createShader(Rect.fromCircle(center: Offset(cx, cy), radius: rr));
          canvas.drawCircle(Offset(cx, cy), rr, p);
        }
        final fp = Paint()
          ..color = Colors.white.withValues(alpha: dark ? 0.05 : 0.1);
        for (var i = 0; i < 16; i++) {
          final x = w * (0.1 + (i % 4) * 0.26) + _sway(i * 0.71, 0.04, w * 0.3);
          final y = (0.1 + (i ~/ 4) * 0.26) * h;
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset(x, y),
                  width: 90.0 + (i % 3) * 40,
                  height: 14.0),
              fp);
        }
        break;

      case _FxKind.clear:
        final rnd = math.Random(5);
        final pnt = Paint();
        final n = 24;
        for (var i = 0; i < n; i++) {
          final px = rnd.nextDouble();
          final ph = rnd.nextDouble();
          final sp = 0.02 + rnd.nextDouble() * 0.05;
          final p = (t * sp + ph) % 1.0;
          final y = (1 - p) * (h + 20) - 10;
          final x = px * w + math.sin(t * 3 + i) * 3;
          pnt.color = Colors.white.withValues(alpha: ((dark ? 0.05 : 0.14) * (1 - p)).clamp(0.0, 0.3));
          canvas.drawCircle(Offset(x, y), 1.0 + px * 1.2, pnt);
        }
        break;

      case _FxKind.cloudy:
      case _FxKind.overcast:
        final n = kind == _FxKind.overcast ? 3 : 2;
        final tint = kind == _FxKind.overcast ? cloudDark : Colors.white;
        final baseA = kind == _FxKind.overcast
            ? (dark ? 0.16 : 0.32)
            : (dark ? 0.2 : 0.48);
        for (var i = 0; i < n; i++) {
          final cx = w * (0.2 + i * 0.3) + _sway(i * 0.37, 0.08 + i * 0.03, w * 0.18);
          final cy = 30.0 + i * 10.0;
          _CloudPuffPainter.paint(canvas, cx, cy, 1.15 + i * 0.25,
              baseA - i * 0.04, tint: tint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FxPainter old) =>
      old.kind != kind || old.t != t || old.rain != rain;
}

/// 打开天气浮动面板（底部弹层）：天气 + 火腿建议 + 特效背景
Future<void> showWeatherPanel(BuildContext context, AppState state) async {
  final sim = WeatherCenter.instance.simulating;
  final hasPos = sim ||
      (state.myHasFix && state.myLat != null && state.myLng != null);
  if (!sim && hasPos) {
    WeatherCenter.instance.load(state.myLat!, state.myLng!);
  }
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _WeatherPanel(state: state, hasPos: hasPos),
  );
}

class _WeatherPanel extends StatefulWidget {
  final AppState state;
  final bool hasPos;
  const _WeatherPanel({required this.state, required this.hasPos});
  @override
  State<_WeatherPanel> createState() => _WeatherPanelState();
}

class _WeatherPanelState extends State<_WeatherPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(); // 粒子循环动画
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
        child: ValueListenableBuilder<int>(
          valueListenable: WeatherCenter.instance.version,
          builder: (context, _, _) {
            final wc = WeatherCenter.instance;
            final kind =
                (wc.now != null) ? _fxKindOf(wc.now!) : _FxKind.cloudy;
            final rain = (wc.now != null &&
                    (kind == _FxKind.rain || kind == _FxKind.storm))
                ? _rainLevel(wc.now!)
                : 0.0;
            final grad = _fxGradient(kind, dark, rain: rain);
            return AnimatedBuilder(
              animation: _ac,
              builder: (context, _) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: grad,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      // 物理特效层
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _FxPainter(
                                kind: kind, t: _ac.value, dark: dark, rain: rain),
                          ),
                        ),
                      ),
                      // 内容层
                      _panelBody(wc, dark),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _panelBody(WeatherCenter wc, bool dark) {
    final kind =
        (wc.now != null) ? _fxKindOf(wc.now!) : _FxKind.cloudy;
    final hasPos = widget.hasPos;
    final s = S.of(context);
    final baseText = dark ? Colors.white : const Color(0xFF1B253C);
    final subText = dark ? Colors.white70 : const Color(0xFF68748F);
    final maxH = MediaQuery.of(context).size.height * 0.86;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: dark ? 0.14 : 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(kind == _FxKind.clear
                  ? Icons.wb_sunny_rounded
                  : Icons.wb_cloudy_rounded, color: baseText, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.weatherPanelTitle,
                      style: ts(16, w: FontWeight.w800, c: baseText)),
                  Text(s.weatherPanelSub,
                      style: ts(10.5, c: subText)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          // 无定位 / 加载 / 无数据
          if (!hasPos)
            _hint(
                Icons.gps_off_rounded, s.weatherNoLoc, subText)
          else if (wc.loading && !wc.hasData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else if (wc.now == null)
            _hint(Icons.cloud_off_rounded, wc.errorCode == 1 ? s.weatherDataFail : (wc.errorCode == 2 ? s.weatherConnFail : s.weatherUnavail), subText)
          else
            _content(wc, kind, dark, baseText, subText),
        ],
      ),
      ),
    );
  }

  Widget _content(WeatherCenter wc, _FxKind kind, bool dark, Color baseText,
      Color subText) {
    final s = S.of(context);
    final now = wc.now!;
    final isStorm = kind == _FxKind.storm;
    final accent = dark ? Colors.cyanAccent : const Color(0xFF0E7490);
    final cardWhite = dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.75);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 主体：城市 + 大图标 + 温度 ──
        Row(children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(now.iconData,
                size: 46,
                color: isStorm ? const Color(0xFFF59E0B) : accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.place_rounded, size: 14, color: subText),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(now.city ?? s.weatherCurLoc,
                        style: ts(12.5, c: subText, w: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 2),
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '${now.tempDisplay}°',
                      style: ts(38, w: FontWeight.w900, c: baseText)),
                  TextSpan(
                      text: '  ${now.text}',
                      style: ts(14, w: FontWeight.w700, c: baseText)),
                ])),
                Text('${s.weatherFeels(now.feelsLike)} · ${s.weatherObserved(now.obsTimeShort)}',
                    style: ts(11, c: subText)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 14),
        // ── 火腿建议卡片 ──
        _hamCard(_hamTips(now, s), dark, baseText),
        const SizedBox(height: 12),
        // ── 更多天气信息 ──
        Row(children: [
          _miniStat(s.weatherCloud, '${now.cloud}%', Icons.cloud_outlined, subText, baseText),
          const SizedBox(width: 8),
          _miniStat(s.weatherDew, '${now.dew}°', Icons.device_thermostat_rounded, subText,
              baseText),
          const SizedBox(width: 8),
          _miniStat(s.weatherHumidity, '${now.humidity}%', Icons.water_drop_outlined, subText,
              baseText),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _miniStat(s.weatherWindDir, now.windDir, Icons.explore_outlined, subText, baseText),
          const SizedBox(width: 8),
          _miniStat(s.weatherWindScale, '${now.windScale} 级', Icons.air, subText, baseText),
          const SizedBox(width: 8),
          _miniStat(s.weatherWindSpeed, '${now.windSpeed} km/h', Icons.speed_rounded, subText,
              baseText),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _miniStat(s.weatherPressure, '${now.pressure} hPa', Icons.compress_rounded, subText,
              baseText),
          const SizedBox(width: 8),
          _miniStat(s.weatherVis, '${now.vis} km', Icons.visibility_outlined, subText,
              baseText),
          const SizedBox(width: 8),
          _miniStat(s.weatherPrecip, '${now.precip} mm', Icons.opacity_rounded, subText,
              baseText),
        ]),
        const SizedBox(height: 10),
        Center(
          child: Text(s.weatherPowered,
              style: ts(9.5, c: subText.withValues(alpha: 0.8))),
        ),
      ],
    );
  }

  Widget _hamCard(List<_HamTip> tips, bool dark, Color baseText) {
    final s = S.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: dark ? 0.10 : 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.rss_feed_rounded,
              size: 16,
              color: dark ? Colors.cyanAccent : const Color(0xFF0E7490)),
          const SizedBox(width: 6),
          Text(s.hamTitle, style: ts(13, w: FontWeight.w800, c: baseText)),
        ]),
        const SizedBox(height: 8),
        for (final tip in tips) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(tip.icon, size: 15, color: tip.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(tip.text,
                  style: ts(11.5,
                      c: baseText.withValues(alpha: 0.92), h: 1.45)),
            ),
          ]),
          if (tips.last != tip) const SizedBox(height: 7),
        ],
      ]),
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color subText,
      Color baseText) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(13, w: FontWeight.w800, c: baseText)),
          const SizedBox(height: 1),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 10, color: subText),
            const SizedBox(width: 3),
            Flexible(
              child: Text(label,
                  style: ts(9, c: subText), overflow: TextOverflow.ellipsis),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _hint(IconData ic, String msg, Color subText) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Column(children: [
            Icon(ic, color: subText, size: 34),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(msg,
                  textAlign: TextAlign.center, style: ts(12, c: subText)),
            ),
          ]),
        ),
      );
}
