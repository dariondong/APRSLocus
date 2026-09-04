import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

enum St { online, moving, stopped, emergency, offline }

class Station {
  final String call;
  String symbol;
  String symbolTable; // APRS 符号表字符（默认 '/'）
  final String alias;
  double lat, lng;
  double? alt;
  double? speed, course;
  String? comment;
  DateTime lastHeard;
  St status;
  List<TrackPt> track;
  String? wx;
  Map<String, String>? fmo;
  Map<String, String>? aprslocus; // APRSlocus 专属信息（版本等）
  String? path; // 最近一次数据包的转发路径（如 WIDE1-1,WIDE2-1）
  bool favorite;
  bool manual; // 手动添加的联系人
  /// 速度/高度遥测历史（内存态，与 track 一致不持久化）
  List<TelemetryPt> telemetry;

  Station({
    required this.call,
    required this.symbol,
    this.symbolTable = '/',
    this.alias = '',
    required this.lat,
    required this.lng,
    this.alt,
    this.speed,
    this.course,
    this.comment,
    required this.lastHeard,
    this.status = St.online,
    this.track = const [],
    this.telemetry = const [],
    this.wx,
    this.fmo,
    this.aprslocus,
    this.path,
    this.favorite = false,
    this.manual = false,
  });

  String get lastSeen {
    final d = DateTime.now().difference(lastHeard);
    if (d.inSeconds < 60) return '${d.inSeconds}秒前';
    if (d.inMinutes < 60) return '${d.inMinutes}分前';
    if (d.inHours < 24) return '${d.inHours}小时前';
    if (d.inDays < 7) return '${d.inDays}天前';
    return '${lastHeard.year}-${lastHeard.month.toString().padLeft(2, '0')}';
  }

  /// 有效状态：5 分钟内上报为在线（保留移动/静止），否则为离线
  St get effectiveStatus {
    final d = DateTime.now().difference(lastHeard);
    if (d.inMinutes >= 5) return St.offline;
    // 5 分钟内：保留移动/静止；原本在线/其他归为在线
    if (status == St.moving) return St.moving;
    if (status == St.stopped) return St.stopped;
    return St.online;
  }

  /// 基础呼号（去掉 -SSID 后缀）
  String get baseCall =>
      call.contains('-') ? call.substring(0, call.indexOf('-')) : call;

  String get speedStr =>
      speed != null ? '${speed!.toStringAsFixed(0)} km/h' : '--';
  String get altStr => alt != null ? '${alt!.toStringAsFixed(0)} m' : '--';
  String get posStr => '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  String get grid => maidenhead(lat, lng);
  IconData get icon => AprsSym.icon(symbol);
  String get typeName => AprsSym.name(symbol);
  Color get color => statusColor(status);

  /// 是否为 APRSlocus 同款软件台站（备注/呼号含关键字，与筛选一致）
  bool get isAprslocusStation =>
      (comment?.toLowerCase().contains('aprslocus') ?? false) ||
      call.toUpperCase().contains('APRSLOCUS');

  /// 距离（公里）
  double distKm(double flat, double flng) => haversine(lat, lng, flat, flng);

  /// 从 (flat,flng) 看向本台的方位角（0-360°）
  double bearingFrom(double flat, double flng) {
    final phi1 = flat * math.pi / 180;
    final phi2 = lat * math.pi / 180;
    final dLng = (lng - flng) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(phi2);
    final x =
        math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLng);
    final brg = math.atan2(y, x) * 180 / math.pi;
    return (brg + 360) % 360;
  }

  String bearingStr(double? flat, double? flng) {
    if (flat == null || flng == null) return '--';
    return '${bearingFrom(flat, flng).toStringAsFixed(0)}°';
  }

  /// 类型分组（用于筛选）——基于业务字段而非图标
  /// FMO：看已解析的 fmo 结构化字段（收包时按 APFMO/FMO-V4 等识别填充），
  /// 图标符号仅作展示；APRSlocus 同款走独立字段 + 独立过滤。
  TypeGroup get typeGroup {
    // 真正的 FMO：已解析出 FMO 结构化字段，或符号明确为 FMO（主表 i / 反斜杠表 I）
    final hasFmoData = (fmo != null && fmo!.isNotEmpty);
    final isFmoSymbol =
        symbol == 'i' || (symbolTable == '\\' && symbol == 'I');
    if (hasFmoData || isFmoSymbol) return TypeGroup.fmo;
    switch (symbol) {
      case '>':
      case '<':
      case 'c':
      case 'k':
      case 'x':
        return TypeGroup.mobile;
      case '!':
      case '/':
      case '_':
        return TypeGroup.fixed;
      case 'R':
      case '#':
        return TypeGroup.infra;
      case 'W':
      case 'w':
        return TypeGroup.wx;
      default:
        return TypeGroup.other;
    }
  }

  String get typeGroupName {
    switch (typeGroup) {
      case TypeGroup.mobile:
        return '移动';
      case TypeGroup.fixed:
        return '固定';
      case TypeGroup.infra:
        return '中继';
      case TypeGroup.wx:
        return '气象';
      case TypeGroup.fmo:
        return 'FMO';
      case TypeGroup.other:
        return '其他';
    }
  }
}

