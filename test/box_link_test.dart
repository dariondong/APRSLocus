/// APRSlocusBOX（小盒子）链路回归测试。
///
/// 这条链路线上是**明文行**（`CFG k=v` / `EVT …` / `OK`），所以测试的重点
/// 不是编解码数学，而是**协议约定**：
///   1. 断行：盒子 println 出的是 `\r\n`，`\n` 与 `\r` 都得当行尾；
///   2. `CFG key=value` 回读进配置表；密码回的 `***` **原样保留**，
///      不能被当成内容（否则用户一点保存就把密码改成三个星号）；
///   3. `EVT` 分类计数（TX/BEACON/RXMSG/ACK/ERR）与「最近事件」；
///   4. `POS` 的**参数顺序不能跳**：固件用 sscanf 顺序解析、靠个数判断有没有
///      后一项，所以「没有高度却发速度」会被当成「高度=速度」。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aprslocus/box.dart';
import 'package:aprslocus/net/tnc_base.dart';

/// 假传输：把字节喂给链路，并**记下**链路写出去的每一行。
class _FakeTransport implements TncTransport {
  final List<String> sent = [];

  @override
  bool connected = false;

  @override
  void Function(List<int> bytes)? onBytes;

  @override
  void Function(String status)? onStatus;

  @override
  void Function()? onClosed;

  @override
  void Function(String reason)? onTxFailed;

  @override
  void Function(int size)? onTxAck;

  @override
  Future<bool> get supported async => true;

  /// 线路 → 链路
  void feed(String text) => onBytes?.call(Uint8List.fromList(text.codeUnits));

  void feedBytes(List<int> b) => onBytes?.call(b);

  @override
  Future<List<TncDevice>> listDevices() async => const [];

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<String?> connect(TncDevice device) async {
    connected = true;
    return null;
  }

  @override
  Future<void> disconnect() async => connected = false;

  @override
  void send(Uint8List bytes) => sent.add(String.fromCharCodes(bytes));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _FakeTransport t;
  late BoxLink link;

  setUp(() async {
    t = _FakeTransport();
    link = BoxLink(transport: t);
    await link.connect(const TncDevice(id: 'AA:BB', name: 'APRSBox'));
    // 连上会自动回读一次配置（`CFG`）—— 那一条由下面的生命周期用例专门验证，
    // 其余用例都不该被它干扰。
    t.sent.clear();
  });

  group('断行', () {
    test(r'\r\n 与 \n 都算行尾', () {
      t.feed('CFG bsec=300\r\nCFG call=BG7LZQ\n');
      expect(link.cfgLines, 2);
      expect(link.cfg['bsec'], '300');
      expect(link.cfg['call'], 'BG7LZQ');
    });

    test('空行被忽略、不计数', () {
      t.feed('\r\n\n\r\n');
      expect(link.rxLines, 0);
    });

    test('超长行被丢弃并计数（对端可能不是盒子）', () {
      t.feed('X' * 600 + '\n');
      expect(link.lineOverflows, 1);
      expect(link.cfgLines, 0);
    });
  });

  group('CFG 回读', () {
    test('键值进配置表，逐字保留（不 trim 值内的空格）', () {
      t.feed('CFG cmt=APRS Box 1\n');
      expect(link.cfg['cmt'], 'APRS Box 1');
    });

    test('密码掩码原样保留 —— 它不能变成「内容」', () {
      t.feed('CFG wpass=***\nCFG pass=***\n');
      expect(link.cfg['wpass'], kBoxMaskedValue);
      expect(link.cfg['pass'], kBoxMaskedValue);
    });

    test('没有等号的行不进配置表', () {
      t.feed('CFG bogus\n');
      expect(link.cfg.isEmpty, isTrue);
      expect(link.cfgLines, 0);
    });
  });

  group('EVT 事件', () {
    test('分类计数', () {
      t.feed('EVT TX BG7LZQ-9>APALOC,TCPIP*:!2249.05N/11314.73E>\n');
      t.feed('EVT BEACON auto\n');
      t.feed('EVT RXMSG BH7GZB-7 hello\n');
      t.feed('EVT ACK 0042\n');
      expect(link.txCount, 1);
      expect(link.beaconCount, 1);
      expect(link.rxMsgCount, 1);
      expect(link.ackCount, 1);
      expect(link.errCount, 0);
    });

    test('ERR 单独计数 —— 「它到底有没有在发」全靠这几个数', () {
      t.feed('EVT ERR no-fix beacon-not-sent\n');
      expect(link.errCount, 1);
      expect(link.lastEvent, 'ERR no-fix beacon-not-sent');
      expect(link.lastEventAt, isNotNull);
    });

    test('最近事件取最后一次（不拼历史）', () {
      t.feed('EVT BEACON manual\n');
      t.feed('EVT BEACON auto\n');
      expect(link.lastEvent, 'BEACON auto');
    });

    test('事件原文进日志（排查时的唯一证据）', () {
      t.feed('EVT ERR not-logged-in beacon-not-sent\n');
      expect(link.logs.any((l) => l.contains('not-logged-in')), isTrue);
    });
  });

