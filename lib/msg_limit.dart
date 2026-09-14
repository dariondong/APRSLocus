/// ─── APRS 消息长度/可解析性预检 ───
///
/// 为什么需要单独一份：APRS-IS 与射频的「过长」完全是两件事，
/// 而历史上只做了射频那一半（67 字符），于是 APRS-IS 上打一长段话会
/// **看起来发出去了、对方却解析不出来**（或服务器直接不转发）。
///
/// 三条约束，按严格程度递增：
///   ① **APRS101 规范**：消息文本字段上限 67 字符。超过后仍能发出，
///      但不少客户端/网关按规范截断或拒收 —— 属于「可能解析不出来」。
///   ② **APRS-IS 报文行上限**：服务器普遍限制单行 512 字节（含报头与 CRLF）。
///      整包超过时服务器可能直接丢弃，**连报头都到不了对方**。
///   ③ AX.25 单帧上限（射频侧另有 maxFrame 限制，见 TncConfig/AudioConfig）。
///
/// 这里只做**纯计算**，不做拦截决策：调用方（UI）决定是提示还是阻止，
/// 这样测试可以直接断言字节数，不必搭 UI。
library;

import 'dart:convert';

/// APRS101 规定的消息文本上限（字符）
const int aprsSpecMsgChars = 67;

/// APRS-IS 单行上限（字节，含报头、信息字段与结尾 CRLF）
const int aprsIsMaxLineBytes = 512;

/// 消息与链路约束的匹配程度
enum MsgFit {
  /// 规范内：对方必定能解析
  ok,

  /// 超出 APRS101 的 67 字符，但整包仍在上限内 —— 多数客户端能读，
  /// 少数按规范截断/拒收，属于「可能解析不出来」
  overSpec,

  /// 整包超过 APRS-IS 行上限 —— 服务器可能整包丢弃，几乎肯定收不到
  overServerLimit,
}

/// 预检结果
class MsgLimitResult {
  /// 匹配程度
  final MsgFit fit;

  /// 按 UTF-8 计算的整包字节数（不含 CRLF）
  final int packetBytes;

  /// 消息文本的**字符**数（不是字节数：中文一个字算一个字符，
  /// 但 APRS 上限是按字符计的，两者必须分开报给用户）
  final int textChars;

  /// 消息文本的 UTF-8 字节数
  final int textBytes;

  /// 整包还能再加多少字节（负数表示已超）
  final int bytesLeft;

  const MsgLimitResult({
    required this.fit,
    required this.packetBytes,
    required this.textChars,
    required this.textBytes,
    required this.bytesLeft,
  });

  bool get ok => fit == MsgFit.ok;
}

class MsgLimit {
  MsgLimit._();

  /// 估算一条 APRS 消息报文的整包大小并给出匹配程度。
  ///
  /// [from] 源呼号（含 SSID），[path] 报头路径（如 `APALOC,TCPIP*`），
  /// [to] 收件人呼号或群呼号，[text] 消息正文，[id] 消息 ID，
  /// [noAck] 为 true 时 ID 后带 `_`（APRS101 的 no-ack 写法）。
  static MsgLimitResult check({
    required String from,
    required String path,
    required String to,
    required String text,
    String id = '',
    bool noAck = false,
  }) {
    // 收件人字段固定 9 字符、空格补齐（APRS101），不足与超出都要按实际
    // 占位计算；超出 9 个字符本身就是对方解析不了的常见原因。
    final addressee = to.padRight(9);
    final tail = id.isEmpty ? '' : '{$id${noAck ? '_' : ''}';
    final packet = '$from>$path::$addressee:$text$tail';
    final packetBytes = utf8.encode(packet).length;
    final textBytes = utf8.encode(text).length;
    final textChars = text.characters_length;

    final fit = packetBytes > aprsIsMaxLineBytes
        ? MsgFit.overServerLimit
        : (textChars > aprsSpecMsgChars ? MsgFit.overSpec : MsgFit.ok);
    return MsgLimitResult(
      fit: fit,
      packetBytes: packetBytes,
      textChars: textChars,
      textBytes: textBytes,
      bytesLeft: aprsIsMaxLineBytes - packetBytes,
    );
  }
}

extension on String {
  /// 字符数（按 Unicode 码点，避免把 emoji 的代理对算成两个字符）
  int get characters_length => runes.length;
}
