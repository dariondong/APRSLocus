// 本机 rigctld 的命令行：CI 里没有 hamlib，也没有电台，所以这里只验参数。
//
// 为什么值得钉：型号编号写错，rigctld 会起来又立刻退出（界面只看到「起不来」）；
// 串口与波特率漏一个，串口打不开；端口带错，应用连到自己都想不到的地方。
// 这三样在编译、analyze 里都看不见。
import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/net/rig_daemon_base.dart';

void main() {
  group('本机 rigctld 的命令行', () {
    test('型号、串口、波特率、端口全进参数', () {
      expect(
        rigctldArgs(const RigDaemonConfig(
          model: 3085,
          device: 'COM3',
          baud: 38400,
          port: 4532,
        )),
        <String>[
          '-m', '3085',
          '-r', 'COM3',
          '-s', '38400',
          '-t', '4532',
          '-T', '127.0.0.1',
        ],
      );
    });

    test('虚拟电台：没有串口就不带 -r', () {
      expect(
        rigctldArgs(const RigDaemonConfig(model: 1, port: 4533)),
        <String>['-m', '1', '-t', '4533', '-T', '127.0.0.1'],
      );
    });

    test('波特率 0 就是不指定，交给 hamlib 自己的默认值', () {
      expect(
        rigctldArgs(const RigDaemonConfig(
          model: 3073,
          device: ' /dev/ttyUSB0 ',
          baud: 0,
          port: 4532,
        )),
        <String>[
          '-m', '3073',
          '-r', '/dev/ttyUSB0',
          '-t', '4532',
          '-T', '127.0.0.1',
        ],
      );
    });
  });
}
