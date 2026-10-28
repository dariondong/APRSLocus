import 'dart:convert';

import 'package:gbk_codec/gbk_codec.dart';

/// APRS 报文字节 → 文本，自动识别 UTF-8 / GBK。
///
/// APRS 协议本身只规定 ASCII，但国内电台与软件常把中文直接写进备注 / 消息，
/// 编码有 UTF-8 也有 GBK（老电台、PC 软件多为 GBK），而报文里**没有任何编码标记**，
/// 只能靠字节本身判断。顺序：
///
///  1. 纯 ASCII：直接解（绝大多数报文走这条，最快）；
///  2. **严格** UTF-8：合法才采用。中文 GBK 字节几乎不可能恰好拼成合法 UTF-8，
///     所以「合法 UTF-8」基本可以断定就是 UTF-8；
///  3. **严格** GBK：每个高位字节都必须落在 GBK 的双字节范围内才采用；
///  4. 都不是（常见于同一行里混了两种编码）：逐段宽容解码，能认哪段认哪段，
///     认不出的字节按 Latin-1 原样保留，**至少不丢信息**。
///
/// 为什么自己校验 GBK 范围而不是直接信解码器：`gbk_bytes.decode` 对非法字节不会抛异常，
/// 没法拿来当「是不是 GBK」的判据。
///
/// ⚠️ 字节流必须用 `gbk_bytes`，**不是** `gbk`：后者的输入输出是 16 位编码
/// （`你` = 0xC4E3 一个整数），把原始字节喂给它得到的全是乱码。旧版 APRS-IS 解码
/// 就是这么写的，所以 GBK 中文其实从来没真正显示对过。
String decodeAprsBytes(List<int> bytes) {
  var ascii = true;
  for (final b in bytes) {
    if (b >= 0x80) {
      ascii = false;
      break;
    }
  }
  if (ascii) return String.fromCharCodes(bytes);

  try {
    return utf8.decode(bytes);
  } on FormatException {
    // 不是合法 UTF-8，往下试 GBK
  }

  if (_isStrictGbk(bytes)) return gbk_bytes.decode(bytes);

  return _decodeMixed(bytes);
}

/// 是否整段都是合法 GBK：ASCII 或「前导 0x81–0xFE + 尾字节 0x40–0xFE（除 0x7F）」。
bool _isStrictGbk(List<int> bytes) {
  var i = 0;
  while (i < bytes.length) {
    final b = bytes[i];
    if (b < 0x80) {
      i++;
      continue;
    }
    if (i + 1 >= bytes.length || !_isGbkPair(b, bytes[i + 1])) return false;
    i += 2;
  }
  return true;
}

bool _isGbkPair(int lead, int trail) =>
    lead >= 0x81 && lead <= 0xFE && trail >= 0x40 && trail <= 0xFE && trail != 0x7F;

/// 宽容的逐段解码：每个高位字节处，先认一个完整的 UTF-8 序列，其次认一个 GBK
/// 双字节，都不是就按 Latin-1 留一个字符。
String _decodeMixed(List<int> bytes) {
  final out = StringBuffer();
  var i = 0;
  while (i < bytes.length) {
    final b = bytes[i];
    if (b < 0x80) {
      out.writeCharCode(b);
      i++;
      continue;
    }
    final n = _utf8SeqLen(bytes, i);
    if (n > 0) {
      out.write(utf8.decode(bytes.sublist(i, i + n)));
      i += n;
    } else if (i + 1 < bytes.length && _isGbkPair(b, bytes[i + 1])) {
      out.write(gbk_bytes.decode(bytes.sublist(i, i + 2)));
      i += 2;
    } else {
      out.writeCharCode(b);
      i++;
    }
  }
  return out.toString();
}

/// 从 [i] 起若是一个**合法**的 UTF-8 多字节序列，返回其长度，否则 0。
int _utf8SeqLen(List<int> bytes, int i) {
  final b = bytes[i];
  final int n;
  if (b >= 0xC2 && b <= 0xDF) {
    n = 2;
  } else if (b >= 0xE0 && b <= 0xEF) {
    n = 3;
  } else if (b >= 0xF0 && b <= 0xF4) {
    n = 4;
  } else {
    return 0;
  }
  if (i + n > bytes.length) return 0;
  try {
    utf8.decode(bytes.sublist(i, i + n));
    return n;
  } on FormatException {
    return 0;
  }
}
