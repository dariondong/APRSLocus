import 'dart:async';
import 'dart:typed_data';

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

/// 二进制 GET 兜底：Web 不做离线地图（拿不到本地可写目录存瓦片），
/// 因此这里明确不支持，而不是返回空字节让上层以为「下载成功但图是空的」。
Future<Uint8List> httpGetBytes(
  Uri uri, {
  Map<String, String>? headers,
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