enum TypeGroup { mobile, fixed, infra, wx, fmo, other }

class TrackPt {
  final double lat, lng;
  final DateTime time;
  const TrackPt(this.lat, this.lng, this.time);
}

/// 台站遥测采样点：速度/高度历史（用于详情页变化图表）
class TelemetryPt {
  final DateTime time;
  final double? speed; // km/h
  final double? alt; // 米
  const TelemetryPt(this.time, {this.speed, this.alt});
}

class AprsMsg {
  final String from, to, text;
  final DateTime time;
  final bool sent;
  final String? id;
  final String? groupId; // 群聊ID（可选）
  final bool system; // 系统消息（如"XX 已加入群聊"）
  bool acked;
  AprsMsg(
    this.from,
    this.to,
    this.text,
    this.time, {
    this.sent = false,
    this.id,
    this.acked = false,
    this.groupId,
    this.system = false,
  });

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'text': text,
    'time': time.millisecondsSinceEpoch,
    'sent': sent,
    'id': id,
    'acked': acked,
    if (groupId != null) 'groupId': groupId,
    if (system) 'system': system,
  };

  factory AprsMsg.fromJson(Map<String, dynamic> j) => AprsMsg(
    j['from'] as String,
    j['to'] as String,
    j['text'] as String,
    DateTime.fromMillisecondsSinceEpoch(j['time'] as int),
    sent: j['sent'] as bool? ?? false,
    id: j['id'] as String?,
    acked: j['acked'] as bool? ?? false,
    groupId: j['groupId'] as String?,
    system: j['system'] as bool? ?? false,
  );
}

/// 群成员状态
enum GroupMemberStatus { pending, joined, declined, left, timeout, blocked }

/// 群聊
class ChatGroup {
  final String id;
  String name;
  final String groupCall; // 群呼号，如 BG7LZQ-G1
  final String owner; // 群主呼号
  final DateTime createdAt;

  /// 期望成员：群主想邀请的人 → 各自状态
  final Map<String, GroupMemberStatus> memberStatus;

  /// 活跃成员：从群聊消息中自动提取（谁在群里发过消息）
  final Set<String> activeMembers;

  /// 屏蔽列表：群主不想看到的人
  final Set<String> blockedMembers;

  ChatGroup({
    required this.id,
    required this.name,
    required this.groupCall,
    required this.owner,
    DateTime? createdAt,
    Map<String, GroupMemberStatus>? memberStatus,
    Set<String>? activeMembers,
    Set<String>? blockedMembers,
  }) : createdAt = createdAt ?? DateTime.now(),
       memberStatus = memberStatus ?? {},
       activeMembers = activeMembers ?? {},
       blockedMembers = blockedMembers ?? {};

  /// 获取所有成员（含已加入、待确认、拒绝、离开等所有状态）
  /// 用于成员管理展示；聊天接收则用 recipients（排除 left/declined/blocked）
  Set<String> get allMemberCalls => {...memberStatus.keys, ...activeMembers};

  /// 获取所有已加入的成员（joined 或 active）
  Set<String> get confirmedMembers => {
    ...memberStatus.entries
        .where(
          (e) =>
              e.value == GroupMemberStatus.joined ||
              e.value == GroupMemberStatus.pending,
        )
        .map((e) => e.key),
    ...activeMembers,
  };

  /// 获取所有需要接收消息的成员（joined + active，排除 blocked/left/declined）
  Set<String> get recipients => {
    ...memberStatus.entries
        .where((e) => e.value == GroupMemberStatus.joined)
        .map((e) => e.key),
    ...activeMembers,
  }.where((m) => !blockedMembers.contains(m)).toSet();

