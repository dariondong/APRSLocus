/// IC-705 / Icom LAN 会话运行时（UDP 收发）。
///
/// 分工：
///   * `icom_lan_protocol.dart` —— 字节编解码（纯函数）；
///   * `icom_lan_rx_session_engine.dart` —— 握手/重连状态机（纯逻辑）；
///   * 本文件 —— 把状态机要求的动作翻译成真实 UDP 收发，并把收到的报文
///     翻译成状态机事件；同时负责音频重排、保活与 watchdog。
///
/// 依赖是注入的（[IcomLanSocketFactory]），因此整条握手流程可以在没有电台、
/// 没有网络的情况下用假 socket 跑单元测试。
///
/// 与 APRSLocus 的关系：本文件只产出/消费 **PCM16LE 单声道 12 kHz** 音频，
/// 不碰 AFSK/AX.25 —— 那些由既有的 `lib/afsk.dart` 与 `lib/audio.dart` 负责。
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'icom_lan_protocol.dart';
import 'icom_lan_rx_session_engine.dart';
import 'icom_lan_rx_session_types.dart';
import 'icom_lan_settings.dart';

export 'icom_lan_settings.dart' show IcomLanConfig;
export 'icom_lan_rx_session_types.dart';

extension IcomLanConfigPorts on IcomLanConfig {
  /// 各角色使用的本地/远端端口。
  int portFor(IcomLanChannelRole role) => switch (role) {
        IcomLanChannelRole.control => controlPort,
        IcomLanChannelRole.civ => controlPort + 1,
        IcomLanChannelRole.audio => controlPort + 2,
      };
}

/// 收到的 UDP 数据报。
class IcomLanDatagram {
  const IcomLanDatagram(this.data, this.from, this.fromPort);

  final Uint8List data;
  final InternetAddress from;
  final int fromPort;
}

/// UDP 通道抽象（只为可测试性存在）。
abstract class IcomLanDatagramSocket {
  /// 绑定后的本地端口（构造客户端 ID 时要用）。
  int get localPort;

  void Function(IcomLanDatagram datagram)? onDatagram;
  void Function(Object error)? onError;

  void send(Uint8List data, InternetAddress to, int port);
  void close();
}

/// 通道工厂（默认实现走 `dart:io` 的 RawDatagramSocket）。
typedef IcomLanSocketFactory = Future<IcomLanDatagramSocket> Function(
    int localPort);

Future<IcomLanDatagramSocket> defaultIcomLanSocketFactory(int localPort) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, localPort);
  return _RawIcomLanSocket(socket);
}

class _RawIcomLanSocket implements IcomLanDatagramSocket {
  _RawIcomLanSocket(this._socket) {
    _socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket.receive();
      if (datagram == null) return;
      onDatagram?.call(IcomLanDatagram(
          Uint8List.fromList(datagram.data), datagram.address, datagram.port));
    }, onError: (Object error) => onError?.call(error));
  }

  final RawDatagramSocket _socket;

  @override
  int get localPort => _socket.port;

  @override
  void Function(IcomLanDatagram datagram)? onDatagram;

  @override
  void Function(Object error)? onError;

  @override
  void send(Uint8List data, InternetAddress to, int port) {
    _socket.send(data, to, port);
  }

  @override
  void close() => _socket.close();
}

/// 会话对外回调。
class IcomLanCallbacks {
  const IcomLanCallbacks({
    this.onStateChanged,
    this.onLog,
    this.onAudioDiscontinuity,
    this.onPcm,
  });

  final void Function(IcomLanSessionState state)? onStateChanged;
  final void Function(String message)? onLog;

  /// 音频流出现断点（丢包 / 会话重启）：下游解调器必须复位。
  final void Function(String reason)? onAudioDiscontinuity;

  /// 收到 PCM16LE 单声道 12 kHz 音频。
  final void Function(Uint8List pcm)? onPcm;
}

/// 一个通道的运行时状态。
class _ChannelRuntime {
  _ChannelRuntime(this.role);

  final IcomLanChannelRole role;
  IcomLanDatagramSocket? socket;
  InternetAddress? remoteAddress;
  int? remotePort;
  int localId = 0;
  int? remoteId;
  int pingSequence = 0;
  int civSequence = 0;
  DateTime lastReceived = DateTime.now();
}

/// 会话运行时。
class IcomLanSession {
  IcomLanSession({
    required this.config,
    IcomLanCallbacks callbacks = const IcomLanCallbacks(),
    IcomLanSocketFactory socketFactory = defaultIcomLanSocketFactory,
    Random? random,
  })  : _callbacks = callbacks,
        _socketFactory = socketFactory,
        _random = random ?? Random();

  final IcomLanConfig config;
  final IcomLanCallbacks _callbacks;
  final IcomLanSocketFactory _socketFactory;
  final Random _random;

