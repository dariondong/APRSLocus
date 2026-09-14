import 'package:aprslocus/tnc.dart';
import 'package:flutter_test/flutter_test.dart';

/// TNC 配置的持久化与「能收不能发」相关默认值的回归测试。
///
/// 背景：APRSdroid（可用参考实现）**默认一个 KISS 参数帧都不发**，只发
/// 可选的初始化串；我们此前连上就强推 TxDelay/P/SlotTime/TxTail/FullDuplex。
/// 这些参数会覆盖 TNC 自身配置，推错值可能让它在共享信道上一直退避而不发射。
/// 因此把「默认不下发」这条约定钉死，并保留显式开关。
void main() {
  group('TncConfig 新增字段（初始化串 / 参数下发开关）', () {
    test('默认不下发 KISS 参数（与 APRSdroid 行为一致）', () {
      expect(TncConfig().pushKissParams, isFalse,
          reason: '连上就推参数会让 TNC 行为变得不可预期，默认必须是关');
      expect(TncConfig().initString, isEmpty);
      expect(TncConfig().initDelayMs, 300);
    });

    test('toJson/fromJson 往返：初始化串与开关不丢', () {
      final c = TncConfig()
        ..initString = 'KISS ON\nRESTART'
        ..initDelayMs = 500
        ..pushKissParams = true;
      final back = TncConfig.fromJson(c.toJson());
      expect(back.initString, 'KISS ON\nRESTART');
      expect(back.initDelayMs, 500);
      expect(back.pushKissParams, isTrue);
    });

    test('旧配置（无新键）读取后仍用安全默认值，不抛异常', () {
      final back = TncConfig.fromJson({'txDelayMs': 200, 'path': 'WIDE1-1'});
      expect(back.txDelayMs, 200);
      expect(back.path, 'WIDE1-1');
      expect(back.initString, isEmpty);
      expect(back.pushKissParams, isFalse, reason: '旧配置必须是「不下发」');
      expect(TncConfig.fromJson(null).pushKissParams, isFalse);
    });

    test('initDelayMs 收敛到 0-5000ms，避免非法值把连接卡死', () {
      expect(TncConfig.fromJson({'initDelayMs': 999999}).initDelayMs, 5000);
      expect(TncConfig.fromJson({'initDelayMs': -5}).initDelayMs, 0);
    });
  });
}
