import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 单个成就定义
class Achievement {
  final String key;
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  const Achievement(this.key, this.title, this.desc, this.icon, this.color);
}

/// 各成就解锁阈值（计数型）
const Map<String, int> kAchieveThreshold = {
  'sendCoord': 150, // 累计发送 150 次坐标
  'receiveMsg': 20, // 累计收到 20 条短信
  'sendMsg': 20, // 累计发送 20 条短信
  'worldListener': 30000, // 累计接收 3 万数据包
  'flowerWorld': 800, // 累计见过 800 个台站
  'gather': 2, // 累计组建 2 个群组
};

/// 全局成就中心：定义 + 计数 + 解锁状态（SharedPreferences 持久化）
class AchievementCenter {
  AchievementCenter._();
  static final AchievementCenter instance = AchievementCenter._();

  /// 全部成就（固定顺序展示）
  static const List<Achievement> all = [
    Achievement('sendCoord', '坐标发送·请求打击',
        '使用 APRSlocus 累计发送 150 次坐标', Icons.near_me_rounded, Color(0xFF16A34A)),
    Achievement('receiveMsg', '听没听到',
        '累计接收到 20 条 APRS 短信', Icons.mark_chat_unread_rounded, Color(0xFF2563EB)),
    Achievement('sendMsg', '我发出去了吗？',
        '累计发送 20 条 APRS 短信', Icons.send_rounded, Color(0xFF0E7490)),
    Achievement('bigRadius', 'Big? Big!',
        '将接收范围调到 3000 公里以上', Icons.public_rounded, Color(0xFFEA580C)),
    Achievement('worldListener', '世界聆听者',
        '累计接收超过 3 万个数据包', Icons.earbuds_rounded, Color(0xFF7C3AED)),
    Achievement('flowerWorld', '花花世界',
        '累计看到超过 800 个台站', Icons.radar_rounded, Color(0xFFDB2777)),
    Achievement('gather', '紧急集合！',
        '累计组建 2 个 APRSlocus 群组', Icons.groups_rounded, Color(0xFFE11D48)),
  ];

  /// 至高荣誉（需解锁全部成就后可申请）
  static const Achievement firstFix = Achievement(
      'firstFix', 'FIRST FIX · 至高荣誉',
      '完成 APRSlocus 1.0 全部成就（解锁全部成就后可向开发团队申请）',
      Icons.military_tech_rounded, Color(0xFFC9A227));

  final ValueNotifier<int> version = ValueNotifier<int>(0);
  final Set<String> _unlocked = {};
  final Map<String, int> _counts = {};
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
        }
      }
      final cjson = p.getString('achCounts');
      if (cjson != null) {
        final m = jsonDecode(cjson);
        if (m is Map) {
          m.forEach((k, v) {
            if (v is num) _counts[k.toString()] = v.toInt();
          });
        }
      }
      version.value++;
    } catch (_) {}
  }

  int countOf(String key) => _counts[key] ?? 0;

  /// 累加一次事件计数；达到阈值自动解锁
  Future<void> bump(String key) async {
    final th = kAchieveThreshold[key];
    if (th == null) return;
    final c = (_counts[key] ?? 0) + 1;
    _counts[key] = c;
    if (!_unlocked.contains(key) && c >= th) {
      _unlocked.add(key);
    }
    await _save();
  }

  /// 数值型达成（如范围达到阈值）直接解锁
  Future<void> unlock(String key) async {
    if (_unlocked.contains(key)) return;
    if (!all.any((a) => a.key == key)) return;
    _unlocked.add(key);
    version.value++;
    await _save();
  }

  /// “最高水位”型：current 达到阈值解锁（如台站数峰值）
  Future<void> reach(String key, int current) async {
    final th = kAchieveThreshold[key];
    if (th == null) return;
    if (current >= th && !_unlocked.contains(key)) {
      _unlocked.add(key);
      version.value++;
      await _save();
    }
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('achievements', jsonEncode(_unlocked.toList()));
      await p.setString('achCounts', jsonEncode(_counts));
    } catch (_) {}
    version.value++;
  }

  /// 是否已解锁全部 7 项（FIRST FIX 前置）
  bool get allUnlocked => AchievementCenter.all.every((a) => isUnlocked(a.key));
}
