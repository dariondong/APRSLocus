import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'pinned_http.dart';
import 'state.dart';

/// ─── 更新包下载器（进程内后台下载，issue #22-5）───
///
/// 用户要求：「下载新安装包，支持后台下载」。
///
/// ## 为什么需要一个独立于页面的单例
///
/// 原来的下载写在 `_CheckUpdatePageState` 里：它一被 `dispose`（用户返回上一页），
/// 进度就没人更新了，而且**下完之后会拿一个已经失效的 `context` 去弹安装对话框**
/// （`mounted` 为真才 setState、却在外面无条件弹窗）—— 用户在下载完成前离开那一页，
/// 轻则什么提示都没有，重则踩到「用了已卸载的 context」。
///
/// 现在下载任务归这个单例所有：页面只是**订阅者**。于是：
///   * 离开页面 → 任务照跑（`HttpClient` 与 `IOSink` 都归它持有）；
///   * 回到页面 → 从 [progress] 接着显示（不用从头再来）；
///   * 下完了而用户不在页面上 → 走**通知栏**告诉他（见 [AppState.notifExtra]），
///     下次进更新页时「已下载」卡片本来就在。
///
/// ## 边界（必须如实说，别让用户以为它能扛住杀进程）
///
/// 这是**进程内**的后台：App 活着（退到后台、切到别的页面、锁屏）下载都在跑，
/// 但**进程被杀就断了**（APK/exe 是几百 MB，不做断点续传：GitHub 的直链支持
/// `Range`，但那要引入临时文件 + 校验 + 恢复逻辑，收益与风险不成比例）。
/// 页面上会把这句话写给用户看 —— 承诺「后台下载」却悄悄断在半路更糟。
class UpdateDownloader extends ChangeNotifier {
  UpdateDownloader._();

  static final UpdateDownloader instance = UpdateDownloader._();

  /// 绑定的状态（拿 l10n 与通知栏用）。由更新页在 initState 里调用，幂等。
  AppState? _state;

  void bind(AppState st) => _state ??= st;

  /// 当前正在下载的版本号（如 2.0.8）；空闲时为 null。
  String? tag;

  /// 下载完成的文件路径；没有则为 null。
  String? path;

  /// 下载成功的版本号。单独一个字段而不是复用 [tag]：完成时 [tag] 会被清空
  /// （它是「正在下载」的标志），而界面要显示「已下载 v2.0.8」。
  String? doneTag;

  /// 0~1；[total] 未知时恒为 0（界面用不确定进度条）。
  double progress = 0;

  int received = 0;
  int total = 0;

  /// 人类可读的状态行（已本地化）。
  String statusText = '';

  /// 网络/写盘错误；null = 没有错误。
  String? error;

  bool get running => tag != null;

  /// 每完成一次下载 +1。页面靠它判断「这次完成要不要弹安装对话框」——
  /// 用布尔标志会在「完成时页面不在、回来后又读到 true」时多弹一次。
  int doneSeq = 0;

  int _runSeq = 0;
  HttpClient? _client;

