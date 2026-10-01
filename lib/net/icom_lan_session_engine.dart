/// IC-705 / Icom LAN 会话状态机（纯逻辑，无 I/O、无时钟、无线程）。
///
/// 为什么把状态机单独拿出来：电台握手有十来步（探测 → 登录 → 令牌 → 连接信息
/// → 开流 → 收音频），每步都可能失败并需要区分「同一会话重试」和「整段重连」。
/// 把它写成 `reduce(状态, 事件) → (新状态, 动作)` 的纯函数后，上述所有分支
/// 都能用单元测试钉住（`test/icom_lan_session_engine_test.dart`），不需要电台。
///
/// 运行时（`icom_lan_session.dart`）只负责：把动作翻译成真实 UDP 收发、
/// 把收到的报文翻译成事件。
library;

import 'icom_lan_protocol.dart';

/// 会话阶段。
enum IcomLanPhase {
  stopped,
  openingSockets,
  controlDiscovery,
  authenticating,
  negotiating,
  openingStreams,
  streamsReady,
  receiving,
  reconnectWait,
  failed,
}

/// 重连冷却类别：电台「明确拒绝」时应该等更久，而不是立刻重试。
enum IcomLanRetryCooldown { normal, sessionNotReady, sessionRejected }

/// 电台侧为 CI-V / 音频流分配的端口。
class IcomLanStreamEndpoints {
  const IcomLanStreamEndpoints({required this.civPort, required this.audioPort});

  final int civPort;
  final int audioPort;

  @override
  bool operator ==(Object other) =>
      other is IcomLanStreamEndpoints &&
      other.civPort == civPort &&
      other.audioPort == audioPort;

  @override
  int get hashCode => Object.hash(civPort, audioPort);
}

/// 会话状态（对外只暴露阶段与失败原因；内部标志用于推进状态机）。
class IcomLanSessionState {
  const IcomLanSessionState({
    this.phase = IcomLanPhase.stopped,
    this.retryAttempt = 0,
    this.failureReason,
    this.socketsOpened = false,
    this.discoverySent = false,
    this.controlDiscovered = false,
    this.controlReady = false,
    this.loginSent = false,
    this.loginAccepted = false,
    this.loginToken,
    this.tokenSent = false,
    this.connectionRequestAuthorized = false,
    this.connectionInfoReceived = false,
    this.connectionInfoSettlePending = false,
    this.connectionInfoSent = false,
    this.connectionInfoAttempts = 0,
    this.streamEndpoints,
    this.streamsOpenSent = false,
    this.civReady = false,
    this.audioReady = false,
    this.firstAudioSeen = false,
  });

  final IcomLanPhase phase;
  final int retryAttempt;
  final String? failureReason;

  final bool socketsOpened;
  final bool discoverySent;
  final bool controlDiscovered;
  final bool controlReady;
  final bool loginSent;
  final bool loginAccepted;
  final int? loginToken;
  final bool tokenSent;
  final bool connectionRequestAuthorized;
  final bool connectionInfoReceived;
  final bool connectionInfoSettlePending;
  final bool connectionInfoSent;
  final int connectionInfoAttempts;
  final IcomLanStreamEndpoints? streamEndpoints;
  final bool streamsOpenSent;
  final bool civReady;
  final bool audioReady;
  final bool firstAudioSeen;

