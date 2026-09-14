/// ─── 音频链路（声卡 TNC / AFSK 1200）───
///
/// 与 APRS-IS / TNC 的关系：三者是**并列的数据来源**，由 `AppState.dataSource`
/// 选择。本类负责把 TNC2 文本 ↔ AX.25 帧 ↔ AFSK 音频互转：
///   * 收：`AudioTransport` 上来的 PCM → `AfskDemodulator` → AX.25 → TNC2 →
///     交给 `AppState._onAprsLine`（与 APRS-IS / TNC 完全同一条解析管线）；
///   * 发：TNC2 → AX.25（复用 `kiss.dart` 的 `Ax25`）→ `AfskModulator` → PCM →
///     `AudioTransport` 播放出去。
///
/// 因此台站解析、消息、过滤、成就等逻辑对三个来源完全共用，不会出现
/// 「音频模式下台站不上图」这类分叉 bug。
///
/// 射频语义（与 TNC 一致，见 `AppState.usingRf`）：
///   * 目的呼号 `APALOC`，**不加 TCPIP***（那是 APRS-IS 专有路径）；
///   * 单条消息 67 字符上限、禁用群聊广播；
///   * 自动周期发射需用户显式打开「射频信标」（默认关）；
///   * 发射前做 CSMA（等信道空闲）—— 射频频段是共享资源。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'afsk.dart';
import 'kiss.dart';
import 'net/audio.dart';
import 'net/audio_file.dart';
import 'wav.dart';

/// 音频链路状态码
class AudioStatus {
  AudioStatus._();

  static const String idle = 'idle';
  static const String connecting = 'connecting';
  static const String connected = 'connected';
  static const String closed = 'closed';
  static const String error = 'error';
  static const String unsupported = 'unsupported';
  static const String noPermission = 'no-permission';
}

/// 音频链路设置
class AudioConfig {
  /// AFSK 调制解调参数（采样率 / 音调 / 比特率 / TxDelay / 幅度）
  AfskParams afsk;

  /// 射频中继路径（如 `WIDE1-1,WIDE2-1`；留空 = 不指定中继）。
  /// 与 TNC 各自独立配置 —— 声卡接手持台和接车台的中继策略常常不同。
  String path;

  /// 应用侧 AX.25 帧长上限（字节）。1200bd 下单帧上限约 330 字节，
  /// 超过则**不发送**（而不是让对端丢弃或截断）
  int maxFrame;

  /// 允许发射（总开关）。关闭后只收不发 —— 只想收听信标时最省心，
  /// 也避免误触发电台 PTT
  bool txEnabled;

  /// 是否允许自动周期发射位置（安全开关，默认关 —— 射频发射需持照操作）
  bool rfBeacon;

  /// 收到需要 ack 的消息时自动回复 ack
  bool autoAck;

  /// 链路断开后自动重连
  bool autoReconnect;

  /// 发射前等待信道空闲的最长时间（ms）；期间持续检测到信号则延后发射
  int csmaWaitMs;

  AudioConfig({
    this.afsk = const AfskParams(),
    this.path = 'WIDE1-1,WIDE2-1',
    this.maxFrame = 330,
    this.txEnabled = true,
    this.rfBeacon = false,
    this.autoAck = true,
    this.autoReconnect = true,
    this.csmaWaitMs = 3000,
  });

  Map<String, dynamic> toJson() => {
        'afsk': afsk.toJson(),
        'path': path,
        'maxFrame': maxFrame,
        'txEnabled': txEnabled,
        'rfBeacon': rfBeacon,
        'autoAck': autoAck,
        'autoReconnect': autoReconnect,
        'csmaWaitMs': csmaWaitMs,
      };

  static AudioConfig fromJson(Object? j) {
    if (j is! Map) return AudioConfig();
    int i(Object? v, int d) => v is num ? v.toInt() : d;
    bool b(Object? v, bool d) => v is bool ? v : d;
    return AudioConfig(
      afsk: AfskParams.fromJson(j['afsk']),
      path: j['path']?.toString() ?? 'WIDE1-1,WIDE2-1',
      maxFrame: i(j['maxFrame'], 330).clamp(16, 512),
      txEnabled: b(j['txEnabled'], true),
      rfBeacon: b(j['rfBeacon'], false),
      autoAck: b(j['autoAck'], true),
      autoReconnect: b(j['autoReconnect'], true),
      csmaWaitMs: i(j['csmaWaitMs'], 3000).clamp(0, 10000),
    );
  }
}

