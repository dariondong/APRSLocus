// 连接信息重试策略回归（对应 mod 的 Ic705ConnectionInfoRetryPolicyTest）
import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_connection_info_retry_policy.dart';

void main() {
  test('未发出请求、或端点已到手时忽略状态包', () {
    expect(
      icomLanConnectionInfoStatusDecision(
        connectionInfoSent: false,
        hasStreamEndpoints: false,
        errorCode: 0,
        disconnectFlag: 0,
      ),
      IcomLanConnectionInfoStatusDecision.ignore,
    );
    expect(
      icomLanConnectionInfoStatusDecision(
        connectionInfoSent: true,
        hasStreamEndpoints: true,
        errorCode: 1,
        disconnectFlag: 1,
      ),
      IcomLanConnectionInfoStatusDecision.ignore,
    );
  });

  test('「没准备好」同会话重试；任何明确失败都整段重连', () {
    expect(
      icomLanConnectionInfoStatusDecision(
        connectionInfoSent: true,
        hasStreamEndpoints: false,
        errorCode: 0,
        disconnectFlag: 0,
      ),
      IcomLanConnectionInfoStatusDecision.retrySameSession,
    );
    expect(
      icomLanConnectionInfoStatusDecision(
        connectionInfoSent: true,
        hasStreamEndpoints: false,
        errorCode: 1,
        disconnectFlag: 0,
      ),
      IcomLanConnectionInfoStatusDecision.rejectSession,
    );
    expect(
      icomLanConnectionInfoStatusDecision(
        connectionInfoSent: true,
        hasStreamEndpoints: false,
        errorCode: 0,
        disconnectFlag: 1,
      ),
      IcomLanConnectionInfoStatusDecision.rejectSession,
    );
  });

  test('重试上限是 4 次，第 4 次算耗尽', () {
    expect(kIcomLanMaxConnectionInfoAttempts, 4);
    for (final attempts in [1, 3]) {
      expect(
        icomLanConnectionInfoRetryDecision(
          connectionInfoSent: true,
          hasStreamEndpoints: false,
          attempts: attempts,
        ),
        IcomLanConnectionInfoRetryDecision.retry,
      );
    }
    expect(
      icomLanConnectionInfoRetryDecision(
        connectionInfoSent: true,
        hasStreamEndpoints: false,
        attempts: 4,
      ),
      IcomLanConnectionInfoRetryDecision.exhausted,
    );
  });

  test('不该影响当前协商时忽略重试计时器', () {
    expect(
      icomLanConnectionInfoRetryDecision(
        connectionInfoSent: false,
        hasStreamEndpoints: false,
        attempts: 0,
      ),
      IcomLanConnectionInfoRetryDecision.ignore,
    );
    expect(
      icomLanConnectionInfoRetryDecision(
        connectionInfoSent: true,
        hasStreamEndpoints: true,
        attempts: 4,
      ),
      IcomLanConnectionInfoRetryDecision.ignore,
    );
  });
}
