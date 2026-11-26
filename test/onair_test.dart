import 'package:flutter_test/flutter_test.dart';

import '../lib/models.dart';
import '../lib/onair.dart';
import '../lib/satellite.dart';

/// On-Air Friends 的纯逻辑：编码 / 解析 / 频率归一 / 挑在线友台。
///
/// 编码已改用 APRS 的 **AFRS / QSY 标准**（`145.500MHz`），不再用私有的
/// `OAF:` 标记；旧标记仍能解析（兼容已经在网上跑的老报文）。
void main() {
  group('On-Air 编码（AFRS / QSY 标准）', () {
    test('往返一致', () {
      const info = OnAirInfo(freq: '145.500', mode: 'FM');
      final token = info.encode();
      expect(token, '145.500MHz FM');
      expect(OnAirInfo.decode('HR=72 $token'), info);
    });

    test('附加参数跟在模式后面', () {
      const info = OnAirInfo(freq: '439.600', mode: 'USB', extra: 'GP 5W');
      expect(info.encode(), '439.600MHz USB GP 5W');
      final back = OnAirInfo.decode(info.encode());
      expect(back?.extra, 'GP 5W');
      expect(back?.freq, '439.600');
      expect(back?.mode, 'USB');
    });

    test('音调/偏移按 AFRS 标准顺序排在频率后面', () {
      const info = OnAirInfo(
        freq: '145.500',
        mode: 'FM',
        extra: 'T107 +060 GP 5W',
      );
      expect(info.encode(), '145.500MHz T107 +060 FM GP 5W');
      final back = OnAirInfo.decode(info.encode());
      expect(back?.freq, '145.500');
      expect(back?.tone, 'T107');
      expect(back?.offset, '+060');
      expect(back?.mode, 'FM');
      expect(back?.extra, 'GP 5W');
      expect(back?.label, '145.500 FM · T107 +060 · GP 5W');
    });

    test('模式不区分大小写，输出大写', () {
      expect(OnAirInfo.decode('145.500MHz c4fm')?.mode, 'C4FM');
    });

    test('没填频率时编码是空串（备注里一个字符都不加）', () {
      expect(const OnAirInfo(freq: '').encode(), '');
      expect(const OnAirInfo(freq: '').label, '');
    });

    test('附加参数超长会被截断，不会把整段备注撑爆', () {
      final long = 'x' * 40;
      final info = OnAirInfo(freq: '145.500', mode: 'FM', extra: long);
      const head = '145.500MHz FM ';
      expect(info.encode().length, head.length + OnAirInfo.extraMax);
      expect(info.encode(), head + 'x' * OnAirInfo.extraMax);
    });

    test('一行读数', () {
      expect(const OnAirInfo(freq: '145.500', mode: 'FM').label, '145.500 FM');
      expect(
        const OnAirInfo(freq: '145.500', mode: 'FM', extra: 'GP 5W').label,
        '145.500 FM · GP 5W',
      );
    });
  });

  group('标准备注解析（第三方电台）', () {
    test('Kenwood/Yaesu 常见的 FFF.FF MHz + Tnnn', () {
      final info = OnAirInfo.decode('146.82 MHz T107 AARC Repeater');
      expect(info, isNotNull);
      expect(info!.freq, '146.820');
      expect(info.mode, 'FM'); // AFRS 没有模式字段，默认话音
      expect(info.tone, 'T107');
      expect(info.extra, 'AARC Repeater');
    });

    test('1 kHz 分辨率 + 偏移', () {
      final info = OnAirInfo.decode('442.440MHz T107 -500 Repeater');
      expect(info!.freq, '442.440');
      expect(info.tone, 'T107');
      expect(info.offset, '-500');
      expect(info.extra, 'Repeater');
    });

    test('小写 t（窄带）与自由文本', () {
      final info = OnAirInfo.decode('145.50 MHz t077 Simplex');
      expect(info!.freq, '145.500');
      expect(info.tone, 't077');
      expect(info.extra, 'Simplex');
    });

    test('显式模式被识别，不混进附加参数', () {
      final info = OnAirInfo.decode('439.600MHz USB GP 5W');
      expect(info!.mode, 'USB');
      expect(info.extra, 'GP 5W');
    });

    test('频率前面有分隔符也认', () {
      final info = OnAirInfo.decode('PHG5950/A=001234/145.500MHz FM');
      expect(info!.freq, '145.500');
      expect(info.mode, 'FM');
    });

    test('OAS 卫星段不混进附加参数', () {
      const c = '438.500MHz FM OAS:ISS:0548Z';
      final info = OnAirInfo.decode(c);
      expect(info!.freq, '438.500');
      expect(info.mode, 'FM');
      expect(info.extra, '');
      expect(SatQso.decode(c)!.name, 'ISS');
    });

    test('没有 MHz 的普通备注不认', () {
      expect(OnAirInfo.decode('守听 145.500 FM'), isNull);
      expect(OnAirInfo.decode('HR=72 Bat:80%'), isNull);
      expect(OnAirInfo.decode(''), isNull);
      expect(OnAirInfo.decode(null), isNull);
    });
  });

  group('收到的标准 QSY 报文', () {
    test('? / ! / . 与无后缀', () {
      final q1 = QsyRequest.parse('QSY 145.500MHz?');
      expect(q1!.freq, '145.500');
      expect(q1.suffix, '?');
      final q2 = QsyRequest.parse('qsy 145.5 MHz!');
      expect(q2!.freq, '145.500');
      expect(q2.suffix, '!');
      final q3 = QsyRequest.parse('QSY 145.500MHz.');
      expect(q3!.suffix, '.');
      final q4 = QsyRequest.parse('QSY 145.500MHz');
      expect(q4!.suffix, '');
    });

    test('允许末尾带一句说明', () {
      final q = QsyRequest.parse('QSY 145.500MHz? please');
      expect(q!.freq, '145.500');
      expect(q.suffix, '?');
    });

    test('不是 QSY 或频率非法时不认', () {
      expect(QsyRequest.parse('hello'), isNull);
      expect(QsyRequest.parse('QSY abc'), isNull);
      expect(QsyRequest.parse('QSY 9999MHz'), isNull);
    });
  });

  group('旧版 OAF 兼容', () {
    test('旧标记仍然能解析', () {
      final info = OnAirInfo.decode('HR=72 OAF:145.500:FM');
      expect(info!.freq, '145.500');
      expect(info.mode, 'FM');
      expect(OnAirInfo.decode('OAF:7.050:CW:a:b')?.extra, 'a:b');
    });

    test('OAF 后跟 OAS 时仍然认得出来', () {
      const c = '212/000/A=000000 Bat:53% OAF:438.500:FM OAS:ISS:0548Z';
      final info = OnAirInfo.decode(c);
      expect(info, isNotNull);
      expect(info!.freq, '438.500');
      expect(info.mode, 'FM');
      expect(info.extra, '');
    });

    test('旧标记格式不对时不认', () {
      expect(OnAirInfo.decode('OAF:abc:FM'), isNull);
      expect(OnAirInfo.decode('OAF:145.500'), isNull);
      expect(OnAirInfo.decode('OAF:145.500:中文'), isNull);
    });
  });

  group('频率归一', () {
    test('带小数点按 MHz 读', () {
      expect(normalizeOnAirFreq('145.5'), '145.500');
      expect(normalizeOnAirFreq(' 145.500 '), '145.500');
      expect(normalizeOnAirFreq('7.05'), '7.050');
    });

    test('纯数字按位数猜单位', () {
      expect(normalizeOnAirFreq('145'), '145.000');
      expect(normalizeOnAirFreq('145500'), '145.500');
      expect(normalizeOnAirFreq('145500000'), '145.500');
    });

    test('单位后缀认', () {
      expect(normalizeOnAirFreq('145.500 MHz'), '145.500');
      expect(normalizeOnAirFreq('145500khz'), '145.500');
    });

    test('填不成返回空串（界面据此提示，不悄悄改值）', () {
      expect(normalizeOnAirFreq(''), '');
      expect(normalizeOnAirFreq('abc'), '');
      expect(normalizeOnAirFreq('0'), '');
      expect(normalizeOnAirFreq('9999'), '');
    });
  });

  group('在线友台', () {
    Station station(String call, String? comment, DateTime at) => Station(
          call: call,
          symbol: '>',
          lat: 0,
          lng: 0,
          lastHeard: at,
          comment: comment,
        );

    final now = DateTime(2026, 11, 22, 12, 0);

    test('只挑开着且没过期的，自己不算', () {
      final list = [
        station('BG7LZQ-7', '145.500MHz FM',
            now.subtract(const Duration(minutes: 1))),
        station('BG5CCC-7', '145.500MHz FM GP 5W',
            now.subtract(const Duration(minutes: 5))),
        // 没开
        station('BA4XYZ-9', '周末在山上', now.subtract(const Duration(minutes: 2))),
        // 过期
        station('BD3QID-6', '439.600MHz USB',
            now.subtract(const Duration(minutes: 40))),
      ];
      final out = onAirFriendsOf(list, self: 'bg7lzq-7', now: now);
      expect(out.map((f) => f.call).toList(), ['BG5CCC-7']);
      expect(out.first.info.extra, 'GP 5W');
    });

    test('按最后听到倒序', () {
      final list = [
        station('A1AAA-1', '145.500MHz FM',
            now.subtract(const Duration(minutes: 9))),
        station('A2AAA-2', '145.500MHz FM',
            now.subtract(const Duration(minutes: 1))),
        station('A3AAA-3', '145.500MHz FM',
            now.subtract(const Duration(minutes: 5))),
      ];
      final out = onAirFriendsOf(list, now: now);
      expect(out.map((f) => f.call).toList(), ['A2AAA-2', 'A3AAA-3', 'A1AAA-1']);
    });

    test('过期时间可改（界面将来要调就一处）', () {
      final list = [
        station('A1AAA-1', '145.500MHz FM',
            now.subtract(const Duration(minutes: 40))),
      ];
      expect(onAirFriendsOf(list, now: now), isEmpty);
      expect(
        onAirFriendsOf(list, now: now, ttl: const Duration(hours: 1)).length,
        1,
      );
    });

    test('模式统计：多的在前，同名按字母', () {
      final list = [
        station('A1AAA-1', '145.500MHz FM', now),
        station('A2AAA-2', '145.600MHz USB', now),
        station('A3AAA-3', '145.700MHz FM', now),
        station('A4AAA-4', '145.800MHz AM', now),
      ];
      expect(onAirModesOf(onAirFriendsOf(list, now: now)), ['FM', 'AM', 'USB']);
    });
  });
}
