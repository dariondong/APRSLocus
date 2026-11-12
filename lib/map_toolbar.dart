import 'dart:math' as math;

/// 右侧工具列的尺寸与分列算式（纯逻辑，无 Widget）。
///
/// ── 为什么单独一份 ──
/// 「分几列」这个答案以前是 `map_page.build` 里一长段算出来的，而且**同一个量
/// 算了两遍**：工具列自己算一次，贴底浮层的裁剪线又照抄了一遍
/// （`62 + padBottom + … + _kBeaconBarH`）。抄的那份一旦漏改，表现是「裁剪线
/// 落在横杠里面」，只有看屏幕的人才能发现。现在算式只在这里，`map_page`
/// 只负责把当帧的几个实数递进来，测试盯着几条不变量
/// （`test/map_toolbar_test.dart`）。
///
/// ── 两件事必须分开 ──
/// **列数**只跟窗口尺寸与固定预留有关：同一块屏幕、同一个方向，永远是同一个
/// 答案，横幅出现、开始上报、外壳内容面板开合都不改它（那几项以前是「控件
/// 排序被重排」的根因）。**贴底控件摆不摆**只看当帧的真实几何：它管的是
/// 「会不会真压住」，所以必须用当前的真值。
library;

/// 这一帧地图浮层的几何。字段全是算好的结果，调用方不该再自己乘一遍。
class MapToolbarLayout {
  /// 分几列。
  final int cols;

  /// 算列数用的可用高度（窗口高 − 顶部预留 − 底部预留）。
  final double room;

  /// 顶部浮层的锚点（14 + 外壳顶栏 inset）。
  final double topBase;

  /// 工具列最后一颗按钮的下沿（相对地图框顶部）。
  final double bottom;

  /// 贴底控件（坐标条 / 上报横杠）的上沿。
  final double barsTop;

  /// 贴底那一整块的总高（控件自身 + 系统导航栏 + 外壳底 inset）。
  final double barsBlock;

  /// 左侧浮层要让开的右边界距离。
  final double rightGutter;

  const MapToolbarLayout({
    required this.cols,
    required this.room,
    required this.topBase,
    required this.bottom,
    required this.barsTop,
    required this.barsBlock,
    required this.rightGutter,
  });

  /// 贴底控件还摆不摆得下：工具列下沿再留 8 像素，必须还在它们上面。
  bool get roomForBottom => bottom + 8 <= barsTop;

  /// 地图**画出来的**那几层要裁掉的下边距。贴底控件不摆时不裁。
  double get clipBottom => roomForBottom ? barsBlock : 0;
}

class MapToolbar {
  MapToolbar._();

  /// 一颗按钮的尺寸与相邻两颗的间距。列高由它们算出来，不写死。
  static const double btn = 38;
  static const double gap = 6;

  /// 两组按钮的颗数：5 颗工具（图层 / 轨迹组 / 策略 / 底图 / 中心经纬度）
  /// + 6 颗缩放（放大 / 缩小 / 轨迹 / 热力图 / 定位 / 锁定中心）。
  static const int toolCount = 5;
  static const int zoomCount = 6;
  static int get count => toolCount + zoomCount;

  /// 最多分几列。再多会把工具列拉成一排横贯地图的按钮（十一颗三列已经
  /// 126 宽，十一列就是 478 宽），比「贴底控件让位」难看多了。
  static const int maxCols = 3;

  /// 判分栏时的上下固定预留（顶部：顶栏 + 最多一排横幅；底部：导航 + 贴底控件）。
  ///
  /// 用常量而不是当帧的 `topInset` / `bottomInset`：那两项一时一变（横幅出现
  /// 与收起、开始上报、内容面板开合），扣它们会让列数在同一块屏幕上跳，整排
  /// 按钮跟着重排。数值取那几件东西的尺寸上限 —— 宁可多分一列，也不让最下面
  /// 那颗按钮被裁掉。
  static const double topReserve = 100;
  static const double bottomReserve = 70;

  /// 顶部两道横幅同时挂着时，锚点还会往下多走多少。取上限而不是当帧值：
  /// 横幅出现只是把工具列整个推下去，列数不变、排序不变。
  static const double bannerSlack = 90;

  /// 顶部浮层起点（外壳顶栏之下）。
  static const double topBasePad = 14;

  /// 上报横杠：自身高度、底边到屏幕底的距离。
  static const double beaconBarH = 38;
  static const double beaconRise = 62;

  /// 底部坐标条：同上。
  static const double coordBarH = 30;
  static const double coordRise = 14;

  /// 分 [cols] 列时每列几颗（向上取整）。
  static int perColumn(int cols) {
    final c = cols < 1 ? 1 : cols;
    return (count + c - 1) ~/ c;
  }

  /// 分 [cols] 列时一列的高度（n 颗钮 + n−1 道间距）。
  static double height(int cols) {
    final per = perColumn(cols);
    return per * btn + (per - 1) * gap;
  }

  /// 分 [cols] 列时整块的宽度（列宽 + 列间距）。
  static double width(int cols) => cols * btn + (cols - 1) * gap;

  /// 装进 [room] 高最少要分几列；到 [maxCols] 封顶。
  static int columns(double room) {
    for (var c = 1; c < maxCols; c++) {
      if (height(c) <= room) return c;
    }
    return maxCols;
  }

  /// 算这一帧的几何。
  ///
  /// [beaconOn] 为真表示贴底的是上报横杠（更矮但离底更远），否则是底部坐标条。
  static MapToolbarLayout layout({
    required double height,
    required double topInset,
    required double bottomInset,
    required double padBottom,
    required bool beaconOn,
  }) {
    final topBase = topBasePad + topInset;
    // 顶部预留取「两道横幅都挂着时的锚点」：这台设备上的常数。
    final top = math.max(topReserve, topBase + bannerSlack);
    // 底部预留按**上报横杠**算（比坐标条更占），也与原来逐字一致：
    // 14（坐标条离底）+ 38（横杠高）+ 62（横杠离底）。两者不会同时出现，
    // 这里取的是那个上限，改它就会在真机上换掉某一档列数。
    final bottom = math.max(
      bottomReserve,
      coordRise + beaconBarH + beaconRise + padBottom + bottomInset,
    );
    final room = height - top - bottom;
    final cols = columns(room);
    final barsOwn = beaconOn ? beaconRise + beaconBarH : coordRise + coordBarH;
    return MapToolbarLayout(
      cols: cols,
      room: room,
      topBase: topBase,
      bottom: topBase + height(cols),
      barsTop: height - (barsOwn + padBottom + bottomInset),
      barsBlock: barsOwn + padBottom + bottomInset,
      // 左侧那一列浮层要让开工具列（以前写死 74，只够一列）。
      rightGutter: MapToolbar.topBasePad + width(cols) + 12,
    );
  }
}
