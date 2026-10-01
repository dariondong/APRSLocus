// SPDX-License-Identifier: GPL-2.0-or-later
// See LICENSING.md: this file is additionally available under GPL-2.0-or-later.

library;

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'icom_lan_packet_inspector.dart';
import 'icom_lan_pcm16.dart';
import 'icom_lan_protocol.dart';
import 'icom_lan_ptt_state_machine.dart';
import 'icom_lan_radio_session.dart';
import 'icom_lan_rx_audio_receiver.dart';
import 'icom_lan_rx_session_engine.dart';
import 'icom_lan_rx_session_types.dart';
import 'icom_lan_session.dart' show IcomLanDatagramSocket;
import 'icom_lan_session_policy.dart';
import 'icom_lan_session_task_registry.dart';
import 'icom_lan_session_timing_policy.dart';
import 'icom_lan_settings.dart';
import 'icom_lan_tracked_packet_store.dart';
import 'icom_lan_tx_audio_packetizer.dart';
import 'icom_lan_udp_channel.dart' hide IcomLanDatagramSocket;

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
  final void Function(String reason)? onAudioDiscontinuity;
  final void Function(Uint8List pcm)? onPcm;
}

class _AudioPcmSink implements IcomLanPcmSink {
  _AudioPcmSink({required this.onSamples});

  final void Function(Int16List samples) onSamples;

  @override
  IcomLanPcmFormat get format => const IcomLanPcmFormat(
        sampleRateHz: IcomLanAudioCodec.sampleRateHz,
        channelCount: 1,
      );

  @override
  void write(Int16List samples) => onSamples(samples);
}

class _ChannelRuntime {
  _ChannelRuntime(this.role);

  final IcomLanChannelRole role;
  IcomLanDatagramChannel? channel;
  int localId = 0;
  int? remoteId;
  int pingSequence = 0;
  int civSequence = 0;
  late final IcomLanTrackedPacketStore trackedPackets =
      IcomLanTrackedPacketStore();
  DateTime lastReceived = DateTime.now();
}

/// IC-705 LAN 会话核心运行时（对应 mod 的 `session/Ic705RxSession.kt`）。
///
/// 整合 P0 类型/策略/任务注册表、P1 追踪存储/音频接收重排/发射分片、
/// P2 故障安全 PTT 状态机与 P3 UDP 传输通道。
class IcomLanRxSession implements IcomLanRadioSession {
  IcomLanRxSession({
    required this.config,
    this._callbacks = const IcomLanCallbacks(),
    IcomLanRxSessionTiming? timing,
    Future<IcomLanDatagramSocket> Function(int localPort)? socketFactory,
    Random? random,
    int Function()? monotonicMillis,
  })  : _timing = timing ?? IcomLanRxSessionTiming(),
        _legacySocketFactory = socketFactory,
        _random = random ?? Random(),
        _monotonicMillis = monotonicMillis ??
            (() => DateTime.now().microsecondsSinceEpoch ~/ 1000) {
    _taskRegistry = IcomLanSessionTaskRegistry();
    _pttStateMachine = IcomLanPttStateMachine(
      actions: _PttActionsImpl(this),
      radioAddress: config.radioCivAddress,
      controllerAddress: config.controllerCivAddress,
      ackTimeoutMs: 500,
      absoluteWatchdogMs: 5000,
      onLog: _log,
    );
  }

  final IcomLanConfig config;
  final IcomLanCallbacks _callbacks;
  final IcomLanRxSessionTiming _timing;
  final Future<IcomLanDatagramSocket> Function(int localPort)?
      _legacySocketFactory;
  final Random _random;
  final int Function() _monotonicMillis;

  late final IcomLanSessionTaskRegistry _taskRegistry;
  late final IcomLanPttStateMachine _pttStateMachine;

  final Map<IcomLanChannelRole, _ChannelRuntime> _channels = {
    IcomLanChannelRole.control: _ChannelRuntime(IcomLanChannelRole.control),
    IcomLanChannelRole.civ: _ChannelRuntime(IcomLanChannelRole.civ),
    IcomLanChannelRole.audio: _ChannelRuntime(IcomLanChannelRole.audio),
  };

