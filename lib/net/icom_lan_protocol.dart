/// Icom 局域网（IC-705 / IC-9700 / IC-7610 等 RS-BA1 OEM）协议编解码层。
///
/// 本文件**只做字节编解码，不做任何 I/O**：UDP 收发在 `icom_lan_session.dart`，
/// 音频链路适配在 `icom_lan.dart`。这样协议层可以完全用单元测试覆盖
/// （`test/icom_lan_protocol_test.dart`），不需要电台、不需要网络。
///
/// 字节序：该协议的同一包里**大小端混用**（长度/序号小端，能力值/端口大端），
/// 所以所有读写都带显式 `Le`/`Be` 后缀 —— 不靠记忆猜。
///
/// 来源：Icom RS-BA1/OEM 协议（公开协议资料 + 实测抓包）；实现为独立编写，
/// 参见仓库 `LICENSING.md` / `PROVENANCE.md`。
library;

import 'dart:typed_data';

/// 报文与协议约定不符时抛出。
class IcomLanProtocolException implements Exception {
  IcomLanProtocolException(this.message);

  final String message;

  @override
  String toString() => 'IcomLanProtocolException: $message';
}

/// 基础头部长度：所有 Icom LAN 控制类报文都以这 16 字节开头。
const int kIcomLanBaseHeaderSize = 0x10;

/// 混合字节序读写helper。
///
/// 每个方法都先做边界检查并给出可读错误 —— 收到畸形 UDP 包时能直接定位
/// 是「包太短」还是「字段越界」，而不是抛一个裸的 RangeError。
class IcomLanBytes {
  IcomLanBytes._();

  static void _require(Uint8List data, int offset, int width, String what) {
    if (offset < 0 || offset + width > data.length) {
      throw IcomLanProtocolException(
          '$what: need $width byte(s) at offset 0x${offset.toRadixString(16)}, '
          'but frame is ${data.length} byte(s)');
    }
  }

  static int readUInt16Le(Uint8List d, int off) {
    _require(d, off, 2, 'readUInt16Le');
    return d[off] | (d[off + 1] << 8);
  }

  static int readUInt16Be(Uint8List d, int off) {
    _require(d, off, 2, 'readUInt16Be');
    return (d[off] << 8) | d[off + 1];
  }

  static int readInt32Le(Uint8List d, int off) {
    _require(d, off, 4, 'readInt32Le');
    final v = d[off] |
        (d[off + 1] << 8) |
        (d[off + 2] << 16) |
        (d[off + 3] << 24);
    return v & 0xffffffff;
  }

  static int readInt32Be(Uint8List d, int off) {
    _require(d, off, 4, 'readInt32Be');
    final v = (d[off] << 24) |
        (d[off + 1] << 16) |
        (d[off + 2] << 8) |
        d[off + 3];
    return v & 0xffffffff;
  }

  static void writeUInt8(Uint8List d, int off, int value) {
    _requireUInt('value', value, 0xff);
    _require(d, off, 1, 'writeUInt8');
    d[off] = value;
  }

  static void writeUInt16Le(Uint8List d, int off, int value) {
    _requireUInt('value', value, 0xffff);
    _require(d, off, 2, 'writeUInt16Le');
    d[off] = value & 0xff;
    d[off + 1] = (value >> 8) & 0xff;
  }

  static void writeUInt16Be(Uint8List d, int off, int value) {
    _requireUInt('value', value, 0xffff);
    _require(d, off, 2, 'writeUInt16Be');
    d[off] = (value >> 8) & 0xff;
    d[off + 1] = value & 0xff;
  }

  static void writeInt32Le(Uint8List d, int off, int value) {
    _requireUInt('value', value, 0xffffffff);
    _require(d, off, 4, 'writeInt32Le');
    d[off] = value & 0xff;
    d[off + 1] = (value >> 8) & 0xff;
    d[off + 2] = (value >> 16) & 0xff;
    d[off + 3] = (value >> 24) & 0xff;
  }

  static void writeInt32Be(Uint8List d, int off, int value) {
    _requireUInt('value', value, 0xffffffff);
    _require(d, off, 4, 'writeInt32Be');
    d[off] = (value >> 24) & 0xff;
    d[off + 1] = (value >> 16) & 0xff;
    d[off + 2] = (value >> 8) & 0xff;
    d[off + 3] = value & 0xff;
  }

  static void _requireUInt(String field, int value, int max) {
    if (value < 0 || value > max) {
      throw IcomLanProtocolException(
          '$field must fit in an unsigned ${max == 0xff ? 8 : (max == 0xffff ? 16 : 32)}-bit value: $value');
    }
  }

  /// 校验 16 字节基础头部：声明长度必须等于实际长度。
  static void requireEnvelope(Uint8List data, int expectedSize,
      {int? expectedReceiverId, String what = 'packet'}) {
    if (data.length != expectedSize) {
      throw IcomLanProtocolException(
          '$what must be $expectedSize byte(s), got ${data.length}');
    }
    final declared = readInt32Le(data, 0x00);
    if (declared != expectedSize) {
      throw IcomLanProtocolException(
          '$what declares length $declared, expected $expectedSize');
    }
    validateReceiverId(readInt32Le(data, 0x0c), expectedReceiverId);
  }

  /// 接收方 ID 校验：非 null 时要求完全一致（丢弃发给别人的包）。
  static void validateReceiverId(int actual, int? expected) {
    if (expected != null && actual != expected) {
      throw IcomLanProtocolException(
          'Datagram receiver ID $actual does not match local ID $expected');
    }
  }
}

/// Icom 的 16 字节 `passCode` 替换表（用户名/密码在线路上的编码方式）。
class IcomLanPassCode {
  IcomLanPassCode._();

