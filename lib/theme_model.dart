import 'dart:convert';

import 'package:flutter/material.dart' show Color;

/// ─── 主题模型（纯数据，不依赖 Widget / 平台）───
///
/// 设计要点：
///
/// 1. **主题是一份「覆写」而不是一份「全量」**：只存用户改过的项（
///    `colors` 里只放被改过的令牌、`texts` 只放被覆写的键）。这样：
///    - 升级时应用内置的默认值可以继续演进，用户只锁住自己想改的部分；
///    - 导出的 JSON 短、可读、可手改（这也是用户要的功能之一）。
///
/// 2. **令牌（token）是白名单**：颜色只认 [kThemeColorTokens] 里列出的名字，
///    文字只认 [kThemeTextKeys]，图标只认 [kThemeIconSlots]。主题文件是用户
///    可见可编辑的文本，若无脑应用「文件里出现的任意键」，一份伪造/改坏的
///    文件就能把界面写到不可用（例如把 `white` 设成透明）。越界项一律
///    **跳过并计数**，由 UI 如实汇报，而不是静默忽略或整体拒绝。
///
/// 3. **schema 版本只增不减**：导入时遇到更高的 schema 直接拒绝并提示升级应用，
///    而不是猜着解析 —— 猜错的代价是界面直接坏掉。
///
/// 4. **一切可迭代项都有兜底**：颜色解析失败 → 回退默认色；图标名不认识 →
///    回退默认图标；导入的图片文件丢了 → 回退默认图标。主题是「锦上添花」的东西，
///    任何一处坏掉都不该让应用起不来。

/// 主题文件的身份标识（避免把任意 JSON 当主题解析）
const String kThemeKind = 'aprslocus-theme';

/// 主题格式版本
const int kThemeSchema = 1;

/// 一个可自定义的颜色令牌：id + 内置默认（分浅色/深色两套）。
///
/// 编辑页直接由这张表生成，所以**新增令牌只要加一行**，UI 自动出现。
class ThemeColorToken {
  final String id;
  final Color light;
  final Color dark;

  const ThemeColorToken(this.id, this.light, this.dark);
}

/// 可自定义的颜色令牌。
///
/// 挑选原则：只暴露「改了好处明显、改坏了不至于不可用」的那些。
/// 刻意**不**暴露 `white`（卡片表面）这类语义重名重的令牌 ——
/// 它在深色模式下其实是深灰，让用户按字面理解去改必然出事；
/// 需要改表面色请用 [surface]。
const List<ThemeColorToken> kThemeColorTokens = [
  ThemeColorToken('primary', Color(0xFF2563EB), Color(0xFF2563EB)),
  ThemeColorToken('surface', Color(0xFFFFFFFF), Color(0xFF1E2530)),
  ThemeColorToken('background', Color(0xFFF3F5F9), Color(0xFF12161E)),
  ThemeColorToken('backgroundSoft', Color(0xFFEDF1F7), Color(0xFF1B2230)),
  ThemeColorToken('textPrimary', Color(0xFF253044), Color(0xFFE6EAF2)),
  ThemeColorToken('textSecondary', Color(0xFF637083), Color(0xFFAAB4C5)),
  ThemeColorToken('textMuted', Color(0xFF94A0B2), Color(0xFF7A8699)),
  ThemeColorToken('divider', Color(0xFFE5E9F0), Color(0xFF2A3344)),
  ThemeColorToken('success', Color(0xFF16A34A), Color(0xFF16A34A)),
  ThemeColorToken('warning', Color(0xFFD97706), Color(0xFFD97706)),
  ThemeColorToken('danger', Color(0xFFE11D48), Color(0xFFE11D48)),
  ThemeColorToken('info', Color(0xFF0E7490), Color(0xFF0E7490)),
];

ThemeColorToken? themeColorToken(String id) {
  for (final t in kThemeColorTokens) {
    if (t.id == id) return t;
  }
  return null;
}

/// 圆角档位（卡片/输入框的视觉圆角）
const double kThemeMinRadius = 0.0;
const double kThemeMaxRadius = 28.0;
const double kThemeDefaultRadius = 16.0;