  final Map<IcomLanChannelRole, _ChannelRuntime> _channels = {};
  final Map<String, Timer> _timers = {};
  final Map<int, Uint8List> _trackedPackets = {};

  /// 套接字开/关是异步的（`dart:io` 绑定要等），串成一条链保证顺序，
  /// 同时让 [start] 能等"三个 UDP 通道都绑好"再返回。
  Future<void> _socketChain = Future<void>.value();

  IcomLanSessionState _state = const IcomLanSessionState();
  IcomLanSessionState get state => _state;

  int _generation = 0;
  bool _closed = false;
  bool _firstAudioReported = false;
  int _authInnerSequence = 0x30;
  int _nextTrackedSequence = 1;
  int _localToken = 0;
  int _radioToken = 0;
  IcomLanConnectionInfo? _announcement;
  InternetAddress? _radioAddress;
  DateTime? _lastTrackedAt;
  DateTime? _lastTxFinishedAt;

  // 音频重排：IC-705 走 UDP，音频包可能乱序或丢失。
  int? _expectedAudioSequence;
  final Map<int, Uint8List> _audioReorder = {};
  Timer? _audioFlushTimer;

  bool get isRunning => !_closed && _state.phase != IcomLanPhase.stopped;
  bool get isReceiving => _state.phase == IcomLanPhase.receiving;

  /// 各通道当前使用的客户端 ID（诊断/测试用；尚未打开时为 null）。
  int? localIdFor(IcomLanChannelRole role) => _channels[role]?.localId;

  /// 收到 PCM 的回调（等价于 `callbacks.onPcm`，此处再暴露一次便于适配层接线）。
  void Function(Uint8List pcm)? get onPcm => _callbacks.onPcm;

  // ─── 生命周期 ───

  Future<void> start() async {
    if (_closed) throw StateError('session 已关闭');
    final error = config.validate();
    if (error != null) throw ArgumentError(error);
    _dispatch(const IcomLanStart());
    await _socketChain;
  }

  Future<void> stop() async {
    _dispatch(const IcomLanStop());
  }

  Future<void> close() async {
    if (_closed) return;
    await stop();
    _closed = true;
    _cancelAllTimers();
    await _socketChain;
    await _closeSockets();
  }

  // ─── 状态机接线 ───

  void _dispatch(IcomLanEvent event) {
    final transition = IcomLanSessionEngine.reduce(_state, event);
    final previous = _state;
    _state = transition.state;
    if (previous.phase != _state.phase ||
        previous.failureReason != _state.failureReason) {
      _log('阶段 ${previous.phase.name} → ${_state.phase.name}'
          '${_state.failureReason == null ? '' : '（${_state.failureReason}）'}');
      _callbacks.onStateChanged?.call(_state);
    }
    for (final action in transition.actions) {
      _execute(action);
    }
  }

  void _execute(IcomLanAction action) {
    switch (action) {
      case IcomLanOpenSockets():
        _socketChain = _socketChain
            .then((_) => _openSockets())
            .catchError((Object error) => _log('打开套接字失败：$error'));
      case IcomLanCloseSockets():
        _socketChain = _socketChain
            .then((_) => _closeSockets())
            .catchError((Object error) => _log('关闭套接字失败：$error'));
      case IcomLanSendDiscovery():
        _startDiscovery(IcomLanChannelRole.control);
      case IcomLanSendLogin():
        _sendLogin();
      case IcomLanSendTokenConfirmation(:final token):
        _sendTokenConfirmation(token);
      case IcomLanScheduleConnectionInfoSettle():
        _scheduleConnectionInfoTimer(_connectionInfoSettleTimer, 3000);
      case IcomLanSendConnectionInfo():
        _sendConnectionInfo();
      case IcomLanScheduleConnectionInfoRetry():
        _scheduleConnectionInfoTimer(_connectionInfoRetryTimer, 10000);
      case IcomLanCancelConnectionInfoTimers():
        _cancelTimer(_connectionInfoSettleTimer);
        _cancelTimer(_connectionInfoRetryTimer);
      case IcomLanSendOpenStreams(:final endpoints):
        _openStreams(endpoints);
      case IcomLanScheduleRetry(:final attempt):
        _scheduleReconnect(attempt);
      case IcomLanCancelRetryTimer():
        _cancelTimer(_retryTimer);
      case IcomLanNotifyAudioDiscontinuity():
        _notifyAudioReset('会话重启');
    }
  }

  // ─── 套接字 ───

