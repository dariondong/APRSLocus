import 'dart:async';

import 'package:flutter/material.dart';

import 'aprs_device.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';

/// ─── 统计面板 ───
/// 与「台站列表」在同一页内切换（同消息页瀑布流/会话的做法），
/// 用于全方位了解当前 APRS 接收概况：收包量、台站状态/类型/设备分布、
/// 大网格（Maidenhead Field）台站数量与排序等。
class StationStatsPanel extends StatefulWidget {
  final AppState state;
  const StationStatsPanel({super.key, required this.state});

  @override
  State<StationStatsPanel> createState() => _StationStatsPanelState();
}

/// 单个分布条目（名称 + 数量）
class _Dist {
  final String name;
  final int count;
  const _Dist(this.name, this.count);
}

/// 统计快照（按台站版本 + 收包数缓存，避免每帧重建时全量扫描）
class _Stats {
  final int totalRx, totalTx, perMin;
  final int total, online, moving, stopped, offline;
  final List<_Dist> types;
  final List<_Dist> grids;
  final List<_Dist> devs;
  final int aprslocus;
  final String? farCall;
  final double? farKm;
  final DateTime? lastHeard;
  /// 最近上报的台站呼号（便于核对，避免只给一个无法验证的时间）
  final String? lastCall;
  const _Stats({
    required this.totalRx,
    required this.totalTx,
    required this.perMin,
    required this.total,
    required this.online,
    required this.moving,
    required this.stopped,
    required this.offline,
    required this.types,
    required this.grids,
    required this.devs,
    required this.aprslocus,
    this.farCall,
    this.farKm,
    this.lastHeard,
    this.lastCall,
  });

  /// 在线率（在线 / 接收范围内台站总数）。
  /// 比原先的「平均速度」有意义：后者把不同时段、不同运动状态的台站速度
  /// 混在一起求平均，数值本身无法解释，已移除。
  int get onlineRatePct => total <= 0 ? 0 : (online * 100 / total).round();
}

class _StationStatsPanelState extends State<StationStatsPanel> {
  int _cacheSig = -1;
  _Stats? _cached;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // 「最近上报」是相对时间，必须秒级刷新。
    // 台站页只有一个 StreamBuilder，仅当台站版本变化时才重建，
    // 因此没有这个 tick 的话，「5 秒前」会一直停在「5 秒前」。
    // 面板只在统计模式下挂载，可见时才计时，开销可忽。
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// 坐标是否可用：排除越界与「空岛」（0,0）附近的无效上报。
  /// 否则坐标解码异常/未定位的台站会把「最远」变成一个天文数字。
  static bool _validCoord(double lat, double lng) {
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
    if (lat.abs() < 0.01 && lng.abs() < 0.01) return false;
    return true;
  }

