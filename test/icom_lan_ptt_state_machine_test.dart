// SPDX-License-Identifier: GPL-2.0-or-later
// See LICENSING.md: this file is additionally available under GPL-2.0-or-later.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_ptt_state_machine.dart';

class _ScheduledTaskEntry implements IcomLanPttScheduledTask {
  _ScheduledTaskEntry(this.dueTime, this.task);
  final Duration dueTime;
  final void Function() task;
  bool isCancelled = false;

  @override
  void cancel() {
    isCancelled = true;
  }
}

class FakePttScheduler implements IcomLanPttScheduler {
  Duration _currentTime = Duration.zero;
  Duration get currentTime => _currentTime;

  final List<_ScheduledTaskEntry> _tasks = [];

  @override
  IcomLanPttScheduledTask schedule(Duration duration, void Function() task) {
    final entry = _ScheduledTaskEntry(_currentTime + duration, task);
    _tasks.add(entry);
    return entry;
  }

  void advanceTime(Duration duration) {
    _currentTime += duration;
    _runEligibleTasks();
  }

  void advanceTimeToNext() {
    final pending = _tasks.where((t) => !t.isCancelled).toList();
    if (pending.isEmpty) return;
    pending.sort((a, b) => a.dueTime.compareTo(b.dueTime));
    final next = pending.first;
    if (next.dueTime > _currentTime) {
      _currentTime = next.dueTime;
    }
    _runEligibleTasks();
  }

  void _runEligibleTasks() {
    while (true) {
      final eligible = _tasks
          .where((t) => !t.isCancelled && t.dueTime <= _currentTime)
          .toList();
      if (eligible.isEmpty) break;
      eligible.sort((a, b) => a.dueTime.compareTo(b.dueTime));
      final taskToRun = eligible.first;
      _tasks.remove(taskToRun);
      taskToRun.task();
    }
  }

  bool get hasPendingTasks => _tasks.any((t) => !t.isCancelled);
}

class FakePttActions implements IcomLanPttActions {
  final List<Uint8List> sentCivFrames = [];
  final List<Uint8List> sentAudioDatagrams = [];
  final List<IcomLanPttState> stateHistory = [];
  int civSendAttempts = 0;
  int remainingCivFailures = 0;

  @override
  void sendCivFrame(Uint8List frame) {
    civSendAttempts++;
    if (remainingCivFailures > 0) {
      remainingCivFailures--;
      throw StateError('simulated socket failure');
    }
    sentCivFrames.add(Uint8List.fromList(frame));
  }

  @override
  void sendAudioDatagram(Uint8List datagram) {
    sentAudioDatagrams.add(Uint8List.fromList(datagram));
  }

  @override
  void onStateChanged(IcomLanPttState state) {
    stateHistory.add(state);
  }
}

Uint8List ackFrame({int radioAddress = 0xa4, int controllerAddress = 0xe0}) =>
    Uint8List.fromList(
      [0xfe, 0xfe, controllerAddress, radioAddress, 0xfb, 0xfd],
    );

Uint8List nakFrame({int radioAddress = 0xa4, int controllerAddress = 0xe0}) =>
    Uint8List.fromList(
      [0xfe, 0xfe, controllerAddress, radioAddress, 0xfa, 0xfd],
    );

Uint8List pttStatusFrame({
  required bool transmitting,
  int radioAddress = 0xa4,
  int controllerAddress = 0xe0,
}) =>
    Uint8List.fromList([
      0xfe,
      0xfe,
      controllerAddress,
      radioAddress,
      0x1c,
      0x00,
      transmitting ? 0x01 : 0x00,
      0xfd,
    ]);

/// Answers PTT OFF attempts the way a real radio does: every attempt is
/// acknowledged and, when the coordinator asks for a readback, reports RX.
void acknowledgeRelease(
  IcomLanPttStateMachine sm, [
  FakePttScheduler? scheduler,
]) {
  for (var i = 0; i < 50 && sm.state != IcomLanPttState.rxIdle; i++) {
    sm.onCivReceived(ackFrame());
    if (sm.state != IcomLanPttState.rxIdle) {
      sm.onCivReceived(pttStatusFrame(transmitting: false));
    }
    if (sm.state != IcomLanPttState.rxIdle &&
        scheduler != null &&
        scheduler.hasPendingTasks) {
      scheduler.advanceTimeToNext();
    }
  }
  expect(
    sm.state,
    equals(IcomLanPttState.rxIdle),
    reason: 'radio release was not confirmed',
  );
}

