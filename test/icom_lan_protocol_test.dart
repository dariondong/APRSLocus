// IC-705 / Icom LAN 协议层回归测试
//
// 这里的字节向量与协议实现一一对应：编码结果必须**逐字节**匹配
// （布局来自 Icom RS-BA1/OEM 协议资料与实测抓包），解码则必须能从同样的
// 字节里复原字段，并在长度/接收方 ID 不符时报错 —— 现场收到的畸形包
// 只有这两种失败模式。
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_protocol.dart';

Uint8List hexBytes(String text) {
  final cleaned = text.replaceAll(RegExp(r'[\s]+'), '');
  if (cleaned.length.isOdd) {
    throw ArgumentError('hex string must have an even length: $text');
  }
  final out = Uint8List(cleaned.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

void expectProtocolFailure(void Function() body) {
  expect(body, throwsA(isA<IcomLanProtocolException>()));
}

void main() {
  group('基础字节序 / passCode', () {
    test('passCode 与协议替代表逐字节一致', () {
      expect(
        IcomLanPassCode.encode('USER'),
        hexBytes('56 6b 54 56 00 00 00 00 00 00 00 00 00 00 00 00'),
      );
      expect(
        IcomLanPassCode.encode('PASS'),
        hexBytes('5b 4a 56 6f 00 00 00 00 00 00 00 00 00 00 00 00'),
      );
    });

    test('passCode 拒绝非 ASCII 与超长输入', () {
      expectProtocolFailure(() => IcomLanPassCode.encode('密码'));
      expectProtocolFailure(() => IcomLanPassCode.encode('12345678901234567'));
    });

    test('字节序读写是显式的（LE/BE 不混）', () {
      final buf = Uint8List(8);
      IcomLanBytes.writeUInt16Le(buf, 0, 0x1234);
      IcomLanBytes.writeUInt16Be(buf, 2, 0x1234);
      IcomLanBytes.writeInt32Le(buf, 4, 0x11223344);
      expect(buf.sublist(0, 4), hexBytes('34 12 12 34'));
      expect(IcomLanBytes.readUInt16Le(buf, 0), 0x1234);
      expect(IcomLanBytes.readUInt16Be(buf, 2), 0x1234);
      expect(IcomLanBytes.readInt32Le(buf, 4), 0x11223344);
    });

    test('越界读取给出可读错误', () {
      final buf = Uint8List(4);
      expectProtocolFailure(() => IcomLanBytes.readInt32Be(buf, 2));
    });
  });

  group('心跳（0x07）', () {
    final pingRequestGolden = hexBytes(
      '15 00 00 00 07 00 34 12 44 33 22 11 88 77 66 55 00 ef cd ab 89',
    );
    final pingReplyGolden = hexBytes(
      '15 00 00 00 07 00 34 12 88 77 66 55 44 33 22 11 01 ef cd ab 89',
    );

    test('编码/解码与协议布局一致', () {
      const request = IcomLanPingPacket(
        sequence: 0x1234,
        senderId: 0x11223344,
        receiverId: 0x55667788,
        isReply: false,
        timestampBits: 0x89abcdef,
      );
      const reply = IcomLanPingPacket(
        sequence: 0x1234,
        senderId: 0x55667788,
        receiverId: 0x11223344,
        isReply: true,
        timestampBits: 0x89abcdef,
      );

      expect(IcomLanHandshakeCodec.encodePing(request), pingRequestGolden);
      expect(IcomLanHandshakeCodec.encodePing(reply), pingReplyGolden);

      final decodedRequest = IcomLanHandshakeCodec.decodePing(pingRequestGolden,
          expectedReceiverId: 0x55667788);
      expect(decodedRequest.sequence, 0x1234);
      expect(decodedRequest.senderId, 0x11223344);
      expect(decodedRequest.receiverId, 0x55667788);
      expect(decodedRequest.isReply, isFalse);
      expect(decodedRequest.timestampBits, 0x89abcdef);

      final decodedReply = IcomLanHandshakeCodec.decodePing(pingReplyGolden,
          expectedReceiverId: 0x11223344);
      expect(decodedReply.isReply, isTrue);
    });

    test('真机把长度字段填 0 也要能收', () {
      final radioRequest = Uint8List.fromList(pingRequestGolden);
      for (var i = 0; i < 4; i++) {
        radioRequest[i] = 0;
      }
      final decoded = IcomLanHandshakeCodec.decodePing(radioRequest,
          expectedReceiverId: 0x55667788);
      expect(decoded.isReply, isFalse);
      expect(decoded.sequence, 0x1234);
      expect(decoded.timestampBits, 0x89abcdef);
    });

    test('长度错误或接收方 ID 不符时报错', () {
      final malformed = Uint8List.fromList(pingRequestGolden);
      malformed[0] = 0x14;
      expectProtocolFailure(() => IcomLanHandshakeCodec.decodePing(malformed));
      expectProtocolFailure(() => IcomLanHandshakeCodec.decodePing(
          pingRequestGolden,
          expectedReceiverId: 0x01020304));
    });
  });

  group('CI-V 通道开关（0x16）', () {
    test('开/关两个方向的字节布局', () {
      const open = IcomLanCivOpenClosePacket(
        sequence: 0x1234,
        senderId: 0x11223344,
        receiverId: 0x55667788,
        civSequence: 0x9abc,
        action: IcomLanCivChannelAction.open,
      );
      const close = IcomLanCivOpenClosePacket(
        sequence: 0x1234,
        senderId: 0x11223344,
        receiverId: 0x55667788,
        civSequence: 0x9abc,
        action: IcomLanCivChannelAction.close,
      );
      final openGolden = hexBytes(
        '16 00 00 00 00 00 34 12 44 33 22 11 88 77 66 55 c0 01 00 9a bc 04',
      );
      final closeGolden = hexBytes(
        '16 00 00 00 00 00 34 12 44 33 22 11 88 77 66 55 c0 01 00 9a bc 00',
      );

      expect(IcomLanHandshakeCodec.encodeCivOpenClose(open), openGolden);
      expect(IcomLanHandshakeCodec.encodeCivOpenClose(close), closeGolden);

      final decoded = IcomLanHandshakeCodec.decodeCivOpenClose(openGolden,
          expectedReceiverId: 0x55667788);
      expect(decoded.sequence, 0x1234);
      expect(decoded.civSequence, 0x9abc);
      expect(decoded.action, IcomLanCivChannelAction.open);
    });
  });

  group('登录 / 令牌 / 状态', () {
    test('登录请求逐字节匹配（含凭据编码与客户端名）', () {
      final golden = hexBytes(
        '80 00 00 00 00 00 34 12 44 33 22 11 88 77 66 55 '
        '00 00 00 70 01 00 9a bc 00 00 13 57 24 68 ac e0 '
        '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 '
        '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 '
        '56 6b 54 56 00 00 00 00 00 00 00 00 00 00 00 00 '
        '5b 4a 56 6f 00 00 00 00 00 00 00 00 00 00 00 00 '
        '41 50 52 53 64 72 6f 69 64 00 00 00 00 00 00 00 '
        '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00',
      );

      expect(
        IcomLanHandshakeCodec.encodeLoginRequest(
          sequence: 0x1234,
          senderId: 0x11223344,
          receiverId: 0x55667788,
          innerSequence: 0x9abc,
          tokenRequest: 0x1357,
          token: 0x2468ace0,
          username: 'USER',
          password: 'PASS',
          clientName: 'APRSdroid',
        ),
        golden,
      );
    });

    test('登录应答字段解析与接收方校验', () {
      final golden = hexBytes(
        '60 00 00 00 01 00 34 12 88 77 66 55 44 33 22 11 '
        '00 00 00 50 02 00 9a bc 00 00 13 57 24 68 ac e0 '
        'be ef 00 00 00 00 00 00 00 00 00 00 00 00 00 00 '
        '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 '
        '49 43 2d 37 30 35 00 00 00 00 00 00 00 00 00 00 '
        '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00',
      );

      final response = IcomLanHandshakeCodec.decodeLoginResponse(golden,
          expectedReceiverId: 0x11223344);
      expect(response.header.sequence, 0x1234);
      expect(response.header.senderId, 0x55667788);
      expect(response.header.receiverId, 0x11223344);
      expect(response.header.innerSequence, 0x9abc);
      expect(response.header.tokenRequest, 0x1357);
      expect(response.header.token, 0x2468ace0);
      expect(response.authStartId, 0xbeef);
      expect(response.errorCode, 0);
      expect(response.connectionName, 'IC-705');
      expect(response.isAuthenticated, isTrue);

      expectProtocolFailure(() => IcomLanHandshakeCodec.decodeLoginResponse(
          golden,
          expectedReceiverId: 0x01020304));
    });

    test('令牌确认/续期携带能力标记', () {
      final confirmGolden = hexBytes(
        '40 00 00 00 00 00 34 12 44 33 22 11 88 77 66 55 '
        '00 00 00 30 01 02 9a bc 00 00 13 57 24 68 ac e0 '
        '00 00 00 00 07 98 00 00 00 00 00 00 00 00 00 00 '
        '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00',
      );
      final renewalGolden = hexBytes(
        '40 00 00 00 00 00 34 12 44 33 22 11 88 77 66 55 '
        '00 00 00 30 01 05 9a bc 00 00 13 57 24 68 ac e0 '
        '00 00 00 00 07 98 00 00 00 00 00 00 00 00 00 00 '
        '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00',
      );

      expect(
        IcomLanHandshakeCodec.encodeTokenConfirm(
          sequence: 0x1234,
          senderId: 0x11223344,
          receiverId: 0x55667788,
          innerSequence: 0x9abc,
          tokenRequest: 0x1357,
          token: 0x2468ace0,
        ),
        confirmGolden,
      );
      expect(
        IcomLanHandshakeCodec.encodeTokenRenewal(
          sequence: 0x1234,
          senderId: 0x11223344,
          receiverId: 0x55667788,
          innerSequence: 0x9abc,
          tokenRequest: 0x1357,
          token: 0x2468ace0,
        ),
        renewalGolden,
      );
    });

    test('状态包的端口是大端、错误码是小端', () {
      Uint8List statusPacket() {
        final p = Uint8List(IcomLanHandshakeCodec.statusPacketSize);
        IcomLanBytes.writeInt32Le(p, 0x00, p.length);
        IcomLanBytes.writeUInt16Le(p, 0x04, 0x01);
        IcomLanBytes.writeUInt16Le(p, 0x06, 0x1234);
        IcomLanBytes.writeInt32Le(p, 0x08, 0x55667788);
        IcomLanBytes.writeInt32Le(p, 0x0c, 0x11223344);
        IcomLanBytes.writeUInt16Be(p, 0x12, p.length - 0x10);
        IcomLanBytes.writeUInt8(p, 0x14, 0x02);
        IcomLanBytes.writeUInt16Be(p, 0x42, 0x1234);
        IcomLanBytes.writeUInt16Be(p, 0x46, 0x5678);
        return p;
      }

      final status = IcomLanHandshakeCodec.decodeStatusPacket(statusPacket(),
          expectedReceiverId: 0x11223344);
      expect(status.isAuthenticated, isTrue);
      expect(status.isConnected, isTrue);
      expect(status.civPort, 0x1234);
      expect(status.audioPort, 0x5678);

      final failed = statusPacket();
      IcomLanBytes.writeInt32Le(failed, 0x30, 0x12345678);
      final failedStatus = IcomLanHandshakeCodec.decodeStatusPacket(failed,
          expectedReceiverId: 0x11223344);
      expect(failedStatus.errorCode, 0x12345678);
      expect(failedStatus.isAuthenticated, isFalse);
    });
  });

  group('连接信息（0x90）', () {
    IcomLanConnectionParameters parameters() => IcomLanConnectionParameters(
          sequence: 0x1234,
          senderId: 0x11223344,
          receiverId: 0x55667788,
          innerSequence: 0x9abc,
          tokenRequest: 0x1357,
          token: 0x2468ace0,
          radioIdentityBlock: Uint8List.fromList(List.generate(0x20, (i) => i)),
          radioName: 'IC-705',
          username: 'USER',
          localCivPort: 0x1234,
          localAudioPort: 0x5678,
          receiveSampleRateHz: 12000,
          transmitSampleRateHz: 12000,
          transmitBufferSamples: 0x96,
        );

    test('RX-only 参数逐字节匹配（混合字节序）', () {
      final golden = hexBytes(
        '90 00 00 00 00 00 34 12 44 33 22 11 88 77 66 55 '
        '00 00 00 80 01 03 9a bc 00 00 13 57 24 68 ac e0 '
        '00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f '
        '10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f '
        '49 43 2d 37 30 35 00 00 00 00 00 00 00 00 00 00 '
        '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 '
        '56 6b 54 56 00 00 00 00 00 00 00 00 00 00 00 00 '
        '01 00 04 04 00 00 2e e0 00 00 2e e0 00 00 12 34 '
        '00 00 56 78 00 00 00 96 01 00 00 00 00 00 00 00',
      );

      final encoded =
          IcomLanConnectionInfoCodec.encodeParameters(parameters());
      expect(encoded, golden);
      expect(encoded[0x70], 0x01);
      expect(encoded[0x71], 0x00);
    });

    test('真机抓包参数也能逐字节复现', () {
      final captured = hexBytes(
        '90 00 00 00 00 00 26 00 ec 45 97 ae 42 4b 8b 18 '
        '00 00 00 80 01 03 00 1e 00 00 50 ed 60 6c d0 a6 '
        '00 00 00 00 00 00 10 80 00 00 90 c7 12 78 26 00 '
        '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 '
        '49 43 2d 37 30 35 00 00 00 00 00 00 00 00 00 00 '
        '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 '
        '37 50 49 2d 49 00 00 00 00 00 00 00 00 00 00 00 '
        '01 01 04 04 00 00 bb 80 00 00 bb 80 00 00 c3 52 '
        '00 00 c3 53 00 00 00 a0 01 00 00 00 00 00 00 00',
      );

      final encoded = IcomLanConnectionInfoCodec.encodeParameters(
        IcomLanConnectionParameters(
          sequence: 0x26,
          senderId: 0xae9745ec,
          receiverId: 0x188b4b42,
          innerSequence: 0x001e,
          tokenRequest: 0x50ed,
          token: 0x606cd0a6,
          radioIdentityBlock:
              Uint8List.fromList(captured.sublist(0x20, 0x40)),
          radioName: 'IC-705',
          username: 'ic705',
          localCivPort: 50002,
          localAudioPort: 50003,
          receiveEnabled: true,
          transmitEnabled: true,
          receiveSampleRateHz: 48000,
          transmitSampleRateHz: 48000,
          transmitBufferSamples: 0xa0,
        ),
      );
      expect(encoded, captured);
    });

    test('首次连接用的身份块只有两个非零字节', () {
      final identity = IcomLanConnectionInfoCodec.initialClientIdentityBlock();
      expect(identity.length, 0x20);
      expect(identity[0x06], 0x10);
      expect(identity[0x07], 0x80);
      expect(identity.where((b) => b != 0).length, 2);
    });

    test('解析电台名称与「流被占用」联合体', () {
      final golden = hexBytes(
        '90 00 00 00 00 00 34 12 44 33 22 11 88 77 66 55 '
        '00 00 00 80 01 03 9a bc 00 00 13 57 24 68 ac e0 '
        '00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f '
        '10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f '
        '49 43 2d 37 30 35 00 00 00 00 00 00 00 00 00 00 '
        '00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 '
        '56 6b 54 56 00 00 00 00 00 00 00 00 00 00 00 00 '
        '01 00 04 04 00 00 2e e0 00 00 2e e0 00 00 12 34 '
        '00 00 56 78 00 00 00 96 01 00 00 00 00 00 00 00',
      );
      final busy = Uint8List.fromList(golden);
      for (var i = 0x60; i < busy.length; i++) {
        busy[i] = 0;
      }
      busy[0x60] = 1;
      IcomLanBytes.writeInt32Le(busy, 0x08, 0x55667788);
      IcomLanBytes.writeInt32Le(busy, 0x0c, 0x11223344);
      busy[0x14] = IcomLanHandshakeCodec.requestReplyResponse;
      final name = 'APRSdroid'.codeUnits;
      busy.setRange(0x64, 0x64 + name.length, name);

      final announcement = IcomLanConnectionInfoCodec.decodeAnnouncement(busy,
          expectedReceiverId: 0x11223344);
      expect(announcement.radioName, 'IC-705');
      expect(announcement.isBusy, isTrue);
      expect(announcement.busyClientName, 'APRSdroid');

      busy[0x60] = 0;
      final available = IcomLanConnectionInfoCodec.decodeAnnouncement(busy);
      expect(available.isBusy, isFalse);
      expect(available.busyClientName, isNull);
    });

    test('端口非法时报错', () {
      expectProtocolFailure(() => IcomLanConnectionInfoCodec.encodeParameters(
          IcomLanConnectionParameters(
            sequence: 0x1234,
            senderId: 0x11223344,
            receiverId: 0x55667788,
            innerSequence: 0x9abc,
            tokenRequest: 0x1357,
            token: 0x2468ace0,
            radioIdentityBlock: Uint8List(0x20),
            radioName: 'IC-705',
            username: 'USER',
            localCivPort: 50001,
            localAudioPort: 0,
          )));
    });
  });

  group('音频包（0x18 头 + PCM）', () {
    test('音频包逐字节匹配协议布局', () {
      final golden = hexBytes(
        '1c 00 00 00 00 00 34 12 44 33 22 11 88 77 66 55 '
        '80 00 9a bc 00 00 00 04 34 12 cc ed',
      );
      final encoded = IcomLanAudioCodec.encode(
        sequence: 0x1234,
        senderId: 0x11223344,
        receiverId: 0x55667788,
        audioSequence: 0x9abc,
        pcmPayload: hexBytes('34 12 cc ed'),
      );
      expect(encoded, golden);

      final decoded =
          IcomLanAudioCodec.decode(golden, expectedReceiverId: 0x55667788);
      expect(decoded.header.identity, IcomLanAudioCodec.identityForOtherPayloads);
      expect(decoded.header.audioSequence, 0x9abc);
      expect(decoded.pcmPayload, hexBytes('34 12 cc ed'));
    });

    test('编码后能原样解出头部与 PCM', () {
      final pcm = Uint8List.fromList(List.generate(480, (i) => i & 0xff));
      final packet = IcomLanAudioCodec.encode(
        sequence: 0x1234,
        senderId: 0x11223344,
        receiverId: 0x55667788,
        audioSequence: 0x0007,
        pcmPayload: pcm,
      );
      expect(packet.length, IcomLanAudioCodec.headerSize + 480);

      final decoded =
          IcomLanAudioCodec.decode(packet, expectedReceiverId: 0x55667788);
      expect(decoded.header.sequence, 0x1234);
      expect(decoded.header.senderId, 0x11223344);
      expect(decoded.header.receiverId, 0x55667788);
      expect(decoded.header.audioSequence, 0x0007);
      expect(decoded.header.payloadLength, 480);
      expect(decoded.pcmPayload, pcm);
    });

    test('标识值按负载长度选择', () {
      expect(IcomLanAudioCodec.transmitIdentity(0xa0),
          IcomLanAudioCodec.identityFor160BytePayload);
      expect(IcomLanAudioCodec.transmitIdentity(0x1e0),
          IcomLanAudioCodec.identityForOtherPayloads);
    });

    test('长度不符或接收方 ID 不符时报错', () {
      final pcm = Uint8List(480);
      final packet = IcomLanAudioCodec.encode(
        sequence: 1,
        senderId: 2,
        receiverId: 3,
        audioSequence: 4,
        pcmPayload: pcm,
      );
      final truncated = Uint8List.fromList(packet.sublist(0, packet.length - 2));
      expectProtocolFailure(() => IcomLanAudioCodec.decode(truncated));
      expectProtocolFailure(() => IcomLanAudioCodec.decode(packet,
          expectedReceiverId: 0x01020304));
    });
  });

  group('通用控制包（0x10）', () {
    test('探测包与重传请求', () {
      final probe = IcomLanControlCodec.encode(const IcomLanControlPacket(
        type: IcomLanControlCodec.typeAreYouThere,
        sequence: 0,
        senderId: 0x11223344,
        receiverId: 0xffffffff,
      ));
      expect(probe.length, IcomLanControlCodec.packetSize);
      final decoded = IcomLanControlCodec.decode(probe);
      expect(decoded.type, IcomLanControlCodec.typeAreYouThere);
      expect(decoded.senderId, 0x11223344);
      expect(decoded.receiverId, 0xffffffff);

      // 单序号形态：序号在 0x06。
      final single =
          hexBytes('10 00 00 00 01 00 34 12 44 33 22 11 88 77 66 55');
      expect(
          IcomLanControlCodec.decodeRetransmitRequest(single,
              expectedReceiverId: 0x55667788),
          [0x1234]);

      // 多序号形态：请求的序号列表跟在 16 字节头之后（0x10 起），
      // 头部 0x06 不再参与 —— 与协议实现保持一致。
      final multiple =
          hexBytes('14 00 00 00 01 00 00 00 44 33 22 11 88 77 66 55 34 12 cd ab');
      expect(
          IcomLanControlCodec.decodeRetransmitRequest(multiple,
              expectedReceiverId: 0x55667788),
          [0x1234, 0xabcd]);

      // 奇数字节的序号列表属于畸形包。
      final malformed =
          hexBytes('11 00 00 00 01 00 00 00 44 33 22 11 88 77 66 55 34');
      expectProtocolFailure(
          () => IcomLanControlCodec.decodeRetransmitRequest(malformed));
    });
  });
}
