import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'early_member.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 「获得新荣誉」庆祝动画 ───
///
/// 打开软件时若检测到**账号被新授予荣誉**，弹出这一层：遮罩上金箔粒子四散，
/// 中央卡片（白底 + 大圆角 + 柔和阴影，与全 App 一致）里徽章**带光环浮现**，
/// 光环 / 射线自荣誉色扩散，最后落到荣誉名 + 描述 + 蓝色主按钮。
///
/// 设计取舍：
///   * **只在启动时**判断（见 [AppState] 里的调用），不打扰使用中的操作；
///   * 造型**沿用项目语言**：浅色底、白卡片、大圆角、
///     [ts] 文字、[C.blue] 主按钮 —— 不做霓虹暗黑那套第二视觉；
///   * 动画只是「高级感」的点缀（弹性入场 + 呼吸微光 + 粒子），不盖过信息；
///   * 点按任意处或按钮关闭；关闭后走 [onDone] 让上层落盘「已展示」记录，
///     确保**同一枚荣誉只弹一次**；
///   * 徽章配色取自荣誉自己的 [Honor.color]，与荣誉墙 / 设置页**同色**，不做第二套色。
class HonorCelebrationPage extends StatefulWidget {
  final Honor honor;

  /// 界面语言键（'zh' / 'zh-TW' / 'en'），由调用方用 honorLangOf 取好。
  final String lang;
  final VoidCallback onDone;

  const HonorCelebrationPage({
    super.key,
    required this.honor,
    required this.lang,
    required this.onDone,
  });

  @override
  State<HonorCelebrationPage> createState() => _HonorCelebrationPageState();
}

class _HonorCelebrationPageState extends State<HonorCelebrationPage>
    with TickerProviderStateMixin {
  /// 入场时间轴（单次播放）
  late final AnimationController _intro;

  /// 停稳后的常驻微光（循环，让画面「活着」）
  late final AnimationController _shimmer;

  late final Animation<double> _cardFade;
  late final Animation<double> _cardScale;
  late final Animation<double> _badgeScale;
  late final Animation<double> _capFade;
  late final Animation<double> _nameFade;
  late final Animation<double> _descFade;
  late final Animation<double> _buttonFade;

  final math.Random _rng = math.Random();
  final List<_Confetti> _confetti = [];

  @override
  void initState() {
    super.initState();
    _buildConfetti();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _cardFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );
    _cardScale = Tween<double>(begin: 0.88, end: 1.0).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
    ));

    // 徽章：弹性放大，略带回弹的「高级感」
    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 72,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 28,
      ),
    ]).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.14, 0.66, curve: Curves.linear),
    ));

    _capFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.34, 0.62, curve: Curves.easeOutCubic),
    );
    _nameFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.42, 0.74, curve: Curves.easeOutCubic),
    );
    _descFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.50, 0.84, curve: Curves.easeOutCubic),
    );
    _buttonFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.62, 1.0, curve: Curves.easeOutCubic),
    );

    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _intro.forward();
    _intro.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.mediumImpact();
        _shimmer.repeat();
      }
    });
  }

  void _buildConfetti() {
    _confetti.clear();
    for (var i = 0; i < 52; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      _confetti.add(
        _Confetti(
          angle: angle,
          speed: 90 + _rng.nextDouble() * 260,
          size: 4 + _rng.nextDouble() * 7,
          spin: (_rng.nextDouble() - 0.5) * 10,
          delay: _rng.nextDouble() * 0.24,
          color: _palette[_rng.nextInt(_palette.length)],
          round: _rng.nextBool(),
        ),
      );
    }
  }

  /// 粒子配色：以荣誉色为主，掺少量暖金与白，克制不发荧光。
  List<Color> get _palette {
    final c = widget.honor.color;
    return [
      c,
      c.withValues(alpha: 0.7),
      const Color(0xFFD9A441),
      const Color(0xFFE9C77E),
      Colors.white,
    ];
  }

  @override
  void dispose() {
    _intro.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  void _finish() {
    HapticFeedback.selectionClick();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 遮罩：与项目对话框一致的暗底
            ColoredBox(color: C.black.withValues(alpha: 0.46)),
            // 金箔粒子（在卡片之下，自卡片边缘外散开）
            AnimatedBuilder(
              animation: _intro,
              builder: (context, _) => CustomPaint(
                painter: _CelebrationPainter(
                  progress: _intro.value,
                  confetti: _confetti,
                ),
              ),
            ),
            // 主卡片：白底 + 大圆角 + 柔和阴影（与全 App 一致）
            Center(
              child: FadeTransition(
                opacity: _cardFade,
                child: ScaleTransition(
                  scale: _cardScale,
                  child: _card(S.of(context), widget.honor.color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(S s, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: C.surfaceFill,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 40,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _badgeStage(color),
                const SizedBox(height: 24),
                _fade(_capFade, _cap(s)),
                const SizedBox(height: 8),
                _fade(_nameFade, _name()),
                const SizedBox(height: 12),
                _fade(_descFade, _desc()),
                const SizedBox(height: 24),
                _fade(_buttonFade, _button(s)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 徽章舞台：光环 / 射线自荣誉色扩散，中心是徽章色块。
  Widget _badgeStage(Color color) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _intro,
            builder: (context, _) => CustomPaint(
              size: const Size(200, 200),
              painter: _RaysPainter(progress: _intro.value, accent: color),
            ),
          ),
          // 常驻微光：一道柔和高光缓慢扫过徽章
          AnimatedBuilder(
            animation: _shimmer,
            builder: (context, child) => ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) {
                final t = _shimmer.value;
                return LinearGradient(
                  begin: Alignment(-1.0 + t * 2.0, -1),
                  end: Alignment(-0.2 + t * 2.0, 1),
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.30),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.35, 0.5, 0.65],
                ).createShader(bounds);
              },
              child: child,
            ),
            child: ScaleTransition(
              scale: _badgeScale,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Icon(widget.honor.icon, color: color, size: 60),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fade(Animation<double> a, Widget child) => FadeTransition(
        opacity: a,
        child: AnimatedBuilder(
          animation: a,
          builder: (context, _) => Transform.translate(
            offset: Offset(0, (1 - a.value) * 16),
            child: child,
          ),
        ),
      );

  /// 小字标签：沿用「分区标题」那种小号大写字距，点明这是荣誉授予。
  Widget _cap(S s) => Text(
        s.honorCelebrateTitle,
        textAlign: TextAlign.center,
        style: ts(12, c: C.grey, w: FontWeight.w800, ls: 1.4),
      );

  Widget _name() => Text(
        widget.honor.labelOf(widget.lang),
        textAlign: TextAlign.center,
        style: ts(26, c: C.black, w: FontWeight.w900, ls: 0.2),
      );

  Widget _desc() {
    final d = widget.honor.descOf(widget.lang);
    if (d.isEmpty) return const SizedBox.shrink();
    return Text(
      d,
      textAlign: TextAlign.center,
      style: ts(13.5, c: C.slate, h: 1.55),
    );
  }

  /// 主按钮：项目里最常见的实心蓝按钮。
  Widget _button(S s) => SizedBox(
        width: double.infinity,
        child: Material(
          color: C.blue,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _finish,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  s.honorCelebrateOk,
                  style: ts(15, w: FontWeight.w800, c: Colors.white),
                ),
              ),
            ),
          ),
        ),
      );
}

