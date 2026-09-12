import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'state.dart';
import 'models.dart';
import 'widgets.dart';
import 'about_page.dart';
import 'check_update_page.dart';
import 'exit_app.dart';
import 'early_member.dart';
import 'honor_wall_page.dart';
import 'settings_pages.dart';
import 'export_adif_page.dart';

class SettingsPage extends StatefulWidget {
  final AppState state;
  const SettingsPage({super.key, required this.state});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppState get st => widget.state;

  /// 按时段返回问候前缀（早上好/中午好/下午好/晚上好/夜深了）
  String get _greetingPrefix {
    final s = S.of(context);
    final h = DateTime.now().hour;
    if (h < 5) return s.greetNight;
    if (h < 11) return s.greetMorning;
    if (h < 13) return s.greetNoon;
    if (h < 18) return s.greetAfternoon;
    if (h < 22) return s.greetEvening;
    return s.greetNight;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 页面标题：顶部栏已显示“设置”，这里用问候语（早上好，呼号）避免重复
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$_greetingPrefix${widget.state.myCall}',
                        style: T.h1,
                      ),
                    ),
                    // 早期成员徽标：呼号匹配时显示，点击打开专属会员卡页
                    SizedBox(width: 8),
                    HonorBadge(widget.state.myCall,
                        symbol: widget.state.mySymbol),
                  ],
                ),
                SizedBox(height: 4),
                Text(S.of(context).settingsDesc, style: ts(13, c: C.slate)),
                SizedBox(height: 20),
                // 连接状态横幅
                _connBanner(),
                SizedBox(height: 16),
                // 分类入口
                IntrinsicHeight(
                  child: Row(
                    children: [
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
                    ],
                  ),
                ),
                SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    children: [
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
                    ],
                  ),
                ),
                SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      // 原「聊天」入口已替换为「设备」（聊天记录清除已并入数据页）
                      Expanded(
                        child: _catCard(
                          icon: Icons.radio_rounded,
                          color: C.indigo,
                          title: S.of(context).deviceCat,
                          desc: S.of(context).deviceCatDesc,
                          onTap: () => _push(DeviceSettingsPage(state: st)),
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
                    ],
                  ),
                ),
                SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    children: [
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
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // 荣誉墙（徽章墙 / 成就墙 / FIRST FIX）
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => HonorWallPage(widget.state.myFullCall,
                            symbol: widget.state.mySymbol,
                            symbolTable: '/')),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDeco(),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFC9A227), Color(0xFF8A6D1F)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.emoji_events_rounded,
                              color: Colors.white, size: 17),
                        ),
                        SizedBox(width: 10),
                        Text(S.of(context).honorWall, style: ts(13, w: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Text(S.of(context).myBadgesAndAchievements,
                            style: TextStyle(fontSize: 10, color: Color(0xFF98A2B8))),
                        Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            color: C.grey, size: 20),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12),
                // QQ 交流群
                _qqBanner(),
                SizedBox(height: 12),
                // 导出 ADIF（按需求置于「关于」上方）
                GestureDetector(
                  onTap: () => _push(ExportAdifPage(state: widget.state)),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDeco(),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF16A34A), Color(0xFF0B7A37)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.file_download_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          S.of(context).exportAdif,
                          style: ts(13, w: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            S.of(context).adifLogFile,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF98A2B8),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: C.grey,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12),
                // 关于
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutPage()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDeco(),
                    child: Row(
                      children: [
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
                          child: const Icon(
                            Icons.info_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          S.of(context).about,
                          style: ts(13, w: FontWeight.w700),
                        ),
                        Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: C.grey,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                if (defaultTargetPlatform != TargetPlatform.windows) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: C.orangeBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: C.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_clock_rounded,
                          color: C.orange,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            S.of(context).backgroundRunTip,
                            style: ts(
                              11,
                              c: C.orange,
                              w: FontWeight.w600,
                              h: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // 退出应用（Android / 桌面）：结束后台服务并退出进程
                if (canShowExitButton) ...[const SizedBox(height: 16), _exitButton()],
              ],
            ),
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
        child: Row(
          children: [
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
                  Text(
                    title,
                    style: ts(14, w: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    desc,
                    style: ts(10, c: C.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: C.grey, size: 18),
          ],
        ),
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: col, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  st.connected
                      ? S.of(context).connectedAprsIs
                      : st.connecting
                      ? S.of(context).connecting
                      : S.of(context).disconnected,
                  style: ts(13, c: col, w: FontWeight.w700),
                ),
                Text(
                  localizedConnectionInfo(context, st.connInfo),
                  style: ts(11, c: col.withValues(alpha: 0.8)),
                ),
              ],
            ),
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
        ],
      ),
    );
  }

  /// 退出应用按钮：确认后保存设置、停止定位/后台服务并按平台退出进程
  Widget _exitButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _confirmExit,
        style: OutlinedButton.styleFrom(
          foregroundColor: C.red,
          side: BorderSide(color: C.red.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle: ts(13, w: FontWeight.w700),
        ),
        icon: const Icon(Icons.power_settings_new_rounded, size: 17),
        label: Text(S.of(context).quitApp),
      ),
    );
  }

  Future<void> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.power_settings_new_rounded, color: C.red, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(S.of(context).quitApp,
                style: ts(15, w: FontWeight.w700)),
          ),
        ]),
        content: Text(
          S.of(context).quitAppDesc,
          style: ts(13, h: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(context).cancel,
                style: ts(13, c: C.slate)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.of(context).logout, style: ts(13)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await st.shutdownForExit();
    if (!mounted) return;
    await exitApplication();
  }

  Widget _qqBanner() {
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse('https://qm.qq.com/q/8pL6vc5YA0'),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: C.blueBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.blue.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: C.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.forum_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).qqGroup,
                    style: ts(13, w: FontWeight.w700),
                  ),
                  SizedBox(height: 2),
                  Text(S.of(context).qqGroupDesc, style: ts(11, c: C.slate)),
                ],
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 18, color: C.blue),
          ],
        ),
      ),
    );
  }
}
