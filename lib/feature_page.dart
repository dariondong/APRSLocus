import 'package:flutter/material.dart';

import 'features.dart';
import 'satellite_mode_page.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'ui_layout_selector.dart';
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
    return SettingsSectionCard(
      title: s.featureModes,
      icon: Icons.bolt_rounded,
      color: C.blue,
      children: [
        // 界面结构：1.0 经典 / 2.0 地图基底 —— 与下面两个模式同属「外壳怎么长」。
        // 精简模式有自己的一套外壳，这时候选 1.0/2.0 看不出效果，按旧行为隐藏。
        if (!state.liteMode) UiLayoutSelector(state: state),
        SettingsSwitch(
          s.featureLite,
          value: state.liteMode,
          onChanged: state.setLiteMode,
        ),
        SettingsHint(s.featureLiteDesc),
        // APRS 卫星模式：射频路径改用卫星路径（默认 ARISS），并开一个专用面板。
        SettingsSwitch(
          s.satMode,
          value: state.satelliteMode,
          color: C.blue,
          onChanged: state.setSatelliteMode,
        ),
        SettingsHint(s.satModeDesc),
        if (state.satelliteMode)
          SettingsNavRow(
            title: s.satModeOpen,
            icon: Icons.satellite_alt_rounded,
            color: C.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SatelliteModePage(state: state),
              ),
            ),
          ),
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