  IcomLanSessionState _state = const IcomLanSessionState();
  @override
  IcomLanSessionState get state => _state;

  bool _closed = false;
  int _authInnerSequence = 0x30;
  int _localToken = 0;
  int _radioToken = 0;
  InternetAddress? _radioAddress;
  IcomLanConnectionInfo? _connectionAnnouncement;
  IcomLanRxAudioReceiver? _audioReceiver;
  DateTime? _lastTxFinishedAt;
  int _lastTxCompletedMonotonicMillis = 0;
  Completer<void>? _socketsOpenCompleter;
  bool _txCancelled = false;

  int _nextTxOuterSequence = 1;
  int _nextTxAudioSequence = 1;

  bool get isRunning => !_closed && _state.phase != IcomLanPhase.stopped;
  bool get isReceiving => _state.phase == IcomLanPhase.receiving;
  @override
  bool get isTransmitting => _pttStateMachine.isTransmitting;

  int? localIdFor(IcomLanChannelRole role) => _channels[role]?.localId;
  void Function(Uint8List pcm)? get onPcm => _callbacks.onPcm;

  void _log(String message) {
    _callbacks.onLog?.call(message);
  }

  @override
  Future<void> start() async {
    if (_closed) throw StateError('Session is closed');
    final err = config.validate();
    if (err != null) throw ArgumentError(err);
    _dispatch(const IcomLanStart());
    await _socketsOpenCompleter?.future;
  }

  @override
  void stop() {
    _dispatch(const IcomLanStop());
  }

  @override
  void close([void Function()? onClosed]) {
    if (_closed) {
      onClosed?.call();
      return;
    }
    _closed = true;
    _taskRegistry.cancelAll();
    _pttStateMachine.shutdown();
    _closeSockets().then((_) {
      onClosed?.call();
    });
  }

  void _dispatch(IcomLanEvent event) {
    final transition = IcomLanSessionEngine.reduce(_state, event);
    final previous = _state;
    _state = transition.state;

    if (previous.phase != _state.phase ||
        previous.failureReason != _state.failureReason) {
      _log('Phase ${previous.phase.name} -> ${_state.phase.name}'
          '${_state.failureReason == null ? '' : ' (${_state.failureReason})'}');
      _callbacks.onStateChanged?.call(_state);
    }

    for (final action in transition.actions) {
      _execute(action);
    }
  }

  void _execute(IcomLanAction action) {
    switch (action) {
      case IcomLanOpenSockets():
        _openSockets();
      case IcomLanCloseSockets():
        _closeSockets();
      case IcomLanSendDiscovery():
        _startDiscovery();
      case IcomLanSendLogin():
        _sendLogin();
      case IcomLanSendTokenConfirmation(:final token):
        _sendTokenConfirmation(token);
      case IcomLanScheduleConnectionInfoSettle():
        _scheduleTimer(
          'conn_settle',
          Duration(milliseconds: _timing.connectionInfoSettleMillis),
          () {
            _dispatch(const IcomLanConnectionInfoSettleTimerFired());
          },
        );
      case IcomLanSendConnectionInfo():
        _sendConnectionInfo();
      case IcomLanScheduleConnectionInfoRetry():
        _scheduleTimer(
          'conn_retry',
          Duration(milliseconds: _timing.connectionInfoRetryMillis),
          () {
            _dispatch(const IcomLanConnectionInfoRetryTimerFired());
          },
        );
      case IcomLanCancelConnectionInfoTimers():
        _cancelTimer('conn_settle');
        _cancelTimer('conn_retry');
      case IcomLanSendOpenStreams(:final endpoints):
        _openStreams(endpoints);
      case IcomLanScheduleRetry(:final attempt, :final cooldown):
        final delayMillis =
            icomLanReconnectDelayMillis(_timing, attempt, cooldown);
        _scheduleTimer(
          'retry',
          Duration(milliseconds: delayMillis),
          () {
            _dispatch(const IcomLanRetryTimerFired());
          },
        );
      case IcomLanCancelRetryTimer():
        _cancelTimer('retry');
      case IcomLanNotifyAudioDiscontinuity():
        _callbacks.onAudioDiscontinuity
            ?.call('Audio stream lost or discontinued');
    }
  }

