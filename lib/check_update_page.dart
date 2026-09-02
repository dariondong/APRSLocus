import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'theme.dart';
import 'state.dart';
import 'widgets.dart';

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
    for (final a in assets) {
      final n = (a['name'] ?? '').toString().toLowerCase();
      if (n.endsWith('.apk')) return a;
    }
    return null;
  }

  String assetNameFor(bool isWindows) {
    final a = assetFor(isWindows);
    if (a != null) return (a['name'] ?? '').toString();
    return isWindows ? 'Windows 安装包' : 'APK 安装包';
  }

  int assetSizeFor(bool isWindows) {
    final a = assetFor(isWindows);
    if (a != null) {
      final s = a['size'];
      if (s is num) return s.toInt();
    }
    return 0;
  }

  String? assetUrlFor(bool isWindows) {
    final a = assetFor(isWindows);
    if (a == null) return null;
    // 兼容 GitHub / GitCode 不同字段名
    for (final k in const ['browser_download_url', 'download_url', 'url']) {
      final v = a[k]?.toString();
      if (v != null && v.isNotEmpty && !v.endsWith('{?path}')) return v;
    }
    return null;
  }
}

/// 检查更新页面
class CheckUpdatePage extends StatefulWidget {
  final AppState state;
  const CheckUpdatePage({super.key, required this.state});
  @override
  State<CheckUpdatePage> createState() => _CheckUpdatePageState();
}

class _CheckUpdatePageState extends State<CheckUpdatePage> {
  static const _repoOwner = 'DarionDong';
  static const _repoName = 'APRSLocus';
  static const _installerChannel = MethodChannel('com.aprslocus/installer');

  /// 当前更新渠道对应的 API 地址
  String get _apiBase => widget.state.updateChannel == 'github'
      ? 'https://api.github.com/repos'
      : 'https://api.gitcode.com/api/v5/repos';

  bool _checking = false;
  bool _hasError = false;
  String _errorMsg = '';
  _ReleaseInfo? _latest;
  List<_ReleaseInfo> _allReleases = [];
  bool _isNewer = false;
  bool _latestHasAsset = false; // 最新版本是否有当前平台安装包
  bool _moreOpen = false; // 更多版本折叠

  // 正在下载的特定版本（tagName → true）
  String? _downloadingTag;
  double _progress = 0;
  String _dlStatus = '';
  String? _downloadedPath;
  String? _downloadedTag; // 实际下载成功的版本
  bool _dlError = false;

  // 本地已有安装包（用于"重新下载"按钮提示）
  String? _localApkPath;

  // 本地已下载的全部安装包（按版本会累积多个，用于"删除全部"）
  List<File> _localPackages = [];

