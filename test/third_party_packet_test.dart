import 'package:aprslocus/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 第三方包（DTI `}`）解析回归测试。
///
/// 起因（v1.6.174 用户反馈「TNC 模式没有识别成消息」）：
/// iGate 把互联网上收到的报文转到射频、中继台之间互转时，会把**整条报文**
/// 再用 `}` 包一层，于是射频上收到的信息字段长这样（截图里的原文）：
///
/// ```
/// LX0WX-13>APMI06,TCPIP,LX0WX-13*:}BG7LZQ-2>APALOC,TCPIP,LX0WX-13*::LX6FB-15 :I received it.{5224
/// └──────── 外层：谁在射频上发的 ───────┘└────────── 内层：真正的报文 ──────────┘
/// ```
///
/// 以前不看内层：内层的 `:收件人:文本` 落到默认类型「位置」——
/// 数据包页把消息显示成「位置」（用户看到的就是这个），消息页也一条收不到；
/// 内层是位置包时更彻底：台站根本不上图。
///
/// 这里把「解包后按内层走」钉住：类型、发信台、台站、消息列表、原文保留。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> fresh() async {
    final st = AppState();
    // 构造函数里的 _loadPrefs 是异步的，不等它落地会被它覆盖（见 multi_source 测试）
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return st;
  }

  group('第三方包（DTI `}`）', () {
    test('内层是消息 → 类型是「消息」，不再是默认的「位置」', () async {
      final st = await fresh();
      // 截图里那条（内层收件人不是本机，只影响「进不进消息列表」）
      const line =
          'LX0WX-13>APMI06,TCPIP,LX0WX-13*:'
          '}BG7LZQ-2>APALOC,TCPIP,LX0WX-13*::LX6FB-15 :I received it.{5224';
      st.injectRawPacket(line);

      final p = st.packets.first;
      expect(p.type, 'message', reason: '内层是消息包，不该落到默认的「位置」');
      expect(p.src, 'BG7LZQ-2', reason: '详情里的发信台必须是内层台，不是转递它的那一跳');
      // 信息栏带上「谁转递的」，否则这条与直收的报文长得一模一样
      expect(p.info, contains('[转递 LX0WX-13]'), reason: '要能看出这条是绕了一手来的');
      // 原文仍是**外层**那条：长按复制 / 原始模式看到的必须是真正收到的字节
      expect(p.raw, line);

      st.dispose();
    });

    test('内层消息发给本机 → 进消息列表（这就是用户要的「识别成消息」）', () async {
      final st = await fresh();
      st.injectRawPacket(
        'LX0WX-13>APMI06,TCPIP,LX0WX-13*:'
        '}BG7LZQ-2>APALOC,TCPIP,LX0WX-13*::BV2AAA   :I received it.{5224',
      );

      expect(st.packets.first.type, 'message');
      expect(st.messages, isNotEmpty, reason: '收件人是本机（默认呼号 BV2AAA），必须进消息列表');
      expect(st.messages.first.text, 'I received it.');
      expect(st.messages.first.from, 'BG7LZQ-2', reason: '会话另一头是内层发信台');

      st.dispose();
    });

    test('内层是位置包 → 内层台站上台站列表（以前一个点都上不去）', () async {
      final st = await fresh();
      st.injectRawPacket(
        'LX0WX-13>APMI06,TCPIP,LX0WX-13*:'
        '}DM0AAA>APALOC,TCPIP*:!5001.60N/00838.40E>test',
      );

      final idx = st.stations.indexWhere((s) => s.call == 'DM0AAA');
      expect(idx, isNonNegative, reason: '内层位置包要落到它自己的台站上');
      expect(st.stations[idx].lat, closeTo(50.0267, 0.0005));
      expect(st.stations[idx].lng, closeTo(8.6400, 0.0005));
      // 转递台不是台站：它只是发射了这条包，位置是内层的
      expect(st.stations.any((s) => s.call == 'LX0WX-13'), isFalse);

      st.dispose();
    });

    test('内层不是 TNC2（缺 : 或 >）→ 原样保留，不吞包、不抛异常', () async {
      final st = await fresh();
      st.injectRawPacket('LX0WX-13>APRS,TCPIP*:}garbage>X');

      expect(st.packets, hasLength(1), reason: '畸形报文也要如实展示，不能凭空丢掉');
      final p = st.packets.first;
      expect(p.info, contains('}garbage>X'), reason: '解不了就显示原文');
      expect(p.type, 'position'); // 兜底类型：内层解不了就不算任何已知 DTI

      st.dispose();
    });

    test('套娃两层也能解到最内层，且层数有限不会失控', () async {
      final st = await fresh();
      st.injectRawPacket(
        'REL0Y>APRS:}MID0Y>APRS:}SRC0Y>APALOC::BV2AAA   :nested{4321',
      );

      expect(st.packets.first.src, 'SRC0Y');
      expect(st.packets.first.type, 'message');
      expect(st.messages.first.text, 'nested');

      st.dispose();
    });
  });

  group('对象报告（DTI `;`）', () {
    test('分类成「对象」—— 否则数据包页的「对象」筛选永远筛不出东西', () async {
      final st = await fresh();
      st.injectRawPacket(
        'LX0WX-13>APRS,TCPIP*:;145.5875D*131532z4939.25N/00625.28Er145.587MHz',
      );

      expect(st.packets.first.type, 'object');

      st.dispose();
    });
  });
}