  IcomLanSessionState copyWith({
    IcomLanPhase? phase,
    int? retryAttempt,
    Object? failureReason = _unset,
    bool? socketsOpened,
    bool? discoverySent,
    bool? controlDiscovered,
    bool? controlReady,
    bool? loginSent,
    bool? loginAccepted,
    int? loginToken,
    bool? tokenSent,
    bool? connectionRequestAuthorized,
    bool? connectionInfoReceived,
    bool? connectionInfoSettlePending,
    bool? connectionInfoSent,
    int? connectionInfoAttempts,
    IcomLanStreamEndpoints? streamEndpoints,
    bool? streamsOpenSent,
    bool? civReady,
    bool? audioReady,
    bool? firstAudioSeen,
  }) =>
      IcomLanSessionState(
        phase: phase ?? this.phase,
        retryAttempt: retryAttempt ?? this.retryAttempt,
        failureReason: failureReason == _unset
            ? this.failureReason
            : failureReason as String?,
        socketsOpened: socketsOpened ?? this.socketsOpened,
        discoverySent: discoverySent ?? this.discoverySent,
        controlDiscovered: controlDiscovered ?? this.controlDiscovered,
        controlReady: controlReady ?? this.controlReady,
        loginSent: loginSent ?? this.loginSent,
        loginAccepted: loginAccepted ?? this.loginAccepted,
        loginToken: loginToken ?? this.loginToken,
        tokenSent: tokenSent ?? this.tokenSent,
        connectionRequestAuthorized:
            connectionRequestAuthorized ?? this.connectionRequestAuthorized,
        connectionInfoReceived:
            connectionInfoReceived ?? this.connectionInfoReceived,
        connectionInfoSettlePending:
            connectionInfoSettlePending ?? this.connectionInfoSettlePending,
        connectionInfoSent: connectionInfoSent ?? this.connectionInfoSent,
        connectionInfoAttempts:
            connectionInfoAttempts ?? this.connectionInfoAttempts,
        streamEndpoints: streamEndpoints ?? this.streamEndpoints,
        streamsOpenSent: streamsOpenSent ?? this.streamsOpenSent,
        civReady: civReady ?? this.civReady,
        audioReady: audioReady ?? this.audioReady,
        firstAudioSeen: firstAudioSeen ?? this.firstAudioSeen,
      );

  /// 本次 generation 是否已经有过音频（用于决定要不要通知上层「音频中断」）。
  bool get hasLiveAudio =>
      audioReady ||
      firstAudioSeen ||
      phase == IcomLanPhase.streamsReady ||
      phase == IcomLanPhase.receiving;

  static const Object _unset = Object();
}

/// 状态机事件。
sealed class IcomLanEvent {
  const IcomLanEvent();
}

class IcomLanStart extends IcomLanEvent {
  const IcomLanStart();
}

class IcomLanStop extends IcomLanEvent {
  const IcomLanStop();
}

class IcomLanSocketsOpened extends IcomLanEvent {
  const IcomLanSocketsOpened();
}

class IcomLanControlDiscovered extends IcomLanEvent {
  const IcomLanControlDiscovered();
}

class IcomLanControlReady extends IcomLanEvent {
  const IcomLanControlReady();
}

class IcomLanLoginAccepted extends IcomLanEvent {
  const IcomLanLoginAccepted(this.token);

  final int token;
}

class IcomLanLoginRejected extends IcomLanEvent {
  const IcomLanLoginRejected(this.reason);

  final String reason;
}

class IcomLanConnectionRequestAuthorized extends IcomLanEvent {
  const IcomLanConnectionRequestAuthorized();
}

class IcomLanStatusEndpointsReceived extends IcomLanEvent {
  const IcomLanStatusEndpointsReceived(this.endpoints);

  final IcomLanStreamEndpoints endpoints;
}

class IcomLanStatusNotReady extends IcomLanEvent {
  const IcomLanStatusNotReady({
    required this.errorCode,
    required this.disconnectFlag,
  });

  final int errorCode;
  final int disconnectFlag;
}

class IcomLanConnectionInfoReceived extends IcomLanEvent {
  const IcomLanConnectionInfoReceived();
}

class IcomLanConnectionInfoSettleTimerFired extends IcomLanEvent {
  const IcomLanConnectionInfoSettleTimerFired();
}

class IcomLanConnectionInfoRetryTimerFired extends IcomLanEvent {
  const IcomLanConnectionInfoRetryTimerFired();
}

class IcomLanCivReady extends IcomLanEvent {
  const IcomLanCivReady();
}

class IcomLanAudioReady extends IcomLanEvent {
  const IcomLanAudioReady();
}

class IcomLanFirstAudio extends IcomLanEvent {
  const IcomLanFirstAudio();
}

class IcomLanRecoverableFailure extends IcomLanEvent {
  const IcomLanRecoverableFailure(this.reason, {this.cooldown = IcomLanRetryCooldown.normal});

  final String reason;
  final IcomLanRetryCooldown cooldown;
}

class IcomLanRetryTimerFired extends IcomLanEvent {
  const IcomLanRetryTimerFired();
}

class IcomLanRetryDisabled extends IcomLanEvent {
  const IcomLanRetryDisabled();
}

/// 状态机要求运行时执行的动作。
sealed class IcomLanAction {
  const IcomLanAction();
}

class IcomLanOpenSockets extends IcomLanAction {
  const IcomLanOpenSockets();
}

