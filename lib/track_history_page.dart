import 'package:flutter/material.dart';

import 'material.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'track_day_page.dart';
import 'track_log.dart';
import 'widgets.dart';

/// ─── 历史轨迹页（设置 → 历史轨迹）───
///
/// 只读展示 [TrackLogStore] 里按天保存的个人轨迹台账：每天的里程、平均/最高
/// 速度、移动时长、点数，以及一张极简的点列预览。删除粒度是「天」，
/// 不提供「删除单个点」—— 轨迹点单看没有意义，而且误删一个点就会把当天的
/// 里程算短，比不能删更糟。
///
/// **点按某一天**进入 [TrackDayPage]：底图 + 回放动画。列表里的预览只是
/// 「形状对不对」，要看「怎么走的」必须进详情页。
class TrackHistoryPage extends StatefulWidget {
  final AppState state;
  const TrackHistoryPage({super.key, required this.state});

  @override
  State<TrackHistoryPage> createState() => _TrackHistoryPageState();
}

class _TrackHistoryPageState extends State<TrackHistoryPage> {
  List<DayTrack> _days = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final days = await TrackLogStore.instance.loadAll();
    if (!mounted) return;
    setState(() {
      _days = days;
      _loading = false;
    });
  }

  /// 打开某一天的地图回放
  void _openDay(DayTrack d) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrackDayPage(day: d, state: widget.state),
      ),
    );
  }

  Future<void> _confirmDeleteDay(DayTrack d) async {
    final s = S.of(context);
    final label = dayLabelText(context, d.day);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => MaterialSurface(
        radius: 16,
        child: AlertDialog(
          backgroundColor: C.sheetFill,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(s.historyClearDay, style: ts(16, w: FontWeight.w700)),
          content: Text(
            '$label · ${fmtKm(d.distanceKm)}',
            style: ts(13, c: C.slate),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel, style: ts(13, c: C.grey)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.delete, style: ts(13)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await TrackLogStore.instance.deleteDay(d.day);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.of(context).historyCleared)));
    await _reload();
  }

  Future<void> _confirmClearAll() async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => MaterialSurface(
        radius: 16,
        child: AlertDialog(
          backgroundColor: C.sheetFill,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(s.historyClearAll, style: ts(16, w: FontWeight.w700)),
          content: Text(s.historyClearAllConfirm,
              style: ts(13, c: C.slate, h: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel, style: ts(13, c: C.grey)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.clear, style: ts(13)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await TrackLogStore.instance.clearAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.of(context).historyClearedAll)));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageShell(
      guideId: 'trackHistory',
      state: widget.state,
      title: S.of(context).historyTracks,
      subtitle: S.of(context).historyTracksDesc,
      icon: Icons.route_rounded,
      color: C.green,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_days.isEmpty)
            _emptyCard()
          else ...[
            _summaryCard(),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 13, color: C.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    S.of(context).historyTapDay,
                    style: ts(10, c: C.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final d in _days) ...[
              _dayCard(d),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _confirmClearAll,
              style: OutlinedButton.styleFrom(
                foregroundColor: C.red,
                side: BorderSide(color: C.red.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: ts(13, w: FontWeight.w700),
              ),
              icon: const Icon(Icons.delete_sweep_rounded, size: 17),
              label: Text(S.of(context).historyClearAll),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDeco(),
      child: Column(
        children: [
          Icon(Icons.route_rounded, size: 34, color: C.grey),
          const SizedBox(height: 10),
          Text(
            S.of(context).historyEmpty,
            textAlign: TextAlign.center,
            style: ts(12, c: C.slate, h: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    var totalKm = 0.0;
    var points = 0;
    for (final d in _days) {
      totalKm += d.distanceKm;
      points += d.count;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, size: 20, color: C.green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.of(context).historyTotalDistance,
                    style: ts(11, c: C.grey)),
                Text(fmtKm(totalKm),
                    style: ts(20, c: C.green, w: FontWeight.w800)),
              ],
            ),
          ),
          Text(
            '${_days.length} · $points',
            style: ts(11, c: C.grey),
          ),
        ],
      ),
    );
  }

  Widget _dayCard(DayTrack d) {
    // 点整张卡片进详情：预览只能看形状，回放才看得出「怎么走的」
    return GestureDetector(onTap: () => _openDay(d), child: _dayCardBody(d));
  }

  Widget _dayCardBody(DayTrack d) {
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_rounded, size: 16, color: C.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dayLabelText(context, d.day),
                  style: ts(13, w: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                s.historyPoints + ' ${d.count}',
                style: ts(10, c: C.grey),
              ),
              // 卡片可点进回放页：给一个明确的指示符，否则用户不知道能点
              Icon(Icons.chevron_right_rounded, size: 18, color: C.grey),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: C.grey),
                tooltip: s.historyClearDay,
                onPressed: () => _confirmDeleteDay(d),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 64,
              width: double.infinity,
              color: C.bgSoft,
              child: d.count < 2
                  ? Center(
                      child: Text(s.historyPoints + ' ${d.count}',
                          style: ts(10, c: C.grey)),
                    )
                  : CustomPaint(
                      painter: _DayPreviewPainter(d.points),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _stat(s.distance, fmtKm(d.distanceKm), C.green),
              _stat(s.statsAvgSpeed,
                  '${d.avgSpeedKmh.toStringAsFixed(1)} km/h', C.blue),
              _stat(s.historyMaxSpeed,
                  '${d.maxSpeedKmh.toStringAsFixed(0)} km/h', C.orange),
              _stat(s.historyMovingTime, fmtDur(d.movingTime), C.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ts(9, c: C.grey)),
        const SizedBox(height: 2),
        Text(value, style: ts(13, c: color, w: FontWeight.w700)),
      ],
    );
  }
}

/// 一天轨迹的极简预览：把经纬度按等比缩放画进小框。
///
/// 等比（而不是分别拉满宽高）是必要的：分别拉满会把一条南北向的直线
/// 画成对角线，预览就变成了「形状完全不对的装饰」。宁可两侧留白。
class _DayPreviewPainter extends CustomPainter {
  final List<TrackLogPoint> pts;
  _DayPreviewPainter(this.pts);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    var minLat = pts.first.lat, maxLat = pts.first.lat;
    var minLng = pts.first.lng, maxLng = pts.first.lng;
    for (final p in pts) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }
    final spanLat = (maxLat - minLat).abs();
    final spanLng = (maxLng - minLng).abs();
    final span = spanLat > spanLng ? spanLat : spanLng;
    if (span <= 0) return;
    const pad = 8.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    if (w <= 0 || h <= 0) return;
    // 以较大跨度为准做等比缩放，居中
    final scale = (w < h ? w : h) / span;
    final offX = pad + (w - spanLng * scale) / 2;
    final offY = pad + (h - spanLat * scale) / 2;
    double sx(double lng) => offX + (lng - minLng) * scale;
    double sy(double lat) => offY + (maxLat - lat) * scale;

    final path = Path()..moveTo(sx(pts.first.lng), sy(pts.first.lat));
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(sx(pts[i].lng), sy(pts[i].lat));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = C.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    // 起终点：起点空心、终点实心
    canvas.drawCircle(
        Offset(sx(pts.first.lng), sy(pts.first.lat)), 2.6, Paint()..color = C.green);
    canvas.drawCircle(Offset(sx(pts.last.lng), sy(pts.last.lat)), 3.2,
        Paint()..color = C.orange);
  }

  @override
  bool shouldRepaint(covariant _DayPreviewPainter old) =>
      !identical(old.pts, pts);
}
