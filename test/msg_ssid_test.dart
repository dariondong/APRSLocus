import 'package:aprslocus/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 消息接收身份：
///   * 发给我**另一个 SSID** 的消息也要收下（以前直接丢掉，看起来像对方没发到）；
///   * 收下之后气泡上的提示、以及「发送 ID」（`msgSendCall`）的默认值都不能乱跑。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> ready() async {
    final st = AppState();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    st.myCall = 'BG7LZQ';
    st.setSsid('7');
    return st;
  }

  /// 构造一条发给 [to] 的 APRS 消息行
  String line(String to, String text) =>
      'BG5CCC-7>APRS::${to.padRight(9)}:$text{12';

  test('发给本机 ID 的消息照旧收下', () async {
    final st = await ready();
    st.injectRawPacket(line('BG7LZQ-7', 'hello'));
    expect(st.messages.length, 1);
    expect(st.messages.first.text, 'hello');
    expect(st.messages.first.to.toUpperCase(), 'BG7LZQ-7');
  });

  test('发给同一呼号另一个 SSID 的消息也收下', () async {
    final st = await ready();
    st.injectRawPacket(line('BG7LZQ-9', 'to the other device'));
    expect(st.messages.length, 1);
    expect(st.messages.first.text, 'to the other device');
    // `to` 必须留着真实收件人，气泡才知道要提示「这条不是发给本机 ID 的」
    expect(st.messages.first.to.toUpperCase(), 'BG7LZQ-9');
  });

  test('关掉「其他 SSID 的消息也收」后，只收发给本机 ID 的', () async {
    final st = await ready();
    expect(st.acceptOtherSsidMsgs, isTrue); // 默认开
    st.setAcceptOtherSsidMsgs(false);
    st.injectRawPacket(line('BG7LZQ-9', 'to the other device'));
    expect(st.messages, isEmpty);
    // 发给本机 ID 的照旧收
    st.injectRawPacket(line('BG7LZQ-7', 'to me'));
    expect(st.messages.length, 1);
    st.setAcceptOtherSsidMsgs(true);
    st.injectRawPacket(line('BG7LZQ-9', 'again to the other device'));
    expect(st.messages.length, 2);
  });

  test('发给别人呼号的消息仍然丢掉', () async {
    final st = await ready();
    st.injectRawPacket(line('BG5XYZ-3', 'not for me'));
    expect(st.messages, isEmpty);
  });

  test('发送身份默认是本机 ID，可以临时换成另一个 SSID', () async {
    final st = await ready();
    expect(st.msgSendCall, 'BG7LZQ-7');
    st.setMsgSendAs('bg7lzq-9');
    expect(st.msgSendCall, 'BG7LZQ-9');
    // 换回来（等价于界面上点本机 ID 那个按钮）
    st.setMsgSendAs(null);
    expect(st.msgSendCall, 'BG7LZQ-7');
    st.setMsgSendAs('  ');
    expect(st.msgSendCall, 'BG7LZQ-7');
  });
}
