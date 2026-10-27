import 'coord.dart';

/// ─── 经纬度的显示格式 ───
///
/// 只影响**给人看**的字符串：地图底部的坐标读数、我的位置面板、台站详情、
/// 沉浸地图角落、地图选点提示、地图中心那一圈。落库、报文（APRS 的
/// `ddmm.mm`）、地图计算、距离判断统统用原始的十进制度 —— 换个显示格式
/// 不能改变任何计算。
///
/// 偏好里存的就是 [coordFormatName] 的短名字（'dec' / 'dm' / 'dms'），
/// 与 [coordFormatOf] 同一套口径；认不出的值一律回落十进制度。
enum CoordFormat {
  /// 十进制度：`39.90420°N`
  dec,

  /// 度分：`39°54.252′N`
  dm,

  /// 度分秒：`39°54′15″N`
  dms,
}

/// 偏好字符串 → 格式（认不出 = 十进制度）
CoordFormat coordFormatOf(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'dm':
      return CoordFormat.dm;
    case 'dms':
      return CoordFormat.dms;
  }
  return CoordFormat.dec;
}

/// 格式 → 偏好字符串
String coordFormatName(CoordFormat f) {
  switch (f) {
    case CoordFormat.dm:
      return 'dm';
    case CoordFormat.dms:
      return 'dms';
    case CoordFormat.dec:
      return 'dec';
  }
}

/// 纬度 → 人读文字（带 N/S）。
String fmtLat(double lat, CoordFormat f) =>
    _fmt(lat, f, lat < 0 ? 'S' : 'N');

/// 经度 → 人读文字（带 E/W）。经度先收进 [-180,180)（见 [wrapLng]）。
String fmtLng(double lng, CoordFormat f) {
  final v = wrapLng(lng);
  return _fmt(v, f, v < 0 ? 'W' : 'E');
}

/// 一对经纬度：`39.90420°N  116.40740°E`
String fmtLatLng(double lat, double lng, CoordFormat f) =>
    '${fmtLat(lat, f)}  ${fmtLng(lng, f)}';

/// 一位十进制 → 度 / 度分 / 度分秒。
///
/// 进位是这里唯一容易错的地方：59.9996′ 舍入成 `60.000′` 而不是 `59.000′`，
/// 秒同理（59.6″ → `60″` → 进到下一分）。所以先把值拆成度、分、秒，再从最小
/// 单位往上收，而不是在三处各写一遍进位。
String _fmt(double v, CoordFormat f, String hemi) {
  final a = v.abs();
  switch (f) {
    case CoordFormat.dec:
      return '${a.toStringAsFixed(5)}°$hemi';
    case CoordFormat.dm:
      var d = a.floor();
      // 分保留三位（≈ 2 米），比度分秒短，也不会长得像十进制度
      var m = double.parse(((a - d) * 60).toStringAsFixed(3));
      if (m >= 60) {
        d += 1;
        m = 0;
      }
      return '$d°${m.toStringAsFixed(3)}′$hemi';
    case CoordFormat.dms:
      var d = a.floor();
      final mf = (a - d) * 60;
      var m = mf.floor();
      var s = ((mf - m) * 60).round();
      if (s >= 60) {
        s -= 60;
        m += 1;
      }
      if (m >= 60) {
        m -= 60;
        d += 1;
      }
      return '$d°$m′$s″$hemi';
  }
}