/// 金箔 / 纸屑粒子
class _Confetti {
  final double angle;
  final double speed;
  final double size;
  final double spin;
  final double delay;
  final Color color;
  final bool round;
  _Confetti({
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
    required this.delay,
    required this.color,
    required this.round,
  });
}

class _CelebrationPainter extends CustomPainter {
  final double progress;
  final List<_Confetti> confetti;
  _CelebrationPainter({required this.progress, required this.confetti});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // 粒子自卡片上半部（徽章位置附近）迸发
    final cy = size.height / 2 - 60;
    for (final c in confetti) {
      final local = ((progress - c.delay) / (1 - c.delay)).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final eased = 1 - math.pow(1 - local, 3);
      final dist = c.speed * eased * 1.6;
      final x = cx + math.cos(c.angle) * dist;
      final y = cy + math.sin(c.angle) * dist + 130 * local * local;
      final op = (1 - local) * 0.95;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(c.angle + c.spin * local);
      final paint = Paint()..color = c.color.withValues(alpha: op);
      if (c.round) {
        canvas.drawCircle(Offset.zero, c.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: c.size, height: c.size * 0.55),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) =>
      old.progress != progress || old.confetti != confetti;
}

/// 徽章背后的光环 / 射线
class _RaysPainter extends CustomPainter {
  final double progress;
  final Color accent;
  _RaysPainter({required this.progress, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 射线：低透明、短促，扩散到一半即隐去
    final tr = (progress / 0.7).clamp(0.0, 1.0);
    if (tr < 1) {
      final op = (1 - tr) * 0.30;
      final rot = tr * 0.5;
      final maxR = size.width * 0.5;
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi * 2 / 12 + rot;
        final len = maxR * (0.72 + 0.28 * math.sin(i * 2.3));
        final half = 0.016 + 0.006 * math.sin(i * 1.7);
        final grad = Paint()
          ..shader = LinearGradient(
            colors: [
              accent.withValues(alpha: 0),
              accent.withValues(alpha: op),
              accent.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromLTWH(cx - len, cy - len, len * 2, len * 2));
        final path = Path()
          ..moveTo(cx, cy)
          ..lineTo(cx + math.cos(a - half) * len, cy + math.sin(a - half) * len)
          ..lineTo(cx + math.cos(a) * len, cy + math.sin(a) * len)
          ..lineTo(cx + math.cos(a + half) * len, cy + math.sin(a + half) * len)
          ..close();
        canvas.drawPath(path, grad);
      }
    }

    // 光环：两圈错峰扩散
    for (var k = 0; k < 2; k++) {
      final tt = ((progress - k * 0.12) / 0.62).clamp(0.0, 1.0);
      if (tt <= 0 || tt >= 1) continue;
      final eased = 1 - math.pow(1 - tt, 3);
      final radius = 44.0 + 62 * eased;
      final raw = (1 - tt) * (0.5 - k * 0.16);
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = accent.withValues(alpha: raw < 0 ? 0 : raw),
      );
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) =>
      old.progress != progress || old.accent != accent;
}
