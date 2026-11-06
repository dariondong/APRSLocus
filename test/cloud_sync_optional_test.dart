/// 云同步是可选模块（用户：「这不是必须项 所以你要确保可分离性」）。
///
/// 钉住四件事：
///   * 模块关掉 / 精简模式下，手动与自动同步都不再发请求；
///   * 「同步内容」里关掉消息或轨迹，那一路直接跳过，不报错；
///   * 自动间隔只认三档，脏值写不进去；
///   * 模块 id 是写进偏好的字符串，改了等于把所有人的开关重置。
library;

import 'package:aprslocus/cloud_sync.dart';
import 'package:aprslocus/features.dart';
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

  test('云同步默认开着，模块 id 固定为 cloudSync', () async {
    final st = await fresh();
    expect(appFeatureById('cloudSync'), AppFeature.cloudSync);
    expect(st.cloudSyncOn, isTrue);
  });

  test('关掉模块之后，手动同步一个请求也不发', () async {
    final st = await fresh();
    st.setFeature(AppFeature.cloudSync.id, false);
    expect(st.cloudSyncOn, isFalse);
    expect(await st.syncNow(), 'disabled');
    expect(st.syncState(), throwsA(isA<SyncException>()));
    expect(await st.syncLogin(), 'disabled');
  });

  test('精简模式下一律算关掉', () async {
    final st = await fresh();
    st.setLiteMode(true);
    expect(st.cloudSyncOn, isFalse);
    expect(await st.syncNow(), 'disabled');
  });

  test('同步内容：关掉消息就只走轨迹', () async {
    final st = await fresh();
    st.setSyncMessagesOn(false);
    expect(st.syncMessagesOn, isFalse);
    expect(await st.syncPushMessages(), '');
    expect(await st.syncPullMessages(), '');
    expect(st.syncTracksOn, isTrue);
  });

  test('同步内容：关掉轨迹就只走消息', () async {
    final st = await fresh();
    st.setSyncTracksOn(false);
    expect(st.syncTracksOn, isFalse);
    expect(await st.syncPushTracks(), '');
    expect(await st.syncPullTracks(), '');
  });

  test('自动间隔只认 5 / 15 / 60 分钟', () async {
    final st = await fresh();
    expect(st.syncAutoMinutes, 5);
    st.setSyncAutoMinutes(60);
    expect(st.syncAutoMinutes, 60);
    st.setSyncAutoMinutes(7);
    expect(st.syncAutoMinutes, 60, reason: '认不出的档位不该写进去');
  });
}
