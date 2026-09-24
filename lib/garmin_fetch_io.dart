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
    // ⚠ `followRedirects` / `maxRedirects` 是 **HttpClientRequest** 上的属性，
    // 不是 HttpClient 上的（写成 `HttpClient()..followRedirects = true` 会直接
    // 编译不过 —— `no setter named 'followRedirects'`）。
    //
    // 这两个必须显式写：**佳明 App 分享的短链（gar.mn/xxx）就是靠 301 跳到
    // livetrack.garmin.com 的长链**。dart:io 默认确实跟随，但显式写出来是为了
    // 让「这条链依赖跳转」这件事在代码里看得见 —— 否则哪天有人关掉它，
    // 表现会是「短链永远抓不到数据」而长链照常，极难归因。
    req
      ..followRedirects = true
      ..maxRedirects = 5;
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
