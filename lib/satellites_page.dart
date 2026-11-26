import 'package:flutter/material.dart';

import 'sat_passes_page.dart';
import 'satellite.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// 卫星目录（Look4Sat 的 Satellites 页思路）：
/// 搜索 + 收藏；收藏的星才会进过境列表。
class SatellitesPage extends StatefulWidget {
  final AppState state;
  const SatellitesPage({super.key, required this.state});

  @override
  State<SatellitesPage> createState() => _SatellitesPageState();
}

class _SatellitesPageState extends State<SatellitesPage> {
  AppState get st => widget.state;
  final TextEditingController _search = TextEditingController();
  bool _onlyFav = false;
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
    setState(() {});
  }

  /// 把 Celestrak 业余组里能认出来的 APRS 星一次收藏。
  void _favAprs(S s) {
    var n = 0;
    for (final t in st.satTles) {
      final upper = t.name.toUpperCase();
      final aprs = upper.contains('ISS') ||
          upper.contains('NO-84') ||
          upper.contains('PSAT') ||
          upper.contains('PCSAT');
      if (!aprs) continue;
      if (!st.isSatFavorite(t.name)) {
        st.toggleSatFavorite(t.name);
        n++;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(n > 0 ? '${s.satFavorites} +$n' : s.satFavHint),
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() {});
  }

  List<Tle> _visible() {
    final q = _q.trim().toUpperCase();
    final list = <Tle>[
      for (final t in st.satTles)
        if (q.isEmpty || t.name.toUpperCase().contains(q))
          if (!_onlyFav || st.isSatFavorite(t.name)) t,
    ];
    list.sort((a, b) {
      final fa = st.isSatFavorite(a.name) ? 0 : 1;
      final fb = st.isSatFavorite(b.name) ? 0 : 1;
      if (fa != fb) return fa - fb;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final list = _visible();
    final favCount = st.satFavorites.length;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        title: Text(s.satCatalog),
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
            tooltip: s.satPasses,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SatPassesPage(state: st)),
            ),
            icon: Icon(Icons.format_list_bulleted_rounded, color: C.slate),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: TextField(
                controller: _search,
                style: ts(13),
                decoration: InputDecoration(
                  hintText: s.search,
                  hintStyle: ts(13, c: C.grey),
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 18, color: C.grey),
                  suffixIcon: _q.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 16, color: C.grey),
                          onPressed: () {
                            _search.clear();
                            setState(() => _q = '');
                          },
                        ),
                  filled: true,
                  fillColor: C.bgSoft,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: C.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: C.border),
                  ),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(s.all, style: ts(11)),
                    selected: !_onlyFav,
                    onSelected: (_) => setState(() => _onlyFav = false),
                    visualDensity: VisualDensity.compact,
                    selectedColor: C.blue.withValues(alpha: 0.16),
                    backgroundColor: C.bgSoft,
                    side: BorderSide(color: C.border),
                    labelStyle: ts(11, c: !_onlyFav ? C.blue : C.slate),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: Icon(Icons.star_rounded,
                        size: 13,
                        color: _onlyFav ? C.orange : C.grey),
                    label: Text('${s.satFavorites} $favCount',
                        style: ts(11)),
                    selected: _onlyFav,
                    onSelected: (_) => setState(() => _onlyFav = true),
                    visualDensity: VisualDensity.compact,
                    selectedColor: C.orange.withValues(alpha: 0.14),
                    backgroundColor: C.bgSoft,
                    side: BorderSide(color: C.border),
                    labelStyle:
                        ts(11, c: _onlyFav ? C.orange : C.slate),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _favAprs(s),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                    ),
                    child: Text(s.satFavAprs,
                        style: ts(10.5, c: C.blue, w: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
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
              child: st.satTles.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.satellite_alt_rounded,
                                size: 42, color: C.greyLight),
                            const SizedBox(height: 8),
                            Text(s.satNeedSync,
                                textAlign: TextAlign.center,
                                style: ts(12, c: C.grey)),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: st.satSyncing ? null : _sync,
                              style: FilledButton.styleFrom(
                                  backgroundColor: C.blue),
                              child: Text(s.satSync, style: ts(12.5)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : list.isEmpty
                      ? Center(
                          child: Text(
                            _q.isEmpty ? s.satFavHint : s.search,
                            style: ts(12, c: C.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          itemCount: list.length,
                          itemBuilder: (context, i) =>
                              _row(context, s, list[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, S s, Tle t) {
    final fav = st.isSatFavorite(t.name);
    final selected = normalizeSatName(t.name) == st.satName;
    final custom = st.satIsCustom(t.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: selected ? C.blue.withValues(alpha: 0.08) : C.sheetFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? C.blue.withValues(alpha: 0.5) : C.border,
          width: selected ? 1.1 : 0.8,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: s.satFavorites,
            onPressed: () {
              st.toggleSatFavorite(t.name);
              setState(() {});
            },
            icon: Icon(
              fav ? Icons.star_rounded : Icons.star_border_rounded,
              size: 20,
              color: fav ? C.orange : C.greyLight,
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                st.setSatName(t.name);
                Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      style: ts(13, w: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      custom
                          ? s.satCustom
                          : (selected ? s.satSatellite : ''),
                      style: ts(9.5, c: C.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.check_rounded, size: 16, color: C.blue),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right_rounded,
                  size: 16, color: C.greyLight),
            ),
        ],
      ),
    );
  }
}
