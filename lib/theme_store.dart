import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';
import 'theme_icon_io.dart' if (dart.library.html) 'theme_icon_io_web.dart'
    as icon_io;
import 'theme_icons.dart';
import 'theme_model.dart';

/// ─── 主题控制器：加载 / 应用 / 存储 / 图标与文字的解析 ───
///
/// 为什么做成单例而不是塞进 AppState：图标与文字的解析发生在**很深**的组件里
/// （底部导航的一个 Icon、设置页的一张卡片）。把它们都改成从 AppState 取，
/// 要动几十个构造函数；而主题是「全局只读」性质的数据，单例是合适的形状。
///
/// 与 AppState 的分工：
/// - AppState 负责持久化时机（与其它偏好一起落盘）与通知刷新；
/// - ThemeController 负责「当前主题是什么、某个插槽该画什么」。
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  /// 存储键（同时被备份白名单引用，见 lib/backup.dart）
  static const String kPrefsKey = 'themeBundle';

  /// 用户自建/导入的主题（内置预设不入库，见 [all]）
  final List<AppTheme> _user = [];

  String _activeId = '';

  /// 每次「主题发生变化」就 +1。AppState 观察它来决定要不要重建 MaterialApp。
  int revision = 0;

  bool _loaded = false;

  bool get loaded => _loaded;

  /// 内置预设：随应用一起提供，不可删、不可改名（可以「另存为」再改）
  static final List<AppTheme> builtinPresets = [
    AppTheme(id: 'builtin:default', name: '默认', builtin: true),
    AppTheme(
      id: 'builtin:ocean',
      name: '海洋',
      builtin: true,
      colors: {
        'primary': '0E7490',
        'background': 'F0F6F9',
        'backgroundSoft': 'E4EFF4',
        'textPrimary': '17313A',
        'textSecondary': '48646E',
        'info': '0EA5A4',
      },
    ),
    AppTheme(
      id: 'builtin:forest',
      name: '森林',
      builtin: true,
      colors: {
        'primary': '15803D',
        'background': 'F1F7F2',
        'backgroundSoft': 'E6F0E8',
        'textPrimary': '1B2E20',
        'textSecondary': '4C6552',
        'success': '15803D',
      },
    ),
    AppTheme(
      id: 'builtin:midnight',
      name: '暗夜',
      builtin: true,
      dark: true,
      colors: {
        'primary': '818CF8',
        'surface': '131A26',
        'background': '0B1017',
        'backgroundSoft': '151D2B',
        'textPrimary': 'E8ECF5',
        'textSecondary': '9AA7BC',
        'divider': '232C3D',
      },
      radius: 12,
    ),
    AppTheme(
      id: 'builtin:sunset',
      name: '日落',
      builtin: true,
      colors: {
        'primary': 'EA580C',
        'background': 'FBF4EE',
        'backgroundSoft': 'F6E8DC',
        'textPrimary': '3A2416',
        'textSecondary': '6B5346',
        'warning': 'C2410C',
      },
    ),
    AppTheme(
      id: 'builtin:contrast',
      name: '高对比',
      builtin: true,
      colors: {
        'primary': '0B5FFF',
        'surface': 'FFFFFF',
        'background': 'FFFFFF',
        'backgroundSoft': 'F2F4F8',
        'textPrimary': '000000',
        'textSecondary': '2B3445',
        'textMuted': '4A5568',
        'divider': '9AA5B5',
        'success': '0F7A38',
        'warning': 'A65A00',
        'danger': 'C4103A',
      },
      radius: 8,
    ),
  ];

  /// 全部主题（内置 + 用户）
  List<AppTheme> get all => [...builtinPresets, ..._user];

  List<AppTheme> get userThemes => List.unmodifiable(_user);

  String get activeId => _activeId;

  AppTheme? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 当前生效的主题；没设置过则返回「默认」预设（永远非 null）
  AppTheme get active =>
      byId(_activeId) ??
      (all.isEmpty ? AppTheme(id: 'builtin:default', name: '默认') : all.first);

  /// 是否在使用内置的「默认」主题（等于「没有任何自定义」）
  bool get isDefault => active.id == 'builtin:default' && active.isEmpty;

  // ─── 加载 / 保存 ───

  Future<void> load(SharedPreferences p) async {
    try {
      final raw = p.getString(kPrefsKey);
      if (raw != null && raw.isNotEmpty) {
        final d = jsonDecode(raw);
        if (d is Map) {
          _user.clear();
          final list = d['themes'];
          if (list is List) {
            for (final e in list) {
              final t = AppTheme.fromJson(e);
              // 从偏好里读出来的「内置」标记不可信：一份被改过的偏好
              // 不能凭空造出不可删除的主题
              if (t != null) {
                t.builtin = false;
                _user.add(t);
              }
            }
          }
          _activeId = '${d['active'] ?? ''}';
        }
      }
    } catch (_) {
      // 主题坏了就退回默认：这是「锦上添花」的功能，不能拖垮启动
      _user.clear();
      _activeId = '';
    }
    if (byId(_activeId) == null) _activeId = builtinPresets.first.id;
    _loaded = true;
    // 图标目录的准备是异步的；就绪后要通知一次，否则第一次渲染会用到回退图标
    unawaited(_warmIconStore());
    revision++;
    notifyListeners();
  }

  Future<void> _warmIconStore() async {
    if (!icon_io.supportsFileIcons) return;
    // 借一次「找文件」把目录准备好（iconFilePath 内部会创建目录）
    try {
      await icon_io.iconFilePath('__warmup__');
    } catch (_) {}
    if (icon_io.iconStoreReady) {
      revision++;
      notifyListeners();
    }
  }

  /// 写入 Store（由 AppState 在 persist 时调用，或在主题页里直接调用）
  Future<void> saveTo(SharedPreferences p) async {
    try {
      await p.setString(
        kPrefsKey,
        jsonEncode({
          'active': _activeId,
          'themes': [for (final t in _user) t.toJson()],
        }),
      );
    } catch (_) {}
  }

  /// 导出用的 JSON（整包）。
  ///
  /// **只导出用户主题**，不含内置预设：预设每台设备本来就有，导出去再导回来
  /// 只会让对方的主题列表平白多出 6 个重复项（而且它们会被降级成用户主题，
  /// 删起来还得一个个删）。想分享预设的单一样式，用 [exportOneJson]。
  String exportBundleJson() =>
      encodeThemeJson(ThemeBundle(themes: _user, activeId: _activeId)
          .toJson(includeBuiltin: false));

  /// 导出单个主题的 JSON
  String exportOneJson(AppTheme t) => encodeThemeJson({
        'kind': kThemeKind,
        'schema': kThemeSchema,
        'active': t.id,
        'theme': t.toJson(),
      });

  // ─── 增删改 ───

  /// 加入或更新一个用户主题
  void upsert(AppTheme t) {
    t.builtin = false;
    // id 与内置预设撞车时必须换 id：否则 `all` 里会出现两个同 id 项，
    // 而 byId/激活查找总是先命中内置那个 —— 用户新存的这份就永远打不开、
    // 也删不掉（列表里看得见两个「默认」，点哪个都是同一个）。
    if (builtinPresets.any((b) => b.id == t.id)) {
      t.id = 'u${DateTime.now().millisecondsSinceEpoch}';
    }
    final i = _user.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      _user[i] = t;
    } else {
      _user.add(t);
    }
    revision++;
    notifyListeners();
  }

  /// 删除用户主题；若删的是当前激活项则回到默认
  void remove(String id) {
    _user.removeWhere((t) => t.id == id);
    if (_activeId == id) _activeId = builtinPresets.first.id;
    revision++;
    notifyListeners();
  }

  void setActive(String id) {
    if (byId(id) == null) return;
    _activeId = id;
    revision++;
    notifyListeners();
  }

  /// 由内置预设「另存为」一个可编辑的用户主题
  AppTheme duplicateOf(AppTheme src, {String? name}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return AppTheme(
      id: 'u$now',
      name: name ?? _uniqueName(src.name),
      colors: Map<String, String>.from(src.colors),
      radius: src.radius,
      texts: Map<String, String>.from(src.texts),
      icons: Map<String, String>.from(src.icons),
      dark: src.dark,
    );
  }

  String _uniqueName(String base) {
    final taken = all.map((t) => t.name).toSet();
    if (!taken.contains(base)) return base;
    for (var i = 2; i < 999; i++) {
      final n = '$base $i';
      if (!taken.contains(n)) return n;
    }
    return base;
  }

  String uniqueName(String base) => _uniqueName(base);

  // ─── 解析：颜色 / 图标 / 文字 ───

  /// 把当前主题应用到 C 的调色板
  ///
  /// [legacyPrimary] 是旧版的单一 `themeColor`：只有当前主题**没有**覆写
  /// primary 时才用它 —— 这样老用户的颜色设置在升级后原样保留。
  void applyColors({required bool isDark, Color? legacyPrimary}) {
    final t = active;
    final tokens = <String, Color>{};
    for (final token in kThemeColorTokens) {
      if (t.overridesColor(token.id)) {
        tokens[token.id] = t.colorOf(token.id, isDark: isDark);
      }
    }
    C.applyTheme(
      isDark: isDark,
      primary: tokens['primary'] ?? legacyPrimary,
      tokens: tokens,
      radius: t.radius,
    );
  }

  /// 某个插槽该用哪个内置图标（已考虑覆写与回退）
  IconData iconFor(String slot, {bool active2 = false}) {
    final def = themeIconSlot(slot);
    final ref = active.iconOf(slot);
    if (ref != null && ref.startsWith('lib:')) {
      final ic = themeIconByName(ref.substring(4));
      if (ic != null) return ic;
    }
    // 覆写是 `file:` 时这里给的是回退值，真正的图由 [buildSlotIcon] 画
    final name = active2 && def?.defaultIconActive != null
        ? def!.defaultIconActive!
        : (def?.defaultIcon ?? 'help_outline_rounded');
    return themeIconByName(name) ?? Icons.help_outline_rounded;
  }

  /// 某个插槽是否引用了外部图片文件
  bool hasFileIcon(String slot) {
    final ref = active.iconOf(slot);
    return ref != null && ref.startsWith('file:');
  }

  /// 覆写文字（无覆写返回 null，调用方回退 l10n）
  String? textFor(String key) => active.textOf(key);

  /// 渲染插槽图标：优先外部图片，失败/不存在则回退内置图标。
  ///
  /// [fallbackIcon] 允许调用方在「默认主题」下沿用自己原来的图标，
  /// 这样没装主题时界面上一个像素都不会变。
  Widget buildSlotIcon(
    String slot, {
    required double size,
    required Color color,
    IconData? fallbackIcon,
    bool selected = false,
  }) {
    final t = active;
    final ref = t.iconOf(slot);
    if (ref != null && ref.startsWith('lib:')) {
      final ic = themeIconByName(ref.substring(4));
      if (ic != null) return Icon(ic, size: size, color: color);
    }
    Widget libIcon() => Icon(
          fallbackIcon ?? iconFor(slot, active2: selected),
          size: size,
          color: color,
        );
    if (ref != null && ref.startsWith('file:')) {
      final w = icon_io.buildFileIcon(
        ref.substring(5),
        size: size,
        fallback: libIcon,
      );
      if (w != null) return w;
    }
    return libIcon();
  }
}
