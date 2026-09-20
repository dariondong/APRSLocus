import 'package:flutter/material.dart';

import 'map_math.dart';
import 'offline_map.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'tile_cache.dart';
import 'tile_map.dart';
import 'widgets.dart';
import 'material.dart';

/// ─── 离线地图：区域管理页 ───
///
/// 「下载瓦片」和「管理已下载区域」放在同一个页面，因为它们是一件事的两半：
/// 用户点进「离线地图」就是想「下点东西备用」，或者「看看下过什么、删掉点」。
class OfflineMapPage extends StatefulWidget {
  final AppState state;
  const OfflineMapPage({super.key, required this.state});

  @override
  State<OfflineMapPage> createState() => _OfflineMapPageState();
}

class _OfflineMapPageState extends State<OfflineMapPage> {
  final OfflineMapStore store = OfflineMapStore.instance;
  final OfflineDownloader dl = OfflineDownloader.instance;

  (int, int)? _stats;
  bool _deleting = false;
  int _deleteDone = 0;
  int _deleteTotal = 0;

  @override
  void initState() {
    super.initState();
    store.load();
    dl.addListener(_onDl);
    _refreshStats();
  }

  @override
  void dispose() {
    dl.removeListener(_onDl);
    super.dispose();
  }

  void _onDl() {
    // 下载结束后占用会变，刷新一下统计
    if (!dl.busy) _refreshStats();
  }

  Future<void> _refreshStats() async {
    final s = await TileCache.stats();
    if (mounted) setState(() => _stats = s);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SettingsPageShell(
      title: s.offlineMap,
      subtitle: s.offlineMapDesc,
      icon: Icons.download_for_offline_rounded,
      color: C.blue,
      body: ListenableBuilder(
        listenable: Listenable.merge([store, dl]),
        builder: (context, _) => Column(children: [
          _cacheCard(s),
          const SizedBox(height: 16),
          _regionsCard(s),
          const SizedBox(height: 16),
          SettingsHint(s.offlineMapFooter, color: C.grey),
        ]),
      ),
    );
  }

