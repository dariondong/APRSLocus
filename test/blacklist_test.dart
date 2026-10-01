/// 远程限制名单（黑名单）的解析与命中判断回归测试。
///
/// 这份逻辑的价值全在**边界**上，平时看不出来：
///   * 名单拉不到 / JSON 坏了 → 必须**放行**（否则一次网络抖动就把所有人挡在门外）；
///   * 条目格式不对（小写呼号、空条目）→ 必须**不误伤**，也不能静默命中错的人；
///   * 命中判断要大小写不敏感、去空白（手写名单很容易大小写不一致）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aprslocus/blacklist.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('解析', () {
    test('正常名单', () {
      final bl = Blacklist.parse('''
{"updated":"2026-10-01","entries":[
  {"call":"BG7LZQ-9","reason":"测试","at":"2026-10-01"},
  {"device":"0123456789abcdef0123456789abcdef","reason":"测试"}]}''');
      expect(bl, isNotNull);
      expect(bl!.entries.length, 2);
      expect(bl.entries.first.call, 'BG7LZQ-9');
    });

    test('坏 JSON → null（调用方按"失败放行"处理）', () {
      expect(Blacklist.parse('{ this is not json'), isNull);
      expect(Blacklist.parse(''), isNull);
      expect(Blacklist.parse('[]'), isNull);          // 顶层不是对象
      expect(Blacklist.parse('{"updated":"x"}'), isNull);  // 没有 entries
    });

    test('空条目被丢掉（防止手滑写个空对象把所有人拦下）', () {
      final bl = Blacklist.parse(
          '{"entries":[{"reason":"oops"},{"call":"A1AAA","reason":"x"}]}')!;
      expect(bl.entries.length, 1);
      expect(bl.entries.single.call, 'A1AAA');
    });

    test('呼号统一大写、标识统一小写', () {
      final bl = Blacklist.parse(
          '{"entries":[{"call":"bg7lzq-9","device":"ABCDEF","reason":"x"}]}')!;
      expect(bl.entries.single.call, 'BG7LZQ-9');
      expect(bl.entries.single.device, 'abcdef');
    });
  });

  group('命中判断', () {
    final bl = Blacklist.parse('{"entries":['
        '{"call":"BG7LZQ-9","reason":"呼号命中"},'
        '{"device":"0123456789abcdef0123456789abcdef","reason":"设备命中"}]}')!;

    test('按呼号命中（大小写/空白不敏感）', () {
      final hit = bl.match('  bg7lzq-9 ', 'ffff');
      expect(hit, isNotNull);
      expect(hit!.reason, '呼号命中');
      expect(hit.matched, 'BG7LZQ-9');
    });

    test('按安装标识命中', () {
      final hit = bl.match('BA1AAA', '0123456789ABCDEF0123456789ABCDEF');
      expect(hit, isNotNull);
      expect(hit!.matched, '0123456789abcdef0123456789abcdef');
    });

    test('不在名单里 → null', () {
      expect(bl.match('BA1AAA', 'ffff'), isNull);
    });

    test('空呼号 / 空标识**不**命中空条目', () {
      final e = Blacklist.parse('{"entries":[{"call":"X","reason":"r"}]}')!;
      expect(e.match('', ''), isNull);
    });
  });

  group('呼号通配符', () {
    test('B-* ：任意 SSID，**并含不带 SSID 的那个**', () {
      final bl = Blacklist.parse(
          '{"entries":[{"call":"BG7LZQ-*","reason":"任意 SSID"}]}')!;
      for (final c in ['BG7LZQ', 'BG7LZQ-0', 'BG7LZQ-7', 'bg7lzq-15']) {
        expect(bl.match(c, '')?.matched, 'BG7LZQ-*', reason: '该命中：$c');
      }
      for (final c in ['BG7LZQ2', 'BG7LZQ-1A', 'BA7LZQ-7', 'BG7LZ']) {
        expect(bl.match(c, ''), isNull, reason: '不该命中：$c');
      }
    });

    test('其他位置的 * 是任意串', () {
      final bl = Blacklist.parse('{"entries":['
          '{"call":"BH7*","reason":"前缀"},'
          '{"call":"*LZQ-9","reason":"后缀"}]}')!;
      expect(bl.match('BH7GZB-3', '')?.reason, '前缀');
      expect(bl.match('bg7lzq-9', '')?.reason, '后缀');
      expect(bl.match('BH7GZB', '')?.reason, '前缀');
      expect(bl.match('BG7LZQ-7', ''), isNull);
    });

    test('不带 * 仍是完全相等（有通配符不等于放松匹配）', () {
      final bl = Blacklist.parse(
          '{"entries":[{"call":"BG7LZQ-7","reason":"exact"}]}')!;
      expect(bl.match('BG7LZQ-7', ''), isNotNull);
      expect(bl.match('BG7LZQ', ''), isNull, reason: '不带 SSID 的那个不该命中');
      expect(bl.match('BG7LZQ-9', ''), isNull);
    });

    test('只有通配符的条目被丢弃（防手滑把所有人拦下）', () {
      final bl = Blacklist.parse('{"entries":['
          '{"call":"*","reason":"oops"},'
          '{"call":"-*","reason":"oops"},'
          '{"call":"BG7LZQ-*","reason":"ok"}]}')!;
      expect(bl.entries.length, 1, reason: '只该留下带真实呼号的那条');
      expect(bl.match('BA1AAA-1', ''), isNull);
      expect(bl.match('BG7LZQ-1', ''), isNotNull);
    });
  });

  group('本地缓存与安装标识', () {
    test('安装标识随机生成一次后稳定（且是本机才有，不上传）', () async {
      final a = await Blacklist.deviceId();
      final b = await Blacklist.deviceId();
      expect(a, isNotEmpty);
      expect(a.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(a), isTrue,
          reason: '格式要和官网名单里写的 device 一致（32 位小写十六进制）');
      expect(b, a);
    });

    test('没有缓存时 cached()/lastChecked() 返回 null（= 失败放行）', () async {
      expect(await Blacklist.cached(), isNull);
      expect(await Blacklist.lastChecked(), isNull);
    });
  });
}
