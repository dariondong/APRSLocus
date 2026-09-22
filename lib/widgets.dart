import 'package:flutter/material.dart';

import 'theme.dart';
import 'material.dart';
import 'models.dart';
import 'l10n/app_localizations.dart';

/// 界面本地化便捷别名
typedef S = AppLocalizations;

String _aprsSymbolKey(String symbol) => switch (symbol) {
  '>' => 'car',
  '!' => 'police',
  '"' => 'person',
  '#' => 'digitalRepeater',
  r'$' => 'telephone',
  '%' => 'dxCluster',
  '&' => 'hfGateway',
  "'" => 'smallAircraft',
  '(' => 'mobileSatellite',
  ')' => 'disabled',
  '*' => 'snowmobile',
  '+' => 'redCross',
  ',' => 'scouts',
  '-' => 'house',
  '.' => 'redX',
  '/' => 'redDot',
  ':' => 'fire',
  ';' => 'campground',
  '<' => 'motorcycle',
  '=' => 'train',
  '?' => 'fileServer',
  '@' => 'hurricane',
  '[' => 'person',
  '\\' => 'dfTriangle',
  ']' => 'postOffice',
  '^' => 'largeAircraft',
  '_' => 'weatherStation',
  '`' => 'satelliteDish',
  'a' => 'ambulance',
  'b' => 'bicycle',
  'c' => 'commandPost',
  'd' => 'fireStation',
  'e' => 'horse',
  'f' => 'fireTruck',
  'g' => 'glider',
  'h' => 'hospital',
  'i' => 'fmoStation',
  'j' => 'jeep',
  'k' => 'truck',
  'l' => 'laptop',
  'm' => 'micERepeater',
  'n' => 'node',
  'o' => 'emergencyOps',
  'p' => 'dog',
  'q' => 'gridSquare',
  'r' => 'repeaterTower',
  's' => 'boat',
  't' => 'truckStop',
  'u' => 'semiTrailer',
  'v' => 'van',
  'w' => 'waterStation',
  'y' => 'yagi',
  'z' => 'shelter',
  'R' => 'rv',
  'W' => 'weatherSymbol',
  'O' => 'balloon',
  'U' => 'bus',
  'S' => 'shuttle',
  'P' => 'policeCar',
  'Y' => 'sailboat',
  'K' => 'school',
  'H' => 'lodging',
  'J' => 'hotel',
  _ => 'other',
};

String localizedAprsSymbolName(BuildContext context, String symbol) =>
    S.of(context).aprsSymbolName(_aprsSymbolKey(symbol));

String localizedSymbolCategory(BuildContext context, String category) {
  final key = switch (category) {
    '车辆 / 交通' => 'vehicles',
    '建筑 / 设施' => 'facilities',
    '气象 / 自然' => 'weatherNature',
    '应急救援' => 'emergencyRescue',
    '飞行 / 水域' => 'airWater',
    '通信 / 其他' => 'communications',
    _ => 'other',
  };
  return S.of(context).symbolCategoryName(key);
}

String localizedStatusLabel(BuildContext context, St status) =>
    switch (status) {
      St.online => S.of(context).online,
      St.moving => S.of(context).moving,
      St.stopped => S.of(context).stationary,
      St.emergency => S.of(context).emergency,
      St.offline => S.of(context).offline,
    };

String localizedLastSeen(BuildContext context, Station station) {
  final d = DateTime.now().difference(station.lastHeard);
  if (d.inSeconds < 60) return S.of(context).secondsAgo(d.inSeconds);
  if (d.inMinutes < 60) return S.of(context).minutesAgo(d.inMinutes);
  if (d.inHours < 24) return S.of(context).hoursAgo(d.inHours);
  if (d.inDays < 7) return S.of(context).daysAgo(d.inDays);
  return '${station.lastHeard.year}-${station.lastHeard.month.toString().padLeft(2, '0')}';
}

