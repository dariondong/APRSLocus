import 'package:aprslocus/ssid_remote.dart';
import 'package:aprslocus/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「我的其他 SSID」远程指令（`!AL ACT/BCN/STP`）。
///
/// 两条都不能错：
///   * 指令格式必须一眼辨得出来（日常聊天不能被当成指令）；
///   * 只有**同一基础呼号**发来的才执行 —— 别人发 `!AL STP` 就能关掉你的上报，
///     那是个能被利用的洞，所以这条要钉在 CI 里。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('指令解析', () {
    test('三个指令都认', () {
      expect(parseSsidCommand('!AL ACT'), SsidCmd.activate);
      expect(parseSsidCommand('!al bcn'), SsidCmd.beacon);
      expect(parseSsidCommand('  !AL STP  '), SsidCmd.stop);
    });

    test('后面跟一句说明也认', () {
      expect(parseSsidCommand('!AL STP 电量低'), SsidCmd.stop);
    });

    test('普通聊天不是指令', () {
      expect(parseSsidCommand('hello'), isNull);
      expect(parseSsidCommand('AL ACT'), isNull);
      expect(parseSsidCommand('!AL'), isNull);
      expect(parseSsidCommand('!AL XYZ'), isNull);
    });

    test('构造与解析对称', () {
      for (final c in SsidCmd.values) {
        expect(parseSsidCommand(ssidCmdText(c)), c);
      }
    });
  });

  group('执行边界', () {
    Future<AppState> ready() async {
      final st = AppState();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      st.myCall = 'BG7LZQ';
      st.setSsid('7');
      return st;
    }

    String line(String from, String to, String text) =>
        '$from>APRS::${to.padRight(9)}:$text{12';

    test('同呼号的另一个 SSID 可以停止上报', () async {
      final st = await ready();
      st.beaconEnabled = true;
      st.injectRawPacket(line('BG7LZQ-9', 'BG7LZQ-7', '!AL STP'));
      expect(st.beaconEnabled, isFalse);
      // 指令本身也进会话，用户看得见自己另一台设备被下了什么指令
      expect(st.messages.length, 1);
    });

    test('外人发来的指令一律不执行', () async {
      final st = await ready();
      st.beaconEnabled = true;
      st.injectRawPacket(line('BG5CCC-7', 'BG7LZQ-7', '!AL STP'));
      expect(st.beaconEnabled, isTrue);
    });

    test('自己发出去的指令不会回灌执行', () async {
      final st = await ready();
      st.beaconEnabled = true;
      st.injectRawPacket(line('BG7LZQ-7', 'BG7LZQ-9', '!AL STP'));
      expect(st.beaconEnabled, isTrue);
    });
  });

  test('只在链路通时才算发得出去', () async {
    final st = AppState();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    st.myCall = 'BG7LZQ';
    st.setSsid('7');
    expect(st.sendSsidCommand('BG7LZQ-9', SsidCmd.beacon), isFalse);
  });
}
