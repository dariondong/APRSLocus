import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'coord.dart';
import 'material.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'tile_map.dart';
import 'track_log.dart';
import 'widgets.dart';

/// 「今天 / 昨天 / 2026-09-20」。
///
/// 放在这个文件里而不是历史轨迹页，是为了避免
/// `track_history_page.dart ↔ track_day_page.dart` 互相 import —— 详情页是
/// 由列表页打开的，只能是列表页单向 import 这里。
String dayLabelText(BuildContext context, String day) {
  final s = S.of(context);
  final now = DateTime.now();
  if (day == TrackLogStore.dayKey(now)) return s.dateToday;
  if (day == TrackLogStore.dayKey(now.subtract(const Duration(days: 1)))) {
    return s.dateYesterday;
  }
  return day;
}

/// ─── 某一天的历史轨迹：地图 + 回放动画 ───
///
/// 列表页的「极简点列预览」只能看出形状；要看**怎么走的**（在哪停过、哪段快、
/// 几点到几点），得有底图和一条会长的线。这一页就干这件事：
///
///   * 底图用 [TileMapView] —— 与主地图同一套瓦片/缓存/离线逻辑，不另起炉灶；
///   * 轨迹线**随播放进度生长**（已走过的实线、未走的淡线），终点是当前点；
///   * 进度条可拖、可倍速（×0.5 / ×1 / ×2 / ×4）、可「跟随」把视野钉在当前点上。
///
/// ## 时间轴是**压缩过的**，这一点必须说清
///
/// 直接按墙上时钟回放没有意义：一天跨度常常 10 小时，而真正在动的可能只有
/// 40 分钟，照实播就是「盯着一个点不动两小时」。所以进度映射到的是
/// **动画时间**：相邻点间隔照实计入，但**超过 [_gapCapSec] 的停顿只按
/// [_gapCapSec] 计**。于是长停顿被整体压缩（快进），而移动中的快慢差异
/// 完整保留 —— 你看到的仍然是「这段骑得快、那段在走路」。
///
/// 与之配套：进度条拖到任意位置都要立刻显示**那个时刻**的点（二分查找时间轴），
/// 不能只在「已播放到的点」上做插值 —— 那样拖动会跳。
class TrackDayPage extends StatefulWidget {
  final DayTrack day;
  final AppState state;

  const TrackDayPage({super.key, required this.day, required this.state});

  @override
  State<TrackDayPage> createState() => _TrackDayPageState();
}

