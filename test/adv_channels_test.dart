/// 「高级连接通道设置」开关的行为回归。
///
/// 用户要求（2026-10-27）：关掉这个开关时，消息保留原来的勾选，位置默认
/// 全部都发。这条规则分成两半，两半都得钉住：
///   * 位置 —— 所有已启用**且已连上**的可发射链路都发，不再逐条打勾；
///   * 消息 —— 完全不受开关影响（dataSourceMsg 不动，仍按它发）。
/// 另外两条容易漏的：没连上的链路不能进默认列表（勾着却发不出去，每次信标
/// 都往日志里写一条 not-connected）；一条都没连上时也不能返回空列表 —— 那会
/// 让发送路径静默什么都不做，比报错难查得多。
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

  /// 两条链路都开着且都连着：APRS-IS + 音频（声卡）。
  Future<AppState> bothUp() async {
    final st = await fresh();
    await st.toggleSource(AppState.srcAudio, true);
    st.debugSetLinkUp(AppState.srcAprsIs, true);
    st.debugSetLinkUp(AppState.srcAudio, true);
    return st;
  }

  test('默认关：位置发往所有已启用且连上的可发射链路', () async {
    final st = await bothUp();
    expect(st.advChannels, isFalse);
    expect(
      st.posTxTargets,
      containsAll(<String>[AppState.srcAprsIs, AppState.srcAudio]),
    );
    expect(st.posTxHas(AppState.srcAprsIs), isTrue);
    expect(st.posTxHas(AppState.srcAudio), isTrue,
        reason: '两条链路都连着，位置就该两条都发');
    expect(st.posTxHas(AppState.srcPkwdwpl), isFalse,
        reason: '只读链路永远不发射');
  });

  test('没连上的链路不进默认列表', () async {
    final st = await bothUp();
    st.debugSetLinkUp(AppState.srcAudio, false);
    expect(st.posTxTargets, <String>[AppState.srcAprsIs]);
    expect(st.posTxHas(AppState.srcAudio), isFalse);
  });

  test('一条都没连上时仍留主链路（发送路径照常报错，不静默）', () async {
    final st = await bothUp();
    st.debugSetLinkUp(AppState.srcAprsIs, false);
    st.debugSetLinkUp(AppState.srcAudio, false);
    expect(st.posTxTargets, <String>[st.dataSource]);
  });

  test('简单模式下启用通道，该通道的位置发射也跟着开', () async {
    final st = await bothUp();
    expect(st.advChannels, isFalse);
    expect(st.posTxHas(AppState.srcAudio), isTrue,
        reason: '启用通道 = 这条通道也发位置');
    // 切到高级：刚启用的通道仍然是勾着的 —— 两种口径不许自相矛盾
    st.setAdvChannels(true);
    expect(st.posTxTargets, <String>[AppState.srcAprsIs, AppState.srcAudio]);
    // 高级模式下逐条取消，没勾的就不发
    st.togglePosTx(AppState.srcAudio);
    expect(st.posTxTargets, <String>[AppState.srcAprsIs]);
  });

  test('关掉通道时，它的位置勾选一起删掉', () async {
    final st = await bothUp();
    st.setAdvChannels(true);
    await st.toggleSource(AppState.srcAudio, false);
    expect(st.posTxHas(AppState.srcAudio), isFalse);
    expect(st.posTxTargets, <String>[AppState.srcAprsIs]);
  });

  test('开关不动消息链路', () async {
    final st = await bothUp();
    st.setTxMsgSource(AppState.srcAudio);
    st.setAdvChannels(true);
    st.setAdvChannels(false);
    expect(st.dataSourceMsg, AppState.srcAudio,
        reason: '消息保留原来的勾选，开关只决定位置要不要逐条挑');
  });

  test('开关落盘：新实例读得回来', () async {
    final a = await bothUp();
    a.setAdvChannels(true);
    await a.persistNow();
    final b = await fresh();
    expect(b.advChannels, isTrue);
  });

  test('出厂复位回到关（位置全发）', () async {
    final st = await bothUp();
    st.setAdvChannels(true);
    await st.factoryReset();
    expect(st.advChannels, isFalse);
  });
}
