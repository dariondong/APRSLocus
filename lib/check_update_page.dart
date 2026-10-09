import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'device_abi.dart';
import 'theme.dart';
import 'update_download.dart';
import 'update_packages.dart';
import 'state.dart';
import 'widgets.dart';
import 'material.dart';

/// GitCode Release 数据模型
class _ReleaseInfo {
  final String tagName;
  final String name;
  final String body;
  final bool prerelease;
  final List<Map<String, dynamic>> assets;

  _ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.body,
    required this.prerelease,
    required this.assets,
  });

  /// 按平台获取安装包下载信息
  /// [isWindows] 为 true 时优先 .exe，其次 .zip/.msi；否则用 .apk
  Map<String, dynamic>? assetFor(bool isWindows) {
    if (isWindows) {
      const exts = ['.exe', '.zip', '.msi'];
      for (final ext in exts) {
        for (final a in assets) {
          final n = (a['name'] ?? '').toString().toLowerCase();
          if (n.endsWith(ext)) return a;
        }
      }
      return null;
    }
    // 安卓（及其它非 Windows 平台）：**按本机 CPU 架构挑对应的包**。
    //
    // 架构不对的包装不上（Android 报 ABI 不匹配），而「该下哪个」这件事
    // 不该让用户判断 —— 32 位老机型自动拿到 32 位包，模拟器自动拿到 x86_64。
    // 认不出架构时回退到「列表里第一个 .apk」（分架构之前的行为）。
    // 规则本体与守卫都在 lib/update_packages.dart。
    return pickUpdateAssetFor(assets, deviceAbi());
  }
  String assetNameFor(bool isWindows) {
    final a = assetFor(isWindows);
    if (a != null) return (a['name'] ?? '').toString();
    return isWindows ? 'Windows 安装包' : 'APK 安装包';
  }

  int assetSizeFor(bool isWindows) {
    final a = assetFor(isWindows);
    return a == null ? 0 : sizeOf(a);
  }

  String? assetUrlFor(bool isWindows) {
    final a = assetFor(isWindows);
    if (a == null) return null;
    return urlOf(a);
  }

  /// 某个资产的下载地址（兼容 GitHub / GitCode 不同字段名）。
  static String? urlOf(Map<String, dynamic> a) {
    for (final k in const ['browser_download_url', 'download_url', 'url']) {
      final v = a[k]?.toString();
      if (v != null && v.isNotEmpty && !v.endsWith('{?path}')) return v;
    }
    return null;
  }

  /// 某个资产的字节数。
  static int sizeOf(Map<String, dynamic> a) {
    final s = a['size'];
    return s is num ? s.toInt() : 0;
  }
}

/// 更新日志正文：**默认折叠**（issue #20：「有时候日志很长的，就很难看」）。
///
/// 一版日志常常几十行，整段铺开会把「立即下载」挤出屏幕 —— 而用户第一眼要的是
/// 「这一版改了什么、要不要升」，不是把几十行逐字读完。所以先露前
/// [_CollapsibleNotes.collapsedLines] 行，想细看再点「展开」。
///
/// 按**行**而不是按字符截：Markdown 的段落/列表都靠换行，按字符切会把半行标题
/// 或者一个列表项切两半，看起来像排版坏了。
class _CollapsibleNotes extends StatefulWidget {
  final String text;
  const _CollapsibleNotes(this.text);

  static const int collapsedLines = 8;

  @override
  State<_CollapsibleNotes> createState() => _CollapsibleNotesState();
}

