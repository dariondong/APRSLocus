import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aprslocus/state.dart';

/// APRS 卫星模式：射频路径覆盖 + 设置落盘。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> fresh() async {
    final st = AppState();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return st;
  }

  test('卫星模式下射频路径改用卫星路径，关掉后恢复', () async {
    final st = await fresh();
    final beforeTnc = st.pathFor(AppState.srcTnc);
    final beforeAudio = st.pathFor(AppState.srcAudio);

    st.setSatelliteMode(true);
    expect(st.pathFor(AppState.srcTnc), 'APALOC,ARISS');
    expect(st.pathFor(AppState.srcAudio), 'APALOC,ARISS');
    // 互联网那一条不该被卫星路径污染
    expect(st.pathFor(AppState.srcAprsIs), 'APALOC,TCPIP*');

    st.setSatPath('wide1-1');
    expect(st.pathFor(AppState.srcTnc), 'APALOC,WIDE1-1');

    st.setSatelliteMode(false);
    expect(st.pathFor(AppState.srcTnc), beforeTnc);
    expect(st.pathFor(AppState.srcAudio), beforeAudio);
    st.dispose();
  });

  test('卫星模式、路径与频率会落盘', () async {
    final st = await fresh();
    st.setSatelliteMode(true);
    st.setSatPath('ariss');
    st.setSatFreqs(up: 145.850, down: 145.825);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final st2 = await fresh();
    expect(st2.satelliteMode, isTrue);
    expect(st2.satPath, 'ARISS');
    expect(st2.satUpMhz, closeTo(145.850, 1e-9));
    expect(st2.satDownMhz, closeTo(145.825, 1e-9));
    st.dispose();
    st2.dispose();
  });

  test('非法频率被忽略，不会把默认值写坏', () async {
    final st = await fresh();
    st.setSatFreqs(up: 0, down: 99999);
    expect(st.satUpMhz, closeTo(145.825, 1e-9));
    expect(st.satDownMhz, closeTo(145.825, 1e-9));
    st.dispose();
  });

  test('收藏与自动多普勒会落盘', () async {
    final st = await fresh();
    expect(st.isSatFavorite('ISS (ZARYA)'), isFalse);
    st.toggleSatFavorite('ISS (ZARYA)');
    st.toggleSatFavorite('so-50');
    expect(st.isSatFavorite('ISS (ZARYA)'), isTrue);
    expect(st.isSatFavorite('SO-50'), isTrue);
    expect(st.satFavorites.length, 2);
    st.setSatAutoDoppler(true);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final st2 = await fresh();
    expect(st2.isSatFavorite('ISS (ZARYA)'), isTrue);
    expect(st2.isSatFavorite('SO-50'), isTrue);
    expect(st2.satAutoDoppler, isTrue);

    st2.toggleSatFavorite('SO-50');
    expect(st2.isSatFavorite('SO-50'), isFalse);
    expect(st2.satFavorites.length, 1);
    st.dispose();
    st2.dispose();
  });

  test('模式互斥：卫星 / 精简 / 2.0 / 1.0 一次只选一个', () async {
    final st = await fresh();
    st.setAppMode(AppMode.satellite);
    expect(st.appMode, AppMode.satellite);
    expect(st.liteMode, isFalse);

    st.setAppMode(AppMode.lite);
    expect(st.appMode, AppMode.lite);
    expect(st.satelliteMode, isFalse);

    st.setAppMode(AppMode.classic);
    expect(st.appMode, AppMode.classic);
    expect(st.liteMode, isFalse);
    expect(st.satelliteMode, isFalse);

    st.setAppMode(AppMode.sheet);
    expect(st.appMode, AppMode.sheet);
    st.dispose();
  });
}