  Future<void> _openSockets() async {
    _socketsOpenCompleter = Completer<void>();
    try {
      final basePort = config.controlPort;
      for (final role in IcomLanChannelRole.values) {
        final runtime = _channels[role]!;
        final port = basePort + role.index;

        final socketFactory = _legacySocketFactory;
        if (socketFactory != null) {
          final datagramSocket = await socketFactory(port);
          final channel = _LegacyAdaptedChannel(
            role: role,
            socket: datagramSocket,
            onDatagram: (d) => _onDatagram(role, d),
            onError: (err) => _log('$role socket error: $err'),
          );
          await channel.open();
          runtime.channel = channel;
        } else {
          final channel = IcomLanUdpChannel(
            role: role,
            localAddress:
                IcomLanSocketAddress(InternetAddress.anyIPv4, port),
            onDatagram: (d) => _onDatagram(role, d),
            onError: (err) => _log('$role UDP channel error: $err'),
          );
          await channel.open();
          runtime.channel = channel;
        }
        runtime.localId = icomLanClientIdForEndpoint(
          localAddress: runtime.channel?.boundLocalAddress,
          localPort: runtime.channel?.localPort ?? port,
        );
      }

      // Initialize audio receiver for audio channel
      final audioRuntime = _channels[IcomLanChannelRole.audio]!;
      _ensureAudioReceiver(audioRuntime.localId);

      _dispatch(const IcomLanSocketsOpened());
      _socketsOpenCompleter?.complete();
    } catch (error) {
      _log('Failed to open sockets: $error');
      _socketsOpenCompleter?.completeError(error);
      _dispatch(IcomLanRecoverableFailure('Failed to open sockets: $error'));
    }
  }

  Future<void> _closeSockets() async {
    for (final runtime in _channels.values) {
      try {
        await runtime.channel?.close();
      } catch (_) {}
      runtime.channel = null;
      runtime.remoteId = null;
    }
  }

  void _startDiscovery() {
    final runtime = _channels[IcomLanChannelRole.control]!;
    _radioAddress = InternetAddress.tryParse(config.host) ??
        InternetAddress('127.0.0.1');

    final target = IcomLanSocketAddress(_radioAddress!, config.controlPort);
    runtime.channel?.setRemoteEndpoint(target, lockSource: false);

    void sendProbe() {
      if (_state.phase != IcomLanPhase.controlDiscovery) return;
      final probe = IcomLanControlCodec.encode(
        IcomLanControlPacket(
          type: IcomLanControlCodec.typeAreYouThere,
          sequence: 0,
          senderId: runtime.localId,
          receiverId: 0,
        ),
      );
      _sendUntracked(runtime, probe);
    }

    sendProbe();
    _schedulePeriodic(
      'discovery_control',
      Duration(milliseconds: _timing.discoveryPeriodMillis),
      sendProbe,
    );
  }

  void _openStreams(IcomLanStreamEndpoints endpoints) {
    final radioAddr = _radioAddress ??
        InternetAddress.tryParse(config.host) ??
        InternetAddress('127.0.0.1');
    final civRuntime = _channels[IcomLanChannelRole.civ]!;
    final audioRuntime = _channels[IcomLanChannelRole.audio]!;

    civRuntime.channel?.setRemoteEndpoint(
      IcomLanSocketAddress(radioAddr, endpoints.civPort),
      lockSource: false,
    );
    audioRuntime.channel?.setRemoteEndpoint(
      IcomLanSocketAddress(radioAddr, endpoints.audioPort),
      lockSource: false,
    );

    _ensureAudioReceiver(audioRuntime.localId, audioRuntime.remoteId);

    _startChannelDiscovery(IcomLanChannelRole.civ);
    _startChannelDiscovery(IcomLanChannelRole.audio);
  }