void main() {
  group('Ic705PttStateMachine', () {
    test('successfulTransmissionLifecycle', () {
      final actions = FakePttActions();
      final sm = IcomLanPttStateMachine(actions: actions);
      expect(sm.state, equals(IcomLanPttState.rxIdle));
      expect(sm.isTransmitting, isFalse);
      expect(sm.canStreamAudio, isFalse);
      expect(sm.isRadioPttOn, isFalse);

      expect(sm.beginTransmission(), isTrue);
      expect(sm.state, equals(IcomLanPttState.txStreaming));
      expect(sm.isTransmitting, isTrue);
      expect(sm.canStreamAudio, isTrue);
      expect(sm.isRadioPttOn, isTrue);
      expect(actions.sentCivFrames.length, equals(1));
      expect(actions.sentCivFrames[0][6], equals(0x01));

      sm.onCivReceived(ackFrame());
      expect(sm.onAudioStreamingFinished(), isTrue);
      expect(sm.state, equals(IcomLanPttState.draining));
      expect(sm.isTransmitting, isTrue);
      expect(sm.canStreamAudio, isFalse);

      sm.finishTransmission();
      expect(sm.state, equals(IcomLanPttState.draining));
      expect(sm.isRadioPttOn, isTrue);

      acknowledgeRelease(sm);
      expect(sm.state, equals(IcomLanPttState.rxIdle));
      expect(sm.isTransmitting, isFalse);
      expect(sm.canStreamAudio, isFalse);
      expect(sm.isRadioPttOn, isFalse);
      expect(actions.sentCivFrames.length, equals(2));
      expect(actions.sentCivFrames[1][6], equals(0x00));
    });

    test('radioNakForcesRelease', () {
      final actions = FakePttActions();
      final sm = IcomLanPttStateMachine(actions: actions);
      expect(sm.beginTransmission(), isTrue);

      sm.onCivReceived(nakFrame());
      expect(sm.state, equals(IcomLanPttState.draining));
      expect(sm.isRadioPttOn, isTrue);

      acknowledgeRelease(sm);
      expect(sm.state, equals(IcomLanPttState.rxIdle));
      expect(sm.isRadioPttOn, isFalse);
    });

    test('forceReleaseFromStreamingWaitsForOffAck', () {
      final actions = FakePttActions();
      final sm = IcomLanPttStateMachine(actions: actions);
      expect(sm.beginTransmission(), isTrue);

      sm.forceRelease('Testing force release');
      expect(sm.state, equals(IcomLanPttState.draining));
      expect(sm.canStreamAudio, isFalse);
      expect(sm.isRadioPttOn, isTrue);
      expect(actions.sentCivFrames.length, equals(2));
      expect(actions.sentCivFrames[1][6], equals(0x00));

      acknowledgeRelease(sm);
      expect(sm.state, equals(IcomLanPttState.rxIdle));
      expect(sm.isRadioPttOn, isFalse);
    });

    test('finishDoesNotRestartAlreadyPendingRelease', () {
      final actions = FakePttActions();
      final scheduler = FakePttScheduler();
      final sm = IcomLanPttStateMachine(
        actions: actions,
        ackTimeoutMs: 1000,
        absoluteWatchdogMs: 60000,
        scheduler: scheduler,
      );

      expect(sm.beginTransmission(), isTrue);
      sm.forceRelease('session recovery');
      expect(actions.civSendAttempts, equals(2));

      sm.finishTransmission();
      expect(actions.civSendAttempts, equals(2));
      expect(sm.state, equals(IcomLanPttState.draining));

      acknowledgeRelease(sm, scheduler);
      expect(sm.state, equals(IcomLanPttState.rxIdle));
    });

    test('shutdownCancelsFutureRetriesWithoutReportingFalseIdle', () {
      final actions = FakePttActions();
      final scheduler = FakePttScheduler();
      final sm = IcomLanPttStateMachine(
        actions: actions,
        ackTimeoutMs: 20,
        absoluteWatchdogMs: 40,
        scheduler: scheduler,
      );

      expect(sm.beginTransmission(), isTrue);
      expect(sm.onAudioStreamingFinished(), isTrue);
      sm.finishTransmission();
      final attemptsAtShutdown = actions.civSendAttempts;
      sm.shutdown();

      expect(sm.isShutdown, isTrue);
      expect(sm.state, equals(IcomLanPttState.draining));
      expect(sm.isTransmitting, isTrue);
      expect(sm.canStreamAudio, isFalse);
      expect(sm.isRadioPttOn, isTrue);
      expect(sm.beginTransmission(), isFalse);

      scheduler.advanceTime(const Duration(milliseconds: 100));
      expect(actions.civSendAttempts, equals(attemptsAtShutdown));
      expect(sm.state, equals(IcomLanPttState.draining));
      expect(sm.isRadioPttOn, isTrue);
    });

    test('duplicateBeginTransmissionRejectedWhenAlreadyTransmitting', () {
      final actions = FakePttActions();
      final sm = IcomLanPttStateMachine(actions: actions);
      expect(sm.beginTransmission(), isTrue);
      expect(sm.beginTransmission(), isFalse);
      expect(actions.sentCivFrames.length, equals(1));
    });

    test('failedPttOffKeepsTransmitStateUntilRetrySucceeds', () {
      final actions = FakePttActions();
      final scheduler = FakePttScheduler();
      final sm = IcomLanPttStateMachine(
        actions: actions,
        ackTimeoutMs: 10,
        absoluteWatchdogMs: 60000,
        scheduler: scheduler,
      );

      expect(sm.beginTransmission(), isTrue);
      expect(sm.onAudioStreamingFinished(), isTrue);
      actions.remainingCivFailures = 1;
      sm.finishTransmission();

      expect(sm.state, equals(IcomLanPttState.draining));
      expect(sm.isRadioPttOn, isTrue);

      while (actions.civSendAttempts < 3 && scheduler.hasPendingTasks) {
        scheduler.advanceTimeToNext();
      }
      expect(actions.civSendAttempts, greaterThanOrEqualTo(3));

      acknowledgeRelease(sm, scheduler);
      expect(sm.state, equals(IcomLanPttState.rxIdle));
      expect(sm.isRadioPttOn, isFalse);
    });

    test('failedForcedPttOffRetainsAssertedStateAfterRetries', () {
      final actions = FakePttActions();
      final scheduler = FakePttScheduler();
      final sm = IcomLanPttStateMachine(
        actions: actions,
        ackTimeoutMs: 10,
        maxReleaseAttempts: 3,
        scheduler: scheduler,
      );

      expect(sm.beginTransmission(), isTrue);
      actions.remainingCivFailures = 3;
      sm.forceRelease('test failure cleanup');

      while (actions.civSendAttempts < 4 && scheduler.hasPendingTasks) {
        scheduler.advanceTimeToNext();
      }
      expect(actions.civSendAttempts, greaterThanOrEqualTo(4));
      expect(sm.state, equals(IcomLanPttState.draining));
      expect(sm.isTransmitting, isTrue);
      expect(sm.isRadioPttOn, isTrue);
    });

    test('watchdogRetriesAfterAllLocalPttOffSendsFail', () {
      final actions = FakePttActions();
      final scheduler = FakePttScheduler();
      final sm = IcomLanPttStateMachine(
        actions: actions,
        ackTimeoutMs: 10,
        absoluteWatchdogMs: 80,
        maxReleaseAttempts: 3,
        scheduler: scheduler,
      );

      expect(sm.beginTransmission(), isTrue);
      actions.remainingCivFailures = 3;
      sm.finishTransmission();

      while (actions.civSendAttempts < 5 && scheduler.hasPendingTasks) {
        scheduler.advanceTimeToNext();
      }
      expect(actions.civSendAttempts, greaterThanOrEqualTo(5));
      expect(sm.state, equals(IcomLanPttState.draining));
      expect(sm.isRadioPttOn, isTrue);

      acknowledgeRelease(sm, scheduler);
      expect(sm.state, equals(IcomLanPttState.rxIdle));
      expect(sm.isRadioPttOn, isFalse);
    });

    test('missingOffAckNeverReportsFalseIdle', () {
      final actions = FakePttActions();
      final scheduler = FakePttScheduler();
      final sm = IcomLanPttStateMachine(
        actions: actions,
        ackTimeoutMs: 10,
        absoluteWatchdogMs: 60000,
        maxReleaseAttempts: 2,
        scheduler: scheduler,
      );

      expect(sm.beginTransmission(), isTrue);
      expect(sm.onAudioStreamingFinished(), isTrue);
      sm.finishTransmission();

      while (actions.civSendAttempts < 3 && scheduler.hasPendingTasks) {
        scheduler.advanceTimeToNext();
      }
      expect(actions.civSendAttempts, greaterThanOrEqualTo(3));
      expect(sm.state, equals(IcomLanPttState.draining));
      expect(sm.isTransmitting, isTrue);
      expect(sm.isRadioPttOn, isTrue);

      acknowledgeRelease(sm, scheduler);
      expect(sm.state, equals(IcomLanPttState.rxIdle));
      expect(sm.isRadioPttOn, isFalse);
    });

    test('delayedOnAckCannotMasqueradeAsOffAck', () {
      final actions = FakePttActions();
      final sm = IcomLanPttStateMachine(actions: actions);

      expect(sm.beginTransmission(), isTrue);
      sm.finishTransmission();
      expect(sm.state, equals(IcomLanPttState.draining));
      expect(actions.sentCivFrames.length, equals(2));
      expect(actions.sentCivFrames[1][6], equals(0x00));

      // The first ACK can still belong to the earlier PTT ON command.
      sm.onCivReceived(ackFrame());
      expect(sm.state, equals(IcomLanPttState.draining));
      expect(sm.isRadioPttOn, isTrue);
      expect(actions.sentCivFrames.length, equals(3));
      expect(actions.sentCivFrames[2][4], equals(0x1c));
      expect(actions.sentCivFrames[2][5], equals(0x00));
      expect(actions.sentCivFrames[2].length, equals(7));

      // If readback still says TX, retry PTT OFF instead of reporting false RX.
      sm.onCivReceived(pttStatusFrame(transmitting: true));
      expect(sm.state, equals(IcomLanPttState.draining));
      expect(sm.isRadioPttOn, isTrue);
      expect(actions.sentCivFrames.length, equals(4));
      expect(actions.sentCivFrames[3][6], equals(0x00));

      sm.onCivReceived(ackFrame());
      expect(sm.state, equals(IcomLanPttState.draining));
      expect(actions.sentCivFrames.length, equals(5));
      sm.onCivReceived(pttStatusFrame(transmitting: false));
      expect(sm.state, equals(IcomLanPttState.rxIdle));
      expect(sm.isRadioPttOn, isFalse);
    });

    test('offNakTriggersImmediateRetry', () {
      final actions = FakePttActions();
      final sm = IcomLanPttStateMachine(actions: actions);

      expect(sm.beginTransmission(), isTrue);
      sm.onCivReceived(ackFrame());
      expect(sm.onAudioStreamingFinished(), isTrue);
      sm.finishTransmission();
      sm.onCivReceived(nakFrame());
      expect(actions.sentCivFrames.length, equals(3));
      expect(sm.state, equals(IcomLanPttState.draining));

      acknowledgeRelease(sm);
      expect(sm.state, equals(IcomLanPttState.rxIdle));
      expect(sm.isRadioPttOn, isFalse);
    });

    test('beginTransmissionSendFailureResetsPendingCommand', () {
      final actions = FakePttActions()..remainingCivFailures = 1;
      final sm = IcomLanPttStateMachine(actions: actions);

      expect(() => sm.beginTransmission(), throwsA(isA<StateError>()));
      expect(sm.state, equals(IcomLanPttState.rxIdle));
      expect(sm.isTransmitting, isFalse);
      expect(sm.isRadioPttOn, isFalse);
    });

    test('verifyReleaseSendFailureRetriesRelease', () {
      final actions = FakePttActions();
      final scheduler = FakePttScheduler();
      final sm = IcomLanPttStateMachine(
        actions: actions,
        scheduler: scheduler,
      );

      expect(sm.beginTransmission(), isTrue);
      sm.finishTransmission(); // requiresReadback = true
      expect(actions.sentCivFrames.length, equals(2));

      actions.remainingCivFailures = 1;
      sm.onCivReceived(ackFrame()); // triggers verifyRelease() which throws
      expect(sm.state, equals(IcomLanPttState.draining));

      acknowledgeRelease(sm, scheduler);
      expect(sm.state, equals(IcomLanPttState.rxIdle));
      expect(sm.isRadioPttOn, isFalse);
    });

    test('invalidCivFramesIgnored', () {
      final actions = FakePttActions();
      final sm = IcomLanPttStateMachine(actions: actions);

      expect(sm.beginTransmission(), isTrue);

      // Wrong preamble
      sm.onCivReceived(Uint8List.fromList([0x00, 0xfe, 0xe0, 0xa4, 0xfb, 0xfd]));
      // Wrong address
      sm.onCivReceived(Uint8List.fromList([0xfe, 0xfe, 0x11, 0xa4, 0xfb, 0xfd]));
      // Wrong terminator
      sm.onCivReceived(Uint8List.fromList([0xfe, 0xfe, 0xe0, 0xa4, 0xfb, 0x00]));
      // Too short
      sm.onCivReceived(Uint8List.fromList([0xfe, 0xfe, 0xe0]));

      expect(sm.state, equals(IcomLanPttState.txStreaming));
    });
  });
}
