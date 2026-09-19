import 'dart:typed_data';

import 'package:aprslocus/net/tnc.dart';
import 'package:aprslocus/net/tnc_base.dart';
// TncAutoTransport / TncNativeUsb 在平台实现文件里（条件导入只对运行时生效，
// 测试要直接验选路逻辑，所以显式引用 io 实现；Linux 测试主机上正好可用）。
import 'package:aprslocus/net/tnc_io.dart';
import 'package:aprslocus/tnc.dart';
import 'package:flutter_test/flutter_test.dart';

/// 硬件串口（Android USB-OTG / 桌面串口线速）回归测试
///
/// 这一层最容易出的是**选路**与**参数传递**错误，而且两边都不会报错：
///   * 选错后端 → 蓝牙明明断了却仍往蓝牙发（或反之），表现为「连上了但发不出」；
///   * 线速没传下去 → 设备用默认 9600，而电台是 38400，一个字节都收不到。
/// 所以固定住这两类行为。
class FakeTransport implements TncTransport {
  FakeTransport(this.name);

  final String name;

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

  final List<String> calls = [];
  TncDevice? lastConnected;
  int sentBytes = 0;
  List<TncDevice> devicesToReturn = const [];

  @override
  Future<bool> get supported async => true;

  @override
  Future<List<TncDevice>> listDevices() async {
    calls.add('list');
    return devicesToReturn;
  }

  @override
  Future<bool> requestPermissions() async {
    calls.add('perm');
    return true;
  }

  @override
  Future<String?> connect(TncDevice device) async {
    calls.add('connect:${device.id}');
    lastConnected = device;
    connected = true;
    return null;
  }

  @override
  Future<void> disconnect() async {
    calls.add('disconnect');
    connected = false;
  }

  @override
  void send(Uint8List bytes) {
    calls.add('send');
    sentBytes += bytes.length;
  }

  /// 模拟链路被动断开（拔线 / 对端消失）
  void fireClosed() => onClosed?.call();
}

