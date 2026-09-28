import 'dart:async';

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
    final s = S.of(context);
    return SettingsPageShell(
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
          ],
        ),
        const SizedBox(height: 16),
        // ③ 告警设置
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
