import 'dart:convert';
import 'dart:io';

import 'pinned_http.dart';

/// ─── 联网校验一个已下载的安装包 ───
///
/// 用户要的口径：「校验是联网针对版本号校验值，该版本号是否与仓库 sha 和
/// 签名是否一样，如果没有联网，提示无法校验版本号是否一致」。
///
/// 所以这里做三件事，一件都不能省：
///
///   1. **版本号**：包里的 `versionName` 必须等于仓库这一版的 tag；
///   2. **摘要**：包里这个文件的 SHA-256 必须等于仓库那份资产的 `digest`
///      （GitHub 会给每个 release 资产算 `sha256:…`，它才是「仓库里那一份」）；
///   3. **签名**：包的签名证书必须与已装在本机的这一份一致 —— 这一条纯本地就能比，
///      联网那一步只是把「该是什么」拿到手。
///
/// 三道里任何一道对不上，就如实说清是哪一道；**没联网就说没联网**，
/// 不要拿「签名一致」糊弄成「校验通过」—— 签名一致只说明包是同一个人签的，
/// 不说明它是这一次发布的那一个。
///
/// 桌面端没有可校验的签名，也不走这条路（[UpdateInstaller.isAndroid] 为假时
/// 调用方直接不查）。
enum UpdateVerifyState {
  /// 正在查。
  checking,

  /// 三道全对。
  ok,

  /// 没联网 / 接口不通：版本号到底对不对，这一次说不了。
  offline,

  /// 仓库里查不到这一版（或是这条渠道没有这个接口）。
  notFound,

  /// 包里的版本号与仓库这一版不一致。
  versionMismatch,

  /// 文件摘要与仓库里那份不一致（被换过 / 传坏了 / 镜像塞了别的包）。
  shaMismatch,

  /// 签名与本机不一致（不是同一个证书签的）。
  sigMismatch,

  /// 读不出这个包（文件坏了 / 系统接口失败）。
  unknown,
}

class UpdateVerifyReport {
  final UpdateVerifyState state;

  /// 可展示的补充（比如两边的版本号、摘要前几位）。空串表示没有。
  final String detail;

  const UpdateVerifyReport(this.state, [this.detail = '']);

  static const UpdateVerifyReport checking =
      UpdateVerifyReport(UpdateVerifyState.checking);

  bool get ok => state == UpdateVerifyState.ok;
}

/// 版本号归一：`v2.2.3` 与 `2.2.3` 是同一版。
String normalizeVersionTag(String tag) =>
    tag.trim().replaceFirst(RegExp('^[vV]'), '');

/// 纯比较：把「本机读到的包」与「仓库里那一版」对一遍。
///
/// 单独一个函数是为了能不联网也能测（见 `test/update_verify_test.dart`）。
UpdateVerifyReport judgeUpdatePackage({
  required Map<String, dynamic> local,
  required String ownSignature,
  required String packageName,
  required String tag,
  required String assetDigest,
}) {
  final rawName = (local['versionName'] ?? '').toString();
  if (rawName.isEmpty) return const UpdateVerifyReport(UpdateVerifyState.unknown);
  final want = normalizeVersionTag(tag);
  if (want.isNotEmpty && normalizeVersionTag(rawName) != want) {
    return UpdateVerifyReport(
        UpdateVerifyState.versionMismatch, '$rawName / $want');
  }
  final pkg = (local['package'] ?? '').toString();
  if (packageName.isNotEmpty && pkg.isNotEmpty && pkg != packageName) {
    return UpdateVerifyReport(UpdateVerifyState.sigMismatch, pkg);
  }
  final sig = (local['sig'] ?? '').toString();
  if (sig.isEmpty || ownSignature.isEmpty) {
    // 读不出签名：这个包说不清是谁签的，也不等于「签名不对」。
    return const UpdateVerifyReport(UpdateVerifyState.unknown);
  }
  if (sig != ownSignature) {
    return const UpdateVerifyReport(UpdateVerifyState.sigMismatch);
  }
  // 仓库没给摘要（老接口 / 别的渠道）：版本号与签名都对了，但摘要这一道
  // 没法算 —— 明说「摘要拿不到」，不冒充三道全过。
  final wantSha = _digestOf(assetDigest);
  if (wantSha.isEmpty) {
    return const UpdateVerifyReport(UpdateVerifyState.notFound);
  }
  final gotSha = (local['sha256'] ?? '').toString().toLowerCase();
  if (gotSha.isEmpty) return const UpdateVerifyReport(UpdateVerifyState.unknown);
  if (gotSha != wantSha) {
    final head = gotSha.length > 12 ? '${gotSha.substring(0, 12)}…' : gotSha;
    return UpdateVerifyReport(UpdateVerifyState.shaMismatch, head);
  }
  return const UpdateVerifyReport(UpdateVerifyState.ok);
}

/// `sha256:abcd…` → `abcd…`（小写）。拿不到就空串。
String _digestOf(String raw) {
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) return '';
  if (s.startsWith('sha256:')) s = s.substring(7);
  return s;
}

/// 读一次的结果：拿到的那一版（可能没有）+ 有没有真的连上。
///
/// 「没连上」与「连上了但这一版查不到」必须分开：前者是没网，后者是这条渠道
/// 根本没有 releases 接口（阿里云 OSS 那两条就是这样）。两种情况提示的话不一样，
/// 不能都写成「没有联网」。
class ReleaseFetch {
  final Map<String, dynamic>? release;

  /// 至少有一次请求真的拿到了 HTTP 响应（哪怕 404）。
  final bool reachable;

  const ReleaseFetch(this.release, {required this.reachable});

  static const ReleaseFetch unreachable = ReleaseFetch(null, reachable: false);
}

