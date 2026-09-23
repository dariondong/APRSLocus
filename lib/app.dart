import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme.dart';
import 'theme_store.dart';
import 'state.dart';
import 'home_page.dart';
import 'shell2.dart';
import 'splash_page.dart';
import 'oobe_page.dart';
import 'app_widget.dart';
import 'l10n/app_localizations.dart';

/// 将设置里保存的语言码（如 'zh_TW'）解析成 Locale
Locale _localeOf(String s) {
  final parts = s.split('_');
  return parts.length > 1
      ? Locale(parts[0], parts[1])
      : Locale(s);
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final AppState _state = AppState();

  /// 当前亮暗下的主题。
  ///
  /// 抽出来只为一件事：给它装**带底的转场**（见 [_BackdropTransitionBuilder]）。
  ThemeData _themeFor(Brightness b) =>
      (b == Brightness.dark
              ? ThemeData.dark(useMaterial3: true)
              : ThemeData.light(useMaterial3: true))
          .copyWith(
        scaffoldBackgroundColor: C.bg,
        canvasColor: C.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: C.blue,
          brightness: b,
        ).copyWith(surface: C.bg),
        splashFactory: InkSparkle.splashFactory,
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            for (final p in TargetPlatform.values)
              p: const _BackdropTransitionBuilder(),
          },
        ),
      );
  bool _lastDark = false;
  String _lastTheme = '';
  String _lastLocale = '';
  String _lastMaterial = '';
  String _lastLayout = '';
  int _lastReloadTick = 0;
  int _lastThemeRevision = 0;

  @override
  void initState() {
    super.initState();
    // 仅在深色/主题色/语言/重载变化时重建 MaterialApp（避免数据洪峰期间反复重建整个导航栈）
    _state.addListener(_onThemeChange);
    // 启动后应用保存的主题（深色/自定义色）——_loadPrefs 完成后还会再应用一次
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _state.applySavedTheme();
      if (mounted) setState(() {});
    });
  }

  void _onThemeChange() {
    final dark = _state.darkMode;
    final tc = _state.themeColor;
    final loc = _state.locale;
    final mat = _state.uiMaterial;
    // 布局（1.0 / 2.0）也要看：它换的是**整个外壳**（HomePage ↔ HomeShell2），
    // 不重建就会出现「设置里点了 2.0、界面还是 1.0」。与材质同理不进 `key`。
    final lay = _state.uiLayout;
    final rt = _state.reloadTick;
    // 主题改动也要重建 MaterialApp：颜色/圆角写在 ThemeData 里，
    // 但它们**不**需要换 key（换 key 会把导航栈整个丢掉，
    // 主题页正在编辑时会被弹出去）。
    final tr = _state.themeRevision;
    // 材质（磨砂玻璃/云母）也要进这个判断：它改的是**表面填色与底图**，
    // 不重建 MaterialApp 的话只有下次进页面才生效 —— 那和「开关坏了」没区别。
    // （但它不能进 `key`：换 key 会把导航栈整个丢掉，用户正在显示设置页里
    //  点这一档，界面会当场弹回首页。）
    if (dark != _lastDark ||
        tc != _lastTheme ||
        lay != _lastLayout ||
        loc != _lastLocale ||
        mat != _lastMaterial ||
        rt != _lastReloadTick ||
        tr != _lastThemeRevision) {
      _lastDark = dark;
      _lastTheme = tc;
      _lastLocale = loc;
      _lastMaterial = mat;
      _lastLayout = lay;
      _lastReloadTick = rt;
      _lastThemeRevision = tr;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _state.removeListener(_onThemeChange);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: ValueKey('app_${_state.reloadTick}'),
      title: 'APRSlocus',
      debugShowCheckedModeBanner: false,
      theme: _themeFor(Brightness.light),
      darkTheme: _themeFor(Brightness.dark),
      themeMode: _state.darkMode ? ThemeMode.dark : ThemeMode.light,
      locale: _state.locale.isEmpty
          ? null
          : _localeOf(_state.locale),
      supportedLocales: const [
        Locale('zh'),
        Locale('zh', 'TW'),
        Locale('en'),
        Locale('es'),
        Locale('ja'),
        Locale('id'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final scale = _state.uiScale;
        // 底（背景图 / 材质壁纸）在这里**一次性**生效：builder 位于 MaterialApp
        // 之下、Navigator 之上，所以所有页面（含设置子页、push 出来的对话框
        // 页面）都盖到了，不必逐个页面去改 —— 逐个改的结果必然是漏掉几个，
        // 而那几页看起来就像「背景图/材质有时候不生效」。
        final bg = ThemeController.instance.buildBackdrop();
        Widget content = AppWidgetSync(state: _state, child: child!);
        if (bg != null) {
          content = Stack(
            children: [
              Positioned.fill(child: bg),
              Positioned.fill(child: content),
            ],
          );
        }
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          // 说明：桌面小组件同步器 AppWidgetSync 也必须在 builder 的 context 下
          // ——它位于 Localizations **之下**，所以里面 AppLocalizations.of(context)
          // 拿到的就是当前真正生效的语言（包括「跟随系统」那档）。换到 App 层
          // 就得自己重算 locale，一旦算错，组件上的文字会和界面差一个语言。
          child: content,
        );
      },
      home: ListenableBuilder(
        listenable: _state,
        builder: (_, _) {
          if (!_state.initialized) return const SplashPage();
          // 首次启动：进入设置向导
          if (!_state.oobeDone) return OobePage(state: _state);
          // 两套外壳二选一（设置 → 显示 → 界面布局）。判断读 C 上的全局值
          // 而不是 _state.uiLayout：C.layout 与调色板同一时刻写入，不会出现
          // 「颜色已换、外壳还是旧的」这种半截状态。
          return C.sheetLayout
              ? HomeShell2(state: _state)
              : HomePage(state: _state);
        },
      ),
    );
  }
}