/// 解析 `RRGGBB` / `#RRGGBB` / `AARRGGBB` → Color；不合法返回 null。
Color? parseHexColor(String? raw) {
  final h = (raw ?? '').trim().replaceAll('#', '').toUpperCase();
  if (h.length != 6 && h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return null;
  return Color(h.length == 6 ? (0xFF000000 | v) : v);
}

/// Color → `RRGGBB`（丢掉 alpha：主题里不需要半透明，见下）
///
/// 说明：令牌刻意不支持 alpha。半透明颜色与背景叠加后，对比度会随主题变化，
/// 「看起来还行」与「看不清」之间没有可靠判据；与其让用户踩坑，不如只给不透明色。
String hexOfColor(Color c) {
  final r = (c.r * 255).round().clamp(0, 255);
  final g = (c.g * 255).round().clamp(0, 255);
  final b = (c.b * 255).round().clamp(0, 255);
  return ((r << 16) | (g << 8) | b).toRadixString(16).padLeft(6, '0').toUpperCase();
}

/// 单条主题。
class AppTheme {
  /// 唯一 id（内置主题用固定 id，用户主题用时间戳/随机串）
  String id;

  /// 显示名（用户可改）
  String name;

  /// 内置主题不可删除、不可改名（但可以「另存为」再改）
  bool builtin;

  /// 该主题偏好的深色模式；null = 不改动当前深色设置
  bool? dark;

  /// 令牌 id → `RRGGBB`
  final Map<String, String> colors;

  /// 自定义圆角（卡片）
  double radius;

  /// l10n 键 → 覆写文本
  final Map<String, String> texts;

  /// 插槽 id → 图标引用（`lib:<iconName>` 或 `file:<存放文件名>`）
  final Map<String, String> icons;

  AppTheme({
    required this.id,
    required this.name,
    this.builtin = false,
    this.dark,
    Map<String, String>? colors,
    double? radius,
    Map<String, String>? texts,
    Map<String, String>? icons,
  })  : colors = colors ?? <String, String>{},
        radius = radius ?? kThemeDefaultRadius,
        texts = texts ?? <String, String>{},
        icons = icons ?? <String, String>{};

  bool get isEmpty =>
      colors.isEmpty && texts.isEmpty && icons.isEmpty && radius == kThemeDefaultRadius;

  /// 深拷贝（编辑页里做「取消」时靠它回滚）
  AppTheme copy() => AppTheme(
        id: id,
        name: name,
        builtin: builtin,
        dark: dark,
        colors: Map<String, String>.from(colors),
        radius: radius,
        texts: Map<String, String>.from(texts),
        icons: Map<String, String>.from(icons),
      );

  /// 取某令牌在本主题下的颜色（未覆写 → 内置默认）
  Color colorOf(String tokenId, {required bool isDark}) {
    final t = themeColorToken(tokenId);
    final fallback = t == null
        ? const Color(0xFF000000)
        : (isDark ? t.dark : t.light);
    final hex = colors[tokenId];
    if (hex == null) return fallback;
    return parseHexColor(hex) ?? fallback;
  }

  /// 该令牌是否被本主题覆写
  bool overridesColor(String tokenId) => colors.containsKey(tokenId);

  /// 取覆写文本；没有返回 null（调用方回退 l10n）
  String? textOf(String key) {
    final v = texts[key];
    if (v == null || v.isEmpty) return null;
    return v;
  }

  /// 取图标引用；没有返回 null（调用方用默认图标）
  String? iconOf(String slot) {
    final v = icons[slot];
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        if (builtin) 'builtin': true,
        if (dark != null) 'dark': dark,
        if (colors.isNotEmpty) 'colors': colors,
        if (radius != kThemeDefaultRadius) 'radius': radius,
        if (texts.isNotEmpty) 'texts': texts,
        if (icons.isNotEmpty) 'icons': icons,
      };

  static AppTheme? fromJson(Object? raw, {List<String>? warnings}) {
    if (raw is! Map) return null;
    final id = '${raw['id'] ?? ''}'.trim();
    if (id.isEmpty) return null;
    final t = AppTheme(
      id: id,
      name: '${raw['name'] ?? id}'.trim(),
      builtin: raw['builtin'] == true,
      dark: raw['dark'] is bool ? raw['dark'] as bool : null,
    );
    final r = raw['radius'];
    if (r is num) {
      t.radius = r.toDouble().clamp(kThemeMinRadius, kThemeMaxRadius);
    }
    final c = raw['colors'];
    if (c is Map) {
      for (final e in c.entries) {
        final key = '${e.key}';
        final val = '${e.value}';
        // 白名单 + 值必须能解析：改坏的一项跳过，不影响整份主题
        if (themeColorToken(key) == null || parseHexColor(val) == null) {
          warnings?.add('colors.$key');
          continue;
        }
        t.colors[key] = val.trim().replaceAll('#', '').toUpperCase();
      }
    }
    final tx = raw['texts'];
    if (tx is Map) {
      for (final e in tx.entries) {
        final key = '${e.key}';
        if (!kThemeTextKeys.contains(key)) {
          warnings?.add('texts.$key');
          continue;
        }
        final v = '${e.value}';
        // 空串视为「删掉这条覆写」，而不是「显示空标题」——
        // 后者会让界面出现无法点击/无法识别的空白项
        if (v.trim().isEmpty) continue;
        t.texts[key] = v;
      }
    }
    final ic = raw['icons'];
    if (ic is Map) {
      for (final e in ic.entries) {
        final slot = '${e.key}';
        final v = '${e.value}';
        if (!kThemeIconSlots.any((s) => s.id == slot)) {
          warnings?.add('icons.$slot');
          continue;
        }
        if (!isValidIconRef(v)) {
          warnings?.add('icons.$slot');
          continue;
        }
        t.icons[slot] = v;
      }
    }
    return t;
  }
}

/// 图标引用：`lib:map_rounded` 或 `file:ab12cd34.png`
bool isValidIconRef(String ref) {
  if (ref.startsWith('lib:')) {
    // 名字是否真存在于图标库由 theme_icons.dart 判定（这里只管形状）
    return RegExp(r'^lib:[A-Za-z][A-Za-z0-9_]*$').hasMatch(ref);
  }
  if (ref.startsWith('file:')) {
    // 只允许「文件名」，不允许路径 —— 否则主题文件能指向磁盘上任意位置
    final name = ref.substring(5);
    return RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(name) && name.contains('.');
  }
  return false;
}

/// 一组主题 + 当前激活项（这就是「主题包」的导出/导入单位）。
class ThemeBundle {
  final List<AppTheme> themes;
  String activeId;
  final List<String> warnings;

  ThemeBundle({
    required this.themes,
    required this.activeId,
    this.warnings = const [],
  });

  AppTheme? get active {
    for (final t in themes) {
      if (t.id == activeId) return t;
    }
    return themes.isEmpty ? null : themes.first;
  }

  AppTheme? byId(String id) {
    for (final t in themes) {
      if (t.id == id) return t;
    }
    return null;
  }

  Map<String, Object?> toJson({bool includeBuiltin = true}) => {
        'kind': kThemeKind,
        'schema': kThemeSchema,
        'active': activeId,
        'themes': [
          for (final t in themes)
            if (includeBuiltin || !t.builtin) t.toJson(),
        ],
      };
}

/// 导出成可读 JSON 文本（单个主题 / 整包）
String encodeThemeJson(Object payload) =>
    const JsonEncoder.withIndent('  ').convert(payload);

enum ThemeErrorCode { notJson, notTheme, schemaNewer, empty, noThemes }

class ThemeException implements Exception {
  final ThemeErrorCode code;
  final String? detail;

  const ThemeException(this.code, [this.detail]);

  @override
  String toString() =>
      'ThemeException($code${detail == null ? '' : ': $detail'})';
}

/// 解析主题包 / 单个主题。
///
/// 两种形态都接受：
/// - 单个主题：`{"kind":"aprslocus-theme","schema":1,"theme":{...}}`（编辑页导出）
/// - 整包：`{"kind":"aprslocus-theme","schema":1,"themes":[...]}`（备份/分享）
/// 这样「导出当前主题分享给别人」与「导出全部主题」都能被同一个入口导入。
ThemeBundle parseThemeJson(String text) {
  Object? raw;
  try {
    raw = jsonDecode(text);
  } catch (e) {
    throw ThemeException(ThemeErrorCode.notJson, '$e');
  }
  if (raw is! Map) throw const ThemeException(ThemeErrorCode.notTheme);
  if (raw['kind'] != kThemeKind) {
    throw const ThemeException(ThemeErrorCode.notTheme);
  }
  final schema = raw['schema'];
  if (schema is! int) throw const ThemeException(ThemeErrorCode.notTheme);
  if (schema > kThemeSchema) {
    throw ThemeException(ThemeErrorCode.schemaNewer, 'schema=$schema');
  }

  final warnings = <String>[];
  final themes = <AppTheme>[];

  final one = raw['theme'];
  if (one is Map) {
    final t = AppTheme.fromJson(one, warnings: warnings);
    if (t != null) themes.add(t);
  }
  final many = raw['themes'];
  if (many is List) {
    for (final e in many) {
      final t = AppTheme.fromJson(e, warnings: warnings);
      if (t != null) themes.add(t);
    }
  }
  if (themes.isEmpty) {
    throw const ThemeException(ThemeErrorCode.noThemes);
  }

  // 导入的主题一律视为「用户主题」：内置标记不可由文件授予，
  // 否则一份文件就能伪装成内置主题从而不可删除/不可改名。
  for (final t in themes) {
    t.builtin = false;
  }

  var active = '${raw['active'] ?? ''}';
  if (!themes.any((t) => t.id == active)) active = themes.first.id;
  return ThemeBundle(themes: themes, activeId: active, warnings: warnings);
}

/// 主题文本文件名
String themeFileName(DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'APRSLocus_theme_${now.year}${two(now.month)}${two(now.day)}'
      '_${two(now.hour)}${two(now.minute)}${two(now.second)}.json';
}

// ─── 插槽与文案白名单 ───
//
// 注意：这两个表放在本文件里（而不是 theme_icons.dart / 文案文件），
// 是因为 AppTheme.fromJson 校验时要引用它们。它们只描述「有哪些可自定义项」，
// 不含任何 Flutter 组件或 l10n 依赖。

/// 一个图标插槽：id + 默认图标名 + 用途说明键
///
/// [defaultIcon] 是 theme_icons.dart 图标库里的**名字**（不是 IconData）——
/// 名字可序列化，也便于做「默认值」比较。
class ThemeIconSlot {
  final String id;
  final String defaultIcon;

  /// 该插槽「选中态」的默认图标（仅底部导航用：未选/已选两套）
  final String? defaultIconActive;

  const ThemeIconSlot(this.id, this.defaultIcon, {this.defaultIconActive});
}

/// 可自定义的图标插槽。
///
/// 只收「用户天天看见、改了立刻有感」的位置：底部 5 个页签 + 设置页 8 个分类入口。
/// 不把 288 个图标全开放：那既没人改得完，也让导出的主题文件失去可读性。
const List<ThemeIconSlot> kThemeIconSlots = [
  ThemeIconSlot('navMap', 'map_rounded', defaultIconActive: 'map_rounded'),
  ThemeIconSlot('navStations', 'cell_tower_rounded',
      defaultIconActive: 'cell_tower_rounded'),
  ThemeIconSlot('navMessages', 'chat_bubble_rounded',
      defaultIconActive: 'chat_bubble_rounded'),
  ThemeIconSlot('navPackets', 'cable_rounded', defaultIconActive: 'cable_rounded'),
  ThemeIconSlot('navSettings', 'settings_rounded',
      defaultIconActive: 'settings_rounded'),
  ThemeIconSlot('catRadio', 'person_rounded'),
  ThemeIconSlot('catBeacon', 'my_location_rounded'),
  ThemeIconSlot('catConnection', 'wifi_rounded'),
  ThemeIconSlot('catDisplay', 'palette_rounded'),
  ThemeIconSlot('catDevice', 'radio_rounded'),
  ThemeIconSlot('catData', 'storage_rounded'),
  ThemeIconSlot('catAdvanced', 'tune_rounded'),
  ThemeIconSlot('catUpdate', 'system_update_rounded'),
];

ThemeIconSlot? themeIconSlot(String id) {
  for (final s in kThemeIconSlots) {
    if (s.id == id) return s;
  }
  return null;
}

/// 文案白名单：能被主题覆写的 l10n 键。
///
/// 只收高频、且「改了不会让界面失去可读性」的文案（页签名、设置分类名等）。
/// 刻意**不**收按钮动词（确定/取消/删除）与错误提示：那些是用户的操作依据，
/// 被改成看不懂的词会让应用变得不可操作。这也是「白名单」而非「全量覆写」
/// 的根本原因 —— 全量覆写等于把应用的可操作性交给主题文件。
const Set<String> kThemeTextKeys = {
  // 底部页签
  'map', 'stations', 'messages', 'packets', 'settings',
  // 设置页分类
  'radioCat', 'radioCatDesc',
  'beaconCat', 'beaconCatDesc',
  'connectionCat', 'connectionCatDesc',
  'displayCat', 'displayCatDesc',
  'deviceCat', 'deviceCatDesc',
  'dataCat', 'dataCatDesc',
  'advancedCat', 'advancedCatDesc',
  'updateCat', 'updateCatDesc',
  // 设置页里几个入口标题
  'honorWall', 'translateSettings', 'exportAdif', 'backupTitle', 'about',
};
