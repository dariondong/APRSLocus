// IC-705 会话策略回归（对应 mod 的 Ic705WatchdogPolicyTest /
// Ic705SessionPolicy 的客户端 ID 部分）
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_rx_session_types.dart';
import 'package:aprslocus/net/icom_lan_session_policy.dart';

void main() {
  group('通道 watchdog 超时', () {
    test('默认超时按角色区分，且宽限期/软恢复参数与 mod 一致', () {
      final timing = IcomLanRxSessionTiming();
      expect(icomLanChannelWatchdogTimeoutMillis(timing, IcomLanChannelRole.control), 5000);
      expect(icomLanChannelWatchdogTimeoutMillis(timing, IcomLanChannelRole.civ), 3000);
      expect(icomLanChannelWatchdogTimeoutMillis(timing, IcomLanChannelRole.audio), 30000);
      expect(timing.audioPostTxGraceMillis, 5000);
      expect(timing.streamRecoveryResponseMillis, 3000);
      expect(timing.streamRecoveryAttempts, 2);
    });
  });

  group('watchdog 决策', () {
    test('CONTROL 直接升级；空闲流允许有限次软恢复', () {
      expect(
        icomLanWatchdogDecision(
          role: IcomLanChannelRole.control,
          ageMillis: 5001,
          timeoutMillis: 5000,
          pttPossiblyAsserted: false,
          activeRecoveryAttempt: null,
          recoveryDeadlineReached: false,
          maxSoftRecoveryAttempts: 2,
        ),
        IcomLanWatchdogDecision.escalate,
      );
      expect(
        icomLanWatchdogDecision(
          role: IcomLanChannelRole.civ,
          ageMillis: 3001,
          timeoutMillis: 3000,
          pttPossiblyAsserted: false,
          activeRecoveryAttempt: null,
          recoveryDeadlineReached: false,
          maxSoftRecoveryAttempts: 2,
        ),
        IcomLanWatchdogDecision.startSoftRecovery,
      );
      // PTT 可能按着时 CI-V 超时不能"悄悄恢复"。
      expect(
        icomLanWatchdogDecision(
          role: IcomLanChannelRole.civ,
          ageMillis: 3001,
          timeoutMillis: 3000,
          pttPossiblyAsserted: true,
          activeRecoveryAttempt: null,
          recoveryDeadlineReached: false,
          maxSoftRecoveryAttempts: 2,
        ),
        IcomLanWatchdogDecision.escalate,
      );
      expect(
        icomLanWatchdogDecision(
          role: IcomLanChannelRole.audio,
          ageMillis: 31000,
          timeoutMillis: 30000,
          pttPossiblyAsserted: false,
          activeRecoveryAttempt: 1,
          recoveryDeadlineReached: false,
          maxSoftRecoveryAttempts: 2,
        ),
        IcomLanWatchdogDecision.waitForSoftRecovery,
      );
      expect(
        icomLanWatchdogDecision(
          role: IcomLanChannelRole.audio,
          ageMillis: 34000,
          timeoutMillis: 30000,
          pttPossiblyAsserted: false,
          activeRecoveryAttempt: 1,
          recoveryDeadlineReached: true,
          maxSoftRecoveryAttempts: 2,
        ),
        IcomLanWatchdogDecision.retrySoftRecovery,
      );
      expect(
        icomLanWatchdogDecision(
          role: IcomLanChannelRole.audio,
          ageMillis: 37000,
          timeoutMillis: 30000,
          pttPossiblyAsserted: false,
          activeRecoveryAttempt: 2,
          recoveryDeadlineReached: true,
          maxSoftRecoveryAttempts: 2,
        ),
        IcomLanWatchdogDecision.escalate,
      );
    });

    test('PTT 期间与 PTT OFF 后的恢复宽限期内不判音频超时', () {
      expect(
        shouldSuppressIcomLanAudioWatchdog(
            pttPossiblyAsserted: true, nowMillis: 10000, graceUntilMillis: 0),
        isTrue,
      );
      expect(
        shouldSuppressIcomLanAudioWatchdog(
            pttPossiblyAsserted: false, nowMillis: 10000, graceUntilMillis: 10001),
        isTrue,
      );
      expect(
        shouldSuppressIcomLanAudioWatchdog(
            pttPossiblyAsserted: false, nowMillis: 10000, graceUntilMillis: 10000),
        isFalse,
      );
    });

    test('tracked idle 的触发阈值', () {
      expect(
        shouldSendIcomLanTrackedIdle(
            millisSinceLastTracked: 99, idleAfterMillis: 100),
        isFalse,
      );
      expect(
        shouldSendIcomLanTrackedIdle(
            millisSinceLastTracked: 100, idleAfterMillis: 100),
        isTrue,
      );
    });
  });

  group('客户端 ID 构造', () {
    test('用本机 IPv4 后两段 + 本地端口拼成', () {
      final id = icomLanClientIdForEndpoint(
        localAddress: InternetAddress('192.168.1.53'),
        localPort: 50001,
      );
      expect(id, 0x0135c351);
    });

    test('拿不到具体路由地址时用端点兜底，且不做随机', () {
      final id = icomLanClientIdForEndpoint(localPort: 50001);
      expect(id, 0x0001c351);
      expect(icomLanClientIdForEndpoint(localPort: 50001), id);
    });
  });
}
