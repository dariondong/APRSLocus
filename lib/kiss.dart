/// ─── KISS 协议 + AX.25 编解码 ───
///
/// 用途：把本应用生成的 APRS 报文（TNC2 文本形式 `SRC>DEST,PATH:info`）
/// 转成 KISS-over-serial/bluetooth 的字节流发到 TNC；并把 TNC 收到的
/// KISS 帧还原成 TNC2 文本，交给已有的解析管线（`AppState._onAprsLine`）。
///
/// 参考：
///   - KISS：`kiss.c`（Phil Karn KA9Q），帧界定 FEND 0xC0，
///     转义 FESC 0xDB / TFEND 0xDC / TFESC 0xDD；命令字节高 4 位为端口号、
///     低 4 位为命令。
///   - AX.25 UI 帧：地址字段每字符左移 1 位，SSID 字节低 4 位为 SSID、
///     0x60 为保留位、最低位标记地址字段结束；UI 帧控制字段 0x03、
///     PID 0xF0（无连接信息）。
library;

import 'dart:convert' show utf8;

/// KISS 常量与编解码
class Kiss {
  Kiss._();

  static const int fend = 0xC0; // 帧首尾界定符
  static const int fesc = 0xDB; // 转义前缀
  static const int tfend = 0xDC; // 被转义的 FEND
  static const int tfesc = 0xDD; // 被转义的 FESC

  // 命令（低 4 位）
  static const int cmdTxDelay = 0x01;
  static const int cmdPersistence = 0x02;
  static const int cmdSlotTime = 0x03;
  static const int cmdTxTail = 0x04;
  static const int cmdFullDuplex = 0x05;
  static const int cmdSetHardware = 0x06;
  static const int cmdReturn = 0x0F; // 退出 KISS，回到 TNC 命令模式
  static const int cmdUnknown = 0x0F; // 0x0F 兼作「未识别」

  /// 把数据包体转义并加上首尾 FEND
  static List<int> escape(List<int> data) {
    final out = <int>[fend];
    for (final b in data) {
      if (b == fend) {
        out..add(fesc)..add(tfend);
      } else if (b == fesc) {
        out..add(fesc)..add(tfesc);
      } else {
        out.add(b);
      }
    }
    out.add(fend);
    return out;
  }

  /// 数据帧（KISS type 0，即 AX.25 帧）
  static List<int> dataFrame(int port, List<int> ax25) =>
      escape(<int>[(port & 0x0F) << 4] + ax25);

  /// 参数帧：命令字 + 参数值。注意 **TxDelay / TxTail / SlotTime 的单位是 10ms**，
  /// 由调用方换算；本函数只负责组帧。
  static List<int> paramFrame(int port, int command, int value) =>
      escape(<int>[(port & 0x0F) << 4 | (command & 0x0F), value & 0xFF]);

  /// 无参数命令帧（如 RETURN）
  static List<int> commandFrame(int port, int command) =>
      escape(<int>[(port & 0x0F) << 4 | (command & 0x0F)]);
}

/// 一帧已解出的 KISS 数据
class KissFrame {
  final int port;
  final int command;

  /// 命令帧时为参数（长度 0 或 1），数据帧时为 AX.25 帧体
  final List<int> payload;

  const KissFrame(this.port, this.command, this.payload);

  /// 是否为 AX.25 数据帧（命令 0）
  bool get isData => command == 0;

  @override
  String toString() =>
      'KissFrame(port=$port, cmd=$command, ${payload.length}B)';
}

/// 流式 KISS 解码器。
///
/// TNC 是字节流：一次 `read` 可能拿到半帧、也可能拿到多帧，所以必须
/// 增量喂入。FEND 既做「帧结束」也做「帧开始」——连续两个 FEND 之间的
/// 空内容（如帧间填充）直接丢弃。
class KissDecoder {
  final List<int> _buf = [];
  bool _inFrame = false;
  bool _escaped = false;