/// 从仓库读这一版的信息。没网返回 [ReleaseFetch.unreachable]；
/// 连上了但查不到这一版时 `release` 为 null、`reachable` 为真。
///
/// 各条渠道都是 GitHub 兼容的 REST：`<base>/<owner>/<repo>/releases/tags/<tag>`。
/// 自建镜像走钉扎 context（见 `lib/pinned_http.dart`）。
Future<ReleaseFetch> fetchRelease({
  required String apiBase,
  required String owner,
  required String repo,
  required String tag,
  required String userAgent,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final want = normalizeVersionTag(tag);
  if (apiBase.isEmpty || want.isEmpty) return ReleaseFetch.unreachable;
  var reachable = false;
  // 有的渠道 tag 带 v、有的不带：先按 v 版问，再按原样问一次。
  for (final candidate in ['v$want', want]) {
    final url = '$apiBase/$owner/$repo/releases/tags/$candidate';
    try {
      final got = await _getJson(url, userAgent, timeout);
      if (got.status > 0) reachable = true;
      if (got.json != null) return ReleaseFetch(got.json, reachable: true);
    } catch (_) {
      // 网络层失败：继续试下一个写法（两种都失败就是没网）
    }
  }
  return ReleaseFetch(null, reachable: reachable);
}

/// 只要那一版本身（拿不到返回 null）。上面的 [fetchRelease] 是完整版。
Future<Map<String, dynamic>?> fetchReleaseByTag({
  required String apiBase,
  required String owner,
  required String repo,
  required String tag,
  required String userAgent,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final got = await fetchRelease(
    apiBase: apiBase,
    owner: owner,
    repo: repo,
    tag: tag,
    userAgent: userAgent,
    timeout: timeout,
  );
  return got.release;
}

class _JsonGot {
  /// 0 = 连不上（抛异常的那条路）。
  final int status;
  final Map<String, dynamic>? json;

  const _JsonGot(this.status, this.json);
}

Future<_JsonGot> _getJson(
    String url, String userAgent, Duration timeout) async {
  final client = HttpClient(context: pinnedContextFor(url))
    ..connectionTimeout = timeout;
  try {
    final req = await client.getUrl(Uri.parse(url)).timeout(timeout);
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    req.headers.set(HttpHeaders.userAgentHeader, userAgent);
    final resp = await req.close().timeout(timeout);
    // 不管什么状态码，正文都要读完再关：手机上一个没读的 socket 会一直挂着。
    final body = await resp.transform(utf8.decoder).join().timeout(timeout);
    if (resp.statusCode != 200) return _JsonGot(resp.statusCode, null);
    final data = jsonDecode(body);
    if (data is Map) {
      return _JsonGot(resp.statusCode,
          data.map((k, v) => MapEntry(k.toString(), v)));
    }
    return _JsonGot(resp.statusCode, null);
  } finally {
    client.close(force: true);
  }
}

/// 走完整的一遍：读仓库 → 比版本号 / 摘要 / 签名。
///
/// [assetName] 是本机这个包的文件名，用它去仓库那份资产列表里对号；
/// 对不上号（改名了）就退回「第一个 .apk」，仍然按摘要比。
Future<UpdateVerifyReport> verifyUpdatePackageOnline({
  required String apiBase,
  required String owner,
  required String repo,
  required String tag,
  required String assetName,
  required Map<String, dynamic>? local,
  required String ownSignature,
  required String packageName,
  required String userAgent,
  Duration timeout = const Duration(seconds: 8),
}) async {
  if (local == null) return const UpdateVerifyReport(UpdateVerifyState.unknown);
  final got = await fetchRelease(
    apiBase: apiBase,
    owner: owner,
    repo: repo,
    tag: tag,
    userAgent: userAgent,
    timeout: timeout,
  );
  final release = got.release;
  if (release == null) {
    // 连不上 = 没联网；连上了却查不到 = 这条渠道没有 releases 接口，
    // 两句话不一样，别把「没网」安在阿里云 OSS 那两条渠道头上。
    return UpdateVerifyReport(got.reachable
        ? UpdateVerifyState.notFound
        : UpdateVerifyState.offline);
  }
  final digest = assetDigestOf(release, assetName);
  if (digest.isEmpty) return const UpdateVerifyReport(UpdateVerifyState.notFound);
  return judgeUpdatePackage(
    local: local,
    ownSignature: ownSignature,
    packageName: packageName,
    tag: (release['tag_name'] ?? tag).toString(),
    assetDigest: digest,
  );
}

/// 从一版 release 里取某个资产的 `digest`（`sha256:…`）。取不到返回空串。
String assetDigestOf(Map<String, dynamic> release, String assetName) {
  final assets = release['assets'];
  if (assets is! List) return '';
  Map? hit;
  for (final a in assets) {
    if (a is! Map) continue;
    final n = (a['name'] ?? '').toString();
    if (assetName.isNotEmpty && n == assetName) {
      hit = a;
      break;
    }
    // 文件名里可能带目录（桌面端），按 basename 再比一次
    final base = assetName.split(RegExp(r'[/\\]')).last;
    if (hit == null && base.isNotEmpty && n == base) hit = a;
  }
  if (hit == null) {
    // 改名了（比如换了架构后缀）：拿第一个 .apk 当参照，摘要照样能判真假。
    for (final a in assets) {
      if (a is! Map) continue;
      if ((a['name'] ?? '').toString().toLowerCase().endsWith('.apk')) {
        hit = a;
        break;
      }
    }
  }
  if (hit == null) return '';
  final d = (hit['digest'] ?? '').toString();
  return _digestOf(d).isEmpty ? '' : d;
}
