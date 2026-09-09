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
const String kQwHost = 'pf4ewvjfqj.re.qweatherapi.com';
const String kQwKey = '963cae25b17241aaab9d73e327ba5d4d';

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

  /// 是否命中缓存：同坐标且 30 分钟内（顶栏每秒重建时避免风暴请求）
  bool _withinTtl(double lat, double lng) {
    final n = now;
    if (n == null || updated == null) return false;
    if (DateTime.now().difference(updated!) > const Duration(minutes: 30)) {
      return false;
    }
    if (this.lat == null || this.lng == null) return false;
    final d = _haversineKm(this.lat!, this.lng!, lat, lng);
    return d < 3.0; // 位移 3km 内视为同地
  }

  DateTime? updated;

  /// 拉取天气（幂等）：同坐标缓存有效期内直接返回；移动超过 3km 或 30 分钟后重拉
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
class _FxPainter extends CustomPainter {
  final _FxKind kind;
  final double t; // 0..1 循环进度
  final bool dark;
  final double rain; // 0..1 降雨强度（影响雨丝数量/粗细/长度）
  _FxPainter({required this.kind, required this.t, required this.dark, this.rain = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final w = size.width;
    final h = size.height;
    final soft = Colors.white.withValues(alpha: dark ? 0.05 : 0.28);

    switch (kind) {
      case _FxKind.rain:
      case _FxKind.storm:
        final boost = 0.35 + rain * 0.65; // 雨大→更多更粗更长的雨丝
        final alpha = dark ? 0.10 : 0.5;
        final p = Paint()
          ..color = Colors.white.withValues(alpha: (alpha * (0.8 + rain * 0.4)).clamp(0.0, 1.0))
          ..strokeWidth = 1.0 + rain * 1.3
          ..strokeCap = StrokeCap.round;
        final baseN = kind == _FxKind.storm ? 40.0 : 50.0;
        final n = (baseN * boost).round();
        for (var i = 0; i < n; i++) {
          final x = rnd.nextDouble() * w;
          final sp = 0.2 + rnd.nextDouble() * 0.45;
          final len = (5 + rnd.nextDouble() * 9) * (1 + rain * 1.1);
          final y = ((rnd.nextDouble() + t * sp) % 1.15) * h;
          canvas.drawLine(Offset(x, y), Offset(x - 1.5 - rain * 1.5, y + len), p);
        }
        break;
      case _FxKind.snow:
        final p = Paint()..color = Colors.white.withValues(alpha: dark ? 0.3 : 0.75);
        for (var i = 0; i < 46; i++) {
          final x = rnd.nextDouble() * w + math.sin(t * 3 + i * 0.7) * 6;
          final sp = 0.08 + rnd.nextDouble() * 0.15;
          final y = ((rnd.nextDouble() + t * sp) % 1.1) * h;
          final r = 1.2 + rnd.nextDouble() * 1.6;
          canvas.drawCircle(Offset(x, y), r, p);
        }
        break;
      case _FxKind.fog:
        final p = Paint();
        for (var i = 0; i < 16; i++) {
          final cx = (rnd.nextDouble() * 1.3 - 0.15) * w;
          final cy = (0.1 + rnd.nextDouble() * 0.8) * h;
          final rr = 24 + rnd.nextDouble() * 40;
          final g = RadialGradient(colors: [
            Colors.white.withValues(alpha: dark ? 0.05 : 0.22),
            Colors.white.withValues(alpha: 0),
          ]);
          p.shader = g.createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: rr));
          canvas.drawCircle(Offset(cx, cy), rr, p);
        }
        break;
      case _FxKind.clear:
        final p = Paint()..color = soft;
        for (var i = 0; i < 30; i++) {
          final x = rnd.nextDouble() * w;
          final sp = 0.02 + rnd.nextDouble() * 0.05;
          final y = ((rnd.nextDouble() - t * sp) % 1.1 + 1.1) % 1.1 * h;
          final r = 0.8 + rnd.nextDouble() * 1.6;
          canvas.drawCircle(Offset(x, y), r, p);
        }
        break;
      case _FxKind.cloudy:
      case _FxKind.overcast:
        final p = Paint()..color = soft;
        for (var i = 0; i < 14; i++) {
          final x = rnd.nextDouble() * w;
          final sp = 0.03 + rnd.nextDouble() * 0.06;
          final y = ((rnd.nextDouble() + t * sp) % 1.1) * h;
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset(x, y),
                  width: 18 + rnd.nextDouble() * 26,
                  height: 8),
              p);
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
    final st = widget.state;
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
            if (hasPos)
              GestureDetector(
                onTap: () {
                  if (st.myHasFix && st.myLat != null && st.myLng != null) {
                    WeatherCenter.instance
                        .load(st.myLat!, st.myLng!, force: true);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: dark ? 0.14 : 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh_rounded, size: 14, color: baseText),
                    const SizedBox(width: 3),
                    Text(s.weatherRefresh, style: ts(11, c: baseText, w: FontWeight.w700)),
                  ]),
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
