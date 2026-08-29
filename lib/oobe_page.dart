import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'state.dart';
import 'models.dart';
import 'widgets.dart';

/// 首次启动引导（OOBE）：欢迎 → 呼号 → 符号 → 服务器连接
class OobePage extends StatefulWidget {
  final AppState state;
  const OobePage({super.key, required this.state});
  @override
  State<OobePage> createState() => _OobePageState();
}

class _OobePageState extends State<OobePage> {
  int _step = 0;
  final PageController _pc = PageController();
  late final TextEditingController _call;
  late final TextEditingController _server;
  late final TextEditingController _port;
  late final TextEditingController _pass;
  String _symbol = '>';
  int _ssid = 0;
  // 界面语言：'' = 跟随系统；'zh' 中文；'en' English
  String _lang = '';
  // 接收筛选：默认接受中国呼号
  List<String> _filterCountries = ['CN'];
  bool _receiveOthers = false;

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
    _call = TextEditingController(text: st.myCall);
    _server = TextEditingController(text: st.aprs.server);
    _port = TextEditingController(text: '${st.aprs.port}');
    _pass = TextEditingController(text: st.aprs.passcode);
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
    switch (_step) {
      case 0:
        // 语言选择步骤：立即应用界面语言
        widget.state.setLocale(_lang);
      case 1:
      // 欢迎页：无校验
      case 2:
        // 呼号步骤
        final c = _call.text.trim().toUpperCase();
        if (c.isEmpty) {
          _toast(S.of(context).enterCallsign);
          return;
        }
        widget.state.myCall = c;
        widget.state.mySsid = _ssid;
        widget.state.persist();
      case 3:
        // 符号步骤
        widget.state.mySymbol = _symbol;
        widget.state.persist();
      case 4:
        // 接收筛选步骤：把选择的国家写入 state（默认已选中国）
        _applyFilterCountries();
    }
    if (_step >= 5) {
      // 步骤 5（服务器）：强调 passcode 重要性，默认值弹确认
      final pc = _pass.text.trim().isEmpty ? '-1' : _pass.text.trim();
      if (pc == '-1') {
        _confirmDefaultPasscode();
      } else {
        _finish();
      }
      return;
    }
    _pc.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) return;
    _pc.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInCubic,
    );
    setState(() => _step--);
  }

  /// 默认 Passcode（-1）确认提示：强调未验证无法正常收发消息
  void _confirmDefaultPasscode() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: C.orange, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                S.of(context).oobePasscodeMissing,
                style: ts(16, w: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          S.of(context).oobePasscodeMissingDesc,
          style: ts(13, c: C.slate, h: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _finish();
            },
            child: Text(
              S.of(context).continueAnyway,
              style: ts(13, c: C.orange, w: FontWeight.w600),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: C.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              S.of(context).fillPasscode,
              style: ts(13, c: Colors.white, w: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finish() async {
    final st = widget.state;
    st.aprs.server = _server.text.trim().isEmpty
        ? 'rotate.aprs2.net'
        : _server.text.trim();
    st.aprs.port = int.tryParse(_port.text) ?? 14580;
    st.aprs.passcode = _pass.text.trim().isEmpty ? '-1' : _pass.text.trim();
    st.persist();
    // 先进主页，连接放到后台进行（主页底部横幅显示连接状态）
    st.completeOobe();
    st.toggleConnect();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _step >= 5;
    return Scaffold(
      backgroundColor: C.bg,
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
                    style: ts(15, w: FontWeight.w800, ls: -0.3),
                  ),
                  Spacer(),
                  Text('${_step + 1} / 6', style: ts(12, c: C.grey)),
                ],
              ),
            ),
            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  for (var i = 0; i < 6; i++) ...[
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
                    if (i < 5) const SizedBox(width: 6),
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
                  _welcome(),
                  _callsign(),
                  _symbolPick(),
                  _filterPick(),
                  _serverPage(),
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
                  FilledButton.icon(
                    onPressed: _next,
                    icon: Icon(
                      last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                      size: 16,
                    ),
                    label: Text(
                      last ? S.of(context).finish : S.of(context).next,
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
      ('en', S.of(context).languageEn),
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
            style: ts(22, w: FontWeight.w800, ls: -0.4),
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
                  borderRadius: BorderRadius.circular(14),
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

  // ─── 第 2 步：欢迎 ───
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
            style: ts(24, w: FontWeight.w800, ls: -0.5),
          ),
          SizedBox(height: 10),
          Text(S.of(context).aboutSubtitle, style: ts(14, c: C.slate, ls: 1)),
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
        ],
      ),
    );
  }

  void _pickSsid(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: C.greyLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 14),
            Text(
              S.of(context).chooseSsidSuffix,
              style: ts(16, w: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              S.of(context).ssidDescShort,
              style: ts(11, c: C.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _ssidOption(S.of(context).none, 0),
                for (int i = 1; i <= 15; i++) _ssidOption('-$i', i),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _ssidOption(String label, int val) {
    final selected = _ssid == val;
    return GestureDetector(
      onTap: () {
        setState(() => _ssid = val);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? C.blue : C.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? C.blue : C.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: ts(
            13,
            c: selected ? Colors.white : C.slate,
            w: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
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
        color: C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: C.blueBg,
              borderRadius: BorderRadius.circular(11),
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

  // ─── 第 2 步：呼号 ───
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
            style: ts(22, w: FontWeight.w800, ls: -0.4),
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
            style: ts(22, w: FontWeight.w800, ls: 2),
            decoration: InputDecoration(
              hintText: S.of(context).callsign,
              hintStyle: ts(22, c: C.greyLight, w: FontWeight.w800),
              filled: true,
              fillColor: C.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: C.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: C.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
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
                color: C.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.tag_rounded, size: 18, color: C.blue),
                  SizedBox(width: 8),
                  Text(
                    _ssid == 0 ? S.of(context).noSsid : '-$_ssid',
                    style: ts(14, c: C.blue, w: FontWeight.w700),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right_rounded, size: 20, color: C.grey),
                ],
              ),
            ),
          ),
          SizedBox(height: 6),
          // 预览完整呼号
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: C.blueBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              S
                  .of(context)
                  .fullCallsign(
                    '${_call.text.trim().toUpperCase()}${_ssid == 0 ? '' : '-$_ssid'}',
                  ),
              style: ts(12, c: C.blue, w: FontWeight.w600),
            ),
          ),
          SizedBox(height: 14),
        ],
      ),
    );
  }

  // ─── 第 3 步：符号 ───
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
            style: ts(22, w: FontWeight.w800, ls: -0.4),
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
                      borderRadius: BorderRadius.circular(14),
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

  // ─── 第 4 步：服务器 ───
  void _applyFilterCountries() {
    widget.state.receiveCountries
      ..clear()
      ..addAll(_filterCountries);
    widget.state.setReceiveOthers(_receiveOthers);
  }

  /// 接收筛选：按国家/地区选择接收台站（默认中国）
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
            style: ts(22, w: FontWeight.w800, ls: -0.4),
          ),
          SizedBox(height: 8),
          Text(
            S.of(context).oobeFilterDesc,
            textAlign: TextAlign.center,
            style: ts(12, c: C.slate, h: 1.6),
          ),
          SizedBox(height: 24),
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
          SizedBox(height: 12),
          // 其他台站开关
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
        ],
      ),
    );
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
            style: ts(22, w: FontWeight.w800, ls: -0.4),
          ),
          SizedBox(height: 8),
          Text(
            S.of(context).oobeServerDesc,
            textAlign: TextAlign.center,
            style: ts(12, c: C.slate, h: 1.6),
          ),
          SizedBox(height: 24),
          _field(S.of(context).server, _server, 'rotate.aprs2.net'),
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
                SizedBox(height: 8),
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse('https://aprs.cool/AprsPG'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: C.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new_rounded, size: 14, color: C.red),
                        SizedBox(width: 6),
                        Text(
                          S.of(context).lookupPasscode,
                          style: ts(12, c: C.red, w: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  S.of(context).passcodeLookupHint,
                  style: ts(10, c: C.grey),
                ),
              ],
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