  Future<void> _openSockets() async {
    await _closeSockets();
    _generation += 1;
    final generation = _generation;
    _firstAudioReported = false;
    _authInnerSequence = 0x30;
    _nextTrackedSequence = 1;
    _localToken = _random.nextInt(0x10000);
    _radioToken = 0;
    _announcement = null;
    _radioAddress = null;
    _expectedAudioSequence = null;
    _audioReorder.clear();

    for (final role in IcomLanChannelRole.values) {
      final runtime = _ChannelRuntime(role);
      _channels[role] = runtime;
      final socket = await _socketFactory(config.portFor(role));
      if (generation != _generation || _closed) {
        socket.close();
        return;
      }
      runtime.socket = socket;
      runtime.lastReceived = DateTime.now();
      // WFVIEW profile：每个通道用独立的随机 32 位客户端 ID。
      runtime.localId = _random.nextInt(0xffffffff) | 1;
      socket.onDatagram = (datagram) {
        if (generation == _generation) _onDatagram(runtime, datagram);
      };
      socket.onError = (error) {
        if (generation != _generation) return;
        _log('${role.name} 套接字错误：$error');
        _dispatch(const IcomLanRecoverableFailure('socket error'));
      };
    }

    _channels[IcomLanChannelRole.control]!.remoteAddress =
        InternetAddress.tryParse(config.host.trim());
    _channels[IcomLanChannelRole.control]!.remotePort = config.controlPort;

    _startFixedTimer(_watchdogTimer, 500, _checkWatchdog, immediate: false);
    _dispatch(const IcomLanSocketsOpened());
  }

  Future<void> _closeSockets() async {
    _cancelAllTimers();
    for (final runtime in _channels.values) {
      try {
        runtime.socket?.close();
      } catch (_) {
        // 关闭失败不影响后续恢复。
      }
    }
    _channels.clear();
    _trackedPackets.clear();
    _audioReorder.clear();
    _audioFlushTimer?.cancel();
    _audioFlushTimer = null;
    _expectedAudioSequence = null;
  }

  // ─── 收包分派 ───

  void _onDatagram(_ChannelRuntime runtime, IcomLanDatagram datagram) {
    try {
      final data = datagram.data;
      if (runtime.role == IcomLanChannelRole.audio &&
          data.length > IcomLanAudioCodec.headerSize) {
        _handleAudio(audioData: data, runtime: runtime);
        return;
      }
      if (data.length == IcomLanHandshakeCodec.pingPacketSize) {
        _handlePing(runtime, data);
        runtime.lastReceived = DateTime.now();
        return;
      }
      if (data.length == IcomLanControlCodec.packetSize) {
        _handleControlPacket(runtime, data, datagram);
        runtime.lastReceived = DateTime.now();
        return;
      }
      if (runtime.role == IcomLanChannelRole.civ &&
          data.length > 0x15 &&
          data[0x10] == 0xc1) {
        _handleCivDatagram(runtime, data);
        runtime.lastReceived = DateTime.now();
        return;
      }
      if (runtime.role == IcomLanChannelRole.control) {
        switch (data.length) {
          case IcomLanHandshakeCodec.loginResponsePacketSize:
          case IcomLanHandshakeCodec.tokenPacketSize:
          case IcomLanHandshakeCodec.statusPacketSize:
          case IcomLanConnectionInfoCodec.packetSize:
            _handleControlSessionPacket(data);
            runtime.lastReceived = DateTime.now();
            return;
        }
      }
      if (data.length > IcomLanControlCodec.packetSize &&
          data.length >= 4 &&
          IcomLanBytes.readInt32Le(data, 0) == data.length) {
        // 变量长度的重传请求。
        _handleRetransmit(runtime, data);
        runtime.lastReceived = DateTime.now();
      }
    } on IcomLanProtocolException catch (error) {
      // 畸形包只记日志：现场噪声不应该把整条链路拆掉。
      _log('丢弃畸形报文（${runtime.role.name}）：${error.message}');
    } catch (error) {
      _log('处理报文失败（${runtime.role.name}）：$error');
    }
  }

  void _handleControlPacket(
    _ChannelRuntime runtime,
    Uint8List data,
    IcomLanDatagram datagram,
  ) {
    final packet = IcomLanControlCodec.decode(data,
        expectedReceiverId: runtime.localId);
    switch (packet.type) {
      case IcomLanControlCodec.typeRetransmit:
        _handleRetransmit(runtime, data);
      case IcomLanControlCodec.typeAreYouThere:
        _sendUntracked(
          runtime,
          IcomLanControlCodec.encode(IcomLanControlPacket(
            type: IcomLanControlCodec.typeIAmHere,
            sequence: packet.sequence,
            senderId: runtime.localId,
            receiverId: packet.senderId,
          )),
        );
      case IcomLanControlCodec.typeIAmHere:
        _onChannelDiscovered(runtime, packet.senderId, datagram);
      case IcomLanControlCodec.typeReady:
        _onChannelReady(runtime);
      case IcomLanControlCodec.typeDisconnect:
        _dispatch(const IcomLanRecoverableFailure('radio disconnected'));
    }
  }

