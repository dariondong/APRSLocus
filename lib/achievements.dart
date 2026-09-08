import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─── APRSlocus 成就（本地检测并解锁，不联网）───
class Achievement {
  final String key;
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  const Achievement(this.key, this.title, this.desc, this.icon, this.color);
}

/// 全局成就中心：定义 + 解锁状态（SharedPreferences 持久化）
class AchievementCenter {
  AchievementCenter._();
  static final AchievementCenter instance = AchievementCenter._();

  /// 全部成就（固定顺序展示）
  static const List<Achievement> all = [
    Achievement('sendCoord', '坐标发送·请求打击',
        '使用 APRSlocus 发送一次坐标', Icons.near_me_rounded, Color(0xFF16A34A)),
    Achievement('receiveMsg', '听没听到',
        '使用 APRSlocus 接收到一次 APRS 短信', Icons.mark_chat_unread_rounded, Color(0xFF2563EB)),
    Achievement('sendMsg', '我发出去了吗？',
        '使用 APRSlocus 发送一次 APRS 短信', Icons.send_rounded, Color(0xFF0E7490)),
    Achievement('bigRadius', 'Big? Big!',
        '将 APRSlocus 接收范围调到 2000 公里以上', Icons.public_rounded, Color(0xFFEA580C)),
    Achievement('worldListener', '世界聆听者',
        '接收超过 10000 个数据包', Icons.earbuds_rounded, Color(0xFF7C3AED)),
    Achievement('flowerWorld', '花花世界',
        '接收超过 500 个台站', Icons.radar_rounded, Color(0xFFDB2777)),
    Achievement('gather', '紧急集合！',
        '组建一个 APRSlocus 群组', Icons.groups_rounded, Color(0xFFE11D48)),
  ];

  final ValueNotifier<int> version = ValueNotifier<int>(0);
  final Set<String> _unlocked = {};
  int _loaded = 0;

  bool isUnlocked(String key) => _unlocked.contains(key);
  int get unlockedCount => _unlocked.length;

  Future<void> ensureLoaded() async {
    if (_loaded > 0) return;
    _loaded++;
    try {
      final p = await SharedPreferences.getInstance();
      final json = p.getString('achievements');
      if (json != null && json.isNotEmpty) {
        final list = jsonDecode(json);
        if (list is List) {
          for (final k in list) {
            if (k is String) _unlocked.add(k);
          }
          version.value++;
        }
      }
    } catch (_) {}
  }

  /// 解锁（幂等；命中已解锁则忽略）
  Future<void> unlock(String key) async {
    if (_unlocked.contains(key)) return;
    if (!all.any((a) => a.key == key)) return;
    _unlocked.add(key);
    version.value++;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('achievements', jsonEncode(_unlocked.toList()));
    } catch (_) {}
  }
}
