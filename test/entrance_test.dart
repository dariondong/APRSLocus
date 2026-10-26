import 'package:aprslocus/entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 设置页「卡片逐条淡入上移」的回归测试（用户：设置页引入线性动画 → 选「二」）。
///
/// 这里守的是**两条不会编译失败、只会肉眼看不见**的坑：
///   ① 外壳忘了把「当前页签是不是本页」传下来时，页面不能一直是空白
///      （`play` 初值必须落在动画终点，而不是起点）；
///   ② 页签切到设置页时要重新起跑（`IndexedStack` 常驻子页，只在开机播一次
///      等于没有动画）。
void main() {
  Widget host({required bool play, List<Widget>? children}) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StaggerColumn(
              play: play,
              children: children ??
                  [
                    // 注意：SizedBox 会被 StaggerColumn 当成空隙跳过，所以这里
                    // 用 Container 当卡片，才能真的生成 Rising 条目
                    for (var i = 0; i < 3; i++)
                      Container(height: 40, child: Text('row$i')),
                  ],
            ),
          ),
        ),
      );

  int animating(WidgetTester tester) => tester
      .widgetList(find.descendant(
        of: find.byType(StaggerColumn),
        matching: find.byType(AnimatedBuilder),
      ))
      .length;

  testWidgets('play 打开时逐条进场，播完卸掉动画层', (tester) async {
    await tester.pumpWidget(host(play: true));
    expect(animating(tester), 3, reason: '三条卡片应各有一层进场动画');
    // 首帧透明度还没到 1
    final ops = tester
        .widgetList<Opacity>(find.descendant(
          of: find.byType(StaggerColumn),
          matching: find.byType(Opacity),
        ))
        .toList();
    expect(ops.any((o) => o.opacity < 1), isTrue);

    // 全部播完（阶梯最多 8 档 + 240 毫秒，给足 1 秒）
    await tester.pump(const Duration(milliseconds: 1000));
    expect(animating(tester), 0, reason: '播完要卸掉 Opacity + Transform，别每帧多合成一层');
    expect(find.text('row0'), findsOneWidget);
  });

  testWidgets('play 关闭时内容直接可见（外壳漏传也不能白屏）', (tester) async {
    await tester.pumpWidget(host(play: false));
    expect(animating(tester), 0);
    expect(find.text('row0'), findsOneWidget);
    for (final o in tester.widgetList<Opacity>(find.descendant(
      of: find.byType(StaggerColumn),
      matching: find.byType(Opacity),
    ))) {
      expect(o.opacity, 1, reason: '没播动画就不该压透明度');
    }
  });

  testWidgets('页签切到本页时重新起跑', (tester) async {
    await tester.pumpWidget(host(play: false));
    expect(animating(tester), 0);

    // 用户点开设置页
    await tester.pumpWidget(host(play: true));
    expect(animating(tester), 3, reason: '常驻子页的动画要跟着页签重新起跑');

    await tester.pump(const Duration(milliseconds: 1000));
    expect(animating(tester), 0);
  });
}
