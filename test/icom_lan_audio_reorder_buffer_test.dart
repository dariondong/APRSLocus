// 音频重排缓冲回归（对应 mod 的 Ic705AudioReorderBufferTest）
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_audio_reorder_buffer.dart';

Int16List samples(List<int> values) => Int16List.fromList(values);

void main() {
  test('短前向缺口先缓冲、按序补出', () {
    final writes = <int>[];
    final buffer = IcomLanAudioReorderBuffer(
      writeSamples: (data) => writes.add(data.single),
    );

    expect(buffer.accept(7, samples([7])), IcomLanAudioReceiveResult.accepted);
    expect(buffer.accept(9, samples([9])), IcomLanAudioReceiveResult.buffered);
    expect(buffer.accept(8, samples([8])), IcomLanAudioReceiveResult.accepted);
    expect(writes, [7, 8, 9]);
  });

  test('reset 会清掉重复判定与序号状态', () {
    final writes = <int>[];
    final buffer = IcomLanAudioReorderBuffer(
      writeSamples: (data) => writes.add(data.single),
    );

    expect(buffer.accept(0xffff, samples([1])), IcomLanAudioReceiveResult.accepted);
    expect(buffer.accept(0xffff, samples([2])),
        IcomLanAudioReceiveResult.duplicateDropped);

    buffer.reset();

    expect(buffer.accept(0xffff, samples([3])), IcomLanAudioReceiveResult.accepted);
    expect(writes, [1, 3]);
  });

  test('大缺口只报断点、不补静音', () {
    final discontinuities = <IcomLanAudioDiscontinuity>[];
    final writes = <int>[];
    final buffer = IcomLanAudioReorderBuffer(
      writeSamples: (data) => writes.add(data.last),
      onDiscontinuity: discontinuities.add,
    );

    buffer.accept(7, samples([7]));
    expect(buffer.accept(20, samples([20])), IcomLanAudioReceiveResult.accepted);

    expect(discontinuities.length, 1);
    expect(discontinuities.single.kind, IcomLanAudioDiscontinuityKind.gap);
    expect(discontinuities.single.expectedSequence, 8);
    expect(discontinuities.single.actualSequence, 20);
    expect(discontinuities.single.missingPacketCount, 12);
    expect(writes, [7, 20]);
  });

  test('补齐用**观测到的**真实包大小', () {
    final writes = <Int16List>[];
    final buffer = IcomLanAudioReorderBuffer(
      writeSamples: (data) => writes.add(Int16List.fromList(data)),
    );

    // 先教会缓冲：偶包 3 个样本、奇包 2 个样本。
    buffer.accept(0, samples([10, 10, 10]));
    buffer.accept(1, samples([11, 11]));

    // 缺 2；当挂起包攒到 4 个时，最靠前的 3 会被放出，前面补一个偶包静音。
    buffer.accept(3, samples([13, 13]));
    buffer.accept(4, samples([14, 14, 14]));
    buffer.accept(5, samples([15, 15]));
    buffer.accept(6, samples([16, 16, 16]));

    final concealed = writes[2];
    expect(concealed.length, 5);
    expect(concealed[0], 0);
    expect(concealed[1], 0);
    expect(concealed[2], 0);
    expect(concealed[3], 13);
    expect(concealed[4], 13);
  });

  test('超大包不会污染学习到的大小', () {
    final writes = <Int16List>[];
    final buffer = IcomLanAudioReorderBuffer(
      writeSamples: (data) => writes.add(Int16List.fromList(data)),
    );

    buffer.accept(0, Int16List(1000)..fillRange(0, 1000, 1));
    buffer.accept(1, samples([11, 11]));

    buffer.accept(3, samples([13, 13]));
    buffer.accept(4, samples([14, 14, 14]));
    buffer.accept(5, samples([15, 15]));
    buffer.accept(6, samples([16, 16, 16]));

    // 序号 2 是偶包：序号 0 的 1000 样本越界没被学习 → 回退到 171。
    expect(writes[2].length, 171 + 2);
  });
}
