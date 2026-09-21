import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 聊天日期分界线 ───
///
/// 为什么需要：消息列表按时间倒序、界面 `reverse: true` 渲染（最新在底部），
/// 用户往上滑看历史时，若没有日期分界，完全不知道「这段是哪天的」。
///
/// 关键点：**分组必须按「视觉顺序」做，不能按数组下标**。
/// 列表是倒序的，视觉上从上到下 = 下标从大到小 —— 若按下标递增去比较
/// `今天 != 昨天`，分界线会插在错误的位置（插到相邻两条之间而不是日期
/// 真正变换处）。所以这里统一：给定「视觉上相邻的两条消息」判断是否换天。
class ChatDateDivider {
  ChatDateDivider._();

  /// 是否为同一天
  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 日期分界线文案：今天 / 昨天 / 具体日期（带星期）
  static String label(BuildContext context, DateTime t) {
    final s = S.of(context);
    final now = DateTime.now();
    if (sameDay(t, now)) return s.dateToday;
    if (sameDay(t, now.subtract(const Duration(days: 1)))) {
      return s.dateYesterday;
    }
    // 星期：DateTime.weekday 是 1(周一)..7(周日)，与 l10n 的 select 键一致
    final w = s.dateWeekday('${t.weekday}');
    return s.dateDividerFull(t.year, t.month, t.day, w);
  }

  /// 渲染一条日期分界线
  static Widget build(BuildContext context, DateTime t) {
    final text = label(context, t);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(child: Container(height: 1, color: C.border)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: C.greyBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: ts(10, c: C.slate, w: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: C.border)),
      ]),
    );
  }
}

/// 消息列表的一行：要么是日期分界线，要么是消息本身
class ChatRow<T> {
  /// null = 这是日期分界线
  final T? item;
  final DateTime? divider;

  const ChatRow.message(this.item) : divider = null;
  const ChatRow.divider(this.divider) : item = null;

  bool get isDivider => item == null;
}

/// 把倒序的消息列表摊平成「含日期分界线」的行列表。
///
/// [items] 必须按时间**倒序**（最新在前），与页面 `reverse: true` 的用法一致。
/// 返回的行列表顺序 = 数组顺序（下标 0 在底部），因此渲染时不需要反转。
///
/// 规则：一天的第一条消息（也就是该天最新的一条）**上方**插入日期线。
/// 因为倒序数组中「该天第一条」的视觉上方正是更晚的一天，
/// 所以判断依据是「当前这条与**更旧的那条**（下一个下标）不同天」。
List<ChatRow<T>> buildChatRows<T>(
  List<T> items,
  DateTime Function(T) timeOf,
) {
  final rows = <ChatRow<T>>[];
  for (var i = 0; i < items.length; i++) {
    final cur = items[i];
    final older = i + 1 < items.length ? items[i + 1] : null;
    rows.add(ChatRow<T>.message(cur));
    // 当前这条是该天最早的一条（或整段最早的）：其上方需要日期线
    final needDivider = older == null ||
        !ChatDateDivider.sameDay(timeOf(cur), timeOf(older));
    if (needDivider) {
      rows.add(ChatRow<T>.divider(timeOf(cur)));
    }
  }
  return rows;
}
