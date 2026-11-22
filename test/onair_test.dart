import 'package:flutter_test/flutter_test.dart';

import '../lib/models.dart';
import '../lib/onair.dart';

/// On-Air Friends 的纯逻辑：编码 / 解析 / 频率归一 / 挑在线友台。
///
/// 解析规则是发送端与接收端**同一份**，所以它值得被钉住：一旦只改一边，
/// 自己的包在别人的列表里就消失了，而那种错在界面上完全看不出来。
void main() {
  group('On-Air 编码与解析', () {
    test('往返一致', () {
      const info = OnAirInfo(freq: '145.500', mode: 'FM');
      final token = info.encode();
      expect(token, 'OAF:145.500:FM');
      expect(OnAirInfo.decode('HR=72 $token'), info);
    });

    test('附加参数跟在最后一段，冒号也收', () {
      const info = OnAirInfo(freq: '439.600', mode: 'USB', extra: 'GP 5W');
      final back = OnAirInfo.decode('${info.encode()}');
      expect(back?.extra, 'GP 5W');
      expect(back?.freq, '439.600');
      expect(back?.mode, 'USB');
      expect(OnAirInfo.decode('OAF:7.050:CW:a:b')?.extra, 'a:b');
    });

    test('模式不区分大小写，输出大写', () {
      expect(OnAirInfo.decode('OAF:145.500:c4fm')?.mode, 'C4FM');
    });

    test('没有标记 / 频率不像频率 / 模式不像模式，一律不认', () {
      expect(OnAirInfo.decode('守听 145.500 FM'), isNull);
      expect(OnAirInfo.decode('OAF:abc:FM'), isNull);
      expect(OnAirInfo.decode('OAF:145.500'), isNull);
      expect(OnAirInfo.decode('OAF:145.500:中文'), isNull);
      expect(OnAirInfo.decode(null), isNull);
    });

    test('没填频率时编码是空串（备注里一个字符都不加）', () {
      expect(const OnAirInfo(freq: '').encode(), '');
      expect(const OnAirInfo(freq: '').label, '');
    });

    test('附加参数超长会被截断，不会把整段备注撑爆', () {
      final long = 'x' * 40;
      final info = OnAirInfo(freq: '145.500', mode: 'FM', extra: long);
      const head = 'OAF:145.500:FM:';
      expect(info.encode().length, head.length + OnAirInfo.extraMax);
      expect(info.encode().startsWith(head), isTrue);
    });

    test('一行读数', () {
      expect(const OnAirInfo(freq: '145.500', mode: 'FM').label, '145.500 FM');
      expect(
        const OnAirInfo(freq: '145.500', mode: 'FM', extra: 'GP 5W').label,
        '145.500 FM · GP 5W',
      );
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
        station('BG7LZQ-7', 'OAF:145.500:FM', now.subtract(const Duration(minutes: 1))),
        station('BG5CCC-7', 'OAF:145.500:FM:GP 5W',
            now.subtract(const Duration(minutes: 5))),
        // 没开
        station('BA4XYZ-9', '周末在山上', now.subtract(const Duration(minutes: 2))),
        // 过期
        station('BD3QID-6', 'OAF:439.600:USB',
            now.subtract(const Duration(minutes: 40))),
      ];
      final out = onAirFriendsOf(list, self: 'bg7lzq-7', now: now);
      expect(out.map((f) => f.call).toList(), ['BG5CCC-7']);
      expect(out.first.info.extra, 'GP 5W');
    });

    test('按最后听到倒序', () {
      final list = [
        station('A1AAA-1', 'OAF:145.500:FM', now.subtract(const Duration(minutes: 9))),
        station('A2AAA-2', 'OAF:145.500:FM', now.subtract(const Duration(minutes: 1))),
        station('A3AAA-3', 'OAF:145.500:FM', now.subtract(const Duration(minutes: 5))),
      ];
      final out = onAirFriendsOf(list, now: now);
      expect(out.map((f) => f.call).toList(), ['A2AAA-2', 'A3AAA-3', 'A1AAA-1']);
    });

    test('过期时间可改（界面将来要调就一处）', () {
      final list = [
        station('A1AAA-1', 'OAF:145.500:FM', now.subtract(const Duration(minutes: 40))),
      ];
      expect(onAirFriendsOf(list, now: now), isEmpty);
      expect(
        onAirFriendsOf(list, now: now, ttl: const Duration(hours: 1)).length,
        1,
      );
    });

    test('模式统计：多的在前，同名按字母', () {
      final list = [
        station('A1AAA-1', 'OAF:145.500:FM', now),
        station('A2AAA-2', 'OAF:145.600:USB', now),
        station('A3AAA-3', 'OAF:145.700:FM', now),
        station('A4AAA-4', 'OAF:145.800:AM', now),
      ];
      expect(onAirModesOf(onAirFriendsOf(list, now: now)), ['FM', 'AM', 'USB']);
    });
  });
}
