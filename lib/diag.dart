/// ─── 链路自检：TNC / 音频（声卡 TNC）───
///
/// 为什么需要它：射频链路出问题时，用户看到的只有「连不上 / 收不到」，
/// 可能的原因却横跨四五层 —— 平台支不支持、有没有权限、设备/声卡对不对、
/// 协议编解码是否正确、波形是否真的能解出来。靠猜既慢又容易误判。
///
/// 本模块把这些层拆成**一条条可独立判断的检查项**，每条都给出「结论」，
/// 失败时指向该修哪一层：
///   * 协议回路（KISS/AX.25、AFSK 调制解调）—— 不接电台就能跑，先排除软件问题；
///   * 平台能力（后端、权限）；
///   * 实时收发（采集是否真的有数据、扬声器是否能出声）；
///   * WAV 文件模式读写与解码。
///
/// 协议回路那一项**真的做编码→解码 / 调制→解调**，不是「看起来像成功」，
/// 因此能抓出「波形错了但一直没人发现」这类问题。
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'afsk.dart';
import 'audio.dart';
import 'kiss.dart';
import 'l10n/app_localizations.dart';
import 'net/audio_file.dart';
import 'wav.dart';

/// 一条检查结果
class DiagItem {
  /// 检查项名称（已本地化）
  final String label;

  /// 结论 / 依据（已本地化；失败时给出原因或下一步）
  final String detail;

  final bool ok;

  /// 警告而非失败（例如平台不支持实时音频，但 WAV 模式仍可用）
  final bool warn;

  const DiagItem(this.label, this.detail, {this.ok = true, this.warn = false});
}

/// 一次自检的结果
class DiagResult {
  final List<DiagItem> items;
  const DiagResult(this.items);

  /// 是否没有硬失败（警告不算）
  bool get ok => items.every((i) => i.ok || i.warn);

  /// 失败条数（警告不计）
  int get failures => items.where((i) => !i.ok).length;

  int get passed => items.where((i) => i.ok && !i.warn).length;

  DiagResult plus(DiagItem i) => DiagResult([...items, i]);

  DiagResult plusAll(Iterable<DiagItem> more) =>
      DiagResult([...items, ...more]);
}

/// 链路自检
class LinkDiag {
  LinkDiag._();

  /// 自检用报文：带中继，覆盖「地址字段 + 中继 + 信息字段」三段
  static const String sampleTnc2 =
      'BG7LZQ-9>APALOC,WIDE1-1,WIDE2-1:!2230.00N/11400.00E>链路自检';

  // ─── 协议回路：TNC（KISS + AX.25）───

  /// KISS 转义 + AX.25 编解码 + FCS 校验回路。
  ///
  /// 不依赖任何硬件：编好再解回来逐字节比对。这一项失败说明软件层的帧格式
  /// 有问题 —— 此时换任何 TNC 都收不到，先修代码而不是折腾设备。
  static DiagItem protocolLoopbackTnc(AppLocalizations l) {
    // ① KISS 转义：载荷故意含 FEND/FESC，必须能原样还原
    final payload = <int>[0xC0, 0xDB, 0x00, 0x7E, 0xAA];
    final decoded = KissDecoder().feed(Kiss.dataFrame(0, payload));
    if (decoded.length != 1 || !_same(decoded.first.payload, payload)) {
      return DiagItem(l.diagKissEscape, l.diagKissEscapeFail, ok: false);
    }
    // ② AX.25：编码成 UI 帧再解回文本（中继会被标 *，与真实接收一致）
    final frame = Ax25.encodeTnc2(sampleTnc2);
    if (frame == null) {
      return DiagItem(l.diagAx25, l.diagAx25Fail, ok: false);
    }
    final back = Ax25.decodeToTnc2(frame);
    final wantBody = sampleTnc2.substring(sampleTnc2.indexOf(':') + 1);
    if (back == null ||
        !back.startsWith('BG7LZQ-9>APALOC,WIDE1-1*,WIDE2-1*:') ||
        !back.endsWith(wantBody)) {
      return DiagItem(l.diagAx25, l.diagAx25Mismatch(back ?? 'null'), ok: false);
    }
    // ③ FCS：改一位必须被拒收 —— 否则「收到乱码」也会被当成成功
    final withFcs = Hdlc.appendFcs(frame);
    if (!Hdlc.checkFcs(withFcs)) {
      return DiagItem(l.diagFcs, l.diagFcsFail, ok: false);
    }
    final bad = List<int>.from(withFcs)..[3] ^= 0x01;
    if (Hdlc.checkFcs(bad)) {
      return DiagItem(l.diagFcs, l.diagFcsFail, ok: false);
    }
    return DiagItem(l.diagTncLoopback, l.diagTncLoopbackOk(frame.length));
  }

