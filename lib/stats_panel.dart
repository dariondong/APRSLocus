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
  final double? avgSpeedKmh;
  final DateTime? lastHeard;
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
    this.avgSpeedKmh,
    this.lastHeard,
  });
}

class _StationStatsPanelState extends State<StationStatsPanel> {
  int _cacheSig = -1;
  _Stats? _cached;

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
    var speedSum = 0.0;
    var speedN = 0;
    String? farCall;
    double? farKm;
    DateTime? lastHeard;

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

      if (s.speed != null && s.speed! > 0.5) {
        speedSum += s.speed!;
        speedN++;
      }
      if (lastHeard == null || s.lastHeard.isAfter(lastHeard)) {
        lastHeard = s.lastHeard;
      }
      if (hasMe) {
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
      avgSpeedKmh: speedN > 0 ? speedSum / speedN : null,
      lastHeard: lastHeard,
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
    final dark = C.dark;
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
      padding: const EdgeInsets.only(top: 2, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 系统总览 ──
          _card(
            dark,
            title: loc.statsOverview,
            icon: Icons.insights_rounded,
            child: Column(children: [
              Row(children: [
                _kv(loc.statsTotalRx, '${s.totalRx}', C.blue, dark),
                _kv(loc.statsTotalTx, '${s.totalTx}', C.purple, dark),
                _kv(
                  loc.statsRate,
                  s.perMin > 0 ? loc.statsPerMin('${s.perMin}') : '0',
                  C.green,
                  dark,
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _kv(loc.statsStationsTotal, '${s.total}', C.ink, dark),
                _kv(loc.statsCap, '${st.maxStations}', C.grey, dark),
                _kv(
                  loc.statsConn,
                  st.connected ? loc.statsConnected : loc.statsDisconnected,
                  st.connected ? C.green : C.grey,
                  dark,
                ),
              ]),
              if (st.myHasFix && st.myLat != null && st.myLng != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  _kv(loc.statsMyGrid, maidenhead(st.myLat!, st.myLng!, 4),
                      C.cyan, dark),
                  _kv(
                    loc.statsAprslocusUsers,
                    '${s.aprslocus}',
                    C.purple,
                    dark,
                  ),
                  if (s.farKm != null)
                    _kv(loc.statsFarthest, '${s.farKm!.round()} km', C.orange,
                        dark),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 10),

          // ── 台站状态分布 ──
          _card(
            dark,
            title: loc.statsStatusDist,
            icon: Icons.pie_chart_rounded,
            child: _bars(
              dark,
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
            dark,
            title: loc.statsTypeDist,
            icon: Icons.category_rounded,
            child: typeDists.isEmpty
                ? _empty(loc.statsNoData)
                : _bars(dark, typeDists,
                    total: typeDists.fold(0, (a, b) => a + b.count)),
          ),
          const SizedBox(height: 10),

          // ── 大网格分布 ──
          _card(
            dark,
            title: loc.statsGridDist,
            icon: Icons.grid_on_rounded,
            subtitle: loc.statsGridHint,
            trailing: s.grids.isEmpty
                ? null
                : loc.statsGridCount('${s.grids.length}'),
            child: s.grids.isEmpty
                ? _empty(loc.statsGridEmpty)
                : _bars(dark, s.grids,
                    total: s.grids.fold(0, (a, b) => a + b.count),
                    showRank: true),
          ),
          const SizedBox(height: 10),

          // ── 设备类别分布 ──
          _card(
            dark,
            title: loc.statsDeviceDist,
            icon: Icons.devices_other_rounded,
            child: s.devs.isEmpty
                ? _empty(loc.statsNoData)
                : _bars(
                    dark,
                    [
                      for (final d in s.devs)
                        _Dist(DeviceClassNames.labelOf(d.name, zh), d.count),
                    ],
                    total: s.devs.fold(0, (a, b) => a + b.count),
                  ),
          ),
          const SizedBox(height: 10),

          // ── 其他指标 ──
          _card(
            dark,
            title: loc.statsOther,
            icon: Icons.speed_rounded,
            child: Column(children: [
              Row(children: [
                _kv(
                  loc.statsAvgSpeed,
                  s.avgSpeedKmh == null
                      ? '--'
                      : '${s.avgSpeedKmh!.toStringAsFixed(0)} km/h',
                  C.blue,
                  dark,
                ),
                _kv(
                  loc.statsLastHeard,
                  s.lastHeard == null ? '--' : _ago(s.lastHeard!, loc),
                  C.green,
                  dark,
                ),
                _kv(loc.statsPackets, '${st.packets.length}', C.slate, dark),
              ]),
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

  Widget _card(
    bool dark, {
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
    String? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1B2230) : C.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 15, color: C.blue),
            const SizedBox(width: 6),
            Text(title, style: ts(12.5, w: FontWeight.w800)),
            const Spacer(),
            if (trailing != null) Text(trailing, style: ts(10, c: C.grey)),
          ]),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle, style: ts(9.5, c: C.grey)),
            ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }

  Widget _empty(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(msg, style: ts(11, c: C.grey)),
      );

  /// 键值小格
  Widget _kv(String label, String value, Color c, bool dark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF222A39) : C.bgSoft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(13.5, w: FontWeight.w800, c: c)),
          const SizedBox(height: 1),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(9, c: C.grey)),
        ]),
      ),
    );
  }

  /// 带条形的分布列表（可排序展示，按数量降序）
  Widget _bars(
    bool dark,
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
      final pct = total > 0 ? (it.count / total * 100) : 0.0;
      out.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          if (showRank)
            SizedBox(
              width: 18,
              child: Text('${i + 1}',
                  style: ts(9.5, c: C.greyLight, w: FontWeight.w700)),
            ),
          SizedBox(
            width: showRank ? 42 : 62,
            child: Text(it.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(11,
                    w: showRank ? FontWeight.w800 : FontWeight.w600,
                    ls: showRank ? 0.4 : 0)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: maxN > 0 ? it.count / maxN : 0,
                minHeight: 6,
                backgroundColor: dark ? const Color(0xFF2A3344) : C.greyBg,
                valueColor: AlwaysStoppedAnimation<Color>(col),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 34,
            child: Text('${it.count}',
                textAlign: TextAlign.right,
                style: ts(11, w: FontWeight.w700)),
          ),
          SizedBox(
            width: 38,
            child: Text('${pct.toStringAsFixed(0)}%',
                textAlign: TextAlign.right,
                style: ts(9, c: C.grey)),
          ),
        ]),
      ));
    }
    return Column(children: out);
  }
}
