import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 单个成就定义
class Achievement {
  final String key;
  /// 中文基准标题（兼容旧调用；多语言请用 [titleOf]）
  final String title;
  /// 中文基准说明（兼容旧调用；多语言请用 [descOf]）
  final String desc;
  final IconData icon;
  final Color color;
  /// 三语标题 / 说明（key: zh / zh-TW / en），缺失回落中文
  final Map<String, String>? titles;
  final Map<String, String>? descs;

  const Achievement(this.key, this.title, this.desc, this.icon, this.color,
      {this.titles, this.descs});

  String titleOf(String lang) => titles?[lang] ?? title;
  String descOf(String lang) => descs?[lang] ?? desc;
}

/// 各成就解锁阈值（计数型）
const Map<String, int> kAchieveThreshold = {
  'sendCoord': 500, // 累计发送 500 次坐标
  'receiveMsg': 50, // 累计收到 50 条短信
  'sendMsg': 50, // 累计发送 50 条短信
  'worldListener': 50000, // 累计接收 5 万数据包
  'flowerWorld': 1500, // 累计见过 1500 个台站
  'gather': 5, // 累计组建 5 个群组
};

/// FIRST FIX 在线名单 URL（官网，由开发团队维护）
const String kFirstFixUrl = 'https://aprslocus.theez.top/firstfix.json';

/// 全局成就中心：定义 + 计数 + 解锁状态（SharedPreferences 持久化）
class AchievementCenter {
  AchievementCenter._();
  static final AchievementCenter instance = AchievementCenter._();

  /// 全部成就（固定顺序展示）
  static const List<Achievement> all = [
    Achievement('sendCoord', '坐标发送·请求打击',
        '使用 APRSlocus 累计发送 500 次坐标', Icons.near_me_rounded, Color(0xFF16A34A),
        titles: {
          'zh': '坐标发送·请求打击',
          'zh-TW': '座標發送·請求打擊',
          'en': 'Beacon sent · Strike requested',
        },
        descs: {
          'zh': '使用 APRSlocus 累计发送 500 次坐标',
          'zh-TW': '使用 APRSlocus 累計發送 500 次座標',
          'en': 'Sent 500 position beacons with APRSlocus',
        }),
    Achievement('receiveMsg', '听没听到',
        '累计接收到 50 条 APRS 短信', Icons.mark_chat_unread_rounded, Color(0xFF2563EB),
        titles: {'zh': '听没听到', 'zh-TW': '聽沒聽到', 'en': 'Did anyone hear me?'},
        descs: {
          'zh': '累计接收到 50 条 APRS 短信',
          'zh-TW': '累計接收到 50 條 APRS 簡訊',
          'en': 'Received 50 APRS messages',
        }),
    Achievement('sendMsg', '我发出去了吗？',
        '累计发送 50 条 APRS 短信', Icons.send_rounded, Color(0xFF0E7490),
        titles: {'zh': '我发出去了吗？', 'zh-TW': '我發出去了嗎？', 'en': 'Did mine go out?'},
        descs: {
          'zh': '累计发送 50 条 APRS 短信',
          'zh-TW': '累計發送 50 條 APRS 簡訊',
          'en': 'Sent 50 APRS messages',
        }),
    Achievement('bigRadius', 'Big? Big!',
        '将接收范围调到 5000 公里以上', Icons.public_rounded, Color(0xFFEA580C),
        titles: {'zh': 'Big? Big!', 'zh-TW': 'Big? Big!', 'en': 'Big? Big!'},
        descs: {
          'zh': '将接收范围调到 5000 公里以上',
          'zh-TW': '將接收範圍調到 5000 公里以上',
          'en': 'Set the receive range beyond 5000 km',
        }),
    Achievement('worldListener', '世界聆听者',
        '累计接收超过 5 万个数据包', Icons.earbuds_rounded, Color(0xFF7C3AED),
        titles: {'zh': '世界聆听者', 'zh-TW': '世界聆聽者', 'en': 'World listener'},
        descs: {
          'zh': '累计接收超过 5 万个数据包',
          'zh-TW': '累計接收超過 5 萬個資料包',
          'en': 'Received over 50,000 packets',
        }),
    Achievement('flowerWorld', '花花世界',
        '累计看到超过 1500 个台站', Icons.radar_rounded, Color(0xFFDB2777),
        titles: {'zh': '花花世界', 'zh-TW': '花花世界', 'en': 'A world of flowers'},
        descs: {
          'zh': '累计看到超过 1500 个台站',
          'zh-TW': '累計看到超過 1500 個台站',
          'en': 'Seen more than 1,500 stations',
        }),
    Achievement('gather', '紧急集合！',
        '累计组建 5 个 APRSlocus 群组', Icons.groups_rounded, Color(0xFFE11D48),
        titles: {'zh': '紧急集合！', 'zh-TW': '緊急集合！', 'en': 'Rally!'},
        descs: {
          'zh': '累计组建 5 个 APRSlocus 群组',
          'zh-TW': '累計組建 5 個 APRSlocus 群組',
          'en': 'Created 5 APRSlocus groups',
        }),
  ];