  /// 是否是群主
  bool isOwner(String call) => call.toUpperCase() == owner.toUpperCase();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'groupCall': groupCall,
    'owner': owner,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'memberStatus': memberStatus.map((k, v) => MapEntry(k, v.index)),
    'activeMembers': activeMembers.toList(),
    'blockedMembers': blockedMembers.toList(),
  };

  factory ChatGroup.fromJson(Map<String, dynamic> j) => ChatGroup(
    id: j['id'] as String,
    name: j['name'] as String,
    groupCall: j['groupCall'] as String,
    owner: j['owner'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
    memberStatus:
        (j['memberStatus'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, GroupMemberStatus.values[v as int]),
        ) ??
        {},
    activeMembers: Set<String>.from(j['activeMembers'] as List? ?? []),
    blockedMembers: Set<String>.from(j['blockedMembers'] as List? ?? []),
  );
}

class Packet {
  final String raw, src, dest, type;
  final DateTime time;
  final String? info;
  Packet(this.raw, this.src, this.dest, this.type, this.time, {this.info});
}

enum LogLevel { debug, info, warn, error }

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String source;
  final String message;
  const LogEntry(this.time, this.level, this.source, this.message);
}

String logLevelName(LogLevel l) {
  switch (l) {
    case LogLevel.debug:
      return '调试';
    case LogLevel.info:
      return '信息';
    case LogLevel.warn:
      return '警告';
    case LogLevel.error:
      return '错误';
  }
}

Color logLevelColor(LogLevel l) {
  switch (l) {
    case LogLevel.debug:
      return C.grey;
    case LogLevel.info:
      return C.blue;
    case LogLevel.warn:
      return C.yellow;
    case LogLevel.error:
      return C.red;
  }
}

Color statusColor(St st) {
  switch (st) {
    case St.online:
      return C.green;
    case St.moving:
      return C.blue;
    case St.stopped:
      return C.yellow;
    case St.emergency:
      return C.red;
    case St.offline:
      return C.grey;
  }
}

String statusLabel(St st) {
  switch (st) {
    case St.online:
      return '在线';
    case St.moving:
      return '移动';
    case St.stopped:
      return '静止';
    case St.emergency:
      return '在线';
    case St.offline:
      return '离线';
  }
}

class AprsSym {
  // 中文含义与 APRS 官方符号表一致（主表 '/' 下）
  static const _map = <String, (IconData, String)>{
    '>': (Icons.directions_car_rounded, '汽车'),
    '!': (Icons.account_balance_rounded, '警局'),
    '"': (Icons.person_rounded, '人'),
    '#': (Icons.cast_connected_rounded, '数字中继'),
    '\$': (Icons.call_rounded, '电话'),
    '%': (Icons.router_rounded, 'DX 集群'),
    '&': (Icons.satellite_alt_rounded, 'HF 网关'),
    "'": (Icons.airplanemode_active_rounded, '小型飞机'),
    '(': (Icons.satellite_alt_rounded, '移动卫星'),
    ')': (Icons.accessible_rounded, '残障'),
    '*': (Icons.snowshoeing_rounded, '雪地摩托'),
    '+': (Icons.medical_services_rounded, '红十字'),
    ',': (Icons.volunteer_activism_rounded, '童子军'),
    '-': (Icons.home_rounded, '房屋'),
    '.': (Icons.close_rounded, '红叉'),
    '/': (Icons.circle_rounded, '红点'),
    ':': (Icons.local_fire_department_rounded, '火警'),
    ';': (Icons.park_rounded, '露营'),
    '<': (Icons.two_wheeler_rounded, '摩托'),
    '=': (Icons.train_rounded, '火车'),
    '?': (Icons.dns_rounded, '文件服务器'),
    '@': (Icons.cyclone_rounded, '飓风'),
    '[': (Icons.man_rounded, '人'),
    '\\': (Icons.change_history_rounded, 'DF 三角'),
    ']': (Icons.local_post_office_rounded, '邮局'),
    '^': (Icons.flight_rounded, '大型飞机'),
    '_': (Icons.cloud_rounded, '气象站'),
    '`': (Icons.satellite_alt_rounded, '卫星天线'),
    'a': (Icons.local_hospital_rounded, '救护车'),
    'b': (Icons.directions_bike_rounded, '自行车'),
    'c': (Icons.sports_esports_rounded, '指挥中心'),
    'd': (Icons.local_fire_department_rounded, '消防站'),
    'e': (Icons.pets_rounded, '骑马'),
    'f': (Icons.fire_truck_rounded, '消防车'),
    'g': (Icons.flight_rounded, '滑翔机'),
    'h': (Icons.local_hospital_rounded, '医院'),
    'i': (Icons.radio_rounded, 'FMO 台站'),
    'j': (Icons.directions_car_rounded, '吉普'),
    'k': (Icons.local_shipping_rounded, '卡车'),
    'l': (Icons.laptop_rounded, '笔记本'),
    'm': (Icons.cell_tower_rounded, 'Mic-E 中继'),
    'n': (Icons.track_changes_rounded, '节点'),
    'o': (Icons.apartment_rounded, '应急中心'),
    'p': (Icons.pets_rounded, '狗'),
    'q': (Icons.grid_4x4_rounded, '网格'),
    'r': (Icons.cell_tower_rounded, '中继塔'),
    's': (Icons.directions_boat_rounded, '船'),
    't': (Icons.local_shipping_rounded, '卡车停靠站'),
    'u': (Icons.local_shipping_rounded, '半挂车'),
    'v': (Icons.airport_shuttle_rounded, '面包车'),
    'w': (Icons.water_drop_rounded, '供水站'),
    'x': (Icons.terminal_rounded, 'X/Unix'),
    'y': (Icons.cell_tower_rounded, '八木天线屋'),
    'z': (Icons.emergency_rounded, '避难所'),
    'R': (Icons.airport_shuttle_rounded, '房车'),
    'W': (Icons.cloud_rounded, '气象台'),
    'O': (Icons.radio_rounded, '气球'),
    'U': (Icons.directions_bus_rounded, '公交'),
    'T': (Icons.videocam_rounded, 'SSTV'),
    'S': (Icons.rocket_launch_rounded, '航天飞机'),
    'P': (Icons.local_police_rounded, '警车'),
    'Y': (Icons.sailing_rounded, '帆船'),
  };

