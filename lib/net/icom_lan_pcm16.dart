/// PCM16LE（小端 16 位）字节 ↔ 样本互转。
///
/// mod 侧用的是 `Pcm16LittleEndian`，Locus 侧音频管线对外只认
/// `Uint8List`（PCM16LE），所以这里保留同一套语义、只是换成 Dart 的
/// `Int16List`。
library;

import 'dart:typed_data';

/// 解码 PCM16LE 字节为样本（奇数长度时按 mod 的行为在调用方先校验）。
Int16List decodePcm16LittleEndian(Uint8List bytes) {
  final count = bytes.length ~/ 2;
  final out = Int16List(count);
  for (var i = 0; i < count; i++) {
    final low = bytes[i * 2];
    final high = bytes[i * 2 + 1];
    final value = (high << 8) | low;
    out[i] = value >= 0x8000 ? value - 0x10000 : value;
  }
  return out;
}

/// 编码样本为 PCM16LE 字节。
Uint8List encodePcm16LittleEndian(Int16List samples) {
  final out = Uint8List(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    final value = samples[i] & 0xffff;
    out[i * 2] = value & 0xff;
    out[i * 2 + 1] = (value >> 8) & 0xff;
  }
  return out;
}
