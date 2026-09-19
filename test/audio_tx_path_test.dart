import 'dart:io';
import 'dart:typed_data';

import 'package:aprslocus/afsk.dart';
import 'package:aprslocus/audio.dart';
import 'package:aprslocus/kiss.dart';
import 'package:aprslocus/net/audio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 假传输层：把「要播出去的 PCM」原样留下，供测试检查。
///
/// 为什么要这一层：`AudioLink.sendTnc2` 是一条**异步流水线**（进队列 →
/// CSMA → 调制 → 交给传输层 → 等播放结束），只测调制器测不到这条链。
/// 真机上它出过问题（发射出去的波形对方解不出），所以这里把「链路的出口」
/// 拿回来自己解一遍 —— 出口的采样能解出，就说明问题一定在音频通路
/// （音量/接线/扬声器频响），而不在协议或流水线。
class _FakeTransport implements AudioTransport {
  final List<int> played = [];
  int playCount = 0;

  @override
  bool get realtime => true;
  @override
  String get backendName => 'fake';
  @override
  bool get capturing => true;
  @override
  bool get playing => false;
  @override
  void Function(Uint8List pcm16le)? onPcm;
  @override
  void Function(String status)? onStatus;
  @override
  void Function()? onClosed;
  @override
  void Function()? onPlaybackDone;
  @override
  Future<bool> get supported async => true;
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Future<String?> startCapture({required int sampleRate}) async => null;
  @override
  Future<void> stopCapture() async {}
  @override
  Future<String?> play(Uint8List pcm16le, {required int sampleRate}) async {
    playCount++;
    played.addAll(pcm16le);
    return null;
  }

  @override
  Future<void> stopPlayback() async {}
  @override
  Future<void> dispose() async {}
}

/// 小端 PCM 字节 → Int16 采样（与 net/audio_io 上来的一致）
Int16List _pcm(Uint8List bytes) {
  final n = bytes.length ~/ 2;
  final out = Int16List(n);
  for (var i = 0; i < n; i++) {
    var v = bytes[i * 2] | (bytes[i * 2 + 1] << 8);
    if (v >= 0x8000) v -= 0x10000;
    out[i] = v;
  }
  return out;
}

void main() {
  const line = 'BG7LZQ-9>APALOC,WIDE1-1:>APRSlocus TX PATH TEST';

  test('发射链路出口的音频能被解出（协议与流水线都没问题）', () async {
    final t = _FakeTransport();
    final link = AudioLink(transport: t);
    expect(await link.connect(), isTrue);
    expect(link.sendTnc2(line), isNull);
    // 假传输层不发 playDone，所以用超时兜底等发射窗口结束
    for (var i = 0; i < 60 && link.transmitting; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(t.playCount, 1, reason: '一帧报文应当只播一次');
    expect(link.txFrames, 1);

    final pcm = _pcm(Uint8List.fromList(t.played));
    expect(pcm.length, greaterThan(0));
    final frames = AfskDemodulator(link.config.afsk).feed(pcm);
    expect(frames.length, 1, reason: '链路出口的采样必须能解出 1 帧');
    expect(frames.first, Ax25.encodeTnc2(line));

    // 发射体检数据：峰值应在合理区间（既不为 0 也不削顶）
    expect(link.lastTxPeak, greaterThan(0.15));
    expect(link.lastTxClipped, isFalse);
    expect(link.lastTxPreamble, greaterThanOrEqualTo(4));

    await link.disconnect();
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('导出 WAV 前后自解一遍，导出文件能被独立解出', () async {
    final t = _FakeTransport();
    final link = AudioLink(transport: t);
    final (bytes, err) = await link.encodeWavBytes(line);
    expect(err, isNull);
    expect(bytes, isNotNull);

    // 落盘再读回，走一遍真实文件（桌面上导出就是这条路径）
    final f = File('${Directory.systemTemp.path}/aprslocus_tx_path_test.wav');
    await f.writeAsBytes(bytes!, flush: true);
    final (lines, derr) = await link.decodeWavFile(f.path);
    expect(derr, isNull);
    // 注意不能直接和 `line` 比：解出来的报文里中继会带 `*`（AX.25 的
    // 「已被该中继转发」标记，是解码器的标准行为），所以要跟编码帧解回的
    // 形式比 —— 这也正是 encodeWavBytes 内部自检用的基准。
    final want = Ax25.decodeToTnc2(Ax25.encodeTnc2(line)!);
    expect(lines, [want]);
    await f.delete();
  });

  test('导出前的自解校验能拦住坏数据（防止写出一个解不出的 WAV）', () async {
    // 用非法报文：编码阶段就该返回 bad-format
    final link = AudioLink(transport: _FakeTransport());
    final (bytes, err) = await link.encodeWavBytes('缺尖括号和冒号');
    expect(bytes, isNull);
    expect(err, 'bad-format');
  });
}
