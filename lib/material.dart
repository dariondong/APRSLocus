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
/// ─── 两档材质：小浮层轻磨砂，大面板重磨砂 ───
///
/// `BackdropFilter` 不是免费的：它每帧都要把**背后已经画好的内容**离屏重绘一遍，
/// 代价 ≈ 被模糊的面积 × 半径，而且**每个实例各付一次**。所以两档的**半径**不同：
///
/// ── 曾经有一个 `blurWhen`（动画期关掉模糊），现在已经删掉 ──
///
/// 它当初是为了治「面板一展开就卡」：动画中面板高度每帧在变，`BackdropFilter`
/// 的几何也就每帧在变，于是每帧都要重做一次离屏模糊。关掉模糊确实省了那十几帧，
/// **但代价是必须同时把填色换成不透明的白** —— 而正常态的面板只有 58% alpha，
/// 这一跳非常显眼，用户看到的就是「一拖就莫名其妙变白」。
///
/// 正确的做法不在这一层，而在**调用点的几何**：让面板**自身高度固定**、只裁出
/// 可视区（见 `shell2` 面板那一段）。这样模糊层的几何在拖动/动画中完全不变，
/// 叠加底图冻结（模糊结果可复用），模糊就能**一直开着** —— 既不卡、也不变白。
/// 所以这里不再提供开关：**谁要用模糊，谁就得保证自己的几何是稳定的。**
///
/// * 小浮层（工具钮 / 图例 / 提示胶囊 / 细横条）→ `blurSigma: C.chipBlur`
///   + `C.chipFill` / [chipTint]。它们**面积小**，代价本来就低；12 的半径既看得出
///   磨砂，又不会把 38px 按钮的边缘糊成一团灰。
/// * 大面板（底面板 / 侧栏 / 顶栏 / 导航胶囊 / AppBar）→ 不写 `blurSigma`，
///   用材质默认半径（玻璃 24 / 云母 16）。
///
/// 真正的性能问题是**同时存在的层数**与**重建频率**，不是这两个半径：这一版同时
/// 把外壳「每秒重建数次」改成「只在显示值变化时重建」，并把半径从 34/22 降到 24/16。
///
/// ── 每层 BackdropFilter 真正贵在哪：一次 render pass 的收尾与重开 ──
///
/// 引擎给每个 `BackdropFilter` 做的事不是「算一次模糊」这么简单：它要把**当前已经画好的
/// 内容**当输入，所以必须**结束当前 render pass**（在 Android/Impeller 上这就是一次
/// 贴着屏幕大小的 flush + 重开），采样，然后再开一层。代价主要不在面积，而在
/// **这一进一出的次数**。地图页一屏有十来个 38px 小浮层（工具钮 8 颗 + 图例 + 信息条
/// + 上报横杠 + 底部坐标条），它们背后是同一张地图 —— 十几次收尾/重开每帧都发生一次，
/// 列表一滚动（60fps）就是每秒上千次。
///
/// 所以这一版把 [MaterialSurface] 里的模糊改成 `BackdropFilter.grouped`，并把
/// **可以共享底的那一簇**（互不重叠、中间没有别的内容、背后同一张底）包进一个
/// `BackdropGroup`（见 `map_page` 里那一段）。同 key 之后引擎只采一次底；若各层的
/// filter 又相同（小浮层全是 `C.chipBlur`），它连模糊也只算一次，再按各自的矩形贴上去
/// —— **观感逐像素不变**。
///
/// 反过来说，**不能整页乱包**：共享 key 的语义是「后一个表面采样的是第一个表面**之前**
/// 的那张底」—— 两个表面之间画的东西不会出现在它的模糊里。所以只有「连续绘制、
/// 互不重叠」的一簇才能合并；没有 `BackdropGroup` 祖先时 `.grouped` 退化成原来的
/// 各算各的（安全），所以调用点没包也不会坏，只是省不到。
///
/// ── 为什么**没有**做成「按面积自动判断」（我试过，行不通）──
///
/// 第一版用 `LayoutBuilder` 拿自己的尺寸：面积够大才插模糊层。看着很聪明，
/// 但地图上的小浮层**全都是 `Positioned` 包着的**，而 Positioned 的子项拿到的
/// 约束是**容器（整个 Stack）的大小**、不是它自己的尺寸 —— 于是 38px 的按钮被
/// 量成整屏，自动规则恰好在最需要它的地方失效。这种「静默失效」比不做还危险，
/// 所以半径改成**显式**写。
///
/// 配对由 `tool/check_material_coverage.py` 检查：用了小浮层的半透明填色
/// （`chipFill` / [chipTint]）就**不能**把 `blurSigma` 写成 0 —— 半透明又不模糊，
/// 底下的地图会直接透上来把字糊掉（只改一半的典型症状）。

