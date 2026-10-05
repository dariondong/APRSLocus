import 'package:flutter/material.dart';

import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 生命守护（设置 → 生命守护）───
///
/// 用户需求（issue #22-4）：「将心率异常报警，移入设置页，底下一个生命守护。
/// 在设置页底下添加一个生命守护页面，并说明其相关信息和开启条件。这是个测试功能。」
///
/// 所以这一页要承担三件事，缺一个用户就会误解这个功能：
///   1. **安置告警设置**（阈值 / 紧急号码 / 开关）—— 原来藏在「设备 → 心率」里，
///      而那个页面是讲「心率带怎么连」的，属性完全不同（一个是设备，一个是安全策略）；
///   2. **说清它怎么触发**（开启条件）—— 光有阈值输入框，用户不知道「它到底是
///      看谁的读数、什么时候才轮到它说话」；
///   3. **如实标注这是测试功能** —— 它的判定只基于心率数值，没有任何医学依据，
///      把这一条藏起来等于默认它对用户健康负责。
///
/// 告警的**判定**在 `AppState._checkHrAlarm`，**呈现**在 `HrAlarmWatcher`
/// （挂在 app.dart 的 home 外层，才能保证在任何页面都弹得出来）。
/// 这一页只负责配置与说明 —— 这也是它不需要「测试告警」按钮以外的任何逻辑的原因。
class LifeGuardPage extends StatelessWidget {
  final AppState state;
  const LifeGuardPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    // ⚠ 必须自己包 ListenableBuilder：`SettingsPageShell.state` **只**服务于引导卡，
    // 并不会让本页跟随状态刷新（那个参数以前的注释写错了，害得本页开关点了不动 ——
    // issue #24）。这一页上每一个开关/输入框都写回 AppState，不监听就是「点了没反应」。
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final s = S.of(context);
    return SettingsPageShell(
      // 传给外壳只为引导卡（首次进入的提示卡）；实时刷新靠上面那层 ListenableBuilder
      state: state,
      title: s.lifeGuard,
      subtitle: s.lifeGuardSubtitle,
      icon: Icons.health_and_safety_rounded,
      color: C.red,
      body: Column(children: [
        // ① 这是什么 / 不是什么的说明
        SettingsSectionCard(
          title: s.lifeGuardIntroTitle,
          subtitle: s.lifeGuardBeta,
          icon: Icons.info_outline_rounded,
          color: C.orange,
          children: [
            SettingsHint(s.lifeGuardIntroBody, color: C.grey),
          ],
        ),
        const SizedBox(height: 16),
        // ② 开启条件
        SettingsSectionCard(
          title: s.lifeGuardCondTitle,
          subtitle: s.lifeGuardCondSubtitle,
          icon: Icons.checklist_rounded,
          color: C.blue,
          children: [
            SettingsHint(s.lifeGuardCondBody, color: C.grey),
            // 「向附近台站求助」的口径也在这里说清 —— 它是告警的一部分，
            // 但用户最容易误以为「会自动广播」，必须在配置之前就写明。
            SettingsHint(s.lifeGuardNearbyNote, color: C.orange),
            // issue #32「强提醒」：告诉用户告警走的是高优先级系统通知，
            // 以及需要他确认的系统侧条件（通知权限 / 免打扰）。
            SettingsHint(s.lifeGuardStrongHint, color: C.blue),
          ],
        ),
        const SizedBox(height: 16),
        // ③ 碰撞 / 摔倒检测（issue #26）
        _CrashCard(state: state),
        const SizedBox(height: 16),
        // ④ 心率告警设置
        _HrAlarmCard(state: state),
        const SizedBox(height: 24),
      ]),
    );
  }
}

