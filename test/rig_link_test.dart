// 电台控制（Hamlib / rigctld）的客户端只对**协议**负责。
//
// CI 里没有 rigctld，也没有电台，所以这里用一台本机的小服务当假的 rigctld：
// 它按扩展格式回包（第一行是命令名，中间是 `键: 值`，最后一行 `RPRT <code>`），
// 并把收到的命令记下来。真 daemon 的行为就是这几行字符串 —— 它们变了，
// 这个测试应该先红，而不是等用户装机后点「连接」才发现。
//
// 实测过的真回包（hamlib 3.3 / 4.7 一致）：
//   +f            → get_freq: / Frequency: 145000000 / RPRT 0
//   +m            → get_mode: / Mode: FM / Passband: 15000 / RPRT 0
//   +\get_info    → get_info: / Info: ... / RPRT 0
//   +M FM 0       → set_mode: FM 0 / RPRT 0（passband 0 = 该模式的默认带宽）
//   +T 1 / +T 0   → set_ptt: 1 / RPRT 0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aprslocus/net/rig_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// 一台假 rigctld。
class _FakeRig {
  late ServerSocket _server;
  final List<String> seen = <String>[];
  int freq = 145000000;
  String mode = 'FM';
  bool ptt = false;

  /// 下一次**写**命令回 `RPRT -1`（模拟电台拒绝 / 型号不支持）。
  bool failNext = false;

  int get port => _server.port;

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((Socket s) {
      var carry = '';
      s.listen((Uint8List data) {
        carry += utf8.decode(data, allowMalformed: true);
        var i = carry.indexOf('\n');
        while (i >= 0) {
          final raw = carry.substring(0, i).trim();
          carry = carry.substring(i + 1);
          if (raw.isNotEmpty) _handle(s, raw);
          i = carry.indexOf('\n');
        }
      });
    });
  }

  /// 写命令取一次「这次成不成」的判定。
  bool _takeOk() {
    final ok = !failNext;
    if (!ok) failNext = false;
    return ok;
  }

  void _handle(Socket s, String raw) {
    // 客户端一律用扩展格式（前面加 `+`）。
    final cmd = raw.startsWith('+') ? raw.substring(1) : raw;
    seen.add(cmd);

    // 读命令永远成功；写命令看 failNext。
    String tail(bool ok, String head) => ok ? '$head\nRPRT 0\n' : 'RPRT -1\n';

    if (cmd == 'f') {
      s.write('get_freq:\nFrequency: $freq\nRPRT 0\n');
      return;
    }
    if (cmd == 'm') {
      s.write('get_mode:\nMode: $mode\nPassband: 15000\nRPRT 0\n');
      return;
    }
    if (cmd == r'\get_info') {
      s.write('get_info:\nInfo: Fake rig\nRPRT 0\n');
      return;
    }
    if (cmd.startsWith('F ')) {
      final ok = _takeOk();
      final hz = int.tryParse(cmd.substring(2).trim());
      if (ok && hz != null) freq = hz;
      s.write(tail(ok, 'set_freq: ${hz ?? 0}'));
      return;
    }
    if (cmd.startsWith('M ')) {
      final ok = _takeOk();
      final parts = cmd.substring(2).trim().split(' ');
      if (ok && parts.isNotEmpty) mode = parts.first;
      s.write(tail(ok, 'set_mode: ${cmd.substring(2)}'));
      return;
    }
    if (cmd.startsWith('T ')) {
      final ok = _takeOk();
      final on = cmd.substring(2).trim() == '1';
      if (ok) ptt = on;
      s.write(tail(ok, 'set_ptt: ${on ? 1 : 0}'));
      return;
    }
    s.write('RPRT -1\n');
  }

  Future<void> stop() async {
    await _server.close();
  }
}

void main() {
  late _FakeRig rig;
  late RigLink link;

  setUp(() async {
    rig = _FakeRig();
    await rig.start();
    link = createRigLink();
    expect(await link.connect('127.0.0.1', rig.port), isTrue);
  });

  tearDown(() async {
    link.disconnect();
    await rig.stop();
  });

  test('读回型号、频率、模式', () async {
    final st = await link.status();
    expect(st, isNotNull);
    expect(st!.freqHz, 145000000);
    expect(st.mode, 'FM');
    expect(st.info, 'Fake rig');
    // 三条命令都用扩展格式发出去的。
    expect(rig.seen, containsAll(<String>[r'\get_info', 'f', 'm']));
  });

  test('设频率：发 F <Hz>，回 RPRT 0 才算成功', () async {
    expect(await link.setFreq(144640000), isTrue);
    expect(rig.freq, 144640000);
    final st = await link.status();
    expect(st!.freqHz, 144640000);
  });

  test('设模式：带宽传 0，由 hamlib 换成该模式的默认值', () async {
    expect(await link.setMode('USB'), isTrue);
    expect(rig.mode, 'USB');
    expect(rig.seen, contains('M USB 0'));
  });

  test('PTT 开与关', () async {
    expect(await link.setPtt(true), isTrue);
    expect(rig.ptt, isTrue);
    expect(await link.setPtt(false), isTrue);
    expect(rig.ptt, isFalse);
    expect(rig.seen, containsAll(<String>['T 1', 'T 0']));
  });

  test('回 RPRT -1 时返回 false，不当成功', () async {
    rig.failNext = true;
    expect(await link.setFreq(145000000), isFalse);
  });

  test('连不上就返回 false，并把原因留下来', () async {
    final dead = createRigLink();
    // 端口 1：没人听，连接会被拒。
    expect(await dead.connect('127.0.0.1', 1), isFalse);
    expect(dead.connected, isFalse);
    expect(dead.lastError.isNotEmpty, isTrue);
    dead.disconnect();
  });

  test('断开之后再发命令直接失败，不挂在超时上', () async {
    link.disconnect();
    expect(await link.setPtt(true), isFalse);
    expect(rig.ptt, isFalse);
  });
}