class _TrackDayPageState extends State<TrackDayPage>
    with SingleTickerProviderStateMixin {
  /// 长停顿在动画时间轴上最多占多少秒（超过就压缩，见类注释）
  static const double _gapCapSec = 45;

  /// 跟随模式下的最小缩放：跟随时要看街景，不能停在「看得见全天」的级别
  static const double _followZoom = 15.0;

  // ── 预计算（只算一次，播放期间每帧只做加减乘）──
  /// 相对基准点的局部世界像素（zoom 0）。所有绘制都在这套坐标里做，
  /// 于是「一条几千点的轨迹」每帧不需要重算三角函数/对数。
  late Float64List _lx, _ly;
  /// 动画时间轴上每个点的累计秒数
  late Float64List _animT;
  /// 每点处累计里程（km）
  late Float64List _cumKm;
  double _totalAnim = 0;

  late (double, double) _base; // 投影基准（GCJ 瓦片时为 GCJ 坐标）
  bool _isGcj = false;
  int get _n => widget.day.points.length;

  // ── 视口 ──
  double _zoom = 11;
  Offset _manualPan = Offset.zero;
  bool _follow = false;
  bool _fitDone = false;

  // ── 播放 ──
  late final AnimationController _ac;
  bool _playing = false;
  double _speed = 1;
  bool _resumeAfterSeek = false;

  // ── 已走过的线：**只往长**（向后拖时才重建）──
  final Path _donePath = Path();
  final Path _fullPath = Path();
  int _drawnTo = 0;
  int _rev = 0;

  @override
  void initState() {
    super.initState();
    _prepare();
    _ac = AnimationController(vsync: this, duration: _baseDuration);
    _ac.addListener(() => setState(() {}));
    _ac.addStatusListener((st) {
      if (st == AnimationStatus.completed && _playing) {
        setState(() => _playing = false);
      }
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Duration get _baseDuration {
    final ms = (_n * 200).clamp(10000, 30000);
    return Duration(milliseconds: ms.toInt());
  }

  /// 播放这一段所需时间（倍速作用在这里，不改动画时间轴本身）
  Duration get _scaledDuration => Duration(
      microseconds: (_baseDuration.inMicroseconds / _speed).round());

  // ── 地图类型：矢量图源没有栅格瓦片，回放页一律退回 OSM（同为 WGS-84）──
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

  /// WGS-84 → 底图坐标系（GCJ 图源要纠偏，否则整条轨迹偏 500m 上下）
  (double, double) _tc(double lat, double lng) =>
      _isGcj ? Gcj.wgsToGcj(lat, lng) : (lat, lng);

  void _prepare() {
    final pts = widget.day.points;
    // 先定图源再算坐标：GCJ 图源要对整条轨迹纠偏，否则会整体偏 500m 上下
    _isGcj = isGcjMapType(_tileType);
    final first = pts.isEmpty ? (0.0, 0.0) : _tc(pts.first.lat, pts.first.lng);
    _base = first;
    final c0 = MapProj.latLngToPx(_base.$1, _base.$2, 0);

    _lx = Float64List(_n);
    _ly = Float64List(_n);
    _animT = Float64List(_n);
    _cumKm = Float64List(_n);

    var anim = 0.0;
    var km = 0.0;
    for (var i = 0; i < _n; i++) {
      final t = _tc(pts[i].lat, pts[i].lng);
      final p = MapProj.latLngToPx(t.$1, t.$2, 0);
      _lx[i] = p.dx - c0.dx;
      _ly[i] = p.dy - c0.dy;
      if (i > 0) {
        final dt = pts[i].time
            .difference(pts[i - 1].time)
            .inMilliseconds
            .abs() /
            1000.0;
        // 长停顿压缩（见类注释）：超过上限的部分不计入动画时间
        anim += dt > _gapCapSec ? _gapCapSec : dt;
        km += haversine(
            pts[i - 1].lat, pts[i - 1].lng, pts[i].lat, pts[i].lng);
      }
      _animT[i] = anim;
      _cumKm[i] = km;
    }
    _totalAnim = anim;

    // 全程路径（淡线）一次建好：播放期间不再重建
    if (_n > 0) {
      _fullPath.moveTo(_lx[0], _ly[0]);
      for (var i = 1; i < _n; i++) {
        _fullPath.lineTo(_lx[i], _ly[i]);
      }
      _rev++;
    }
    _syncDrawn(0);
  }

  /// 当前播放到的点序号。按**时间轴**二分，而不是按点序号线性 —— 点数密度
  /// 不均匀（等红灯时不产点），线性映射会把停车的 20 分钟压成一个点、把
  /// 移动的 20 分钟拉成一长串，进度条与时间就完全对不上了。
  int get _index {
    if (_n < 2) return 0;
    if (_totalAnim <= 0) {
      return ((_ac.value * (_n - 1)).round()).clamp(0, _n - 1);
    }
    final t = _ac.value * _totalAnim;
    var lo = 0, hi = _n - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_animT[mid] <= t) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  Offset get _localOfIndex => Offset(_lx[_index], _ly[_index]);

  double get _zscale => math.pow(2.0, _zoom).toDouble();

  /// 当前生效的 pan：跟随时由当前点算出（不落字段，避免 build 中改状态）
  Offset get _pan {
    if (_follow && _n > 0) return _localOfIndex * -_zscale;
    return _manualPan;
  }

  /// 首次拿到尺寸时把视野套到整条轨迹上。
  ///
  /// 在 build 里直接算并写字段（不 setState）：这些值当帧就要用，而 setState
  /// 只会多来一帧空白。函数幂等，重复调用没有副作用。
  void _ensureFit(Size size) {
    if (_fitDone) return;
    _fitDone = true;
    if (_n == 0) return;
    if (_n == 1) {
      _zoom = 15;
      return;
    }
    var minX = _lx[0], maxX = _lx[0], minY = _ly[0], maxY = _ly[0];
    for (var i = 1; i < _n; i++) {
      if (_lx[i] < minX) minX = _lx[i];
      if (_lx[i] > maxX) maxX = _lx[i];
      if (_ly[i] < minY) minY = _ly[i];
      if (_ly[i] > maxY) maxY = _ly[i];
    }
    // 上下留出顶栏与回放条的位置，别让轨迹压在控件下面
    final availW = (size.width - 72).clamp(64.0, 100000.0);
    final availH = (size.height - 250).clamp(64.0, 100000.0);
    final spanX = math.max(maxX - minX, 1e-9);
    final spanY = math.max(maxY - minY, 1e-9);
    final z = math.min(
        math.log(availW / spanX) / math.ln2, math.log(availH / spanY) / math.ln2);
    _zoom = z.clamp(2.0, 18.0);
    final zs = math.pow(2.0, _zoom).toDouble();
    _manualPan = Offset(-(minX + maxX) / 2 * zs, -(minY + maxY) / 2 * zs);
  }

  /// 把「已走过」的线延长到 [idx]（只增不减，向后拖时才重建）
  void _syncDrawn(int idx) {
    if (idx < _drawnTo) {
      _donePath.reset();
      _donePath.moveTo(_lx[0], _ly[0]);
      for (var i = 1; i <= idx; i++) {
        _donePath.lineTo(_lx[i], _ly[i]);
      }
      _drawnTo = idx;
      _rev++;
      return;
    }
    if (idx == _drawnTo) return;
    for (var i = _drawnTo + 1; i <= idx; i++) {
      _donePath.lineTo(_lx[i], _ly[i]);
    }
    _drawnTo = idx;
    _rev++;
  }

  // ── 播放控制 ──
  void _toggle() {
    if (_n < 2) return;
    if (_playing) {
      _ac.stop();
      setState(() => _playing = false);
      return;
    }
    if (_ac.value >= 1) _ac.value = 0;
    _ac.duration = _scaledDuration;
    _ac.forward();
    setState(() => _playing = true);
  }

  void _setSpeed(double s) {
    setState(() => _speed = s);
    if (_playing) {
      _ac.duration = _scaledDuration;
      _ac.forward();
    }
  }

  void _seek(double p) {
    _ac.value = p.clamp(0.0, 1.0);
    setState(() {});
  }

  void _toggleFollow() {
    setState(() {
      if (_follow) {
        // 退出跟随：把当前视野冻住，别跳回上一次的手动位置
        _manualPan = _pan;
        _follow = false;
      } else {
        _follow = true;
        if (_zoom < _followZoom) _zoom = _followZoom;
      }
    });
  }

  static String _hms(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final day = widget.day;
    return Scaffold(
      backgroundColor: C.pageFill,
      extendBodyBehindAppBar: true,
      appBar: MaterialAppBar(AppBar(
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
              child: Icon(Icons.route_rounded, color: C.green, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                dayLabelText(context, day.day),
                style: ts(16, w: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // ⚠ `overWallpaper` 是 **MaterialAppBar** 的参数，不是 AppBar 的（写进
        // AppBar 里会报 undefined_named_parameter —— CI 上踩过一次）。
        // 这一页写了 `extendBodyBehindAppBar: true`：顶栏背后是**地图**（内容），
        // 不是壁纸 —— 所以照旧要真模糊（见 material.dart 的 MaterialSurface.overWallpaper）。
      ), overWallpaper: false),
      body: LayoutBuilder(builder: (context, cons) {
        final size = Size(cons.maxWidth, cons.maxHeight);
        _ensureFit(size);
        final idx = _n == 0 ? 0 : _index;
        _syncDrawn(idx);
        final pan = _pan;
        return Stack(
          children: [
            Positioned.fill(
              child: TileMapView(
                centerLat: _base.$1,
                centerLng: _base.$2,
                zoom: _zoom,
                pan: pan,
                onPan: (d) => setState(() {
                  // 跟随时先把手势起点接到当前视野上，再累加，否则会瞬移
                  if (_follow) {
                    _manualPan = _pan;
                    _follow = false;
                  }
                  _manualPan += d;
                }),
                onViewChanged: (z, p) => setState(() {
                  _follow = false;
                  _zoom = z;
                  _manualPan = p;
                }),
                onZoomRequest: (z, p) => setState(() {
                  _zoom = z;
                  if (!_follow) _manualPan = p;
                }),
                onTap: (_) {},
                mapType: _tileType,
                cacheEnabled: widget.state.tileCacheOn,
                offlineOnly: widget.state.offlineOnly,
              ),
            ),
            if (_n > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ReplayPainter(
                      n: _n,
                      idx: idx,
                      lx: _lx,
                      ly: _ly,
                      zscale: _zscale,
                      origin: Offset(size.width / 2 + pan.dx,
                          size.height / 2 + pan.dy),
                      full: _fullPath,
                      done: _donePath,
                      course: day.points[idx].course,
                      rev: _rev,
                    ),
                  ),
                ),
              ),
            if (_n < 2)
              Center(
                child: MaterialSurface(
                  radius: 16,
                  blurSigma: C.chipBlur,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: C.chipFill,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: C.grey),
                        const SizedBox(width: 8),
                        Text(s.historyEmpty, style: ts(12, c: C.slate)),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(top: false, child: _controls(s, idx)),
            ),
          ],
        );
      }),
    );
  }

  Widget _controls(S s, int idx) {
    final pts = widget.day.points;
    final p = pts.isEmpty ? null : pts[idx];
    final done = _ac.value >= 1;
    final label = _playing
        ? s.historyPause
        : (done ? s.historyReplay : s.historyPlay);
    return MaterialSurface(
      radius: 18,
      blurSigma: C.chipBlur,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: C.chipFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: C.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Tooltip(
                  message: label,
                  child: GestureDetector(
                    onTap: _n < 2 ? null : _toggle,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: C.accentDeco(
                        radius: 12,
                        fallback: const [
                          Color(0xFF16A34A),
                          Color(0xFF0B7A37),
                        ],
                      ),
                      child: Icon(
                        _playing
                            ? Icons.pause_rounded
                            : (done
                                ? Icons.replay_rounded
                                : Icons.play_arrow_rounded),
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p == null ? '--:--:--' : _hms(p.time),
                        style: ts(15, w: FontWeight.w800),
                      ),
                      Text(
                        p == null
                            ? ''
                            : '${p.speedKmh.toStringAsFixed(0)} km/h · '
                                '${fmtKm(_cumKm[idx])}',
                        style: ts(10, c: C.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: s.historyFollow,
                  child: GestureDetector(
                    onTap: _toggleFollow,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _follow ? C.blue : C.bgSoft,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: _follow ? C.blue : C.border),
                      ),
                      child: Icon(
                        Icons.my_location_rounded,
                        size: 17,
                        color: _follow ? Colors.white : C.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: C.green,
                inactiveTrackColor: C.border,
                thumbColor: C.green,
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: _ac.value.clamp(0.0, 1.0),
                onChangeStart: _n < 2
                    ? null
                    : (_) {
                        // 拖动进度条时先暂停，否则动画与手指抢同一个进度
                        _resumeAfterSeek = _playing;
                        if (_playing) {
                          _ac.stop();
                          setState(() => _playing = false);
                        }
                      },
                onChanged: _n < 2 ? null : _seek,
                onChangeEnd: (_) {
                  if (_resumeAfterSeek) _toggle();
                  _resumeAfterSeek = false;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Text(
                    '${fmtKm(_cumKm.isEmpty ? 0 : _cumKm[_n - 1])} · '
                    '${widget.day.count}',
                    style: ts(10, c: C.grey),
                  ),
                  const Spacer(),
                  for (final sp in const [0.5, 1.0, 2.0, 4.0]) ...[
                    GestureDetector(
                      onTap: () => _setSpeed(sp),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: _speed == sp ? C.blue : C.bgSoft,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                              color: _speed == sp ? C.blue : C.border),
                        ),
                        child: Text(
                          '×${sp == sp.roundToDouble() ? sp.toInt() : sp}',
                          style: ts(10,
                              c: _speed == sp ? Colors.white : C.grey,
                              w: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 轨迹绘制：淡线=全程、实线=已走过、端点=起点/终点、亮点=当前点。
///
/// 所有坐标都在「相对基准点的 zoom-0 局部像素」里，绘制时用
/// `canvas.scale(2^zoom)` 一次变换到位 —— 于是**每帧不需要重算任何点**
/// （几千点的轨迹也能满帧拖动），代价是画笔宽度要先除以缩放倍数。
class _ReplayPainter extends CustomPainter {
  final int n, idx;
  final Float64List lx, ly;
  final double zscale;
  final Offset origin;
  final Path full, done;
  final double? course;
  final int rev;

  _ReplayPainter({
    required this.n,
    required this.idx,
    required this.lx,
    required this.ly,
    required this.zscale,
    required this.origin,
    required this.full,
    required this.done,
    required this.course,
    required this.rev,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (n == 0) return;
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(zscale);
    final w = 1 / zscale;

    if (n > 1) {
      canvas.drawPath(
        full,
        Paint()
          ..color = C.blue.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        done,
        Paint()
          ..color = C.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4 * w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      // 起点（灰）与终点（橙）
      canvas.drawCircle(Offset(lx[0], ly[0]), 4 * w,
          Paint()..color = C.greyLight);
      canvas.drawCircle(Offset(lx[n - 1], ly[n - 1]), 4.5 * w,
          Paint()..color = C.orange);
    }

    // 当前点：白圈 + 绿心 +（有航向时）朝向箭头。
    // 航向在这里特别有用：轨迹线只能看出「从哪到哪」，箭头能看出**朝哪走**，
    // 单向道/掉头这种一眼就分出来了。
    final cur = Offset(lx[idx], ly[idx]);
    canvas.drawCircle(cur, 7.5 * w, Paint()..color = Colors.white);
    canvas.drawCircle(cur, 5 * w, Paint()..color = C.green);
    final c = course;
    if (c != null && c >= 0) {
      final rad = c * math.pi / 180;
      final dir = Offset(math.sin(rad), -math.cos(rad));
      final tip = cur + dir * (15 * w);
      final left = cur + Offset(-dir.dy, dir.dx) * (6 * w) + dir * (8 * w);
      final right = cur - Offset(-dir.dy, dir.dx) * (6 * w) + dir * (8 * w);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(left.dx, left.dy)
          ..lineTo(right.dx, right.dy)
          ..close(),
        Paint()..color = C.green,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReplayPainter old) =>
      old.rev != rev ||
      old.idx != idx ||
      old.zscale != zscale ||
      old.origin != origin ||
      old.course != course ||
      !identical(old.lx, lx);
}