  void _startChannelDiscovery(IcomLanChannelRole role) {
    final runtime = _channels[role]!;
    void sendProbe() {
      if (runtime.remoteId != null) return;
      final probe = IcomLanControlCodec.encode(
        IcomLanControlPacket(
          type: IcomLanControlCodec.typeAreYouThere,
          sequence: 0,
          senderId: runtime.localId,
          receiverId: 0,
        ),
      );
      _sendUntracked(runtime, probe);
    }

    sendProbe();
    _schedulePeriodic(
      'discovery_${role.name}',
      Duration(milliseconds: _timing.discoveryPeriodMillis),
      sendProbe,
    );
  }

  void _ensureAudioReceiver(int localId, [int? radioId]) {
    _audioReceiver ??= IcomLanRxAudioReceiver(
      localId: localId,
      radioId: radioId,
      sink: _AudioPcmSink(
        onSamples: (samples) {
          final pcmBytes = encodePcm16LittleEndian(samples);
          _callbacks.onPcm?.call(pcmBytes);
        },
      ),
      onDiscontinuity: (disc) {
        _callbacks.onAudioDiscontinuity
            ?.call('Audio gap: ${disc.missingPacketCount} packets');
      },
    );
  }

  void _onDatagram(IcomLanChannelRole role, IcomLanReceivedDatagram datagram) {
    final runtime = _channels[role]!;
    runtime.lastReceived = DateTime.now();

    final data = datagram.data;
    if (data.length < kIcomLanBaseHeaderSize) return;

    if (data.length == IcomLanControlCodec.packetSize) {
      _onControlPacket(runtime, data, datagram.source);
    } else if (role == IcomLanChannelRole.control &&
        kIcomLanAuthenticatedPacketSizes.contains(data.length)) {
      _onControlSessionPacket(data);
    } else if (isIcomLanVariableRetransmit(data)) {
      _handleRetransmit(runtime, data);
    } else if (data.length == IcomLanHandshakeCodec.pingPacketSize) {
      _handlePing(runtime, data);
    } else if (role == IcomLanChannelRole.civ &&
        data.length > IcomLanCivDatagramCodec.headerSize &&
        data[0x10] == IcomLanCivDatagramCodec.civMarker) {
      _onCivDatagram(data);
    } else if (role == IcomLanChannelRole.audio &&
        data.length > IcomLanAudioCodec.headerSize) {
      _onAudioDatagram(data);
    }
  }

  void _onControlPacket(
    _ChannelRuntime runtime,
    Uint8List data,
    IcomLanSocketAddress source,
  ) {
    final packet = IcomLanControlCodec.decode(
      data,
      expectedReceiverId: runtime.localId,
    );
    switch (packet.type) {
      case IcomLanControlCodec.typeRetransmit:
        _handleRetransmit(runtime, data);
      case IcomLanControlCodec.typeIAmHere:
        _onChannelDiscovered(runtime, packet.senderId, source);
      case IcomLanControlCodec.typeReady:
        _onChannelReady(runtime);
      case IcomLanControlCodec.typeAreYouThere:
        _sendUntracked(
          runtime,
          IcomLanControlCodec.encode(
            IcomLanControlPacket(
              type: IcomLanControlCodec.typeIAmHere,
              sequence: 0,
              senderId: runtime.localId,
              receiverId: packet.senderId,
            ),
          ),
        );
    }
  }

  void _onChannelDiscovered(
    _ChannelRuntime runtime,
    int remoteId,
    IcomLanSocketAddress source,
  ) {
    _cancelTimer('discovery_${runtime.role.name}');
    runtime.remoteId = remoteId;
    runtime.channel?.setRemoteEndpoint(source, lockSource: true);
    if (runtime.role == IcomLanChannelRole.control) {
      _radioAddress = source.address;
    }
    _sendUntracked(
      runtime,
      IcomLanControlCodec.encode(
        IcomLanControlPacket(
          type: IcomLanControlCodec.typeReady,
          sequence: 1,
          senderId: runtime.localId,
          receiverId: remoteId,
        ),
      ),
    );
    _startPing(runtime, immediate: true);
    if (runtime.role == IcomLanChannelRole.control) {
      _dispatch(const IcomLanControlDiscovered());
    } else if (runtime.role == IcomLanChannelRole.audio) {
      _ensureAudioReceiver(runtime.localId, remoteId);
    }
  }

