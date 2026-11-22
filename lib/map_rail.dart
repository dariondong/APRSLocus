import 'package:flutter/material.dart';

import 'material.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 地图页左上那条浮层列的统一外形 ───
///
/// 地图是全屏视图，四周叠着十来块小浮层。左上那一列原先各写各的：圆角 12 与 16
/// 混着用、宽度随内容各自伸缩、间距 8 与 10 混着用，中间还夹着一枚 38×38 的黑色
/// 方块按钮 —— 一列读下来像是五个不同来源的东西摞在一起（用户原话「好乱 难看」）。
///
/// 这里只定**结构**，不定配色：一条定宽的列 + 一种行。读数行（心率 / 台站计数）
/// 与入口行（沉浸地图 / On-Air）外形相同，入口行右端多一枚箭头。空态的项由调用
/// 方不放进列里，不摆一个空白胶囊。
const double kRailWidth = 214;

/// 行与行的圆角：整列同一个值，改就全改。
const double kRailRadius = 14;

/// 行距：整列同一个值。
const double kRailGap = 8;

/// 一条定宽的读数列。
///
/// 宽度由调用方算（要减去右侧工具列与安全区），这里只保证**所有行一样宽** ——
/// 宽度参差不齐正是原先那一列显得乱的主因。
class MapRail extends StatelessWidget {
  final double width;
  final List<Widget> children;
  const MapRail({super.key, this.width = kRailWidth, required this.children});

  @override
  Widget build(BuildContext context) {
    final kids = <Widget>[];
    for (final w in children) {
      if (kids.isNotEmpty) kids.add(const SizedBox(height: kRailGap));
      kids.add(w);
    }
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: kids,
      ),
    );
  }
}

/// 列里的一行：图标 + 读数 + 右端可选的东西（友台数 / 关闭 / 箭头）。
///
/// 可点的行自己带 `ClickCursor` 与 `HitTestBehavior.opaque` —— 底色画在
/// `BoxDecoration` 上时 `deferToChild` 会把命中区缩到图标那 15px 里，按行尾
/// 没反应（与 `map_page._toolBtn` 是同一个坑）。
class MapRailItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Widget label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? tooltip;

  /// 实心底（选点横幅用的橙底）；不传就是常规的磨砂浅底。
  final Color? fill;

  /// 描边色；不传就没有描边。
  final Color? borderColor;

  const MapRailItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
    this.onTap,
    this.tooltip,
    this.fill,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget body = MaterialSurface(
      radius: kRailRadius,
      blurSigma: C.chipBlur,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
        decoration: BoxDecoration(
          color: fill ?? C.chipFill,
          borderRadius: BorderRadius.circular(kRailRadius),
          border: borderColor == null ? null : Border.all(color: borderColor!),
          boxShadow: elev1(),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 8),
            Expanded(child: label),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing!,
            ],
          ],
        ),
      ),
    );
    if (onTap != null) {
      body = ClickCursor(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: body,
        ),
      );
    }
    if (tooltip == null) return body;
    return Tooltip(message: tooltip!, child: body);
  }
}