  static const int size = 16;

  /// 可打印字符替代表（原始表由协议规定，属事实性数据）。
  static const List<int> _printable = [
    0x47, 0x5d, 0x4c, 0x42, 0x66, 0x20, 0x23, 0x46, 0x4e, 0x57, //
    0x45, 0x3d, 0x67, 0x76, 0x60, 0x41, 0x62, 0x39, 0x59, 0x2d,
    0x68, 0x7e, 0x7c, 0x65, 0x7d, 0x49, 0x29, 0x72, 0x73, 0x78,
    0x21, 0x6e, 0x5a, 0x5e, 0x4a, 0x3e, 0x71, 0x2c, 0x2a, 0x54,
    0x3c, 0x3a, 0x63, 0x4f, 0x43, 0x75, 0x27, 0x79, 0x5b, 0x35,
    0x70, 0x48, 0x6b, 0x56, 0x6f, 0x34, 0x32, 0x6c, 0x30, 0x61,
    0x6d, 0x7b, 0x2f, 0x4b, 0x64, 0x38, 0x2b, 0x2e, 0x50, 0x40,
    0x3f, 0x55, 0x33, 0x37, 0x25, 0x77, 0x24, 0x26, 0x74, 0x6a,
    0x28, 0x53, 0x4d, 0x69, 0x22, 0x5c, 0x44, 0x31, 0x36, 0x58,
    0x3b, 0x7a, 0x51, 0x5f, 0x52,
  ];

  /// 把 [value]（US-ASCII，≤16 字节）编码成 16 字节 `passCode`。
  static Uint8List encode(String value) {
    final encoded = ascii(value, size, 'credential');
    final out = Uint8List(size);
    for (var i = 0; i < encoded.length; i++) {
      var tableIndex = (encoded[i] + i) & 0xff;
      if (tableIndex > 126) {
        tableIndex = 32 + tableIndex % 127;
      }
      out[i] = tableIndex < 32 ? 0 : _printable[tableIndex - 32];
    }
    return out;
  }

  /// 校验并返回 US-ASCII 字节（超过 [maxLength] 或含非 ASCII 时抛错）。
  static Uint8List ascii(String value, int maxLength, String fieldName) {
    for (final code in value.codeUnits) {
      if (code > 0x7f) {
        throw IcomLanProtocolException('$fieldName must contain US-ASCII only');
      }
    }
    if (value.length > maxLength) {
      throw IcomLanProtocolException(
          '$fieldName must be at most $maxLength bytes, got ${value.length}');
    }
    return Uint8List.fromList(value.codeUnits);
  }

  /// 从固定长度字段里解码 ASCII，遇 0 截断并去掉尾部空格。
  static String decodeAscii(Uint8List data, int offset, int length) {
    var end = offset + length;
    for (var i = offset; i < offset + length; i++) {
      if (data[i] == 0) {
        end = i;
        break;
      }
    }
    final text = String.fromCharCodes(data.sublist(offset, end));
    return text.replaceAll(RegExp(r'\s+$'), '');
  }
}

/// 认证类报文（登录 / 令牌 / 状态 / 连接信息）共用的头部字段。
class IcomLanAuthHeader {
  const IcomLanAuthHeader({
    required this.type,
    required this.sequence,
    required this.senderId,
    required this.receiverId,
    required this.requestReply,
    required this.requestType,
    required this.innerSequence,
    required this.tokenRequest,
    required this.token,
  });

  final int type;
  final int sequence;
  final int senderId;
  final int receiverId;
  final int requestReply;
  final int requestType;
  final int innerSequence;
  final int tokenRequest;
  final int token;
}

/// 写认证类报文的 0x20 字节混合字节序前缀（目标缓冲需已清零保留字段）。
void writeAuthHeader(Uint8List destination, int packetSize, IcomLanAuthHeader h) {
  if (destination.length != packetSize) {
    throw IcomLanProtocolException(
        'Destination size ${destination.length} does not match packet size $packetSize');
  }
  if (packetSize < 0x20) {
    throw IcomLanProtocolException('Authenticated packet must be at least 32 bytes');
  }
  writeBaseHeader(destination, packetSize,
      type: h.type,
      sequence: h.sequence,
      senderId: h.senderId,
      receiverId: h.receiverId);
  IcomLanBytes.writeUInt16Be(
      destination, 0x12, packetSize - kIcomLanBaseHeaderSize);
  IcomLanBytes.writeUInt8(destination, 0x14, h.requestReply);
  IcomLanBytes.writeUInt8(destination, 0x15, h.requestType);
  IcomLanBytes.writeUInt16Be(destination, 0x16, h.innerSequence);
  IcomLanBytes.writeUInt16Be(destination, 0x1a, h.tokenRequest);
  IcomLanBytes.writeInt32Be(destination, 0x1c, h.token);
}

/// 读认证类报文的 0x20 字节前缀。
IcomLanAuthHeader decodeAuthHeader(Uint8List data, int expectedPacketSize,
    {int? expectedReceiverId}) {
  if (expectedPacketSize < 0x20) {
    throw IcomLanProtocolException('Authenticated packet must be at least 32 bytes');
  }
  IcomLanBytes.requireEnvelope(data, expectedPacketSize,
      expectedReceiverId: expectedReceiverId, what: 'Authenticated packet');
  final payloadSize = IcomLanBytes.readUInt16Be(data, 0x12);
  final expectedPayload = expectedPacketSize - kIcomLanBaseHeaderSize;
  if (payloadSize != expectedPayload) {
    throw IcomLanProtocolException(
        'Authenticated packet payload declares $payloadSize bytes, expected $expectedPayload');
  }
  return IcomLanAuthHeader(
    type: IcomLanBytes.readUInt16Le(data, 0x04),
    sequence: IcomLanBytes.readUInt16Le(data, 0x06),
    senderId: IcomLanBytes.readInt32Le(data, 0x08),
    receiverId: IcomLanBytes.readInt32Le(data, 0x0c),
    requestReply: data[0x14],
    requestType: data[0x15],
    innerSequence: IcomLanBytes.readUInt16Be(data, 0x16),
    tokenRequest: IcomLanBytes.readUInt16Be(data, 0x1a),
    token: IcomLanBytes.readInt32Be(data, 0x1c),
  );
}