  void _onChannelDiscovered(
    _ChannelRuntime runtime,
    int remoteId,
    IcomLanDatagram datagram,
  ) {
    runtime.remoteId = remoteId;
    runtime.remoteAddress = datagram.from;
    runtime.remotePort = datagram.fromPort;
    if (runtime.role == IcomLanChannelRole.control) {
      _radioAddress = datagram.from;
    }
    _cancelTimer(_discoveryTimer(runtime.role));
    _cancelTimer(_discoveryTimeoutTimer(runtime.role));
    // WFVIEW profile：探测到就立刻起心跳（不等 READY）。
    _startPing(runtime.role);
    _sendUntracked(
      runtime,
      _controlPacket(runtime, type: IcomLanControlCodec.typeReady, sequence: 1),
    );
    if (runtime.role == IcomLanChannelRole.control) {
      _dispatch(const IcomLanControlDiscovered());
    }
  }

  void _onChannelReady(_ChannelRuntime runtime) {
    switch (runtime.role) {
      case IcomLanChannelRole.control:
        _startPing(runtime.role);
        _startIdle(runtime.role);
        _dispatch(const IcomLanControlReady());
      case IcomLanChannelRole.civ:
        final remoteId = runtime.remoteId;
        if (remoteId != null) {
          _sendTracked(
            runtime,
            IcomLanHandshakeCodec.encodeCivOpenClose(IcomLanCivOpenClosePacket(
              sequence: 0,
              senderId: runtime.localId,
              receiverId: remoteId,
              civSequence: _nextCivSequence(runtime),
              action: IcomLanCivChannelAction.open,
            )),
          );
        }
        _startIdle(runtime.role);
        _dispatch(const IcomLanCivReady());
      case IcomLanChannelRole.audio:
        _dispatch(const IcomLanAudioReady());
    }
  }

  void _handlePing(_ChannelRuntime runtime, Uint8List data) {
    final packet = IcomLanHandshakeCodec.decodePing(data,
        expectedReceiverId: runtime.localId);
    if (packet.isReply) {
      if (packet.sequence == runtime.pingSequence) {
        runtime.pingSequence = (runtime.pingSequence + 1) & 0xffff;
      }
      return;
    }
    _sendUntracked(
      runtime,
      IcomLanHandshakeCodec.encodePing(IcomLanPingPacket(
        sequence: packet.sequence,
        senderId: runtime.localId,
        receiverId: packet.senderId,
        isReply: true,
        timestampBits: packet.timestampBits,
      )),
    );
  }

  void _handleCivDatagram(_ChannelRuntime runtime, Uint8List data) {
    final datagram =
        IcomLanCivDatagramCodec.decode(data, expectedReceiverId: runtime.localId);
    // 电台回报「PTT 已回到接收」（CI-V 1C 00 00）——发射流程据此确认。
    if (IcomLanCivCommands.isPttOffReport(datagram.civFrame)) {
      _txPttAcknowledged = true;
      _txAckCompleter?.completeIfPending();
    }
  }

  /// 通用控制会话报文（登录应答 / 令牌 / 状态 / 0x90）。
  void _handleControlSessionPacket(Uint8List data) {
    final control = _channels[IcomLanChannelRole.control];
    if (control == null) return;
    switch (data.length) {
      case IcomLanHandshakeCodec.loginResponsePacketSize:
        final response = IcomLanHandshakeCodec.decodeLoginResponse(data,
            expectedReceiverId: control.localId);
        if (response.isAuthenticated) {
          _radioToken = response.header.token;
          _dispatch(IcomLanLoginAccepted(_radioToken));
        } else {
          _dispatch(const IcomLanLoginRejected('账号或密码被电台拒绝'));
        }
      case IcomLanHandshakeCodec.tokenPacketSize:
        final token = IcomLanHandshakeCodec.decodeTokenPacket(data,
            expectedReceiverId: control.localId);
        if (token.header.requestType ==
                IcomLanHandshakeCodec.tokenRequestRenewal &&
            token.header.requestReply ==
                IcomLanHandshakeCodec.requestReplyResponse) {
          if (token.responseCode == 0xffffffff) {
            control.remoteId = token.header.senderId;
            _localToken = token.header.tokenRequest;
            _radioToken = token.header.token;
            if (_state.connectionRequestAuthorized) {
              _dispatch(const IcomLanRecoverableFailure('令牌需要重新授权'));
            } else {
              _dispatch(const IcomLanConnectionRequestAuthorized());
            }
          } else if (token.responseCode != 0) {
            _dispatch(const IcomLanRecoverableFailure('令牌续期被拒'));
          }
        }
      case IcomLanConnectionInfoCodec.packetSize:
        final announcement = IcomLanConnectionInfoCodec.decodeAnnouncement(
            data,
            expectedReceiverId: control.localId);
        if (!announcement.isBusy) {
          _announcement = announcement;
          control.remoteId = announcement.header.senderId;
          _localToken = announcement.header.tokenRequest;
          _radioToken = announcement.header.token;
          _dispatch(const IcomLanConnectionInfoReceived());
          if (!_state.connectionRequestAuthorized) {
            _dispatch(const IcomLanConnectionRequestAuthorized());
          }
        } else if (_state.connectionInfoSent &&
            announcement.busyClientName == config.clientName) {
          // 我们自己的请求成功后，电台会把这条流标成"自己占用"。
          final endpoints = _defaultStreamEndpoints();
          if (endpoints != null) {
            _dispatch(IcomLanStatusEndpointsReceived(endpoints));
          }
        }
      case IcomLanHandshakeCodec.statusPacketSize:
        final status = IcomLanHandshakeCodec.decodeStatusPacket(data,
            expectedReceiverId: control.localId);
        if (status.isAuthenticated &&
            status.isConnected &&
            status.civPort != 0 &&
            status.audioPort != 0) {
          _dispatch(IcomLanStatusEndpointsReceived(IcomLanStreamEndpoints(
            civPort: status.civPort,
            audioPort: status.audioPort,
          )));
        } else {
          _dispatch(IcomLanStatusNotReady(
            errorCode: status.errorCode,
            disconnectFlag: status.disconnectFlag,
          ));
        }
    }
  }

