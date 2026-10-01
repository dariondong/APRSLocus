import 'dart:async';
import 'dart:typed_data';

import 'icom_lan_base.dart';
import 'icom_lan_protocol.dart' show IcomLanAudioCodec;
import 'icom_lan_session_engine.dart' show IcomLanPhase;
import 'icom_lan_session.dart' as session_impl;
import 'icom_lan_settings.dart';

/// IC-705 局域网链路的真实实现（`dart:io` 平台）。
///
/// 它把自己伪装成一台"音频设备"：`startCapture` 建立电台链路后把电台音频
/// 交给上层，`play` 把待发音频交给电台发射（PTT + 音频包）。因此 APRSLocus
/// 既有的 AFSK 解调、AX.25、报文解析、消息、地图等功能**一行不用改**。
class IcomLanLinkIo implements IcomLanLink {
  IcomLanLinkIo({required this.config});

  @override
  final IcomLanConfig config;

  session_impl.IcomLanSession? _session;
  final List<String> _log = [];
  String _phaseLabel = '未连接';
  Completer<void>? _ready;
  bool _playing = false;
  bool _disposed = false;

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
  bool get realtime => true;

  @override
  String get backendName => 'IC-705 Wi-Fi';

  @override
  bool get capturing => _session?.isRunning ?? false;

  @override
  bool get playing => _playing;

  @override
  bool get isReceiving => _session?.isReceiving ?? false;

  @override
  String get phaseLabel => _phaseLabel;

  @override
  List<String> get logs => List.unmodifiable(_log);

  @override
  String? validateConfig() => config.validate();

  @override
  Future<bool> requestPermissions() async {
    // 电台直连只需要网络权限（应用本身已声明 INTERNET）。
    return true;
  }

  @override
  Future<String?> startCapture({required int sampleRate}) async {
    if (_disposed) return '链路已释放';
    final error = config.validate();
    if (error != null) return error;
    if (sampleRate != IcomLanAudioCodec.sampleRateHz) {
      _addLog('注意：IC-705 音频固定为 '
          '${IcomLanAudioCodec.sampleRateHz} Hz，'
          '已忽略请求的 $sampleRate Hz');
    }
    if (_session != null) return null;

    _ready = Completer<void>();
    final session = session_impl.IcomLanSession(
      config: config,
      callbacks: session_impl.IcomLanCallbacks(
        onLog: _addLog,
        onPcm: (pcm) => onPcm?.call(pcm),
        onAudioDiscontinuity: (reason) => _addLog('音频断点：$reason'),
        onStateChanged: (state) {
          _phaseLabel = _phaseOf(state.phase);
          if (state.phase == IcomLanPhase.receiving ||
              state.phase == IcomLanPhase.streamsReady) {
            if (_ready?.isCompleted == false) _ready?.complete();
          } else if (state.phase == IcomLanPhase.failed) {
            if (_ready?.isCompleted == false) {
              _ready?.completeError(StateError('连接失败'));
            }
          }
          onStatus?.call(_phaseLabel);
        },
      ),
    );
    _session = session;

    try {
      await session.start();
    } catch (error) {
      _session = null;
      return '建立电台链路失败：$error';
    }

    // 等到数据流打开（或失败/超时）。握手正常在 1–3 秒内完成；
    // 留 30 秒覆盖"电台刚开机、Wi-Fi 刚连上"的场景。
    try {
      await _ready!.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      _addLog('等待电台就绪超时');
      await _teardown();
      return '等待电台就绪超时（检查 IP / 用户名 / 密码与电台 WLAN 设置）';
    } catch (_) {
      final reason = _session?.state.failureReason ?? '未知原因';
      await _teardown();
      return '电台链路失败：$reason';
    }
    // 流已打开但还没有音频：链路算建立成功，由上层正常收包。
    onStatus?.call(_phaseLabel);
    return null;
  }

  @override
  Future<void> stopCapture() => _teardown();

  @override
  Future<String?> play(Uint8List pcm16le, {required int sampleRate}) async {
    final session = _session;
    if (session == null) return 'IC-705 未连接';
    if (!session.isReceiving) return 'IC-705 尚未就绪（${session.state.phase.name}）';
    if (_playing) return '上一次发射尚未结束';
    _playing = true;
    onStatus?.call('正在通过电台发射…');
    // 交给电台后立即返回（AudioTransport 的约定是"写入完成"而不是"播完"），
    // 播完再回调 onPlaybackDone —— 上层据此把"发射中"改回空闲。
    unawaited(() async {
      try {
        final error = await session.transmitPcm(pcm16le, sampleRate: sampleRate);
        if (error != null) _addLog('发射失败：$error');
      } catch (error) {
        _addLog('发射异常：$error');
      } finally {
        _playing = false;
        onPlaybackDone?.call();
      }
    }());
    return null;
  }

  @override
  Future<void> stopPlayback() async {
    _session?.cancelTransmit();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _teardown(notifyClosed: false);
  }

  @override
  void setOutputDevice(int id) {}

  @override
  void setInputDevice(int id) {}

  @override
  Future<List<AudioDevice>> listOutputDevices() async => const [];

  @override
  Future<List<AudioDevice>> listInputDevices() async => const [];

  Future<void> _teardown({bool notifyClosed = false}) async {
    final session = _session;
    _session = null;
    if (session != null) {
      await session.close();
    }
    _phaseLabel = '未连接';
    _playing = false;
    if (notifyClosed) onClosed?.call();
    onStatus?.call(_phaseLabel);
  }

  void _addLog(String message) {
    _log.add(message);
    while (_log.length > 100) {
      _log.removeAt(0);
    }
    onStatus?.call(message);
  }

  static String _phaseOf(IcomLanPhase phase) => switch (phase) {
        IcomLanPhase.stopped => '未连接',
        IcomLanPhase.openingSockets => '正在打开端口…',
        IcomLanPhase.controlDiscovery => '正在发现电台…',
        IcomLanPhase.authenticating => '正在登录电台…',
        IcomLanPhase.negotiating => '正在协商音频流…',
        IcomLanPhase.openingStreams => '正在打开数据流…',
        IcomLanPhase.streamsReady => '已连接（等待音频）',
        IcomLanPhase.receiving => '已连接（接收中）',
        IcomLanPhase.reconnectWait => '连接中断，正在重连…',
        IcomLanPhase.failed => '连接失败',
      };
}

IcomLanLink createIcomLanLink({required IcomLanConfig config}) =>
    IcomLanLinkIo(config: config);
