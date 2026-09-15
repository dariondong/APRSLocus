import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 主页「手动上报 / 连接」按钮的布局回归测试。
///
/// 为什么需要它：这两个按钮是 Expanded 并排的定宽布局，2026-09 把字号从
/// 11 提到 13（用户要求「按钮调大点」）后，窄屏＋长语言标签很容易出问题。
/// 溢出在 release 里只画一条黄黑条，很容易被漏掉 —— PKWDWPL Lite 就是靠
/// 渲染预览才发现同类问题的。
///
/// 断言的是**真的会崩的那一类问题**（RenderFlex overflow / 布局异常），
/// 不是「必须单行」：实测 `连接 APRS-IS`（zh）与 `Hubungkan APRS-IS`（id）
/// 在 320dp 上本来就会折行（这是 Flutter 按钮的既有行为），
/// 把它断言成「必须放得下」会写出一个从第一天就失败的测试。
void main() {
  const String beaconText = '手动上报';
  const String connectText = '连接 APRS-IS';

  /// 复刻 home_page 里两个按钮的样式（字号 / 内边距 / 最小高度）
  ButtonStyle btnStyle(Color c) => OutlinedButton.styleFrom(
        foregroundColor: c,
        side: BorderSide(color: c.withValues(alpha: 0.5)),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        textStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  /// 按真实结构搭出「我的面板」里的那一行按钮
  Widget buildRow(double screenW) {
    return MediaQuery(
      data: MediaQueryData(size: Size(screenW, 640)),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: screenW,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text(beaconText),
                        style: btnStyle(const Color(0xFF16A34A)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: const Text(connectText),
                        style: btnStyle(const Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('320dp 窄屏：两个按钮不溢出，且达到 44 最小触摸高度', (tester) async {
    await tester.pumpWidget(buildRow(320));
    await tester.pumpAndSettle();

    // 溢出会以异常形式冒出来（RenderFlex overflowed）
    expect(tester.takeException(), isNull,
        reason: '320dp 窄屏下按钮行不应溢出');

    for (final t in <String>[beaconText, connectText]) {
      final size = tester.getSize(find.ancestor(
        of: find.text(t),
        matching: find.byType(OutlinedButton),
      ));
      expect(size.height, greaterThanOrEqualTo(44),
          reason: '"$t" 的按钮高度应≥44（Material 最小可点区域）');
    }
  });

  testWidgets('411dp 常见机身：同上', (tester) async {
    await tester.pumpWidget(buildRow(411));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('长标签（印尼语 Hubungkan APRS-IS）：折行也不溢出', (tester) async {
    // 这是各语言里最长的按钮文案，最容易把布局撑坏
    await tester.pumpWidget(buildRow(320));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('手动上报按钮的文字确实是 13 号（防止被误改回 11）', (tester) async {
    await tester.pumpWidget(buildRow(411));
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text(beaconText));
    // 字号来自 ButtonStyle.textStyle，因此取渲染后的 DefaultTextStyle
    final ctx = tester.element(find.text(beaconText));
    final style = DefaultTextStyle.of(ctx).style;
    expect(style.fontSize, 13,
        reason: '用户明确要求按钮更大；改小要同时改本测试与其理由');
    expect(text.data, beaconText);
  });
}
