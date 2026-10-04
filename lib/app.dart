import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme.dart';
import 'theme_store.dart';
import 'state.dart';
import 'home_page.dart';
import 'hr_alarm.dart';
import 'shell2.dart';
import 'splash_page.dart';
import 'oobe_page.dart';
import 'app_widget.dart';
import 'blacklist_page.dart';
import 'data_notice_page.dart';
import 'early_member.dart';
import 'honor_celebration.dart';
import 'l10n/app_localizations.dart';
import 'update_prompt.dart';

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

  /// 「有新版弹提醒」只调一次（启动后第一次进入主页时挂一个 post-frame）
  bool _updatePromptScheduled = false;

  /// 新荣誉庆祝：0=未开始 1=已排期/检测中 2=展示中
  int _honorCelebration = 0;

  /// 荣誉数据版本监听是否已挂（只挂一次）
  bool _honorListenerAttached = false;

  /// 用于取得 Navigator 之下的 context / overlay（庆祝层要插在它上面）
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

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
    _honorListenerAttached = false;
    memberListVersion.removeListener(_onHonorsMaybeChanged);
    _state.removeListener(_onThemeChange);
    _state.dispose();
    super.dispose();
  }

  /// 进入主页后：启动新荣誉检测。设置检测呼号、挂一次数据版本监听，
  /// 并在下一帧检查是否已经有待弹项（本地缓存/在线数据可能已经就绪）。
  void _maybeScheduleHonorCelebration() {
    if (_honorCelebration != 0) return;
    _honorCelebration = 1;
    if (!_honorListenerAttached) {
      _honorListenerAttached = true;
      memberListVersion.addListener(_onHonorsMaybeChanged);
    }
    final call = _state.myFullCall;
    unawaited(setHonorCelebrationCall(call));
    WidgetsBinding.instance.addPostFrameCallback((_) => _onHonorsMaybeChanged());
  }

  /// 荣誉数据更新 → 若有待弹项则展示庆祝动画（每枚一次，关闭后再看下一枚）
  void _onHonorsMaybeChanged() {
    if (!mounted || _honorCelebration == 2) return;
    final honor = peekPendingHonorCelebrations();
    if (honor == null) return;
    _showHonorCelebration(honor);
  }

  void _showHonorCelebration(Honor honor) {
    final overlay = _navKey.currentState?.overlay;
    if (overlay == null) {
      // Navigator 还没就绪（极早时机）：下一帧再试一次；仍不行就放弃本轮
      // （不标记已见，下次启动会重算并再试，宁可重复也不要丢）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final o2 = _navKey.currentState?.overlay;
        if (o2 == null) return;
        _insertCelebration(o2, honor);
      });
      return;
    }
    _insertCelebration(overlay, honor);
  }

  void _insertCelebration(OverlayState overlay, Honor honor) {
    if (_honorCelebration == 2) return;
    _honorCelebration = 2;
    var removed = false;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => HonorCelebrationPage(
        honor: honor,
        // 用 Navigator 之下的 context 取语言（本类 context 在 MaterialApp 之上，
        // Localizations.maybeLocaleOf 取不到当前语言）
        lang: honorLangOf(_navKey.currentContext ?? context),
        onDone: () {
          if (removed) return; // 背景与按钮都可能触发，去重
          removed = true;
          entry.remove();
          // 消费掉这一枚（队首），并把「当前拥有」的全部记为「已见」，避免重复弹
          consumeCurrentHonorCelebration();
          unawaited(markHonorsSeen(memberHonorKeys(_state.myFullCall)));
          // 若还有排队的新徽章，依次补弹 —— 不能只弹「最靠前那一枚」就把
          // 其余几枚吞掉（一次新增多枚时用户会少看几个）。
          _honorCelebration = 1;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _onHonorsMaybeChanged());
        },
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: ValueKey('app_${_state.reloadTick}'),
      navigatorKey: _navKey,
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
        builder: (context, _) {
          if (!_state.initialized) return const SplashPage();
          // 首次启动：进入设置向导
          if (!_state.oobeDone) return OobePage(state: _state);
      // 远程限制名单命中 → 整页拦下（用户协议 8.2：违反协议的，我们有权限制使用）。
      // 放在首次引导之前/之后都一样：引导页也不该给被限制的人继续用。
      final bl = _state.blacklistHit;
      if (bl != null) return BlacklistPage(hit: bl, state: _state);
      // 连接服务器前必须签署「数据与网络使用告知」（用户协议 2.4/2.5）：
      // 闸门在 AppState.toggleConnect 里，这里只负责在被请求时把页面显示出来。
      if (_state.pendingDataNotice) return DataNoticePage(state: _state);
          // 启动后检查一次新版本：有则弹提醒（同一版本只提醒一次）。
          // 放在 home 的 builder 里是为了拿到 **Navigator 之下**的 context
          // （showDialog 需要它）。
          if (!_updatePromptScheduled) {
            _updatePromptScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) maybePromptUpdate(context: context, state: _state);
            });
          }
          // 新荣誉庆祝：进入主页后初始化检测（用当前呼号做一次基线），
          // 并监听荣誉数据版本 —— 本地缓存/在线 members.json 到达时会再触发对比。
          // 命中新授予就弹庆祝动画；用户确认前后都只弹一次。
          _maybeScheduleHonorCelebration();
          // 两套外壳二选一（设置 → 显示 → 界面布局）。判断读 C 上的全局值
          // 而不是 _state.uiLayout：C.layout 与调色板同一时刻写入，不会出现
          // 「颜色已换、外壳还是旧的」这种半截状态。
          // 外面套一层心率异常告警（issue #21-8）：告警可能在用户停留在任何页面、
          // 任何一套外壳下发生，挂在 home 这一层才保证「无论在哪儿都弹得出来」。
          return HrAlarmWatcher(
            state: _state,
            child: C.sheetLayout
                ? HomeShell2(state: _state)
                : HomePage(state: _state),
          );
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
/// 反方向（**退出**子页）同理 —— 但那一侧多一个「值仍然是 1」的第一帧坑，
/// 所以这份底是按 **status** 画的，见 [_TransitionBackdrop]。
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
    // 形参必须是**非空**的：基类（`PageTransitionsBuilder`）与
    // `PageTransitionsTheme.buildTransitions` 都声明非空，写成 `PageRoute<T>?`
    // 虽然能当覆盖，但往下调 `inner.buildTransitions` 时类型对不上。
    PageRoute<T> route,
    BuildContext context,
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
    // ⚠ 这份「底」必须包在**页面自己的子树里**，再交给平台转场去做动画。
    //
    // 上一版是把它当成转场 Stack 的一层、压在页面**外面**（不参与动画）——
    // 结果整段退出动画期间它都把底下的页面（地图）盖着，用户看到的就是
    // 「什么都不动，一片纯色，然后页面消失」（issue #16 的追加反馈）。
    //
    // 放进子树之后：它跟着页面一起缩放/淡出，退出时底下的页面是被**逐渐
    // 露出**的 —— 这才是正常的返回观感；而它压在页面之下，仍然挡住了「页面
    // 底色透明、旧路由照常绘制」造成的穿透（当初加它的原因）。
    final backed = _TransitionBackdrop(animation: animation, child: child);
    final transitioned = inner.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      backed,
    );
    return transitioned;
  }
}

