import 'package:flutter/material.dart';

import 'theme.dart';
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
  if (value == '定位失败') return s.locationFailed;
  if (value == '定位已停止') return s.locationStopped;
  if (value == '已定位') return s.locationFixed;
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

String localizedNextBeaconValue(BuildContext context, String value) {
  if (value == '已关闭') return S.of(context).beaconDisabled;
  if (value == '等待定位') return S.of(context).waitingForLocation;
  if (value == '即将') return S.of(context).imminent;
  return value;
}

String localizedConnectionInfo(BuildContext context, String value) {
  final s = S.of(context);
  if (value == '未连接 · 点击播放按钮连接 APRS-IS') return s.connTapToConnect;
  if (value == '未连接 · 已手动断开') return s.connManuallyDisconnected;
  if (value == '未连接 · 位置已上报(模拟)') return s.connDemoBeacon;
  if (value == '已连接 · 未验证（passcode 可能错误）') {
    return s.connPasscodeInvalid;
  }
  var m = RegExp(r'^连接已断开 · (\d+)秒后自动重连…$').firstMatch(value);
  if (m != null) return s.connAutoReconnect(int.parse(m.group(1)!));
  m = RegExp(r'^正在连接 (.+)…$').firstMatch(value);
  if (m != null) return s.connConnectingTarget(m.group(1)!);
  m = RegExp(r'^已连接 · (.+) 在线$').firstMatch(value);
  if (m != null) return s.connOnline(m.group(1)!);
  m = RegExp(r'^连接失败 · (\d+)s 后重试…$').firstMatch(value);
  if (m != null) return s.connRetry(int.parse(m.group(1)!));
  m = RegExp(r'^已连接 · 位置已上传 \((.+)\)$').firstMatch(value);
  if (m != null) return s.connPositionSent(m.group(1)!);
  return value;
}

String localizedMapTypeLabel(BuildContext context, String name) =>
    switch (name) {
      'gaode' => S.of(context).mapTypeAmap,
      'gaode_sat' => S.of(context).mapTypeAmapSatellite,
      'vector' => S.of(context).mapTypeVector,
      'carto' => 'Carto 浅色',
      'carto_dark' => 'Carto 深色',
      'carto_voyager' => 'Carto 航行者',
      'osm' => 'OSM 标准',
      'osm_hot' => 'OSM 人道',
      'open_topo' => 'OpenTopo 地形',
      'esri_street' => 'Esri 街道',
      'esri_sat' => 'Esri 影像',
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
              borderRadius: BorderRadius.circular(10),
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
                  style: ts(18, c: color, w: FontWeight.w800),
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
          borderRadius: BorderRadius.circular(20),
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
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: C.grey),
          SizedBox(width: 6),
        ],
        Text(label, style: ts(12, c: C.slate)),
        Spacer(),
        Text(
          value,
          style: ts(12, c: valueColor ?? C.ink, w: FontWeight.w600),
        ),
      ],
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
                    borderRadius: BorderRadius.circular(10),
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
      child: Row(
        children: [
          Text(label, style: ts(12, c: C.slate)),
          const Spacer(),
          Text(value, style: ts(12, w: FontWeight.w500)),
        ],
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
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: softShadow(blur: 12, y: 3, alpha: 0.08),
          border: Border.all(color: C.border),
        ),
        child: Icon(icon, color: color ?? C.slate, size: 20),
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
