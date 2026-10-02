// SPDX-License-Identifier: GPL-2.0-or-later
// See LICENSING.md: this file is additionally available under GPL-2.0-or-later.

library;

import 'dart:async';
import 'dart:math';

/// Handle for a pending backend-level reconnect attempt.
abstract class IcomLanRetryHandle {
  void cancel();
}

class _TimerRetryHandle implements IcomLanRetryHandle {
  _TimerRetryHandle(this._timer);
  final Timer _timer;

  @override
  void cancel() {
    _timer.cancel();
  }
}

/// Scheduling boundary for backend-level reconnects.
abstract class IcomLanReconnectScheduler {
  IcomLanRetryHandle schedule(int delayMillis, void Function() action);
  void close();
}

/// Default timer-based reconnect scheduler.
class IcomLanDefaultReconnectScheduler implements IcomLanReconnectScheduler {
  bool _closed = false;
  final Set<Timer> _pendingTimers = {};

  @override
  IcomLanRetryHandle schedule(int delayMillis, void Function() action) {
    if (_closed) throw StateError('reconnect scheduler is closed');
    late final Timer timer;
    timer = Timer(Duration(milliseconds: max(0, delayMillis)), () {
      _pendingTimers.remove(timer);
      if (!_closed) action();
    });
    _pendingTimers.add(timer);
    return _TimerRetryHandle(timer);
  }

  @override
  void close() {
    _closed = true;
    for (final timer in _pendingTimers) {
      timer.cancel();
    }
    _pendingTimers.clear();
  }
}

/// Exponential reconnect delay with bounded symmetric jitter.
class IcomLanReconnectBackoff {
  IcomLanReconnectBackoff({
    this.initialMillis = 1000,
    this.maxMillis = 30000,
    this.jitterFraction = 0.20,
    double Function()? randomUnit,
  }) : _randomUnit = randomUnit ?? Random().nextDouble {
    if (initialMillis <= 0) {
      throw ArgumentError('initialMillis must be positive');
    }
    if (maxMillis < initialMillis) {
      throw ArgumentError('maxMillis must be >= initialMillis');
    }
    if (jitterFraction < 0.0 || jitterFraction > 1.0) {
      throw ArgumentError('jitterFraction must be between 0.0 and 1.0');
    }
  }

  final int initialMillis;
  final int maxMillis;
  final double jitterFraction;
  final double Function() _randomUnit;

  int delayMillis(int attempt) {
    final shift = attempt.clamp(0, 30);
    final exponential = initialMillis * (1 << shift);
    final base = min(maxMillis, exponential);
    if (jitterFraction == 0.0) return base;

    final unit = _randomUnit().clamp(0.0, 1.0);
    final factor = 1.0 + ((unit * 2.0) - 1.0) * jitterFraction;
    return (base * factor).round().clamp(0, maxMillis);
  }
}
