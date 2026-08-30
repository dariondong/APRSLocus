import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme.dart';
import 'state.dart';
import 'home_page.dart';
import 'splash_page.dart';
import 'oobe_page.dart';
import 'l10n/app_localizations.dart';

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
  int _lastReloadTick = 0;

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
    final rt = _state.reloadTick;
    if (dark != _lastDark ||
        tc != _lastTheme ||
        loc != _lastLocale ||
        rt != _lastReloadTick) {
      _lastDark = dark;
      _lastTheme = tc;
      _lastLocale = loc;
      _lastReloadTick = rt;
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
          : Locale(_state.locale),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final scale = _state.uiScale;
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
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
