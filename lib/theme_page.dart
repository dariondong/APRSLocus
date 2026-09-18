import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;

import 'backup_io.dart' if (dart.library.html) 'backup_io_web.dart' as text_io;
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'theme_icon_io.dart' if (dart.library.html) 'theme_icon_io_web.dart'
    as icon_io;
import 'theme_icons.dart';
import 'theme_model.dart';
import 'theme_store.dart';
import 'theme_text.dart';
import 'widgets.dart';

/// 主题页：把界面的**颜色 / 图标 / 文字**变成用户可以自己改、并且能导出成
/// JSON 分享或备份的东西。
///
/// 交互上有两个刻意的决定：
///
/// 1. **改动即时生效**（不等「保存」按钮）：主题是用来试的，改完看不到效果
///    就得靠想象。所以每次改动都直接 apply + persist，页面上同时能看到结果。
///
/// 2. **内置预设不可直接编辑**，只能「复制为我的主题」再改。否则用户改了一套
///    预设、又想要回原样时，只能靠「恢复默认」逐项猜——而预设本身是应用的一部分，
///    不该被改坏。
class ThemePage extends StatefulWidget {
  final AppState state;

  const ThemePage({super.key, required this.state});

  @override
  State<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> {
  AppState get st => widget.state;
  ThemeController get tc => ThemeController.instance;

  bool _busy = false;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  /// 每次改动后统一走这里：应用 → 落盘 → 通知全局刷新
  void _commit() {
    // 主题自带深色偏好时，一并切换（否则「暗夜」在浅色模式下的对比度是错的）
    final d = tc.active.dark;
    if (d != null && d != st.darkMode) st.darkMode = d;
    st.applySavedTheme();
    st.persist();
    setState(() {});
  }

  /// 编辑目标：内置预设不可改，需要先复制
  bool get _editable => !tc.active.builtin;

  AppTheme get _t => tc.active;

  void _mutate(void Function(AppTheme t) f) {
    if (!_editable) return;
    final t = _t;
    f(t);
    tc.upsert(t);
    _commit();
  }

  // ─── 主题列表 ───

  Widget _themeList(S s) {
    final list = tc.all;
    return Column(
      children: [
        for (final t in list)
          InkWell(
            onTap: () {
              tc.setActive(t.id);
              _commit();
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
              ),
              child: Row(
                children: [
                  _swatchPreview(t),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _themeName(s, t),
                                style: ts(13, w: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (t.builtin) ...[
                              const SizedBox(width: 6),
                              Text(s.themePresetTag,
                                  style: ts(9, c: C.grey)),
                            ],
                          ],
                        ),
                        if (t.id == tc.activeId)
                          Text(s.themeActive,
                              style: ts(10, c: C.green, w: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (t.id == tc.activeId)
                    Icon(Icons.check_circle_rounded, size: 18, color: C.green),
                  _themeMenu(s, t),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 主题预览色块：让用户不用点进去就能分辨主题
  Widget _swatchPreview(AppTheme t) {
    final isDark = t.dark ?? st.darkMode;
    Color c(String id) => t.colorOf(id, isDark: isDark);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: c('background'),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: C.border),
      ),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: c('primary'),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),
    );
  }

  /// 主题显示名：内置预设的名字要跟着界面语言走
  String _themeName(S s, AppTheme t) {
    switch (t.id) {
      case 'builtin:default':
        return s.themePresetDefault;
      case 'builtin:ocean':
        return s.themePresetOcean;
      case 'builtin:forest':
        return s.themePresetForest;
      case 'builtin:midnight':
        return s.themePresetMidnight;
      case 'builtin:sunset':
        return s.themePresetSunset;
      case 'builtin:contrast':
        return s.themePresetContrast;
    }
    return t.name;
  }

  Widget _themeMenu(S s, AppTheme t) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 18, color: C.grey),
      tooltip: '',
      onSelected: (v) {
        switch (v) {
          case 'dup':
            _duplicate(s, t);
          case 'rename':
            _rename(s, t);
          case 'delete':
            _delete(s, t);
          case 'export':
            _exportOne(s, t);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'dup',
          child: Text(s.themeDuplicate, style: ts(12)),
        ),
        if (!t.builtin)
          PopupMenuItem(
            value: 'rename',
            child: Text(s.themeRename, style: ts(12)),
          ),
        PopupMenuItem(
          value: 'export',
          child: Text(s.themeExport, style: ts(12)),
        ),
        if (!t.builtin)
          PopupMenuItem(
            value: 'delete',
            child: Text(s.themeDelete,
                style: ts(12, c: C.red)),
          ),
      ],
    );
  }

  void _duplicate(S s, AppTheme src) {
    final copy = tc.duplicateOf(src);
    tc.upsert(copy);
    tc.setActive(copy.id);
    _commit();
    _toast(s.themeSaved);
  }

  Future<void> _rename(S s, AppTheme t) async {
    final name = await _promptText(
      title: s.themeRename,
      initial: t.name,
      hint: s.themeNameHint,
    );
    if (name == null) return;
    _mutate((x) {
      x.name = tc.uniqueName(name);
    });
  }

  Future<void> _delete(S s, AppTheme t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.themeDelete, style: T.h2),
        content: Text(s.themeDeleteConfirm(_themeName(s, t)),
            style: ts(12, c: C.slate, h: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(ctx).cancel, style: ts(13, c: C.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.of(ctx).delete, style: ts(13)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    tc.remove(t.id);
    _commit();
  }

  // ─── 颜色 ───

  Widget _colorsSection(S s) {
    return SettingsSectionCard(
      title: s.themeColors,
      subtitle: s.themeColorsDesc,
      icon: Icons.palette_rounded,
      color: C.cyan,
      trailing: _editable
          ? null
          : Text(s.themeBuiltinHint, style: ts(9, c: C.grey)),
      children: [
        for (final token in kThemeColorTokens) _colorRow(s, token),
      ],
    );
  }

  Widget _colorRow(S s, ThemeColorToken token) {
    final isDark = _t.dark ?? st.darkMode;
    final cur = _t.colorOf(token.id, isDark: isDark);
    final overridden = _t.overridesColor(token.id);
    return InkWell(
      onTap: _editable ? () => _pickColor(s, token) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: cur,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: C.borderStrong),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_tokenName(s, token.id),
                  style: ts(12, c: C.slate), maxLines: 1),
            ),
            if (overridden)
              Text(
                hexOfColor(cur),
                style: mono(10, c: C.grey),
              ),
            if (overridden && _editable)
              IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(Icons.restart_alt_rounded,
                    size: 15, color: C.grey),
                onPressed: () => _mutate((t) => t.colors.remove(token.id)),
              )
            else
              const SizedBox(width: 28),
          ],
        ),
      ),
    );
  }

  String _tokenName(S s, String id) {
    switch (id) {
      case 'primary':
        return s.themeTokenPrimary;
      case 'surface':
        return s.themeTokenSurface;
      case 'background':
        return s.themeTokenBackground;
      case 'backgroundSoft':
        return s.themeTokenBackgroundSoft;
      case 'textPrimary':
        return s.themeTokenTextPrimary;
      case 'textSecondary':
        return s.themeTokenTextSecondary;
      case 'textMuted':
        return s.themeTokenTextMuted;
      case 'divider':
        return s.themeTokenDivider;
      case 'success':
        return s.themeTokenSuccess;
      case 'warning':
        return s.themeTokenWarning;
      case 'danger':
        return s.themeTokenDanger;
      case 'info':
        return s.themeTokenInfo;
    }
    return id;
  }

  Future<void> _pickColor(S s, ThemeColorToken token) async {
    final isDark = _t.dark ?? st.darkMode;
    var hex = hexOfColor(_t.colorOf(token.id, isDark: isDark));
    final ctrl = TextEditingController(text: hex);
    const palette = [
      '2563EB', '1D4ED8', '0EA5E9', '0E7490', '0EA5A4', '14B8A6',
      '16A34A', '65A30D', 'D97706', 'EA580C', 'DC2626', 'E11D48',
      'DB2777', '7C3AED', '4F46E5', '475569', '64748B', '0F172A',
      'FFFFFF', 'F3F5F9', 'E5E9F0', '94A0B2', '253044', '000000',
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(s.themePickColor, style: T.h2),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: parseHexColor(hex) ?? C.grey,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: C.borderStrong),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixText: '#',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          final p = parseHexColor(v);
                          if (p != null) setD(() => hex = hexOfColor(p));
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in palette)
                      GestureDetector(
                        onTap: () {
                          setD(() => hex = p);
                          ctrl.text = p;
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: parseHexColor(p),
                            shape: BoxShape.circle,
                            border: Border.all(color: C.borderStrong),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (_t.overridesColor(token.id))
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.themeReset, style: ts(13, c: C.grey)),
              ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.blue),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(S.of(ctx).ok, style: ts(13)),
            ),
          ],
        ),
      ),
    );
    if (ok == null) return;
    if (ok == false) {
      _mutate((t) => t.colors.remove(token.id));
      return;
    }
    _mutate((t) => t.colors[token.id] = hex);
  }

  // ─── 圆角 ───

  Widget _radiusSection(S s) {
    return SettingsSectionCard(
      title: s.themeRadius,
      subtitle: s.themeRadiusDesc,
      icon: Icons.rounded_corner_rounded,
      color: C.purple,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: Slider(
                  value: _t.radius.clamp(kThemeMinRadius, kThemeMaxRadius),
                  min: kThemeMinRadius,
                  max: kThemeMaxRadius,
                  divisions: 14,
                  label: _t.radius.round().toString(),
                  activeColor: C.purple,
                  onChanged:
                      _editable ? (v) => _mutate((t) => t.radius = v) : null,
                ),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  _t.radius.round().toString(),
                  style: ts(12, c: C.slate, w: FontWeight.w600),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 图标 ───

  Widget _iconsSection(S s) {
    return SettingsSectionCard(
      title: s.themeIcons,
      subtitle: s.themeIconsDesc,
      icon: Icons.category_rounded,
      color: C.orange,
      children: [
        if (!icon_io.supportsFileIcons)
          SettingsHint(s.themeIconWebHint, color: C.orange),
        for (final slot in kThemeIconSlots) _iconRow(s, slot),
      ],
    );
  }

  /// 插槽已选了哪个主题键（用来把图标行与它服务的那条文案对应起来）
  static const Map<String, String> _slotTextKey = {
    'navMap': 'map',
    'navStations': 'stations',
    'navMessages': 'messages',
    'navPackets': 'packets',
    'navSettings': 'settings',
    'catRadio': 'radioCat',
    'catBeacon': 'beaconCat',
    'catConnection': 'connectionCat',
    'catDisplay': 'displayCat',
    'catDevice': 'deviceCat',
    'catData': 'dataCat',
    'catAdvanced': 'advancedCat',
    'catUpdate': 'updateCat',
  };

  Widget _iconRow(S s, ThemeIconSlot slot) {
    final overridden = _t.iconOf(slot.id) != null;
    final label = Tx.of(context).byKey(_slotTextKey[slot.id] ?? '');
    return InkWell(
      onTap: _editable ? () => _pickIcon(s, slot) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: C.greyBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: tc.buildSlotIcon(
                  slot.id,
                  size: 19,
                  color: C.ink,
                  fallbackIcon: themeIconByName(slot.defaultIcon),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: ts(12, c: C.slate), maxLines: 1),
            ),
            if (overridden)
              Text(
                _iconRefLabel(_t.iconOf(slot.id)!),
                style: mono(9, c: C.grey),
              ),
            if (overridden && _editable)
              IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(Icons.restart_alt_rounded, size: 15, color: C.grey),
                onPressed: () => _mutate((t) => t.icons.remove(slot.id)),
              )
            else
              const SizedBox(width: 28),
          ],
        ),
      ),
    );
  }

  String _iconRefLabel(String ref) =>
      ref.startsWith('lib:') ? ref.substring(4) : ref.substring(5);

  Future<void> _pickIcon(S s, ThemeIconSlot slot) async {
    final chosen = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.white,
      builder: (ctx) => _IconPickerSheet(
        title: s.themePickIcon,
        searchHint: s.themePickIconSearch,
        importLabel: s.themeIconImport,
        importHint: s.themeIconImportHint,
        resetLabel: s.themeReset,
        canImport: _editable && icon_io.supportsFileIcons,
        // 返回 null = 关闭；返回 '' = 恢复默认；其余为引用
        onImport: () async => _importIcon(s),
      ),
    );
    if (chosen == null) return;
    if (chosen.isEmpty) {
      _mutate((t) => t.icons.remove(slot.id));
      return;
    }
    _mutate((t) => t.icons[slot.id] = chosen);
  }

  /// 从图片文件导入。返回 `file:xxx` 引用；失败返回 null（提示已弹）
  Future<String?> _importIcon(S s) async {
    final r = await icon_io.importIconFromPicker();
    if (!mounted) return null;
    if (r.isOk) {
      _toast(s.themeIconImportDone(r.name ?? ''));
      return r.ref;
    }
    switch (r.error) {
      case icon_io.IconImportError.cancelled:
        return null; // 用户自己取消，不提示
      case icon_io.IconImportError.tooLarge:
        _toast(s.themeIconErrTooLarge);
      case icon_io.IconImportError.badFormat:
        _toast(s.themeIconErrFormat);
      case icon_io.IconImportError.unsupportedPlatform:
        _toast(s.themeIconErrUnsupported);
      default:
        _toast(s.themeIconErrFailed);
    }
    return null;
  }

  // ─── 文字 ───

  Widget _textsSection(S s) {
    final tx = Tx.of(context);
    final keys = kThemeTextKeys.toList()..sort();
    return SettingsSectionCard(
      title: s.themeTexts,
      subtitle: s.themeTextsDesc,
      icon: Icons.text_fields_rounded,
      color: C.green,
      children: [
        for (final k in keys)
          InkWell(
            onTap: _editable ? () => _editText(s, k) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: C.border, width: 0.4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.byKey(k),
                            style: ts(12, c: C.ink), maxLines: 1),
                        Text(k, style: mono(9, c: C.grey)),
                      ],
                    ),
                  ),
                  if (_t.textOf(k) != null && _editable)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: Icon(Icons.restart_alt_rounded,
                          size: 15, color: C.grey),
                      onPressed: () => _mutate((t) => t.texts.remove(k)),
                    )
                  else
                    const SizedBox(width: 28),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _editText(S s, String key) async {
    final cur = Tx.of(context).byKey(key);
    final v = await _promptText(
      title: s.themeEditText,
      initial: cur,
      hint: s.themeTextHint,
      resetLabel: _t.textOf(key) != null ? s.themeReset : null,
    );
    if (v == null) return;
    if (v.isEmpty) {
      _mutate((t) => t.texts.remove(key));
      return;
    }
    _mutate((t) => t.texts[key] = v);
  }

  // ─── 导入 / 导出 ───

  Widget _ioSection(S s) {
    return SettingsSectionCard(
      title: s.themeIo,
      subtitle: s.themeIoDesc,
      icon: Icons.swap_vert_rounded,
      color: C.blue,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _btn(s.themeExportAll, Icons.ios_share_rounded, C.blue,
                  () => unawaited(_exportAll(s))),
              _btn(s.themeImport, Icons.folder_open_rounded, C.green,
                  () => unawaited(_import())),
              _btn(s.themeImportPaste, Icons.content_paste_rounded, C.green,
                  () => unawaited(_import(fromClipboard: true))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          child: Row(
            children: [
              if (_editable)
                _btn(s.themeResetAll, Icons.restart_alt_rounded, C.red,
                    () => unawaited(_resetAll())),
            ],
          ),
        ),
      ],
    );
  }

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onPressed: _busy ? null : onTap,
      icon: Icon(icon, size: 15, color: color),
      label: Text(label, style: ts(12, c: color)),
    );
  }

  Future<void> _resetAll() async {
    _mutate((t) {
      t.colors.clear();
      t.texts.clear();
      t.icons.clear();
      t.radius = kThemeDefaultRadius;
    });
  }

  Future<void> _exportAll(S s) async {
    setState(() => _busy = true);
    String? path;
    try {
      path = await text_io.saveBackupFile(
        themeFileName(DateTime.now()),
        tc.exportBundleJson(),
        mimeType: 'application/json',
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
    if (path == null) {
      _toast(s.backupExportFailed);
      return;
    }
    _toast(s.backupSavedTo(path));
  }

  Future<void> _exportOne(S s, AppTheme t) async {
    setState(() => _busy = true);
    String? path;
    try {
      path = await text_io.saveBackupFile(
        themeFileName(DateTime.now()),
        tc.exportOneJson(t),
        mimeType: 'application/json',
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
    if (path == null) {
      _toast(s.backupExportFailed);
      return;
    }
    _toast(s.backupSavedTo(path));
  }

  Future<void> _import({bool fromClipboard = false}) async {
    final s = S.of(context);
    String? text;
    if (fromClipboard) {
      try {
        final d = await Clipboard.getData('text/plain');
        text = d?.text;
      } catch (_) {}
      if (!mounted) return;
      if ((text ?? '').trim().isEmpty) {
        _toast(s.backupPasteEmpty);
        return;
      }
    } else {
      setState(() => _busy = true);
      try {
        final r = await text_io.pickBackupFile();
        if (!mounted) return;
        setState(() => _busy = false);
        if (r.file == null) {
          switch (r.error) {
            case text_io.BackupPickError.cancelled:
              return;
            case text_io.BackupPickError.tooLarge:
              _toast(s.backupErrTooLarge);
              return;
            case text_io.BackupPickError.unsupported:
              _toast(s.backupErrUnsupported);
              return;
            default:
              _toast(s.backupErrRead);
              return;
          }
        }
        text = r.file!.content;
      } catch (_) {
        if (mounted) setState(() => _busy = false);
        _toast(s.backupErrRead);
        return;
      }
    }
    if (!mounted) return;
    _applyImported(s, text ?? '');
  }

  void _applyImported(S s, String text) {
    try {
      final bundle = parseThemeJson(text);
      for (final t in bundle.themes) {
        tc.upsert(t);
      }
      // 导入的第一条直接启用：用户的意图就是「用上它」
      tc.setActive(bundle.themes.first.id);
      _commit();
      final extra = bundle.warnings.isEmpty
          ? ''
          : ' · ${s.backupSkipped(bundle.warnings.length)}';
      _toast('${s.themeImportDone(bundle.themes.length)}$extra');
    } on ThemeException catch (e) {
      switch (e.code) {
        case ThemeErrorCode.notJson:
          _toast(s.themeErrNotJson);
        case ThemeErrorCode.notTheme:
          _toast(s.themeErrNotTheme);
        case ThemeErrorCode.schemaNewer:
          _toast(s.themeErrSchemaNewer);
        case ThemeErrorCode.empty:
        case ThemeErrorCode.noThemes:
          _toast(s.themeErrEmpty);
      }
    } catch (_) {
      _toast(s.themeErrNotTheme);
    }
  }

  // ─── 通用对话框 ───

  Future<String?> _promptText({
    required String title,
    required String initial,
    String? hint,
    String? resetLabel,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: T.h2),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          if (resetLabel != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: Text(resetLabel, style: ts(13, c: C.grey)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(ctx).cancel, style: ts(13, c: C.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.blue),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(S.of(ctx).ok, style: ts(13)),
          ),
        ],
      ),
    );
    // 返回 null = 取消；'' = 恢复默认；其余为输入内容
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SettingsPageShell(
      title: s.themeTitle,
      subtitle: s.themeSubtitle,
      icon: Icons.brush_rounded,
      color: C.purple,
      body: Column(
        children: [
          SettingsSectionCard(
            title: s.themePresets,
            subtitle: s.themeSubtitle,
            icon: Icons.style_rounded,
            color: C.purple,
            children: [_themeList(s)],
          ),
          const SizedBox(height: 16),
          if (!_editable)
            SettingsHint(s.themeBuiltinHint, color: C.orange)
          else ...[
            _colorsSection(s),
            const SizedBox(height: 16),
            _radiusSection(s),
            const SizedBox(height: 16),
            _iconsSection(s),
            const SizedBox(height: 16),
            _textsSection(s),
          ],
          const SizedBox(height: 16),
          _ioSection(s),
        ],
      ),
    );
  }
}

/// 图标选择：搜索 + 网格 + 「从图片导入」+ 「恢复默认」
class _IconPickerSheet extends StatefulWidget {
  final String title;
  final String searchHint;
  final String importLabel;
  final String importHint;
  final String resetLabel;
  final bool canImport;

  /// 返回导入得到的引用（或 null）
  final Future<String?> Function() onImport;

  const _IconPickerSheet({
    required this.title,
    required this.searchHint,
    required this.importLabel,
    required this.importHint,
    required this.resetLabel,
    required this.canImport,
    required this.onImport,
  });

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final names = kThemeIconNames
        .where((n) => _q.isEmpty || n.contains(_q.toLowerCase()))
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Text(widget.title, style: T.h3),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context, ''),
                    child: Text(widget.resetLabel, style: ts(12, c: C.grey)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: C.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  hintText: widget.searchHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _q = v.trim()),
              ),
            ),
            if (widget.canImport)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final ref = await widget.onImport();
                        if (ref != null && context.mounted) {
                          Navigator.pop(context, ref);
                        }
                      },
                      icon: Icon(Icons.image_rounded, size: 15, color: C.orange),
                      label: Text(widget.importLabel,
                          style: ts(12, c: C.orange)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.importHint,
                          style: ts(9, c: C.grey), maxLines: 1),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 58,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: names.length,
                itemBuilder: (_, i) {
                  final n = names[i];
                  final ic = themeIconByName(n);
                  return InkWell(
                    onTap: () => Navigator.pop(context, 'lib:$n'),
                    borderRadius: BorderRadius.circular(8),
                    child: Tooltip(
                      message: n,
                      child: Center(
                        child: Icon(ic, size: 22, color: C.ink),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