/// 写基础 16 字节头部（长度 / 类型 / 序号 / 双方 ID）。
void writeBaseHeader(
  Uint8List destination,
  int packetSize, {
  required int type,
  required int sequence,
  required int senderId,
  required int receiverId,
}) {
  if (destination.length != packetSize) {
    throw IcomLanProtocolException(
        'Destination size ${destination.length} does not match packet size $packetSize');
  }
  IcomLanBytes.writeInt32Le(destination, 0x00, packetSize);
  IcomLanBytes.writeUInt16Le(destination, 0x04, type);
  IcomLanBytes.writeUInt16Le(destination, 0x06, sequence);
  IcomLanBytes.writeInt32Le(destination, 0x08, senderId);
  IcomLanBytes.writeInt32Le(destination, 0x0c, receiverId);
}

/// 16 字节通用控制包（探测 / 心跳 / 重传请求 / 断开等）。
class IcomLanControlPacket {
  const IcomLanControlPacket({
    required this.type,
    required this.sequence,
    required this.senderId,
    required this.receiverId,
  });

  final int type;
  final int sequence;
  final int senderId;
  final int receiverId;

  bool addressedTo(int localId) => receiverId == localId;
}

/// 通用控制包编解码。
class IcomLanControlCodec {
  IcomLanControlCodec._();

  static const int packetSize = kIcomLanBaseHeaderSize;

  static const int typeNull = 0x00;
  static const int typeRetransmit = 0x01;
  static const int typeAreYouThere = 0x03;
  static const int typeIAmHere = 0x04;
  static const int typeDisconnect = 0x05;
  static const int typeReady = 0x06;
  static const int typePing = 0x07;

  static Uint8List encode(IcomLanControlPacket packet) {
    final out = Uint8List(packetSize);
    writeBaseHeader(out, packetSize,
        type: packet.type,
        sequence: packet.sequence,
        senderId: packet.senderId,
        receiverId: packet.receiverId);
    return out;
  }

  static IcomLanControlPacket decode(Uint8List data, {int? expectedReceiverId}) {
    IcomLanBytes.requireEnvelope(data, packetSize,
        expectedReceiverId: expectedReceiverId, what: 'Control packet');
    return IcomLanControlPacket(
      type: IcomLanBytes.readUInt16Le(data, 0x04),
      sequence: IcomLanBytes.readUInt16Le(data, 0x06),
      senderId: IcomLanBytes.readInt32Le(data, 0x08),
      receiverId: IcomLanBytes.readInt32Le(data, 0x0c),
    );
  }

  /// 解出重传请求里被点名的序号列表。
  ///
  /// 两种形态：恰好 16 字节 = 只有一个序号（在 0x06）；更长 = 头部后跟
  /// 一串 16 位小端序号。
  static List<int> decodeRetransmitRequest(Uint8List data,
      {int? expectedReceiverId}) {
    if (data.length < packetSize) {
      throw IcomLanProtocolException(
          'Retransmit request must be at least $packetSize byte(s), got ${data.length}');
    }
    final declared = IcomLanBytes.readInt32Le(data, 0x00);
    if (declared != data.length) {
      throw IcomLanProtocolException(
          'Retransmit request declares length $declared, actual length is ${data.length}');
    }
    final type = IcomLanBytes.readUInt16Le(data, 0x04);
    if (type != typeRetransmit) {
      throw IcomLanProtocolException(
          'Retransmit request type must be $typeRetransmit, got $type');
    }
    IcomLanBytes.validateReceiverId(
        IcomLanBytes.readInt32Le(data, 0x0c), expectedReceiverId);

    if (data.length == packetSize) {
      return [IcomLanBytes.readUInt16Le(data, 0x06)];
    }
    final sequenceBytes = data.length - packetSize;
    if (sequenceBytes.isOdd) {
      throw IcomLanProtocolException(
          'Retransmit sequence list must contain complete 16-bit values');
    }
    final sequences = <int>[];
    for (var offset = packetSize; offset < data.length; offset += 2) {
      sequences.add(IcomLanBytes.readUInt16Le(data, offset));
    }
    return sequences;
  }
}

/// 心跳包（type 0x07）。
class IcomLanPingPacket {
  const IcomLanPingPacket({
    required this.sequence,
    required this.senderId,
    required this.receiverId,
    required this.isReply,
    required this.timestampBits,
  });

  final int sequence;
  final int senderId;
  final int receiverId;
  final bool isReply;

  /// 发送方时间值的低 32 位；只原样回显，不解释其时钟含义。
  final int timestampBits;
}

/// CI-V 数据通道的开/关动作。
enum IcomLanCivChannelAction {
  close(0x00),
  open(0x04);

  const IcomLanCivChannelAction(this.wireValue);

  final int wireValue;
}

/// CI-V 通道开关包（type 0，0x16 字节）。
class IcomLanCivOpenClosePacket {
  const IcomLanCivOpenClosePacket({
    required this.sequence,
    required this.senderId,
    required this.receiverId,
    required this.civSequence,
    required this.action,
  });

