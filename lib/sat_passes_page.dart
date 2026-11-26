import 'package:flutter/material.dart';

import 'satellite.dart';
import 'satellites_page.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// 过境列表：把**收藏的卫星**未来 1~3 天的过境按时间排成一张表，
/// 点任意一条就切到那颗星 + 那条过境，回到操作台。
class SatPassesPage extends StatefulWidget {
  final AppState state;
  const SatPassesPage({super.key, required this.state});

  @override
  State<SatPassesPage> createState() => _SatPassesPageState();
}

class _SatPassesPageState extends State<SatPassesPage> {
  AppState get st => widget.state;

  int _hours = 48;
  bool _loading = true;
  List<_PassRow> _rows = const [];
  int _scanSeq = 0;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    final seq = ++_scanSeq;
    setState(() => _loading = true);
    // 先让 loading 这一帧画出来，再算（收藏多时也不会像卡死）。
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final lat = st.myLat;
    final lng = st.myLng;
    if (lat == null || lng == null) {
      if (!mounted || seq != _scanSeq) return;
      setState(() {
        _rows = const [];
        _loading = false;
      });
      return;
    }
    final favorites = <Tle>[
      for (final t in st.satTles)
        if (st.isSatFavorite(t.name)) t,
    ];
    final sats = favorites.isNotEmpty
        ? favorites
        : [if (st.satSelected != null) st.satSelected!];
    final now = DateTime.now().toUtc();
    // 与 AppState.satPasses 同样往回看 20 分钟：正在进行的过境要有真实 AOS。
    final from = now.subtract(const Duration(minutes: 20));
    final within = Duration(hours: _hours) + const Duration(minutes: 20);
    final rows = <_PassRow>[];
    for (final t in sats.take(16)) {
      final list = passesWithin(
        t,
        lat,
        lng,
        from: from,
        within: within,
        minElevationDeg: 10,
        maxPasses: 8,
      );
      for (final p in list) {
        if (!p.los.isBefore(now)) rows.add(_PassRow(t, p));
      }
    }
    rows.sort((a, b) => a.pass.aos.compareTo(b.pass.aos));
    if (!mounted || seq != _scanSeq) return;
    setState(() {
      _rows = rows.take(40).toList();
      _loading = false;
    });
  }

  Future<void> _sync() async {
    final s = S.of(context);
    final ok = await st.syncSatEphemeris();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? s.satSyncOk : s.satSyncFail),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (ok) _scan();
  }

  void _open(_PassRow row) {
    st.selectSatPass(row.tle.name, row.pass.aos);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        title: Text(s.satPasses),
        actions: [
          IconButton(
            tooltip: s.satSync,
            onPressed: st.satSyncing ? null : _sync,
            icon: st.satSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.sync_rounded, color: C.slate),
          ),
          IconButton(
            tooltip: s.refresh,
            onPressed: _loading ? null : _scan,
            icon: Icon(Icons.refresh_rounded, color: C.slate),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            ValueListenableBuilder<int>(
              valueListenable: st.tick,
              builder: (context, _, _) => _nextCard(context, s),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  _chip(s, 24, s.sat24h),
                  const SizedBox(width: 8),
                  _chip(s, 48, s.sat48h),
                  const SizedBox(width: 8),
                  _chip(s, 72, s.sat72h),
                  const Spacer(),
                  Text('${_rows.length}', style: ts(10.5, c: C.grey)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, size: 12, color: C.orange),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(s.satFavHint,
                        style: ts(9.5, c: C.grey), maxLines: 2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _body(context, s),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(S s, int h, String label) => ChoiceChip(
        label: Text(label, style: ts(11)),
        selected: _hours == h,
        onSelected: (_) {
          if (_hours == h) return;
          setState(() => _hours = h);
          _scan();
        },
        visualDensity: VisualDensity.compact,
        selectedColor: C.blue.withValues(alpha: 0.16),
        backgroundColor: C.bgSoft,
        side: BorderSide(color: C.border),
        labelStyle: ts(11, c: _hours == h ? C.blue : C.slate),
      );

  Widget _nextCard(BuildContext context, S s) {
    final now = DateTime.now().toUtc();
    final next = _rows.isEmpty
        ? null
        : _rows.firstWhere(
            (r) => r.pass.los.isAfter(now),
            orElse: () => _rows.last,
          );
    final inPass = next != null &&
        !now.isBefore(next.pass.aos) &&
        now.isBefore(next.pass.los);
    final title = next == null
        ? (_rows.isEmpty ? s.satNoPass : s.satPassOver)
        : inPass
            ? '${s.satInPass} · ${next.tle.name}'
            : '${s.satWaitAos} · ${next.tle.name}';
    final remain = next == null
        ? null
        : inPass
            ? next.pass.los.difference(now)
            : next.pass.aos.difference(now);
    final color = inPass ? C.green : (next == null ? C.grey : C.orange);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: C.surfaceFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(inPass ? Icons.sensors_rounded : Icons.timer_outlined,
              size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ts(12, c: color, w: FontWeight.w700)),
                if (next != null)
                  Text(
                    'AOS ${_hm(next.pass.aos)}  ·  LOS ${_hm(next.pass.los)}'
                    '  ·  ${next.pass.maxElevation.toStringAsFixed(0)}°',
                    style: ts(9.5, c: C.grey),
                  ),
              ],
            ),
          ),
          if (remain != null)
            Text(_mmss(remain),
                style: ts(24, c: color, w: FontWeight.w800, ls: -0.5)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, S s) {
    if (st.myLat == null || st.myLng == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(s.satNoPosition, style: ts(12, c: C.grey)),
        ),
      );
    }
    final hasFav = st.satTles.any((t) => st.isSatFavorite(t.name));
    if (_rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_rounded, size: 40, color: C.greyLight),
              const SizedBox(height: 8),
              Text(
                hasFav || st.satSelected != null
                    ? s.satNoPass
                    : s.satNoFavorites,
                textAlign: TextAlign.center,
                style: ts(12, c: C.grey),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SatellitesPage(state: st),
                  ),
                ),
                child: Text(s.satCatalog, style: ts(12, c: C.blue)),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      itemCount: _rows.length,
      itemBuilder: (context, i) => _passCard(context, s, _rows[i]),
    );
  }

  Widget _passCard(BuildContext context, S s, _PassRow row) {
    final p = row.pass;
    final now = DateTime.now().toUtc();
    final inPass = !now.isBefore(p.aos) && now.isBefore(p.los);
    final progress = inPass
        ? (now.difference(p.aos).inMicroseconds / p.duration.inMicroseconds)
            .clamp(0.0, 1.0)
        : 0.0;
    final active = st.satName == normalizeSatName(row.tle.name) &&
        st.satPickedPass?.aos.isAtSameMomentAs(p.aos) == true;
    return GestureDetector(
      onTap: () => _open(row),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: inPass ? C.green.withValues(alpha: 0.07) : C.surfaceFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inPass
                ? C.green.withValues(alpha: 0.55)
                : (active ? C.blue.withValues(alpha: 0.55) : C.border),
            width: active || inPass ? 1.2 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.tle.name,
                    style: ts(13.5, w: FontWeight.w800, ls: -0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.vertical_align_top_rounded,
                    size: 12, color: C.orange),
                Text(' ${p.maxElevation.toStringAsFixed(0)}°',
                    style: ts(11.5, c: C.orange, w: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(_dayHm(p.aos), style: ts(10, c: C.grey)),
                const Spacer(),
                Text(
                  '${_az(row.tle, p.aos)}° → ${_az(row.tle, p.los)}°',
                  style: ts(10, c: C.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(_hm(p.aos), style: ts(10, c: C.slate)),
                const SizedBox(width: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: C.bgSoft,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          inPass ? C.green : C.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(_hm(p.los), style: ts(10, c: C.slate)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('${p.duration.inMinutes} min',
                    style: ts(9.5, c: C.grey)),
                const Spacer(),
                if (inPass)
                  Text(s.satInPass,
                      style: ts(9.5, c: C.green, w: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  String _az(Tle t, DateTime at) {
    final lat = st.myLat;
    final lng = st.myLng;
    if (lat == null || lng == null) return '--';
    return lookAt(t, lat, lng, at).azimuthDeg.toStringAsFixed(0);
  }

  String _dayHm(DateTime t) {
    final l = t.toLocal();
    final h = _hm(l);
    return '${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')} $h';
  }

  String _mmss(Duration d) {
    final sec = d.inSeconds.clamp(0, 359999);
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}

class _PassRow {
  final Tle tle;
  final SatPass pass;
  const _PassRow(this.tle, this.pass);
}
