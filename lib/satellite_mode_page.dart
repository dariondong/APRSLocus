import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'satellite.dart';
import 'satellite_point_page.dart';
import 'sat_overlay.dart';
import 'sat_passes_page.dart';
import 'sat_transponders.dart';
import 'satellites_page.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── APRS 卫星模式面板 ───
///
/// 把原来藏在 On-Air 页里的卫星 QSO 提升成一个**模式**：
///   * 选星 / 同步星历 / 看下一次过境；
///   * 实时仰角、方位、距离、距离变化率；
///   * 按多普勒修正上行 / 下行频率；
///   * 卫星路径（默认 ARISS）—— 开启模式后 TNC / 音频的射频报文改走它。
///
/// 不做自动改频：这里只给读数与一键复制/设为守听；真正拧电台仍由用户决定。
class SatelliteModePage extends StatelessWidget {
  final AppState state;

  /// 作为**卫星模式外壳**的底部面板使用：不套设置页外壳，直接给一个可滚动列表。
  final bool embedded;

  /// 嵌入时由 `DraggableScrollableSheet` 提供的滚动控制器。
  final ScrollController? scrollController;

  const SatelliteModePage({
    super.key,
    required this.state,
    this.embedded = false,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    List<Widget> cards() => [
          _modeCard(context, s),
          const SizedBox(height: 16),
          _passCard(context, s),
          const SizedBox(height: 16),
          _lookCard(context, s),
          const SizedBox(height: 16),
          _freqCard(context, s),
          const SizedBox(height: 16),
          _transponderCard(context, s),
          const SizedBox(height: 24),
        ];
    if (embedded) {
      return ListenableBuilder(
        listenable: state,
        builder: (context, _) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: cards(),
        ),
      );
    }
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => SettingsPageShell(
        title: s.satMode,
        subtitle: s.satModeDesc,
        icon: Icons.satellite_alt_rounded,
        color: C.blue,
        body: Column(children: cards()),
      ),
    );
  }

  // ─── 选星 / 同步 ───

  List<String> _names() {
    final out = <String>[];
    for (final t in state.satTles) {
      final n = normalizeSatName(t.name);
      if (n.isNotEmpty && !out.contains(n)) out.add(n);
    }
    out.sort();
    return out;
  }

  Widget _modeCard(BuildContext context, S s) {
    final names = _names();
    return SettingsSectionCard(
      title: s.satMode,
      icon: Icons.satellite_alt_rounded,
      color: C.blue,
      children: [
        SettingsSwitch(
          s.satMode,
          value: state.satelliteMode,
          color: C.blue,
          onChanged: state.setSatelliteMode,
        ),
        SettingsHint(s.satModeDesc),
        InkWell(
          onTap: names.isEmpty ? null : () => _pickSat(context, names),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
            ),
            child: Row(
              children: [
                Text(s.satSatellite, style: ts(13)),
                const Spacer(),
                Text(
                  state.satName.isEmpty ? s.satNeedSync : state.satName,
                  style: ts(12.5,
                      c: state.satName.isEmpty ? C.grey : C.ink,
                      w: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 16, color: C.grey),
              ],
            ),
          ),
        ),
        SettingsNavRow(
          title: s.satCatalog,
          trailing: '${state.satFavorites.length}',
          icon: Icons.satellite_alt_rounded,
          color: C.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SatellitesPage(state: state)),
          ),
        ),
        SettingsNavRow(
          title: s.satPasses,
          icon: Icons.format_list_bulleted_rounded,
          color: C.indigo,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SatPassesPage(state: state)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: C.blue,
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              onPressed: state.satSyncing ? null : () => _sync(context),
              child: state.satSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(s.satSync, style: ts(13)),
            ),
          ),
        ),
      ],
    );
  }

  // ─── 过境 ───

  Widget _passCard(BuildContext context, S s) {
    final names = _names();
    final passes = state.satPasses();
    final pass = state.satPickedPass;
    final tle = state.satSelected;
    final lat = state.myLat;
    final lng = state.myLng;
    final canPlot = tle != null && lat != null && lng != null;
    return SettingsSectionCard(
      title: s.satNextPass,
      icon: Icons.upcoming_rounded,
      color: C.indigo,
      children: [
        if (names.isEmpty)
          SettingsHint(s.satNeedSync, color: C.orange)
        else if (pass == null)
          SettingsHint(s.satNoPass, color: C.orange)
        else ...[
          // 极坐标天空图：外圈地平线、圆心天顶；轨迹 + 当前星位。
          if (canPlot) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
              child: Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: state.tick,
                  builder: (_, _, _) => SizedBox(
                    width: 210,
                    height: 210,
                    child: _SkyPlot(
                      tle: tle,
                      lat: lat,
                      lng: lng,
                      pass: pass,
                      now: DateTime.now(),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendDot(C.green, s.satAos),
                  const SizedBox(width: 12),
                  _legendDot(C.orange, 'TCA'),
                  const SizedBox(width: 12),
                  _legendDot(C.red, s.satLos),
                ],
              ),
            ),
          ],
          SettingsRow2(
            s.satNextPass,
            s.satPass(_hm(pass.tca), pass.maxElevation.toStringAsFixed(0)),
            valueColor: C.ink,
          ),
          SettingsRow2(
            '${s.satAos} / ${s.satLos}',
            '${_hm(pass.aos)} / ${_hm(pass.los)}',
          ),
          if (passes.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
              child: Column(
                children: [
                  for (var i = 0; i < passes.length && i < 6; i++)
                    _passRow(passes[i], i == state.satPassIndex, i),
                ],
              ),
            ),
          SettingsHint(s.satEstimate),
        ],
      ],
    );
  }

  Widget _legendDot(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label, style: ts(9.5, c: C.grey)),
        ],
      );

  Widget _passRow(SatPass p, bool active, int i) {
    final mins = p.duration.inMinutes;
    return GestureDetector(
      onTap: () => state.setSatPassIndex(i),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? C.indigo.withValues(alpha: 0.10) : C.bgSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? C.indigo : C.border,
            width: active ? 1.2 : 0.6,
          ),
        ),
        child: Row(
          children: [
            Icon(
              active
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 14,
              color: active ? C.indigo : C.greyLight,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${_when(p.aos)} → ${_hm(p.los)}',
                style: ts(11.5,
                    c: active ? C.ink : C.slate,
                    w: active ? FontWeight.w700 : FontWeight.w500),
              ),
            ),
            Text(
              '${p.maxElevation.toStringAsFixed(0)}° · $mins min',
              style: ts(10.5, c: active ? C.indigo : C.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 实时仰角 / 方位 / 多普勒 ───

  Widget _lookCard(BuildContext context, S s) {
    final t = state.satSelected;
    final lat = state.myLat;
    final lng = state.myLng;
    if (t == null || lat == null || lng == null) {
      return SettingsSectionCard(
        title: s.satDoppler,
        icon: Icons.my_location_rounded,
        color: C.cyan,
        children: [SettingsHint(s.satNoPosition, color: C.orange)],
      );
    }
    return ValueListenableBuilder<int>(
      valueListenable: state.tick,
      builder: (context, _, _) {
        final look = lookAt(t, lat, lng, DateTime.now());
        final dUp = dopplerHz(state.satUpMhz, look.rangeRateKmS);
        final dDown = dopplerHz(state.satDownMhz, look.rangeRateKmS);
        // 下行：把接收频率往上/下修到实际信号；上行：反向补偿，让信号到达
        // 卫星时落在标称频率（见 satellite.dart 的 dopplerHz 注释）。
        final up = state.satUpMhz - dUp / 1e6;
        final down = state.satDownMhz + dDown / 1e6;
        return SettingsSectionCard(
          title: s.satDoppler,
          icon: Icons.my_location_rounded,
          color: C.cyan,
          children: [
            SettingsRow2(s.satElevation,
                '${look.elevationDeg.toStringAsFixed(1)}°'),
            SettingsRow2(s.bearing, '${look.azimuthDeg.toStringAsFixed(0)}°'),
            SettingsRow2(s.satRange, '${look.rangeKm.toStringAsFixed(0)} km'),
            SettingsRow2(s.satRangeRate,
                '${look.rangeRateKmS.toStringAsFixed(2)} km/s'),
            SettingsRow2(s.satUplink,
                '${up.toStringAsFixed(3)} MHz · ${_hz(-dUp)}'),
            SettingsRow2(s.satDownlink,
                '${down.toStringAsFixed(3)} MHz · ${_hz(dDown)}'),
            SettingsHint(s.satDopplerHint),
            SettingsNavRow(
              title: s.satPoint,
              subtitle: s.satPointHint,
              icon: Icons.explore_rounded,
              color: C.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SatellitePointPage(state: state),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── 频率 / 路径 / On-Air ───

  Widget _freqCard(BuildContext context, S s) {
    return SettingsSectionCard(
      title: s.satPath,
      icon: Icons.tune_rounded,
      color: C.orange,
      children: [
        SettingsNavRow(
          title: s.satUplink,
          trailing: '${state.satUpMhz.toStringAsFixed(3)} MHz',
          icon: Icons.north_rounded,
          color: C.blue,
          onTap: () => _editFreq(context, s, true),
        ),
        SettingsNavRow(
          title: s.satDownlink,
          trailing: '${state.satDownMhz.toStringAsFixed(3)} MHz',
          icon: Icons.south_rounded,
          color: C.green,
          onTap: () => _editFreq(context, s, false),
        ),
        SettingsNavRow(
          title: s.satPath,
          trailing: state.satPath,
          icon: Icons.alt_route_rounded,
          color: C.purple,
          onTap: () => _editPath(context, s),
        ),
        SettingsNavRow(
          title: s.satTone,
          trailing: state.satTone.isEmpty ? '—' : state.satTone,
          icon: Icons.music_note_rounded,
          color: C.cyan,
          onTap: () => _editTone(context, s),
        ),
        SettingsHint(s.satPathHint),
        ListenableBuilder(
          listenable: SatOverlayController.instance,
          builder: (context, _) {
            final on = SatOverlayController.instance.enabled;
            return SettingsNavRow(
              title: s.satMini,
              trailing: on ? s.tncSwitchOn : s.tncSwitchOff,
              icon: Icons.picture_in_picture_alt_rounded,
              color: C.blue,
              onTap: () => SatOverlayController.instance.toggle(context, state),
            );
          },
        ),
        SettingsHint(s.satMiniTip),
        // 常用 APRS 卫星频点（ISS / NO-84 / PSAT2 / PCSAT 多为 145.825 同频）。
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: Icon(Icons.bolt_rounded, size: 14, color: C.orange),
              label: Text('APRS 145.825 MHz', style: ts(11)),
              onPressed: () =>
                  state.setSatFreqs(up: 145.825, down: 145.825),
            ),
          ),
        ),
        SettingsSwitch(
          s.satAutoDoppler,
          value: state.satAutoDoppler,
          color: C.green,
          onChanged: state.setSatAutoDoppler,
        ),
        SettingsHint(s.satAutoDopplerHint),
        SettingsSwitch(
          s.satQso,
          value: state.satQsoOn,
          color: C.blue,
          onChanged: state.setSatQsoOn,
        ),
        SettingsHint(s.satLead),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyDown(context, s),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: Text(s.satCopyDown, style: ts(11.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.green),
                  onPressed: () => _useAsOnAir(context, s),
                  child: Text(s.satUseAsOnAir, style: ts(11.5)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 转发器 ───

  Widget _transponderCard(BuildContext context, S s) {
    final list = transpondersFor(state.satName);
    return SettingsSectionCard(
      title: s.satTransponders,
      icon: Icons.settings_input_antenna_rounded,
      color: C.purple,
      children: [
        if (state.satName.isEmpty)
          SettingsHint(s.satNeedSync, color: C.orange)
        else if (list.isEmpty)
          SettingsHint(s.satNoTransponders)
        else
          for (final t in list)
            InkWell(
              onTap: () => _applyTransponder(context, t),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: C.border, width: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(t.name,
                              style:
                                  ts(12.5, w: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(t.mode, style: ts(9.5, c: C.grey)),
                        if (t.invert) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: C.orange.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('INV',
                                style: ts(8, c: C.orange, w: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'U ${t.upMhz.toStringAsFixed(3)}  ·  '
                          'D ${t.downMhz.toStringAsFixed(3)}',
                          style: ts(10.5, c: C.slate),
                        ),
                        if (t.tone.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text('T ${t.tone}',
                              style: ts(10.5, c: C.cyan, w: FontWeight.w600)),
                        ],
                        const Spacer(),
                        Text(s.satApply,
                            style:
                                ts(9.5, c: C.blue, w: FontWeight.w700)),
                      ],
                    ),
                    if (t.note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(t.note, style: ts(8.5, c: C.grey)),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }

  void _applyTransponder(BuildContext context, SatTransponder t) {
    state.setSatFreqs(up: t.upMhz, down: t.downMhz);
    state.setSatTone(t.tone);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${t.name} · U ${t.upMhz.toStringAsFixed(3)} / '
          'D ${t.downMhz.toStringAsFixed(3)}'
          '${t.tone.isEmpty ? '' : ' · T ${t.tone}'}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── 动作 ───

  Future<void> _sync(BuildContext context) async {
    final s = S.of(context);
    final ok = await state.syncSatEphemeris();
    if (!context.mounted) return;
    _toast(context, ok ? s.satSyncOk : s.satSyncFail);
  }

  Future<void> _pickSat(BuildContext context, List<String> names) async {
    final s = S.of(context);
    final ctrl = TextEditingController();
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: C.sheetFill,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final q = ctrl.text.trim().toLowerCase();
          final list = q.isEmpty
              ? names
              : names.where((n) => n.toLowerCase().contains(q)).toList();
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: Row(
                      children: [
                        Text(s.satSatellite, style: ts(14, w: FontWeight.w700)),
                        const Spacer(),
                        Text('${names.length}', style: ts(11, c: C.grey)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: TextField(
                      controller: ctrl,
                      onChanged: (_) => setSheet(() {}),
                      style: ts(13),
                      decoration: InputDecoration(
                        hintText: s.search,
                        hintStyle: ts(13, c: C.greyLight),
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 18, color: C.grey),
                        isDense: true,
                        filled: true,
                        fillColor: C.bgSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final n in list)
                          ListTile(
                            dense: true,
                            title: Text(n, style: ts(13)),
                            trailing: state.satName == n
                                ? Icon(Icons.check_rounded,
                                    size: 16, color: C.blue)
                                : null,
                            onTap: () => Navigator.pop(ctx, n),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    ctrl.dispose();
    if (pick != null && context.mounted) state.setSatName(pick);
  }

  Future<void> _editFreq(BuildContext context, S s, bool up) async {
    final ctrl = TextEditingController(
      text: (up ? state.satUpMhz : state.satDownMhz).toStringAsFixed(3),
    );
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.white,
        title: Text(up ? s.satUplink : s.satDownlink,
            style: ts(15, w: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: ts(14),
          decoration: const InputDecoration(suffixText: 'MHz'),
          onSubmitted: (t) {
            final x = double.tryParse(t.trim());
            if (x != null) Navigator.pop(ctx, x);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.of(ctx).cancel)),
          FilledButton(
            onPressed: () {
              final x = double.tryParse(ctrl.text.trim());
              if (x != null) Navigator.pop(ctx, x);
            },
            child: Text(S.of(ctx).save),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (v == null || !context.mounted) return;
    state.setSatFreqs(up: up ? v : null, down: up ? null : v);
  }

  Future<void> _editPath(BuildContext context, S s) async {
    final ctrl = TextEditingController(text: state.satPath);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.white,
        title: Text(s.satPath, style: ts(15, w: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: ts(14),
          decoration: const InputDecoration(hintText: 'ARISS'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.of(ctx).cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(S.of(ctx).save),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (v == null || v.isEmpty || !context.mounted) return;
    state.setSatPath(v);
  }

  Future<void> _editTone(BuildContext context, S s) async {
    final ctrl = TextEditingController(text: state.satTone);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.white,
        title: Text(s.satTone, style: ts(15, w: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: ts(14),
          decoration: const InputDecoration(hintText: '67.0 / T107'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.of(ctx).cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(S.of(ctx).save),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (v == null || !context.mounted) return;
    state.setSatTone(v);
  }

  double _correctedDown() {
    final t = state.satSelected;
    final lat = state.myLat;
    final lng = state.myLng;
    if (t == null || lat == null || lng == null) return state.satDownMhz;
    final look = lookAt(t, lat, lng, DateTime.now());
    return state.satDownMhz +
        dopplerHz(state.satDownMhz, look.rangeRateKmS) / 1e6;
  }

  Future<void> _copyDown(BuildContext context, S s) async {
    final f = _correctedDown().toStringAsFixed(3);
    await Clipboard.setData(ClipboardData(text: '$f MHz'));
    if (context.mounted) _toast(context, s.satCopied);
  }

  void _useAsOnAir(BuildContext context, S s) {
    final ok = state.saveOnAir(
      freq: _correctedDown().toStringAsFixed(3),
      mode: 'FM',
      extra: '',
    );
    if (!context.mounted) return;
    _toast(context, ok ? s.qsySetDone : s.onAirFreqBad);
  }

  // ─── 小工具 ───

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  String _when(DateTime t) {
    final l = t.toLocal();
    final n = DateTime.now();
    final hm = _hm(t);
    if (l.year == n.year && l.month == n.month && l.day == n.day) return hm;
    return '${l.month}/${l.day} $hm';
  }

  String _hz(double hz) {
    final k = hz / 1000.0;
    return '${k >= 0 ? '+' : ''}${k.toStringAsFixed(1)} kHz';
  }

  void _toast(BuildContext context, String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
    );
  }
}

/// 极坐标天空图：外圈 = 地平线（0°），圆心 = 天顶（90°）。
class _SkyPlot extends StatelessWidget {
  final Tle tle;
  final double lat, lng;
  final SatPass pass;
  final DateTime now;

  const _SkyPlot({
    required this.tle,
    required this.lat,
    required this.lng,
    required this.pass,
    required this.now,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _SkyPlotPainter(
          tle: tle,
          lat: lat,
          lng: lng,
          pass: pass,
          now: now,
        ),
      );
}

class _SkyPlotPainter extends CustomPainter {
  final Tle tle;
  final double lat, lng;
  final SatPass pass;
  final DateTime now;

  const _SkyPlotPainter({
    required this.tle,
    required this.lat,
    required this.lng,
    required this.pass,
    required this.now,
  });

  Offset _point(Size size, double azDeg, double elDeg) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 12;
    final rr = r * (1 - elDeg.clamp(0.0, 90.0) / 90);
    final a = azDeg * math.pi / 180;
    return Offset(cx + rr * math.sin(a), cy - rr * math.cos(a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 12;
    final center = Offset(cx, cy);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = C.border;
    canvas.drawCircle(center, r, ring);
    for (final el in const [30.0, 60.0]) {
      canvas.drawCircle(
        center,
        r * (1 - el / 90),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = C.border.withValues(alpha: 0.55),
      );
    }

    void label(String text, Offset at) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: 10, color: C.grey),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    label('N', Offset(cx, cy - r - 8));
    label('E', Offset(cx + r + 8, cy));
    label('S', Offset(cx, cy + r + 8));
    label('W', Offset(cx - r - 8, cy));

    // 过境轨迹（每 20 秒一个点）
    final pts = <Offset>[];
    for (var t = pass.aos;
        t.isBefore(pass.los);
        t = t.add(const Duration(seconds: 20))) {
      final look = lookAt(tle, lat, lng, t);
      if (look.elevationDeg < 0) continue;
      pts.add(_point(size, look.azimuthDeg, look.elevationDeg));
    }
    if (pts.length > 1) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = C.blue,
      );
    }

    void dot(DateTime at, Color color) {
      final look = lookAt(tle, lat, lng, at);
      if (look.elevationDeg < -1) return;
      canvas.drawCircle(
        _point(size, look.azimuthDeg, look.elevationDeg.clamp(0.0, 90.0)),
        3.5,
        Paint()..color = color,
      );
    }

    dot(pass.aos, C.green);
    dot(pass.tca, C.orange);
    dot(pass.los, C.red);

    // 卫星当前所在（只有落在这次过境里才画）
    if (!now.isBefore(pass.aos) && !now.isAfter(pass.los)) {
      final look = lookAt(tle, lat, lng, now);
      if (look.elevationDeg >= 0) {
        final p = _point(size, look.azimuthDeg, look.elevationDeg);
        canvas.drawCircle(p, 6, Paint()..color = Colors.white);
        canvas.drawCircle(p, 4, Paint()..color = C.blue);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPlotPainter old) =>
      old.now != now || old.pass != pass || old.tle != tle;
}
