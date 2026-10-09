// 自建交付服务器的证书钉扎（certificate pinning）。
//
// 背景
// ----
// 项目的更新通道里有一条 `qingling`（清零），指向自建的镜像/交付服务器
// （见 `AppState.updateChannelBases`）。那台服务器用的是**自签名证书**，
// 而 Dart 的 `HttpClient` 默认只信任系统 CA —— 直接走 https 会抛
// `HandshakeException: CERTIFICATE_VERIFY_FAILED`。
//
// 两条出路：
//   1. 通道地址用 http（明文）—— 能用，但更新包在传输中可被篡改；
//   2. 把这个自签证书**内置进 App 并只信任它**（本文件的做法）。
//
// 第 2 条比第 1 条安全，而且**不需要域名、不需要备案、不需要购买证书**：
// 证书 CN/SAN 写的是 IP，钉扎也不受公共 CA 规则约束。
//
// ⚠️ 只对这一个主机生效
// --------------------
// `SecurityContext(withTrustedRoots: false)` 表示**不再信任任何公共 CA**。
// 若把它用在 GitHub / GitCode 的请求上，那两条通道会全部握手失败。
// 因此本文件只对 `pinnedHost` 返回钉扎 context，其余主机一律返回 `null`
// （`HttpClient(context: null)` 即默认行为，等价于原来直接 `HttpClient()`）。
//
// 证书有效期 10 年
// ----------------
// 钉扎的固有代价是：**换证书必须发新版 App**。所以签的是 10 年期证书，
// 避免出现「服务端换证书 → 所有客户端突然连不上」。
// 换证书时的步骤：签新证书 → 更新下面的 `_pinnedCertPem` → 发版。
//
// 指纹（SHA-256，可用于与服务器核对是否为同一张证书）：
//   62:FD:84:73:1E:62:4E:5C:60:3F:0E:20:04:C7:31:4B:
//   D7:E6:09:6A:3F:36:E1:2A:68:0A:07:68:4E:D6:F1:2D
//
// 生效期：2026-10-09 → 2036-10-06

import 'dart:convert';
import 'dart:io';

/// 自建交付服务器的主机名（证书 CN/SAN 即此 IP）。
const String pinnedHost = '47.104.251.69';

/// 服务器的自签证书（PEM）。
///
/// 与服务器上 `/opt/aprslocuslink/data/certs/fullchain.pem` 是同一份内容。
/// 修改它等同换证书 —— 必须同步发新版 App，否则客户端会拒绝连接。
const String _pinnedCertPem = '''
-----BEGIN CERTIFICATE-----
MIIB0DCCAXWgAwIBAgIUJUr75FpS/of9KNqwtgWXQdkL39QwCgYIKoZIzj0EAwIw
GDEWMBQGA1UEAwwNNDcuMTA0LjI1MS42OTAeFw0yNjEwMDkxODE4MjdaFw0zNjEw
MDYxODE4MjdaMBgxFjAUBgNVBAMMDTQ3LjEwNC4yNTEuNjkwWTATBgcqhkjOPQIB
BggqhkjOPQMBBwNCAARGzwlVC/tNdb/vm5Sp0BoEPS3TDAo6ZSueyJdOtG5I//VN
TlOvs0J9Ai4fJqoNM0x/sM0KI/xEJvAjDgg4NPK9o4GcMIGZMB0GA1UdDgQWBBRd
ydYP/P8FNqVhGKAjKT36xe/YvTAfBgNVHSMEGDAWgBRdydYP/P8FNqVhGKAjKT36
xe/YvTAkBgNVHREEHTAbhwQvaPtFghNhcHJzbG9jdXNsaW5rLmxvY2FsMAwGA1Ud
EwEB/wQCMAAwDgYDVR0PAQH/BAQDAgWgMBMGA1UdJQQMMAoGCCsGAQUFBwMBMAoG
CCqGSM49BAMCA0kAMEYCIQDMjDVSkANuhexc+GYVLprLLxDNqWAZRwqB4T4WNy4U
wQIhANeOEHd4LwWuoKPNcgeTHgWAObjr/90Wa0+mpSJl3nip
-----END CERTIFICATE-----
''';

SecurityContext? _pinnedContext;

/// 只信任钉扎证书的 `SecurityContext`（惰性构建，全进程复用一个）。
SecurityContext get _pinned {
  final cached = _pinnedContext;
  if (cached != null) return cached;
  final ctx = SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificatesBytes(utf8.encode(_pinnedCertPem));
  _pinnedContext = ctx;
  return ctx;
}

/// 该地址是否属于自建交付服务器。
bool isPinnedHost(String url) {
  final host = Uri.tryParse(url)?.host;
  return host == pinnedHost;
}

/// 按目标主机返回合适的 `SecurityContext`。
///
/// * 目标是自建服务器 → 返回钉扎 context（只信任内置的那张证书）；
/// * 其它（GitHub / GitCode）→ 返回 `null`，让 `HttpClient` 用默认行为。
///
/// 用法：`HttpClient(context: pinnedContextFor(url))`。
SecurityContext? pinnedContextFor(String url) => isPinnedHost(url) ? _pinned : null;

/// 便捷构造：按 URL 决定是否钉扎的 `HttpClient`。
///
/// 三处发请求的地方都应改用这个，避免漏掉某一处后
/// 只在某一条路径上报证书错误（表现是「更新页能查到、下载却失败」）。
HttpClient pinnedHttpClientFor(String url) => HttpClient(context: pinnedContextFor(url));
