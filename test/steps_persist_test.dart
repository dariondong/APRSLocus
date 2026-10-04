/// 「升级后步数归零」的回归测试。
///
/// 用户报的问题：升级（或改文件重装/冷启动）之后，运动排行榜里的今日步数
/// 变成 0。根因是 [AppState.stepsToday] 只活在内存里、从不落盘 —— 重启后
/// 即使 [_stepsBaseline] 还在，也要先拿到第一个传感器读数才可能恢复，而
/// 升级后的第一次启动往往还没等到读数就停在 0。
///
/// 修法是每次步数变化都写盘（见 AppState._persistSteps），并在 [_loadPrefs]
/// 里把今日步数接回来。这里把「跨实例仍在」钉死。
library;

import 'package:aprslocus/motion.dart';
import 'package:aprslocus/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  MotionSample sample(int steps) => MotionSample(
        available: true,
        moving: true,
        hasCompass: false,
        heading: -1,
        accel: 0.8,
        steps: steps,
        hasSteps: true,
        stepsPermission: true,
      );

  Future<AppState> fresh() async {
    final st = AppState();
    // 构造函数里的 _loadPrefs 是异步的，不等它落地会被它覆盖
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // 计步走的是定位回调那条路（_syncSteps 不依赖上报闸）。给出坐标与
    // 「本轮已定位」只是为了让前置状态完整，避免日后 _syncSteps 的调用
    // 条件变动、或落盘路径顺带触达 myGrid（myLat!）时测试变脆。
    st.myHasFix = true;
    st.myLat = 39.9075;
    st.myLng = 116.3972;
    st.debugSetFreshFix();
    return st;
  }

  test('步数变化后落盘：新实例能读回来（升级 / 冷启动不清零）', () async {
    final a = await fresh();
    MotionService.instance.sample = sample(1000);
    a.debugSyncSteps(); // 首次：取基线，今日还没有增量
    expect(a.stepsToday, 0);

    MotionService.instance.sample = sample(1123);
    a.debugSyncSteps();
    expect(a.stepsToday, 123, reason: '走了 123 步');
    await a.persistNow(); // 保证写入完成（不只是 fire-and-forget）

    // 换一个实例 = 模拟升级/重装后重新加载
    MotionService.instance.sample = MotionSample.unknown;
    final b = await fresh();
    expect(b.stepsToday, 123, reason: '升级/冷启动后今日步数不能归零');
    a.dispose();
    b.dispose();
  });
}
