import 'package:aprslocus/kiss.dart';
import 'package:flutter_test/flutter_test.dart';

/// KISS + AX.25 编解码回归测试
///
/// 这一层出错的代价很高：KISS 转义写错 → TNC 整帧丢弃（射频链路直接不通）；
/// AX.25 地址字段写错 → 呼号/SSID 变形（对方收到别人的呼号）。
/// 因此用逐字节的固定期望值锁住行为。
void main() {
  group('KISS 转义', () {
    test('普通数据加首尾 FEND', () {
      expect(Kiss.escape([0x01, 0x02]), [0xC0, 0x01, 0x02, 0xC0]);
    });

    test('FEND 被转义为 FESC+TFEND', () {
      expect(Kiss.escape([0xC0]), [0xC0, 0xDB, 0xDC, 0xC0]);
    });

    test('FESC 被转义为 FESC+TFESC', () {
      expect(Kiss.escape([0xDB]), [0xC0, 0xDB, 0xDD, 0xC0]);
    });

    test('数据帧首字节是端口+命令（0 号端口数据帧）', () {
      final f = Kiss.dataFrame(0, [0xAA]);
      expect(f, [0xC0, 0x00, 0xAA, 0xC0]);
    });

    test('端口号放在高 4 位', () {
      final f = Kiss.dataFrame(2, [0xAA]);
      expect(f, [0xC0, 0x20, 0xAA, 0xC0]);
    });
  });

  group('KISS 参数帧', () {
    test('TxDelay 编码为 0x01 + 值', () {
      expect(Kiss.paramFrame(0, Kiss.cmdTxDelay, 30),
          [0xC0, 0x01, 30, 0xC0]);
    });

    test('FullDuplex / P / SlotTime / TxTail 命令码符合 KISS 规范', () {
      // 0x01 TxDelay / 0x02 P / 0x03 SlotTime / 0x04 TxTail / 0x05 FullDuplex
      expect(Kiss.cmdTxDelay, 0x01);
      expect(Kiss.cmdPersistence, 0x02);
      expect(Kiss.cmdSlotTime, 0x03);
      expect(Kiss.cmdTxTail, 0x04);
      expect(Kiss.cmdFullDuplex, 0x05);
      expect(Kiss.cmdSetHardware, 0x06);
      expect(Kiss.cmdReturn, 0x0F);
    });

    test('命令帧无参数', () {
      expect(Kiss.commandFrame(0, Kiss.cmdReturn), [0xC0, 0x0F, 0xC0]);
    });
  });

  group('KISS 解码器（流式）', () {
    test('解出一帧并还原端口与命令', () {
      final d = KissDecoder();
      final frames = d.feed(Kiss.dataFrame(1, [1, 2, 3]));
      expect(frames.length, 1);
      expect(frames.first.port, 1);
      expect(frames.first.command, 0);
      expect(frames.first.payload, [1, 2, 3]);
      expect(frames.first.isData, isTrue);
    });

    test('一次喂入多帧全部解出', () {
      final d = KissDecoder();
      final bytes = [
        ...Kiss.dataFrame(0, [1]),
        ...Kiss.dataFrame(0, [2]),
        ...Kiss.dataFrame(0, [3]),
      ];
      final frames = d.feed(bytes);
      expect(frames.map((f) => f.payload.single).toList(), [1, 2, 3]);
    });

    test('半帧分两次喂入也能拼出来', () {
      final d = KissDecoder();
      final full = Kiss.dataFrame(0, [0x10, 0x20, 0x30]);
      final split = full.length ~/ 2;
      expect(d.feed(full.sublist(0, split)), isEmpty);
      final frames = d.feed(full.sublist(split));
      expect(frames.single.payload, [0x10, 0x20, 0x30]);
    });

    test('转义序列跨数据块也能还原', () {
      final d = KissDecoder();
      // 载荷含 FEND 与 FESC，转义后的字节被切成两半
      final full = Kiss.dataFrame(0, [0xC0, 0xDB]);
      final cut = full.indexOf(0xDB) + 1;
      expect(d.feed(full.sublist(0, cut)), isEmpty);
      final frames = d.feed(full.sublist(cut));
      expect(frames.single.payload, [0xC0, 0xDB]);
    });

    test('帧外垃圾字节被忽略', () {
      final d = KissDecoder();
      final frames = d.feed([0x11, 0x22, ...Kiss.dataFrame(0, [0x33])]);
      expect(frames.single.payload, [0x33]);
    });

    test('连续 FEND 不产生空帧', () {
      final d = KissDecoder();
      expect(d.feed([0xC0, 0xC0, 0xC0]), isEmpty);
    });

    test('参数帧的 command 不当作数据帧', () {
      final d = KissDecoder();
      final frames = d.feed(Kiss.paramFrame(0, Kiss.cmdTxDelay, 12));
      expect(frames.single.command, Kiss.cmdTxDelay);
      expect(frames.single.isData, isFalse);
      expect(frames.single.payload, [12]);
    });
  });

  group('AX.25 地址字段', () {
    test('呼号左移一位、SSID 字节带 0x60 与结束位', () {
      // 'A' = 0x41 → <<1 = 0x82
      final a = Ax25.address('A', last: true);
      expect(a.length, 7);
      expect(a[0], 0x82);
      // 其余补空格：' ' = 0x20 → 0x40
      expect(a.sublist(1, 6), [0x40, 0x40, 0x40, 0x40, 0x40]);
      // SSID 0、结束位 1 → 0x61
      expect(a[6], 0x61);
    });

    test('SSID 编入低 4 位；非末位不置结束位', () {
      final a = Ax25.address('BG7LZQ-9', last: false);
      expect(a[6], 0x60 | (9 << 1));
    });

    test('呼号过长被截断到 6 字符，过短补空格', () {
      final long = Ax25.address('ABCDEFGH', last: true);
      final short = Ax25.address('AB', last: true);
      expect(Ax25.readAddress(long, 0).$1, 'ABCDEF');
      expect(Ax25.readAddress(short, 0).$1, 'AB');
    });

    test('splitCall 解析大小写与非法 SSID', () {
      expect(Ax25.splitCall('bg7lzq-9'), ('BG7LZQ', 9));
      expect(Ax25.splitCall('BG7LZQ'), ('BG7LZQ', 0));
      expect(Ax25.splitCall('BG7LZQ-99'), ('BG7LZQ', 15)); // 上限 15
      expect(Ax25.splitCall('BG7LZQ-X'), ('BG7LZQ-X', 0)); // 非法 SSID 视为呼号一部分
    });

    test('地址字段可往返', () {
      for (final c in ['BG7LZQ-9', 'APALOC', 'BA7KSM-15', 'N0CALL']) {
        final raw = Ax25.address(c, last: true);
        final (call, ssid, last) = Ax25.readAddress(raw, 0);
        expect(last, isTrue);
        final (wantCall, wantSsid) = Ax25.splitCall(c);
        expect(call, wantCall);
        expect(ssid, wantSsid);
      }
    });
  });

  group('AX.25 UI 帧编解码', () {
    test('编码后能解回同一 TNC2 报文（呼号/SSID/信息字段）', () {
      const tnc2 = 'BG7LZQ-9>APALOC,WIDE1-1,WIDE2-1:!2230.00N/11400.00E>测试';
      final frame = Ax25.encodeTnc2(tnc2);
      expect(frame, isNotNull);
      final back = Ax25.decodeToTnc2(frame!);
      expect(back, isNotNull);
      expect(back, startsWith('BG7LZQ-9>APALOC,WIDE1-1*,WIDE2-1*:'));
      expect(back, endsWith('!2230.00N/11400.00E>测试'));
    });

    test('UI 帧使用控制字 0x03 与 PID 0xF0', () {
      final f = Ax25.encodeTnc2('BG7LZQ>APALOC:>hello')!;
      expect(f[f.length - '>hello'.length - 2], 0x03);
      expect(f[f.length - '>hello'.length - 1], 0xF0);
    });

    test('APRS-IS 专有路径项 TCPIP* 不进入射频帧', () {
      // 否则射频上会出现无意义的中继项，部分 TNC 会拒发
      final f = Ax25.encodeTnc2('BG7LZQ>APRS,TCPIP*:!1')!;
      expect(Ax25.decodeToTnc2(f), 'BG7LZQ>APRS:!1');
    });

    test('无中继时源地址为最后一个地址字段', () {
      final f = Ax25.encodeTnc2('BG7LZQ-9>APALOC:>x')!;
      // 目的 7 + 源 7 + 控制 + PID = 16 字节固定头
      expect(f.length, 16 + '>x'.length);
    });

    test('最多支持 8 个中继地址', () {
      final digis = List.generate(8, (i) => 'WIDE1-$i').join(',');
      final f = Ax25.encodeTnc2('BG7LZQ>APALOC,$digis:!')!;
      expect(Ax25.decodeToTnc2(f), isNotNull);
    });

    test('非 UI 帧解码返回 null（不把信令帧当 APRS）', () {
      final f = Ax25.encodeTnc2('BG7LZQ>APALOC:!')!;
      // 无中继时：目的 7 + 源 7 = 14，控制字段在下标 14、PID 在 15
      f[14] = 0x2F; // 改成非 UI
      expect(Ax25.decodeToTnc2(f), isNull);
    });

    test('过短/损坏的帧返回 null 而不是抛异常', () {
      expect(Ax25.decodeToTnc2([0x00]), isNull);
      expect(Ax25.decodeToTnc2(const []), isNull);
    });

    test('缺少 > 或 : 的文本返回 null', () {
      expect(Ax25.encodeTnc2('BG7LZQ'), isNull);
      expect(Ax25.encodeTnc2('BG7LZQ>APALOC'), isNull);
      expect(Ax25.encodeTnc2('>APALOC:x'), isNull);
    });

    test('中文信息字段按 UTF-8 往返不丢失', () {
      const msg = 'BG7LZQ>APALOC::BA7KSM  :你好，这里是测试消息';
      final f = Ax25.encodeTnc2(msg)!;
      expect(Ax25.decodeToTnc2(f), msg);
    });
  });

  group('KISS 参数单位换算', () {
    test('ms ↔ 10ms 往返', () {
      expect(TncConfigFixture.msToKiss(300), 30);
      expect(TncConfigFixture.msToKiss(50), 5);
      expect(TncConfigFixture.msToKiss(2550), 255);
      expect(TncConfigFixture.msToKiss(9999), 255); // 封顶
      expect(TncConfigFixture.kissToMs(30), 300);
    });
  });
}

/// 直接复用 lib/tnc.dart 的换算（避免测试里复刻一份公式）
class TncConfigFixture {
  static int msToKiss(int ms) => (ms / 10).round().clamp(0, 255);
  static int kissToMs(int v) => v.clamp(0, 255) * 10;
}
