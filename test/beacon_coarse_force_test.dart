import 'package:aprslocus/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「强制接受网络定位自动上报」的行为回归（v1.6.177）。
///
/// 起因（用户要求）：「在信标上报页面留一个按钮，可开启强制接受网络定位自动上报」。
///
/// 这条需求**动到的是一条既有约定**：v1.6.163 起粗定位（网络/基站/被动）
/// **不自动上报**（粗点常偏几百米，自动发出去等于向全网宣告一个错坐标）。
/// 所以这个开关的核心不是「加个按钮」，而是三件事必须同时成立：
///
///   1. 默认**仍然**不发粗点（不能因为加了开关就把默认行为改掉）；
///   2. 打开后粗点**真的**能自动发（否则这个开关没有任何意义）；
///   3. 打开的当下，界面必须看得出「现在发的是网络定位」—— 所以它是一档
///      **独立的** BeaconPhase（coarseForced），而不是混进普通的 counting。
///
/// 第 3 条最容易漏：混进 counting 的话编译、测试、界面全都「正常」，
/// 用户看到的只是一个绿色倒计时，而发出去的是偏几百米的坐标。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 一个「链路已连、信标已开」的状态：这是自动上报的门槛条件。
  /// 其余四个条件（粗定位与否、射频信标、佳明、定位就绪）由各用例自己摆。
  Future<AppState> armed() async {
    final st = AppState();
    // 构造函数里的 _loadPrefs 是异步的，不等它落地会被它覆盖
    await Future<void>.delayed(const Duration(milliseconds: 20));
    st.beaconEnabled = true;
    st.connected = true; // 默认来源是 APRS-IS，不受「射频信标」那一档影响
    return st;
  }

  group('强制接受网络定位自动上报', () {
    test('默认关：粗定位不自动上报，并报告「粗定位」这一档', () async {
      final st = await armed();
      st.myFixCoarse = true;

      expect(st.beaconForceCoarse, isFalse, reason: '默认必须是关的（v1.6.163 的约定）');
      expect(st.canAutoBeacon, isFalse,
          reason: '粗点默认绝不能自动发出去 —— 这是 v1.6.163 按用户反馈立的规矩');
      expect(st.beaconPhase, BeaconPhase.coarseFix,
          reason: '不能发时必须报告原因，而不是继续倒计时');

      st.dispose();
    });

    test('打开后：粗定位也自动上报', () async {
      final st = await armed();
      st.myFixCoarse = true;
      st.setBeaconForceCoarse(true);

      expect(st.beaconForceCoarse, isTrue);
      expect(st.canAutoBeacon, isTrue,
          reason: '打开后粗点要真的能自动发 —— 否则这个开关等于没做');
      expect(st.beaconPhase, BeaconPhase.coarseForced,
          reason: '必须与 counting 分开（见文件头第 3 条），否则界面上看不出'
              '「正在发一个偏几百米的坐标」');

      st.dispose();
    });

    test('开关只影响自动上报：手动「立即上报」与它无关', () async {
      final st = await armed();
      // ⚠ 手动上报的门槛是 myHasFix / myLat / myLng（见 _sendBeaconNow）——
      // 第一版忘了摆这三样，于是 sendBeacon 直接 return，断言「没发出去」失败，
      // 看着像功能坏了，其实是**测试自己没摆好前置状态**。
      st.myHasFix = true;
      st.myLat = 39.9075;
      st.myLng = 116.3972;
      st.myFixCoarse = true; // 但这一发用的是**网络定位**

      expect(st.canAutoBeacon, isFalse, reason: '开关关着时粗点不自动发');
      st.sendBeacon();

      expect(st.beaconsSent, greaterThan(0),
          reason: '手动上报是显式动作，不该被「粗定位不自动上报」这条规矩拦下');
      expect(st.packets, isNotEmpty, reason: '手动那一发必须真的进了数据包列表');

      st.dispose();
    });

    test('GPS 回来（不再是粗定位）后，两档都回到正常倒计时', () async {
      final st = await armed();
      st.myFixCoarse = true;
      st.setBeaconForceCoarse(true);
      expect(st.beaconPhase, BeaconPhase.coarseForced);

      st.myFixCoarse = false; // GPS 恢复
      expect(st.beaconPhase, isNot(BeaconPhase.coarseForced));
      expect(st.beaconPhase, isNot(BeaconPhase.coarseFix));
      expect(st.canAutoBeacon, isTrue);

      st.dispose();
    });

    test('关掉开关后立刻回到「粗定位不自动上报」', () async {
      final st = await armed();
      st.myFixCoarse = true;
      st.setBeaconForceCoarse(true);
      expect(st.canAutoBeacon, isTrue);

      st.setBeaconForceCoarse(false);
      expect(st.canAutoBeacon, isFalse, reason: '关掉必须立刻生效（不能等到重连/重启）');
      expect(st.beaconPhase, BeaconPhase.coarseFix);

      st.dispose();
    });
  });
}