  // ─── 协议回路：音频（AFSK 调制解调）───

  /// AFSK 调制 → 解调 → AX.25 解码，端到端比对。
  ///
  /// 最能说明问题的一项：真的生成波形再解回来。通过就说明音调、比特率、
  /// NRZI、位填充、FCS 全部自洽，剩下的只可能是音频设备 / 音量 / 接线。
  static DiagItem protocolLoopbackAudio(AppLocalizations l,
      {int sampleRate = 22050}) {
    final frame = Ax25.encodeTnc2(sampleTnc2);
    if (frame == null) {
      return DiagItem(l.diagAfskLoopback, l.diagAx25Fail, ok: false);
    }
    final params = AfskParams(sampleRate: sampleRate, txDelayMs: 60);
    final audio = AfskModulator(params).modulate(frame);
    final out = AfskDemodulator(params).feed(audio);
    if (out.length != 1 || !_same(out.first, frame)) {
      return DiagItem(
          l.diagAfskLoopback, l.diagAfskLoopbackFail(out.length), ok: false);
    }
    // 顺带确认波形不是静音（否则「解出自己」会变成无意义的自证）
    var peak = 0;
    for (final s in audio) {
      final v = s.abs();
      if (v > peak) peak = v;
    }
    if (peak < 32767 * 0.3) {
      return DiagItem(l.diagAfskLoopback, l.diagAfskLevelFail, ok: false);
    }
    return DiagItem(
        l.diagAfskLoopback, l.diagAfskLoopbackOk(audio.length, sampleRate));
  }

  // ─── 平台能力 ───

  static Future<DiagItem> tncPlatform(AppLocalizations l, Future<bool> Function() probe,
      String backend) async {
    final ok = await probe();
    return ok
        ? DiagItem(l.diagPlatform, l.diagPlatformOk(backend))
        : DiagItem(l.diagPlatform, l.diagTncPlatformNo, ok: false);
  }

  static Future<DiagItem> audioPlatform(
      AppLocalizations l, AudioLink audio) async {
    if (!await audio.supported()) {
      // 不算失败：这些平台仍可用 WAV 文件模式收发
      return DiagItem(l.diagPlatform, l.diagAudioPlatformWarn, warn: true);
    }
    return DiagItem(
      l.diagPlatform,
      l.diagPlatformOk(audio.backendName) +
          (audio.realtime ? '' : ' · ${l.diagNoRealtime}'),
    );
  }

  // ─── 权限 ───

  static Future<DiagItem> audioPermission(
      AppLocalizations l, AudioLink audio) async {
    if (!await audio.supported()) {
      return DiagItem(l.diagPermission, l.diagSkipped, warn: true);
    }
    final ok = await audio.requestPermissions();
    return ok
        ? DiagItem(l.diagPermission, l.diagPermissionOk)
        : DiagItem(l.diagPermission, l.audioNeedPermission, ok: false);
  }

  // ─── 实时收发 ───

