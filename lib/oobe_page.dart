import 'dart:async';
import 'terms_version.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show Clipboard, SystemNavigator;
import 'package:url_launcher/url_launcher.dart';

import 'backup.dart';
import 'backup_io.dart' if (dart.library.html) 'backup_io_web.dart' as backup_io;
import 'theme.dart';
import 'state.dart';
import 'models.dart';
import 'features.dart';
import 'widgets.dart';
import 'terms_page.dart';
import 'settings_widgets.dart';

/// 首次启动引导（OOBE）：语言 → 用户协议确认 → 欢迎 → 呼号 → 符号 → 筛选 → 服务器
class OobePage extends StatefulWidget {
  final AppState state;
  const OobePage({super.key, required this.state});
  @override
  State<OobePage> createState() => _OobePageState();
}

class _OobePageState extends State<OobePage> {
  /// 向导一共几步：语言 → 协议 → 欢迎 → 呼号 → 符号 → 筛选 → 功能 → 服务器
  /// → 完成。进度条、页码、最后一步的判定都读它，加一步只改这一处（以及下面
  /// `_next()` 的 case 与 PageView 里那串顺序）。
  static const int _total = 9;

  int _step = 0;
  // 页面切换动画进行中标记：防止快速连点导致 PageView 与 _step 失步（偶发卡死）
  bool _busy = false;
  final PageController _pc = PageController();
  late final TextEditingController _call;
  late final TextEditingController _server;
  late final TextEditingController _port;
  late final TextEditingController _pass;
  String _symbol = '>';
  // 第 7 步选的是哪条互联网链路：APRS-IS 还是 APRSNETCN SERVER。
  // 两条是等价的（都是一条 TCP 登录），所以这里是一个并列的二选一，
  // 不是「主链路 + 备用」。
  String _link = AppState.srcAprsIs;
  /// 呼号后缀（不含前导 -）。空串 = 不加后缀；数字或字母都行，
  /// 形状由 `AppState.normalizeSsid` 判定。
  String _ssid = '';
  // 界面语言：'' = 跟随系统；'zh' 中文；'en' English
  String _lang = '';
  // 接收筛选：**不再默认勾选任何国家/地区**。
  // 不勾选 = 不做限制、接收全部台站 —— 对非中国用户更合理（原先默认 ['CN']
  // 会让海外用户开箱只见中国台站）。
  List<String> _filterCountries = [];
  bool _receiveOthers = false;
  // 用户协议：已阅读并同意
  bool _agreed = false;

