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
  /// 驱动动画（use "repaint" 直接重绘，画家实例可跨帧复用 → 粒子参数缓存真正生效）
  final Animation<double> anim;
  final bool dark;
  /// 天气强度 0.0–1.0：云层数量/明暗/速度、雨雪密度/速度/长度均随其变化
  final double intensity;
  _FxPainter({
    required this.kind,
    required this.anim,
    required this.dark,
    this.intensity = 0,
  }) : super(repaint: anim);

  /// 动画进度 0..1（循环相位）
  double get t => anim.value;

  // ── 粒子参数缓存：位置/相位/速度/外形在首帧确定后复用（不再每帧重建 Random+数组）──
  List<double>? _rxs, _rph, _rsp, _rsh; // 近雨
  List<double>? _fxs, _fph, _fsp, _fsh; // 远雨
  int _rcN = 0;
  int _fcN = 0;

  void _ensureRain(int nearN, int farN) {
    if (_rcN == nearN && _fcN == farN && _rxs != null && _fxs != null) return;
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

  /// 云朵缓慢横向漂移（循环无缝，约十几秒横穿一次）；强度越高漂移越快
  double _drift(int i, double w, double speed) {
    final p = (t * (0.05 + i * 0.012) * speed + i * 0.31) % 1.0;
    return p * (w + 300) - 150;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final inten = intensity.clamp(0.0, 1.0);
    final cloudDark = dark ? const Color(0xFF5B6B7C) : const Color(0xFFC9D6E4);
    // 强度越高：云层数量越多、颜色越暗、移动越快
    final cloudN = (2 + (inten * 2.2).round()).clamp(2, 4);
    final cloudSpeed = 0.6 + inten * 0.9;
    final deepCloud = Color.lerp(cloudDark, const Color(0xFF262F3B), 0.75)!;

    switch (kind) {
      case _FxKind.rain:
      case _FxKind.storm:
        final storm = kind == _FxKind.storm;
        // 积雨云：数量随强度 2–4 朵，强度越高颜色越暗、飘动越快
        final cloudTint = Color.lerp(
            storm ? const Color(0xFF46586B) : cloudDark, deepCloud, inten * 0.7)!;
        final cloudA =
            (storm ? (dark ? 0.30 : 0.5) : (dark ? 0.20 : 0.45)) + inten * 0.08;
        for (var i = 0; i < cloudN; i++) {
          final cx = _drift(i, w, cloudSpeed);
          // 云带落在顶部信息与底部卡片之间的中部留白区，避免压住文字
          final cy = h * 0.20 + i * 8.0 + _sway(i * 0.41, 0.06, 3);
          _CloudPuffPainter.paint(canvas, cx, cy, 1.2 + i * 0.22,
              (cloudA - i * 0.03).clamp(0.05, 0.7), tint: cloudTint);
        }
        // 雨滴：强度越高 → 越密集、下落越快、透明度与长度越大
        final nearN = 34 + (inten * 22).round();
        final farN = 30 + (inten * 18).round();
        _ensureRain(nearN, farN);
        final fall = 0.6 + inten * 1.0; // 下落速度倍率
        // ── 近景雨丝：合并为一条 Path 绘制（一次 raster，不再逐滴 drawLine）──
        final nearPaint = Paint()
          ..color = Colors.white.withValues(
              alpha: ((dark ? 0.16 : 0.42) + inten * 0.26).clamp(0.05, 0.85))
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (1.1 + inten * 1.7).clamp(1.0, 3.0);
        final np = Path();
        for (var i = 0; i < _rcN; i++) {
          final p = (t * _rsp![i] * fall + _rph![i]) % 1.0;
          final y = p * (h + 40) - 20;
          final x = _rxs![i] * w + _sway(_rsh![i], 0.35 + inten * 0.35, 5);
          final len = (7 + _rsh![i] * 9) * (1 + inten * 0.7);
          final slant = 1.4 + inten * 1.8;
          np.moveTo(x, y);
          np.lineTo(x - slant, y + len);
        }
        canvas.drawPath(np, nearPaint);
        // ── 远景雨幕：细淡，一条 Path ──
        final farPaint = Paint()
          ..color = Colors.white.withValues(
              alpha: ((dark ? 0.04 : 0.10) + inten * 0.06).clamp(0.03, 0.2))
          ..strokeWidth = 0.6 + inten * 0.3;
        final fp = Path();
        for (var i = 0; i < _fcN; i++) {
          final p = (t * _fsp![i] * fall + _fph![i]) % 1.0;
          final y = p * (h + 30) - 15;
          final x = _fxs![i] * w + _sway(_fsh![i], 0.3 + inten * 0.2, 3);
          final len = (3 + _fsh![i] * 5) * (1 + inten * 0.4);
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
        // 雪：无 blur 实色圆 + 复用单一 Paint；数量随强度 26–46，减轻重绘
        final rnd = math.Random(9);
        final pnt = Paint()..color = Colors.white;
        final n = 26 + (inten * 20).round();
        final fall = 0.7 + inten * 0.9;
        for (var i = 0; i < n; i++) {
          final px = rnd.nextDouble();
          final ph = rnd.nextDouble();
          final sp = (0.06 + rnd.nextDouble() * 0.12) * fall;
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
        // 雾：强度越高雾团越多越浓（径向渐变团 + 无 blur 细雾纹）
        final fogs = 3 + (inten * 3).round();
        final fogA = (dark ? 0.05 : 0.14) + inten * 0.08;
        for (var i = 0; i < fogs; i++) {
          final cx = w * (0.1 + i * 0.26) + _sway(i * 0.53, 0.05, w * 0.22);
          final cy = (0.18 + (i % 3) * 0.3) * h;
          final rr = 60.0 + (i % 2) * 40;
          final g = RadialGradient(colors: [
            Colors.white.withValues(alpha: fogA),
            Colors.white.withValues(alpha: 0),
          ]);
          final p = Paint()
            ..shader = g.createShader(Rect.fromCircle(center: Offset(cx, cy), radius: rr));
          canvas.drawCircle(Offset(cx, cy), rr, p);
        }
        final fp = Paint()
          ..color = Colors.white
              .withValues(alpha: (dark ? 0.05 : 0.1) + inten * 0.05);
        final stripes = 12 + (inten * 10).round(); // 12–22
        for (var i = 0; i < stripes; i++) {
          final x =
              w * (0.06 + (i % 5) * 0.22) + _sway(i * 0.71, 0.04, w * 0.3);
          final y = (0.08 + ((i ~/ 5) % 4) * 0.26) * h;
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
        // 数量随强度 2–4；越强颜色越暗、飘动越快
        final overcast = kind == _FxKind.overcast;
        final tint = Color.lerp(overcast ? cloudDark : Colors.white,
            overcast ? deepCloud : const Color(0xFFB9C7D6), inten * 0.9)!;
        final baseA = overcast
            ? (dark ? 0.16 : 0.32) + inten * 0.08
            : (dark ? 0.2 : 0.48) + inten * 0.06;
        for (var i = 0; i < cloudN; i++) {
          final cx = _drift(i, w, cloudSpeed);
          final cy = h * 0.22 + i * 10.0 + _sway(i * 0.37, 0.05, 3);
          _CloudPuffPainter.paint(canvas, cx, cy, 1.15 + i * 0.22,
              (baseA - i * 0.04).clamp(0.05, 0.75), tint: tint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FxPainter old) =>
      old.kind != kind || old.intensity != intensity;
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

/// 面板文字统一纯白 + 阴影，保证在明亮/动态背景上依然清晰
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
  const _WeatherPanel({required this.state, required this.hasPos});
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
                  Positioned.fill(
                    child: IgnorePointer(
                      // key 绑定天气种类：切换时重建粒子参数，其他参数变化平滑过渡
                      child: CustomPaint(
                        key: ValueKey<int>(kind.index),
                        painter: _FxPainter(
                          kind: kind,
                          anim: _ac,
                          dark: dark,
                          intensity: intensity,
                        ),
                      ),
                    ),
                  ),
                  // 内容层：顶部信息 + 中部留白 + 底部半透明卡片
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
    final maxH = MediaQuery.of(context).size.height * 0.88;
    final hasPos = widget.hasPos;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 顶部：城市 / 大号温度 / 天气状况 / 空气质量胶囊 ──
          // 顶部叠一层淡暗角：云/雨粒子经过时仍保证白字清晰
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.24),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: (hasPos && wc.now != null)
                  ? _top(wc.now!, s)
                  : _statusHint(wc, s, hasPos, dark),
            ),
          ),
          // ── 中部留白：动态背景展示区（云 / 雨在此区域可见）──
          const SizedBox(height: 96),
          // ── 底部：半透明圆角卡片（无数据时仅保留动态背景）──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: wc.now == null
                  ? const SizedBox.shrink()
                  : _bottomCard(wc, s, dark),
            ),
          ),
        ],
      ),
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
        padding: EdgeInsets.symmetric(vertical: 26),
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
      Icon(ic, color: Colors.white70, size: 30),
      const SizedBox(width: 12),
      Expanded(
        child: Text(msg,
            style: ts(12, c: Colors.white.withValues(alpha: 0.88), h: 1.5)
                .copyWith(shadows: _kTextShadow)),
      ),
    ]);
  }

  /// 顶部信息区：城市名 + 空气质量胶囊 / 大号温度 + 天气状况
  Widget _top(WeatherNow now, AppLocalizations s) {
    final aqi = WeatherCenter.instance.air?.aqiValue ?? -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行：城市名（左）+ 空气质量胶囊（右）
        Row(children: [
          const Icon(Icons.place_rounded, size: 14, color: Colors.white70),
          const SizedBox(width: 3),
          Expanded(
            child: Text(now.city ?? s.weatherCurLoc,
                style: ts(12.5,
                        c: Colors.white.withValues(alpha: 0.9),
                        w: FontWeight.w700)
                    .copyWith(shadows: _kTextShadow),
                overflow: TextOverflow.ellipsis),
          ),
          if (aqi >= 0) ...[const SizedBox(width: 8), _aqiPill(aqi, s)],
        ]),
        const SizedBox(height: 6),
        // 第二行：大号温度 + 天气状况 + 天气图标（自适应缩放，避免窄屏溢出）
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${now.tempDisplay}°',
                  style: ts(52, w: FontWeight.w900, c: Colors.white)
                      .copyWith(shadows: _kTextShadow)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(now.text,
                    style: ts(15,
                            w: FontWeight.w700,
                            c: Colors.white.withValues(alpha: 0.95))
                        .copyWith(shadows: _kTextShadow)),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Icon(now.iconData,
                    size: 30, color: Colors.white.withValues(alpha: 0.92)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text('${s.weatherFeels(now.feelsLike)} · ${s.weatherObserved(now.obsTimeShort)}',
            style: ts(11, c: Colors.white.withValues(alpha: 0.75))
                .copyWith(shadows: _kTextShadow)),
      ],
    );
  }

  /// 空气质量胶囊
  Widget _aqiPill(int aqi, AppLocalizations s) {
    final col = WeatherCenter.instance.air?.levelColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.air_rounded, size: 12, color: Colors.white),
        const SizedBox(width: 5),
        Flexible(
          child: Text('${s.weatherAir} $aqi · ${_airLabel(aqi, s)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(10.5, w: FontWeight.w800, c: Colors.white)),
        ),
      ]),
    );
  }

  /// 底部半透明圆角卡片：三天预报 + 近 15 日按钮 + 火腿建议 + 详细数据
  Widget _bottomCard(WeatherCenter wc, AppLocalizations s, bool dark) {
    final card = Colors.white.withValues(alpha: dark ? 0.12 : 0.20);
    final border = Colors.white.withValues(alpha: 0.20);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        // 半透明圆角卡片（不使用 BackdropFilter，避免每帧模糊带来的开销）
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x26000000), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionTitle(Icons.calendar_month_rounded, s.weatherForecast3),
          const SizedBox(height: 10),
          ..._forecastRows(wc, s),
          const SizedBox(height: 12),
          // 查看近 15 日天气
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showDaily15Sheet(context),
              icon: const Icon(Icons.date_range_rounded, size: 16),
              label: Text(s.weatherDaily15, style: ts(12.5, w: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // 业余无线电建议
          _hamCard(wc, s),
          const SizedBox(height: 14),
          _sectionTitle(Icons.tune_rounded, s.weatherDetails),
          const SizedBox(height: 8),
          _details(wc, s),
          const SizedBox(height: 10),
          Center(
            child: Text(s.weatherPowered,
                style: ts(9.5, c: Colors.white.withValues(alpha: 0.6))),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData ic, String text) => Row(children: [
        Icon(ic, size: 14, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 6),
        Text(text,
            style: ts(12.5, w: FontWeight.w800, c: Colors.white)
                .copyWith(shadows: _kTextShadow)),
      ]);

  /// 三天预报行（日期 / 图标 / 最低温 / 温度进度条 / 最高温）
  List<Widget> _forecastRows(WeatherCenter wc, AppLocalizations s) {
    if (wc.daily.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
              wc.loading ? s.weatherPanelSub : s.weatherUnavail,
              style: ts(11.5, c: Colors.white.withValues(alpha: 0.7))),
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
      out.add(_dailyRow(i, list[i], lo, hi, s));
      if (i != list.length - 1) out.add(const SizedBox(height: 9));
    }
    return out;
  }

  Widget _dailyRow(
      int i, WeatherDaily d, int lo, int hi, AppLocalizations s) {
    return Row(children: [
      SizedBox(
        width: 54,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_dayLabel(i, d.date, s),
                style: ts(12, w: FontWeight.w700, c: Colors.white)),
            Text(d.date == null ? '' : _md(d.date!),
                style: ts(9, c: Colors.white.withValues(alpha: 0.6))),
          ],
        ),
      ),
      Icon(d.iconData, size: 20, color: Colors.white.withValues(alpha: 0.92)),
      const SizedBox(width: 4),
      SizedBox(
        width: 30,
        child: Text('${d.minV}°',
            textAlign: TextAlign.right,
            style: ts(11.5, c: Colors.white.withValues(alpha: 0.8))),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: SizedBox(
          height: 7,
          child: CustomPaint(
            painter: _TempBarPainter(
              min: d.minV,
              max: d.maxV,
              lo: lo,
              hi: hi,
              track: Colors.white.withValues(alpha: 0.22),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 30,
        child: Text('${d.maxV}°',
            style: ts(12.5, w: FontWeight.w800, c: Colors.white)),
      ),
    ]);
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.rss_feed_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(s.hamTitle,
                style: ts(13, w: FontWeight.w800, c: Colors.white)
                    .copyWith(shadows: _kTextShadow)),
          ]),
          const SizedBox(height: 9),
          if (all.isEmpty)
            Text(s.hamNoData,
                style: ts(11.5,
                    c: Colors.white.withValues(alpha: 0.85), h: 1.5))
          else
            for (var i = 0; i < shown.length; i++) ...[
              _tipRow(shown[i], s),
              if (i != shown.length - 1) const SizedBox(height: 9),
            ],
          if (showToggle) ...[
            const SizedBox(height: 6),
            _tipsToggle(all.length, s),
          ],
        ],
      ),
    );
  }

  Widget _tipRow(_HamTip tip, AppLocalizations s) {
    final danger = tip.level == _TipLevel.danger;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      decoration: BoxDecoration(
        color: danger
            ? tip.color.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 34,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: tip.color.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Icon(tip.icon, size: 15, color: tip.color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: tip.color.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(5),
                    border:
                        Border.all(color: tip.color.withValues(alpha: 0.55)),
                  ),
                  child: Text(_levelLabel(tip.level, s),
                      style: ts(8.5, w: FontWeight.w800, c: Colors.white)),
                ),
                const SizedBox(height: 4),
                Text(tip.text,
                    style: ts(11.5,
                            c: Colors.white.withValues(alpha: 0.94), h: 1.5)
                        .copyWith(shadows: _kTextShadow)),
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_tipsExpanded ? s.hamLess : s.hamMore('$n'),
              style: ts(10.5,
                  w: FontWeight.w700,
                  c: Colors.white.withValues(alpha: 0.9))),
          Icon(_tipsExpanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
              size: 16, color: Colors.white.withValues(alpha: 0.9)),
        ]),
      ),
    );
  }

  /// 详细数据网格
  Widget _details(WeatherCenter wc, AppLocalizations s) {
    final n = wc.now;
    if (n == null) return const SizedBox.shrink();
    final air = wc.air;
    final d0 = wc.daily.isNotEmpty ? wc.daily.first : null;
    return Column(children: [
      Row(children: [
        _miniStat(s.weatherHumidity, '${n.humidity}%',
            Icons.water_drop_outlined),
        const SizedBox(width: 8),
        _miniStat(s.weatherDew, '${n.dew}°', Icons.device_thermostat_rounded),
        const SizedBox(width: 8),
        _miniStat(s.weatherCloud, '${n.cloud}%', Icons.cloud_outlined),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _miniStat(s.weatherWindDir, n.windDir, Icons.explore_outlined),
        const SizedBox(width: 8),
        _miniStat(s.weatherWindScale, n.windScale, Icons.air),
        const SizedBox(width: 8),
        _miniStat(s.weatherWindSpeed, '${n.windSpeed} km/h', Icons.speed_rounded),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _miniStat(s.weatherPressure, '${n.pressure} hPa',
            Icons.compress_rounded),
        const SizedBox(width: 8),
        _miniStat(s.weatherVis, '${n.vis} km', Icons.visibility_outlined),
        const SizedBox(width: 8),
        _miniStat(s.weatherPrecip, '${n.precip} mm', Icons.opacity_rounded),
      ]),
      if (air != null && air.aqiValue >= 0) ...[
        const SizedBox(height: 8),
        Row(children: [
          _miniStat('PM2.5', air.pm2p5, Icons.blur_on_rounded),
          const SizedBox(width: 8),
          _miniStat('PM10', air.pm10, Icons.blur_on_rounded),
          const SizedBox(width: 8),
          _miniStat(s.weatherAQIPrimary,
              air.primary.isEmpty ? '—' : air.primary, Icons.science_outlined),
        ]),
      ],
      if (d0 != null) ...[
        const SizedBox(height: 8),
        Row(children: [
          _miniStat(s.weatherSunrise, d0.sunrise, Icons.wb_twilight_rounded),
          const SizedBox(width: 8),
          _miniStat(s.weatherSunset, d0.sunset, Icons.nights_stay_rounded),
          const SizedBox(width: 8),
          _miniStat(s.weatherUV, d0.uvIndex, Icons.wb_sunny_rounded),
        ]),
      ],
    ]);
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(13, w: FontWeight.w800, c: Colors.white)),
          const SizedBox(height: 1),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 10, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(width: 3),
            Flexible(
              child: Text(label,
                  style: ts(9, c: Colors.white.withValues(alpha: 0.7)),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ]),
      ),
    );
  }
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
                    child: CustomPaint(
                      key: ValueKey<int>(kind.index),
                      painter: _FxPainter(
                        kind: kind,
                        anim: _ac,
                        dark: dark,
                        intensity: intensity,
                      ),
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
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      itemCount: list.length,
      separatorBuilder: (_, _) =>
          Divider(height: 14, color: Colors.white.withValues(alpha: 0.16)),
      itemBuilder: (context, i) {
        final d = list[i];
        return Row(children: [
          SizedBox(
            width: 74,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dayLabel(i, d.date, s),
                    style: ts(12, w: FontWeight.w700, c: Colors.white)),
                Text(d.date == null ? '' : _md(d.date!),
                    style: ts(9.5, c: Colors.white.withValues(alpha: 0.65))),
              ],
            ),
          ),
          Icon(d.iconData, size: 19, color: Colors.white.withValues(alpha: 0.92)),
          const SizedBox(width: 6),
          SizedBox(
            width: 30,
            child: Text('${d.minV}°',
                textAlign: TextAlign.right,
                style: ts(11.5, c: Colors.white.withValues(alpha: 0.8))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 7,
              child: CustomPaint(
                painter: _TempBarPainter(
                  min: d.minV,
                  max: d.maxV,
                  lo: lo,
                  hi: hi,
                  track: Colors.white.withValues(alpha: 0.22),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text('${d.maxV}°',
                style: ts(12.5, w: FontWeight.w800, c: Colors.white)),
          ),
          SizedBox(
            width: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(d.textDay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(9.5,
                        c: Colors.white.withValues(alpha: 0.8))),
                Text('${d.precip}mm',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(9, c: Colors.white.withValues(alpha: 0.6))),
              ],
            ),
          ),
        ]);
      },
    );
  }
}
