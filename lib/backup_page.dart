import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:shared_preferences/shared_preferences.dart';

import 'backup.dart';
import 'backup_io.dart' if (dart.library.html) 'backup_io_web.dart' as backup_io;
import 'exit_app.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme_store.dart';
import 'theme_model.dart';
import 'theme.dart';
import 'widgets.dart';

/// 备份与恢复页：把「设置 + 数据」导出成一个 JSON，或从 JSON 恢复。
///
/// 界面按「导出 / 导入」两段分开，每段都以**分组勾选**为核心：
/// 想换机的人整份搬，只想搬设置的人把消息/群聊取消掉即可。
/// 导入永远先出预览（来源版本、导出时间、各组条数），确认后才覆盖 ——
/// 覆盖是不可撤销的动作，不能让用户在一无所知的情况下点下去。
class BackupPage extends StatefulWidget {
  final AppState state;

  const BackupPage({super.key, required this.state});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  /// 导出勾选：默认全选（备份的常见诉求是「整份搬走」）
  final Set<BackupCategory> _expCats = kBackupGroups.map((g) => g.id).toSet();

  /// 导入勾选：解析出备份内容后才填写，默认勾选备份里实际存在的组
  final Set<BackupCategory> _impCats = {};

  bool _busy = false;
  String? _lastPath;

  /// 备份里是否带上主题引用的图片本体（默认带：备份的用途就是「换机搬走」）
  bool _withThemeImages = true;

  /// 本机各分组的条目数（用于告诉用户「这组有多少东西」）
  Map<BackupCategory, int> _counts = const {};

  /// 已解析、待导入的备份
  BackupData? _data;
  String _dataName = '';

  AppState get st => widget.state;

