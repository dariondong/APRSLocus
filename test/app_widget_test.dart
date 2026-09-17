import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/app_widget.dart';
import 'package:aprslocus/l10n/app_localizations.dart';
import 'package:aprslocus/weather.dart';

/// 桌面小组件快照的单元测试。
///
/// 这一层值得测，是因为**组件不会自己纠错**：一旦快照里少了字段、图标名拼错、
/// 或者 tips 越过了行数，Kotlin 侧只会安静地把空格子/兵底图标画出来
/// （那是刻意设计的容错）。于是错误全部落在「界面看起来有点怪」上 ——
/// 不去测试就没人会发现。
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

    test('字段名与 Kotlin 侧读的键一致（跨语言契约）', () {
      // Kotlin 用 `header.read("city")` / `hero.read("iconName")` /
      // `tip.read("shortText")` 这样的字面量取值。键名一旦改了而 Kotlin 没跟着改，
      // 组件上是**安静的空白**（read() 刻意容错返回空串），极难查。
      // 所以把键名固定成契约，改这里就必须同时去改 Kotlin。
      seed(icon: '302');
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);

      final header = snap['header'] as Map;
      for (final k in ['city', 'aqi', 'aqiLabel', 'aqiColor', 'observed']) {
        expect(header.containsKey(k), isTrue, reason: 'header 缺 $k');
      }
      final hero = snap['hero'] as Map;
      for (final k in ['iconName', 'temp', 'cond', 'range']) {
        expect(hero.containsKey(k), isTrue, reason: 'hero 缺 $k');
      }
      for (final m in snap['metrics'] as List) {
        expect((m as Map).keys.toSet(), {'label', 'value'});
      }
      for (final t in snap['tips'] as List) {
        final map = t as Map;
        for (final k in ['iconName', 'levelLabel', 'color', 'level', 'text',
          'shortText']) {
          expect(map.containsKey(k), isTrue, reason: 'tips 缺 $k');
        }
      }
    });

    test('指标格数量与布局里的格子数一致（主档 2×2 → 4 格）', () {
      // 布局 aw_widget_tile 的指标区是 2×2 网格。数量对不上的后果：
      // 少了 → 网格里永久留一个空白块；多了 → Kotlin 会把多余格隐藏（补救），
      // 但根子上的数量对齐应该在这里保证。
      expect(kAppWidgetMetricCount, 4);
      for (final icon in ['100', '104', '302', '400', '501']) {
        seed(icon: icon, precip: '1');
        final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
        expect((snap['metrics'] as List).length, 4, reason: 'icon=$icon');
      }
    });

    test('提示最多下发 4 条（各档按自己的行数取前 N 条）', () {
      // 雷暴 + 大风 + 高湿 + 低能见度，一次凑出远超 4 条建议
      seed(
        icon: '302',
        temp: '36',
        humidity: '92',
        windScale: '7',
        vis: '1',
        precip: '12',
        air: const AirNow(
          aqi: '180', category: '', primary: '', pm2p5: '', pm10: ''),
      );
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);

      final tips = snap['tips'] as List;
      expect(tips.length, lessThanOrEqualTo(kAppWidgetMaxTips));
      // tipTotal 是「一共有多少条」，和截断后的条数不是一回事
      expect(snap['tipTotal'] as int, greaterThanOrEqualTo(tips.length));
    });

    test('危险级建议排在最前，且带上级别文案与图标名', () {
      seed(icon: '302', text: '雷阵雨');
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);

      final first = (snap['tips'] as List).first as Map;
      expect(first['level'], 'danger');
      expect(first['iconName'], 'flash_on');
      expect(first['levelLabel'], zh.hamLevelDanger);
      // 颜色是给 Kotlin setColorFilter / setTextColor 用的 0xAARRGGBB 整数
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

    test('有今日预报时带上「低温 / 高温」', () {
      seed(daily: [
        const WeatherDaily(
          fxDate: '2026-09-17', tempMax: '25', tempMin: '12',
          iconDay: '100', textDay: '晴'),
      ]);
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      expect((snap['hero'] as Map)['range'], '12° / 25°');
    });

    test('跟随语言：同一天气在中英两种语言下文案不同', () {
      seed();
      final zhSnap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      final enSnap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: en);

      expect((zhSnap['header'] as Map)['observed'],
          isNot((enSnap['header'] as Map)['observed']));
      // 图标名与语言无关，不该跟着变
      expect((zhSnap['hero'] as Map)['iconName'],
          (enSnap['hero'] as Map)['iconName']);
    });
  });

  group('指标按天气排序', () {
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

    test('每个指标格两项都不为空（否则格子里会出现空白）', () {
      for (final icon in ['100', '104', '302', '400', '501']) {
        seed(icon: icon, precip: '1');
        final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
        for (final m in snap['metrics'] as List) {
          final map = m as Map;
          expect(map['label'], isNotEmpty, reason: 'icon=$icon');
          expect(map['value'], isNotEmpty, reason: 'icon=$icon');
        }
        expect((snap['metrics'] as List).length, kAppWidgetMetricCount,
            reason: 'icon=$icon');
      }
    });
  });

  group('天气档位与图标名', () {
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

    test('未知图标代码不抛异常', () {
      seed(icon: '99999');
      expect(() => widgetWeatherKind(WeatherCenter.instance.now!),
          returnsNormally);
    });

    test('天气图标名覆盖日/夜/雷/雨/雪/雾', () {
      expect(widgetWeatherIconName('100'), 'wb_sunny');
      expect(widgetWeatherIconName('150'), 'nights_stay');
      expect(widgetWeatherIconName('101'), 'wb_cloudy');
      expect(widgetWeatherIconName('104'), 'cloud');
      expect(widgetWeatherIconName('302'), 'thunderstorm');
      expect(widgetWeatherIconName('305'), 'grain');
      expect(widgetWeatherIconName('307'), 'water_drop');
      expect(widgetWeatherIconName('400'), 'ac_unit');
      expect(widgetWeatherIconName('503'), 'grain');
      expect(widgetWeatherIconName('501'), 'blur_on');
    });

    test('提示图标名：认识的给专属名，不认识给兜底', () {
      expect(widgetTipIconName(Icons.flash_on_rounded), 'flash_on');
      expect(widgetTipIconName(Icons.power_off_rounded), 'power_off');
      expect(widgetTipIconName(Icons.nightlight_round), 'nightlight');
      expect(widgetTipIconName(Icons.rss_feed_rounded), 'rss_feed');
      // 未登记的新图标不能让组件出现空白格
      expect(widgetTipIconName(Icons.abc), kAppWidgetIconFallback);
    });

    test('面板能发出的每个 HamTip 图标都登记了图标名', () {
      // 把所有可能出现的建议图标都跑一遍：任何一条落到兜底都说明
      // lib/weather.dart 新加了图标而忘了登记（组件上会显示成一个收音机图标，
      // 不报错、只是文不对题）
      seed(
        icon: '302', temp: '36', humidity: '92', windScale: '7', vis: '1',
        precip: '12',
      );
      final tips = hamTips(WeatherCenter.instance, zh);
      expect(tips, isNotEmpty);
      for (final tip in tips) {
        expect(kAppWidgetIconNames.containsKey(tip.icon), isTrue,
            reason: '图标 ${tip.icon} 没有对应的图标名，组件上会退化成 '
                '$kAppWidgetIconFallback');
      }
    });

    test('全部图标名都在生成器产出的集合里（跨语言契约）', () {
      // 清单由 tool/gen_app_widget_icons.py 产出（test/reference/
      // widget_icon_names.json），测试读文件 —— **不手抄**。
      // 原本这份清单是手写在测试里的，于是每加一个图标都要记得改测试，
      // 我这轮加 5 个图标就忘了、测试立刻红。让生成器产出、测试读，
      // 两边就不可能再漂移。
      final produced = {
        ...?(jsonDecode(File('test/reference/widget_icon_names.json')
                .readAsStringSync())['small'] as List?)
            ?.cast<String>(),
      };
      expect(produced, isNotEmpty, reason: '图标名清单是空的，生成器没跑？');
      for (final name in kAppWidgetIconNames.values) {
        expect(produced, contains(name),
            reason: 'Dart 会发出图标名 "$name"，但生成器没有产出它'
                '（组件上会静默退化成兜底图标）');
      }
      for (final code in ['100', '150', '101', '104', '302', '305', '307',
        '400', '503', '501']) {
        expect(produced, contains(widgetWeatherIconName(code)),
            reason: '天气图标名 ${widgetWeatherIconName(code)} 生成器没有产出');
      }
    });
  });

  group('单行档的短文案', () {
    const full = '雷雨天气：请勿在室外架设/操作天线！断开天线馈线，谨防雷击感应损坏设备';

    test('切成从长到短的多个版本，且都是原文的子串', () {
      final v = compactTipVariants(full);
      expect(v, isNotEmpty);
      for (final s in v) {
        expect(full.contains(s.replaceAll('…', '')), isTrue,
            reason: '「$s」不是原文的子串，等于凭空造词');
      }
    });

    test('按长到短排列（shortTipText 依赖这个顺序）', () {
      final v = compactTipVariants(full);
      for (var i = 1; i < v.length; i++) {
        expect(v[i].length, lessThanOrEqualTo(v[i - 1].length),
            reason: '第 $i 项比前一项长，挑选逻辑会挑错');
      }
    });

    test('短文案是完整的短句，不是从句子中间切', () {
      final sh = shortTipText(full);
      expect(sh.length, lessThanOrEqualTo(kAppWidgetShortTextMax));
      expect(full.contains(sh.replaceAll('…', '')), isTrue);
      // 关键：不该出现「请勿在室」这种半截词 —— 必须切在标点处
      expect(sh.contains('！') || sh.endsWith('…'), isTrue,
          reason: '短文案「$sh」没有切在标点处，会读成半截话');
    });

    test('没有标点和冒号的短句：原样返回，不能返回空', () {
      expect(shortTipText('天气良好'), '天气良好');
      expect(compactTipVariants('天气良好'), isNotEmpty);
    });

    test('空串不炸', () {
      expect(compactTipVariants(''), isEmpty);
      expect(compactTipVariants('   '), isEmpty);
      expect(shortTipText(''), '');
    });

    test('英文文案（半角冒号）也能切', () {
      const e = 'High pressure with a stable airmass: tropospheric ducting may '
          'form, try long-distance VHF/UHF contacts';
      final v = compactTipVariants(e);
      expect(v, isNotEmpty);
      for (final s in v) {
        expect(e.contains(s.replaceAll('…', '')), isTrue);
      }
      expect(shortTipText(e).isNotEmpty, isTrue);
    });

    test('每条建议都带了短文案，且优先挑放得下的', () {
      // 契约：shortText 必须是「切出来的版本之一」，而且**只要有任意一版**
      // 不超过上限，就必须挑那一版。
      // 极端情况下可能每一版都超长（比如一条没有标点的长句），此时返回最短的那版、
      // 交给系统省略号处理 —— 这是有意的降级，不是失败。
      seed(icon: '302', text: '雷阵雨');
      final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
      final tips = snap['tips'] as List;
      expect(tips, isNotEmpty);
      for (final t in tips) {
        final map = t as Map;
        final text = map['text'] as String;
        final sh = map['shortText'] as String;
        expect(sh, isNotEmpty);
        final variants = compactTipVariants(text);
        expect(variants, contains(sh),
            reason: 'shortText「$sh」不是切出来的版本之一');
        final fits = variants.where(
            (v) => v.length <= kAppWidgetShortTextMax);
        if (fits.isNotEmpty) {
          expect(sh.length, lessThanOrEqualTo(kAppWidgetShortTextMax),
              reason: '有放得下的版本却挑了超长的「$sh」');
        }
      }
    });
  });

  group('颜色编码', () {
    test('ARGB 编码是 0xAARRGGBB（Kotlin 侧当 int 用）', () {
      expect(colorToArgb(const Color(0xFFE11D48)), 0xFFE11D48);
      expect(colorToArgb(const Color(0x00000000)), 0x00000000);
    });

    test('四个级别的提亮色 = 预览图用的色（跨语言契约）', () {
      // 圆点与提示图标都是「白色 PNG + setColorFilter 染色」，染的就是这个值；
      // 预览图 tool/preview_app_widget.py 的 LEVEL_LIT 必须与之一致，
      // 否则预览会骗人（看着好、装上去另一个色）。
      //
      // 断言**精确值**、不留容差：widgetTipTextArgb 刻意用整数分量运算，
      // 就是为了让 Dart 与 Python 两侧结果确定一致。
      const expected = {
        0xFFE11D48: 0xFFEC6C88, // danger
        0xFFD97706: 0xFFE6A75D, // warn
        0xFF16A34A: 0xFF68C389, // good
        0xFF2563EB: 0xFF719AF2, // tip
      };
      expected.forEach((base, lit) {
        expect(widgetTipTextArgb(Color(base)), lit,
            reason: '基准色 #${base.toRadixString(16)} 的提亮结果与预览不一致');
      });
    });

    test('快照里出现的 level 只有 Kotlin 认识的那 4 个', () {
      // Kotlin 用 level 判断危险级、并用 color 染色。将来 weather.dart 新增级别时
      // 这里必须红 —— 否则新级别在组件上没有自己的颜色，而且不会报错。
      const known = {'danger', 'warn', 'good', 'tip'};
      for (final icon in ['100', '104', '302', '305', '400', '501']) {
        seed(icon: icon, temp: '36', humidity: '90', windScale: '7',
            vis: '1', precip: '8');
        final snap = buildAppWidgetSnapshot(wc: WeatherCenter.instance, s: zh);
        for (final t in snap['tips'] as List) {
          expect(known, contains((t as Map)['level']),
              reason: 'tips 里出现了 Kotlin 不认识的 level');
        }
      }
    });

    test('提示色比原色更亮（压在天气渐变上要能看清）', () {
      const raw = Color(0xFF2563EB); // 深蓝，直接压在晴天渐变上会糊
      final shown = widgetTipTextArgb(raw);
      int lum(int c) => ((c >> 16) & 0xFF) + ((c >> 8) & 0xFF) + (c & 0xFF);
      expect(lum(shown), greaterThan(lum(colorToArgb(raw))));
    });
  });
}
