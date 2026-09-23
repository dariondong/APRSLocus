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
import 'material.dart';

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

  /// 导出时是否把图片本体（base64）一并带走
  bool _withImages = true;

  /// 当前主题引用的图片总字节数（给体积提示用）
  int _imgBytes = 0;

  Future<void> _refreshImageSize() async {
    try {
      final n = await tc.imagesTotalBytes();
      if (!mounted) return;
      setState(() => _imgBytes = n);
    } catch (_) {}
  }

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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.border),
      ),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: c('primary'),
            borderRadius: BorderRadius.circular(6),
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
      case 'builtin:graphite':
        return s.themePresetGraphite;
      case 'builtin:sakura':
        return s.themePresetSakura;
      case 'builtin:terminal':
        return s.themePresetTerminal;
      case 'builtin:amber':
        return s.themePresetAmber;
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
                borderRadius: BorderRadius.circular(8),
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

  /// 选色对话框（令牌 / 分页签 / 强调色共用）。
  ///
  /// 返回：null=取消，''=恢复默认，其余为 `RRGGBB`。
  /// [allowReset] 为真才显示「恢复默认」——没有可恢复的东西时摆一个按钮
  /// 只会让人点了没反应。
  Future<String?> _pickColorDialog(
    S s, {
    required String title,
    required String initial,
    bool allowReset = false,
  }) async {
    var hex = initial;
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
          title: Text(title, style: T.h2),
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
                        borderRadius: BorderRadius.circular(8),
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
            if (allowReset)
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
    if (ok == null) return null;
    if (ok == false) return '';
    return hex;
  }

  Future<void> _pickColor(S s, ThemeColorToken token) async {
    final isDark = _t.dark ?? st.darkMode;
    final r = await _pickColorDialog(
      s,
      title: _tokenName(s, token.id),
      initial: hexOfColor(_t.colorOf(token.id, isDark: isDark)),
      allowReset: _t.overridesColor(token.id),
    );
    if (r == null) return;
    if (r.isEmpty) {
      _mutate((t) => t.colors.remove(token.id));
      return;
    }
    _mutate((t) => t.colors[token.id] = r);
  }


  /// 一行「标签 + 值」（可点编辑）
  Widget _textRow({
    required String label,
    required String value,
    required bool muted,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(
          children: [
            Text(label, style: ts(12, c: C.slate)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: ts(12, c: muted ? C.greyLight : C.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_rounded, size: 14, color: C.greyLight),
          ],
        ),
      ),
    );
  }

  Future<void> _editSkinField(S s, {required bool author}) async {
    final v = await _promptText(
      title: author ? s.themeAuthor : s.themeDescription,
      initial: author ? _t.author : _t.description,
      hint: author ? s.themeAuthorHint : s.themeDescHint,
    );
    if (v == null) return;
    _mutate((x) {
      if (author) {
        x.author = v;
      } else {
        x.description = v;
      }
    });
  }

  // ─── 表面 / 布局 / 分页签强调色 ───

  /// 卡片表面不透明度（要有背景图才有可见效果）
  Widget _surfaceSection(S s) {
    return SettingsSectionCard(
      title: s.themeSurface,
      subtitle: s.themeSurfaceDesc,
      icon: Icons.layers_rounded,
      color: C.cyan,
      children: [
        _sliderRow(
          s: s,
          label: s.themeSurfaceAlpha,
          value: _t.surfaceAlpha,
          min: 0.3,
          max: 1.0,
          decimals: 2,
          hint: _t.hasBackground ? s.themeSurfaceAlphaDesc : s.themeSurfaceNoBg,
          onChanged: (v) => _mutate((x) => x.surfaceAlpha = v),
        ),
      ],
    );
  }

  /// 界面密度 + 字体
  Widget _layoutSection(S s) {
    return SettingsSectionCard(
      title: s.themeLayout,
      subtitle: s.themeLayoutDesc,
      icon: Icons.density_medium_rounded,
      color: C.slate,
      children: [
        _chipGroup(
          s: s,
          label: s.themeDensity,
          values: kThemeDensities,
          current: _t.density,
          nameOf: (v) => _densityName(s, v),
          onPick: (v) => _mutate((x) => x.density = v),
        ),
        SettingsHint(s.themeDensityHint, color: C.slate),
        const SizedBox(height: 4),
        _chipGroup(
          s: s,
          label: s.themeFont,
          values: kThemeFonts.map((f) => f.id).toList(),
          current: _t.font,
          nameOf: (v) => _fontName(s, v),
          onPick: (v) => _mutate((x) => x.font = v),
        ),
        // 字体只用系统已装的：不内置字体文件（一款中文字体 5~10MB）。
        // 所以要如实说明「缺失时会回退」，否则用户会以为选项没生效。
        SettingsHint(s.themeFontHint,
            color: C.slate, icon: Icons.info_outline_rounded),
      ],
    );
  }

  /// 统一强调渐变 + 分页签强调色
  Widget _tabsSection(S s) {
    return SettingsSectionCard(
      title: s.themeTabs,
      subtitle: s.themeTabsDesc,
      icon: Icons.tab_rounded,
      color: C.indigo,
      children: [
        SettingsSwitch(
          s.themeUniformAccent,
          value: _t.uniformAccent,
          color: C.indigo,
          onChanged: (v) => _mutate((x) => x.uniformAccent = v),
        ),
        if (_t.uniformAccent) ...[
          _tokenRow(s, 'accentFrom', s.themeAccentFrom),
          _tokenRow(s, 'accentTo', s.themeAccentTo),
        ],
        const Divider(height: 1),
        for (final k in kThemeTabKeys) _tabColorRow(s, k),
      ],
    );
  }

  /// 单行颜色令牌（标签与令牌解耦，便于强调色这类专用项复用）
  Widget _tokenRow(S s, String tokenId, String label) {
    final isDark = _t.dark ?? st.darkMode;
    final cur = _t.colorOf(tokenId, isDark: isDark);
    return InkWell(
      onTap: _editable ? () => _pickToken(s, tokenId, label) : null,
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
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.borderStrong),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: ts(12, c: C.slate))),
            Text(hexOfColor(cur), style: mono(10, c: C.grey)),
          ],
        ),
      ),
    );
  }

  /// 单个页签的强调色行。未指定时显示「跟随主色」而不是摆一个假颜色 ——
  /// 后者会让用户以为已经被改过了。
  Widget _tabColorRow(S s, String tabKey) {
    final t = _t;
    final overridden = t.tabColors.containsKey(tabKey);
    final shown = overridden ? (parseHexColor(t.tabColors[tabKey]) ?? C.blue) : C.blue;
    return InkWell(
      onTap: _editable ? () => _pickTabColor(s, tabKey) : null,
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
                color: shown,
                shape: BoxShape.circle,
                border: Border.all(color: C.borderStrong),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(_tabName(s, tabKey), style: ts(12, c: C.slate))),
            Text(
              overridden ? s.themeOverridden : s.themeFollowsPrimary,
              style: ts(10, c: overridden ? C.grey : C.greyLight),
            ),
            if (overridden && _editable)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(Icons.restart_alt_rounded, size: 15, color: C.grey),
                onPressed: () => _mutate((x) => x.tabColors.remove(tabKey)),
              )
            else
              const SizedBox(width: 28),
          ],
        ),
      ),
    );
  }

  String _tabName(S s, String key) {
    switch (key) {
      case 'tabMap':
        return s.map;
      case 'tabStations':
        return s.stations;
      case 'tabMessages':
        return s.messages;
      case 'tabPackets':
        return s.packets;
    }
    return s.settings;
  }

  Future<void> _pickTabColor(S s, String tabKey) async {
    final r = await _pickColorDialog(
      s,
      title: _tabName(s, tabKey),
      initial: _t.tabColors[tabKey] ?? hexOfColor(C.blue),
      allowReset: _t.tabColors.containsKey(tabKey),
    );
    if (r == null) return;
    if (r.isEmpty) {
      _mutate((x) => x.tabColors.remove(tabKey));
      return;
    }
    _mutate((x) => x.tabColors[tabKey] = r);
  }

  Future<void> _pickToken(S s, String tokenId, String label) async {
    final isDark = _t.dark ?? st.darkMode;
    final r = await _pickColorDialog(
      s,
      title: label,
      initial: hexOfColor(_t.colorOf(tokenId, isDark: isDark)),
      allowReset: _t.overridesColor(tokenId),
    );
    if (r == null) return;
    if (r.isEmpty) {
      _mutate((x) => x.colors.remove(tokenId));
      return;
    }
    _mutate((x) => x.colors[tokenId] = r);
  }

  String _densityName(S s, String id) {
    switch (id) {
      case 'compact':
        return s.themeDensityCompact;
      case 'comfortable':
        return s.themeDensityComfortable;
    }
    return s.themeDensityNormal;
  }

  String _fontName(S s, String id) {
    switch (id) {
      case 'systemUi':
        return s.themeFontSystem;
      case 'segoe':
        return 'Segoe UI';
      case 'pingfang':
        return 'PingFang SC';
      case 'yahei':
        return 'Microsoft YaHei';
      case 'notoSans':
        return 'Noto Sans';
      case 'mono':
        return s.themeFontMono;
    }
    return s.themeFontDefault;
  }

  String _alignName(S s, String id) {
    switch (id) {
      case 'top':
        return s.themeAlignTop;
      case 'bottom':
        return s.themeAlignBottom;
      case 'left':
        return s.themeAlignLeft;
      case 'right':
        return s.themeAlignRight;
      case 'topLeft':
        return s.themeAlignTopLeft;
      case 'topRight':
        return s.themeAlignTopRight;
      case 'bottomLeft':
        return s.themeAlignBottomLeft;
      case 'bottomRight':
        return s.themeAlignBottomRight;
    }
    return s.themeAlignCenter;
  }

  /// 一排可选项（填充方式 / 对齐 / 密度 / 字体 共用）
  Widget _chipGroup({
    required S s,
    required String label,
    required List<String> values,
    required String current,
    required String Function(String) nameOf,
    required void Function(String) onPick,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ts(12, c: C.slate)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                _chip(v == current, nameOf(v), _editable ? () => onPick(v) : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(bool on, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? C.indigo.withValues(alpha: 0.12) : C.greyBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: on ? C.indigo : C.border,
            width: on ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: ts(11, c: on ? C.indigo : C.slate, w: FontWeight.w600),
        ),
      ),
    );
  }

  // ─── 背景图 ───

  Widget _backgroundSection(S s) {
    final t = _t;
    final has = t.hasBackground;
    return SettingsSectionCard(
      title: s.themeBg,
      subtitle: s.themeBgDesc,
      icon: Icons.wallpaper_rounded,
      color: C.indigo,
      children: [
        InkWell(
          onTap: _editable ? () => _pickBackground(s) : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
            ),
            child: Row(
              children: [
                _bgThumb(t),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    has ? s.themeBgReplace : s.themeBgPick,
                    style: ts(12, w: FontWeight.w600),
                  ),
                ),
                if (has && _editable)
                  TextButton(
                    onPressed: () => _mutate((x) => x.background = null),
                    child: Text(s.themeBgRemove, style: ts(11, c: C.red)),
                  ),
              ],
            ),
          ),
        ),
        if (!has)
          SettingsHint(s.themeBgDisabledHint, color: C.slate)
        else ...[
          _sliderRow(
            s: s,
            label: s.themeBgOpacity,
            value: t.bgOpacity,
            min: kThemeBgOpacityMin,
            max: kThemeBgOpacityMax,
            decimals: 2,
            hint: s.themeBgOpacityDesc,
            onChanged: (v) => _mutate((x) => x.bgOpacity = v),
          ),
          _sliderRow(
            s: s,
            label: s.themeBgBlur,
            value: t.bgBlur,
            min: 0,
            max: kThemeBgBlurMax,
            decimals: 0,
            hint: s.themeBgBlurDesc,
            onChanged: (v) => _mutate((x) => x.bgBlur = v),
          ),
          _chipGroup(
            s: s,
            label: s.themeBgFit,
            values: kThemeBgFits,
            current: t.bgFit,
            nameOf: (v) => _fitName(s, v),
            onPick: (v) => _mutate((x) => x.bgFit = v),
          ),
          _chipGroup(
            s: s,
            label: s.themeBgAlign,
            values: kThemeBgAligns,
            current: t.bgAlign,
            nameOf: (v) => _alignName(s, v),
            onPick: (v) => _mutate((x) => x.bgAlign = v),
          ),
          _sliderRow(
            s: s,
            label: s.themeBgScale,
            value: t.bgScale,
            min: kThemeBgScaleMin,
            max: kThemeBgScaleMax,
            decimals: 1,
            hint: s.themeBgScaleDesc,
            onChanged: (v) => _mutate((x) => x.bgScale = v),
          ),
          SettingsHint(s.themeBgLocalOnly,
              color: C.orange, icon: Icons.info_outline_rounded),
        ],
      ],
    );
  }

  Widget _bgThumb(AppTheme t) {
    final ref = t.background;
    return Container(
      width: 56,
      height: 40,
      decoration: BoxDecoration(
        color: C.greyBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ref == null
          ? Icon(Icons.image_not_supported_outlined, size: 16, color: C.grey)
          : (tc.buildBgThumb(ref) ??
              Icon(Icons.broken_image_outlined, size: 16, color: C.grey)),
    );
  }

  String _fitName(S s, String fit) {
    switch (fit) {
      case 'contain':
        return s.themeBgFitContain;
      case 'stretch':
        return s.themeBgFitStretch;
      case 'tile':
        return s.themeBgFitTile;
    }
    return s.themeBgFitCover;
  }

  /// 通用「标签 + 滑杆 + 说明」行（圆角/不透明度/模糊/缩放共用）。
  ///
  /// [decimals] 决定显示精度：0.05~0.6 这种区间用两位才有意义，
  /// 圆角 0~28 用整数即可 —— 一律写死 toFixed(0) 会让不透明度永远显示 0。
  Widget _sliderRow({
    required S s,
    required String label,
    required double value,
    required double min,
    required double max,
    String? hint,
    int decimals = 0,
    required ValueChanged<double> onChanged,
  }) {
    final shown =
        decimals > 0 ? value.toStringAsFixed(decimals) : value.round().toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: ts(12, c: C.slate))),
              Text(shown, style: mono(11, c: C.grey)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: C.indigo,
            onChanged: _editable ? onChanged : null,
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(hint, style: ts(10, c: C.grey, h: 1.35)),
            ),
        ],
      ),
    );
  }

  Future<void> _pickBackground(S s) async {
    setState(() => _busy = true);
    icon_io.IconImportResult r;
    try {
      r = await tc.importBackground();
    } catch (_) {
      r = const icon_io.IconImportResult.fail(icon_io.IconImportError.failed);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.isOk) {
      _mutate((x) => x.background = r.ref);
      return;
    }
    switch (r.error) {
      case icon_io.IconImportError.cancelled:
        return;
      case icon_io.IconImportError.tooLarge:
        // 背景图与图标上限不同，提示必须说清是哪一个，否则用户会拿着
        // 「超过 2MB」去压缩一张本来只用到 8MB 的图
        _toast(s.themeBgErrTooLarge);
      case icon_io.IconImportError.badFormat:
        _toast(s.themeIconErrFormat);
      case icon_io.IconImportError.unsupportedPlatform:
        _toast(s.themeIconErrUnsupported);
      default:
        _toast(s.themeIconErrFailed);
    }
  }

  // ─── 圆角 ───

  Widget _radiusSection(S s) {
    return SettingsSectionCard(
      title: s.themeRadius,
      subtitle: s.themeRadiusDesc,
      icon: Icons.rounded_corner_rounded,
      color: C.purple,
      children: [
        _sliderRow(
          s: s,
          label: s.themeRadius,
          value: _t.radius,
          min: kThemeMinRadius,
          max: kThemeMaxRadius,
          onChanged: (v) => _mutate((x) => x.radius = v),
        ),
        const SizedBox(height: 6),
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
                borderRadius: BorderRadius.circular(8),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => MaterialSurface(
        radius: 24,
        topOnly: true,
        child: Container(
          decoration: BoxDecoration(
            color: C.sheetFill,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24)),
          ),
          child: _IconPickerSheet(
            title: s.themePickIcon,
            searchHint: s.themePickIconSearch,
            importLabel: s.themeIconImport,
            importHint: s.themeIconImportHint,
            resetLabel: s.themeReset,
            canImport: _editable && icon_io.supportsFileIcons,
            // 返回 null = 关闭；返回 '' = 恢复默认；其余为引用
            onImport: () async => _importIcon(s),
        ),
        ),
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
        // 是否带图片：默认带（用户导出主题的意图就是「把这套东西搬走」），
        // 但要让他知道代价 —— base64 会让文件大一个量级，而且不再可手工编辑。
        SettingsSwitch(
          s.themeExportWithImages,
          value: _withImages,
          color: C.blue,
          onChanged: (v) => setState(() => _withImages = v),
        ),
        SettingsHint(
          _imgBytes > 0
              ? s.themeExportWithImagesHint(_fmtBytes(_imgBytes))
              : s.themeExportNoImages,
          color: _imgBytes > 0 ? C.slate : C.grey,
          icon: Icons.info_outline_rounded,
        ),
        if (_clipboardTooBig)
          SettingsHint(s.themeExportClipboardTooBig, color: C.orange,
              icon: Icons.warning_amber_rounded),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _btn(s.themeExportAll, Icons.ios_share_rounded, C.blue,
                  () => unawaited(_exportAll(s))),
              _btn(s.themeImport, Icons.folder_open_rounded, C.green,
                  () => unawaited(_import())),
              // 带图片时剪贴板会塞进几 MB 文本，多数平台上会直接被截断/失败 ——
              // 与其让用户粘贴出一段坏 JSON，不如禁用并说明原因。
              _btn(
                s.themeImportPaste,
                Icons.content_paste_rounded,
                _clipboardTooBig ? C.grey : C.green,
                _clipboardTooBig ? () {} : () => unawaited(_import(fromClipboard: true)),
              ),
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

  /// 剪贴板装不下这么多文本（保守阈值 256KB，含 base64 膨胀）
  bool get _clipboardTooBig => _withImages && _imgBytes > 192 * 1024;

  String _fmtBytes(int b) {
    if (b >= 1024 * 1024) return '${(b / 1048576).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
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
        await tc.exportBundleJson(includeImages: _withImages),
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
        await tc.exportOneJson(t, includeImages: _withImages),
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
    await _applyImported(s, text ?? '');
  }

  Future<void> _applyImported(S s, String text) async {
    try {
      // 先把嵌入的图片落盘，拿到「原文件名 → 本地文件名」映射；解析时据此
      // 把引用重定向。顺序不能颠倒：先解析的话主题会短暂指向不存在的文件。
      var absorb = const ThemeAbsorbResult({}, 0);
      try {
        absorb = await tc.absorbImages(text);
      } catch (_) {}
      final bundle = parseThemeJson(text, imageRemap: absorb.remap);
      for (final t in bundle.themes) {
        tc.upsert(t);
      }
      // 导入的第一条直接启用：用户的意图就是「用上它」
      tc.setActive(bundle.themes.first.id);
      _commit();
      unawaited(_refreshImageSize());
      final notes = <String>[];
      if (bundle.warnings.isNotEmpty) {
        notes.add(s.backupSkipped(bundle.warnings.length));
      }
      // 图片被跳过时说清楚是「几张图没进来」，而不是笼统的「有内容被跳过」——
      // 用户据此才知道要么换个图、要么换台设备重导。
      if (absorb.skipped > 0) notes.add(s.themeImportImagesSkipped(absorb.skipped));
      _toast('${s.themeImportDone(bundle.themes.length)}'
          '${notes.isEmpty ? '' : ' · ${notes.join(' · ')}'}');
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
      guideId: 'theme',
      state: widget.state,
      title: s.themeTitle,
      subtitle: s.themeSubtitle,
      icon: Icons.brush_rounded,
      color: C.purple,
      body: Column(
        children: [
          if (_editable)
            SettingsSectionCard(
              title: s.themeSkinInfo,
              subtitle: s.themeSkinInfoDesc,
              icon: Icons.badge_rounded,
              color: C.purple,
              children: [
                _textRow(
                  label: s.themeAuthor,
                  value: _t.author.isEmpty ? s.themeAuthorHint : _t.author,
                  muted: _t.author.isEmpty,
                  onTap: () => _editSkinField(s, author: true),
                ),
                _textRow(
                  label: s.themeDescription,
                  value: _t.description.isEmpty
                      ? s.themeDescHint
                      : _t.description,
                  muted: _t.description.isEmpty,
                  onTap: () => _editSkinField(s, author: false),
                ),
                // 名字也要能改：复制出来的皮肤默认叫「默认 2」之类，
                // 不改名的话列表里全是一串数字后缀
                _textRow(
                  label: s.themeRename,
                  value: _themeName(s, _t),
                  muted: false,
                  onTap: () => _rename(s, _t),
                ),
              ],
            ),
          if (_editable) const SizedBox(height: 16),
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
            _backgroundSection(s),
            const SizedBox(height: 16),
            _radiusSection(s),
            const SizedBox(height: 16),
            _surfaceSection(s),
            _layoutSection(s),
            const SizedBox(height: 16),
            _tabsSection(s),
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