  /// 至高荣誉（需解锁全部成就 + 名单命中）
  static const Achievement firstFix = Achievement(
      'firstFix', 'FIRST FIX · 至高荣誉',
      'APRSlocus 1.7.0 开放 —— 完成全部成就后向开发团队申请',
      Icons.military_tech_rounded, Color(0xFFC9A227),
      titles: {
        'zh': 'FIRST FIX · 至高荣誉',
        'zh-TW': 'FIRST FIX · 至高榮譽',
        'en': 'FIRST FIX · Supreme Honor',
      },
      descs: {
        'zh': 'APRSlocus 1.7.0 开放 —— 完成全部成就后向开发团队申请',
        'zh-TW': 'APRSlocus 1.7.0 開放 —— 完成全部成就後向開發團隊申請',
        'en': 'Opening in APRSlocus 1.7.0 — complete every achievement, then apply to the dev team',
      });

  final ValueNotifier<int> version = ValueNotifier<int>(0);
  final Set<String> _unlocked = {};
  final Map<String, int> _counts = {};
  final Set<String> _firstFixHolders = {}; // 官网授予名单
  int _loaded = 0;
  int _ffLoaded = 0;

  bool isUnlocked(String key) => _unlocked.contains(key);
  int get unlockedCount => _unlocked.length;

  /// FIRST FIX 是否已由官方授予（在线名单命中）
  bool isFirstFixHolder(String call) {
    final base = call.trim().toUpperCase().split('-').first;
    return _firstFixHolders.contains(base);
  }

  /// FIRST FIX 完整点亮条件：官方名单命中（申请授勋后）——不要求本地全成就（授勋代表官方认可）
  bool firstFixUnlocked(String call) => isFirstFixHolder(call);

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
      final ff = p.getString('firstFixHolders');
      if (ff != null) {
        final list = jsonDecode(ff);
        if (list is List) {
          for (final k in list) {
            if (k is String) _firstFixHolders.add(k.toUpperCase());
          }
        }
      }
      version.value++;
    } catch (_) {}
    unawaited(refreshFirstFix());
  }

  /// 拉取官网 FIRST FIX 名单并缓存
  Future<void> refreshFirstFix() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      try {
        final req = await client
            .getUrl(Uri.parse(kFirstFixUrl))
            .timeout(const Duration(seconds: 8));
        req.headers.set(HttpHeaders.userAgentHeader, 'APRSlocus');
        final resp = await req.close().timeout(const Duration(seconds: 8));
        if (resp.statusCode != 200) return;
        final body = await resp.transform(utf8.decoder).join();
        final d = jsonDecode(body);
        if (d is! Map) return;
        final list = d['holders'];
        if (list is List) {
          _firstFixHolders.clear();
          for (final k in list) {
            if (k is String && k.trim().isNotEmpty) {
              _firstFixHolders.add(k.trim().toUpperCase());
            }
          }
          version.value++;
          try {
            final p = await SharedPreferences.getInstance();
            await p.setString('firstFixHolders',
                jsonEncode(_firstFixHolders.toList()));
          } catch (_) {}
        }
      } finally {
        client.close(force: true);
      }
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

  /// 是否已解锁全部 7 项（FIRST FIX 申请前置）
  bool get allUnlocked => AchievementCenter.all.every((a) => isUnlocked(a.key));
}
