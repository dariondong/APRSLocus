/// 省电模式的回归测试：采样间隔的换算、落盘，以及低电量提醒的台阶。
///
/// 两件事都不写在这一层就看不出来：省电开了但采样还是 1 秒（省了个寂寞），
/// 或者电量在 19% 上下浮时一直弹提醒（会被当成骚扰）。所以钉在这里。
library;

import 'package:aprslocus/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> fresh() async {
    final st = AppState();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return st;
  }

  test('默认关，采样按用户自己那一档', () async {
    final st = await fresh();
    expect(st.powerSave, isFalse);
    expect(st.effectiveGpsIntervalSec, 1);
    expect(st.loc.samplingMs, 1000);
  });

  test('开了省电：采样压到 30 秒，并真的交给定位服务', () async {
    final st = await fresh();
    st.setGpsIntervalSec(5);
    st.setPowerSave(true);
    expect(st.gpsIntervalSec, 5, reason: '用户自己那一档不被改掉');
    expect(st.effectiveGpsIntervalSec, AppState.powerSaveGpsSec);
    expect(st.loc.samplingMs, AppState.powerSaveGpsSec * 1000);
  });

  test('用户本来就选得比 30 秒更省：不被反向调快', () async {
    final st = await fresh();
    st.setPowerSave(true);
    expect(st.effectiveGpsIntervalSec, AppState.powerSaveGpsSec);
    st.setPowerSave(false);
    st.setGpsIntervalSec(30);
    st.setPowerSave(true);
    expect(st.effectiveGpsIntervalSec, 30);
  });

  test('关掉省电：回到用户那一档', () async {
    final st = await fresh();
    st.setGpsIntervalSec(3);
    st.setPowerSave(true);
    expect(st.loc.samplingMs, 30000);
    st.setPowerSave(false);
    expect(st.gpsIntervalSec, 3);
    expect(st.loc.samplingMs, 3000);
  });

  test('省电状态能落盘，新实例读得回来', () async {
    final a = await fresh();
    a.setPowerSave(true);
    await a.persistNow();
    final b = await fresh();
    expect(b.powerSave, isTrue);
    expect(b.loc.samplingMs, AppState.powerSaveGpsSec * 1000,
        reason: '冷启动那一刻就该按省电的间隔注册定位');
  });

  test('低电量提醒：20 / 10 / 5 各一次，不重复弹', () async {
    final st = await fresh();
    final hits = <int>[];
    st.onLowBattery = hits.add;

    st.debugBattery(19, charging: false);
    expect(hits, [19]);
    st.debugBattery(18, charging: false);
    expect(hits, [19], reason: '同一个电量档只在掉进来的那一刻提醒一次');

    st.debugBattery(9, charging: false);
    expect(hits, [19, 9]);
    st.debugBattery(4, charging: false);
    expect(hits, [19, 9, 4]);
    st.debugBattery(3, charging: false);
    expect(hits, [19, 9, 4], reason: '5% 这一档也只在掉进来时提醒一次');
  });

  test('低电量提醒：充电中 / 已开省电 / 电量回升 都不弹', () async {
    final st = await fresh();
    final hits = <int>[];
    st.onLowBattery = hits.add;

    st.debugBattery(15, charging: true);
    expect(hits, isEmpty, reason: '插着电提醒只会招烦');
    st.debugBattery(15, charging: false);
    expect(hits, [15]);

    st.setPowerSave(true);
    st.debugBattery(8, charging: false);
    expect(hits, [15], reason: '已经开着省电模式就没什么可劝的了');

    st.setPowerSave(false);
    st.debugBattery(30, charging: false); // 回升：清零已提醒档
    st.debugBattery(19, charging: false);
    expect(hits, [15, 19], reason: '电量回升再掉下来，应该重新提醒');
  });

  test('充电状态未知（桌面 / iOS）不挡提醒', () async {
    final st = await fresh();
    final hits = <int>[];
    st.onLowBattery = hits.add;
    st.debugBattery(12);
    expect(hits, [12]);
  });
}