  static IconData icon(String sym) => _map[sym]?.$1 ?? Icons.place_rounded;
  static String name(String sym) => _map[sym]?.$2 ?? '未知($sym)';

  /// 判断 table+code 是否在官方 37 个符号表范围内（PNG 已全部下载）
  static bool isValidSymbol(String table, String sym) {
    if (table.isEmpty || sym.isEmpty) return false;
    final t = table.codeUnitAt(0);
    final c = sym.codeUnitAt(0);
    final okTable =
        t == 0x2f ||
        t == 0x5c ||
        (t >= 0x30 && t <= 0x39) ||
        (t >= 0x41 && t <= 0x5a);
    return okTable && c >= 0x21 && c <= 0x7e;
  }

  /// 返回 APRS 符号 PNG 的 asset 路径。
  /// 文件名格式 `<hex(表)><hex(码)>.png`，如 `2f21.png`（/ + !）、`4f23.png`（O + #）。
  /// 超出官方范围返回 null（调用方回退到 Material 图标）。
  static String? iconAsset(String table, String sym) {
    if (!isValidSymbol(table, sym)) return null;
    final t = table.codeUnitAt(0);
    final c = sym.codeUnitAt(0);
    final name = '${t.toRadixString(16)}${c.toRadixString(16)}.png';
    return 'assets/aprs_syms/$name';
  }
}

/// Maidenhead 网格定位（默认 6 位，支持 4/6/8 位）
String maidenhead(double lat, double lng, [int precision = 6]) {
  var lngW = lng;
  if (lngW < -180) lngW += 360;
  if (lngW > 180) lngW -= 360;
  final buf = StringBuffer();
  // Field：经度每 20°，纬度每 10°
  buf.writeCharCode(65 + ((lngW + 180) / 20).floor().clamp(0, 17));
  buf.writeCharCode(65 + ((lat + 90) / 10).floor().clamp(0, 17));
  if (precision >= 4) {
    // Square：Field 内经度每 2°、纬度每 1°
    buf.writeCharCode(48 + (((lngW + 180) % 20) / 2).floor());
    buf.writeCharCode(48 + ((lat + 90) % 10).floor());
  }
  if (precision >= 6) {
    // Subsquare：Square 内经度每 5′、纬度每 2.5′
    buf.writeCharCode(97 + (((lngW + 180) % 2) * 12).floor());
    buf.writeCharCode(97 + (((lat + 90) % 1) * 24).floor());
  }
  if (precision >= 8) {
    // Extended：Subsquare 内经度每 30″、纬度每 15″
    buf.writeCharCode(48 + ((((lngW + 180) % (1 / 12)) * 240).floor() % 10));
    buf.writeCharCode(48 + ((((lat + 90) % (1 / 24)) * 480).floor() % 10));
  }
  return buf.toString();
}

double haversine(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double deg) => deg * math.pi / 180.0;
