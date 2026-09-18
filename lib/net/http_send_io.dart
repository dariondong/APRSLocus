import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

/// 二进制 GET（地图瓦片下载用）。
///
/// 为什么必须与 [httpSend] 分开：后者把响应体按 utf8 解码成 String，
/// 对 PNG/JPEG 会直接抛 FormatException —— 瓦片下载需要的是原始字节。
///
/// 非 2xx 抛 [HttpStatusError]（调用方靠 status 区分 404「这块瓦片没有」
/// 与 429/503「被限流」，前者不该重试、后者该退避）。
Future<Uint8List> httpGetBytes(
  Uri uri, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final req = await _tileConn.getUrl(uri);
  // 每次请求都重新设：共享 client 的 defaultHeaders 会被并发请求互相覆盖
  req.headers.set(HttpHeaders.userAgentHeader, 'APRSLocus');
  headers?.forEach((k, v) => req.headers.set(k, v));
  final resp = await req.close().timeout(timeout);
  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    // 错误响应体很小，读出来仅为日志/诊断，失败也无所谓
    String body = '';
    try {
      body = await resp.transform(utf8.decoder).join().timeout(timeout);
    } catch (_) {}
    throw HttpStatusError(resp.statusCode, body);
  }
  final bytes = <int>[];
  await for (final chunk in resp) {
    bytes.addAll(chunk);
  }
  return Uint8List.fromList(bytes);
}

/// 瓦片请求共享的 HttpClient。
///
/// 必须共享：地图平移一屏要取几十张瓦片，每张都 new 一个 HttpClient 会
/// 变成「几十次 TLS 握手」—— 首字节延迟从毫秒级掉到百毫秒级，
/// 表现就是「地图滑一下要等半天才清晰」。共享后会复用连接。
HttpClient? _tileClient;

HttpClient get _tileConn {
  var c = _tileClient;
  if (c == null) {
    c = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 15)
      ..maxConnectionsPerHost = 8;
    _tileClient = c;
  }
  return c;
}

/// 平台是否具备 HTTP 能力（Web 上自定义接口受 CORS 限制，但浏览器 fetch 可用）
Future<bool> httpAvailable() async => true;
