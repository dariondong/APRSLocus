/// 报文体检（对应 mod 的 `session/Ic705PacketInspector.kt`）。
///
/// 用途：收到畸形包时，把"为什么被拒"整理成**不含凭据与 ID 数值**的元数据
/// （只有长度、类型、接收方归属类别），这样诊断日志可以放心导出。
library;

import 'dart:typed_data';

import 'icom_lan_protocol.dart';
import 'icom_lan_rx_session_types.dart';

/// 认证类报文的合法长度集合（令牌/状态/登录应答/连接信息）。
final Set<int> kIcomLanAuthenticatedPacketSizes = {
  IcomLanHandshakeCodec.tokenPacketSize,
  IcomLanHandshakeCodec.statusPacketSize,
  IcomLanHandshakeCodec.loginResponsePacketSize,
  IcomLanConnectionInfoCodec.packetSize,
};

/// 把畸形包整理成诊断元数据。
IcomLanPacketDiagnostic icomLanPacketDiagnostic(
    Uint8List data, int localId) {
  final declaredLength =
      data.length >= 4 ? IcomLanBytes.readInt32Le(data, 0) : null;
  final commonType =
      data.length >= 6 ? IcomLanBytes.readUInt16Le(data, 4) : null;
  final receiverKind = data.length < IcomLanControlCodec.packetSize
      ? IcomLanPacketReceiverKind.absent
      : switch (IcomLanBytes.readInt32Le(data, 0x0c)) {
          final id when id == localId => IcomLanPacketReceiverKind.local,
          0 => IcomLanPacketReceiverKind.zero,
          _ => IcomLanPacketReceiverKind.other,
        };
  final rejection = data.length < IcomLanControlCodec.packetSize
      ? IcomLanPacketRejectionKind.headerTooShort
      : declaredLength != data.length
          ? IcomLanPacketRejectionKind.declaredLengthMismatch
          : receiverKind == IcomLanPacketReceiverKind.zero
              ? IcomLanPacketRejectionKind.receiverZero
              : receiverKind == IcomLanPacketReceiverKind.other
                  ? IcomLanPacketRejectionKind.receiverOther
                  : IcomLanPacketRejectionKind.packetCodec;
  final hasAuthenticatedHeader =
      kIcomLanAuthenticatedPacketSizes.contains(data.length);
  return IcomLanPacketDiagnostic(
    length: data.length,
    declaredLength: declaredLength,
    commonType: commonType,
    receiverKind: receiverKind,
    payloadLength: hasAuthenticatedHeader
        ? IcomLanBytes.readUInt16Be(data, 0x12)
        : null,
    requestReply: hasAuthenticatedHeader ? data[0x14] : null,
    requestType: hasAuthenticatedHeader ? data[0x15] : null,
    rejection: rejection,
  );
}

/// 通用信封校验：长度字段必须等于实际长度，接收方 ID 必须是本通道。
void validateIcomLanCommonEnvelope(Uint8List data, int expectedReceiverId) {
  if (data.length < IcomLanControlCodec.packetSize) {
    throw IcomLanProtocolException('Datagram is shorter than the common Icom header');
  }
  final declaredLength = IcomLanBytes.readInt32Le(data, 0);
  if (declaredLength != data.length) {
    throw IcomLanProtocolException('Datagram length does not match its common header');
  }
  final receiverId = IcomLanBytes.readInt32Le(data, 0x0c);
  if (receiverId != expectedReceiverId) {
    throw IcomLanProtocolException('Datagram receiver ID does not match this channel');
  }
}

/// 是否是"变长重传请求"（长度 > 16、偶数、类型 0x01）。
bool isIcomLanVariableRetransmit(Uint8List data) =>
    data.length > IcomLanControlCodec.packetSize &&
    data.length % 2 == 0 &&
    IcomLanBytes.readUInt16Le(data, 0x04) == IcomLanControlCodec.typeRetransmit;

/// 是否是音频包（长度自洽、不是重传请求、负载长度字段自洽）。
bool looksLikeIcomLanAudio(Uint8List data) {
  try {
    return data.length > IcomLanAudioCodec.headerSize &&
        IcomLanBytes.readInt32Le(data, 0) == data.length &&
        IcomLanBytes.readUInt16Le(data, 0x04) !=
            IcomLanControlCodec.typeRetransmit &&
        IcomLanBytes.readUInt16Be(data, 0x16) ==
            data.length - IcomLanAudioCodec.headerSize;
  } catch (_) {
    return false;
  }
}
