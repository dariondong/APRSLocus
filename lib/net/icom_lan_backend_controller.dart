// SPDX-License-Identifier: GPL-2.0-or-later
// See LICENSING.md: this file is additionally available under GPL-2.0-or-later.

library;

import 'dart:typed_data';

import 'icom_lan_radio_session.dart';
import 'icom_lan_reconnect_scheduler.dart';
import 'icom_lan_rx_session.dart';
import 'icom_lan_rx_session_engine.dart';
import 'icom_lan_settings.dart';

/// Minimal service-facing surface the controller needs from the host application.
abstract class IcomLanBackendService {
  void postLinkOn();
  void postLinkOff();
  void postAbort(String message);
}

/// Factory for creating an [IcomLanRadioSession].
typedef IcomLanRadioSessionFactory = IcomLanRadioSession Function({
  required IcomLanConfig config,
  required IcomLanCallbacks callbacks,
});

/// Testable lifecycle logic for the IC-705 Wi-Fi backend (full-duplex RX + TX).
///
/// Generation-based session lifecycle management, recovery upon recoverable session
/// failures, exponential reconnect backoff, and link UP/DOWN state dispatch.
class IcomLanBackendController {
  IcomLanBackendController({
    required this.service,
    required this.config,
    IcomLanRadioSessionFactory? sessionFactory,
    IcomLanReconnectScheduler? reconnectScheduler,
    IcomLanReconnectBackoff? reconnectBackoff,
    this.fixedPortReuseCooldownMillis = 0,
    this.onLog,
  })  : _sessionFactory = sessionFactory ?? _defaultSessionFactory,
        _reconnectScheduler =
            reconnectScheduler ?? IcomLanDefaultReconnectScheduler(),
        _reconnectBackoff =
            reconnectBackoff ?? IcomLanReconnectBackoff();

  static IcomLanRadioSession _defaultSessionFactory({
    required IcomLanConfig config,
    required IcomLanCallbacks callbacks,
  }) =>
      IcomLanRxSession(config: config, callbacks: callbacks);

  final IcomLanBackendService service;
  final IcomLanConfig config;
  final IcomLanRadioSessionFactory _sessionFactory;
  final IcomLanReconnectScheduler _reconnectScheduler;
  final IcomLanReconnectBackoff _reconnectBackoff;
  final int fixedPortReuseCooldownMillis;
  final void Function(String message)? onLog;

  bool _stopped = false;
  bool _startRequested = false;
  int _activeGeneration = -1;
  int _nextGeneration = 0;
  IcomLanRadioSession? _session;
  bool _activeSawReconnectWait = false;
  bool _linkReportedUp = false;
  int _retryAttempt = 0;
  IcomLanRetryHandle? _pendingRetry;

  bool get isStopped => _stopped;
  bool get isLinkUp => _linkReportedUp;
  int get activeGeneration => _activeGeneration;
  IcomLanRadioSession? get currentSession => _session;

  void _log(String message) {
    onLog?.call('[IC705.Backend] $message');
  }

  /// Startup completes asynchronously when session enters RECEIVING.
  bool start() {
    if (_startRequested) return false;
    _startRequested = true;
    _log('Starting backend for ${config.host}:${config.controlPort}');

    final err = config.validate();
    if (err != null) {
      _fail('Invalid settings: $err');
      return false;
    }

    _connectNewGeneration(initialAttempt: true);
    return true;
  }

  void stop() {
    if (_stopped) return;
    _stopped = true;
    _log('Stopping backend');

    _pendingRetry?.cancel();
    _pendingRetry = null;
    final closingSession = _session;
    _session = null;
    _activeGeneration = -1;
    _linkReportedUp = false;

    _reconnectScheduler.close();
    closingSession?.close();
  }

  /// Transmits PCM audio through the currently active session.
  bool transmitAudio(Uint8List pcm) {
    if (_stopped) return false;
    final active = _session;
    if (active == null) return false;
    if (active.state.phase != IcomLanPhase.receiving) return false;
    if (active.isTransmitting) return false;
    return active.transmitAudio(pcm);
  }

  void _connectNewGeneration({required bool initialAttempt}) {
    if (_stopped) return;

    final generation = ++_nextGeneration;
    _log('Connecting generation $generation (initial=$initialAttempt)');

    try {
      final newSession = _sessionFactory(
        config: config,
        callbacks: IcomLanCallbacks(
          onStateChanged: (state) => _onSessionState(generation, state),
          onLog: _log,
        ),
      );

      if (_stopped) {
        newSession.close();
        return;
      }

      _activeGeneration = generation;
      _activeSawReconnectWait = false;
      _session = newSession;
      newSession.start();
    } catch (error) {
      _log('Failed to create generation $generation: $error');
      if (initialAttempt) {
        _fail('Initial connection failed: $error');
      } else {
        _scheduleReconnect();
      }
    }
  }

  void _onSessionState(int generation, IcomLanSessionState state) {
    if (_stopped || _activeGeneration != generation) return;

    _log('Generation $generation state: ${state.phase.name}');

    if (state.phase == IcomLanPhase.receiving) {
      if (!_linkReportedUp) {
        _linkReportedUp = true;
        _retryAttempt = 0;
        service.postLinkOn();
      }
    } else {
      if (_linkReportedUp) {
        _linkReportedUp = false;
        service.postLinkOff();
      }
    }

    switch (state.phase) {
      case IcomLanPhase.reconnectWait:
        _activeSawReconnectWait = true;
      case IcomLanPhase.failed:
        if (_activeSawReconnectWait) {
          _recoverGeneration(generation);
        } else {
          _failGeneration(generation);
        }
      default:
        break;
    }
  }

  void _recoverGeneration(int generation) {
    _log('Recovering generation $generation');
    if (_activeGeneration != generation || _stopped) return;

    final closing = _session;
    _session = null;
    _activeGeneration = -1;
    closing?.close(() {
      if (!_stopped) {
        _scheduleReconnect(minimumDelayMillis: fixedPortReuseCooldownMillis);
      }
    });
  }

  void _failGeneration(int generation) {
    _log('Generation $generation failed unrecoverably');
    if (_activeGeneration != generation || _stopped) return;

    final closing = _session;
    _session = null;
    _activeGeneration = -1;
    closing?.close(() {
      if (!_stopped) {
        service.postAbort('Session failed');
      }
    });
  }

  void _scheduleReconnect({int minimumDelayMillis = 0}) {
    if (_stopped || _pendingRetry != null) return;

    final attempt = _retryAttempt++;
    final backoffDelay = _reconnectBackoff.delayMillis(attempt);
    final delay =
        minimumDelayMillis > backoffDelay ? minimumDelayMillis : backoffDelay;

    _log('Reconnect scheduled in ${delay}ms (attempt $attempt)');
    _pendingRetry = _reconnectScheduler.schedule(delay, () {
      _pendingRetry = null;
      if (!_stopped) {
        _connectNewGeneration(initialAttempt: false);
      }
    });
  }

  void _fail(String message) {
    _log('Backend failed: $message');
    service.postAbort(message);
  }
}
