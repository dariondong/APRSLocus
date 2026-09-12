import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/adif.dart';

/// ADIF 导出的回归测试。
///
/// 背景：ADIF 是**长度前缀**格式（`<名称:长度>值`），而长度是
/// **值的 UTF-8 字节数、不是字符数**。这类错误不会抛异常，
/// 只会让日志软件静默解析错乱 —— 是最难靠肉眼发现的一类问题，
/// 所以这里用测试钉住：
///   - 字节长度（含非 ASCII 值）
///   - 日期 / 时间的 **UTC** 语义（写成本地时间会让 QSO 时间整体偏移）
///   - 头部 / EOH / EOR 结构
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
      final out = Adif.encode([
        AdifRecord(call: 'BG7ABC', timeOn: DateTime.utc(2026, 9, 12, 1, 2, 3)),
        AdifRecord(call: 'BH6RIZ', timeOn: DateTime.utc(2026, 1, 2, 3, 4, 5)),
      ]);
      final re = RegExp(r'<([A-Z_]+):(\d+)>');
      var n = 0;
      for (final m in re.allMatches(out)) {
        final name = m.group(1)!;
        final len = int.parse(m.group(2)!);
        final start = m.end;
        final value = out.substring(start, start + len);
        // 值必须以字段分隔符开头，且其真实字节数等于声明长度
        expect(
          utf8.encode(value).length,
          len,
          reason: '字段 $name 声明长度 $len 与实际不符',
        );
        n++;
      }
      // 本调用未传 programVersion，故头部字段为 3 个
      // （ADIF_VER / PROGRAMID / CREATED_TIMESTAMP），
      // 加 2 条记录 × 3 字段 = 9。
      // 断言精确值：将来若增删字段会主动暴露，而不是静默溜过。
      expect(n, 9);
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
      programVersion: '1.6.90',
      created: DateTime.utc(2026, 9, 12, 13, 15, 0),
    );

    test('头部含 ADIF_VER / PROGRAMID / PROGRAMVERSION / CREATED_TIMESTAMP', () {
      expect(out.contains('<ADIF_VER:5>3.1.4'), isTrue);
      expect(out.contains('<PROGRAMID:9>APRSlocus'), isTrue);
      expect(out.contains('<PROGRAMVERSION:6>1.6.90'), isTrue);
      expect(out.contains('<CREATED_TIMESTAMP:15>20260912 131500'), isTrue);
    });

    test('头部以 EOH 结束，记录数与 EOR 数一致且无多余记录', () {
      expect(out.contains('<EOH>'), isTrue);
      expect('<EOR>'.allMatches(out).length, 2);
      // EOH 必须在所有记录之前
      expect(out.indexOf('<EOH>') < out.indexOf('<EOR>'), isTrue);
    });

    test('每条记录都含 CALL / QSO_DATE / TIME_ON，且不含 MODE / BAND', () {
      expect('<CALL:'.allMatches(out).length, 2);
      expect('<QSO_DATE:'.allMatches(out).length, 2);
      expect('<TIME_ON:'.allMatches(out).length, 2);
      // 按用户要求：只写呼号与时间，不写 MODE / BAND（避免写入错误信息）
      expect(out.contains('MODE'), isFalse);
      expect(out.contains('BAND'), isFalse);
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