  IcomLanStreamEndpoints? _defaultStreamEndpoints() {
    if (config.controlPort > 0xffff - 2) return null;
    return IcomLanStreamEndpoints(
      civPort: config.controlPort + 1,
      audioPort: config.controlPort + 2,
    );
  }

  // ─── 握手发包 ───

  void _sendLogin() {
    final control = _channels[IcomLanChannelRole.control];
    final remoteId = control?.remoteId;
    if (control == null || remoteId == null) return;
    final innerSequence = _nextAuthInnerSequence();
    _sendTracked(
      control,
      IcomLanHandshakeCodec.encodeLoginRequest(
        sequence: 0,
        senderId: control.localId,
        receiverId: remoteId,
        innerSequence: innerSequence,
        tokenRequest: _localToken,
        token: _radioToken,
        username: config.username,
        password: config.password,
        clientName: config.clientName,
      ),
    );
  }

  void _sendTokenConfirmation(int token) {
    final control = _channels[IcomLanChannelRole.control];
    final remoteId = control?.remoteId;
    if (control == null || remoteId == null) return;
    _radioToken = token;
    _sendTracked(
      control,
      IcomLanHandshakeCodec.encodeTokenConfirm(
        sequence: 0,
        senderId: control.localId,
        receiverId: remoteId,
        innerSequence: _nextAuthInnerSequence(),
        tokenRequest: _localToken,
        token: _radioToken,
      ),
    );
    _startFixedTimer(_tokenRenewalTimer, 60000, _sendTokenRenewal,
        immediate: false);
  }

  void _sendTokenRenewal() {
    final control = _channels[IcomLanChannelRole.control];
    final remoteId = control?.remoteId;
    if (control == null || remoteId == null) return;
    _sendTracked(
      control,
      IcomLanHandshakeCodec.encodeTokenRenewal(
        sequence: 0,
        senderId: control.localId,
        receiverId: remoteId,
        innerSequence: _nextAuthInnerSequence(),
        tokenRequest: _localToken,
        token: _radioToken,
      ),
    );
  }

  void _sendConnectionInfo() {
    final control = _channels[IcomLanChannelRole.control];
    final remoteId = control?.remoteId;
    final announcement = _announcement;
    final civ = _channels[IcomLanChannelRole.civ];
    final audio = _channels[IcomLanChannelRole.audio];
    if (control == null || remoteId == null || announcement == null) return;
    _sendTracked(
      control,
      IcomLanConnectionInfoCodec.encodeParameters(IcomLanConnectionParameters(
        sequence: 0,
        senderId: control.localId,
        receiverId: remoteId,
        innerSequence: _nextAuthInnerSequence(),
        tokenRequest: _localToken,
        token: _radioToken,
        radioIdentityBlock: announcement.radioIdentityBlock,
        radioName: announcement.radioName,
        username: config.username,
        localCivPort: civ?.socket?.localPort ?? (config.controlPort + 1),
        localAudioPort: audio?.socket?.localPort ?? (config.controlPort + 2),
        receiveEnabled: true,
        // 电台在协商期就期待全双工 LPCM 能力位；这里如实声明，因为本实现
        // 确实支持发射（PTT + 音频包）。
        transmitEnabled: true,
        receiveSampleRateHz: IcomLanAudioCodec.sampleRateHz,
        transmitSampleRateHz: IcomLanAudioCodec.sampleRateHz,
      )),
    );
  }

  void _openStreams(IcomLanStreamEndpoints endpoints) {
    final radio = _radioAddress ?? InternetAddress.tryParse(config.host.trim());
    if (radio == null) return;
    for (final entry in {
      IcomLanChannelRole.civ: endpoints.civPort,
      IcomLanChannelRole.audio: endpoints.audioPort,
    }.entries) {
      final runtime = _channels[entry.key];
      if (runtime == null) continue;
      runtime.remoteAddress = radio;
      runtime.remotePort = entry.value;
      _startDiscovery(entry.key);
    }
  }

