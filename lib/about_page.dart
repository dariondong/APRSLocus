import 'dart:math';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'widgets.dart';
import 'state.dart';
import 'sponsor_page.dart';
import 'terms_page.dart';
import 'material.dart';

/// 彩蛋呼号 → 台词

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});
  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage>
    with SingleTickerProviderStateMixin {
  /// 分享通道：Android 调用系统分享面板（ACTION_SEND）
  static const _shareChannel = MethodChannel('com.aprslocus/share');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 分享文案
  String get _shareText => S.of(context).shareText;

  /// 分享到系统：Android 弹系统分享面板，其他平台复制文案
  Future<void> _shareToSystem() async {
    if (_isAndroid) {
      try {
        await _shareChannel.invokeMethod('shareText', {'text': _shareText});
        return;
      } catch (_) {}
    }
    await _copyShareText();
  }

  /// 复制分享文案到剪贴板
  Future<void> _copyShareText() async {
    await Clipboard.setData(ClipboardData(text: _shareText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context).shareTextCopied),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: C.ink,
      ),
    );
  }

  /// 打开下载页（GitHub Releases）
  void _openDownload() {
    launchUrl(
      Uri.parse('https://github.com/dariondong/APRSLocus/releases'),
      mode: LaunchMode.externalApplication,
    );
  }

  /// 分享面板
  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MaterialSurface(
        radius: 24,
        topOnly: true,
        child: Container(
          decoration: BoxDecoration(
            color: C.sheetFill,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: C.blueBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.share_rounded, color: C.blue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.of(context).shareApp,
                            style: ts(16, w: FontWeight.w800),
                          ),
                          Text(
                            'APRSlocus · v${AppState.appVersion}',
                            style: ts(11, c: C.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: C.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 分享到系统（仅 Android：调系统分享面板）
                if (_isAndroid) ...[
                  _shareOption(
                    icon: Icons.send_rounded,
                    color: C.green,
                    title: S.of(context).shareToSystem,
                    subtitle: S.of(context).shareToSystemDesc,
                    onTap: () {
                      Navigator.pop(context);
                      _shareToSystem();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                // 复制分享文案
                _shareOption(
                  icon: Icons.copy_rounded,
                  color: C.blue,
                  title: S.of(context).copyShareText,
                  subtitle: 'Android / Windows / iOS',
                  onTap: () {
                    Navigator.pop(context);
                    _copyShareText();
                  },
                ),
                const SizedBox(height: 8),
                // 打开下载页
                _shareOption(
                  icon: Icons.download_rounded,
                  color: C.orange,
                  title: S.of(context).openDownload,
                  subtitle: 'github.com/dariondong/APRSLocus/releases',
                  onTap: () {
                    Navigator.pop(context);
                    _openDownload();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shareOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: C.bgSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ts(13, w: FontWeight.w700)),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: ts(10, c: C.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 17, color: C.greyLight),
            ],
          ),
        ),
      ),
    );
  }

  /// Hero 底图视差量（0~240，随滚动量变化）
  final ValueNotifier<double> _heroScroll = ValueNotifier<double>(0);

  // ─── 粒子动画 ───
  AnimationController? _ctrl;
  final List<_Particle> _particles = [];
  Offset _particleCenter = Offset.zero;
  bool _showParticles = false;
  OverlayEntry? _particleOverlay;

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

  void _fireEmojiParticles(Offset center) {
    final rng = Random();
    _particles.clear();
    for (var i = 0; i < 30; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = 90.0 + rng.nextDouble() * 180.0;
      _particles.add(
        _Particle(
          color: Colors.transparent,
          dx: cos(angle) * speed,
          dy: sin(angle) * speed - 70,
          size: 16.0 + rng.nextDouble() * 8.0,
          emoji: i.isEven ? '🐱' : '❤️',
        ),
      );
    }
    _particleCenter = center;
    _showParticles = true;
    _particleOverlay?.remove();
    _particleOverlay = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl!,
          builder: (_, __) => SizedBox.expand(
            child: CustomPaint(
              painter: _ParticlePainter(
                center: _particleCenter,
                progress: _ctrl!.value,
                particles: _particles,
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_particleOverlay!);
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
            if (_ctrl!.isCompleted) {
              _showParticles = false;
              _particleOverlay?.remove();
              _particleOverlay = null;
            }
          }),
        );
  }

  @override
  void dispose() {
    _particleOverlay?.remove();
    _particleOverlay = null;
    _ctrl?.dispose();
    _heroScroll.dispose();
    super.dispose();
  }

  void _onEggTap(String call) {
    final l10n = S.of(context);
    final msg = switch (call) {
      'BG7LZQ' => l10n.eggBg7lzq,
      'BG7PGW' => l10n.eggBg7pgw,
      'BG7LMW' => l10n.eggBg7lmw,
      'BG7OSL' => l10n.eggBg7osl,
      'BG2HCB' => l10n.eggBg2hcb,
      _ => null,
    };
    if (msg == null) return;
    HapticFeedback.mediumImpact();
    if (call == 'BG7OSL' || call == 'BG2HCB') {
      // 图片彩蛋：OSL 袋鼠 / BG2HCB 专属
      final eggAsset = call == 'BG7OSL'
          ? 'assets/osl.png'
          : 'assets/bg2hcb.jpg';
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
                eggAsset,
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 12),
              Text(
                call,
                style: ts(13, c: C.blue, w: FontWeight.w700),
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
      if (call == 'BG2HCB') {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          _fireEmojiParticles(box.size.center(Offset.zero));
        }
      }
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
              style: ts(13, c: C.blue, w: FontWeight.w700),
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
      backgroundColor: C.pageFill,
      appBar: MaterialAppBar(
        AppBar(
          backgroundColor: C.surfaceFillStrong,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: C.ink, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(S.of(context).about, style: ts(16, w: FontWeight.w700)),
          centerTitle: true,
        ),
      ),
      body: _buildBody(context),
    );
  }

  /// 整页内容。
  ///
  /// 拆出来是因为 Hero 有自己的入场动画与视差，跟下面这堆静态分节混在一起
  /// 之后，`build` 一眼看不到结构。
  Widget _buildBody(BuildContext context) {
    final t = S.of(context);
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            // 只把滚动量喂给底图视差，不 setState：整页不重建
            _heroScroll.value = n.metrics.pixels.clamp(0.0, 240.0);
            return false;
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // 封面、名片卡与各分节共用**同一个限宽容器**：桌面宽屏下它们同宽，
              // 边缘才对得齐（以前正文 640、封面 560，宽屏上两套宽度错开一截）
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 44),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _heroCard(context),

                        // 名片卡：往上骑 14px 压住封面下缘。translate 不占布局，
                        // 所以后面补 6px，视觉间距仍是 20px
                        Transform.translate(
                          offset: const Offset(0, -14),
                          child: _profileCard(context),
                        ),
                        const SizedBox(height: 6),

                        // ── 代码贡献 ──
                        _sectionHeader(
                          t.codeContributions,
                          Icons.code_rounded,
                          C.purple,
                        ),
                        const SizedBox(height: 8),
                        SoftCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _eggRow(t.codeContributionI18n, 'BD3QID'),
                              _eggRow(t.codeContributionZhTw, 'BA4UAX'),
                              _eggRow(t.codeContributionTranslation, 'BA7KSM'),
                              _row(
                                t.settingsContribCodeOptimization,
                                '清零（BG2HCB）',
                                onLongPress: () => _onEggTap('BG2HCB'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ── 开源与许可（原「开源致谢」+「许可证声明」并成一节） ──
                        _sectionHeader(
                          t.ossLicenseSection,
                          Icons.favorite_rounded,
                          C.red,
                        ),
                        const SizedBox(height: 8),
                        SoftCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _ossGrid(context),
                              _linkRow(
                                icon: Icons.description_rounded,
                                label: t.licenseName,
                                value: 'GPL-3.0',
                                url:
                                    'https://github.com/dariondong/APRSLocus/blob/main/LICENSE',
                              ),
                              _termsRow(context),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 10, 14, 12),
                                child: Text(
                                  t.licenseStatement,
                                  style: ts(11, c: C.grey, h: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ── 致谢名单（测试成员 + AI 算力 + 赞助入口并成一节） ──
                        _sectionHeader(
                          t.creditsSection,
                          Icons.group_rounded,
                          C.green,
                        ),
                        const SizedBox(height: 8),
                        SoftCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 12, 14, 0),
                                child: Text(t.testMembers, style: ts(11, c: C.grey)),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 8, 14, 10),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _memberChip('BG7PGW'),
                                    _memberChip('BG7LMW'),
                                    _memberChip('BG7OSL'),
                                    _memberChip('BD3QID'),
                                    _memberChip('BG4LZY'),
                                  ],
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                child: Text(
                                  '${t.aiSupport} · BA3RZL 养生',
                                  style: ts(11, c: C.grey),
                                ),
                              ),
                              _sponsorRow(context),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ── 用户反馈 ──
                        _sectionHeader(
                          t.feedback,
                          Icons.forum_rounded,
                          C.orange,
                        ),
                        const SizedBox(height: 8),
                        SoftCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _linkRow(
                                icon: Icons.public_rounded,
                                label: t.officialWebsite,
                                value: 'aprslocus.theez.top',
                                url: 'https://aprslocus.theez.top/',
                              ),
                              _linkRow(
                                icon: Icons.wechat_rounded,
                                label: t.qqGroup,
                                value: t.qqSoftwareName,
                                url: 'https://qm.qq.com/q/8pL6vc5YA0',
                              ),
                              _linkRow(
                                icon: Icons.link_rounded,
                                label: t.projectRepo,
                                value: 'GitCode',
                                url: 'https://gitcode.com/DarionDong/APRSLocus',
                              ),
                              _linkRow(
                                icon: Icons.code_rounded,
                                label: t.projectRepo,
                                value: 'GitHub',
                                url: 'https://github.com/dariondong/APRSLocus',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),
                        _footer(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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
    );
  }

  /// Hero 封面：实景照片 + 玻璃质感标题。
  ///
  /// 高度随宽度走（[_heroHeightFor]）：底图是 3:2，固定高度在桌面宽屏下会被
  /// `cover` 裁得只剩中间一条，山峰就切出去了。
  Widget _heroCard(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: C.ink.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: C.ink.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: LayoutBuilder(
            builder: (ctx, cons) {
              final h = _heroHeightFor(cons.maxWidth);
              // 比原图还扁的超宽屏改用整体装入：宁可上下留边，
              // 也不能把火山裁掉。
              final tooWide = cons.maxWidth / h > 1.62;
              return SizedBox(
                height: h,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 底图：随滚动轻微视差（放大 12% 留出位移余量）
                    AnimatedBuilder(
                      animation: _heroScroll,
                      builder: (_, __) => Transform.scale(
                        scale: 1.12,
                        child: Transform.translate(
                          offset: Offset(0, -_heroScroll.value * 0.035),
                          child: Image.asset(
                            'assets/about_hero.jpg',
                            fit: tooWide ? BoxFit.contain : BoxFit.cover,
                            alignment: Alignment.center,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                    // 顶部压暗 + 底部渐隐：白字压在亮天空上也能读清
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          // 底部要**尽早**压暗：标题落在 ~70% 高度，
                          // 那里还压着明亮的山体，0.30 的白字根本立不住。
                          // 因此从 55% 就开始起色，到 78% 已经够深。
                          colors: [
                            Colors.black.withValues(alpha: 0.26),
                            Colors.transparent,
                            C.ink.withValues(alpha: 0.58),
                            C.ink.withValues(alpha: 0.94),
                          ],
                          stops: const [0.0, 0.30, 0.55, 1.0],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Spacer(),
                              _glassBox(
                                radius: 99,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 5,
                                ),
                                child: Text(
                                  'v${AppState.appVersion}',
                                  style: ts(
                                    10.5,
                                    c: Colors.white,
                                    w: FontWeight.w700,
                                    ls: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              _glassBox(
                                radius: 16,
                                padding: const EdgeInsets.all(5),
                                child: AppLogo(size: 40),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'APRSlocus',
                                      style: ts(
                                        24,
                                        w: FontWeight.w800,
                                        ls: -0.6,
                                        c: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      S.of(context).aboutSubtitle,
                                      style: ts(
                                        12,
                                        c: Colors.white.withValues(
                                          alpha: 0.90,
                                        ),
                                        h: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 内侧极细描边：卡片与照片之间多一道光边
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 名片卡：骑在封面下缘的一张小卡，把「身份 + 官网 + 分享」收在一处。
  ///
  /// 以前这三样拆成「作者」分节 + 一张独立的分享卡，一页光这两块就占两个分节；
  /// 并成一张卡之后整页少一个分节，封面与身份也连成了一体。
  /// **不放作者个人站**：那是作者自己的站，跟 App 官网不是一回事，这里只留官网。
  Widget _profileCard(BuildContext context) {
    final t = S.of(context);
    return Container(
      decoration: cardDeco(r: 20),
      child: Column(
        children: [
          // 头部：呼号 · 名字（长按呼号仍是彩蛋）
          GestureDetector(
            onLongPress: () => _onEggTap('BG7LZQ'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'BG7LZQ · Darion',
                          style: ts(13.5, w: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(t.author, style: ts(11, c: C.grey)),
                      ],
                    ),
                  ),
                  _iconChip(
                    icon: Icons.language_rounded,
                    url: 'https://aprslocus.theez.top/',
                  ),
                ],
              ),
            ),
          ),
          // 分享入口：整行可点。分享只留这一处（右上角不再放重复的图标按钮）
          InkWell(
            onTap: _showShareSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: C.border, width: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.share_rounded, size: 15, color: C.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.shareApp, style: ts(12, c: C.slate)),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: C.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 名片卡右上角的小图标按钮（官网入口）
  Widget _iconChip({required IconData icon, required String url}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: C.blueBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: C.blue),
      ),
    );
  }

  /// 赞助与鸣谢入口行（并进「致谢名单」卡）
  Widget _sponsorRow(BuildContext context) {
    final t = S.of(context);
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SponsorPage()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8C00), Color(0xFFEA580C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.volunteer_activism_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Text(t.sponsors, style: ts(12, c: C.slate)),
            // 值右对齐并允许省略：西语那版「查看作者与赞助详情」很长，
            // 硬塞会直接撑出 RenderFlex 溢出条
            Expanded(
              child: Text(
                t.viewSponsorDetails,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(12, c: C.blue, w: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: C.grey),
          ],
        ),
      ),
    );
  }

  /// 页脚：法律声明 + 复制应用信息 + 摄影署名。
  Widget _footer(BuildContext context) {
    final t = S.of(context);
    return Column(
      children: [
        // 一条细分割线收尾
        Container(height: 1, color: C.border),
        const SizedBox(height: 18),
        Text(
          t.usageNotice,
          textAlign: TextAlign.center,
          style: ts(11, c: C.grey, h: 1.7),
        ),
        const SizedBox(height: 10),
        Text(
          t.licenseNotice,
          textAlign: TextAlign.center,
          style: ts(10, c: C.greyLight, h: 1.7),
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: () {
            final info = t.appInfoText(AppState.appVersion);
            Clipboard.setData(ClipboardData(text: info));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(t.appInfoCopied),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: C.ink,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: C.greyBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.copy_rounded, size: 14, color: C.grey),
                const SizedBox(width: 6),
                Text(t.copyAppInfo, style: ts(12, c: C.slate)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        // 摄影署名（与关于页 Hero 底图对应）
        Text(
          '封面摄影 · Pixabay / frankpotters7',
          textAlign: TextAlign.center,
          style: ts(9.5, c: C.greyLight, ls: 0.2),
        ),
      ],
    );
  }

  // ── 组件 ──

  /// Hero 封面的高度。
  ///
  /// 底图是 3:2（1280×853），容器高度按宽度推：手机竖屏（~360 宽）大约
  /// 232；平板/桌面（≥600 宽）给到 300 封顶。
  double _heroHeightFor(double w) => (w * 0.64).clamp(196.0, 300.0);

  /// 玻璃质感。
  ///
  /// 这里**故意不做真模糊**：`BackdropFilter` 每帧都要把背后的照片离屏重画
  /// 一遍（见 lib/material.dart 顶部关于模糊代价的说明），而 Hero 底图还带
  /// 视差动画，套上去等于每帧多一次全层 saveLayer。半透明白 + 顶部高光 +
  /// 一道细描边在照片上已经足够像玻璃，代价为零。
  Widget _glassBox({
    required Widget child,
    double radius = 14,
    EdgeInsetsGeometry padding = const EdgeInsets.all(6),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.30),
          width: 0.8,
        ),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color c) {
    return Row(
      children: [
        // 淡色底托 + 彩色图标，比光秃秃一个图标更成体系
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: c),
        ),
        const SizedBox(width: 8),
        Text(title, style: ts(13, w: FontWeight.w800)),
        const SizedBox(width: 10),
        // 右侧细横线：把标题和内容一条条串起来
        Expanded(child: Container(height: 1, color: C.border)),
      ],
    );
  }

  Widget _row(String label, String value, {VoidCallback? onLongPress}) {
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
      ),
      child: Row(
        children: [
          Text(label, style: ts(12, c: C.slate)),
          const Spacer(),
          Text(value, style: ts(12, w: FontWeight.w600)),
          if (onLongPress != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: C.grey),
          ],
        ],
      ),
    );
    if (onLongPress != null) {
      return GestureDetector(onLongPress: onLongPress, child: row);
    }
    return row;
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

  /// 用户协议入口行（App 内页面，非外链）
  Widget _termsRow(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TermsPage()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.assignment_rounded, size: 15, color: C.blue),
            SizedBox(width: 8),
            Text(S.of(context).userAgreement, style: ts(12, c: C.slate)),
            Spacer(),
            Text(
              'V1.0',
              style: ts(12, c: C.blue, w: FontWeight.w600),
            ),
            SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 16, color: C.grey),
          ],
        ),
      ),
    );
  }

  /// 「开源与许可」卡顶部的 2×2 网格。
  ///
  /// 四个开源项原本是四行「图标 + 标题 + 说明」，白占四行高度；排成两列后高度
  /// 减半，宽屏下也不至于每行只有几个字。
  Widget _ossGrid(BuildContext context) {
    final t = S.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ossCell(
                icon: Icons.flutter_dash,
                color: C.blue,
                title: t.osFlutter,
                desc: t.osFlutterDesc,
                right: true,
              ),
            ),
            Expanded(
              child: _ossCell(
                icon: Icons.web_rounded,
                color: C.green,
                title: t.osAmap,
                desc: t.osAmapDesc,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _ossCell(
                icon: Icons.cell_tower_rounded,
                color: C.purple,
                title: t.osAprs,
                desc: t.osAprsDesc,
                right: true,
              ),
            ),
            Expanded(
              child: _ossCell(
                icon: Icons.group_rounded,
                color: C.orange,
                title: t.osHam,
                desc: t.osHamDesc,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 2×2 网格里的一格：淡色底托图标 + 标题 + 说明。
  ///
  /// 格子之间用**边框**而不是竖直分割线：`Row` 里那条 `Container(width: 0.4)` 得
  /// 靠 `IntrinsicHeight` + `stretch` 才撑得满高（多一次固有尺寸测量），而两格的
  /// 说明文字行数未必一样——边框方案不受影响。
  Widget _ossCell({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    bool right = false,
    bool bottom = true,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        border: Border(
          right:
              right ? BorderSide(color: C.border, width: 0.4) : BorderSide.none,
          bottom: bottom
              ? BorderSide(color: C.border, width: 0.4)
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts(12, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(desc, style: ts(11, c: C.grey, h: 1.4)),
        ],
      ),
    );
  }

  /// 测试成员呼号 chip（长按仍是彩蛋）
  Widget _memberChip(String call) {
    return GestureDetector(
      onLongPress: () => _onEggTap(call),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: C.green.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.settings_input_antenna_rounded,
              size: 12,
              color: C.green,
            ),
            const SizedBox(width: 5),
            Text(call, style: ts(11.5, c: C.green, w: FontWeight.w700)),
          ],
        ),
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
  final String? emoji;
  _Particle({
    required this.color,
    required this.dx,
    required this.dy,
    required this.size,
    this.emoji,
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
      final dx = center.dx + pt.dx * p;
      final dy = center.dy + pt.dy * p + 80 * p * p; // 重力
      final s = pt.size * (1.0 - p * 0.5);
      if (pt.emoji != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: pt.emoji,
            style: TextStyle(
              fontSize: s,
              color: Colors.black.withValues(alpha: opacity),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(dx - tp.width / 2, dy - tp.height / 2));
      } else {
        final paint = Paint()
          ..color = pt.color.withValues(alpha: opacity)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(dx, dy), s, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
