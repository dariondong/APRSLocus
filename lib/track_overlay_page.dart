import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'backup_io.dart' if (dart.library.html) 'backup_io_web.dart' as backup_io;
import 'coord.dart';
import 'map_math.dart';
import 'material.dart';
import 'state.dart';
import 'theme.dart';
import 'tile_map.dart';
import 'track_day_page.dart' show dayLabelText;
import 'track_log.dart';
import 'widgets.dart';

/// ─── 历史轨迹叠层（所有天画在同一张图上）───
///
/// 历史轨迹原来只能**一天一天看**：翻账时想回答的问题却是「这三个月我都在
/// 哪一带活动、常走哪条路」，那必须先看见全部。这一页把台账里的每一天都叠
/// 在一张底图上：
///
///   * 每天一条线、一个颜色，颜色按天在列表里的位置取（同一天永远同色）；
///   * 底部一排日期片，点一下就把那天藏起来/放出来 —— 想单看某一天不必另开页；
///   * 视野一次套到**所有**选中的点，导出图片时看到的正是这一整片。
///
/// 与 [TrackDayPage] 的分工：那里是「这一天是怎么走的」（回放、曲线），这里
/// 是「所有天叠起来长什么样」（对照、导出）。所以这页没有播放条，也不做
/// 单点插值 —— 几千个点只画路径，拖动/缩放才跟得上手。
class TrackOverlayPage extends StatefulWidget {
  final AppState state;
  const TrackOverlayPage({super.key, required this.state});

  @override
  State<TrackOverlayPage> createState() => _TrackOverlayPageState();
}

/// 一条「已经算好局部坐标」的天轨迹。
///
/// 路径在建页时算一次（含纠偏与投影），之后拖动/缩放只是换变换矩阵 ——
/// 一个月 30 天 × 上千点如果每帧重算，拖一下就掉帧。
class _DayLine {
  final DayTrack day;
  final Color color;
  final Path path;

  const _DayLine(this.day, this.color, this.path);
}

class _TrackOverlayPageState extends State<TrackOverlayPage> {
  /// 导出图片要截的就是这一块（地图 + 底部的日期片）
  final GlobalKey _shotKey = GlobalKey();

  List<_DayLine> _lines = const [];
  bool _loading = true;

  /// 被藏起来的天（默认全显示，所以是「关掉的集合」而不是「打开的集合」）
  final Set<String> _off = <String>{};

  // ── 视图 ──
  double _zoom = 11;
  Offset _pan = Offset.zero;
  bool _fitDone = false;

