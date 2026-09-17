import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/app_widget.dart';
import 'package:aprslocus/hf.dart';
import 'package:aprslocus/l10n/app_localizations.dart';
import 'package:aprslocus/weather.dart';

/// 短波传播 / 电离层数据的解析与判定测试。
///
/// 为什么值得测：这份数据是**用正则从 XML 里抠出来**的（Dart 标准库没有 XML
/// 解析器，为一份扁平且稳定的机器生成 XML 引依赖不划算）。正则解析对格式变化
/// 很敏感，而失败方式是**静默显示 "--"** —— 用户只会觉得「怎么没数据」，
/// 不会报错。所以用真实响应做夹具把字段钉住。
void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));

  /// 真实响应夹具（2026-09-17 从 hamqsl.com 抓取，含原始的 \r\r\n）
  String fixture() =>
      File('test/reference/hf_solar_sample.xml').readAsStringSync();

  group('解析真实响应', () {
    test('字段全部抠出来', () {
      final hf = parseHamQsl(fixture());
      expect(hf, isNotNull);
      expect(hf!.sfi, '100');
      expect(hf.aIndex, '9');
      expect(hf.kIndex, '3');
      expect(hf.xray, 'B2.2');
      expect(hf.sunspots, '23');
      expect(hf.solarWind, '508.8');
      expect(hf.geomag, 'UNSETTLD');
      expect(hf.noise, 'S2-S3');
      // 源数据里 muf 是 "NoRpt" —— 应统一成占位符，而不是把 "NoRpt" 显示给用户
      expect(hf.muf, HfNow.none);
      expect(hf.updated, contains('2026'));
    });

    test('逐波段的日/夜条件都解析出来（这是「各个波段的传播信息」）', () {
      final hf = parseHamQsl(fixture())!;
      // 源数据 4 个波段对 × 日/夜 两条 = 8 条 <band>，应归并成 4 个 HfBand
      expect(hf.bands.length, 4);
      final names = hf.bands.map((b) => b.name).toList();
      expect(names, ['80m-40m', '30m-20m', '17m-15m', '12m-10m']);

      final b = hf.band('30m-20m')!;
      expect(b.day, 'Good');
      expect(b.night, 'Good');
      final low = hf.band('80m-40m')!;
      expect(low.day, 'Poor');
      expect(low.night, 'Fair');
    });

    test('波段顺序是低→高（不是字典序，否则 12m 会跑到 80m 前面）', () {
      final hf = parseHamQsl(fixture())!;
      final order = hf.bands.map((b) => b.name).toList();
      expect(order.first, '80m-40m');
      expect(order.last, '12m-10m');
    });

    test('展示名把连字符换成斜杠（80m-40m → 80m/40m）', () {
      final hf = parseHamQsl(fixture())!;
      expect(hf.band('80m-40m')!.label, '80m/40m');
    });

    test('band() 对斜杠写法也认', () {
      final hf = parseHamQsl(fixture())!;
      expect(hf.band('80m/40m'), isNotNull);
      expect(hf.band('80m-40m'), isNotNull);
      expect(hf.band('160m'), isNull);
    });
  });

  group('解析的容错（数据源改格式时不能炸）', () {
    test('空串 → null', () {
      expect(parseHamQsl(''), isNull);
      expect(parseHamQsl('   '), isNull);
    });

    test('不是 solar XML → null', () {
      expect(parseHamQsl('<html><body>503</body></html>'), isNull);
    });

    test('字段缺失 → 退化成 "--"，不抛异常', () {
      final hf = parseHamQsl('<solar><solardata><solarflux>120</solarflux>'
          '</solardata></solar>')!;
      expect(hf.sfi, '120');
      expect(hf.kIndex, HfNow.none);
      expect(hf.geomag, HfNow.none);
      expect(hf.bands, isEmpty);
      // 判定函数在数据缺失时不能崩
      expect(hf.geomagActive, isFalse);
      expect(hf.geomagStorm, isFalse);
      expect(hf.lowSolarFlux, isFalse);
      expect(hf.highNoise, isFalse);
      expect(hf.bestBandAt(DateTime(2026, 9, 17, 12)), isNull);
    });

    test('NoRpt / No Report 都算「无数据」', () {
      final hf = parseHamQsl('<solar><solardata><muf>NoRpt</muf>'
          '<kindexnt>No Report</kindexnt>'
          '<solarflux>  95 </solarflux></solardata></solar>')!;
      expect(hf.muf, HfNow.none);
      // 前后空格要 trim 掉（源数据里字段值是带空格的）
      expect(hf.sfi, '95');
    });

    test('波段只有 day 或只有 night 时不丢整条', () {
      final hf = parseHamQsl('<solar><solardata><calculatedconditions>'
          '<band name="20m" time="day">Good</band>'
          '</calculatedconditions></solardata></solar>')!;
      expect(hf.bands.length, 1);
      expect(hf.bands.first.day, 'Good');
      expect(hf.bands.first.night, HfNow.none);
    });
  });

  group('判定逻辑', () {
    HfNow make({String k = '2', String a = '5', String sfi = '120',
      String geomag = 'QUIET', String noise = 'S1'}) =>
        HfNow(sfi: sfi, aIndex: a, kIndex: k, xray: 'B1', sunspots: '10',
            solarWind: '400', geomag: geomag, noise: noise, muf: HfNow.none,
            bands: const [], updated: '');

    test('地磁活跃：K≥4 或源数据说 UNSETTLD/ACTIVE/STORM', () {
      expect(make(k: '2').geomagActive, isFalse);
      expect(make(k: '4').geomagActive, isTrue);
      expect(make(k: '2', geomag: 'UNSETTLD').geomagActive, isTrue);
      expect(make(k: '2', geomag: 'ACTIVE').geomagActive, isTrue);
    });

    test('地磁暴：K≥5 或 STORM', () {
      expect(make(k: '4').geomagStorm, isFalse);
      expect(make(k: '5').geomagStorm, isTrue);
      expect(make(k: '6').geomagStorm, isTrue);
      expect(make(k: '2', geomag: 'STORM').geomagStorm, isTrue);
    });

    test('太阳活动偏低：SFI<100', () {
      expect(make(sfi: '99').lowSolarFlux, isTrue);
      expect(make(sfi: '100').lowSolarFlux, isFalse);
      // 缺数据时不该判成「偏低」（否则会给出误导性建议）
      expect(make(sfi: HfNow.none).lowSolarFlux, isFalse);
    });

    test('底噪偏高：S3 及以上', () {
      expect(make(noise: 'S2-S3').highNoise, isTrue);
      expect(make(noise: 'S1-S2').highNoise, isFalse);
      expect(make(noise: HfNow.none).highNoise, isFalse);
    });

    test('按本地时段挑最有戏的波段：日间看 day、夜间看 night', () {
      final hf = parseHamQsl(fixture())!;
      // 夹具里 30m-20m 日/夜都是 Good，所以白天与夜里都应挑到它
      expect(hf.bestBandAt(DateTime(2026, 9, 17, 12))!.name, '30m-20m');
      expect(hf.bestBandAt(DateTime(2026, 9, 17, 23))!.name, '30m-20m');
    });

    test('质量映射：Good/Fair/Poor/Band Closed → 枚举', () {
      expect(hfQualityOf('Good'), HfQuality.good);
      expect(hfQualityOf(' fair '), HfQuality.fair);
      expect(hfQualityOf('Poor'), HfQuality.poor);
      expect(hfQualityOf('Band Closed'), HfQuality.closed);
      expect(hfQualityOf('???'), HfQuality.unknown);
    });

    test('质量文字与颜色都不是空/透明', () {
      for (final q in HfQuality.values) {
        expect(hfQualityLabel(q, zh), isNotEmpty);
        expect(hfQualityColor(q).a, 1.0);
      }
      // 好=绿、差=红：色相要拉开，否则用户分不出
      expect(hfQualityColor(HfQuality.good).g,
          greaterThan(hfQualityColor(HfQuality.good).r));
      expect(hfQualityColor(HfQuality.poor).r,
          greaterThan(hfQualityColor(HfQuality.poor).g));
    });
  });

  group('由电离层状态生成建议', () {
    test('没有数据时不产生建议（而不是产生错建议）', () {
      expect(hfTips(null, zh), isEmpty);
    });

    test('地磁暴 → 出「注意」级建议，且排在通联机会之前', () {
      final hf = parseHamQsl(fixture())!;
      final storm = HfNow(
        sfi: hf.sfi, aIndex: '40', kIndex: '6', xray: hf.xray,
        sunspots: hf.sunspots, solarWind: hf.solarWind, geomag: 'STORM',
        noise: hf.noise, muf: hf.muf, bands: hf.bands, updated: hf.updated,
      );
      final tips = hfTips(storm, zh);
      expect(tips, isNotEmpty);
      expect(tips.first.level, TipLevel.warn);
      expect(tips.first.text, zh.hfTipStorm);
    });

    test('太阳活动高 → SFI≥150 出「通联机会」', () {
      final hf = parseHamQsl(fixture())!;
      final high = HfNow(
        sfi: '180', aIndex: '4', kIndex: '1', xray: hf.xray,
        sunspots: hf.sunspots, solarWind: hf.solarWind, geomag: 'QUIET',
        noise: 'S1', muf: hf.muf, bands: hf.bands, updated: hf.updated,
      );
      final tips = hfTips(high, zh);
      expect(tips.any((t) => t.text == zh.hfTipHighSfi), isTrue);
      expect(tips.any((t) => t.level == TipLevel.good), isTrue);
    });

    test('当前时段有「好」波段 → 提示具体波段（把波段信息落到建议上）', () {
      final hf = parseHamQsl(fixture())!;
      final noon = DateTime(2026, 9, 17, 12);
      final tips = hfTips(hf, zh, now: noon);
      // 夹具里 30m-20m 日间是 Good
      expect(tips.any((t) => t.text.contains('30m/20m')), isTrue,
          reason: '应提示当前最有戏的波段，实际：${tips.map((t) => t.text)}');
    });

    test('每个 HamTip 的图标都能映射到组件图标名（否则组件上是兜底图标）', () {
      // 这条护栏跨模块：hf.dart 出的建议会经 app_widget.dart 转成图标名，
      // 再经 WidgetIcons.kt 查资源。任一段没登记就显示成兜底图标（不报错）。
      final hf = parseHamQsl(fixture())!;
      final tips = hfTips(hf, zh);
      expect(tips, isNotEmpty);
      for (final t in tips) {
        // 只断言「非 null」等于没测。真正要盯住的是：这个图标在
        // app_widget.dart 的 kAppWidgetIconNames 里有名字（否则组件上会
        // 静默退化成兜底图标 —— 不报错、只是图标与内容不搭）。
        expect(kAppWidgetIconNames.containsKey(t.icon), isTrue,
            reason: '图标 ${t.icon} 没有登记图标名，短波建议在组件上会显示成兜底图标');
      }
    });
  });
}