  // ─── 定时任务：探测 / 心跳 / 空闲 / 看门狗 ───

  void _startDiscovery(IcomLanChannelRole role) {
    final runtime = _channels[role];
    if (runtime == null) return;
    final generation = _generation;
    _sendProbe(runtime);
    _startFixedTimer(_discoveryTimer(role), 500, () {
      if (generation == _generation) _sendProbe(runtime);
    }, immediate: false);
    _cancelTimer(_discoveryTimeoutTimer(role));
    _timers[_discoveryTimeoutTimer(role)] = Timer(const Duration(seconds: 10),
        () {
      if (generation == _generation && runtime.remoteId == null) {
        _dispatch(const IcomLanRecoverableFailure('电台未响应探测包'));
      }
    });
  }

  void _sendProbe(_ChannelRuntime runtime) {
    _sendUntracked(
      runtime,
      IcomLanControlCodec.encode(IcomLanControlPacket(
        type: IcomLanControlCodec.typeAreYouThere,
        sequence: 0,
        senderId: runtime.localId,
        receiverId: 0,
      )),
    );
  }

  void _startPing(IcomLanChannelRole role) {
    final runtime = _channels[role];
    if (runtime == null) return;
    final generation = _generation;
    _sendPing(runtime);
    _startFixedTimer(_pingTimer(role), 100, () {
      if (generation == _generation) _sendPing(runtime);
    }, immediate: false);
  }

  void _sendPing(_ChannelRuntime runtime) {
    final remoteId = runtime.remoteId;
    if (remoteId == null) return;
    _sendUntracked(
      runtime,
      IcomLanHandshakeCodec.encodePing(IcomLanPingPacket(
        sequence: runtime.pingSequence,
        senderId: runtime.localId,
        receiverId: remoteId,
        isReply: false,
        timestampBits: DateTime.now().millisecondsSinceEpoch & 0xffffffff,
      )),
    );
  }

  void _startIdle(IcomLanChannelRole role) {
    final runtime = _channels[role];
    if (runtime == null) return;
    final generation = _generation;
    _startFixedTimer(_idleTimer(role), 100, () {
      if (generation != _generation) return;
      final last = _lastTrackedAt;
      if (last != null &&
          DateTime.now().difference(last).inMilliseconds < 100) {
        return;
      }
      _sendTracked(
        runtime,
        _controlPacket(runtime, type: IcomLanControlCodec.typeNull, sequence: 0),
      );
    }, immediate: false);
  }

  void _checkWatchdog() {
    final now = DateTime.now();
    for (final entry in _channels.entries) {
      final runtime = entry.value;
      if (runtime.remoteId == null) continue;
      final timeoutMillis = switch (entry.key) {
        IcomLanChannelRole.control => 5000,
        IcomLanChannelRole.civ => 3000,
        IcomLanChannelRole.audio => 30000,
      };
      if (now.difference(runtime.lastReceived).inMilliseconds >
          timeoutMillis) {
        _dispatch(IcomLanRecoverableFailure('${entry.key.name} 通道超时'));
        return;
      }
    }
  }

  // ─── 音频收 ───

  void _handleAudio({required Uint8List audioData, required _ChannelRuntime runtime}) {
    final packet = IcomLanAudioCodec.decode(audioData,
        expectedReceiverId: runtime.localId);
    final sequence = packet.header.audioSequence;
    final expected = _expectedAudioSequence;
    if (expected == null) {
      _expectedAudioSequence = (sequence + 1) & 0xffff;
      _deliverAudio(packet.pcmPayload);
      return;
    }
    if (sequence == expected) {
      _expectedAudioSequence = (sequence + 1) & 0xffff;
      _deliverAudio(packet.pcmPayload);
      _drainAudioReorder();
      return;
    }
    // 乱序：先缓冲，等缺口补齐；超时则放弃等待并通知下游复位解调器。
    _audioReorder[sequence] = packet.pcmPayload;
    if (_audioReorder.length > 64) {
      // 缓冲上限：直接按序吐出，避免无限增长。
      _flushAudioReorder('音频缓冲溢出');
      return;
    }
    _audioFlushTimer ??= Timer(const Duration(milliseconds: 200), () {
      _audioFlushTimer = null;
      _flushAudioReorder('音频包丢失');
    });
  }

  void _drainAudioReorder() {
    final start = _expectedAudioSequence;
    if (start == null) return;
    var expected = start;
    while (_audioReorder.containsKey(expected)) {
      final payload = _audioReorder.remove(expected)!;
      expected = (expected + 1) & 0xffff;
      _expectedAudioSequence = expected;
      _deliverAudio(payload);
    }
  }

