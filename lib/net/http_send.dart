// HTTP 发送工厂（条件导入）
//   - io 平台：dart:io HttpClient
//   - Web：明确不支持（自定义翻译接口受 CORS 限制）
import 'http_send_io.dart'
    if (dart.library.html) 'http_send_web.dart' as impl;

export 'http_send_io.dart'
    if (dart.library.html) 'http_send_web.dart'
    show HttpStatusError, httpAvailable;

Future<String> httpSend(
  String method,
  Uri uri, {
  Map<String, String>? headers,
  String? body,
  Duration timeout = const Duration(seconds: 20),
}) =>
    impl.httpSend(method, uri, headers: headers, body: body, timeout: timeout);

Future<bool> isHttpAvailable() => impl.httpAvailable();