  final int sequence;
  final int senderId;
  final int receiverId;
  final int civSequence;
  final IcomLanCivChannelAction action;
}

/// 登录/令牌/状态等认证报文的响应模型。
class IcomLanLoginResponse {
  const IcomLanLoginResponse({
    required this.header,
    required this.authStartId,
    required this.errorCode,
    required this.connectionName,
  });

  final IcomLanAuthHeader header;
  final int authStartId;
  final int errorCode;
  final String connectionName;

  bool get isAuthenticated => errorCode == 0;
}

/// 令牌确认/续期/删除的响应。
class IcomLanTokenPacket {
  const IcomLanTokenPacket({required this.header, required this.responseCode});

  final IcomLanAuthHeader header;
  final int responseCode;

  bool get isSuccessfulRenewal =>
      header.type == IcomLanHandshakeCodec.responseType &&
      header.requestReply == IcomLanHandshakeCodec.requestReplyResponse &&
      header.requestType == IcomLanHandshakeCodec.tokenRequestRenewal &&
      responseCode == 0;
}

/// 状态包（0x50）：认证结果 + 断开标志 + 两个流端口。
class IcomLanStatusPacket {
  const IcomLanStatusPacket({
    required this.header,
    required this.errorCode,
    required this.disconnectFlag,
    required this.civPort,
    required this.audioPort,
  });

  final IcomLanAuthHeader header;
  final int errorCode;
  final int disconnectFlag;
  final int civPort;
  final int audioPort;

  bool get isAuthenticated => errorCode == 0;
  bool get isConnected => disconnectFlag == 0;
}

/// 握手（探测 / 登录 / 令牌 / CI-V 通道开关）编解码。
///
/// 刻意不提供任何日志钩子：用户名与密码绝不能进诊断日志。
class IcomLanHandshakeCodec {
  IcomLanHandshakeCodec._();

  static const int pingPacketSize = 0x15;
  static const int civOpenClosePacketSize = 0x16;
  static const int tokenPacketSize = 0x40;
  static const int statusPacketSize = 0x50;
  static const int loginResponsePacketSize = 0x60;
  static const int loginRequestPacketSize = 0x80;

  static const int responseType = 0x01;
  static const int requestReplyRequest = 0x01;
  static const int requestReplyResponse = 0x02;

  static const int tokenRequestDelete = 0x01;
  static const int tokenRequestConfirm = 0x02;
  static const int tokenRequestDisconnect = 0x04;
  static const int tokenRequestRenewal = 0x05;

  static const int _pingType = 0x07;
  static const int _pingRequest = 0x00;
  static const int _pingReply = 0x01;
  static const int _civOpenCloseMarker = 0xc0;
  static const int _tokenResetCapabilityOffset = 0x24;
  static const int _tokenResetCapability = 0x0798;

  /// 探测/心跳包。
  static Uint8List encodePing(IcomLanPingPacket packet) {
    final out = Uint8List(pingPacketSize);
    writeBaseHeader(out, pingPacketSize,
        type: _pingType,
        sequence: packet.sequence,
        senderId: packet.senderId,
        receiverId: packet.receiverId);
    IcomLanBytes.writeUInt8(out, 0x10, packet.isReply ? _pingReply : _pingRequest);
    IcomLanBytes.writeInt32Le(out, 0x11, packet.timestampBits);
    return out;
  }

  static IcomLanPingPacket decodePing(Uint8List data, {int? expectedReceiverId}) {
    if (data.length != pingPacketSize) {
      throw IcomLanProtocolException(
          'Ping packet must be $pingPacketSize byte(s), got ${data.length}');
    }
    final declaredLength = IcomLanBytes.readInt32Le(data, 0x00);
    // 真机在长度字段填 0，部分客户端填 0x15，两者都要能收。
    if (declaredLength != 0 && declaredLength != pingPacketSize) {
      throw IcomLanProtocolException(
          'Ping packet declares length $declaredLength, expected 0 or $pingPacketSize');
    }
    IcomLanBytes.validateReceiverId(
        IcomLanBytes.readInt32Le(data, 0x0c), expectedReceiverId);
    final type = IcomLanBytes.readUInt16Le(data, 0x04);
    if (type != _pingType) {
      throw IcomLanProtocolException(
          'Ping packet type must be $_pingType, got $type');
    }
    final reply = data[0x10];
    if (reply != _pingRequest && reply != _pingReply) {
      throw IcomLanProtocolException(
          'Ping reply marker must be 0 or 1, got $reply');
    }
    return IcomLanPingPacket(
      sequence: IcomLanBytes.readUInt16Le(data, 0x06),
      senderId: IcomLanBytes.readInt32Le(data, 0x08),
      receiverId: IcomLanBytes.readInt32Le(data, 0x0c),
      isReply: reply == _pingReply,
      timestampBits: IcomLanBytes.readInt32Le(data, 0x11),
    );
  }

  /// CI-V 数据通道开/关。
  static Uint8List encodeCivOpenClose(IcomLanCivOpenClosePacket packet) {
    final out = Uint8List(civOpenClosePacketSize);
    writeBaseHeader(out, civOpenClosePacketSize,
        type: 0,
        sequence: packet.sequence,
        senderId: packet.senderId,
        receiverId: packet.receiverId);
    IcomLanBytes.writeUInt8(out, 0x10, _civOpenCloseMarker);
    // 内嵌负载长度是小端，而紧随其后的 CI-V 序号是大端。
    IcomLanBytes.writeUInt16Le(out, 0x11, 1);
    IcomLanBytes.writeUInt16Be(out, 0x13, packet.civSequence);
    IcomLanBytes.writeUInt8(out, 0x15, packet.action.wireValue);
    return out;
  }

