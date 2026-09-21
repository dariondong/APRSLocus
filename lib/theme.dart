import 'dart:io';

import 'package:flutter/material.dart';

/// ─── 界面材质（磨砂玻璃 / 云母）───
///
/// 语义：这是**全局的显示偏好**（像深色模式、界面缩放一样），不是主题的一部分。
/// 主题管「什么颜色」，材质管「表面有多透、后面模糊多强」，两者正交。
///
/// 为什么只有三档、而不是给「模糊强度」一个滑杆：材质的两端（关闭 / 玻璃 / 云母）
/// 各自对应一套**互相配合**的参数（表面不透明度 + 模糊半径 + 描边），随便组合会
/// 出现「半透明但没模糊」（文字与瓦片糊在一起）这种不可用的中间态。
/// 想细调不透明度的人用主题里的 `surfaceAlpha`（它在这里是有意义的乘数）。
enum UiMaterial {
  /// 关闭：表面实色，与旧版逐像素一致（**默认值**）
  none,

  /// 磨砂玻璃：更透（0.55）、模糊更强，像 Win11 Acrylic
  glass,

  /// 云母：更实（0.78）、模糊较轻、带一层主色的灰，像 Win11 Mica
  mica;
}

/// 偏好里存的字符串 → 材质。认不出的一律回落 [UiMaterial.none]。
///
/// 为什么不用 enum 名直接存：偏好是用户可见、也可能被手工改的文本，
/// 用短名字（'glass' / 'mica'）比 'UiMaterial.glass' 更好读也更好改。
UiMaterial uiMaterialOf(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'glass':
      return UiMaterial.glass;
    case 'mica':
      return UiMaterial.mica;
  }
  return UiMaterial.none;
}

/// ─── 界面布局（1.0 经典 / 2.0 地图为基底）───
///
/// 与 [UiMaterial] 一样，这是**显示偏好**而不是主题的一部分：主题管颜色，布局管
/// 结构；两者正交，可以任意组合（2.0 + 云母、1.0 + 磨砂玻璃都成立）。
///
/// 为什么默认 [classic]：2.0 会把导航从「左侧栏/底部栏」换成「底部可拖拽卡片 + 浮层
/// 顶栏」—— 这是改变肌肉记忆级别的改动，不能替老用户决定。默认值 = 升级后与旧版
/// 一模一样，这才是兼容底线。
enum UiLayout {
  /// 1.0 经典：宽屏左侧栏 + 窄屏底部导航 + 顶栏
  classic,

  /// 2.0 地图为基底：地图常驻整屏，其余页装进底部可拖拽卡片，顶栏浮在地图上
  sheet;
}

UiLayout uiLayoutOf(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'sheet':
      return UiLayout.sheet;
  }
  return UiLayout.classic;
}

/// 布局 → 偏好里存的字符串（[UiLayout.classic] 存空串 = 不写这一项）
String uiLayoutName(UiLayout l) =>
    l == UiLayout.sheet ? 'sheet' : '';

/// 材质对应的表面不透明度 / 模糊半径。
///
/// 抽成函数（而不是只塞在 C 的 getter 里）是为了让**设置页里的预览小样**能用
/// 同一组数字：预览要展示「另一档有多透」，就必须能拿来问「玻璃是多少」。
/// 两边各写一套数字一定会漂，而这种漂移只有截图对比才看得出来 ——
/// 也就是说，没人会发现。
double uiMaterialAlphaOf(UiMaterial m) {
  switch (m) {
    case UiMaterial.glass:
      return 0.55;
    case UiMaterial.mica:
      return 0.78;
    case UiMaterial.none:
      return 1.0;
  }
}

double uiMaterialBlurOf(UiMaterial m) {
  switch (m) {
    case UiMaterial.glass:
      // 34 → 24：模糊的代价随半径上升，而观感在 24 时已经「明显是磨砂」。
      // 真正贵的是「大面板 × 每帧重算」，所以配合下面两条一起降：
      // 小浮层不再模糊、外壳不再因无关状态重建（见 shell2._onState）。
      return 24.0;
    case UiMaterial.mica:
      return 16.0;
    case UiMaterial.none:
      return 0.0;
  }
}

/// 材质 → 偏好里存的字符串（[UiMaterial.none] 存空串 = 不写这一项）
String uiMaterialName(UiMaterial m) {
  switch (m) {
    case UiMaterial.glass:
      return 'glass';
    case UiMaterial.mica:
      return 'mica';
    case UiMaterial.none:
      return '';
  }
}

