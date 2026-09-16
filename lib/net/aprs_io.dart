import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:gbk_codec/gbk_codec.dart';
import 'aprs_base.dart';
import '../state.dart';

/// 桌面平台：dart:io Socket 直连 APRS-IS TCP 14580（标准协议）
class AprsIo extends AprsConnector {
  Socket? _sock;
  StreamSubscription<List<int>>? _sub;
  final List<int> _buf = [];

  /// 按行解码：先按 UTF-8，失败回退 GBK（兼容中文 APRS 消息）
  static String _decodeLine(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      try {
        return gbk.decode(bytes);
      } catch (_) {
        return utf8.decode(bytes, allowMalformed: true);
      }
    }
  }

  @override
  Future<bool> connect() async {
    // ⚠️ 先**静默**收掉上一次的连接（不触发 onDisconnected）。
    //
    // 为什么必须有：下面的 `_sock = sock` / `_sub = sock.listen(...)` 会
    // **直接覆盖**旧引用。若不先收掉旧连接，它就成了「孤儿」—— 引用没了，
    // 谁也再关不掉它，而它**仍会继续把数据喂给 onLine**。
    //
    // 后果是**累积性**的：每多一次重复连接就多一个孤儿 socket，
    // 于是同一条报文被重复处理 N 次，N 随时间增长 → 越用越卡、内存上涨。
    //
    // 触发条件很常见：只要有一条已启用的链路始终连不上（未绑定设备、
    // 设备未开机、被设备冲突拦下…），重连定时器就会反复调用本方法。
    _silentTeardown();
    // 旧连接残留的半行不能带进新连接（否则新连接的第一条报文会被拼错）
    _buf.clear();
    try {
      final sock = await Socket.connect(
        server,
        port,
        timeout: const Duration(seconds: 10),
      );
      _sock = sock;
      sock.setOption(SocketOption.tcpNoDelay, true);
      sock.write('user $callsign pass $passcode vers APRSlocus ${AppState.appVersion}'
          ' filter $filter\r\n');
      _sub = sock.listen(
        (data) {
          _buf.addAll(data);
          // 逐行解析（可能跨多个数据块，UTF-8 多字节字符会被完整保留）
          while (true) {
            final idx = _buf.indexOf(10); // '\n'
            if (idx < 0) break;
            final lineBytes = _buf.sublist(0, idx);
            _buf.removeRange(0, idx + 1);
            final line = _decodeLine(lineBytes).trimRight();
            if (line.isEmpty) continue;
            rxCount++;
            onLine?.call(line);
          }
        },
        onError: (_) => _handleGone(),
        onDone: () => _handleGone(),
      );
      connected = true;
      return true;
    } catch (_) {
      _handleGone();
      return false;
    }
  }

  @override
  void send(String raw) {
    try {
      _sock?.write('$raw\r\n');
    } catch (_) {}
  }

  /// 静默收掉当前连接：清理资源但**不**触发 onDisconnected。
  ///
  /// 与 [_handleGone] 的区别：那个会回调 onDisconnected（用于「链路意外
  /// 断开」，上层据此排重连）；在 connect() 内部调用它会误报一次断开、
  /// 甚至再排一次重连。
  void _silentTeardown() {
    try {
      _sub?.cancel();
    } catch (_) {}
    _sub = null;
    try {
      _sock?.destroy();
    } catch (_) {}
    _sock = null;
  }

  void _handleGone() {
    connected = false;
    try {
      _sub?.cancel();
    } catch (_) {}
    _sub = null;
    try {
      _sock?.destroy();
    } catch (_) {}
    _sock = null;
    onDisconnected?.call();
  }

  @override
  void disconnect() => _handleGone();
}

AprsConnector createAprs() => AprsIo();
