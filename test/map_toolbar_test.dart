/// 右侧工具列分列算式的回归测试。
///
/// 用户报过两次同类问题：「地图控件排序被重排」和「浮层工具挡在一起了」。
/// 两次都编译能过、analyze 全绿，只在真机上看得见，所以把算式抽成
/// `lib/map_toolbar.dart` 的纯函数，在这里钉住它的几条不变量：
///
///   * 列数从尺寸算得出来，封顶三列；
///   * 同一块屏幕、同一组 inset，列数永远同一个答案（不随上报横杠出现而变）；
///   * 工具列最后一颗按钮永远在贴底控件上面，真的装不下时让它让位；
///   * 让位之后地图那几层的裁剪下边距必须归零，否则画上去的线会露在屏幕底。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/map_toolbar.dart';

void main() {
  group('颗数、尺寸与分列', () {
    test('十一颗按钮：一列 478、两列 258、三列 170', () {
      expect(MapToolbar.count, 11);
      expect(MapToolbar.perColumn(1), 11);
      expect(MapToolbar.perColumn(2), 6);
      expect(MapToolbar.perColumn(3), 4);
      expect(MapToolbar.height(1), 11 * 38 + 10 * 6);
      expect(MapToolbar.height(2), 6 * 38 + 5 * 6);
      expect(MapToolbar.height(3), 4 * 38 + 3 * 6);
    });

    test('宽度：列宽 + 列间距', () {
      expect(MapToolbar.width(1), 38);
      expect(MapToolbar.width(3), 3 * 38 + 2 * 6);
    });

    test('装不下就加列，到三列封顶', () {
      expect(MapToolbar.columns(1000), 1);
      expect(MapToolbar.columns(478), 1);
      expect(MapToolbar.columns(477), 2);
      expect(MapToolbar.columns(258), 2);
      expect(MapToolbar.columns(170), 3);
      expect(MapToolbar.columns(10), 3);
    });
  });

  group('这一帧的几何', () {
    MapToolbarLayout at(
      double height, {
      double top = 0,
      double bottom = 0,
      double pad = 0,
      bool beacon = true,
    }) =>
        MapToolbar.layout(
          height: height,
          topInset: top,
          bottomInset: bottom,
          padBottom: pad,
          beaconOn: beacon,
        );

    test('常见竖屏（720、无刘海、无导航栏）：一列，贴底横杠摆得下', () {
      final l = at(720);
      expect(l.cols, 1);
      expect(l.topBase, 14);
      expect(l.room, 720 - (14 + 90) - (14 + 38 + 62));
      expect(l.bottom, 14 + MapToolbar.height(1));
      expect(l.barsTop, 720 - (62 + 38));
      expect(l.barsBlock, 62 + 38);
      expect(l.roomForBottom, isTrue);
      expect(l.clipBottom, 100);
      expect(l.rightGutter, 14 + 38 + 12);
    });

    test('导航栏高度整个算进贴底那一块', () {
      final l = at(720, pad: 24);
      expect(l.barsBlock, 100 + 24);
      expect(l.barsTop, 720 - 124);
      expect(l.clipBottom, 124);
    });

    test('矮横屏：分三列，仍摆得下贴底控件', () {
      final l = at(400);
      expect(l.cols, 3);
      expect(l.bottom, 14 + MapToolbar.height(3));
      expect(l.roomForBottom, isTrue);
    });

    test('再矮就把贴底控件让掉，裁剪下边距归零', () {
      final l = at(250);
      expect(l.cols, 3);
      expect(l.roomForBottom, isFalse);
      expect(l.clipBottom, 0);
    });

    test('贴底换成坐标条只是位置更高，列数不变', () {
      final bar = at(720);
      final coord = at(720, beacon: false);
      expect(coord.cols, bar.cols);
      expect(coord.barsBlock, 14 + 30);
      expect(bar.barsBlock, 62 + 38);
      expect(coord.barsTop, greaterThan(bar.barsTop));
      expect(coord.roomForBottom, isTrue);
    });

    test('上报是否开着（横杠 / 坐标条）不改列数', () {
      expect(at(720, beacon: false).cols, at(720, beacon: true).cols);
      expect(at(400, beacon: false).cols, at(400, beacon: true).cols);
    });

    test('topInset 变大只会加列，不会减列', () {
      var last = 0;
      for (final inset in [0.0, 20.0, 44.0, 80.0, 120.0, 200.0]) {
        final c = at(720, top: inset).cols;
        expect(c, greaterThanOrEqualTo(last));
        last = c;
      }
      expect(last, greaterThanOrEqualTo(1));
    });

    test('clipBottom 永远等于「摆得下就整块高度、摆不下就是 0」', () {
      for (final h in [200.0, 250.0, 300.0, 400.0, 600.0, 720.0, 1000.0]) {
        for (final beacon in [true, false]) {
          final l = at(h, beacon: beacon);
          expect(l.clipBottom, l.roomForBottom ? l.barsBlock : 0);
        }
      }
    });
  });
}