String localizedLocationStatus(BuildContext context, String value) {
  final s = S.of(context);
  if (value == '未定位') return s.locationNotFixed;
  if (value == '模拟位置') return s.simulatedLocation;
  if (value == '已保存位置') return s.savedLocation;
  if (value == '模拟位置 · 后台保活') return s.simulatedKeepAlive;
  if (value == '定位失败') return s.locationFailed;
  if (value == '定位已停止') return s.locationStopped;
  if (value == '已定位') return s.locationFixed;
  // 静止防抖判定为静止（见 lib/pos_quality.dart 的 SelfFixFilter）。
  // 这里是**白名单**：新增一个状态串却忘在这里登记，界面就会直接漏出中文
  // —— 这个坑踩过（`模拟位置 · 后台保活`），所以 tool/check_pos_quality.py
  // 会把「所有 locStatus 字面量都已登记」当成断言在 CI 里查。
  if (value == '静止') return s.locationStill;
  // 粗定位：来源是基站/Wi-Fi（或被动定位），误差常在几百米量级。
  // 必须和「已定位」在界面上可区分 —— 否则用户会以为 GPS 明明很准却画歪了。
  if (value == '网络定位（粗）') return s.locationCoarse;
  if (value == '请授予定位权限…') return s.locationPermission;
  if (value == 'GPS 定位中…') return s.gpsLocating;
  if (value == 'Web 平台暂不支持自动定位，请手动输入坐标') {
    return s.webLocationUnsupported;
  }
  final stream = RegExp(r'^定位流异常:\s*(.*)$').firstMatch(value);
  if (stream != null) return s.locationStreamError(stream.group(1)!);
  final init = RegExp(r'^定位初始化失败:\s*(.*)$').firstMatch(value);
  if (init != null) return s.locationInitError(init.group(1)!);
  return value;
}

// 说明：原 `localizedNextBeaconValue()` 已移除。
// 它属于「状态层返回中文串 → 此处映射回本地化文案」的旧模式；
// 现 AppState.nextBeaconIn 已按 locale 自行本地化（并新增结构化的
// AppState.beaconPhase / beaconSecondsLeft），故此映射不再需要。

/// 连接状态说明。
///
/// `AppState.connInfo` 现在由状态层直接按当前语言生成（见 ConnStatus），
/// 因此这里不再需要「拿中文当哨兵再映射」的老做法 —— 那种写法漏登记
/// 一个新状态就会让界面在所有语言下漏出中文。
/// 保留此函数作为调用点，避免各页面重复判断。
String localizedConnectionInfo(BuildContext context, String value) => value;

String localizedMapTypeLabel(BuildContext context, String name) =>
    switch (name) {
      'gaode' => S.of(context).mapTypeAmap,
      'gaode_sat' => S.of(context).mapTypeAmapSatellite,
      'vector' => S.of(context).mapTypeVector,
      'vector_positron' => S.of(context).mapTypeCartoPositron,
      'carto' => S.of(context).mapTypeCarto,
      'carto_dark' => S.of(context).mapTypeCartoDark,
      'carto_voyager' => S.of(context).mapTypeCartoVoyager,
      'osm' => S.of(context).mapTypeOsm,
      'osm_hot' => S.of(context).mapTypeOsmHot,
      'open_topo' => S.of(context).mapTypeOpenTopo,
      'esri_street' => S.of(context).mapTypeEsriStreet,
      'esri_sat' => S.of(context).mapTypeEsriSat,
      _ => name,
    };

String localizedLogLevelName(BuildContext context, LogLevel level) =>
    switch (level) {
      LogLevel.debug => S.of(context).debugLabel,
      LogLevel.info => S.of(context).information,
      LogLevel.warn => S.of(context).warning,
      LogLevel.error => S.of(context).errorLabel,
    };

String localizedSystemMessage(BuildContext context, String value) {
  var m = RegExp(r'^(.+) 加入了群聊$').firstMatch(value);
  if (m != null) return S.of(context).systemMemberJoined(m.group(1)!);
  m = RegExp(r'^(.+) 离开了群聊$').firstMatch(value);
  if (m != null) return S.of(context).systemMemberLeft(m.group(1)!);
  m = RegExp(r'^(.+) 拒绝了邀请$').firstMatch(value);
  if (m != null) return S.of(context).systemInviteDeclined(m.group(1)!);
  m = RegExp(r'^(.+) 已加入群组$').firstMatch(value);
  if (m != null) return S.of(context).systemMemberJoined(m.group(1)!);
  m = RegExp(r'^(.+) 已退出群组$').firstMatch(value);
  if (m != null) return S.of(context).systemMemberLeft(m.group(1)!);
  return value;
}

