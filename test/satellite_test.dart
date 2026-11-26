import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/sat_transponders.dart';
import 'package:aprslocus/satellite.dart';

/// 一个真实 TLE（ISS，2026-11-21 历元）。放在这里当固定样本：过境时间可以由
/// 它复算，不会因为今天抓的是哪份星历而漂。
const _issL1 =
    '1 25544U 98067A   26325.78470666  .00010099  00000+0  18759-3 0  9993';
const _issL2 =
    '2 25544  51.6319 240.1895 0007379  51.3703 308.7945 15.49538290596182';

Tle _iss() => Tle.parse('ISS (ZARYA)', _issL1, _issL2)!;

void main() {
  group('TLE 解析', () {
    test('三行一组，坏条跳过', () {
      final text = '''
ISS (ZARYA)
$_issL1
$_issL2

BROKEN SAT
not a tle line
nor this one

SO-50
1 27607U 02058C   26325.58903017  .00000096  00000+0  19903-3 0  9991
2 27607  64.5550 227.8923 0017966  28.5340 331.7277 14.71937787259277
''';
      final list = Tle.parseList(text);
      expect(list.length, 2);
      expect(list.first.name, 'ISS (ZARYA)');
      expect(list.last.name, 'SO-50');
    });

    test('历元与轨道根数', () {
      final t = _iss();
      expect(t.epoch.year, 2026);
      expect(t.epoch.month, 11);
      expect(t.epoch.day, 21);
      expect(t.inclinationDeg, closeTo(51.6319, 1e-4));
      expect(t.meanMotion, closeTo(15.49538290, 1e-6));
      expect(t.periodMinutes, closeTo(92.93, 0.1));
      expect(t.eccentricity, closeTo(0.0007379, 1e-7));
    });
  });

  group('星下点', () {
    test('高度在低轨范围内，纬度不超过倾角', () {
      final t = _iss();
      for (var i = 0; i < 12; i++) {
        final at = t.epoch.add(Duration(minutes: 7 * i));
        final p = subPoint(t, at);
        expect(p.altKm, greaterThan(350));
        expect(p.altKm, lessThan(500));
        expect(p.lat.abs(), lessThanOrEqualTo(t.inclinationDeg + 0.5));
        expect(p.lng.abs(), lessThanOrEqualTo(180));
      }
    });
  });

  group('过境', () {
    test('广州 24 小时内有一次，顺序与时长合理', () {
      final t = _iss();
      final p = nextPass(t, 23.13, 113.26,
          from: t.epoch.add(const Duration(hours: 1)));
      expect(p, isNotNull);
      expect(p!.aos.isBefore(p.tca), isTrue);
      expect(p.tca.isBefore(p.los), isTrue);
      expect(p.duration.inSeconds, greaterThan(60));
      expect(p.duration.inSeconds, lessThan(15 * 60));
      expect(p.maxElevation, greaterThanOrEqualTo(0));
      expect(p.maxElevation, lessThanOrEqualTo(90));
    });

    test('三天内不止一次，且按时间排开', () {
      final t = _iss();
      final from = t.epoch.add(const Duration(hours: 1));
      final list = passesWithin(t, 23.13, 113.26, from: from);
      expect(list.length, greaterThanOrEqualTo(2));
      for (var i = 1; i < list.length; i++) {
        expect(list[i].aos.isAfter(list[i - 1].los), isTrue);
      }
      // 第一个就是「下一次」，两处口径必须一致
      final one = nextPass(t, 23.13, 113.26, from: from)!;
      expect(list.first.aos, one.aos);
      expect(list.first.tca, one.tca);
    });

    test('地平高度在场内高于阈值', () {
      final t = _iss();
      final from = t.epoch.add(const Duration(hours: 1));
      final p = nextPass(t, 23.13, 113.26, from: from, minElevationDeg: 5);
      expect(p, isNotNull);
      expect(elevationDeg(t, 23.13, 113.26, p!.tca),
          greaterThanOrEqualTo(5));
    });
  });

  group('罗盘经过线', () {
    test('passTrack 覆盖 AOS→LOS，首尾与过境一致', () {
      final t = _iss();
      final p = nextPass(t, 23.13, 113.26,
          from: t.epoch.add(const Duration(hours: 1)))!;
      final track = passTrack(t, 23.13, 113.26, p);
      expect(track.length, greaterThan(5));
      expect(track.first.at, p.aos);
      expect(track.last.at, p.los);
      for (final q in track) {
        expect(q.azimuthDeg, inInclusiveRange(0, 360));
        // 过境窗口按 0° 地平算，端点采样可能略低于 0°。
        expect(q.elevationDeg, greaterThanOrEqualTo(-2));
      }
      expect(
        track
            .map((q) => q.elevationDeg)
            .reduce((a, b) => a > b ? a : b),
        greaterThan(0),
      );
    });
  });

  group('转发器预设', () {
    test('按卫星名匹配，APRS 星给 145.825', () {
      final iss = transpondersFor('ISS (ZARYA)');
      expect(iss.any((t) => t.isAprs && t.upMhz == 145.825), isTrue);
      expect(iss.any((t) => t.downMhz == 145.800), isTrue);
      expect(transpondersFor('SO-50').first.tone, '67.0');
      expect(transpondersFor('PO-101').first.tone, '141.3');
      expect(transpondersFor('CAS-4A').first.invert, isTrue);
      expect(transpondersFor('NOT A SAT'), isEmpty);
      expect(transpondersFor(''), isEmpty);
    });
  });

  group('过境声明', () {
    test('名字归一', () {
      expect(normalizeSatName('ISS (ZARYA)'), 'ISS');
      expect(normalizeSatName(' so-50 '), 'SO-50');
      expect(normalizeSatName('IO-117'), 'IO-117');
      expect(normalizeSatName('ABCDEFGHIJKLMNOP'), 'ABCDEFGHIJKL');
      expect(normalizeSatName('  '), '');
    });

    test('编码与读回', () {
      final at = DateTime.utc(2026, 11, 22, 2, 34);
      final q = SatQso.of('IO-117', at)!;
      expect(q.encode(), 'OAS:IO-117:0234Z');
      expect(q.label, '02:34Z');
      final back = SatQso.decode('HR=72 OAF:145.500:FM OAS:IO-117:0234Z');
      expect(back, isNotNull);
      expect(back!.name, 'IO-117');
      expect(back.hhmm, '0234');
    });

    test('不合格式的不认', () {
      expect(SatQso.decode('OAS:IO-117'), isNull);
      expect(SatQso.decode('OAS::0234Z'), isNull);
      expect(SatQso.decode('OAS:IO-117:2461Z'), isNull);
      expect(SatQso.decode('没有标记'), isNull);
      expect(SatQso.decode(null), isNull);
    });
  });

  group('观测与多普勒', () {
    test('lookAt 的仰角与 elevationDeg 一致，方位/距离/变化率合理', () {
      final t = _iss();
      final at = t.epoch.add(const Duration(hours: 1));
      const lat = 23.13;
      const lng = 113.26;
      final look = lookAt(t, lat, lng, at);
      expect(look.elevationDeg, closeTo(elevationDeg(t, lat, lng, at), 1e-6));
      expect(look.azimuthDeg, inInclusiveRange(0, 360));
      expect(look.rangeKm, greaterThan(300));
      expect(look.rangeKm, lessThan(20000));
      expect(look.rangeRateKmS.abs(), lessThan(8)); // 低轨上限约 7.5 km/s
    });

    test('多普勒符号：接近为正、远离为负', () {
      final approaching = dopplerHz(145.825, -7.0);
      final receding = dopplerHz(145.825, 7.0);
      expect(approaching, greaterThan(0));
      expect(receding, lessThan(0));
      expect(approaching, closeTo(3404, 20));
      expect(receding, closeTo(-3404, 20));
    });
  });
}