  /// 缓存占用 + 清除
  Widget _cacheCard(S s) {
    final st = widget.state;
    final stats = _stats;
    final text = stats == null
        ? s.offlineLoading
        : '${s.offlineTilesDownloaded('${stats.$1}')} · ${formatBytes(stats.$2)}';
    return SettingsSectionCard(
      title: s.offlineCacheUsage,
      subtitle: s.offlineCacheUsageDesc,
      icon: Icons.sd_storage_rounded,
      color: C.purple,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(text, style: ts(12, c: C.slate)),
              ),
              if (_deleting)
                Text(
                  s.offlineDeletingTiles(
                      '$_deleteDone', '$_deleteTotal'),
                  style: ts(11, c: C.orange, w: FontWeight.w600),
                )
              else
                GestureDetector(
                  onTap: (stats == null || stats.$1 == 0)
                      ? null
                      : () => _confirmClearCache(s),
                  child: Text(
                    s.offlineClearCache,
                    style: ts(12,
                        c: stats == null || stats.$1 == 0 ? C.grey : C.red,
                        w: FontWeight.w600),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            SettingsSwitch(s.offlineCacheSwitch, value: st.tileCacheOn, color: C.blue, onChanged: (v) {
              st.setTileCacheOn(v);
              _refreshStats();
            }),
            SettingsHint(s.offlineCacheSwitchDesc, color: C.grey),
            SettingsSwitch(s.offlineOnlySwitch, value: st.offlineOnly, color: C.orange, onChanged: st.setOfflineOnly),
            SettingsHint(s.offlineOnlySwitchDesc, color: C.grey),
          ]),
        ),
      ],
    );
  }

  Widget _regionsCard(S s) {
    final regions = store.regions;
    return SettingsSectionCard(
      title: s.offlineRegions,
      subtitle: s.offlineRegionsDesc,
      icon: Icons.map_rounded,
      color: C.blue,
      trailing: GestureDetector(
        onTap: () => _openPicker(s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: C.blueBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, size: 14, color: C.blue),
            const SizedBox(width: 3),
            Text(s.offlineNew, style: ts(11, c: C.blue, w: FontWeight.w700)),
          ]),
        ),
      ),
      children: [
        if (regions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Icon(Icons.public_off_rounded, size: 30, color: C.greyLight),
              const SizedBox(height: 8),
              Text(s.offlineNoRegions, style: ts(13, c: C.slate, w: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(s.offlineNoRegionsHint,
                  style: ts(11, c: C.grey, h: 1.4), textAlign: TextAlign.center),
            ]),
          )
        else
          for (final r in regions) _regionTile(s, r),
      ],
    );
  }

  Widget _regionTile(S s, OfflineRegion r) {
    final active = dl.active?.id == r.id;
    final status = active
        ? (dl.paused ? OfflineStatus.paused : OfflineStatus.running)
        : r.status;
    final color = switch (status) {
      OfflineStatus.pending => C.grey,
      OfflineStatus.running => C.blue,
      OfflineStatus.paused => C.yellow,
      OfflineStatus.done => C.green,
      OfflineStatus.canceled => C.slate,
      OfflineStatus.failed => C.red,
    };
    final statusText = switch (status) {
      OfflineStatus.pending => s.offlineStatusPending,
      OfflineStatus.running => s.offlineStatusRunning,
      OfflineStatus.paused => s.offlineStatusPaused,
      OfflineStatus.done => s.offlineStatusDone,
      OfflineStatus.canceled => s.offlineStatusCanceled,
      OfflineStatus.failed => s.offlineStatusFailed,
    };
    final showBar = status == OfflineStatus.running ||
        status == OfflineStatus.paused ||
        (status == OfflineStatus.done && r.total > 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: C.border, width: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(r.name,
                style: ts(13, w: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(statusText, style: ts(10, c: color, w: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 5),
        Text(
          '${r.type.label} · ${s.offlineZoomLevels('${r.minZoom}', '${r.maxZoom}')}'
          ' · ${formatBytes(r.sizeBytes)}',
          style: ts(11, c: C.slate),
        ),
        const SizedBox(height: 2),
        Text(r.bounds.describe(),
            style: ts(10, c: C.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (showBar) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: r.progress,
              minHeight: 5,
              backgroundColor: C.greyBg,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Text(
              r.total > 0
                  ? s.offlineTileProgress('${r.done}', '${r.total}')
                  : s.offlineTilesDownloaded('${r.done}'),
              style: ts(10, c: C.slate),
            ),
            if (r.failed > 0) ...[
              const SizedBox(width: 8),
              Text(s.offlineFailedCount('${r.failed}'),
                  style: ts(10, c: C.orange)),
            ],
            const Spacer(),
            if (active && !dl.paused)
              _action(s.offlinePause, Icons.pause_rounded, C.yellow, () => dl.pause()),
            if (active && dl.paused)
              _action(s.offlineResume, Icons.play_arrow_rounded, C.blue, () => dl.resume()),
            if (!active && r.status.resumable)
              _action(s.offlineResume, Icons.download_rounded, C.blue, () => _start(r)),
            if (active)
              _action(s.offlineCancelDownload, Icons.close_rounded, C.orange, () => dl.cancel())
            else
              _action(s.delete, Icons.delete_outline_rounded, C.red, () => _confirmDelete(s, r)),
          ]),
        ] else ...[
          const SizedBox(height: 6),
          Row(children: [
            Text(s.offlineTilesDownloaded('${r.done}'), style: ts(10, c: C.slate)),
            const Spacer(),
            if (r.status.resumable)
              _action(s.offlineResume, Icons.download_rounded, C.blue,
                  () => _start(r)),
            _action(s.delete, Icons.delete_outline_rounded, C.red,
                () => _confirmDelete(s, r)),
          ]),
        ],
      ]),
    );
  }

  Widget _action(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 3),
          Text(label, style: ts(11, c: color, w: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _start(OfflineRegion r) {
    final s = S.of(context);
    if (!TileCache.available) {
      _snack(s.offlineCacheDisabled);
      return;
    }
    if (!widget.state.tileCacheOn) {
      _snack(s.offlineSwitchFirst);
      return;
    }
    if (!OfflineDownloader.instance.start(r)) {
      _snack(s.offlineDownloadBusy);
      return;
    }
    setState(() {});
  }

  Future<void> _openPicker(S s) async {
    if (!TileCache.available) {
      _snack(s.offlineCacheDisabled);
      return;
    }
    final r = await Navigator.push<OfflineRegion>(
      context,
      MaterialPageRoute(builder: (_) => OfflineRegionPickerPage(state: widget.state)),
    );
    if (r == null) return;
    await store.add(r);
    _start(r);
  }

  void _confirmDelete(S s, OfflineRegion r) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.surfaceFillStrong,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(s.offlineDeleteRegionConfirm(r.name),
                style: ts(14, w: FontWeight.w700), textAlign: TextAlign.center),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(s.offlineDeleteTileCount('${r.tileCount}'),
                style: ts(11, c: C.grey)),
          ),
          ListTile(
            leading: Icon(Icons.link_off_rounded, color: C.slate),
            title: Text(s.offlineDeleteKeepTiles, style: ts(13)),
            onTap: () async {
              Navigator.pop(ctx);
              await store.remove(r.id);
              _refreshStats();
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_rounded, color: C.red),
            title: Text(s.offlineDeleteWithTiles,
                style: ts(13, c: C.red, w: FontWeight.w600)),
            onTap: () async {
              Navigator.pop(ctx);
              setState(() {
                _deleting = true;
                _deleteDone = 0;
                _deleteTotal = r.tileCount;
              });
              await dl.deleteTiles(r, onProgress: (d, t) {
                if (mounted) setState(() => _deleteDone = d);
              });
              await store.remove(r.id);
              setState(() => _deleting = false);
              _refreshStats();
            },
          ),
          ListTile(
            leading: Icon(Icons.close_rounded, color: C.grey),
            title: Text(s.cancel, style: ts(13)),
            onTap: () => Navigator.pop(ctx),
          ),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }

  void _confirmClearCache(S s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.offlineClearCacheConfirm, style: ts(15, w: FontWeight.w700)),
        content: Text(s.offlineClearCacheConfirmBody, style: ts(12, c: C.slate, h: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await TileCache.clear();
              for (final r in store.regions) {
                r.done = 0;
                r.bytes = 0;
                r.status = OfflineStatus.pending;
              }
              await store.save();
              store.touch();
              _refreshStats();
            },
            child: Text(s.offlineClearCache, style: TextStyle(color: C.red)),
          ),
        ],
      ),
    );
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }
}