class IcomLanCloseSockets extends IcomLanAction {
  const IcomLanCloseSockets();
}

class IcomLanSendDiscovery extends IcomLanAction {
  const IcomLanSendDiscovery();
}

class IcomLanSendLogin extends IcomLanAction {
  const IcomLanSendLogin();
}

class IcomLanSendTokenConfirmation extends IcomLanAction {
  const IcomLanSendTokenConfirmation(this.token);

  final int token;
}

class IcomLanScheduleConnectionInfoSettle extends IcomLanAction {
  const IcomLanScheduleConnectionInfoSettle();
}

class IcomLanSendConnectionInfo extends IcomLanAction {
  const IcomLanSendConnectionInfo();
}

class IcomLanScheduleConnectionInfoRetry extends IcomLanAction {
  const IcomLanScheduleConnectionInfoRetry();
}

class IcomLanCancelConnectionInfoTimers extends IcomLanAction {
  const IcomLanCancelConnectionInfoTimers();
}

class IcomLanSendOpenStreams extends IcomLanAction {
  const IcomLanSendOpenStreams(this.endpoints);

  final IcomLanStreamEndpoints endpoints;
}

class IcomLanScheduleRetry extends IcomLanAction {
  const IcomLanScheduleRetry(this.attempt, this.cooldown);

  final int attempt;
  final IcomLanRetryCooldown cooldown;
}

class IcomLanCancelRetryTimer extends IcomLanAction {
  const IcomLanCancelRetryTimer();
}

class IcomLanNotifyAudioDiscontinuity extends IcomLanAction {
  const IcomLanNotifyAudioDiscontinuity();
}

/// 归约结果：新状态 + 需要执行的动作。
class IcomLanTransition {
  const IcomLanTransition(this.state, [this.actions = const []]);

  final IcomLanSessionState state;
  final List<IcomLanAction> actions;
}

/// 连接信息重试上限（超过就整段重连）。
const int kIcomLanMaxConnectionInfoAttempts = 4;

/// 收到「会话未就绪」状态时的处置。
enum IcomLanConnectionInfoStatusDecision { ignore, retrySameSession, rejectSession }

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

enum IcomLanConnectionInfoRetryDecision { ignore, retry, exhausted }

/// 连接信息重试计时器到点后的决策。
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

/// 会话状态机。
class IcomLanSessionEngine {
  IcomLanSessionEngine._();

  static IcomLanSessionState _freshAttempt({
    required IcomLanPhase phase,
    int retryAttempt = 0,
    String? failureReason,
  }) =>
      IcomLanSessionState(
        phase: phase,
        retryAttempt: retryAttempt,
        failureReason: failureReason,
      );

  static IcomLanTransition _unchanged(IcomLanSessionState state) =>
      IcomLanTransition(state);

