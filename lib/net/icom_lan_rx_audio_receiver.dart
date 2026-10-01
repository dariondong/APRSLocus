/// 接收音频校验与落盘（对应 mod 的 `session/Ic705RxAudioReceiver.kt`）。
///
/// 它只做三件事：校验音频包（接收方 ID、发送方 ID、PCM 帧完整）、解码
/// PCM16LE、交给重排缓冲。不做控制、CI-V、PTT、发射。
library;

import 'dart:typed_data';

import 'icom_lan_audio_reorder_buffer.dart';
import 'icom_lan_pcm16.dart';
import 'icom_lan_protocol.dart';

/// PCM 格式（mod 侧是 `PcmFormat`；这里只保留本场景需要的三件事）。
class IcomLanPcmFormat {
  const IcomLanPcmFormat({required this.sampleRateHz, required this.channelCount});

  final int sampleRateHz;
  final int channelCount;

  int get bytesPerFrame => channelCount * 2;
}

/// 音频落点。
abstract class IcomLanPcmSink {
  IcomLanPcmFormat get format;

  void write(Int16List samples);
}

class IcomLanRxAudioReceiver {
  IcomLanRxAudioReceiver({
    required this.localId,
    this.radioId,
    required this.sink,
    this.onDiscontinuity,
  }) {
    if (sink.format.sampleRateHz != IcomLanAudioCodec.sampleRateHz) {
      throw ArgumentError('IC-705 receive audio requires '
          '${IcomLanAudioCodec.sampleRateHz} Hz PCM');
    }
    if (sink.format.channelCount != 1) {
      throw ArgumentError('IC-705 receive audio requires mono PCM');
    }
    // 编码只有 PCM16LE 一种（mod 侧还会校验 encoding 枚举）。
  }

  final int localId;
  final int? radioId;
  final IcomLanPcmSink sink;
  final void Function(IcomLanAudioDiscontinuity discontinuity)? onDiscontinuity;

  late final IcomLanAudioReorderBuffer _reorderBuffer =
      IcomLanAudioReorderBuffer(
    writeSamples: sink.write,
    onDiscontinuity: onDiscontinuity,
  );

  IcomLanAudioReceiveResult accept(Uint8List datagram) {
    final packet =
        IcomLanAudioCodec.decode(datagram, expectedReceiverId: localId);
    final expectedRadioId = radioId;
    if (expectedRadioId != null && packet.header.senderId != expectedRadioId) {
      throw IcomLanProtocolException(
          'Audio sender ID ${packet.header.senderId} does not match radio ID $expectedRadioId');
    }
    if (packet.pcmPayload.length % sink.format.bytesPerFrame != 0) {
      throw IcomLanProtocolException(
          'Audio payload has ${packet.pcmPayload.length} bytes, not complete PCM frames');
    }
    return _reorderBuffer.accept(
      packet.header.audioSequence,
      decodePcm16LittleEndian(packet.pcmPayload),
    );
  }

  void reset() => _reorderBuffer.reset();
}