  void _onChannelReady(_ChannelRuntime runtime) {
    switch (runtime.role) {
      case IcomLanChannelRole.control:
        _dispatch(const IcomLanControlReady());
      case IcomLanChannelRole.civ:
        _sendTracked(
          runtime,
          IcomLanHandshakeCodec.encodeCivOpenClose(
            IcomLanCivOpenClosePacket(
              sequence: 0,
              senderId: runtime.localId,
              receiverId: runtime.remoteId ?? 0,
              civSequence: _nextCivSequence(runtime),
              action: IcomLanCivChannelAction.open,
            ),
          ),
        );
        _dispatch(const IcomLanCivReady());
      case IcomLanChannelRole.audio:
        _dispatch(const IcomLanAudioReady());
    }
  }

  void _onControlSessionPacket(Uint8List data) {
    final control = _channels[IcomLanChannelRole.control]!;
    if (data.length == IcomLanHandshakeCodec.loginResponsePacketSize) {
      try {
        final response = IcomLanHandshakeCodec.decodeLoginResponse(
          data,
          expectedReceiverId: control.localId,
        );
        if (response.isAuthenticated) {
          _radioToken = response.header.token;
          _dispatch(IcomLanLoginAccepted(_radioToken));
        } else {
          _dispatch(const IcomLanLoginRejected('电台拒绝认证（用户名或密码错误）'));
        }
      } catch (e) {
        _log('Decode login response failed: $e');
      }
      return;
    }

    if (data.length == IcomLanConnectionInfoCodec.packetSize) {
      try {
        final announcement = IcomLanConnectionInfoCodec.decodeAnnouncement(
          data,
          expectedReceiverId: control.localId,
        );
        if (!announcement.isBusy) {
          _connectionAnnouncement = announcement;
          control.remoteId = announcement.header.senderId;
          _localToken = announcement.header.tokenRequest;
          _radioToken = announcement.header.token;
          _dispatch(const IcomLanConnectionInfoReceived());
          if (!_state.connectionRequestAuthorized) {
            _dispatch(const IcomLanConnectionRequestAuthorized());
          }
        } else if (_state.connectionInfoSent &&
            announcement.busyClientName == config.clientName) {
          final endpoints = IcomLanStreamEndpoints(
            civPort: config.controlPort + 1,
            audioPort: config.controlPort + 2,
          );
          _dispatch(IcomLanStatusEndpointsReceived(endpoints));
        }
      } catch (e) {
        _log('Decode connection info failed: $e');
      }
      return;
    }

    if (data.length == IcomLanHandshakeCodec.statusPacketSize) {
      try {
        final status = IcomLanHandshakeCodec.decodeStatusPacket(
          data,
          expectedReceiverId: control.localId,
        );
        if (status.errorCode == 0 &&
            status.civPort != 0 &&
            status.audioPort != 0) {
          _dispatch(IcomLanStatusEndpointsReceived(
            IcomLanStreamEndpoints(
              civPort: status.civPort,
              audioPort: status.audioPort,
            ),
          ));
        } else {
          _dispatch(IcomLanStatusNotReady(
            errorCode: status.errorCode,
            disconnectFlag: status.disconnectFlag,
          ));
        }
      } catch (e) {
        _log('Decode status packet failed: $e');
      }
      return;
    }
  }

  void _onCivDatagram(Uint8List data) {
    final civ = _channels[IcomLanChannelRole.civ]!;
    try {
      final datagram = IcomLanCivDatagramCodec.decode(data);
      civ.remoteId ??= datagram.senderId;
      _pttStateMachine.onCivReceived(datagram.civFrame);
    } catch (e) {
      _log('CI-V datagram decode error: $e');
    }
  }

