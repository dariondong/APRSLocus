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
      // 两列列头即使没数据也要有（Kotlin 会照填，不该出现空标签）
      expect((snap['dayLabel'] as String).isNotEmpty, isTrue);
      expect((snap['nightLabel'] as String).isNotEmpty, isTrue);
      expect(() => jsonEncode(snap), returnsNormally);
    });

    test('有数据时汇总三格 + 四行波段，且可 JSON 编码', () {
      seedHf(sample());
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);

      expect(snap['hasData'], isTrue);
      final sum = snap['indices'] as List;
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

      for (final k in ['v', 'hasData', 'title', 'indices', 'dayLabel', 'nightLabel',
        'bands',
        'emptyLabel']) {
        expect(snap.containsKey(k), isTrue, reason: '快照缺 $k');
      }
      for (final c in snap['indices'] as List) {
        expect((c as Map).keys.toSet(), {'label', 'value', 'color'});
      }
      for (final b in snap['bands'] as List) {
        final map = b as Map;
        for (final k in ['name', 'dayLabel', 'dayLevel', 'nightLabel',
          'nightLevel']) {
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
      expect(zhRow['dayLevel'], enRow['dayLevel']);
    });

    test('Band Closed 用灰色，不是红/绿', () {
      seedHf(sample());
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);
      final last = (snap['bands'] as List).last as Map;
      expect(last['nightLabel'], zh.hfQClosed);
      // 契约是**等级名**（Kotlin 用 CHIP_BY_LEVEL 选 aw_chip_closed），
      // 不再是色值 —— chip 是实心色块，换底靠换 drawable
      // （TextView 没有 setColorFilter，那是 ImageView 独有的）。
      expect(last['nightLevel'], 'closed');
    });
  });

  group('chip 等级契约', () {
    test('level 名落在 Kotlin 认识的集合里', () {
      // Kotlin 的 CHIP_BY_LEVEL 只认 good/fair/poor/closed，认不出会回退灰底。
      // hf.dart 的 HfQuality 还多一个 unknown（"no report"/"--" 这类无数据），
      // 它没有专属 chip —— 这是**有意的**：unknown 也走灰底，语义就是「没数据」。
      const known = {'good', 'fair', 'poor', 'closed', 'unknown'};
      const chipLevels = {'good', 'fair', 'poor', 'closed'};
      for (final (day, night) in const [
        ('Good', 'Poor'),
        ('Fair', 'Band Closed'),
        ('no report', 'NoRpt'),
        ('--', 'Band Closed'),
      ]) {
        seedHf(sample(bands: [HfBand(name: 'x', day: day, night: night)]));
        final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);
        final row = (snap['bands'] as List).first as Map;
        for (final key in ['dayLevel', 'nightLevel']) {
          expect(known, contains(row[key]),
              reason: 'level=${row[key]} 不在允许集合里');
        }
        // 契约：**凡是源数据给了明确条件的一侧，就必须落到有专属 chip 的等级上**
        // （不能落 unknown，否则这一侧的 chip 是灰的、看不出条件）。
        // 注意不能要求「两边都非 unknown」—— 第 3/4 组样本两边本来就都是
        // 「无数据」（no report / --），全灰才是正确行为。
        for (final (raw, key) in [(day, 'dayLevel'), (night, 'nightLevel')]) {
          final q = hfQualityOf(raw);
          if (q == HfQuality.unknown) continue; // 源数据没给，灰底是对的
          expect(chipLevels, contains(row[key]),
              reason: '源数据 $raw 有明确条件，却落到了灰底（${row[key]}）');
        }
      }
    });
  });

  group('Kp / A 阈值染色', () {
    int kpColor(int k) {
      seedHf(sample(kIndex: '$k'));
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);
      return ((snap['indices'] as List)[1] as Map)['color'] as int;
    }

    int aColor(int a) {
      seedHf(sample(aIndex: '$a'));
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);
      return ((snap['indices'] as List)[2] as Map)['color'] as int;
    }

    test('Kp ≤3 绿、=4 橙、≥5 红（与 hf.dart 的 geomagActive/Storm 同阈值）', () {
      const green = 0xFF16A34A; // 基准色（白底上用基准色，不提亮）
      const orange = 0xFFD97706;
      const red = 0xFFE11D48;
      expect(kpColor(0), green);
      expect(kpColor(3), green);
      expect(kpColor(4), orange);
      expect(kpColor(5), red);
      expect(kpColor(9), red);
    });

    test('A ≤15 绿、≤30 橙、>30 红', () {
      const green = 0xFF16A34A;
      const orange = 0xFFD97706;
      const red = 0xFFE11D48;
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
      expect(((snap['indices'] as List)[1] as Map)['color'], 0);
      expect(((snap['indices'] as List)[2] as Map)['color'], 0);
    });

    test('SFI 不染色（它只是太阳活动强度，高低各有玩法）', () {
      seedHf(sample(sfi: '250'));
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);
      expect(((snap['indices'] as List)[0] as Map)['color'], 0);
    });
  });

  group('质量文案（chip 内显示）', () {
    /// chip 宽 46dp、字号 8.5sp：CJK 每字约 8.5dp，拉丁每字约 4.7dp。
    double chipWidth(String v) {
      final cjk = v.runes.where((r) => r > 0x2E80).length;
      final lat = v.runes.length - cjk;
      return cjk * 8.5 + lat * 4.7;
    }

    test('四种质量文案非空，且都能放进 chip（不靠省略号）', () {
      // chip 是**固定宽度**的（对齐需要），所以文案一旦变长就会被省略号截断 ——
      // 而截断的条件文字（「未开…」）等于没给信息。这条护栏盯住长度。
      for (final s in [zh, en]) {
        for (final label in [s.hfQGood, s.hfQFair, s.hfQPoor, s.hfQClosed]) {
          expect(label, isNotEmpty);
          expect(chipWidth(label), lessThanOrEqualTo(46),
              reason: '「$label」约 ${chipWidth(label).toStringAsFixed(1)}dp，'
                  '超出 chip 的 46dp，会被省略号截断');
        }
      }
    });

    test('「Band Closed」的文案不能是该语言的 UI 关闭动词', () {
      // 回归护栏：中文曾用「关闭」，而 chip 是**圆角色块**（形状像按钮）——
      // 于是那颗 chip 看起来就是一颗关闭按钮（用户实际这么反馈过）。
      // 判据：不能等于「关闭」这类会被读成 UI 动作的词。
      const uiCloseWords = {'关闭', '關閉', 'クローズ', 'Tutup', 'Close'};
      for (final s in [zh, en]) {
        expect(uiCloseWords.contains(s.hfQClosed), isFalse,
            reason: '「${s.hfQClosed}」在 chip 里会被读成关闭按钮，'
                '应改用表示「无传播」的状态词');
      }
      // 目前选用的词（未开通 / 未開通 / 伝搬なし / Tertutup …）都表示状态
      expect(zh.hfQClosed, '未开通');
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
