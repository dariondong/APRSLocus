// SPDX-License-Identifier: GPL-2.0-or-later
// See LICENSING.md: this file is additionally available under GPL-2.0-or-later.

library;

import 'dart:async';
import 'dart:typed_data';

import 'icom_lan_protocol.dart';

/// States of the IC-705 PTT coordinator.
enum IcomLanPttState {
  rxIdle,
  txStreaming,
  draining,
}

/// Callbacks for PTT state machine actions.
abstract class IcomLanPttActions {
  void sendCivFrame(Uint8List frame);
  void sendAudioDatagram(Uint8List datagram);
  void onStateChanged(IcomLanPttState state);
}

/// 可取消的定时任务句柄（抽象 ScheduledFuture / Timer）。
abstract class IcomLanPttScheduledTask {
  void cancel();
}

/// 定时器调度接口（便于单元测试注入手动推进的时钟）。
abstract class IcomLanPttScheduler {
  IcomLanPttScheduledTask schedule(Duration duration, void Function() task);
}

/// 基于 dart:async Timer 的默认调度器。
class IcomLanDefaultPttScheduler implements IcomLanPttScheduler {
  const IcomLanDefaultPttScheduler();

  @override
  IcomLanPttScheduledTask schedule(Duration duration, void Function() task) {
    return _TimerScheduledTask(Timer(duration, task));
  }
}

class _TimerScheduledTask implements IcomLanPttScheduledTask {
  _TimerScheduledTask(this._timer);

  final Timer _timer;

  @override
  void cancel() {
    _timer.cancel();
  }
}

enum _PendingPttCommand { on, off, verifyOff }

/// Fail-safe PTT and TX audio coordinator for IC-705 over Wi-Fi CI-V and Audio UDP.
///
/// A release is considered confirmed only after a radio ACK. If local sends fail
/// or the ACK is lost, the state deliberately remains asserted and the absolute
/// watchdog keeps retrying rather than reporting a false RX state.
///
/// [shutdown] terminates this coordinator's local lifetime only. It deliberately
/// does not report rxIdle or clear [isRadioPttOn], because losing the local
/// session is not evidence that the radio actually released PTT.
class IcomLanPttStateMachine {
  IcomLanPttStateMachine({
    required this.actions,
    this.radioAddress = IcomLanCivCommands.defaultRadioAddress,
    this.controllerAddress = IcomLanCivCommands.defaultControllerAddress,
    this.ackTimeoutMs = defaultAckTimeoutMs,
    this.absoluteWatchdogMs = defaultWatchdogMs,
    this.maxReleaseAttempts = defaultReleaseAttempts,
    IcomLanPttScheduler? scheduler,
    this.onLog,
  }) : _scheduler = scheduler ?? const IcomLanDefaultPttScheduler() {
    if (ackTimeoutMs <= 0) {
      throw ArgumentError('ackTimeoutMs must be positive');
    }
    if (absoluteWatchdogMs <= 0) {
      throw ArgumentError('absoluteWatchdogMs must be positive');
    }
    if (maxReleaseAttempts <= 0) {
      throw ArgumentError('maxReleaseAttempts must be positive');
    }
    _publishState();
  }

  static const int civAck = 0xfb;
  static const int civNak = 0xfa;
  static const int _civTransceiverStatus = 0x1c;
  static const int _civPttSubcommand = 0x00;
  static const int _pttStatusRx = 0x00;
  static const int _pttStatusTx = 0x01;
  static const int defaultAckTimeoutMs = 500;
  static const int defaultWatchdogMs = 5000;
  static const int defaultReleaseAttempts = 3;

  final IcomLanPttActions actions;
  final int radioAddress;
  final int controllerAddress;
  final int ackTimeoutMs;
  final int absoluteWatchdogMs;
  final int maxReleaseAttempts;
  final IcomLanPttScheduler _scheduler;
  final void Function(String message)? onLog;

  IcomLanPttState _state = IcomLanPttState.rxIdle;
  IcomLanPttState get state => _state;

