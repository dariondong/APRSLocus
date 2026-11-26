import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/app_localizations.dart';
import 'satellite.dart';
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
  const SatelliteModePage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => SettingsPageShell(
        title: s.satMode,
        subtitle: s.satModeDesc,
        icon: Icons.satellite_alt_rounded,
        color: C.blue,
        body: Column(
          children: [
            _modeCard(context, s),
            const SizedBox(height: 16),
            _passCard(context, s),
            const SizedBox(height: 16),
            _lookCard(context, s),
            const SizedBox(height: 16),
            _freqCard(context, s),
            const SizedBox(height: 24),
          ],
        ),
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
          SettingsRow2(
            s.satNextPass,
            s.satPass(_utcHm(pass.tca), pass.maxElevation.toStringAsFixed(0)),
            valueColor: C.ink,
          ),
          SettingsRow2(
            '${s.satAos} / ${s.satLos}',
            '${_utcHm(pass.aos)} / ${_utcHm(pass.los)}',
          ),
          if (passes.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < passes.length; i++)
                      _passChip(passes[i], i == state.satPassIndex, i, s),
                  ],
                ),
              ),
            ),
          SettingsHint(s.satEstimate),
        ],
      ],
    );
  }

  Widget _passChip(SatPass p, bool active, int i, S s) {
    return GestureDetector(
      onTap: () => state.setSatPassIndex(i),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? C.blueBg : C.bgSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? C.blue : C.border),
        ),
        child: Text(
          '${_utcHm(p.tca)} · ${p.maxElevation.toStringAsFixed(0)}°',
          style: ts(11,
              c: active ? C.blue : C.slate,
              w: active ? FontWeight.w700 : FontWeight.w500),
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
        SettingsHint(s.satPathHint),
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

  // ─── 动作 ───

  Future<void> _sync(BuildContext context) async {
    final s = S.of(context);
    final ok = await state.syncSatEphemeris();
    if (!context.mounted) return;
    _toast(context, ok ? s.satSyncOk : s.satSyncFail);
  }

  Future<void> _pickSat(BuildContext context, List<String> names) async {
    final s = S.of(context);
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: C.sheetFill,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(s.satSatellite,
                  style: ts(14, w: FontWeight.w700)),
            ),
            for (final n in names)
              ListTile(
                dense: true,
                title: Text(n, style: ts(13)),
                trailing: state.satName == n
                    ? Icon(Icons.check_rounded, size: 16, color: C.blue)
                    : null,
                onTap: () => Navigator.pop(ctx, n),
              ),
          ],
        ),
      ),
    );
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

  String _utcHm(DateTime t) {
    final u = t.toUtc();
    return '${u.hour.toString().padLeft(2, '0')}:'
        '${u.minute.toString().padLeft(2, '0')}Z';
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
