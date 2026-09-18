import 'dart:io';

import 'package:flutter/material.dart';

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
      fontFamily: _uiFont,
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

List<BoxShadow> softShadow({double blur = 18, double y = 5, double alpha = 0.07}) => [
      BoxShadow(
        color: C.black.withValues(alpha: alpha),
        blurRadius: blur,
        offset: Offset(0, y),
      ),
    ];

/// 卡片装饰。圆角默认取 [C.radius]（主题可调），显式传 [r] 则优先用 [r]。
BoxDecoration cardDeco({Color? bg, double? r, bool shadow = true}) =>
    BoxDecoration(
      color: bg ?? C.white,
      borderRadius: BorderRadius.circular(r ?? C.radius),
      boxShadow: shadow ? softShadow() : null,
    );

BoxDecoration fieldDeco() => BoxDecoration(
      color: C.white,
      borderRadius: BorderRadius.circular(C.fieldRadius),
      border: Border.all(color: C.border),
    );

class T {
  T._();
  static TextStyle get h1 => ts(26, w: FontWeight.w800, ls: -0.5);
  static TextStyle get h2 => ts(20, w: FontWeight.w700, ls: -0.3);
  static TextStyle get h3 => ts(16, w: FontWeight.w600);
  static TextStyle get body => ts(14);
  static TextStyle get cap => ts(11, c: C.slate, w: FontWeight.w600, ls: 1.1);
  static TextStyle get num => mono(16, w: FontWeight.w700);
}
