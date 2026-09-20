import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

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
/// 解包嵌入图片的结果
class ThemeAbsorbResult {
  /// 「导出时的文件名 → 本地落盘后的文件名」。
  ///
  /// 由 IO 层算好后返回，**而不是在这里用 Platform 拼路径**：
  /// theme_store.dart 必须在 Web 上也能编译，import dart:io 会直接把它废掉
  /// （这类错误 flutter analyze 也发现不了 —— 它只解析非 Web 那一支）。
  final Map<String, String> remap;

  /// 被跳过的张数（超预算 / 解码失败 / 不是图片 / 写盘失败 / Web 无法写盘）
  final int skipped;

  const ThemeAbsorbResult(this.remap, this.skipped);

  bool get isEmpty => remap.isEmpty && skipped == 0;
}

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
        'dividerStrong': '6B7686',
        'success': '0F7A38',
        'warning': 'A65A00',
        'danger': 'C4103A',
      },
      radius: 8,
    ),
    // ── 以下为「皮肤」基调的内置预设：统一强调 + 更完整的令牌覆写 ──
    AppTheme(
      id: 'builtin:graphite',
      name: '石墨',
      builtin: true,
      dark: true,
      colors: {
        'primary': '22D3EE',
        'accentFrom': '22D3EE',
        'accentTo': '0891B2',
        'surface': '171B21',
        'surfaceAlt': '1F242C',
        'background': '0E1116',
        'backgroundSoft': '171C23',
        'textPrimary': 'E7EBF0',
        'textSecondary': '9BA6B4',
        'textMuted': '6B7684',
        'divider': '262D36',
        'dividerStrong': '39424E',
        'scrim': '05070A',
      },
      radius: 10,
      uniformAccent: true,
    ),
    AppTheme(
      id: 'builtin:sakura',
      name: '樱花',
      builtin: true,
      colors: {
        'primary': 'DB2777',
        'accentFrom': 'F472B6',
        'accentTo': 'BE185D',
        'background': 'FDF4F8',
        'backgroundSoft': 'FAE8F1',
        'surface': 'FFFFFF',
        'surfaceAlt': 'F7E9F0',
        'textPrimary': '3B1F2B',
        'textSecondary': '7A5566',
        'textMuted': 'A98C99',
        'divider': 'F0DCE6',
        'dividerStrong': 'E0C3D1',
      },
      radius: 18,
      uniformAccent: true,
    ),
    AppTheme(
      id: 'builtin:terminal',
      name: '终端',
      builtin: true,
      dark: true,
      colors: {
        'primary': '4ADE80',
        'accentFrom': '4ADE80',
        'accentTo': '15803D',
        'surface': '101510',
        'surfaceAlt': '182018',
        'background': '080B08',
        'backgroundSoft': '101710',
        'textPrimary': 'D7F5DE',
        'textSecondary': '86A88E',
        'textMuted': '5E7A66',
        'divider': '1E2A1E',
        'dividerStrong': '2F4030',
        'scrim': '040604',
      },
      radius: 4,
      uniformAccent: true,
    ),
    AppTheme(
      id: 'builtin:amber',
      name: '琥珀',
      builtin: true,
      colors: {
        'primary': 'B45309',
        'accentFrom': 'F59E0B',
        'accentTo': '92400E',
        'background': 'FBF6EE',
        'backgroundSoft': 'F5EAD8',
        'surface': 'FFFDF8',
        'surfaceAlt': 'F3E7D3',
        'textPrimary': '33240F',
        'textSecondary': '6B5333',
        'textMuted': '9A8666',
        'divider': 'EBDFC9',
        'dividerStrong': 'D8C6A6',
      },
      radius: 14,
      uniformAccent: true,
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
        // 偏好里可能躺着**带嵌入图片**的主题包（例如从备份恢复过来）。
        // 这种状态不能久留：base64 存在 SharedPreferences 里会一直占着
        // 几 MB，而且主题每次读写都要把它搬来搬去。所以在这里把图片落盘、
        // 引用改成指向本地文件，然后把偏好里的 base64 剥掉重写回去。
        final absorbed = await absorbImages(raw);
        var effective = raw;
        if (!absorbed.isEmpty) {
          // 把图片落盘、引用改指到本地，再把 base64 从偏好里剥掉重写回去。
          //
          // 关键点：**即使一张都没落成（skipped > 0）也要剥掉**。否则那几 MB
          // 的 base64 会永远躺在 SharedPreferences 里，而且每次保存主题都要
          // 把它整串搬一遍 —— 看起来「能用」，实际是在持续为一次失败的导入
          // 付存储与性能成本。
          effective = _remapJson(raw, absorbed.remap);
          try {
            await p.setString(kPrefsKey, effective);
          } catch (_) {}
        }
        final d = jsonDecode(effective);
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
    try {
      // 两个目录（图标 / 背景）都要准备好：只建图标目录的话，
      // 背景图在首次渲染时会因为「目录尚未就绪」而回退成无背景，
      // 用户看到的是「设了图但一开始不显示」。
      await icon_io.warmImageStore();
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
  ///
  /// [includeImages] 为真时把引用到的图片本体（base64）一并塞进包里 ——
  /// 这样对方导入后能直接看到同样的背景图/图标，而不需要自己再找图。
  /// 代价是文件会大一个量级（base64 膨胀 33%），且不再是可手工编辑的文本，
  /// 所以要用户明确选择，不能默默替他决定。
  Future<String> exportBundleJson({bool includeImages = false}) async {
    final json = encodeThemeJson(
      ThemeBundle(themes: _user, activeId: _activeId)
          .toJson(includeBuiltin: false),
    );
    if (!includeImages) return json;
    return attachImages(json, await _collectImages(_user));
  }

  /// 导出单个主题的 JSON
  Future<String> exportOneJson(AppTheme t, {bool includeImages = false}) async {
    final json = encodeThemeJson({
      'kind': kThemeKind,
      'schema': kThemeSchema,
      'active': t.id,
      'theme': t.toJson(),
    });
    if (!includeImages) return json;
    return attachImages(json, await _collectImages([t]));
  }

  /// 供备份页复用：把「当前全部用户主题」引用到的图片读成 base64
  Future<Map<String, String>> collectImagesForExport() =>
      _collectImages(_user);

  /// 收集这些主题引用到的所有本地图片 → {文件名: base64}
  ///
  /// 按文件名去重：多个主题（或多个插槽）常用同一张图，不去重的话
  /// 包里会有多份完全相同的 base64。
  Future<Map<String, String>> _collectImages(List<AppTheme> themes) async {
    final refs = <String>{};
    for (final t in themes) {
      final bg = t.background;
      if (bg != null) refs.add(bg);
      for (final v in t.icons.values) {
        if (v.startsWith('file:')) refs.add(v);
      }
    }
    final out = <String, String>{};
    for (final ref in refs) {
      final b64 = await icon_io.readImageBase64(ref);
      if (b64 != null) out[ref.substring(5)] = b64;
    }
    return out;
  }

  /// 当前（用户主题引用的）图片总字节数 —— 给导出前的体积提示用
  Future<int> imagesTotalBytes() async {
    final refs = <String>{};
    for (final t in _user) {
      final bg = t.background;
      if (bg != null) refs.add(bg);
      for (final v in t.icons.values) {
        if (v.startsWith('file:')) refs.add(v);
      }
    }
    var total = 0;
    for (final ref in refs) {
      total += await icon_io.imageByteSize(ref);
    }
    return total;
  }

  /// 让主题包里的「图片文件名 → 本地文件名」映射生效（导出侧的反向操作）。
  ///
  /// 同时把嵌进去的图片落盘，并返回「跳过了几张」以便如实告知用户 ——
  /// 超预算、解码失败、不是图片都会走到跳过分支，静默丢弃是最坏的处理。
  Future<ThemeAbsorbResult> absorbImages(String rawJson) async {
    final embedded = embeddedImages(rawJson);
    if (embedded.isEmpty) return const ThemeAbsorbResult({}, 0);
    final outcome = await icon_io.storeEmbeddedImages(embedded);
    return ThemeAbsorbResult(outcome.remap, outcome.skipped);
  }

  /// 把 JSON 里所有图片引用按 [remap] 改指到本地文件，并返回**不含嵌入图片**的 JSON
  String _remapJson(String json, Map<String, String> remap) {
    final effective = stripImages(json);
    if (remap.isEmpty) return effective;
    try {
      final bundle = parseThemeJson(effective);
      for (final t in bundle.themes) {
        t.background = remapRef(t.background, remap);
        for (final e in t.icons.entries.toList()) {
          t.icons[e.key] = remapRef(e.value, remap) ?? e.value;
        }
      }
      return encodeThemeJson(
        ThemeBundle(themes: bundle.themes, activeId: bundle.activeId)
            .toJson(includeBuiltin: false),
      );
    } catch (_) {
      return effective;
    }
  }

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
    // 皮肤没显式给强调渐变时，用主色推出来 —— 否则「统一卡片配色」会
    // 把每张卡片都刷成内置的蓝，与用户刚改的主色对不上。
    if (!t.overridesColor('accentFrom') && t.uniformAccent) {
      tokens['accentFrom'] = t.colorOf('primary', isDark: isDark);
    }
    if (!t.overridesColor('accentTo') && t.uniformAccent) {
      tokens['accentTo'] = t.colorOf('primary', isDark: isDark);
    }
    C.applyTheme(
      isDark: isDark,
      primary: tokens['primary'] ?? legacyPrimary,
      tokens: tokens,
      radius: t.radius,
    );
    // 密度 / 字体 / 统一强调：这三个是「皮肤」层面的整体观感，
    // 与颜色一起在同一个时刻生效 —— 分两处设置会出现「颜色变了但字号没变」
    // 这种半截状态。
    C.density = kThemeDensityScale[t.density] ?? 1.0;
    final fm = themeFontOption(t.font);
    C.uiFont = fm?.family;
    C.uniformAccent = t.uniformAccent;
    // 表面不透明度只在「真的透出背景」时才有意义，但值本身总是同步过去，
    // 这样用户先调不透明度、再加背景图时不用回头再调一次。
    C.surfaceAlpha = t.surfaceAlpha;

    // 卡片/页面底色是否该透出背景，取决于「这个主题有没有背景图」。
    // 放在这里而不是 build 里：调色板是全局单例，它必须和主题同一时刻更新，
    // 否则会出现「背景已生效但卡片还是不透明」的半截状态。
    final had = C.hasBackground;
    C.hasBackground = t.hasBackground;
    if (had != C.hasBackground) {
      // 表面色的语义变了，所有已构建的页面都得重画一次
      revision++;
    }
  }

  // ─── 背景图 ───

  /// 页面底部的「底」：优先用主题背景图，其次用材质壁纸，都没有则返回 null
  /// （调用方直接显示不透明的页面底色）。
  ///
  /// 这一个入口同时管两件事，是因为**它们必须在同一处生效**：`app.dart` 的
  /// builder 是唯一能一次覆盖「所有页面 + push 出来的子页 + 弹窗路由」的位置。
  /// 分成两处写，必然会出现「材质在设置子页不生效」这种半截状态。
  Widget? buildBackdrop() => buildAppBackground() ?? buildMaterialWallpaper();

  /// 材质壁纸：从主色混出来的一层柔和渐变（斜向 + 中心高光）。
  ///
  /// 为什么不模糊它：它是**渐变**，本身就没有需要压掉的细节，再模糊一层只是白花
  /// 一次全屏 filter（而壁纸每帧都在）。模糊只给真正压在**内容**上的表面用
  /// （见 material.dart 的 MaterialSurface）。
  ///
  /// 为什么要画它：没有这层，「磨砂玻璃」的作用对象就是一片纯色 —— 半透明表面
  /// 后面什么都看不到，用户只会觉得「开了没反应，只是变淡了」。有渐变才有
  /// 「背后有东西」的观感，这也是这次改动的核心。
  Widget? buildMaterialWallpaper() {
    if (!C.materialWallpaper) return null;
    final base = C.materialBase;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [C.materialAccent, base, base],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: CustomPaint(
              painter: _BackdropGrainPainter(C.dark ? Colors.white : Colors.black),
              size: Size.infinite,
            ),
          ),
        ),
        // 中心高光：让「主色在哪里」有个明确的方向，而不是平摊一整面
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.55),
                radius: 1.15,
                colors: [C.materialAccent, base.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        // 亮度归一：浅色模式盖一层白、深色盖一层黑，把整面往中间亮度拉一点，
        // 半透明表面上的正文才有一致的可读性（不然渐变两端差很多）
        Positioned.fill(
          child: ColoredBox(
            color: (C.dark ? C.black : C.white).withValues(alpha: 0.10),
          ),
        ),
      ],
    );
  }

  /// 背景层；主题没设背景图、或图已不可用 → 返回 null（调用方直接用原内容）。
  ///
  /// 三层的顺序是**有讲究**的，不是随手叠的：
  /// 1. 图（按 fill 模式绘制）；
  /// 2. 模糊：作用在**已画好的图**上，所以 SVG 也能模糊（它最终也是像素）；
  /// 3. 遮罩：按深浅模式盖一层底色。
  ///
  /// 第 3 层不能省。没有它，用户拿一张中等亮度的照片当背景，无论深色还是
  /// 浅色文字都会有一半看不清 —— 而「看不清」比「不好看」严重得多。
  /// 遮罩的浓度直接取用户设的不透明度，所以调这个滑杆同时也在调对比度，
  /// 这比再给一个「遮罩强度」旋钮更好理解。
  Widget? buildAppBackground() {
    final t = active;
    if (!t.hasBackground) return null;
    final ref = t.background!;

    final layer = icon_io.buildBackgroundLayer(
      ref,
      fit: _boxFit(t.bgFit),
      tile: t.bgFit == 'tile',
      alignment: _align(t.bgAlign),
      scale: t.bgScale,
      fallback: () => const SizedBox.shrink(),
    );
    if (layer == null) return null; // 图没了：当作没设背景，而不是给一块空白

    Widget w = layer;
    if (t.bgBlur > 0) {
      w = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: t.bgBlur, sigmaY: t.bgBlur),
        child: w,
      );
    }
    final veil = (C.dark ? C.black : C.white)
        .withValues(alpha: t.bgOpacity.clamp(kThemeBgOpacityMin, kThemeBgOpacityMax));
    return Stack(
      children: [
        Positioned.fill(child: w),
        Positioned.fill(child: ColoredBox(color: veil)),
      ],
    );
  }

  /// 背景图预览（主题页里那张小图）。
  ///
  /// 名字保留旧称 `buildBgThumb` 是为了不动 theme_page 里的调用点；
  /// 它只画**用户自己的**背景图，与材质壁纸无关。
  ///
  /// 主题页里那张小预览图。
  ///
  /// 走 [icon_io] 而不是自己 Image.file：路径解析、文件名安全校验、
  /// 「文件被删了怎么办」这些逻辑只在那一处有，复制一份出来必然漂移。
  Widget? buildBgThumb(String ref) =>
      icon_io.buildFileImage(ref, fit: BoxFit.cover);

  /// 背景对齐字符串 → Alignment（认不出回中心）
  Alignment _align(String a) {
    switch (a) {
      case 'top':
        return Alignment.topCenter;
      case 'bottom':
        return Alignment.bottomCenter;
      case 'left':
        return Alignment.centerLeft;
      case 'right':
        return Alignment.centerRight;
      case 'topLeft':
        return Alignment.topLeft;
      case 'topRight':
        return Alignment.topRight;
      case 'bottomLeft':
        return Alignment.bottomLeft;
      case 'bottomRight':
        return Alignment.bottomRight;
    }
    return Alignment.center;
  }

  BoxFit _boxFit(String fit) {
    switch (fit) {
      case 'contain':
        return BoxFit.contain;
      case 'stretch':
        return BoxFit.fill;
      case 'tile':
        return BoxFit.none;
    }
    return BoxFit.cover;
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

  /// 导入一张背景图（走与图标同一条通道，只是上限与目录不同）
  Future<icon_io.IconImportResult> importBackground() =>
      icon_io.importBackgroundFromPicker();

  /// 某个页签的强调色（未被主题指定则返回 null，调用方回退 C.blue）
  Color? tabAccent(String tabKey, {required bool isDark}) {
    final t = active;
    final hex = t.tabColors[tabKey];
    if (hex == null) return null;
    return parseHexColor(hex);
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

/// 底上那层极淡的颗粒。
///
/// Win11 的云母有细微的「纸纹」，全平的渐变看起来像廉价的色块；这一层用
/// 确定性（不用 Random，避免每次重画都不一样）的点阵把它补回来。
///
/// 代价意识：这是全屏 CustomPaint，但点阵是**固定**的、只有 ~600 个点，
/// 在设备像素比下的开销远小于一次全屏高斯模糊，所以壁纸不模糊、颗粒反而保留。
class _BackdropGrainPainter extends CustomPainter {
  final Color color;
  const _BackdropGrainPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()..color = color.withValues(alpha: 0.022);
    const step = 22.0;
    var i = 0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        // 三级错位：不然点会排成规整的网格，看起来像印刷网纹而不是颗粒
        final dx = (i % 3) * (step / 3);
        canvas.drawCircle(Offset(x + dx, y), 0.7, paint);
        i++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropGrainPainter old) => old.color != color;
}
