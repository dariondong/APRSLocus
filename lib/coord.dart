import 'dart:math' as math;

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
