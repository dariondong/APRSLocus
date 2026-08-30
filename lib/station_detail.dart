import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'models.dart';
import 'state.dart';
import 'widgets.dart';
import 'coord.dart';

class StationDetail extends StatefulWidget {
  final AppState state;
  final Station station;
  const StationDetail({super.key, required this.state, required this.station});
  @override
  State<StationDetail> createState() => _StationDetailState();
}

class _StationDetailState extends State<StationDetail> {
  final _msg = TextEditingController();

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.station;
    final pkt = widget.state.packets
        .where((p) => p.src == s.call)
        .take(5)
        .toList();

    // 同基础呼号的相关台站（含不同 SSID）
    final related =
        widget.state.stations
            .where((x) => x.baseCall == s.baseCall && x.call != s.call)
            .toList()
          ..sort((a, b) => a.call.compareTo(b.call));

    // 内容超过屏幕高度时可滚动，不会溢出
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动指示条
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: C.greyLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 头部
                      Row(
                        children: [
                          SymbolBadge(s, size: 56),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      s.call,
                                      style: ts(
                                        20,
                                        w: FontWeight.w800,
                                        ls: -0.4,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    StatusBadge(s.status),
                                  ],
                                ),
                                SizedBox(height: 3),
                                Text(
                                  '${s.typeName} · ${s.comment ?? ''}',
                                  style: ts(12, c: C.slate),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: C.grey),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      if (related.isNotEmpty) ...[
                        SizedBox(height: 14),
                        // 相关台站（同基础呼号）
                        SoftCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.link_rounded,
                                    size: 15,
                                    color: C.cyan,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '${S.of(context).relatedStations} (${related.length})',
                                    style: ts(
                                      12,
                                      c: C.cyan,
                                      w: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final r in related)
                                    GestureDetector(
                                      onTap: () {
                                        // 切换到相关台站的面板
                                        Navigator.pop(context);
                                        showModalBottomSheet(
                                          context: context,
                                          backgroundColor: Colors.transparent,
                                          isScrollControlled: true,
                                          builder: (_) => StationDetail(
                                            state: widget.state,
                                            station: r,
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: C.cyanBg,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: C.cyan.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: r.status == St.offline
                                                    ? C.grey
                                                    : C.green,
                                              ),
                                            ),
                                            SizedBox(width: 5),
                                            Text(
                                              r.call,
                                              style: ts(
                                                11,
                                                c: C.cyan,
                                                w: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: 16),
                      // 指标
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              S.of(context).speedLabel,
                              s.speedStr,
                              Icons.speed_rounded,
                              C.blue,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _metric(
                              S.of(context).altitude,
                              s.altStr,
                              Icons.height_rounded,
                              C.purple,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _metric(
                              S.of(context).courseLabel,
                              s.course != null
                                  ? '${s.course!.toStringAsFixed(0)}°'
                                  : '--',
                              Icons.navigation_rounded,
                              C.cyan,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 快捷操作（Wrap 自动换行，窄屏不溢出）
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _action(
                            Icons.content_copy_rounded,
                            S.of(context).copyCoords,
                            () {
                              Clipboard.setData(ClipboardData(text: s.posStr));
                              _toast(S.of(context).copiedCoordsValue(s.posStr));
                            },
                          ),
                          _action(
                            Icons.grid_4x4_rounded,
                            S.of(context).copyGrid,
                            () {
                              Clipboard.setData(ClipboardData(text: s.grid));
                              _toast(S.of(context).copiedGridValue(s.grid));
                            },
                          ),
                          _action(
                            Icons.map_rounded,
                            S.of(context).openInMap,
                            () {
                              widget.state.focusOnMap(s);
                              Navigator.pop(context);
                            },
                          ),
                          _action(
                            Icons.navigation_rounded,
                            S.of(context).navigate,
                            () {
                              _openNavigation(s);
                            },
                          ),
                        ],
                      ),
                      if (widget.state.myStation != null) ...[
                        SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: C.blueBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: C.blue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.navigation_rounded,
                                color: C.blue,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                S
                                    .of(context)
                                    .distanceBearing(
                                      s
                                          .distKm(
                                            widget.state.myLat!,
                                            widget.state.myLng!,
                                          )
                                          .toStringAsFixed(1),
                                      s
                                          .bearingFrom(
                                            widget.state.myLat!,
                                            widget.state.myLng!,
                                          )
                                          .toStringAsFixed(0),
                                    ),
                                style: ts(12, c: C.blue, w: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (s.wx != null) ...[
                        SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: C.cyanBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: C.cyan.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.cloud_rounded,
                                color: C.cyan,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  S.of(context).weatherDataValue(s.wx!),
                                  style: ts(12, c: C.cyan, w: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: 16),
                      // 位置信息
                      SoftCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            KV(
                              S.of(context).grid,
                              s.grid,
                              icon: Icons.grid_4x4_rounded,
                            ),
                            SizedBox(height: 8),
                            KV(
                              S.of(context).latitude,
                              s.lat.toStringAsFixed(5),
                              icon: Icons.explore_rounded,
                            ),
                            SizedBox(height: 8),
                            KV(
                              S.of(context).longitude,
                              s.lng.toStringAsFixed(5),
                              icon: Icons.explore_rounded,
                            ),
                            SizedBox(height: 8),
                            KV(
                              S.of(context).lastSeen,
                              localizedLastSeen(context, s),
                              icon: Icons.access_time_rounded,
                            ),
                            SizedBox(height: 8),
                            KV(
                              S.of(context).symbolLabel,
                              '${s.symbol}  ${localizedAprsSymbolName(context, s.symbol)}',
                              icon: Icons.tag_rounded,
                            ),
                          ],
                        ),
                      ),
                      // 转发路径（独立区块，箭头串联，中继台可点击跳转）
                      if (s.path != null && s.path!.isNotEmpty) ...[
                        SizedBox(height: 14),
                        SoftCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.route_rounded,
                                    size: 14,
                                    color: C.orange,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    S.of(context).forwardingPath,
                                    style: ts(
                                      12,
                                      c: C.orange,
                                      w: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Wrap(
                                spacing: 2,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: _buildPathHops(_pathHops(s.path!)),
                              ),
                              SizedBox(height: 6),
                              Text(
                                S.of(context).digipeaterTapHint,
                                style: ts(9, c: C.greyLight),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: 14),
                      // FMO 台站信息
                      if (s.fmo != null && s.fmo!.isNotEmpty) ...[
                        SoftCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: C.greenBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.radio_rounded,
                                      color: C.green,
                                      size: 15,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    S.of(context).fmoInfo,
                                    style: ts(
                                      13,
                                      c: C.green,
                                      w: FontWeight.w700,
                                    ),
                                  ),
                                  Spacer(),
                                  GestureDetector(
                                    onTap: () {
                                      final txt = s.fmo!.entries
                                          .map((e) => '${e.key}: ${e.value}')
                                          .join('\n');
                                      Clipboard.setData(
                                        ClipboardData(text: txt),
                                      );
                                      _toast(S.of(context).copiedFmoInfo);
                                    },
                                    child: Icon(
                                      Icons.copy_rounded,
                                      color: C.grey,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              ...s.fmo!.entries.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Text(e.key, style: ts(11, c: C.slate)),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          e.value,
                                          textAlign: TextAlign.right,
                                          style: ts(
                                            11,
                                            c: C.ink,
                                            w: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 14),
                      ],
                      // APRSlocus 专属信息（同款软件台站）
                      if (s.isAprslocusStation) ...[
                        SoftCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: C.blueBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.terminal_rounded,
                                      color: C.blue,
                                      size: 15,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    S.of(context).aprslocusInfo,
                                    style: ts(
                                      13,
                                      c: C.blue,
                                      w: FontWeight.w700,
                                    ),
                                  ),
                                  Spacer(),
                                  GestureDetector(
                                    onTap: () {
                                      final txt =
                                          (s.aprslocus ??
                                                  _aprslocusFromComment(s))
                                              .entries
                                              .map(
                                                (e) => '${e.key}: ${e.value}',
                                              )
                                              .join('\n');
                                      Clipboard.setData(
                                        ClipboardData(text: txt),
                                      );
                                      _toast(S.of(context).copiedAprslocusInfo);
                                    },
                                    child: Icon(
                                      Icons.copy_rounded,
                                      color: C.grey,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              ..._aprslocusEntries(s).entries.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Text(e.key, style: ts(11, c: C.slate)),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          e.value,
                                          textAlign: TextAlign.right,
                                          style: ts(
                                            11,
                                            c: C.ink,
                                            w: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 14),
                      ],
                      // 轨迹预览
                      SoftCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.route_rounded,
                                  size: 16,
                                  color: C.slate,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  S.of(context).trackPoints(s.track.length),
                                  style: ts(12, c: C.slate, w: FontWeight.w600),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            SizedBox(
                              height: 90,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: _TrackPainter(s.track, s.color),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 14),
                      // 最近数据包
                      if (pkt.isNotEmpty) ...[
                        Text(
                          S.of(context).recentPackets,
                          style: ts(13, w: FontWeight.w600),
                        ),
                        SizedBox(height: 8),
                        ...pkt.map(
                          (p) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: C.bgSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              p.raw,
                              style: mono(10, c: C.slate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                      ],
                      // 快捷操作
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _msg,
                              style: ts(13),
                              decoration: InputDecoration(
                                hintText: S.of(context).sendMessageTo(s.call),
                                hintStyle: ts(13, c: C.grey),
                                filled: true,
                                fillColor: C.bgSoft,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              if (_msg.text.isNotEmpty) {
                                widget.state.sendMessage(
                                  s.call,
                                  _msg.text.trim(),
                                );
                                _msg.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(S.of(context).messageSent),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: C.blue,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: softShadow(blur: 12, alpha: 0.2),
                              ),
                              child: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    final w = (MediaQuery.of(context).size.width - 64) / 4;
    return SizedBox(
      width: w.clamp(70.0, 110.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: C.bgSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: C.blue),
              SizedBox(height: 3),
              Text(
                label,
                style: ts(10, c: C.slate, w: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNavigation(Station s) async {
    // 高德使用 GCJ-02 坐标，APRS 是 WGS-84，需转换
    final (gLat, gLng) = Gcj.wgsToGcj(s.lat, s.lng);
    final name = Uri.encodeComponent(s.call);

    // 尝试启动一个 URI，成功返回 true
    Future<bool> tryLaunch(
      Uri uri, {
      LaunchMode mode = LaunchMode.externalApplication,
    }) async {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: mode);
          return true;
        }
        // 部分 ROM 忽略包可见性，直接尝试启动
        await launchUrl(uri, mode: mode);
        return true;
      } catch (_) {
        return false;
      }
    }

    // 1. 高德导航（androidamap scheme）
    final gaodeUri = Uri.parse(
      'androidamap://navi?sourceApplication=aprslocus'
      '&lat=${gLat.toStringAsFixed(6)}'
      '&lon=${gLng.toStringAsFixed(6)}'
      '&poiname=$name&style=2&dev=0',
    );
    if (await tryLaunch(gaodeUri)) return;
    // 1b. 高德路线规划（amapuri scheme 变体）
    final amapUri = Uri.parse(
      'amapuri://route/plan/?dname=$name'
      '&dlat=${gLat.toStringAsFixed(6)}'
      '&dlon=${gLng.toStringAsFixed(6)}&dev=0&t=0',
    );
    if (await tryLaunch(amapUri)) return;

    // 2. 系统地图
    final geoUri = Uri.parse(
      'geo:${s.lat},${s.lng}?q=${s.lat},${s.lng}($name)',
    );
    if (await tryLaunch(geoUri)) return;

    // 3. 兜底：浏览器 OpenStreetMap
    final osmUri = Uri.parse(
      'https://www.openstreetmap.org/?mlat=${s.lat}&mlon=${s.lng}#map=16/${s.lat}/${s.lng}',
    );
    if (await tryLaunch(osmUri)) {
      return;
    }
    _toast(S.of(context).navigationUnavailable);
  }

  /// 从台站备注推断 APRSlocus 信息（未走位置解析时兜底）
  Map<String, String> _aprslocusFromComment(Station s) {
    final map = <String, String>{S.of(context).software: 'APRSlocus'};
    final c = s.comment ?? '';
    final vm = RegExp(
      r'APRSLOCUS\s*v?(\d[\d.]*)',
      caseSensitive: false,
    ).firstMatch(c);
    if (vm != null) map[S.of(context).version] = 'v${vm.group(1)}';
    final bm = RegExp(r'Bat:(\d+)%', caseSensitive: false).firstMatch(c);
    if (bm != null) map[S.of(context).phoneBattery] = '${bm.group(1)}%';
    // 高度/速度来自台站已解析字段（s.alt/s.speed 米、km/h）
    if (s.alt != null && s.alt! > 0) {
      map[S.of(context).altitude] = '${s.alt!.toStringAsFixed(0)}m';
    }
    if (s.speed != null && s.speed! > 0) {
      map[S.of(context).speed] = '${s.speed!.toStringAsFixed(0)}km/h';
    }
    return map;
  }

  /// APRSlocus 信息：优先用解析后的结构化数据，缺失时从备注推断
  Map<String, String> _aprslocusEntries(Station s) {
    if (s.aprslocus != null && s.aprslocus!.isNotEmpty) {
      return s.aprslocus!;
    }
    return _aprslocusFromComment(s);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  /// 解析转发路径为跳段列表（可点击的真实中继台 vs 仅路径标识如 WIDE1-1）
  List<({String call, bool isClickable})> _pathHops(String path) {
    final hops = <({String call, bool isClickable})>[];
    for (final raw in path.split(',')) {
      var hop = raw.trim().replaceAll('*', '');
      if (hop.isEmpty) continue;
      // IGate 确认标识：qAR:BG7XYZ / qAo / qAX，只保留冒号前的 qXX 作为标识
      final qm = RegExp(r'^(q[A-Z]+)[:_-]').firstMatch(hop);
      final base0 = hop.split(':').first.split('-').first.toUpperCase();
      // 协议/路径标识（WIDE/TRACE/RELAY/TCPIP、qA 确认符、T2 节点、纯数字等）不可点击
      const skip = {
        'WIDE',
        'TRACE',
        'RELAY',
        'TCPIP',
        'APRS',
        'NOGATE',
        'SAT',
        'ARISS',
        'T2CS',
        'T2HUB',
        'T2PHX',
        'T2NZ',
        'T2EUROPE',
        'T2ANZ',
      };
      final isT2Node = base0.startsWith('T2');
      final isQConf = qm != null || base0.startsWith('QA');
      // 纯数字 / 单字符路径段也视为标识
      final isNumeric = RegExp(r'^\d+$').hasMatch(base0);
      final isClickable =
          !skip.contains(base0) &&
          !isT2Node &&
          !isQConf &&
          !isNumeric &&
          AppState.isValidCallsign(hop);
      hops.add((call: hop, isClickable: isClickable));
    }
    return hops;
  }

  /// 构建转发路径可视化（箭头串联，中继台可点击）
  List<Widget> _buildPathHops(List<({String call, bool isClickable})> hops) {
    final widgets = <Widget>[];
    for (var i = 0; i < hops.length; i++) {
      if (i > 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 12,
              color: C.greyLight,
            ),
          ),
        );
      }
      final hop = hops[i];
      if (hop.isClickable) {
        widgets.add(
          GestureDetector(
            onTap: () => _jumpToHop(hop.call),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: C.orangeBg,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: C.orange.withValues(alpha: 0.35)),
              ),
              child: Text(
                hop.call,
                style: ts(11, c: C.orange, w: FontWeight.w700),
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: C.greyBg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              hop.call,
              style: ts(10, c: C.grey, w: FontWeight.w500),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  /// 点击路径中的中继台，跳转到该台站详情
  void _jumpToHop(String call) {
    final target = widget.state.stations
        .where((s) => s.call.toUpperCase() == call.toUpperCase())
        .firstOrNull;
    if (target == null) {
      _toast(S.of(context).stationNoData(call));
      return;
    }
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StationDetail(state: widget.state, station: target),
    );
  }

  Widget _metric(String label, String value, IconData icon, Color c) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Icon(icon, color: c, size: 18),
          SizedBox(height: 6),
          Text(
            value,
            style: ts(13, c: c, w: FontWeight.w700),
          ),
          Text(
            label,
            style: ts(9, c: C.grey, w: FontWeight.w600, ls: 0.8),
          ),
        ],
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  final List<TrackPt> pts;
  final Color color;
  _TrackPainter(this.pts, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final minLat = pts.map((p) => p.lat).reduce((a, b) => a < b ? a : b);
    final maxLat = pts.map((p) => p.lat).reduce((a, b) => a > b ? a : b);
    final minLng = pts.map((p) => p.lng).reduce((a, b) => a < b ? a : b);
    final maxLng = pts.map((p) => p.lng).reduce((a, b) => a > b ? a : b);
    final dLat = (maxLat - minLat).clamp(0.0001, 1.0);
    final dLng = (maxLng - minLng).clamp(0.0001, 1.0);

    Offset map(double lat, double lng) => Offset(
      (lng - minLng) / dLng * (size.width - 16) + 8,
      size.height - 8 - (lat - minLat) / dLat * (size.height - 16),
    );

    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    bool first = true;
    for (final p in pts) {
      final pos = map(p.lat, p.lng);
      if (first) {
        path.moveTo(pos.dx, pos.dy);
        first = false;
      } else {
        path.lineTo(pos.dx, pos.dy);
      }
    }
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      map(pts.first.lat, pts.first.lng),
      3,
      Paint()..color = C.greyLight,
    );
    canvas.drawCircle(
      map(pts.last.lat, pts.last.lng),
      4,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _TrackPainter old) => old.pts != pts;
}