/// Windows 上 Roboto 未预装，用系统字体避免字体回退导致发虚
String get _uiFont {
  if (Platform.isWindows) return 'Segoe UI';
  if (Platform.isLinux) return 'Noto Sans';
  if (Platform.isMacOS) return '.SF NS Text';
  return 'Roboto';
}

class C {
  C._();
  // Backgrounds
  static Color bg = const Color(0xFFF3F5F9);
  static Color bgSoft = const Color(0xFFEDF1F7);
  static Color white = Colors.white;
  static Color black = const Color(0xFF141A26);
  static Color ink = const Color(0xFF253044);
  static Color slate = const Color(0xFF637083);
  static Color grey = const Color(0xFF94A0B2);
  static Color greyLight = const Color(0xFFC3CCD9);
  static Color greyBg = const Color(0xFFEDF0F5);
  static Color border = const Color(0xFFE5E9F0);
  static Color borderStrong = const Color(0xFFD2DAE4);

  // Accent
  static Color blue = const Color(0xFF2563EB);
  static Color blueDark = const Color(0xFF1D4ED8);
  static Color blueBg = const Color(0xFFEAF1FE);
  static Color indigo = const Color(0xFF4F46E5);

  // Status
  static Color green = const Color(0xFF16A34A);
  static Color greenBg = const Color(0xFFE9F9EF);
  static Color red = const Color(0xFFE11D48);
  static Color redBg = const Color(0xFFFEEDF0);
  static Color yellow = const Color(0xFFD97706);
  static Color yellowBg = const Color(0xFFFFF6E5);
  static Color cyan = const Color(0xFF0E7490);
  static Color cyanBg = const Color(0xFFE4F5F9);
  static Color purple = const Color(0xFF7C3AED);
  static Color purpleBg = const Color(0xFFF2EDFE);
  static Color orange = const Color(0xFFEA580C);
  static Color orangeBg = const Color(0xFFFFF1E7);

  // Map
  static Color mapBg = const Color(0xFFF4F7FC);
  static Color mapGrid = const Color(0xFFE2E9F2);
  static Color mapGridStrong = const Color(0xFFD0DAE8);
  static Color mapLand = const Color(0xFFEAF0F8);
  static Color water = const Color(0xFFD8E8F5);

  /// 深色模式
  static bool dark = false;

  /// 卡片圆角（主题可调）。默认 16；`cardDeco` / `fieldDeco` 从这里取默认值。
  ///
  /// 只作用于**共用辅助函数**，而不是 383 处 `BorderRadius.circular(N)` ——
  /// 那些 N 里有徽标用的 2、胶囊用的 999，统一乘一个系数会把小圆点变成
  /// 菱形、把胶囊撑破。所以这里的语义就是「卡片与输入框的圆角」，
  /// UI 上也是这么标称呼，不假装它是全局圆角。
  static double radius = kDefaultRadius;

  static const double kDefaultRadius = 16;

  /// 是否设置了背景图（由 ThemeController 在 applyColors 时写入）。
  ///
  /// 有背景图时卡片表面必须**半透明**：不透明的话内容全被图盖住反而更不可读
  /// （等于只是换了个更花的底色），透一点才能既看见图又看清内容。
  static bool hasBackground = false;

  /// 页面底色的实际填色。
  ///
  /// 有底（背景图或材质壁纸）时必须**透明**：页面底色是不透明的 C.bg，
  /// 直接盖在底上会把底完全遮住（用户只会看到「设了图但没变化」/
  /// 「开了磨砂玻璃但界面一点没变」）。
  static Color get pageFill => hasBackdrop ? Colors.transparent : bg;

  /// 卡片表面的实际填色
  ///
  /// 底层带 `materialAlpha`（材质的固定基准），再乘用户调过的 `surfaceAlpha`
  /// 相对默认 0.85 的比例 —— 这样「材质定的通透程度」和「用户自己调的不透明度」
  /// 都保留：玻璃永远比云母透，而滑杆往哪边拉就真的往哪边去。
  static Color get surfaceFill =>
      hasBackdrop ? white.withValues(alpha: _surfaceAlphaEff) : white;

  /// 顶栏/侧栏等「压在内容上层」的表面，比卡片更实一点，避免文字与图打架
  static Color get surfaceFillStrong =>
      hasBackdrop ? white.withValues(alpha: _surfaceStrongAlphaEff) : white;

