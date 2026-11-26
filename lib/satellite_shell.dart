import 'package:flutter/material.dart';

import 'map_page.dart';
import 'material.dart';
import 'satellite_mode_page.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── APRS 卫星模式外壳 ───
///
/// 与 1.0 经典 / 2.0 地图 / 精简并列，不是设置里的一个开关：
///   * 地图铺底（卫星星下点、足迹与轨迹由 MapPage 的卫星层画）；
///   * 顶部一颗状态胶囊：卫星名 + 下次过境，右侧直接切换模式；
///   * 底部可拖动面板：卫星选择/同步、极坐标天空图、过境列表、实时多普勒、
///     频率/路径、指向卫星。
class SatelliteShell extends StatelessWidget {
  final AppState state;
  const SatelliteShell({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: C.pageFill,
      body: Stack(
        children: [
          Positioned.fill(
            child: MapPage(
              state: state,
              isActive: true,
              // 让开顶部状态胶囊；底部由面板盖住。
              topInset: 64,
              bottomInset: 0,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: _topBar(context, s),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.46,
            minChildSize: 0.12,
            maxChildSize: 0.94,
            builder: (ctx, controller) => Container(
              decoration: BoxDecoration(
                color: C.pageFill,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: elev3(),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 2),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: C.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SatelliteModePage(
                      state: state,
                      embedded: true,
                      scrollController: controller,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context, S s) {
    final pass = state.satPickedPass;
    final name = state.satName;
    final label = name.isEmpty
        ? s.satMode
        : '$name${pass == null ? '' : ' · ${_hm(pass.aos)}'}';
    return MaterialSurface(
      radius: 999,
      blurSigma: C.chipBlur,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: C.chipFill,
          borderRadius: BorderRadius.circular(999),
          boxShadow: elev2(),
        ),
        child: Row(
          children: [
            Icon(Icons.satellite_alt_rounded, size: 17, color: C.blue),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: ts(12.5, w: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () => _showModes(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: C.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dashboard_customize_rounded,
                        size: 14, color: C.blue),
                    const SizedBox(width: 4),
                    Text(s.featureModes,
                        style: ts(11, c: C.blue, w: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showModes(BuildContext context) {
    final s = S.of(context);
    final modes = <(AppMode, String, IconData)>[
      (AppMode.sheet, s.uiLayoutSheet, Icons.map_rounded),
      (AppMode.classic, s.uiLayoutClassic, Icons.dashboard_rounded),
      (AppMode.lite, s.featureLite, Icons.bolt_rounded),
      (AppMode.satellite, s.satMode, Icons.satellite_alt_rounded),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.sheetFill,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: C.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            for (final (m, label, icon) in modes)
              ListTile(
                leading: Icon(icon,
                    color: state.appMode == m ? C.blue : C.slate),
                title: Text(label, style: ts(13, w: FontWeight.w600)),
                trailing: state.appMode == m
                    ? Icon(Icons.check_rounded, size: 18, color: C.blue)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  state.setAppMode(m);
                },
              ),
            const SizedBox(height: 6),
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
}
