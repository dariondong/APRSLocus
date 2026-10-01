// IC-705 / Icom LAN 会话状态机回归测试
//
// 覆盖的是「握手推进」与「失败恢复」两类判据：正常路径必须一步步推进；
// 重复/乱序事件必须幂等；可恢复失败必须关套接字 + 通知音频中断 + 按次数退避；
// 电台明确拒绝必须与「暂时没准备好」区分开。
import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_session_engine.dart';

const endpoints = IcomLanStreamEndpoints(civPort: 50002, audioPort: 50003);

IcomLanSessionState step(
  IcomLanSessionState state,
  IcomLanEvent event,
  IcomLanPhase expectedPhase, [
  List<IcomLanAction> expectedActions = const [],
]) {
  final transition = IcomLanSessionEngine.reduce(state, event);
  expect(transition.state.phase, expectedPhase,
      reason: 'unexpected phase after ${event.runtimeType}');
  expect(transition.actions.map((a) => a.runtimeType).toList(),
      expectedActions.map((a) => a.runtimeType).toList(),
      reason: 'unexpected actions after ${event.runtimeType}');
  return transition.state;
}

/// 已完成探测与登录发送、等待登录应答的状态。
IcomLanSessionState authenticatedState() {
  var state = IcomLanSessionEngine.reduce(
          const IcomLanSessionState(), const IcomLanStart())
      .state;
  state = IcomLanSessionEngine.reduce(state, const IcomLanSocketsOpened()).state;
  state =
      IcomLanSessionEngine.reduce(state, const IcomLanControlDiscovered()).state;
  state = IcomLanSessionEngine.reduce(state, const IcomLanControlReady()).state;
  return state;
}

/// 已完成登录应答、等待连接信息的后续事实的状态。
IcomLanSessionState negotiatingState() {
  final state = IcomLanSessionEngine.reduce(
      authenticatedState(), const IcomLanLoginAccepted(0x12345678));
  return state.state;
}

/// 已进入 RECEIVING 的状态。
IcomLanSessionState receivingState() {
  var state = negotiatingState();
  state = IcomLanSessionEngine.reduce(
          state, const IcomLanConnectionRequestAuthorized())
      .state;
  state =
      IcomLanSessionEngine.reduce(state, const IcomLanConnectionInfoReceived())
          .state;
  state = IcomLanSessionEngine.reduce(
          state, const IcomLanConnectionInfoSettleTimerFired())
      .state;
  state = IcomLanSessionEngine.reduce(
          state, const IcomLanStatusEndpointsReceived(endpoints))
      .state;
  state = IcomLanSessionEngine.reduce(state, const IcomLanCivReady()).state;
  state = IcomLanSessionEngine.reduce(state, const IcomLanAudioReady()).state;
  state = IcomLanSessionEngine.reduce(state, const IcomLanFirstAudio()).state;
  return state;
}

