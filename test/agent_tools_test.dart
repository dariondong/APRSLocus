import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aprslocus/agent.dart';
import 'package:aprslocus/agent_tools.dart';
import 'package:aprslocus/models.dart';
import 'package:aprslocus/state.dart';

/// 智能体「工具层」的回归测试。
///
/// 这一层是**模型与 AppState 之间唯一的写入通道**：模型说了改设置、发消息，
/// 真正落地的就是这里。几类错误在 analyze / 编译下全绿，只有真机点到才发现，
/// 所以在这里钉死：
/// - 权限闸门（没授权不许发消息 / 不许改设置）；
/// - 参数校验（越界值必须被拒，而不是静默写进 state）；
/// - 参数类型（字符串 "30" 与 int 30 都应接受）；
/// - `_val` 的 null 归一（没传的字段不能变成字符串 "null"）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AgentToolOutcome> run(
    AppState st,
    String name,
    Map<String, dynamic> args, {
    bool allowSend = true,
    bool allowSettings = true,
  }) =>
      executeAgentTool(st, name, args,
          allowedSend: allowSend, allowedSettings: allowSettings);

  group('schema', () {
    test('未授权发送时，send_* 工具不出现在 schema 里', () {
      final names = agentToolSchemas(allowSend: false)
          .map((t) => t['function']['name'])
          .toSet();
      expect(names.any((n) => '$n'.startsWith('send_')), isFalse);
      // 只读工具仍在
      expect(names, contains('get_app_state'));

      final withSend = agentToolSchemas(allowSend: true)
          .map((t) => t['function']['name'])
          .toSet();
      expect(withSend, contains('send_message'));
      expect(withSend, contains('send_beacon_now'));
    });
  });

  group('权限闸门', () {
    test('未授权发送：send_message 被拒且不产生消息', () async {
      final st = AppState();
      final before = st.messages.length;
      final r = await run(st, 'send_message', {'to': 'BG7LZQ', 'text': 'hi'},
          allowSend: false);
      expect(r.text, contains('Permission denied'));
      expect(st.messages.length, before);
    });

    test('未授权改设置：set_preferences 被拒且值不变', () async {
      final st = AppState();
      final before = st.darkMode;
      final r = await run(st, 'set_preferences', {'dark_mode': !before},
          allowSettings: false);
      expect(r.text, contains('Permission denied'));
      expect(st.darkMode, before);
    });

    test('navigate 不受「改设置」开关限制（只切页面）', () async {
      final st = AppState();
      final r = await run(st, 'navigate', {'screen': 'map'},
          allowSettings: false);
      expect(r.text, isNot(contains('Permission denied')));
    });
  });

  group('参数校验', () {
    test('非法枚举值被拒、状态不变', () async {
      final st = AppState();
      final before = st.mapType;
      final r = await run(st, 'set_preferences', {'map_type': 'no-such-map'});
      expect(r.text, contains('ERROR'));
      expect(st.mapType, before);
    });

    test('越界的 ui_scale 被拒', () async {
      final st = AppState();
      final before = st.uiScale;
      final r = await run(st, 'set_preferences', {'ui_scale': 5.0});
      expect(r.text, contains('ERROR'));
      expect(st.uiScale, before);
    });

    test('越界的 max_stations 被拒、合法值被接受', () async {
      final st = AppState();
      expect((await run(st, 'set_station_filters', {'max_stations': -1})).text,
          contains('ERROR'));
      final ok = await run(st, 'set_station_filters', {'max_stations': 1234});
      expect(ok.text, isNot(contains('ERROR')));
      expect(st.maxStations, 1234);
    });

    test('字符串数字被接受（模型常把数字当字符串传）', () async {
      final st = AppState();
      final r = await run(st, 'set_station_filters', {'max_stations': '4321'});
      expect(r.text, isNot(contains('ERROR')));
      expect(st.maxStations, 4321);
    });

    test('未知工具名被拒', () async {
      final r = await run(AppState(), 'do_something_wild', {});
      expect(r.text, contains('Unknown tool'));
    });
  });

  group('参数提取（_val 的 null 归一）', () {
    test('缺少 focus_call 时不会拿 "NULL" 去搜台站', () async {
      final st = AppState();
      // 没传 focus_call：若 _val 把 null 变成 "null"，这里会去搜 "NULL" 并
      // 报「Station NULL not found」，而不是正常切到 map 页。
      final r = await run(st, 'navigate', {'screen': 'map'});
      expect(r.text, isNot(contains('not found')));
      expect(r.text, isNot(contains('ERROR')));
    });

    test('search_stations 缺 query 时报错而不是搜 "null"', () async {
      final r = await run(AppState(), 'search_stations', {});
      expect(r.text, contains('ERROR'));
    });
  });

  group('身份信息', () {
    test('set_nickname 同时改呼号/SSID/备注并落盘', () async {
      final st = AppState();
      final r = await run(st, 'set_nickname', {
        'callsign': 'bd7abc',
        'ssid': 7,
        'comment': 'hello',
      });
      expect(r.text, isNot(contains('ERROR')));
      expect(st.myCall, 'BD7ABC');
      expect(st.mySsid, 7);
      expect(st.myComment, 'hello');
      expect(st.myFullCall, 'BD7ABC-7');
    });

    test('非法呼号（含空格）被拒、不改动现有值', () async {
      final st = AppState();
      final before = st.myCall;
      final r = await run(st, 'set_nickname', {'callsign': 'BAD CALL'});
      expect(r.text, contains('ERROR'));
      expect(st.myCall, before);
    });
  });

  group('只读工具', () {
    test('get_app_state 返回可解析的 JSON 且含允许值', () async {
      final st = AppState();
      final r = await run(st, 'get_app_state', {});
      expect(r.text, isNot(contains('ERROR')));
      final decoded = jsonDecodeSafe(r.text);
      expect(decoded, isA<Map>());
      expect((decoded as Map)['allowed_values'], isA<Map>());
    });

    test('list_groups 返回数组', () async {
      final r = await run(AppState(), 'list_groups', {});
      expect(jsonDecodeSafe(r.text), isA<List>());
    });

    test('search_stations 命中已存在的台站', () async {
      final st = AppState();
      st.stations.add(Station(
        call: 'BG7LZQ-9',
        symbol: '>',
        lat: 1,
        lng: 2,
        lastHeard: DateTime.now(),
      ));
      final r = await run(st, 'search_stations', {'query': 'bg7'});
      expect(r.text, contains('BG7LZQ-9'));
    });
  });
}

/// 测试里不想引 dart:convert 只用一次，包一层返回 null 表示解析失败。
Object? jsonDecodeSafe(String s) {
  try {
    return jsonDecode(s);
  } catch (_) {
    return null;
  }
}
