import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

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

/// 和风图标代码 → Material 图标（实时天气与逐日预报共用）
IconData qwIcon(String code) {
  final n = int.tryParse(code) ?? -1;
  // 夜间晴 / 夜间多云
  if (code == '150') return Icons.nights_stay_rounded;
  if (code == '151' || code == '152' || code == '153') {
    return Icons.nights_stay_rounded;
  }
  if (n >= 100 && n <= 104) {
    if (n == 100) return Icons.wb_sunny_rounded;
    if (n == 104) return Icons.cloud_rounded;
    return Icons.wb_cloudy_rounded;
  }
  // 300-399 雨
  if (n >= 300 && n < 400) {
    if (n == 302 || n == 303 || n == 304) return Icons.thunderstorm_rounded;
    if (n == 305 || n == 309) return Icons.grain_rounded; // 小雨 / 毛毛雨
    if (n == 306 || n == 315) return Icons.water_drop_rounded; // 中雨 / 阵雨
    if (n == 307 || n == 310 || n == 316) return Icons.thunderstorm_rounded; // 大雨/暴雨
    return Icons.grain_rounded;
  }
  // 400-499 雪 / 雨夹雪
  if (n >= 400 && n < 500) return Icons.ac_unit_rounded;
  // 500+ 雾 / 霾 / 沙尘
  if (n >= 500 && n < 600) return Icons.blur_on_rounded;
  // 未知天气
  return Icons.cloud_rounded;
}

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

  IconData get iconData => qwIcon(icon);

  /// 观测时间 → "HH:mm"（本地化显示；解析失败返回原串）
  String get obsTimeShort {
    final t = DateTime.tryParse(obsTime);
    if (t == null) return obsTime;
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  String get tempDisplay => temp;
}

/// 空气质量（和风 /v7/air/now 的 now 对象）
class AirNow {
  final String aqi; // 空气质量指数
  final String category; // 等级文字（优 / 良 / 轻度污染 …）
  final String primary; // 首要污染物（可为空）
  final String pm2p5;
  final String pm10;
  final String no2;
  final String so2;
  final String co;
  final String o3;

  const AirNow({
    required this.aqi,
    required this.category,
    required this.primary,
    this.pm2p5 = '',
    this.pm10 = '',
    this.no2 = '',
    this.so2 = '',
    this.co = '',
    this.o3 = '',
  });

  int get aqiValue => int.tryParse(aqi) ?? -1;

  /// 国标 AQI 等级色（优→绿 … 严重污染→褐红）
  Color get levelColor {
    final v = aqiValue;
    if (v < 0) return const Color(0xFF94A3B8);
    if (v <= 50) return const Color(0xFF22C55E);
    if (v <= 100) return const Color(0xFFEAB308);
    if (v <= 150) return const Color(0xFFF97316);
    if (v <= 200) return const Color(0xFFEF4444);
    if (v <= 300) return const Color(0xFFA21CAF);
    return const Color(0xFF8B1A1A);
  }
}

/// 逐日预报（和风 /v7/weather/3d 与 /v7/weather/15d 的 daily 项）
class WeatherDaily {
  final String fxDate; // yyyy-MM-dd
  final String tempMax; // 最高温 ℃
  final String tempMin; // 最低温 ℃
  final String iconDay; // 白天图标代码
  final String textDay; // 白天天气现象
  final String iconNight; // 夜间图标代码
  final String textNight; // 夜间天气现象
  final String precip; // 降水量 mm
  final String humidity; // 相对湿度 %
  final String uvIndex; // 紫外线指数
  final String windDirDay; // 白天风向
  final String windScaleDay; // 白天风力等级
  final String windSpeedDay; // 白天风速 km/h
  final String sunrise; // 日出
  final String sunset; // 日落
  final String moonPhase; // 月相

  const WeatherDaily({
    required this.fxDate,
    required this.tempMax,
    required this.tempMin,
    required this.iconDay,
    required this.textDay,
    this.iconNight = '',
    this.textNight = '',
    this.precip = '',
    this.humidity = '',
    this.uvIndex = '',
    this.windDirDay = '',
    this.windScaleDay = '',
    this.windSpeedDay = '',
    this.sunrise = '',
    this.sunset = '',
    this.moonPhase = '',
  });

  IconData get iconData => qwIcon(iconDay);
  int get maxV => int.tryParse(tempMax) ?? 0;
  int get minV => int.tryParse(tempMin) ?? 0;
  DateTime? get date => DateTime.tryParse(fxDate);
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

