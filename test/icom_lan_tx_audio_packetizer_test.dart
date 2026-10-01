// 发射音频分片回归（mod 无独立测试，此处按实现语义补测）
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_pcm16.dart';
import 'package:aprslocus/net/icom_lan_protocol.dart';
import 'package:aprslocus/net/icom_lan_tx_audio_packetizer.dart';

void main() {
  test('前导与尾部各补 60 ms 静音，并补到整包边界', () {
    final packetizer = IcomLanTxAudioPacketizer(senderId: 1, receiverId: 2);
    // 240 样本（20 ms）音频 + 60 ms 前导 + 60 ms 尾部 = 240+720+720 = 1680
    // 1680 / 240 = 7 个整包。
    final datagrams = packetizer.packetize(Int16List(240)..fillRange(0, 240, 1000));

    expect(datagrams.length, 7);
    // 前 3 个包是纯静音（60 ms = 720 样本 = 3 包）。
    for (var i = 0; i < 3; i++) {
      final packet = IcomLanAudioCodec.decode(datagrams[i]);
      expect(packet.pcmPayload.every((byte) => byte == 0), isTrue);
    }
    // 第 4 个包开始是音频（1000）。
    final fourth = IcomLanAudioCodec.decode(datagrams[3]);
    expect(decodePcm16LittleEndian(fourth.pcmPayload).first, 1000);
    // 尾部两包静音。
    final last = IcomLanAudioCodec.decode(datagrams.last);
    expect(last.pcmPayload.every((byte) => byte == 0), isTrue);
  });

  test('外层序号与音频序号各自递增且可回绕', () {
    final packetizer = IcomLanTxAudioPacketizer(
      senderId: 1,
      receiverId: 2,
      initialOuterSequence: 0xfffe,
      initialAudioSequence: 10,
    );
    final datagrams = packetizer.packetize(Int16List(240));
    final headers = datagrams
        .map((d) => IcomLanAudioCodec.decode(d))
        .toList();

    expect(headers.map((h) => h.header.sequence).take(3).toList(),
        [0xfffe, 0xffff, 0]);
    expect(headers.map((h) => h.header.audioSequence).take(3).toList(),
        [10, 11, 12]);
    expect(packetizer.outerSequence, (0xfffe + datagrams.length) & 0xffff);
  });

  test('每个包的 PCM 都是整帧 16 位', () {
    final packetizer = IcomLanTxAudioPacketizer(senderId: 1, receiverId: 2);
    final datagrams = packetizer.packetize(Int16List(100)..fillRange(0, 100, 7));
    for (final datagram in datagrams) {
      final packet = IcomLanAudioCodec.decode(datagram);
      expect(packet.pcmPayload.length % 2, 0);
      expect(packet.header.payloadLength, packet.pcmPayload.length);
    }
  });
}
