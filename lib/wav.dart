/// ─── WAV（RIFF/PCM）读写 ───
///
/// 用途：
///   * 「音频」数据来源在桌面端（Windows/Linux/macOS）的**文件模式** ——
///     导入一段录音离线解码（现场录不上、事后分析），或把待发射报文
///     导出成 WAV，再由外部程序/对讲机声卡线播放；
///   * 单元测试用的参考音频（`test/afsk_test.dart`）。
///
/// 只支持未压缩 PCM（format 1，8/16 位）；APRS 声卡链路用的就是这种。
/// 解析时跳过未知块（LIST/fact/bext…），取 fmt 与 data —— 很多录音软件
/// 会写额外块，直接假设偏移 44 会解析错。
library;

import 'dart:typed_data';

/// 解出的 WAV 数据（多声道已混合为单声道）
class WavData {
  /// 16 位有符号单声道采样
  final Int16List samples;
  final int sampleRate;
  final int channels;
  final int bitsPerSample;

  const WavData({
    required this.samples,
    required this.sampleRate,
    this.channels = 1,
    this.bitsPerSample = 16,
  });

  double get seconds =>
      sampleRate == 0 ? 0 : samples.length / sampleRate;

  @override
  String toString() =>
      'WavData(${samples.length} 样本, ${sampleRate}Hz, ${channels}ch, ${bitsPerSample}bit)';
}

class Wav {
  Wav._();

  /// 编码为 16 位单声道 WAV（小端）
  static Uint8List encode(Int16List samples, {int sampleRate = 22050}) {
    final dataLen = samples.length * 2;
    final out = Uint8List(44 + dataLen);
    final bd = ByteData.sublistView(out);
    void ascii(int off, String s) {
      for (var i = 0; i < s.length; i++) {
        out[off + i] = s.codeUnitAt(i);
      }
    }

    ascii(0, 'RIFF');
    bd.setUint32(4, 36 + dataLen, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little); // fmt 块长度
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, 1, Endian.little); // 单声道
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * 2, Endian.little); // 字节率
    bd.setUint16(32, 2, Endian.little); // 块对齐
    bd.setUint16(34, 16, Endian.little); // 位深
    ascii(36, 'data');
    bd.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      bd.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return out;
  }

  /// 解析 WAV。格式不支持或数据损坏时返回 null（不抛异常 —— 调用方是 UI）。
  static WavData? decode(Uint8List bytes) {
    if (bytes.length < 44) return null;
    final bd = ByteData.sublistView(bytes);
    bool tag(int off, String s) {
      if (off + s.length > bytes.length) return false;
      for (var i = 0; i < s.length; i++) {
        if (bytes[off + i] != s.codeUnitAt(i)) return false;
      }
      return true;
    }

    if (!tag(0, 'RIFF') || !tag(8, 'WAVE')) return null;
    var off = 12;
    int sampleRate = 0, channels = 0, bits = 0, format = 0;
    Uint8List? data;
    while (off + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes, off, off + 4);
      final size = bd.getUint32(off + 4, Endian.little);
      final body = off + 8;
      if (id == 'fmt ') {
        if (body + 16 > bytes.length) return null;
        format = bd.getUint16(body, Endian.little);
        channels = bd.getUint16(body + 2, Endian.little);
        sampleRate = bd.getUint32(body + 4, Endian.little);
        bits = bd.getUint16(body + 14, Endian.little);
      } else if (id == 'data') {
        final end = (body + size) <= bytes.length ? body + size : bytes.length;
        data = Uint8List.sublistView(bytes, body, end);
      }
      // 块长度为奇数时补 1 字节对齐
      off = body + size + (size & 1);
    }
    if (data == null || sampleRate <= 0 || channels <= 0) return null;
    if (format != 1) return null; // 只支持未压缩 PCM
    if (bits != 16 && bits != 8) return null;

    final frames = bits == 16 ? data.length ~/ 2 : data.length;
    final out = Int16List(frames ~/ channels);
    // 16 位路径用 data 自己的 ByteData 视图，索引相对 data 起点（避免偏移算错）
    final d16 = bits == 16 ? ByteData.sublistView(data) : null;
    for (var f = 0; f < out.length; f++) {
      var acc = 0;
      for (var c = 0; c < channels; c++) {
        if (d16 != null) {
          acc += d16.getInt16((f * channels + c) * 2, Endian.little);
        } else {
          acc += ((data[f * channels + c] - 128) << 8);
        }
      }
      out[f] = (acc ~/ channels).clamp(-32768, 32767);
    }
    return WavData(
      samples: out,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bits,
    );
  }
}
