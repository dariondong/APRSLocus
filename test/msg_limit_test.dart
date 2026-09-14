import 'package:aprslocus/msg_limit.dart';
import 'package:flutter_test/flutter_test.dart';

/// 消息长度预检的回归测试。
///
/// 背景：射频侧一直有 67 字符上限提示，APRS-IS 侧**完全没有**长度预检。
/// 于是长文本在 APRS-IS 上看起来发出去了，对方却解析不出来（或服务器
/// 整包丢弃）。这一层把「太长」分成两种后果，测试要钉死区分。
void main() {
  MsgLimitResult check(String text, {String to = 'BA7KSM', String id = 'AB1'}) =>
      MsgLimit.check(
        from: 'BG7LZQ-9',
        path: 'APALOC,TCPIP*',
        to: to,
        text: text,
        id: id,
      );

  group('APRS 消息长度预检', () {
    test('逐字节核对整包长度（报头 + 9 字符收件人 + 信息字段 + ID）', () {
      // 常量部分的字节数：把公式显式算一遍，防止有人「顺手优化」时改错
      final header = 'BG7LZQ-9>APALOC,TCPIP*::BA7KSM   :'.length;
      final r = check('hello');
      expect(r.packetBytes, header + 'hello'.length + '{AB1'.length);
      expect(r.textChars, 5);
      expect(r.textBytes, 5);
      expect(r.fit, MsgFit.ok);
    });

    test('67 字符正好等于上限（允许），68 才超', () {
      expect(check('a' * 67).fit, MsgFit.ok);
      expect(check('a' * 67).textChars, 67);
      expect(check('a' * 68).fit, MsgFit.overSpec);
      expect(check('a' * 68).textChars, 68);
    });

    test('中文按字符计数、按 UTF-8 计字节：两者必须分开报', () {
      final r = check('测试' * 34); // 68 个字符
      expect(r.textChars, 68, reason: '中文一字算一个字符');
      expect(r.textBytes, 68 * 3, reason: 'UTF-8 下中文一字 3 字节');
      expect(r.fit, MsgFit.overSpec);
      // 34 个中文 = 102 字节，整包仍未到 512，所以是「可能解析不出来」而非被拦
      expect(r.packetBytes, lessThan(aprsIsMaxLineBytes));
    });

    test('整包超 512 字节 → overServerLimit（会被服务器丢弃，必须拦）', () {
      final r = check('x' * 600);
      expect(r.packetBytes, greaterThan(aprsIsMaxLineBytes));
      expect(r.fit, MsgFit.overServerLimit);
      expect(r.bytesLeft, lessThan(0), reason: '超出时 bytesLeft 应为负，UI 取其相反数显示');
    });

    test('emoji/代理对按码点计数，不虚增字符数', () {
      final r = check('📡' * 10);
      expect(r.textChars, 10, reason: '代理对不能算成 20 个字符');
      expect(r.fit, MsgFit.ok);
    });

    test('收件人短于 9 字符要按 9 补位（APRS101 固定字段）', () {
      final short = check('hi', to: 'A');
      expect(short.packetBytes, check('hi', to: 'A'.padRight(9)).packetBytes);
    });

    test('无 ID 时不计 {id 的字节', () {
      final withId = MsgLimit.check(
          from: 'X', path: 'P', to: 'Y', text: 'z', id: 'AB1');
      final noId = MsgLimit.check(from: 'X', path: 'P', to: 'Y', text: 'z');
      expect(withId.packetBytes - noId.packetBytes, 4); // '{AB1'
    });
  });
}