  /// 喂入一段字节，返回本次能完整解出的所有帧
  List<KissFrame> feed(List<int> bytes) {
    final out = <KissFrame>[];
    for (final b in bytes) {
      if (b == Kiss.fend) {
        // 帧边界：若有累积内容则结算
        if (_inFrame && _buf.isNotEmpty) {
          final f = _finish();
          if (f != null) out.add(f);
        }
        _buf.clear();
        _inFrame = true;
        _escaped = false;
        continue;
      }
      if (!_inFrame) continue; // 帧外垃圾字节（部分 TNC 上电时会吐）
      if (b == Kiss.fesc) {
        _escaped = true;
        continue;
      }
      if (_escaped) {
        _escaped = false;
        if (b == Kiss.tfend) {
          _buf.add(Kiss.fend);
        } else if (b == Kiss.tfesc) {
          _buf.add(Kiss.fesc);
        } else {
          // 非法转义：按字面量收下（宽容处理，避免整帧报废）
          _buf.add(b);
        }
        continue;
      }
      _buf.add(b);
    }
    return out;
  }

  KissFrame? _finish() {
    if (_buf.isEmpty) return null;
    final head = _buf[0];
    final port = (head >> 4) & 0x0F;
    final cmd = head & 0x0F;
    return KissFrame(port, cmd, _buf.sublist(1));
  }

  void reset() {
    _buf.clear();
    _inFrame = false;
    _escaped = false;
  }
}

/// AX.25 编解码（仅 UI 帧 —— APRS 只用它）
class Ax25 {
  Ax25._();

  /// 解析 `CALL-SSID`，返回 (呼号大写, SSID)
  static (String, int) splitCall(String raw) {
    final s = raw.trim().toUpperCase();
    final i = s.lastIndexOf('-');
    if (i <= 0) return (s, 0);
    final ssid = int.tryParse(s.substring(i + 1));
    if (ssid == null) return (s, 0);
    return (s.substring(0, i), ssid.clamp(0, 15));
  }

  /// 单个地址字段 7 字节：呼号 6 字节（左移 1 位，空格补齐）+ SSID 字节
  ///
  /// [last] 为 true 时 SSID 字节最低位置 1，标记地址字段结束。
  ///
  /// SSID 字节的位布局（AX.25 v2.2 §2.2.6，位序写作 `C R R SSID 0`）：
  ///   * bit0 = 扩展位（[last]）
  ///   * bit1-4 = SSID
  ///   * bit5-6 = 保留位，未使用时置 1（即 0x60）
  ///   * bit7 = C 位（命令/响应）
  ///
  /// **C 位必须按角色区分**（[dest]）：direwolf 的组帧代码写得很明确
  /// （`src/ax25_pad.c:428,431`）——
  ///   目的地址 `SSID_H_MASK|SSID_RR_MASK` = 0x80|0x60 = **0xE0**
  ///   源地址/中继 `SSID_RR_MASK`        = 0x60
  /// 我们此前对所有地址都写 0x60（目的 C 位为 0），与参考实现不一致。
  /// direwolf 的注释也坦承「APRS 里四种组合都有人用、大家都忽略它」，
  /// 所以这是**兼容性对齐**而不是故障根因 —— 但既然规范与参考实现都写 1，
  /// 就没有理由继续偏离。
  static List<int> address(String callSsid,
      {required bool last, bool dest = false}) {
    final (call, ssid) = splitCall(callSsid);
    final out = <int>[];
    final padded = call.padRight(6).substring(0, 6);
    for (var i = 0; i < 6; i++) {
      out.add((padded.codeUnitAt(i) << 1) & 0xFF);
    }
    final cr = dest ? 0x80 : 0x00; // C 位：目的 = 1，源/中继 = 0
    out.add(cr | 0x60 | ((ssid & 0x0F) << 1) | (last ? 1 : 0));
    return out;
  }

  /// 解出一个地址字段，返回 (呼号, SSID, 是否结束)
  static (String, int, bool) readAddress(List<int> b, int offset) {
    final sb = StringBuffer();
    for (var i = 0; i < 6; i++) {
      sb.writeCharCode((b[offset + i] >> 1) & 0x7F);
    }
    final ssidByte = b[offset + 6];
    final ssid = (ssidByte >> 1) & 0x0F;
    final last = (ssidByte & 0x01) == 1;
    var call = sb.toString().trim();
    if (call.isEmpty) call = '?';
    return (call, ssid, last);
  }