/// 转场期间那份「底」，只在**转场进行中**画。
///
/// ── 为什么判据必须是 status，不能是 `value == 1` ──
///
/// 这里原来写的是 `ValueListenableBuilder` + `v >= 1 ? 不画 : 画`。推入子页时它是对的
/// （推入的第一帧值就是 0），**弹出时正好反了**：`AnimationController.reverse()` 只把
/// status 置为 reverse，**值要等下一个 tick 才动**，而 ticker 的**首次回调 elapsed 恒为 0**
/// —— 于是弹出后的第一帧里：
///
///   * 框架已经按 `overlayEntries.first.opaque = false`（见上面类注释里 routes.dart 那段）
///     把**底下那一页**画了一遍；
///   * 这份「底」却又被 `v >= 1` 判成「不用画」；
///   * 而正在退出的页面底色是**透明**的（`C.pageFill`：有底时透明）。
///
/// 三者叠加 = 底下那一页**整整透出一帧**。2.0 布局下底下就是地图，而公告横幅正好浮在
/// 地图上、位置又与设置子页自己那条横幅同高 —— 用户看到的就是「公告横幅怎么显示在
/// 设置子页？页面退出动画会闪一下」。
///
/// 改成按 status 判断之后，`reverse()` 是在**帧之前**同步触发的（状态监听器里
/// setState），所以弹出的第一帧就已经带着这份底，不再有那一帧空洞。
///
/// ⚠ 也因此必须挂 [Animation<double>.addStatusListener]，**不能**用
/// `ValueListenableBuilder` / `AnimatedBuilder` 顶上：`reverse()` 不通知值监听器
/// （值要下一帧才变），而弹出时**恰恰只有在值还没变的那一帧**需要把底画上。
class _TransitionBackdrop extends StatefulWidget {
  final Animation<double> animation;

  /// 转场中的页面。底画在它**之下、同一个子树里** —— 跟着它一起缩放/淡出，
  /// 退出时底下的页面才会被逐渐露出（见 [buildTransitions] 里的说明）。
  final Widget child;

  const _TransitionBackdrop({required this.animation, required this.child});

  @override
  State<_TransitionBackdrop> createState() => _TransitionBackdropState();
}

class _TransitionBackdropState extends State<_TransitionBackdrop> {
  /// 当前是否该画这份底（= 是否在转场中）
  bool _on = false;

  /// 转场是否进行中。
  ///
  /// 用**排除法**判断「没停稳」：`completed`（已就位）与 `dismissed`（还没进来）
  /// 之外一律算转场中 —— 不写「值是不是 1」，也不再列举 forward / reverse，
  /// 将来状态只可能更多（见 [AnimationStatus]）。
  bool get _moving {
    final s = widget.animation.status;
    return s != AnimationStatus.completed && s != AnimationStatus.dismissed;
  }

  @override
  void initState() {
    super.initState();
    _on = _moving;
    widget.animation.addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    super.dispose();
  }

  /// ⚠ 参数用不到（判据统一在 [_moving]，免得两处各写一份），所以名字写成 `_`：
  /// 留一个没人读的 `status` 会让人以为「是不是漏了用它」。
  void _onStatus(AnimationStatus _) {
    final on = _moving;
    if (on != _on) setState(() => _on = on);
  }

  @override
  Widget build(BuildContext context) {
    // 停稳之后**不画**：`builder` 那份底已经在位，再画一份就是白多一层
    // 合成（这是当初就定下的取舍）。
    if (!_on) return widget.child;
    // 与 `builder` 那份**同一个函数**：逐像素一致，看不出「换了一次底」
    final backdrop =
        ThemeController.instance.buildBackdrop() ?? const SizedBox.shrink();
    // ⚠ `StackFit.passthrough`：把外层约束原样传给页面，布局与不加这层时
    // 完全一致（`expand` 会强制拉满，对话框 / 底部弹层这类节点会被撑坏）。
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // 底在页面**之下**：页面底色透明的那几帧由它挡住旧路由的穿透
        Positioned.fill(child: backdrop),
        widget.child,
      ],
    );
  }
}
