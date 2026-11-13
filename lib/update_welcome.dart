import 'dart:io';

import 'package:flutter/material.dart';

import 'state.dart';
import 'theme.dart';
import 'update_install.dart';
import 'version_compare.dart';
import 'widgets.dart';

/// 装上新版之后的两件事，**分成两步，不再塞进一个弹窗**：
///
///   1. 欢迎一句 + 这一版改了什么（用户要「简要提示该版本更新内容」）；
///   2. 那个安装包还要不要留（留着能装到别的设备，删掉能腾出空间）。
///
/// 合成一个弹窗的毛病：想留安装包的人得先看完一堆更新说明才能答「留」，
/// 而只想看更新内容的人被迫面对一个「删除 / 保留」的选择题。两件事分开问，
/// 各自一次，互不牵连。
///
/// ── 为什么放在启动这一层判断 ──
/// 「是不是刚更新完」只有启动时才知道：新版本是系统的安装器装上去的，
/// 我们的进程在那之前就已经被杀掉了。所以**下载时**把包记进 prefs
/// （[AppState.updatePkgJson]），启动后拿当前版本跟它比：装上了才问。
///
/// 欢迎卡一个版本只弹一次（[AppState.updatePkgWelcomeSeen]）；
/// 「要不要留」按 [AppState.updatePkgAsked] 只听用户一次：设置里选了
/// 「自动删除 / 一直保留」就照做，不再问。
Future<void> maybePromptUpdateWelcome({
  required BuildContext context,
  required AppState state,
}) async {
  final tag = state.updatePkgTag;
  if (tag.isEmpty) return;
  final cmp = compareVersions(AppState.appVersion, tag);
  // 还没装上新版（下的是更高版本）：不打扰，等他装完再问。
  if (cmp < 0) return;
  // 装的是比记录更新的版本（他直接从别处升上来了）：这条记录过时了。
  if (cmp > 0) {
    state.forgetUpdatePackage();
    return;
  }

  // 走到这里说明确实装上了：安装时复制到缓存的那份副本没用了。
  await UpdateInstaller.cleanCache();

  // ── ① 欢迎 + 这一版改了什么（一个版本一次）──
  if (state.updatePkgWelcomeSeen != tag && context.mounted) {
    state.markUpdatePkgWelcomeSeen(tag);
    await _showWelcome(context, state, tag);
  }

  // ── ② 安装包还要不要留 ──
  if (state.updatePkgAsked == tag) return;
  final name = state.updatePkgName;
  if (name.isEmpty) {
    state.forgetUpdatePackage();
    return;
  }

  if (state.updatePkgAction == 'delete') {
    await deleteUpdatePackage(state);
    state.markUpdatePkgAsked(tag);
    return;
  }
  if (state.updatePkgAction == 'keep') {
    state.markUpdatePkgAsked(tag);
    return;
  }

  if (!context.mounted) return;
  await _askKeepPackage(context, state, tag);
}

/// 第一屏：欢迎一句 + 这一版改了什么。只有一个「知道了」，不做任何选择。
Future<void> _showWelcome(
  BuildContext context,
  AppState state,
  String tag,
) async {
  final s = S.of(context);
  final notes = state.updatePkgNotes;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.celebration_rounded, color: C.blue, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.updatePkgWelcomeTitle(AppState.appVersion),
              style: ts(16, w: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.updatePkgWelcomeHello, style: ts(13, h: 1.6)),
            // 这一版改了什么：下载时从 release 正文里挑出的几行（见
            // lib/update_notes.dart）。从别处装的包没有这段，就不摆标题。
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                s.updatePkgWhatsNew,
                style: ts(12, w: FontWeight.w700, c: C.slate),
              ),
              const SizedBox(height: 6),
              for (final line in notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('· ', style: ts(12, c: C.grey)),
                      Expanded(child: Text(line, style: ts(12, h: 1.5))),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: C.blue,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            s.gotIt,
            style: ts(13, c: Colors.white, w: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// 第二步：那个安装包还要不要留（这才有选择）。
Future<void> _askKeepPackage(
  BuildContext context,
  AppState state,
  String tag,
) async {
  final s = S.of(context);
  final name = state.updatePkgName;
  var remember = false;
  final del = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: C.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          s.updatePkgDeleteTitle,
          style: ts(16, w: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.updatePkgWelcomeBody, style: ts(13, h: 1.6)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: C.greyBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: ts(12, w: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.updatePkgInDownloads} · '
                      '${_fmtSize(state.updatePkgSize)}',
                      style: ts(11, c: C.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // 记住的是「这一次的做法」，不是某一个按钮：选删除就记住删除，
              // 选保留就记住保留，下次直接照做。
              InkWell(
                onTap: () => setLocal(() => remember = !remember),
                child: Row(
                  children: [
                    Checkbox(
                      value: remember,
                      onChanged: (v) => setLocal(() => remember = v ?? false),
                    ),
                    Expanded(
                      child: Text(
                        s.updatePkgRemember,
                        style: ts(12, c: C.slate),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.updatePkgKeep, style: ts(13, c: C.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: C.blue,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              s.updatePkgDelete,
              style: ts(13, c: Colors.white, w: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
  // 点了外面关掉：不记「问过」，下次启动再问一次。
  if (del == null) return;
  if (remember) state.setUpdatePkgAction(del ? 'delete' : 'keep');
  if (del) {
    await deleteUpdatePackage(state);
    if (context.mounted) _toast(context, s.packageDeleted);
  } else {
    state.markUpdatePkgAsked(tag);
    if (context.mounted) _toast(context, s.updatePkgKept);
  }
}

/// 删掉记下来的那个安装包：系统「下载」里那份 + 应用自己目录里那份（如果有）。
Future<bool> deleteUpdatePackage(AppState state) async {
  final name = state.updatePkgName;
  final path = state.updatePkgPath;
  var ok = false;
  if (name.isNotEmpty && UpdateInstaller.isAndroid) {
    ok = await UpdateInstaller.remove(name);
  }
  if (path.isNotEmpty) {
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
        ok = true;
      }
    } catch (_) {}
  }
  // 记下的包已经处理完（删掉了，或者本来就不在了）：记录一并清掉，
  // 否则装完以后还会拿旧文件名再来问一次。
  state.forgetUpdatePackage();
  return ok;
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(text)),
  );
}

String _fmtSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