  group('非协议行', () {
    test('OK / usage / 开机横幅都如实进日志', () {
      t.feed('OK\n');
      t.feed('[boot] reset reason: PANIC (4)\n');
      expect(link.logs.any((l) => l.endsWith('OK')), isTrue);
      expect(link.logs.any((l) => l.contains('reset reason')), isTrue);
    });

    test('usage / unknown 记为 lastError（界面要能说清为什么没生效）', () {
      t.feed('unknown config key: zzz\n');
      expect(link.lastError, startsWith('unknown'));
    });
  });

  group('命令写出', () {
    test('行尾补 \\n（固件按 \\n/\\r 断行）', () {
      link.setCfg('bsec', '600');
      expect(t.sent, ['CFG bsec=600\n']);
    });

    test('未连接时拒绝发送（不能假装发出去了）', () async {
      await link.disconnect();
      expect(link.beacon(), isFalse);
      expect(t.sent, isEmpty);
      expect(link.lastError, 'not-connected');
    });
  });

  group('喂位置（POS lat lon [alt] [spd] [crs]）', () {
    test('齐活：5 位小数 + 米 + m/s + 度', () {
      link.feedPos(
          lat: 22.123456, lon: 113.987654,
          altM: 12.3, speedMps: 5.0, courseDeg: 271.4);
      expect(t.sent.single, 'POS 22.12346 113.98765 12.3 5.00 271\n');
    });

    test('没有高度时**不发**速度/航向（参数顺序不能跳）', () {
      link.feedPos(lat: 22.5, lon: 113.5, speedMps: 5, courseDeg: 90);
      expect(t.sent.single, 'POS 22.50000 113.50000\n');
    });

    test('有高度没航向：速度照发，航向省略', () {
      link.feedPos(lat: 22.5, lon: 113.5, altM: 0, speedMps: 1.5);
      expect(t.sent.single, 'POS 22.50000 113.50000 0.0 1.50\n');
    });

    test('POS OFF 清位', () {
      link.clearPos();
      expect(t.sent.single, 'POS OFF\n');
    });
  });

  group('手机状态推送（APP / NEAR）', () {
    test('APP：未知值发 -1（跳字段会让后面的数字整体错位）', () {
      link.pushApp(fix: false, isUp: true, unread: 3);
      expect(t.sent.single, 'APP -1 -1 -1 0 1 3\n');
    });

    test('APP：有数就带数（速度 km/h、方位度、海拔米）', () {
      link.pushApp(
          fix: true, isUp: false, unread: 0,
          speedKmh: 12.34, courseDeg: 45.6, altM: 32.4);
      expect(t.sent.single, 'APP 12.3 46 32 1 0 0\n');
    });

    test('NEAR：一条一行，带 total/idx（固件靠 idx==total 才算整轮完整）', () {
      link.pushNear(const [
        BoxNearRow(call: 'BG7LZQ-9', distM: 3200, brg: 45, ageSec: 12,
                   comment: 'TEST'),
        BoxNearRow(call: 'BH7GZB-7', distM: 8100, ageSec: 270),
      ]);
      expect(t.sent, [
        'NEAR 2 1 BG7LZQ-9 3200 45 12 TEST\n',
        'NEAR 2 2 BH7GZB-7 8100 -1 270\n',
      ]);
    });

    test('NEAR：空列表发 `NEAR 0` —— 让盒子清空，别留着上一次的旧列表', () {
      link.pushNear(const []);
      expect(t.sent.single, 'NEAR 0\n');
    });

    test('NEAR：备注里的换行会被压成空格（否则会劈出第二条命令）', () {
      link.pushNear(const [
        BoxNearRow(call: 'X', distM: 1, brg: 0, ageSec: 0, comment: 'a\nb'),
      ]);
      expect(t.sent.single, 'NEAR 1 1 X 1 0 0 a b\n');
    });
  });

  group('生命周期', () {
    test('连上就回读配置（界面立刻有内容，也顺带证明对端是盒子）', () async {
      final t2 = _FakeTransport();
      final l2 = BoxLink(transport: t2);
      await l2.connect(const TncDevice(id: 'AA:BB', name: 'APRSBox'));
      expect(t2.sent, ['CFG\n']);
      expect(l2.connected, isTrue);
    });

    test('断开不误报成「意外掉线」', () async {
      link.onClosed = () => fail('主动断开不应上报 onClosed');
      await link.disconnect();
      expect(link.connected, isFalse);
      expect(link.status, BoxStatus.idle);
    });
  });
}
