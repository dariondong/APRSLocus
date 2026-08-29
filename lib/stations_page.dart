import 'package:flutter/material.dart';
import 'theme.dart';
import 'models.dart';
import 'state.dart';
import 'widgets.dart';
import 'station_detail.dart';

class StationsPage extends StatefulWidget {
  final AppState state;
  final String searchQuery;
  const StationsPage({super.key, required this.state, this.searchQuery = ''});
  @override
  State<StationsPage> createState() => _StationsPageState();
}

class _StationsPageState extends State<StationsPage> {
  String _filter = 'all'; // 状态筛选
  String _type = 'all'; // 类型筛选
  String _app = 'all'; // 软件筛选：all / aprslocus
  String _sort = 'call';
  final _searchCtrl = TextEditingController();

  // 列表缓存：台站版本 + 筛选参数未变时复用，避免每 60ms 重建时全量重算
  int _cacheVersion = -1;
  String _cacheKey = '';
  List<Station> _cacheList = const [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 本页搜索 + 主页搜索合并（本页优先）
  String get _query {
    final local = _searchCtrl.text.trim().toLowerCase();
    if (local.isNotEmpty) return local;
    return widget.searchQuery.trim().toLowerCase();
  }

  List<Station> _list(AppState st) {
    final key = '${st.stationsVersion}|$_filter|$_type|$_app|$_sort|$_query|${st.receiveCountries.join(',')}|${st.receiveOthers}';
    if (key == _cacheKey && st.stationsVersion == _cacheVersion) {
      return _cacheList;
    }
    var s = List<Station>.from(st.stations);
    // 国家/地区接收筛选：始终按 stationAllowedFor 过滤（传对象避免线性查找）
    s = s.where(st.stationAllowedFor).toList();
    final q = _query;
    if (q.isNotEmpty) {
      s = s
          .where((s) =>
              s.call.toLowerCase().contains(q) ||
              s.typeName.contains(q) ||
              (s.comment ?? '').contains(q) ||
              s.grid.contains(q))
          .toList();
    }
    switch (_filter) {
      case 'online':
        s = s.where((s) => s.status != St.offline).toList();
        break;
      case 'moving':
        s = s.where((s) => s.status == St.moving).toList();
        break;
      case 'emergency':
        s = s.where((s) => s.status == St.emergency).toList();
        break;
    }
    switch (_type) {
      case 'mobile':
        s = s.where((s) => s.typeGroup == TypeGroup.mobile).toList();
        break;
      case 'fixed':
        s = s.where((s) => s.typeGroup == TypeGroup.fixed).toList();
        break;
      case 'infra':
        s = s.where((s) => s.typeGroup == TypeGroup.infra).toList();
        break;
      case 'wx':
        s = s.where((s) => s.typeGroup == TypeGroup.wx).toList();
        break;
      case 'fmo':
        s = s.where((s) => s.typeGroup == TypeGroup.fmo).toList();
        break;
    }
    switch (_app) {
      case 'aprslocus':
        // 备注/呼号含 APRSlocus 的台站（同为 APRSlocus 用户）
        s = s.where((s) =>
            (s.comment ?? '').toLowerCase().contains('aprslocus') ||
            s.call.toUpperCase().contains('APRSLOCUS')).toList();
        break;
    }
    final my = st.myStation;
    switch (_sort) {
      case 'recent':
        s.sort((a, b) => b.lastHeard.compareTo(a.lastHeard));
        break;
      case 'distance':
        if (my != null) {
          s.sort((a, b) => a.distKm(my.lat, my.lng)
              .compareTo(b.distKm(my.lat, my.lng)));
        }
        break;
      case 'status':
        s.sort((a, b) => b.status.index.compareTo(a.status.index));
        break;
      default:
        s.sort((a, b) => a.call.compareTo(b.call));
    }
    _cacheKey = key;
    _cacheVersion = st.stationsVersion;
    _cacheList = List.unmodifiable(s);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final st = widget.state;
        final list = _list(st);
        // 横屏屏幕矮：隐藏统计框，避免头部过高溢出
        final landscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 搜索框
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                style: ts(13),
                decoration: InputDecoration(
                  hintText: S.of(context).searchHint,
                  hintStyle: ts(13, c: C.grey),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 18, color: C.grey),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 16, color: C.grey),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          })
                      : null,
                  filled: true,
                  fillColor: C.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: C.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: C.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: C.blue, width: 1.5),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              SizedBox(height: 14),
              // 统计 + 筛选合并在紧凑区域
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: C.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.border),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // 统计行
                  if (!landscape)
                    Row(children: [
                      _statMini(S.of(context).online, '${st.online}', C.green),
                      _statMini(S.of(context).moving, '${st.moving}', C.blue),
                      _statMini(S.of(context).emergency, '${st.emergency}', C.red),
                      _statMini(S.of(context).totalStations, '${st.stations.length}', C.slate),
                      Spacer(),
                      _sortMenu(),
                    ]),
                  if (!landscape) SizedBox(height: 6),
                  // 筛选 chips 合并为一行 Wrap
                  Wrap(spacing: 4, runSpacing: 4, children: [
                    _miniChip(S.of(context).all, _filter == 'all' && _type == 'all' && _app == 'all',
                        C.slate, () => setState(() { _filter = 'all'; _type = 'all'; _app = 'all'; })),
                    _miniChip(S.of(context).online, _filter == 'online', C.green,
                        () => setState(() => _filter = _filter == 'online' ? 'all' : 'online')),
                    _miniChip(S.of(context).moving, _filter == 'moving', C.blue,
                        () => setState(() => _filter = _filter == 'moving' ? 'all' : 'moving')),
                    _miniChip(S.of(context).emergency, _filter == 'emergency', C.red,
                        () => setState(() => _filter = _filter == 'emergency' ? 'all' : 'emergency')),
                    Container(width: 1, height: 16, color: C.border),
                    _miniChip(S.of(context).mobile, _type == 'mobile', C.blue,
                        () => setState(() => _type = _type == 'mobile' ? 'all' : 'mobile')),
                    _miniChip(S.of(context).fixed, _type == 'fixed', C.green,
                        () => setState(() => _type = _type == 'fixed' ? 'all' : 'fixed')),
                    _miniChip(S.of(context).infrastructure, _type == 'infra', C.orange,
                        () => setState(() => _type = _type == 'infra' ? 'all' : 'infra')),
                    _miniChip(S.of(context).weather, _type == 'wx', C.cyan,
                        () => setState(() => _type = _type == 'wx' ? 'all' : 'wx')),
                    _miniChip('FMO', _type == 'fmo', C.orange,
                        () => setState(() => _type = _type == 'fmo' ? 'all' : 'fmo')),
                    Container(width: 1, height: 16, color: C.border),
                    _miniChip(S.of(context).aprslocusOnly, _app == 'aprslocus', C.purple,
                        () => setState(() => _app = _app == 'aprslocus' ? 'all' : 'aprslocus')),
                  ]),
                ]),
              ),
              SizedBox(height: 8),
              // 列表
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.radar_rounded, size: 44, color: C.greyLight),
                          SizedBox(height: 10),
                          Text(S.of(context).notFound, style: ts(14, c: C.grey)),
                        ]))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _tile(st, list[i], i),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 筛选行：标签 + 可换行的 chips
  Widget _statMini(String label, String value, Color c) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 5, height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
        const SizedBox(width: 3),
        Text(value, style: ts(11, c: c, w: FontWeight.w700)),
      ]),
    );
  }

  Widget _miniChip(String label, bool selected, Color c, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.12) : C.bgSoft,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: selected ? c.withValues(alpha: 0.3) : C.border),
        ),
        child: Text(label,
            style: ts(10,
                c: selected ? c : C.slate,
                w: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  IconData _typeIcon(String val) {
    switch (val) {
      case 'mobile':
        return Icons.directions_car_rounded;
      case 'fixed':
        return Icons.home_rounded;
      case 'infra':
        return Icons.cell_tower_rounded;
      case 'wx':
        return Icons.cloud_rounded;
      case 'fmo':
        return Icons.radio_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  Widget _sortMenu() {
    final s = S.of(context);
    final labels = {'call': s.sortCall, 'recent': s.sortRecent, 'distance': s.sortDistance, 'status': s.sortStatus};
    return PopupMenuButton<String>(
      initialValue: _sort,
      onSelected: (v) => setState(() => _sort = v),
      offset: const Offset(0, 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: C.bgSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sort_rounded, size: 14, color: C.grey),
          SizedBox(width: 3),
          Text(labels[_sort] ?? s.sortCall, style: ts(10, c: C.slate)),
          SizedBox(width: 2),
          Icon(Icons.arrow_drop_down_rounded, size: 14, color: C.grey),
        ]),
      ),
      itemBuilder: (_) => [
        for (final e in labels.entries)
          PopupMenuItem(value: e.key, height: 36,
              child: Text(e.value, style: ts(12))),
      ],
    );
  }

  Widget _tile(AppState st, Station s, int index) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('st-${s.call}-${s.lastHeard.millisecondsSinceEpoch ~/ 5000}'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index * 25),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(18 * (1 - v), 0), child: child),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => StationDetail(state: st, station: s),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: cardDeco(),
            child: Row(children: [
              SymbolBadge(s),
              SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: _callText(s, _query),
                    ),
                    SizedBox(width: 8),
                    StatusBadge(s.status),
                  ]),
                  SizedBox(height: 2),
                  Text('${s.typeName} · ${s.comment ?? ''}',
                      style: ts(11, c: C.slate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 6),
                  Wrap(spacing: 14, runSpacing: 4, children: [
                    _mini(Icons.speed_rounded, s.speedStr),
                    _mini(Icons.height_rounded, s.altStr),
                    _mini(Icons.grid_4x4_rounded, s.grid),
                    _mini(Icons.access_time_rounded, s.lastSeen),
                    if (s.wx != null)
                      _mini(Icons.cloud_outlined, s.wx!),
                    if (st.myStation != null) ...[
                      _mini(Icons.place_outlined,
                          '${s.distKm(st.myLat!, st.myLng!).toStringAsFixed(1)}km'),
                      _mini(Icons.navigation_outlined,
                          '${s.bearingFrom(st.myLat!, st.myLng!).toStringAsFixed(0)}°'),
                    ],
                  ]),
                ]),
              ),
              SizedBox(width: 6),
              // 包一层 GestureDetector，防止点击冒泡到外层 InkWell 打开详情面板
              GestureDetector(
                onTap: () => st.focusOnMap(s),
                behavior: HitTestBehavior.opaque,
                child: IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.map_outlined, color: C.blue, size: 20),
                  tooltip: S.of(context).openInMap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: C.greyLight, size: 20),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _mini(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 12, color: C.grey),
        SizedBox(width: 3),
        Text(t, style: ts(10, c: C.slate)),
      ]);

  /// 呼号显示，搜索命中部分高亮
  Widget _callText(Station s, String q) {
    final base = ts(14, c: C.ink, w: FontWeight.w700);
    if (q.isEmpty) {
      return Text(s.call,
          style: base, overflow: TextOverflow.ellipsis);
    }
    final lower = s.call.toLowerCase();
    final idx = lower.indexOf(q);
    if (idx < 0) {
      return Text(s.call,
          style: base, overflow: TextOverflow.ellipsis);
    }
    final match = s.call.substring(idx, idx + q.length);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: s.call.substring(0, idx), style: base),
        TextSpan(
          text: match,
          style: TextStyle(
            color: C.blue,
            fontWeight: FontWeight.w800,
            backgroundColor: C.blueBg,
          ),
        ),
        TextSpan(text: s.call.substring(idx + q.length), style: base),
      ]),
      overflow: TextOverflow.ellipsis,
    );
  }
}