  static IcomLanCivOpenClosePacket decodeCivOpenClose(Uint8List data,
      {int? expectedReceiverId}) {
    IcomLanBytes.requireEnvelope(data, civOpenClosePacketSize,
        expectedReceiverId: expectedReceiverId,
        what: 'CI-V open/close packet');
    final type = IcomLanBytes.readUInt16Le(data, 0x04);
    if (type != 0) {
      throw IcomLanProtocolException(
          'CI-V open/close packet type must be 0, got $type');
    }
    final marker = data[0x10];
    if (marker != _civOpenCloseMarker) {
      throw IcomLanProtocolException(
          'CI-V open/close marker must be 0xc0, got 0x${marker.toRadixString(16)}');
    }
    final payloadLength = IcomLanBytes.readUInt16Le(data, 0x11);
    if (payloadLength != 1) {
      throw IcomLanProtocolException(
          'CI-V open/close payload must be 1 byte, got $payloadLength');
    }
    final actionByte = data[0x15];
    IcomLanCivChannelAction? action;
    for (final candidate in IcomLanCivChannelAction.values) {
      if (candidate.wireValue == actionByte) {
        action = candidate;
        break;
      }
    }
    if (action == null) {
      throw IcomLanProtocolException(
          'Unknown CI-V open/close action 0x${actionByte.toRadixString(16)}');
    }
    return IcomLanCivOpenClosePacket(
      sequence: IcomLanBytes.readUInt16Le(data, 0x06),
      senderId: IcomLanBytes.readInt32Le(data, 0x08),
      receiverId: IcomLanBytes.readInt32Le(data, 0x0c),
      civSequence: IcomLanBytes.readUInt16Be(data, 0x13),
      action: action,
    );
  }

  /// 登录请求（0x80）。
  static Uint8List encodeLoginRequest({
    required int sequence,
    required int senderId,
    required int receiverId,
    required int innerSequence,
    required int tokenRequest,
    required int token,
    required String username,
    required String password,
    required String clientName,
  }) {
    final out = Uint8List(loginRequestPacketSize);
    writeAuthHeader(
      out,
      loginRequestPacketSize,
      IcomLanAuthHeader(
        type: 0,
        sequence: sequence,
        senderId: senderId,
        receiverId: receiverId,
        requestReply: requestReplyRequest,
        requestType: 0,
        innerSequence: innerSequence,
        tokenRequest: tokenRequest,
        token: token,
      ),
    );
    out.setRange(0x40, 0x50, IcomLanPassCode.encode(username));
    out.setRange(0x50, 0x60, IcomLanPassCode.encode(password));
    final name = IcomLanPassCode.ascii(clientName, IcomLanPassCode.size, 'clientName');
    out.setRange(0x60, 0x60 + name.length, name);
    return out;
  }

  static IcomLanLoginResponse decodeLoginResponse(Uint8List data,
      {int? expectedReceiverId}) {
    final header = decodeAuthHeader(data, loginResponsePacketSize,
        expectedReceiverId: expectedReceiverId);
    return IcomLanLoginResponse(
      header: header,
      authStartId: IcomLanBytes.readUInt16Be(data, 0x20),
      errorCode: IcomLanBytes.readInt32Le(data, 0x30),
      connectionName: IcomLanPassCode.decodeAscii(data, 0x40, IcomLanPassCode.size),
    );
  }

  static Uint8List encodeTokenConfirm({
    required int sequence,
    required int senderId,
    required int receiverId,
    required int innerSequence,
    required int tokenRequest,
    required int token,
  }) =>
      _encodeTokenRequest(
        sequence: sequence,
        senderId: senderId,
        receiverId: receiverId,
        requestType: tokenRequestConfirm,
        innerSequence: innerSequence,
        tokenRequest: tokenRequest,
        token: token,
      );

  static Uint8List encodeTokenRenewal({
    required int sequence,
    required int senderId,
    required int receiverId,
    required int innerSequence,
    required int tokenRequest,
    required int token,
  }) =>
      _encodeTokenRequest(
        sequence: sequence,
        senderId: senderId,
        receiverId: receiverId,
        requestType: tokenRequestRenewal,
        innerSequence: innerSequence,
        tokenRequest: tokenRequest,
        token: token,
      );

  static Uint8List encodeTokenDelete({
    required int sequence,
    required int senderId,
    required int receiverId,
    required int innerSequence,
    required int tokenRequest,
    required int token,
  }) =>
      _encodeTokenRequest(
        sequence: sequence,
        senderId: senderId,
        receiverId: receiverId,
        requestType: tokenRequestDelete,
        innerSequence: innerSequence,
        tokenRequest: tokenRequest,
        token: token,
      );

  static IcomLanTokenPacket decodeTokenPacket(Uint8List data,
      {int? expectedReceiverId}) {
    final header = decodeAuthHeader(data, tokenPacketSize,
        expectedReceiverId: expectedReceiverId);
    return IcomLanTokenPacket(
      header: header,
      responseCode: IcomLanBytes.readInt32Be(data, 0x30),
    );
  }

  static IcomLanStatusPacket decodeStatusPacket(Uint8List data,
      {int? expectedReceiverId}) {
    final header = decodeAuthHeader(data, statusPacketSize,
        expectedReceiverId: expectedReceiverId);
    return IcomLanStatusPacket(
      header: header,
      errorCode: IcomLanBytes.readInt32Le(data, 0x30),
      disconnectFlag: data[0x40],
      civPort: IcomLanBytes.readUInt16Be(data, 0x42),
      audioPort: IcomLanBytes.readUInt16Be(data, 0x46),
    );
  }

