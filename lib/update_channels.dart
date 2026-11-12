import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// ─── 更新渠道：由官网下发 ───
///
/// 「有哪些渠道、地址是什么、默认哪个、什么顺序」以前全写死在
/// `state.dart` 里，加一条镜像、换一个地址都得发版。
/// 现在这份清单放在官网（`docs/assets/update_channels.json`），客户端启动时
/// 拉一次、缓存起来，6 小时后过期。
///
/// ── 三道保险，让「拉不到」不影响更新 ──
///  1. 拉到过就认缓存，离线也用上次那份；
///  2. 从没拉到过就用 [kFallbackChannels]（与旧硬编码逐字一致）；
///  3. 配置里某一项不合法（没 id、地址不是 http(s)）就跳过它，
///     一条都不剩时整份作废。
///
/// ── 渠道 id 不能改 ──
/// id 会写进用户的设置（`updateChannel`），改了等于把所有人踢回默认；
/// 要下线一条渠道，从清单里拿掉即可（客户端会自动回落到默认那条）。
class UpdateChannel {
  /// 设置里存的那个值，发布后不可改。
  final String id;

  /// 显示名（品牌名，不翻译）。
  final String name;

  /// API 根地址：`<base>/<owner>/<repo>/releases`。
  final String base;

  /// 选择器第二行显示的地址（缺省取 [base] 的主机名）。
  final String host;

  /// 图标名：`public` / `cloud` / `cloud_done` / `server`，认不出用服务器图标。
  final String icon;

  /// 说明文案的 id（本地化文案在 App 里，比如 `qingling`），可空。
  final String hint;

  const UpdateChannel({
    required this.id,
    required this.name,
    required this.base,
    this.host = '',
    this.icon = '',
    this.hint = '',
  });

  String get displayHost => host.isEmpty ? (Uri.tryParse(base)?.host ?? '') : host;
}

/// 拉不到、或从来没拉到过时用的清单：与旧硬编码逐字一致。
const List<UpdateChannel> kFallbackChannels = [
  UpdateChannel(
    id: 'github',
    name: 'GitHub',
    base: 'https://api.github.com/repos',
    host: 'api.github.com',
    icon: 'public',
  ),
  UpdateChannel(
    id: 'gitcode',
    name: 'GitCode',
    base: 'https://api.gitcode.com/api/v5/repos',
    host: 'api.gitcode.com',
    icon: 'cloud',
  ),
  // 自建镜像：自签证书，走钉扎。
  UpdateChannel(
    id: 'qingling',
    name: 'Qingling',
    base: 'https://47.104.251.69/v1/repos',
    host: '47.104.251.69',
    icon: 'server',
    hint: 'qingling',
  ),
  UpdateChannel(
    id: 'aliyun',
    name: 'Aliyun OSS',
    base: 'https://aprslocus.oss-cn-guangzhou.aliyuncs.com',
    host: 'aprslocus.oss-cn-guangzhou.aliyuncs.com',
    icon: 'cloud_done',
  ),
  // 香港节点走 CNAME 自定义域：默认域名会拦 .apk，自定义域不会。
  UpdateChannel(
    id: 'aliyun_hk',
    name: 'Aliyun OSS（香港）',
    base: 'https://aprslocushk.oss.theez.top',
    host: 'aprslocushk.oss.theez.top',
    icon: 'cloud_done',
  ),
];

/// 内置清单的默认渠道。
const String kFallbackChannelId = 'github';

/// 清单最多几条：官网写坏了不至于把选择器刷满屏。
const int kMaxChannels = 8;

/// 解析后的一份渠道清单。
class UpdateChannelConfig {
  final List<UpdateChannel> channels;

  /// 官网指定的默认渠道 id（不在这份清单里时会回退成第一条）。
  final String defaultId;

  const UpdateChannelConfig(this.channels, this.defaultId);

  static const UpdateChannelConfig fallback =
      UpdateChannelConfig(kFallbackChannels, kFallbackChannelId);

  UpdateChannel? byId(String id) {
    for (final c in channels) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 真正的默认 id：官网写错了也不至于没有默认。
  String get resolvedDefault =>
      byId(defaultId) != null ? defaultId : channels.first.id;

  /// 把官网那份文本解析成清单；任何一处不合格就退回 [fallback]。
  static UpdateChannelConfig parse(String? text) {
    if (text == null || text.trim().isEmpty) return fallback;
    try {
      final data = jsonDecode(text);
      final list = parseChannelList(data);
      if (list == null) return fallback;
      var d = '';
      if (data is Map) d = (data['default'] ?? '').toString().trim();
      if (!list.any((c) => c.id == d)) d = list.first.id;
      return UpdateChannelConfig(list, d);
    } catch (_) {
      return fallback;
    }
  }
}

/// 从解出来的 JSON 里读渠道数组：一条都不合法时返回 null。
List<UpdateChannel>? parseChannelList(Object? data) {
  if (data is! Map) return null;
  final raw = data['channels'];
  if (raw is! List) return null;
  final out = <UpdateChannel>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final id = (e['id'] ?? '').toString().trim();
    final base = (e['base'] ?? '').toString().trim().replaceAll(RegExp(r'/+$'), '');
    if (id.isEmpty || id.length > 24) continue;
    final uri = Uri.tryParse(base);
    // 只认 http(s)：别的 scheme 拼出来的地址根本不是 releases 接口。
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) continue;
    if (out.any((c) => c.id == id)) continue; // 重复 id 只认第一条
    final name = (e['name'] ?? '').toString().trim();
    final host = (e['host'] ?? '').toString().trim();
    out.add(UpdateChannel(
      id: id,
      name: name.isEmpty ? id : name,
      base: base,
      host: host.isEmpty ? uri.host : host,
      icon: (e['icon'] ?? '').toString().trim(),
      hint: (e['hint'] ?? '').toString().trim(),
    ));
    if (out.length >= kMaxChannels) break;
  }
  return out.isEmpty ? null : out;
}

/// 官网那份渠道清单的地址（与最低版本、限制名单同一个站点）。
const String kUpdateChannelsUrl =
    'https://aprslocus.theez.top/assets/update_channels.json';

/// 拉一次官网的渠道清单。失败返回 null（调用方保留缓存或内置清单）。
Future<String?> fetchUpdateChannelsJson({
  required String userAgent,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final req = await client
        .getUrl(Uri.parse(kUpdateChannelsUrl))
        .timeout(timeout);
    req.headers.set(HttpHeaders.userAgentHeader, userAgent);
    final resp = await req.close().timeout(timeout);
    if (resp.statusCode != 200) return null;
    return await resp.transform(utf8.decoder).join().timeout(timeout);
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
