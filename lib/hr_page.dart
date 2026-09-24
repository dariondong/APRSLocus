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
        ],
      ),
    );
  }
}
