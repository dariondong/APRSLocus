import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 统一的 HTTP 发送（io 平台实现）。
///
/// 抽成独立文件是为了让 `translate.dart` 不直接 import `dart:io` ——
/// 否则 Web 编译会失败。与 `net/aprs*.dart`、`net/tnc*.dart` 同一模式。
Future<String> httpSend(
  String method,
  Uri uri, {
  Map<String, String>? headers,
  String? body,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final req = method == 'GET'
        ? await client.getUrl(uri)
        : await client.postUrl(uri);
    req.headers.set(HttpHeaders.userAgentHeader, 'APRSlocus');
    headers?.forEach((k, v) => req.headers.set(k, v));
    if (body != null && method != 'GET') {
      final bytes = utf8.encode(body);
      req.headers.contentLength = bytes.length;
      req.add(bytes);
    }
    final resp = await req.close().timeout(timeout);
    final text =
        await resp.transform(utf8.decoder).join().timeout(timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpStatusError(resp.statusCode, text);
    }
    return text;
  } finally {
    try {
      client.close(force: true);
    } catch (_) {}
  }
}

/// 非 2xx 响应
class HttpStatusError implements Exception {
  final int status;
  final String body;
  HttpStatusError(this.status, this.body);
  @override
  String toString() => 'HTTP $status';
}

/// 平台是否具备 HTTP 能力（Web 上自定义接口受 CORS 限制，但浏览器 fetch 可用）
Future<bool> httpAvailable() async => true;
