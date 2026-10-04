/// 拦截页「安装标识行」的手势回归测试。
///
/// 这行同时挂了两个互相冲突的手势：**点一下 = 复制**、**长按 = 本机豁免**
/// （软封的隐藏解封入口）。它踩过两次坑，且都不会让编译失败、也没有异常 ——
/// 只能靠测试挡：
///
///   * 标识原本是 `SelectableText`：长按弹**系统选区工具栏**，豁免手势被吃掉
///     （用户看到的正是"长按就变成复制选择工具栏了"）；
///   * 隐藏手势挂在旁边的 `IconButton` 上，而它带了 `tooltip`：`Tooltip` 默认
///     `longPress` 触发，于是长按**又**被拿去显示提示（"长按复制按钮也没用"）。
///
/// 所以这里既驱动真实手势，又硬断言渲染子树里**不得出现** `SelectableText` /
/// `Tooltip` —— 谁把它们加回来，测试就会红。
library;

import 'package:aprslocus/blacklist_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = '0123456789abcdef0123456789abcdef';

  Future<void> pumpRow(
    WidgetTester tester, {
    required VoidCallback onCopy,
    required VoidCallback onLongPress,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: DeviceIdRow(
            deviceId: id,
            onCopy: onCopy,
            onLongPress: onLongPress,
          ),
        ),
      ),
    ));
  }

  testWidgets('长按标识行 → 本机豁免（不是复制、不是选区）', (tester) async {
    var copied = 0, exempted = 0;
    await pumpRow(tester, onCopy: () => copied++, onLongPress: () => exempted++);

    await tester.longPress(find.byType(DeviceIdRow));

    expect(exempted, 1, reason: '长按必须触发隐藏豁免手势');
    expect(copied, 0, reason: '长按不应误触发复制');
  });

  testWidgets('点一下标识行 → 复制（不是豁免）', (tester) async {
    var copied = 0, exempted = 0;
    await pumpRow(tester, onCopy: () => copied++, onLongPress: () => exempted++);

    await tester.tap(find.byType(DeviceIdRow));

    expect(copied, 1, reason: '点按应复制安装标识');
    expect(exempted, 0, reason: '点按不应触发豁免');
  });

  testWidgets('子树内不得有 SelectableText / Tooltip（它们会抢走长按）',
      (tester) async {
    await pumpRow(tester, onCopy: () {}, onLongPress: () {});

    final row = find.byType(DeviceIdRow);
    expect(
      find.descendant(of: row, matching: find.byType(SelectableText)),
      findsNothing,
      reason: 'SelectableText 会把长按变成系统选区工具栏',
    );
    expect(
      find.descendant(of: row, matching: find.byType(Tooltip)),
      findsNothing,
      reason: 'Tooltip 默认 longPress 触发，会抢走豁免手势',
    );
  });
}