  static Uint8List _encodeTokenRequest({
    required int sequence,
    required int senderId,
    required int receiverId,
    required int requestType,
    required int innerSequence,
    required int tokenRequest,
    required int token,
  }) {
    final out = Uint8List(tokenPacketSize);
    writeAuthHeader(
      out,
      tokenPacketSize,
      IcomLanAuthHeader(
        type: 0,
        sequence: sequence,
        senderId: senderId,
        receiverId: receiverId,
        requestReply: requestReplyRequest,
        requestType: requestType,
        innerSequence: innerSequence,
        tokenRequest: tokenRequest,
        token: token,
      ),
    );
    // 确认/续期/删除请求都带这个能力标记（实测抓包）。
    IcomLanBytes.writeUInt16Be(out, _tokenResetCapabilityOffset, _tokenResetCapability);
    return out;
  }
}

/// 0x90 连接信息协商：客户端参数。
class IcomLanConnectionParameters {
  const IcomLanConnectionParameters({
    required this.sequence,
    required this.senderId,
    required this.receiverId,
    required this.innerSequence,
    required this.tokenRequest,
    required this.token,
    required this.radioIdentityBlock,
    required this.radioName,
    required this.username,
    required this.localCivPort,
    required this.localAudioPort,
    this.receiveEnabled = true,
    this.transmitEnabled = false,
    this.receiveSampleRateHz = IcomLanAudioCodec.sampleRateHz,
    this.transmitSampleRateHz = IcomLanAudioCodec.sampleRateHz,
    this.transmitBufferSamples = IcomLanConnectionInfoCodec.defaultTxBufferSamples,
  });

  final int sequence;
  final int senderId;
  final int receiverId;
  final int innerSequence;
  final int tokenRequest;
  final int token;
  final Uint8List radioIdentityBlock;
  final String radioName;
  final String username;
  final int localCivPort;
  final int localAudioPort;
  final bool receiveEnabled;
  final bool transmitEnabled;
  final int receiveSampleRateHz;
  final int transmitSampleRateHz;
  final int transmitBufferSamples;
}

/// 电台侧的 0x90 应答。
class IcomLanConnectionInfo {
  const IcomLanConnectionInfo({
    required this.header,
    required this.radioIdentityBlock,
    required this.radioName,
    required this.isBusy,
    required this.busyClientName,
  });

  final IcomLanAuthHeader header;
  final Uint8List radioIdentityBlock;
  final String radioName;
  final bool isBusy;

  /// 流被占用时，占用者的客户端名。
  final String? busyClientName;
}

/// 0x90 连接信息编解码。
class IcomLanConnectionInfoCodec {
  IcomLanConnectionInfoCodec._();

  static const int packetSize = 0x90;
  static const int identityBlockSize = 0x20;
  static const int radioNameSize = 0x20;
  static const int codecLpcmMono16Bit = 0x04;

  /// 48 kHz/12 kHz LPCM 会话中实测的发送缓冲样本数。
  static const int defaultTxBufferSamples = 0xf0;

  static const int _requestTypeConnection = 0x03;
  static const int _convertAudio = 0x01;

  /// 第一次发 0x90 时使用的身份占位块。
  static Uint8List initialClientIdentityBlock() {
    final out = Uint8List(identityBlockSize);
    out[0x06] = 0x10;
    out[0x07] = 0x80;
    return out;
  }

  /// 编码客户端半边的 0x90 请求。
  static Uint8List encodeParameters(IcomLanConnectionParameters p) {
    if (p.radioIdentityBlock.length != identityBlockSize) {
      throw IcomLanProtocolException(
          'radioIdentityBlock must be $identityBlockSize bytes');
    }
    if (p.localCivPort <= 0 || p.localCivPort > 0xffff) {
      throw IcomLanProtocolException('localCivPort must be a valid UDP port');
    }
    if (p.localAudioPort <= 0 || p.localAudioPort > 0xffff) {
      throw IcomLanProtocolException('localAudioPort must be a valid UDP port');
    }
    final out = Uint8List(packetSize);
    writeAuthHeader(
      out,
      packetSize,
      IcomLanAuthHeader(
        type: 0,
        sequence: p.sequence,
        senderId: p.senderId,
        receiverId: p.receiverId,
        requestReply: IcomLanHandshakeCodec.requestReplyRequest,
        requestType: _requestTypeConnection,
        innerSequence: p.innerSequence,
        tokenRequest: p.tokenRequest,
        token: p.token,
      ),
    );
    out.setRange(0x20, 0x40, p.radioIdentityBlock);
    final name = IcomLanPassCode.ascii(p.radioName, radioNameSize, 'radioName');
    out.setRange(0x40, 0x40 + name.length, name);
    out.setRange(0x60, 0x70, IcomLanPassCode.encode(p.username));
    out[0x70] = p.receiveEnabled ? 1 : 0;
    out[0x71] = p.transmitEnabled ? 1 : 0;
    out[0x72] = codecLpcmMono16Bit;
    out[0x73] = codecLpcmMono16Bit;
    IcomLanBytes.writeInt32Be(out, 0x74, p.receiveSampleRateHz);
    IcomLanBytes.writeInt32Be(out, 0x78, p.transmitSampleRateHz);
    IcomLanBytes.writeInt32Be(out, 0x7c, p.localCivPort);
    IcomLanBytes.writeInt32Be(out, 0x80, p.localAudioPort);
    IcomLanBytes.writeInt32Be(out, 0x84, p.transmitBufferSamples);
    out[0x88] = _convertAudio;
    return out;
  }

