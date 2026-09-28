import 'package:flutter/material.dart';

import 'hr_card.dart';
import 'material.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// 蓝牙心率带设置页（设置 → 设备 → 心率）。
///
/// ── 为什么单独一页，而不是塞在信标设置页里 ──
/// 它是**一个设备**（要搜、要连、会掉线），与「信标怎么发」是不同的两件事。
/// 放在设备列表里，用户找「连心率带」时才会往这里看（而信标页是「上报什么内容」）。
///
/// 页面正文直接复用 [HrSettingsCard]（原来给信标页写的那张卡）——
/// 不重写一份，免得两处逻辑漂移。
class HrDevicePage extends StatelessWidget {
  final AppState state;
  const HrDevicePage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.pageFill,
      // 材质开启时顶栏是半透明壳表面，必须套材质壳（见 material.dart）
      appBar: MaterialAppBar(
        AppBar(
          backgroundColor: C.surfaceFillStrong,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: C.ink, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(S.of(context).hrCardTitle, style: ts(16, w: FontWeight.w700)),
          centerTitle: true,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          SettingsSectionCard(
            title: S.of(context).hrCardTitle,
            subtitle: S.of(context).hrCardSubtitle,
            icon: Icons.favorite_rounded,
            color: C.red,
            children: [HrSettingsCard(state: state)],
          ),
          const SizedBox(height: 16),
          _HrAlarmCard(state: state),
        ],
      ),
    );
  }
}


/// 心率异常告警设置（issue #21-8）。
///
/// 只在这里**配置**，不在这一页弹告警：告警的判定在 AppState（`_checkHrAlarm`），
/// 呈现由 `HrAlarmWatcher` 统一负责 —— 那里才能保证「无论在哪个页面都弹得出来」。
///
/// 单独一个 StatefulWidget 只为一件事：三个输入框各自的 controller 与「回车即
/// 写入」的时序（与信标页那一套同一个做法：失焦/回车才提交，不逐字符写 prefs）。
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

  @override
  void initState() {
    super.initState();
    _high = TextEditingController(text: '${st.hrAlarmHigh}');
    _low = TextEditingController(text: '${st.hrAlarmLow}');
    _tel = TextEditingController(text: st.emergencyTel);
  }

  @override
  void dispose() {
    _high.dispose();
    _low.dispose();
    _tel.dispose();
    super.dispose();
  }

  void _commit() {
    st.setHrAlarmThresholds(
      high: int.tryParse(_high.text.trim()),
      low: int.tryParse(_low.text.trim()),
    );
    // 回写：setter 里做了 clamp，把夹过的值显示回输入框，
    // 否则用户输入的 300 会被静默改成 240 而界面还写着 300。
    _high.text = '${st.hrAlarmHigh}';
    _low.text = '${st.hrAlarmLow}';
    st.setEmergencyTel(_tel.text);
    _tel.text = st.emergencyTel;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SettingsSectionCard(
      title: s.hrAlarmCard,
      subtitle: s.hrAlarmCardSub,
      icon: Icons.warning_amber_rounded,
      color: C.red,
      children: [
        SettingsSwitch(s.hrAlarmEnabled, value: st.hrAlarmEnabled,
            color: C.red, onChanged: st.setHrAlarmEnabled),
        SettingsHint(s.hrAlarmEnabledTip, color: C.grey),
        if (st.hrAlarmEnabled) ...[
          SettingsInput(s.hrAlarmHighLabel, _high,
              tip: s.hrAlarmHighTip, onEditingComplete: _commit),
          SettingsInput(s.hrAlarmLowLabel, _low,
              tip: s.hrAlarmLowTip, onEditingComplete: _commit),
          SettingsInput(s.hrAlarmTelLabel, _tel,
              tip: s.hrAlarmTelTip, onEditingComplete: _commit),
        ],
      ],
    );
  }
}
