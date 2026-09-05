import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// 设备识别库
///
/// 数据源：官方 APRS 设备识别仓库 aprsorg/aprs-deviceid 的 tocalls 索引
///   https://github.com/aprsorg/aprs-deviceid/blob/main/tocalls.yaml
///   (CC BY-SA 2.0, 由 hessu OH7LZB 为 aprs.fi 维护)
///
/// 识别原理：APRS 数据包头部 `CALL>目的呼号,路径...:...` 中的目的呼号
/// （to-call，形如 APxxxx）由电台/软件设置，官方 tocalls 表将其映射到
/// 厂商 + 型号 + 设备类别。
///
/// 策略：App 内置一份 JSON 快照保证离线可用；联网时自动拉取官方最新
/// tocalls.yaml 并缓存到本地（失败静默回退内置）。
class AprsDeviceInfo {
  /// 匹配到的目的呼号（原始大小写）
  final String toCall;
  final String vendor;
  final String model;

  /// 设备类别 key（空串表示官方未标注类别）
  final String cls;

  const AprsDeviceInfo({
    required this.toCall,
    required this.vendor,
    required this.model,
    required this.cls,
  });

  /// 是否为有效识别：官方用 vendor/model 'Unknown' 标记未分配/实验性
  /// to-call 段，这类不做“已知设备”展示（仍可用类别参与筛选）。
  bool get isKnown {
    final v = vendor.toLowerCase();
    final m = model.toLowerCase();
    if (m.isEmpty) return false;
    if (m == 'unknown') return false;
    if (v == 'unknown' && m == 'experimental') return false;
    return true;
  }

  /// 展示名：厂商 + 型号（厂商与型号同名/为空时只显示一个）
  String get displayName {
    final v = vendor.trim();
    final m = model.trim();
    if (v.isEmpty) return m;
    if (m.isEmpty || v.toLowerCase() == m.toLowerCase()) return v;
    return '$v $m';
  }

  /// 设备类别 key（无类别时归为 other，供列表筛选与标签展示）
  String get classKey => cls.isEmpty ? 'other' : cls;
}

/// 设备类别 → 中文显示名（用于列表筛选 chips 与标签）
class DeviceClassNames {
  /// zh/en 双语显示名（UI 语言不同选择不同文案）
  static String labelOf(String cls, bool zh) {
    const zhMap = <String, String>{
      'wx': '气象站',
      'tracker': '跟踪器',
      'gadget': '小型设备',
      'rig': '车载电台',
      'ht': '手持电台',
      'app': '手机 App',
      'software': '桌面软件',
      'daemon': '后台软件',
      'service': '网络服务',
      'network': '网络硬件',
      'digi': '数字中继',
      'igate': '网关',
      'dstar': 'D-Star 电台',
      'satellite': '卫星台站',
      'other': '其它设备',
      'unknown': '未知设备',
    };
    const enMap = <String, String>{
      'wx': 'Weather',
      'tracker': 'Tracker',
      'gadget': 'Gadget',
      'rig': 'Rig',
      'ht': 'HT',
      'app': 'App',
      'software': 'Software',
      'daemon': 'Daemon',
      'service': 'Service',
      'network': 'Network',
      'digi': 'Digipeater',
      'igate': 'iGate',
      'dstar': 'D-Star',
      'satellite': 'Satellite',
      'other': 'Other',
      'unknown': 'Unknown',
    };
    final map = zh ? zhMap : enMap;
    return map[cls] ?? (zh ? '其它设备' : 'Other');
  }
}

class _DeviceEntry {
  final String pattern; // 原始模式，如 AP4R?? / APALH* / APAGW
  final String vendor;
  final String model;
  final String cls;
  // 编译好的匹配表达式：'?' → 单字符，'*' → 任意，全大写
  final RegExp regex;
  // 通配符数量越少越具体，用于匹配优先级
  final int literalLen;

  _DeviceEntry({
    required this.pattern,
    required this.vendor,
    required this.model,
    required this.cls,
  }) : regex = _compile(pattern),
       literalLen = pattern.replaceAll(RegExp(r'[?*]'), '').length;

  static RegExp _compile(String pat) {
    final up = pat.trim().toUpperCase();
    final sb = StringBuffer('^');
    for (var i = 0; i < up.length; i++) {
      final ch = up[i];
      if (ch == '?') {
        sb.write('.');
      } else if (ch == '*') {
        sb.write('.*');
      } else if (RegExp(r'^[a-zA-Z0-9]$').hasMatch(ch)) {
        sb.write(ch);
      } else {
        // 其它字符（如空格）按字面量转义
        sb.write(RegExp.escape(ch));
      }
    }
    sb.write(r'$');
    return RegExp(sb.toString(), caseSensitive: false);
  }
}

