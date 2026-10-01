// IC-705 / Icom LAN 会话运行时的端到端测试（假 UDP 套接字）
//
// 这里跑的是**完整握手链**：探测 → 发现 → 登录 → 令牌 → 连接信息 → 开流
// → 收音频 → 发射（PTT + 音频包）。全部用注入的假 socket 驱动，不需要电台、
// 不需要网络 —— 因此握手顺序、报文类型、寻址对象都可以被逐条断言。
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_protocol.dart';
import 'package:aprslocus/net/icom_lan_session.dart';
import 'package:aprslocus/net/icom_lan_session_engine.dart';

/// 记录所有发出的报文，并允许注入"电台发来的"报文。
class FakeSocket implements IcomLanDatagramSocket {
  FakeSocket(this.localPort);

  @override
  final int localPort;

  final List<Uint8List> sent = [];
  final List<String> targets = [];
  bool closed = false;

  @override
  void Function(IcomLanDatagram datagram)? onDatagram;

  @override
  void Function(Object error)? onError;

  @override
  void send(Uint8List data, InternetAddress to, int port) {
    sent.add(Uint8List.fromList(data));
    targets.add('${to.address}:$port');
  }

  @override
  void close() => closed = true;

  void deliver(Uint8List data) {
    onDatagram?.call(IcomLanDatagram(
        data, InternetAddress('192.168.1.143'), localPort == 50001 ? 50001 : localPort));
  }

  Iterable<Uint8List> ofType(int type) => sent.where((d) =>
      d.length >= 6 && IcomLanBytes.readUInt16Le(d, 0x04) == type);
}

const radioId = 0x188b4b42;

Uint8List helloPacket({
  required int type,
  required int senderId,
  required int receiverId,
  int sequence = 0,
}) =>
    IcomLanControlCodec.encode(IcomLanControlPacket(
      type: type,
      sequence: sequence,
      senderId: senderId,
      receiverId: receiverId,
    ));

Uint8List loginResponse({required int senderId, required int receiverId}) {
  final packet = Uint8List(IcomLanHandshakeCodec.loginResponsePacketSize);
  IcomLanBytes.writeInt32Le(packet, 0x00, packet.length);
  IcomLanBytes.writeUInt16Le(packet, 0x04, IcomLanHandshakeCodec.responseType);
  IcomLanBytes.writeUInt16Le(packet, 0x06, 0x1234);
  IcomLanBytes.writeInt32Le(packet, 0x08, senderId);
  IcomLanBytes.writeInt32Le(packet, 0x0c, receiverId);
  IcomLanBytes.writeUInt16Be(packet, 0x12, packet.length - 0x10);
  IcomLanBytes.writeUInt8(packet, 0x14, IcomLanHandshakeCodec.requestReplyResponse);
  IcomLanBytes.writeUInt16Be(packet, 0x16, 0x9abc);
  IcomLanBytes.writeUInt16Be(packet, 0x1a, 0x1357);
  IcomLanBytes.writeInt32Be(packet, 0x1c, 0x2468ace0);
  // errorCode（0x30）保持 0 → 认证成功。
  return packet;
}

/// 电台的 0x90 应答：`busy=false` 是「流可用并提供身份块」，
/// `busy=true` + 我们的客户端名是「我们自己刚申请的流」。
Uint8List connectionInfo({
  required int senderId,
  required int receiverId,
  required bool busy,
  String clientName = 'APRSLocus',
}) {
  final packet = Uint8List(IcomLanConnectionInfoCodec.packetSize);
  IcomLanBytes.writeInt32Le(packet, 0x00, packet.length);
  IcomLanBytes.writeUInt16Le(packet, 0x04, IcomLanHandshakeCodec.responseType);
  IcomLanBytes.writeUInt16Le(packet, 0x06, 0x26);
  IcomLanBytes.writeInt32Le(packet, 0x08, senderId);
  IcomLanBytes.writeInt32Le(packet, 0x0c, receiverId);
  IcomLanBytes.writeUInt16Be(packet, 0x12, packet.length - 0x10);
  IcomLanBytes.writeUInt8(packet, 0x14, IcomLanHandshakeCodec.requestReplyResponse);
  IcomLanBytes.writeUInt16Be(packet, 0x16, 0x001e);
  IcomLanBytes.writeUInt16Be(packet, 0x1a, 0x50ed);
  IcomLanBytes.writeInt32Be(packet, 0x1c, 0x606cd0a6);
  for (var i = 0; i < 0x20; i++) {
    packet[0x20 + i] = i;
  }
  final name = 'IC-705'.codeUnits;
  packet.setRange(0x40, 0x40 + name.length, name);
  if (busy) {
    packet[0x60] = 1;
    final client = clientName.codeUnits;
    packet.setRange(0x64, 0x64 + client.length, client);
  }
  return packet;
}