  /// **小浮层**（工具钮、图例、提示胶囊、细横条）的表面色。
  ///
  /// 比 [sheetFill] 略透一点：小浮层用的是**较小的模糊半径**（[kChipBlurSigma]），
  /// 透一点才看得出「背后有东西」；再透就会让底下的地图透上来把字糊掉。
  /// 0.72 与 kChipBlurSigma 是一对数字，改一个就要回头看另一个。
  static Color get chipFill =>
      materialOn ? white.withValues(alpha: 0.72) : white;

  /// 小浮层的模糊半径。
  ///
  /// 为什么不直接用小按钮的默认半径：模糊的代价 ≈ 面积 × 半径，而小浮层的**面积**
  /// 本来就小（38px 的按钮只有 1.4k px²，一块底部面板是 196k），所以它便宜；
  /// 但半径给大反而会把这些小东西的边缘糊成一团灰、看着像没画好。12 是那个平衡点。
  static const double kChipBlurSigma = 12;

  /// 弹窗 / 底部面板的表面：材质下也做成半透明。
  ///
  /// 比卡片实（0.9 档）：这类表面背后是**正在滚动的列表或地图**，
  /// 透太多会看不清里面的字，而弹窗里的内容通常是用户马上要做决定的。
  static Color get sheetFill => hasBackdrop
      ? white.withValues(alpha: (_surfaceStrongAlphaEff + 0.04).clamp(0.0, 1.0))
      : white;

  /// 表面实际用到的 alpha（基准 × 用户系数，且始终留一点通透）
  static double get _surfaceAlphaEff {
    if (!hasBackdrop) return 1.0;
    final user = (surfaceAlpha / 0.85).clamp(0.5, 1.2);
    return ((materialOn ? materialAlpha : 0.85) * user).clamp(0.15, 1.0);
  }

  static double get _surfaceStrongAlphaEff {
    if (!hasBackdrop) return 1.0;
    return (_surfaceAlphaEff + 0.12).clamp(0.0, 1.0);
  }

  /// 卡片表面不透明度（主题可调；仅在真的透出背景时才有意义）
  static double surfaceAlpha = 0.85;

  /// 界面密度系数（0.85 紧凑 / 1.0 标准 / 1.2 宽松）。
  /// 只作用于共用辅助函数算出来的留白，不去改硬编码的 EdgeInsets。
  static double density = 1.0;

  /// 界面字体族（null = 平台默认）
  static String? uiFont;

  /// 强调渐变（设置页入口卡片的图标底色）
  static Color accentFrom = const Color(0xFF2563EB);
  static Color accentTo = const Color(0xFF1D4ED8);

  /// 皮肤是否把各入口卡片统一成同一套强调渐变。
  /// 默认 false —— 保持每张卡片原本各自的配色，界面与旧版一模一样。
  static bool uniformAccent = false;

  /// 当前界面材质（磨砂玻璃 / 云母）。由 AppState 在 applySavedTheme 里写入。
  ///
  /// 刻意**不**放进 `applyTheme` 的重置列表：材质是显示偏好，换主题不该把它
  /// 悄悄关掉（那会表现为「换了个皮肤，磨砂玻璃自己没了」）。
  static UiMaterial material = UiMaterial.none;

  /// 当前界面布局（v1.6.139 起的「 UI 2.0」）。由 AppState 在 applySavedTheme 里写入。
  ///
  /// 与 [material] 同理，刻意**不**放进 `applyTheme` 的重置列表：换肤不该
  /// 偷偷把布局换回 1.0。
  static UiLayout layout = UiLayout.classic;

  /// 是否是「地图为基底」的 2.0 布局。
  ///
  /// 多处要问这个问题（地图要不要当底、外壳选哪一套、卡片要不要半透明），
  /// 所以给个具名 getter：到处写 `C.layout == UiLayout.sheet` 容易在某处写成
  /// 反的，而写反了的表现是「整个界面变成另一套布局、但不报错」。
  static bool get sheetLayout => layout == UiLayout.sheet;

  /// 是否有材质（= 表面要半透明 + 壁纸要画出来）
  static bool get materialOn => material != UiMaterial.none;

