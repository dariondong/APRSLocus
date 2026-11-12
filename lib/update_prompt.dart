import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'check_update_page.dart';
import 'pinned_http.dart';
import 'state.dart';
import 'theme.dart';
import 'version_compare.dart';
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
    final latest = await _fetchLatestTag(state.updateChannelBase);
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

Future<String?> _fetchLatestTag(String base) async {
  // 渠道清单与地址都由官网下发（`lib/update_channels.dart`），这里只拿
  // 「当前这条渠道的 API 根」拼地址 —— 地址改了不必发版。
  final url = '$base/DarionDong/APRSLocus/releases';
  // 与更新页同一套规则：目标是自建服务器才用钉扎证书，其余用默认行为。
  final client = HttpClient(context: pinnedContextFor(url))
    ..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await client
        .getUrl(Uri.parse(url))
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

// 版本比较 compareVersions 已移到 version_compare.dart：最低版本闸门
// （lib/min_version.dart）也要用它，而那边不该为一个函数把整套界面拉进来。