/// 音频链路：参数、收发、统计与日志
class AudioLink {
  AudioLink({AudioTransport? transport})
      : _t = transport ?? createAudioTransport() {
    _t.onPcm = _onPcm;
    _t.onStatus = (s) {
      _log(s);
      onStateChanged?.call();
    };
    _t.onClosed = _onClosed;
    _t.onPlaybackDone = () {
      _playing = false;
      _playDone?.complete();
      _playDone = null;
      onStateChanged?.call();
    };
    _rebuildModem();
  }

  final AudioTransport _t;

  AudioConfig config = AudioConfig();

  bool connecting = false;
  bool connected = false;

  /// 状态码，见 [AudioStatus]
  String status = AudioStatus.idle;

  /// 状态补充说明（系统/后端错误原文，未本地化）
  String lastDetail = '';
  String lastError = '';

  /// 后端名称（winmm / native / stub）——界面提示用
  String get backendName => _t.backendName;

  /// 该平台是否支持实时收发（false = 只能走 WAV 文件模式）
  bool get realtime => _t.realtime;

  int rxFrames = 0;
  int txFrames = 0;
  int rxBytes = 0;
  int txBytes = 0;
  DateTime? lastRxAt;
  DateTime? lastTxAt;

  /// 解码中途中止的次数（失步/噪声）——信道质量参考
  int get badFrames => _demod.badFrameCount;

  /// 发射期间丢弃的采样字节数（半双工：不听自己）
  int droppedDuringTx = 0;

  /// 链路日志（环形，最多 100 条；供「音频」页排查用）
  final List<String> log = [];

  /// 解出的 TNC2 报文
  void Function(String line)? onLine;

  /// 链路断开（被动）
  void Function()? onClosed;

  /// 状态变化（连接/断开/错误/电平刷新）
  void Function()? onStateChanged;

  bool get up => connected;

  AudioTransport get transport => _t;

  // ─── 调制解调 ───

  late AfskModulator _mod;
  late AfskDemodulator _demod;

  void _rebuildModem() {
    _mod = AfskModulator(config.afsk);
    _demod = AfskDemodulator(config.afsk);
  }

  /// 当前相关幅度（0~1）——UI 电平表
  double get level => _demod.level;

  /// 近期峰值（缓慢衰减）
  double get peak => _demod.peak;

  /// 解调器是否已锁定（用于「信道忙」判断与界面提示）
  bool get synced => _demod.synced;

  /// 信道是否忙（有 AFSK 信号）：发射前 CSMA 依据
  bool get channelBusy => connected && (_demod.level > 0.18 && _demod.synced);

  /// 是否正在发射（半双工，期间不监听自己）
  bool get transmitting => _txActive;

  /// 是否正在播放音频（含尾音余量；[transmitting] 只看发射窗口）
  bool get playing => _playing;
  bool _txActive = false;
  bool _playing = false;