  static const _syms = [
    ('>', '汽车', Icons.directions_car_rounded),
    ('-', '房屋', Icons.home_rounded),
    ('[', '人', Icons.man_rounded),
    ('k', '卡车', Icons.local_shipping_rounded),
    ('b', '自行车', Icons.directions_bike_rounded),
    ('R', '房车', Icons.airport_shuttle_rounded),
    ('W', '气象站', Icons.cloud_rounded),
    ('!', '警局', Icons.local_police_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final st = widget.state;
    // 连接参数在**首次运行**时一律留空：软件不预置、也不推荐任何服务器地址
    // （用户协议 2.4），端口/Passcode 也交由用户显式决定，仅以 hint 提示常值。
    // 预填 `rotate.aprs2.net` / `14580` / `-1` 会诱导用户「直接下一步」，等于
    // 软件替他选了连到哪里。重新运行向导（oobeDone）时才回填已保存值，
    // 否则会把用户现有配置清掉（向导承诺「当前设置不会丢」）。
    final rerun = st.oobeDone;
    _call = TextEditingController(text: st.myCall);
    _server = TextEditingController(text: rerun ? st.aprs.server : '');
    _port = TextEditingController(text: rerun ? '${st.aprs.port}' : '');
    _pass = TextEditingController(text: rerun ? st.aprs.passcode : '');
    _symbol = st.mySymbol;
    _ssid = st.mySsid;
    _lang = st.locale;
  }

  @override
  void dispose() {
    _pc.dispose();
    _call.dispose();
    _server.dispose();
    _port.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _next() {
    if (_busy) return; // 动画期间防重复点击，避免 PageView 与 _step 失步
    switch (_step) {
      case 0:
        // 语言选择步骤：立即应用界面语言
        widget.state.setLocale(_lang);
        break;
      case 1:
        // 用户协议确认步骤：必须勾选同意才能继续
        if (!_agreed) {
          _toast(S.of(context).oobeAgreeNeed);
          return;
        }
        break;
      case 2:
        // 欢迎页：无校验
        break;
      case 3:
        // 呼号步骤：不能只判「非空」。形状不对的呼号在 APRS-IS 上发不出去，
        // 用户却以为配好了，所以这里按 state 的同一套规则校验。
        // 顺手写在呼号里的 -SSID（BG7LZQ-9）拆出来交给后缀 ——
        // 一个输入框写完是最自然的输入方式，不该要求他分成两步填。
        final raw = _call.text.trim().toUpperCase();
        if (raw.isEmpty) {
          _toast(S.of(context).enterCallsign);
          return;
        }
        final dash = raw.indexOf('-');
        final base = (dash < 0 ? raw : raw.substring(0, dash)).trim();
        final typedSsid = dash < 0 ? '' : raw.substring(dash + 1).trim();
        if (!AppState.isValidCallsign(base)) {
          _toast(S.of(context).oobeCallInvalid);
          return;
        }
        if (typedSsid.isNotEmpty) {
          final v = AppState.normalizeSsid(typedSsid);
          if (v == null) {
            _toast(S.of(context).oobeSsidInvalid);
            return;
          }
          _ssid = v;
        }
        _call.text = base;
        widget.state.myCall = base;
        widget.state.setSsid(_ssid);
        widget.state.persist();
        break;
      case 4:
        // 符号步骤
        widget.state.mySymbol = _symbol;
        widget.state.persist();
        break;
      case 5:
        // 接收筛选步骤：把选择的国家写入 state（默认不勾选 = 不做限制）
        _applyFilterCountries();
        break;
      case 6:
        // 功能步骤：模块开关是**边点边落盘**的（setFeature 自己 persist）。
        // 只有历史轨迹要再补一步 —— 它自己那道「记录」开关默认是关的
        // （2.1.30），于是在设置里看着模块开着、却什么都不记。用户在向导里
        // 留着它就是要它记，所以这里跟着开关一次；反过来关掉模块就停记，
        // 否则入口没了、后台还在写。
        final tracksOn =
            !widget.state.featuresOff.contains(AppFeature.tracks.id);
        widget.state.setTrackLogOn(tracksOn);
        break;
      case 7:
        // 服务器步骤：先把填的地址写进 state，下一步的「配置完成」要回读它。
        _saveServer();
        break;
    }
    if (_step >= _total - 1) {
      _finish();
      return;
    }
    // 先更新 _step 再动画到显式目标页：动画中重复点击也不会再触发逻辑
    final target = _step + 1;
    setState(() => _step = target);
    _goTo(target);
  }

  /// 页面切换：以 _step 为唯一事实来源，动画到显式目标页。
  /// 双保险：① animateToPage 抛异常则退化为瞬时跳转；② 兜底定时器确保
  /// _busy 不会因 Future 异常/不完成而永远卡住（否则界面会“卡死”）。
  void _goTo(int target) {
    _busy = true;
    try {
      _pc
          .animateToPage(
            target,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _busy = false);
    } catch (_) {
      try {
        _pc.jumpToPage(target);
      } catch (_) {}
      _busy = false;
    }
    Timer(const Duration(milliseconds: 500), () => _busy = false);
  }

  void _back() {
    if (_busy || _step == 0) return;
    final target = _step - 1;
    setState(() => _step = target);
    _goTo(target);
  }

  /// 换一条互联网链路：三个输入框跟着换成那条链路已保存的值。
  ///
  /// 首次运行时地址一律是空的 —— 软件不预置、也不推荐连到哪台服务器（用户
  /// 协议 2.4），两条链路都一样。重跑向导时才回填用户自己存过的值。
  void _pickLink(String link) {
    setState(() => _link = link);
    final st = widget.state;
    final isAcn = link == AppState.srcAcn;
    _server.text = st.oobeDone
        ? (isAcn ? st.acnServer : st.aprs.server)
        : '';
    _port.text = st.oobeDone
        ? '${isAcn ? st.acnPort : st.aprs.port}'
        : '';
    _pass.text = st.oobeDone
        ? (isAcn ? st.acnPasscode : st.aprs.passcode)
        : '';
  }

  /// 把服务器那一步填的内容写进 state。
  ///
  /// 服务器**留空就是不连接**：本软件不预置、也不推荐任何服务器地址（用户协议
  /// 2.4）。以前这里会把空值悄悄填成公共服务器并立刻连接 —— 那是"软件自己决定
  /// 连到哪里"，与"默认不连接任何服务器"的声明冲突。
  void _saveServer() {
    final st = widget.state;
    final acnLink = _link == AppState.srcAcn;
    final server = _server.text.trim();
    final port = int.tryParse(_port.text.trim()) ?? 14580;
    final pass = _pass.text.trim().isEmpty
        ? (acnLink ? '' : '-1')
        : _pass.text.trim();
    if (acnLink) {
      // APRSNETCN 的 passcode 留空就沿用 APRS-IS 那条链路的（与设置页同一口径）
      st.acnServer = server;
      st.acnPort = port;
      st.acnPasscode = pass;
    } else {
      st.aprs.server = server;
      st.aprs.port = port;
      st.aprs.passcode = pass;
    }
    st.persist();
  }

  Future<void> _finish() async {
    final st = widget.state;
    final acnLink = _link == AppState.srcAcn;
    final server = _server.text.trim();
    // 先进主页，连接放到后台进行（主页底部横幅显示连接状态）
    st.completeOobe();
    // 只有用户**自己填了**服务器才连接；留空则保持纯本地（不碰任何网络服务器）。
    if (server.isEmpty) return;
    if (acnLink) {
      // 选了 APRSNETCN 就意味着这条是互联网链路：先把没填地址的 APRS-IS 关掉，
      // 否则「连接」会被「没配服务器」那一拦挡下来（[connectBlockedNoServer]）。
      await st.toggleSource(AppState.srcAcn, true);
      await st.toggleSource(AppState.srcAprsIs, false);
    }
    st.toggleConnect();
  }

  // ─── 从备份恢复（欢迎页） ───

  String _restoreErrText(S s, BackupErrorCode code) {
    switch (code) {
      case BackupErrorCode.notJson:
        return s.backupErrNotJson;
      case BackupErrorCode.notBackup:
        return s.backupErrNotBackup;
      case BackupErrorCode.schemaNewer:
        return s.backupErrSchemaNewer;
      case BackupErrorCode.empty:
        return s.backupErrEmpty;
    }
  }

  /// 不能选文件时（Web 版）从剪贴板取备份文本。
  Future<String?> _backupFromClipboard(S s) async {
    Object? text;
    try {
      final d = await Clipboard.getData('text/plain');
      text = d?.text;
    } catch (_) {}
    if (!mounted) return null;
    final t = (text ?? '').toString();
    if (t.trim().isEmpty) {
      _toast(s.backupPasteEmpty);
      return null;
    }
    return t;
  }

  /// 选一份备份并读回文本；取消或出错时提示并返回 null。
  Future<String?> _pickBackupText(S s) async {
    backup_io.BackupPickResult r;
    try {
      r = await backup_io.pickBackupFile();
    } catch (_) {
      r = const backup_io.BackupPickResult.fail(
        backup_io.BackupPickError.readFailed,
      );
    }
    if (!mounted) return null;
    final t = r.file?.content;
    if (t != null) return t;
    switch (r.error) {
      case backup_io.BackupPickError.cancelled:
        return null; // 用户自己取消，不提示
      case backup_io.BackupPickError.tooLarge:
        _toast(s.backupErrTooLarge);
        return null;
      case backup_io.BackupPickError.unsupported:
        // 选不了文件就走剪贴板，与备份页给的出路一致
        return _backupFromClipboard(s);
      default:
        _toast(s.backupErrRead);
        return null;
    }
  }

  /// 整份导入一份备份，再按备份里的「引导已完成」决定下一步。
  ///
  /// 入口只放在欢迎页：重装或换机的人最先到这里，让他走完七步再进设置恢复，
  /// 等于把呼号、符号、服务器又手填一遍，备份就白做了。备份的设置分组里带着
  /// `oobeDone`（见 lib/backup.dart），恢复成功后 App 层（app.dart）会按它
  /// 直接切到主界面，这一页随即被替换掉。
  Future<void> _restoreFromBackup() async {
    if (_busy) return;
    final s = S.of(context);
    setState(() => _busy = true);
    final content = await _pickBackupText(s);
    if (!mounted) return;
    setState(() => _busy = false);
    if (content == null) return; // 取消或出错，提示已经在里面发过了
    BackupData data;
    try {
      data = parseBackupJson(content);
    } on BackupException catch (e) {
      _toast(_restoreErrText(s, e.code));
      return;
    } catch (_) {
      _toast(s.backupErrRead);
      return;
    }
    final cats = data.categories.toSet();
    if (cats.isEmpty) {
      _toast(s.backupErrEmpty);
      return;
    }
    setState(() => _busy = true);
    BackupApplyResult? res;
    var days = 0;
    try {
      res = await applyBackup(data, cats);
      // 历史轨迹拼在设置分组里（见 lib/backup.dart），按天合并，不动本地其它天。
      if (cats.contains(BackupCategory.settings) && data.trackDays.isNotEmpty) {
        try {
          days = await backup_io.applyTrackDays(data.trackDays);
        } catch (_) {}
      }
      if (res.applied > 0 || days > 0) await widget.state.reloadFromPrefs();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
    if (res == null) {
      _toast(s.backupErrRead);
      return;
    }
    // 备份说引导已经走完：主界面已经接上，这一页正在被替换，不必再刷表单。
    if (widget.state.oobeDone) return;
    _adoptRestored();
    _toast(s.backupImported(res.applied));
  }

  /// 把恢复出来的值搬回本页表单：备份没带「引导已完成」时用户接着往下走，
  /// 看到的是备份里的呼号/符号/筛选/服务器，而不是一片空白。
  void _adoptRestored() {
    final st = widget.state;
    final acn = st.acnOn;
    setState(() {
      _call.text = st.myCall;
      _ssid = st.mySsid;
      _symbol = st.mySymbol;
      _lang = st.locale;
      _link = acn ? AppState.srcAcn : AppState.srcAprsIs;
      _filterCountries = List<String>.from(st.receiveCountries);
      _receiveOthers = st.receiveOthers;
      // 服务器三格直接读恢复出来的值：这里不能用 _pickLink，它按「是否重跑
      // 向导」决定填不填，会把刚恢复的地址又清成空。
      _server.text = acn ? st.acnServer : st.aprs.server;
      _port.text = '${acn ? st.acnPort : st.aprs.port}';
      _pass.text = acn ? st.acnPasscode : st.aprs.passcode;
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _step >= _total - 1;
    return Scaffold(
      backgroundColor: C.pageFill,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部：Logo + 步骤指示
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              child: Row(
                children: [
                  AppLogo(size: 36),
                  SizedBox(width: 10),
                  Text(
                    S.of(context).wizard,
                    style: ts(16, w: FontWeight.w800, ls: -0.3),
                  ),
                  Spacer(),
                  Text('${_step + 1} / $_total', style: ts(12, c: C.grey)),
                ],
              ),
            ),
            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  for (var i = 0; i < _total; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _step ? C.blue : C.greyLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < _total - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            SizedBox(height: 6),
            // 页面
            Expanded(
              child: PageView(
                controller: _pc,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _languagePick(),
                  _agreement(),
                  _welcome(),
                  _callsign(),
                  _symbolPick(),
                  _filterPick(),
                  _featuresPage(),
                  _serverPage(),
                  _done(),
                ],
              ),
            ),
            // 底部操作
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton.icon(
                      onPressed: _back,
                      icon: Icon(Icons.arrow_back_rounded, size: 16),
                      label: Text(S.of(context).previous),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.slate,
                        side: BorderSide(color: C.borderStrong),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        textStyle: ts(13, w: FontWeight.w600),
                      ),
                    )
                  else
                    SizedBox(width: 96),
                  Spacer(),
                  // 最后一步的按钮文案跟着地址走：没填地址时只是「完成」，
                  // 因为留空就是不连接（软件不预置服务器）。写成「完成并连接」
                  // 会让人以为点完会去哪台服务器。
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _server,
                    builder: (_, v, __) {
                      final filled = v.text.trim().isNotEmpty;
                      return FilledButton.icon(
                        onPressed: _next,
                        icon: Icon(
                          last
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          size: 16,
                        ),
                        label: Text(
                          last
                              ? (filled
                                    ? S.of(context).finish
                                    : S.of(context).oobeFinishLocal)
                              : S.of(context).next,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: C.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                          textStyle: ts(13, w: FontWeight.w700),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 第 1 步：选择语言 ───
  Widget _languagePick() {
    final options = <(String, String)>[
      ('', S.of(context).languageSystem),
      ('zh', S.of(context).languageZh),
      ('zh_TW', S.of(context).languageZhTw),
      ('en', S.of(context).languageEn),
      ('ja', S.of(context).languageJa),
      ('id', S.of(context).languageId),
      ('es', S.of(context).languageEs),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          SizedBox(height: 16),
          Icon(Icons.language_rounded, color: C.blue, size: 52),
          SizedBox(height: 16),
          Text(
            S.of(context).language,
            style: ts(20, w: FontWeight.w800, ls: -0.4),
          ),
          SizedBox(height: 8),
          Text(
            'Select your language',
            textAlign: TextAlign.center,
            style: ts(12, c: C.slate),
          ),
          SizedBox(height: 24),
          ...options.map((opt) {
            final on = _lang == opt.$1;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _lang = opt.$1;
                  widget.state.setLocale(opt.$1);
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: on ? C.blueBg : C.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: on ? C.blue : C.border,
                    width: on ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.language_rounded,
                      size: 18,
                      color: on ? C.blue : C.greyLight,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        opt.$2,
                        style: ts(
                          15,
                          w: on ? FontWeight.w700 : FontWeight.w500,
                          c: on ? C.blue : C.ink,
                        ),
                      ),
                    ),
                    if (on)
                      Icon(Icons.check_circle_rounded, size: 20, color: C.blue),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 第 2 步：用户协议确认 ───
  Widget _agreement() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          SizedBox(height: 10),
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: C.blueBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.description_rounded, size: 36, color: C.blue),
          ),
          SizedBox(height: 18),
          Text(
            S.of(context).oobeAgreeTitle,
            style: ts(20, w: FontWeight.w800, ls: -0.4),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            S.of(context).oobeAgreeBody,
            style: ts(13, c: C.slate, h: 1.7),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 18),
          // 全文入口
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _agreeLink(
                  Icons.assignment_rounded,
                  S.of(context).userAgreement,
                  kTermsVersion,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsPage()),
                  ),
                ),
                _agreeLink(
                  Icons.gavel_rounded,
                  S.of(context).licenseText,
                  'GPL-3.0',
                  () => launchUrl(
                    Uri.parse(
                      'https://github.com/dariondong/APRSLocus/blob/main/LICENSE',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          // 同意复选框
          Container(
            decoration: BoxDecoration(
              color: C.greyBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _agreed = !_agreed),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      _agreed
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: _agreed ? C.blue : C.grey,
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        S.of(context).oobeAgreeCheck,
                        style: ts(12, c: _agreed ? C.ink : C.slate, h: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          // 不同意：退出应用
          TextButton(
            onPressed: _exitOobe,
            style: TextButton.styleFrom(foregroundColor: C.red),
            child: Text(
              S.of(context).oobeDeclineExit,
              style: ts(12, w: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _agreeLink(
    IconData icon,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: C.blue),
            SizedBox(width: 8),
            Text(label, style: ts(12, c: C.slate)),
            Spacer(),
            Text(value, style: ts(12, c: C.blue, w: FontWeight.w600)),
            SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: C.grey),
          ],
        ),
      ),
    );
  }

  /// 不同意协议：退出应用（移动端退回系统桌面；Web 提示无法退出）
  void _exitOobe() {
    if (kIsWeb) {
      _toast(S.of(context).oobeAgreeNeed);
      return;
    }
    try {
      SystemNavigator.pop();
    } catch (_) {
      // 桌面端无“退出”语义时忽略
    }
  }

  // ─── 第 3 步：欢迎 ───
  Widget _welcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          SizedBox(height: 12),
          AppLogo(size: 88),
          SizedBox(height: 22),
          Text(
            S.of(context).oobeWelcomeTitle,
            style: ts(26, w: FontWeight.w800, ls: -0.5),
          ),
          SizedBox(height: 10),
          Text(S.of(context).aboutSubtitle, style: ts(13, c: C.slate, ls: 1)),
          SizedBox(height: 28),
          _feature(
            Icons.map_rounded,
            S.of(context).oobeWelcomeRealMap,
            S.of(context).oobeMapFeatureDesc,
          ),
          SizedBox(height: 12),
          _feature(
            Icons.gps_fixed_rounded,
            S.of(context).oobeWelcomeGps,
            S.of(context).oobeGpsFeatureDesc,
          ),
          SizedBox(height: 12),
          _feature(
            Icons.chat_bubble_rounded,
            S.of(context).oobeWelcomeMsg,
            S.of(context).oobeMsgFeatureDesc,
          ),
          SizedBox(height: 12),
          _feature(
            Icons.wifi_rounded,
            S.of(context).oobeWelcomeIs,
            S.of(context).oobeIsFeatureDesc,
          ),
          SizedBox(height: 20),
          if (defaultTargetPlatform != TargetPlatform.windows) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.orangeBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_clock_rounded, color: C.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.of(context).oobeBackgroundTip,
                      style: ts(11, c: C.orange, w: FontWeight.w600, h: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],
          Text(S.of(context).oobeNextSteps, style: ts(11, c: C.grey, h: 1.5)),
          SizedBox(height: 4),
          // 恢复入口只放在欢迎页：重装或换机的人到这里就能整份搬回来。
          TextButton.icon(
            onPressed: _busy ? null : _restoreFromBackup,
            icon: Icon(Icons.settings_backup_restore_rounded, size: 16),
            label: Text(
              S.of(context).oobeRestore,
              style: ts(12, w: FontWeight.w600),
            ),
            style: TextButton.styleFrom(foregroundColor: C.blue),
          ),
        ],
      ),
    );
  }

  /// 选后缀：弹层与设置页共用（见 settings_widgets 的 showSsidPicker），
  /// 这里只把选中的值先存在本页 —— 首次引导要到第 3 步才真正写进 state。
  Future<void> _pickSsid(BuildContext context) async {
    final v = await showSsidPicker(context, current: _ssid);
    if (v == null || !mounted) return;
    setState(() => _ssid = v);
  }

  /// 符号图标：官方 APRS PNG 优先，缺失回退 Material
  Widget _symIcon(String sym, IconData fallback, {required bool active}) {
    final png = AprsSym.iconAsset('/', sym);
    final color = active ? C.blue : C.slate;
    if (png != null) {
      return Image.asset(
        png,
        width: 30,
        height: 30,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(fallback, color: color, size: 26),
      );
    }
    return Icon(fallback, color: color, size: 26);
  }

  Widget _feature(IconData icon, String title, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.surfaceFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: C.blueBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: C.blue, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ts(13, w: FontWeight.w700)),
                SizedBox(height: 2),
                Text(desc, style: ts(11, c: C.slate)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 第 4 步：呼号 ───
  Widget _callsign() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          SizedBox(height: 16),
          Icon(Icons.badge_rounded, color: C.blue, size: 52),
          SizedBox(height: 16),
          Text(
            S.of(context).oobeCallTitle,
            style: ts(20, w: FontWeight.w800, ls: -0.4),
          ),
          SizedBox(height: 8),
          Text(
            S.of(context).oobeCallDesc,
            textAlign: TextAlign.center,
            style: ts(12, c: C.slate, h: 1.6),
          ),
          SizedBox(height: 24),
          TextField(
            controller: _call,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            style: ts(20, w: FontWeight.w800, ls: 2),
            decoration: InputDecoration(
              hintText: S.of(context).callsign,
              hintStyle: ts(20, c: C.greyLight, w: FontWeight.w800),
              filled: true,
              fillColor: C.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: C.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: C.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: C.blue, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
            onSubmitted: (_) => _next(),
          ),
          SizedBox(height: 12),
          // SSID 后缀选择（点击弹窗）
          Text(S.of(context).ssidOptional, style: ts(13, w: FontWeight.w700)),
          SizedBox(height: 6),
          GestureDetector(
            onTap: () => _pickSsid(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: C.surfaceFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.tag_rounded, size: 18, color: C.blue),
                  SizedBox(width: 8),
                  Text(
                    _ssid.isEmpty ? S.of(context).noSsid : '-$_ssid',
                    style: ts(13, c: C.blue, w: FontWeight.w700),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right_rounded, size: 20, color: C.grey),
                ],
              ),
            ),
          ),
          SizedBox(height: 6),
          // 预览完整呼号：跟着输入框实时刷新（文本框自己改字不会重建父组件，
          // 所以用 ValueListenableBuilder 盯 controller，整页不跟着逐字重建）
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _call,
            builder: (_, v, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: C.blueBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                S.of(context).fullCallsign(
                  '${v.text.trim().toUpperCase()}${_ssid.isEmpty ? '' : '-$_ssid'}',
                ),
                style: ts(12, c: C.blue, w: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(height: 14),
        ],
      ),
    );
  }

  // ─── 第 5 步：符号 ───
  Widget _symbolPick() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          SizedBox(height: 16),
          Icon(Icons.interests_rounded, color: C.blue, size: 52),
          SizedBox(height: 16),
          Text(
            S.of(context).oobeSymbolTitle,
            style: ts(20, w: FontWeight.w800, ls: -0.4),
          ),
          SizedBox(height: 8),
          Text(S.of(context).oobeSymbolDesc, style: ts(12, c: C.slate)),
          SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final s in _syms)
                GestureDetector(
                  onTap: () => setState(() => _symbol = s.$1),
                  child: Container(
                    width: 92,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _symbol == s.$1 ? C.blueBg : C.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _symbol == s.$1 ? C.blue : C.border,
                        width: _symbol == s.$1 ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // 官方 APRS PNG 图标（优先），缺失回退 Material
                        _symIcon(s.$1, s.$3, active: _symbol == s.$1),
                        SizedBox(height: 8),
                        Text(
                          localizedAprsSymbolName(context, s.$1),
                          style: ts(
                            11,
                            c: _symbol == s.$1 ? C.blue : C.slate,
                            w: _symbol == s.$1
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 接收筛选：把勾选的国家写回 state
  void _applyFilterCountries() {
    widget.state.receiveCountries
      ..clear()
      ..addAll(_filterCountries);
    widget.state.setReceiveOthers(_receiveOthers);
  }

  // ─── 第 6 步：接收筛选 ───
  /// 接收筛选：按国家/地区选择接收台站（默认不勾选 = 不做限制）
  Widget _filterPick() {
    final entries = AppState.countryNames.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          SizedBox(height: 16),
          Icon(Icons.public_rounded, color: C.blue, size: 52),
          SizedBox(height: 16),
          Text(
            S.of(context).oobeFilterTitle,
            style: ts(20, w: FontWeight.w800, ls: -0.4),
          ),
          SizedBox(height: 8),
          Text(
            S.of(context).oobeFilterDesc,
            textAlign: TextAlign.center,
            style: ts(12, c: C.slate, h: 1.6),
          ),
          SizedBox(height: 16),
          // 「其他台站」开关**前移到国家列表之前** ——
          // 它是「是否也接收未勾选国家的台站」的总开关；国家列表有 25 项，
          // 放在列表底部要滑很久才看得到。
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: C.purpleBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.purple.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.blur_circular_rounded, size: 18, color: C.purple),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context).receiveOthers,
                        style: ts(13, w: FontWeight.w700),
                      ),
                      SizedBox(height: 2),
                      Text(
                        S.of(context).receiveOthersDesc,
                        style: ts(11, c: C.slate),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _receiveOthers,
                  activeColor: C.purple,
                  onChanged: (v) => setState(() => _receiveOthers = v),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          ...entries.map((e) {
            final on = _filterCountries.contains(e.key);
            return GestureDetector(
              onTap: () => setState(() {
                if (on) {
                  _filterCountries.remove(e.key);
                } else {
                  _filterCountries.add(e.key);
                }
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: on ? C.blueBg : C.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: on ? C.blue : C.border,
                    width: on ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.radio_button_checked_rounded,
                      size: 18,
                      color: on ? C.blue : C.greyLight,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        S.of(context).countryName(e.key),
                        style: ts(
                          13,
                          w: on ? FontWeight.w700 : FontWeight.w500,
                          c: on ? C.blue : C.ink,
                        ),
                      ),
                    ),
                    Text(e.key, style: ts(11, c: C.grey)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 第 7 步：服务器连接 ───
  /// 第 7 步：功能 —— 自选模块。
  ///
  /// 用户要求（2026-10-29）：「OOBE 阶段增加功能设置，涵盖历史轨迹和其他功能」。
  /// 装完第一件事常常就是「这些花哨的东西我不要」，在这里就能关掉，不必先装好
  /// 再跑一趟设置。开关写的就是同一份 state（setFeature 自己落盘）——「设置 →
  /// 功能」里那批开关与这里是同一批，不会各记一套。
  ///
  /// 精简模式**不**放在这一步：它是整套外壳的切换，在向导里按一下会让后面的页面
  /// 直接换个样子，装完也记不住「刚才是我自己按的」。
  Widget _featuresPage() {
    final s = S.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          SizedBox(height: 16),
          Icon(Icons.widgets_rounded, color: C.purple, size: 52),
          SizedBox(height: 16),
          Text(
            s.oobeFeatureTitle,
            style: ts(20, w: FontWeight.w800, ls: -0.4),
          ),
          SizedBox(height: 8),
          Text(
            s.oobeFeatureDesc,
            textAlign: TextAlign.center,
            style: ts(12, c: C.slate, h: 1.6),
          ),
          SizedBox(height: 16),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // 天气不是模块（它只是顶栏的一条读数），但在「设置 → 功能」那张
                // 单子上排第一 —— 这里跟着排同一份，两处看到的顺序一致。
                SettingsSwitch(
                  s.featureWeather,
                  value: widget.state.weatherEnabled,
                  color: C.purple,
                  onChanged: (v) =>
                      setState(() => widget.state.setWeatherEnabled(v)),
                ),
                // ⚠ 这里读 `featuresOff` 而不是 `featureEnabled`：后者在精简模式下
                // 一律 false，若用户是从一份开着精简模式的备份恢复过来的，开关会
                // 显示成关、点下去也「不动」（值写了但不显示）—— 那正是「启用了却
                // 激活不了」的观感。向导里显示的是他自己关过哪几个。
                for (final f in AppFeature.values)
                  SettingsSwitch(
                    _featureLabel(f, s),
                    value: !widget.state.featuresOff.contains(f.id),
                    color: C.purple,
                    onChanged: (v) =>
                        setState(() => widget.state.setFeature(f.id, v)),
                  ),
              ],
            ),
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }

  /// 模块名：与「设置 → 功能」用的是同一批文案键。
  String _featureLabel(AppFeature f, S s) {
    switch (f) {
      case AppFeature.rank:
        return s.sportRank;
      case AppFeature.honor:
        return s.honorWall;
      case AppFeature.sponsor:
        return s.sponsorEntry;
      case AppFeature.lifeGuard:
        return s.lifeGuard;
      case AppFeature.translate:
        return s.featureTranslate;
      case AppFeature.tracks:
        return s.historyTracks;
      case AppFeature.adif:
        return s.exportAdif;
    }
  }

  Widget _serverPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          SizedBox(height: 16),
          Icon(Icons.wifi_rounded, color: C.blue, size: 52),
          SizedBox(height: 16),
          Text(
            S.of(context).oobeServerTitle,
            style: ts(20, w: FontWeight.w800, ls: -0.4),
          ),
          SizedBox(height: 8),
          Text(
            S.of(context).oobeServerDesc,
            textAlign: TextAlign.center,
            style: ts(12, c: C.slate, h: 1.6),
          ),
          SizedBox(height: 24),
          // 两条互联网链路二选一：都是「一条 TCP 登录」，没有主备之分。
          Row(
            children: [
              Expanded(
                child: _linkCard(
                  title: S.of(context).dataSourceAprsIs,
                  desc: S.of(context).dataSourceAprsIsDesc,
                  icon: Icons.cloud_rounded,
                  on: _link == AppState.srcAprsIs,
                  onTap: () => _pickLink(AppState.srcAprsIs),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _linkCard(
                  title: S.of(context).acnCardTitle,
                  desc: S.of(context).acnCardSubtitle,
                  icon: Icons.hub_rounded,
                  on: _link == AppState.srcAcn,
                  onTap: () => _pickLink(AppState.srcAcn),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // 提示里**不出现任何具体服务器地址**（不提供、不推荐：见用户协议 2.4）
          _field(S.of(context).server, _server, ''),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _field(S.of(context).port, _port, '14580')),
              SizedBox(width: 10),
              Expanded(child: _field(S.of(context).passcode, _pass, '-1')),
            ],
          ),
          SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.redBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: C.red),
                    SizedBox(width: 6),
                    Text(
                      S.of(context).passcodeImportant,
                      style: ts(12, c: C.red, w: FontWeight.w700),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  S.of(context).passcodeImportantDesc,
                  style: ts(11, c: C.red, w: FontWeight.w500, h: 1.4),
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          // 服务器这一步**可以完全不填**（留空 = 纯本地）。但底部那颗
          // 「下一步」长得像「必须填完才能过」，重跑向导的人会卡在这里 ——
          // 给一个大按钮明说可以跳过。
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: _skipServer,
              style: OutlinedButton.styleFrom(
                foregroundColor: C.slate,
                side: BorderSide(color: C.borderStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: ts(13.5, w: FontWeight.w700),
              ),
              child: Text(S.of(context).oobeServerSkip),
            ),
          ),
        ],
      ),
    );
  }

  /// 「跳过服务器配置」：把三个输入框清空，再照常走下一步。
  ///
  /// 清空不是多余的：重跑向导时这三格回填的是上次存的值，只跳过不清空
  /// 会变成「以为跳过了，其实地址还在」。留空就是不连接。
  void _skipServer() {
    _server.clear();
    _port.clear();
    _pass.clear();
    _next();
  }

  /// 第 7 步的二选一卡片（与筛选页那一组选中卡同一个观感）。
  Widget _linkCard({
    required String title,
    required String desc,
    required IconData icon,
    required bool on,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: on ? C.blueBg : C.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: on ? C.blue : C.border,
            width: on ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: on ? C.blue : C.grey),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: ts(
                      12.5,
                      w: FontWeight.w700,
                      c: on ? C.blue : C.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  on
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 15,
                  color: on ? C.blue : C.greyLight,
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              desc,
              style: ts(10.5, c: C.slate, h: 1.35),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── 第 8 步：配置完成 ───
  /// 最后一步做两件事：把刚才存下来的三样东西回读一次，再指一下接下来常用的
  /// 三处地方。首次使用的人真正缺的是「然后呢」，而不是更多选项。
  Widget _done() {
    final s = S.of(context);
    final acnLink = _link == AppState.srcAcn;
    final call =
        '${_call.text.trim().toUpperCase()}${_ssid.isEmpty ? '' : '-$_ssid'}';
    final server = _server.text.trim();
    final linkName = acnLink ? s.acnCardTitle : s.dataSourceAprsIs;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          SizedBox(height: 16),
          Icon(Icons.check_circle_rounded, color: C.green, size: 52),
          SizedBox(height: 16),
          Text(s.oobeDoneTitle, style: ts(20, w: FontWeight.w800, ls: -0.4)),
          SizedBox(height: 8),
          Text(
            server.isEmpty
                ? s.oobeDoneLocalNote
                : s.oobeDoneConnectNote(linkName),
            textAlign: TextAlign.center,
            style: ts(12, c: C.slate, h: 1.6),
          ),
          SizedBox(height: 20),
          // 回读：让用户确认向导真的写进了设置，而不是一路「下一步」到底
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _sumRow(s.callsign, call.isEmpty ? '—' : call),
                _sumRow(
                  s.oobeDoneSymbolLabel,
                  localizedAprsSymbolName(context, _symbol),
                ),
                _sumRow(
                  s.server,
                  server.isEmpty ? s.oobeDoneUnset : '$linkName · $server',
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          _feature(Icons.public_rounded, s.oobeDoneMap, s.oobeDoneMapDesc),
          SizedBox(height: 12),
          _feature(Icons.send_rounded, s.oobeDoneBeacon, s.oobeDoneBeaconDesc),
          SizedBox(height: 12),
          _feature(
            Icons.menu_book_rounded,
            s.manualTitle,
            s.oobeDoneManualDesc,
          ),
        ],
      ),
    );
  }

  /// 完成页的回读行：左边是名目，右边是刚才存下来的值。
  Widget _sumRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
      ),
      child: Row(
        children: [
          Text(label, style: ts(12, c: C.slate)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(12.5, c: C.ink, w: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ts(11, c: C.slate, w: FontWeight.w600),
        ),
        SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: ts(13, w: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: ts(13, c: C.greyLight),
            isDense: true,
            filled: true,
            fillColor: C.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: C.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: C.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: C.blue, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
