import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 源码级回归护栏：TNC 链路断开后**必须**安排重连。
///
/// 为什么用源码断言而不是行为测试：`AppState.tnc` 是 `final TncLink tnc = TncLink();`
/// —— 没有注入口，无法在测试里塞一个假 transport 去触发 `onClosed`。而这个 bug
/// 的代价很值得护栏：
///
///   原代码在 `_wireTnc()` 的 `tnc.onClosed` 里写了
///       `if (!usingTnc && !multiSource) return;`
///   本意只是「非发射来源断了不必改横幅」，但那个 `return` 把后面的
///   `_scheduleReconnect()` 一起跳过了。**默认配置正好命中这个条件**
///   （只启用 APRS-IS、dataSource=aprsis），于是 TNC 链路一旦断开就
///   **静默地永不重连** —— 不写日志、不改状态，用户只看到「收不到报文了」。
///
/// 顺带一个同类隐患：Kotlin 侧 reader 线程死亡后如果没有清掉 socket 引用，
/// `send()` 仍会通过校验并把字节入队给一个已退出的写线程 —— 界面显示发送成功、
/// 实际一个字节都没出去。两者合起来正是「能发不能收」。Kotlin 侧已用
/// `teardown()` 修掉（无法在此测试，见 commit message）。
void main() {
  test('TNC onClosed 不得在安排重连之前 return（会静默失去重连）', () {
    final src = File('lib/state.dart').readAsStringSync();

    // 取出 _wireTnc 的整段实现
    final start = src.indexOf('void _wireTnc()');
    expect(start, greaterThan(0), reason: '找不不到 _wireTnc —— 结构变了，本护栏需要更新');
    // 到下一个顶层方法定义为止（缩进 2 空格 + void/匹配）
    final rest = src.substring(start);
    final endMatch = RegExp(r'\n  (?:void|Future|bool|String|int) ').firstMatch(rest.substring(1));
    final body = endMatch == null ? rest : rest.substring(0, endMatch.start + 1);

    expect(body.contains('onClosed'), isTrue, reason: '_wireTnc 应当设置 onClosed');
    expect(
      body.contains('_scheduleReconnect'),
      isTrue,
      reason: 'TNC 断开后必须安排重连 —— 否则链路断了就永不恢复',
    );
    // 只看**代码行**，不看注释 —— 注释里会引用这句旧写法做说明。
    final codeLines = body
        .split('\n')
        .map((l) => l.trim())
        .where((l) => !l.startsWith('//'))
        .toList();
    expect(
      codeLines.any((l) => l.contains('usingTnc && !multiSource') && l.contains('return')),
      isFalse,
      reason: '这句 `return` 会连带跳过 _scheduleReconnect()，'
          '而默认配置（只启用 APRS-IS）正好命中 → TNC 静默永不重连',
    );
  });

  test('射频链路在退出/销毁时必须被释放（不能只断 APRS-IS）', () {
    final src = File('lib/state.dart').readAsStringSync();
    // shutdownForExit 与 dispose 都应断开三条射频链路
    final shutdown = src.indexOf('Future<void> shutdownForExit()');
    final dispose = src.indexOf('void dispose()', shutdown);
    expect(shutdown, greaterThan(0));
    expect(dispose, greaterThan(shutdown));

    for (final name in ['shutdownForExit', 'dispose']) {
      final from = name == 'shutdownForExit' ? shutdown : dispose;
      final seg = src.substring(from, from + 1600);
      for (final link in ['tnc', 'audio', 'pkwdwpl']) {
        expect(
          seg.contains('$link.disconnect(manual: false)'),
          isTrue,
          reason: '$name 里应当释放 $link —— 蓝牙 socket / 串口句柄不释放会占住电台，'
              '下次打开可能连不上',
        );
      }
    }
  });
}
