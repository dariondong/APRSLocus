import 'package:flutter/material.dart';

import 'features.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 功能启用页 ───
///
/// 分两段：最上面是精简模式（整套外壳换成极简布局），下面是模块开关
/// （天气、排行榜、荣誉墙、赞助、生命守护、翻译、轨迹、ADIF）。
///
/// 两个开关组**互不改写**：精简模式按掉全部模块，但不动用户自己关过的那几个；
/// 关掉精简模式，他原来的选择原样回来。合并成一份状态的话，「试一下精简模式」
/// 就等于「把我调好的模块全丢了」。
class FeaturePage extends StatelessWidget {
  final AppState state;
  const FeaturePage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => SettingsPageShell(
        title: s.featureModeTitle,
        subtitle: s.featureModeDesc,
        icon: Icons.tune_rounded,
        color: C.slate,
        body: Column(
          children: [
            _modesCard(context, s),
            const SizedBox(height: 16),
            _modulesCard(s),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _modesCard(BuildContext context, S s) {
    final modes = <(AppMode, String, String, IconData, Color)>[
      (
        AppMode.sheet,
        s.uiLayoutSheet,
        s.uiLayoutSheetDesc,
        Icons.map_rounded,
        C.blue,
      ),
      (
        AppMode.classic,
        s.uiLayoutClassic,
        s.uiLayoutClassicDesc,
        Icons.dashboard_rounded,
        C.slate,
      ),
      (
        AppMode.lite,
        s.featureLite,
        s.featureLiteDesc,
        Icons.bolt_rounded,
        C.orange,
      ),
      (
        AppMode.satellite,
        s.satMode,
        s.satModeDesc,
        Icons.satellite_alt_rounded,
        C.indigo,
      ),
    ];
    final cur = state.appMode;
    return SettingsSectionCard(
      title: s.featureModes,
      icon: Icons.bolt_rounded,
      color: C.blue,
      children: [
        for (final (m, name, desc, icon, color) in modes)
          GestureDetector(
            onTap: () => state.setAppMode(m),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cur == m ? color.withValues(alpha: 0.10) : C.bgSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cur == m ? color : C.border,
                  width: cur == m ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: cur == m ? color : C.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: ts(12.5,
                              c: cur == m ? color : C.ink,
                              w: cur == m ? FontWeight.w700 : FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(desc, style: ts(10, c: C.grey, h: 1.3)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    cur == m
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: cur == m ? color : C.greyLight,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _modulesCard(S s) {
    // 精简模式下模块一律不显示在界面上，开关也就该置灰 —— 留着能点会让人
    // 以为「点了就回来了」，而下一次冷启动它还是灰的。
    final lite = state.liteMode;
    Widget row(AppFeature f, String label) => SettingsSwitch(
          label,
          value: state.featureEnabled(f),
          enabled: !lite,
          onChanged: (v) => state.setFeature(f.id, v),
        );

    return SettingsSectionCard(
      title: s.featureModules,
      icon: Icons.widgets_rounded,
      color: C.purple,
      children: [
        // 天气不是一个独立页面，而是顶栏与外壳上的一条读数，开关一直挂在
        // 显示设置里 —— 这里只是把它摆到同一张单子上，写的是同一个状态。
        SettingsSwitch(
          s.featureWeather,
          value: state.weatherEnabled,
          enabled: !lite,
          onChanged: state.setWeatherEnabled,
        ),
        row(AppFeature.rank, s.sportRank),
        row(AppFeature.honor, s.honorWall),
        row(AppFeature.sponsor, s.sponsorEntry),
        row(AppFeature.lifeGuard, s.lifeGuard),
        row(AppFeature.translate, s.featureTranslate),
        row(AppFeature.tracks, s.historyTracks),
        row(AppFeature.adif, s.exportAdif),
        row(AppFeature.cloudSync, s.syncTitle),
        if (lite) SettingsHint(s.featureLiteBlocks),
      ],
    );
  }
}
