import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:url_launcher/url_launcher.dart';

import 'notice.dart';
import 'notice_banner.dart';
import 'theme.dart';
import 'guide.dart';
import 'state.dart';
import 'models.dart';
import 'widgets.dart';
import 'about_page.dart';
import 'check_update_page.dart';
import 'exit_app.dart';
import 'early_member.dart';
import 'honor_wall_page.dart';
import 'settings_pages.dart';
import 'translate_page.dart';
import 'export_adif_page.dart';
import 'backup_page.dart';
import 'track_history_page.dart';
import 'theme_page.dart';
import 'theme_store.dart';
import 'theme_text.dart';

class SettingsPage extends StatefulWidget {
  final AppState state;
  const SettingsPage({super.key, required this.state});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppState get st => widget.state;

  /// 公告入口正在取（见 [_openNotice]）：只用来在行尾换成一个转圈
  bool _noticeLoading = false;

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
                const SizedBox(height: 16),
                // 功能引导（首次进入显示；看过后不占位置）
                GuideTipCard(
                  guideId: 'settings',
                  state: widget.state,
                  margin: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),
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
                          slot: 'catRadio',
                          color: C.blue,
                          title: Tx.of(context).byKey('radioCat'),
                          desc: S.of(context).radioCatDesc,
                          onTap: () => _push(StationSettingsPage(state: st)),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _catCard(
                          icon: Icons.my_location_rounded,
                          slot: 'catBeacon',
                          color: C.green,
                          title: Tx.of(context).byKey('beaconCat'),
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
                          slot: 'catConnection',
                          color: C.purple,
                          title: Tx.of(context).byKey('connectionCat'),
                          desc: S.of(context).connectionCatDesc,
                          onTap: () => _push(ConnectionSettingsPage(state: st)),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _catCard(
                          icon: Icons.palette_rounded,
                          slot: 'catDisplay',
                          color: C.cyan,
                          title: Tx.of(context).byKey('displayCat'),
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
                          slot: 'catDevice',
                          color: C.indigo,
                          title: Tx.of(context).byKey('deviceCat'),
                          desc: S.of(context).deviceCatDesc,
                          onTap: () => _push(DeviceSettingsPage(state: st)),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _catCard(
                          icon: Icons.storage_rounded,
                          slot: 'catData',
                          color: C.red,
                          title: Tx.of(context).byKey('dataCat'),
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
                          slot: 'catAdvanced',
                          color: C.slate,
                          title: Tx.of(context).byKey('advancedCat'),
                          desc: S.of(context).advancedCatDesc,
                          onTap: () => _push(AdvancedSettingsPage(state: st)),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _catCard(
                          icon: Icons.system_update_rounded,
                          slot: 'catUpdate',
                          color: const Color(0xFF0EA5A4),
                          title: Tx.of(context).byKey('updateCat'),
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
                          decoration: C.accentDeco(
                            radius: 8,
                            fallback: const [Color(0xFFC9A227), Color(0xFF8A6D1F)],
                            ),
                          child: const Icon(Icons.emoji_events_rounded,
                              color: Colors.white, size: 17),
                        ),
                        SizedBox(width: 10),
                        // 标题短、副标题长（且各语言长度差很大）：标题限份额，
                        // 副标题用 Expanded 把剩余全吃掉 —— 不用 Spacer，因为
                        // Spacer 也是弹性子项，会把副标题的可用宽度再切一刀。
                        Flexible(
                          flex: 2,
                          child: Text(
                            Tx.of(context).byKey('honorWall'),
                            style: ts(13, w: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 3,
                          child: Text(
                            S.of(context).myBadgesAndAchievements,
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF98A2B8)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                // 翻译设置
                GestureDetector(
                  onTap: () => _push(TranslateSettingsPage(state: st)),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDeco(),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: C.accentDeco(
                            radius: 8,
                            fallback: const [Color(0xFF0E7490), Color(0xFF155E75)],
                            ),
                          child: const Icon(Icons.translate_rounded,
                              color: Colors.white, size: 17),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(Tx.of(context).byKey('translateSettings'),
                                  style: ts(13, w: FontWeight.w700)),
                              SizedBox(height: 2),
                              Text(S.of(context).translateSettingsSubtitle,
                                  style: ts(10, c: C.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: C.grey, size: 20),
                      ],
                    ),
                  ),
                ),
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
                          decoration: C.accentDeco(
                            radius: 8,
                            fallback: const [Color(0xFF16A34A), Color(0xFF0B7A37)],
                            ),
                          child: const Icon(
                            Icons.file_download_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          Tx.of(context).byKey('exportAdif'),
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
                // 主题（自定义颜色 / 图标 / 文字）
                GestureDetector(
                  onTap: () => _push(ThemePage(state: widget.state)),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDeco(),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: C.accentDeco(
                            radius: 8,
                            fallback: const [Color(0xFFDB2777), Color(0xFF9D174D)],
                            ),
                          child: const Icon(
                            Icons.brush_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          S.of(context).themeTitle,
                          style: ts(13, w: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            S.of(context).themeEntryDesc,
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
                // 历史轨迹（个人按天台账：里程 / 速度 / 时长）
                GestureDetector(
                  onTap: () => _push(TrackHistoryPage(state: st)),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDeco(),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: C.accentDeco(
                            radius: 8,
                            fallback: const [Color(0xFF16A34A), Color(0xFF0B7A37)],
                            ),
                          child: const Icon(
                            Icons.route_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          S.of(context).historyTracks,
                          style: ts(13, w: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            S.of(context).historyTracksDesc,
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
                // 备份与恢复（与 ADIF 导出并列的数据出入口）
                GestureDetector(
                  onTap: () => _push(BackupPage(state: widget.state)),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDeco(),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: C.accentDeco(
                            radius: 8,
                            fallback: const [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                            ),
                          child: const Icon(
                            Icons.settings_backup_restore_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          Tx.of(context).byKey('backupTitle'),
                          style: ts(13, w: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            S.of(context).backupEntryDesc,
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
                // 公告：**主动查看**的入口（用户：「在设置主页底下添加一个公告进入
                // 按钮」）。归在最底下这一簇入口里（备份之后、关于之前；退出应用
                // 那颗销毁性按钮仍留在最底，不把公告排到它下面）。
                //
                // 为什么是「按钮」而不是在这个主页也放一条横幅：横幅是**被动可见**的
                // 通知（主页/地图那条已经在做这件事），而这里要的是「我想看时点一下」。
                // 两条横幅才是重复的 —— 上一版就因为在设置子页也塞了一条而被指出来。
                //
                // ⚠ 点它才联网：不在进入设置页时预拉。公告横幅那个开关的承诺是
                // 「关了就不在后台联网」（见 notice_banner.dart 顶部），而**用户主动
                // 点这一下**不是后台行为，所以开关关着时这个入口依旧可用 ——
                // 不然「不想在主页看到横幅」的人就再也读不到公告了。
                _noticeEntry(),
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
                          decoration: C.accentDeco(
                            radius: 8,
                            fallback: const [Color(0xFF0A5CFF), Color(0xFF003D99)],
                            ),
                          child: const Icon(
                            Icons.info_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          Tx.of(context).byKey('about'),
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

  /// 公告入口：点一下**当场去取**（先网络、失败退缓存），拿到了就弹底部弹层。
  ///
  /// 取不到就如实说「暂无公告」，不留白也不假装成功 —— 与横幅那条的
  /// 「暂无公告 + 重试」同一条原则（v1.6.109 只读模式起就定下的）。
  Future<void> _openNotice() async {
    // 防连点：不拦的话手抖两下会发两次请求、叠两层弹层
    if (_noticeLoading) return;
    setState(() => _noticeLoading = true);
    final d = await NoticeStore.instance.load(lang: noticeLangOf(context));
    if (!mounted) return;
    setState(() => _noticeLoading = false);
    if (d == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.of(context).noticeEmpty),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    // 全文用**底部弹层**（用户明确要求不要整页）：与横幅点开的是同一个
    await showNoticeSheet(context,
        markdown: d.body, fetchedAt: d.fetchedAt, fromCache: d.fromCache);
  }

  /// 公告入口行。样式与上面几个入口（备份 / 关于）保持一致。
  Widget _noticeEntry() {
    return GestureDetector(
      onTap: _openNotice,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: C.accentDeco(
                radius: 8,
                fallback: const [Color(0xFF0891B2), Color(0xFF155E75)],
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
            SizedBox(width: 10),
            Text(
              S.of(context).noticeTitle,
              style: ts(13, w: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                S.of(context).noticeEntryDesc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF98A2B8),
                ),
              ),
            ),
            // 取公告时给个转圈：这几百毫秒里若毫无反应，用户会以为没点上
            // （又一次点击会叠一层弹层）
            if (_noticeLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  // ⚠ 里面没有 C.*，所以 const 合法（check_const_colors 会报）
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: C.grey,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _catCard({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required VoidCallback onTap,
    /// 主题图标插槽 id。给了它，这张卡片的图标就能被主题替换；
    /// 没给则永远用 [icon]（保持旧行为，不必为了接入主题改一圈调用点）。
    String? slot,
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
              child: slot == null
                  ? Icon(icon, color: color, size: 20)
                  : ThemeController.instance.buildSlotIcon(
                      slot,
                      size: 20,
                      color: color,
                      fallbackIcon: icon,
                    ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ts(13, w: FontWeight.w700),
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
        borderRadius: BorderRadius.circular(16),
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
                style: ts(16, w: FontWeight.w700)),
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
                borderRadius: BorderRadius.circular(12),
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