  /// 是否有「底」可透：主题背景图，或者材质壁纸。
  ///
  /// 两个来源都必须算进来，否则会出现两种半截状态：
  /// - 只看材质：老用户设的**背景图**会失效（卡片突然变实色，图被盖住）；
  /// - 只看背景图：开了材质却没设图时，卡片仍是实色 —— 用户只会觉得「开了没反应」。
  static bool get hasBackdrop => hasBackground || materialOn;

  /// 材质**壁纸**（那层从主色混出来的渐变）是否该画。
  ///
  /// 用户给主题设了背景图时不画：那是他自己挑的图，在他的图上再叠一层渐变
  /// 只会变成一团脏颜色。此时材质只负责「把顶栏/浮层模糊掉」，不再造背景。
  static bool get materialWallpaper => materialOn && !hasBackground;

  /// 材质下的表面不透明度。
  ///
  /// 玻璃必须比云母透：Acrylic 的观感就是「能认出背后是什么」，而 Mica 是
  /// 「只有一点色调」。这两个数字与模糊半径是一套的，改一个就要回头看另一个。
  ///
  /// 材质开启时它**就是**基准（即使用户也有背景图）：用户刚选的那一档应该说了算，
  /// 否则会出现「选了磨砂玻璃但比之前还不透」。背景图用户的对比度由那层自动
  /// 遮罩（[hasBackground] 那套）与 `surfaceAlpha` 滑杆兜底。
  static double get materialAlpha => uiMaterialAlphaOf(material);

  /// 材质下的模糊半径（sigma）
  static double get materialBlur => uiMaterialBlurOf(material);


  /// 材质壁纸的底色：从主色混出来的一层极淡的色，而不是纯灰。
  ///
  /// 用主色而不是灰色，是为了让「云母」看起来像 Windows 的「取壁纸色调」而
  /// 不是一块灰塑料；同时也让材质跟着用户改的主色走。
  static Color get materialBase => dark
      ? Color.alphaBlend(blue.withValues(alpha: 0.14), bg)
      : Color.alphaBlend(blue.withValues(alpha: 0.08), bg);

  /// 材质壁纸的点缀色（渐变的高光端）
  static Color get materialAccent => dark
      ? Color.alphaBlend(blue.withValues(alpha: 0.30), bg)
      : Color.alphaBlend(blue.withValues(alpha: 0.20), bg);

  /// 按密度缩放一个内边距
  static EdgeInsets pad(double l, double t, double r, double b) =>
      EdgeInsets.fromLTRB(l * density, t * density, r * density, b * density);

  /// 按密度缩放一个统一内边距
  static EdgeInsets padAll(double v) => EdgeInsets.all(v * density);