/// Soft elevated card
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 16,
    this.onTap,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: padding,
      decoration: cardDeco(bg: color, r: radius),
      child: onTap != null
          ? InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: onTap,
              child: child,
            )
          : child,
    );
  }
}

/// Small stat box with icon
class StatBox extends StatelessWidget {
  final String label, value;
  final Color color, bg;
  final IconData icon;
  const StatBox({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: ts(16, c: color, w: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: ts(9, c: C.slate, w: FontWeight.w600, ls: 0.8),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chip
class FilterChip2 extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const FilterChip2({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : C.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.4) : C.border,
          ),
        ),
        child: Text(
          label,
          style: ts(
            12,
            c: selected ? color : C.slate,
            w: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Status badge
class StatusBadge extends StatelessWidget {
  final St status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        localizedStatusLabel(context, status),
        style: ts(9, c: c, w: FontWeight.w700, ls: 0.5),
      ),
    );
  }
}

/// APRS symbol badge (icon in tinted box)
class SymbolBadge extends StatelessWidget {
  final Station station;
  final double size;
  const SymbolBadge(this.station, {super.key, this.size = 44});
  @override
  Widget build(BuildContext context) {
    final c = station.color;
    // 优先使用 APRS 标准符号 PNG（存在才加载），缺失回退 Material 图标
    final png = AprsSym.iconAsset(station.symbolTable, station.symbol);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: png != null
          ? Image.asset(
              png,
              width: size * 0.6,
              height: size * 0.6,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(station.icon, color: c, size: size * 0.5),
            )
          : Icon(station.icon, color: c, size: size * 0.5),
    );
  }
}

/// KV row used in detail pages
class KV extends StatelessWidget {
  final String label, value;
  final IconData? icon;
  final Color? valueColor;
  const KV(this.label, this.value, {super.key, this.icon, this.valueColor});
  @override
  Widget build(BuildContext context) {
    // 走 LabelValueRow：值常常是用户数据（呼号、设备名、距离、时间），
    // 而原来的 `Text + Spacer + Text` 两端都是自然宽 —— 值一长就整行溢出。
    return LabelValueRow(
      label,
      value,
      labelStyle: ts(12, c: C.slate),
      valueStyle: ts(12, c: valueColor ?? C.ink, w: FontWeight.w600),
      leading: icon == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(icon, size: 14, color: C.grey),
            ),
    );
  }
}

/// Section card with title
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Widget? trailing;
  final List<Widget> children;
  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.trailing,
    required this.children,
  });
  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: ts(13, c: color, w: FontWeight.w700)),
                      if (subtitle != null) ...[
                        SizedBox(height: 2),
                        Text(subtitle!,
                            style: ts(10, c: C.slate),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
          Divider(height: 1, color: C.border),
          ...children,
        ],
      ),
    );
  }
}

