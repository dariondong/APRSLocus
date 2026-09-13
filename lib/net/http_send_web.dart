import 'dart:async';

/// Web 兜底：本应用桌面/移动端才需要翻译接口，
/// Web 上自定义接口还会受 CORS 限制，故不做实现（返回明确错误而不是静默失败）。
Future<String> httpSend(
  String method,
  Uri uri, {
  Map<String, String>? headers,
  String? body,
  Duration timeout = const Duration(seconds: 20),
}) async {
  throw UnsupportedError('http-unsupported');
}

class HttpStatusError implements Exception {
  final int status;
  final String body;
  HttpStatusError(this.status, this.body);
  @override
  String toString() => 'HTTP $status';
}

Future<bool> httpAvailable() async => false;
