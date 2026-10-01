// 音频序号策略回归（对应 mod 的 Ic705AudioSequencePolicyTest）
import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_audio_sequence_policy.dart';

void main() {
  test('序号运算在 16 位处回绕', () {
    expect(incrementIcomLanAudioSequence(0xffff), 0);
    expect(icomLanAudioSequenceDistance(0xffff, 0), 1);
    expect(icomLanAudioSequenceDistance(0, 0xffff), 0xffff);
  });

  test('收包大小兜底值与协商到的 12 kHz 一致', () {
    expect(icomLanSamplesPerReceivePacket(0), 171);
    expect(icomLanSamplesPerReceivePacket(1), 69);
    expect(icomLanSamplesPerReceivePacket(2), 171);
    expect(icomLanSamplesPerReceivePacket(3), 69);
    expect(icomLanSamplesPerReceivePacket(0) + icomLanSamplesPerReceivePacket(1), 240);
  });
}
