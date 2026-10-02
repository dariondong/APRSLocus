/// 发射音频分片（对应 mod 的 `session/Ic705TxAudioPacketizer.kt`）。
///
/// 把一段 12 kHz PCM 切成连续的音频包，并在**前面补 60 ms、后面补 60 ms**
/// 静音：前面那段填满电台 DSP 的抖动缓冲（防欠载），后面那段保证最后一个
/// 符号发得出去（防截尾）。尾部再补到整包边界。
library;

import 'dart:typed_data';

import 'icom_lan_pcm16.dart';
import 'icom_lan_protocol.dart';

class IcomLanTxAudioPacketizer {
  IcomLanTxAudioPacketizer({
    required this.senderId,
    required this.receiverId,
    int initialOuterSequence = 1,
    int initialAudioSequence = 1,
    this.samplesPerPacket = IcomLanAudioCodec.samplesPerPacket,
  })  : _currentOuterSequence = initialOuterSequence & 0xffff,
        _currentAudioSequence = initialAudioSequence & 0xffff {
    if (samplesPerPacket <= 0) {
      throw ArgumentError('samplesPerPacket must be positive');
    }
  }

  static const int defaultPrimeSilenceMs = 60;
  static const int defaultTrailingSilenceMs = 60;

  final int senderId;
  final int receiverId;
  final int samplesPerPacket;

  int _currentOuterSequence;
  int _currentAudioSequence;

  int get outerSequence => _currentOuterSequence;
  int get audioSequence => _currentAudioSequence;

  List<Uint8List> packetize(
    Int16List samples, {
    int primeSilenceMs = defaultPrimeSilenceMs,
    int trailingSilenceMs = defaultTrailingSilenceMs,
    int sampleRateHz = IcomLanAudioCodec.sampleRateHz,
  }) {
    final primeSamples = (primeSilenceMs * sampleRateHz) ~/ 1000;
    final trailingSamples = (trailingSilenceMs * sampleRateHz) ~/ 1000;
    final totalRawSamples = primeSamples + samples.length + trailingSamples;

    final remainder = totalRawSamples % samplesPerPacket;
    final paddingNeeded =
        remainder == 0 ? 0 : samplesPerPacket - remainder;
    final totalSamples = totalRawSamples + paddingNeeded;

    // 前导/尾部静音都是 0，Int16List 默认即 0。
    final combined = Int16List(totalSamples);
    combined.setRange(primeSamples, primeSamples + samples.length, samples);

    final datagrams = <Uint8List>[];
    final chunk = Int16List(samplesPerPacket);
    for (var offset = 0; offset < totalSamples; offset += samplesPerPacket) {
      chunk.setRange(0, samplesPerPacket, combined, offset);
      datagrams.add(IcomLanAudioCodec.encode(
        sequence: _currentOuterSequence,
        senderId: senderId,
        receiverId: receiverId,
        audioSequence: _currentAudioSequence,
        pcmPayload: encodePcm16LittleEndian(chunk),
      ));
      _currentOuterSequence = (_currentOuterSequence + 1) & 0xffff;
      _currentAudioSequence = (_currentAudioSequence + 1) & 0xffff;
    }
    return datagrams;
  }
}
