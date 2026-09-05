import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';
import 'models.dart';
import 'state.dart';
import 'aprs_device.dart';
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
  String _dev = 'all'; // 设备类别筛选：all / 官方 tocalls 类别 key
  String _model = 'all'; // 具体设备筛选：all / 识别出的 厂商型号(displayName)
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
        '${st.stationsVersion}|$_filter|$_type|$_app|$_dev|$_model|$_sort|$_query|${st.receiveCountries.join(',')}|${st.receiveOthers}';
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
    switch (_filter) {
      case 'online':
        s = s.where((s) => s.effectiveStatus != St.offline).toList();
        break;
      case 'moving':
        s = s.where((s) => s.effectiveStatus == St.moving).toList();
        break;
      case 'stopped':
        s = s.where((s) => s.effectiveStatus == St.stopped).toList();
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
    if (_dev != 'all') {
      s = s.where((s) => s.deviceClassKey == _dev).toList();
    }
    if (_model != 'all') {
      s = s.where((s) => (s.deviceName ?? '') == _model).toList();
    }
    switch (_app) {
      case 'aprslocus':
        // 备注/呼号含 APRSlocus 的台站（同为 APRSlocus 用户）
        s = s
            .where(
              (s) =>
                  (s.comment ?? '').toLowerCase().contains('aprslocus') ||
                  s.call.toUpperCase().contains('APRSLOCUS'),
            )
            .toList();
        break;
    }
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
              SizedBox(height: 14),
              // 统计 + 筛选合并在紧凑区域
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
                    // 常驻行：状态 chips + 「筛选」按钮（分类筛选在底部弹层内选择）
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _miniChip(
                          S.of(context).all,
                          _filter == 'all' &&
                              _type == 'all' &&
                              _app == 'all' &&
                              _dev == 'all' &&
                              _model == 'all',
                          C.slate,
                          () => setState(() {
                            _filter = 'all';
                            _type = 'all';
                            _app = 'all';
                            _dev = 'all';
                            _model = 'all';
                          }),
                        ),
                        _miniChip(
                          S.of(context).online,
                          _filter == 'online',
                          C.green,
                          () => setState(
                            () => _filter = _filter == 'online'
                                ? 'all'
                                : 'online',
                          ),
                        ),
                        _miniChip(
                          S.of(context).moving,
                          _filter == 'moving',
                          C.blue,
                          () => setState(
                            () => _filter = _filter == 'moving'
                                ? 'all'
                                : 'moving',
                          ),
                        ),
                        _miniChip(
                          S.of(context).stationary,
                          _filter == 'stopped',
                          C.yellow,
                          () => setState(
                            () => _filter = _filter == 'stopped'
                                ? 'all'
                                : 'stopped',
                          ),
                        ),
                        Container(width: 1, height: 16, color: C.border),
                        _categoryButton(context),
                      ],
                    ),
                    // 已生效的分类筛选 tag（类型/软件/设备类别，可单独删除）
                    if (_hasCategoryFilter) ...[SizedBox(height: 6), _activeFilterTags(context)],
                  ],
                ),
              ),
              SizedBox(height: 8),
              // 列表
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.radar_rounded,
                              size: 44,
                              color: C.greyLight,
                            ),
                            SizedBox(height: 10),
                            Text(
                              S.of(context).notFound,
                              style: ts(14, c: C.grey),
                            ),
                          ],
                        ),
                      )
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

  /// 除状态外是否还有分类筛选生效（类型/软件/设备类别）
  bool get _hasCategoryFilter =>
      _type != 'all' || _app != 'all' || _dev != 'all' || _model != 'all';

  /// 当前接收范围内台站识别出的具体设备名（去重，出现多的在前，含已选中兜底）
  List<String> _deviceModelOptions(AppState st) {
    final counts = <String, int>{};
    for (final s in st.stations) {
      if (!st.stationAllowedFor(s)) continue;
      final n = s.deviceName;
      if (n != null && n.isNotEmpty) counts[n] = (counts[n] ?? 0) + 1;
    }
    if (_model != 'all' && !counts.containsKey(_model)) counts[_model] = 0;
    final list = counts.keys.toList()
      ..sort((a, b) {
        final c = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
        return c != 0 ? c : a.compareTo(b);
      });
    return list;
  }

  /// 当前接收范围内台站识别出的设备类别 key（有序，含已选中兜底）
  List<String> _deviceClassKeys(AppState st) {
    final present = <String>{};
    for (final s in st.stations) {
      if (!st.stationAllowedFor(s)) continue;
      final k = s.deviceClassKey;
      if (k != null && k.isNotEmpty) present.add(k);
    }
    if (_dev != 'all') present.add(_dev); // 已选类别即使暂无台站也保留
    final order = <String>[];
    for (final k in AprsDevice.instance.classKeys) {
      if (present.contains(k) && !order.contains(k)) order.add(k);
    }
    for (final k in present) {
      if (!order.contains(k)) order.add(k);
    }
    return order;
  }

  bool _zh(BuildContext context) =>
      (Localizations.maybeLocaleOf(context)?.languageCode ?? 'zh') == 'zh';

  /// APRS 符号类型选中项的标签
  String _typeLabel(BuildContext context, String v) {
    switch (v) {
      case 'mobile':
        return S.of(context).mobile;
      case 'fixed':
        return S.of(context).fixed;
      case 'infra':
        return S.of(context).infrastructure;
      case 'wx':
        return S.of(context).weather;
      case 'fmo':
        return 'FMO';
    }
    return v;
  }

  /// 分类类型对应主题色（用于 chip / tag）
  Color _typeColor(String v) {
    switch (v) {
      case 'mobile':
        return C.blue;
      case 'fixed':
        return C.green;
      case 'infra':
        return C.orange;
      case 'wx':
        return C.cyan;
      case 'fmo':
        return C.orange;
    }
    return C.slate;
  }

  /// 常驻「筛选」按钮：分类维度（类型/软件/设备）均从底部弹层选择。
  Widget _categoryButton(BuildContext context) {
    final active = _hasCategoryFilter;
    return GestureDetector(
      onTap: () => _openFilterSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: active ? C.purple.withValues(alpha: 0.12) : C.bgSoft,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? C.purple.withValues(alpha: 0.3) : C.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 12,
              color: active ? C.purple : C.slate,
            ),
            SizedBox(width: 3),
            Text(
              S.of(context).filters,
              style: ts(
                10,
                c: active ? C.purple : C.slate,
                w: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 已生效分类筛选 tag 行（类型/软件/设备类别，各可单独点除）
  Widget _activeFilterTags(BuildContext context) {
    final zh = _zh(context);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        if (_type != 'all')
          _tagChip(
            _typeLabel(context, _type),
            _typeColor(_type),
            () => setState(() => _type = 'all'),
          ),
        if (_app == 'aprslocus')
          _tagChip(
            S.of(context).aprslocusOnly,
            C.purple,
            () => setState(() => _app = 'all'),
          ),
        if (_dev != 'all')
          _tagChip(
            DeviceClassNames.labelOf(_dev, zh),
            C.indigo,
            () => setState(() => _dev = 'all'),
          ),
        if (_model != 'all')
          _tagChip(
            _model,
            C.blueDark,
            () => setState(() => _model = 'all'),
          ),
        _miniChip(
          S.of(context).clearAll,
          false,
          C.grey,
          () => setState(() {
            _type = 'all';
            _app = 'all';
            _dev = 'all';
            _model = 'all';
          }),
        ),
      ],
    );
  }

  /// 可删除的筛选 tag：显示分类名，点击即取消该筛选
  Widget _tagChip(String label, Color c, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(left: 8, right: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: ts(10, c: c, w: FontWeight.w700),
            ),
            SizedBox(width: 2),
            Icon(Icons.close_rounded, size: 12, color: c),
          ],
        ),
      ),
    );
  }

  /// 底部筛选弹层：APRS 类型 / 软件 / 设备类别 分组，组内单选、跨组叠加
  Future<void> _openFilterSheet(BuildContext context) async {
    final st = widget.state;
    final zh = _zh(context);
    final devKeys = _deviceClassKeys(st);
    final _modelOptions = _deviceModelOptions(st);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
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
            setSheet(() {}); // 刷新面板内选中态
            setState(() {}); // 刷新背后列表
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
                // 标题 + 全部清除
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 4),
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 18, color: C.purple),
                      SizedBox(width: 8),
                      Text(
                        S.of(sheetCtx).filters,
                        style: ts(16, c: C.ink, w: FontWeight.w800),
                      ),
                      Spacer(),
                      TextButton(
                        onPressed: () => apply(() {
                          _type = 'all';
                          _app = 'all';
                          _dev = 'all';
                          _model = 'all';
                        }),
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
                        // ── APRS 类型 ──
                        groupTitle(S.of(sheetCtx).typeGroup),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            opt(
                              S.of(sheetCtx).all,
                              _type == 'all',
                              C.slate,
                              () => apply(() => _type = 'all'),
                            ),
                            opt(
                              _typeLabel(sheetCtx, 'mobile'),
                              _type == 'mobile',
                              C.blue,
                              () => apply(
                                () => _type = _type == 'mobile'
                                    ? 'all'
                                    : 'mobile',
                              ),
                            ),
                            opt(
                              _typeLabel(sheetCtx, 'fixed'),
                              _type == 'fixed',
                              C.green,
                              () => apply(
                                () => _type = _type == 'fixed'
                                    ? 'all'
                                    : 'fixed',
                              ),
                            ),
                            opt(
                              _typeLabel(sheetCtx, 'infra'),
                              _type == 'infra',
                              C.orange,
                              () => apply(
                                () => _type = _type == 'infra'
                                    ? 'all'
                                    : 'infra',
                              ),
                            ),
                            opt(
                              _typeLabel(sheetCtx, 'wx'),
                              _type == 'wx',
                              C.cyan,
                              () => apply(
                                () => _type = _type == 'wx' ? 'all' : 'wx',
                              ),
                            ),
                            opt(
                              _typeLabel(sheetCtx, 'fmo'),
                              _type == 'fmo',
                              C.orange,
                              () => apply(
                                () => _type = _type == 'fmo' ? 'all' : 'fmo',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        // ── 软件 ──
                        groupTitle(S.of(sheetCtx).software),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            opt(
                              S.of(sheetCtx).all,
                              _app == 'all',
                              C.slate,
                              () => apply(() => _app = 'all'),
                            ),
                            opt(
                              S.of(sheetCtx).aprslocusOnly,
                              _app == 'aprslocus',
                              C.purple,
                              () => apply(
                                () => _app = _app == 'aprslocus'
                                    ? 'all'
                                    : 'aprslocus',
                              ),
                            ),
                          ],
                        ),
                        // ── 设备类别（官方 tocalls 识别）──
                        if (devKeys.isNotEmpty) ...[SizedBox(height: 12), groupTitle(S.of(sheetCtx).deviceClass), Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            opt(
                              S.of(sheetCtx).all,
                              _dev == 'all',
                              C.slate,
                              () => apply(() => _dev = 'all'),
                            ),
                            for (final k in devKeys)
                              opt(
                                DeviceClassNames.labelOf(k, zh),
                                _dev == k,
                                C.indigo,
                                () => apply(() => _dev = _dev == k ? 'all' : k),
                              ),
                          ],
                        )],
                        // ── 具体设备（识别到的厂商型号）──
                        if (_modelOptions.isNotEmpty) ...[SizedBox(height: 12), groupTitle(S.of(sheetCtx).deviceModel), Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            opt(
                              S.of(sheetCtx).all,
                              _model == 'all',
                              C.slate,
                              () => apply(() => _model = 'all'),
                            ),
                            for (final m in _modelOptions)
                              opt(
                                m,
                                _model == m,
                                C.blueDark,
                                () => apply(() => _model = _model == m ? 'all' : m),
                              ),
                          ],
                        )],
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
