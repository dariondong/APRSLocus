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
