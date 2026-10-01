/// 连接信息（0x90）重试策略（对应 mod 的
/// `session/Ic705ConnectionInfoRetryPolicy.kt`）。
///
/// 电台一时"没准备好"（还在分配流）与"明确拒绝"必须分开：前者等一会儿重发
/// 同一条连接信息，后者要整段重连并且冷却更久。
library;

/// 连接信息重试上限（超过就整段重连）。
const int kIcomLanMaxConnectionInfoAttempts = 4;

/// 收到「会话未就绪」状态时的处置。
enum IcomLanConnectionInfoStatusDecision {
  ignore,
  retrySameSession,
  rejectSession,
}

/// 收到「会话未就绪」状态时的处置决策。
IcomLanConnectionInfoStatusDecision icomLanConnectionInfoStatusDecision({
  required bool connectionInfoSent,
  required bool hasStreamEndpoints,
  required int errorCode,
  required int disconnectFlag,
}) {
  if (!connectionInfoSent || hasStreamEndpoints) {
    return IcomLanConnectionInfoStatusDecision.ignore;
  }
  return errorCode == 0 && disconnectFlag == 0
      ? IcomLanConnectionInfoStatusDecision.retrySameSession
      : IcomLanConnectionInfoStatusDecision.rejectSession;
}

/// 连接信息重试计时器到点后的决策。
enum IcomLanConnectionInfoRetryDecision { ignore, retry, exhausted }

IcomLanConnectionInfoRetryDecision icomLanConnectionInfoRetryDecision({
  required bool connectionInfoSent,
  required bool hasStreamEndpoints,
  required int attempts,
}) {
  if (!connectionInfoSent || hasStreamEndpoints) {
    return IcomLanConnectionInfoRetryDecision.ignore;
  }
  return attempts >= kIcomLanMaxConnectionInfoAttempts
      ? IcomLanConnectionInfoRetryDecision.exhausted
      : IcomLanConnectionInfoRetryDecision.retry;
}
