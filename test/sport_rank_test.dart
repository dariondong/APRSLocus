/// 运动排行榜（issue #22-3）的两条**排序不合理**回归测试。
///
/// 榜单卡片上写的是「今日」，而 APRS 台站最后一次报文可能是三天前的：
/// 不过滤时间的话，三天前的 30000 步会排在今天 8000 步前面 —— 读者只会以为
/// 自己今天输了。另外「我」在页面上已经单独一张卡（今日步数 + 上传开关），
/// 再出现在榜里就是同一屏里同一个人两行。
///
/// 这两条都只在**数据边界**上出错（平时看着都正常），所以钉在这里。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aprslocus/models.dart';
import 'package:aprslocus/state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 起一个干净的 AppState（构造里会异步载入配置，等一拍再动它）
  Future<AppState> fresh() async {
    final st = AppState();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    st.myCall = 'BG7LZQ';
    st.mySsid = 9;
    return st;
  }

  /// 一个"从 APRSlocus 台站收到"的台站（`toCall == APALOC` 才会进榜）
  Station mk(String call, String comment, {Duration ago = Duration.zero}) =>
      Station(
        call: call,
        symbol: '>',
        lat: 22.5,
        lng: 113.5,
        comment: comment,
        toCall: AppState.apalocToCall,
        lastHeard: DateTime.now().subtract(ago),
      );

  test('只统计今天：三天前的步数不进「今日」榜', () async {
    final st = await fresh();
    st.stations
      ..clear()
      ..addAll([
        mk('BH7GZB-7', 'STEPS=8000'),
        mk('BH7NOR-9', 'STEPS=30000', ago: const Duration(days: 3)),
      ]);
    final r = st.sportRank();
    expect(r.map((e) => e.$1.call).toList(), ['BH7GZB-7'],
        reason: '过期条目不该排在今天的数字前面');
    expect(r.single.$2, 8000);
    st.dispose();
  });

  test('自己在榜里，并按步数排在正确的位置（用户要求）', () async {
    final st = await fresh();
    st.stations
      ..clear()
      ..addAll([
        mk('BG7LZQ-9', 'STEPS=12000'),   // 我自己
        mk('BH7GZB-7', 'STEPS=8000'),
      ]);
    expect(st.sportRank().map((e) => e.$1.call).toList(),
        ['BG7LZQ-9', 'BH7GZB-7']);
    st.dispose();
  });

  test('按步数降序；没带步数、非 APRSlocus、步数为 0 的都不进榜', () async {
    final st = await fresh();
    st.stations
      ..clear()
      ..addAll([
        mk('BH7GZB-7', 'STEPS=8000'),
        mk('BH7NOR-9', 'STEPS=15000'),
        mk('BI7KZM-13', 'no steps here'),            // 没带步数
        mk('BD7QWE-3', 'STEPS=0'),                   // 带了但是 0
        Station(                                     // 不是 APRSlocus 台站
          call: 'VR2ABC-7',
          symbol: '>',
          lat: 22.4,
          lng: 113.4,
          comment: 'STEPS=99999',
          toCall: 'APDW16',
          lastHeard: DateTime.now(),
        ),
      ]);
    expect(st.sportRank().map((e) => e.$1.call).toList(),
        ['BH7NOR-9', 'BH7GZB-7']);
    st.dispose();
  });
}