void main() {
  group('TncDevice：USB 与串口的识别', () {
    test('kind=usb 认作 USB 串口，需要设置线速', () {
      const d = TncDevice(id: '1a86:7523:', kind: 'usb', name: 'CH340');
      expect(d.isUsb, isTrue);
      expect(d.isBluetooth, isFalse);
      expect(d.needsBaud, isTrue);
    });

    test('桌面串口（kind=serial）同样需要线速', () {
      const d = TncDevice(id: 'COM5', kind: 'serial');
      expect(d.needsBaud, isTrue);
    });

    test('蓝牙不需要线速（SPP 没有波特率概念）', () {
      const d = TncDevice(id: 'AA:BB:CC:DD:EE:FF', kind: 'bluetooth');
      expect(d.isBluetooth, isTrue);
      expect(d.needsBaud, isFalse);
    });

    test('copyWith 能把线速带上而不动其他字段', () {
      const d = TncDevice(id: 'x', kind: 'usb', name: '线');
      final b = d.copyWith(baud: 38400);
      expect(b.baud, 38400);
      expect(b.id, 'x');
      expect(b.kind, 'usb');
      expect(b.name, '线');
    });
  });

  group('TncConfig.serialBaud：必须持久化', () {
    test('默认 9600 并随 JSON 往返（不持久化会在重启后静默复位）', () {
      final c = TncConfig();
      expect(c.serialBaud, 9600);
      c.serialBaud = 38400;
      final back = TncConfig.fromJson(c.toJson());
      expect(back.serialBaud, 38400);
    });

    test('越界值被夹住（防止手输 0 或百万级把设备搞挂）', () {
      expect(TncConfig.fromJson({'serialBaud': 0}).serialBaud, 1200);
      expect(TncConfig.fromJson({'serialBaud': 99999999}).serialBaud, 1000000);
    });
  });

  group('TncAutoTransport：按设备类型自动选路', () {
    late FakeTransport bt;
    late FakeTransport usb;
    late TncAutoTransport auto;

    setUp(() {
      bt = FakeTransport('bt');
      usb = FakeTransport('usb');
      auto = TncAutoTransport(bluetooth: bt, usb: usb);
    });

    test('扫描列表把两条通路合并（蓝牙设备 + USB 设备并列出现）', () async {
      bt.devicesToReturn = const [
        TncDevice(id: 'AA:BB', kind: 'bluetooth', name: '电台蓝牙'),
      ];
      usb.devicesToReturn = const [
        TncDevice(id: '1a86:7523:', kind: 'usb', name: 'CH340'),
      ];
      final list = await auto.listDevices();
      expect(list.length, 2);
      expect(list.any((d) => d.isBluetooth), isTrue);
      expect(list.any((d) => d.isUsb), isTrue);
    });

    test('连 USB 设备 → 路由到 USB 后端，并把线速交给它', () async {
      const dev = TncDevice(id: '1a86:7523:', kind: 'usb');
      final err = await auto.connect(dev.copyWith(baud: 38400));
      expect(err, isNull);
      expect(usb.calls, contains('connect:1a86:7523:'));
      expect(bt.calls, isNot(contains('connect:1a86:7523:')));
      expect(usb.lastConnected?.baud, 38400);
    });

    test('连蓝牙设备 → 路由到蓝牙后端', () async {
      const dev = TncDevice(id: 'AA:BB', kind: 'bluetooth');
      await auto.connect(dev);
      expect(bt.calls, contains('connect:AA:BB'));
      expect(usb.calls, isEmpty);
    });

    test('切路时先把另一条断干净（两条同时开会把接收字节流瓜分）', () async {
      await auto.connect(const TncDevice(id: 'AA:BB', kind: 'bluetooth'));
      bt.calls.clear();
      await auto.connect(const TncDevice(id: '1a86:7523:', kind: 'usb'));
      expect(bt.calls, contains('disconnect'));
      expect(usb.calls, contains('connect:1a86:7523:'));
    });

    test('发送只走当前活跃链路', () async {
      await auto.connect(const TncDevice(id: '1a86:7523:', kind: 'usb'));
      auto.send(Uint8List.fromList([1, 2, 3]));
      expect(usb.sentBytes, 3);
      expect(bt.sentBytes, 0);
    });

    test('未连接就发送 → 明确报失败，而不是静默丢弃', () async {
      String? reason;
      auto.onTxFailed = (r) => reason = r;
      auto.send(Uint8List.fromList([1]));
      expect(reason, 'no-active-link');
      expect(usb.sentBytes, 0);
    });

    test('只有活跃链路断开才向上报：切路时旧的 onClosed 是预期行为', () async {
      await auto.connect(const TncDevice(id: 'AA:BB', kind: 'bluetooth'));
      var closed = 0;
      auto.onClosed = () => closed++;
      // 切到 USB 时蓝牙被关闭 —— 不应该被当成「链路丢失」
      await auto.connect(const TncDevice(id: '1a86:7523:', kind: 'usb'));
      bt.fireClosed();
      expect(closed, 0);
      // 活跃的 USB 断开才算
      usb.fireClosed();
      expect(closed, 1);
    });

    test('断开时两条都断（用户点的是「断开」，不该留下没人认领的链路）', () async {
      await auto.connect(const TncDevice(id: '1a86:7523:', kind: 'usb'));
      bt.connected = true; // 假设蓝牙还残留着
      await auto.disconnect();
      expect(usb.calls, contains('disconnect'));
      expect(bt.calls, contains('disconnect'));
    });
  });

  group('TncLink：把线速随设备带到传输层', () {
    test('串口类设备连接时会带上 config.serialBaud', () async {
      final fake = FakeTransport('fake');
      final link = TncLink(transport: fake);
      link.config.serialBaud = 57600;
      await link.connect(const TncDevice(id: '/dev/ttyUSB0', kind: 'serial'));
      expect(fake.lastConnected?.baud, 57600);
    });

    test('蓝牙设备不需要线速（不强行塞一个无意义的值）', () async {
      final fake = FakeTransport('fake');
      final link = TncLink(transport: fake);
      link.config.serialBaud = 57600;
      await link.connect(const TncDevice(id: 'AA:BB', kind: 'bluetooth'));
      expect(fake.lastConnected?.needsBaud, isFalse);
      expect(fake.lastConnected?.baud, 0);
    });
  });
}