  // ── 逐日预报 / 空气质量（与实时天气一并拉取）──
  List<WeatherDaily> daily = const []; // 未来 3 天
  AirNow? air; // 空气质量
  List<WeatherDaily> daily15 = const []; // 近 15 天（点开时才懒加载）
  bool loading15 = false;
  /// 0=无错误 1=数据获取失败 2=连接失败
  int errorCode15 = 0;
  bool _busy15 = false;

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
    _applySimAux();
    version.value++;
  }

  /// 模拟模式下构造 3/15 日预报与空气质量，便于预览新面板
  void _applySimAux() {
    final icon = simIcon;
    if (icon == null) return;
    final base = int.tryParse(simTemp) ?? 24;
    final nowD = DateTime.now();
    const codes = ['100', '101', '104', '305', '306', '307', '400', '501'];
    List<WeatherDaily> gen(int days) => [
          for (var i = 0; i < days; i++)
            WeatherDaily(
              fxDate: _fmtDate(nowD.add(Duration(days: i))),
              tempMax: '${base + 4 - (i % 3)}',
              tempMin: '${base - 5 + (i % 4)}',
              iconDay: i == 0 ? icon : codes[i % codes.length],
              textDay: i == 0 ? simText : '模拟',
              precip: simPrecip,
              humidity: '55',
              uvIndex: '${i % 6}',
              windDirDay: '--',
              windScaleDay: '2',
              windSpeedDay: '9',
              sunrise: '06:12',
              sunset: '18:40',
            ),
        ];
    daily = gen(3);
    daily15 = gen(15);
    air = const AirNow(
        aqi: '42', category: '', primary: '', pm2p5: '18', pm10: '32');
    updated = DateTime.now();
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
      // 并行拉取：城市反查 / 3 日预报 / 空气质量 与实时天气同时发起，
      // 辅助接口失败不影响实时天气主流程。
      final cityF = _fetchCity(lat, lng);
      final d3F = _fetchDaily(lat, lng, 3);
      final airF = _fetchAir(lat, lng);
      final n = await _fetchNow(lat, lng);
      final city = await cityF;
      final d3 = await d3F;
      final airNow = await airF;
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
        daily = d3;
        air = airNow;
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

  /// 拉取逐日预报（3d / 15d）；失败返回空列表，不抛出
  Future<List<WeatherDaily>> _fetchDaily(
      double lat, double lng, int days) async {
    try {
      final url =
          'https://$kQwHost/v7/weather/${days}d?location=$lng,$lat&key=$kQwKey';
      final d = await _getJson(url);
      if (d == null) return const [];
      if ((d['code']?.toString() ?? '') != '200') return const [];
      final list = d['daily'];
      if (list is! List) return const [];
      final out = <WeatherDaily>[];
      for (final e in list) {
        if (e is Map) out.add(_dailyFromMap(e));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static WeatherDaily _dailyFromMap(Map e) {
    String s(Object? v) => (v ?? '').toString();
    return WeatherDaily(
      fxDate: s(e['fxDate']),
      tempMax: s(e['tempMax']),
      tempMin: s(e['tempMin']),
      iconDay: s(e['iconDay']),
      textDay: s(e['textDay']),
      iconNight: s(e['iconNight']),
      textNight: s(e['textNight']),
      precip: s(e['precip']),
      humidity: s(e['humidity']),
      uvIndex: s(e['uvIndex']),
      windDirDay: s(e['windDirDay']),
      windScaleDay: s(e['windScaleDay']),
      windSpeedDay: s(e['windSpeedDay']),
      sunrise: s(e['sunrise']),
      sunset: s(e['sunset']),
      moonPhase: s(e['moonPhase']),
    );
  }

  /// 拉取空气质量（/v7/air/now）；失败返回 null，不抛出
  Future<AirNow?> _fetchAir(double lat, double lng) async {
    try {
      final url =
          'https://$kQwHost/v7/air/now?location=$lng,$lat&key=$kQwKey';
      final d = await _getJson(url);
      if (d == null) return null;
      if ((d['code']?.toString() ?? '') != '200') return null;
      final n = d['now'];
      if (n is! Map) return null;
      String s(Object? v) => (v ?? '').toString();
      return AirNow(
        aqi: s(n['aqi']),
        category: s(n['category']),
        primary: s(n['primary']),
        pm2p5: s(n['pm2p5']),
        pm10: s(n['pm10']),
        no2: s(n['no2']),
        so2: s(n['so2']),
        co: s(n['co']),
        o3: s(n['o3']),
      );
    } catch (_) {
      return null;
    }
  }

  /// 懒加载近 15 日预报（打开 15 日面板时调用；已缓存则直接返回）
  Future<void> load15({bool force = false}) async {
    if (simulating) return; // 模拟模式已在 _applySimAux 构造好数据
    final la = lat, ln = lng;
    if (la == null || ln == null) {
      errorCode15 = 1;
      return;
    }
    if (_busy15) return;
    if (!force && daily15.isNotEmpty) return;
    _busy15 = true;
    loading15 = true;
    errorCode15 = 0;
    version.value++;
    try {
      final d = await _fetchDaily(la, ln, 15);
      if (d.isNotEmpty) {
        daily15 = d;
      } else {
        errorCode15 = 1;
      }
    } catch (_) {
      errorCode15 = 2;
    } finally {
      _busy15 = false;
      loading15 = false;
      version.value++;
    }
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

/// 天气强度 0.0–1.0（驱动背景云层/雨雪粒子的数量、颜色、速度与密度）：
/// 小雨/中雨/大雨/暴雨按现象代码递增，并用降水量微调；雪/雾/阴/多云为较小值。
double weatherIntensity(WeatherNow w) {
  final n = int.tryParse(w.icon) ?? -1;
  // 300-399 雨
  if (n >= 300 && n < 400) {
    double base;
    switch (n) {
      case 305: case 309: case 313: case 314:
        base = 0.30; // 小雨/毛毛雨/冻雨/小到中雨
      case 300: case 306: case 315:
        base = 0.55; // 阵雨/中雨
      case 301: case 307: case 316:
        base = 0.78; // 强阵雨/大雨/中到大雨
      default:
        // 302 雷阵雨 / 303 / 304 / 308 极端 / 310-312 / 317-318 暴雨级
        base = (n >= 302 && n <= 304) ||
                (n >= 310 && n <= 312) ||
                n == 308 || n == 317 || n == 318
            ? 1.0
            : 0.45;
    }
    // 用降水量微调
    final p = double.tryParse(w.precip);
    if (p != null && p > 0) {
      base = (base + (p / 25.0).clamp(0.0, 0.35)).clamp(0.15, 1.0);
    }
    return base;
  }
  // 400-499 雪
  if (n >= 400 && n < 500) {
    final p = double.tryParse(w.precip);
    if (p != null && p > 0) {
      return (0.5 + (p / 20.0).clamp(0.0, 0.4)).clamp(0.2, 1.0);
    }
    return 0.5;
  }
  if (n >= 500 && n < 600) return 0.4; // 雾 / 霾 / 沙尘
  if (n == 104 || n == 154) return 0.4; // 阴
  if ((n >= 101 && n <= 103) || (n >= 151 && n <= 153)) return 0.22; // 多云
  return 0.0; // 晴
}

/// 面板背景渐变（按天气类型 + 明暗主题 + 降雨强度）
List<Color> _fxGradient(_FxKind k, bool dark, {double rain = 0}) {
  // 面板文字统一使用纯白，因此渐变整体保持足够的深度（浅色主题=明亮天空色，
  // 深色主题=更暗沉），避免白字在浅背景上发虚。
  const light = <_FxKind, List<Color>>{
    _FxKind.clear: [Color(0xFF2E86D6), Color(0xFF79C4F2)],
    _FxKind.cloudy: [Color(0xFF4A6E93), Color(0xFF87AACB)],
    _FxKind.overcast: [Color(0xFF56677A), Color(0xFF8C9BAB)],
    _FxKind.rain: [Color(0xFF36506B), Color(0xFF63809B)],
    _FxKind.storm: [Color(0xFF232F3E), Color(0xFF4A5B70)],
    _FxKind.snow: [Color(0xFF5C7FA8), Color(0xFFA8C6E2)],
    _FxKind.fog: [Color(0xFF6C7A87), Color(0xFFA3AEB9)],
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

/// 建议级别：安全警示 > 注意 > 通联机会 > 操作提示
enum _TipLevel { danger, warn, good, tip }

/// 单条火腿建议（带级别，便于分级配色与分级排序）
class _HamTip {
  final IconData icon;
  final String text;
  final Color color;
  final _TipLevel level;
  const _HamTip(this.icon, this.text, this.color, this.level);
}

/// "HH:mm" 是否落在当前时刻 ±[win] 分钟内（用于灰线判定）
bool _nearClock(String hhmm, int nowMin, {int win = 60}) {
  final p = hhmm.split(':');
  if (p.length < 2) return false;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return false;
  var d = (h * 60 + m - nowMin).abs();
  if (d > 720) d = 1440 - d;
  return d <= win;
}

/// 根据当前天气（及空气质量/逐日预报/时间）生成业余无线电操作建议。
/// 覆盖：雷电与浪涌防护、降水与馈线防水、结冰与低温电池、大风加固、高温降额、
/// 高湿绝缘、沙尘/污染、低气压预警、大气波导与灰线/夜间等传播机会、露点结露、紫外线。
/// 返回结果按级别排序：安全警示 → 注意 → 通联机会 → 操作提示。
List<_HamTip> _hamTips(WeatherCenter wc, AppLocalizations s) {
  final w = wc.now;
  if (w == null) {
    return const [];
  }
  const cDanger = Color(0xFFE11D48);
  const cWarn = Color(0xFFD97706);
  const cGood = Color(0xFF16A34A);
  const cTip = Color(0xFF2563EB);
  const cCold = Color(0xFF0E7490);
  const cViolet = Color(0xFF7C3AED);

  final n = int.tryParse(w.icon) ?? -1;
  final t = int.tryParse(w.temp) ?? 0;
  final wind = int.tryParse(w.windScale) ?? 0;
  final hum = int.tryParse(w.humidity) ?? 0;
  final vis = double.tryParse(w.vis) ?? 30;
  final precip = double.tryParse(w.precip);
  final pressure = double.tryParse(w.pressure) ?? 1013;
  final dew = double.tryParse(w.dew);
  final isRain = (n >= 300 && n < 400) || (precip != null && precip > 0);
  final isThunder = n == 302 || n == 303 || n == 304; // 雷阵雨/强雷雨/雷雨冰雹
  final isShower = n == 300 || n == 301; // 阵雨/强阵雨
  final isExtreme = n == 308 || (n >= 310 && n <= 318); // 极端降水/暴雨量级
  final isSnow = n >= 400 && n < 500;
  final isDust = n == 503 || n == 504 || n == 507 || n == 508; // 扬沙/浮尘/沙尘暴
  final isHaze = n == 502 || n == 511 || n == 512 || n == 513; // 霾（中/重/严重）
  final aqi = wc.air?.aqiValue ?? -1;
  final uv = int.tryParse(
          wc.daily.isNotEmpty ? wc.daily.first.uvIndex : '') ??
      -1;
  final nowD = DateTime.now();
  final nowMin = nowD.hour * 60 + nowD.minute;

  final danger = <_HamTip>[];
  final warn = <_HamTip>[];
  final good = <_HamTip>[];
  final tip = <_HamTip>[];

  // ── 安全警示：雷电是最优先事项 ──
  if (isThunder) {
    danger.add(_HamTip(Icons.flash_on_rounded, s.hamStorm1, cDanger, _TipLevel.danger));
    danger.add(_HamTip(Icons.power_off_rounded, s.hamStorm3, cDanger, _TipLevel.danger));
    warn.add(_HamTip(Icons.warning_amber_rounded, s.hamStorm2, cWarn, _TipLevel.warn));
    warn.add(_HamTip(Icons.graphic_eq_rounded, s.hamStorm4, cWarn, _TipLevel.warn));
  }
  if (isExtreme) {
    danger.add(_HamTip(Icons.water_rounded, s.hamExtreme, cDanger, _TipLevel.danger));
  }
  if (wind >= 6) {
    danger.add(_HamTip(Icons.air_rounded, s.hamGale('$wind'), cDanger, _TipLevel.danger));
  }

  // ── 天气本身的防护 ──
  if (isRain && !isShower) {
    tip.add(_HamTip(Icons.umbrella_rounded, s.hamRain, cTip, _TipLevel.tip));
  }
  if (isShower) {
    tip.add(_HamTip(Icons.umbrella_rounded, s.hamShower, cTip, _TipLevel.tip));
  }
  if ((n >= 300 && n < 400) && (n >= 310 || n == 301 || n == 307)) {
    tip.add(_HamTip(Icons.wifi_tethering_rounded, s.hamRainFade, cTip, _TipLevel.tip));
  }
  if (isSnow || t <= 2) {
    warn.add(_HamTip(Icons.ac_unit_rounded, s.hamCold, cCold, _TipLevel.warn));
  }
  if (isSnow) {
    warn.add(_HamTip(Icons.icecream_rounded, s.hamIce, cCold, _TipLevel.warn));
  }
  if (t <= 0) {
    warn.add(_HamTip(
        Icons.device_thermostat_rounded, s.hamFrost, cCold, _TipLevel.warn));
  }
  if (wind >= 5 && wind < 6) {
    warn.add(_HamTip(Icons.air_rounded, s.hamWind('$wind'), cWarn, _TipLevel.warn));
  }
  if (wind == 4) {
    tip.add(_HamTip(Icons.flag_rounded, s.hamWindExtra('$wind'), cWarn, _TipLevel.tip));
  }
  if (t >= 35) {
    warn.add(_HamTip(Icons.local_fire_department_rounded, s.hamHot('$t'), cWarn, _TipLevel.warn));
    warn.add(_HamTip(Icons.thermostat_rounded, s.hamHeat2, cWarn, _TipLevel.warn));
  } else if (t >= 33) {
    tip.add(_HamTip(Icons.local_fire_department_rounded, s.hamHot('$t'), cWarn, _TipLevel.tip));
  }
  if (hum >= 85) {
    tip.add(_HamTip(Icons.water_drop_rounded, s.hamHumid('$hum'), cTip, _TipLevel.tip));
  }
  if (vis < 3) {
    warn.add(_HamTip(Icons.blur_on_rounded, s.hamFog(w.vis), cViolet, _TipLevel.warn));
  }
  if (isDust) {
    warn.add(_HamTip(Icons.grain_rounded, s.hamDust, cViolet, _TipLevel.warn));
  }
  if (aqi > 150 || isHaze) {
    warn.add(_HamTip(Icons.masks_rounded, s.hamAir, cViolet, _TipLevel.warn));
  }
  // 露点差很小 → 接近饱和，易结露
  if (dew != null && (t - dew) <= 3) {
    tip.add(_HamTip(Icons.opacity_rounded,
        s.hamDew((t - dew).toStringAsFixed(0)), cTip, _TipLevel.tip));
  }
  if (uv >= 8) {
    tip.add(_HamTip(Icons.wb_sunny_rounded, s.hamUV('$uv'), cWarn, _TipLevel.tip));
  }

  // ── 气压预警 / 传播机会 ──
  if (pressure > 0 && pressure <= 1000) {
    warn.add(_HamTip(Icons.trending_down_rounded, s.hamLowPressure(w.pressure), cWarn, _TipLevel.warn));
  }
  if (pressure >= 1020) {
    good.add(_HamTip(Icons.waves_rounded, s.hamHighPressure(w.pressure), cGood, _TipLevel.good));
  }
  // 灰线：日出/日落 ±1h
  if (wc.daily.isNotEmpty) {
    final d0 = wc.daily.first;
    if (_nearClock(d0.sunrise, nowMin) || _nearClock(d0.sunset, nowMin)) {
      good.add(_HamTip(Icons.wb_twilight_rounded, s.hamGrayLine, cGood, _TipLevel.good));
    }
  }
  // 夜间低波段
  if (nowD.hour >= 20 || nowD.hour < 5) {
    good.add(_HamTip(Icons.nightlight_round, s.hamNight, cGood, _TipLevel.good));
  }
  // 天气良好：适合架台
  if (danger.isEmpty && warn.isEmpty && !isRain && !isSnow && vis >= 3) {
    good.add(_HamTip(Icons.rss_feed_rounded, s.hamGood, cGood, _TipLevel.good));
  }

  return [...danger, ...warn, ...good, ...tip];
}

/// ─── 天气动态背景（轻量：不引入任何 3D 引擎 / 重型动画库）───
///
/// 性能要点（卡顿根因与对策）：
/// ① **绝不每帧做 `MaskFilter.blur`**：模糊会强制离屏渲染 + 多次采样，
///    实测每帧 12 次 blur 占整个特效层约 84% 开销，在 Windows 桌面上
///    还会退化到 CPU 光栅化（观感即「纯 CPU 画界面」）。这里改为把云朵
///    **离线烘焙成一张 `ui.Image`**（模糊只做一次），之后每帧仅
///    `drawImageRect` 贴图 —— 实测 2.61ms → 1.08ms（2.4×）。
/// ② 特效层外层包 `RepaintBoundary`（见 `_FxLayer`），把每帧重绘**限制在
///    背景这一层**，不再连带面板上的所有文字与卡片一起重光栅化。
/// ③ 画笔 / 着色器按需缓存，避免每帧重建 Paint 与 Gradient。
/// ④ 雨丝/雪粒参数跨帧复用，仅强度分档变化时重建。

/// 云朵贴图：多团柔和圆叠成蓬松云（模糊只烘焙一次），
/// 之后每帧仅贴图 + `ColorFilter` 调色。
class _CloudSprite {
  _CloudSprite._();
  static ui.Image? _img;
  static const int sw = 232, sh = 124;

  static ui.Image image() {
    final cached = _img;
    if (cached != null) return cached;
    final rec = ui.PictureRecorder();
    final cv = Canvas(rec);

    void puff(double x, double y, double r, double a, double blur) {
      cv.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }

    // 底部较平的一层（云的「底盘」）
    cv.drawOval(
      Rect.fromCenter(
          center: const Offset(sw / 2, sh * 0.68), width: sw * 0.80, height: sh * 0.42),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.50)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // 主体鼓包（中间高、两侧低，形成蓬松轮廓）
    puff(sw * 0.34, sh * 0.55, 25, 0.58, 8);
    puff(sw * 0.50, sh * 0.40, 32, 0.62, 9);
    puff(sw * 0.66, sh * 0.53, 23, 0.55, 8);
    puff(sw * 0.22, sh * 0.62, 15, 0.42, 7);
    puff(sw * 0.78, sh * 0.61, 16, 0.42, 7);
    // 顶部高光，让云更有体积感
    puff(sw * 0.46, sh * 0.34, 15, 0.30, 7);

    final img = rec.endRecording().toImageSync(sw, sh);
    _img = img;
    return img;
  }
}

/// 特效层：把 `CustomPaint` 包进 `RepaintBoundary`，
/// 保证每帧只重绘背景本身，不影响上层文字/卡片。
class _FxLayer extends StatelessWidget {
  final _FxKind kind;
  final Animation<double> anim;
  final bool dark;
  final double intensity;
  const _FxLayer({
    required this.kind,
    required this.anim,
    required this.dark,
    required this.intensity,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        key: ValueKey<int>(kind.index),
        isComplex: true,
        willChange: true,
        painter: _FxPainter(
          kind: kind,
          anim: anim,
          dark: dark,
          intensity: intensity,
        ),
      ),
    );
  }
}

class _FxPainter extends CustomPainter {
  final _FxKind kind;
  /// 驱动动画（`repaint:` 直接重绘 → 画家实例跨帧复用，参数缓存真正生效）
  final Animation<double> anim;
  final bool dark;
  /// 天气强度 0.0–1.0：云层数量/明暗/漂移速度、雨雪密度/速度/长度随其变化
  final double intensity;

  _FxPainter({
    required this.kind,
    required this.anim,
    required this.dark,
    this.intensity = 0,
  }) : super(repaint: anim);

  /// 动画相位 0..1
  double get t => anim.value;

  // ── 粒子参数缓存（跨帧复用）──
  List<double>? _rxs, _rph, _rsp, _rsh; // 近景雨丝
  List<double>? _fxs, _fph, _fsp, _fsh; // 远景雨幕
  List<double>? _nxs, _nph, _nsp, _nsh; // 雪粒
  int _rcN = 0, _fcN = 0, _ncN = 0;

  // ── 画笔 / 着色器缓存 ──
  final Map<String, Paint> _pc = {};
  int _shW = 0, _shH = 0;
  bool _shDark = false;

  Paint _cached(String key, Paint Function() make) =>
      _pc.putIfAbsent(key, make);

  void _ensureRain(int nearN, int farN) {
    if (_rcN == nearN && _fcN == farN && _rxs != null) return;
    _rcN = nearN;
    _fcN = farN;
    final rnd = math.Random(7);
    List<double> gen(int n) => [for (var i = 0; i < n; i++) rnd.nextDouble()];
    _rxs = gen(nearN);
    _rph = gen(nearN);
    // 下落速度：约 0.7–1.1s 穿屏（此前 0.5–1.0 太慢，看起来像在飘雪）
    _rsp = [for (var i = 0; i < nearN; i++) 1.9 + rnd.nextDouble() * 1.1];
    _rsh = gen(nearN);
    _fxs = gen(farN);
    _fph = gen(farN);
    _fsp = [for (var i = 0; i < farN; i++) 1.5 + rnd.nextDouble() * 0.8];
    _fsh = gen(farN);
  }

  void _ensureSnow(int n) {
    if (_ncN == n && _nxs != null) return;
    _ncN = n;
    final rnd = math.Random(9);
    List<double> gen(int k) => [for (var i = 0; i < k; i++) rnd.nextDouble()];
    _nxs = gen(n);
    _nph = gen(n);
    // 雪要慢慢飘：约 5–9s 落到底
    _nsp = [for (var i = 0; i < n; i++) 0.22 + rnd.nextDouble() * 0.22];
    _nsh = gen(n);
  }

  /// 正弦摆动（往复、不 wrap）
  double _sway(double seed, double cyc, double amp) =>
      math.sin(2 * math.pi * cyc * seed + t * 2 * math.pi) * amp;

  /// 云朵缓慢横向漂移（无缝循环）；强度越高越快
  double _drift(int i, double w, double speed) {
    final p = (t * (0.045 + i * 0.011) * speed + i * 0.31) % 1.0;
    return p * (w + 320) - 160;
  }

  /// 贴一朵云：纯 blit（+ ColorFilter 调色），不做任何模糊
  void _blitCloud(
      Canvas cv, double cx, double cy, double scale, Color tint, double alpha) {
    final img = _CloudSprite.image();
    final w = _CloudSprite.sw * scale;
    final h = _CloudSprite.sh * scale;
    cv.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, _CloudSprite.sw.toDouble(), _CloudSprite.sh.toDouble()),
      Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
      _cached(
        // 量化成整型 key，避免每帧生成新 Paint；容器级缓存仅几十项
        'cl${(tint.r * 255).round()}_${(tint.g * 255).round()}_'
            '${(tint.b * 255).round()}_${(alpha * 20).round()}',
        () => Paint()
          ..filterQuality = FilterQuality.low
          ..colorFilter = ColorFilter.mode(
              tint.withValues(alpha: alpha.clamp(0.0, 1.0)), BlendMode.modulate),
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;
    final inten = intensity.clamp(0.0, 1.0);

    // 强度越高：云越多、越暗、漂移越快
    final cloudN = (2 + (inten * 2.2).round()).clamp(2, 4);
    final cloudSpeed = 0.6 + inten * 0.9;
    final baseCloud = dark ? const Color(0xFF8A9AAC) : const Color(0xFFF2F7FC);
    final deepCloud = dark ? const Color(0xFF39465A) : const Color(0xFF8FA3B8);
    final cloudTint = Color.lerp(baseCloud, deepCloud, inten * 0.75)!;
    final cloudA = (dark ? 0.42 : 0.78) + inten * 0.16;

    // 着色器与尺寸绑定，尺寸/dark 变化时清一次缓存
    final wi = w.toInt(), hi = h.toInt();
    if (_shW != wi || _shH != hi || _shDark != dark) {
      _shW = wi;
      _shH = hi;
      _shDark = dark;
      _pc.removeWhere((k, _) => k.startsWith('sun') || k.startsWith('mist'));
    }

    switch (kind) {
      case _FxKind.rain:
      case _FxKind.storm:
        final storm = kind == _FxKind.storm;

        // ── 云层（贴图，无模糊）──
        for (var i = 0; i < cloudN; i++) {
          final cx = _drift(i, w, cloudSpeed);
          final cy = h * 0.19 + i * 7.0 + _sway(i * 0.41, 0.06, 3);
          _blitCloud(canvas, cx, cy, 1.15 + i * 0.20,
              storm ? Color.lerp(cloudTint, deepCloud, 0.5)! : cloudTint,
              (cloudA - i * 0.05).clamp(0.05, 0.95));
        }

        // ── 雨 ──
        // 数量较之前收敛（近 20–34 / 远 14–26），配合细线与低透明度，
        // 观感从「满屏粗线」变成一层轻薄雨幕
        final nearN = 20 + (inten * 14).round();
        final farN = 14 + (inten * 12).round();
        _ensureRain(nearN, farN);

        // 近景雨丝：分「实 / 虚」两档透明度，制造纵深；
        // 细线 + 低透明度 + 长度收敛，避免「粗而杂乱」
        final nw = (0.75 + inten * 0.75).clamp(0.75, 1.5); // 原 1.0–2.8，明显变细
        final na = ((dark ? 0.09 : 0.18) + inten * 0.12).clamp(0.05, 0.30);
        final nearHi = _cached(
          'nrh${dark ? 1 : 0}${(inten * 10).round()}',
          () => Paint()
            // 必须显式 stroke：drawPath 默认是 fill，开放的两点路径会被
            // 当成“零面积填充”而完全不渲染（drawLine 不受 style 影响，
            // 所以 v1.6.56 把 drawLine 批量改成 Path 后雨丝就消失了）
            ..style = PaintingStyle.stroke
            ..color = Colors.white.withValues(alpha: na)
            ..strokeCap = StrokeCap.round
            ..strokeWidth = nw,
        );
        final nearLo = _cached(
          'nrl${dark ? 1 : 0}${(inten * 10).round()}',
          () => Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.white.withValues(alpha: na * 0.45)
            ..strokeCap = StrokeCap.round
            ..strokeWidth = nw * 0.75,
        );
        final npHi = Path();
        final npLo = Path();
        for (var i = 0; i < _rcN; i++) {
          final p = (t * _rsp![i] + _rph![i]) % 1.0;
          final y = p * (h + 60) - 30;
          final x = _rxs![i] * w + _sway(_rsh![i], 0.28, 3);
          // 长度由 14–42px 收敛到 9–17px（×强度），长短差异小了就不显乱
          final len = (9 + _rsh![i] * 8) * (1 + inten * 0.35);
          final slant = (1.2 + inten * 1.1) * (storm ? 1.3 : 1.0);
          final path = _rsh![i] > 0.55 ? npHi : npLo;
          path.moveTo(x, y);
          path.lineTo(x - slant, y + len);
        }
        canvas.drawPath(npLo, nearLo);
        canvas.drawPath(npHi, nearHi);

        // 远景雨幕：极细极淡，只做气氛
        final fa = ((dark ? 0.04 : 0.08) + inten * 0.05).clamp(0.03, 0.14);
        final farPaint = _cached(
          'fr${dark ? 1 : 0}${(inten * 10).round()}',
          () => Paint()
            ..style = PaintingStyle.stroke // 同上：不加则雨幕完全不可见
            ..color = Colors.white.withValues(alpha: fa)
            ..strokeWidth = 0.5
            ..strokeCap = StrokeCap.round,
        );
        final fp = Path();
        for (var i = 0; i < _fcN; i++) {
          final p = (t * _fsp![i] + _fph![i]) % 1.0;
          final y = p * (h + 40) - 20;
          final x = _fxs![i] * w + _sway(_fsh![i], 0.25, 2);
          final len = (6 + _fsh![i] * 5) * (1 + inten * 0.3);
          fp.moveTo(x, y);
          fp.lineTo(x - 1.0, y + len);
        }
        canvas.drawPath(fp, farPaint);

        // ── 雷雨：整屏瞬闪（一次 fill，极便宜）+ 闪电支干 ──
        if (storm) {
          // 双频叠加，形成不规则闪烁节奏
          final f1 = math.sin(t * math.pi * 2 * 3.0);
          final f2 = math.sin(t * math.pi * 2 * 7.0);
          final flash = (f1 * 0.6 + f2 * 0.4);
          if (flash > 0.72) {
            final k = ((flash - 0.72) / 0.28).clamp(0.0, 1.0);
            canvas.drawRect(
              Rect.fromLTWH(0, 0, w, h),
              _cached('flash', () => Paint())..color =
                  Colors.white.withValues(alpha: 0.30 * k),
            );
          }
          if (flash > 0.86) {
            final lp = _cached(
              'bolt',
              () => Paint()
                ..color = const Color(0xFFFFF8DC).withValues(alpha: 0.85)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.8
                ..strokeJoin = StrokeJoin.round
                ..strokeCap = StrokeCap.round,
            );
            final bx = w * 0.66 + _sway(0.3, 0.7, w * 0.05);
            final path = Path()
              ..moveTo(bx, h * 0.20)
              ..lineTo(bx - 10, h * 0.31)
              ..lineTo(bx + 5, h * 0.34)
              ..lineTo(bx - 8, h * 0.45);
            canvas.drawPath(path, lp);
          }
        }
        break;

      case _FxKind.snow:
        for (var i = 0; i < cloudN; i++) {
          final cx = _drift(i, w, cloudSpeed * 0.7);
          final cy = h * 0.18 + i * 7.0 + _sway(i * 0.41, 0.05, 3);
          _blitCloud(canvas, cx, cy, 1.15 + i * 0.18, cloudTint,
              (cloudA - i * 0.06).clamp(0.05, 0.95));
        }
        final n = 30 + (inten * 18).round();
        _ensureSnow(n);
        final pnt = _cached('snow', () => Paint());
        for (var i = 0; i < _ncN; i++) {
          final p = (t * _nsp![i] + _nph![i]) % 1.0;
          final y = p * (h + 40) - 20;
          final x = _nxs![i] * w + _sway(_nsh![i], 0.45 + _nsp![i], 9);
          final near = _nsh![i] > 0.65;
          pnt.color = Colors.white
              .withValues(alpha: near ? 0.85 : 0.42);
          canvas.drawCircle(Offset(x, y), near ? 2.0 : 1.2, pnt);
        }
        break;

      case _FxKind.fog:
        // 雾：几条横向雾带缓慢漂移（线性渐变，无模糊）
        final bands = 3 + (inten * 2).round();
        for (var i = 0; i < bands; i++) {
          final y = h * (0.16 + i * (0.62 / bands));
          final x = _drift(i, w, 0.5) * 0.35 - w * 0.1;
          final bh = 46.0 + (i % 2) * 26;
          canvas.drawRect(
            Rect.fromLTWH(x - w * 0.3, y, w * 1.6, bh),
            _cached(
              'mist$i${dark ? 1 : 0}',
              () => Paint()
                ..shader = ui.Gradient.linear(
                  Offset(0, y),
                  Offset(0, y + bh),
                  [
                    Colors.white.withValues(alpha: 0),
                    Colors.white
                        .withValues(alpha: (dark ? 0.09 : 0.20) + inten * 0.06),
                    Colors.white.withValues(alpha: 0),
                  ],
                  const [0.0, 0.5, 1.0],
                ),
            ),
          );
        }
        break;

      case _FxKind.clear:
        // 晴：柔和日晕 + 极缓慢的细卷云
        final sunX = w * 0.80, sunY = h * 0.16;
        canvas.drawCircle(
          Offset(sunX, sunY),
          w * 0.42,
          _cached(
            'sun${dark ? 1 : 0}',
            () => Paint()
              ..shader = ui.Gradient.radial(
                Offset(sunX, sunY),
                w * 0.42,
                [
                  const Color(0xFFFFE9A8)
                      .withValues(alpha: dark ? 0.16 : 0.34),
                  const Color(0xFFFFE9A8).withValues(alpha: 0),
                ],
                const [0.0, 1.0],
              ),
          ),
        );
        canvas.drawCircle(
          Offset(sunX, sunY),
          w * 0.085,
          _cached('suncore', () => Paint())
            ..color = const Color(0xFFFFF3C4)
                .withValues(alpha: dark ? 0.32 : 0.62),
        );
        for (var i = 0; i < 3; i++) {
          final cx = _drift(i, w, 0.35);
          final cy = h * (0.13 + i * 0.05) + _sway(i * 0.5, 0.04, 4);
          _blitCloud(canvas, cx, cy, 0.95 + i * 0.12,
              dark ? const Color(0xFF9FB0C4) : Colors.white,
              (dark ? 0.10 : 0.20) - i * 0.02);
        }
        break;

      case _FxKind.cloudy:
      case _FxKind.overcast:
        // 数量随强度 2–4；越强越暗、飘得越快
        final overcast = kind == _FxKind.overcast;
        final tint = overcast
            ? cloudTint
            : Color.lerp(
                dark ? const Color(0xFFB9C7D6) : Colors.white, cloudTint, inten * 0.85)!;
        final baseA = overcast
            ? (dark ? 0.34 : 0.62) + inten * 0.12
            : (dark ? 0.28 : 0.55) + inten * 0.10;
        for (var i = 0; i < cloudN; i++) {
          final cx = _drift(i, w, cloudSpeed);
          final cy = h * 0.21 + i * 9.0 + _sway(i * 0.37, 0.05, 3);
          _blitCloud(canvas, cx, cy, 1.10 + i * 0.20, tint,
              (baseA - i * 0.05).clamp(0.05, 0.95));
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FxPainter old) =>
      old.kind != kind || old.intensity != intensity || old.dark != dark;
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
    // 点击面板外的空白处关闭（默认即 true，这里显式声明避免后续被误改）
    isDismissible: true,
    enableDrag: true,
    // 给出可见的遮罩，让“点外部可关闭”这件事可被感知
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (ctx) => DraggableScrollableSheet(
      // 优先半屏弹出；向上滑动可展开覆盖更多（吸附到半屏 / 近满屏两档）
      initialChildSize: 0.58,
      minChildSize: 0.32,
      maxChildSize: 0.94,
      snap: true,
      snapSizes: const [0.58, 0.94],
      // 必须为 false：true 时 DraggableScrollableSheet 内部会用
      // `SizedBox.expand` 把 sheet 撑满整个屏幕（见 Flutter 源码
      // draggable_scrollable_sheet.dart: `widget.expand ? SizedBox.expand(child: sheet) : sheet`），
      // 于是面板的渲染树盖住全屏，点击“面板外空白处”落到的是面板自己的树、
      // 永远到不了下层遮罩 → 点空白无法退出。
      // 置 false 后 sheet 只占 58%，上方空白归还给遮罩即可点击关闭；
      // snap 不受影响（吸附位置按 LayoutBuilder 的 constraints.biggest.height 计算）。
      expand: false,
      builder: (ctx2, controller) => _WeatherPanel(
        state: state,
        hasPos: hasPos,
        scrollController: controller,
      ),
    ),
  );
}

/// 打开「近 15 日天气」底部弹层（懒加载 15d 接口）
Future<void> showDaily15Sheet(BuildContext context) async {
  WeatherCenter.instance.load15();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _Daily15Sheet(),
  );
}

/// 细分隔线。
/// 注意：不能用 `Divider` —— 在 `CrossAxisAlignment.start` 的 Column 里
/// （以及默认居中的 Column）子项只拿到宽松约束，`Divider` 内部没有宽度的
/// Container 会塔成 0 宽而完全不可见。这里显式给 `width: double.infinity`。
Widget _hairline([double alpha = 0.08]) => Container(
      width: double.infinity,
      height: 1,
      color: Colors.white.withValues(alpha: alpha),
    );

/// 顶部区域承载的指标条数（其余留在底部卡片）
const int _topMetricCount = 6;

/// 面板文字阴影（仅用于弹层标题等仍需要独立的场合）
const List<Shadow> _kTextShadow = [
  Shadow(color: Color(0x73000000), blurRadius: 8, offset: Offset(0, 1)),
];

/// 空气质量等级文字（按 AQI 数值本地化，避免直接使用接口返回的单一语言）
String _airLabel(int aqi, AppLocalizations s) {
  if (aqi < 0) return '--';
  if (aqi <= 50) return s.airExcellent;
  if (aqi <= 100) return s.airGood;
  if (aqi <= 150) return s.airModerate;
  if (aqi <= 200) return s.airUnhealthy;
  if (aqi <= 300) return s.airVeryUnhealthy;
  return s.airHazardous;
}

/// 温度 → 进度条颜色（冷蓝 → 暖红）
Color _tempColor(int t) {
  if (t <= 0) return const Color(0xFF60A5FA);
  if (t <= 10) return const Color(0xFF22D3EE);
  if (t <= 20) return const Color(0xFF34D399);
  if (t <= 28) return const Color(0xFFFBBF24);
  return const Color(0xFFF87171);
}

/// 日期 → "M/d"
String _md(DateTime d) => '${d.month}/${d.day}';

/// 前三天用「今天/明天/后天」，其余用星期
String _dayLabel(int i, DateTime? d, AppLocalizations s) {
  if (i == 0) return s.weatherToday;
  if (i == 1) return s.weatherTomorrow;
  if (i == 2) return s.weatherDayAfter;
  if (d == null) return '--';
  return s.weatherWeekday('${d.weekday}');
}

/// 建议级别文字
String _levelLabel(_TipLevel l, AppLocalizations s) {
  switch (l) {
    case _TipLevel.danger:
      return s.hamLevelDanger;
    case _TipLevel.warn:
      return s.hamLevelWarn;
    case _TipLevel.good:
      return s.hamLevelGood;
    case _TipLevel.tip:
      return s.hamLevelTip;
  }
}

/// 温度进度条：底轨 + 起止温度渐变填充（无第三方库，纯 CustomPainter）
class _TempBarPainter extends CustomPainter {
  final int min;
  final int max;
  final int lo;
  final int hi;
  final Color track;
  const _TempBarPainter({
    required this.min,
    required this.max,
    required this.lo,
    required this.hi,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const r = 4.0;
    final h = size.height;
    final span = (hi - lo).abs() < 1 ? 1 : (hi - lo);
    var f0 = ((min - lo) / span).clamp(0.0, 1.0);
    var f1 = ((max - lo) / span).clamp(0.0, 1.0);
    // 温差过小时给一个最小可见长度（居中显示）
    if (f1 - f0 < 0.12) {
      final c = (f0 + f1) / 2;
      f0 = (c - 0.06).clamp(0.0, 0.88);
      f1 = f0 + 0.12;
    }
    final trackR = RRect.fromLTRBR(0, 0, size.width, h, const Radius.circular(r));
    canvas.drawRRect(trackR, Paint()..color = track);
    final x0 = size.width * f0;
    final x1 = size.width * f1;
    final bar = RRect.fromLTRBR(
        x0, 0, x1 < x0 + 2 ? x0 + 2 : x1, h, const Radius.circular(r));
    final g = LinearGradient(
        colors: [_tempColor(min), _tempColor(max)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight);
    canvas.drawRRect(
      bar,
      Paint()
        ..shader = g.createShader(
            Rect.fromLTWH(x0, 0, (x1 - x0).abs() < 2 ? 2 : x1 - x0, h)),
    );
  }

  @override
  bool shouldRepaint(covariant _TempBarPainter old) =>
      old.min != min || old.max != max || old.lo != lo || old.hi != hi;
}

class _WeatherPanel extends StatefulWidget {
  final AppState state;
  final bool hasPos;

  /// 由 DraggableScrollableSheet 提供：内容必须绑定它，向上拖动才能展开面板
  final ScrollController scrollController;
  const _WeatherPanel({
    required this.state,
    required this.hasPos,
    required this.scrollController,
  });
  @override
  State<_WeatherPanel> createState() => _WeatherPanelState();
}

class _WeatherPanelState extends State<_WeatherPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  bool _tipsExpanded = false;

  @override
  void initState() {
    super.initState();
    // 2 秒循环：云朵飘动 / 雨雪下落等背景元素缓慢循环动画
    _ac = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
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
            final kind = (wc.now != null) ? _fxKindOf(wc.now!) : _FxKind.cloudy;
            final intensity = (wc.now != null) ? weatherIntensity(wc.now!) : 0.0;
            final grad = _fxGradient(kind, dark, rain: intensity);
            // AnimatedContainer：天气/强度切换时渐变与整体色调平滑过渡
            return AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOut,
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
                  // 动态背景层（云 / 雨 / 雪 / 雾，强度驱动；不引入 3D 引擎）
                  // _FxLayer 内部包 RepaintBoundary：每帧只重绘背景这一层，
                  // 不连带上方文字/卡片一起重光栅化
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _FxLayer(
                        kind: kind,
                        anim: _ac,
                        dark: dark,
                        intensity: intensity,
                      ),
                    ),
                  ),
                  // 背景纱层：给动态背景统一压一层极淡的纱，
                  // 让云/雨稳定处于「背景」地位（不抢主体文字），
                  // 也顺带柔化云团边缘。仅一次 fill，开销可忽略。
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: dark ? 0.10 : 0.05),
                              Colors.black.withValues(alpha: dark ? 0.16 : 0.09),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 内容层（可滚动，向上拖动展开面板）
                  // 顶部暗角渐变随内容一起滚动，见 _body 中的顶部块
                  _body(wc, dark),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _body(WeatherCenter wc, bool dark) {
    final s = S.of(context);
    final hasPos = widget.hasPos;
    final topInfo = (hasPos && wc.now != null)
        ? _top(wc, s)
        : _statusHint(wc, s, hasPos, dark);
    // 整页内容交给 DraggableScrollableSheet 的 controller：
    // 在任意位置向上拖动即可展开面板（半屏 → 近满屏），向下拖动收起
    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.zero,
      children: [
        // ── 顶部：城市 / 大号温度 / 天气状况 / 空气质量 + 关键指标 ──
        // 暗角用「随内容滚动」的渐变：底部淡出到全透明，
        // 因此不会出现「一块黑色圆角方块」的硬边界
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.34),
                Colors.black.withValues(alpha: 0.10),
                Colors.black.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: topInfo,
        ),
        // ── 中部留白：动态背景展示区（云 / 雨在此区域可见）──
        const SizedBox(height: 56),
        // ── 底部：半透明圆角卡片（无数据时仅保留动态背景）──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
          child: wc.now == null
              ? const SizedBox.shrink()
              : _bottomCard(wc, s, dark),
        ),
      ],
    );
  }

  /// 无定位 / 加载中 / 无数据
  Widget _statusHint(
      WeatherCenter wc, AppLocalizations s, bool hasPos, bool dark) {
    final IconData ic;
    final String msg;
    if (!hasPos) {
      ic = Icons.gps_off_rounded;
      msg = s.weatherNoLoc;
    } else if (wc.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white)),
      );
    } else if (wc.errorCode == 1) {
      ic = Icons.cloud_off_rounded;
      msg = s.weatherDataFail;
    } else if (wc.errorCode == 2) {
      ic = Icons.wifi_off_rounded;
      msg = s.weatherConnFail;
    } else {
      ic = Icons.cloud_off_rounded;
      msg = s.weatherUnavail;
    }
    return Row(children: [
      Icon(ic, color: Colors.white.withValues(alpha: 0.8), size: 28),
      const SizedBox(width: 12),
      Expanded(
        child: Text(msg,
            style: ts(12.5, c: Colors.white.withValues(alpha: 0.9), h: 1.55)),
      ),
    ]);
  }

  /// 顶部信息区：城市 / 空气质量胶囊 / 大号温度 / 天气状况 /
  /// 今日高低温 · 体感 · 更新 / 关键指标（湿度·风·气压·能见度·露点·云量）
  ///
  /// 上半部分承载主要信息密度（原先沉在底部的指标上移至此，
  /// 并且不在底部重复）；温度用「大数字 + 小度数符号」，
  /// 不套逐字阴影（发糊），靠顶部全幅渐变保证可读性。
  Widget _top(WeatherCenter wc, AppLocalizations s) {
    final now = wc.now!;
    final aqi = wc.air?.aqiValue ?? -1;
    final d0 = wc.daily.isNotEmpty ? wc.daily.first : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行：城市名（左）+ 空气质量胶囊（右）
        Row(children: [
          Icon(Icons.place_rounded,
              size: 13, color: Colors.white.withValues(alpha: 0.72)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(now.city ?? s.weatherCurLoc,
                style: ts(13,
                    c: Colors.white.withValues(alpha: 0.94),
                    w: FontWeight.w600,
                    ls: 0.2),
                overflow: TextOverflow.ellipsis),
          ),
          if (aqi >= 0) ...[const SizedBox(width: 10), _aqiPill(aqi, s)],
        ]),
        const SizedBox(height: 10),
        // 第二行：大号温度 + 天气状况 + 天气图标（自适应缩放，避免窄屏溢出）
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 大数字与度数符号分离：数字 58、度数 22 且抬高
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(now.tempDisplay,
                      style: ts(58,
                          w: FontWeight.w800, c: Colors.white, ls: -2)),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text('°',
                        style: ts(24,
                            w: FontWeight.w700,
                            c: Colors.white.withValues(alpha: 0.85))),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Icon(now.iconData,
                      size: 22, color: Colors.white.withValues(alpha: 0.95)),
                  const SizedBox(width: 7),
                  Text(now.text,
                      style: ts(16, w: FontWeight.w600, c: Colors.white)),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // 今日高低温 · 体感 · 观测时间（一行紧凑信息）
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(children: [
            if (d0 != null) ...[
              Text('${s.weatherToday} ${d0.tempMin}° ~ ${d0.tempMax}°',
                  style: ts(11.5,
                      w: FontWeight.w600,
                      c: Colors.white.withValues(alpha: 0.86))),
              Text('  ·  ',
                  style: ts(11.5, c: Colors.white.withValues(alpha: 0.35))),
            ],
            Text(s.weatherFeels(now.feelsLike),
                style: ts(11.5, c: Colors.white.withValues(alpha: 0.7))),
            Text('  ·  ',
                style: ts(11.5, c: Colors.white.withValues(alpha: 0.35))),
            Text(s.weatherObserved(now.obsTimeShort),
                style: ts(11.5, c: Colors.white.withValues(alpha: 0.7))),
          ]),
        ),
        const SizedBox(height: 12),
        // 关键指标：上半部分的信息密度来源（两列清单）
        _topMetrics(wc, s),
      ],
    );
  }

  /// 顶部关键指标（两列清单，无分隔线，保持紧凑）
  Widget _topMetrics(WeatherCenter wc, AppLocalizations s) {
    final pairs = _metricPairs(wc, s);
    final head = pairs.take(_topMetricCount).toList();
    final rows = <Widget>[];
    for (var i = 0; i < head.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Expanded(child: _kvPair(head[i].$1, head[i].$2)),
          const SizedBox(width: 18),
          Expanded(
            child: i + 1 < head.length
                ? _kvPair(head[i + 1].$1, head[i + 1].$2)
                : const SizedBox.shrink(),
          ),
        ]),
      ));
    }
    return Column(children: rows);
  }

  /// 空气质量胶囊：深色底 + 等级色圆点（比整块高饱和色块更耐看，也更易读）
  Widget _aqiPill(int aqi, AppLocalizations s) {
    final col = WeatherCenter.instance.air?.levelColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: col, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('${s.weatherAir} $aqi',
            style: ts(10.5, w: FontWeight.w700, c: Colors.white)),
        const SizedBox(width: 5),
        Text(_airLabel(aqi, s),
            style: ts(10.5, c: Colors.white.withValues(alpha: 0.68))),
      ]),
    );
  }

  /// 底部半透明圆角卡片：三天预报 + 近 15 日按钮 + 火腿建议 + 详细数据
  Widget _bottomCard(WeatherCenter wc, AppLocalizations s, bool dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        // 半透明圆角卡片：不使用 BackdropFilter（避免每帧模糊开销），
        // 也不用黑色投影（叠在彩色渐变上会发灰变脏）。
        // 底色略提高，保证雨丝飘过时文字依然压得住
        color: Colors.white.withValues(alpha: dark ? 0.14 : 0.19),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 业余无线电建议排在三天预报之前（更贴近「架台/通联决策」的场景）
          _hamCard(wc, s),
          const SizedBox(height: 18),
          _sectionTitle(Icons.calendar_month_rounded, s.weatherForecast3),
          const SizedBox(height: 4),
          ..._forecastRows(wc, s),
          const SizedBox(height: 14),
          _daily15Button(s),
          const SizedBox(height: 18),
          _sectionTitle(Icons.tune_rounded, s.weatherDetails),
          const SizedBox(height: 6),
          _details(wc, s),
          const SizedBox(height: 12),
          Center(
            child: Text(s.weatherPowered,
                style: ts(9.5, c: Colors.white.withValues(alpha: 0.5))),
          ),
        ],
      ),
    );
  }

  /// 分组标题：小号 + 字距，弱化存在感、让内容成为主角
  Widget _sectionTitle(IconData ic, String text) => Row(children: [
        Icon(ic, size: 13, color: Colors.white.withValues(alpha: 0.62)),
        const SizedBox(width: 6),
        Text(text,
            style: ts(11.5,
                w: FontWeight.w700, c: Colors.white.withValues(alpha: 0.8), ls: 0.8)),
      ]);

  /// 「查看近 15 日天气」按钮：自定义（可控内边距与字重，比 OutlinedButton 利落）
  Widget _daily15Button(AppLocalizations s) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showDaily15Sheet(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.date_range_rounded,
                  size: 16, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              Text(s.weatherDaily15,
                  style: ts(13, w: FontWeight.w600, c: Colors.white)),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 17, color: Colors.white.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  /// 三天预报行（日期 / 图标 / 最低温 / 温度进度条 / 最高温）
  List<Widget> _forecastRows(WeatherCenter wc, AppLocalizations s) {
    if (wc.daily.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(wc.loading ? s.weatherPanelSub : s.weatherUnavail,
              style: ts(11.5, c: Colors.white.withValues(alpha: 0.65))),
        ),
      ];
    }
    final list = wc.daily;
    var lo = list.first.minV;
    var hi = list.first.maxV;
    for (final d in list) {
      if (d.minV < lo) lo = d.minV;
      if (d.maxV > hi) hi = d.maxV;
    }
    final out = <Widget>[];
    for (var i = 0; i < list.length; i++) {
      if (i > 0) out.add(_hairline());
      out.add(_dailyRow(i, list[i], lo, hi, s));
    }
    return out;
  }

  Widget _dailyRow(
      int i, WeatherDaily d, int lo, int hi, AppLocalizations s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        SizedBox(
          width: 52,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_dayLabel(i, d.date, s),
                  style: ts(12.5, w: FontWeight.w700, c: Colors.white)),
              const SizedBox(height: 1),
              Text(d.date == null ? '' : _md(d.date!),
                  style: ts(10, c: Colors.white.withValues(alpha: 0.5))),
            ],
          ),
        ),
        Icon(d.iconData,
            size: 19, color: Colors.white.withValues(alpha: 0.9)),
        const SizedBox(width: 12),
        SizedBox(
          width: 34,
          child: Text('${d.minV}°',
              textAlign: TextAlign.right,
              style: ts(12,
                  w: FontWeight.w600,
                  c: Colors.white.withValues(alpha: 0.7))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 6,
            child: CustomPaint(
              painter: _TempBarPainter(
                min: d.minV,
                max: d.maxV,
                lo: lo,
                hi: hi,
                track: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 34,
          child: Text('${d.maxV}°',
              style: ts(13, w: FontWeight.w800, c: Colors.white)),
        ),
      ]),
    );
  }

  /// 火腿建议卡片（按级别排序，可展开全部）
  Widget _hamCard(WeatherCenter wc, AppLocalizations s) {
    final all = _hamTips(wc, s);
    const maxCollapsed = 4;
    final showToggle = all.length > maxCollapsed;
    final shown =
        (_tipsExpanded || !showToggle) ? all : all.sublist(0, maxCollapsed);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.rss_feed_rounded,
                size: 15, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(width: 7),
            Text(s.hamTitle,
                style: ts(12.5, w: FontWeight.w800, c: Colors.white)),
            const Spacer(),
            if (all.isNotEmpty)
              Text('${all.length}',
                  style: ts(10.5,
                      w: FontWeight.w700,
                      c: Colors.white.withValues(alpha: 0.45))),
          ]),
          const SizedBox(height: 8),
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(s.hamNoData,
                  style: ts(12, c: Colors.white.withValues(alpha: 0.8), h: 1.55)),
            )
          else
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(height: 2),
              _tipRow(shown[i], s),
            ],
          if (showToggle) ...[
            const SizedBox(height: 4),
            _tipsToggle(all.length, s),
          ],
        ],
      ),
    );
  }

  /// 单条建议：色点 + 「级别」小标签 + 正文；危险项仅用淡色底，不加描边方框
  Widget _tipRow(_HamTip tip, AppLocalizations s) {
    final danger = tip.level == _TipLevel.danger;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: danger ? tip.color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: tip.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(tip.icon, size: 12, color: tip.color),
                  const SizedBox(width: 5),
                  Text(_levelLabel(tip.level, s),
                      style: ts(9.5,
                          w: FontWeight.w800, c: tip.color, ls: 0.7)),
                ]),
                const SizedBox(height: 4),
                Text(tip.text,
                    style: ts(12,
                        c: Colors.white.withValues(alpha: 0.9), h: 1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipsToggle(int n, AppLocalizations s) {
    return InkWell(
      onTap: () => setState(() => _tipsExpanded = !_tipsExpanded),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_tipsExpanded ? s.hamLess : s.hamMore('$n'),
              style: ts(11,
                  w: FontWeight.w600,
                  c: Colors.white.withValues(alpha: 0.82))),
          Icon(
              _tipsExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.82)),
        ]),
      ),
    );
  }

  /// 指标总表（顺序即展示顺序）。
  /// 前 [_topMetricCount] 项上移到顶部区域，其余留在底部卡片，两处不重复。
  List<(String, String)> _metricPairs(WeatherCenter wc, AppLocalizations s) {
    final n = wc.now;
    if (n == null) return const [];
    final air = wc.air;
    final d0 = wc.daily.isNotEmpty ? wc.daily.first : null;
    final hasAir = air != null && air.aqiValue >= 0;
    return [
      // ── 前 _topMetricCount 项：顶部常用指标 ──
      (s.weatherHumidity, '${n.humidity}%'),
      (s.weatherWindDir, '${n.windDir} ${n.windScale} 级'),
      (s.weatherPressure, '${n.pressure} hPa'),
      (s.weatherVis, '${n.vis} km'),
      (s.weatherDew, '${n.dew}°'),
      (s.weatherCloud, '${n.cloud}%'),
      // ── 其余：留在底部卡片 ──
      (s.weatherWindSpeed, '${n.windSpeed} km/h'),
      (s.weatherPrecip, '${n.precip} mm'),
      if (hasAir) ('PM2.5', air.pm2p5),
      if (hasAir) ('PM10', air.pm10),
      if (hasAir)
        (s.weatherAQIPrimary, air.primary.isEmpty ? '—' : air.primary),
      if (d0 != null) (s.weatherSunrise, d0.sunrise),
      if (d0 != null) (s.weatherSunset, d0.sunset),
      if (d0 != null) (s.weatherUV, d0.uvIndex),
    ];
  }

  /// 底部详细数据：顶部已展示的指标不再重复
  Widget _details(WeatherCenter wc, AppLocalizations s) {
    final all = _metricPairs(wc, s);
    if (all.length <= _topMetricCount) return const SizedBox.shrink();
    final pairs = all.sublist(_topMetricCount);

    final rows = <Widget>[];
    for (var i = 0; i < pairs.length; i += 2) {
      if (i > 0) rows.add(_hairline());
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(child: _kvPair(pairs[i].$1, pairs[i].$2)),
          const SizedBox(width: 20),
          Expanded(
            child: i + 1 < pairs.length
                ? _kvPair(pairs[i + 1].$1, pairs[i + 1].$2)
                : const SizedBox.shrink(),
          ),
        ]),
      ));
    }
    return Column(children: rows);
  }

  Widget _kvPair(String label, String value) => Row(children: [
        Text(label,
            style: ts(10.5, c: Colors.white.withValues(alpha: 0.58))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(12, w: FontWeight.w700, c: Colors.white)),
        ),
      ]);
}