  /// 采集自检：打开采集，静候 [window] 看是否真的有 PCM 上来。
  ///
  /// 只判断「有没有数据」而不判断内容 —— 环境安静时收到的本就是噪声，
  /// 用它判断音质会误报；解调能力由协议回路那一项负责。
  static Future<DiagItem> audioCapture(
    AppLocalizations l,
    AudioLink audio, {
    Duration window = const Duration(milliseconds: 900),
  }) async {
    if (!await audio.supported()) {
      return DiagItem(l.diagCapture, l.diagSkipped, warn: true);
    }
    if (!await audio.requestPermissions()) {
      return DiagItem(l.diagCapture, l.audioNeedPermission, ok: false);
    }
    var bytes = 0;
    final prev = audio.transport.onPcm;
    audio.transport.onPcm = (d) {
      bytes += d.length;
      prev?.call(d);
    };
    final wasConnected = audio.connected;
    try {
      if (!wasConnected) {
        final ok = await audio.connect();
        if (!ok) {
          return DiagItem(
              l.diagCapture, l.diagCaptureFailed(audio.lastError), ok: false);
        }
      }
      await Future.delayed(window);
    } finally {
      audio.transport.onPcm = prev;
    }
    if (bytes <= 0) {
      return DiagItem(l.diagCapture, l.diagCaptureNoData, ok: false);
    }
    return DiagItem(l.diagCapture,
        l.diagCaptureOk(bytes, audio.config.afsk.sampleRate));
  }

  /// 扬声器自检：播一段 1200Hz 测试音（**不发射报文、不在射频上发射**）。
  ///
  /// 目的是确认音频口能出声 —— 声卡 TNC 发射靠的就是它。
  static Future<DiagItem> audioSpeaker(
      AppLocalizations l, AudioLink audio) async {
    if (!await audio.supported()) {
      return DiagItem(l.diagSpeaker, l.diagSkipped, warn: true);
    }
    final rate = audio.config.afsk.sampleRate;
    final n = (rate * 0.4).round();
    final tone = Int16List(n);
    for (var i = 0; i < n; i++) {
      // 幅度 0.5：既有明显声音又不削顶
      tone[i] = (32767 * 0.5 * math.sin(2 * math.pi * 1200 * i / rate))
          .round()
          .clamp(-32768, 32767)
          .toInt();
    }
    final pcm =
        Uint8List.view(tone.buffer, tone.offsetInBytes, tone.lengthInBytes);
    final err = await audio.transport.play(pcm, sampleRate: rate);
    if (err != null) {
      return DiagItem(l.diagSpeaker, l.diagSpeakerFail(err), ok: false);
    }
    await Future.delayed(const Duration(milliseconds: 500));
    await audio.transport.stopPlayback();
    return DiagItem(l.diagSpeaker, l.diagSpeakerOk);
  }

  // ─── WAV 文件模式 ───

  /// WAV 写 → 读 → 解码回路（文件模式可用性）
  static Future<DiagItem> audioFileIo(AppLocalizations l, String dir) async {
    final path = '$dir/link_diag_probe.wav';
    final frame = Ax25.encodeTnc2(sampleTnc2);
    if (frame == null) {
      return DiagItem(l.diagFileIo, l.diagAx25Fail, ok: false);
    }
    final wav = Wav.encode(
      AfskModulator(const AfskParams(txDelayMs: 60)).modulate(frame),
      sampleRate: 22050,
    );
    final werr = await writeAudioFile(path, wav);
    if (werr != null) {
      return DiagItem(l.diagFileIo, l.diagFileWriteFail(werr), ok: false);
    }
    final read = await readAudioFile(path);
    if (read == null) {
      return DiagItem(l.diagFileIo, l.diagFileReadFail, ok: false);
    }
    final parsed = Wav.decode(Uint8List.fromList(read));
    if (parsed == null) {
      return DiagItem(l.diagFileIo, l.diagFileReadFail, ok: false);
    }
    final back = AfskDemodulator(AfskParams(sampleRate: parsed.sampleRate))
        .feed(parsed.samples);
    if (back.length != 1 || !_same(back.first, frame)) {
      return DiagItem(l.diagFileIo, l.diagFileDecodeFail, ok: false);
    }
    return DiagItem(l.diagFileIo, l.diagFileIoOk(parsed.sampleRate));
  }

  // ─── 测试发射 ───

  /// 构造一条测试报文。
  ///
  /// 用**状态包**（`>`）而不是位置包：发出去不会在 aprs.fi 等地图上把本台站
  /// 挪到某个坐标（测试不该改变台站位置），但仍然能在对方/网关的原始报文
  /// 里看到，足以验证「真的发出去了」。
  static String testFrame(String fullCall, String txPath, String version) =>
      '$fullCall>$txPath:>APRSlocus TEST v$version';

  // ─── 工具 ───

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