  bool _isPttAsserted = false;
  IcomLanPttScheduledTask? _watchdogTask;
  IcomLanPttScheduledTask? _releaseTask;
  _PendingPttCommand? _pendingCommand;
  bool _releaseRequiresReadback = false;
  int _releaseAttempts = 0;
  bool _shutdown = false;

  /// 单线程事件循环下的方法同步保护封装（对应 Kotlin 的 @Synchronized）。
  T _lock<T>(T Function() action) => action();

  void _log(String message) {
    onLog?.call('[IC705.PTT] $message');
  }

  /// True while the radio may still have PTT asserted.
  bool get isTransmitting => _state != IcomLanPttState.rxIdle;

  /// True only while TX audio is allowed to continue being emitted.
  bool get canStreamAudio =>
      _state == IcomLanPttState.txStreaming && _lock(() => !_shutdown);

  bool get isRadioPttOn => _isPttAsserted;

  bool get isShutdown => _lock(() => _shutdown);

  void onCivReceived(Uint8List civFrame) => _lock(() {
        if (_shutdown) return;
        if (civFrame.length >= 6 &&
            civFrame[0] == 0xfe &&
            civFrame[1] == 0xfe &&
            civFrame[2] == controllerAddress &&
            civFrame[3] == radioAddress &&
            civFrame[civFrame.length - 1] == 0xfd) {
          switch (civFrame[4]) {
            case civAck:
              _handleAck();
              break;
            case civNak:
              _handleNak();
              break;
            case _civTransceiverStatus:
              if (civFrame.length >= 8 &&
                  civFrame[5] == _civPttSubcommand) {
                _handlePttStatus(civFrame[6]);
              }
              break;
          }
        }
      });

  bool beginTransmission() => _lock(() {
        if (_shutdown || _state != IcomLanPttState.rxIdle) return false;
        _log('ptt_on_requested');
        _cancelReleaseTimer();
        _releaseRequiresReadback = false;
        _pendingCommand = _PendingPttCommand.on;
        try {
          _sendPttCommand(true);
        } catch (error) {
          _pendingCommand = null;
          _log('ptt_on_send_failed: error=$error');
          rethrow;
        }
        _isPttAsserted = true;
        _scheduleWatchdog();
        _transitionTo(IcomLanPttState.txStreaming);
        return true;
      });

  bool onAudioStreamingStarted() =>
      _lock(() => !_shutdown && _state == IcomLanPttState.txStreaming);

  bool onAudioStreamingFinished() => _lock(() {
        if (_shutdown || _state != IcomLanPttState.txStreaming) return false;
        _transitionTo(IcomLanPttState.draining);
        return true;
      });

  void finishTransmission() => _lock(() {
        if (_shutdown || _state == IcomLanPttState.rxIdle) return;
        if (_state == IcomLanPttState.txStreaming) {
          _transitionTo(IcomLanPttState.draining);
        }
        if (_pendingCommand == _PendingPttCommand.off ||
            _pendingCommand == _PendingPttCommand.verifyOff) {
          return;
        }
        _startRelease('Transmission finished');
      });

  void forceRelease([String reason = 'Forced release']) => _lock(() {
        if (_shutdown) return;
        _cancelWatchdog();
        if (_isPttAsserted || _state != IcomLanPttState.rxIdle) {
          _log(
            'force_release: reason=$reason, state=$_state, ptt_asserted=$_isPttAsserted',
          );
          if (_state == IcomLanPttState.txStreaming) {
            _transitionTo(IcomLanPttState.draining);
          }
          if (_pendingCommand != _PendingPttCommand.off &&
              _pendingCommand != _PendingPttCommand.verifyOff) {
            _startRelease(reason);
          }
        }
      });

  /// Cancels all future local PTT callbacks without claiming the radio is in RX.
  /// This is used only when the owning session is permanently being destroyed.
  void shutdown() => _lock(() {
        if (_shutdown) return;
        _shutdown = true;
        _cancelReleaseTimer();
        _cancelWatchdog();
        _pendingCommand = null;
        _releaseAttempts = 0;
        _log(
          'coordinator_shutdown: state=$_state, ptt_asserted=$_isPttAsserted',
        );
        _publishState();
      });

