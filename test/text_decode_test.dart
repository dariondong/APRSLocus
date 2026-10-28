import 'dart:convert';

import 'package:aprslocus/kiss.dart';
import 'package:aprslocus/text_decode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbk_codec/gbk_codec.dart';

/// APRS 报文字节 → 文本：UTF-8 / GBK 自动识别回归测试。
///
/// 报文里没有编码标记，只能靠字节本身判断；判错的后果是备注显示成乱码，
/// 所以把「该判成什么」逐种锁住。
void main() {
  group('decodeAprsBytes', () {
    test('纯 ASCII 原样返回', () {
      expect(decodeAprsBytes(ascii.encode('BG1ABC>APRS:!3010.00N/12010.00E>hi')),
          'BG1ABC>APRS:!3010.00N/12010.00E>hi');
    });

    test('UTF-8 中文', () {
      final b = utf8.encode('BG1ABC>APRS:>你好 world');
      expect(decodeAprsBytes(b), 'BG1ABC>APRS:>你好 world');
    });

    test('GBK 中文', () {
      final b = [...ascii.encode('BG1ABC>APRS:>'), ...gbk_bytes.encode('你好，业余无线电')];
      expect(decodeAprsBytes(b), 'BG1ABC>APRS:>你好，业余无线电');
    });

    test('GBK 字节确实不是合法 UTF-8（前提成立，测试才有意义）', () {
      expect(() => utf8.decode(gbk_bytes.encode('中文')), throwsFormatException);
    });

    test('同一行混了 UTF-8 与 GBK：各认各的', () {
      final b = [...utf8.encode('甲'), 0x20, ...gbk_bytes.encode('乙')];
      expect(decodeAprsBytes(b), '甲 乙');
    });

    test('认不出的字节按 Latin-1 保留，不丢信息、不抛异常', () {
      // 0xFF 单独出现：既不是 UTF-8 也没有配对的 GBK 尾字节
      final s = decodeAprsBytes([0x41, 0xFF]);
      expect(s, 'Aÿ');
    });

    test('末尾截断的多字节序列不抛异常', () {
      expect(() => decodeAprsBytes([0x41, 0xE4, 0xB8]), returnsNormally);
    });
  });

  group('AX.25 UI 帧信息字段', () {
    // decodeToTnc2 吃 AX.25 帧（不含 KISS 外壳）；用 encodeUi 造一帧，再换信息字段。
    List<int> frameWithInfo(List<int> info) {
      final head = Ax25.encodeTnc2('BG1ABC>APRS:x')!;
      return [...head.sublist(0, head.length - 1), ...info];
    }

    test('GBK 备注在 TNC / 声卡链路上也能还原成中文', () {
      final f = frameWithInfo([...ascii.encode('>'), ...gbk_bytes.encode('移动台')]);
      expect(Ax25.decodeToTnc2(f), 'BG1ABC>APRS:>移动台');
    });

    test('UTF-8 备注仍然正常', () {
      final f = frameWithInfo([...ascii.encode('>'), ...utf8.encode('移动台')]);
      expect(Ax25.decodeToTnc2(f), 'BG1ABC>APRS:>移动台');
    });
  });
}
