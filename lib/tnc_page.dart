import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'tnc.dart';
import 'widgets.dart';

/// ─── TNC 页的**共享组件** ───
///
/// 页面本体已拆分（设备页重构，v1.6.105）：
///   * 概览（数据来源 + 当前链路 + 自检 + 入口）→ lib/device_page.dart
///   * TNC 设备与参数（绑定 / 初始化串 / KISS 参数 / 射频行为 / 发射自检）
///     → lib/tnc_device_page.dart
///   * 音频 → lib/audio_page.dart
///
/// 本文件只留两块被多处复用的东西：
///   ① `DataSourceCard`：连接页与设备页都要能切来源，各写一份必然不一致
///   ② `copyTncLog`：调试用的日志复制助手
/// 数据来源选择卡片（连接页与设备页共用）
///
/// 做成公共组件的原因：同一个设置在两个入口都要能改 —— 用户插上 TNC 后
/// 往往在「设备」页，而排查连接问题时又会去「连接」页；各写一份迟早出现
/// 文案与行为不一致。
class DataSourceCard extends StatelessWidget {
  final AppState state;
  final String? extra;
  const DataSourceCard({super.key, required this.state, this.extra});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SettingsSectionCard(
      title: s.dataSourceTitle,
      subtitle: s.dataSourceSubtitle,
      icon: Icons.swap_horiz_rounded,
      color: C.blue,
      children: [
        _tile(
          key: AppState.srcAprsIs,
          title: s.dataSourceAprsIs,
          desc: s.dataSourceAprsIsDesc,
          icon: Icons.cloud_rounded,
        ),
        _tile(
          key: AppState.srcTnc,
          title: s.dataSourceTnc,
          desc: s.dataSourceTncDesc,
          icon: Icons.settings_input_antenna_rounded,
        ),
        _tile(
          key: AppState.srcAudio,
          title: s.dataSourceAudio,
          desc: s.dataSourceAudioDesc,
          icon: Icons.graphic_eq_rounded,
        ),
        if (extra != null) SettingsHint(extra!),
      ],
    );
  }

  Widget _tile({
    required String key,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    final selected = state.dataSource == key;
    return InkWell(
      onTap: selected ? null : () => state.setDataSource(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: selected ? C.blue.withValues(alpha: 0.12) : C.greyBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: selected ? C.blue : C.grey),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: ts(13,
                        w: FontWeight.w700, c: selected ? C.blue : C.ink)),
                const SizedBox(height: 2),
                Text(desc, style: ts(11, c: C.grey)),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, size: 18, color: C.blue)
          else
            Icon(Icons.radio_button_unchecked_rounded,
                size: 18, color: C.greyLight),
        ]),
      ),
    );
  }
}