/// ─── 新建离线区域：所见即所得地选范围 ───
///
/// 不画可拖拽的矩形框，而是把「当前视图」本身当作下载范围：
/// 用户能看见什么，就下载什么 —— 没有坐标系换算的两套真值，
/// 也就不会出现「框选范围与实际下载范围差半屏」这种最难解释的 bug。
class OfflineRegionPickerPage extends StatefulWidget {
  final AppState state;
  const OfflineRegionPickerPage({super.key, required this.state});

  @override
  State<OfflineRegionPickerPage> createState() => _OfflineRegionPickerPageState();
}

class _OfflineRegionPickerPageState extends State<OfflineRegionPickerPage> {
  double _zoom = 12;
  Offset _pan = Offset.zero;

  late MapType _type;
  late final TextEditingController _name;
  int _minZoom = 8;
  int _maxZoom = 16;
  GeoBounds? _bounds;
  Size _viewSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _type = mapTypeByName(widget.state.mapType);
    if (!_type.canDownloadOffline) _type = MapType.gaode;
    // 以「我」为起点：绝大多数人要下的就是自己常待的地方
    final st = widget.state;
    _centerLat = st.myHasFix ? st.myLat! : 39.9042;
    _centerLng = st.myHasFix ? st.myLng! : 116.4074;
    _zoom = st.myHasFix ? 12 : 11;
    _name = TextEditingController(text: DateTime.now().toString().substring(0, 10));
  }

  late double _centerLat;
  late double _centerLng;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _gcj => isGcjMapType(_type);

  void _recompute(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _viewSize = size;
    _bounds = viewBounds(
      centerLat: _centerLat,
      centerLng: _centerLng,
      zoom: _zoom,
      pan: _pan,
      size: size,
      gcj: _gcj,
    );
  }

  void _panDelta(Offset d) {
    setState(() => _pan += d);
    _recompute(_viewSize);
  }

  void _setView(double zoom, Offset pan) {
    setState(() {
      _zoom = zoom;
      _pan = pan;
    });
    _recompute(_viewSize);
  }

  void _goMyLocation() {
    final st = widget.state;
    if (!st.myHasFix) return;
    setState(() {
      _centerLat = st.myLat!;
      _centerLng = st.myLng!;
      _pan = Offset.zero;
      if (_zoom < 11) _zoom = 12;
    });
    _recompute(_viewSize);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = widget.state;
    final bounds = _bounds;
    final tiles = bounds == null
        ? 0
        : countTilesIn(bounds, _minZoom, _maxZoom);
    final tooMany = tiles > kMaxOfflineTiles;
    final canStart = bounds != null &&
        bounds.isValid &&
        !tooMany &&
        tiles > 0 &&
        TileCache.available &&
        st.tileCacheOn;

    return Scaffold(
      backgroundColor: C.pageFill,
      appBar: MaterialAppBar(
        AppBar(
          backgroundColor: C.surfaceFillStrong,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: C.slate),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(s.offlineNew, style: ts(16, w: FontWeight.w700)),
        ),
      ),
      body: Column(children: [
        // 地图（当前视图 = 下载范围）
        Expanded(
          child: LayoutBuilder(builder: (ctx, cons) {
            final size = Size(cons.maxWidth, cons.maxHeight);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && (_viewSize != size || _bounds == null)) {
                setState(() => _recompute(size));
              }
            });
            return Stack(children: [
              TileMapView(
                centerLat: _centerLat,
                centerLng: _centerLng,
                zoom: _zoom,
                pan: _pan,
                onPan: _panDelta,
                onViewChanged: _setView,
                onZoomRequest: _setView,
                onTap: (_) {},
                minZoom: 2,
                maxZoom: 19,
                mapType: _type,
                cacheEnabled: st.tileCacheOn,
                offlineOnly: st.offlineOnly,
              ),
              // 视图边框：强调「框内就是下载范围」
              IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: C.blue.withValues(alpha: 0.55), width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Positioned(
                left: 16, top: 16,
                child: _chip(s.offlineAreaHint, C.blue),
              ),
              if (st.offlineOnly)
                Positioned(
                  left: 16, right: 16, bottom: 12,
                  child: _chip(s.offlineOnlyWarn, C.orange),
                ),
              Positioned(
                right: 14, bottom: 14,
                child: GestureDetector(
                  onTap: _goMyLocation,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: C.surfaceFillStrong,
                      shape: BoxShape.circle,
                      border: Border.all(color: C.border),
                    ),
                    child: Icon(Icons.my_location_rounded,
                        size: 18, color: C.blue),
                  ),
                ),
              ),
            ]);
          }),
        ),
        // 控制区
        Container(
          decoration: BoxDecoration(
            color: C.surfaceFillStrong,
            border: Border(top: BorderSide(color: C.border, width: 0.6)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 名称
                Row(children: [
                  Text(s.offlineName, style: ts(12, c: C.slate)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _name,
                      textAlign: TextAlign.right,
                      style: ts(13, w: FontWeight.w600),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: s.offlineNameHint,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Divider(height: 1, color: C.border),
                const SizedBox(height: 10),
                // 图源
                Text(s.offlineSource, style: ts(12, c: C.slate)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in MapType.values.where((t) => t.canDownloadOffline))
                    GestureDetector(
                      onTap: () {
                        setState(() => _type = t);
                        _recompute(_viewSize);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _type == t ? C.blue : C.bgSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _type == t ? C.blue : C.border),
                        ),
                        child: Text(t.label,
                            style: ts(11,
                                c: _type == t ? Colors.white : C.slate,
                                w: FontWeight.w600)),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),
                // 层级范围
                Row(children: [
                  Text(s.offlineZoomLevels('$_minZoom', '$_maxZoom'),
                      style: ts(12, c: C.slate, w: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    bounds == null
                        ? ''
                        : s.offlineEstimate(
                            '$tiles', formatBytes(tiles * kTileBytesEstimate)),
                    style: ts(11, c: tooMany ? C.red : C.grey),
                  ),
                ]),
                RangeSlider(
                  values: RangeValues(_minZoom.toDouble(), _maxZoom.toDouble()),
                  min: 0,
                  max: 19,
                  divisions: 19,
                  labels: RangeLabels('$_minZoom', '$_maxZoom'),
                  activeColor: C.blue,
                  onChanged: (v) => setState(() {
                    _minZoom = v.start.round();
                    _maxZoom = v.end.round();
                  }),
                ),
                if (tooMany)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SettingsHint(s.offlineTooManyTiles('$tiles'),
                        color: C.red, icon: Icons.warning_amber_rounded),
                  ),
                if (st.offlineOnly)
                  SettingsHint(s.offlineOnlyWarn, color: C.orange),
                if (!TileCache.available)
                  SettingsHint(s.offlineCacheDisabled, color: C.red),
                if (TileCache.available && !st.tileCacheOn)
                  SettingsHint(s.offlineSwitchFirst, color: C.orange),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canStart ? _start : null,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(s.offlineStartDownload,
                        style: ts(13, w: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: C.blue,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: ts(11, c: Colors.white, w: FontWeight.w600)),
      );

  /// 只把区域**交回上一页**，由上一页「入册 + 开下」。
  ///
  /// 这里不自己 start()：那样区域不在 OfflineMapStore 里，会出现「下载在跑、
  /// 列表里却没有它」，用户既看不到进度也无法暂停/删除，重启后彻底失踪。
  void _start() {
    final b = _bounds;
    if (b == null || !b.isValid) return;
    Navigator.pop(context, _buildRegion(b));
  }

  OfflineRegion _buildRegion(GeoBounds b) {
    final name = _name.text.trim();
    return OfflineRegion(
      id: newOfflineRegionId(),
      name: name.isEmpty ? DateTime.now().toString().substring(0, 10) : name,
      mapType: _type.name,
      bounds: b,
      minZoom: _minZoom,
      maxZoom: _maxZoom,
      status: OfflineStatus.pending,
    );
  }
}
