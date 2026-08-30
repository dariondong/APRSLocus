import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'aprs_base.dart';
import '../state.dart';

/// Web 平台：WebSocket 连接（需 WebSocket 兼容网关）
class AprsWeb extends AprsConnector {
  WebSocketChannel? _ch;

  String get targetUrl {
    if (wsUrl != null && wsUrl!.trim().isNotEmpty) return wsUrl!.trim();
    return 'wss://$server:$port';
  }

  @override
  Future<bool> connect() async {
    try {
      final url = Uri.parse(targetUrl);
      final ch = WebSocketChannel.connect(url);
      await ch.ready;
      _ch = ch;
      ch.sink.add('user $callsign pass $passcode vers APRSlocus ${AppState.appVersion}'
          ' filter $filter');
      ch.stream.listen(
        (d) {
          rxCount++;
          onLine?.call(d.toString());
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
    if (connected && _ch != null) {
      try {
        _ch!.sink.add(raw);
      } catch (_) {}
    }
  }

  void _handleGone() {
    connected = false;
    try {
      _ch?.sink.close();
    } catch (_) {}
    _ch = null;
    onDisconnected?.call();
  }

  @override
  void disconnect() {
    connected = false;
    try {
      _ch?.sink.close();
    } catch (_) {}
    _ch = null;
  }
}

AprsConnector createAprs() => AprsWeb();
