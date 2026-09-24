/// 本平台能不能抓取（Web 变体：**不能**，浏览器跨域）。
const bool supported = false;

/// 抓取佳明 LiveTrack 分享页（Web 变体）。
///
/// Web 上没有 dart:io，而且佳明的分享页**不返回 CORS 头**，浏览器里 fetch
/// 一定会被拦。与其让用户看到一个莫名其妙的网络错误，不如直说不支持，
/// 并引导他用 Android / Windows 版（那里是原生请求，没有同源限制）。
Future<String> httpGetText(String url) async {
  throw UnsupportedError('web-unsupported');
}
