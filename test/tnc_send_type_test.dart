import 'dart:typed_data';

import 'package:aprslocus/kiss.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 「蓝牙 TNC 能收不能发」的**直接复现**测试。
///
/// 事故经过：发送路径是 Dart → MethodChannel → Kotlin → BluetoothSocket。
/// Flutter 的 `StandardMessageCodec` 对字节数组有两条不同的编码分支：
///
///   * `Uint8List`  → `_valueUint8List` → 平台侧是 **byte[]**
///   * `List<int>`  → `_valueList`      → 平台侧是 **ArrayList**
///
/// 我们当初用 `Kiss.escape()` 组帧，返回的是 `List<int>`（`<int>[]`），
/// 于是 Kotlin 侧 `call.argument<ByteArray>("data")` 取到 **null**，
/// 抛 `NO_DATA`；而 `invokeMethod` 的失败是**异步**的，被同步
/// `try/catch` 漏掉后完全静默 —— 表现就是「能收（接收方向做了
/// Uint8List/List 双容错），不能发（发送方向没有容错），且毫无提示」。
///
/// 桌面串口走 `dart:io` 的 `writeFrom(List<int>)`，不做类型转换，
/// 所以只有 Android 蓝牙中招 —— 这也是它长期没被发现的原因。
///
/// 下面用**真实的** StandardMessageCodec 复现这个差异，并把修复钉死：
/// 组帧函数必须返回 Uint8List，且接口签名用 Uint8List 强制约束。
void main() {
  const codec = StandardMessageCodec();

  /// 模拟「Dart 编 → 平台解」这一趟，返回平台侧会拿到的东西
  Object? roundTrip(Object? value) {
    final encoded = codec.encodeMessage(<String, Object?>{'data': value})!;
    final decoded = codec.decodeMessage(encoded) as Map<Object?, Object?>;
    return decoded['data'];
  }

  group('MethodChannel 字节类型（事故复现）', () {
    test('List<int> 到平台侧**不是** Uint8List（即不是 byte[]）', () {
      final got = roundTrip(<int>[1, 2, 3]);
      expect(got, isA<List<Object?>>(),
          reason: '会走 _valueList，平台侧是 ArrayList');
      expect(got, isNot(isA<Uint8List>()),
          reason: '这一步为真，就意味着 Kotlin 的 argument<ByteArray>() 会拿到 null');
    });

    test('Uint8List 到平台侧才是 byte[]', () {
      final got = roundTrip(Uint8List.fromList(<int>[1, 2, 3]));
      expect(got, isA<Uint8List>());
      expect((got as Uint8List).toList(), <int>[1, 2, 3]);
    });
  });

  group('KISS 组帧必须返回 Uint8List（防止事故回归）', () {
    test('escape / dataFrame / paramFrame / commandFrame 的静态类型与运行时类型', () {
      final payload = Ax25.encodeTnc2('BG7LZQ-9>APALOC:>TEST')!;

      final frames = <String, Object>{
        'escape': Kiss.escape(payload),
        'dataFrame': Kiss.dataFrame(0, payload),
        'paramFrame': Kiss.paramFrame(0, Kiss.cmdTxDelay, 30),
        'commandFrame': Kiss.commandFrame(0, Kiss.cmdReturn),
      };
      frames.forEach((name, f) {
        expect(f, isA<Uint8List>(), reason: '$name 必须返回 Uint8List');
        // 运行时也必须真的是 Uint8List（不能是伪装成它的 List）
        expect(roundTrip(f), isA<Uint8List>(),
            reason: '$name 经 MethodChannel 后必须是 byte[]，否则原生侧取不到');
      });
    });

    test('发出的 KISS 帧内容仍然正确（首尾 FEND + 端口/命令字节）', () {
      final payload = Ax25.encodeTnc2('BG7LZQ-9>APALOC:>TEST')!;
      final f = Kiss.dataFrame(0, payload);
      expect(f.first, Kiss.fend);
      expect(f.last, Kiss.fend);
      expect(f[1], 0x00, reason: '端口 0 的数据帧，命令字节为 0');
      // 转义正确性：载荷里出现 FEND/FESC 时必须被转义
      final esc = Kiss.escape(<int>[Kiss.fend, Kiss.fesc]);
      expect(esc, <int>[Kiss.fend, Kiss.fesc, Kiss.tfend, Kiss.fesc, Kiss.tfesc,
        Kiss.fend]);
    });

    test('整条发送链路的字节类型正确（encodeTnc2 → dataFrame）', () {
      final payload = Ax25.encodeTnc2('BG7LZQ-9>APALOC:>TEST')!;
      expect(payload, isA<List<int>>());
      final wire = Kiss.dataFrame(0, payload);
      expect(wire, isA<Uint8List>());
      expect(roundTrip(wire), isA<Uint8List>(),
          reason: '这八位宽的字节数组必须原样变成平台的 byte[]，否则蓝牙 TNC 收不到任何下行数据');
    });
  });
}