  void _onAudioDatagram(Uint8List data) {
    final audio = _channels[IcomLanChannelRole.audio]!;
    try {
      if (audio.remoteId == null && data.length >= 0x10) {
        audio.remoteId = IcomLanBytes.readInt32Le(data, 0x08);
      }
      _audioReceiver?.accept(data);
      if (!_state.firstAudioSeen) {
        _dispatch(const IcomLanFirstAudio());
      }
    } catch (e) {
      _log('Audio accept error: $e');
    }
  }

  void _handlePing(_ChannelRuntime runtime, Uint8List data) {
    try {
      final ping = IcomLanHandshakeCodec.decodePing(
        data,
        expectedReceiverId: runtime.localId,
      );
      if (ping.isReply) {
        if (ping.sequence == runtime.pingSequence) {
          runtime.pingSequence = (runtime.pingSequence + 1) & 0xffff;
        }
      } else {
        _sendUntracked(
          runtime,
          IcomLanHandshakeCodec.encodePing(
            IcomLanPingPacket(
              sequence: ping.sequence,
              senderId: runtime.localId,
              receiverId: ping.senderId,
              isReply: true,
              timestampBits: ping.timestampBits,
            ),
          ),
        );
      }
    } catch (_) {}
  }

  void _startPing(_ChannelRuntime runtime, {bool immediate = false}) {
    _schedulePeriodic(
      'ping_${runtime.role.name}',
      Duration(milliseconds: _timing.pingPeriodMillis),
      () {
        if (runtime.channel == null || runtime.remoteId == null) return;
        final ping = IcomLanHandshakeCodec.encodePing(
          IcomLanPingPacket(
            sequence: runtime.pingSequence++,
            senderId: runtime.localId,
            receiverId: runtime.remoteId!,
            isReply: false,
            timestampBits: DateTime.now().millisecondsSinceEpoch & 0xffffffff,
          ),
        );
        _sendUntracked(runtime, ping);
      },
      immediate: immediate,
    );
  }

  void _sendLogin() {
    final control = _channels[IcomLanChannelRole.control]!;
    final remoteId = control.remoteId ?? 0;
    _localToken = _random.nextInt(0x7fffffff);

    final request = IcomLanHandshakeCodec.encodeLoginRequest(
      sequence: 0,
      senderId: control.localId,
      receiverId: remoteId,
      innerSequence: _nextAuthInnerSequence(),
      tokenRequest: 0,
      token: _localToken,
      username: config.username,
      password: config.password,
      clientName: config.clientName,
    );
    _sendTracked(control, request);
  }

  void _sendTokenConfirmation(int token) {
    final control = _channels[IcomLanChannelRole.control]!;
    final remoteId = control.remoteId ?? 0;

    final confirm = IcomLanHandshakeCodec.encodeTokenConfirm(
      sequence: 0,
      senderId: control.localId,
      receiverId: remoteId,
      innerSequence: _nextAuthInnerSequence(),
      tokenRequest: 0,
      token: token,
    );
    _sendUntracked(control, confirm);
  }

  void _sendConnectionInfo() {
    final control = _channels[IcomLanChannelRole.control]!;
    final remoteId = control.remoteId ?? 0;
    final civ = _channels[IcomLanChannelRole.civ]!;
    final audio = _channels[IcomLanChannelRole.audio]!;

    final request = IcomLanConnectionInfoCodec.encodeParameters(
      IcomLanConnectionParameters(
        sequence: 0,
        senderId: control.localId,
        receiverId: remoteId,
        innerSequence: _nextAuthInnerSequence(),
        tokenRequest: _localToken,
        token: _radioToken,
        radioIdentityBlock: _connectionAnnouncement?.radioIdentityBlock ??
            IcomLanConnectionInfoCodec.initialClientIdentityBlock(),
        radioName: _connectionAnnouncement?.radioName ?? 'IC-705',
        username: config.username,
        localCivPort: civ.channel?.localPort ?? (config.controlPort + 1),
        localAudioPort:
            audio.channel?.localPort ?? (config.controlPort + 2),
      ),
    );
    _sendTracked(control, request);
  }

