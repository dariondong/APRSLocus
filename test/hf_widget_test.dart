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
    String muf = 'NoRpt',
    List<HfBand>? bands,
    // VHF 条件（6m 的 Es / 极光）。默认给空 —— 此时 6m 段应显示 '--'，
    // 而不是把「无数据」误显示成「未开通」。
    HfVhf vhf = const HfVhf(),
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
        muf: muf,
        vhf: vhf,
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

  group('6m 波段预测', () {
    test('Es 优先取 6m 专门项，而不是欧洲区那项', () {
      // 源数据里同时有 'europe'（给 4m/6m 的区域值）与 'europe_6m'（6m 专门项）。
      // 6m 必须取专门项 —— 取区域值会把 4m 的条件混进来。
      seedHf(sample(vhf: const HfVhf(
        eSkip: {'europe': 'Poor', 'europe_6m': 'Good', 'europe_4m': 'Fair'},
      )));
      expect(hfSixMeter(HfCenter.instance.now).es, 'Good');
    });

    test('没有 6m 专门项时，取各区域里**最好**的一档', () {
      // Es 是局地现象，某区开通就说明当天有 Es 活动层。
      // 全球平均会把「开了」抹成「关着」，反而更没用。
      seedHf(sample(vhf: const HfVhf(
        eSkip: {'europe': 'Band Closed', 'north_america': 'Fair'},
      )));
      expect(hfSixMeter(HfCenter.instance.now).es, 'Fair');
    });

    test('合成结论取三条通路里最好的一档（任一开通就值得上机）', () {
      // Es 关着，但极光开通 → 合成应是「一般」而不是「未开通」
      seedHf(sample(
        kIndex: '5',
        vhf: const HfVhf(
          eSkip: {'europe_6m': 'Band Closed'},
          aurora: 'Fair',
        ),
      ));
      final six = hfSixMeter(HfCenter.instance.now);
      expect(six.quality, HfQuality.fair);
      expect(six.es, 'Band Closed');
      expect(six.aurora, 'Fair');
    });

    test('F2 需要 MUF ≥ 50MHz；NoRpt 时按不成立处理（不猜）', () {
      // 猜错会让人白等一晚，所以源数据没给 MUF 时宁可说「不成立」。
      seedHf(sample(muf: 'NoRpt'));
      expect(hfSixMeter(HfCenter.instance.now).f2, isFalse);

      seedHf(sample(muf: '48'));
      expect(hfSixMeter(HfCenter.instance.now).f2, isFalse,
          reason: '48 < 50，不够');

      seedHf(sample(muf: '52'));
      expect(hfSixMeter(HfCenter.instance.now).f2, isTrue);
      // F2 成立即视为「好」——它本身就是难得的机会
      expect(hfSixMeter(HfCenter.instance.now).quality, HfQuality.good);
    });

    test('没有 VHF 数据时，6m 三项都是 -- 而不是「未开通」', () {
      // 「无数据」与「未开通」是两回事：前者是没拿到，后者是拿到了但关闭。
      // 混为一谈会让用户以为「今天 6m 确定没戏」，而其实是数据缺失。
      seedHf(sample(vhf: const HfVhf()));
      final six = hfSixMeter(HfCenter.instance.now);
      expect(six.es, HfNow.none);
      expect(six.aurora, HfNow.none);
      expect(six.quality, HfQuality.unknown);

      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);
      final sixSnap = snap['six'] as Map;
      expect(sixSnap['esValue'], HfNow.none);
      expect(sixSnap['esValue'], isNot(zh.hfQClosed));
    });
  });

  group('本地化完整性（防未翻译文本漏进快照）', () {
    // 回归护栏：6m 段的 Es / 极光两个值曾经**直接用源数据原始串**下发，
    // 于是中文界面里显示英文 'Band Closed' —— 而它恰恰是 6m 最常见的取值
    // （几乎每次打开都是它），等于长期露英文。
    // 逐波段表的 dayLabel/nightLabel 一直是本地化的，只有这两处漏了。
    //
    // 这条按「整份快照」检查，而不是只盯那两个字段 —— 同一类错误
    // （把源数据原始串当展示文案）以后可能出现在任何新字段上。
    test('中文快照里不残留英文质量词', () {
      seedHf(sample(
        // 四条都凑上：Good / Fair / Poor / Band Closed
        bands: const [
          HfBand(name: '80m-40m', day: 'Good', night: 'Fair'),
          HfBand(name: '30m-20m', day: 'Poor', night: 'Band Closed'),
          HfBand(name: '17m-15m', day: 'Fair', night: 'Good'),
          HfBand(name: '12m-10m', day: 'Poor', night: 'Poor'),
        ],
      ));
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);
      final json = jsonEncode(snap);
      // 只看**首字母大写**的英文质量词：level 键是小写的枚举名
      // （'good'/'fair'…，那是给 Kotlin 选 chip 用的，不是展示文案），
      // 所以大写形式一旦出现，就说明某个字段漏了本地化。
      for (final w in ['Good', 'Fair', 'Poor', 'Band Closed', 'NoRpt']) {
        expect(json.contains(w), isFalse,
            reason: '中文快照里出现了未本地化的「$w」——'
                '检查是否有字段直接把源数据原始串当展示文案下发');
      }
    });

    test('英文快照里这些词是**正常**的（说明上一条不是把英文一刀切）', () {
      seedHf(sample(bands: const [
        HfBand(name: '80m-40m', day: 'Good', night: 'Fair'),
      ]));
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: en);
      final json = jsonEncode(snap);
      expect(json.contains('Good'), isTrue,
          reason: '英文界面本来就该显示 Good/Fair/Poor');
    });

    test('6m 段的 Es / 极光值已本地化，且与源数据取值一致', () {
      // 「Band Closed」在中文里是「未开通」（v1.6.122 改的用词）
      // 源数据里 E-skip / 极光的取值就是 Band Closed（最常见的状态）
      seedHf(sample(
        bands: const [HfBand(name: '80m-40m', day: 'Good', night: 'Good')],
        vhf: const HfVhf(
          eSkip: {'europe_6m': 'Band Closed', 'north_america': 'Band Closed'},
          aurora: 'Band Closed',
        ),
      ));
      final snap = buildHfWidgetSnapshot(hf: HfCenter.instance, s: zh);
      final six = snap['six'] as Map;
      // → 中文必须显示「未开通」，而不是英文 'Band Closed'
      expect(six['esValue'], zh.hfQClosed);
      expect(six['auroraValue'], zh.hfQClosed);
      expect(six['esValue'], isNot('Band Closed'));
      expect(six['label'], zh.hfQClosed, reason: '合成结论也应为未开通');
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