  void _flushAudioReorder(String reason) {
    if (_audioReorder.isEmpty) return;
    final sequences = _audioReorder.keys.toList()..sort();
    _callbacks.onAudioDiscontinuity?.call(reason);
    for (final sequence in sequences) {
      _deliverAudio(_audioReorder.remove(sequence)!);
      _expectedAudioSequence = (sequence + 1) & 0xffff;
    }
  }

  void _deliverAudio(Uint8List pcm) {
    _callbacks.onPcm?.call(pcm);
    if (!_firstAudioReported) {
      _firstAudioReported = true;
      _dispatch(const IcomLanFirstAudio());
    }
  }

  void _notifyAudioReset(String reason) {
    _expectedAudioSequence = null;
    _audioReorder.clear();
    _callbacks.onAudioDiscontinuity?.call(reason);
  }

  // ─── 音频发（PTT + 音频包）───

  bool _txPttAcknowledged = false;
  bool _txCancelled = false;
  _Completer? _txAckCompleter;

  /// 请求中断正在进行的发射（广播里的"停止发射"按钮走这条路）。
  ///
  /// 只在音频流循环里被检查，PTT 释放仍在 `transmitPcm` 的 finally 中执行 ——
  /// 也就是说无论怎么中断，电台都会被放回接收态。
  void cancelTransmit() {
    _txCancelled = true;
  }

  /// 通过电台发射一段 PCM16LE（12 kHz 单声道）。
  ///
  /// 顺序：CI-V PTT ON → 等待电台 ACK → 按实时节奏发音频包 → PTT OFF → 等排空。
  /// 任何一步失败都会尽力释放 PTT（电台停在发射态是危险的）。
  Future<String?> transmitPcm(Uint8List pcm16le,
      {int sampleRate = IcomLanAudioCodec.sampleRateHz}) async {
    if (!isReceiving) return 'IC-705 未就绪';
    final civ = _channels[IcomLanChannelRole.civ];
    final audio = _channels[IcomLanChannelRole.audio];
    if (civ == null || audio == null) return 'IC-705 未连接';
    final finishedAt = _lastTxFinishedAt;
    if (finishedAt != null &&
        DateTime.now().difference(finishedAt).inMilliseconds < 300) {
      return '上一次发射尚未冷却';
    }
    _txCancelled = false;

    try {
      await _sendPtt(civ, true);
    } catch (error) {
      return 'PTT ON 失败：$error';
    }
    try {
      await _streamAudio(audio, pcm16le, sampleRate);
    } finally {
      try {
        await _sendPtt(civ, false);
      } catch (error) {
        _log('PTT OFF 失败：$error');
      }
      _lastTxFinishedAt = DateTime.now();
    }
    return null;
  }

  Future<void> _sendPtt(_ChannelRuntime civ, bool on) async {
    final remoteId = civ.remoteId;
    if (remoteId == null) throw StateError('CI-V 通道未就绪');
    _txPttAcknowledged = false;
    _sendTracked(
      civ,
      IcomLanCivDatagramCodec.encode(IcomLanCivDatagram(
        sequence: 0,
        senderId: civ.localId,
        receiverId: remoteId,
        civSequence: _nextCivSequence(civ),
        civFrame: IcomLanCivCommands.buildPttFrame(
          pttOn: on,
          radioAddress: config.radioCivAddress,
          controllerAddress: config.controllerCivAddress,
        ),
      )),
    );
    if (!on) {
      // 释放命令发完即可（电台随后会回报 RX 状态）。
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return;
    }
    // PTT ON 后等电台 ACK（CI-V 回读）或短超时：超时仍继续发音频，
    // 但不再久等 —— 电台对 PTT 的响应通常远快于一个包时长。
    final completer = _Completer();
    _txAckCompleter = completer;
    await completer.future.timeout(const Duration(milliseconds: 300),
        onTimeout: () {});
    _txAckCompleter = null;
    if (!_txPttAcknowledged) {
      _log('PTT ON 未收到回读，继续发射');
    }
  }