/// ─── 近 15 日天气弹层 ───
class _Daily15Sheet extends StatefulWidget {
  const _Daily15Sheet();
  @override
  State<_Daily15Sheet> createState() => _Daily15SheetState();
}

class _Daily15SheetState extends State<_Daily15Sheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = S.of(context);
    final maxH = MediaQuery.of(context).size.height * 0.82;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
        child: ValueListenableBuilder<int>(
          valueListenable: WeatherCenter.instance.version,
          builder: (context, _, _) {
            final wc = WeatherCenter.instance;
            final kind = (wc.now != null) ? _fxKindOf(wc.now!) : _FxKind.cloudy;
            final intensity = (wc.now != null) ? weatherIntensity(wc.now!) : 0.0;
            final grad = _fxGradient(kind, dark, rain: intensity);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: grad,
                ),
              ),
              child: Stack(children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: _FxLayer(
                      kind: kind,
                      anim: _ac,
                      dark: dark,
                      intensity: intensity,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                        child: Row(children: [
                          const Icon(Icons.date_range_rounded,
                              size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(s.weatherDaily15Title,
                                style: ts(14.5,
                                        w: FontWeight.w800, c: Colors.white)
                                    .copyWith(shadows: _kTextShadow)),
                          ),
                        ]),
                      ),
                      Flexible(child: _list(wc, S.of(context))),
                    ],
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _list(WeatherCenter wc, AppLocalizations s) {
    if (wc.loading15 && wc.daily15.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
            child:
                CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
      );
    }
    if (wc.daily15.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 34, color: Colors.white70),
          const SizedBox(height: 10),
          Text(
              wc.errorCode15 == 2 ? s.weatherConnFail : s.weatherDataFail,
              textAlign: TextAlign.center,
              style: ts(12, c: Colors.white.withValues(alpha: 0.85))),
        ]),
      );
    }
    final list = wc.daily15;
    var lo = list.first.minV;
    var hi = list.first.maxV;
    for (final d in list) {
      if (d.minV < lo) lo = d.minV;
      if (d.maxV > hi) hi = d.maxV;
    }
    // 与主页面板保持同一套排版：细分隔线、列宽对齐、字号统一
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
      itemCount: list.length,
      separatorBuilder: (_, _) => _hairline(),
      itemBuilder: (context, i) {
        final d = list[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dayLabel(i, d.date, s),
                    style: ts(12.5, w: FontWeight.w700, c: Colors.white)),
                const SizedBox(height: 1),
                Text(d.date == null ? '' : _md(d.date!),
                    style: ts(10, c: Colors.white.withValues(alpha: 0.5))),
              ],
            ),
          ),
          Icon(d.iconData,
              size: 19, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 12),
          SizedBox(
            width: 34,
            child: Text('${d.minV}°',
                textAlign: TextAlign.right,
                style: ts(12,
                    w: FontWeight.w600,
                    c: Colors.white.withValues(alpha: 0.7))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 6,
              child: CustomPaint(
                painter: _TempBarPainter(
                  min: d.minV,
                  max: d.maxV,
                  lo: lo,
                  hi: hi,
                  track: Colors.white.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text('${d.maxV}°',
                style: ts(13, w: FontWeight.w800, c: Colors.white)),
          ),
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(d.textDay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(10, c: Colors.white.withValues(alpha: 0.75))),
                const SizedBox(height: 1),
                Text('${d.precip}mm',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(9.5, c: Colors.white.withValues(alpha: 0.5))),
              ],
            ),
          ),
          ]),
        );
      },
    );
  }
}
