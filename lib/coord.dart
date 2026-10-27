import 'dart:math' as math;

/// 经度规整到 [-180,180)。
///
/// 底图的 `pan` 是一个**不封顶**的像素偏移：拖动可以一直拖下去，瓦片按取模
/// 换列，于是「屏幕点 → 经纬度」反算出来的经度也会一路累加 —— 拖过一整圈
/// 之后读数就成了 181°、360°、720°（用户报的「用鼠标往一个方向划拉地图，
/// 经度值会一直累加」）。所有落到界面上的经度都必须过这一道。
///
/// 只给**显示 / 落点**用：视口反算 [viewBounds] 不能先用它，否则跨 180° 的
/// 视口会把两侧角点折到同一侧，算出一个宽度为负的范围。
///
/// 放在 coord.dart（纯 Dart，不依赖 `dart:ui`）而不是 map_math：显示层的
/// [fmtLng] 也要用它，而那个文件要能在纯 Dart 测试里跑。
double wrapLng(double lng) {
  if (lng >= -180 && lng < 180) return lng;
  var v = (lng + 180) % 360;
  if (v < 0) v += 360;
  return v - 180;
}

/// WGS-84 ⇄ GCJ-02（火星坐标）转换
/// 国内地图瓦片（高德/腾讯）使用 GCJ-02 坐标系，
/// APRS 数据为 WGS-84，需要转换才能让标记准确落位。
class Gcj {
  Gcj._();

  static const double _a = 6378245.0;
  static const double _ee = 0.00669342162296594323;

  static bool _outOfChina(double lat, double lng) =>
      lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271;

  static double _transformLat(double x, double y) {
    var ret = -100.0 +
        2.0 * x +
        3.0 * y +
        0.2 * y * y +
        0.1 * x * y +
        0.2 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) *
        2.0 /
        3.0;
    ret += (20.0 * math.sin(y * math.pi) +
            40.0 * math.sin(y / 3.0 * math.pi)) *
        2.0 /
        3.0;
    ret += (160.0 * math.sin(y / 12.0 * math.pi) +
            320 * math.sin(y * math.pi / 30.0)) *
        2.0 /
        3.0;
    return ret;
  }

  static double _transformLng(double x, double y) {
    var ret = 300.0 +
        x +
        2.0 * y +
        0.1 * x * x +
        0.1 * x * y +
        0.1 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) *
        2.0 /
        3.0;
    ret += (20.0 * math.sin(x * math.pi) +
            40.0 * math.sin(x / 3.0 * math.pi)) *
        2.0 /
        3.0;
    ret += (150.0 * math.sin(x / 12.0 * math.pi) +
            300.0 * math.sin(x / 30.0 * math.pi)) *
        2.0 /
        3.0;
    return ret;
  }

  /// WGS-84 → GCJ-02，返回 (lat, lng)
  static (double, double) wgsToGcj(double lat, double lng) {
    if (_outOfChina(lat, lng)) return (lat, lng);
    var dLat = _transformLat(lng - 105.0, lat - 35.0);
    var dLng = _transformLng(lng - 105.0, lat - 35.0);
    final radLat = lat / 180.0 * math.pi;
    var magic = math.sin(radLat);
    magic = 1 - _ee * magic * magic;
    final sqrtMagic = math.sqrt(magic);
    dLat = (dLat * 180.0) /
        ((_a * (1 - _ee)) / (magic * sqrtMagic) * math.pi);
    dLng = (dLng * 180.0) / (_a / sqrtMagic * math.cos(radLat) * math.pi);
    return (lat + dLat, lng + dLng);
  }

  /// GCJ-02 → WGS-84（近似反解）
  static (double, double) gcjToWgs(double lat, double lng) {
    if (_outOfChina(lat, lng)) return (lat, lng);
    final g = wgsToGcj(lat, lng);
    return (2 * lat - g.$1, 2 * lng - g.$2);
  }
}

/// WGS-84 ⇄ BD-09（百度坐标）：先 WGS→GCJ，再在 GCJ 上做一次极坐标偏移。
class Bd09 {
  Bd09._();

  static const double _xPi = 3.14159265358979324 * 3000.0 / 180.0;

  /// WGS-84 → BD-09，返回 (lat, lng)
  static (double, double) wgsToBd09(double lat, double lng) {
    final g = Gcj.wgsToGcj(lat, lng);
    return gcjToBd09(g.$1, g.$2);
  }

  /// BD-09 → WGS-84
  static (double, double) bd09ToWgs(double lat, double lng) {
    final g = bd09ToGcj(lat, lng);
    return Gcj.gcjToWgs(g.$1, g.$2);
  }

  /// GCJ-02 → BD-09
  static (double, double) gcjToBd09(double lat, double lng) {
    final x = lng;
    final y = lat;
    final z = math.sqrt(x * x + y * y) + 0.00002 * math.sin(y * _xPi);
    final theta = math.atan2(y, x) + 0.000003 * math.cos(x * _xPi);
    return (
      z * math.sin(theta) + 0.006,
      z * math.cos(theta) + 0.0065,
    );
  }

  /// BD-09 → GCJ-02
  static (double, double) bd09ToGcj(double lat, double lng) {
    final x = lng - 0.0065;
    final y = lat - 0.006;
    final z = math.sqrt(x * x + y * y) - 0.00002 * math.sin(y * _xPi);
    final theta = math.atan2(y, x) - 0.000003 * math.cos(x * _xPi);
    return (
      z * math.sin(theta),
      z * math.cos(theta),
    );
  }
}
