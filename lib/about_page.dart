import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'widgets.dart';
import 'state.dart';
import 'sponsor_page.dart';

/// 彩蛋呼号 → 台词

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});
  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage>
    with SingleTickerProviderStateMixin {
  // ─── 粒子动画 ───
  AnimationController? _ctrl;
  final List<_Particle> _particles = [];
  Offset _particleCenter = Offset.zero;
  bool _showParticles = false;

  void _fireParticles(Offset center) {
    final rng = Random();
    _particles.clear();
    for (var i = 0; i < 28; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = 80.0 + rng.nextDouble() * 160.0;
      _particles.add(
        _Particle(
          color: [
            Colors.red,
            Colors.orange,
            Colors.blue,
            Colors.green,
            Colors.purple,
            Colors.pink,
          ][rng.nextInt(6)],
          dx: cos(angle) * speed,
          dy: sin(angle) * speed - 60,
          size: 3.0 + rng.nextDouble() * 5.0,
        ),
      );
    }
    _particleCenter = center;
    _showParticles = true;
    _ctrl?.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1200),
        )..addListener(
          () => setState(() {
            if (_ctrl!.isCompleted) _showParticles = false;
          }),
        );
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _onEggTap(String call) {
    final l10n = S.of(context);
    final msg = switch (call) {
      'BG7LZQ' => l10n.eggBg7lzq,
      'BG7PGW' => l10n.eggBg7pgw,
      'BG7LMW' => l10n.eggBg7lmw,
      'BG7OSL' => l10n.eggBg7osl,
      _ => null,
    };
    if (msg == null) return;
    HapticFeedback.mediumImpact();
    if (call == 'BG7OSL') {
      // OSL 彩蛋：显示袋鼠图片
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/osl.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 12),
              Text(
                call,
                style: ts(14, c: C.blue, w: FontWeight.w700),
              ),
              SizedBox(height: 6),
              Text(
                msg,
                style: ts(16, w: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.of(context).close, style: ts(13, c: C.grey)),
            ),
          ],
        ),
      );
      return;
    }
    // 弹提示框
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              call,
              style: ts(14, c: C.blue, w: FontWeight.w700),
            ),
            SizedBox(height: 10),
            Text(
              msg,
              style: ts(16, w: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).ok, style: ts(13, c: C.blue)),
          ),
        ],
      ),
    );
    // 粒子从屏幕中央爆发
    final box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      _fireParticles(box.size.center(Offset.zero));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: C.ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(S.of(context).about, style: ts(16, w: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              // ── Hero 横幅：logobg 背景 + 中央 logo（带外边距圆角卡片） ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: C.ink.withValues(alpha: 0.10),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    image: DecorationImage(
                      image: AssetImage('assets/logobg.jfif'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // 深色半透明遮罩，突出 logo
                        Positioned.fill(
                          child: Container(
                            color: C.ink.withValues(alpha: 0.30),
                          ),
                        ),
                        // 底部渐变过渡到背景色
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  C.ink.withValues(alpha: 0.75),
                                ],
                                stops: const [0.45, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // 中央 logo + 标题
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppLogo(size: 78),
                              const SizedBox(height: 12),
                              Text(
                                'APRSlocus',
                                style: ts(
                                  22,
                                  w: FontWeight.w800,
                                  ls: -0.5,
                                  c: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                S.of(context).aboutSubtitle,
                                style: ts(12, c: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ── 内容列表 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 2),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: C.blueBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'v${AppState.appVersion}',
                          style: ts(11, c: C.blue, w: FontWeight.w600),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    // ── 作者信息 ──
                    _sectionHeader(
                      S.of(context).author,
                      Icons.person_rounded,
                      C.blue,
                    ),
                    SizedBox(height: 8),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _eggRow(S.of(context).callsign, 'BG7LZQ'),
                          _row(S.of(context).nameLabel, 'Darion'),
                          _linkRow(
                            icon: Icons.language_rounded,
                            label: S.of(context).website,
                            value: 'Theez.top',
                            url: 'https://theez.top',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    // ── Code contributions ──
                    _sectionHeader(
                      S.of(context).codeContributions,
                      Icons.code_rounded,
                      C.purple,
                    ),
                    SizedBox(height: 8),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _linkRow(
                            icon: Icons.translate_rounded,
                            label: S.of(context).codeContributionI18n,
                            value: 'BD3QID',
                            url: 'https://github.com/nimenhagg/APRSLocus-translation',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    // ── 功能特性 ──
                    _sectionHeader(
                      S.of(context).features,
                      Icons.star_rounded,
                      C.orange,
                    ),
                    SizedBox(height: 8),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _feature(
                            Icons.map_rounded,
                            S.of(context).featureLiveMap,
                            S.of(context).featureLiveMapDesc,
                          ),
                          _feature(
                            Icons.gps_fixed_rounded,
                            S.of(context).featureGps,
                            S.of(context).featureGpsDesc,
                          ),
                          _feature(
                            Icons.send_rounded,
                            S.of(context).featureBeacon,
                            S.of(context).featureBeaconDesc,
                          ),
                          _feature(
                            Icons.chat_bubble_rounded,
                            S.of(context).featureMsg,
                            S.of(context).featureMsgDesc,
                          ),
                          _feature(
                            Icons.wifi_tethering_rounded,
                            S.of(context).featureAutoConnect,
                            S.of(context).featureAutoConnectDesc,
                          ),
                          _feature(
                            Icons.layers_rounded,
                            S.of(context).featureLayerFilter,
                            S.of(context).featureLayerFilterDesc,
                          ),
                          _feature(
                            Icons.radio_rounded,
                            S.of(context).featureFmo,
                            S.of(context).featureFmoDesc,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    // ── 开源致谢 ──
                    _sectionHeader(
                      S.of(context).openSource,
                      Icons.favorite_rounded,
                      C.red,
                    ),
                    SizedBox(height: 8),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _feature(
                            Icons.flutter_dash,
                            S.of(context).osFlutter,
                            S.of(context).osFlutterDesc,
                          ),
                          _feature(
                            Icons.web_rounded,
                            S.of(context).osAmap,
                            S.of(context).osAmapDesc,
                          ),
                          _feature(
                            Icons.cell_tower_rounded,
                            S.of(context).osAprs,
                            S.of(context).osAprsDesc,
                          ),
                          _feature(
                            Icons.group_rounded,
                            S.of(context).osHam,
                            S.of(context).osHamDesc,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    // ── License ──
                    _sectionHeader(
                      S.of(context).licenseSection,
                      Icons.balance_rounded,
                      C.slate,
                    ),
                    SizedBox(height: 8),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _feature(
                            Icons.gavel_rounded,
                            S.of(context).licenseName,
                            S.of(context).licenseStatement,
                          ),
                          _linkRow(
                            icon: Icons.description_rounded,
                            label: S.of(context).licenseText,
                            value: 'GPL-3.0',
                            url: 'https://github.com/dariondong/APRSLocus/blob/main/LICENSE',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    // ── 赞助与鸣谢（独立页面入口） ──
                    _sectionHeader(
                      S.of(context).sponsors,
                      Icons.volunteer_activism_rounded,
                      C.orange,
                    ),
                    SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SponsorPage()),
                      ),
                      child: SoftCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF8C00),
                                    Color(0xFFEA580C),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.volunteer_activism_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    S.of(context).sponsorsThanks,
                                    style: ts(13, w: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    S.of(context).viewSponsorDetails,
                                    style: ts(11, c: C.grey),
                                  ),
                                ],
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
                    SizedBox(height: 20),
                    // ── 测试成员 ──
                    _sectionHeader(
                      S.of(context).testMembers,
                      Icons.group_rounded,
                      C.green,
                    ),
                    SizedBox(height: 8),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _eggRow(S.of(context).callsign, 'BG7PGW'),
                          _eggRow(S.of(context).callsign, 'BG7LMW'),
                          _eggRow(S.of(context).callsign, 'BG7OSL'),
                          _eggRow(S.of(context).callsign, 'BD3QID'),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    // ── AI 算力支持 ──
                    _sectionHeader(
                      S.of(context).aiSupport,
                      Icons.memory_rounded,
                      C.purple,
                    ),
                    SizedBox(height: 8),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [_row(S.of(context).thanks, 'BA3RZL 养生')],
                      ),
                    ),
                    SizedBox(height: 20),
                    // ── 用户反馈 ──
                    _sectionHeader(
                      S.of(context).feedback,
                      Icons.forum_rounded,
                      C.orange,
                    ),
                    SizedBox(height: 8),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _linkRow(
                            icon: Icons.wechat_rounded,
                            label: S.of(context).qqGroup,
                            value: S.of(context).qqSoftwareName,
                            url: 'https://qm.qq.com/q/8pL6vc5YA0',
                          ),
                          _linkRow(
                            icon: Icons.link_rounded,
                            label: S.of(context).projectRepo,
                            value: 'GitCode',
                            url: 'https://gitcode.com/DarionDong/APRSLocus',
                          ),
                          _linkRow(
                            icon: Icons.code_rounded,
                            label: S.of(context).projectRepo,
                            value: 'GitHub',
                            url: 'https://github.com/dariondong/APRSLocus',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    Center(
                      child: Text(
                        S.of(context).usageNotice,
                        textAlign: TextAlign.center,
                        style: ts(11, c: C.grey, h: 1.6),
                      ),
                    ),
                    SizedBox(height: 12),
                    Center(
                      child: Text(
                        S.of(context).licenseNotice,
                        textAlign: TextAlign.center,
                        style: ts(10, c: C.greyLight, h: 1.6),
                      ),
                    ),
                    SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          final info = S
                              .of(context)
                              .appInfoText(AppState.appVersion);
                          Clipboard.setData(ClipboardData(text: info));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(S.of(context).appInfoCopied),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              backgroundColor: C.ink,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: C.greyBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded, size: 14, color: C.grey),
                              SizedBox(width: 6),
                              Text(
                                S.of(context).copyAppInfo,
                                style: ts(12, c: C.slate),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ─── 粒子层 ───
          if (_showParticles)
            IgnorePointer(
              child: CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _ParticlePainter(
                  center: _particleCenter,
                  progress: _ctrl!.value,
                  particles: _particles,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── 组件 ──

  Widget _sectionHeader(String title, IconData icon, Color c) {
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 6),
        Text(
          title,
          style: ts(13, w: FontWeight.w700, c: c),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
      ),
      child: Row(
        children: [
          Text(label, style: ts(12, c: C.slate)),
          const Spacer(),
          Text(value, style: ts(12, w: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _linkRow({
    required IconData icon,
    required String label,
    required String value,
    required String url,
  }) {
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: C.blue),
            SizedBox(width: 8),
            Text(label, style: ts(12, c: C.slate)),
            Spacer(),
            Text(
              value,
              style: ts(12, c: C.blue, w: FontWeight.w600),
            ),
            SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 14, color: C.grey),
          ],
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: C.blueBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: C.blue),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ts(12, w: FontWeight.w700)),
                SizedBox(height: 2),
                Text(desc, style: ts(11, c: C.grey, h: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 长按触发彩蛋的行
  Widget _eggRow(String label, String call) {
    return GestureDetector(
      onLongPress: () => _onEggTap(call),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(
          children: [
            Text(label, style: ts(12, c: C.slate)),
            Spacer(),
            Text(call, style: ts(12, w: FontWeight.w600)),
            SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 16, color: C.grey),
          ],
        ),
      ),
    );
  }
}

// ─── 粒子效果 ───

class _Particle {
  final Color color;
  final double dx, dy, size;
  _Particle({
    required this.color,
    required this.dx,
    required this.dy,
    required this.size,
  });
}

class _ParticlePainter extends CustomPainter {
  final Offset center;
  final double progress;
  final List<_Particle> particles;

  _ParticlePainter({
    required this.center,
    required this.progress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress;
    final opacity = (1.0 - p).clamp(0.0, 1.0);
    for (final pt in particles) {
      final paint = Paint()
        ..color = pt.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      final dx = center.dx + pt.dx * p;
      final dy = center.dy + pt.dy * p + 80 * p * p; // 重力
      final s = pt.size * (1.0 - p * 0.5);
      canvas.drawCircle(Offset(dx, dy), s, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
