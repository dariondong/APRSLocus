import 'package:aprslocus/state.dart';
import 'package:aprslocus/subscriptions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 订阅命中走系统通知的行为回归。
///
/// 用户的话：「订阅通过系统通知提示啊」——之前命中只进订阅页的记录列表，
/// 离开那个页面就看不到，等于要自己隔一会儿去翻一次。现在命中直接弹通知。
///
/// 这里钉住三件事：
///   ① 命中会弹（一条订阅一个通知位，标题带订阅值，正文是呼号 + 报文内容）；
///   ② 同一条订阅 30 秒内再命中不重复弹，压下的条数在下一条里说明；
///   ③ 关掉页面上那个「系统通知」开关后不再弹，但命中记录照旧（订阅本身不变）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.aprslocus/location');
  final calls = <MethodCall>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// 只统计订阅通知那一条通道方法（同一个通道还有常驻通知等其它方法）
  List<Map<String, dynamic>> subsCalls() => calls
      .where((c) => c.method == 'showSubs')
      .map((c) => Map<String, dynamic>.from(c.arguments as Map))
      .toList();

  Future<AppState> fresh() async {
    final st = AppState();
    // _loadPrefs 是异步的，不等它落地会被它覆盖（与其它状态测试同一套写法）
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return st;
  }

  /// 喂一条别的台站发来的状态报文（走真实的收包路径：解析 → 记账 → 订阅）
  void feed(AppState st, String call, String text) {
    st.debugFeedLine('$call>APRS:>$text');
  }

  test('命中会弹系统通知：标题带订阅值，正文是呼号 + 报文内容', () async {
    final st = await fresh();
    st.addSubscription(SubKind.station, 'BG5CCC');

    feed(st, 'BG5CCC-7', 'hello');

    final sent = subsCalls();
    expect(sent.length, 1, reason: '命中一次就该弹一条通知');
    expect('${sent.first['title']}', contains('BG5CCC'));
    expect('${sent.first['text']}', contains('BG5CCC-7'));
    expect('${sent.first['text']}', contains('hello'));
    expect(sent.first['id'], st.subscriptions.first.id,
        reason: '通知 id 用订阅自己的 id，一条订阅只占一个通知位');

    st.dispose();
  });

  test('30 秒内同一条订阅不再弹，压下的条数在下一条里说明', () async {
    final st = await fresh();
    st.addSubscription(SubKind.station, 'BG5CCC');
    final id = st.subscriptions.first.id;

    feed(st, 'BG5CCC-7', 'one');
    expect(subsCalls().length, 1);

    // 窗口内连着两条：都不弹
    feed(st, 'BG5CCC-7', 'two');
    feed(st, 'BG5CCC-7', 'three');
    expect(subsCalls().length, 1, reason: '限流窗口内不能刷屏');

    // 时间旅行到窗口之外：下一条带上「另有 2 条」
    st.debugAgeSubNotify(id, const Duration(seconds: 31));
    feed(st, 'BG5CCC-7', 'four');
    final sent = subsCalls();
    expect(sent.length, 2);
    expect('${sent.last['text']}', contains('2'),
        reason: '被压下的条数要说明，否则用户以为只命中了一次');

    st.dispose();
  });

  test('关掉「系统通知」后不弹，但命中记录照旧', () async {
    final st = await fresh();
    st.addSubscription(SubKind.station, 'BG5CCC');
    st.setSubsNotify(false);

    feed(st, 'BG5CCC-7', 'quiet');

    expect(subsCalls(), isEmpty);
    expect(st.subHits.length, 1, reason: '关的只是通知，订阅本身照旧记账');
    expect(st.subscriptions.first.hits, 1);

    st.dispose();
  });
}
