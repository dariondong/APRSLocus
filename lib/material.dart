import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'theme.dart';

/// ─── 界面材质：把「半透明 + 背后真模糊」这一层单独抽出来 ───
///
/// 为什么需要这个文件：磨砂玻璃/云母的观感来自**两层**，缺一层都会「看起来像
/// 坏了」：
///
/// 1. **表面半透明**：由 `C.surfaceFill` / `C.surfaceFillStrong` / `C.sheetFill`
///    这些 getter 统一给出（调用点一处都不用改）。所以卡片、设置行、输入框之类
///    **不需要**在这里套一层 —— 它们背后只有一层已经画好的底（壁纸/背景图），
///    再模糊一次是纯浪费，而每个 BackdropFilter 都是一次整屏 saveLayer：
///    一屏十几张卡片就是十几层，在低端 Android 上直接掉帧。
/// 2. **背后真模糊**：[MaterialSurface]。只给**压在内容之上**的表面用 ——
///    顶栏/侧栏/底部导航/AppBar/地图浮层/底部面板/弹窗。这些表面背后是真的内容
///    （地图瓦片、滚动中的列表），不模糊的话文字会和瓦片糊在一起没法看。
///
/// 材质关闭（[UiMaterial.none]）时 [MaterialSurface] 原样返回 child：不新建
/// 任何图层、不做任何裁剪，默认观感与旧版逐像素一致（见 theme.dart 里
/// `C.materialOn` 的说明）。
///
/// 刻意**不做**的两件事（都是「看着想做、其实有害」的）：
/// - **不铺噪点**：Win11 云母有细微颗粒，但在 Flutter 里只能靠 CustomPaint
///   每帧画上万个点（或先离屏生成一张纹理再按 TileMode.repeat 贴图）。前者在
///   地图页每帧都重画，代价远超收益；后者要多一套异步纹理生命周期管理。
///   这里用「低模糊 + 带主色的底色」表达云母的质感，而不是假装有颗粒。
/// - **不给卡片套 BackdropFilter**：见上，卡片的通透靠「底本身够柔和 + 表面半透明」
///   实现，不需要每张卡一次模糊。
/// ─── 小浮层不模糊，大面板才磨砂 ───
///
/// `BackdropFilter` 不是免费的：它每帧都要把**背后已经画好的内容**离屏重绘一遍，
/// 代价 ≈ 被模糊的面积 × 半径，而且**每个实例各付一次**。而小浮层上根本看不出
/// 模糊 —— 你能看见的是它的填充色（38px 的工具钮上，模糊只是把边缘糊成一团灰）。
/// 于是「小浮层实心 + 大面板磨砂」既保住观感，又把同时存在的模糊层从十几个降到
/// 两三个：地图页原来光工具钮就有 8 个 `BackdropFilter`，而它们全是 38px。
///
/// ── 为什么**没有**做成「按面积自动判断」（我试过，行不通）──
///
/// 第一版用 `LayoutBuilder` 拿自己的尺寸：面积够大才插模糊层。看着很聪明，
/// 但地图上的小浮层**全都是 `Positioned` 包着的**，而 Positioned 的子项拿到的
/// 约束是**容器（整个 Stack）的大小**、不是它自己的尺寸 —— 于是 38px 的按钮被
/// 量成整屏，自动规则恰好在最需要它的地方失效。这种「静默失效」比不做还危险，
/// 所以改成**显式**：
///
/// * 小浮层 → `blurSigma: 0`（不模糊）+ `C.chipFill` / [chipTint]（实心填色）；
/// * 大面板 → 不写 `blurSigma`，用材质默认半径。
///
/// 两者的配对由 `tool/check_material_coverage.py` 检查：出现 `chipFill`/`chipTint`
/// 的 `MaterialSurface` 必须写 `blurSigma: 0`，否则报红 —— 免得将来有人只改一半。

class MaterialSurface extends StatelessWidget {
  /// 被包裹的表面（自身通常带半透明填色与阴影）
  final Widget child;

  /// 裁剪圆角：必须和 child 自己的圆角一致，否则模糊会从圆角外露出来一角
  final double radius;

  /// 只有上方两角是圆角（底部面板用）
  final bool topOnly;

