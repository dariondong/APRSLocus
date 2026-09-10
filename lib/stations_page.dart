import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';
import 'models.dart';
import 'state.dart';
import 'aprs_device.dart';
import 'widgets.dart';
import 'station_detail.dart';
import 'stats_panel.dart';

class StationsPage extends StatefulWidget {
  final AppState state;
  final String searchQuery;
  const StationsPage({super.key, required this.state, this.searchQuery = ''});
  @override
  State<StationsPage> createState() => _StationsPageState();
}

class _StationsPageState extends State<StationsPage> {
  // 台站筛选条件存放在 AppState：与地图共用同一份（见 applyFilterToMap），
  // 面板本身不再各自持有一份，避免两处筛选不一致。
  StationFilter get _f => widget.state.stationFilter;
  void _setFilter(StationFilter f) => widget.state.setStationFilter(f);

  /// 台站列表 / 统计面板切换。
  /// 刻意**不做持久化**：每次进入台站面板都默认回到台站列表，
  /// 不记忆上次选择（与需求一致）。
  bool _statsMode = false;
  String _sort = 'call';
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce; // 搜索防抖：台站多时避免逐字重建列表

  // 列表缓存：台站版本 + 筛选参数未变时复用，避免每 60ms 重建时全量重算
  int _cacheVersion = -1;
  String _cacheKey = '';
  List<Station> _cacheList = const [];

