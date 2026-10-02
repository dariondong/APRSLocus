/// IC-705 会话的判定策略（对应 mod 的 `session/Ic705SessionPolicy.kt`）。
///
/// 这些都是**纯函数/纯枚举**：谁超时该软恢复、谁该整段重连、客户端 ID 怎么
/// 构造、什么时候该发 tracked idle —— 全部可单测，不需要电台也不需要时钟。
library;

import 'dart:io' show InternetAddress, InternetAddressType;

import 'icom_lan_rx_session_types.dart';

/// 该协议里客户端 ID 的构造方式：把本机 IPv4 的后两段与本地端口拼进 32 位。
///
/// 电台按这个 ID 区分客户端；`randomizeClientId` 的 wire profile 会改用随机值
/// （见 `icom_lan_rx_session_types.dart` 的 wire profile）。
int icomLanClientIdForEndpoint({
  InternetAddress? localAddress,
  required int localPort,
}) {
  if (localPort <= 0 || localPort > 0xffff) {
    throw ArgumentError('localPort must be a bound UDP port');
  }
  // Dart 的 InternetAddress 没有 isAny：用原始字节判断「未指定地址」(0.0.0.0)。
  if (localAddress != null &&
      localAddress.type == InternetAddressType.IPv4 &&
      localAddress.rawAddress.any((byte) => byte != 0)) {
    final octets = localAddress.rawAddress;
    return ((octets[2] & 0xff) << 24) |
        ((octets[3] & 0xff) << 16) |
        localPort;
  }
  // 拿不到该路由的具体 IPv4 时的兜底形式（同样来自端点，不用随机值）。
  return 0x00010000 | localPort;
}

/// 距上次 tracked 包超过 [idleAfterMillis] 时，应补一个 tracked idle。
bool shouldSendIcomLanTrackedIdle({
  required int millisSinceLastTracked,
  required int idleAfterMillis,
}) =>
    millisSinceLastTracked >= idleAfterMillis;

/// 角色化的通道 watchdog 超时（CONTROL 是整会话活性的权威）。
int icomLanChannelWatchdogTimeoutMillis(
  IcomLanRxSessionTiming timing,
  IcomLanChannelRole role,
) =>
    switch (role) {
      IcomLanChannelRole.control => timing.channelTimeoutMillis,
      IcomLanChannelRole.civ => timing.civChannelTimeoutMillis,
      IcomLanChannelRole.audio => timing.audioChannelTimeoutMillis,
    };

/// PTT 可能还按着、或处于 PTT OFF 后的接收恢复宽限期时，音频 watchdog 不判死。
bool shouldSuppressIcomLanAudioWatchdog({
  required bool pttPossiblyAsserted,
  required int nowMillis,
  required int graceUntilMillis,
}) =>
    pttPossiblyAsserted || nowMillis < graceUntilMillis;

/// watchdog 的处置决策。
enum IcomLanWatchdogDecision {
  healthy,
  waitForSoftRecovery,
  startSoftRecovery,
  retrySoftRecovery,
  escalate,
}

/// 按角色与恢复进度决定：继续等、开始/重试软恢复、还是升级为整段重连。
IcomLanWatchdogDecision icomLanWatchdogDecision({
  required IcomLanChannelRole role,
  required int ageMillis,
  required int timeoutMillis,
  required bool pttPossiblyAsserted,
  required int? activeRecoveryAttempt,
  required bool recoveryDeadlineReached,
  required int maxSoftRecoveryAttempts,
}) {
  if (ageMillis <= timeoutMillis) return IcomLanWatchdogDecision.healthy;
  // CONTROL 是整会话活性：它超时不能只恢复一条流。
  if (role == IcomLanChannelRole.control) {
    return IcomLanWatchdogDecision.escalate;
  }
  // PTT 期间 CI-V 不能悄悄恢复：发射中丢流必须整段重连。
  if (role == IcomLanChannelRole.civ && pttPossiblyAsserted) {
    return IcomLanWatchdogDecision.escalate;
  }
  if (activeRecoveryAttempt == null) {
    return IcomLanWatchdogDecision.startSoftRecovery;
  }
  if (!recoveryDeadlineReached) {
    return IcomLanWatchdogDecision.waitForSoftRecovery;
  }
  return activeRecoveryAttempt < maxSoftRecoveryAttempts
      ? IcomLanWatchdogDecision.retrySoftRecovery
      : IcomLanWatchdogDecision.escalate;
}
