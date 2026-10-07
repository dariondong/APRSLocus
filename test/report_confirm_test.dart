import 'package:aprslocus/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「连接后由用户手动确认才开始上报」的行为回归。
///
/// 用户要求：无论用哪种方式定位，**连上服务器后不要自动上报**，必须由用户手动
/// 点一下正式的「开始上报」按钮、确认坐标有效之后才开始。这条约束只针对
/// **本次连接**（`beaconArmed`）—— 断线/重连都要重新确认，否则老连接残留的确认
/// 会让新连接又变成「连上就自动上报」。
///
/// 关键点：`beaconArmed` **不持久化**。持久化就等于「确认一次、以后永远自动」，
/// 又绕回用户反对的行为，所以这里也要守住「重启后仍是未确认」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 一个「链路已连、信标已开、本轮已定位、未确认」的状态。
  /// `connected` 通过真实翻转口子 [AppState.debugSetLinkUp] 置起 —— 这样才能
  /// 连带验证「连接翻转会复位确认」这件事；直接改 `connected` 字段会绕过它。
  Future<AppState> connectedFresh() async {
    final st = AppState();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    st.beaconEnabled = true;
    st.dataSource = AppState.srcAprsIs;
    // 本轮真实定位：给坐标 + 打开上报闸（缺一不可，见 myPositionReportable）
    st.myHasFix = true;
    st.myLat = 39.9075;
    st.myLng = 116.3972;
    st.debugSetFreshFix();
    // 从断到连：beaconArmed 应被复位为 false
    st.debugSetLinkUp(AppState.srcAprsIs, true);
    return st;
  }

  group('连接后手动确认才上报', () {
    test('全新连接：未确认前不能自动上报，报 needConfirm 这一档', () async {
      final st = await connectedFresh();

      expect(st.connected, isTrue);
      expect(st.beaconArmed, isFalse, reason: '连上后必须处于「待确认」，不能自动上报');
      expect(st.canAutoBeacon, isFalse,
          reason: '未确认就能自动上报 —— 正是用户反对的「连上就自动上报」');
      expect(st.beaconPhase, BeaconPhase.needConfirm,
          reason: '不能发时必须报告原因（needConfirm），而不是继续倒计时');

      st.dispose();
    });

    test('点「开始上报」后：本次连接内放行自动上报', () async {
      final st = await connectedFresh();

      st.beginReporting();

      expect(st.beaconArmed, isTrue);
      expect(st.canAutoBeacon, isTrue, reason: '确认之后自动上报要真的能进行');
      expect(st.beaconPhase, isNot(BeaconPhase.needConfirm));

      st.dispose();
    });

    test('断开再连：确认被复位，必须重新确认', () async {
      final st = await connectedFresh();
      st.beginReporting();
      expect(st.beaconArmed, isTrue);

      st.debugSetLinkUp(AppState.srcAprsIs, false);
      st.debugSetLinkUp(AppState.srcAprsIs, true);

      expect(st.beaconArmed, isFalse, reason: '新连接不能继承上一次的确认');
      expect(st.canAutoBeacon, isFalse);
      expect(st.beaconPhase, BeaconPhase.needConfirm);

      st.dispose();
    });

    test('beginReporting 会顺带打开自动上报总开关', () async {
      final st = await connectedFresh();
      st.beaconEnabled = false;
      expect(st.canAutoBeacon, isFalse);

      st.beginReporting();

      expect(st.beaconEnabled, isTrue, reason: '「开始上报」应打开自动上报总开关');
      expect(st.canAutoBeacon, isTrue);

      st.dispose();
    });

    test('手动「立即上报」不受连接闸影响：但按钮门槛是同一条 myPositionReportable',
        () async {
      final st = await connectedFresh();
      expect(st.beaconArmed, isFalse);

      // 未确认也能手动发一次（这是显式动作，不受「开始上报」闸约束）
      expect(st.myPositionReportable, isTrue);
      final before = st.beaconsSent;
      st.sendBeacon();
      expect(st.beaconsSent, before + 1,
          reason: '手动上报是用户显式动作，不该被连接确认闸挡住');

      st.dispose();
    });
  });
}
