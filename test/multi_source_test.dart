import 'package:aprslocus/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 数据来源多选 + 网关开关的状态回归测试。
///
/// 多选改造的关键约定（写错任何一条都会造成静默错乱）：
///   * `enabledSources` = 同时连哪几条（多选）；`dataSource` = **发射**走哪条（单选）；
///   * `connected` 仍然表示「发射来源是否可用」，由 `_linkUp` 推导 ——
///     否则老界面（连接卡片/状态栏/通知）会在多选下显示错乱；
///   * 发射来源必须**始终落在已启用集合内**，否则会出现「选了它却永远连不上」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // **每个用例都要重置**：`persist()` 会写进 mock prefs，而 mock prefs 在
  // 同一个测试文件内是共享的 —— 不重置的话前一个用例保存的 enabledSources
  // 会被后一个用例的 AppState 加载回来，出现「状态自己变了」这种假失败。
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 构造 AppState 并等一等：构造函数里的 `_loadPrefs()` 是**异步**的，
  /// 它会把 enabledSources 按持久化内容重置。不等它落地就改状态，
  /// 会被它异步覆盖掉（测试看起来像「状态改不动」，其实是竞态）。
  Future<AppState> fresh() async {
    final st = AppState();
    // 多等几拍：_loadPrefs 内部有若干次 await，一拍不一定够
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return st;
  }

  group('数据来源多选', () {
    test('默认只启用 APRS-IS，且发射走它', () async {
      final st = await fresh();
      expect(st.enabledSources, {AppState.srcAprsIs});
      expect(st.dataSource, AppState.srcAprsIs);
      expect(st.aprsIsOn, isTrue);
      expect(st.tncOn, isFalse);
      expect(st.audioOn, isFalse);
      expect(st.multiSource, isFalse);
    });

    test('可以同时启用 APRS-IS 与 TNC（网关的典型配置）', () async {
      final st = await fresh();
      await st.toggleSource(AppState.srcTnc, true);
      expect(st.aprsIsOn, isTrue);
      expect(st.tncOn, isTrue);
      expect(st.multiSource, isTrue);
      // 发射来源默认不变，仍是最初那条
      expect(st.dataSource, AppState.srcAprsIs);
    });

    test('不能把最后一条来源关掉（否则应用什么都不收）', () async {
      final st = await fresh();
      await st.toggleSource(AppState.srcAprsIs, false);
      expect(st.enabledSources, {AppState.srcAprsIs},
          reason: '最后一条必须保留，且要有日志说明原因');
    });

    test('关掉发射来源时，发射自动改到还启用的那条', () async {
      final st = await fresh();
      await st.toggleSource(AppState.srcTnc, true);
      st.setTxSource(AppState.srcTnc);
      expect(st.dataSource, AppState.srcTnc);
      await st.toggleSource(AppState.srcTnc, false);
      expect(st.dataSource, AppState.srcAprsIs,
          reason: '发射来源必须始终落在已启用集合内');
      expect(st.enabledSources.contains(st.dataSource), isTrue);
    });

    test('setTxSource 拒绝未启用的来源', () async {
      final st = await fresh();
      st.setTxSource(AppState.srcTnc);
      expect(st.dataSource, AppState.srcAprsIs);
      expect(st.enabledSources.contains(st.dataSource), isTrue);
    });

    test('connected 由「发射来源」的链路状态推导，不受其它来源影响', () async {
      final st = await fresh();
      await st.toggleSource(AppState.srcTnc, true);
      // 手动构造：IS 掉线、TNC 在线，发射走 TNC
      st.debugSetLinkUp(AppState.srcAprsIs, false);
      st.debugSetLinkUp(AppState.srcTnc, true);
      st.setTxSource(AppState.srcTnc);
      expect(st.connected, isTrue, reason: '发射来源在线就是已连接');
      expect(st.anyLinkUp, isTrue);
      // 切回 IS 发射 → 立刻变成未连接（因为 IS 掉线）
      st.setTxSource(AppState.srcAprsIs);
      expect(st.connected, isFalse);
      expect(st.anyLinkUp, isTrue, reason: '仍有链路可用');
    });
  });

  group('网关开关', () {
    test('默认关闭；双向默认也关闭（会真实发射，必须显式同意）', () async {
      final st = await fresh();
      expect(st.igateEnabled, isFalse);
      expect(st.igateTwoWay, isFalse);
    });

    test('关掉网关时同时关掉双向（不留下「还会往射频发」的开关）', () async {
      final st = await fresh();
      st.setIgateEnabled(true);
      st.setIgateTwoWay(true);
      expect(st.igateTwoWay, isTrue);
      st.setIgateEnabled(false);
      expect(st.igateEnabled, isFalse);
      expect(st.igateTwoWay, isFalse);
    });

    test('打开双向会自动把网关也打开（避免「开了双向但没生效」）', () async {
      final st = await fresh();
      st.setIgateTwoWay(true);
      expect(st.igateEnabled, isTrue);
    });

    test('igateReady 只反映「有没有射频来源」', () async {
      final st = await fresh();
      expect(st.igateReady, isFalse);
      expect(st.multiSource, isFalse);
    });
  });
}