void main() {
  group('握手推进', () {
    test('正常路径逐级推进到 RECEIVING', () {
      var state = IcomLanSessionEngine.reduce(
              const IcomLanSessionState(), const IcomLanStart())
          .state;
      expect(state.phase, IcomLanPhase.openingSockets);

      state = step(state, const IcomLanSocketsOpened(),
          IcomLanPhase.controlDiscovery, const [IcomLanSendDiscovery()]);
      state = step(state, const IcomLanControlDiscovered(),
          IcomLanPhase.controlDiscovery);
      state = step(state, const IcomLanControlReady(),
          IcomLanPhase.authenticating, const [IcomLanSendLogin()]);
      state = step(
          state,
          const IcomLanLoginAccepted(0x12345678),
          IcomLanPhase.negotiating,
          const [IcomLanSendTokenConfirmation(0x12345678)]);
      state = step(state, const IcomLanConnectionRequestAuthorized(),
          IcomLanPhase.negotiating);
      state = step(state, const IcomLanConnectionInfoReceived(),
          IcomLanPhase.negotiating,
          const [IcomLanScheduleConnectionInfoSettle()]);
      state = step(state, const IcomLanConnectionInfoSettleTimerFired(),
          IcomLanPhase.negotiating,
          const [IcomLanSendConnectionInfo(), IcomLanScheduleConnectionInfoRetry()]);
      state = step(state, const IcomLanStatusEndpointsReceived(endpoints),
          IcomLanPhase.openingStreams,
          const [IcomLanCancelConnectionInfoTimers(), IcomLanSendOpenStreams(endpoints)]);
      state = step(state, const IcomLanCivReady(), IcomLanPhase.openingStreams);
      state = step(state, const IcomLanAudioReady(), IcomLanPhase.streamsReady);
      state = step(state, const IcomLanFirstAudio(), IcomLanPhase.receiving);

      expect(state.firstAudioSeen, isTrue);
      expect(state.streamEndpoints, endpoints);
    });

    test('重复与乱序的控制事件是幂等的', () {
      var state = IcomLanSessionEngine.reduce(
              const IcomLanSessionState(), const IcomLanStart())
          .state;

      state = step(state, const IcomLanControlReady(), IcomLanPhase.openingSockets);
      state = step(state, const IcomLanControlReady(), IcomLanPhase.openingSockets);
      state = step(state, const IcomLanControlDiscovered(), IcomLanPhase.openingSockets);
      state = step(state, const IcomLanSocketsOpened(), IcomLanPhase.authenticating,
          const [IcomLanSendDiscovery(), IcomLanSendLogin()]);

      state = step(state, const IcomLanControlDiscovered(), IcomLanPhase.authenticating);
      state = step(state, const IcomLanControlReady(), IcomLanPhase.authenticating);
      step(state, const IcomLanSocketsOpened(), IcomLanPhase.authenticating);
    });

    test('乱序的协商事实在前提齐备后各推进一次', () {
      var state = authenticatedState();

      state = step(state, const IcomLanConnectionInfoReceived(),
          IcomLanPhase.authenticating,
          const [IcomLanScheduleConnectionInfoSettle()]);
      state = step(state, const IcomLanStatusEndpointsReceived(endpoints),
          IcomLanPhase.authenticating);
      state = step(state, const IcomLanConnectionRequestAuthorized(),
          IcomLanPhase.authenticating);
      state = step(state, const IcomLanLoginAccepted(99), IcomLanPhase.negotiating,
          const [IcomLanSendTokenConfirmation(99)]);
      state = step(state, const IcomLanConnectionInfoSettleTimerFired(),
          IcomLanPhase.negotiating,
          const [IcomLanSendConnectionInfo(), IcomLanScheduleConnectionInfoRetry()]);
      state = step(state, const IcomLanStatusEndpointsReceived(endpoints),
          IcomLanPhase.openingStreams,
          const [IcomLanCancelConnectionInfoTimers(), IcomLanSendOpenStreams(endpoints)]);

      state = step(state, const IcomLanLoginAccepted(100), IcomLanPhase.openingStreams);
      state = step(state, const IcomLanConnectionRequestAuthorized(),
          IcomLanPhase.openingStreams);
      state = step(state, const IcomLanConnectionInfoReceived(),
          IcomLanPhase.openingStreams);
      step(state, const IcomLanStatusEndpointsReceived(endpoints),
          IcomLanPhase.openingStreams);
    });

    test('重复的连接信息在 settle 计时器前被合并', () {
      var state = negotiatingState();
      state = IcomLanSessionEngine.reduce(
              state, const IcomLanConnectionRequestAuthorized())
          .state;

      state = step(state, const IcomLanConnectionInfoReceived(),
          IcomLanPhase.negotiating,
          const [IcomLanScheduleConnectionInfoSettle()]);
      state = step(state, const IcomLanConnectionInfoReceived(),
          IcomLanPhase.negotiating,
          const [IcomLanScheduleConnectionInfoSettle()]);
      expect(state.connectionInfoAttempts, 0);
      expect(state.connectionInfoSent, isFalse);
    });
  });

  group('失败与恢复', () {
    test('可恢复失败：关套接字 + 通知音频中断 + 退避重连', () {
      final state = receivingState();
      expect(state.phase, IcomLanPhase.receiving);

      final transition = IcomLanSessionEngine.reduce(
          state, const IcomLanRecoverableFailure('audio timeout'));
      expect(transition.state.phase, IcomLanPhase.reconnectWait);
      expect(transition.state.retryAttempt, 1);
      expect(transition.state.failureReason, 'audio timeout');
      expect(transition.actions.map((a) => a.runtimeType).toList(), [
        IcomLanCloseSockets,
        IcomLanNotifyAudioDiscontinuity,
        IcomLanScheduleRetry,
      ]);
      final scheduled = transition.actions.last as IcomLanScheduleRetry;
      expect(scheduled.attempt, 1);
      expect(scheduled.cooldown, IcomLanRetryCooldown.normal);

      // 重连等待期间再来一次失败：状态不变（不叠加退避）。
      final again = IcomLanSessionEngine.reduce(transition.state,
          const IcomLanRecoverableFailure('duplicate'));
      expect(again.state.retryAttempt, 1);
      expect(again.actions, isEmpty);

      // 计时器到点：清空上一轮的事实，重新开套接字。
      final retry = IcomLanSessionEngine.reduce(
          again.state, const IcomLanRetryTimerFired());
      expect(retry.state.phase, IcomLanPhase.openingSockets);
      expect(retry.state.retryAttempt, 1);
      expect(retry.actions.map((a) => a.runtimeType).toList(),
          [IcomLanCancelRetryTimer, IcomLanOpenSockets]);
      expect(retry.state.civReady, isFalse);
      expect(retry.state.audioReady, isFalse);
      expect(retry.state.firstAudioSeen, isFalse);
      expect(retry.state.streamEndpoints, isNull);
    });

    test('重连等待期间被禁用重试则进入失败态', () {
      final waiting = IcomLanSessionEngine.reduce(receivingState(),
              const IcomLanRecoverableFailure('boom'))
          .state;
      final failed = IcomLanSessionEngine.reduce(
          waiting, const IcomLanRetryDisabled());
      expect(failed.state.phase, IcomLanPhase.failed);
    });

    test('登录被拒直接失败并关闭套接字（不进入重连）', () {
      final transition = IcomLanSessionEngine.reduce(
          authenticatedState(), const IcomLanLoginRejected('authentication rejected'));
      expect(transition.state.phase, IcomLanPhase.failed);
      expect(transition.state.failureReason, 'authentication rejected');
      expect(transition.actions.map((a) => a.runtimeType).toList(),
          [IcomLanCloseSockets]);
    });

    test('会话未就绪：已发连接信息则同会话重试，否则忽略', () {
      final negotiating = negotiatingState();
      final ignored = IcomLanSessionEngine.reduce(negotiating,
          const IcomLanStatusNotReady(errorCode: 0, disconnectFlag: 0));
      expect(ignored.actions, isEmpty);
      // 尚未发出连接信息 → 这条状态与本次协商无关，忽略。
      expect(ignored.state.phase, IcomLanPhase.negotiating);

      // 连上信息之后再报「未就绪」→ 同会话重试。
      var state = IcomLanSessionEngine.reduce(
              negotiating, const IcomLanConnectionRequestAuthorized())
          .state;
      state =
          IcomLanSessionEngine.reduce(state, const IcomLanConnectionInfoReceived())
              .state;
      state = IcomLanSessionEngine.reduce(
              state, const IcomLanConnectionInfoSettleTimerFired())
          .state;
      final retry = IcomLanSessionEngine.reduce(state,
          const IcomLanStatusNotReady(errorCode: 0, disconnectFlag: 0));
      expect(retry.actions.map((a) => a.runtimeType).toList(),
          [IcomLanScheduleConnectionInfoRetry]);
      expect(retry.state.failureReason, 'radio session not ready');

      // 电台明确拒绝（errorCode/disconnectFlag 非 0）→ 整段重连且冷却更长。
      final rejected = IcomLanSessionEngine.reduce(state,
          const IcomLanStatusNotReady(errorCode: 1, disconnectFlag: 0));
      expect(rejected.state.phase, IcomLanPhase.reconnectWait);
      final scheduled = rejected.actions.last as IcomLanScheduleRetry;
      expect(scheduled.cooldown, IcomLanRetryCooldown.sessionRejected);
    });

    test('连接信息重试耗尽后整段重连', () {
      var state = negotiatingState();
      state = IcomLanSessionEngine.reduce(
              state, const IcomLanConnectionRequestAuthorized())
          .state;
      state =
          IcomLanSessionEngine.reduce(state, const IcomLanConnectionInfoReceived())
              .state;
      state = IcomLanSessionEngine.reduce(
              state, const IcomLanConnectionInfoSettleTimerFired())
          .state;
      expect(state.connectionInfoAttempts, 1);

      for (var i = state.connectionInfoAttempts;
          i < kIcomLanMaxConnectionInfoAttempts;
          i++) {
        state = IcomLanSessionEngine.reduce(
                state, const IcomLanConnectionInfoRetryTimerFired())
            .state;
      }
      final exhausted = IcomLanSessionEngine.reduce(
          state, const IcomLanConnectionInfoRetryTimerFired());
      expect(exhausted.state.phase, IcomLanPhase.reconnectWait);
      final scheduled = exhausted.actions.last as IcomLanScheduleRetry;
      expect(scheduled.cooldown, IcomLanRetryCooldown.sessionNotReady);
    });

    test('停止：关套接字、通知音频中断、回到停止态', () {
      final transition = IcomLanSessionEngine.reduce(
          receivingState(), const IcomLanStop());
      expect(transition.state.phase, IcomLanPhase.stopped);
      expect(transition.actions.map((a) => a.runtimeType).toList(),
          [IcomLanCloseSockets, IcomLanNotifyAudioDiscontinuity]);
    });

    test('失败态下的事件不再推进状态机', () {
      final failed = IcomLanSessionEngine.reduce(authenticatedState(),
              const IcomLanLoginRejected('nope'))
          .state;
      final ignored =
          IcomLanSessionEngine.reduce(failed, const IcomLanSocketsOpened());
      expect(ignored.state.phase, IcomLanPhase.failed);
      expect(ignored.actions, isEmpty);

      final restarted =
          IcomLanSessionEngine.reduce(failed, const IcomLanStart());
      expect(restarted.state.phase, IcomLanPhase.openingSockets);
    });
  });

  group('客户端 ID 构造', () {
    test('用本机 IPv4 后两段 + 本地端口拼成', () {
      expect(icomLanClientIdForEndpoint(ipv4LastTwoOctets: 0x0102, localPort: 50001),
          0x0102c351);
    });

    test('拿不到路由地址时用端点兜底，且不做随机', () {
      final id = icomLanClientIdForEndpoint(localPort: 50001);
      expect(id, 0x0001c351);
      expect(icomLanClientIdForEndpoint(localPort: 50001), id);
    });
  });
}
