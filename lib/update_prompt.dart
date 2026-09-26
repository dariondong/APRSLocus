import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'check_update_page.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// 启动后检查一次新版本，**有新版就弹提醒**（同一版本只提醒一次）。
///
/// 与「设置 → 检查更新」页共用同一套版本比较规则（[compareVersions]），
/// 但这里只做一件事：发现更新 → 提示 → 用户可一键跳到更新页。
///
/// 旧版兼容 / 不打扰：
///   * 完全后台、失败静默 —— 断网 / 接口变动都不该在启动时弹错误；
///   * 记 `updatePromptedVersion`：同一个版本提醒过一次就不再打扰，
///     只有**出新版本**时才会再出现。
Future<void> maybePromptUpdate({
  required BuildContext context,
  required AppState state,
}) async {
  try {
    final latest = await _fetchLatestTag(state.updateChannel);
    if (latest == null) return;
    if (compareVersions(latest, AppState.appVersion) <= 0) return;

    final p = await SharedPreferences.getInstance();
    if (p.getString('updatePromptedVersion') == latest) return;
    await p.setString('updatePromptedVersion', latest);

    if (!context.mounted) return;
    await _showUpdateDialog(context, state, latest);
  } catch (_) {
    // 更新提示是「顺带」的东西，任何失败都不该影响启动
  }
}

Future<String?> _fetchLatestTag(String channel) async {
  final base = channel == 'github'
      ? 'https://api.github.com/repos'
      : 'https://api.gitcode.com/api/v5/repos';
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await client
        .getUrl(Uri.parse('$base/DarionDong/APRSLocus/releases'))
        .timeout(const Duration(seconds: 15));
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    req.headers.set(
        HttpHeaders.userAgentHeader, 'APRSlocus/${AppState.appVersion}');
    final resp = await req.close().timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return null;
    final body = await resp.transform(utf8.decoder).join();
    final data = jsonDecode(body);
    if (data is! List) return null;

    final tags = <String>[];
    for (final r in data) {
      if (r is! Map) continue;
      if (r['prerelease'] == true) continue; // 只用正式版
      final tag = (r['tag_name'] ?? '')
          .toString()
          .replaceFirst(RegExp(r'^[Vv]'), '');
      if (tag.isNotEmpty) tags.add(tag);
    }
    if (tags.isEmpty) return null;
    tags.sort((a, b) => compareVersions(b, a)); // 新 → 旧
    return tags.first;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

Future<void> _showUpdateDialog(
    BuildContext context, AppState state, String tag) {
  final s = S.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.system_update_rounded, color: C.blue, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(s.newVersionTitle(tag),
                style: ts(16, w: FontWeight.w700)),
          ),
        ],
      ),
      content: Text(s.newVersionFound, style: ts(13, c: C.slate, h: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(s.backupLater, style: ts(13, c: C.grey)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: C.blue,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CheckUpdatePage(state: state)),
            );
          },
          child: Text(s.checkUpdate,
              style: ts(13, c: Colors.white, w: FontWeight.w600)),
        ),
      ],
    ),
  );
}

/// 版本比较：支持 `1.2.5` / `1.2.5.b` / `v1.0.0`。
///
/// 与「检查更新」页保持同一套规则：字母后缀视为修复版
/// （`1.2.5.b > 1.2.5`），数字段 > 字母段（`1.2.6 > 1.2.5.b`）。
/// 返回 >0 表示 a 更新。
int compareVersions(String a, String b) {
  final sa = a.replaceAll(RegExp('^v'), '').split(RegExp(r'[._-]'));
  final sb = b.replaceAll(RegExp('^v'), '').split(RegExp(r'[._-]'));
  const letters = 'abcdefghijklmnopqrstuvwxyz';
  final len = sa.length > sb.length ? sa.length : sb.length;
  for (var i = 0; i < len; i++) {
    final hasA = i < sa.length;
    final hasB = i < sb.length;
    if (!hasA && hasB) return -1;
    if (hasA && !hasB) return 1;
    final x = sa[i];
    final y = sb[i];
    final xv = int.tryParse(x);
    final yv = int.tryParse(y);
    if (xv != null && yv != null) {
      if (xv != yv) return xv - yv;
    } else if (xv != null && yv == null) {
      return 1;
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
