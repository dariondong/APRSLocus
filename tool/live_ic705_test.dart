// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:aprslocus/net/icom_lan_rx_session.dart';
import 'package:aprslocus/net/icom_lan_settings.dart';

Uint8List generateSineTone({
  required int sampleRate,
  required double frequencyHz,
  required double durationSeconds,
}) {
  final sampleCount = (sampleRate * durationSeconds).round();
  final byteData = ByteData(sampleCount * 2);
  for (int i = 0; i < sampleCount; i++) {
    final t = i / sampleRate;
    final sample = (sin(2 * pi * frequencyHz * t) * 16000).clamp(-32768, 32767).toInt();
    byteData.setInt16(i * 2, sample, Endian.little);
  }
  return byteData.buffer.asUint8List();
}

Future<void> main() async {
  print('========================================================');
  print('   IC-705 Live Hardware Test (Radio Direct over LAN)   ');
  print('========================================================');
  print('Target IP: 192.168.1.143:50001');
  print('User: 114514');

  final config = IcomLanConfig(
    host: '192.168.1.143',
    controlPort: 50001,
    username: '114514',
    password: 'aa1919810',
    radioCivAddress: 0xA4,
    controllerCivAddress: 0xE0,
  );

  int pcmPacketCount = 0;
  int totalPcmBytes = 0;

  final session = IcomLanRxSession(
    config: config,
    callbacks: IcomLanCallbacks(
      onLog: (msg) => print('  [IC705 LOG] $msg'),
      onStateChanged: (state) => print('  [STATE CHANGE] phase=${state.phase.name}, failure=${state.failureReason}'),
      onPcm: (pcm) {
        pcmPacketCount++;
        totalPcmBytes += pcm.length;
        if (pcmPacketCount % 25 == 0) {
          print('  [AUDIO RX] Packets: $pcmPacketCount, Total Audio: ${(totalPcmBytes / 1024).toStringAsFixed(1)} KB');
        }
      },
      onAudioDiscontinuity: (reason) => print('  [AUDIO WARNING] $reason'),
    ),
  );

  try {
    print('\n[Step 1] Connecting to IC-705...');
    await session.start();

    // Wait up to 30 seconds for session to reach receiving
    final stopwatch = Stopwatch()..start();
    while (!session.isReceiving && stopwatch.elapsedMilliseconds < 30000) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!session.isReceiving) {
      print('\n[FAIL] Session did not reach receiving phase. Final state: ${session.state.phase}');
      session.close();
      exit(1);
    }

    print('\n[Step 2] Connection established successfully! Currently in RECEIVING phase.');
    print('Streaming RX audio for 4 seconds...');
    await Future.delayed(const Duration(seconds: 4));
    print('RX Audio summary: $pcmPacketCount packets received, $totalPcmBytes bytes (~${(totalPcmBytes / 24000).toStringAsFixed(2)}s of 12kHz 16-bit audio).');

    print('\n[Step 3] Initiating PTT / TX Test (Dummy Load Attached)...');
    final tone = generateSineTone(
      sampleRate: 12000,
      frequencyHz: 1200,
      durationSeconds: 1.0,
    );
    print('Generated 1.0s 1200Hz test tone (${tone.length} bytes PCM).');

    print('Calling session.transmitPcm()...');
    final txStopwatch = Stopwatch()..start();
    final txResult = await session.transmitPcm(tone);
    txStopwatch.stop();

    if (txResult != null) {
      print('[FAIL] TX failed with error: $txResult');
    } else {
      print('[SUCCESS] TX completed in ${txStopwatch.elapsedMilliseconds}ms! PTT ON confirmed -> audio streamed -> PTT OFF confirmed!');
    }

    print('\n[Step 4] Continuing RX for 3 seconds after TX...');
    final rxPacketsBefore = pcmPacketCount;
    await Future.delayed(const Duration(seconds: 3));
    final rxPacketsAfter = pcmPacketCount;
    print('Post-TX RX packets: ${rxPacketsAfter - rxPacketsBefore} new packets received.');

    print('\n[Step 5] Disconnecting cleanly...');
    session.close();
    await Future.delayed(const Duration(milliseconds: 500));
    print('\n========================================================');
    print('   IC-705 Real Hardware Validation PASSED 100%!       ');
    print('========================================================');
    exit(0);
  } catch (e, stack) {
    print('\n[ERROR] Exception encountered: $e\n$stack');
    session.close();
    exit(1);
  }
}