  /// 解析电台半边的 0x90 应答。
  static IcomLanConnectionInfo decodeAnnouncement(Uint8List data,
      {int? expectedReceiverId}) {
    final header = decodeAuthHeader(data, packetSize,
        expectedReceiverId: expectedReceiverId);
    final isBusy = data[0x60] != 0;
    return IcomLanConnectionInfo(
      header: header,
      radioIdentityBlock:
          Uint8List.fromList(data.sublist(0x20, 0x20 + identityBlockSize)),
      radioName: IcomLanPassCode.decodeAscii(data, 0x40, radioNameSize),
      isBusy: isBusy,
      busyClientName: isBusy
          ? IcomLanPassCode.decodeAscii(data, 0x64, radioNameSize)
          : null,
    );
  }
}

/// 音频包头部（0x18 字节）+ PCM 负载。
class IcomLanAudioHeader {
  const IcomLanAudioHeader({
    this.type = 0,
    required this.sequence,
    required this.senderId,
    required this.receiverId,
    required this.identity,
    required this.audioSequence,
    this.unused = 0,
    required this.payloadLength,
  });

  final int type;
  final int sequence;
  final int senderId;
  final int receiverId;
  final int identity;
  final int audioSequence;
  final int unused;
  final int payloadLength;

  int get packetLength => IcomLanAudioCodec.headerSize + payloadLength;
}

/// 音频包（含 PCM 负载）。
class IcomLanAudioPacket {
  const IcomLanAudioPacket({required this.header, required this.pcmPayload});

  final IcomLanAudioHeader header;
  final Uint8List pcmPayload;
}

/// Icom LAN 音频包编解码。
///
/// 负载是 **LPCM 单声道 16 位小端**；采样率在 0x90 协商里确定
/// （本实现请求 [sampleRateHz] = 12 kHz，与 AFSK1200 解调所需一致）。
class IcomLanAudioCodec {
  IcomLanAudioCodec._();

  static const int headerSize = 0x18;

  /// 请求的 LPCM 采样率（Hz）。
  static const int sampleRateHz = 12000;

  /// 每个音频包携带的样本数（0xf0 = 240）。
  static const int samplesPerPacket = 0xf0;

  /// 每样本字节数（16 位单声道）。
  static const int bytesPerSample = 2;

  /// 每个音频包的 PCM 字节数（480）。
  static const int bytesPerPacket = samplesPerPacket * bytesPerSample;

  /// 160 字节负载（0xa0）时使用的标识值（实测）。
  static const int identityFor160BytePayload = 0x8197;

  /// 其它负载长度使用的标识值。
  static const int identityForOtherPayloads = 0x8000;

  static int transmitIdentity(int payloadLength) =>
      payloadLength == 0xa0 ? identityFor160BytePayload : identityForOtherPayloads;

  /// 编码一个音频包。
  static Uint8List encode({
    required int sequence,
    required int senderId,
    required int receiverId,
    required int audioSequence,
    required Uint8List pcmPayload,
    int type = 0,
    int? identity,
    int unused = 0,
  }) {
    final header = IcomLanAudioHeader(
      type: type,
      sequence: sequence,
      senderId: senderId,
      receiverId: receiverId,
      identity: identity ?? transmitIdentity(pcmPayload.length),
      audioSequence: audioSequence,
      unused: unused,
      payloadLength: pcmPayload.length,
    );
    final out = Uint8List(header.packetLength);
    out.setRange(0, headerSize, encodeHeader(header));
    out.setRange(headerSize, header.packetLength, pcmPayload);
    return out;
  }

  static Uint8List encodeHeader(IcomLanAudioHeader header) {
    final out = Uint8List(headerSize);
    IcomLanBytes.writeInt32Le(out, 0x00, header.packetLength);
    IcomLanBytes.writeUInt16Le(out, 0x04, header.type);
    IcomLanBytes.writeUInt16Le(out, 0x06, header.sequence);
    IcomLanBytes.writeInt32Le(out, 0x08, header.senderId);
    IcomLanBytes.writeInt32Le(out, 0x0c, header.receiverId);
    IcomLanBytes.writeUInt16Be(out, 0x10, header.identity);
    IcomLanBytes.writeUInt16Be(out, 0x12, header.audioSequence);
    IcomLanBytes.writeUInt16Be(out, 0x14, header.unused);
    IcomLanBytes.writeUInt16Be(out, 0x16, header.payloadLength);
    return out;
  }

  /// 解出头部，并校验声明长度与实际报文长度一致。
  static IcomLanAudioHeader decodeHeader(Uint8List data,
      {int? expectedReceiverId}) {
    if (data.length < headerSize) {
      throw IcomLanProtocolException(
          'Audio datagram must contain a $headerSize-byte header, got ${data.length} byte(s)');
    }
    final declaredLength = IcomLanBytes.readInt32Le(data, 0x00);
    if (declaredLength != data.length) {
      throw IcomLanProtocolException(
          'Audio datagram declares length $declaredLength, actual length is ${data.length}');
    }
    final payloadLength = IcomLanBytes.readUInt16Be(data, 0x16);
    if (payloadLength != data.length - headerSize) {
      throw IcomLanProtocolException(
          'Audio payload declares $payloadLength bytes, actual payload is ${data.length - headerSize}');
    }
    final header = IcomLanAudioHeader(
      type: IcomLanBytes.readUInt16Le(data, 0x04),
      sequence: IcomLanBytes.readUInt16Le(data, 0x06),
      senderId: IcomLanBytes.readInt32Le(data, 0x08),
      receiverId: IcomLanBytes.readInt32Le(data, 0x0c),
      identity: IcomLanBytes.readUInt16Be(data, 0x10),
      audioSequence: IcomLanBytes.readUInt16Be(data, 0x12),
      unused: IcomLanBytes.readUInt16Be(data, 0x14),
      payloadLength: payloadLength,
    );
    IcomLanBytes.validateReceiverId(header.receiverId, expectedReceiverId);
    return header;
  }

