/// ─── 智能体工具（把 AppState 暴露成模型可调用的函数）───
///
/// [agent.dart] 只认「工具 schema + 执行器」两块数据，具体的工具都在这里实现。
/// 之所以单独一个文件：工具要 import `state.dart`，而 `state.dart` 反过来又要
/// import `agent.dart`（读配置、把 Key 纳入出厂清理）—— 两者若合在一起就循环导入。
///
/// ## 设计取舍
///
/// * 工具集**刻意不含**连接/断开、重启、清空数据这类「一刀切且可能把用户挡在
///   门外」的操作。智能体的价值是「动动嘴就把常用设置调好」，不是替代遥控。
/// * 每个工具都做**参数校验**（枚举值、范围），非法参数直接把错误文本回给模型，
///   让模型自己纠正 —— 比抛异常中断整轮对话好。
/// * 展示给用户的 `note` 保持简洁（工具名 + 关键参数），给用户看的自然语言解释
///   由模型回复给出，避免为几十个工具各配一套本地化文案。
library;

import 'dart:convert';

import 'agent.dart';
import 'map_math.dart';
import 'state.dart';

/// 工具定义：名称、说明（给模型看）、参数 schema、是否有副作用。
class AgentToolSpec {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  /// 有副作用、需要用户确认（发送/改设置=true；只读=false）
  final bool mutating;

  const AgentToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
    this.mutating = false,
  });

  Map<String, dynamic> toSchema() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
}

const _str = {'type': 'string'};
const _bool = {'type': 'boolean'};

/// 工具 schema 列表（发给模型的 tools 字段）
final List<AgentToolSpec> kAgentTools = [
  const AgentToolSpec(
    name: 'get_app_state',
    description:
        'Read the current app state: my callsign, connection status, tracking '
        '(beacon) settings, preference values, counts of stations/messages/'
        'groups, and the allowed value ranges for settings. Call this before '
        'changing settings or sending messages.',
    parameters: {'type': 'object', 'properties': {}},
  ),
  const AgentToolSpec(
    name: 'list_groups',
    description: 'List chat groups the user has joined (name + group call).',
    parameters: {'type': 'object', 'properties': {}},
  ),
  const AgentToolSpec(
    name: 'search_stations',
    description:
        'Search recently heard APRS stations by callsign substring. Returns '
        'callsign, position and how long ago it was heard.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'Callsign or substring to search for.',
        },
      },
      'required': ['query'],
    },
  ),
  const AgentToolSpec(
    name: 'send_message',
    description:
        'Send an APRS text message to a callsign, or to a group by its group '
        'call. Requires the "allow sending messages" permission.',
    mutating: true,
    parameters: {
      'type': 'object',
      'properties': {
        'to': {'type': 'string', 'description': 'Destination callsign.'},
        'text': {'type': 'string', 'description': 'Message body.'},
      },
      'required': ['to', 'text'],
    },
  ),
  const AgentToolSpec(
    name: 'send_beacon_now',
    description: 'Immediately send one position beacon.',
    mutating: true,
    parameters: {'type': 'object', 'properties': {}},
  ),
  const AgentToolSpec(
    name: 'set_tracking',
    description:
        'Enable/disable and configure automatic position reporting (beacon). '
        'Only the provided fields are changed. This enables or disables '
        'tracking directly; it is unrelated to "beacon auto-start on launch".',
    mutating: true,
    parameters: {
      'type': 'object',
      'properties': {
        'beacon_enabled': {
          'type': 'boolean',
          'description': 'true = enable tracking now, false = stop tracking.',
        },
        'beacon_interval_sec': {'type': 'integer', 'description': '5..3600'},
        'beacon_net_interval_sec': {
          'type': 'integer',
          'description': '30..3600 (network-only mode)',
        },
        'smart_beacon': _bool,
        'include_speed': _bool,
        'include_course': _bool,
        'include_battery': _bool,
        'include_hr': _bool,
        'include_steps': _bool,
        'include_trip_mileage': _bool,
        'include_total_mileage': _bool,
      },
    },
  ),
  const AgentToolSpec(
    name: 'set_station_filters',
    description: 'Change which stations are displayed and how many are kept.',
    mutating: true,
    parameters: {
      'type': 'object',
      'properties': {
        'receive_others': _bool,
        'max_stations': {'type': 'integer', 'description': '0..5000'},
        'max_packets': {'type': 'integer', 'description': '0..20000'},
        'max_track_points': {'type': 'integer', 'description': '0..5000'},
        'retention_days': {'type': 'integer', 'description': '0..3650'},
      },
    },
  ),
  const AgentToolSpec(
    name: 'set_preferences',
    description:
        'Change general preferences: language, dark mode, UI layout, UI '
        'scale, map type, interface material, weather, sensor assist, heat '
        'level. Only the provided fields change.',
    mutating: true,
    parameters: {
      'type': 'object',
      'properties': {
        'language': {
          'type': 'string',
          'description': 'One of: zh, zh_TW, en, ja, es, id.',
        },
        'dark_mode': _bool,
        'ui_layout': {
          'type': 'string',
          'description': 'classic or sheet (2.0).',
        },
        'ui_scale': {'type': 'number', 'description': '0.85..1.3'},
        'map_type': _str,
        'ui_material': {
          'type': 'string',
          'description': 'none, glass, mica or glass_full.',
        },
        'weather': _bool,
        'sensor_assist': _bool,
        'heat_level': {'type': 'integer', 'description': '0..2'},
      },
    },
  ),
  const AgentToolSpec(
    name: 'set_nickname',
    description: "Change the user's own callsign, SSID, symbol or comment.",
    mutating: true,
    parameters: {
      'type': 'object',
      'properties': {
        'callsign': _str,
        'ssid': {'type': 'integer', 'description': '0..15'},
        'symbol': _str,
        'comment': _str,
      },
    },
  ),
  const AgentToolSpec(
    name: 'navigate',
    description:
        'Switch the app to a screen and optionally focus a station on the '
        'map: screen = map/stations/messages/data/settings; or pass focus_call '
        'to center the map on that station.',
    mutating: true,
    parameters: {
      'type': 'object',
      'properties': {
        'screen': {
          'type': 'string',
          'description': 'map, stations, messages, data or settings.',
        },
        'focus_call': {
          'type': 'string',
          'description': 'Callsign to focus on the map.',
        },
      },
    },
  ),
];

