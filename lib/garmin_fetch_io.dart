import 'dart:convert';
import 'dart:io';

/// 本平台能不能抓取（io 变体：可以）。
const bool supported = true;

/// 抓取佳明 LiveTrack 分享页（io 变体：Android / Windows / Linux / macOS）。
///
/// 请求头按参考实现照抄（`Accept: text/html` + 常见桌面 UA）：佳明那边对
/// 不带 UA 的脚本请求偶发返回空页/403，而分享页本身是公开的，不需要登录。
/// 超时也必须有 —— 没有超时的 HttpClient 会一直挂着，轮询定时器就废了。
Future<String> httpGetText(String url) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent = 'Mozilla/5.0';
  try {
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.acceptHeader, 'text/html');
    final res = await req.close().timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}');
    }
    return await res.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}
