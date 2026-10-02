// SPDX-License-Identifier: GPL-2.0-or-later
// See LICENSING.md: this file is additionally available under GPL-2.0-or-later.

library;

import 'dart:typed_data';

import 'icom_lan_rx_session_engine.dart' show IcomLanSessionState;

/// Narrow lifecycle and transmission surface the APRS backend needs from an IC-705
/// radio session. The real implementation is [IcomLanRxSession]; backend tests substitute
/// a fake so they can drive phases and close timing without sockets or threads.
abstract class IcomLanRadioSession {
  IcomLanSessionState get state;
  bool get isTransmitting;

  void start();
  void stop();

  /// Transmits PCM audio samples via CI-V PTT ON, 12 kHz audio streaming, and CI-V PTT OFF.
  /// Returns true if the transmission was successfully initiated.
  bool transmitAudio(Uint8List pcm);

  /// Calls [onClosed] after sockets close and the audio worker has exited.
  void close([void Function()? onClosed]);
}
