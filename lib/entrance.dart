import 'package:flutter/material.dart';

/// 打开页面时卡片逐条淡入上移（用户要的「线性动画」）。
///
/// 为什么是「逐条」：设置页是一列卡片，整页一起淡入看起来像加载慢了半拍；
/// 自上而下一条接一条进场，眼睛才知道这是一张单子、从上往下读。
///
/// 三个决定：
/// * **匀速**（`Curves.linear`）：用户要的就是线性动画，加缓动等于换了一种观感；
/// * **没有 Timer**：被延迟的那几条如果靠定时器起跑，widget 测试会在结尾报
///   「A Timer is still pending」。这里每条各自跑一个等长的控制器，靠
///   `Interval` 把「晚 40 毫秒」编进同一条时间轴 —— 所有条同一帧起跑，错位由曲线给；
/// * **阶梯有上限**（[maxStep]）：页尾那几条再往下等就成了「打开半天才出现」，
///   超过第 8 条的一起上 —— 反正那时它们多半还在屏幕外。
///
/// 序号用调用点传进来的 [index]，不用「自己数是第几个」：顺序与视觉顺序一致，
/// 重排卡片时只改一处。
class RiseIn extends StatefulWidget {
  /// 这一条在单子里的序号（0 起），决定它什么时候开始
  final int index;
  final Widget child;

  /// 什么时候该放这段动画。
  ///
  /// 设置页在 1.0 / 2.0 / 精简三套外壳里都是 `IndexedStack` 的常驻子页 —— 开机
  /// 那一刻就已经建好了，等用户真的点到「设置」时动画早跑完了。外壳把当前页签
  /// 是不是本页传进来，由 false 变 true 的那一刻重新起跑。
  ///
  /// 默认 true：普通推入的子页建好即播。
  final bool play;

  /// 相邻两条的间隔
  static const Duration step = Duration(milliseconds: 40);

  /// 单条的时长
  static const Duration span = Duration(milliseconds: 240);

  /// 阶梯最多走到第几条
  static const int maxStep = 8;

  /// 上移的距离（像素）。用固定像素而不是自身高度的比例：卡片高矮差得远，
  /// 按比例算，长卡片飘一大段、短卡片几乎不动。
  static const double risePx = 14;

  const RiseIn(
      {super.key, required this.index, this.play = true, required this.child});

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;

  /// 动画结束后卸掉那层 Opacity + Transform：之后每次重绘少一层合成
  bool _live = true;

  @override
  void initState() {
    super.initState();
    final total = RiseIn.span + RiseIn.step * RiseIn.maxStep;
    final step = widget.index <= 0
        ? 0
        : (widget.index > RiseIn.maxStep ? RiseIn.maxStep : widget.index);
    final beginFrac = (RiseIn.step * step).inMilliseconds / total.inMilliseconds;
    final lenFrac = RiseIn.span.inMilliseconds / total.inMilliseconds;
    _c = AnimationController(vsync: this, duration: total, value: 1);
    _t = CurvedAnimation(
      parent: _c,
      // 匀速：用户明确要线性，不加缓动
      // step 已按 maxStep 封顶，所以 begin + len 最大就是 1.0，不用再夹
      curve: Interval(beginFrac, beginFrac + lenFrac, curve: Curves.linear),
    );
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _live = false);
      }
    });
    if (widget.play) {
      _c.value = 0;
      _c.forward();
    } else {
      // 还没轮到它上台：停在末尾、不占合成层。**不能**停在 0 位 ——
      // 那样一旦外壳忘了把 play 翻成 true，这页就永远是空白。
      _live = false;
    }
  }

  @override
  void didUpdateWidget(covariant RiseIn old) {
    super.didUpdateWidget(old);
    // 页签切到本页：重新跑一遍（这就是用户要的「打开设置页时」）
    if (widget.play && !old.play) {
      // 这里不调 setState：didUpdateWidget 之后必然紧接着 build，
      // 直接改标志就够了（在 build 阶段调 setState 是多余的）
      _live = true;
      _c.value = 0;
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 系统里关掉动画的（无障碍设置 / 省电）直接给成品，别让人等
    if (!_live || MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      // 子节点只建一次：每帧只换 Opacity 与位移，不重建卡片本身
      child: widget.child,
      builder: (context, child) {
        final t = _t.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, RiseIn.risePx * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

/// 一列卡片，进场时逐条淡入上移。
///
/// 它是 [Column] 的替身：调用点从 `Column(` 换成 `StaggerColumn(` 就行，
/// 不用给每一张卡片再包一层 —— 设置主页那个 children 列表有两百多行，
/// 逐项包起来会把一次改动变成一次重排。
///
/// 算序号时**跳过 `SizedBox`**：那些是卡片之间的空隙，不是一张卡。
class StaggerColumn extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;

  /// 见 [RiseIn.play]：外壳把「当前页签是不是本页」传进来
  final bool play;

  const StaggerColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.play = true,
  });

  @override
  Widget build(BuildContext context) {
    var slot = 0;
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: [
        for (final w in children)
          if (w is SizedBox)
            w
          else
            RiseIn(index: slot++, play: play, child: w),
      ],
    );
  }
}