  /// 纯归约：状态 + 事件 → 新状态 + 动作。
  static IcomLanTransition reduce(IcomLanSessionState state, IcomLanEvent event) {
    if (event is IcomLanStart) {
      if (state.phase == IcomLanPhase.stopped ||
          state.phase == IcomLanPhase.failed) {
        return IcomLanTransition(
          _freshAttempt(phase: IcomLanPhase.openingSockets),
          const [IcomLanOpenSockets()],
        );
      }
      return _unchanged(state);
    }

    if (event is IcomLanStop) return _stop(state);

    if (state.phase == IcomLanPhase.stopped ||
        state.phase == IcomLanPhase.failed) {
      return _unchanged(state);
    }

    if (event is IcomLanRecoverableFailure) {
      return _recover(state, event.reason, event.cooldown);
    }

    if (state.phase == IcomLanPhase.reconnectWait) {
      if (event is IcomLanRetryTimerFired) {
        return IcomLanTransition(
          _freshAttempt(
            phase: IcomLanPhase.openingSockets,
            retryAttempt: state.retryAttempt,
            failureReason: state.failureReason,
          ),
          const [IcomLanCancelRetryTimer(), IcomLanOpenSockets()],
        );
      }
      if (event is IcomLanRetryDisabled) {
        return IcomLanTransition(
            state.copyWith(phase: IcomLanPhase.failed));
      }
      return _unchanged(state);
    }

    if (event is IcomLanStatusNotReady) {
      switch (icomLanConnectionInfoStatusDecision(
        connectionInfoSent: state.connectionInfoSent,
        hasStreamEndpoints: state.streamEndpoints != null,
        errorCode: event.errorCode,
        disconnectFlag: event.disconnectFlag,
      )) {
        case IcomLanConnectionInfoStatusDecision.ignore:
          return _unchanged(state);
        case IcomLanConnectionInfoStatusDecision.retrySameSession:
          return IcomLanTransition(
            state.copyWith(failureReason: 'radio session not ready'),
            const [IcomLanScheduleConnectionInfoRetry()],
          );
        case IcomLanConnectionInfoStatusDecision.rejectSession:
          return _recover(state, 'radio session allocation rejected',
              IcomLanRetryCooldown.sessionRejected);
      }
    }

    if (event is IcomLanConnectionInfoRetryTimerFired) {
      switch (icomLanConnectionInfoRetryDecision(
        connectionInfoSent: state.connectionInfoSent,
        hasStreamEndpoints: state.streamEndpoints != null,
        attempts: state.connectionInfoAttempts,
      )) {
        case IcomLanConnectionInfoRetryDecision.ignore:
          return _unchanged(state);
        case IcomLanConnectionInfoRetryDecision.exhausted:
          return _recover(state, 'radio session not ready after connection-info retries',
              IcomLanRetryCooldown.sessionNotReady);
        case IcomLanConnectionInfoRetryDecision.retry:
          return IcomLanTransition(
            state.copyWith(
              connectionInfoAttempts: state.connectionInfoAttempts + 1,
              failureReason: 'waiting for radio session allocation',
            ),
            const [
              IcomLanSendConnectionInfo(),
              IcomLanScheduleConnectionInfoRetry(),
            ],
          );
      }
    }

    final eventActions = <IcomLanAction>[];
    late IcomLanSessionState updated;

    if (event is IcomLanSocketsOpened) {
      updated = state.copyWith(socketsOpened: true);
    } else if (event is IcomLanControlDiscovered) {
      updated = state.copyWith(controlDiscovered: true);
    } else if (event is IcomLanControlReady) {
      updated = state.copyWith(controlReady: true);
    } else if (event is IcomLanLoginAccepted) {
      if (!state.loginSent || state.loginAccepted) {
        updated = state;
      } else {
        updated = state.copyWith(loginAccepted: true, loginToken: event.token);
      }
    } else if (event is IcomLanLoginRejected) {
      if (!state.loginSent || state.loginAccepted) return _unchanged(state);
      return IcomLanTransition(
        _freshAttempt(
          phase: IcomLanPhase.failed,
          retryAttempt: state.retryAttempt,
          failureReason: event.reason,
        ),
        const [IcomLanCloseSockets()],
      );
    } else if (event is IcomLanConnectionRequestAuthorized) {
      updated = state.copyWith(connectionRequestAuthorized: true);
    } else if (event is IcomLanStatusEndpointsReceived) {
      if (!state.connectionInfoSent ||
          state.streamEndpoints == event.endpoints) {
        updated = state;
      } else {
        eventActions.add(const IcomLanCancelConnectionInfoTimers());
        updated = state.copyWith(
          streamEndpoints: event.endpoints,
          connectionInfoSettlePending: false,
        );
      }
    } else if (event is IcomLanConnectionInfoReceived) {
      if (state.streamEndpoints == null) {
        eventActions.add(const IcomLanScheduleConnectionInfoSettle());
        updated = state.copyWith(
          connectionInfoReceived: true,
          connectionInfoSettlePending: true,
        );
      } else {
        updated = state;
      }
    } else if (event is IcomLanConnectionInfoSettleTimerFired) {
      if (state.loginAccepted &&
          state.connectionRequestAuthorized &&
          state.connectionInfoReceived &&
          state.connectionInfoSettlePending &&
          state.streamEndpoints == null) {
        eventActions.add(const IcomLanSendConnectionInfo());
        eventActions.add(const IcomLanScheduleConnectionInfoRetry());
        updated = state.copyWith(
          connectionInfoSettlePending: false,
          connectionInfoSent: true,
          connectionInfoAttempts: state.connectionInfoAttempts + 1,
        );
      } else {
        updated = state;
      }
    } else if (event is IcomLanCivReady) {
      updated = state.copyWith(civReady: true);
    } else if (event is IcomLanAudioReady) {
      updated = state.copyWith(audioReady: true);
    } else if (event is IcomLanFirstAudio) {
      // 真正收到 PCM 才算「这次重连成功」：不要让长会话里攒下的失败把
      // 后续重连永久钉在最大退避上。
      updated = state.copyWith(
        retryAttempt: 0,
        failureReason: null,
        firstAudioSeen: true,
      );
    } else {
      updated = state;
    }

    final advanced = _advance(updated);
    return IcomLanTransition(
      advanced.state,
      [...eventActions, ...advanced.actions],
    );
  }

