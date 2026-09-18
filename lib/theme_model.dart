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
  // ── 更深一层的自定义（v1.6.127）──
  // 这三个令牌此前是写死的：次级面板底色、较重的描边、弹窗遮罩。
  // 不开放的话，改完主色仍会看到「某些地方还是原来的灰」。
  ThemeColorToken('surfaceAlt', Color(0xFFEDF0F5), Color(0xFF232B39)),
  ThemeColorToken('dividerStrong', Color(0xFFD2DAE4), Color(0xFF39445A)),
  ThemeColorToken('scrim', Color(0xFF141A26), Color(0xFF0C0F14)),
  // 强调渐变：设置页各入口卡片的图标底色用它。原本每张卡片都写死了自己的
  // 渐变色（8 组互不相同），主题改成统一的 from→to 两色即可 —— 这也是
  // 「皮肤」最直观的一处观感来源。
  ThemeColorToken('accentFrom', Color(0xFF2563EB), Color(0xFF2563EB)),
  ThemeColorToken('accentTo', Color(0xFF1D4ED8), Color(0xFF1D4ED8)),
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

/// ─── 背景图 ───
///
/// 背景图是整个界面里**最容易把可用性搞坏**的一项个性化：一张深色照片配上
/// 深色文字，界面立刻不可读。所以它只给四个旋钮，每个都有硬边界：
///
/// - [kBgOpacity] 上限 **0.6**：给再高就直接盖住主题色，文字对比度不再受控；
/// - 附带**自动遮罩**（按明暗模式盖一层底色，见 theme_store），
///   这条不能省 —— 没有它，任何中等亮度的图都会让浅色/深色文字之一失效；
/// - 卡片会随之上浮成**半透明**表面，否则内容全被图盖住反而更不可读；
/// - 模糊默认 6（用户可关到 0）。
const double kThemeBgOpacityMin = 0.05;
const double kThemeBgOpacityMax = 0.6;
const double kThemeBgOpacityDefault = 0.3;
const double kThemeBgBlurMax = 30.0;
const double kThemeBgBlurDefault = 6.0;

/// 背景填充方式
const List<String> kThemeBgFits = ['cover', 'contain', 'stretch', 'tile'];

/// 背景图对齐（仅在「完整显示」下明显；铺满时用于决定裁切重心）
const List<String> kThemeBgAligns = [
  'center', 'top', 'bottom', 'left', 'right',
  'topLeft', 'topRight', 'bottomLeft', 'bottomRight',
];

/// 背景缩放倍率区间（1.0 = 原始尺寸；只在「完整显示/平铺」下有可见差别）
const double kThemeBgScaleMin = 0.5;
const double kThemeBgScaleMax = 2.0;

/// 界面密度：只作用于**共用辅助函数**的留白（卡片内边距、条目行距），
/// 不去改上百处硬编码的 EdgeInsets —— 那类改动的回归面太大。
/// 语义上就是「界面松紧」，UI 里也这么称呼。
const List<String> kThemeDensities = ['compact', 'normal', 'comfortable'];
const Map<String, double> kThemeDensityScale = {
  'compact': 0.85,
  'normal': 1.0,
  'comfortable': 1.2,
};

/// 可选界面字体。
///
/// **只用系统已装字体**，不内置字体文件：内置一款中文字体动辄 5~10MB，
/// 而本应用已经因为图标库+SVG 涨过一轮体积。代价是各平台可用性不同，
/// 所以每个选项都标了它依赖的系统字体名，缺失时 Flutter 会自然回退，
/// 不会变成方框或乱码。
class ThemeFontOption {
  final String id;

  /// 传给 TextStyle.fontFamily 的名字（null = 用平台默认）
  final String? family;

  const ThemeFontOption(this.id, this.family);
}

const List<ThemeFontOption> kThemeFonts = [
  ThemeFontOption('default', null),
  ThemeFontOption('systemUi', 'system-ui'),
  ThemeFontOption('segoe', 'Segoe UI'),
  ThemeFontOption('pingfang', 'PingFang SC'),
  ThemeFontOption('yahei', 'Microsoft YaHei'),
  ThemeFontOption('notoSans', 'Noto Sans'),
  ThemeFontOption('mono', 'monospace'),
];

