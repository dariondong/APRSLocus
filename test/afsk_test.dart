import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'dart:io';

import 'package:aprslocus/afsk.dart';
import 'package:aprslocus/audio.dart';
import 'package:aprslocus/kiss.dart';
import 'package:aprslocus/wav.dart';
import 'package:flutter_test/flutter_test.dart';

/// AFSK 1200（Bell 202）+ HDLC 回归测试
///
/// 这一层出错的代价和 KISS 一样高，而且更隐蔽：波形错了不会有异常，
/// 只是「对方收不到」——所以用固定期望值锁住行为：
///   * CRC 用公开校验值（"123456789" → 0x906E）；
///   * HDLC 用「编码后解回同一帧」+ 位填充边界（0x7E/0xFF）；
///   * 调制解调做往返（含分块喂入、噪声、直流、频偏）；
///   * 参考音频由**独立的 Python 实现**生成（tool/afsk_reference.py），
///     避免「自己编自己解」把同一个理解错误两头都掩盖掉。
void main() {
  // 覆盖位置报文/状态报文/中文消息三类真实报文
  const tnc2Position = 'BG7LZQ-9>APALOC,WIDE1-1,WIDE2-1:!2230.00N/11400.00E>测试';
  const tnc2Status = 'BG7LZQ>APALOC:>APRSlocus CONNECT v1.6.104';
  const tnc2Message = 'BG7LZQ-9>APALOC::BA7KSM   :你好，这里是中文消息';

  group('CRC-16/X.25（FCS）', () {
    test('公开校验值：字符串 123456789 → 0x6F91（取反后即公开的 0x906E）', () {
      // 注意：CRC-16/X.25 的公开 check value 0x906E 含最后一步取反（xorout），
      // 而 crc16X25 只做原始计算 —— 取反由 appendFcs 负责：
      //   0x6F91 ^ 0xFFFF == 0x906E
      expect(Hdlc.crc16X25('123456789'.codeUnits), 0x6F91);
      expect(Hdlc.crc16X25('123456789'.codeUnits) ^ 0xFFFF, 0x906E);
    });

    test('追加 FCS 后整帧残差恒为 0xF0B8，改动一字节即失败', () {
      final payload = Ax25.encodeTnc2(tnc2Position)!;
      final withFcs = Hdlc.appendFcs(payload);
      expect(withFcs.length, payload.length + 2);
      expect(Hdlc.checkFcs(withFcs), isTrue);
      // 防止「校验函数恒真」：改一位必须拒收
      final bad = List<int>.from(withFcs)..[5] ^= 0x01;
      expect(Hdlc.checkFcs(bad), isFalse);
    });

    test('FCS 取反后低字节在前（AX.25 规定）', () {
      final payload = [0x01, 0x02, 0x03, 0x04];
      final crc = Hdlc.crc16X25(payload) ^ 0xFFFF;
      expect(Hdlc.appendFcs(payload).sublist(4), [crc & 0xFF, (crc >> 8) & 0xFF]);
    });
  });

  group('HDLC 帧定界与位填充', () {
    test('比特流往返（编码的比特直接喂解码器）', () {
      final payload = Ax25.encodeTnc2(tnc2Status)!;
      final got = <Uint8List>[];
      final dec = HdlcDecoder()..onFrame = got.add;
      dec.feedBits(Hdlc.frameBits(payload, preambleFlags: 4, tailFlags: 2));
      expect(got.length, 1);
      expect(got.first, payload);
    });

    test('数据里的 0x7E / 0xFF 靠位填充往返（不会被误判为 flag/abort）', () {
      // 0xFF = 8 个连续 1，必须被填充打断；0x7E 是 flag 字面量，必须转义
      final payload =
          Uint8List.fromList(List.generate(16, (i) => const [0x7E, 0xFF, 0x00, 0xAA][i % 4]));
      final got = <Uint8List>[];
      final dec = HdlcDecoder()..onFrame = got.add;
      dec.feedBits(Hdlc.frameBits(payload, preambleFlags: 2, tailFlags: 1));
      expect(got.length, 1);
      expect(got.first, payload);
    });

    test('连续 7 个 1 触发中止；随后的 flag 重新开始接收', () {
      final got = <Uint8List>[];
      final dec = HdlcDecoder()..onFrame = got.add;
      dec.feedBits(Hdlc.bits(const [Hdlc.flag]));
      expect(dec.inFrame, isTrue);
      dec.feedBits(List<int>.filled(7, 1)); // 非法：既非 flag 也无填充
      expect(dec.inFrame, isFalse);
      dec.feedBits(Hdlc.bits(const [Hdlc.flag]));
      expect(dec.inFrame, isTrue);
      expect(got, isEmpty);
    });

    test('FCS 不符的帧被丢弃', () {
      final payload = Ax25.encodeTnc2(tnc2Status)!;
      final bits = Hdlc.frameBits(payload, preambleFlags: 2, tailFlags: 2);
      bits[bits.length - 20] ^= 1; // 破坏数据区一位
      final got = <Uint8List>[];
      final dec = HdlcDecoder()..onFrame = got.add;
      dec.feedBits(bits);
      expect(got, isEmpty);
    });

    test('一次喂入多帧全部解出（帧间共享 flag）', () {
      final a = Ax25.encodeTnc2(tnc2Status)!;
      final b = Ax25.encodeTnc2(tnc2Message)!;
      final stream = <int>[
        ...Hdlc.frameBits(a, preambleFlags: 2, tailFlags: 1),
        ...Hdlc.frameBits(b, preambleFlags: 2, tailFlags: 1),
      ];
      final got = <Uint8List>[];
      final dec = HdlcDecoder()..onFrame = got.add;
      dec.feedBits(stream);
      expect(got, [a, b]);
    });
  });

  group('AFSK 调制解调往返', () {
    for (final sr in [22050, 44100, 48000]) {
      test('${sr}Hz：位置/状态/中文消息三类报文往返', () {
        final p = AfskParams(sampleRate: sr, txDelayMs: 100);
        for (final text in [tnc2Position, tnc2Status, tnc2Message]) {
          final frame = Ax25.encodeTnc2(text)!;
          final audio = AfskModulator(p).modulate(frame);
          final frames = AfskDemodulator(p).feed(audio);
          expect(frames.length, 1, reason: '$sr Hz / $text');
          expect(frames.first, frame, reason: '$sr Hz / $text');
          expect(Ax25.decodeToTnc2(frames.first), startsWith('BG7LZQ'));
        }
      });
    }

    test('分块喂入（模拟音频回调 512 样本/块）', () {
      const p = AfskParams(sampleRate: 22050, txDelayMs: 100);
      final frame = Ax25.encodeTnc2(tnc2Message)!;
      final audio = AfskModulator(p).modulate(frame);
      final dem = AfskDemodulator(p);
      final got = <Uint8List>[];
      for (var i = 0; i < audio.length; i += 512) {
        final end = (i + 512) > audio.length ? audio.length : i + 512;
        got.addAll(dem.feed(Int16List.sublistView(audio, i, end)));
      }
      expect(got, [frame]);
    });

    test('多帧连续发射（DPLL 保持锁定，第二帧更快解出）', () {
      const p = AfskParams(sampleRate: 22050, txDelayMs: 60);
      final a = Ax25.encodeTnc2(tnc2Status)!;
      final b = Ax25.encodeTnc2(tnc2Position)!;
      final mod = AfskModulator(p);
      final dem = AfskDemodulator(p);
      final got = <Uint8List>[];
      // 两帧之间插 300ms 静音（真实信道上的间隔）
      final gap = Int16List(22050 * 3 ~/ 10);
      got.addAll(dem.feed(mod.modulate(a)));
      got.addAll(dem.feed(gap));
      got.addAll(dem.feed(mod.modulate(b)));
      expect(got, [a, b]);
    });

    test('叠加噪声（约 12dB SNR）仍可解', () {
      const p = AfskParams(sampleRate: 22050, txDelayMs: 100);
      final frame = Ax25.encodeTnc2(tnc2Position)!;
      final audio = AfskModulator(p).modulate(frame);
      final rnd = Random(7);
      final noisy = Int16List(audio.length);
      for (var i = 0; i < audio.length; i++) {
        final n = (rnd.nextDouble() * 2 - 1) * 0.1 * 32767;
        noisy[i] = (audio[i] + n).round().clamp(-32768, 32767);
      }
      expect(AfskDemodulator(p).feed(noisy), [frame]);
    });

    test('直流偏置 + 幅度减半仍可解（验证去直流）', () {
      const p = AfskParams(sampleRate: 22050, txDelayMs: 100);
      final frame = Ax25.encodeTnc2(tnc2Status)!;
      final audio = AfskModulator(p).modulate(frame);
      final dirty = Int16List(audio.length);
      for (var i = 0; i < audio.length; i++) {
        dirty[i] = (audio[i] * 0.5 + 0.2 * 32767).round().clamp(-32768, 32767);
      }
      expect(AfskDemodulator(p).feed(dirty), [frame]);
    });

    test('发射/接收有 ±25Hz 频偏仍可解（电台偏频容限）', () {
      const rx = AfskParams(sampleRate: 22050, txDelayMs: 100);
      const tx = AfskParams(
          sampleRate: 22050, markHz: 1225, spaceHz: 2225, txDelayMs: 100);
      final frame = Ax25.encodeTnc2(tnc2Position)!;
      final audio = AfskModulator(tx).modulate(frame);
      expect(AfskDemodulator(rx).feed(audio), [frame]);
    });

    test('纯噪声不产生伪帧（RNG 固定，结果可复现）', () {
      final rnd = Random(42);
      final noise = Int16List.fromList(
          List.generate(22050 * 2, (_) => ((rnd.nextDouble() * 2 - 1) * 20000).round()));
      final dem = AfskDemodulator(const AfskParams());
      expect(dem.feed(noise), isEmpty);
      expect(dem.frameCount, 0);
    });
  });

  group('WAV 读写', () {
    test('16 位单声道编码-解码往返', () {
      const p = AfskParams(sampleRate: 22050, txDelayMs: 60);
      final audio = AfskModulator(p).modulate(Ax25.encodeTnc2(tnc2Status)!);
      final wav = Wav.encode(audio, sampleRate: p.sampleRate);
      final back = Wav.decode(wav)!;
      expect(back.sampleRate, 22050);
      expect(back.channels, 1);
      expect(back.bitsPerSample, 16);
      expect(back.samples, audio);
    });

    test('未知块（LIST）被跳过后仍能取到 data', () {
      const p = AfskParams(txDelayMs: 60);
      final audio = AfskModulator(p).modulate(Ax25.encodeTnc2(tnc2Status)!);
      final wav = Wav.encode(audio, sampleRate: p.sampleRate);
      // 在 fmt 与 data 之间插入一个 LIST 块
      final extra = Uint8List.fromList('LIST'.codeUnits + [4, 0, 0, 0, 1, 2, 3, 4]);
      final spliced = Uint8List.fromList(
          [...wav.sublist(0, 36), ...extra, ...wav.sublist(36)]);
      final back = Wav.decode(spliced)!;
      expect(back.samples.length, audio.length);
      expect(AfskDemodulator(p).feed(back.samples), [Ax25.encodeTnc2(tnc2Status)!]);
    });

    test('非 WAV / 非 PCM 数据返回 null 而不抛异常', () {
      expect(Wav.decode(Uint8List(10)), isNull);
      expect(Wav.decode(Uint8List.fromList(List.filled(64, 0x41))), isNull);
    });
  });

  group('参考音频（独立 Python 实现生成）', () {
    final f = File('test/reference/afsk1200_reference.wav');
    test('解码真实风格录音（含噪声/直流/频偏/静音）', () {
      if (!f.existsSync()) {
        markTestSkipped('缺少 test/reference/afsk1200_reference.wav'
            '（用 python3 tool/afsk_reference.py gen 生成）');
        return;
      }
      final wav = Wav.decode(f.readAsBytesSync());
      expect(wav, isNotNull);
      final dem = AfskDemodulator(AfskParams(sampleRate: wav!.sampleRate));
      final lines = dem
          .feed(wav.samples)
          .map((b) => Ax25.decodeToTnc2(b))
          .whereType<String>()
          .toList();
      // 参考音频里第二帧故意带噪声+偏频，两帧都应解出
      expect(lines.length, 2, reason: '解出 $lines');
      expect(lines[0], startsWith('BG7LZQ-9>APALOC:'));
      expect(lines[1], startsWith('BG7LZQ>APALOC:'));
      expect(lines.join(), contains('独立实现'));
    });
  });

  group('音频链路·文件模式（离线收发）', () {
    // 这一组覆盖 AudioLink 对外提供的那两条路径：导出 WAV / 解码 WAV。
    // 它们不依赖任何音频设备，因此在 CI（无音频后端）上也能完整跑通 ——
    // 这正好是「没接上音频线时先录音、事后分析」这个用法的保障。
    test('encodeWavFile → decodeWavFile 往返（含中继与中文）', () async {
      final link = AudioLink();
      final dir = Directory.systemTemp.createTempSync('afsk_link_test');
      try {
        final path = '${dir.path}/tx.wav';
        // 用带中继的报文：导出时中继会被编进地址字段，解回来会带 *
        const tnc2 = 'BG7LZQ-9>APALOC,WIDE1-1:!2230.00N/11400.00E>离线往返';
        final err = await link.encodeWavFile(path, tnc2);
        expect(err, isNull);
        final f = File(path);
        expect(f.existsSync(), isTrue);
        expect(f.lengthSync() > 44, isTrue); // 至少要有 WAV 头 + 数据

        final (lines, derr) = await link.decodeWavFile(path);
        expect(derr, isNull);
        expect(lines.length, 1);
        expect(lines.first, startsWith('BG7LZQ-9>APALOC,WIDE1-1*:'));
        expect(lines.first, endsWith('!2230.00N/11400.00E>离线往返'));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('导出非法报文返回错误码；读取不存在的文件不抛异常', () async {
      final link = AudioLink();
      expect(await link.encodeWavFile('/tmp/x.wav', '不是报文'), 'bad-format');
      final (lines, err) = await link.decodeWavFile('/tmp/definitely-missing.wav');
      expect(lines, isEmpty);
      expect(err, 'read-failed');
    });
  });

  group('参数持久化', () {
    test('fromJson 容错并对非法值收敛到安全范围', () {
      final p = AfskParams.fromJson({
        'sampleRate': 999999,
        'baud': 0,
        'amplitude': 5,
      });
      expect(p.sampleRate, 192000);
      expect(p.baud, 300);
      expect(p.amplitude, 1.0);
      expect(AfskParams.fromJson(null).sampleRate, 22050);
      expect(AfskParams.fromJson('oops').txDelayMs, 300);
    });

    test('toJson/fromJson 往返', () {
      const p = AfskParams(
          sampleRate: 44100, markHz: 1300, spaceHz: 2100, txDelayMs: 200, amplitude: 0.8);
      final back = AfskParams.fromJson(p.toJson());
      expect(back.sampleRate, 44100);
      expect(back.markHz, 1300);
      expect(back.spaceHz, 2100);
      expect(back.txDelayMs, 200);
      expect(back.amplitude, 0.8);
    });

    test('前导 flag 至少 4 个（TxDelay 配 0 也要给对端锁定时间）', () {
      expect(const AfskParams(txDelayMs: 0).preambleFlags, 4);
      expect(const AfskParams(txDelayMs: 300).preambleFlags, 45);
    });
  });
}
