import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'state.dart';

/// ─── 天气组件（和风天气 QWeather）───
/// 数据：和风「实时天气」+「城市定位」；顶栏默认显示 图标+温度，点击弹浮动面板。
/// 配置见 https://dev.qweather.com/docs
const String kQwHost = 'pf4ewvjfqj.re.qweatherapi.com';
const String kQwGeoHost = 'geoapi.qweather.com';
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
  String? error;
  double? lat, lng;
  bool _busy = false;

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
    if (_busy) return;
    if (!force && _withinTtl(lat, lng)) return;
    _busy = true;
    loading = true;
    error = null;
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
          obsTime: n.obsTime,
          city: city ?? n.city,
        );
        updated = DateTime.now();
      } else {
        error = '天气数据获取失败';
      }
    } catch (_) {
      error = '天气服务连接失败';
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
      final url =
          'https://$kQwGeoHost/v2/city/lookup?location=$lng,$lat&key=$kQwKey';
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
      return d is Map ? d : null;
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
    final hasPos =
        state.myHasFix && state.myLat != null && state.myLng != null;
    if (hasPos) {
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

/// 打开天气浮动面板（底部弹层）：大图标 + 温度 + 天气现象 + 详情 + 手动刷新
Future<void> showWeatherPanel(BuildContext context, AppState state) async {
  final hasPos = state.myHasFix && state.myLat != null && state.myLng != null;
  if (hasPos) {
    WeatherCenter.instance.load(state.myLat!, state.myLng!);
  }
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _WeatherPanel(state: state, hasPos: hasPos),
  );
}

class _WeatherPanel extends StatelessWidget {
  final AppState state;
  final bool hasPos;
  const _WeatherPanel({required this.state, required this.hasPos});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: ValueListenableBuilder<int>(
          valueListenable: WeatherCenter.instance.version,
          builder: (context, _, _) {
            final wc = WeatherCenter.instance;
            final col = C.cyan;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行
                Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: C.cyanBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.wb_cloudy_rounded,
                        color: Color(0xFF0E7490), size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('天气',
                            style: ts(16, w: FontWeight.w800)),
                        Text('和风天气 · 当前位置实时天气',
                            style: ts(10.5, c: C.grey)),
                      ],
                    ),
                  ),
                  if (hasPos)
                    GestureDetector(
                    onTap: () {
                      WeatherCenter.instance
                          .load(state.myLat!, state.myLng!, force: true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: C.cyanBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.refresh_rounded,
                            size: 14, color: col),
                        const SizedBox(width: 3),
                        Text('刷新', style: ts(11, c: col, w: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                if (!hasPos)
                  _emptyHint('暂无定位：请在“我的电台”开启位置服务后查看天气')
                else if (wc.loading && !wc.hasData)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                  )
                else if (wc.now == null)
                  _emptyHint(wc.error ?? '天气服务暂时不可用')
                else ...[
                  // 主体：城市 + 大图标 + 温度 + 现象
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Row(children: [
                      Icon(Icons.place_rounded, size: 16, color: C.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          wc.now!.city ?? '当前位置',
                          style: ts(13, c: C.slate, w: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${wc.now!.text} · 观测 ${wc.now!.obsTimeShort}',
                        style: ts(10.5, c: C.grey),
                      ),
                    ]),
                  ),
                  Row(
                    children: [
                      Icon(wc.now!.iconData, size: 58, color: col),
                      const SizedBox(width: 14),
                      Text('${wc.now!.tempDisplay}°',
                          style: ts(44, w: FontWeight.w800)),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text('体感 ${wc.now!.feelsLike}°',
                            style: ts(12, c: C.slate, w: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 详情格
                  Row(children: [
                    _cell('湿度', '${wc.now!.humidity}%'),
                    _cell('风向', wc.now!.windDir),
                    _cell('风力', '${wc.now!.windScale} 级'),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _cell('风速', '${wc.now!.windSpeed} km/h'),
                    _cell('气压', '${wc.now!.pressure} hPa'),
                    _cell('能见度', '${wc.now!.vis} km'),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: C.bgSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      const Icon(Icons.opacity_rounded,
                          size: 14, color: Color(0xFF0E7490)),
                      const SizedBox(width: 6),
                      Text('当前降水 ${wc.now!.precip} mm',
                          style: ts(11, c: C.slate, w: FontWeight.w600)),
                      const Spacer(),
                      Text('数据由和风天气提供',
                          style: ts(9.5, c: C.grey)),
                    ]),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _emptyHint(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Column(children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFFC2CAD8), size: 36),
            const SizedBox(height: 10),
            Text(msg, style: ts(12, c: C.grey)),
          ]),
        ),
      );

  Widget _cell(String k, String v) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: C.bgSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(v, style: ts(14, w: FontWeight.w800, c: C.ink)),
          const SizedBox(height: 2),
          Text(k, style: ts(9.5, c: C.grey)),
        ]),
      ),
    );
  }
}
