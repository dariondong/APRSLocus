import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';
import 'state.dart';
import 'models.dart';
import 'widgets.dart';
import 'about_page.dart';
import 'check_update_page.dart';
import 'settings_pages.dart';

class SettingsPage extends StatefulWidget {
  final AppState state;
  const SettingsPage({super.key, required this.state});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppState get st => widget.state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(S.of(context).settings, style: T.h1),
              SizedBox(height: 4),
              Text(S.of(context).settingsDesc, style: ts(13, c: C.slate)),
              SizedBox(height: 20),
              // 连接状态横幅
              _connBanner(),
              SizedBox(height: 16),
              // 分类入口
              IntrinsicHeight(
                child: Row(children: [
                  Expanded(
                    child: _catCard(
                      icon: Icons.person_rounded,
                      color: C.blue,
                      title: S.of(context).radioCat,
                      desc: S.of(context).radioCatDesc,
                      onTap: () => _push(StationSettingsPage(state: st)),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _catCard(
                      icon: Icons.my_location_rounded,
                      color: C.green,
                      title: S.of(context).beaconCat,
                      desc: S.of(context).beaconCatDesc,
                      onTap: () => _push(BeaconSettingsPage(state: st)),
                    ),
                  ),
                ]),
              ),
              SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(children: [
                  Expanded(
                    child: _catCard(
                      icon: Icons.wifi_rounded,
                      color: C.purple,
                      title: S.of(context).connectionCat,
                      desc: S.of(context).connectionCatDesc,
                      onTap: () => _push(ConnectionSettingsPage(state: st)),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _catCard(
                      icon: Icons.palette_rounded,
                      color: C.cyan,
                      title: S.of(context).displayCat,
                      desc: S.of(context).displayCatDesc,
                      onTap: () => _push(DisplaySettingsPage(state: st)),
                    ),
                  ),
                ]),
              ),
              SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(children: [
                  Expanded(
                    child: _catCard(
                      icon: Icons.forum_rounded,
                      color: C.orange,
                      title: S.of(context).chatCat,
                      desc: S.of(context).chatCatDesc,
                      onTap: () => _push(ChatSettingsPage(state: st)),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _catCard(
                      icon: Icons.storage_rounded,
                      color: C.red,
                      title: S.of(context).dataCat,
                      desc: S.of(context).dataCatDesc,
                      onTap: () => _push(DataSettingsPage(state: st)),
                    ),
                  ),
                ]),
              ),
              SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(children: [
                  Expanded(
                    child: _catCard(
                      icon: Icons.tune_rounded,
                      color: C.slate,
                      title: S.of(context).advancedCat,
                      desc: S.of(context).advancedCatDesc,
                      onTap: () => _push(AdvancedSettingsPage(state: st)),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _catCard(
                      icon: Icons.system_update_rounded,
                      color: const Color(0xFF0EA5A4),
                      title: S.of(context).updateCat,
                      desc: S.of(context).updateCatDesc,
                      onTap: () => _push(CheckUpdatePage(state: st)),
                    ),
                  ),
                ]),
              ),
              SizedBox(height: 16),
              // QQ 交流群
              _qqBanner(),
              SizedBox(height: 12),
              // 关于
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AboutPage())),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: cardDeco(),
                  child: Row(children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0A5CFF), Color(0xFF003D99)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.info_rounded,
                          color: Colors.white, size: 17),
                    ),
                    SizedBox(width: 10),
                    Text(S.of(context).about,
                        style: ts(13, w: FontWeight.w700)),
                    Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        color: C.grey, size: 20),
                  ]),
                ),
              ),
              if (defaultTargetPlatform != TargetPlatform.windows) ...[
                SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: C.orangeBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.lock_clock_rounded, color: C.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '后台运行提示：为保证后台持续定位上报，请到系统设置中允许 APRSlocus 后台运行、关闭省电优化，并允许自启动。',
                        style: ts(11, c: C.orange, w: FontWeight.w600, h: 1.5),
                      ),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _catCard({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: ts(14, w: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: 2),
                Text(desc,
                    style: ts(10, c: C.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: C.grey, size: 18),
        ]),
      ),
    );
  }

  Widget _connBanner() {
    final col = st.connected
        ? C.green
        : st.connecting
            ? C.blue
            : C.red;
    final bg = st.connected
        ? C.greenBg
        : st.connecting
            ? C.blueBg
            : C.redBg;
    final icon = st.connected
        ? Icons.check_circle_rounded
        : st.connecting
            ? Icons.sync_rounded
            : Icons.cloud_off_rounded;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: col, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              st.connected
                  ? '已连接 APRS-IS'
                  : st.connecting
                      ? '连接中…'
                      : '未连接',
              style: ts(13, c: col, w: FontWeight.w700),
            ),
            Text(st.connInfo, style: ts(11, c: col.withValues(alpha: 0.8))),
          ]),
        ),
        SizedBox(width: 8),
        IconButton(
          icon: Icon(
            st.connected
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outline,
            color: st.connected ? C.red : C.green,
          ),
          onPressed: st.toggleConnect,
        ),
      ]),
    );
  }

  Widget _qqBanner() {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse('https://qm.qq.com/q/8pL6vc5YA0'),
          mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: C.blueBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.blue.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: C.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.forum_rounded, size: 18, color: Colors.white),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('QQ 交流群', style: ts(13, w: FontWeight.w700)),
              SizedBox(height: 2),
              Text('APRSlocus 软件 · 反馈问题/交流使用',
                  style: ts(11, c: C.slate)),
            ]),
          ),
          SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 18, color: C.blue),
        ]),
      ),
    );
  }
}
