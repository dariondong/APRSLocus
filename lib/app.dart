import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme.dart';
import 'theme_store.dart';
import 'state.dart';
import 'home_page.dart';
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
  bool _lastDark = false;
  String _lastTheme = '';
  String _lastLocale = '';
  String _lastMaterial = '';
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
        loc != _lastLocale ||
        mat != _lastMaterial ||
        rt != _lastReloadTick ||
        tr != _lastThemeRevision) {
      _lastDark = dark;
      _lastTheme = tc;
      _lastLocale = loc;
      _lastMaterial = mat;
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
      theme: ThemeData.light(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: C.bg,
        canvasColor: C.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: C.blue,
          brightness: Brightness.light,
        ).copyWith(surface: C.bg),
        splashFactory: InkSparkle.splashFactory,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: C.bg,
        canvasColor: C.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: C.blue,
          brightness: Brightness.dark,
        ).copyWith(surface: C.bg),
        splashFactory: InkSparkle.splashFactory,
      ),
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
          return HomePage(state: _state);
        },
      ),
    );
  }
}