void main() {
  late Map<int, FakeSocket> sockets;
  late List<String> logs;
  late List<Uint8List> pcm;
  late List<String> discontinuities;
  late IcomLanSession session;

  Future<IcomLanDatagramSocket> factory(int port) async {
    final socket = FakeSocket(port);
    sockets[port] = socket;
    return socket;
  }

  Future<IcomLanSession> startSession({String clientName = 'APRSLocus'}) async {
    sockets = {};
    logs = [];
    pcm = [];
    discontinuities = [];
    session = IcomLanSession(
      config: IcomLanConfig(
        host: '192.168.1.143',
        username: 'ic705',
        password: 'secret',
        clientName: clientName,
      ),
      socketFactory: factory,
      callbacks: IcomLanCallbacks(
        onLog: logs.add,
        onPcm: pcm.add,
        onAudioDiscontinuity: discontinuities.add,
      ),
    );
    await session.start();
    return session;
  }

  /// 把控制通道推进到「已登录 + 已授权」。
  Future<void> driveToAuthorized() async {
    final control = sockets[50001]!;
    final controlId = session.localIdFor(IcomLanChannelRole.control)!;
    control.deliver(helloPacket(
        type: IcomLanControlCodec.typeIAmHere,
        senderId: radioId,
        receiverId: controlId));
    control.deliver(helloPacket(
        type: IcomLanControlCodec.typeReady,
        senderId: radioId,
        receiverId: controlId));
    control.deliver(loginResponse(senderId: radioId, receiverId: controlId));
    control.deliver(connectionInfo(
        senderId: radioId, receiverId: controlId, busy: false));
  }

  test('开三个 UDP 通道并向电台发探测包', () async {
    await startSession();
    expect(sockets.keys.toSet(), {50001, 50002, 50003});
    final control = sockets[50001]!;
    final probe = control.sent.first;
    expect(IcomLanBytes.readUInt16Le(probe, 0x04),
        IcomLanControlCodec.typeAreYouThere);
    expect(control.targets.first, '192.168.1.143:50001');
    expect(session.state.phase, IcomLanPhase.controlDiscovery);
  });

  test('发现电台后回 READY 并起心跳，收到 READY 后发登录', () async {
    await startSession();
    final control = sockets[50001]!;
    final controlId = session.localIdFor(IcomLanChannelRole.control)!;

    control.deliver(helloPacket(
        type: IcomLanControlCodec.typeIAmHere,
        senderId: radioId,
        receiverId: controlId));
    expect(control.ofType(IcomLanControlCodec.typeReady), isNotEmpty);
    expect(control.ofType(IcomLanControlCodec.typePing), isNotEmpty);
    expect(session.state.phase, IcomLanPhase.controlDiscovery);

    control.deliver(helloPacket(
        type: IcomLanControlCodec.typeReady,
        senderId: radioId,
        receiverId: controlId));
    expect(session.state.phase, IcomLanPhase.authenticating);
    final login = control.sent.last;
    expect(login.length, IcomLanHandshakeCodec.loginRequestPacketSize);
    expect(IcomLanBytes.readInt32Le(login, 0x0c), radioId);
  });

  test('登录成功后发令牌确认，认证被拒则进入失败态', () async {
    await startSession();
    final control = sockets[50001]!;
    final controlId = session.localIdFor(IcomLanChannelRole.control)!;
    control.deliver(helloPacket(
        type: IcomLanControlCodec.typeIAmHere,
        senderId: radioId,
        receiverId: controlId));
    control.deliver(helloPacket(
        type: IcomLanControlCodec.typeReady,
        senderId: radioId,
        receiverId: controlId));

    control.deliver(loginResponse(senderId: radioId, receiverId: controlId));
    expect(session.state.phase, IcomLanPhase.negotiating);
    final token = control.sent.last;
    expect(token.length, IcomLanHandshakeCodec.tokenPacketSize);
    expect(token[0x15], IcomLanHandshakeCodec.tokenRequestConfirm);

    // 认证失败：另一条会话（错误码非 0）。
    final rejected = loginResponse(senderId: radioId, receiverId: controlId);
    IcomLanBytes.writeInt32Le(rejected, 0x30, 1);
    final second = await startSession();
    final ctl = sockets[50001]!;
    final id = second.localIdFor(IcomLanChannelRole.control)!;
    ctl.deliver(helloPacket(
        type: IcomLanControlCodec.typeIAmHere, senderId: radioId, receiverId: id));
    ctl.deliver(helloPacket(
        type: IcomLanControlCodec.typeReady, senderId: radioId, receiverId: id));
    final bad = loginResponse(senderId: radioId, receiverId: id);
    IcomLanBytes.writeInt32Le(bad, 0x30, 1);
    ctl.deliver(bad);
    expect(second.state.phase, IcomLanPhase.failed);
    expect(second.state.failureReason, contains('拒绝'));
  });

  test('音频包按序交付，乱序先缓冲再补齐', () async {
    await startSession();
    final audio = sockets[50003]!;
    final audioId = session.localIdFor(IcomLanChannelRole.audio)!;

    Uint8List packet(int sequence) {
      final payload = Uint8List.fromList(List.generate(240, (i) => (i + sequence) & 0xff));
      return IcomLanAudioCodec.encode(
        sequence: sequence,
        senderId: radioId,
        receiverId: audioId,
        audioSequence: sequence,
        pcmPayload: payload,
      );
    }

    audio.deliver(packet(0));
    expect(pcm.length, 1);
    audio.deliver(packet(2));
    expect(pcm.length, 1, reason: '缺口未补齐前不应交付');
    audio.deliver(packet(1));
    expect(pcm.length, 3, reason: '补齐缺口后应连同缓冲一起按序交付');
    expect(discontinuities, isEmpty);
  });

  test('完整握手到 RECEIVING，然后发射（PTT ON → 音频 → PTT OFF）', () async {
    await startSession(clientName: 'APRSLocus');
    await driveToAuthorized();
    expect(session.state.phase, IcomLanPhase.negotiating);

    // 连接信息 settle 计时器到点后，客户端会发出 0x90 请求。
    await Future<void>.delayed(const Duration(milliseconds: 3400));
    final control = sockets[50001]!;
    final controlId = session.localIdFor(IcomLanChannelRole.control)!;
    final request = control.sent.lastWhere(
        (d) => d.length == IcomLanConnectionInfoCodec.packetSize);
    expect(IcomLanBytes.readInt32Be(request, 0x7c), 50002,
        reason: '0x90 里必须带上本机 CI-V 端口');
    expect(IcomLanBytes.readInt32Be(request, 0x80), 50003,
        reason: '0x90 里必须带上本机音频端口');

    // 电台把这条流标成"我们占用" → 端点确认 → 打开流。
    control.deliver(connectionInfo(
        senderId: radioId, receiverId: controlId, busy: true));
    expect(session.state.phase, IcomLanPhase.openingStreams);
    expect(sockets[50002]!.targets.last, '192.168.1.143:50002');
    expect(sockets[50003]!.targets.last, '192.168.1.143:50003');

    final civId = session.localIdFor(IcomLanChannelRole.civ)!;
    final audioId = session.localIdFor(IcomLanChannelRole.audio)!;
    sockets[50002]!.deliver(helloPacket(
        type: IcomLanControlCodec.typeIAmHere, senderId: radioId, receiverId: civId));
    sockets[50002]!.deliver(helloPacket(
        type: IcomLanControlCodec.typeReady, senderId: radioId, receiverId: civId));
    expect(session.state.phase, IcomLanPhase.openingStreams,
        reason: '音频流未就绪前不应进入 STREAMS_READY');
    sockets[50003]!.deliver(helloPacket(
        type: IcomLanControlCodec.typeIAmHere, senderId: radioId, receiverId: audioId));
    sockets[50003]!.deliver(helloPacket(
        type: IcomLanControlCodec.typeReady, senderId: radioId, receiverId: audioId));
    expect(session.state.phase, IcomLanPhase.streamsReady);

    // 第一段 PCM → RECEIVING。
    final pcmChunk = Uint8List.fromList(
        List.generate(IcomLanAudioCodec.bytesPerPacket, (i) => i & 0xff));
    sockets[50003]!.deliver(IcomLanAudioCodec.encode(
      sequence: 0,
      senderId: radioId,
      receiverId: audioId,
      audioSequence: 0,
      pcmPayload: pcmChunk,
    ));
    expect(session.state.phase, IcomLanPhase.receiving);

    // 发射：CI-V 通道应出现 PTT ON 帧，音频通道应出现音频包。
    final civBefore = sockets[50002]!.sent.length;
    final audioBefore = sockets[50003]!.sent.length;
    final error = await session.transmitPcm(pcmChunk);
    expect(error, isNull);

    final civFrames = sockets[50002]!.sent.sublist(civBefore);
    final pttFrames = civFrames
        .where((d) => d.length > 0x15 && d[0x10] == 0xc1)
        .map((d) => IcomLanCivDatagramCodec.decode(d).civFrame)
        .where((f) => f.length >= 7 && f[4] == 0x1c)
        .toList();
    expect(pttFrames.first[6], 0x01, reason: '第一条应是 PTT ON');
    expect(pttFrames.last[6], 0x00, reason: '最后一条应是 PTT OFF');

    // 音频通道上也有心跳（0x15 字节），按长度筛出真正的音频包。
    final audioPackets = sockets[50003]!
        .sent
        .sublist(audioBefore)
        .where((d) => d.length > IcomLanAudioCodec.headerSize)
        .toList();
    expect(audioPackets, isNotEmpty);
    final decoded = IcomLanAudioCodec.decode(audioPackets.first);
    expect(decoded.pcmPayload.length, IcomLanAudioCodec.bytesPerPacket);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('配置非法时拒绝启动', () async {
    sockets = {};
    final bad = IcomLanSession(
      config: const IcomLanConfig(host: '192.168.1.143', username: '', password: 'x'),
      socketFactory: factory,
    );
    await expectLater(bad.start(), throwsA(isA<ArgumentError>()));
  });
}
