import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/aprs_parse.dart';
import 'package:aprslocus/services.dart';
import 'package:aprslocus/state.dart';

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
///
/// 还踩过一个更隐蔽的坑（v1.6.103，见下面「发射路径的目的呼号」一组）：
/// 加入 TNC 数据来源时，把写死的 `path: 'APALOC,TCPIP*'` 换成了
/// `path: txPath`，而 `txPath` 在 APRS-IS 模式下返回了通用的
/// `'APRS,TCPIP*'` —— 于是位置包/消息的 tocall 变成 `APRS`，
/// 第三方统计站按 `u/APALOC` 订阅时只能收到状态包、收不到位置包。
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
      expect(raw, 'BG7LZG-9>APALOC,TCPIP*:!3904.25N/11624.44E>');
      expect(raw.endsWith(' '), isFalse);
    });

    test('空/纯空白注释不产生多余分隔', () {
      final a = AprsFmt.position('BG7LZG-9', 39.070833, 116.407333, '>',
          comment: '');
      final b = AprsFmt.position('BG7LZG-9', 39.070833, 116.407333, '>',
          comment: '   ');
      expect(a, 'BG7LZG-9>APALOC,TCPIP*:!3904.25N/11624.44E>');
      expect(b, 'BG7LZG-9>APALOC,TCPIP*:!3904.25N/11624.44E>');
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

  /// 发射路径的目的呼号回归测试
  ///
  /// 事故经过（v1.6.103）：加入蓝牙 TNC 数据来源时，把原本写死的
  /// `path: 'APALOC,TCPIP*'` 改成 `path: txPath`；而 txPath 在
  /// APRS-IS 模式下返回 `'APRS,TCPIP*'`。后果是：
  ///   * 状态包（保活帧，写死 APALOC）照常发出 → 统计站能收到
  ///   * 位置包 / 消息 / ack 的 tocall 变成通用的 `APRS` → 收不到
  /// 外部表现：按 `u/APALOC` 订阅的统计站里这些台站全都「没有位置」。
  /// 下面把「两种数据来源的目的呼号都必须是 APALOC」钉死。
  group('发射路径的目的呼号（必须始终是 APALOC）', () {
    test('APRS-IS 模式：APALOC,TCPIP*', () {
      final st = AppState();
      expect(st.dataSource, AppState.srcAprsIs, reason: '默认数据来源应为 APRS-IS');
      expect(st.usingTnc, isFalse);
      expect(st.txPath, 'APALOC,TCPIP*',
          reason: 'APRS-IS 的报头目的呼号必须是 APALOC，不能是通用的 APRS');
    });

    test('TNC（射频）模式：目的呼号同样是 APALOC，且不带 TCPIP*', () {
      final st = AppState()..dataSource = AppState.srcTnc;
      expect(st.usingTnc, isTrue);
      expect(st.txPath, startsWith('APALOC'));
      expect(st.txPath, isNot(contains('APRS')));
      expect(st.txPath, isNot(contains('TCPIP*')),
          reason: '射频路径不能带 IP 网关才有的 TCPIP*');
    });

    test('位置信标报头用 APALOC（不得出现通用的 APRS）', () {
      final st = AppState();
      final raw = AprsFmt.position('BG7LZG-9', 39.070833, 116.407333, '>',
          comment: 'Bat:88% APRSlocus v1.6.104', path: st.txPath);
      expect(raw, startsWith('BG7LZG-9>APALOC,TCPIP*:'));
      expect(raw.contains('>APRS,'), isFalse,
          reason: '出现 >APRS, 说明目的呼号退回了通用的 APRS');
    });

    test('消息报头也用 APALOC', () {
      final st = AppState();
      expect(AprsFmt.message('BG7LZG-9', 'BG7LZQ', 'hello', '1234',
              path: st.txPath),
          startsWith('BG7LZG-9>APALOC,TCPIP*::BG7LZQ   :'));
    });

    test('默认 path 也是 APALOC（防止漏传 path 又退回通用 APRS）', () {
      expect(AprsFmt.position('BG7LZG-9', 39.070833, 116.407333, '>'),
          startsWith('BG7LZG-9>APALOC,TCPIP*:'));
      expect(AprsFmt.message('BG7LZG-9', 'BG7LZQ', 'hi', '1'),
          startsWith('BG7LZG-9>APALOC,TCPIP*:'));
      expect(AprsFmt.messageNoAck('BG7LZG-9', 'BG7LZQ', 'hi', '1'),
          startsWith('BG7LZG-9>APALOC,TCPIP*:'));
    });
  });
}
