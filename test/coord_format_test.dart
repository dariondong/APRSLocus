/// 经纬度显示格式（十进制度 / 度分 / 度分秒）的回归测试。
///
/// 用户要求「经纬度可以按度分、度分秒的格式显示」。这是纯显示层的东西，
/// 但两个地方最容易出错、而且**编译与 analyze 都不会报**：
///   * 进位：59.9996′ 必须变成下一度的 `0.000′`，不能显示成 `60.000′`；
///     秒 59.6″ 必须进到下一分（59″ → `60″` 同理）。
///   * 半球：南纬 / 西经要带 S / W，符号取自原始值而不是绝对值；经度先收进
///     [-180,180)（拖动地图越过一圈时反算出来的经度会累加成 360、720）。
/// 另外钉住「换格式不换数据」：格式化函数只读不写，十进制度档仍然是原来
/// 那串 `toStringAsFixed(5)`。
library;

import 'package:aprslocus/coord.dart';
import 'package:aprslocus/coord_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('偏好字符串 ↔ 格式，认不出回落十进制度', () {
    expect(coordFormatOf('dm'), CoordFormat.dm);
    expect(coordFormatOf(' DMS '), CoordFormat.dms);
    expect(coordFormatOf('dec'), CoordFormat.dec);
    expect(coordFormatOf(''), CoordFormat.dec);
    expect(coordFormatOf(null), CoordFormat.dec);
    expect(coordFormatOf('rubbish'), CoordFormat.dec);
    expect(coordFormatName(CoordFormat.dec), 'dec');
    expect(coordFormatName(CoordFormat.dm), 'dm');
    expect(coordFormatName(CoordFormat.dms), 'dms');
  });

  test('十进制度：五位小数 + 半球', () {
    expect(fmtLat(39.9042, CoordFormat.dec), '39.90420°N');
    expect(fmtLat(-33.8688, CoordFormat.dec), '33.86880°S');
    expect(fmtLng(116.4074, CoordFormat.dec), '116.40740°E');
    expect(fmtLng(-122.4194, CoordFormat.dec), '122.41940°W');
  });

  test('度分：分保留三位，59.9996′ 要进位到下一度', () {
    expect(fmtLat(39.9042, CoordFormat.dm), '39°54.252′N');
    expect(fmtLng(116.4074, CoordFormat.dm), '116°24.444′E');
    // 0.999999° = 59.99994′ → 舍入成 60.000′，必须进到 1°0.000′
    expect(fmtLat(0.999999, CoordFormat.dm), '1°00.000′N');
    // 分的整数部分补到两位：位数一变整行宽度就跳
    expect(fmtLat(39.0817, CoordFormat.dm), '39°04.902′N');
  });

  test('度分秒：秒进位到分、分进位到度', () {
    expect(fmtLat(39.9042, CoordFormat.dms), '39°54′15″N');
    expect(fmtLng(116.4074, CoordFormat.dms), '116°24′27″E');
    // 59.9999″ → 60″ → 进到 1′
    expect(fmtLat(0.01666663, CoordFormat.dms), '0°01′00″N');
  });

  test('度分秒补位：分与秒不足两位补 0', () {
    // 39°05′04″：分 5、秒 4 都要补成两位
    expect(fmtLat(39.0844444, CoordFormat.dms), '39°05′04″N');
    expect(fmtLat(39.0169444, CoordFormat.dms), '39°01′01″N');
    // 进位后也不能掉成一位
    expect(fmtLat(39.9999999, CoordFormat.dms), '40°00′00″N');
  });

  test('半球取自原始值：南纬 / 西经', () {
    expect(fmtLat(-0.5, CoordFormat.dms), '0°30′00″S');
    expect(fmtLng(-0.5, CoordFormat.dms), '0°30′00″W');
  });

  test('经度先规整：越圈累加出来的值显示在 ±180 内', () {
    expect(wrapLng(181.5), closeTo(-178.5, 1e-9));
    expect(wrapLng(720.0), closeTo(0.0, 1e-9));
    expect(wrapLng(-181.5), closeTo(178.5, 1e-9));
    expect(wrapLng(180.0), closeTo(-180.0, 1e-9));
    expect(fmtLng(360 + 116.4074, CoordFormat.dec), '116.40740°E');
  });

  test('一对经纬度：两段用两个空格隔开', () {
    expect(fmtLatLng(39.9042, 116.4074, CoordFormat.dec),
        '39.90420°N  116.40740°E');
  });
}