/// 带**底色**的转场：进子页时不让动画期间透出「上一页」。
///
/// ── 为什么需要它 ──
///
/// 应用只有**一层**底（`builder` 里的 `ThemeController.buildBackdrop()`，压在
/// Navigator 之下）。而 Flutter 在路由转场动画期间会把新路由的 OverlayEntry 设为
/// **非 opaque**（`routes.dart` 的 `_handleStatusChanged`：forward/reverse 时
/// `opaque = false`，completed 才恢复）—— 于是动画期间旧路由照常绘制，新页面若是
/// 透明底（本项目正是：页面底色 = `C.pageFill` = 透明），**透出来的是上一页的内容**；
/// 动画一完旧路由停画，底色才「出现」。用户看到的就是
/// **「动画期间背景色闪一下／先透明后出现，动画完才正常」**。
///
/// ── 修法 ──
///
/// 转场期间给页面**自带一份底**：与 `builder` 那份同一函数（[ThemeController.buildBackdrop]），
/// 所以逐像素一致，不会看到「换了一次底」；动画结束（`completed`）后它不再常驻，
/// 不会与 builder 的底重复合成、也不多占一层。
///
/// 刻意不做两件事：
/// * **不靠 `opaque` 解决**：让旧路由不画（`maintainState`/`opaque`）会打断返回手势
///   与“预测式返回”的观感，而且要在每个路由上改，容易漏；
/// * **不缓存背景图 widget**：图片经 `Image.file` 异步解码，**同一个 widget 实例出现在
///   两棵树里**会踩 Flutter 的「同名 GlobalKey / 同实例复用」限制，而底在下面已经有一份
///   （`AppWidgetSync` 还依赖它）；转场那两百毫秒重建一次，代价远小于这个风险。
class _BackdropTransitionBuilder extends PageTransitionsBuilder {
  const _BackdropTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 内层照旧用**框架自己的默认** builder，观感与改前逐帧一致 ——
    // 不自己硬编码平台表：那样一旦框架调默认值（或某平台改用新转场）就会漂。
    // （`PageTransitionsTheme()` 的默认构造带的就是 `_defaultBuilders`。）
    final inner = const PageTransitionsTheme()
            .builders[defaultTargetPlatform] ??
        const ZoomPageTransitionsBuilder();
    final transitioned = inner.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
    return Stack(
      children: [
        // 转场期间才画；转入完成（value == 1）后置空
        Positioned.fill(
          child: ValueListenableBuilder<double>(
            valueListenable: animation,
            builder: (_, v, _) => v >= 1
                ? const SizedBox.shrink()
                : (ThemeController.instance.buildBackdrop() ??
                    const SizedBox.shrink()),
          ),
        ),
        // 转场包在底之上：否则淡入/缩放会把这份底一起缩进去
        Positioned.fill(child: transitioned),
      ],
    );
  }
}