  void _log(String s) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    log.insert(0, '$ts  $s');
    if (log.length > 100) log.removeRange(100, log.length);
  }

  List<String> get logs => List.unmodifiable(log);

  // ─── 生命周期 ───

  Future<bool> supported() => _t.supported;

  /// 请求平台权限（Android 的 RECORD_AUDIO）
  Future<bool> requestPermissions() => _t.requestPermissions();

  /// 建立链路：打开采集。音频链路没有「对端设备」，连上即可收。
  Future<bool> connect() async {
    if (connected) return true;
    if (!await _t.supported) {
      status = AudioStatus.unsupported;
      lastError = 'unsupported';
      _log('当前平台不支持实时音频（可用 WAV 文件模式）');
      onStateChanged?.call();
      return false;
    }
    if (!await _t.requestPermissions()) {
      status = AudioStatus.noPermission;
      lastError = 'no-permission';
      _log('缺少录音权限（RECORD_AUDIO）');
      onStateChanged?.call();
      return false;
    }
    connecting = true;
    status = AudioStatus.connecting;
    lastError = '';
    _log('打开音频采集 @${config.afsk.sampleRate}Hz（${_t.backendName}）…');
    onStateChanged?.call();
    _rebuildModem();
    final err = await _t.startCapture(sampleRate: config.afsk.sampleRate);
    connecting = false;
    if (err != null) {
      connected = false;
      lastError = err;
      lastDetail = err;
      status = AudioStatus.error;
      _log('打开采集失败：$err');
      onStateChanged?.call();
      return false;
    }
    connected = true;
    status = AudioStatus.connected;
    _log('音频链路已建立（${_t.backendName} @${config.afsk.sampleRate}Hz）');
    onStateChanged?.call();
    return true;
  }

  Future<void> disconnect({bool manual = true}) async {
    await _t.stopCapture();
    await _t.stopPlayback();
    _txQueue.clear();
    connected = false;
    connecting = false;
    _txActive = false;
    _playing = false;
    status = AudioStatus.idle;
    if (manual) _log('已断开');
    onStateChanged?.call();
  }

  void _onClosed() {
    final was = connected;
    connected = false;
    status = AudioStatus.closed;
    if (was) _log('音频采集被系统中断');
    onStateChanged?.call();
    onClosed?.call();
  }

  /// 重启链路（音频参数改动后必须重建：解调器与采集采样率都要跟着换）
  Future<bool> restart() async {
    _log('重启音频链路…');
    await disconnect(manual: false);
    await Future.delayed(const Duration(milliseconds: 200));
    return connect();
  }

  /// 参数（采样率/音调/比特率）改动后应用：连接中则重开采集
  Future<void> applyParams({bool restartIfConnected = true}) async {
    _rebuildModem();
    if (connected && restartIfConnected) {
      await restart();
    }
    onStateChanged?.call();
  }

  // ─── 收 ───

  void _onPcm(Uint8List bytes) {
    if (bytes.isEmpty) return;
    rxBytes += bytes.length;
    // 半双工：发射期间听到的是自己的声音，喂给解调器会把自己的报文
    // 当外来报文再收一遍（还会污染 DPLL 锁定状态）
    if (_txActive) {
      droppedDuringTx += bytes.length;
      return;
    }
    final frames = _demod.feedBytes(bytes);
    for (final f in frames) {
      final tnc2 = Ax25.decodeToTnc2(f);
      if (tnc2 == null) {
        _log('丢弃非法 AX.25 帧（${f.length}B）');
        continue;
      }
      rxFrames++;
      lastRxAt = DateTime.now();
      onLine?.call(tnc2);
    }
    onStateChanged?.call();
  }

  // ─── 发 ───

  final List<String> _txQueue = [];
  bool _txRunning = false;
  Completer<void>? _playDone;

  /// 发送一条 TNC2 报文；返回错误描述，null 表示已**接受**（进入发射队列）。
  ///
  /// 与 TNC 不同，音频发射天生异步（先等信道空闲、再播放整段音频），
  /// 因此这里只做「能否接受」的同步校验，真正的失败通过 [onStateChanged]
  /// 与日志上报 —— 调用方（`AppState._sendRaw`）无需改成异步。
  String? sendTnc2(String tnc2) {
    if (!connected) {
      lastError = 'not-connected';
      return lastError;
    }
    if (!config.txEnabled) {
      lastError = 'tx-disabled';
      return lastError;
    }
    final frame = Ax25.encodeTnc2(tnc2);
    if (frame == null) {
      lastError = 'bad-format';
      return lastError;
    }
    if (config.maxFrame > 0 && frame.length > config.maxFrame) {
      lastError = 'frame-too-long';
      _log('帧过长 ${frame.length}B > ${config.maxFrame}B，未发送');
      onStateChanged?.call();
      return lastError;
    }
    if (_txQueue.length >= 16) {
      lastError = 'queue-full';
      _log('发射队列已满（16 条），丢弃本包');
      onStateChanged?.call();
      return lastError;
    }
    _txQueue.add(tnc2);
    lastError = '';
    unawaited(_pumpTx());
    return null;
  }

  Future<void> _pumpTx() async {
    if (_txRunning) return;
    _txRunning = true;
    try {
      while (_txQueue.isNotEmpty && connected) {
        final line = _txQueue.removeAt(0);
        await _txOne(line);
      }
    } finally {
      _txRunning = false;
      onStateChanged?.call();
    }
  }

  Future<void> _txOne(String tnc2) async {
    if (!connected) return;
    // ① CSMA：射频频段是共享资源，先听再发（最多等 config.csmaWaitMs）
    if (config.csmaWaitMs > 0 && channelBusy) {
      final deadline = DateTime.now().add(Duration(milliseconds: config.csmaWaitMs));
      while (channelBusy && connected && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (channelBusy) _log('信道持续占用，延后发射');
    }
    if (!connected) return;

    final frame = Ax25.encodeTnc2(tnc2);
    if (frame == null) {
      _log('发射中止：报文格式不合法');
      return;
    }
    final audio = _mod.modulate(frame);
    final pcm = Uint8List.view(audio.buffer, audio.offsetInBytes, audio.lengthInBytes);
    final seconds = audio.length / config.afsk.sampleRate;

    // ② 半双工：发射期间不喂解调器；结束后复位，避免把发射尾音当半帧
    _txActive = true;
    _playing = true;
    _playDone = Completer<void>();
    final err = await _t.play(pcm, sampleRate: config.afsk.sampleRate);
    if (err != null) {
      lastError = err;
      _log('发射失败（$err）：${_trunc(tnc2)}');
      _txActive = false;
      _playing = false;
      _playDone = null;
      onStateChanged?.call();
      return;
    }
    txFrames++;
    txBytes += pcm.length;
    lastTxAt = DateTime.now();
    // ③ 等播放结束（写完成 ≠ 播完），超时兜底免得队列卡死
    await _playDone?.future.timeout(
      Duration(milliseconds: (seconds * 1000).round() + 1500),
      onTimeout: () {},
    );
    _txActive = false;
    _playing = false;
    _demod.reset();
    onStateChanged?.call();
  }

  /// 停止发射（清空队列 + 停止播放）
  Future<void> stopTx() async {
    _txQueue.clear();
    await _t.stopPlayback();
    _txActive = false;
    _playing = false;
    onStateChanged?.call();
  }

  // ─── 文件模式（离线收 / 离线发）───
  //
  // 用途：现场没接上音频线时先录下音频事后分析；或把待发报文导出成
  // WAV，用外部播放器/对讲机声卡线发出去。

  /// 解码一段 WAV（任意采样率，自动按文件采样率建解调器）。
  /// 返回 (解出的 TNC2 列表, 错误描述)
  Future<(List<String>, String?)> decodeWavFile(String path) async {
    final bytes = await readAudioFile(path);
    if (bytes == null) return (const <String>[], 'read-failed');
    final wav = Wav.decode(Uint8List.fromList(bytes));
    if (wav == null) return (const <String>[], 'bad-wav');
    final dem = AfskDemodulator(config.afsk.copyWith(sampleRate: wav.sampleRate));
    final out = <String>[];
    for (final f in dem.feed(wav.samples)) {
      final t = Ax25.decodeToTnc2(f);
      if (t != null) out.add(t);
    }
    return (out, null);
  }

  /// 把一条 TNC2 报文编码成 WAV 文件；返回错误描述，null 表示成功
  Future<String?> encodeWavFile(String path, String tnc2) async {
    final frame = Ax25.encodeTnc2(tnc2);
    if (frame == null) return 'bad-format';
    final audio = _mod.modulate(frame);
    return writeAudioFile(path, Wav.encode(audio, sampleRate: config.afsk.sampleRate));
  }

  // ─── 持久化 ───

  static const _kConfig = 'audioConfigJson';

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final c = p.getString(_kConfig);
      if (c != null && c.isNotEmpty) config = AudioConfig.fromJson(jsonDecode(c));
    } catch (_) {}
    _rebuildModem();
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kConfig, jsonEncode(config.toJson()));
    } catch (_) {}
  }
}

String _trunc(String s) => s.length <= 80 ? s : '${s.substring(0, 80)}…';