  @override
  void dispose() {
    _searchDebounce?.cancel();
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
    final key =
        '${st.stationsVersion}|${st.stationFilter.key}|$_sort|$_query|${st.receiveCountries.join(',')}|${st.receiveOthers}';
    if (key == _cacheKey && st.stationsVersion == _cacheVersion) {
      return _cacheList;
    }
    var s = List<Station>.from(st.stations);
    // 国家/地区接收筛选：始终按 stationAllowedFor 过滤（传对象避免线性查找）
    s = s.where(st.stationAllowedFor).toList();
    final q = _query;
    if (q.isNotEmpty) {
      s = s
          .where(
            (s) =>
                s.call.toLowerCase().contains(q) ||
                s.typeName.contains(q) ||
                (s.comment ?? '').contains(q) ||
                (s.deviceName ?? '').toLowerCase().contains(q) ||
                s.grid.contains(q),
          )
          .toList();
    }
    // 台站筛选（状态/类型/同款软件/设备）—— 与地图共用同一套判定
    final f = st.stationFilter;
    if (!f.isEmpty) s = s.where(f.matches).toList();
    final my = st.myStation;
    switch (_sort) {
      case 'recent':
        s.sort((a, b) => b.lastHeard.compareTo(a.lastHeard));
        break;
      case 'distance':
        if (my != null) {
          s.sort(
            (a, b) =>
                a.distKm(my.lat, my.lng).compareTo(b.distKm(my.lat, my.lng)),
          );
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
    // 流式加载：只订阅“台站数据流”（版本变化才推流）+ 页内秒级 tick，
    // 连接/消息/GPS/设置等与台站无关的 AppState 变化不再触发整页重建
    return StreamBuilder<int>(
      stream: widget.state.stationsStream,
      initialData: widget.state.stationsVersion,
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
                onChanged: (_) {
                  // 防抖：输入停止 300ms 才重建列表，台站多时避免卡顿
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      if (mounted) setState(() {});
                    },
                  );
                },
                style: ts(13),
                decoration: InputDecoration(
                  hintText: S.of(context).searchHint,
                  hintStyle: ts(13, c: C.grey),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: C.grey,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: C.grey,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
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
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              SizedBox(height: 10),
              // 台站列表 / 统计面板 切换（同消息页瀑布流/会话的样式，不记忆选择）
              Row(
                children: [
                  _modeToggle(),
                  const Spacer(),
                ],
              ),
              SizedBox(height: 10),
              // 统计 + 筛选合并在紧凑区域
              if (!_statsMode)
                Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: C.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 统计行
                    if (!landscape)
                      Row(
                        children: [
                          _statMini(
                            S.of(context).online,
                            '${st.online}',
                            C.green,
                          ),
                          _statMini(
                            S.of(context).moving,
                            '${st.moving}',
                            C.blue,
                          ),
                          _statMini(
                            S.of(context).stationary,
                            '${st.stoppedCount}',
                            C.yellow,
                          ),
                          _statMini(
                            S.of(context).totalStations,
                            '${st.stations.length}',
                            C.slate,
                          ),
                          Spacer(),
                          _sortMenu(),
                        ],
                      ),
                    if (!landscape) SizedBox(height: 6),
                    // 筛选行：单行横向滚动 chips，即点即筛（不含 FMO）
                    _chipBar(context),
                  ],
                ),
              ),
              SizedBox(height: 8),
              // 列表（或统计面板）
              Expanded(
                child: _statsMode
                    ? StationStatsPanel(state: st)
                    : list.isEmpty
                    ? _emptyState(st)
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

  /// 台站列表 / 统计面板 切换（样式与消息页 瀑布流/会话 一致）
  Widget _modeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: C.bgSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modePill(false, S.of(context).stationList),
          _modePill(true, S.of(context).statsPanel),
        ],
      ),
    );
  }

  Widget _modePill(bool stats, String label) {
    final sel = _statsMode == stats;
    return GestureDetector(
      onTap: () {
        if (sel) return;
        setState(() => _statsMode = stats);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? C.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: ts(12, c: sel ? Colors.white : C.slate, w: FontWeight.w600),
        ),
      ),
    );
  }

  /// 当前生效的筛选条件（用于空状态提示，让用户知道是什么把台站挡掉了）
  /// 注意：本文件未直接 import l10n，本地化类型用 widgets.dart 的别名 [S]。
  List<String> _activeConditions(AppState st, S s) {
    final f = st.stationFilter;
    final out = <String>[];
    switch (f.status) {
      case 'online':
        out.add(s.online);
        break;
      case 'moving':
        out.add(s.moving);
        break;
      case 'stopped':
        out.add(s.stationary);
        break;
      case 'iss':
        out.add(s.issStation);
        break;
    }
    switch (f.type) {
      case 'mobile':
        out.add(s.mobile);
        break;
      case 'fixed':
        out.add(s.fixed);
        break;
      case 'infra':
        out.add(s.infrastructure);
        break;
      case 'wx':
        out.add(s.weather);
        break;
    }
    if (f.app == 'aprslocus') out.add(s.aprslocusOnly);
    if (f.dev != 'all') out.add(DeviceClassNames.labelOf(f.dev, _zh(context)));
    if (f.model != 'all') out.add(f.model);
    final q = _query;
    if (q.isNotEmpty) out.add('${s.search}: $q');
    if (st.receiveCountries.isNotEmpty) {
      out.add('${s.filter} ×${st.receiveCountries.length}');
    }
    return out;
  }

  /// 列表空状态。
  /// 区分「确实没收到台站」与「被筛选/接收范围挡掉」：后者列出生效条件
  /// 并给出清除入口，否则用户只会看到一句「未找到台站」而无法判断原因。
  Widget _emptyState(AppState st) {
    final s = S.of(context);
    final conds = _activeConditions(st, s);
    final narrowed = conds.isNotEmpty;
    final canClearFilter = !st.stationFilter.isEmpty;
    final canClearSearch = _searchCtrl.text.trim().isNotEmpty;

    Widget pill(String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: C.bgSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: C.border),
          ),
          child: Text(t, style: ts(11, c: C.slate, w: FontWeight.w600)),
        );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              narrowed ? Icons.filter_alt_off_rounded : Icons.radar_rounded,
              size: 40,
              color: C.greyLight,
            ),
            const SizedBox(height: 10),
            Text(
              narrowed ? s.noStationsFiltered : s.notFound,
              textAlign: TextAlign.center,
              style: ts(14, w: FontWeight.w700, c: C.slate),
            ),
            if (narrowed) ...[
              const SizedBox(height: 6),
              Text(
                s.noStationsFilteredHint,
                textAlign: TextAlign.center,
                style: ts(11.5, c: C.grey, h: 1.5),
              ),
              const SizedBox(height: 10),
              Text(s.activeConditions,
                  style: ts(10, c: C.greyLight, w: FontWeight.w700, ls: 0.6)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [for (final t in conds) pill(t)],
              ),
              if (canClearFilter || canClearSearch) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (canClearFilter)
                      OutlinedButton.icon(
                        onPressed: _clearAll,
                        icon: const Icon(Icons.filter_alt_off_rounded, size: 15),
                        label: Text(s.clearStationFilter,
                            style: ts(12, w: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: C.blue,
                          side: BorderSide(color: C.blue.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    if (canClearSearch)
                      OutlinedButton.icon(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.backspace_outlined, size: 15),
                        label: Text(s.clearSearch,
                            style: ts(12, w: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: C.slate,
                          side: BorderSide(color: C.border),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 筛选行：标签 + 可换行的 chips
  Widget _statMini(String label, String value, Color c) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c),
          ),
          const SizedBox(width: 3),
          Text(
            value,
            style: ts(11, c: c, w: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// 是否所有筛选均为空（无任何生效筛选）
  bool get _nothingFiltered => _f.isEmpty;

  /// 重置全部筛选
  void _clearAll() {
    setState(() => _setFilter(const StationFilter()));
  }

  bool _zh(BuildContext context) =>
      (Localizations.maybeLocaleOf(context)?.languageCode ?? 'zh') == 'zh';

  /// 当前接收范围内台站识别出的设备类别 key（有序，含已选中兜底）
  List<String> _deviceClassKeys(AppState st) {
    final present = <String>{};
    for (final s in st.stations) {
      if (!st.stationAllowedFor(s)) continue;
      final k = s.deviceClassKey;
      if (k != null && k.isNotEmpty) present.add(k);
    }
    final f = widget.state.stationFilter;
    if (f.dev != 'all') present.add(f.dev); // 已选类别即使暂无台站也保留
    final order = <String>[];
    for (final k in AprsDevice.instance.classKeys) {
      if (present.contains(k) && !order.contains(k)) order.add(k);
    }
    for (final k in present) {
      if (!order.contains(k)) order.add(k);
    }
    return order;
  }

  /// 当前接收范围内台站识别出的具体设备名（去重，出现多的在前，含已选中兜底）
  /// [cls] 非空时只返回该设备类别下的设备（设备类别/型号联动）
  List<String> _deviceModelOptions(AppState st, {String? cls}) {
    final counts = <String, int>{};
    for (final s in st.stations) {
      if (!st.stationAllowedFor(s)) continue;
      if (cls != null && s.deviceClassKey != cls) continue;
      final n = s.deviceName;
      if (n != null && n.isNotEmpty) counts[n] = (counts[n] ?? 0) + 1;
    }
    final model = widget.state.stationFilter.model;
    if (model != 'all' &&
        (cls == null || _modelDeviceClass(st, model) == cls) &&
        !counts.containsKey(model)) {
      counts[model] = 0;
    }
    final list = counts.keys.toList()
      ..sort((a, b) {
        final c = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
        return c != 0 ? c : a.compareTo(b);
      });
    return list;
  }

  /// 某具体设备名对应的设备类别（用于联动判断）
  String? _modelDeviceClass(AppState st, String model) {
    for (final s in st.stations) {
      if (!st.stationAllowedFor(s)) continue;
      if (s.deviceName == model) return s.deviceClassKey;
    }
    return null;
  }

  Widget _divider() => Container(width: 1, height: 14, color: C.border);

  /// 单行筛选 chips（横向滚动，即点即筛）：状态 + APRS 类型 + 同款软件 + 设备
  Widget _chipBar(BuildContext context) {
    Widget chip(String label, bool selected, Color c, VoidCallback onTap) =>
        _miniChip(label, selected, c, onTap);
    Widget status(String label, String key, Color c) => chip(
          label,
          _f.status == key,
          c,
          () => _setFilter(
            _f.copyWith(status: _f.status == key ? 'all' : key),
          ),
        );
    Widget typeC(String label, String key, Color c) => chip(
          label,
          _f.type == key,
          c,
          () => _setFilter(_f.copyWith(type: _f.type == key ? 'all' : key)),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(S.of(context).all, _nothingFiltered, C.slate, _clearAll),
          const SizedBox(width: 4),
          status(S.of(context).online, 'online', C.green),
          const SizedBox(width: 4),
          status(S.of(context).moving, 'moving', C.blue),
          const SizedBox(width: 4),
          status(S.of(context).stationary, 'stopped', C.yellow),
          const SizedBox(width: 8),
          _divider(),
          const SizedBox(width: 8),
          typeC(S.of(context).mobile, 'mobile', C.blue),
          const SizedBox(width: 4),
          typeC(S.of(context).fixed, 'fixed', C.green),
          const SizedBox(width: 4),
          typeC(S.of(context).infrastructure, 'infra', C.orange),
          const SizedBox(width: 4),
          typeC(S.of(context).weather, 'wx', C.cyan),
          const SizedBox(width: 8),
          _divider(),
          const SizedBox(width: 8),
          chip(
            S.of(context).aprslocusOnly,
            _f.app == 'aprslocus',
            C.purple,
            () => _setFilter(
              _f.copyWith(app: _f.app == 'aprslocus' ? 'all' : 'aprslocus'),
            ),
          ),
          const SizedBox(width: 4),
          // ISS 空间站台站（RS0ISS / NA1SS / OR4ISS）
          chip(
            S.of(context).issStation,
            _f.status == 'iss',
            C.cyan,
            () => _setFilter(
              _f.copyWith(status: _f.status == 'iss' ? 'all' : 'iss'),
            ),
          ),
          const SizedBox(width: 8),
          _divider(),
          const SizedBox(width: 8),
          _deviceEntryChip(context),
        ],
      ),
    );
  }

  /// 设备筛选入口 chip：未选中显示「设备筛选」；选中后显示当前类别/型号并高亮
  Widget _deviceEntryChip(BuildContext context) {
    final zh = _zh(context);
    final active = _f.dev != 'all' || _f.model != 'all';
    final label = active
        ? (_f.model != 'all' ? _f.model : DeviceClassNames.labelOf(_f.dev, zh))
        : S.of(context).deviceFilter;
    return _miniChip(label, active, C.indigo, () => _openDeviceSheet(context));
  }

  /// 设备筛选弹层：设备类别 + 设备型号 两组（组内单选、两组可叠加）
  Future<void> _openDeviceSheet(BuildContext context) async {
    final st = widget.state;
    final zh = _zh(context);
    final devKeys = _deviceClassKeys(st);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          // 型号联动：已选类别时只列该类别下的型号；未选则列全部
          final models = _deviceModelOptions(
            st,
            cls: _f.dev == 'all' ? null : _f.dev,
          );
          Widget groupTitle(String t) => Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  t,
                  style: ts(11, c: C.slate, w: FontWeight.w700, ls: 0.5),
                ),
              );
          Widget opt(
            String label,
            bool selected,
            Color c,
            VoidCallback tap,
          ) => GestureDetector(
                onTap: tap,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(sheetCtx).size.width - 84,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? c.withValues(alpha: 0.12) : C.bgSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? c.withValues(alpha: 0.4) : C.border,
                      ),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(
                        12,
                        c: selected ? c : C.ink,
                        w: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
          void apply(VoidCallback change) {
            change();
            setSheet(() {});
            setState(() {});
          }
          return Container(
            decoration: BoxDecoration(
              color: C.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.78,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 4),
                  child: Row(
                    children: [
                      Icon(Icons.devices_rounded, size: 18, color: C.indigo),
                      SizedBox(width: 8),
                      Text(
                        S.of(sheetCtx).deviceFilter,
                        style: ts(16, c: C.ink, w: FontWeight.w800),
                      ),
                      Spacer(),
                      TextButton(
                        onPressed: () => apply(
                          () => _setFilter(_f.copyWith(dev: 'all', model: 'all')),
                        ),
                        child: Text(
                          S.of(sheetCtx).clearAll,
                          style: ts(12, c: C.grey),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 18, color: C.grey),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        groupTitle(S.of(sheetCtx).deviceClass),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            opt(
                              S.of(sheetCtx).all,
                              _f.dev == 'all',
                              C.indigo,
                              () => apply(() => _setFilter(_f.copyWith(dev: 'all'))),
                            ),
                            for (final k in devKeys)
                              opt(
                                DeviceClassNames.labelOf(k, zh),
                                _f.dev == k,
                                C.indigo,
                                () => apply(() {
                                  // 切类别时若已选型号不属于新类别则清空，避免空列表
                                  var m = _f.model;
                                  if (m != 'all' && _modelDeviceClass(st, m) != k) {
                                    m = 'all';
                                  }
                                  _setFilter(_f.copyWith(
                                    dev: _f.dev == k ? 'all' : k,
                                    model: m,
                                  ));
                                }),
                              ),
                          ],
                        ),
                        if (models.isNotEmpty) ...[
                          SizedBox(height: 14),
                          groupTitle(S.of(sheetCtx).deviceModel),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              opt(
                                S.of(sheetCtx).all,
                                _f.model == 'all',
                                C.blueDark,
                                () => apply(
                                  () => _setFilter(_f.copyWith(model: 'all')),
                                ),
                              ),
                              for (final m in models)
                                opt(
                                  m,
                                  _f.model == m,
                                  C.blueDark,
                                  () => apply(() => _setFilter(
                                        _f.copyWith(
                                            model: _f.model == m ? 'all' : m),
                                      )),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 行内设备标签（识别到厂商/型号才显示）
  Widget _devicePill(Station s) {
    final name = s.deviceName;
    if (name == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: C.indigo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.devices_rounded, size: 11, color: C.indigo),
          SizedBox(width: 3),
          Text(
            name,
            style: ts(10, c: C.indigo, w: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
            color: selected ? c.withValues(alpha: 0.3) : C.border,
          ),
        ),
        child: Text(
          label,
          style: ts(
            10,
            c: selected ? c : C.slate,
            w: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _sortMenu() {
    final s = S.of(context);
    final labels = {
      'call': s.sortCall,
      'recent': s.sortRecent,
      'distance': s.sortDistance,
      'status': s.sortStatus,
    };
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 14, color: C.grey),
            SizedBox(width: 3),
            Text(labels[_sort] ?? s.sortCall, style: ts(10, c: C.slate)),
            SizedBox(width: 2),
            Icon(Icons.arrow_drop_down_rounded, size: 14, color: C.grey),
          ],
        ),
      ),
      itemBuilder: (_) => [
        for (final e in labels.entries)
          PopupMenuItem(
            value: e.key,
            height: 36,
            child: Text(e.value, style: ts(12)),
          ),
      ],
    );
  }

  Widget _tile(AppState st, Station s, int index) {
    // key 必须稳定（只用呼号）：以前把 lastHeard 的 5 秒桶写进 key，
    // 导致每 5 秒整行被当成新组件重新播放入场动画（列表在后台也持续抖动）
    return TweenAnimationBuilder<double>(
      key: ValueKey('st-${s.call}'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index * 25),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(18 * (1 - v), 0),
          child: child,
        ),
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
            child: Row(
              children: [
                SymbolBadge(s),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: _callText(s, _query)),
                          SizedBox(width: 8),
                          StatusBadge(s.effectiveStatus),
                        ],
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${localizedAprsSymbolName(context, s.symbol)} · ${s.comment ?? ''}',
                              style: ts(11, c: C.slate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 识别出的设备标签（目的呼号 → 官方 tocalls）
                          if (s.deviceName != null) ...[SizedBox(width: 6), _devicePill(s)],
                        ],
                      ),
                      SizedBox(height: 6),
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          _mini(Icons.speed_rounded, s.speedStr),
                          _mini(Icons.height_rounded, s.altStr),
                          _mini(Icons.grid_4x4_rounded, s.grid),
                          // “X秒前”随每秒 tick 单独刷新，避免整页每秒重建
                          ValueListenableBuilder<int>(
                            valueListenable: widget.state.tick,
                            builder: (_, _, _) => _mini(
                              Icons.access_time_rounded,
                              localizedLastSeen(context, s),
                            ),
                          ),
                          if (s.wx != null) _mini(Icons.cloud_outlined, s.wx!),
                          if (st.myStation != null) ...[
                            _mini(
                              Icons.place_outlined,
                              '${s.distKm(st.myLat!, st.myLng!).toStringAsFixed(1)}km',
                            ),
                            _mini(
                              Icons.navigation_outlined,
                              '${s.bearingFrom(st.myLat!, st.myLng!).toStringAsFixed(0)}°',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6),
                // 在地图显示：直接给 IconButton 有效 onPressed（IconButton 会吸收点击，
                // 不会再冒泡到外层 InkWell 打开详情面板）
                IconButton(
                  onPressed: () => st.focusOnMap(s),
                  icon: Icon(Icons.map_outlined, color: C.blue, size: 20),
                  tooltip: S.of(context).openInMap,
                  visualDensity: VisualDensity.compact,
                ),
                Icon(Icons.chevron_right_rounded, color: C.greyLight, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mini(IconData i, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(i, size: 12, color: C.grey),
      SizedBox(width: 3),
      Text(t, style: ts(10, c: C.slate)),
    ],
  );

  /// 呼号显示，搜索命中部分高亮
  Widget _callText(Station s, String q) {
    final base = ts(14, c: C.ink, w: FontWeight.w700);
    if (q.isEmpty) {
      return Text(s.call, style: base, overflow: TextOverflow.ellipsis);
    }
    final lower = s.call.toLowerCase();
    final idx = lower.indexOf(q);
    if (idx < 0) {
      return Text(s.call, style: base, overflow: TextOverflow.ellipsis);
    }
    final match = s.call.substring(idx, idx + q.length);
    return Text.rich(
      TextSpan(
        children: [
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
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
