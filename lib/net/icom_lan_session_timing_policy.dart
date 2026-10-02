/// IC-705 会话的时序策略（对应 mod 的 `session/Ic705SessionTimingPolicy.kt`）。
library;

import 'icom_lan_rx_session_engine.dart';
import 'icom_lan_rx_session_types.dart';

const int _sessionRejectedCooldownMillis = 30000;

/// 「连接信息 settle / retry」两个互斥定时器。
enum IcomLanConnectionInfoTimer {
  settle('connection-info-settle', 'connection-info-retry'),
  retry('connection-info-retry', 'connection-info-settle');

  const IcomLanConnectionInfoTimer(this.taskKey, this.conflictingTaskKey);

  final String taskKey;
  final String conflictingTaskKey;
}

int icomLanConnectionInfoTimerDelayMillis(
  IcomLanRxSessionTiming timing,
  IcomLanConnectionInfoTimer timer,
) =>
    switch (timer) {
      IcomLanConnectionInfoTimer.settle => timing.connectionInfoSettleMillis,
      IcomLanConnectionInfoTimer.retry => timing.connectionInfoRetryMillis,
    };

IcomLanEvent icomLanConnectionInfoTimerEvent(IcomLanConnectionInfoTimer timer) =>
    switch (timer) {
      IcomLanConnectionInfoTimer.settle =>
        const IcomLanConnectionInfoSettleTimerFired(),
      IcomLanConnectionInfoTimer.retry =>
        const IcomLanConnectionInfoRetryTimerFired(),
    };

/// 重连延迟：指数退避 + 冷却下限（电台"明确拒绝"等 30 秒，别再敲它）。
int icomLanReconnectDelayMillis(
  IcomLanRxSessionTiming timing,
  int attempt,
  IcomLanRetryCooldown cooldown,
) {
  var delay = timing.initialReconnectMillis;
  final steps = (attempt - 1).clamp(0, 30);
  for (var i = 0; i < steps; i++) {
    delay = (delay * 2).clamp(0, timing.maximumReconnectMillis);
  }
  final floor = switch (cooldown) {
    IcomLanRetryCooldown.normal => 0,
    IcomLanRetryCooldown.sessionNotReady => timing.connectionInfoRetryMillis,
    IcomLanRetryCooldown.sessionRejected => _sessionRejectedCooldownMillis,
  };
  return delay > floor ? delay : floor;
}

/// 各握手阶段的超时；已进入稳定态（接收/重连等待/失败）返回 null。
int? icomLanHandshakeTimeoutMillis(
  IcomLanRxSessionTiming timing,
  IcomLanPhase phase,
) =>
    switch (phase) {
      IcomLanPhase.openingSockets ||
      IcomLanPhase.controlDiscovery ||
      IcomLanPhase.authenticating ||
      IcomLanPhase.openingStreams ||
      IcomLanPhase.streamsReady =>
        timing.handshakeStageTimeoutMillis,
      IcomLanPhase.negotiating => timing.negotiationTimeoutMillis,
      IcomLanPhase.stopped ||
      IcomLanPhase.receiving ||
      IcomLanPhase.reconnectWait ||
      IcomLanPhase.failed =>
        null,
    };