ThemeFontOption? themeFontOption(String id) {
  for (final f in kThemeFonts) {
    if (f.id == id) return f;
  }
  return null;
}

/// 分页签强调色的插槽（底部/侧栏导航的 5 个页签）
const List<String> kThemeTabKeys = [
  'tabMap', 'tabStations', 'tabMessages', 'tabPackets', 'tabSettings',
];

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

  /// 页面背景图引用（`file:<存放文件名>`）；null = 不使用背景图
  String? background;

  /// 背景图不透明度（越小越透）
  double bgOpacity;

  /// 背景图模糊半径（0 = 不模糊）
  double bgBlur;

  /// 背景填充方式，见 [kThemeBgFits]
  String bgFit;

  /// 背景对齐，见 [kThemeBgAligns]
  String bgAlign;

  /// 背景缩放倍率
  double bgScale;

  /// 卡片表面的不透明度（1.0 = 完全不透明）。有背景图时默认 0.85。
  double surfaceAlpha;

  /// 界面密度，见 [kThemeDensities]
  String density;

  /// 界面字体 id，见 [kThemeFonts]
  String font;

  /// 每个页签的强调色（键见 [kThemeTabKeys]）；缺项则用主色。
  final Map<String, String> tabColors;

  /// 皮肤元信息（「皮肤」相对「主题」多出来的就是可流传的身份信息）
  String author;
  String description;

  /// 强调渐变之外还要覆盖的卡片强调色（留空 = 用 accentFrom/To）
  bool uniformAccent;

  /// 预览色板（给皮肤列表展示用，按顺序最多 5 个 RRGGBB）
  List<String> previewSwatches;

  AppTheme({
    required this.id,
    required this.name,
    this.builtin = false,
    this.dark,
    Map<String, String>? colors,
    double? radius,
    Map<String, String>? texts,
    Map<String, String>? icons,
    this.background,
    double? bgOpacity,
    double? bgBlur,
    String? bgFit,
    String? bgAlign,
    double? bgScale,
    double? surfaceAlpha,
    String? density,
    String? font,
    Map<String, String>? tabColors,
    this.author = '',
    this.description = '',
    bool? uniformAccent,
    List<String>? previewSwatches,
  })  : colors = colors ?? <String, String>{},
        radius = radius ?? kThemeDefaultRadius,
        texts = texts ?? <String, String>{},
        icons = icons ?? <String, String>{},
        bgOpacity = bgOpacity ?? kThemeBgOpacityDefault,
        bgBlur = bgBlur ?? kThemeBgBlurDefault,
        bgFit = (bgFit != null && kThemeBgFits.contains(bgFit)) ? bgFit : 'cover',
        bgAlign =
            (bgAlign != null && kThemeBgAligns.contains(bgAlign)) ? bgAlign : 'center',
        bgScale = (bgScale ?? 1.0).clamp(kThemeBgScaleMin, kThemeBgScaleMax),
        surfaceAlpha = (surfaceAlpha ?? 0.85).clamp(0.3, 1.0),
        density =
            (density != null && kThemeDensities.contains(density)) ? density : 'normal',
        font = (font != null && themeFontOption(font) != null) ? font : 'default',
        tabColors = tabColors ?? <String, String>{},
        uniformAccent = uniformAccent ?? false,
        previewSwatches = previewSwatches ?? <String>[];

  bool get isEmpty =>
      colors.isEmpty &&
      texts.isEmpty &&
      icons.isEmpty &&
      radius == kThemeDefaultRadius &&
      background == null &&
      tabColors.isEmpty &&
      density == 'normal' &&
      font == 'default' &&
      surfaceAlpha == 0.85;

  bool get hasBackground => background != null && background!.startsWith('file:');

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
        background: background,
        bgOpacity: bgOpacity,
        bgBlur: bgBlur,
        bgFit: bgFit,
        bgAlign: bgAlign,
        bgScale: bgScale,
        surfaceAlpha: surfaceAlpha,
        density: density,
        font: font,
        tabColors: Map<String, String>.from(tabColors),
        author: author,
        description: description,
        uniformAccent: uniformAccent,
        previewSwatches: List<String>.from(previewSwatches),
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
        if (tabColors.isNotEmpty) 'tabColors': tabColors,
        if (density != 'normal') 'density': density,
        if (font != 'default') 'font': font,
        if (surfaceAlpha != 0.85) 'surfaceAlpha': surfaceAlpha,
        if (author.isNotEmpty) 'author': author,
        if (description.isNotEmpty) 'description': description,
        // 只在开启时才写：默认是 false，写出来只是噪声。
        // （写反过一次：`if (!uniformAccent)` 会让 true 永远存不下去。）
        if (uniformAccent) 'uniformAccent': true,
        if (previewSwatches.isNotEmpty) 'previewSwatches': previewSwatches,
        // 背景相关只在真正用到时才写：没背景图的主题文件里不该出现
        // opacity/blur/fit 这三行噪声
        if (background != null) ...{
          'background': background,
          'bgOpacity': bgOpacity,
          'bgBlur': bgBlur,
          'bgFit': bgFit,
          if (bgAlign != 'center') 'bgAlign': bgAlign,
          if (bgScale != 1.0) 'bgScale': bgScale,
        },
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
    final bg = raw['background'];
    if (bg is String && isValidIconRef(bg) && bg.startsWith('file:')) {
      t.background = bg;
      final o = raw['bgOpacity'];
      if (o is num) {
        t.bgOpacity = o.toDouble().clamp(kThemeBgOpacityMin, kThemeBgOpacityMax);
      }
      final b = raw['bgBlur'];
      if (b is num) {
        t.bgBlur = b.toDouble().clamp(0.0, kThemeBgBlurMax);
      }
      final f = raw['bgFit'];
      if (f is String && kThemeBgFits.contains(f)) t.bgFit = f;
      final al = raw['bgAlign'];
      if (al is String && kThemeBgAligns.contains(al)) t.bgAlign = al;
      final sc = raw['bgScale'];
      if (sc is num) {
        t.bgScale = sc.toDouble().clamp(kThemeBgScaleMin, kThemeBgScaleMax);
      }
    } else if (bg != null) {
      // 认不出的引用宁可整个丢掉，也不要留一个「有背景但画不出来」的状态
      warnings?.add('background');
    }
    // 分页签强调色：只认白名单键 + 能解析的颜色
    final tc = raw['tabColors'];
    if (tc is Map) {
      for (final e in tc.entries) {
        final key = '${e.key}';
        final val = '${e.value}';
        if (!kThemeTabKeys.contains(key) || parseHexColor(val) == null) {
          warnings?.add('tabColors.$key');
          continue;
        }
        t.tabColors[key] = val.trim().replaceAll('#', '').toUpperCase();
      }
    }
    final dn = raw['density'];
    if (dn is String && kThemeDensities.contains(dn)) t.density = dn;
    final fn = raw['font'];
    if (fn is String && themeFontOption(fn) != null) t.font = fn;
    final sa = raw['surfaceAlpha'];
    if (sa is num) t.surfaceAlpha = sa.toDouble().clamp(0.3, 1.0);
    final au = raw['author'];
    if (au is String) t.author = au.trim();
    final de = raw['description'];
    if (de is String) t.description = de.trim();
    if (raw['uniformAccent'] is bool) {
      t.uniformAccent = raw['uniformAccent'] as bool;
    }
    final pv = raw['previewSwatches'];
    if (pv is List) {
      for (final e in pv) {
        final v = '$e';
        if (parseHexColor(v) != null) t.previewSwatches.add(v.toUpperCase());
        if (t.previewSwatches.length >= 5) break;
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

/// ─── 打包图片（导出时把图片本体塞进 JSON）───
///
/// 为什么做成**可选的**：把图片嵌进 JSON 意味着 base64 膨胀 33%、文件从几十 KB
/// 变成几 MB、而且再也没法用文本编辑器打开看。所以默认只存引用，用户明确勾了
/// 「包含图片」才嵌。
///
/// 嵌入的字段名与形状：顶层 `images: { "bg_1a2b3c4d.png": "<base64>" }`。
/// 放在**顶层而不是每个主题里**，是因为多个主题常引用同一张图 ——
/// 按名字去重，导出的体积才不会被重复的图撑大。
const String kThemeImagesField = 'images';

/// 嵌入图片的总预算。超过就丢弃多余的那几张（并计数）。
///
/// 不设预算的话，一份伪造/损坏的主题文件能带几百 MB 的 base64 进来，
/// 解码那一刻直接把内存吃爆 —— 而这是个「双击一个文件」就能触发的路径。
const int kThemePackMaxBytes = 24 * 1024 * 1024;

/// 把图片 base64 表附加到一份主题 JSON 上（json 必须是对象）
String attachImages(String json, Map<String, String> images) {
  if (images.isEmpty) return json;
  Object? raw;
  try {
    raw = jsonDecode(json);
  } catch (_) {
    return json;
  }
  if (raw is! Map) return json;
  final out = <String, Object?>{};
  raw.forEach((k, v) => out['$k'] = v);
  out[kThemeImagesField] = images;
  return encodeThemeJson(out);
}

/// 从主题 JSON 里取出嵌入的图片（没有/不合法返回空表）
///
/// 只接受**形状合法**的条目：文件名要能过 [isValidIconRef] 那套规则（挡住路径穿越），
/// 内容非空。形状不对就整条丢掉，而不是留给下游去猜。
Map<String, String> embeddedImages(String json) {
  final out = <String, String>{};
  Object? raw;
  try {
    raw = jsonDecode(json);
  } catch (_) {
    return out;
  }
  if (raw is! Map) return out;
  final m = raw[kThemeImagesField];
  if (m is! Map) return out;
  m.forEach((k, v) {
    final name = '$k';
    final data = '$v';
    if (data.isEmpty) return;
    if (!isValidIconRef('file:$name')) return;
    out[name] = data;
  });
  return out;
}

/// 去掉嵌入的图片（保留其余内容）
String stripImages(String json) {
  Object? raw;
  try {
    raw = jsonDecode(json);
  } catch (_) {
    return json;
  }
  if (raw is! Map) return json;
  if (!raw.containsKey(kThemeImagesField)) return json;
  final out = <String, Object?>{};
  raw.forEach((k, v) {
    if ('$k' != kThemeImagesField) out['$k'] = v;
  });
  return encodeThemeJson(out);
}

/// 把所有 `file:<旧名>` 引用改成新名字。
///
/// 为什么需要它：图片按**内容哈希**落盘，同一张图在别人机器上的文件名与
/// 导出时的不一样（甚至可能已有同样内容但不同前缀的文件）；导入时必须
/// 把引用重新指向本地实际落下的那个名字，否则主题会指向一个不存在的文件。
String? remapRef(String? ref, Map<String, String> oldToNew) {
  if (ref == null) return null;
  if (!ref.startsWith('file:')) return ref;
  final name = ref.substring(5);
  final hit = oldToNew[name];
  return hit == null ? ref : 'file:$hit';
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
/// [imageRemap] 是「导出时的文件名 → 本地落盘后的文件名」映射；
/// 导入带图片的主题包时必传，否则引用会指向本机不存在的文件。
///
/// 两种形态都接受：
/// - 单个主题：`{"kind":"aprslocus-theme","schema":1,"theme":{...}}`（编辑页导出）
/// - 整包：`{"kind":"aprslocus-theme","schema":1,"themes":[...]}`（备份/分享）
/// 这样「导出当前主题分享给别人」与「导出全部主题」都能被同一个入口导入。
ThemeBundle parseThemeJson(String text, {Map<String, String> imageRemap = const {}}) {
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

  // 引用重定向：必须在返回前做完，否则调用方（UI）会先看到一批坏引用
  if (imageRemap.isNotEmpty) {
    for (final t in themes) {
      t.background = remapRef(t.background, imageRemap);
      for (final e in t.icons.entries.toList()) {
        t.icons[e.key] = remapRef(e.value, imageRemap) ?? e.value;
      }
    }
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
