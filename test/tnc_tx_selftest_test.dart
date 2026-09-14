import 'dart:async';
import 'dart:typed_data';

import 'package:aprslocus/net/tnc.dart';
import 'package:aprslocus/tnc.dart';
import 'package:flutter_test/flutter_test.dart';

/// 假传输层：可控制「写入成功」或「写入被原生拒收」。
///
/// 存在的理由：**发射自检不许误报**。v1.6.105 引入的自检直接看
/// `txFrames++`（发送后无条件自增），于是明明一个字节都没送出去、
/// 它也报「已写入」—— 而真实事故正是「Dart 传 `List<int>`，Kotlin 取不到
/// `ByteArray`」，字节全被丢掉。这个 fake 让「字节没出去」可被测试。
class _FakeTransport implements TncTransport {
  _FakeTransport({this.failOnSend = false});

  /// true = 模拟原生侧拒收（异步回调 onTxFailed）
  final bool failOnSend;

  /// 实际被写出的字节（用于断言「真的发出去了什么」）
  final List<Uint8List> written = [];

  @override
  bool connected = true;

  @override
  Future<bool> get supported async => true;

  @override
  void Function(List<int> bytes)? onBytes;

  @override
  void Function(String status)? onStatus;

  @override
  void Function()? onClosed;

  @override
  void Function(String reason)? onTxFailed;

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
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  void send(Uint8List bytes) {
    if (failOnSend) {
      // 模拟原生侧异步拒绝（MethodChannel 的失败不是同步抛出的）
      scheduleMicrotask(() => onTxFailed?.call('NO_DATA: 期望 ByteArray'));
      return;
    }
    written.add(bytes);
  }
}

void main() {
  group('TNC 发射自检（不得误报成功）', () {
    test('链路层接受 → 自检通过，且确实写出了 KISS 帧字节', () async {
      final t = _FakeTransport();
      final link = TncLink(transport: t);
      link.connected = true;
      final err = await link.txSelfTest('BG7LZQ-9', 'APALOC');
      expect(err, isNull);
      expect(link.txErrors, 0);
      expect(t.written, hasLength(1), reason: '必须真的写出一帧');
      // 写出的必须是完整 KISS 帧：首尾 FEND
      expect(t.written.first.first, 0xC0, reason: 'KISS 帧首字节必须是 FEND');
      expect(t.written.first.last, 0xC0);
      expect(link.txFrames, 1);
    });

    test('链路层拒收 → 自检必须报失败（旧实现会误报「已写入」）', () async {
      final t = _FakeTransport(failOnSend: true);
      final link = TncLink(transport: t);
      link.connected = true;
      final err = await link.txSelfTest('BG7LZQ-9', 'APALOC');
      expect(err, isNotNull, reason: '字节没出去就必须报错，不能让用户以为发成功');
      expect(err, startsWith('send-failed'));
      expect(link.txErrors, 1);
      expect(t.written, isEmpty);
    });

    test('未连接时立即失败，不做无意义的等待', () async {
      final link = TncLink(transport: _FakeTransport());
      link.connected = false;
      expect(await link.txSelfTest('BG7LZQ-9', 'APALOC'), 'not-connected');
    });

    test('发送失败会写进链路日志（供用户排查，而不是静默）', () async {
      final t = _FakeTransport(failOnSend: true);
      final link = TncLink(transport: t);
      link.connected = true;
      await link.txSelfTest('BG7LZQ-9', 'APALOC');
      expect(link.logs.any((l) => l.contains('发送失败')), isTrue,
          reason: '发送失败必须留痕，否则排查时无从下手');
    });
  });
}