  void _handleAck() {
    switch (_pendingCommand) {
      case _PendingPttCommand.on:
        _pendingCommand = null;
        _log('ptt_on_ack: state=$_state');
        break;
      case _PendingPttCommand.off:
        _log(
          'ptt_off_ack: attempts=$_releaseAttempts, requires_readback=$_releaseRequiresReadback',
        );
        if (_releaseRequiresReadback) {
          _verifyRelease();
        } else {
          _completeRelease();
        }
        break;
      case _PendingPttCommand.verifyOff:
        _log('ack_while_verifying_ptt_off: state=$_state');
        break;
      case null:
        _log('unexpected_ack: state=$_state');
        break;
    }
  }

  void _handleNak() {
    switch (_pendingCommand) {
      case _PendingPttCommand.off:
        _log('ptt_off_nak: attempt=$_releaseAttempts');
        _cancelReleaseTimer();
        if (_releaseAttempts < maxReleaseAttempts) {
          _attemptRelease('Radio rejected PTT OFF command (NAK)');
        } else {
          _pendingCommand = null;
          _log(
            'ptt_off_rejected: attempts=$_releaseAttempts, retaining_asserted_state=true',
          );
          _scheduleWatchdog();
        }
        break;
      case _PendingPttCommand.on:
        forceRelease('Radio rejected PTT ON command (NAK)');
        break;
      case _PendingPttCommand.verifyOff:
        _log('ptt_off_verify_nak: attempt=$_releaseAttempts');
        _cancelReleaseTimer();
        _pendingCommand = null;
        if (_releaseAttempts < maxReleaseAttempts) {
          _attemptRelease('Radio rejected PTT state readback (NAK)');
        } else {
          _scheduleWatchdog();
        }
        break;
      case null:
        if (isTransmitting) {
          forceRelease(
            'Radio returned an unexpected NAK while transmitting',
          );
        } else {
          _log('unexpected_nak');
        }
        break;
    }
  }

  void _startRelease(String reason) {
    if (_shutdown) return;
    _cancelReleaseTimer();
    _releaseRequiresReadback = _pendingCommand == _PendingPttCommand.on;
    _releaseAttempts = 0;
    _attemptRelease(reason);
  }

  void _attemptRelease(String reason) {
    if (_shutdown || (!_isPttAsserted && _state == IcomLanPttState.rxIdle)) {
      return;
    }
    _releaseAttempts += 1;
    _pendingCommand = _PendingPttCommand.off;
    _log(
      'ptt_off_attempt: attempt=$_releaseAttempts, max_attempts=$maxReleaseAttempts, reason=$reason',
    );
    bool sendSucceeded;
    try {
      _sendPttCommand(false);
      sendSucceeded = true;
    } catch (error) {
      _pendingCommand = null;
      _log(
        'ptt_off_send_failed: attempt=$_releaseAttempts, max_attempts=$maxReleaseAttempts, reason=$reason, error=$error',
      );
      sendSucceeded = false;
    }

    if (_releaseAttempts < maxReleaseAttempts) {
      _scheduleReleaseTimer(reason);
    } else if (sendSucceeded) {
      _scheduleReleaseTimer(reason);
    } else {
      _log(
        'ptt_off_all_sends_failed: attempts=$_releaseAttempts, retaining_asserted_state=true',
      );
      _scheduleWatchdog();
    }
  }

  void _verifyRelease() {
    if (_shutdown) return;
    _cancelReleaseTimer();
    _pendingCommand = _PendingPttCommand.verifyOff;
    _log('ptt_off_verify_requested: attempts=$_releaseAttempts');
    try {
      actions.sendCivFrame(
        IcomLanCivCommands.buildPttQueryFrame(
          radioAddress: radioAddress,
          controllerAddress: controllerAddress,
        ),
      );
      _scheduleReleaseTimer('PTT OFF state verification timed out');
    } catch (error) {
      _pendingCommand = null;
      _log(
        'ptt_off_verify_send_failed: attempts=$_releaseAttempts, error=$error',
      );
      if (_releaseAttempts < maxReleaseAttempts) {
        _attemptRelease('PTT OFF state verification send failed');
      } else {
        _scheduleWatchdog();
      }
    }
  }