  /// 开始下载。[dirProvider] 由页面传入（它知道各平台的下载目录口径）。
  Future<void> start({
    required String url,
    required String fileName,
    required String versionTag,
    required Future<Directory> Function() dirProvider,
  }) async {
    if (running) return; // 同一时刻只允许一个（重复点按钮不会开出两条流）
    final seq = ++_runSeq;
    tag = versionTag;
    path = null;
    error = null;
    progress = 0;
    received = 0;
    total = 0;
    final l = _state?.l10n;
    statusText = l?.connectingEllipsis ?? '';
    _notify();
    _notifyBar();
    try {
      final dir = await dirProvider();
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/$fileName');
      // 先写 `.part` 再改名：中途断掉（进程被杀/网络断）留下的是 `.part`，
      // 不会让下一次「已下载」扫描把一个半截的 APK 当成可用安装包。
      final part = File('${file.path}.part');

      // 下载地址若指向自建服务器（自签证书），需要钉扎 context；
      // 指向 GitHub 等公共站点时 pinnedContextFor 返回 null，即默认行为。
      final client = HttpClient(context: pinnedContextFor(url))
        ..connectionTimeout = const Duration(seconds: 30);
      _client = client;
      final req = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      final resp = await req.close().timeout(const Duration(seconds: 120));
      if (resp.statusCode != 200) {
        throw Exception(l?.downloadHttpError(resp.statusCode) ??
            'HTTP ${resp.statusCode}');
      }
      total = resp.contentLength;

      final sink = part.openWrite();
      var lastBarAt = DateTime.fromMillisecondsSinceEpoch(0);
      await for (final chunk in resp) {
        sink.add(chunk);
        received += chunk.length;
        if (seq != _runSeq) {
          // 被取消（或又开了一次）：关掉流与句柄，删掉半截文件
          await sink.flush();
          await sink.close();
          try {
            if (await part.exists()) await part.delete();
          } catch (_) {}
          return;
        }
        if (total > 0) progress = received / total;
        final now = DateTime.now();
        // 通知栏不能每来一块就刷一次（APK 有几千个 chunk）：250ms 节流，
        // 而**页面内的进度**照旧每块都更新（它便宜，且要跟手）。
        if (now.difference(lastBarAt).inMilliseconds >= 250) {
          lastBarAt = now;
          _notifyBar();
        }
        statusText = _state?.l10n.downloadedBytes(
                _fmt(received), _fmt(total > 0 ? total : received)) ??
            '';
        _notify();
      }
      await sink.flush();
      await sink.close();
      client.close();
      _client = null;

      // 原子改名：这一步之后才算「有一个可用的安装包」
      if (await part.exists()) await part.rename(file.path);
      path = file.path;
      doneTag = versionTag;
      tag = null;
      progress = 1;
      statusText = _state?.l10n.downloadComplete ?? 'ok';
      doneSeq++;
      _notify();
      _notifyBar();
    } catch (e) {
      _client?.close();
      _client = null;
      tag = null;
      error = e.toString().replaceFirst('Exception: ', '');
      statusText =
          '${_state?.l10n.downloadFailed ?? 'failed'}: $error';
      _notify();
      _notifyBar();
    }
  }

  /// 取消下载（进度卡上的按钮）。文件与流都由 [start] 的循环负责收尾。
  void cancel() {
    if (!running) return;
    _runSeq++; // 让循环在下一个 chunk 处自行退出并清理
    _client?.close();
    _client = null;
    tag = null;
    progress = 0;
    received = 0;
    total = 0;
    statusText = _state?.l10n.downloadCanceled ?? '';
    _notify();
    _notifyBar();
  }

  /// 用户进更新页看过之后清掉「下载完成」那条通知（避免永远挂着）。
  ///
  /// **不动 [path]** —— 已下载卡片还要用它；只是把通知栏那一行收掉。
  void clearDoneNotice() {
    if (doneSeq == 0) return;
    final st = _state;
    if (st == null) return;
    if (st.notifExtra.isEmpty) return;
    st.setNotifExtra('');
  }

  void _notify() {
    // 页面可能已经 dispose，但监听器会自行移除；这里只管发通知。
    notifyListeners();
  }

  /// 把下载进度写进常驻通知（Android）。这是「后台下载」对用户唯一的可见性 ——
  /// 不写的话，退到后台就只剩一个转圈，用户只能靠等。
  ///
  /// 走 [AppState.notifExtra] 而不是直接调 `loc.updateNotification`：
  /// 通知栏文字是由 `AppState._updateNotification()` 整体拼装的（连接状态、
  /// 台站数、信标倒计时…），直接覆盖会被它 15 秒一次的保活刷新顶掉。
  void _notifyBar() {
    final st = _state;
    if (st == null) return;
    final l = st.l10n;
    if (running) {
      final pct = total > 0 ? (progress * 100).clamp(0, 100).toStringAsFixed(0) : '…';
      st.setNotifExtra(l.notifUpdateDownload(tag ?? '', pct));
    } else if (error != null) {
      st.setNotifExtra(l.notifUpdateFailed);
    } else if (path != null) {
      st.setNotifExtra(l.notifUpdateReady);
    } else {
      st.setNotifExtra('');
    }
  }

  static String _fmt(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}
