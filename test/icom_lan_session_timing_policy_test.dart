// IC-705 时序策略回归（对应 mod 的 Ic705SessionTimingPolicyTest）
import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_rx_session_engine.dart';
import 'package:aprslocus/net/icom_lan_rx_session_types.dart';
import 'package:aprslocus/net/icom_lan_session_timing_policy.dart';

void main() {
  test('连接信息两个定时器的延迟来自配置', () {
    final timing = IcomLanRxSessionTiming(
      connectionInfoSettleMillis: 3000,
      connectionInfoRetryMillis: 10000,
    );
    expect(
      icomLanConnectionInfoTimerDelayMillis(
          timing, IcomLanConnectionInfoTimer.settle),
      3000,
    );
    expect(
      icomLanConnectionInfoTimerDelayMillis(
          timing, IcomLanConnectionInfoTimer.retry),
      10000,
    );
  });

  test('两个定时器的 key 互斥（不会同时跑）', () {
    expect(IcomLanConnectionInfoTimer.settle.conflictingTaskKey,
        IcomLanConnectionInfoTimer.retry.taskKey);
    expect(IcomLanConnectionInfoTimer.retry.conflictingTaskKey,
        IcomLanConnectionInfoTimer.settle.taskKey);
  });

  test('两个定时器映射到不同事件', () {
    expect(icomLanConnectionInfoTimerEvent(IcomLanConnectionInfoTimer.settle),
        isA<IcomLanConnectionInfoSettleTimerFired>());
    expect(icomLanConnectionInfoTimerEvent(IcomLanConnectionInfoTimer.retry),
        isA<IcomLanConnectionInfoRetryTimerFired>());
  });

  test('重连延迟是指数退避并受上限约束', () {
    final timing = IcomLanRxSessionTiming(
      initialReconnectMillis: 1000,
      maximumReconnectMillis: 30000,
    );
    expect(icomLanReconnectDelayMillis(timing, 1, IcomLanRetryCooldown.normal), 1000);
    expect(icomLanReconnectDelayMillis(timing, 2, IcomLanRetryCooldown.normal), 2000);
    expect(icomLanReconnectDelayMillis(timing, 3, IcomLanRetryCooldown.normal), 4000);
    expect(icomLanReconnectDelayMillis(timing, 6, IcomLanRetryCooldown.normal), 30000);
    expect(icomLanReconnectDelayMillis(timing, 20, IcomLanRetryCooldown.normal), 30000);
  });

  test('冷却类别给出下限（没准备好 / 明确拒绝）', () {
    final timing = IcomLanRxSessionTiming(
      initialReconnectMillis: 1000,
      maximumReconnectMillis: 30000,
      connectionInfoRetryMillis: 10000,
    );
    expect(
      icomLanReconnectDelayMillis(timing, 1, IcomLanRetryCooldown.sessionNotReady),
      10000,
    );
    expect(
      icomLanReconnectDelayMillis(timing, 1, IcomLanRetryCooldown.sessionRejected),
      30000,
    );
  });

  test('握手超时按阶段区分，稳定态没有超时', () {
    final timing = IcomLanRxSessionTiming(
      handshakeStageTimeoutMillis: 10000,
      negotiationTimeoutMillis: 45000,
    );
    for (final phase in [
      IcomLanPhase.openingSockets,
      IcomLanPhase.controlDiscovery,
      IcomLanPhase.authenticating,
      IcomLanPhase.openingStreams,
      IcomLanPhase.streamsReady,
    ]) {
      expect(icomLanHandshakeTimeoutMillis(timing, phase), 10000);
    }
    expect(icomLanHandshakeTimeoutMillis(timing, IcomLanPhase.negotiating), 45000);
    for (final phase in [
      IcomLanPhase.stopped,
      IcomLanPhase.receiving,
      IcomLanPhase.reconnectWait,
      IcomLanPhase.failed,
    ]) {
      expect(icomLanHandshakeTimeoutMillis(timing, phase), isNull);
    }
  });
}
