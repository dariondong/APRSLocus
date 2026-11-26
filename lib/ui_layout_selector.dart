import 'package:flutter/material.dart';

import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// 界面布局选择（1.0 经典 / 2.0 地图为基底）。
///
/// 原来在「设置 → 显示」里，现在收进「设置 → 模式与功能」的模式卡 ——
/// 两档是**外壳结构**的选择，和精简模式、卫星模式属于同一类。
class UiLayoutSelector extends StatelessWidget {
  final AppState state;
  const UiLayoutSelector({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cur = state.uiLayoutValue;
    final options = <(UiLayout, String, String)>[
      (UiLayout.classic, s.uiLayoutClassic, s.uiLayoutClassicDesc),
      (UiLayout.sheet, s.uiLayoutSheet, s.uiLayoutSheetDesc),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.uiLayout, style: ts(12, c: C.slate)),
          const SizedBox(height: 2),
          Text(s.uiLayoutDesc, style: ts(10, c: C.grey, h: 1.35)),
          const SizedBox(height: 8),
          for (final (m, name, desc) in options)
            GestureDetector(
              onTap: () => state.setUiLayout(uiLayoutName(m)),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: cur == m ? C.cyanBg : C.bgSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cur == m ? C.cyan : C.border,
                    width: cur == m ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      cur == m
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: cur == m ? C.cyan : C.greyLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: ts(
                              12,
                              c: cur == m ? C.cyan : C.slate,
                              w: cur == m ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(desc, style: ts(10, c: C.grey, h: 1.3)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _swatch(m),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 布局小样：把「地图在哪、内容在哪」画成示意图。
  Widget _swatch(UiLayout l) {
    final mapColor = C.blue.withValues(alpha: 0.18);
    final barColor = C.blue.withValues(alpha: 0.55);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 68,
        height: 40,
        child: Container(
          color: C.bgSoft,
          child: l == UiLayout.sheet
              // 2.0：地图满屏，底部一张浮起的卡片
              ? Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: mapColor)),
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 5,
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: C.surfaceFill,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: C.border),
                        ),
                      ),
                    ),
                  ],
                )
              // 1.0：左侧栏 + 顶栏 + 内容区
              : Row(
                  children: [
                    Container(width: 16, color: barColor),
                    Expanded(
                      child: Column(
                        children: [
                          Container(height: 8, color: barColor),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
