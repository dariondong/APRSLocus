import 'package:aprslocus/chat_dates.dart';
import 'package:flutter_test/flutter_test.dart';

/// 消息列表的日期分界线回归测试
///
/// 这里的错误最隐蔽：分组若按「数组下标递增」比较（而不是按视觉顺序），
/// 分界线会插到相邻两条之间而不是日期真正变换处 —— 界面看上去「有日期」，
/// 但那一天是错的。所以用固定数据把位置锁住。
void main() {
  group('buildChatRows', () {
    test('倒序列表：分界线插在该天最早一条之后（视觉上方）', () {
      // 造 3 天数据：D1 两条、D2 一条、D3 两条，按时间倒序（最新在前）
      final d1a = DateTime(2026, 9, 11, 9);
      final d1b = DateTime(2026, 9, 11, 20);
      final d2a = DateTime(2026, 9, 12, 8);
      final d3a = DateTime(2026, 9, 13, 7);
      final d3b = DateTime(2026, 9, 13, 19);
      // 倒序：d3b, d3a, d2a, d1b, d1a
      final items = [d3b, d3a, d2a, d1b, d1a];

      final rows = buildChatRows<DateTime>(items, (t) => t);

      // 期望：5 条消息 + 3 条分界线 = 8 行
      expect(rows.length, 8);
      // 下标 0 = 最新消息 d3b
      expect(rows[0].isDivider, isFalse);
      expect(rows[0].item, d3b);
      // 下标 1 = d3a（同一天，不插线）
      expect(rows[1].item, d3a);
      // 下标 2 = 该天（D3）最早一条之后的日期线 → D3
      expect(rows[2].isDivider, isTrue);
      expect(ChatDateDivider.sameDay(rows[2].divider!, d3a), isTrue);
      // 下标 3 = d2a，下标 4 = 跨到 D2 的分界线
      expect(rows[3].item, d2a);
      expect(rows[4].isDivider, isTrue);
      expect(ChatDateDivider.sameDay(rows[4].divider!, d2a), isTrue);
      // 下标 5 = d1b，下标 6 = d1a（同天），下标 7 = D1 分界线
      expect(rows[5].item, d1b);
      expect(rows[6].item, d1a);
      expect(rows[7].isDivider, isTrue);
      expect(ChatDateDivider.sameDay(rows[7].divider!, d1a), isTrue);
    });

    test('同一天的消息只插一条分界线', () {
      final items = [
        DateTime(2026, 9, 13, 18),
        DateTime(2026, 9, 13, 12),
        DateTime(2026, 9, 13, 3),
      ];
      final rows = buildChatRows<DateTime>(items, (t) => t);
      // 3 条消息 + 1 条线（只有整段最早的那条之后需要）
      expect(rows.length, 4);
      expect(rows.where((r) => r.isDivider).length, 1);
      expect(rows.last.isDivider, isTrue);
    });

    test('每条消息各属一天 → 每条之后都有分界线', () {
      final items = [
        DateTime(2026, 9, 13, 1),
        DateTime(2026, 9, 12, 1),
        DateTime(2026, 9, 11, 1),
      ];
      final rows = buildChatRows<DateTime>(items, (t) => t);
      expect(rows.length, 6);
      for (var i = 0; i < rows.length; i += 2) {
        expect(rows[i].isDivider, isFalse);
        expect(rows[i + 1].isDivider, isTrue);
      }
    });

    test('跨年：同为 1 日 / 31 日但月份年份不同也要算换天', () {
      final items = [
        DateTime(2027, 1, 1, 0, 5), // 元旦
        DateTime(2026, 12, 31, 23), // 前一天
        DateTime(2026, 12, 31, 1),
      ];
      final rows = buildChatRows<DateTime>(items, (t) => t);
      expect(rows.length, 5);
      // 跨年处必须插线；注意这里专门用「同为某日但月年不同」的数据
      // 去逼出「只比较 day」的实现错误
      expect(rows[1].isDivider, isTrue);
      expect(rows[3].isDivider, isFalse); // 同为 12/31
      expect(rows[4].isDivider, isTrue);
    });

    test('跨月但日号相同（9/1 与 8/1）仍要插线', () {
      final items = [
        DateTime(2026, 9, 1, 10),
        DateTime(2026, 8, 1, 10),
      ];
      final rows = buildChatRows<DateTime>(items, (t) => t);
      expect(rows.length, 4);
      expect(rows[1].isDivider, isTrue);
    });

    test('另一年同月同日仍要插线', () {
      final items = [
        DateTime(2027, 5, 5, 9),
        DateTime(2026, 5, 5, 9),
      ];
      final rows = buildChatRows<DateTime>(items, (t) => t);
      expect(rows.where((r) => r.isDivider).length, 2);
    });

    test('空列表 → 无行', () {
      expect(buildChatRows<DateTime>(const [], (t) => t), isEmpty);
    });

    test('单条消息 → 1 条消息 + 1 条分界线', () {
      final rows =
          buildChatRows<DateTime>([DateTime(2026, 9, 13, 10)], (t) => t);
      expect(rows.length, 2);
      expect(rows[0].isDivider, isFalse);
      expect(rows[1].isDivider, isTrue);
    });

    test('用带下标的结构体验证「不会漏插/重复插」', () {
      // 模拟 10 条消息横跨 4 天，校验分界线数量与位置自洽
      final days = [13, 13, 12, 12, 12, 11, 11, 10, 10, 10];
      final items = [
        for (var i = 0; i < days.length; i++)
          (i, DateTime(2026, 9, days[i], 1)),
      ];
      final rows = buildChatRows<(int, DateTime)>(items, (e) => e.$2);
      final dividers = rows.where((r) => r.isDivider).length;
      expect(dividers, 4, reason: '4 个不同的日期应有 4 条分界线');
      // 每条分界线的日期，应与紧邻其「视觉下方」（数组前一个）消息同日
      for (var i = 0; i < rows.length; i++) {
        if (!rows[i].isDivider) continue;
        final prev = rows[i - 1].item!.$2;
        expect(ChatDateDivider.sameDay(rows[i].divider!, prev), isTrue);
      }
    });
  });

  group('sameDay', () {
    test('同一天任意时刻相等', () {
      expect(
        ChatDateDivider.sameDay(
          DateTime(2026, 9, 13, 0, 0, 0),
          DateTime(2026, 9, 13, 23, 59, 59),
        ),
        isTrue,
      );
    });

    test('相邻天不等', () {
      expect(
        ChatDateDivider.sameDay(
          DateTime(2026, 9, 13, 23, 59),
          DateTime(2026, 9, 14, 0, 0),
        ),
        isFalse,
      );
    });

    test('同年月日但不同年不等', () {
      expect(
        ChatDateDivider.sameDay(DateTime(2027, 9, 13), DateTime(2026, 9, 13)),
        isFalse,
      );
    });
  });
}