  _Stats get _stats {
    final st = widget.state;
    final sig = Object.hash(st.stationsVersion, st.packetsRx, st.receiveOthers,
        Object.hashAll(st.receiveCountries));
    if (sig == _cacheSig && _cached != null) return _cached!;

    var online = 0, moving = 0, stopped = 0, offline = 0;
    final gridCount = <String, int>{};
    final typeCount = <TypeGroup, int>{};
    final devCount = <String, int>{};
    var aprslocus = 0;
    String? farCall;
    double? farKm;
    DateTime? lastHeard;
    String? lastCall;

    final hasMe = st.myHasFix && st.myLat != null && st.myLng != null;

    for (final s in st.stations) {
      // 与台站列表口径一致：先按接收范围过滤
      if (!st.stationAllowedFor(s)) continue;

      switch (s.effectiveStatus) {
        case St.moving:
          moving++;
          online++;
          break;
        case St.stopped:
          stopped++;
          online++;
          break;
        case St.online:
          online++;
          break;
        case St.offline:
        case St.emergency:
          offline++;
          break;
      }

      typeCount[s.typeGroup] = (typeCount[s.typeGroup] ?? 0) + 1;

      final k = s.deviceClassKey;
      if (k != null && k.isNotEmpty) {
        devCount[k] = (devCount[k] ?? 0) + 1;
      }

      if (s.isAprslocusStation) aprslocus++;

      // 大网格：Maidenhead 4 位（Field + Square，如 PM86）
      final g = maidenhead(s.lat, s.lng, 4);
      gridCount[g] = (gridCount[g] ?? 0) + 1;

      // 最近上报：记下时间与呼号（呼号用于核对，避免只给一个无法验证的时间）
      if (lastHeard == null || s.lastHeard.isAfter(lastHeard)) {
        lastHeard = s.lastHeard;
        lastCall = s.call;
      }
      // 最远台站：
      // ① 仅统计「当前仍在线」的（5 分钟内上报，与列表口径一致）——
      //    否则磁盘恢复的过期台站或早已离线台站也会被计入；
      // ② 排除无效/空岛坐标，避免解码异常把「最远」拉成天文数字；
      // ③ 同时记下呼号，供界面展示以便核对。
      if (hasMe &&
          s.effectiveStatus != St.offline &&
          _validCoord(s.lat, s.lng)) {
        final d = haversine(st.myLat!, st.myLng!, s.lat, s.lng);
        if (farKm == null || d > farKm) {
          farKm = d;
          farCall = s.call;
        }
      }
    }

    List<_Dist> dist(Map<String, int> m) {
      final l = m.entries.map((e) => _Dist(e.key, e.value)).toList()
        ..sort((a, b) {
          final c = b.count.compareTo(a.count);
          return c != 0 ? c : a.name.compareTo(b.name);
        });
      return l;
    }

    const typeOrder = <TypeGroup>[
      TypeGroup.mobile,
      TypeGroup.fixed,
      TypeGroup.infra,
      TypeGroup.wx,
      TypeGroup.fmo,
      TypeGroup.other,
    ];
    final types = <_Dist>[
      for (final t in typeOrder)
        if ((typeCount[t] ?? 0) > 0) _Dist(_typeName(t), typeCount[t]!),
    ];

    final res = _Stats(
      totalRx: st.packetsRx,
      totalTx: st.packetsTx,
      perMin: st.rxPerMin,
      total: st.stations.length,
      online: online,
      moving: moving,
      stopped: stopped,
      offline: offline,
      types: types,
      grids: dist(gridCount),
      devs: dist(devCount),
      aprslocus: aprslocus,
      farCall: farCall,
      farKm: farKm,
      lastHeard: lastHeard,
      lastCall: lastCall,
    );
    _cacheSig = sig;
    _cached = res;
    return res;
  }

