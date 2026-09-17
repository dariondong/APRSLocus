import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/app_widget.dart';
import 'package:aprslocus/l10n/app_localizations.dart';
import 'package:aprslocus/weather.dart';

/// 桌面小组件快照的单元测试。
///
/// 这一层值得测，是因为**组件不会自己纠错**：一旦快照里少了 city、
/// kind 拼成了 'Cloudy'、或者 tips 越过了 4 条，Kotlin 侧只会安静地把
/// 空格子画出来（那是刻意设计的容错，见 WeatherWidgetProvider.read()）。
/// 于是错误全部落在「界面看起来有点怪」上 —— 不去测试就没人会发现。
void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  /// 造一个确定的天气状态，避免测试之间互相污染（WeatherCenter 是单例）
  void seed({
    String? icon,
    String temp = '23',
    String humidity = '45',
    String windDir = '东北风',
    String windScale = '3',
    String pressure = '1013',
    String vis = '25',
    String precip = '0',
    String dew = '12',
    String text = '晴',
    String? city = '北京',
    AirNow? air,
    List<WeatherDaily> daily = const [],
  }) {
    final wc = WeatherCenter.instance;
    wc.now = WeatherNow(
      temp: temp,
      text: text,
      icon: icon ?? '100',
      feelsLike: temp,
      humidity: humidity,
      windDir: windDir,
      windScale: windScale,
      windSpeed: '12',
      pressure: pressure,
      vis: vis,
      precip: precip,
      cloud: '20',
      dew: dew,
      // 故意用「不带时区偏移」的本地时间串：带 +08:00 的话，测试机器的
      // 时区会把 14:30 转成别的钟点，测试会随环境飘。
      obsTime: '2026-09-17T14:30:00',
      city: city,
    );
    wc.air = air;
    wc.daily = daily;
    wc.loading = false;
    wc.errorCode = 0;
  }

  void seedNoData() {
    final wc = WeatherCenter.instance;
    wc.now = null;
    wc.air = null;
    wc.daily = const [];
    wc.loading = false;
    wc.errorCode = 0;
  }

  group('快照结构', () {
    test('没有天气数据时给占位，不抛异常', () {
      seedNoData();
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);

      expect(snap['hasData'], isFalse);
      expect(snap['v'], kAppWidgetSnapshotVersion);
      expect((snap['emptyLabel'] as String).isNotEmpty, isTrue);
      expect(snap['kind'], 'cloudy');
      expect(snap['tips'], isEmpty);
      expect(snap['metrics'], isEmpty);
      // 没有数据时也必须能编码 —— Kotlin 侧对 null 的处理是有意省略的
      expect(() => jsonEncode(snap), returnsNormally);
    });

    test('有数据时字段齐全且可 JSON 编码', () {
      seed();
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);

      expect(snap['hasData'], isTrue);
      expect((snap['header'] as Map)['city'], '北京');
      expect((snap['hero'] as Map)['temp'], '23°');
      expect((snap['metrics'] as List).length, kAppWidgetMetricCount);
      expect(snap['tipTotal'], isA<int>());
      expect(() => jsonEncode(snap), returnsNormally);
    });

    test('指标格数量与布局里的格子数一致（2×2 网格 → 4 格）', () {
      // 布局 aw_widget_tile / aw_widget_tall 的指标区是 2×2 网格。
      // 数量对不上的后果：少了 → 网格里永久留一个空白块；
      // 多了 → Kotlin 会把多余格隐藏（补救），但根子上的数量对齐该在这里保证。
      expect(kAppWidgetMetricCount, 4);
      for (final icon in ['100', '104', '302', '400', '501']) {
        seed(icon: icon, precip: '1');
        final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
        expect((snap['metrics'] as List).length, 4, reason: 'icon=$icon');
      }
    });

    test('提示最多下发 4 条（第 2 行只有 4 格）', () {
      // 雷暴 + 大风 + 高湿 + 低能见度，一次凑出远超 4 条建议
      seed(
        icon: '302',
        temp: '36',
        humidity: '92',
        windScale: '7',
        vis: '1',
        precip: '12',
        air: const AirNow(
          aqi: '180',
          category: '',
          primary: '',
          pm2p5: '',
          pm10: '',
        ),
      );
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);

      final tips = snap['tips'] as List;
      expect(tips.length, lessThanOrEqualTo(kAppWidgetMaxTips));
      // tipTotal 是「一共有多少条」，和截断后的条数不是一回事
      expect(snap['tipTotal'] as int, greaterThanOrEqualTo(tips.length));
    });

    test('危险级建议排在最前且带上了级别文案', () {
      seed(icon: '302', text: '雷阵雨');
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);

      final first = (snap['tips'] as List).first as Map;
      expect(first['level'], 'danger');
      expect(first['emoji'], '⚡');
      expect(first['levelLabel'], zh.hamLevelDanger);
      // 颜色是给 Kotlin setTextColor 用的 0xAARRGGBB 整数
      expect(first['color'], isA<int>());
      expect(first['color'] as int, isNot(0));
    });

    test('城市缺失时退回「当前位置」，不留空串', () {
      seed(city: null);
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      expect((snap['header'] as Map)['city'], zh.weatherCurLoc);
    });

    test('观测时刻用「观测 HH:mm」而不是本机时间', () {
      seed();
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      expect((snap['header'] as Map)['observed'], zh.weatherObserved('14:30'));
    });

    test('跟随语言：同一天气在中英两种语言下文案不同', () {
      seed();
      final zhSnap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      final enSnap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: en);

      expect((zhSnap['header'] as Map)['observed'],
          isNot((enSnap['header'] as Map)['observed']));
      expect((zhSnap['metrics'] as List).length,
          (enSnap['metrics'] as List).length);
    });
  });

  group('指标按天气切换', () {
    String firstLabel(Map<String, Object?> snap) =>
        ((snap['metrics'] as List).first as Map)['label'] as String;

    test('起雾 → 第一格是能见度', () {
      seed(icon: '501', vis: '0.5', text: '雾');
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      expect(firstLabel(snap), zh.weatherVis);
    });

    test('能见度低于 5km 也按雾处理（哪怕现象代码不是雾）', () {
      seed(icon: '104', vis: '2');
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      expect(firstLabel(snap), zh.weatherVis);
    });

    test('下雨 → 第一格是降水量', () {
      seed(icon: '305', precip: '3.5', text: '小雨');
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      expect(firstLabel(snap), zh.weatherPrecip);
    });

    test('下雪 → 第一格是降水量', () {
      seed(icon: '400', precip: '2', text: '小雪');
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      expect(firstLabel(snap), zh.weatherPrecip);
    });

    test('低温 → 第一格是露点（比体感更实用：结露会短路）', () {
      seed(icon: '100', temp: '2', dew: '-1');
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      expect(firstLabel(snap), zh.weatherDew);
    });

    test('常规天气 → 第一格是气压（关注大气波导）', () {
      seed(icon: '100', temp: '20', vis: '25');
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      expect(firstLabel(snap), contains(zh.weatherPressure));
    });

    test('每项指标的名次随天气变化（最要紧的排第一格）', () {
      // 同一组数值下，雾天把能见度顶上来、雨天把降水量顶上来 ——
      // 组件格子少，必须分主次，不能像面板那样平铺一份通用清单。
      seed(icon: '501', temp: '20', vis: '0.8', precip: '1');
      final fog = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      expect(firstLabel(fog), zh.weatherVis);

      seed(icon: '305', temp: '20', vis: '25', precip: '4');
      final rain = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      expect(firstLabel(rain), zh.weatherPrecip);
    });

    test('每个指标格三项都不为空（否则格子里会出现空白）', () {
      for (final icon in ['100', '104', '305', '302', '400', '501']) {
        seed(icon: icon, precip: '1');
        final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
        for (final m in snap['metrics'] as List) {
          final map = m as Map;
          expect(map['emoji'], isNotEmpty, reason: 'icon=$icon');
          expect(map['value'], isNotEmpty, reason: 'icon=$icon');
          expect(map['label'], isNotEmpty, reason: 'icon=$icon');
        }
        expect((snap['metrics'] as List).length, kAppWidgetMetricCount,
            reason: 'icon=$icon');
      }
    });
  });

  group('天气档位与图标', () {
    test('天气档位与面板同口径', () {
      seed(icon: '100');
      expect(widgetWeatherKind(WeatherCenter.instance.now!), 'clear');
      seed(icon: '150'); // 夜间晴
      expect(widgetWeatherKind(WeatherCenter.instance.now!), 'clear');
      seed(icon: '101');
      expect(widgetWeatherKind(WeatherCenter.instance.now!), 'cloudy');
      seed(icon: '104');
      expect(widgetWeatherKind(WeatherCenter.instance.now!), 'overcast');
      seed(icon: '305');
      expect(widgetWeatherKind(WeatherCenter.instance.now!), 'rain');
      seed(icon: '302'); // 雷阵雨
      expect(widgetWeatherKind(WeatherCenter.instance.now!), 'storm');
      seed(icon: '400');
      expect(widgetWeatherKind(WeatherCenter.instance.now!), 'snow');
      seed(icon: '501');
      expect(widgetWeatherKind(WeatherCenter.instance.now!), 'fog');
    });

    test('未知图标代码不抛异常，退回阴天档', () {
      seed(icon: '99999');
      // 99999 落在 500-599 之外 → clear；关键是不崩
      expect(() => widgetWeatherKind(WeatherCenter.instance.now!),
          returnsNormally);
    });

    test('天气 emoji 覆盖日/夜/雷/雨/雪/雾', () {
      expect(widgetWeatherEmoji('100'), '☀️');
      expect(widgetWeatherEmoji('150'), '🌙');
      expect(widgetWeatherEmoji('101'), '🌤️');
      expect(widgetWeatherEmoji('104'), '☁️');
      expect(widgetWeatherEmoji('302'), '⛈️');
      expect(widgetWeatherEmoji('305'), '🌦️');
      expect(widgetWeatherEmoji('307'), '🌧️');
      expect(widgetWeatherEmoji('400'), '❄️');
      expect(widgetWeatherEmoji('503'), '🌪️');
      expect(widgetWeatherEmoji('501'), '🌫️');
    });

    test('提示图标映射：认识的给专属 emoji，不认识给兜底', () {
      expect(widgetTipEmoji(Icons.flash_on_rounded), '⚡');
      expect(widgetTipEmoji(Icons.power_off_rounded), '🔌');
      expect(widgetTipEmoji(Icons.nightlight_round), '🌙');
      expect(widgetTipEmoji(Icons.rss_feed_rounded), '📡');
      // 未登记的新图标不能让组件出现空白格
      expect(widgetTipEmoji(Icons.abc), kWidgetTipEmojiFallback);
    });

    test('天气面板用到的每个 HamTip 图标都在映射表里', () {
      // 把所有可能出现的建议图标都跑一遍：任何一条落到兜底都说明
      // lib/weather.dart 新加了图标而忘了登记
      seed(
        icon: '302',
        temp: '36',
        humidity: '92',
        windScale: '7',
        vis: '1',
        precip: '12',
      );
      final tips = hamTips(WeatherCenter.instance, zh);
      expect(tips, isNotEmpty);
      for (final tip in tips) {
        expect(kWidgetTipEmoji.containsKey(tip.icon), isTrue,
            reason: '图标 ${tip.icon} 没有对应的 emoji，组件上会退化成 '
                '$kWidgetTipEmojiFallback');
      }
    });
  });

  group('单行形态的文案压缩（2×2 / 4×1 档用）', () {
    const full = '雷雨天气：请勿在室外架设/操作天线！断开天线馈线，谨防雷击感应损坏设备';

    test('切出从长到短的多个版本，且都是原文的子串', () {
      final v = compactTipVariants(full);
      expect(v, isNotEmpty);
      for (final s in v) {
        expect(full.contains(s.replaceAll('…', '')), isTrue,
            reason: '「$s」不是原文的子串，等于凭空造词');
      }
    });

    test('每一版都比原文短（否则压缩没意义）', () {
      for (final s in compactTipVariants(full)) {
        expect(s.length, lessThan(full.length));
      }
    });

    test('按长到短排列（Kotlin 从前往后挑第一个放得下的）', () {
      final v = compactTipVariants(full);
      for (var i = 1; i < v.length; i++) {
        expect(v[i].length, lessThanOrEqualTo(v[i - 1].length),
            reason: '第 $i 项比前一项长，挑选逻辑会挑错');
      }
    });

    test('长版本会带省略号，用户能看出还有下文', () {
      expect(compactTipVariants(full).any((s) => s.endsWith('…')), isTrue);
    });

    test('没有标点和冒号的短句：原样返回，不能返回空', () {
      final v = compactTipVariants('天气良好');
      expect(v, isNotEmpty);
      expect(v.first, '天气良好');
    });

    test('空串不炸', () {
      expect(compactTipVariants(''), isEmpty);
      expect(compactTipVariants('   '), isEmpty);
    });

    test('英文文案（半角冒号）也能切', () {
      const en = 'High pressure with a stable airmass: tropospheric ducting may '
          'form, try long-distance VHF/UHF contacts';
      final v = compactTipVariants(en);
      expect(v, isNotEmpty);
      for (final s in v) {
        expect(en.contains(s.replaceAll('…', '')), isTrue);
      }
    });

    test('快照里的 compactRows 带上压缩版本（供小尺寸档用）', () {
      seed(icon: '302', text: '雷阵雨');
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      final rows = snap['compactRows'] as List;
      expect(rows, isNotEmpty);

      final first = rows.first as Map;
      expect(first['emoji'], '⚡');
      expect(first['levelLabel'], zh.hamLevelDanger);
      final singles = first['singles'] as List;
      expect(singles, isNotEmpty);
      for (final s in singles) {
        final m = s as Map;
        expect(m['text'], isNotEmpty);
        expect(m['emoji'], isNotEmpty);
        expect(m['color'], isA<int>());
      }
      expect(() => jsonEncode(snap), returnsNormally);
    });

    test('没有天气数据时 compactRows 为空（占位态不该显示提示）', () {
      seedNoData();
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      expect(snap['compactRows'], isEmpty);
    });
  });

  group('颜色编码', () {
    test('ARGB 编码是 0xAARRGGBB（Kotlin 侧当 int 用）', () {
      expect(colorToArgb(const Color(0xFFE11D48)), 0xFFE11D48);
      expect(colorToArgb(const Color(0x00000000)), 0x00000000);
    });

    test('提示文字色比原色更亮（压在天气渐变上要能看清）', () {
      const raw = Color(0xFF2563EB); // 深蓝，直接压在晴天渐变上会糊
      final shown = widgetTipTextArgb(raw);
      int lum(int c) => ((c >> 16) & 0xFF) + ((c >> 8) & 0xFF) + (c & 0xFF);
      expect(lum(shown), greaterThan(lum(colorToArgb(raw))));
    });
  });
}