  void _handleRetransmit(_ChannelRuntime runtime, Uint8List data) {
    try {
      final sequences = IcomLanControlCodec.decodeRetransmitRequest(
        data,
        expectedReceiverId: runtime.localId,
      );
      for (final seq in sequences) {
        final stored = runtime.trackedPackets.find(seq);
        if (stored != null) {
          _sendUntracked(runtime, stored);
        } else {
          _sendUntracked(
            runtime,
            IcomLanControlCodec.encode(
              IcomLanControlPacket(
                type: IcomLanControlCodec.typeNull,
                sequence: seq,
                senderId: runtime.localId,
                receiverId: runtime.remoteId ?? 0,
              ),
            ),
          );
        }
      }
    } catch (err) {
      _log('Retransmit handling error: $err');
    }
  }

  void _sendTracked(_ChannelRuntime runtime, Uint8List template) {
    final tracked = runtime.trackedPackets.track(template);
    _sendUntracked(runtime, tracked.data);
  }

  void _sendUntracked(_ChannelRuntime runtime, Uint8List data) {
    try {
      runtime.channel?.send(data);
    } catch (error) {
      _log('${runtime.role.name} send error: $error');
    }
  }

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

  void _scheduleTimer(
    String key,
    Duration duration,
    void Function() action,
  ) {
    _taskRegistry.replace(
      key,
      IcomLanTimerTask(Timer(duration, action)),
    );
  }

  void _schedulePeriodic(
    String key,
    Duration period,
    void Function() action, {
    bool immediate = false,
  }) {
    if (immediate) action();
    _taskRegistry.replace(
      key,
      IcomLanTimerTask(Timer.periodic(period, (_) => action())),
    );
  }

  void _cancelTimer(String key) {
    _taskRegistry.cancel(key);
  }

  @override
  bool transmitAudio(Uint8List pcm) {
    if (!isReceiving || isTransmitting) return false;
    transmitPcm(pcm);
    return true;
  }

  /// 发送 PCM 音频并等待发射流程完成。
  Future<String?> transmitPcm(
    Uint8List pcm16le, {
    int sampleRate = IcomLanAudioCodec.sampleRateHz,
  }) async {
    if (!isReceiving) return 'IC-705 未就绪';
    final civRuntime = _channels[IcomLanChannelRole.civ];
    final audioRuntime = _channels[IcomLanChannelRole.audio];
    if (civRuntime?.channel == null || audioRuntime?.channel == null) {
      return 'IC-705 未连接';
    }
    final finishedAt = _lastTxFinishedAt;
    if (finishedAt != null &&
        DateTime.now().difference(finishedAt).inMilliseconds < 300) {
      return '上一次发射尚未冷却';
    }

    _txCancelled = false;
    final now = _monotonicMillis();
    final cooldownRemaining = 50 - (now - _lastTxCompletedMonotonicMillis);
    if (cooldownRemaining > 0) {
      await Future<void>.delayed(Duration(milliseconds: cooldownRemaining));
    }

    try {
      final started = _pttStateMachine.beginTransmission();
      if (!started) return 'PTT 状态机忙';
    } catch (e) {
      return 'PTT ON 失败：$e';
    }

    try {
      _pttStateMachine.onAudioStreamingStarted();
      final samples = decodePcm16LittleEndian(pcm16le);
      final packetizer = IcomLanTxAudioPacketizer(
        senderId: audioRuntime!.localId,
        receiverId: audioRuntime.remoteId ?? 0,
        initialOuterSequence: _nextTxOuterSequence,
        initialAudioSequence: _nextTxAudioSequence,
      );
      final datagrams =
          packetizer.packetize(samples, sampleRateHz: sampleRate);
      _nextTxOuterSequence = packetizer.outerSequence;
      _nextTxAudioSequence = packetizer.audioSequence;

      final stopwatch = Stopwatch()..start();
      var index = 0;
      for (final datagram in datagrams) {
        if (!_pttStateMachine.canStreamAudio || _txCancelled) break;
        final targetMillis = index *
                (IcomLanAudioCodec.samplesPerPacket * 1000 ~/ sampleRate) -
            60;
        final waitMillis = targetMillis - stopwatch.elapsedMilliseconds;
        if (waitMillis > 0) {
          await Future<void>.delayed(Duration(milliseconds: waitMillis));
        }
        audioRuntime.channel?.send(datagram);
        index++;
      }
      _pttStateMachine.onAudioStreamingFinished();
    } finally {
      _pttStateMachine.finishTransmission();
      _lastTxFinishedAt = DateTime.now();
      _lastTxCompletedMonotonicMillis = _monotonicMillis();
    }
    return null;
  }

