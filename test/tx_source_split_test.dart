/// 「发射来源」分成两条的回归测试：位置/状态报文一条，消息一条。
///
/// 用户的原话：「快捷面板的发射是啥意思，不应该区分消息和位置状态报文吗？」
/// 常见用法是位置走射频、消息走网络，所以两类各选一条，互不影响；两条选
/// 同一条也允许。这里钉住的都是**编译能过、界面看着正常**的错：
///   * 选消息那条不该顺手把位置那条也改掉（反过来同理）；
///   * 只读链路（PKWDWPL）不能被选成任何一条；
///   * 关掉某条链路时，指着它的那两条来源要各自换走；
///   * 旧版本只存过 dataSource 一个键，升级后消息那条要跟着它，而不是回落
///     到一个用户没选过的链路。
library;

import 'package:aprslocus/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 构造函数里的 `_loadPrefs` 是异步的：不等它落地，会被它覆盖。
  Future<AppState> fresh() async {
    final st = AppState();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return st;
  }

  test('默认两条都是 APRS-IS：只有一个来源时没有第二个选项', () async {
    final st = await fresh();
    expect(st.dataSource, AppState.srcAprsIs);
    expect(st.dataSourceMsg, AppState.srcAprsIs);
  });

  test('选消息那条不影响位置那条，反过来也一样', () async {
    final st = await fresh();
    await st.toggleSource(AppState.srcTnc, true);

    st.setTxMsgSource(AppState.srcTnc);
    expect(st.dataSourceMsg, AppState.srcTnc);
    expect(st.dataSource, AppState.srcAprsIs, reason: '位置/状态那条不该被带走');

    st.setTxSource(AppState.srcTnc);
    expect(st.dataSource, AppState.srcTnc);
    st.setTxMsgSource(AppState.srcAprsIs);
    expect(st.dataSource, AppState.srcTnc, reason: '改消息不该改位置');
    expect(st.dataSourceMsg, AppState.srcAprsIs);
  });

  test('两条可以落在同一条链路上', () async {
    final st = await fresh();
    await st.toggleSource(AppState.srcTnc, true);
    st.setTxSource(AppState.srcTnc);
    st.setTxMsgSource(AppState.srcTnc);
    expect(st.dataSource, AppState.srcTnc);
    expect(st.dataSourceMsg, AppState.srcTnc);
  });

  test('只读链路哪一条都不能当发射来源', () async {
    final st = await fresh();
    await st.toggleSource(AppState.srcPkwdwpl, true);
    st.setTxMsgSource(AppState.srcPkwdwpl);
    st.setTxSource(AppState.srcPkwdwpl);
    expect(st.dataSourceMsg, AppState.srcAprsIs);
    expect(st.dataSource, AppState.srcAprsIs);
  });

  test('关掉一条链路时，指着它的两条来源各自换走', () async {
    final st = await fresh();
    await st.toggleSource(AppState.srcTnc, true);
    st.setTxSource(AppState.srcTnc);
    st.setTxMsgSource(AppState.srcTnc);
    await st.toggleSource(AppState.srcTnc, false);
    expect(st.dataSource, AppState.srcAprsIs);
    expect(st.dataSourceMsg, AppState.srcAprsIs);
  });

  test('没启用的链路不能被选', () async {
    final st = await fresh();
    st.setTxMsgSource(AppState.srcAcn);
    expect(st.dataSourceMsg, AppState.srcAprsIs);
  });

  test('落盘：两个键各存各的，冷启动都读得回来', () async {
    final a = await fresh();
    await a.toggleSource(AppState.srcTnc, true);
    a.setTxSource(AppState.srcAprsIs);
    a.setTxMsgSource(AppState.srcTnc);
    await a.persistNow();

    final b = await fresh();
    expect(b.dataSource, AppState.srcAprsIs);
    expect(b.dataSourceMsg, AppState.srcTnc, reason: '消息那条该记得');
  });

  test('位置/状态报文可以同时发好几条：取消主链路时另一条顶上来', () async {
    final st = await fresh();
    await st.toggleSource(AppState.srcTnc, true);
    // 「同时发好几条」现在是**高级模式**的事：默认（开关关着）位置一律发给
    // 所有已连上的链路，没有「勾哪几条」这回事。而启用通道时就把它记进了
    // 那份勾选（见 AppState._notePosTxLink），所以切到高级模式它已经是勾着的。
    st.setAdvChannels(true);

    expect(st.posTxHas(AppState.srcTnc), isTrue,
        reason: '启用通道 = 这条通道也发位置，切到高级模式不该又变成没勾');
    expect(st.posTxTargets,
        [AppState.srcAprsIs, AppState.srcTnc],
        reason: '两条都要发');

    // 取消最后一条没有意义，不该把发射链路清空
    st.togglePosTx(AppState.srcAprsIs);
    expect(st.posTxTargets, [AppState.srcTnc]);
    st.togglePosTx(AppState.srcTnc);
    expect(st.posTxTargets, [AppState.srcTnc], reason: '不能一条都不剩');
  });

  test('同时发的那几条也落盘', () async {
    final a = await fresh();
    await a.toggleSource(AppState.srcTnc, true);
    a.setAdvChannels(true);
    await a.persistNow();

    final b = await fresh();
    expect(b.advChannels, isTrue, reason: '高级开关本身也要记得');
    expect(b.posTxHas(AppState.srcTnc), isTrue);
  });

  test('旧配置只有 dataSource：消息那条跟着它走', () async {
    SharedPreferences.setMockInitialValues({
      'dataSource': AppState.srcTnc,
      'enabledSources': <String>[AppState.srcAprsIs, AppState.srcTnc],
    });
    final st = await fresh();
    expect(st.dataSource, AppState.srcTnc);
    expect(st.dataSourceMsg, AppState.srcTnc,
        reason: '升级用户不该被悄悄改成「消息走 APRS-IS」');
  });
}