  static IcomLanAudioPacket decode(Uint8List data, {int? expectedReceiverId}) {
    final header = decodeHeader(data, expectedReceiverId: expectedReceiverId);
    return IcomLanAudioPacket(
      header: header,
      pcmPayload: Uint8List.fromList(data.sublist(headerSize)),
    );
  }
}

/// CI-V 数据包（0x15 字节信封 + 一段 CI-V 帧）。
class IcomLanCivDatagram {
  const IcomLanCivDatagram({
    this.type = 0,
    required this.sequence,
    required this.senderId,
    required this.receiverId,
    required this.civSequence,
    required this.civFrame,
  });

  final int type;
  final int sequence;
  final int senderId;
  final int receiverId;
  final int civSequence;
  final Uint8List civFrame;
}

/// CI-V 信封编解码（紧跟在通用头部之后，标记 0xc1）。
class IcomLanCivDatagramCodec {
  IcomLanCivDatagramCodec._();

  static const int headerSize = 0x15;
  static const int civMarker = 0xc1;

  static Uint8List encode(IcomLanCivDatagram packet) {
    if (packet.civFrame.isEmpty) {
      throw IcomLanProtocolException('CI-V frame must not be empty');
    }
    final out = Uint8List(headerSize + packet.civFrame.length);
    IcomLanBytes.writeInt32Le(out, 0x00, out.length);
    IcomLanBytes.writeUInt16Le(out, 0x04, packet.type);
    IcomLanBytes.writeUInt16Le(out, 0x06, packet.sequence);
    IcomLanBytes.writeInt32Le(out, 0x08, packet.senderId);
    IcomLanBytes.writeInt32Le(out, 0x0c, packet.receiverId);
    IcomLanBytes.writeUInt8(out, 0x10, civMarker);
    IcomLanBytes.writeUInt16Le(out, 0x11, packet.civFrame.length);
    IcomLanBytes.writeUInt16Be(out, 0x13, packet.civSequence);
    out.setRange(headerSize, out.length, packet.civFrame);
    return out;
  }

  static IcomLanCivDatagram decode(Uint8List data, {int? expectedReceiverId}) {
    if (data.length <= headerSize) {
      throw IcomLanProtocolException(
          'CI-V datagram must contain a frame after its $headerSize-byte header');
    }
    final declaredLength = IcomLanBytes.readInt32Le(data, 0x00);
    if (declaredLength != data.length) {
      throw IcomLanProtocolException(
          'CI-V datagram declares length $declaredLength, actual length is ${data.length}');
    }
    final type = IcomLanBytes.readUInt16Le(data, 0x04);
    if (type == IcomLanControlCodec.typeRetransmit) {
      throw IcomLanProtocolException(
          'Retransmit request is not a CI-V data envelope');
    }
    if (data[0x10] != civMarker) {
      throw IcomLanProtocolException('CI-V datagram marker must be 0xc1');
    }
    final frameLength = IcomLanBytes.readUInt16Le(data, 0x11);
    if (frameLength != data.length - headerSize) {
      throw IcomLanProtocolException(
          'CI-V frame declares $frameLength bytes, actual frame is ${data.length - headerSize}');
    }
    final datagram = IcomLanCivDatagram(
      type: type,
      sequence: IcomLanBytes.readUInt16Le(data, 0x06),
      senderId: IcomLanBytes.readInt32Le(data, 0x08),
      receiverId: IcomLanBytes.readInt32Le(data, 0x0c),
      civSequence: IcomLanBytes.readUInt16Be(data, 0x13),
      civFrame: Uint8List.fromList(data.sublist(headerSize)),
    );
    IcomLanBytes.validateReceiverId(datagram.receiverId, expectedReceiverId);
    return datagram;
  }
}

/// 纯 CI-V 命令构造（不做任何 I/O）。
class IcomLanCivCommands {
  IcomLanCivCommands._();

  static const int defaultRadioAddress = 0xa4;
  static const int defaultControllerAddress = 0xe0;

  static const int _preamble = 0xfe;
  static const int _terminator = 0xfd;
  static const int _commandTransceiverStatus = 0x1c;
  static const int _subcommandPtt = 0x00;

  /// PTT 开关帧：`FE FE <radio> <controller> 1C 00 01/00 FD`。
  static Uint8List buildPttFrame({
    required bool pttOn,
    int radioAddress = defaultRadioAddress,
    int controllerAddress = defaultControllerAddress,
  }) =>
      Uint8List.fromList([
        _preamble,
        _preamble,
        radioAddress,
        controllerAddress,
        _commandTransceiverStatus,
        _subcommandPtt,
        pttOn ? 0x01 : 0x00,
        _terminator,
      ]);

  /// PTT 状态回读帧（`1C 00` 不带数据字节）。
  static Uint8List buildPttQueryFrame({
    int radioAddress = defaultRadioAddress,
    int controllerAddress = defaultControllerAddress,
  }) =>
      Uint8List.fromList([
        _preamble,
        _preamble,
        radioAddress,
        controllerAddress,
        _commandTransceiverStatus,
        _subcommandPtt,
        _terminator,
      ]);

  /// 电台回报的 CI-V 帧是否是「PTT 已回到接收」（1C 00 00）。
  static bool isPttOffReport(Uint8List civFrame) =>
      civFrame.length >= 7 &&
      civFrame[4] == _commandTransceiverStatus &&
      civFrame[5] == _subcommandPtt &&
      civFrame[6] == 0x00;
}