  /// 强调渐变装饰（各入口卡片的图标块共用）。
  ///
  /// [fallback] 是该卡片**原本**的配色：皮肤没要求统一时原样用它，
  /// 这样默认观感与旧版逐像素一致，皮肤开启统一后才换成 accentFrom/To。
  static BoxDecoration accentDeco({double radius = 9, List<Color>? fallback}) {
    final colors = (!uniformAccent && fallback != null)
        ? fallback
        : <Color>[accentFrom, accentTo];
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// 输入框圆角：比卡片小一档，跟随卡片圆角但不小于 6
  static double get fieldRadius =>
      (radius - 4) < 6 ? 6 : (radius - 4);

  /// 应用主题：深色 / 主色 / 令牌覆写。
  ///
  /// [tokens] 的键是 theme_model.dart 里的 [ThemeColorToken.id]。
  /// 不传（或传空）时行为与旧版完全一致 —— 这是**有意的兼容保证**：
  /// 老用户只有 `themeColor`，他们的界面不能被这次改动改掉。
  static void applyTheme({
    required bool isDark,
    Color? primary,
    Map<String, Color>? tokens,
    double? radius,
  }) {
    dark = isDark;
    if (primary != null) blue = primary;
    if (isDark) {
      bg = const Color(0xFF12161E);
      bgSoft = const Color(0xFF1B2230);
      white = const Color(0xFF1E2530);
      black = const Color(0xFF0C0F14);
      ink = const Color(0xFFE6EAF2);
      slate = const Color(0xFFAAB4C5);
      grey = const Color(0xFF7A8699);
      greyLight = const Color(0xFF5A6678);
      greyBg = const Color(0xFF232B39);
      border = const Color(0xFF2A3344);
      borderStrong = const Color(0xFF39445A);
      blueBg = const Color(0xFF16233F);
      greenBg = const Color(0xFF13301F);
      redBg = const Color(0xFF3B1520);
      yellowBg = const Color(0xFF3A2A0F);
      cyanBg = const Color(0xFF0F2A33);
      purpleBg = const Color(0xFF251740);
      orangeBg = const Color(0xFF3B1D0E);
      mapBg = const Color(0xFF141A26);
      mapGrid = const Color(0xFF1E2736);
      mapGridStrong = const Color(0xFF2A364A);
      mapLand = const Color(0xFF182030);
      water = const Color(0xFF142334);
    } else {
      bg = const Color(0xFFF3F5F9);
      bgSoft = const Color(0xFFEDF1F7);
      white = Colors.white;
      black = const Color(0xFF141A26);
      ink = const Color(0xFF253044);
      slate = const Color(0xFF637083);
      grey = const Color(0xFF94A0B2);
      greyLight = const Color(0xFFC3CCD9);
      greyBg = const Color(0xFFEDF0F5);
      border = const Color(0xFFE5E9F0);
      borderStrong = const Color(0xFFD2DAE4);
      blueBg = const Color(0xFFEAF1FE);
      greenBg = const Color(0xFFE9F9EF);
      redBg = const Color(0xFFFEEDF0);
      yellowBg = const Color(0xFFFFF6E5);
      cyanBg = const Color(0xFFE4F5F9);
      purpleBg = const Color(0xFFF2EDFE);
      orangeBg = const Color(0xFFFFF1E7);
      mapBg = const Color(0xFFF4F7FC);
      mapGrid = const Color(0xFFE2E9F2);
      mapGridStrong = const Color(0xFFD0DAE8);
      mapLand = const Color(0xFFEAF0F8);
      water = const Color(0xFFD8E8F5);
      if (primary != null) {
        blue = primary;
      } else {
        blue = const Color(0xFF2563EB);
      }
    }
    C.radius = radius ?? kDefaultRadius;
    // 先复位到内置默认，再让令牌覆写覆盖 —— 顺序反了的话，换主题时
    // 上一个主题设过的新令牌会残留（例如强调渐变还是旧皮肤的颜色）。
    surfaceAlpha = 0.85;
    density = 1.0;
    uiFont = null;
    uniformAccent = false;
    accentFrom = const Color(0xFF2563EB);
    accentTo = const Color(0xFF1D4ED8);
    if (tokens != null && tokens.isNotEmpty) _applyTokens(tokens);
  }

  /// 把主题令牌写到对应的颜色字段上。
  ///
  /// 一个令牌可能对应多个字段（例如主色深浅），这里显式列出来，
  /// 而不是让调用方去猜 —— 猜错的后果是「改了主色但某个角落没变」，
  /// 用户只会觉得主题功能是坏的。
  static void _applyTokens(Map<String, Color> t) {
    Color? g(String k) => t[k];
    if (g('primary') != null) {
      blue = g('primary')!;
      // 主色的深一档：直接压暗，避免再引入一个必须手工同步的令牌
      blueDark = _darken(g('primary')!, 0.18);
    }
    if (g('surface') != null) white = g('surface')!;
    if (g('background') != null) bg = g('background')!;
    if (g('backgroundSoft') != null) bgSoft = g('backgroundSoft')!;
    if (g('textPrimary') != null) ink = g('textPrimary')!;
    if (g('textSecondary') != null) slate = g('textSecondary')!;
    if (g('textMuted') != null) grey = g('textMuted')!;
    if (g('divider') != null) {
      border = g('divider')!;
      borderStrong = _darken(g('divider')!, 0.10);
    }
    if (g('success') != null) green = g('success')!;
    if (g('warning') != null) yellow = g('warning')!;
    if (g('danger') != null) red = g('danger')!;
    if (g('info') != null) cyan = g('info')!;
    // 次级面板底色：greyBg 与 greyLight 是同一族的两个深浅
    if (g('surfaceAlt') != null) {
      greyBg = g('surfaceAlt')!;
      greyLight = _lighten(g('surfaceAlt')!, 0.10);
    }
    if (g('dividerStrong') != null) borderStrong = g('dividerStrong')!;
    if (g('scrim') != null) black = g('scrim')!;
    if (g('accentFrom') != null) accentFrom = g('accentFrom')!;
    if (g('accentTo') != null) accentTo = g('accentTo')!;
    // 强调渐变只给了一头时，另一头跟着走，避免出现「半截默认色」的怪渐变
    if (g('accentFrom') != null && g('accentTo') == null) {
      accentTo = _darken(g('accentFrom')!, 0.14);
    }
    if (g('accentTo') != null && g('accentFrom') == null) {
      accentFrom = _lighten(g('accentTo')!, 0.14);
    }
  }

  static Color _lighten(Color c, double amount) {
    HSLColor h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static Color _darken(Color c, double amount) {
    HSLColor h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}

TextStyle ts(double s, {Color? c, FontWeight? w, double? h, double? ls}) =>
    TextStyle(
      fontSize: s,
      color: c ?? C.ink,
      fontWeight: w ?? FontWeight.w400,
      height: h,
      letterSpacing: ls,
      fontFamily: C.uiFont ?? _uiFont,
      fontFamilyFallback: const ['Microsoft YaHei', 'PingFang SC', 'Noto Sans CJK SC'],
      package: null,
    );

TextStyle mono(double s, {Color? c, FontWeight? w}) =>
    TextStyle(
      fontSize: s,
      color: c ?? C.ink,
      fontWeight: w ?? FontWeight.w500,
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Consolas', 'Microsoft YaHei'],
      package: null,
    );

/// ─── 三级高度（阴影）───
///
/// 之前散着 15 种 (blur, y, alpha) 组合（0.07/0.08/0.09/0.10/0.12/0.14/0.15/
/// 0.16/0.18/0.20/0.22/0.25 × blur 10~20），等于「每个表面自己定投影」——
/// 看起来就是没有层次体系。现在只留三级，按**浮起高度**选：
///
/// * [elev1] 小浮起：图标按钮、圆形工具钮、chip 这类小控件；
/// * [elev2] 面板：顶栏、浮动提示条、地图浮层；
/// * [elev3] 最高层：底部面板、对话框、醒目横幅。
///
/// [softShadow] 保留（默认参数即「卡片」那一档）：卡片是最多的表面，
/// 它的取值不动 —— 这次的目标是**收拾乱**，不是改默认长相。
List<BoxShadow> elev1() => [
      BoxShadow(
        color: C.black.withValues(alpha: 0.08),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ];

List<BoxShadow> elev2() => [
      BoxShadow(
        color: C.black.withValues(alpha: 0.10),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];

List<BoxShadow> elev3() => [
      BoxShadow(
        color: C.black.withValues(alpha: 0.16),
        blurRadius: 18,
        offset: const Offset(0, 5),
      ),
    ];

List<BoxShadow> softShadow({double blur = 18, double y = 5, double alpha = 0.07}) => [
      BoxShadow(
        color: C.black.withValues(alpha: alpha),
        blurRadius: blur,
        offset: Offset(0, y),
      ),
    ];

/// 只有上两角圆角的卡片装饰（底部面板的头部用）
BoxDecoration sheetDeco({double r = 20}) => BoxDecoration(
      color: C.sheetFill,
      borderRadius: BorderRadius.vertical(top: Radius.circular(r)),
    );

/// 卡片装饰。圆角默认取 [C.radius]（主题可调），显式传 [r] 则优先用 [r]。
/// 卡片内容内边距（随密度缩放）。调用点若已写死 EdgeInsets 则保持原样 ——
/// 只把「通用卡片」这一层交给密度控制，避免为一致性去改上百处。
EdgeInsets cardPad([double v = 14]) => C.padAll(v);

BoxDecoration cardDeco({Color? bg, double? r, bool shadow = true}) =>
    BoxDecoration(
      // 默认取 surfaceFill：有背景图时自动半透明，调用点一个都不用改
      color: bg ?? C.surfaceFill,
      borderRadius: BorderRadius.circular(r ?? C.radius),
      boxShadow: shadow ? softShadow() : null,
    );

BoxDecoration fieldDeco() => BoxDecoration(
      color: C.surfaceFillStrong,
      borderRadius: BorderRadius.circular(C.fieldRadius),
      border: Border.all(color: C.border),
    );

class T {
  T._();
  static TextStyle get h1 => ts(26, w: FontWeight.w800, ls: -0.5);
  static TextStyle get h2 => ts(20, w: FontWeight.w700, ls: -0.3);
  static TextStyle get h3 => ts(16, w: FontWeight.w600);
  static TextStyle get body => ts(13);
  static TextStyle get cap => ts(11, c: C.slate, w: FontWeight.w600, ls: 1.1);
  static TextStyle get num => mono(16, w: FontWeight.w700);
}
