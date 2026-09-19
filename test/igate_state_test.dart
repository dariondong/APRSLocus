import 'package:aprslocus/kiss.dart';
import 'package:aprslocus/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─── 网关（iGate）统计的自证性回归测试 ───
///
/// 用户报「网关传递统计一直是 0」。逐层查下来，计数逻辑本身是好的
/// （纯函数有 test/igate_test.dart，状态层这里再钉一遍），真正的问题是
/// **四个 0 分不清是哪种情况**：
///
///   ① 射频根本没收到报文（TNC 没连上 / 线速不对）  → 链路问题
///   ② 收到了，但 APRS-IS 没连上（没有可转递的目标）→ 网络问题
///   ③ 收到了，但全被环路防护拒收（报文来自互联网）  → 在正确工作
///   ④ 收到了、也转了，只是还没刷新                  → 不存在，代码里必然自增
///
/// 因此本文件锁定的是「界面能不能把 0 解释清楚」：射频收到数、
/// 环路拒收数、以及 [AppState.igateIdleReason] 的判定。
///
/// 另外两条**由统计自己造成 0**的坑也在下面钉住 —— 它们比缺字段更隐蔽，
/// 因为界面上的表现和「一切正常但没流量」一模一样：
///   * 开关一开一关就把统计清零（用户看到 0 的第一反应正是关掉再打开）；
///   * 射频链路已经断了还在计「射频收到」（那个数会去证明「射频没问题」）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 起一个干净的 AppState（构造里会异步载入配置，等一拍再动它）
  Future<AppState> fresh() async {
    final st = AppState();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return st;
  }

  /// 纯接收方向的射频报文（不含本机呼号，必定该被转递）
  const rfLine = 'BG7LZQ-9>APALOC,WIDE1-1*,WIDE2-1*:!2230.00N/11400.00E>test';

  /// 已经进过 APRS-IS 的报文（带 q 构造）→ 必被环路防护拒收
  const qLine = 'BH7NOR-9>APDW16,WIDE1-1,qAR,BH7NOR-10:!2230.00N/11400.00E>';

  /// 三条链路都勾上（TNC + 音频 + APRS-IS），射频走 TNC
  Future<AppState> armed() async {
    final st = await fresh();
    await st.toggleSource(AppState.srcTnc, true);
    st.adoptDeviceLink(AppState.srcTnc, true);
    st.adoptDeviceLink(AppState.srcAprsIs, true);
    st.setIgateEnabled(true);
    return st;
  }

  group('网关统计：射频收到数（判断「到底是没流量还是没转递」）', () {
    test('网关没开时也计射频收到数 —— 这正是它的用处', () async {
      final st = await fresh();
      await st.toggleSource(AppState.srcTnc, true);
      st.adoptDeviceLink(AppState.srcTnc, true);
      st.adoptDeviceLink(AppState.srcAprsIs, true);
      expect(st.igateEnabled, isFalse);

      st.tnc.onLine!(rfLine);
      expect(st.igateRfSeen, 1, reason: '射频流量与网关开关无关，必须能单独看出');
      expect(st.igateGated, 0);
      st.dispose();
    });

    test('射频链路断了就不记 —— 0 必须是真的 0（否则它会去证明「射频没问题」）',
        () async {
      final st = await fresh();
      await st.toggleSource(AppState.srcTnc, true);
      st.adoptDeviceLink(AppState.srcTnc, true);
      st.adoptDeviceLink(AppState.srcAprsIs, true);
      st.setIgateEnabled(true);

      // 射频链路掉线：此后管线里再有射频行，只能是别的链路灌进来的
      st.adoptDeviceLink(AppState.srcTnc, false);
      expect(st.igateRfUp, isFalse);
      st.tnc.onLine!(rfLine);
      st.tnc.onLine!(qLine);
      expect(st.igateRfSeen, 0, reason: '链路断了就没有「射频收到」这回事');
      expect(st.igateBlocked, 0, reason: '顺带：断链期间的拒收也不该记账');
      expect(st.igateIdleReason, 'rf-down');

      // 连回来立刻照常计
      st.adoptDeviceLink(AppState.srcTnc, true);
      st.tnc.onLine!(rfLine);
      expect(st.igateRfSeen, 1);
      expect(st.igateGated, 1);
      st.dispose();
    });
  });

  group('网关统计：为什么是 0（igateIdleReason）', () {
    test('没勾射频来源 → no-rf-source', () async {
      final st = await fresh();
      st.setIgateEnabled(true);
      expect(st.igateIdleReason, 'no-rf-source');
      st.dispose();
    });

    test('勾了射频但链路没连上 → rf-down（不是「没勾」，得分开说）', () async {
      final st = await fresh();
      await st.toggleSource(AppState.srcTnc, true);
      st.adoptDeviceLink(AppState.srcAprsIs, true);
      st.setIgateEnabled(true);
      // TNC 只是被勾选，从未连上（测试环境里没有设备）
      expect(st.isUp(AppState.srcTnc), isFalse);
      expect(st.igateReady, isTrue, reason: '配置层面确实勾了');
      expect(st.igateRfUp, isFalse);
      expect(st.igateIdleReason, 'rf-down');
      st.dispose();
    });

    test('射频在收但 APRS-IS 没连上 → is-down，且数字保持 0（有据可查）', () async {
      final st = await fresh();
      await st.toggleSource(AppState.srcTnc, true);
      st.adoptDeviceLink(AppState.srcTnc, true);
      st.setIgateEnabled(true);
      expect(st.igateIdleReason, 'is-down');

      st.tnc.onLine!(rfLine);
      st.tnc.onLine!(rfLine.replaceAll('BG7LZQ-9', 'BH7NOR-9'));
      expect(st.igateRfSeen, 2, reason: '射频确实收到了');
      expect(st.igateGated, 0, reason: 'IS 没连上，一条都不该转');
      expect(st.igateIdleReason, 'is-down');

      // IS 连上后，同一条链路立刻开始转递（不需要重新开关网关）
      st.adoptDeviceLink(AppState.srcAprsIs, true);
      expect(st.igateIdleReason, '');
      st.tnc.onLine!('BI7NOR-2>APRS,WIDE1-1*:>hello');
      expect(st.igateGated, 1);
      st.dispose();
    });

    test('条件齐了就没有「为什么」可说（空串）', () async {
      final st = await armed();
      expect(st.igateIdleReason, '');
      st.tnc.onLine!(rfLine);
      expect(st.igateGated, 1);
      expect(st.igateRfSeen, 1);
      st.dispose();
    });

    test('射频在收、IS 也连着，但全被环路防护拒收 → all-rejected（在正确工作）',
        () async {
      final st = await armed();
      // 带 q 构造的报文说明已经进过 APRS-IS，再送回去就是环路
      st.tnc.onLine!(qLine);
      expect(st.igateRfSeen, 1);
      expect(st.igateGated, 0);
      expect(st.igateBlocked, 1);
      expect(st.igateIdleReason, 'all-rejected');
      st.dispose();
    });
  });

  group('网关统计：不该被自己清零 / 漏计', () {
    test('关掉再打开网关**不清统计**（否则用户一折腾，历史数字就永远看不见）',
        () async {
      final st = await armed();
      st.tnc.onLine!(rfLine);
      st.tnc.onLine!(qLine);
      expect(st.igateRfSeen, 2);
      expect(st.igateGated, 1);

      st.setIgateEnabled(false);
      expect(st.igateRfSeen, 2, reason: '关网关不该改历史');
      expect(st.igateGated, 1);

      st.setIgateEnabled(true);
      expect(st.igateRfSeen, 2,
          reason: '「不涨 → 关掉再打开」是用户的第一反应；若这会清零，'
              '统计就永远显示 0，看起来像从没工作过');
      expect(st.igateGated, 1);
      st.dispose();
    });

    test('清空统计只认「清空统计」这个动作', () async {
      final st = await armed();
      st.tnc.onLine!(rfLine);
      expect(st.igateGated, 1);
      st.resetIgateStats();
      expect(st.igateRfSeen, 0);
      expect(st.igateGated, 0);
      st.dispose();
    });

    test('切换射频来源会清掉去重表，但不动统计', () async {
      final st = await armed();
      st.tnc.onLine!(rfLine);
      st.tnc.onLine!(rfLine); // 同一帧经多路径再来一次 = 重复
      expect(st.igateGated, 1);
      expect(st.igateDupDropped, 1);

      // 换设备 / 换线速 / 换频段之后，旧去重表会把新链路上的**首包**当成重复
      await st.toggleSource(AppState.srcTnc, false);
      await st.toggleSource(AppState.srcTnc, true);
      st.adoptDeviceLink(AppState.srcTnc, true); // 测试里没有真设备，手动接线
      st.tnc.onLine!(rfLine);
      expect(st.igateGated, 2, reason: '去重表清了，首包必须转得出去');
      expect(st.igateRfSeen, 3, reason: '统计不该被清 —— 用户正要用它对比换配置前后');
      st.dispose();
    });
  });

  group('网关统计：真实解码器的产物也能被转递（接缝）', () {
    test('AX.25 → TNC2 的形状不会被网关判成畸形', () async {
      final st = await armed();

      // 真机上进管线的文本是 Ax25.decodeToTnc2 产出的，而不是手写的
      final tnc2 = Ax25.decodeToTnc2(Ax25.encodeUi(
        source: 'BG7LZQ-9',
        dest: 'APALOC',
        digis: ['WIDE1-1', 'WIDE2-1'],
        info: '!2230.00N/11400.00E>test',
      ));
      expect(tnc2, isNotNull);
      st.tnc.onLine!(tnc2!);
      expect(st.igateGated, 1, reason: '解码器与网关判据必须对得上');
      st.dispose();
    });
  });
}
