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
import 'lite_shell.dart';
import 'shell2.dart';
import 'splash_page.dart';
import 'oobe_page.dart';
import 'app_widget.dart';
import 'blacklist_page.dart';
import 'min_version_page.dart';
import 'data_notice_page.dart';
import 'consent_page.dart';
import 'agent_notice_page.dart';
import 'agent_auth_page.dart';
import 'early_member.dart';
import 'honor_celebration.dart';
import 'l10n/app_localizations.dart';
import 'permission_check.dart';
import 'settings_pages.dart';
import 'update_prompt.dart';
import 'desktop_tray.dart';
import 'agent_ui.dart';

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
  bool _lastLite = false;
  int _lastReloadTick = 0;
  int _lastThemeRevision = 0;

  /// 「有新版弹提醒」只调一次（启动后第一次进入主页时挂一个 post-frame）
  bool _updatePromptScheduled = false;

  /// 权限体检只做一次（同上，启动后第一次进入主页时查一次）。
  ///
  /// 摆在首页这一层、而不是某一页里：权限是**全局**的，用户在哪个页面上都
  /// 可能需要那句话；而体检自己只在启动后跑一次，不会跟着页面切来切去。
  bool _permPromptScheduled = false;

  /// 新荣誉庆祝：0=未开始 1=已排期/检测中 2=展示中
  int _honorCelebration = 0;

  /// 荣誉数据版本监听是否已挂（只挂一次）
  bool _honorListenerAttached = false;

  /// 用于取得 Navigator 之下的 context / overlay（庆祝层要插在它上面）
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  /// 全局弹提示用的 messenger（见 [_maybePromptNoServer]）。
  ///
  /// 挂在 MaterialApp 上而不是各页的 Scaffold 上：连接入口有 7 处（首页、外壳、
  /// 面板、设置两处、首次引导…），提示只能有一个来源，否则「哪里弹得出来」取决于
  /// 用户当时停在哪一页。
  final GlobalKey<ScaffoldMessengerState> _msgKey =
      GlobalKey<ScaffoldMessengerState>();

  /// 上次弹过的「服务器地址没填」序号（见 [AppState.connectNoServerSeq]）。
  int _lastNoServerSeq = 0;

  /// 智能体聊天框的 Overlay 条目 —— 挂在根 Navigator 的 Overlay 里，
  /// 因此位于所有路由之上（切页不丢），且能拿到 Navigator / Overlay 祖先。
  OverlayEntry? _agentEntry;
  OverlayState? _agentOverlay;

  @override
  void initState() {
    super.initState();
    // 仅在深色/主题色/语言/重载变化时重建 MaterialApp（避免数据洪峰期间反复重建整个导航栈）
    _state.addListener(_onThemeChange);
    // 启动后应用保存的主题（深色/自定义色）——_loadPrefs 完成后还会再应用一次
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _state.applySavedTheme();
      _syncAgentOverlay();
      if (mounted) setState(() {});
    });
  }

  /// 把智能体聊天框挂进根 Overlay。
  ///
  /// 为什么是 OverlayEntry 而不是 `MaterialApp.builder` 里的一层 Stack：
  ///   * builder 在 Navigator **之上** → 聊天框里的 `Navigator.of(context)`
  ///     取不到当前 Navigator（设置按钮点了没反应）、Tooltip 找不到 Overlay
  ///     祖先而抛 "No Overlay widget found" → 布局崩出黄黑条纹（「下划线」）；
  ///   * 放在 Overlay 里则同时拿到 Navigator 与 Overlay，且位于所有路由之上
  ///     —— 从首页 push 出设置子页时聊天框依旧在、不会消失。
  ///
  /// 幂等：Navigator 未就绪或 Overlay 未变时什么都不做；`reloadTick` 会让
  /// MaterialApp 换 key、连同 Navigator 一起重建，这时需要往新 Overlay 里重挂。
  void _syncAgentOverlay() {
    final overlay = _navKey.currentState?.overlay;
    if (overlay == null) return; // Navigator 还没就绪，等下一次调用
    if (identical(overlay, _agentOverlay) && _agentEntry != null) return;
    // 旧 Overlay 已被重建/销毁：它自己会连同条目一起回收，这里只丢引用。
    _agentEntry = null;
    _agentOverlay = overlay;
    final entry = OverlayEntry(
      // 必须 Positioned.fill：聊天框根节点是 Stack，靠满屏约束才能把面板
      // 定位到右下角；否则在 Overlay 的 Stack 里被挤成零尺寸。
      builder: (_) => Positioned.fill(child: AgentOverlay(state: _state)),
    );
    overlay.insert(entry);
    _agentEntry = entry;
  }

  void _onThemeChange() {
    final dark = _state.darkMode;
    final tc = _state.themeColor;
    final loc = _state.locale;
    final mat = _state.uiMaterial;
    // 布局（1.0 / 2.0）也要看：它换的是**整个外壳**（HomePage ↔ HomeShell2），
    // 不重建就会出现「设置里点了 2.0、界面还是 1.0」。与材质同理不进 `key`。
    final lay = _state.uiLayout;
    // 精简模式换的是**整个外壳**（HomeShell2 / HomePage ↔ LiteShell），不进 key。
    final lite = _state.liteMode;
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
        lite != _lastLite ||
        loc != _lastLocale ||
        mat != _lastMaterial ||
        rt != _lastReloadTick ||
        tr != _lastThemeRevision) {
      _lastDark = dark;
      _lastTheme = tc;
      _lastLocale = loc;
      _lastMaterial = mat;
      _lastLayout = lay;
      _lastLite = lite;
      _lastReloadTick = rt;
      _lastThemeRevision = tr;
      if (mounted) setState(() {});
      // MaterialApp 换了 key（reloadTick）时 Navigator 会连同 Overlay 一起重建，
      // 聊天框要挂回新 Overlay 上；没换 key 时这次调用是幂等的。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncAgentOverlay();
      });
    }
  }

  @override
  void dispose() {
    _honorListenerAttached = false;
    memberListVersion.removeListener(_onHonorsMaybeChanged);
    _state.removeListener(_onThemeChange);
    _agentEntry?.remove();
    _agentEntry = null;
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

  /// 连接被「服务器地址没填」拦下 → 弹一句原因 + 一个直达连接设置的入口。
  ///
  /// 用序号而不是布尔量：连续点几次「连接」要能各弹一次（第一次的提示可能已经
  /// 飘走了），布尔量第二次点就变成「值没变、不弹」。
  ///
  /// 文案复用未连接横幅那句 `linkNoServer`（「还没填服务器地址 · 点一下去设置里填」）：
  /// 同一件事在界面上的两种说法必须是同一句，否则用户会以为它们说的不是一回事。
  void _maybePromptNoServer() {
    final seq = _state.connectNoServerSeq;
    if (seq == _lastNoServerSeq) return;
    _lastNoServerSeq = seq;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = _msgKey.currentState;
      // 语言取自 Navigator 之下的 context（本类的 context 在 MaterialApp 之上，
      // 取不到当前语言 —— 见 _insertCelebration 的同一条注释）。
      final ctx = _navKey.currentContext;
      if (messenger == null || ctx == null) return;
      final l = AppLocalizations.of(ctx);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(l.linkNoServer),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: l.goSettings,
          onPressed: _openConnSettings,
        ),
      ));
    });
  }

  /// 权限体检：用户可能在系统设置里把权限关掉，而关掉之后**应用里什么都看不出来**，
  /// 只会在用到的那一刻失败（定位那条最坏：前台服务起不来，进程被系统带走）。
  /// 所以启动后查一次，缺哪一项就说哪一项，并给一个直达系统设置的入口。
  ///
  /// 只做一次、只对**核心功能**的两项（定位 / 通知，见 [PermissionCheck.watched]），
  /// 而且只说「以前到手过、现在没了」的那几项（见 [PermissionCheck.revoked]）——
  /// 第一次就拒绝是用户的选择，每次冷启都拿它拦人一道只会让人烦。
  /// 一项不缺时全程静默。
  void _maybePromptPermissions(BuildContext context) {
    if (_permPromptScheduled) return;
    _permPromptScheduled = true;
    // 语言要在 build 期间取好：下面已经跨了一次 await，不能再用那个 context 取
    final l = AppLocalizations.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // 稍等一下再查：启动瞬间还压在闪屏 / 首次引导上，这时候弹出来
      // 用户正在看的页面会被换掉（与「有新版弹提醒」同一考虑）。
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      final missing = await PermissionCheck.revoked();
      if (missing.isEmpty || !mounted) return;
      // 弹窗的 context 用根 Navigator 自己的：下面已经跨了好几次 await，
      // 首页那个 builder 的 context 可能已经不在了（换外壳 / 换主题会重建）。
      // `Navigator.of` 对「传进来的就是 Navigator 自己的 element」有专门处理，
      // 所以拿它去 showDialog 能找到正确的 Navigator。
      final nav = _navKey.currentState;
      if (nav == null) return;
      final lines = <String>[
        if (missing.contains('location')) l.permCheckLocation,
        if (missing.contains('notifications')) l.permCheckNotify,
      ];
      final go = await showDialog<bool>(
        context: nav.context,
        builder: (dctx) => AlertDialog(
          backgroundColor: C.white,
          title: Text(l.permCheckTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == lines.length - 1 ? 0 : 10,
                  ),
                  child: Text(lines[i], style: ts(13, h: 1.5)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: Text(l.gotIt),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.blue),
              onPressed: () => Navigator.pop(dctx, true),
              child: Text(l.goSettings),
            ),
          ],
        ),
      );
      if (go == true) {
        // 「去设置」：用户可能真的去把它打开，也可能只是想先看看 —— 所以
        // 名单不动，下次启动查到还缺就再提一次（真打开了自然就不再提）。
        await PermissionCheck.openSettings();
      } else if (go == false) {
        // 「知道了」：这次不说了。把这两项从名单里划掉（见 stopReminding）——
        // 哪天它们重新到手又被关掉，还是会提。
        await PermissionCheck.stopReminding(missing);
      }
    });
  }

  /// 打开「连接设置」页（提示里那个「去设置」的动作）。
  void _openConnSettings() {
    final nav = _navKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) => ConnectionSettingsPage(state: _state),
    ));
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
      scaffoldMessengerKey: _msgKey,
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
        // 系统托盘（桌面三平台）搭在这一层：builder 位于 Localizations 之下，
        // 托盘菜单的语言才能跟着界面走。手机 / Web 上它只是一层直通。
        content = DesktopTrayHost(state: _state, child: content);
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
          //
          // ⚠ 智能体聊天框不在这里。它在 Navigator 的 Overlay 里（见
          // `_syncAgentOverlay`）：builder 位于 Navigator **之上**，而聊天框
          // 用到 `Navigator.of(context)`（打开设置页）与 Tooltip（需要 Overlay
          // 祖先）—— 挂在这里会取到上层 Navigator / 找不到 Overlay，Tooltip 抛
          // "No Overlay widget found"，布局连带崩出黄黑条纹（用户看到的
          // 「下划线」），设置按钮点了也毫无反应。放进根 Overlay 就同时拿到
          // 当前 Navigator 与 Overlay，且居所有路由之上、切页不丢。
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
      // 低于官网要求的最低版本 → 整页拦下：只能去更新页，别处没有出口
      // （返回键直接退出应用，见 MinVersionPage）。
      if (_state.versionBlocked) return MinVersionPage(state: _state);
      // 连接服务器前必须签署「数据与网络使用告知」（用户协议 2.4/2.5）：
      // 闸门在 AppState.toggleConnect 里，这里只负责在被请求时把页面显示出来。
      if (_state.pendingDataNotice) return DataNoticePage(state: _state);
      // 上传/发射前的单独同意（用户协议 V2.0 附件一）：与上面那份告知相互独立。
      // 闸门在 AppState.ensureConsent 里（开关、开始上报、网关入口都走它），
      // 这里只负责在被请求时把同意书显示出来。
      if (_state.pendingConsent.isNotEmpty) {
        return ConsentPage(state: _state);
      }
      // 启用智能体前必须签署「智能体使用告知」（与上面那份相互独立）：
      // 闸门在 AppState.setAgentEnabled 里，这里只负责在被请求时把页面显示出来。
      if (_state.pendingAgentNotice) return AgentNoticePage(state: _state);
      // 智能体不对普通用户开放：签完告知还不够，本机呼号要**在官网授权名单里**。
      // 未授权时弹授权/申请页（承诺书邮寄到 AgentAllow.kApplyEmail）。
      if (_state.pendingAgentAuth) return AgentAuthPage(state: _state);
      // 「服务器地址没填」：点连接被拦下（见 AppState.connectBlockedNoServer）时
      // 弹一句说明 + 一键去设置（用户要求：同 Passcode 填 -1 的验证提示一样）。
      _maybePromptNoServer();
          // 启动时体检一次权限（缺哪项就提示哪项，见 [_maybePromptPermissions]）。
      _maybePromptPermissions(context);
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
            child: C.liteMode
                ? LiteShell(state: _state)
                : (C.sheetLayout
                    ? HomeShell2(state: _state)
                    : HomePage(state: _state)),
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
