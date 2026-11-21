// 音频链路与电台控制是**一体**的：音频要发报，先让电台按下 PTT、切到发报
// 频率，播完再放开。
//
// 这里的两种错都编译得过、analyze 也全绿，只有接上真电台才看得出来：
//   ① 顺序反了 —— 先播音频再按键，对方听到的是后半截；
//   ② 放不开 —— PTT 一直按着，载波堵住整个频段。
// 所以两半都钉在这里：AudioLink 的 hooks 顺序（用假传输层），
// AppState 的「切频率 → 对齐 FM → 按键 → 放开」（用本机假 rigctld）。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aprslocus/audio.dart';
import 'package:aprslocus/net/audio.dart';
import 'package:aprslocus/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 假传输层：只留下「播过几次、什么时候播」。
class _FakeTransport implements AudioTransport {
  final List<String> events;
  int playCount = 0;
  _FakeTransport(this.events);

  @override
  void setOutputDevice(int id) {}
  @override
  void setInputDevice(int id) {}
  @override
  Future<List<AudioDevice>> listOutputDevices() async => const [];
  @override
  Future<List<AudioDevice>> listInputDevices() async => const [];
  @override
  bool get realtime => true;
  @override
  String get backendName => 'fake';
  @override
  bool get capturing => true;
  @override
  bool get playing => false;
  @override
  void Function(Uint8List pcm16le)? onPcm;
  @override
  void Function(String status)? onStatus;
  @override
  void Function()? onClosed;
  @override
  void Function()? onPlaybackDone;
  @override
  Future<bool> get supported async => true;
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Future<String?> startCapture({required int sampleRate}) async => null;
  @override
  Future<void> stopCapture() async {}
  @override
  Future<String?> play(Uint8List pcm16le, {required int sampleRate}) async {
    playCount++;
    events.add('play');
    return null;
  }

  @override
  Future<void> stopPlayback() async {}
  @override
  Future<void> dispose() async {}
}

/// 一台假 rigctld（回包格式与真 daemon 一致，见 rig_link_test）。
class _FakeRig {
  late ServerSocket _server;
  final List<String> seen = <String>[];
  int freq = 145000000;
  String mode = 'FM';
  bool ptt = false;

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

  void _handle(Socket s, String raw) {
    final cmd = raw.startsWith('+') ? raw.substring(1) : raw;
    seen.add(cmd);
    String tail(String head) => '$head\nRPRT 0\n';
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
      freq = int.tryParse(cmd.substring(2).trim()) ?? freq;
      s.write(tail('set_freq: $freq'));
      return;
    }
    if (cmd.startsWith('M ')) {
      final parts = cmd.substring(2).trim().split(' ');
      if (parts.isNotEmpty) mode = parts.first;
      s.write(tail('set_mode: ${cmd.substring(2)}'));
      return;
    }
    if (cmd.startsWith('T ')) {
      ptt = cmd.substring(2).trim() == '1';
      s.write(tail('set_ptt: ${ptt ? 1 : 0}'));
      return;
    }
    s.write('RPRT -1\n');
  }

  Future<void> stop() async {
    await _server.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  const line = 'BG7LZQ-9>APALOC:>APRSlocus RIG TX TEST';

  /// 等到这条帧的发射窗口结束（假传输层不发 playDone，靠超时兜底）。
  Future<void> settle(AudioLink link) async {
    for (var i = 0; i < 60 && link.transmitting; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  group('AudioLink 的两支钩子', () {
    test('先按键、再播、播完放开', () async {
      final events = <String>[];
      final unkeyed = Completer<void>();
      final link = AudioLink(transport: _FakeTransport(events));
      link.onTxKey = () async {
        events.add('key');
        return true;
      };
      link.onTxUnkey = () async {
        events.add('unkey');
        if (!unkeyed.isCompleted) unkeyed.complete();
      };
      expect(await link.connect(), isTrue);
      expect(link.sendTnc2(line), isNull);
      await settle(link);
      // 放开 PTT 在播放窗口之后（finally 里），不能只等 transmitting 变 false：
      // 那一瞬只是音频播完了，CAT 还在路上。
      await unkeyed.future.timeout(const Duration(seconds: 5));
      expect(events, <String>['key', 'play', 'unkey']);
      expect(link.txFrames, 1);
      await link.disconnect();
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('按键失败就整条不发（不播无人接收的音频）', () async {
      final events = <String>[];
      final link = AudioLink(transport: _FakeTransport(events));
      link.onTxKey = () async {
        events.add('key');
        return false;
      };
      link.onTxUnkey = () async {
        events.add('unkey');
      };
      expect(await link.connect(), isTrue);
      expect(link.sendTnc2(line), isNull);
      await settle(link);
      expect(events, <String>['key'], reason: '没按键就不该播，也不该有 unkey');
      expect(link.txFrames, 0);
      expect(link.lastError, 'ptt-failed');
      await link.disconnect();
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('没有电台控制时行为照旧', () async {
      final events = <String>[];
      final link = AudioLink(transport: _FakeTransport(events));
      expect(await link.connect(), isTrue);
      expect(link.sendTnc2(line), isNull);
      await settle(link);
      expect(events, <String>['play']);
      expect(link.txFrames, 1);
      await link.disconnect();
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('AppState 的发报按键', () {
    late _FakeRig rig;
    late AppState st;

    Future<void> up() async {
      SharedPreferences.setMockInitialValues({});
      st = AppState();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      st.setRigHost('127.0.0.1');
      st.setRigPort(rig.port);
      await st.setRigOn(true);
    }

    setUp(() async {
      rig = _FakeRig();
      await rig.start();
    });

    tearDown(() async {
      st.rigLink.disconnect();
      await rig.stop();
    });

    test('切频率 → 对齐 FM → 按键，发完放开', () async {
      // 电台停在其他模式上：报文只能走 FM，发报前要自己对齐。
      rig.mode = 'USB';
      await up();
      expect(st.rigConnected, isTrue);
      st.setRigTxFreq(144640000);
      expect(await st.debugRigKeyForTx(), isTrue);
      expect(rig.freq, 144640000);
      expect(rig.mode, 'FM');
      expect(rig.ptt, isTrue, reason: '按键这一步必须真的发出 T 1');
      // 命令顺序：先改频率，再改模式，最后才按键。
      final f = rig.seen.lastIndexOf('F 144640000');
      final m = rig.seen.lastIndexOf('M FM 0');
      final t = rig.seen.lastIndexOf('T 1');
      expect(f, greaterThanOrEqualTo(0));
      expect(m, greaterThan(f));
      expect(t, greaterThan(m));

      await st.debugRigUnkey();
      expect(rig.ptt, isFalse, reason: '放不开 PTT 会一直压着载波');
    });

    test('没填发报频率就只按键，不动电台当前的频率', () async {
      await up();
      st.setRigTxFreq(0);
      final before = rig.freq;
      expect(await st.debugRigKeyForTx(), isTrue);
      expect(rig.freq, before);
      expect(rig.ptt, isTrue);
      await st.debugRigUnkey();
      expect(rig.ptt, isFalse);
    });

    test('关掉「发报时按下 PTT」就完全不碰电台', () async {
      await up();
      st.setRigKeyTx(false);
      final before = rig.seen.length;
      expect(await st.debugRigKeyForTx(), isTrue, reason: '音频照旧发出去');
      expect(rig.seen.length, before);
      expect(rig.ptt, isFalse);
    });

    test('电台控制没开时直接放行', () async {
      await up();
      await st.setRigOn(false);
      expect(st.rigConnected, isFalse);
      expect(await st.debugRigKeyForTx(), isTrue);
    });
  });
}
