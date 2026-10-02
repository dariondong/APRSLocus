// SPDX-License-Identifier: GPL-2.0-or-later
// See LICENSING.md: this file is additionally available under GPL-2.0-or-later.

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_reconnect_scheduler.dart';

void main() {
  group('IcomLanReconnectBackoff', () {
    test('computes exact exponential backoff when jitter is zero', () {
      final backoff = IcomLanReconnectBackoff(
        initialMillis: 1000,
        maxMillis: 30000,
        jitterFraction: 0.0,
      );

      expect(backoff.delayMillis(0), equals(1000));
      expect(backoff.delayMillis(1), equals(2000));
      expect(backoff.delayMillis(2), equals(4000));
      expect(backoff.delayMillis(3), equals(8000));
      expect(backoff.delayMillis(4), equals(16000));
      expect(backoff.delayMillis(5), equals(30000)); // clamped to max
      expect(backoff.delayMillis(10), equals(30000));
    });

    test('applies symmetric jitter within bounds', () {
      // Test minimum unit (0.0) -> factor 0.8
      final minBackoff = IcomLanReconnectBackoff(
        initialMillis: 1000,
        maxMillis: 30000,
        jitterFraction: 0.20,
        randomUnit: () => 0.0,
      );
      expect(minBackoff.delayMillis(0), equals(800));

      // Test maximum unit (1.0) -> factor 1.2
      final maxBackoff = IcomLanReconnectBackoff(
        initialMillis: 1000,
        maxMillis: 30000,
        jitterFraction: 0.20,
        randomUnit: () => 1.0,
      );
      expect(maxBackoff.delayMillis(0), equals(1200));

      // Test midpoint (0.5) -> factor 1.0
      final midBackoff = IcomLanReconnectBackoff(
        initialMillis: 1000,
        maxMillis: 30000,
        jitterFraction: 0.20,
        randomUnit: () => 0.5,
      );
      expect(midBackoff.delayMillis(0), equals(1000));
    });
  });

  group('IcomLanDefaultReconnectScheduler', () {
    test('schedules and executes action', () async {
      final scheduler = IcomLanDefaultReconnectScheduler();
      final completer = Completer<void>();

      scheduler.schedule(10, () {
        completer.complete();
      });

      await completer.future.timeout(const Duration(seconds: 1));
      scheduler.close();
    });

    test('cancels scheduled action via handle', () async {
      final scheduler = IcomLanDefaultReconnectScheduler();
      var executed = false;

      final handle = scheduler.schedule(20, () {
        executed = true;
      });
      handle.cancel();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(executed, isFalse);
      scheduler.close();
    });

    test('close cancels all pending and throws on schedule', () {
      final scheduler = IcomLanDefaultReconnectScheduler();
      scheduler.close();

      expect(() => scheduler.schedule(10, () {}), throwsStateError);
    });
  });
}
