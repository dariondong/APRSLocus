// 接收音频校验回归（对应 mod 的 Ic705RxAudioReceiverTest）
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_audio_reorder_buffer.dart';
import 'package:aprslocus/net/icom_lan_protocol.dart';
import 'package:aprslocus/net/icom_lan_rx_audio_receiver.dart';

const int localId = 0x11223344;
const int radioId = 0x55667788;

Uint8List audioDatagram({
  required int sequence,
  int senderId = radioId,
  Uint8List? pcm,
}) =>
    IcomLanAudioCodec.encode(
      sequence: sequence,
      senderId: senderId,
      receiverId: localId,
      audioSequence: sequence,
      pcmPayload: pcm ?? Uint8List.fromList([0x01, 0x00]),
    );

/// 记录落盘样本的假 sink（格式固定 12 kHz 单声道）。
class RecordingSink implements IcomLanPcmSink {
  final List<int> samples = [];

  @override
  IcomLanPcmFormat get format =>
      const IcomLanPcmFormat(sampleRateHz: IcomLanAudioCodec.sampleRateHz, channelCount: 1);

  @override
  void write(Int16List data) => samples.addAll(data);
}

void main() {
  test('把 PCM16LE 解成样本写进 sink', () {
    final sink = RecordingSink();
    final receiver = IcomLanRxAudioReceiver(
        localId: localId, radioId: radioId, sink: sink);

    final result = receiver.accept(audioDatagram(
      sequence: 7,
      pcm: Uint8List.fromList([0x34, 0x12, 0x00, 0x80]),
    ));

    expect(result, IcomLanAudioReceiveResult.accepted);
    expect(sink.samples, [0x1234, -32768]);
  });

  test('完全重复的包不会写两次', () {
    final sink = RecordingSink();
    final receiver = IcomLanRxAudioReceiver(
        localId: localId, radioId: radioId, sink: sink);
    final datagram = audioDatagram(sequence: 7);

    expect(receiver.accept(datagram), IcomLanAudioReceiveResult.accepted);
    expect(receiver.accept(datagram),
        IcomLanAudioReceiveResult.duplicateDropped);
    expect(sink.samples.length, 1);
  });

  test('短前向缺口按序补出，且不触发断点', () {
    final sink = RecordingSink();
    final discontinuities = <IcomLanAudioDiscontinuity>[];
    final receiver = IcomLanRxAudioReceiver(
      localId: localId,
      radioId: radioId,
      sink: sink,
      onDiscontinuity: discontinuities.add,
    );

    expect(receiver.accept(audioDatagram(sequence: 7)),
        IcomLanAudioReceiveResult.accepted);
    expect(receiver.accept(audioDatagram(sequence: 9)),
        IcomLanAudioReceiveResult.buffered);
    expect(receiver.accept(audioDatagram(sequence: 8)),
        IcomLanAudioReceiveResult.accepted);

    expect(sink.samples.length, 3);
    expect(discontinuities, isEmpty);
  });

  test('孤立丢包用静音补齐，迟到的包被丢弃且不复位解调器', () {
    final sink = RecordingSink();
    final discontinuities = <IcomLanAudioDiscontinuity>[];
    final receiver = IcomLanRxAudioReceiver(
      localId: localId,
      radioId: radioId,
      sink: sink,
      onDiscontinuity: discontinuities.add,
    );

    expect(receiver.accept(audioDatagram(sequence: 7)),
        IcomLanAudioReceiveResult.accepted);
    expect(receiver.accept(audioDatagram(sequence: 9)),
        IcomLanAudioReceiveResult.buffered);
    expect(receiver.accept(audioDatagram(sequence: 10)),
        IcomLanAudioReceiveResult.buffered);
    expect(receiver.accept(audioDatagram(sequence: 11)),
        IcomLanAudioReceiveResult.buffered);
    expect(receiver.accept(audioDatagram(sequence: 12)),
        IcomLanAudioReceiveResult.accepted);
    expect(discontinuities, isEmpty);

    expect(
      receiver.accept(audioDatagram(
          sequence: 8, pcm: Uint8List.fromList([0x02, 0x00]))),
      IcomLanAudioReceiveResult.outOfOrderDropped,
    );
    // 序号 8 是 12 kHz 交替包里的"大"半边；还没有观测到偶包，
    // 所以补齐用 171 样本的兜底值。
    expect(sink.samples.length, 1 + 171 + 4);
    expect(discontinuities, isEmpty);
  });

  test('大缺口报断点而不是补静音', () {
    final sink = RecordingSink();
    final discontinuities = <IcomLanAudioDiscontinuity>[];
    final receiver = IcomLanRxAudioReceiver(
      localId: localId,
      radioId: radioId,
      sink: sink,
      onDiscontinuity: discontinuities.add,
    );

    receiver.accept(audioDatagram(sequence: 7));
    expect(receiver.accept(audioDatagram(sequence: 20)),
        IcomLanAudioReceiveResult.accepted);

    expect(discontinuities.length, 1);
    expect(discontinuities.single.kind, IcomLanAudioDiscontinuityKind.gap);
    expect(discontinuities.single.expectedSequence, 8);
    expect(discontinuities.single.actualSequence, 20);
    expect(discontinuities.single.missingPacketCount, 12);
    expect(sink.samples.length, 2);
  });

  test('序号回绕不会被误判成缺口', () {
    final sink = RecordingSink();
    final discontinuities = <IcomLanAudioDiscontinuity>[];
    final receiver = IcomLanRxAudioReceiver(
      localId: localId,
      radioId: radioId,
      sink: sink,
      onDiscontinuity: discontinuities.add,
    );

    receiver.accept(audioDatagram(sequence: 0xffff));
    receiver.accept(audioDatagram(sequence: 0));

    expect(sink.samples.length, 2);
    expect(discontinuities, isEmpty);
  });

  test('拒收来自别的电台会话的音频', () {
    final receiver = IcomLanRxAudioReceiver(
        localId: localId, radioId: radioId, sink: RecordingSink());
    expect(
      () => receiver.accept(audioDatagram(sequence: 1, senderId: 0x01020304)),
      throwsA(isA<IcomLanProtocolException>()),
    );
  });

  test('拒收不完整的 PCM 帧', () {
    final receiver = IcomLanRxAudioReceiver(
        localId: localId, radioId: radioId, sink: RecordingSink());
    expect(
      () => receiver.accept(audioDatagram(
          sequence: 1, pcm: Uint8List.fromList([0x01]))),
      throwsA(isA<IcomLanProtocolException>()),
    );
  });

  test('sink 采样率不是 12 kHz 时拒绝构造', () {
    expect(
      () => IcomLanRxAudioReceiver(
        localId: localId,
        radioId: radioId,
        sink: _WrongRateSink(),
      ),
      throwsArgumentError,
    );
  });
}

class _WrongRateSink implements IcomLanPcmSink {
  @override
  IcomLanPcmFormat get format =>
      const IcomLanPcmFormat(sampleRateHz: 48000, channelCount: 1);

  @override
  void write(Int16List data) {}
}
