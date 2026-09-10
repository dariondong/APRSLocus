import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/aprs_parse.dart';

/// 期望值取自 aprslib 参考实现（APRS101 规范实现）在**真实 APRS-IS 报文**上的结果。
/// 覆盖：非压缩、压缩、带时间戳（/ @）、Mic-E（纬度编码在目的呼号）、
/// 航向/速度、高度、位置模糊、备注清理。
class _C {
  final String info, dest;
  final double lat, lng;
  final String symbol, table;
  final double? course, speed, alt;
  final String? comment;
  const _C(this.info, this.dest, this.lat, this.lng, this.symbol, this.table,
      {this.course, this.speed, this.alt, this.comment});
}

const _cases = <_C>[
  // 非压缩：符号表 'D'、高度 0、备注中 /A= 不得吞掉 "70cm"
  _C('!5000.00ND00300.00W&/A=00000070cm MMDVM Voice', 'APDG03', 50.0, -3.0,
      '&', 'D', alt: 0.0, comment: '70cm MMDVM Voice'),
  _C('!5308.04N/02311.99EV https://github.com/SP3KON/ESP32-HAM-CLOC', 'APRS',
      53.134, 23.199833, 'V', '/',
      comment: 'https://github.com/SP3KON/ESP32-HAM-CLOC'),
  // 压缩：符号表 'L'（非 / \），Base91 为 ASCII-33
  _C('=L9L^{L:/z# !GLoRa APRS Remote DIGI', 'APLRG1', 41.572148, -8.775452, '#',
      'L', comment: 'LoRa APRS Remote DIGI'),
  // 压缩 + 海拔字段（csT 中 ctype&0x18==0x10）
  _C('=/4g#nRK4_>G_Q', 'APLRT1', 50.890624, 15.705056, '>', '/', alt: 345.46),
  // "/" 带时间戳 + 航向/速度 + 高度
  _C('/100452z2647.57S/02749.70E>151/052/A=004801 37C 1Mv', 'APCLEY', -26.792833,
      27.828333, '>', '/', course: 151, speed: 96.304, alt: 1463.34,
      comment: '37C 1Mv'),
  // "/" 带时间戳 + 压缩
  _C('/100452z/7/[rSd!d-7xQ YO2MAS HOME2', 'APE32I', 46.159845, 20.739482, '-',
      '/', alt: 19.8, comment: 'YO2MAS HOME2'),
  _C('@100452I4146.78N/11210.74W#Riverside Gateway', 'APMI06', 41.779667,
      -112.179, '#', '/', comment: 'Riverside Gateway'),
  // "@" 带时间戳 + 航向/速度（000 表示无速度）
  _C('@100430z2220.00N/11411.00E_100/009g...t...b10230 Hong Kong', 'APRS',
      22.333333, 114.183333, '_', '/', course: 100, speed: 16.668,
      comment: 'g...t...b10230 Hong Kong'),
  // Mic-E：Georgia Tech
  _C("'p3ol \x1c#1]Georgia Tech ARC -- NET 9PM Thursdays=", 'SSTV5U', 33.7758,
      -84.3972, '#', '1', comment: 'Georgia Tech ARC -- NET 9PM Thursdays='),
  _C('`h(|l \x1c-/12.61V"5U}', 'T3PS5V', 43.0593, -76.216, '-', '/',
      comment: '12.61V"5U}'),
  // Mic-E + 航向/速度
  _C('`-6G HQ>/]"5H}145.500MHz Adam=', 'UTPX60', 54.1433, 17.4405, '>', '/',
      speed: 81.5, course: 53),
];

void main() {
  test('位置解析与参考实现一致', () {
    for (final e in _cases) {
      final p = parseAprsPosition(e.info, dest: e.dest);
      expect(p, isNotNull, reason: '解析失败：${e.info}');

      expect(p!.lat, closeTo(e.lat, 0.0005), reason: 'lat <<< ${e.info}');
      expect(p.lng, closeTo(e.lng, 0.0005), reason: 'lng <<< ${e.info}');
      expect(p.symbol, e.symbol, reason: 'symbol <<< ${e.info}');
      expect(p.symbolTable, e.table, reason: 'table <<< ${e.info}');
      if (e.course != null) {
        expect(p.course, closeTo(e.course!, 0.51), reason: 'course <<< ${e.info}');
      }
      if (e.speed != null) {
        expect(p.speed, closeTo(e.speed!, 0.51), reason: 'speed <<< ${e.info}');
      }
      if (e.alt != null) {
        expect(p.alt, closeTo(e.alt!, 0.51), reason: 'alt <<< ${e.info}');
      }
      if (e.comment != null) {
        expect(p.comment, e.comment, reason: 'comment <<< ${e.info}');
      }
      // 航向/速度必须已从备注剥离，不能残留在备注里
      expect(RegExp(r'(^|\s)\d{3}/\d{3}(\s|$)').hasMatch(p.comment ?? ''),
          isFalse,
          reason: '备注残留航向/速度 <<< ${e.info}');
    }
  });

  test('非法/不支持帧应返回 null 而不是乱解析', () {
    expect(parseAprsPosition(''), isNull);
    expect(parseAprsPosition('>status text'), isNull);
    expect(parseAprsPosition(':BLAH     :hello'), isNull);
    // Mic-E 缺少目的呼号：无法取到纬度编码，应放弃
    expect(parseAprsPosition("'p3ol \x1c#1]Georgia"), isNull);
  });
}