  Future<void> _streamAudio(
      _ChannelRuntime audio, Uint8List pcm, int sampleRate) async {
    final remoteId = audio.remoteId;
    if (remoteId == null) throw StateError('音频通道未就绪');
    const bytesPerPacket = IcomLanAudioCodec.bytesPerPacket;
    final stopwatch = Stopwatch()..start();
    var index = 0;
    for (var offset = 0; offset < pcm.length; offset += bytesPerPacket) {
      if (!isReceiving || _txCancelled) break;
      final end = min(offset + bytesPerPacket, pcm.length);
      final chunk = Uint8List.fromList(pcm.sublist(offset, end));
      // 60 ms 前导，填满电台 DSP 抖动缓冲，避免欠载。
      final targetMillis =
          index * (IcomLanAudioCodec.samplesPerPacket * 1000 ~/ sampleRate) - 60;
      final waitMillis = targetMillis - stopwatch.elapsedMilliseconds;
      if (waitMillis > 0) {
        await Future<void>.delayed(Duration(milliseconds: waitMillis));
      }
      _sendTracked(
        audio,
        IcomLanAudioCodec.encode(
          sequence: _nextTrackedSequence++ & 0xffff,
          senderId: audio.localId,
          receiverId: remoteId,
          audioSequence: _nextTxAudioSequence++ & 0xffff,
          pcmPayload: chunk,
        ),
      );
      index++;
    }
    // 排空：等最后一个包播完再放 PTT。
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  int _nextTxAudioSequence = 1;

  // ─── 追踪包（重传）───

  void _handleRetransmit(_ChannelRuntime runtime, Uint8List data) {
    final sequences =
        IcomLanControlCodec.decodeRetransmitRequest(data,
            expectedReceiverId: runtime.localId);
    for (final sequence in sequences) {
      final stored = _trackedPackets[sequence];
      if (stored != null) {
        _sendUntracked(runtime, stored);
      } else {
        _sendUntracked(
          runtime,
          _controlPacket(runtime,
              type: IcomLanControlCodec.typeNull, sequence: sequence),
        );
      }
    }
  }

  void _sendTracked(_ChannelRuntime runtime, Uint8List template) {
    final sequence = _nextTrackedSequence;
    _nextTrackedSequence = (_nextTrackedSequence + 1) & 0xffff;
    final copy = Uint8List.fromList(template);
    if (copy.length >= 8) {
      IcomLanBytes.writeUInt16Le(copy, 0x06, sequence);
    }
    _trackedPackets[sequence] = copy;
    if (_trackedPackets.length > 64) {
      _trackedPackets.remove(_trackedPackets.keys.first);
    }
    _lastTrackedAt = DateTime.now();
    _sendUntracked(runtime, copy);
  }

  void _sendUntracked(_ChannelRuntime runtime, Uint8List data) {
    final socket = runtime.socket;
    final address = runtime.remoteAddress;
    final port = runtime.remotePort;
    if (socket == null || address == null || port == null) return;
    try {
      socket.send(data, address, port);
    } catch (error) {
      _log('${runtime.role.name} 发送失败：$error');
    }
  }

  Uint8List _controlPacket(
    _ChannelRuntime runtime, {
    required int type,
    required int sequence,
  }) =>
      IcomLanControlCodec.encode(IcomLanControlPacket(
        type: type,
        sequence: sequence,
        senderId: runtime.localId,
        receiverId: runtime.remoteId ?? 0,
      ));

  int _nextCivSequence(_ChannelRuntime runtime) {
    final value = runtime.civSequence;
    runtime.civSequence = (runtime.civSequence + 1) & 0xffff;
    return value;
  }

  int _nextAuthInnerSequence() {
    final value = _authInnerSequence;
    _authInnerSequence = (_authInnerSequence + 1) & 0xffff;
    return value;
  }

  // ─── 定时器管理 ───

  static const _watchdogTimer = 'watchdog';
  static const _tokenRenewalTimer = 'token-renewal';
  static const _retryTimer = 'retry';
  static const _connectionInfoSettleTimer = 'conn-settle';
  static const _connectionInfoRetryTimer = 'conn-retry';

  static String _discoveryTimer(IcomLanChannelRole role) =>
      'discovery-${role.name}';
  static String _discoveryTimeoutTimer(IcomLanChannelRole role) =>
      'discovery-timeout-${role.name}';
  static String _pingTimer(IcomLanChannelRole role) => 'ping-${role.name}';
  static String _idleTimer(IcomLanChannelRole role) => 'idle-${role.name}';

  void _startFixedTimer(String key, int periodMillis, void Function() body,
      {bool immediate = true}) {
    _cancelTimer(key);
    if (immediate) body();
    _timers[key] = Timer.periodic(Duration(milliseconds: periodMillis), (_) => body());
  }

  void _scheduleConnectionInfoTimer(String key, int delayMillis) {
    _cancelTimer(key);
    _timers[key] = Timer(Duration(milliseconds: delayMillis), () {
      _dispatch(key == _connectionInfoSettleTimer
          ? const IcomLanConnectionInfoSettleTimerFired()
          : const IcomLanConnectionInfoRetryTimerFired());
    });
  }

  void _scheduleReconnect(int attempt) {
    _cancelTimer(_retryTimer);
    // 指数退避 1s → 30s（与 Kotlin 实现一致）。
    final base = 1000 * (1 << min(attempt - 1, 5));
    final delay = min(base, 30000);
    _timers[_retryTimer] = Timer(Duration(milliseconds: delay), () {
      _dispatch(const IcomLanRetryTimerFired());
    });
  }

  void _cancelTimer(String key) {
    _timers.remove(key)?.cancel();
  }

  void _cancelAllTimers() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  void _log(String message) => _callbacks.onLog?.call(message);
}

/// 简单可取消的 Completer（PTT ACK 用）。
class _Completer {
  final Completer<void> _completer = Completer<void>();

  Future<void> get future => _completer.future;

  void completeIfPending() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