  // ── 投影（只算一次）──
  bool _isGcj = false;
  (double, double) _base = (0, 0);
  double _minX = 0, _maxX = 0, _minY = 0, _maxY = 0;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final days = await TrackLogStore.instance.loadAll();
    // 只留有点的天：空档画出来只是一片空白，混在颜色表里还会占掉一个颜色
    final list = days.where((d) => d.points.isNotEmpty).toList();
    if (!mounted) return;
    setState(() {
      _lines = _buildLines(list);
      _fitDone = false;
      _loading = false;
    });
  }

  /// 矢量图源（flutter_map 插件）没有栅格瓦片，这一页与回放页一样退回 OSM
  MapType get _tileType {
    final want = widget.state.mapType;
    for (final t in MapType.values) {
      if (t.name == want) {
        if (t == MapType.vector || t == MapType.vector_positron) {
          return MapType.osm;
        }
        return t;
      }
    }
    return MapType.gaode;
  }

  (double, double) _tc(double lat, double lng) =>
      _isGcj ? Gcj.wgsToGcj(lat, lng) : (lat, lng);

  /// 每天一个颜色。取主题里的既有色板（不新造色相），按序号循环 ——
  /// 天一多必然有重复色，但相邻两天不会撞色，相邻的两条线才需要区分。
  ///
  /// 不能写成 `const` 列表：`C.blue` 这些是**可变**的静态字段（换主题 / 深色
  /// 模式会改它们），常量列表编不过（CI 上就是这一行报的 constant evaluation）。
  static Color _colorOf(int i) {
    final palette = <Color>[
      C.blue,
      C.green,
      C.orange,
      C.purple,
      C.cyan,
      C.red,
      C.indigo,
      C.yellow,
    ];
    return palette[i % palette.length];
  }

  List<_DayLine> _buildLines(List<DayTrack> days) {
    _isGcj = isGcjMapType(_tileType);
    final proj = projectionFor(_tileType);
    // 基准点取**最新一天的第一个点**：它一定存在（空天在 `_load` 里已经滤掉），
    // 且所有局部坐标都相对它算一次就够，循环里不再重复投影基准点。
    final firstPt = days.isEmpty ? null : days.first.points.first;
    _base = firstPt == null ? (0, 0) : _tc(firstPt.lat, firstPt.lng);
    final basePx = proj.latLngToPx(_base.$1, _base.$2, 0);
    var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0;
    final lines = <_DayLine>[];
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final path = Path();
      var started = false;
      for (final p in d.points) {
        final t = _tc(p.lat, p.lng);
        final px = proj.latLngToPx(t.$1, t.$2, 0);
        final x = px.dx - basePx.dx;
        final y = px.dy - basePx.dy;
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
      lines.add(_DayLine(d, _colorOf(i), path));
    }
    _minX = minX;
    _maxX = maxX;
    _minY = minY;
    _maxY = maxY;
    return lines;
  }

  /// 视野套到所有**选中**的点上。放在 build 里算（幂等、不 setState）：
  /// 这些值当帧就要用，setState 只会多来一帧空白。
  void _ensureFit(Size size) {
    if (_fitDone) return;
    _fitDone = true;
    if (_lines.isEmpty) return;
    // 默认范围 = 全部点（它们在建路径时已经算好）；选中集合为空时就用它，
    // 免得视野跑到原点 (0,0) 去。
    var loX = _minX, hiX = _maxX, loY = _minY, hiY = _maxY;
    var any = false;
    for (final l in _lines) {
      if (_off.contains(l.day.day)) continue;
      final b = l.path.getBounds();
      if (b.isEmpty) continue;
      if (!any) {
        loX = b.left;
        hiX = b.right;
        loY = b.top;
        hiY = b.bottom;
        any = true;
      } else {
        loX = math.min(loX, b.left);
        hiX = math.max(hiX, b.right);
        loY = math.min(loY, b.top);
        hiY = math.max(hiY, b.bottom);
      }
    }
    final availW = (size.width - 64).clamp(64.0, 100000.0);
    final availH = (size.height - 220).clamp(64.0, 100000.0);
    final spanX = math.max(hiX - loX, 1e-9);
    final spanY = math.max(hiY - loY, 1e-9);
    final z = math.min(math.log(availW / spanX) / math.ln2,
        math.log(availH / spanY) / math.ln2);
    _zoom = z.clamp(2.0, 18.0);
    final zs = math.pow(2.0, _zoom).toDouble();
    _pan = Offset(-(loX + hiX) / 2 * zs, -(loY + hiY) / 2 * zs);
  }

  void _toggleDay(String day) {
    setState(() {
      if (!_off.remove(day)) _off.add(day);
      _fitDone = false; // 选中的点变了，重新套一次视野
    });
  }

  void _showAll() {
    setState(() {
      _off.clear();
      _fitDone = false;
    });
  }

  // ── 导出 / 分享 ──

  /// 截当前这一屏（地图 + 日期片）为 PNG。
  ///
  /// `pixelRatio` 取 2：手机屏上导出的图要能直接发群里看清日期片，1 倍太糊；
  /// 3 倍在多天多点的长路径上只是把文件撑大。
  Future<List<int>?> _capturePng() async {
    final obj = _shotKey.currentContext?.findRenderObject();
    if (obj is! RenderRepaintBoundary) return null;
    try {
      final img = await obj.toImage(pixelRatio: 2);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (data == null) return null;
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static String _stampName() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'APRSLocus-tracks-${n.year}${two(n.month)}${two(n.day)}'
        '-${two(n.hour)}${two(n.minute)}.png';
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    final s = S.of(context);
    final bytes = await _capturePng();
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.historyOverlayExportFailed)),
      );
      return;
    }
    final path = await backup_io.saveImageBytes(_stampName(), bytes);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(path == null
          ? s.historyOverlayExportFailed
          : s.gpxSavedTo(path)),
    ));
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    final s = S.of(context);
    final bytes = await _capturePng();
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.historyOverlayExportFailed)),
      );
      return;
    }
    final ok = await backup_io.shareImageBytes(_stampName(), bytes);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.historyOverlayExportFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final zscale = math.pow(2.0, _zoom).toDouble();
    return Scaffold(
      backgroundColor: C.pageFill,
      appBar: MaterialAppBar(
        AppBar(
          backgroundColor: C.surfaceFillStrong,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: C.slate),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: C.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.layers_rounded, color: C.green, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.historyOverlay,
                  style: ts(16, w: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            if (backup_io.shareImageSupported)
              IconButton(
                tooltip: s.historyOverlayShare,
                onPressed: _busy ? null : _share,
                icon: Icon(Icons.ios_share_rounded, color: C.blue),
              ),
            IconButton(
              tooltip: s.historyOverlayExport,
              onPressed: _busy ? null : _export,
              icon: Icon(Icons.image_outlined, color: C.green),
            ),
          ],
        ),
        overWallpaper: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, cons) {
              final size = Size(cons.maxWidth, cons.maxHeight);
              _ensureFit(size);
              if (_lines.isEmpty) return _emptyCard();
              return RepaintBoundary(
                key: _shotKey,
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(builder: (ctx2, mc) {
                        // 画笔的原点要用**地图那块真实尺寸**（不含下面的日期片），
                        // 否则整条轨迹会往上偏一个日期片的高度。
                        final msize = Size(mc.maxWidth, mc.maxHeight);
                        return Stack(children: [
                          Positioned.fill(
                            child: TileMapView(
                              centerLat: _base.$1,
                              centerLng: _base.$2,
                              zoom: _zoom,
                              pan: _pan,
                              onPan: (d) => setState(() => _pan += d),
                              onViewChanged: (z, p) => setState(() {
                                _zoom = z;
                                _pan = p;
                              }),
                              onZoomRequest: (z, p) => setState(() {
                                _zoom = z;
                                _pan = p;
                              }),
                              onTap: (_) {},
                              mapType: _tileType,
                              cacheEnabled: widget.state.tileCacheOn,
                              offlineOnly: widget.state.offlineOnly,
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _OverlayPainter(
                                  lines: _lines,
                                  off: _off,
                                  zscale: zscale,
                                  origin: Offset(msize.width / 2 + _pan.dx,
                                      msize.height / 2 + _pan.dy),
                                  rev: _off.length,
                                ),
                              ),
                            ),
                          ),
                        ]);
                      }),
                    ),
                    _legend(s),
                  ],
                ),
              );
            }),
    );
  }

  Widget _emptyCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: cardDeco(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.route_rounded, size: 34, color: C.grey),
              const SizedBox(height: 10),
              Text(S.of(context).historyOverlayEmpty,
                  textAlign: TextAlign.center,
                  style: ts(12, c: C.slate, h: 1.6)),
            ],
          ),
        ),
      ),
    );
  }

  /// 底部的日期片：一天一格，点一下藏/放。
  ///
  /// 不放进地图里浮着：天一多就是一列很长的东西，压在轨迹上反而挡视线。
  /// 这一条固定在地图下面，导出时也一起截进去 —— 图里带的颜色和日期片对得上，
  /// 别人拿到这张图才知道哪条线是哪天。
  Widget _legend(S s) {
    final shown = _lines.where((l) => !_off.contains(l.day.day)).toList();
    var km = 0.0;
    for (final l in shown) {
      km += l.day.distanceKm;
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        14, 10, 14, 10 + MediaQuery.of(context).viewPadding.bottom),
      decoration: BoxDecoration(
        // 这一条在**地图下面**，不压在任何内容上（Column 排下来），所以用卡片
        // 那一档表面色就够：套 BackdropFilter 只是白多一层整屏 saveLayer。
        color: C.surfaceFill,
        border: Border(top: BorderSide(color: C.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers_rounded, size: 14, color: C.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.historyOverlaySummary(
                      '${shown.length}', '${_lines.length}', fmtKm(km)),
                  style: ts(11, c: C.slate, w: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_off.isNotEmpty)
                GestureDetector(
                  onTap: _showAll,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: C.greenBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(s.historyOverlayAll,
                        style: ts(10, c: C.green, w: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 104),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final l in _lines) _dayChip(l)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayChip(_DayLine l) {
    final on = !_off.contains(l.day.day);
    // 今天 / 昨天 用现成的说法；更早的只留 MM-DD（芯片里放年份太占地方）——
    // 但**跨年**时保留完整日期，否则 12-31 和 10-31 哪个是今年就看不出。
    final full = dayLabelText(context, l.day.day);
    final oneYear = _lines.isNotEmpty &&
        _lines.first.day.day.substring(0, 4) == l.day.day.substring(0, 4);
    final label = oneYear && full.length >= 10 ? full.substring(5) : full;
    return GestureDetector(
      onTap: () => _toggleDay(l.day.day),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: on ? l.color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: on ? l.color : C.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: on ? l.color : C.greyLight,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: ts(10,
                  c: on ? l.color : C.grey,
                  w: FontWeight.w700),
            ),
            const SizedBox(width: 5),
            Text(
              fmtKm(l.day.distanceKm),
              style: ts(10, c: on ? C.slate : C.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// 把每一天的路径画成一条线：局部坐标（zoom 0 的像素）→ 一次缩放到位。
///
/// 与回放页同一个手法：每帧不重算任何点，只换变换矩阵，所以几千点也能拖动。
class _OverlayPainter extends CustomPainter {
  final List<_DayLine> lines;
  final Set<String> off;
  final double zscale;
  final Offset origin;

  /// 选中集合变了要重画（集合本身不可比较，用长度 + 内容拼的版本号最省事）
  final int rev;

  const _OverlayPainter({
    required this.lines,
    required this.off,
    required this.zscale,
    required this.origin,
    required this.rev,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(zscale);
    // 倒着画：列表里最新的在前，先画旧的，最新那条压在最上面
    for (var i = lines.length - 1; i >= 0; i--) {
      final l = lines[i];
      if (off.contains(l.day.day)) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        // 宽度先除以缩放倍数：线宽是屏幕像素，不该跟着地图缩放变粗
        ..strokeWidth = (i == 0 ? 2.6 : 1.8) / zscale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = l.color.withValues(alpha: i == 0 ? 0.95 : 0.75);
      canvas.drawPath(l.path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.zscale != zscale ||
      old.origin != origin ||
      old.rev != rev ||
      old.lines.length != lines.length;

  @override
  bool hitTest(Offset position) => false;
}