/// 名称 → spec
final Map<String, AgentToolSpec> _byName = {
  for (final t in kAgentTools) t.name: t,
};

/// 允许的底图名（来自 [MapType]，避免两处漂移）
final List<String> _mapTypeNames =
    MapType.values.map((e) => e.name).toList(growable: false);

/// 允许切换的页签名 → 页签编号（两套外壳一致）
const Map<String, int> _screens = {
  'map': 0,
  'stations': 1,
  'messages': 2,
  'data': 3,
  'settings': 4,
};

/// 发给模型的 schema 列表。
///
/// 未开启发送权限时连 `send_*` 的 schema 都不给 —— 既有明确的权限边界，
/// 也避免模型反复尝试一个注定被拒的操作。
List<Map<String, dynamic>> agentToolSchemas({required bool allowSend}) => [
      for (final t in kAgentTools)
        if (allowSend || !t.name.startsWith('send_')) t.toSchema(),
    ];

String _val(Map<String, dynamic> a, String k) {
  final v = a[k];
  // 注意：不能用 '$v' 直接插值 —— 缺省/显式 null 会变成字符串 "null"，
  // 让「没传 focus_call」被当成呼号 "NULL" 去搜索。这里统一归一为 ''。
  if (v == null) return '';
  return '$v';
}

int? _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

double? _asDouble(Object? v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

bool? _asBool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    switch (v.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'off':
        return false;
    }
  }
  return null;
}

AgentToolOutcome _err(String msg) => AgentToolOutcome('ERROR: $msg');