/// 「标签 …… 值」的行式布局：标签最多占 [maxLabelFactor] 的比例（超出省略号），
/// 值吃掉剩余全部宽度并右对齐，**两端都不会溢出**。
///
/// 为什么不用 `Flexible(标签) + Expanded(值)` 这个常见写法：Row 的弹性空间是
/// **按 flex 权重一次分配**的（`RenderFlex._computeSizes` 里 `spacePerFlex` 只算
/// 一次，宽松子项没用完的那份不会再分给兄弟）—— 于是标签短的时候，值只拿到自己
/// 那一份（约一半），右边留一截空隙，看起来「值没贴右」。这里让标签走**限宽的自然
/// 宽**、值走 `Expanded`：只有一个弹性子项时，它拿到的就是全部剩余，行为确定。
///
/// 为什么要 Tooltip：省略号一旦出现，用户总得有个办法看到全文。这两端本来就不
/// 可点（设置项只读），加 Tooltip 不会和点击手势打架。
class LabelValueRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  /// 标签前的小图标（不参与弹性分配）
  final Widget? leading;

  /// 标签最多占的宽度比例。0.42 能容下现有各语言里最长的几个标签
  /// （「射频信标」/「Bound device」），又把大头留给值 —— 而**值**才是长的
  /// 那个（设备名、呼号、服务器地址）。
  final double maxLabelFactor;
  final double gap;

  const LabelValueRow(
    this.label,
    this.value, {
    super.key,
    this.labelStyle,
    this.valueStyle,
    this.leading,
    this.maxLabelFactor = 0.42,
    this.gap = 10,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final maxLabel = (c.maxWidth * maxLabelFactor).clamp(0.0, c.maxWidth);
        return Row(
          children: [
            if (leading != null) leading!,
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLabel),
              child: _tip(
                label,
                Text(
                  label,
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _tip(
                value,
                Text(
                  value,
                  style: valueStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 空串不加 Tooltip：否则会弹出一个空白提示框，比不加更难理解
  Widget _tip(String msg, Widget child) =>
      msg.trim().isEmpty ? child : Tooltip(message: msg, child: child);
}

/// Row in settings
class SettingRow extends StatelessWidget {
  final String label, value;
  const SettingRow(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
      ),
      child: LabelValueRow(
        label,
        value,
        labelStyle: ts(12, c: C.slate),
        valueStyle: ts(12, w: FontWeight.w500),
      ),
    );
  }
}

/// Round small button
class RoundIconBtn extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  final String? tooltip;
  const RoundIconBtn(
    this.icon, {
    super.key,
    this.color,
    required this.onTap,
    this.tooltip,
  });
  @override
  Widget build(BuildContext context) {
    // 圆形按钮基本都是**压在地图/列表上**的浮层：材质开启时给它真模糊，
    // 但用更小的半径 —— 38px 的按钮上套全屏级别的模糊，边缘会糊成一团灰，
    // 看起来像按钮没画好，而不是像磨砂。
    final btn = GestureDetector(
      onTap: onTap,
      child: MaterialSurface(
        radius: 12,
        blurSigma: C.chipBlur,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: chipTint(C.white),
            borderRadius: BorderRadius.circular(12),
            // 同上：投影负责分层，描边去掉（圆形工具钮常年压在地图上）
            boxShadow: elev1(),
          ),
          child: Icon(icon, color: color ?? C.slate, size: 20),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

/// ─── APRSlocus Logo ───

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 88});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A5CFF), Color(0xFF003D99)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: CustomPaint(
        painter: _LogoPainter(),
        child: SizedBox.square(dimension: size),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width / 512;

    // 中心实心圆
    canvas.drawCircle(
      Offset(cx, cy),
      46 * scale,
      Paint()..color = Colors.white,
    );

    // 三层同心圆环
    for (final (r, w, a) in [
      (84.0, 16.0, 1.0),
      (124.0, 14.0, 1.0),
      (162.0, 12.0, 0.65),
    ]) {
      canvas.drawCircle(
        Offset(cx, cy),
        r * scale,
        Paint()
          ..color = Colors.white.withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * scale,
      );
    }

    // 左右信号点
    for (final dx in [-144.0, 144.0]) {
      canvas.drawCircle(
        Offset(cx + dx * scale, cy),
        12 * scale,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 真实 APRS 官方符号图标：优先加载官方符号表 PNG（透明底彩色），
/// 资源缺失/超出范围回退 Material 图标；offline 等场景可整图灰度弱化。
class AprsSymbolImage extends StatelessWidget {
  final String symbol; // 符号码，如 '>' / 'k'
  final String symbolTable; // 符号表字符，默认主表 '/'
  final double size;
  final bool grayscale;
  const AprsSymbolImage(
    this.symbol,
    this.symbolTable, {
    super.key,
    this.size = 20,
    this.grayscale = false,
  });

  /// 灰度滤镜：保留透明度，只把彩色像素去饱和，用于离线台站弱化
  static const List<double> _grayscale = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final table = symbolTable.isEmpty ? '/' : symbolTable;
    final png = AprsSym.iconAsset(table, symbol);
    final fallback = Icon(AprsSym.icon(symbol), size: size);
    Widget child;
    if (png == null) {
      child = fallback;
    } else {
      child = Image.asset(
        png,
        width: size,
        height: size,
        fit: BoxFit.contain,
        // 地图标记大量同 asset 复用；小图按固定像素解码降内存
        cacheWidth: (size * 3).clamp(32, 128).round(),
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    if (!grayscale) return child;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_grayscale),
      child: child,
    );
  }
}
