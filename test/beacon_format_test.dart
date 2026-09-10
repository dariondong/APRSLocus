import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/aprs_parse.dart';
import 'package:aprslocus/services.dart';

/// 发送侧报文格式的回归测试。
///
/// 背景（真实踩过的坑）：`AprsFmt.position()` 曾在注释前拼了一个空格：
///   `...E> 123/045/A=000100 ...`
/// APRS101 规定注释（含 CsT `ddd/sss`）必须**紧跟**位置字段、无分隔符。
/// 第三方解析器（aprs.fi / aprslib）普遍用 `^(\d{3})/(\d{3})` 锚定注释行首，
/// 前导空格会让它匹配失败 —— 结果速度与方位角被当成普通备注文字显示，
/// 即用户反馈的「第三方地图里速度与方位角出现在备注里」。
///
/// 期望值经参考实现 aprslib 实测：带空格 → course/speed 为 None；
/// 无空格 → course=123、speed=83.34 km/h、comment 中不含 `ddd/sss`。
void main() {
  group('信标报文格式（第三方兼容性）', () {
    test('注释必须紧跟符号，中间不得有空格', () {
      final raw = AprsFmt.position(
        'BG7LZG-9',
        39.070833,
        116.407333,
        '>',
        comment: '123/045/A=000100 Bat:88% APRSlocus v1.6.67',
        path: 'APALOC,TCPIP*',
      );

      // 精确钉死格式（含注释位置）
      expect(
        raw,
        'BG7LZG-9>APALOC,TCPIP*:!3904.25N/11624.44E>'
        '123/045/A=000100 Bat:88% APRSlocus v1.6.67',
      );

      // 核心断言：符号 '>' 之后不得紧跟空格
      final info = raw.substring(raw.indexOf(':') + 1);
      final symIdx = info.indexOf('>');
      expect(symIdx, greaterThan(0));
      expect(info[symIdx + 1], isNot(' '),
          reason: '符号后出现空格会让第三方把 CsT 当备注文字（本 bug 曾出现）');
    });

    test('无注释时不应残留尾部空格', () {
      final raw = AprsFmt.position('BG7LZG-9', 39.070833, 116.407333, '>');
      expect(raw, 'BG7LZG-9>APRS,TCPIP*:!3904.25N/11624.44E>');
      expect(raw.endsWith(' '), isFalse);
    });

    test('空/纯空白注释不产生多余分隔', () {
      final a = AprsFmt.position('BG7LZG-9', 39.070833, 116.407333, '>',
          comment: '');
      final b = AprsFmt.position('BG7LZG-9', 39.070833, 116.407333, '>',
          comment: '   ');
      expect(a, 'BG7LZG-9>APRS,TCPIP*:!3904.25N/11624.44E>');
      expect(b, 'BG7LZG-9>APRS,TCPIP*:!3904.25N/11624.44E>');
    });

    test('自产报文能被自家解析器正确解出速度/方位角，且备注不残留 CsT', () {
      final raw = AprsFmt.position(
        'BG7LZG-9',
        39.070833,
        116.407333,
        '>',
        comment: '123/045/A=000100 Bat:88% APRSlocus v1.6.67',
        path: 'APALOC,TCPIP*',
      );
      // 从完整报文里取出信息字段（: 之后）作为位置帧体
      final body = raw.substring(raw.indexOf(':') + 1);
      final p = parseAprsPosition(body, dest: 'APALOC');
      expect(p, isNotNull, reason: '自产报文应可被解析');
      expect(p!.course, closeTo(123, 0.5));
      expect(p.speed, closeTo(83.34, 0.5)); // 45 节
      expect(p.alt, closeTo(30.48, 0.5)); // 100 ft
      expect(p.comment, 'Bat:88% APRSlocus v1.6.67');
      expect(RegExp(r'\d{3}/\d{3}').hasMatch(p.comment ?? ''), isFalse,
          reason: '备注中不应残留 ddd/sss');
    });
  });
}