/// 心率异常告警的设置卡（从「设备 → 心率」搬过来，见 [LifeGuardPage] 的说明）。
///
/// ── commit 语义（issue #22-1 的根因）──
///
/// 上一版把三个输入框都只在 `onEditingComplete` 里提交，而 Flutter 的
/// `onEditingComplete` **只在按键盘上的「完成/回车」时触发，失焦不触发**。
/// 于是用户输入一个新阈值、随手点别处 → 什么都没保存，界面还显示着旧值效果，
/// 表现就是「异常数值无法更改」。现在：
///   * `onChanged` **立即写入**（解析成功才写，且**不回写文本**，否则输入
///     「1」会被 clamp 成 80 再把输入框改成「80」，用户根本打不完 150）；
///   * 失焦 / 回车时做一次 **clamp + 回写**，把夹过的值如实显示出来；
///   * 卡片里多一行「当前生效：40~150 bpm」—— 改没改、改成多少，一眼可见
///     （用户说的「按钮更新并不及时」正是缺这个可见的反馈）。
class _HrAlarmCard extends StatefulWidget {
  final AppState state;
  const _HrAlarmCard({required this.state});

  @override
  State<_HrAlarmCard> createState() => _HrAlarmCardState();
}

class _HrAlarmCardState extends State<_HrAlarmCard> {
  AppState get st => widget.state;

  late final TextEditingController _high;
  late final TextEditingController _low;
  late final TextEditingController _tel;
  late final FocusNode _highFocus;
  late final FocusNode _lowFocus;
  late final FocusNode _telFocus;

  @override
  void initState() {
    super.initState();
    _high = TextEditingController(text: '${st.hrAlarmHigh}');
    _low = TextEditingController(text: '${st.hrAlarmLow}');
    _tel = TextEditingController(text: st.emergencyTel);
    // 失焦即落定：这是「改完就走」这条最常见路径的兜底。
    _highFocus = FocusNode()..addListener(_onBlur);
    _lowFocus = FocusNode()..addListener(_onBlur);
    _telFocus = FocusNode()..addListener(_onBlur);
  }

  void _onBlur() {
    if (_highFocus.hasFocus || _lowFocus.hasFocus || _telFocus.hasFocus) return;
    _normalize();
  }

