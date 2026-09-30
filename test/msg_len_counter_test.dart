import 'package:aprslocus/l10n/app_localizations.dart';
import 'package:aprslocus/msg_len_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 聊天输入栏「长度 / 整包字节」计数器的**实时性**回归。
///
/// 用户实测上报：这个数字**不跟着打字变**，要等输入框失去焦点才更新。
/// 根因是计数器只在页面 build 时读一次 `controller.text`，而打字只会重建
/// TextField 自己，不会重建它旁边的计数器。
///
/// 所以这里的断言方式是**故意不碰焦点**：打完字立刻看数字变没变。
/// 老写法（页面里直接读 `_input.text`）下这些断言必然失败。
void main() {
  Widget host(
    TextEditingController c, {
    String? preview,
    String? previewSrc,
  }) =>
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(children: [
            TextField(controller: c),
            // 与消息页同构：输入框与计数器**共用同一个控制器**，但计数器是
            // 输入框的兄弟节点（页面不重建时它是不会自己刷新的）。
            MsgLenCounter(
              controller: c,
              from: 'BG7LZQ-9',
              path: 'APRS,TCPIR*',
              to: 'JA1XYZ',
              preview: preview,
              previewSrc: previewSrc,
            ),
          ]),
        ),
      );

  testWidgets('打字时计数器实时更新（不需要失焦）', (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(host(c));

    // 空输入：0 字符
    expect(find.textContaining('0/67'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hello world');
    await tester.pump();

    // 关键：全程没有让输入框失焦
    expect(tester.testTextInput.hasAnyClients, isTrue,
        reason: '前提不成立：这里根本没在编辑状态，测试就测不到「失焦才更新」');
    expect(find.textContaining('11/67'), findsOneWidget,
        reason: '打字后计数器没有实时更新（用户报的「要失去焦点才更新」）');

    // 继续打字，仍然实时
    await tester.enterText(find.byType(TextField), 'hello world!!');
    await tester.pump();
    expect(find.textContaining('13/67'), findsOneWidget);
  });

  testWidgets('超长时状态与配色跟着变（67 字符 / 512 字节两档）', (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(host(c));

    // 68 个 ASCII 字符：超过 APRS101 的 67 字符上限
    await tester.enterText(find.byType(TextField), 'a' * 68);
    await tester.pump();
    expect(find.textContaining('68/67'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

    // 足够长：整包（含报头）超过 APRS-IS 的 512 字节
    await tester.enterText(find.byType(TextField), 'a' * 600);
    await tester.pump();
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
  });

  testWidgets('译发预览：按译文算；原文一改就回落到原文', (tester) async {
    final c = TextEditingController(text: '你好');
    await tester.pumpWidget(host(c,
        preview: 'Hello world!', previewSrc: '你好'));

    // 展示的是译文的长度（12 字符），不是原文的 2
    expect(find.textContaining('12/67'), findsOneWidget);

    // 改了原文：旧译文失效，计数器按新的原文算（避免「按旧译文算」）
    await tester.enterText(find.byType(TextField), '你好呀');
    await tester.pump();
    expect(find.textContaining('3/67'), findsOneWidget);
  });
}