class MaterialSurface extends StatelessWidget {
  /// 被包裹的表面（自身通常带半透明填色与阴影）
  final Widget child;

  /// 裁剪圆角：必须和 child 自己的圆角一致，否则模糊会从圆角外露出来一角
  final double radius;

  /// 只有上方两角是圆角（底部面板用）
  final bool topOnly;

  /// 模糊强度：
  /// * `null`（默认）→ 用材质默认半径 [C.materialBlur]（大面板/条走这条）；
  /// * `C.chipBlur` → 小浮层的模糊（**随档位变**：满血档给大半径，其余档给 12）；
  /// * `0` → **不模糊**。用半透明填色时**不要**这么写（见 `chipTint` 的说明）。
  final double? blurSigma;

  /// 这个表面背后**只有应用底色**（材质壁纸 / 主题背景图），没有内容。
  ///
  /// 1.0 布局的壳就是这种情况：顶栏 / 侧栏 / 底栏 / 各子页的 AppBar —— 它们**不压在
  /// 内容上**（`Scaffold` 的 body 排在它们下面，不在背后），背后只有壁纸。
  ///
  /// 为什么要单开这个字段：材质壁纸是**渐变**（见 theme_store 里那段「为什么不模糊
  /// 壁纸」），模糊一层渐变 ≈ 渐变本身，视觉上零收益，却要每帧多付一次
  /// 「结束 render pass → 采样 → 重开」（见文件顶部说明）。列表一滚动就是每帧一次。
  /// 用户给主题设了**背景图**时不算「只有底色」：照片有细节，该糊还得糊
  /// （判据收在 [C.wallpaperHasDetail]）。
  final bool overWallpaper;

  const MaterialSurface({
    super.key,
    required this.child,
    this.radius = 0,
    this.topOnly = false,
    this.blurSigma,
    this.overWallpaper = false,
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
    // 说明：这里**没有**「动画期关掉模糊」这类开关，见文件顶部关于 blurWhen
    // 为何被删掉的那一段 —— 责任在调用点：要用模糊，就得保证几何稳定。
    final sigma = blurSigma ?? C.materialBlur;
    // 显式 0：调用点明确要实心（小浮层都是这么写的，见文件顶部的说明）
    if (sigma <= 0) return child;
    // 背后只有渐变壁纸：模糊它没有视觉收益，只有每帧一次 pass 收尾/重开
    if (overWallpaper && !C.wallpaperHasDetail) return child;
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
            // `.grouped`（而不是默认构造）：见文件顶部「每层 BackdropFilter 真正贵
            // 在哪」。有 BackdropGroup 祖先时，同一簇浮层只让引擎采一次底；没有祖先
            // 时它退化成和默认构造完全一样（各自一份），所以调用点漏包不会坏。
            child: BackdropFilter.grouped(
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

  /// 见 [MaterialSurface.overWallpaper]。
  ///
  /// AppBar **默认就是**这种表面：`Scaffold` 把 body 排在 AppBar 之下，除非页面写了
  /// `extendBodyBehindAppBar: true` —— 那种页面（目前只有 track_day_page）要传 `false`，
  /// 否则顶栏会变成「半透明但不模糊」，底下的内容直接透上来把字糊掉。
  final bool overWallpaper;

  const MaterialAppBar(this.child, {super.key, this.overWallpaper = true});

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) =>
      MaterialSurface(overWallpaper: overWallpaper, child: child);
}

/// 把一个小控件的底色调成「实心小浮层」的透明度 —— **保留它的色相**。
///
/// 与 [surfaceTint] 的分工（别混用）：
/// * [surfaceTint] 给**会做模糊**的表面（AppBar 这类大面积条）→ 半透明，靠背后的
///   模糊把它和内容分开；
/// * [chipTint] 给**小控件**（38px 工具钮、圆形按钮）→ 半透明 + 轻模糊
///   （`blurSigma: C.chipBlur`）。两者都半透明，区别只在半径：
///   小的默认 12（满血档用大半径）、大的用材质默认。
Color chipTint(Color c) {
  if (!C.materialOn) return c;
  return c.withValues(alpha: c.a * 0.72);
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