  void _handlePttStatus(int status) {
    if (_pendingCommand != _PendingPttCommand.verifyOff) {
      _log('unexpected_ptt_status: status=$status, state=$_state');
      return;
    }

    switch (status) {
      case _pttStatusRx:
        _log('ptt_off_verified: attempts=$_releaseAttempts');
        _completeRelease();
        break;
      case _pttStatusTx:
        _cancelReleaseTimer();
        _pendingCommand = null;
        _log('ptt_still_on_after_off: attempts=$_releaseAttempts');
        if (_releaseAttempts < maxReleaseAttempts) {
          _attemptRelease('PTT state readback still reports TX');
        } else {
          _scheduleWatchdog();
        }
        break;
      default:
        _log('unexpected_ptt_status_value: status=$status, state=$_state');
        break;
    }
  }

  void _scheduleReleaseTimer(String reason) {
    if (_shutdown) return;
    _cancelReleaseTimer();
    _releaseTask = _scheduler.schedule(
      Duration(milliseconds: ackTimeoutMs),
      () => _lock(() {
        _releaseTask = null;
        if (_shutdown) return;
        if (!_isPttAsserted && _state == IcomLanPttState.rxIdle) return;
        if (_releaseAttempts < maxReleaseAttempts) {
          _log(
            'ptt_off_ack_timeout_retry: timeout_ms=$ackTimeoutMs, attempt=$_releaseAttempts',
          );
          _attemptRelease(reason);
        } else {
          _pendingCommand = null;
          _log(
            'ptt_off_ack_timeout: attempts=$_releaseAttempts, retaining_asserted_state=true',
          );
          _scheduleWatchdog();
        }
      }),
    );
  }

  void _completeRelease() {
    if (_shutdown) return;
    _cancelReleaseTimer();
    _cancelWatchdog();
    _pendingCommand = null;
    _releaseRequiresReadback = false;
    _releaseAttempts = 0;
    _isPttAsserted = false;
    _transitionTo(IcomLanPttState.rxIdle);
  }

  void _sendPttCommand(bool pttOn) {
    actions.sendCivFrame(
      IcomLanCivCommands.buildPttFrame(
        pttOn: pttOn,
        radioAddress: radioAddress,
        controllerAddress: controllerAddress,
      ),
    );
  }

  void _scheduleWatchdog() {
    if (_shutdown) return;
    _cancelWatchdog();
    _watchdogTask = _scheduler.schedule(
      Duration(milliseconds: absoluteWatchdogMs),
      () => _lock(() {
        if (_shutdown) return;
        if (isTransmitting) {
          _log(
            'absolute_watchdog_fired: watchdog_ms=$absoluteWatchdogMs, state=$_state',
          );
          forceRelease(
            'PTT absolute watchdog timeout (${absoluteWatchdogMs}ms)',
          );
        }
      }),
    );
  }

  void _cancelWatchdog() {
    _watchdogTask?.cancel();
    _watchdogTask = null;
  }

  void _cancelReleaseTimer() {
    _releaseTask?.cancel();
    _releaseTask = null;
  }

  void _transitionTo(IcomLanPttState newState) {
    if (_state == newState) return;
    final oldState = _state;
    _state = newState;
    _log('state_transition: from=$oldState, to=$newState');
    _publishState();
    actions.onStateChanged(newState);
  }

  void _publishState() {
    _log(
      'publish_state: ptt_state=$_state, '
      'ptt_asserted_possible=${_isPttAsserted || _state != IcomLanPttState.rxIdle}, '
      'can_stream_audio=$canStreamAudio',
    );
  }
}