class _CollapsibleNotesState extends State<_CollapsibleNotes> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lines = widget.text.split('\n');
    final long = lines.length > _CollapsibleNotes.collapsedLines;
    final shown = (!_open && long)
        ? lines.take(_CollapsibleNotes.collapsedLines).join('\n')
        : widget.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(shown, style: ts(13, c: C.slate, h: 1.7)),
        if (long)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _open ? s.collapseNotes : s.expandNotes,
                    style: ts(12, c: C.blue, w: FontWeight.w700),
                  ),
                  Icon(
                    _open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: C.blue,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 检查更新页面
class CheckUpdatePage extends StatefulWidget {
  final AppState state;
  const CheckUpdatePage({super.key, required this.state});
  @override
  State<CheckUpdatePage> createState() => _CheckUpdatePageState();
}

class _CheckUpdatePageState extends State<CheckUpdatePage>
    with SingleTickerProviderStateMixin {
  static const _repoOwner = 'DarionDong';
  static const _repoName = 'APRSLocus';
  static const _installerChannel = MethodChannel('com.aprslocus/installer');

  /// 顶部英雄卡上的「扫光」动画（一条柔光带循环掠过）。
  /// 纯装饰，只为「更高级」的观感，不参与任何逻辑。
  late final AnimationController _sheen;

  /// 当前更新渠道对应的 API 地址。
  ///
  /// 已集中到 `AppState.updateBaseFor` —— 这里与 update_prompt.dart 原本各写
  /// 一份相同的三元表达式，新增渠道时极易只改一处（两处不一致的表现是
  /// 「更新页能查到新版、启动提示查不到」这种很难复现的问题）。
  String get _apiBase => AppState.updateBaseFor(widget.state.updateChannel);

  bool _checking = false;
  bool _hasError = false;
  String _errorMsg = '';
  _ReleaseInfo? _latest;
  List<_ReleaseInfo> _allReleases = [];
  bool _isNewer = false;
  bool _latestHasAsset = false; // 最新版本是否有当前平台安装包
  bool _moreOpen = false; // 更多版本折叠

  // ── 下载相关：**状态在 UpdateDownloader 单例里**（issue #22-5 后台下载）──
  //
  // 页面只是订阅者，所以这几个名字都改成 getter 转发 —— 下面所有引用它们的
  // 代码一行都不用动，而「离开页面→回来」天然就是连续的（状态不随页面销毁）。
  final _dl = UpdateDownloader.instance;

  /// 正在下载的版本 tag；null = 没在下载
  String? get _downloadingTag => _dl.running ? _dl.tag : null;
  double get _progress => _dl.progress;
  String get _dlStatus => _dl.statusText;
  bool get _dlError => _dl.error != null;

  /// 已下载到本地的安装包（页面自己扫出来的那份）
  String? _downloadedPath;
  String? _downloadedTag; // 实际下载成功的版本

  /// 已经弹过「下载完成」对话框的序号（见 UpdateDownloader.doneSeq）
  int _doneSeqSeen = 0;

  // 本地已下载的全部安装包（按版本会累积多个，用于"删除全部"）
  List<File> _localPackages = [];

  /// 两个 tag 是否指向**同一版本**（比较时忽略开头的 `v`）。
  ///
  /// 为什么不能直接比字符串：下载卡片里的 `_downloadedTag` 是从**文件名**
  /// 里抠出来的（`APRSLocus_2.0.5.apk` → `2.0.5`），而 API 给的
  /// `_latest.tagName` 是 `v2.0.5` —— 直接比永远不相等，于是「已下载」
  /// 判断永远不成立、下载按钮永远不消（issue #13）。
  static bool _sameVersion(String? a, String? b) {
    if (a == null || b == null) return false;
    String norm(String s) => s.trim().replaceAll(RegExp('^[vV]'), '');
    final na = norm(a);
    return na.isNotEmpty && na == norm(b);
  }

  /// 最新版**已经下载到本地**吗？是的话顶部那张卡片不再收「立即下载」——
  /// 再点也只是下载同一个包，而下面那张「已下载」卡片已经给了安装/重新
  /// 下载/删除的入口。
  bool get _alreadyDownloadedLatest =>
      _downloadedPath != null &&
      _downloadingTag == null &&
      _sameVersion(_downloadedTag, _latest?.tagName);

  @override
  void initState() {
    super.initState();
    _sheen = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _check();
    _findLocalApk();
    // 后台下载（issue #22-5）：任务归单例，页面订阅它 —— 离开页面下载照跑，
    // 回到页面从这里接着显示。
    _dl.bind(widget.state);
    _doneSeqSeen = _dl.doneSeq;
    _dl.addListener(_onDownloadTick);
    // 之前那次「下载完成」的通知已经看过了（用户进这一页了），清掉它。
    if (_dl.path != null) _dl.clearDoneNotice();
  }

  @override
  void dispose() {
    _dl.removeListener(_onDownloadTick);
    _sheen.dispose();
    super.dispose();
  }

  /// 单例有变化：刷新进度，并在**本次**真的下完时弹安装对话框。
  ///
  /// 用 doneSeq 而不是「path != null」判断「刚下完」：后者在「下载完成时页面
  /// 不在、用户后来才进来」的情况下会平白弹一次（用户只是想看看更新页）。
  void _onDownloadTick() {
    if (!mounted) return;
    final done = _dl.doneSeq;
    if (done != _doneSeqSeen) {
      _doneSeqSeen = done;
      final p = _dl.path;
      if (p != null) {
        setState(() {
          _downloadedPath = p;
          _downloadedTag = _dl.doneTag ?? _downloadedTag;
          if (!_localPackages.any((f) => f.path == p)) {
            _localPackages.add(File(p));
          }
        });
        // 弹安装对话框只在**页面还开着**时做；页面不在时靠通知栏那条
        // 「更新包已下载」告诉用户（见 UpdateDownloader._notifyBar）。
        if (defaultTargetPlatform == TargetPlatform.windows) {
          _showWinDialog(p);
        } else {
          _showInstallDialog(p);
        }
      }
      return;
    }
    setState(() {});
  }

  /// 查找已下载的安装包（按平台对应格式）
  Future<void> _findLocalApk() async {
    try {
      final isWin = defaultTargetPlatform == TargetPlatform.windows;
      final dir = await _downloadDir();
      final ext = isWin ? '.exe' : '.apk';
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith(ext))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      _localPackages = files;
      // 优先找带版本号的最新文件（APRSLocus_1.2.5.apk），其次通用名
      for (final f in files) {
        final base = f.uri.pathSegments.last;
        final m = RegExp(r'[Vv]?(\d[\d._a-z]*)').firstMatch(base);
        if (m != null) {
          _downloadedPath = f.path;
          _downloadedTag = m.group(1);
          if (mounted) setState(() {});
          return;
        }
      }
      // 兜底：无版本号匹配则取最新的一个
      if (files.isNotEmpty) {
        _downloadedPath = files.first.path;
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<Directory> _downloadDir() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final docs = await getDownloadsDirectory();
      if (docs != null) return docs;
      final tmp = await getTemporaryDirectory();
      return tmp;
    }
    final d = await getExternalStorageDirectory();
    if (d != null) return d;
    final tmp = await getTemporaryDirectory();
    return tmp;
  }

  /// 切换更新渠道（GitHub / GitCode / Qingling）
  void _switchChannel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MaterialSurface(
        radius: 24,
        topOnly: true,
        child: Container(
          decoration: BoxDecoration(
            color: C.sheetFill,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.of(context).updateChannel,
                  style: ts(16, w: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                _channelOption(
                  'GitHub',
                  'api.github.com',
                  widget.state.updateChannel == 'github',
                  () {
                    widget.state.setUpdateChannel('github');
                    Navigator.pop(context);
                    _check();
                  },
                ),
                const SizedBox(height: 8),
                _channelOption(
                  'GitCode',
                  'api.gitcode.com',
                  widget.state.updateChannel == 'gitcode',
                  () {
                    widget.state.setUpdateChannel('gitcode');
                    Navigator.pop(context);
                    _check();
                  },
                ),
                const SizedBox(height: 8),
                // Qingling（清零）：自建镜像通道。国内直连 GitHub 常失败，
                // 本通道由镜像服务器代取发行版，客户端只访问镜像地址。
                _channelOption(
                  'Qingling',
                  S.of(context).updateChannelQinglingHint,
                  widget.state.updateChannel == 'qingling',
                  () {
                    widget.state.setUpdateChannel('qingling');
                    Navigator.pop(context);
                    _check();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _channelOption(
    String name,
    String api,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? C.blueBg : C.bgSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? C.blue : C.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 18,
              color: selected ? C.blue : C.greyLight,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: ts(
                      13,
                      w: selected ? FontWeight.w700 : FontWeight.w500,
                      c: selected ? C.blue : C.ink,
                    ),
                  ),
                  Text(api, style: ts(10, c: C.grey)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_rounded, size: 18, color: C.blue),
          ],
        ),
      ),
    );
  }

  /// 检查更新
  Future<void> _check() async {
    setState(() {
      _checking = true;
      _hasError = false;
      _errorMsg = '';
    });
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final req = await client
          .getUrl(Uri.parse('$_apiBase/$_repoOwner/$_repoName/releases'))
          .timeout(const Duration(seconds: 20));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set(
        HttpHeaders.userAgentHeader,
        'APRSlocus/${AppState.appVersion}',
      );
      final resp = await req.close().timeout(const Duration(seconds: 20));
      final body = await resp.transform(utf8.decoder).join();
      client.close();

      if (resp.statusCode != 200) {
        throw Exception(S.of(context).serverReturned(resp.statusCode));
      }

      final data = jsonDecode(body);
      if (data is! List) throw Exception(S.of(context).invalidResponseData);

      // 解析所有 release，取最新正式版
      List<_ReleaseInfo> releases = [];
      for (final r in data) {
        if (r is! Map) continue;
        // 统一去掉 tag 的前导 v（如 v1.4.9 → 1.4.9），避免显示两个 v
        final tag = (r['tag_name'] ?? '').toString().replaceFirst(
          RegExp(r'^[Vv]'),
          '',
        );
        releases.add(
          _ReleaseInfo(
            tagName: tag,
            name: (r['name'] ?? (r['tag_name'] ?? '')).toString(),
            body: (r['body'] ?? '').toString(),
            prerelease: r['prerelease'] == true,
            assets: (r['assets'] as List? ?? [])
                .whereType<Map>()
                .cast<Map<String, dynamic>>()
                .toList(),
          ),
        );
      }
      if (releases.isEmpty) throw Exception(S.of(context).noVersionsFound);

      // 过滤正式版，选最新
      final formal = releases.where((r) => !r.prerelease).toList();
      final pool = formal.isNotEmpty ? formal : releases;
      pool.sort((a, b) => _cmpVersion(b.tagName, a.tagName));

      _latest = pool.first;
      _allReleases = List.of(pool);
      _isNewer = _cmpVersion(_latest!.tagName, AppState.appVersion) > 0;
      final isWin = defaultTargetPlatform == TargetPlatform.windows;
      _latestHasAsset = _latest!.assetUrlFor(isWin) != null;

      setState(() {
        _checking = false;
      });
    } catch (e) {
      setState(() {
        _checking = false;
        _hasError = true;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// 版本比较：支持 1.2.5 / 1.2.5.b / v1.0.0
  /// 返回 a.compareTo(b)：正数=a新，负数=b新，0=相同
  /// 规则：1.2.5.b > 1.2.5（字母后缀为修复版），1.2.6 > 1.2.5.b
  int _cmpVersion(String a, String b) {
    final sa = a.replaceAll(RegExp('^v'), '').split(RegExp(r'[._-]'));
    final sb = b.replaceAll(RegExp('^v'), '').split(RegExp(r'[._-]'));
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    final len = sa.length > sb.length ? sa.length : sb.length;
    for (var i = 0; i < len; i++) {
      final hasA = i < sa.length;
      final hasB = i < sb.length;
      if (!hasA && hasB) return -1; // a 已结束，b 有后缀 → b 新
      if (hasA && !hasB) return 1; // b 已结束，a 有后缀 → a 新
      final x = sa[i];
      final y = sb[i];
      final xv = int.tryParse(x);
      final yv = int.tryParse(y);
      if (xv != null && yv != null) {
        if (xv != yv) return xv - yv;
      } else if (xv != null && yv == null) {
        return 1; // 数字段 > 字母段
      } else if (xv == null && yv != null) {
        return -1;
      } else {
        final xl = x.isNotEmpty ? letters.indexOf(x[0]) : -1;
        final yl = y.isNotEmpty ? letters.indexOf(y[0]) : -1;
        if (xl != yl) return xl - yl;
      }
    }
    return 0;
  }

  /// 下载安装包（**委托给 UpdateDownloader**，见 lib/update_download.dart）。
  /// [target] 指定版本，默认最新。
  ///
  /// 原来这一大段逻辑写在本页 State 里，用户一离开页面就没人更新进度、
  /// 完成后还会拿失效的 context 去弹窗。现在只做三件事：校验参数、
  /// 起任务、把用户可能踩到的两种「没反应」说清楚。
  Future<void> _download([_ReleaseInfo? target]) async {
    final rel = target ?? _latest;
    if (rel == null) return;
    final isWin = defaultTargetPlatform == TargetPlatform.windows;
    final url = rel.assetUrlFor(isWin);
    if (url == null) {
      _showSnack(
        isWin ? S.of(context).noWindowsInstaller : S.of(context).noApkInstaller,
      );
      return;
    }
    if (_dl.running) {
      // 同一时刻只跑一条流：用户连点两次不该开出两条下载（也避免两个写句柄
      // 抢同一个文件）。如实说一句，比静默忽略好。
      _showSnack(S.of(context).downloadAlreadyRunning);
      return;
    }
    final tag = rel.tagName;
    // 本地缓存文件名：去掉 tag 的 v 前缀，与 CI 产物命名一致（APRSLocus_1.4.4.apk）
    final ver = tag.replaceAll(RegExp('^v'), '');
    final fileName = isWin ? 'APRSLocus_$ver.exe' : 'APRSLocus_$ver.apk';
    // 不 await：用户要的是「点完就能走」，进度由单例驱动（订阅见 initState）
    unawaited(_dl.start(
      url: url,
      fileName: fileName,
      versionTag: tag,
      dirProvider: _downloadDir,
    ));
  }

  /// 弹出安装确认
  void _showInstallDialog(String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(S.of(context).installApk),
        content: Text(
          S.of(context).androidInstallHelp(path),
          style: ts(13, h: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.blue),
            onPressed: () async {
              Navigator.pop(ctx);
              await _openApk(path);
            },
            child: Text(S.of(context).install),
          ),
        ],
      ),
    );
  }

  /// Windows 下载完成：运行 exe 或打开所在目录
  void _showWinDialog(String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(S.of(context).downloadComplete),
        content: Text(
          S.of(context).windowsInstallHelp(path),
          style: ts(13, h: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openFolder(path);
            },
            child: Text(S.of(context).openContainingFolder),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.blue),
            onPressed: () {
              Navigator.pop(ctx);
              _runExe(path);
            },
            child: Text(S.of(context).runNow),
          ),
        ],
      ),
    );
  }

  /// Windows：启动下载的 exe 安装程序
  void _runExe(String path) {
    try {
      Process.start(path, [], mode: ProcessStartMode.detachedWithStdio);
    } catch (_) {
      _showSnack(S.of(context).cannotRunInstaller);
    }
  }

  /// 打开 APK 触发系统安装（Android 用 FileProvider + ACTION_VIEW）
  Future<void> _openApk(String path) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // 检查是否允许安装未知来源
        bool canInstall = false;
        try {
          canInstall =
              await _installerChannel.invokeMethod<bool>('canRequestInstall') ??
              false;
        } catch (_) {}
        if (!canInstall) {
          _showInstallPermissionDialog();
          return;
        }
        final ok = await _installerChannel.invokeMethod<bool>('installApk', {
          'path': path,
        });
        if (ok != true) {
          _showSnack(S.of(context).cannotLaunchInstaller);
        }
      } else {
        _showSnack(S.of(context).openPackageManually);
      }
    } catch (e) {
      _showSnack(S.of(context).cannotOpenPackage(e.toString()));
    }
  }

  /// 引导用户开启"安装未知应用"权限
  void _showInstallPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(S.of(context).installPermissionTitle),
        content: Text(
          S.of(context).installPermissionDesc,
          style: ts(13, h: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.blue),
            onPressed: () {
              Navigator.pop(ctx);
              _openInstallSettings();
            },
            child: Text(S.of(context).goSettings),
          ),
        ],
      ),
    );
  }

  /// 打开系统"允许安装未知应用"设置页
  void _openInstallSettings() {
    try {
      _installerChannel.invokeMethod('openInstallSettings');
    } catch (_) {}
  }

  /// Windows：打开所在目录
  void _openFolder(String path) {
    try {
      Process.run('explorer', ['/select,', path]);
    } catch (_) {}
  }

  String _fmtSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isWin = defaultTargetPlatform == TargetPlatform.windows;
    return Scaffold(
      backgroundColor: C.pageFill,
      appBar: MaterialAppBar(
        AppBar(
          backgroundColor: surfaceTint(Colors.white),
          elevation: 0,
          title: Text(S.of(context).checkUpdate),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: S.of(context).allChangelog,
              onPressed: _allReleases.isEmpty ? null : _showAllChangelog,
              icon: Icon(
                Icons.article_outlined,
                color: _allReleases.isEmpty ? C.greyLight : C.blue,
              ),
            ),
            IconButton(
              tooltip: AppState.updateChannelLabels[widget.state.updateChannel] ??
                  widget.state.updateChannel,
              onPressed: _switchChannel,
              icon: Icon(
                switch (widget.state.updateChannel) {
                  'github' => Icons.public_rounded,
                  'gitcode' => Icons.cloud_rounded,
                  _ => Icons.dns_rounded, // Qingling 等自建镜像：用服务器图标
                },
                color: C.blue,
              ),
            ),
            IconButton(
              tooltip: S.of(context).recheck,
              onPressed: _checking ? null : _check,
              icon: Icon(Icons.refresh_rounded, color: C.blue),
            ),
          ],
        ),
      ),
      body: ListView(
        // 底部让出系统导航栏（三大金刚键 / 手势条）：Android 15 起强制
        // edge-to-edge，不让的话最后一张卡片的按钮会被导航栏压住
        // （与设置子页同一个问题，见 issue #12）。
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewPadding.bottom,
        ),
        children: [
          // 签名已固定（1.5.2 起 release 统一 keystore），不再提示“签名变更需卸载重装”
          _versionCard(isWin),
          const SizedBox(height: 16),
          ..._buildStatusArea(isWin),
          const SizedBox(height: 16),
          if (_downloadedPath != null && _downloadingTag == null)
            _downloadedCard(isWin),
          if (_allReleases.length > 1) ...[
            const SizedBox(height: 16),
            _moreVersionsCard(isWin),
          ],
        ],
      ),
    );
  }

  Widget _versionCard(bool isWin) {
    final hasUpdate = !_hasError && !_checking && _isNewer;
    final gradient = hasUpdate
        ? const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFD6450C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF0A5CFF), Color(0xFF003D99)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    // 阴影放在 ClipRRect 外层（圆角裁切会把内层阴影一起剪掉）
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: hasUpdate ? const Color(0x33D6450C) : const Color(0x33003D99),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: gradient),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.system_update_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.of(context).currentVersion,
                              style: ts(
                                11,
                                c: Colors.white70,
                                w: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'v${AppState.appVersion}',
                              style: ts(26, c: Colors.white, w: FontWeight.w800),
                            ),
                            if (_latest != null && !_checking && !_hasError)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  _isNewer
                                      ? S
                                            .of(context)
                                            .newVersionTitle(_latest!.tagName)
                                      : S
                                            .of(context)
                                            .repoLatestTitle(_latest!.tagName),
                                  style: ts(
                                    12,
                                    c: Colors.white,
                                    w: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _heroStatus(),
                    ],
                  ),
                  // 主操作：整行白底按钮，放在最上面这张卡里。
                  // 以前这里只有一个向下的箭头图标，既像下载按钮又点不动；
                  // 真正的下载按钮却压在更新日志最底下、要滚动才看得到。
                  // 已经下过最新版：按钮**变成安装**，而不是消失
                  // （issue #20：「下载完成后下载按钮应变成安装按钮」）。
                  // 以前这里直接隐藏，用户以为要滚到下面那张卡里去找入口。
                  if (_alreadyDownloadedLatest) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0A5CFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final p = _downloadedPath;
                          if (p == null) return;
                          if (isWin) {
                            _runExe(p);
                          } else {
                            unawaited(_openApk(p));
                          }
                        },
                        icon: const Icon(Icons.install_mobile_rounded, size: 19),
                        label: Text(
                          isWin
                              ? S.of(context).runInstaller
                              : S.of(context).installNow,
                          style: ts(14, w: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                  if (_isNewer &&
                      !_checking &&
                      !_hasError &&
                      _downloadingTag == null &&
                      !_alreadyDownloadedLatest) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: hasUpdate
                              ? const Color(0xFFD6450C)
                              : const Color(0xFF0A5CFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _download(),
                        icon: const Icon(Icons.download_rounded, size: 19),
                        label: Text(
                          S.of(context).downloadNow,
                          style: ts(14, w: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                  // 下载中：一条白色**确定进度**线性动画 + 百分比。
                  //
                  // ⚠ 这里是**唯一**一条下载进度条（下面那张卡只留状态文字与取消，
                  // 见 _progressCard）。条件刻意不带 `_isNewer`：从「更多版本」里
                  // 手动下一次旧版时，这条也要出现，否则全屏只有百分比文字。
                  if (_downloadingTag != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.22,
                              ),
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                          style: ts(14, c: Colors.white, w: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // 高级感：一条柔光带从左到右循环掠过（纯装饰，不拦手势）。
            // 只在「有新版本 / 正在检查」时出现，避免常年动个没完。
            if (hasUpdate || _checking)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _sheen,
                    builder: (context, _) => FractionallySizedBox(
                      widthFactor: 0.32,
                      alignment: Alignment(-2.2 + 4.4 * _sheen.value, 0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.18),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // 检查中：底部一条线性进度动画（比转圈更贴合「下载/进度」的语义）
            if (_checking)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 英雄卡右上角的状态指示（检查中 / 出错 / 已最新）。
  ///
  /// **有新版时这里刻意不放任何图标**：状态由卡片里那个整行「立即下载」按钮
  /// 表达。以前这里放的是一个向下箭头图标，用户会把它当成下载按钮却又点不动，
  /// 和真正的下载按钮混在一起 —— 这就是「顶部有类似下载按钮容易弄混」的来源。
  Widget _heroStatus() {
    Widget child;
    if (_checking) {
      child = const SizedBox(
        key: ValueKey('checking'),
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
      );
    } else if (_hasError) {
      child = const Icon(
        Icons.warning_amber_rounded,
        key: ValueKey('error'),
        color: Colors.white,
        size: 28,
      );
    } else if (_isNewer) {
      child = const SizedBox.shrink(key: ValueKey('updateBlank'));
    } else {
      child = const Icon(
        Icons.check_rounded,
        key: ValueKey('ok'),
        color: Colors.white,
        size: 28,
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: child,
    );
  }

  List<Widget> _buildStatusArea(bool isWin) {
    if (_checking) {
      return [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: cardDeco(),
          child: Column(
            children: [
              // 线性进度（不确定态）而不是转圈：与顶部卡片底部那条同一种语言
              SizedBox(
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: C.greyBg,
                    color: C.blue,
                  ),
                ),
              ),
              SizedBox(height: 14),
              Text(
                S.of(context).checkingLatest,
                style: TextStyle(fontSize: 13, color: C.grey),
              ),
              SizedBox(height: 4),
              // 文案必须跟着**当前渠道**（issue #20：默认已改成 GitHub，
              // 而这里一直写死「GitCode」，用户看到的就是「描述一直是 gitcode」）。
              // 新增渠道时必须一并处理，否则又会退回「写死某一个渠道」的老问题。
              Text(
                switch (widget.state.updateChannel) {
                  'github' => S.of(context).connectingGitHub,
                  'gitcode' => S.of(context).connectingGitCode,
                  _ => S.of(context).updateChannelQinglingHint,
                },
                style: TextStyle(fontSize: 11, color: C.greyLight),
              ),
            ],
          ),
        ),
      ];
    }

    if (_hasError) {
      return [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: cardDeco(),
          child: Column(
            children: [
              Icon(Icons.cloud_off_rounded, color: C.red, size: 40),
              SizedBox(height: 12),
              Text(
                S.of(context).updateFailed,
                style: ts(16, w: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                _errorMsg,
                textAlign: TextAlign.center,
                style: ts(12, c: C.grey, h: 1.5),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: C.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _check,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(S.of(context).recheck),
                  ),
                ],
              ),
            ],
          ),
        ),
      ];
    }

    if (_latest == null) return [SizedBox()];

    if (!_isNewer) {
      final release = _latest!;
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDeco(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: C.greenBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.verified_rounded,
                      color: C.green,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context).latestVersion,
                          style: ts(13, w: FontWeight.w700),
                        ),
                        SizedBox(height: 2),
                        Text(
                          S
                              .of(context)
                              .localRepoVersion(
                                AppState.appVersion,
                                release.tagName,
                              ),
                          style: ts(11, c: C.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // 这次会下哪个包：如实写出来（文件名 · 架构），用户不需要做选择。
              if (_hasPackage(release, isWin)) ...[
                _packageLine(release, isWin),
                SizedBox(height: 16),
              ],
              Row(
                children: [
                  Icon(Icons.notes_rounded, size: 14, color: C.greyLight),
                  SizedBox(width: 4),
                  Text(
                    S.of(context).releaseNotes,
                    style: ts(12, c: C.grey, w: FontWeight.w700),
                  ),
                  Spacer(),
                  Text(
                    'v${release.tagName}',
                    style: ts(12, c: C.slate, w: FontWeight.w700),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: C.greyBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _CollapsibleNotes(
                  release.body.trim().isNotEmpty
                      ? release.body.trim()
                      : S.of(context).noReleaseNotes,
                ),
              ),
              SizedBox(height: 16),
              if (_downloadingTag != null && _downloadingTag == release.tagName)
                _progressCard()
              else if (_dlError)
                _retryDownloadCard()
              else if (_downloadedPath == null && !_latestHasAsset)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: C.greyBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    S
                        .of(context)
                        .noInstallerHistoryHint(isWin ? 'Windows' : 'APK'),
                    textAlign: TextAlign.center,
                    style: ts(12, c: C.grey),
                  ),
                )
              else if (_downloadedPath == null)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _download,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      S.of(context).downloadAgain,
                      style: ts(13, w: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ];
    }

    // 有更新
    final release = _latest!;
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDeco(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 版本升级信息
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context).latestVersionLabel,
                        style: ts(11, c: C.grey, w: FontWeight.w600),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'v${release.tagName}',
                        style: ts(20, w: FontWeight.w800, c: C.red),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: C.redBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward_rounded, color: C.red, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'v${AppState.appVersion} → v${release.tagName}',
                        style: ts(12, c: C.red, w: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (release.assetSizeFor(isWin) > 0) ...[
              SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.sd_storage_rounded, size: 14, color: C.greyLight),
                  SizedBox(width: 4),
                  Text(
                    S
                        .of(context)
                        .packageSize(
                          isWin ? 'Windows' : 'APK',
                          _fmtSize(release.assetSizeFor(isWin)),
                        ),
                    style: ts(12, c: C.grey),
                  ),
                ],
              ),
            ],
            if (_hasPackage(release, isWin)) ...[
              SizedBox(height: 16),
              _packageLine(release, isWin),
            ],
            if (release.body.trim().isNotEmpty) ...[
              SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: C.greyBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notes_rounded, size: 14, color: C.greyLight),
                        SizedBox(width: 4),
                        Text(
                          S.of(context).updateContents,
                          style: ts(12, c: C.grey, w: FontWeight.w700),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    _CollapsibleNotes(release.body.trim()),
                  ],
                ),
              ),
            ],
            SizedBox(height: 18),
            if (_downloadingTag != null && _downloadingTag == release.tagName)
              _progressCard()
            else if (_dlError)
              _retryDownloadCard()
            else if (_downloadedPath == null && !_latestHasAsset)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.greyBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  S
                      .of(context)
                      .noInstallerHistoryHint(isWin ? 'Windows' : 'APK'),
                  textAlign: TextAlign.center,
                  style: ts(12, c: C.grey),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _progressCard() {
    // ⚠ **不要**在这里再画一条进度条：英雄卡里已经有一条（就在「立即下载」按钮
    // 下方，是下载开始后第一眼看的地方）。两处各画一条，同一个下载在屏幕上会
    // 出现两条进度，看着像两个任务 —— 所以这里只留状态文字 + 后台说明 + 取消。
    return Column(
      children: [
        Text(_dlStatus, style: ts(12, c: C.grey)),
        SizedBox(height: 8),
        // 后台下载（issue #22-5）：把**边界**写明 —— 承诺「后台下载」却悄悄
        // 断在半路，比不做这个功能更伤人。用户可以离开这一页，也可以把 App
        // 切到后台，下载都在跑（进度也在通知栏里）；但**进程被杀就断了**。
        Row(
          children: [
            Icon(Icons.cloud_download_outlined, size: 13, color: C.green),
            const SizedBox(width: 5),
            Expanded(
              child: Text(S.of(context).downloadBackgroundHint,
                  style: ts(10.5, c: C.green, h: 1.4)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _dl.cancel(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: C.redBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(S.of(context).downloadCancel,
                    style: ts(10.5, c: C.red, w: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _retryDownloadCard() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: C.redBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _dlStatus,
            style: ts(12, c: C.red, w: FontWeight.w600),
          ),
        ),
        SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: C.blue),
            onPressed: _download,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(
              S.of(context).redownload,
              style: ts(13, w: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  /// 该版本有没有本平台的安装包（没有就不占位）。
  bool _hasPackage(_ReleaseInfo r, bool isWin) => r.assetFor(isWin) != null;

  /// 「这次会下哪个包」—— 文件名 + 架构 + 大小。
  ///
  /// 分架构发布之后，用户唯一需要知道的就是这一句：**我会拿到哪一个**。
  /// 挑包由 [pickUpdateAssetFor] 按本机架构自动完成（32 位老机型自动拿到 32 位包），
  /// 这里只把结果如实写出来 —— **不摆一排让用户选**：绝大多数人只知道「我要更新」，
  /// 让他们去理解 `armeabi-v7a` 是什么，等于把应用该做的事推给用户。
  Widget _packageLine(_ReleaseInfo release, bool isWin) {
    final a = release.assetFor(isWin);
    if (a == null) return const SizedBox.shrink();
    final name = (a['name'] ?? '').toString();
    final abi = isWin ? '' : ' · ${abiLabelOfAssetName(name)}';
    return Row(
      children: [
        Icon(Icons.inventory_2_outlined, size: 13, color: C.greyLight),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            '$name$abi',
            style: ts(10.5, c: C.greyLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _downloadedCard(bool isWin) {
    final path = _downloadedPath!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: C.greenBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.download_done_rounded,
                  color: C.green,
                  size: 20,
                ),
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).alreadyDownloaded,
                    style: ts(13, w: FontWeight.w700),
                  ),
                  SizedBox(height: 2),
                  Text('v${_downloadedTag ?? ''}', style: ts(11, c: C.grey)),
                ],
              ),
            ],
          ),
          SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: C.greyBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              path,
              style: ts(11, c: C.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: 12),
          if (!isWin)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: C.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _openApk(path),
                    icon: const Icon(Icons.android_rounded, size: 18),
                    label: Text(S.of(context).installNow),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: C.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _runExe(path),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(S.of(context).runInstaller),
                  ),
                ),
              ],
            ),
          if (isWin) ...[
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: C.blue),
                onPressed: () => _openFolder(path),
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: Text(S.of(context).openContainingFolder),
              ),
            ),
          ],
          SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: C.blue),
              onPressed: _download,
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: Text(
                S.of(context).downloadAgain,
                style: ts(13, w: FontWeight.w700),
              ),
            ),
          ),
          SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: C.red),
              onPressed: () => _deleteDownloaded(path),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(
                S.of(context).deletePackage,
                style: ts(13, w: FontWeight.w700),
              ),
            ),
          ),
          // 本地按版本会累积多个安装包，提供“删除全部”清理入口
          if (_localPackages.length > 1) ...[
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: C.red),
                onPressed: _deleteAllPackages,
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: Text(
                  S
                      .of(context)
                      .deleteAllPackagesWithCount(_localPackages.length),
                  style: ts(13, w: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 删除已下载的安装包（带确认）
  void _deleteDownloaded(String path) {
    final name = path.split(Platform.pathSeparator).last;
    _confirmDelete(
      title: S.of(context).deletePackage,
      message: S.of(context).deletePackageConfirm(name),
      onConfirm: () {
        try {
          final f = File(path);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
        _localPackages.removeWhere((x) => x.path == path);
        _findLocalApk(); // 重新确定“最新已下载”，无残留则收起下载卡片
        _showSnack(S.of(context).packageDeleted);
      },
    );
  }

  /// 删除本地全部已下载的安装包（带确认，展示数量与占用空间）
  void _deleteAllPackages() {
    if (_localPackages.isEmpty) return;
    var total = 0;
    for (final f in _localPackages) {
      try {
        total += f.lengthSync();
      } catch (_) {}
    }
    _confirmDelete(
      title: S.of(context).deleteAllPackages,
      message: S.of(context).deleteAllPackagesConfirm(
        _localPackages.length,
        _fmtSize(total),
      ),
      onConfirm: () {
        for (final f in _localPackages) {
          try {
            if (f.existsSync()) f.deleteSync();
          } catch (_) {}
        }
        setState(() {
          _localPackages = [];
          _downloadedPath = null;
          _downloadedTag = null;
        });
        _showSnack(S.of(context).packageDeleted);
      },
    );
  }

  /// 通用删除确认弹窗
  void _confirmDelete({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: ts(16, w: FontWeight.w700)),
        content: Text(message, style: ts(13, h: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).cancel, style: ts(13, c: C.slate)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.red),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(S.of(context).confirmDelete, style: ts(13)),
          ),
        ],
      ),
    );
  }

  /// 更多版本列表
  Widget _moreVersionsCard(bool isWin) {
    // 已是最新时最新版本已在"更新日志"里展示过，历史版本从第2个开始
    final history = _isNewer ? _allReleases : _allReleases.skip(1).toList();
    if (history.isEmpty) return SizedBox();

    return Container(
      decoration: cardDeco(),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _moreOpen = !_moreOpen),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: C.blueBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.history_rounded, color: C.blue, size: 17),
                  ),
                  SizedBox(width: 10),
                  Text(
                    S.of(context).historyVersions,
                    style: ts(13, w: FontWeight.w700),
                  ),
                  SizedBox(width: 6),
                  Text(
                    S.of(context).versionCount(history.length),
                    style: ts(11, c: C.grey),
                  ),
                  Spacer(),
                  AnimatedRotation(
                    turns: _moreOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: C.grey,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_moreOpen) ...history.map((rel) => _versionRow(isWin, rel)),
        ],
      ),
    );
  }

  Widget _versionRow(bool isWin, _ReleaseInfo rel) {
    final isCurrent = rel.tagName == AppState.appVersion;
    final tag = rel.tagName;
    final size = rel.assetSizeFor(isWin);
    final hasAsset = rel.assetUrlFor(isWin) != null;
    final busy = _downloadingTag == tag;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: C.greyBg, width: 1)),
      ),
      child: busy
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'v$tag',
                      style: ts(13, w: FontWeight.w700, c: C.blue),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        S
                            .of(context)
                            .downloadProgress(
                              (_progress * 100)
                                  .clamp(0, 100)
                                  .toStringAsFixed(0),
                            ),
                        style: ts(11, c: C.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 6,
                    backgroundColor: C.greyBg,
                    color: C.blue,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  _dlStatus.isNotEmpty
                      ? _dlStatus
                      : S.of(context).connectingEllipsis,
                  style: ts(10, c: C.greyLight),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'v$tag',
                            style: ts(
                              13,
                              w: FontWeight.w700,
                              c: isCurrent ? C.green : C.slate,
                            ),
                          ),
                          if (isCurrent) ...[
                            SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: C.greenBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                S.of(context).current,
                                style: ts(10, c: C.green, w: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (size > 0) ...[
                        SizedBox(height: 2),
                        Text(
                          '${isWin ? 'Windows' : 'APK'} ${_fmtSize(size)}',
                          style: ts(11, c: C.grey),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!hasAsset)
                  Text(S.of(context).noInstaller, style: ts(11, c: C.greyLight))
                else
                  SizedBox(
                    height: 32,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: C.blue),
                      onPressed: () => _download(rel),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: Text(
                        S.of(context).download,
                        style: ts(12, w: FontWeight.w700),
                      ),
                    ),
                  ),
                if (rel.body.trim().isNotEmpty)
                  IconButton(
                    tooltip: S.of(context).viewChangelog,
                    icon: Icon(Icons.notes_rounded, size: 16, color: C.grey),
                    onPressed: () => _showReleaseLog(rel),
                  ),
              ],
            ),
    );
  }

  /// 弹出某版本的更新日志
  void _showReleaseLog(_ReleaseInfo rel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Text(
              S.of(context).versionChangelog(rel.tagName),
              style: ts(16, w: FontWeight.w700),
            ),
            Spacer(),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 18, color: C.grey),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            rel.body.trim().isNotEmpty
                ? rel.body.trim()
                : S.of(context).noReleaseNotes,
            style: ts(13, c: C.slate, h: 1.7),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.blue),
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).gotIt),
          ),
        ],
      ),
    );
  }

  /// 弹出全部版本的更新日志（新 → 旧）
  void _showAllChangelog() {
    if (_allReleases.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.82,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
                child: Row(
                  children: [
                    Icon(Icons.article_outlined, size: 20, color: C.blue),
                    const SizedBox(width: 8),
                    Text(
                      S.of(context).allChangelog,
                      style: ts(16, w: FontWeight.w800),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: C.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  children: [
                    for (final rel in _allReleases) ...[
                      Row(
                        children: [
                          Text(
                            'v${rel.tagName}',
                            style: ts(13, c: C.blue, w: FontWeight.w800),
                          ),
                          if (rel.tagName == AppState.appVersion) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: C.greenBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                S.of(context).current,
                                style: ts(10, c: C.green, w: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: C.greyBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          rel.body.trim().isNotEmpty
                              ? rel.body.trim()
                              : S.of(context).noReleaseNotes,
                          style: ts(12, c: C.slate, h: 1.6),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