  /// 模糊强度：
  /// * `null`（默认）→ 用材质默认半径 [C.materialBlur]（大面板/条走这条）；
  /// * `0` → **不模糊**（小浮层走这条，必须配 `C.chipFill` / [chipTint] 实心填色）；
  /// * `> 0` → 用指定半径。
  ///
  /// 小浮层为什么必须显式写 0：见文件顶部「为什么没有做成按面积自动判断」。
  final double? blurSigma;

  const MaterialSurface({
    super.key,
    required this.child,
    this.radius = 0,
    this.topOnly = false,
    this.blurSigma,
  });

  /// 为什么把模糊层垫在 child **下面**，而不是 `ClipRRect > BackdropFilter > child`：
  ///
  /// 后者会把 child 的**投影一起裁掉**。而调用点的 decoration 里都带着
  /// `boxShadow`（浮层靠它和地图分开），裁掉之后材质一开，所有浮层都变成
  /// 贴着地图的平片 —— 用户看到的不是「材质」，是「阴影没了」。所以这里改成
  /// 在 child 背后插一层**只裁剪模糊**的圆角层，child 自己照旧画它的阴影与描边。
  ///
  /// 合成顺序也是对的：先画（被裁剪的）模糊底，再画 child 的半透明填色 ——
  /// 这正好就是「磨砂玻璃」的定义。
  @override
  Widget build(BuildContext context) {
    if (!C.materialOn) return child;
    final sigma = blurSigma ?? C.materialBlur;
    // 显式 0：调用点明确要实心（小浮层都是这么写的，见文件顶部的说明）
    if (sigma <= 0) return child;
    return _blurred(sigma);
  }

  Widget _blurred(double sigma) {
    final br = topOnly
        ? BorderRadius.vertical(top: Radius.circular(radius))
        : BorderRadius.circular(radius);
    return Stack(
      clipBehavior: Clip.none, // 不裁 child 的阴影（见上）
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: br,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// 顶栏（AppBar）用的材质外壳
///
/// 为什么需要单独一个类：`Scaffold.appBar` 的类型是 `PreferredSizeWidget`，
/// 直接把 AppBar 塞进 MaterialSurface 会丢掉 `preferredSize`，
/// 布局会变成「顶栏高度按内容算」。这里显式转发 preferredSize。
///
/// 用法上要求 AppBar 自己的 `backgroundColor` 取 `C.surfaceFillStrong`
/// （材质开启时它是半透明的）—— 顶栏若还是实色，模糊就被自己盖住了，
/// 而那种「改了没反应」的表现最难查。
///
/// 注意必须 **extends StatelessWidget implements PreferredSizeWidget**，
/// 不能只写 `implements`：后者会让父类退化成 Object，于是 `{super.key}` 无处可传
/// （报 super_formal_parameter_without_associated_named），还得自己实现
/// Diagnosticable 的一整套方法。这一条是 CI 的 analyze 拦下来的。
class MaterialAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget child;
  const MaterialAppBar(this.child, {super.key});

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) => MaterialSurface(child: child);
}

/// 把一个小控件的底色调成「实心小浮层」的透明度 —— **保留它的色相**。
///
/// 与 [surfaceTint] 的分工（别混用）：
/// * [surfaceTint] 给**会做模糊**的表面（AppBar 这类大面积条）→ 半透明，靠背后的
///   模糊把它和内容分开；
/// * [chipTint] 给**不做模糊**的小控件（38px 工具钮、圆形按钮）→ 近乎不透明，
///   自己就把底下的地图盖住。两者分别对应「不模糊的小浮层」与「模糊的大面板」。
Color chipTint(Color c) {
  if (!C.materialOn) return c;
  return c.withValues(alpha: c.a * 0.94);
}

/// 把一个「表面色」调成材质该有的透明度 —— **保留它的色相**。
///
/// 地图右侧工具列这类按钮的底色是传参进来的（选中态蓝底、普通白底），
/// 直接换成 `C.surfaceFillStrong` 会把「选中变蓝」这个信息丢掉；
/// 不换又是实色，磨砂就等于没开。所以按它自己的 alpha 乘一个系数：
/// 颜色的语义（哪个是选中）留着，只有通透程度跟着材质走。
///
/// 材质关闭时原样返回 —— 调用点不必自己写 if。
Color surfaceTint(Color c) {
  if (!C.materialOn) return c;
  return c.withValues(alpha: c.a * uiMaterialAlphaOf(C.material));
}
