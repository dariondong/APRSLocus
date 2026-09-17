import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/hf.dart';
import 'package:aprslocus/hf_widget.dart';
import 'package:aprslocus/l10n/app_localizations.dart';
// TipLevel / HamTip 定义在 weather.dart（建议的分级与排序都在那边）
import 'package:aprslocus/weather.dart';

/// 短波/电离层组件的快照测试。
///
/// 与天气组件同样的理由：**组件不会自己纠错** —— 快照里少个字段、条件色算错、
/// 波段行数越界，Kotlin 侧只会安静地留空或回退（那是刻意设计的容错），
/// 错误全部落在「界面看起来有点怪」上。
void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  /// 造一份确定的短波状态（不联网）
  HfNow sample({
    String sfi = '100',
    String aIndex = '9',
    String kIndex = '3',
    String geomag = 'UNSETTLD',
    String noise = 'S2-S3',
    List<HfBand>? bands,
  }) =>
      HfNow(
        sfi: sfi,
        aIndex: aIndex,
        kIndex: kIndex,
        xray: 'B2.2',
        sunspots: '23',
        solarWind: '508.8',
        geomag: geomag,
        noise: noise,
        muf: 'NoRpt',
        bands: bands ??
            const [
              HfBand(name: '80m-40m', day: 'Poor', night: 'Fair'),
              HfBand(name: '30m-20m', day: 'Good', night: 'Good'),
              HfBand(name: '17m-15m', day: 'Fair', night: 'Fair'),
              HfBand(name: '12m-10m', day: 'Poor', night: 'Band Closed'),
            ],
        updated: '17 Sep 2026 0513 GMT',
      );

  void seedHf(HfNow? now) => HfCenter.instance.now = now;

  group('短波组件快照', () {
    test('没有数据时给占位，不抛异常', () {
      seedHf(null);
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);

      expect(snap['hasData'], isFalse);
      expect(snap['v'], kHfWidgetSnapshotVersion);
      expect((snap['emptyLabel'] as String).isNotEmpty, isTrue);
      expect(snap['bands'], isEmpty);
      // 表头即使没数据也要有（Kotlin 会照填，不该出现空标签）
      expect((snap['bandHead'] as List).length, 3);
      expect(() => jsonEncode(snap), returnsNormally);
    });

    test('有数据时汇总三格 + 四行波段，且可 JSON 编码', () {
      seedHf(sample());
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);

      expect(snap['hasData'], isTrue);
      final sum = snap['summary'] as List;
      expect(sum.length, kHfWidgetSummaryCells);
      expect((sum[0] as Map)['label'], zh.hfSfi);
      expect((sum[1] as Map)['label'], zh.hfKp);
      expect((sum[2] as Map)['label'], zh.hfAIndex);

      final bands = snap['bands'] as List;
      expect(bands.length, 4);
      expect((bands[0] as Map)['name'], '80m/40m'); // 连字符→斜杠，面板更好读
      expect(() => jsonEncode(snap), returnsNormally);
    });

    test('字段名与 Kotlin 侧读的键一致（跨语言契约）', () {
      // HfWidgetProvider 用 header.read("title") / cell.read("label") /
      // band.read("dayLabel") 这类**字面量**取值。键名改了而 Kotlin 没跟上，
      // 组件上是**安静的空白**（read() 刻意容错返回空串），极难查。
      seedHf(sample());
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);

      for (final k in ['v', 'hasData', 'title', 'summary', 'bandHead', 'bands',
        'emptyLabel']) {
        expect(snap.containsKey(k), isTrue, reason: '快照缺 $k');
      }
      for (final c in snap['summary'] as List) {
        expect((c as Map).keys.toSet(), {'label', 'value', 'color'});
      }
      for (final b in snap['bands'] as List) {
        final map = b as Map;
        for (final k in ['name', 'dayLabel', 'dayColor', 'nightLabel',
          'nightColor']) {
          expect(map.containsKey(k), isTrue, reason: '波段行缺 $k');
        }
      }
    });

    test('波段行数不超过布局的行数（多余会被静默丢弃）', () {
      // 布局 aw_widget_hf.xml 只有 4 行。源数据是 4 个波段对，但如果哪天源改了
      // （多发几对），这里必须截断 —— 而截断得**有意识**，所以断言上限。
      seedHf(sample(bands: const [
        HfBand(name: 'a', day: 'Good', night: 'Good'),
        HfBand(name: 'b', day: 'Good', night: 'Good'),
        HfBand(name: 'c', day: 'Good', night: 'Good'),
        HfBand(name: 'd', day: 'Good', night: 'Good'),
        HfBand(name: 'e', day: 'Good', night: 'Good'),
      ]));
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);
      expect((snap['bands'] as List).length, kHfWidgetBandRows);
      expect(kHfWidgetBandRows, 4, reason: '与布局行数必须一致');
    });

    test('条件文案已本地化，且带上了颜色', () {
      seedHf(sample());
      final zhSnap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);
      final enSnap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: en);

      final zhRow = (zhSnap['bands'] as List).first as Map;
      final enRow = (enSnap['bands'] as List).first as Map;
      expect(zhRow['dayLabel'], zh.hfQPoor); // 80m/40m 日间 = Poor
      expect(enRow['dayLabel'], en.hfQPoor);
      expect(zhRow['dayLabel'], isNot(enRow['dayLabel']),
          reason: '中英文案应该不同');
      // 颜色与语言无关
      expect(zhRow['dayColor'], enRow['dayColor']);
    });

    test('Band Closed 用灰色，不是红/绿', () {
      seedHf(sample());
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);
      final last = (snap['bands'] as List).last as Map;
      expect(last['nightLabel'], zh.hfQClosed);
      // 灰 (#94A3B8 提亮后 = #B9C3D1)，不该等于绿/橙/红
      expect(last['nightColor'], 0xFFB9C3D1);
    });
  });

  group('Kp / A 阈值染色', () {
    int kpColor(int k) {
      seedHf(sample(kIndex: '$k'));
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);
      return ((snap['summary'] as List)[1] as Map)['color'] as int;
    }

    int aColor(int a) {
      seedHf(sample(aIndex: '$a'));
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);
      return ((snap['summary'] as List)[2] as Map)['color'] as int;
    }

    test('Kp ≤3 绿、=4 橙、≥5 红（与 hf.dart 的 geomagActive/Storm 同阈值）', () {
      const green = 0xFF68C389; // hfQualityColor(good) 提亮后
      const orange = 0xFFE6A75D;
      const red = 0xFFEC6C88;
      expect(kpColor(0), green);
      expect(kpColor(3), green);
      expect(kpColor(4), orange);
      expect(kpColor(5), red);
      expect(kpColor(9), red);
    });

    test('A ≤15 绿、≤30 橙、>30 红', () {
      const green = 0xFF68C389;
      const orange = 0xFFE6A75D;
      const red = 0xFFEC6C88;
      expect(aColor(5), green);
      expect(aColor(15), green);
      expect(aColor(16), orange);
      expect(aColor(30), orange);
      expect(aColor(31), red);
    });

    test('Kp 阈值与 HfNow.geomagActive / geomagStorm 一致', () {
      // 组件染色与建议分级必须同一套阈值，否则会出现「组件标红、建议说没事」
      expect(sample(kIndex: '3', geomag: 'QUIET').geomagActive, isFalse);
      expect(sample(kIndex: '4', geomag: 'QUIET').geomagActive, isTrue);
      expect(sample(kIndex: '5', geomag: 'QUIET').geomagStorm, isTrue);
    });

    test('没有数值时不染色（color = 0），而不是误染绿', () {
      seedHf(sample(kIndex: '--', aIndex: '--'));
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);
      expect(((snap['summary'] as List)[1] as Map)['color'], 0);
      expect(((snap['summary'] as List)[2] as Map)['color'], 0);
    });

    test('SFI 不染色（它只是太阳活动强度，高低各有玩法）', () {
      seedHf(sample(sfi: '250'));
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);
      expect(((snap['summary'] as List)[0] as Map)['color'], 0);
    });
  });

  group('短波建议接入面板', () {
    test('地磁暴会给出风暴级建议', () {
      // hfTips 的入口契约：Kp ≥5 必须能产出建议（面板靠它把传播风险讲清楚）
      final tips = hfTips(sample(kIndex: '6', geomag: 'STORM'), zh);
      expect(tips, isNotEmpty);
      expect(tips.any((t) => t.level == TipLevel.warn), isTrue,
          reason: '地磁暴应当至少是「注意」级别');
    });

    test('地磁平静且 SFI 高时给出「高波段有戏」的通联机会', () {
      final tips = hfTips(
        sample(kIndex: '1', aIndex: '3', sfi: '180', geomag: 'QUIET'),
        zh,
      );
      expect(tips.isNotEmpty, isTrue);
    });

    test('没有短波数据时不产出建议（不能凭空造）', () {
      expect(hfTips(null, zh), isEmpty);
    });
  });
}
