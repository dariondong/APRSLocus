/// 「新获荣誉」庆祝判定的回归测试。
///
/// 这段逻辑的价值全在**边界**上，平时看不出来：
///   * 没有任何新增 → 不弹（否则每次启动都弹，用户会烦）；
///   * 一次新增多枚 → 只挑展示顺序最靠前的一枚（不能弹多次）；
///   * 新增的 key 没有定义 → 跳过（不能弹出一个没有名字/图标的东西）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aprslocus/early_member.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('newHonorsToCelebrate', () {
    test('没有新增 → 空（不该弹）', () {
      expect(newHonorsToCelebrate({'earlyMember'}, {'earlyMember'}), isEmpty);
      expect(newHonorsToCelebrate({}, {}), isEmpty);
    });

    test('单枚新增 → 返回该枚', () {
      final out = newHonorsToCelebrate({'sower'}, {});
      expect(out.length, 1);
      expect(out.single.key, 'sower');
    });

    test('多枚新增 → 取展示顺序最靠前的一枚', () {
      // displayHonorKeys 顺序：kaishan, developer, earlyMember, mostBrain,
      // firstFix, jadeGift, sower, iSelfReliant
      final out = newHonorsToCelebrate(
        {'sower', 'developer', 'jadeGift'},
        {},
      );
      expect(out.length, 1);
      expect(out.single.key, 'developer');
    });

    test('未定义的新 key → 跳过（不弹无名徽章）', () {
      expect(newHonorsToCelebrate({'__nope__'}, {}), isEmpty);
    });
  });

  group('已见快照落盘', () {
    test('markHonorsSeen 写入 honorSeenKeys', () async {
      await markHonorsSeen({'kaishan', 'developer'});
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('honorSeenKeys');
      expect(raw, isNotNull);
      expect(raw, contains('kaishan'));
      expect(raw, contains('developer'));
    });
  });
}