/// 单例设备库：解析 JSON 快照/官方 YAML，提供 to-call → 设备查询
class AprsDevice {
  AprsDevice._();

  static final AprsDevice instance = AprsDevice._();

  static const String _assetPath = 'assets/aprs_device/tocalls.json';
  static const String _prefsKey = 'deviceDbJsonV1';
  static const String _prefsUpdatedAt = 'deviceDbUpdatedAtV1';

  /// 官方 tocalls.yaml 拉取地址（raw + CDN 兜底）
  static const List<String> _sources = [
    'https://raw.githubusercontent.com/aprsorg/aprs-deviceid/main/tocalls.yaml',
    'https://cdn.jsdelivr.net/gh/aprsorg/aprs-deviceid@main/tocalls.yaml',
  ];

  bool _ready = false;
  bool _loading = false;
  bool get ready => _ready;

  final List<_DeviceEntry> _devices = [];
  final Map<String, AprsDeviceInfo?> _cache = {};
  final List<String> _classKeys = [];

  /// 当前库里的设备类别 key 列表（含 'other' 兜底），用于筛选 chips
  List<String> get classKeys => List.unmodifiable(_classKeys);

  int _loadedCount = 0;
  int get loadedCount => _loadedCount;

  /// 初始化：优先读本地缓存 JSON，其次读内置快照；随后静默后台拉取官方更新
  Future<void> ensureLoaded() async {
    if (_ready || _loading) return;
    _loading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsKey);
      if (cached != null && cached.isNotEmpty && _parseDbJson(cached)) {
        _ready = true;
      }
    } catch (_) {}
    if (!_ready) {
      try {
        final asset = await rootBundle.loadString(_assetPath);
        _parseDbJson(asset);
        _ready = true;
      } catch (_) {}
    }
    _loading = false;
    if (_ready) _notifyReady();
    // 后台拉取最新官方数据（不阻塞启动）
    unawaited(refreshFromNetwork());
  }

  /// 拉取官方 tocalls.yaml 并更新本地缓存（失败静默忽略）
  Future<void> refreshFromNetwork() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_prefsUpdatedAt) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      // 距上次成功更新不足 12 小时不重复拉取
      if (nowMs - last < 12 * 3600 * 1000) return;
      for (final url in _sources) {
        final yaml = await _httpGet(url);
        if (yaml == null || yaml.isEmpty) continue;
        final json = _convertYamlToJson(yaml);
        if (json == null) continue;
        if (_parseDbJson(json)) {
          _ready = true;
          await prefs.setString(_prefsKey, json);
          await prefs.setInt(_prefsUpdatedAt, nowMs);
          _notifyReady();
          return;
        }
      }
    } catch (_) {}
  }

  /// 解析内置/缓存的精简 JSON（schema=1）
  bool _parseDbJson(String json) {
    try {
      final map = jsonDecode(json);
      if (map is! Map) return false;
      if ((map['schema'] as num?)?.toInt() != 1) return false;
      final list = map['devices'];
      if (list is! List) return false;
      final devices = <_DeviceEntry>[];
      final classSet = <String>{};
      final seen = <String>{};
      for (final d in list) {
        if (d is! Map) continue;
        final pat = (d['p'] as String? ?? '').trim().toUpperCase();
        if (pat.isEmpty) continue;
        final vendor = (d['v'] as String? ?? '').trim();
        final model = (d['m'] as String? ?? '').trim();
        final cls = (d['c'] as String? ?? '').trim();
        // 丢弃空型号与官方“未知”泛化登记（APRS → Unknown），无识别价值
        if (model.isEmpty) continue;
        if (model.toLowerCase() == 'unknown' && cls.isEmpty) continue;
        final key = '$pat|$model';
        if (seen.contains(key)) continue;
        seen.add(key);
        final entry = _DeviceEntry(
          pattern: pat,
          vendor: vendor,
          model: model,
          cls: cls,
        );
        devices.add(entry);
        if (cls.isNotEmpty) classSet.add(cls);
      }
      _devices
        ..clear()
        ..addAll(devices);
      _classKeys
        ..clear()
        ..addAll(classSet)
        ..add('other');
      _cache.clear();
      _loadedCount = devices.length;
      return devices.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 查询某目的呼号对应设备（未识别/未加载返回 null）
  AprsDeviceInfo? lookup(String? toCall) {
    if (toCall == null) return null;
    final key = toCall.trim().toUpperCase();
    if (key.isEmpty || key == 'APRS' || key == 'BEACON') return null;
    if (_cache.containsKey(key)) return _cache[key];
    AprsDeviceInfo? best;
    var bestScore = -1;
    for (final e in _devices) {
      if (!e.regex.hasMatch(key)) continue;
      // 具体（少通配符）优先，同具体度时字面量长度优先
      var score = e.literalLen;
      if (e.pattern.indexOf('?') < 0 && e.pattern.indexOf('*') < 0) {
        score += 1000; // 精确匹配优先于通配
      }
      if (score > bestScore) {
        bestScore = score;
        best = AprsDeviceInfo(
          toCall: key,
          vendor: e.vendor,
          model: e.model,
          cls: e.cls,
        );
      }
    }
    _cache[key] = best;
    return best;
  }

  /// 设备库就绪后的回调（AppState 用于刷新台站界面）
  void Function()? onReady;

  void _notifyReady() {
    onReady?.call();
  }

  static Future<String?> _httpGet(String url) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
      try {
        final req = await client.getUrl(Uri.parse(url));
        req.headers.set(HttpHeaders.userAgentHeader, 'APRSlocus');
        final resp = await req.close();
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join();
          return body;
        }
      } finally {
        client.close(force: true);
      }
    } catch (_) {}
    return null;
  }

  /// 把官方 tocalls.yaml 最小解析为精简 JSON（仅取 classes 与 tocalls 两节，
  /// 忽略 mice/micelegacy —— 那是 mic-E 编码字节识别，本方案只用 to-call）。
  /// 返回 null 表示格式不适用。
  static String? _convertYamlToJson(String yaml) {
    final lines = yaml.split('\n');
    final classes = <String, String>{};
    final devices = <Map<String, String>>[];
    var section = '';
    Map<String, String>? cur;
    const itemRe = r'^\s*-\s+([a-zA-Z0-9_]+):\s*(.*)$';
    const kvRe = r'^(\s*)([a-zA-Z0-9_]+):\s*(.*)$';

    String unq(String s) {
      var v = s.trim();
      if (v.length >= 2 &&
          ((v.startsWith('"') && v.endsWith('"')) ||
              (v.startsWith("'") && v.endsWith("'")))) {
        v = v.substring(1, v.length - 1).trim();
      }
      // 去掉可能的行尾注释（前有空白 #，且 # 不在引号内——本文件值不含 #，简单处理）
      final hash = v.indexOf(' #');
      if (hash >= 0) v = v.substring(0, hash).trim();
      return v;
    }

    for (final rawLine in lines) {
      final line = rawLine; // 保留缩进
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      // 顶层区块头（顶格 + 冒号结尾）：tocalls: / classes: / mice: / micelegacy:
      if (!line.startsWith(' ') && t.endsWith(':') && !t.startsWith('-')) {
        section = t.substring(0, t.length - 1).trim();
        cur = null;
        continue;
      }
      if (section == 'mice' || section == 'micelegacy') continue;
      final im = RegExp(itemRe).firstMatch(line);
      if (im != null) {
        final key = im.group(1)!;
        final val = unq(im.group(2) ?? '');
        if (section == 'tocalls' && key == 'tocall') {
          cur = <String, String>{'tocall': val};
          devices.add(cur);
        } else if (section == 'classes' && key == 'class') {
          cur = <String, String>{'class': val};
          // class 的 shown 在下一行跟随
        }
        continue;
      }
      // 属性行
      final km = RegExp(kvRe).firstMatch(line);
      if (km != null) {
        final indent = km.group(1)!.length;
        final key = km.group(2)!;
        final val = unq(km.group(3) ?? '');
        if (indent <= 0) {
          // 顶层裸 key（非区块头）→ 退出当前小节
          section = '';
          cur = null;
          continue;
        }
        if (cur == null) continue;
        if (section == 'tocalls') {
          // features:/os:/contact: 等多行结构直接忽略，只收单值基础字段
          if ((key == 'vendor' || key == 'model' || key == 'class') &&
              val.isNotEmpty) {
            cur[key] = val;
          }
        } else if (section == 'classes' && cur.containsKey('class')) {
          if (key == 'shown' && val.isNotEmpty) {
            final c = cur['class']!;
            if (!classes.containsKey(c)) classes[c] = val;
          }
        }
      }
    }

    // 汇总：to-call 条目带 vendor/model（仅模型名也可保留）
    final out = <Map<String, String>>[];
    for (final d in devices) {
      final pat = (d['tocall'] ?? '').trim();
      if (pat.isEmpty) continue;
      final vendor = (d['vendor'] ?? '').trim();
      final model = (d['model'] ?? '').trim();
      final cls = (d['class'] ?? '').trim();
      if (model.isEmpty) continue; // 无型号名的空登记（如纯占位）跳过
      out.add({'p': pat, 'v': vendor, 'm': model, 'c': cls});
    }

    if (out.isEmpty) return null;
    final result = {
      'schema': 1,
      'classes': classes,
      'devices': out,
    };
    return jsonEncode(result);
  }
}