  static IcomLanTransition _advance(IcomLanSessionState input) {
    var state = input;
    final actions = <IcomLanAction>[];

    if (!state.socketsOpened) return _unchanged(state);

    if (!state.discoverySent) {
      state = state.copyWith(
        phase: IcomLanPhase.controlDiscovery,
        discoverySent: true,
      );
      actions.add(const IcomLanSendDiscovery());
    }

    if (state.controlDiscovered && state.controlReady && !state.loginSent) {
      state = state.copyWith(
        phase: IcomLanPhase.authenticating,
        loginSent: true,
      );
      actions.add(const IcomLanSendLogin());
    }

    if (state.loginAccepted) {
      // 幂等事件重跑归约时，不要把阶段从 OPENING_STREAMS/RECEIVING 退回去。
      if (!state.streamsOpenSent) {
        state = state.copyWith(phase: IcomLanPhase.negotiating);
      }
      if (!state.tokenSent) {
        state = state.copyWith(tokenSent: true);
        actions.add(IcomLanSendTokenConfirmation(state.loginToken!));
      }
    }

    final endpoints = state.streamEndpoints;
    if (state.loginAccepted &&
        state.connectionRequestAuthorized &&
        state.connectionInfoSent &&
        endpoints != null &&
        !state.streamsOpenSent) {
      state = state.copyWith(
        phase: IcomLanPhase.openingStreams,
        streamsOpenSent: true,
      );
      actions.add(IcomLanSendOpenStreams(endpoints));
    }

    if (state.streamsOpenSent && state.civReady && state.audioReady) {
      state = state.copyWith(
        phase: state.firstAudioSeen
            ? IcomLanPhase.receiving
            : IcomLanPhase.streamsReady,
      );
    }

    return IcomLanTransition(state, actions);
  }

  static IcomLanTransition _recover(
    IcomLanSessionState state,
    String reason, [
    IcomLanRetryCooldown cooldown = IcomLanRetryCooldown.normal,
  ]) {
    if (state.phase == IcomLanPhase.reconnectWait) return _unchanged(state);

    final nextAttempt = state.retryAttempt + 1;
    final actions = <IcomLanAction>[const IcomLanCloseSockets()];
    if (state.hasLiveAudio) actions.add(const IcomLanNotifyAudioDiscontinuity());
    actions.add(IcomLanScheduleRetry(nextAttempt, cooldown));

    return IcomLanTransition(
      _freshAttempt(
        phase: IcomLanPhase.reconnectWait,
        retryAttempt: nextAttempt,
        failureReason: reason,
      ),
      actions,
    );
  }

  static IcomLanTransition _stop(IcomLanSessionState state) {
    if (state.phase == IcomLanPhase.stopped) return _unchanged(state);

    final actions = <IcomLanAction>[];
    if (state.phase == IcomLanPhase.reconnectWait) {
      actions.add(const IcomLanCancelRetryTimer());
    }
    if (state.phase != IcomLanPhase.failed &&
        state.phase != IcomLanPhase.reconnectWait) {
      actions.add(const IcomLanCloseSockets());
    }
    if (state.hasLiveAudio) actions.add(const IcomLanNotifyAudioDiscontinuity());
    return IcomLanTransition(const IcomLanSessionState(), actions);
  }
}

/// 该协议里客户端 ID 的构造方式：把本机 IPv4 的后两段与本地端口拼进 32 位。
///
/// 电台按这个 ID 区分客户端，所以每次重连（端口/地址可能变）都要重算。
int icomLanClientIdForEndpoint({int? ipv4LastTwoOctets, required int localPort}) {
  if (localPort <= 0 || localPort > 0xffff) {
    throw IcomLanProtocolException('localPort must be a bound UDP port');
  }
  if (ipv4LastTwoOctets != null) {
    return ((ipv4LastTwoOctets & 0xffff) << 16) | localPort;
  }
  // 拿不到具体路由 IPv4 时的兜底形式（同样来自端点，不用随机值）。
  return 0x00010000 | localPort;
}
