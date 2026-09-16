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

  test('APRS-IS 已连接时不得被重建（否则累积孤儿 socket → 越用越卡）', () {
    final io = File('lib/net/aprs_io.dart').readAsStringSync();
    final state = File('lib/state.dart').readAsStringSync();

    // ① 源头：connect() 必须先收掉上一次的连接。
    //    `_sock = sock` / `_sub = sock.listen(...)` 会直接覆盖旧引用；
    //    若不先收掉，旧 socket 成为孤儿 —— 引用没了，谁也关不掉它，
    //    而它仍会继续把数据喂给 onLine，于是同一报文被重复处理 N 次，
    //    N 随重复连接次数增长。
    final ci = io.indexOf('Future<bool> connect() async {');
    expect(ci, greaterThan(0));
    final connBody = io.substring(ci, ci + 900);
    expect(
      connBody.contains('_silentTeardown()'),
      isTrue,
      reason: 'connect() 必须先静默收掉旧连接，否则每次重复连接都会漏一个孤儿 socket',
    );
    // 覆盖旧引用之前不能先赋值。
    // 注意带分号：注释里会引用 `_sock = sock` 这行做说明，不带分号会误匹配注释。
    final teardownAt = connBody.indexOf('_silentTeardown()');
    final assignAt = connBody.indexOf('_sock = sock;');
    expect(teardownAt, lessThan(assignAt),
        reason: '_silentTeardown() 必须在 `_sock = sock` 之前调用');

    // ② 闸门一：已连上就不再重建 APRS-IS
    final ai = state.indexOf('Future<void> _connectAprsIs() async {');
    expect(ai, greaterThan(0));
    final aiBody = state.substring(ai, ai + 700);
    expect(
      aiBody.contains('if (isUp(srcAprsIs)) return;'),
      isTrue,
      reason: '_connectAprsIs 必须先判断「已经连着」，否则重连 tick 会反复重建 TCP 连接',
    );

    // ③ 闸门二：_connect() 只连没连着的链路
    final ci2 = state.indexOf('Future<void> _connect() async {');
    expect(ci2, greaterThan(0));
    final connectBody = state.substring(ci2, ci2 + 1200);
    for (final probe in [
      'aprsIsOn && !isUp(srcAprsIs)',
      'tncOn && !isUp(srcTnc)',
      'audioOn && !isUp(srcAudio)',
      'pkwdwplOn && !isUp(srcPkwdwpl)',
    ]) {
      expect(connectBody.contains(probe), isTrue,
          reason: '_connect() 必须用「未连上」条件包住每条链路（缺：$probe）');
    }

    // ④ 闸门三：重试也没用的链路不该让定时器空转
    expect(state.contains('bool _permanentlyDown(String src)'), isTrue,
        reason: '需要 _permanentlyDown 识别「永久失败」的链路（未绑定设备等）');
    expect(state.contains('|| _permanentlyDown(s));'), isTrue,
        reason: '_allExpectedLinksUp 必须把永久失败的链路也算作「不用再重试」');
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