  @override
  void dispose() {
    for (final f in [_highFocus, _lowFocus, _telFocus]) {
      f.dispose();
    }
    for (final c in [_high, _low, _tel]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 边输边存：解析不出来的中间态（空串、只打了个「-」）不写，
  /// 保持上一次的有效值 —— 与信标页那几个数值输入同一套口径。
  void _live() {
    final hi = int.tryParse(_high.text.trim());
    final lo = int.tryParse(_low.text.trim());
    if (hi != null || lo != null) {
      st.setHrAlarmThresholds(high: hi, low: lo);
    }
    if (_tel.text.trim().isNotEmpty) st.setEmergencyTel(_tel.text);
  }

  /// 失焦/回车时把 state 里（clamp 过的）真值回写进输入框。
  void _normalize() {
    _live();
    final hi = '${st.hrAlarmHigh}';
    final lo = '${st.hrAlarmLow}';
    final tel = st.emergencyTel;
    if (_high.text != hi) _high.text = hi;
    if (_low.text != lo) _low.text = lo;
    if (_tel.text != tel) _tel.text = tel;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SettingsSectionCard(
      title: s.hrAlarmCard,
      subtitle: s.hrAlarmCardSub,
      icon: Icons.warning_amber_rounded,
      color: C.red,
      trailing: st.hrAlarmEnabled
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: C.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(s.lifeGuardBeta,
                  style: ts(10, c: C.red, w: FontWeight.w700)),
            )
          : null,
      children: [
        SettingsSwitch(s.hrAlarmEnabled, value: st.hrAlarmEnabled,
            color: C.red, onChanged: st.setHrAlarmEnabled),
        SettingsHint(s.hrAlarmEnabledTip, color: C.grey),
        if (st.hrAlarmEnabled) ...[
          // 当前生效值：改没改、改成多少，一眼可见（issue #22-1 的「更新不及时」）
          SettingsRow2(
            s.hrAlarmCurrent,
            '${st.hrAlarmLow} ~ ${st.hrAlarmHigh} bpm',
            valueColor: C.red,
          ),
          SettingsInput(s.hrAlarmHighLabel, _high,
              tip: s.hrAlarmHighTip,
              focusNode: _highFocus,
              onChanged: (_) => _live(),
              onEditingComplete: _normalize),
          SettingsInput(s.hrAlarmLowLabel, _low,
              tip: s.hrAlarmLowTip,
              focusNode: _lowFocus,
              onChanged: (_) => _live(),
              onEditingComplete: _normalize),
          SettingsInput(s.hrAlarmTelLabel, _tel,
              tip: s.hrAlarmTelTip,
              focusNode: _telFocus,
              onChanged: (_) => _live(),
              onEditingComplete: _normalize),
          SettingsHint(s.hrAlarmRangeNote, color: C.grey),
        ],
      ],
    );
  }
}


/// 碰撞 / 摔倒检测的设置卡（issue #26）。
///
/// 用户需求：「生命守护支持车祸与摔落检测提醒（测试），通过手机加速度判断」。
///
/// 判定在原生侧（`MotionManager.checkImpact`：**冲击 + 随后静止**两段式），
/// 这一张卡只负责开关与说明 —— 而说明比开关重要：
///   * 它是**启发式**的（固定阈值、不看行车方向、不融合 GPS），必须写明；
///   * 它**会误报**（过减速带 + 随后停车正好满足两段判据），也要写明，
///     并且弹窗第一个按钮是「我没事」；
///   * 「随后静止」这条为什么必须有：不要求静止的话，手机放桌上、甩一甩都会报，
///     每天响几次，用户第一件事就是把它永久关掉。
class _CrashCard extends StatelessWidget {
  final AppState state;
  const _CrashCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = state;
    return SettingsSectionCard(
      title: s.crashCard,
      subtitle: s.crashCardSub,
      icon: Icons.car_crash_rounded,
      color: C.orange,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: C.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(s.lifeGuardBeta,
            style: ts(10, c: C.orange, w: FontWeight.w700)),
      ),
      children: [
        SettingsSwitch(s.crashEnabled,
            value: st.crashDetectEnabled,
            color: C.orange,
            onChanged: st.setCrashDetectEnabled),
        // 灵敏度（issue #32）：固定阈值无法同时适配「放裤兜里骑车」与「固定在车把上」，
        // 所以给三档。只在开启时显示 —— 关着的时候调它没有意义。
        if (st.crashDetectEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.crashSensitivity, style: ts(12, c: C.slate)),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'gentle', label: Text(s.crashSensGentle)),
                      ButtonSegment(
                          value: 'standard',
                          label: Text(s.crashSensStandard)),
                      ButtonSegment(
                          value: 'firm', label: Text(s.crashSensFirm)),
                    ],
                    selected: {st.crashSensitivity},
                    onSelectionChanged: (v) => st.setCrashSensitivity(v.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle:
                          WidgetStatePropertyAll(ts(11, w: FontWeight.w600)),
                      foregroundColor: WidgetStateProperty.resolveWith((sel) =>
                          sel.contains(WidgetState.selected)
                              ? Colors.white
                              : C.orange),
                      backgroundColor: WidgetStateProperty.resolveWith((sel) =>
                          sel.contains(WidgetState.selected)
                              ? C.orange
                              : Colors.transparent),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(s.crashSensHint, style: ts(11, c: C.grey, h: 1.4)),
              ],
            ),
          ),
        SettingsHint(s.crashHowItWorks, color: C.grey),
        // issue #32：讲清「摔倒 vs 碰撞」的新判据（自由落体段）。
        SettingsHint(s.crashKindHint, color: C.grey),
        // 没有加速度计：开关照旧可以点，但要如实说「这台设备检测不了」
        if (!st.hasCrashSensor && st.crashDetectEnabled)
          SettingsHint(s.crashNoSensor, color: C.orange),
        // 「检测到冲击、正在观察」：把它显示出来，用户就能理解
        // 「刚才那下颠簸它在看」——否则只会觉得这个功能「有时候会突然弹一下」
        if (st.crashDetectEnabled && st.impactPending)
          SettingsRow2(s.crashPending, s.hrAlarmCurrent,
              valueColor: C.orange),
        SettingsHint(s.crashFalsePositive, color: C.grey),
      ],
    );
  }
}
