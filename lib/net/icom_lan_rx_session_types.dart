/// IC-705 会话的类型层（对应 mod 的 `session/Ic705RxSessionTypes.kt`）。
///
/// 直译原则：**名字与结构一一对应**（`Ic705RxSessionTiming` →
/// [IcomLanRxSessionTiming] 等），这样日后跟 mod 双向同步时能一眼对上。
/// 唯一必要的平台适配：`radioAddress` 在 Kotlin 侧是 `InetAddress`，Dart 侧
/// 保存**主机字符串**，真正解析发生在绑定 socket 的那一步。
library;

import 'icom_lan_protocol.dart' show IcomLanCivCommands;

/// UDP 通道角色（对应 mod 的 `transport/Ic705ChannelRole`）。
enum IcomLanChannelRole { control, civ, audio }

/// 会话时序参数（默认值与 mod 完全一致）。
class IcomLanRxSessionTiming {
  IcomLanRxSessionTiming({
    this.discoveryPeriodMillis = 500,
    this.discoveryTimeoutMillis = 10000,
    this.pingPeriodMillis = 100,
    this.idleCheckPeriodMillis = 100,
    this.idleAfterMillis = 100,
    this.tokenRenewalMillis = 60000,
    this.watchdogPeriodMillis = 500,
    this.channelTimeoutMillis = 5000,
    this.civChannelTimeoutMillis = 3000,
    this.audioChannelTimeoutMillis = 30000,
    this.audioPostTxGraceMillis = 5000,
    this.streamRecoveryResponseMillis = 3000,
    this.streamRecoveryAttempts = 2,
    this.handshakeStageTimeoutMillis = 10000,
    this.negotiationTimeoutMillis = 45000,
    this.connectionInfoSettleMillis = 3000,
    this.connectionInfoRetryMillis = 10000,
    this.initialReconnectMillis = 1000,
    this.maximumReconnectMillis = 30000,
  }) {
    final values = <int>[
      discoveryPeriodMillis,
      discoveryTimeoutMillis,
      pingPeriodMillis,
      idleCheckPeriodMillis,
      idleAfterMillis,
      tokenRenewalMillis,
      watchdogPeriodMillis,
      channelTimeoutMillis,
      civChannelTimeoutMillis,
      audioChannelTimeoutMillis,
      audioPostTxGraceMillis,
      streamRecoveryResponseMillis,
      handshakeStageTimeoutMillis,
      negotiationTimeoutMillis,
      connectionInfoSettleMillis,
      connectionInfoRetryMillis,
      initialReconnectMillis,
      maximumReconnectMillis,
    ];
    if (values.any((v) => v <= 0)) {
      throw ArgumentError('IC-705 timing values must be positive');
    }
    if (streamRecoveryAttempts <= 0) {
      throw ArgumentError('streamRecoveryAttempts must be positive');
    }
    if (maximumReconnectMillis < initialReconnectMillis) {
      throw ArgumentError(
          'maximumReconnectMillis must be >= initialReconnectMillis');
    }
  }

  final int discoveryPeriodMillis;
  final int discoveryTimeoutMillis;

  /// RS-BA1 keeps every active LAN control channel at a 10 Hz cadence.
  final int pingPeriodMillis;
  final int idleCheckPeriodMillis;
  final int idleAfterMillis;
  final int tokenRenewalMillis;
  final int watchdogPeriodMillis;

  /// CONTROL is authoritative for whole-session liveness.
  final int channelTimeoutMillis;

  /// CI-V stays latency sensitive but is independent from RX audio silence.
  final int civChannelTimeoutMillis;

  /// RX audio may legitimately be silent for long stretches.
  final int audioChannelTimeoutMillis;

  /// Time for the radio to resume RX audio after PTT OFF is acknowledged.
  final int audioPostTxGraceMillis;

  /// How long a stream rediscovery attempt may wait for fresh traffic.
  final int streamRecoveryResponseMillis;

  /// Stream-local recovery attempts before escalating to a full reconnect.
  final int streamRecoveryAttempts;

  final int handshakeStageTimeoutMillis;
  final int negotiationTimeoutMillis;

  /// RS-BA1 waits about three seconds after login before claiming streams.
  final int connectionInfoSettleMillis;
  final int connectionInfoRetryMillis;
  final int initialReconnectMillis;
  final int maximumReconnectMillis;
}

