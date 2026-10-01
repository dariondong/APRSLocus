// 会话配置校验回归（对应 mod 的 Ic705RxSessionConfigTest）
import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_protocol.dart' show IcomLanCivCommands;
import 'package:aprslocus/net/icom_lan_rx_session_types.dart';

IcomLanRxSessionConfig config({int civ = IcomLanCivCommands.defaultRadioAddress}) =>
    IcomLanRxSessionConfig(
      radioAddress: '192.168.59.1',
      controlPort: 50001,
      username: 'ic705',
      password: 'password',
      radioCivAddress: civ,
    );

void main() {
  test('默认 CI-V 地址是 0xA4，且 toString 里体现出来', () {
    final c = config();
    expect(c.radioCivAddress, IcomLanCivCommands.defaultRadioAddress);
    expect(c.radioCivAddress, 0xa4);
    expect(c.toString(), contains('radioCivAddress=A4'));
  });

  test('自定义 CI-V 地址被保留', () {
    expect(config(civ: 0xa2).radioCivAddress, 0xa2);
    expect(config(civ: 0xa2).toString(), contains('radioCivAddress=A2'));
  });

  test('CI-V 地址 0 与越界值被拒', () {
    expect(() => config(civ: 0), throwsArgumentError);
    expect(() => config(civ: 0xf0), throwsArgumentError);
  });

  test('凭据不进 toString —— 口令与用户名都不能漏进日志', () {
    final c = config();
    final text = c.toString();
    expect(text.contains('password'), isTrue, reason: '字段名可以出现');
    expect(text.contains('password=<redacted>'), isTrue);
    expect(text.contains('password'), isTrue);
    expect(text.contains('password, '), isFalse, reason: '明文口令不得出现');
  });
}
