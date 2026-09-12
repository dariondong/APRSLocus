import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/adif.dart';

/// ADIF 导出的回归测试。
///
/// 背景一：ADIF 是**长度前缀**格式（`<名称:长度>值`），而长度是
/// **值的 UTF-8 字节数、不是字符数**。这类错误不会抛异常，
/// 只会让日志软件静默解析错乱 —— 最难靠肉眼发现，所以用测试钉住。
///
/// 背景二（真实踩坑）：早期版本为了「不写入不确定的信息」而**完全省略 MODE**，
/// 结果 QRZ Logbook 报「缺少 MODE」并**拒收全部记录**。所以现在默认写
/// `MODE=PKT` + `SUBMODE=APRS`，且做成用户可选。本文件把
/// 「默认必须有 MODE」「SUBMODE 不得脱离 MODE」都钉住。
void main() {
  group('ADIF 字段编码', () {
    test('长度是 UTF-8 字节数，不是字符数', () {
      // 3 个中日韩字符 = 9 字节（每个 3 字节），若按字符数会写成 :3
      final out = Adif.encode([
        AdifRecord(call: '测试台', timeOn: DateTime.utc(2026, 9, 12, 1, 2, 3)),
      ]);
      expect(out.contains('<CALL:9>测试台'), isTrue);
      expect(out.contains('<CALL:3>'), isFalse);
    });

    test('ASCII 呼号长度等于字符数', () {
      final out = Adif.encode([
        AdifRecord(call: 'BG7ABC', timeOn: DateTime.utc(2026, 9, 12)),
      ]);
      expect(out.contains('<CALL:6>BG7ABC'), isTrue);
    });

    test('呼号统一转大写并去除首尾空白', () {
      final out = Adif.encode([
        AdifRecord(call: '  bg7abc ', timeOn: DateTime.utc(2026, 9, 12)),
      ]);
      expect(out.contains('<CALL:6>BG7ABC'), isTrue);
      // 长度必须按**转换后**的值算，否则长度与值不一致
      expect(out.contains('<CALL:8>'), isFalse);
    });

    test('每个字段的长度与紧随其后的值自洽（全串扫描）', () {
      final out = Adif.encode(
        [
          AdifRecord(call: 'BG7ABC', timeOn: DateTime.utc(2026, 9, 12, 1, 2, 3)),
          AdifRecord(call: 'BH6RIZ', timeOn: DateTime.utc(2026, 1, 2, 3, 4, 5)),
        ],
        options: const AdifOptions(mode: 'PKT', subModeAprs: true),
      );
      final re = RegExp(r'<([A-Z_]+):(\d+)>');
      var n = 0;
      for (final m in re.allMatches(out)) {
        final name = m.group(1)!;
        final len = int.parse(m.group(2)!);
        final start = m.end;
        final value = out.substring(start, start + len);
        expect(
          utf8.encode(value).length,
          len,
          reason: '字段 $name 声明长度 $len 与实际不符',
        );
        n++;
      }
      // 本调用未传 programVersion，故头部字段为 3 个
      // （ADIF_VER / PROGRAMID / CREATED_TIMESTAMP）；
      // 每条记录 5 个字段（CALL/QSO_DATE/TIME_ON/MODE/SUBMODE），2 条 = 10。
      // 断言精确值：将来若增删字段会主动暴露，而不是静默溜过。
      expect(n, 13);
    });
  });

  group('ADIF 日期与时间（必须 UTC）', () {
    test('本地时间按 UTC 写出（与运行机器时区无关的等价性检查）', () {
      // 传本地墙上时间，写出的必须是它的 UTC 等价时刻。
      // 若实现漏掉 toUtc()，在非 UTC 时区的机器上就会整体偏移 ——
      // 该断言在任何时区下都成立，因此不会随机器而假绿。
      final local = DateTime(2026, 9, 12, 13, 15, 0);
      final u = local.toUtc();
      final out = Adif.encode([AdifRecord(call: 'BG7ABC', timeOn: local)]);
      expect(out.contains('<QSO_DATE:8>${Adif.dateOf(u)}'), isTrue);
      expect(out.contains('<TIME_ON:6>${Adif.timeOf(u)}'), isTrue);
    });

    test('dateOf / timeOf 补零正确', () {
      final t = DateTime.utc(2026, 1, 2, 3, 4, 5);
      expect(Adif.dateOf(t), '20260102');
      expect(Adif.timeOf(t), '030405');
    });

    test('时间跨日时日期与时间同时正确', () {
      final out = Adif.encode([
        AdifRecord(call: 'BG7ABC', timeOn: DateTime.utc(2026, 12, 31, 23, 59, 59)),
      ]);
      expect(out.contains('<QSO_DATE:8>20261231'), isTrue);
      expect(out.contains('<TIME_ON:6>235959'), isTrue);
    });
  });

  group('ADIF 结构', () {
    final out = Adif.encode(
      [
        AdifRecord(call: 'BG7ABC', timeOn: DateTime.utc(2026, 9, 12, 1, 2, 3)),
        AdifRecord(call: 'BH6RIZ', timeOn: DateTime.utc(2026, 9, 13, 4, 5, 6)),
      ],
      programVersion: '1.6.91',
      created: DateTime.utc(2026, 9, 12, 13, 15, 0),
    );

    test('头部含 ADIF_VER / PROGRAMID / PROGRAMVERSION / CREATED_TIMESTAMP', () {
      expect(out.contains('<ADIF_VER:5>3.1.4'), isTrue);
      expect(out.contains('<PROGRAMID:9>APRSlocus'), isTrue);
      expect(out.contains('<PROGRAMVERSION:6>1.6.91'), isTrue);
      expect(out.contains('<CREATED_TIMESTAMP:15>20260912 131500'), isTrue);
    });

    test('头部以 EOH 结束，记录数与 EOR 数一致且无多余记录', () {
      expect(out.contains('<EOH>'), isTrue);
      expect('<EOR>'.allMatches(out).length, 2);
      expect(out.indexOf('<EOH>') < out.indexOf('<EOR>'), isTrue);
    });

    test('每条记录都含 CALL / QSO_DATE / TIME_ON', () {
      expect('<CALL:'.allMatches(out).length, 2);
      expect('<QSO_DATE:'.allMatches(out).length, 2);
      expect('<TIME_ON:'.allMatches(out).length, 2);
    });

    test('空记录列表仍产出合法头部（不产生 EOR）', () {
      final empty = Adif.encode([], created: DateTime.utc(2026, 9, 12));
      expect(empty.contains('<EOH>'), isTrue);
      expect(empty.contains('<EOR>'), isFalse);
    });

    test('不写 PROGRAMVERSION 时该字段整体不出现', () {
      final noVer = Adif.encode([], created: DateTime.utc(2026, 9, 12));
      expect(noVer.contains('PROGRAMVERSION'), isFalse);
    });
  });

  // ─── 用户可选选项（本次新增，直接对应 QRZ 拒收问题）───
  group('ADIF 导出选项：MODE / SUBMODE', () {
    final r = AdifRecord(call: 'BG6XVJ', timeOn: DateTime.utc(2026, 9, 12, 13, 58));

    test('默认必写 MODE=PKT 与 SUBMODE=APRS（修复 QRZ 拒收）', () {
      final out = Adif.encode([r]);
      expect(out.contains('<MODE:3>PKT'), isTrue);
      expect(out.contains('<SUBMODE:4>APRS'), isTrue);
    });

    test('MODE 值长度按字节数正确（PKT=3 / FM=2 / DATA=4）', () {
      expect(
        Adif.encode([r], options: const AdifOptions(mode: 'PKT'))
            .contains('<MODE:3>PKT'),
        isTrue,
      );
      expect(
        Adif.encode([r], options: const AdifOptions(mode: 'FM'))
            .contains('<MODE:2>FM'),
        isTrue,
      );
      expect(
        Adif.encode([r], options: const AdifOptions(mode: 'DATA'))
            .contains('<MODE:4>DATA'),
        isTrue,
      );
    });

    test('mode 为 null 时 MODE 与 SUBMODE 都不写', () {
      final out = Adif.encode([r], options: const AdifOptions(mode: null));
      expect(out.contains('MODE'), isFalse);
    });

    test('SUBMODE 不得脱离 MODE 单独出现（ADIF 规定）', () {
      // 即使显式要求 subModeAprs，只要没有 MODE 就必须一并省略
      final out = Adif.encode(
        [r],
        options: const AdifOptions(mode: null, subModeAprs: true),
      );
      expect(out.contains('SUBMODE'), isFalse);
    });

    test('关闭 subModeAprs 时只写 MODE', () {
      final out = Adif.encode(
        [r],
        options: const AdifOptions(mode: 'PKT', subModeAprs: false),
      );
      expect(out.contains('<MODE:3>PKT'), isTrue);
      expect(out.contains('SUBMODE'), isFalse);
    });

    test('用户可选的 MODE / BAND 候选值都产出合法字段', () {
      for (final m in Adif.modeChoices) {
        final out = Adif.encode([r], options: AdifOptions(mode: m));
        expect(out.contains('MODE'), m != null);
        expect(out.contains('SUBMODE'), m != null);
      }
      for (final b in Adif.bandChoices) {
        final out = Adif.encode([r], options: AdifOptions(band: b));
        expect(out.contains('BAND'), b != null);
      }
    });
  });

  group('ADIF 导出选项：BAND', () {
    final r = AdifRecord(call: 'BG6XVJ', timeOn: DateTime.utc(2026, 9, 12));

    test('默认不写 BAND（APRS 实际频段 App 无从得知）', () {
      expect(Adif.encode([r]).contains('BAND'), isFalse);
    });

    test('指定 BAND 时按 ADIF 标准写法输出', () {
      expect(
        Adif.encode([r], options: const AdifOptions(band: '2m'))
            .contains('<BAND:2>2m'),
        isTrue,
      );
      expect(
        Adif.encode([r], options: const AdifOptions(band: '70cm'))
            .contains('<BAND:4>70cm'),
        isTrue,
      );
    });
  });

  group('ADIF 导出选项：呼号 SSID', () {
    test('stripSsid 去掉 -SSID，保留基础呼号', () {
      expect(Adif.stripSsid('BG7PGW-2'), 'BG7PGW');
      expect(Adif.stripSsid('PY1RV-7'), 'PY1RV');
    });

    test('无 SSID 的呼号原样返回', () {
      expect(Adif.stripSsid('BG6XVJ'), 'BG6XVJ');
    });

    test('畸形输入（连字符在首位）不被破坏', () {
      // 防御性：不应把 '-2' 截成空串
      expect(Adif.stripSsid('-2'), '-2');
    });

    test('默认不改写呼号；开启后写出基础呼号且长度正确', () {
      final r = AdifRecord(call: 'BG7PGW-2', timeOn: DateTime.utc(2026, 9, 12));
      expect(Adif.encode([r]).contains('<CALL:8>BG7PGW-2'), isTrue);
      final stripped = Adif.encode([r], options: const AdifOptions(stripSsid: true));
      // BG7PGW = 6 字符（不是 7）
      expect(stripped.contains('<CALL:6>BG7PGW'), isTrue);
      expect(stripped.contains('BG7PGW-2'), isFalse);
    });
  });

  group('ADIF 导出选项：频率 FREQ', () {
    final r = AdifRecord(call: 'BG6XVJ', timeOn: DateTime.utc(2026, 9, 12));

    test('默认不写 FREQ（各地 APRS 频率不同，App 无从得知）', () {
      expect(Adif.encode([r]).contains('FREQ'), isFalse);
    });

    test('指定 FREQ 时按 MHz 写出，且长度按字节数正确', () {
      expect(
        Adif.encode([r], options: const AdifOptions(freq: '144.640'))
            .contains('<FREQ:7>144.640'),
        isTrue,
      );
      // HF 频率位数较少
      expect(
        Adif.encode([r], options: const AdifOptions(freq: '7.035'))
            .contains('<FREQ:5>7.035'),
        isTrue,
      );
    });

    test('FREQ 与 BAND 可同时存在，且都写在 EOR 之前', () {
      final out = Adif.encode(
        [r],
        options: const AdifOptions(band: '2m', freq: '144.640'),
      );
      expect(out.contains('<BAND:2>2m'), isTrue);
      expect(out.contains('<FREQ:7>144.640'), isTrue);
      expect(out.indexOf('FREQ') < out.indexOf('<EOR>'), isTrue);
    });

    test('规范化：去空白 / 去 MHz 后缀 / 逗号转点', () {
      expect(Adif.normalizeFreq('144.640'), '144.640');
      expect(Adif.normalizeFreq('  144.640  '), '144.640');
      expect(Adif.normalizeFreq('144,640'), '144.640');
      expect(Adif.normalizeFreq('144.640MHz'), '144.640');
      expect(Adif.normalizeFreq('144.640 MHz'), '144.640');
      expect(Adif.normalizeFreq('144'), '144');
    });

    test('逗号必须被转成点（ADIF 与语言环境无关）', () {
      // 若原样写 <FREQ:7>144,640，欧/法语区日志软件会解析错位
      final n = Adif.normalizeFreq('144,640');
      expect(n, isNotNull);
      expect(n!.contains(','), isFalse);
      final out = Adif.encode([r], options: AdifOptions(freq: n));
      expect(out.contains(','), isFalse);
    });

    test('非法输入一律返回 null（宁可不写，不写错值）', () {
      for (final bad in [
        '', '   ', 'abc', '144.', '.5', '0', '0.0', '-144',
        '144.640.1', '99999', '1e3', '３６５',
      ]) {
        expect(Adif.normalizeFreq(bad), isNull, reason: '应拒绝: $bad');
      }
      // 上边界允许
      expect(Adif.normalizeFreq('30000'), '30000');
    });

    test('常用频率预设本身都是合法值（否则快选会填进非法值）', () {
      expect(Adif.freqPresets, isNotEmpty);
      for (final f in Adif.freqPresets) {
        expect(Adif.normalizeFreq(f), f, reason: '预设不合法: $f');
      }
    });
  });

  group('界面「预览」与实际写出必须完全一致', () {
    test('record() 是 encode() 输出的组成部分', () {
      // 预览如果和实际写出走两条代码路径，就会骗人 ——
      // 这条断言保证两者同源。
      final r = AdifRecord(call: 'BG7PGW-2', timeOn: DateTime.utc(2026, 9, 12, 1, 2, 3));
      for (final o in const [
        AdifOptions(),
        AdifOptions(mode: null, subModeAprs: false),
        AdifOptions(mode: 'FM', subModeAprs: false, band: '2m'),
        AdifOptions(stripSsid: true, band: '70cm'),
        AdifOptions(band: '2m', freq: '144.640'),
      ]) {
        final full = Adif.encode(
          [r],
          options: o,
          created: DateTime.utc(2026, 9, 12),
        );
        expect(
          full.contains(Adif.record(r, o)),
          isTrue,
          reason: '预览与实际输出不一致：$o',
        );
      }
    });
  });

  group('ADIF 文件名', () {
    test('按本地时间取名为 APRSlocus_yyyyMMdd_HHmmss.adi', () {
      expect(
        Adif.fileName(DateTime(2026, 9, 12, 13, 15, 0)),
        'APRSlocus_20260912_131500.adi',
      );
    });

    test('个位数月日时分秒补零', () {
      expect(
        Adif.fileName(DateTime(2026, 1, 2, 3, 4, 5)),
        'APRSlocus_20260102_030405.adi',
      );
    });
  });
}