/// 会话配置。凭据刻意不进 [toString]。
class IcomLanRxSessionConfig {
  IcomLanRxSessionConfig({
    required this.radioAddress,
    required this.controlPort,
    required this.username,
    required String password,
    this.clientName = 'APRSdroid',
    this.autoReconnect = true,
    IcomLanRxSessionTiming? timing,
    this.radioCivAddress = IcomLanCivCommands.defaultRadioAddress,
  })  : _password = password,
        timing = timing ?? IcomLanRxSessionTiming() {
    if (controlPort < 1 || controlPort > 0xffff) {
      throw ArgumentError('controlPort must be a valid UDP port');
    }
    if (radioCivAddress < 1 || radioCivAddress > 0xef) {
      throw ArgumentError(
          'radioCivAddress must be a valid CI-V address (0x01..0xEF)');
    }
    if (username.trim().isEmpty) {
      throw ArgumentError('username must not be blank');
    }
    if (username.length > 16) {
      throw ArgumentError('username must be at most 16 characters');
    }
    if (password.length > 16) {
      throw ArgumentError('password must be at most 16 characters');
    }
    if (clientName.trim().isEmpty) {
      throw ArgumentError('clientName must not be blank');
    }
    if (clientName.length > 16) {
      throw ArgumentError('clientName must be at most 16 characters');
    }
    if (!_isAscii(username)) {
      throw ArgumentError('username must contain US-ASCII only');
    }
    if (!_isAscii(password)) {
      throw ArgumentError('password must contain US-ASCII only');
    }
    if (!_isAscii(clientName)) {
      throw ArgumentError('clientName must contain US-ASCII only');
    }
  }

  final String radioAddress;
  final int controlPort;
  final String username;
  final String _password;
  final String clientName;
  final bool autoReconnect;
  final IcomLanRxSessionTiming timing;
  final int radioCivAddress;

  String passwordValue() => _password;

  static bool _isAscii(String value) =>
      value.codeUnits.every((code) => code <= 0x7f);

  @override
  String toString() =>
      'IcomLanRxSessionConfig(radioAddress=$radioAddress, controlPort=$controlPort, '
      'username=<redacted>, password=<redacted>, clientName=$clientName, '
      'autoReconnect=$autoReconnect, '
      'radioCivAddress=${radioCivAddress.toRadixString(16).toUpperCase()})';
}

/// 会话问题分类（对应 mod 的 `Ic705RxSessionIssueCode`）。
enum IcomLanRxSessionIssueCode {
  socketIo,
  malformedPacket,
  audioQueueOverflow,
}

/// 收到的包在"接收方 ID"上的归类（诊断用，不含任何 ID 数值）。
enum IcomLanPacketReceiverKind { local, zero, other, absent }

/// 包被拒的原因（诊断用）。
enum IcomLanPacketRejectionKind {
  headerTooShort,
  declaredLengthMismatch,
  receiverZero,
  receiverOther,
  packetCodec,
}

/// 凭据安全的包头元数据：只有长度与类型，绝不含负载字节或 ID 数值。
class IcomLanPacketDiagnostic {
  const IcomLanPacketDiagnostic({
    required this.length,
    this.declaredLength,
    this.commonType,
    required this.receiverKind,
    this.payloadLength,
    this.requestReply,
    this.requestType,
    required this.rejection,
  });

  final int length;
  final int? declaredLength;
  final int? commonType;
  final IcomLanPacketReceiverKind receiverKind;
  final int? payloadLength;
  final int? requestReply;
  final int? requestType;
  final IcomLanPacketRejectionKind rejection;
}

/// 会话问题事件。
class IcomLanRxSessionIssue {
  const IcomLanRxSessionIssue({
    required this.code,
    required this.channel,
    this.packet,
  });

  final IcomLanRxSessionIssueCode code;
  final IcomLanChannelRole? channel;
  final IcomLanPacketDiagnostic? packet;
}

/// 音频复位原因。
enum IcomLanAudioResetReason {
  udpDiscontinuity,
  sessionRestart,
  streamRecovery,
  audioQueueOverflow,
}

/// 音频复位事件（下游解调器据此复位）。
class IcomLanAudioReset {
  const IcomLanAudioReset(this.reason, {this.discontinuity});

  final IcomLanAudioResetReason reason;
  final Object? discontinuity;
}

/// 单条流软恢复的结果（用于上层日志/UI）。
enum IcomLanStreamRecoveryOutcome { started, succeeded, escalated }

/// 流软恢复事件。
class IcomLanStreamRecoveryEvent {
  const IcomLanStreamRecoveryEvent({
    required this.role,
    required this.outcome,
    required this.attempt,
    required this.ageMillis,
  });

  final IcomLanChannelRole role;
  final IcomLanStreamRecoveryOutcome outcome;
  final int attempt;
  final int ageMillis;
}