  @override
  void initState() {
    super.initState();
    _check();
    _findLocalApk();
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
          _localApkPath = f.path;
          if (mounted) setState(() {});
          return;
        }
      }
      // 兜底：无版本号匹配则取最新的一个
      if (files.isNotEmpty) {
        _downloadedPath = files.first.path;
        _localApkPath = files.first.path;
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

  /// 切换更新渠道（GitCode / GitHub）
  void _switchChannel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.of(context).updateChannel,
                style: ts(15, w: FontWeight.w800),
              ),
              const SizedBox(height: 14),
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
            ],
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

  /// 下载安装包
  /// [target] 指定版本，默认最新
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
    final tag = rel.tagName;
    // 本地缓存文件名：去掉 tag 的 v 前缀，与 CI 产物命名一致（APRSLocus_1.4.4.apk）
    final ver = tag.replaceAll(RegExp('^v'), '');
    final fileName = isWin ? 'APRSLocus_$ver.exe' : 'APRSLocus_$ver.apk';
    setState(() {
      _downloadingTag = tag;
      _progress = 0;
      _dlStatus = S.of(context).connectingEllipsis;
      _dlError = false;
    });

    try {
      final dir = await _downloadDir();
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/$fileName');

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      final req = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      final resp = await req.close().timeout(const Duration(seconds: 120));
      if (resp.statusCode != 200) {
        throw Exception(S.of(context).downloadHttpError(resp.statusCode));
      }
      final total = resp.contentLength;

      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in resp) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          final p = received / total;
          if (mounted) {
            setState(() {
              _progress = p;
              _dlStatus = S
                  .of(context)
                  .downloadedBytes(_fmtSize(received), _fmtSize(total));
            });
          }
        }
      }
      await sink.flush();
      await sink.close();
      client.close();

      if (mounted) {
        setState(() {
          _downloadingTag = null;
          _downloadedPath = file.path;
          _downloadedTag = tag;
          _localApkPath = file.path;
          if (!_localPackages.any((f) => f.path == file.path)) {
            _localPackages.add(file);
          }
          _dlStatus = S.of(context).downloadComplete;
        });
      }
      if (defaultTargetPlatform == TargetPlatform.windows) {
        _showWinDialog(file.path);
      } else {
        _showInstallDialog(file.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadingTag = null;
          _dlError = true;
          _dlStatus =
              '${S.of(context).downloadFailed}: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
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
      backgroundColor: C.greyBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
            tooltip: widget.state.updateChannel == 'github'
                ? 'GitHub'
                : 'GitCode',
            onPressed: _switchChannel,
            icon: Icon(
              widget.state.updateChannel == 'github'
                  ? Icons.public_rounded
                  : Icons.cloud_rounded,
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
      body: ListView(
        padding: const EdgeInsets.all(16),
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

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: hasUpdate
                ? const Color(0x33D6450C)
                : const Color(0x33003D99),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(15),
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
                  style: ts(11, c: Colors.white70, w: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  'v${AppState.appVersion}',
                  style: ts(24, c: Colors.white, w: FontWeight.w800),
                ),
                if (_latest != null && !_checking && !_hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _isNewer
                          ? S.of(context).newVersionTitle(_latest!.tagName)
                          : S.of(context).repoLatestTitle(_latest!.tagName),
                      style: ts(12, c: Colors.white, w: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          if (_checking)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          else if (_isNewer && !_hasError)
            const Icon(
              Icons.arrow_downward_rounded,
              color: Colors.white,
              size: 30,
            )
          else if (!_hasError)
            const Icon(Icons.check_rounded, color: Colors.white, size: 30)
          else
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 30,
            ),
        ],
      ),
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
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 3, color: C.blue),
              ),
              SizedBox(height: 14),
              Text(
                S.of(context).checkingLatest,
                style: TextStyle(fontSize: 13, color: C.grey),
              ),
              SizedBox(height: 4),
              Text(
                S.of(context).connectingGitCode,
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
                      borderRadius: BorderRadius.circular(10),
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
                          style: ts(14, w: FontWeight.w700),
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
                child: Text(
                  release.body.trim().isNotEmpty
                      ? release.body.trim()
                      : S.of(context).noReleaseNotes,
                  style: ts(13, c: C.slate, h: 1.7),
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
                    borderRadius: BorderRadius.circular(10),
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
                    borderRadius: BorderRadius.circular(10),
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
                    Text(
                      release.body.trim(),
                      style: ts(13, c: C.slate, h: 1.7),
                    ),
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
                  borderRadius: BorderRadius.circular(10),
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
              _downloadButton(isWin),
          ],
        ),
      ),
    ];
  }

  Widget _progressCard() {
    final pct = (_progress * 100).clamp(0, 100);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 10,
                  backgroundColor: C.greyBg,
                  color: C.blue,
                ),
              ),
            ),
            SizedBox(width: 10),
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: ts(13, w: FontWeight.w800, c: C.blue),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(_dlStatus, style: ts(12, c: C.grey)),
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
            borderRadius: BorderRadius.circular(10),
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
              style: ts(14, w: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _downloadButton(bool isWin) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: C.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _download,
            icon: const Icon(Icons.download_rounded, size: 20),
            label: Text(
              isWin
                  ? S.of(context).downloadInstaller
                  : S.of(context).downloadAndInstall,
              style: ts(15, w: FontWeight.w700),
            ),
          ),
        ),
        if (_localApkPath != null) ...[
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_rounded, size: 13, color: C.greyLight),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  S.of(context).localPackageExists,
                  style: ts(11, c: C.greyLight),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
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
                  borderRadius: BorderRadius.circular(10),
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
                    style: ts(14, w: FontWeight.w700),
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
              borderRadius: BorderRadius.circular(10),
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
          _localApkPath = null;
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
        title: Text(title, style: ts(15, w: FontWeight.w700)),
        content: Text(message, style: ts(13, h: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).cancel, style: ts(14, c: C.slate)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.red),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(S.of(context).confirmDelete, style: ts(14)),
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
                      borderRadius: BorderRadius.circular(9),
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
                  borderRadius: BorderRadius.circular(4),
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
                                borderRadius: BorderRadius.circular(5),
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
              style: ts(15, w: FontWeight.w700),
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                                borderRadius: BorderRadius.circular(5),
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
                          borderRadius: BorderRadius.circular(10),
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