  @override
  void initState() {
    super.initState();
    _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    try {
      // 先落盘再数：不然「刚改完就进这个页面」会看到旧数字
      await st.persistNow();
      final p = await SharedPreferences.getInstance();
      final counts = backupCounts(
        snapshotFromPrefs(p),
        kBackupGroups.map((g) => g.id).toSet(),
      );
      if (!mounted) return;
      setState(() => _counts = counts);
    } catch (_) {}
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  /// 备份解析/读取失败 → 用户看得懂的文案
  String _errText(S s, BackupErrorCode code) {
    switch (code) {
      case BackupErrorCode.notJson:
        return s.backupErrNotJson;
      case BackupErrorCode.notBackup:
        return s.backupErrNotBackup;
      case BackupErrorCode.schemaNewer:
        return s.backupErrSchemaNewer;
      case BackupErrorCode.empty:
        return s.backupErrEmpty;
    }
  }

  // ─── 导出 ───

  Future<void> _export({required bool toFile}) async {
    final s = S.of(context);
    if (_expCats.isEmpty) {
      _toast(s.backupNoSelection);
      return;
    }
    setState(() => _busy = true);
    String? json;
    String? path;
    try {
      await st.flushForBackup();
      final p = await SharedPreferences.getInstance();
      final snap = snapshotFromPrefs(p);
      // 主题分组里存的是「引用」（file:xxx.png），而那几张图本身在应用目录里。
      // 不把它们嵌进来，换机恢复后主题会指向不存在的文件 —— 界面不会坏，
      // 但用户会以为「备份没备全」。这里按用户的选择嵌进去。
      if (_withThemeImages && _expCats.contains(BackupCategory.theme)) {
        final raw = snap[ThemeController.kPrefsKey];
        if (raw is String && raw.isNotEmpty) {
          final images = await ThemeController.instance.collectImagesForExport();
          if (images.isNotEmpty) snap[ThemeController.kPrefsKey] = attachImages(raw, images);
        }
      }
      json = buildBackupJson(
        snapshot: snap,
        categories: _expCats.toSet(),
        appVersion: AppState.appVersion,
        platform: defaultTargetPlatform.name,
      );
      if (!toFile) {
        await Clipboard.setData(ClipboardData(text: json));
      } else {
        path = await backup_io.saveBackupFile(
          backupFileName(DateTime.now()),
          json,
        );
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastPath = path;
    });
    if (!toFile) {
      _toast(s.backupCopyDone);
      return;
    }
    if (path == null) {
      _toast(s.backupExportFailed);
      return;
    }
    await _showSavedDialog(s, path);
  }

  Future<void> _showSavedDialog(S s, String path) async {
    final act = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.backupExportDone, style: T.h2),
        content: Text(s.backupSavedTo(path), style: ts(12, c: C.slate, h: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'copy'),
            child: Text(S.of(ctx).adifCopyPath, style: ts(13, c: C.blue)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.blue),
            onPressed: () => Navigator.pop(ctx, 'done'),
            child: Text(S.of(ctx).done, style: ts(13)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (act == 'copy') {
      await Clipboard.setData(ClipboardData(text: path));
      if (!mounted) return;
      _toast(s.adifPathCopied);
    }
  }

  // ─── 导入 ───

  Future<void> _pick() async {
    final s = S.of(context);
    if (_busy) return;
    setState(() => _busy = true);
    backup_io.BackupPickResult r;
    try {
      r = await backup_io.pickBackupFile();
    } catch (_) {
      r = const backup_io.BackupPickResult.fail(
        backup_io.BackupPickError.readFailed,
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final f = r.file;
    if (f == null) {
      switch (r.error) {
        case backup_io.BackupPickError.cancelled:
          return; // 用户自己取消，不提示
        case backup_io.BackupPickError.tooLarge:
          _toast(s.backupErrTooLarge);
          return;
        case backup_io.BackupPickError.unsupported:
          _toast(s.backupErrUnsupported);
          return;
        default:
          _toast(s.backupErrRead);
          return;
      }
    }
    _loadPicked(s, f.name, f.content);
  }

  Future<void> _paste() async {
    final s = S.of(context);
    Object? text;
    try {
      final d = await Clipboard.getData('text/plain');
      text = d?.text;
    } catch (_) {}
    if (!mounted) return;
    final t = (text ?? '').toString();
    if (t.trim().isEmpty) {
      _toast(s.backupPasteEmpty);
      return;
    }
    _loadPicked(s, 'clipboard', t);
  }

  void _loadPicked(S s, String name, String content) {
    try {
      final data = parseBackupJson(content);
      setState(() {
        _data = data;
        _dataName = name;
        _impCats
          ..clear()
          ..addAll(data.categories);
      });
    } on BackupException catch (e) {
      _toast(_errText(s, e.code));
    } catch (_) {
      _toast(s.backupErrRead);
    }
  }

  Future<void> _doImport() async {
    final s = S.of(context);
    final data = _data;
    if (data == null) return;
    final cats =
        _impCats.where((c) => data.groups.containsKey(c)).toSet();
    if (cats.isEmpty) {
      _toast(s.backupImportNothing);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.backupImportConfirmTitle, style: T.h2),
        content: Text(s.backupImportConfirm, style: ts(12, c: C.slate, h: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel, style: ts(13, c: C.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.backupImportSelected, style: ts(13)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    BackupApplyResult? res;
    try {
      res = await applyBackup(data, cats);
      if (res.applied > 0) await st.reloadFromPrefs();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
    if (res == null) {
      _toast(s.backupErrRead);
      return;
    }
    await _refreshCounts();
    if (!mounted) return;
    setState(() {
      _data = null;
      _impCats.clear();
    });
    await _showImportedDialog(s, res);
  }

  Future<void> _showImportedDialog(S s, BackupApplyResult res) async {
    final act = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final parts = <String>[s.backupImported(res.applied)];
        if (res.skipped > 0) parts.add(s.backupSkipped(res.skipped));
        parts.add(s.backupRestartHint);
        return AlertDialog(
          title: Text(s.backupRestartTitle, style: T.h2),
          content: Text(parts.join('\n\n'), style: ts(12, c: C.slate, h: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'later'),
              child: Text(s.backupLater, style: ts(13, c: C.grey)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.blue),
              onPressed: () => Navigator.pop(ctx, 'quit'),
              child: Text(s.backupRestartNow, style: ts(13)),
            ),
          ],
        );
      },
    );
    if (act == 'quit') await exitApplication();
  }

  // ─── 小组件 ───

  Widget _catRow({
    required S s,
    required String title,
    required String desc,
    required int count,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ts(12, w: FontWeight.w600)),
                  Text(desc, style: ts(10, c: C.grey, h: 1.35)),
                ],
              ),
            ),
            if (count > 0)
              Text(s.backupItems(count), style: ts(10, c: C.grey)),
          ],
        ),
      ),
    );
  }

  Widget _tip(String text, Color color, IconData icon) => SettingsHint(
        text,
        color: color,
        icon: icon,
      );

  Widget _buttons({required S s, required bool toFile}) {
    final busy = _busy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          if (toFile && !kIsWeb)
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: C.blue,
                  disabledBackgroundColor: C.greyBg,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: busy ? null : () => _export(toFile: true),
                icon: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_alt_rounded, size: 16),
                label: Text(s.backupExportToFile, style: ts(12)),
              ),
            ),
          if (toFile && !kIsWeb) const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: C.blue.withValues(alpha: 0.4)),
              ),
              onPressed: busy ? null : () => _export(toFile: false),
              icon: Icon(Icons.copy_all_rounded, size: 16, color: C.blue),
              label: Text(
                s.backupCopyJson,
                style: ts(12, c: C.blue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final all = _expCats.length == kBackupGroups.length;
    return SettingsPageShell(
      guideId: 'backup',
      // state 必须给：外壳靠它读写「引导已读」，只给 guideId 卡片会**静默不出现**
      // （tool/check_guides.py 把这条钉住了）
      state: st,
      title: s.backupTitle,
      subtitle: s.backupSubtitle,
      icon: Icons.settings_backup_restore_rounded,
      color: C.purple,
      body: Column(
        children: [
          SettingsSectionCard(
            title: s.backupTitle,
            subtitle: s.backupDesc,
            icon: Icons.info_outline_rounded,
            color: C.purple,
            children: [
              _tip(s.backupSecurityTip, C.orange, Icons.lock_outline_rounded),
              if (kIsWeb) _tip(s.backupWebHint, C.slate, Icons.language_rounded),
            ],
          ),
          const SizedBox(height: 16),

          // ─── 导出 ───
          SettingsSectionCard(
            title: s.backupExport,
            subtitle: s.backupExportDesc,
            icon: Icons.upload_file_rounded,
            color: C.green,
            trailing: TextButton(
              onPressed: () => setState(() {
                if (all) {
                  _expCats.clear();
                } else {
                  _expCats
                    ..clear()
                    ..addAll(kBackupGroups.map((g) => g.id));
                }
              }),
              child: Text(
                s.backupSelectAll,
                style: ts(11, c: all ? C.grey : C.blue),
              ),
            ),
            children: [
              for (final spec in kBackupGroups)
                _catRow(
                  s: s,
                  title: _catName(s, spec.id),
                  desc: _catDesc(s, spec.id),
                  count: _counts[spec.id] ?? 0,
                  value: _expCats.contains(spec.id),
                  color: C.green,
                  onChanged: (v) => setState(() {
                    if (v) {
                      _expCats.add(spec.id);
                    } else {
                      _expCats.remove(spec.id);
                    }
                  }),
                ),
              if (_lastPath != null)
                _tip(
                  s.backupSavedTo(_lastPath!),
                  C.green,
                  Icons.check_circle_outline_rounded,
                ),
              if (_expCats.contains(BackupCategory.theme))
                SettingsSwitch(
                  s.themeExportWithImages,
                  value: _withThemeImages,
                  color: C.green,
                  onChanged: (v) => setState(() => _withThemeImages = v),
                ),
              if (_expCats.contains(BackupCategory.theme))
                SettingsHint(
                  _withThemeImages
                      ? s.backupThemeImagesHint
                      : s.backupThemeImagesOff,
                  color: _withThemeImages ? C.green : C.orange,
                  icon: Icons.info_outline_rounded,
                ),
              _buttons(s: s, toFile: true),
            ],
          ),
          const SizedBox(height: 16),

          // ─── 导入 ───
          SettingsSectionCard(
            title: s.backupImport,
            subtitle: s.backupImportDesc,
            icon: Icons.download_rounded,
            color: C.orange,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    if (!kIsWeb) ...[
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: C.orange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _busy ? null : _pick,
                          icon: const Icon(Icons.folder_open_rounded, size: 16),
                          label: Text(s.backupPickFile, style: ts(12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: C.orange.withValues(alpha: 0.4),
                          ),
                        ),
                        onPressed: _busy ? null : _paste,
                        icon: Icon(
                          Icons.content_paste_rounded,
                          size: 16,
                          color: C.orange,
                        ),
                        label: Text(
                          s.backupPaste,
                          style: ts(12, c: C.orange),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_data != null) ..._preview(s, _data!),
            ],
          ),
        ],
      ),
    );
  }

  /// 导入预览：来源信息 + 各组条数 + 「导入所选」
  List<Widget> _preview(S s, BackupData data) {
    final stamp = data.exportedAt?.toLocal();
    final meta = <String>[
      if (data.appVersion.isNotEmpty) s.backupFromVersion(data.appVersion),
      if (stamp != null) s.backupExportedAt(_fmtTime(stamp)),
      if (_dataName.isNotEmpty) _dataName,
    ].join(' · ');
    return [
      Container(
        width: double.infinity,
        color: C.orangeBg,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.backupPreview,
              style: ts(12, w: FontWeight.w700, c: C.orange),
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(meta, style: ts(10, c: C.slate, h: 1.4)),
            ],
            if (data.skippedKeys > 0) ...[
              const SizedBox(height: 2),
              Text(
                s.backupSkipped(data.skippedKeys),
                style: ts(10, c: C.orange, h: 1.4),
              ),
            ],
          ],
        ),
      ),
      for (final cat in data.categories)
        _catRow(
          s: s,
          title: _catName(s, cat),
          desc: _catDesc(s, cat),
          count: data.countOf(cat),
          value: _impCats.contains(cat),
          color: C.orange,
          onChanged: (v) => setState(() {
            if (v) {
              _impCats.add(cat);
            } else {
              _impCats.remove(cat);
            }
          }),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: C.orange,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _busy ? null : _doImport,
            icon: const Icon(Icons.restore_rounded, size: 16),
            label: Text(s.backupImportSelected, style: ts(12)),
          ),
        ),
      ),
    ];
  }

  String _catName(S s, BackupCategory id) {
    switch (id) {
      case BackupCategory.settings:
        return s.backupCatSettings;
      case BackupCategory.stations:
        return s.backupCatStations;
      case BackupCategory.messages:
        return s.backupCatMessages;
      case BackupCategory.chats:
        return s.backupCatChats;
      case BackupCategory.translate:
        return s.backupCatTranslate;
      case BackupCategory.honors:
        return s.backupCatHonors;
      case BackupCategory.theme:
        // 复用主题页自己的文案：同一件事在两处用同一个词，用户才不会以为
        // 「主题」与「界面自定义」是两样东西。
        return s.themeTitle;
    }
  }

  String _catDesc(S s, BackupCategory id) {
    switch (id) {
      case BackupCategory.settings:
        return s.backupCatSettingsDesc;
      case BackupCategory.stations:
        return s.backupCatStationsDesc;
      case BackupCategory.messages:
        return s.backupCatMessagesDesc;
      case BackupCategory.chats:
        return s.backupCatChatsDesc;
      case BackupCategory.translate:
        return s.backupCatTranslateDesc;
      case BackupCategory.honors:
        return s.backupCatHonorsDesc;
      case BackupCategory.theme:
        return s.themeEntryDesc;
    }
  }

  /// 时间显示：不引 intl 的 DateFormat（这里只是给人看的参考值），
  /// 固定 `YYYY-MM-DD HH:MM` 反而在任何语言下都读得懂。
  String _fmtTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }
}