/// 执行一个工具调用。
///
/// [allowedSend] / [allowedSettings] 来自配置的权限开关；未授权时返回错误文本
/// （模型会据此告知用户去打开权限）。
Future<AgentToolOutcome> executeAgentTool(
  AppState st,
  String name,
  Map<String, dynamic> args, {
  required bool allowedSend,
  required bool allowedSettings,
}) async {
  final spec = _byName[name];
  if (spec == null) return _err('Unknown tool: $name');

  // 权限闸门（schema 层已隐藏 send_*，但模型仍可能凭空调用）
  if (name.startsWith('send_') && !allowedSend) {
    return _err('Permission denied: sending messages is disabled in settings.');
  }
  if (spec.mutating && name != 'navigate' && !allowedSettings) {
    return _err('Permission denied: changing settings is disabled.');
  }

  switch (name) {
    case 'get_app_state':
      return AgentToolOutcome(jsonEncode({
        'my_callsign': st.myFullCall,
        'my_symbol': st.mySymbol,
        'my_comment': st.myComment,
        'connected': st.connected,
        'using_rf': st.usingRf,
        'stations': st.stations.length,
        'messages': st.messages.length,
        'groups': st.chatGroups.length,
        'tracking': {
          'beacon_enabled': st.beaconEnabled,
          'beacon_interval_sec': st.beaconInterval,
          'beacon_net_interval_sec': st.beaconNetInterval,
          'smart_beacon': st.smartBeaconEnabled,
          'include_speed': st.beaconIncludeSpeed,
          'include_course': st.beaconIncludeCourse,
          'include_battery': st.beaconIncludeBattery,
          'include_hr': st.beaconIncludeHr,
        },
        'preferences': {
          'language': st.locale,
          'dark_mode': st.darkMode,
          'ui_layout': st.uiLayout,
          'ui_scale': st.uiScale,
          'map_type': st.mapType,
          'ui_material': st.uiMaterial,
          'weather': st.weatherEnabled,
          'sensor_assist': st.sensorAssist,
        },
        'allowed_values': {
          'language': const ['zh', 'zh_TW', 'en', 'ja', 'es', 'id'],
          'ui_layout': const ['classic', 'sheet'],
          'ui_material': const ['none', 'glass', 'mica', 'glass_full'],
          'map_type': _mapTypeNames,
          'screen': _screens.keys.toList(),
        },
      }));

    case 'list_groups':
      return AgentToolOutcome(jsonEncode([
        for (final g in st.chatGroups) {'name': g.name, 'call': g.groupCall},
      ]));

    case 'search_stations':
      {
        final q = _val(args, 'query').trim().toUpperCase();
        if (q.isEmpty) return _err('query is required');
        final hits =
            st.stations.where((s) => s.call.toUpperCase().contains(q)).take(20);
        final list = [
          for (final s in hits)
            {
              'call': s.call,
              'lat': s.lat,
              'lng': s.lng,
              'comment': s.comment,
              'heard_min_ago': DateTime.now().difference(s.lastHeard).inMinutes,
            },
        ];
        return AgentToolOutcome(jsonEncode(list),
            note: 'search_stations "$q" → ${list.length}');
      }

    case 'send_message':
      {
        final to = _val(args, 'to').trim().toUpperCase();
        final text = _val(args, 'text').trim();
        if (to.isEmpty || text.isEmpty) {
          return _err('"to" and "text" are required');
        }
        if (st.usingRf && text.length > 67) {
          return _err('Radio mode limits a message to 67 characters.');
        }
        st.sendMessage(to, text);
        return AgentToolOutcome('Message queued to $to: $text',
            note: 'send_message → $to');
      }

    case 'send_beacon_now':
      if (!st.myPositionReportable) {
        return _err('No usable GPS fix yet; beacon not sent.');
      }
      st.sendBeacon();
      return AgentToolOutcome('Beacon sent.', note: 'send_beacon_now');

    case 'set_tracking':
      {
        final changed = <String>[];
        if (args.containsKey('beacon_enabled')) {
          final b = _asBool(args['beacon_enabled']);
          if (b == null) return _err('beacon_enabled must be a boolean');
          st.setBeaconEnabled(b);
          changed.add('beacon_enabled');
        }
        if (args.containsKey('beacon_interval_sec')) {
          final n = _asInt(args['beacon_interval_sec']);
          if (n == null || n < 5 || n > 3600) {
            return _err('beacon_interval_sec must be 5..3600');
          }
          st.setBeaconInterval(n);
          changed.add('beacon_interval_sec');
        }
        if (args.containsKey('beacon_net_interval_sec')) {
          final n = _asInt(args['beacon_net_interval_sec']);
          if (n == null || n < 30 || n > 3600) {
            return _err('beacon_net_interval_sec must be 30..3600');
          }
          st.setBeaconNetInterval(n);
          changed.add('beacon_net_interval_sec');
        }
        final bools = <String, void Function(bool)>{
          'smart_beacon': st.setSmartBeaconOn,
          'include_speed': st.setBeaconIncludeSpeed,
          'include_course': st.setBeaconIncludeCourse,
          'include_battery': st.setBeaconIncludeBattery,
          'include_hr': st.setBeaconIncludeHr,
          'include_steps': st.setBeaconIncludeSteps,
          'include_trip_mileage': st.setBeaconIncludeTripMileage,
          'include_total_mileage': st.setBeaconIncludeTotalMileage,
        };
        for (final e in bools.entries) {
          if (!args.containsKey(e.key)) continue;
          final b = _asBool(args[e.key]);
          if (b == null) return _err('${e.key} must be a boolean');
          e.value(b);
          changed.add(e.key);
        }
        if (changed.isEmpty) return _err('No tracked fields provided.');
        return AgentToolOutcome('Updated tracking: ${changed.join(', ')}',
            note: 'set_tracking ${changed.join(', ')}');
      }

    case 'set_station_filters':
      {
        final changed = <String>[];
        if (args.containsKey('receive_others')) {
          final b = _asBool(args['receive_others']);
          if (b == null) return _err('receive_others must be a boolean');
          st.setReceiveOthers(b);
          changed.add('receive_others');
        }
        if (args.containsKey('max_stations')) {
          final n = _asInt(args['max_stations']);
          if (n == null || n < 0 || n > 5000) {
            return _err('max_stations must be 0..5000');
          }
          st.setMaxStations(n);
          changed.add('max_stations');
        }
        if (args.containsKey('max_packets')) {
          final n = _asInt(args['max_packets']);
          if (n == null || n < 0 || n > 20000) {
            return _err('max_packets must be 0..20000');
          }
          st.setMaxPackets(n);
          changed.add('max_packets');
        }
        if (args.containsKey('max_track_points')) {
          final n = _asInt(args['max_track_points']);
          if (n == null || n < 0 || n > 5000) {
            return _err('max_track_points must be 0..5000');
          }
          st.setMaxTrackPts(n);
          changed.add('max_track_points');
        }
        if (args.containsKey('retention_days')) {
          final n = _asInt(args['retention_days']);
          if (n == null || n < 0 || n > 3650) {
            return _err('retention_days must be 0..3650');
          }
          st.setStationRetentionDays(n);
          changed.add('retention_days');
        }
        if (changed.isEmpty) return _err('No fields provided.');
        return AgentToolOutcome('Updated filters: ${changed.join(', ')}',
            note: 'set_station_filters ${changed.join(', ')}');
      }

    case 'set_preferences':
      {
        final changed = <String>[];
        if (args.containsKey('language')) {
          final v = _val(args, 'language');
          if (!const ['zh', 'zh_TW', 'en', 'ja', 'es', 'id'].contains(v)) {
            return _err('language must be one of zh, zh_TW, en, ja, es, id');
          }
          st.setLocale(v);
          changed.add('language=$v');
        }
        if (args.containsKey('dark_mode')) {
          final b = _asBool(args['dark_mode']);
          if (b == null) return _err('dark_mode must be a boolean');
          st.setDarkMode(b);
          changed.add('dark_mode=$b');
        }
        if (args.containsKey('ui_layout')) {
          final v = _val(args, 'ui_layout');
          if (v != 'classic' && v != 'sheet') {
            return _err('ui_layout must be classic or sheet');
          }
          st.setUiLayout(v);
          changed.add('ui_layout=$v');
        }
        if (args.containsKey('ui_scale')) {
          final d = _asDouble(args['ui_scale']);
          if (d == null || d < 0.85 || d > 1.3) {
            return _err('ui_scale must be 0.85..1.3');
          }
          st.setUiScale(d);
          changed.add('ui_scale=$d');
        }
        if (args.containsKey('map_type')) {
          final v = _val(args, 'map_type');
          if (!_mapTypeNames.contains(v)) {
            return _err('map_type must be one of ${_mapTypeNames.join(', ')}');
          }
          st.setMapType(v);
          changed.add('map_type=$v');
        }
        if (args.containsKey('ui_material')) {
          final v = _val(args, 'ui_material');
          if (!const ['none', 'glass', 'mica', 'glass_full'].contains(v)) {
            return _err('ui_material must be none, glass, mica or glass_full');
          }
          st.setUiMaterial(v);
          changed.add('ui_material=$v');
        }
        if (args.containsKey('weather')) {
          final b = _asBool(args['weather']);
          if (b == null) return _err('weather must be a boolean');
          st.setWeatherEnabled(b);
          changed.add('weather=$b');
        }
        if (args.containsKey('sensor_assist')) {
          final b = _asBool(args['sensor_assist']);
          if (b == null) return _err('sensor_assist must be a boolean');
          st.setSensorAssist(b);
          changed.add('sensor_assist=$b');
        }
        if (args.containsKey('heat_level')) {
          final n = _asInt(args['heat_level']);
          if (n == null || n < 0 || n > 2) {
            return _err('heat_level must be 0..2');
          }
          st.setHeatLevel(n);
          changed.add('heat_level=$n');
        }
        if (changed.isEmpty) return _err('No fields provided.');
        return AgentToolOutcome(
            'Updated preferences: ${changed.join(', ')}',
            note: 'set_preferences ${changed.join(', ')}');
      }

    case 'set_nickname':
      {
        final changed = <String>[];
        if (args.containsKey('callsign')) {
          final v = _val(args, 'callsign').trim().toUpperCase();
          if (v.isEmpty || v.length > 10 || v.contains(RegExp(r'\s'))) {
            return _err('callsign must be 1..10 non-space characters');
          }
          st.myCall = v;
          changed.add('callsign=$v');
        }
        if (args.containsKey('ssid')) {
          final n = _asInt(args['ssid']);
          if (n == null || n < 0 || n > 15) return _err('ssid must be 0..15');
          st.mySsid = n;
          changed.add('ssid=$n');
        }
        if (args.containsKey('symbol')) {
          final v = _val(args, 'symbol');
          if (v.isEmpty || v.length > 2) {
            return _err('symbol must be 1..2 characters');
          }
          st.mySymbol = v;
          changed.add('symbol=$v');
        }
        if (args.containsKey('comment')) {
          st.myComment = _val(args, 'comment').trim();
          changed.add('comment');
        }
        if (changed.isEmpty) return _err('No fields provided.');
        st.persist();
        return AgentToolOutcome(
            'Updated station identity: ${changed.join(', ')}',
            note: 'set_nickname ${changed.join(', ')}');
      }

    case 'navigate':
      {
        final focus = _val(args, 'focus_call').trim().toUpperCase();
        if (focus.isNotEmpty) {
          // 精确匹配优先，退而求其次按包含匹配
          final exact =
              st.stations.where((s) => s.call.toUpperCase() == focus).toList();
          final matches = exact.isEmpty
              ? st.stations
                  .where((s) => s.call.toUpperCase().contains(focus))
                  .toList()
              : exact;
          if (matches.isEmpty) return _err('Station $focus not found.');
          st.focusOnMap(matches.first);
          st.requestTab(0);
          return AgentToolOutcome(
              'Centered map on ${matches.first.call}.',
              note: 'navigate → map (${matches.first.call})');
        }
        final screen = _val(args, 'screen').trim().toLowerCase();
        final idx = _screens[screen];
        if (idx == null) {
          return _err('screen must be one of ${_screens.keys.join(', ')}');
        }
        st.requestTab(idx);
        return AgentToolOutcome('Switched to $screen screen.',
            note: 'navigate → $screen');
      }
  }
  return _err('Unhandled tool: $name');
}