  static String _typeName(TypeGroup t) {
    switch (t) {
      case TypeGroup.mobile:
        return 'mobile';
      case TypeGroup.fixed:
        return 'fixed';
      case TypeGroup.infra:
        return 'infra';
      case TypeGroup.wx:
        return 'wx';
      case TypeGroup.fmo:
        return 'fmo';
      case TypeGroup.other:
        return 'other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    final s = _stats;
    final loc = AppLocalizations.of(context);
    final zh =
        (Localizations.maybeLocaleOf(context)?.languageCode ?? 'zh') == 'zh';

    String typeLabel(TypeGroup t) {
      switch (t) {
        case TypeGroup.mobile:
          return loc.mobile;
        case TypeGroup.fixed:
          return loc.fixed;
        case TypeGroup.infra:
          return loc.infrastructure;
        case TypeGroup.wx:
          return loc.weather;
        case TypeGroup.fmo:
          return 'FMO';
        case TypeGroup.other:
          return loc.otherType;
      }
    }

    // 类型条目名是内部 key，这里换成当前语言的展示名
    final typeDists = <_Dist>[
      for (final d in s.types)
        _Dist(
          typeLabel(TypeGroup.values.firstWhere((t) => _typeName(t) == d.name)),
          d.count,
        ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 2, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 系统总览：两个主指标（大数字）+ 次要指标 ──
          _card(
            title: loc.statsOverview,
            icon: Icons.insights_rounded,
            child: Column(children: [
              Row(children: [
                _hero(loc.statsTotalRx, _num(s.totalRx), C.blue),
                const SizedBox(width: 10),
                _hero(loc.statsStationsTotal, _num(s.total), C.ink),
              ]),
              const SizedBox(height: 14),
              _hairline(),
              const SizedBox(height: 12),
              Row(children: [
                _stat(loc.statsTotalTx, _num(s.totalTx), C.purple),
                _stat(
                  loc.statsRate,
                  s.perMin > 0 ? loc.statsPerMin('${s.perMin}') : '0',
                  C.green,
                ),
                _stat(
                  loc.statsConn,
                  st.connected ? loc.statsConnected : loc.statsDisconnected,
                  st.connected ? C.green : C.grey,
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _stat(loc.statsCap, _num(st.maxStations), C.grey),
                _stat(loc.statsAprslocusUsers, _num(s.aprslocus), C.purple),
                _stat(loc.statsMovingCount, _num(s.moving), C.blue),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                if (st.myHasFix && st.myLat != null && st.myLng != null)
                  _stat(loc.statsMyGrid, maidenhead(st.myLat!, st.myLng!, 4),
                      C.cyan)
                else
                  _stat(loc.statsMovingCount, _num(s.moving), C.blue),
                // 相对时间需秒级刷新（面板内置 1s tick）
                _stat(loc.statsLastHeard,
                    s.lastHeard == null ? '--' : _ago(s.lastHeard!, loc), C.green,
                    sub: s.lastCall),
                // 显示呼号，便于核对数值是否合理
                _stat(
                    loc.statsFarthest,
                    s.farKm == null ? '--' : '${s.farKm!.round()} km',
                    C.orange,
                    sub: s.farCall),
              ]),
            ]),
          ),
          const SizedBox(height: 10),

          // ── 台站状态分布（带色点，无排名）──
          _card(
            title: loc.statsStatusDist,
            icon: Icons.pie_chart_rounded,
            child: _bars(
              [
                _Dist(loc.online, s.online),
                _Dist(loc.moving, s.moving),
                _Dist(loc.stationary, s.stopped),
                _Dist(loc.offline, s.offline),
              ],
              total: s.online + s.offline,
              // 注意：C.* 颜色是 static 非 const，不能放进 const 列表
              colors: [C.green, C.blue, C.yellow, C.grey],
            ),
          ),
          const SizedBox(height: 10),

          // ── APRS 类型分布 ──
          _card(
            title: loc.statsTypeDist,
            icon: Icons.category_rounded,
            child: typeDists.isEmpty
                ? _empty(loc.statsNoData)
                : _bars(typeDists,
                    total: typeDists.fold(0, (a, b) => a + b.count)),
          ),
          const SizedBox(height: 10),

          // ── 大网格分布（带排名，前三名高亮）──
          _card(
            title: loc.statsGridDist,
            icon: Icons.grid_on_rounded,
            subtitle: loc.statsGridHint,
            trailing:
                s.grids.isEmpty ? null : loc.statsGridCount('${s.grids.length}'),
            child: s.grids.isEmpty
                ? _empty(loc.statsGridEmpty)
                : _bars(s.grids,
                    total: s.grids.fold(0, (a, b) => a + b.count),
                    showRank: true),
          ),
          const SizedBox(height: 10),

          // ── 设备类别分布 ──
          _card(
            title: loc.statsDeviceDist,
            icon: Icons.devices_other_rounded,
            child: s.devs.isEmpty
                ? _empty(loc.statsNoData)
                : _bars(
                    [
                      for (final d in s.devs)
                        _Dist(DeviceClassNames.labelOf(d.name, zh), d.count),
                    ],
                    total: s.devs.fold(0, (a, b) => a + b.count),
                  ),
          ),
          const SizedBox(height: 10),

          // ── 其他指标 ──
          // 注意：「最近上报 ┘已在总览区展示，此处不再重复
          _card(
            title: loc.statsOther,
            icon: Icons.speed_rounded,
            child: Row(children: [
              _stat(loc.statsOnlineRate, '${s.onlineRatePct}%', C.green),
              _stat(loc.statsGridCountLabel, _num(s.grids.length), C.cyan),
              _stat(loc.statsPackets, _num(st.packets.length), C.slate),
            ]),
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime t, AppLocalizations loc) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return loc.secondsAgo(d.inSeconds);
    if (d.inMinutes < 60) return loc.minutesAgo(d.inMinutes);
    if (d.inHours < 24) return loc.hoursAgo(d.inHours);
    return loc.daysAgo(d.inDays);
  }

  /// 千分位（大数字更好读）
  static String _num(int v) {
    final s = v.toString();
    if (s.length <= 4) return s;
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// 细分隔线（同天气面板：显式给宽度，避免在宽松约束下塌成 0 宽）
  Widget _hairline() => Container(
        width: double.infinity,
        height: 1,
        color: C.border,
      );

  /// 区块卡片：统一圆角 14、无描边（靠底色分层），内边距收紧
  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
    String? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: C.blue),
            const SizedBox(width: 6),
            Text(title, style: ts(12.5, w: FontWeight.w800)),
            const Spacer(),
            if (trailing != null)
              Text(trailing, style: ts(10, c: C.grey, w: FontWeight.w600)),
          ]),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle, style: ts(9.5, c: C.grey)),
            ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }

  Widget _empty(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(msg, style: ts(11, c: C.grey)),
      );

  /// 主指标：大数字 + 小标签（等宽两列）
  Widget _hero(String label, String value, Color c) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(26, w: FontWeight.w900, c: c, ls: -0.5)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(10.5, c: C.grey)),
        ],
      ),
    );
  }

  /// 次要指标：值在上、标签在下，无边框（比一排方框更干净也让层级更清楚）
  /// [sub] 用于附上呼号等可核对信息（如最远台站、最近上报）
  Widget _stat(String label, String value, Color c, {String? sub}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(13.5, w: FontWeight.w800, c: c)),
          const SizedBox(height: 1),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(9, c: C.grey)),
          if (sub != null && sub.isNotEmpty)
            Text(sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(9.5, w: FontWeight.w700, c: C.slate)),
        ],
      ),
    );
  }

  /// 分布列表：色点 / 排名 + 名称 + 条形 + 数量
  /// （条形本身已表达占比，故不再单列百分比，避免一行挤 5 列）
  Widget _bars(
    List<_Dist> items, {
    required int total,
    List<Color>? colors,
    bool showRank = false,
  }) {
    if (items.isEmpty) return _empty('--');
    final maxN = items.first.count;
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final col = colors != null ? colors[i % colors.length] : C.blue;
      final frac = maxN > 0 ? it.count / maxN : 0.0;
      // 前三名的排名徽章做高亮
      final top3 = showRank && i < 3;
      out.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          if (showRank)
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(
                color: top3 ? C.blue.withValues(alpha: 0.14) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${i + 1}',
                  style: ts(9.5,
                      w: FontWeight.w800,
                      c: top3 ? C.blue : C.greyLight)),
            )
          else
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(left: 2, right: 9),
              decoration: BoxDecoration(color: col, shape: BoxShape.circle),
            ),
          SizedBox(
            width: showRank ? 46 : 58,
            child: Text(it.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(11,
                    w: showRank ? FontWeight.w800 : FontWeight.w600,
                    ls: showRank ? 0.4 : 0)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 6,
                backgroundColor: C.greyBg,
                valueColor: AlwaysStoppedAnimation<Color>(
                    showRank && !top3 ? col.withValues(alpha: 0.45) : col),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(_num(it.count),
                textAlign: TextAlign.right,
                style: ts(11.5, w: FontWeight.w700)),
          ),
        ]),
      ));
    }
    return Column(children: out);
  }
}