  /// 取消当前正在进行的发射。
  void cancelTransmit() {
    _txCancelled = true;
    _pttStateMachine.forceRelease('发射已被取消');
  }

  /// 兼容旧版 play(pcm) 方法。
  void play(Uint8List pcm) => transmitAudio(pcm);
}

class _PttActionsImpl implements IcomLanPttActions {
  _PttActionsImpl(this._session);
  final IcomLanRxSession _session;

  @override
  void sendCivFrame(Uint8List frame) {
    final civ = _session._channels[IcomLanChannelRole.civ]!;
    final remoteId = civ.remoteId ?? 0;
    final envelope = IcomLanCivDatagramCodec.encode(
      IcomLanCivDatagram(
        type: 0,
        sequence: 0,
        senderId: civ.localId,
        receiverId: remoteId,
        civSequence: _session._nextCivSequence(civ),
        civFrame: frame,
      ),
    );
    _session._sendTracked(civ, envelope);
  }

  @override
  void sendAudioDatagram(Uint8List datagram) {
    final audio = _session._channels[IcomLanChannelRole.audio]!;
    audio.channel?.send(datagram);
  }

  @override
  void onStateChanged(IcomLanPttState state) {
    _session._log('PTT state changed to ${state.name}');
  }
}

/// 将旧版 [IcomLanDatagramSocket] 适配为 [IcomLanDatagramChannel]。
class _LegacyAdaptedChannel implements IcomLanDatagramChannel {
  _LegacyAdaptedChannel({
    required this.role,
    required this.socket,
    required this.onDatagram,
    this.onError,
  });

  @override
  final IcomLanChannelRole role;
  final IcomLanDatagramSocket socket;
  final void Function(IcomLanReceivedDatagram datagram) onDatagram;
  final void Function(Object error)? onError;

  IcomLanSocketAddress? _configuredRemoteEndpoint;
  bool _remoteSourceLocked = false;
  bool _open = false;

  @override
  bool get isOpen => _open;

  @override
  int get localPort => socket.localPort;

  @override
  InternetAddress? get boundLocalAddress => null;

  @override
  IcomLanSocketAddress? get remoteEndpoint => _configuredRemoteEndpoint;

  @override
  Future<void> open() async {
    _open = true;
    socket.onDatagram = (datagram) {
      if (!_open) return;
      final expected = _configuredRemoteEndpoint;
      if (expected != null && _remoteSourceLocked) {
        if (datagram.address != expected.address ||
            datagram.port != expected.port) {
          return;
        }
      }
      onDatagram(IcomLanReceivedDatagram(
        data: datagram.data,
        source: IcomLanSocketAddress(datagram.address, datagram.port),
      ));
    };
    socket.onError = (err) => onError?.call(err);
  }

  @override
  void setRemoteEndpoint(
    IcomLanSocketAddress? endpoint, {
    bool lockSource = true,
  }) {
    _configuredRemoteEndpoint = endpoint;
    _remoteSourceLocked = endpoint != null && lockSource;
  }

  @override
  void send(Uint8List data) {
    final target = _configuredRemoteEndpoint;
    if (target == null) throw StateError('Remote endpoint not configured');
    socket.send(data, target.address, target.port);
  }

  @override
  Future<void> close() async {
    _open = false;
    socket.close();
  }
}
