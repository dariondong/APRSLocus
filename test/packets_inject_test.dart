import 'package:aprslocus/l10n/app_localizations.dart';
import 'package:aprslocus/packets_page.dart';
import 'package:aprslocus/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 数据包控制台「手动注入」的反馈回归测试。
///
/// 起因（用户报告）：在 TNC / 音频（射频）下点发送**毫无反应** ——
/// 既没有成功提示，也没有失败提示。查下去是三件事叠在一起：
///   ① `sendPacket` 不返回任何结果，界面无从提示；
///   ② 不管有没有发出去，`packetsTx` 都自增（统计虚高）；
///   ③ 它走的是 `_pushPacket` —— 那条路是**收包**用的，于是「我发的包」
///      被计成了「我收到的包」，还会计入「世界聆听者」成就。
/// 所以这里把「反馈」和「计数」两件事都钉住。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> fresh() async {
    final st = AppState();
    // 构造函数里的 _loadPrefs 是异步的，不等它落地会被它覆盖（见 multi_source 测试）
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return st;
  }

  /// widget 用例里**不能**用 `fresh()`：`testWidgets` 跑在 fake async 时钟下，
  /// `Future.delayed` 永远不会到点（看起来就是「加载中卡死几分钟」）。
  /// 这里改成用 `pump` 推进时钟，效果一样但会真的往前走。
  Future<AppState> freshWidget(WidgetTester tester) async {
    final st = AppState();
    await tester.pump(const Duration(milliseconds: 50));
    return st;
  }

  Future<void> pumpPage(WidgetTester tester, AppState st) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PacketsPage(state: st)),
    ));
    await tester.pump();
  }

  /// 收尾：先卸掉界面 → 释放 AppState → 把时钟推过最后一个延时。
  ///
  /// 不这么做的话，AppState 里那些 `Timer.periodic`（1 秒 tick / 15 秒保活）
  /// 和构造时的 900ms 启动延时都还挂着，测试框架会判「Pending timers」
  /// 并让进程卡住几分钟才退出（伴随 `Cannot close sink while adding stream`）。
  /// `dispose()` 会取消前者；后者靠 `pump(1s)` 让它到点 ——
  /// 回调开头就有 `_disposed` 检查，会直接 return，不会真的去碰定位。
  Future<void> teardownPage(WidgetTester tester, AppState st) async {
    await tester.pumpWidget(const SizedBox.shrink());
    st.dispose();
    await tester.pump(const Duration(seconds: 1));
  }

  group('手动注入：格式校验（发送前就该拦下）', () {
    test('缺 > 或 : 都是 bad-format，且不计入发包数', () async {
      final st = await fresh();
      expect(st.validateTnc2('BG7LZQ-9>APALOC:>hello'), isNull);
      expect(st.validateTnc2('BG7LZQ-9 APALOC>hello'), 'bad-format');
      expect(st.validateTnc2('BG7LZQ-9>APALOC'), 'bad-format');
      expect(st.validateTnc2('>APALOC:>x'), 'bad-format');
      expect(st.validateTnc2('BG7LZQ-9>:>x'), 'bad-format');
      expect(st.validateTnc2('   '), 'bad-format');

      final before = st.packetsTx;
      expect(st.sendPacket('BG7LZQ-9>APALOC'), 'bad-format');
      expect(st.packetsTx, before, reason: '格式不合法不该计入发包统计');
    });

    test('未连接时不发送，但如实返回 not-connected', () async {
      final st = await fresh();
      expect(st.connected, isFalse);
      final rx = st.packetsRx;
      expect(st.sendPacket('BG7LZQ-9>APALOC:>hello'), 'not-connected');
      expect(st.packetsTx, 0);
      // 发出去的包不能走收包路径（否则收包数和「世界聆听者」成就都被污染）
      expect(st.packetsRx, rx);
    });
  });

  group('手动注入：界面反馈', () {
    testWidgets('格式不合法 → 弹出失败提示（而不是毫无反应）', (tester) async {
      final st = await freshWidget(tester);
      await pumpPage(tester, st);

      await tester.enterText(find.byType(TextField).last, 'BG7LZQ-9 APALOC');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump(); // 让 SnackBar 入场

      expect(find.byType(SnackBar), findsOneWidget);
      // 关键：提示里必须说清「报文格式不合法」，用户才知道去改哪里
      expect(find.textContaining('格式'), findsOneWidget);

      await teardownPage(tester, st);
    });

    testWidgets('未连接 → 提示未发送，输入保留下来供修改', (tester) async {
      final st = await freshWidget(tester);
      await pumpPage(tester, st);

      const line = 'BG7LZQ-9>APALOC:>hello';
      await tester.enterText(find.byType(TextField).last, line);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('未发送'), findsOneWidget);
      // 失败时不清空输入：改一个字符就能重发
      expect(find.text(line), findsOneWidget);

      await teardownPage(tester, st);
    });
  });
}