  /// 把 TNC2 文本 `SRC>DEST,DIGI1,DIGI2:info` 编成 AX.25 UI 帧
  ///
  /// 返回 null 表示格式不合法（缺少 `>` 或 `:`）。
  static List<int>? encodeTnc2(String tnc2) {
    final gt = tnc2.indexOf('>');
    if (gt <= 0) return null;
    final src = tnc2.substring(0, gt).trim();
    final rest = tnc2.substring(gt + 1);
    final colon = rest.indexOf(':');
    if (colon < 0) return null;
    final header = rest.substring(0, colon);
    final info = rest.substring(colon + 1);
    if (src.isEmpty) return null;
    final parts = header
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s != '*')
        .toList();
    if (parts.isEmpty) return null;
    final dest = parts.first;
    // 过滤 TCPIP* / TCPXX* 之类仅 APRS-IS 才有意义的路径项，
    // 它们出现在射频上会成为无效中继（且部分 TNC 会拒发）。
    final digis = parts
        .skip(1)
        .where((d) => !d.toUpperCase().startsWith('TCPIP') && !d.toUpperCase().startsWith('TCPXX'))
        .toList();
    return encodeUi(source: src, dest: dest, digis: digis, info: info);
  }

  /// 组 AX.25 UI 帧
  static List<int> encodeUi({
    required String source,
    required String dest,
    List<String> digis = const [],
    required String info,
  }) {
    final out = <int>[];
    out.addAll(address(dest, last: false, dest: true));
    out.addAll(address(source, last: digis.isEmpty));
    for (var i = 0; i < digis.length; i++) {
      // 中继是否「已使用」由 TNC/中继自己标记，这里统一发未使用
      out.addAll(address(digis[i], last: i == digis.length - 1));
    }
    out.add(0x03); // UI 帧
    out.add(0xF0); // PID：无连接信息
    // APRS 信息字段以 ASCII 为主；非 ASCII 字符按 **UTF-8** 字节发出，
    // 与接收侧（`aprs_parse` 先试 UTF-8、失败回退 GBK）以及 APRS-IS
    // 通路（Dart Socket.write 默认 UTF-8）保持一致，否则中文消息
    // 在射频上会变成乱码。
    out.addAll(utf8.encode(info));
    return out;
  }

  /// 把一帧 AX.25 UI 还原成 TNC2 文本；非 UI 帧或格式异常返回 null
  static String? decodeToTnc2(List<int> frame) {
    if (frame.length < 16) return null;
    var off = 0;
    final (dest, _, destLast) = readAddress(frame, off);
    off += 7;
    if (off + 7 > frame.length) return null;
    final (src, srcSsid, srcLast) = readAddress(frame, off);
    off += 7;
    final digis = <String>[];
    var last = destLast || srcLast;
    // 最多 8 个中继地址
    while (!last && off + 7 <= frame.length && digis.length < 8) {
      final (dCall, dSsid, dLast) = readAddress(frame, off);
      off += 7;
      last = dLast;
      var s = dCall;
      if (dSsid > 0) s = '$s-$dSsid';
      if (!s.contains('*')) s = '$s*';
      digis.add(s);
    }
    if (off + 2 > frame.length) return null;
    final ctrl = frame[off];
    off++;
    // 只认 UI 帧（0x03）与 UI 的 PF 变体
    if ((ctrl & 0xEF) != 0x03) return null;
    if (off < frame.length) off++; // 跳过 PID
    if (off > frame.length) return null;
    final bytes = frame.sublist(off);
    final info = _decodeInfo(bytes);
    final srcFull = srcSsid > 0 ? '$src-$srcSsid' : src;
    final head = digis.isEmpty ? '$srcFull>$dest' : '$srcFull>$dest,${digis.join(',')}';
    return '$head:$info';
  }

  /// 信息字段解码：先 UTF-8，非法字节序列则按原字节字面量保留
  /// （不做 GBK 猜测 —— KISS 层只负责还原字节，字符集判断留给上层）
  static String _decodeInfo(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      // 宽容解码：把非法字节按 Latin-1 映射保留，至少不丢信息
      return String.fromCharCodes(bytes);
    }
  }
}
