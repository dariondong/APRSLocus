/// 把一条 TNC2 报文用 **Dart 侧 AFSK 调制器**调制成 WAV，供交叉验证使用。
///
/// 为什么要它：AFSK 最容易「自己编自己解、同一个理解错误两头掩盖」。
/// `tool/afsk_reference.py` 是一份独立的 Python 参考实现，它用暴力时钟搜索
/// + FCS 裁决解调本工具生成的音频 —— 能解出且内容一致，才说明 Dart 调制器
/// 发出的波形是**真实可解**的。反向（Python 生成 → Dart 解调）由
/// test/afsk_test.dart 的「参考音频」用例覆盖。
///
/// 用法：
///   dart run tool/dump_afsk_wav.dart "BG7LZQ-9>APALOC:>hello" /tmp/tx.wav [采样率]
///   python3 tool/afsk_reference.py decode /tmp/tx.wav
library;

import 'dart:io';

import 'package:aprslocus/afsk.dart';
import 'package:aprslocus/kiss.dart';
import 'package:aprslocus/wav.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('用法: dump_afsk_wav.dart "TNC2 报文" 输出.wav [采样率=22050]');
    exit(2);
  }
  final tnc2 = args[0];
  final outPath = args[1];
  final sampleRate = args.length > 2 ? int.parse(args[2]) : 22050;

  final frame = Ax25.encodeTnc2(tnc2);
  if (frame == null) {
    stderr.writeln('TNC2 报文格式不合法（需要 SRC>DEST,PATH:info）: $tnc2');
    exit(1);
  }
  final audio = AfskModulator(AfskParams(sampleRate: sampleRate, txDelayMs: 120))
      .modulate(frame);
  File(outPath).writeAsBytesSync(Wav.encode(audio, sampleRate: sampleRate));
  stdout.writeln('$outPath: ${audio.length} 采样 @ ${sampleRate}Hz '
      '（${(audio.length / sampleRate).toStringAsFixed(2)}s）');
}
