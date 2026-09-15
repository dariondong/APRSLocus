import 'package:aprslocus/igate.dart';
import 'package:flutter_test/flutter_test.dart';

/// iGate（网关）逻辑回归测试。
///
/// 网关的两类错误都不会立刻暴露，但都会造成实际伤害，所以逐条钉死：
///   ① **环路** —— 把从 APRS-IS 收到的报文再送回 IS，同一条报文在互联网上
///      无限增殖。判据是 q 构造与 TCPIP*/TCPXX* 路径项。
///   ② **重复注入** —— 同一帧经不同中继路径多次到达，IS 上出现多条相同报文。
void main() {
  group('RF → IS：环路防护（最关键）', () {
    test('路径含 TCPIP* / TCPXX* 的报文绝不能再送回 IS', () {
      for (final line in [
        'BG7LZQ-9>APALOC,TCPIP*:!2230.00N/11400.00E>',
        'BG7LZQ-9>APRS,TCPXX*:>hello',
        'BG7LZQ-9>APALOC,WIDE1-1,TCPIP*:>x',
      ]) {
        final d = Igate.toIs(tnc2: line, myFullCall: 'BA7KSM-10');
        expect(d.ok, isFalse, reason: '漏放会造成 IS 环路: $line');
        expect(d.reason, 'from-is');
      }
    });

    test('路径含 q 构造的报文不能再送回 IS（已被别的网关注入过）', () {
      for (final line in [
        'BG7LZQ-9>APALOC,qAR,BA7KSM-10:>x',
        'BG7LZQ-9>APALOC,WIDE1-1,qAC,BA7KSM:>x',
        'BG7LZQ-9>APALOC,qAZ:>x',
        'BG7LZQ-9>APALOC,qAS,SERVER:>x',
      ]) {
        final d = Igate.toIs(tnc2: line, myFullCall: 'BA7KSM-10');
        expect(d.ok, isFalse, reason: '漏放会造成 IS 环路: $line');
        expect(d.reason, 'has-q-construct');
      }
    });

    test('自己发出的报文不再由自己转一遍（否则自己刷自己）', () {
      final d = Igate.toIs(
          tnc2: 'BA7KSM-10>APALOC:>APRSlocus', myFullCall: 'BA7KSM-10');
      expect(d.ok, isFalse);
      expect(d.reason, 'own-packet');
    });

    test('正常射频报文放行', () {
      final d = Igate.toIs(
        tnc2: 'BG7LZQ-9>APALOC,WIDE1-1,WIDE2-1*:!2230.00N/11400.00E>',
        myFullCall: 'BA7KSM-10',
      );
      expect(d.ok, isTrue);
    });

    test('畸形/空报文不放行（不能把垃圾灌进 IS）', () {
      for (final line in ['', 'no-separator', 'A>:x', 'A>B>']) {
        expect(Igate.toIs(tnc2: line, myFullCall: 'X').ok, isFalse,
            reason: line);
      }
      expect(
          Igate.toIs(tnc2: 'A>B:   ', myFullCall: 'X').reason, 'empty-body');
    });
  });

  group('RF → IS：整行改写（q 构造 / 去星号 / 剥互联网路径）', () {
    test('插入 qAr（单向）与 qAR（双向），大小写有意义', () {
      const rf = 'BG7LZQ-9>APALOC,WIDE1-1,WIDE2-1*:!2230.00N/11400.00E>';
      expect(
        Igate.toIsLine(tnc2: rf, myFullCall: 'BA7KSM-10', twoWay: false),
        'BG7LZQ-9>APALOC,WIDE1-1,WIDE2-1,qAr,BA7KSM-10:!2230.00N/11400.00E>',
      );
      expect(
        Igate.toIsLine(tnc2: rf, myFullCall: 'BA7KSM-10', twoWay: true),
        'BG7LZQ-9>APALOC,WIDE1-1,WIDE2-1,qAR,BA7KSM-10:!2230.00N/11400.00E>',
      );
    });

    test('去掉中继上的 * （* 是本机听到的本地观察，不属于报文本身）', () {
      final out = Igate.toIsLine(
        tnc2: 'A>B,D1*,D2,D3*:x',
        myFullCall: 'ME',
        twoWay: false,
      )!;
      expect(out, 'A>B,D1,D2,D3,qAr,ME:x');
      expect(out.contains('*'), isFalse);
    });

    test('保险：即使混进 TCPIP*/q 构造也会被剥掉', () {
      final out = Igate.toIsLine(
        tnc2: 'A>B,D1,TCPIP*,qAC,SERVER:hello',
        myFullCall: 'ME',
        twoWay: false,
      )!;
      expect(out, 'A>B,D1,qAr,ME:hello');
    });

    test('中继数量截到 AX.25 上限（8 个），不会造出非法帧', () {
      final digis = List.generate(12, (i) => 'D$i').join(',');
      final out = Igate.toIsLine(
        tnc2: 'A>B,$digis:x',
        myFullCall: 'ME',
        twoWay: false,
      )!;
      final path = out.substring(out.indexOf('>') + 1, out.indexOf(':'));
      // 目的 + 中继(≤8) + q 构造 + 网关呼号
      expect(path.split(',').length,
          lessThanOrEqualTo(Igate.maxRfDigis + 3));
    });

    test('信息字段原样保留（含中文与冒号，不能被二次切割）', () {
      const body = '::BA7KSM  :你好: 世界';
      final out = Igate.toIsLine(
        tnc2: 'A>B,WIDE1*:$body',
        myFullCall: 'ME',
        twoWay: false,
      )!;
      expect(out.endsWith(':$body'), isTrue, reason: '信息字段必须完整保留');
    });

    test('畸形报文返回 null 而不是抛出', () {
      expect(Igate.toIsLine(tnc2: 'junk', myFullCall: 'ME', twoWay: false),
          isNull);
    });
  });

  group('IS → RF：只转点对点消息，且收件人必须刚在射频上听到过', () {
    test('转给「刚听到过」的台站', () {
      final d = Igate.toRf(
        tnc2: 'BG7LZQ-9>APRS,TCPIP*,qAC,X::BA7KSM   :hi{AB1',
        heardOnRf: {'BA7KSM'},
        myFullCall: 'ME-10',
        allowMessages: true,
      );
      expect(d.ok, isTrue);
    });

    test('收件人没在射频上听到过 → 不转（射频上没人能收到，白占时隙）', () {
      final d = Igate.toRf(
        tnc2: 'BG7LZQ-9>APRS,TCPIP*::BA7KSM   :hi',
        heardOnRf: {'OTHER'},
        myFullCall: 'ME',
        allowMessages: true,
      );
      expect(d.ok, isFalse);
      expect(d.reason, 'addressee-not-heard');
    });

    test('位置/天气等广播报文不转（避免占满信道）', () {
      for (final body in [
        '!2230.00N/11400.00E>',
        '>status text',
        '_10000000...',
        'T#123,456,789',
      ]) {
        final d = Igate.toRf(
          tnc2: 'A>APRS,TCPIP*:$body',
          heardOnRf: {'BA7KSM'},
          myFullCall: 'ME',
          allowMessages: true,
        );
        expect(d.ok, isFalse, reason: '不该转: $body');
        expect(d.reason, 'not-a-message');
      }
    });

    test('开关关闭时一律不转（默认就是关的，射频发射需显式同意）', () {
      final d = Igate.toRf(
        tnc2: 'A>APRS,TCPIP*::BA7KSM   :hi',
        heardOnRf: {'BA7KSM'},
        myFullCall: 'ME',
        allowMessages: false,
      );
      expect(d.ok, isFalse);
      expect(d.reason, 'is-to-rf-off');
    });

    test('自己发出的报文不回转（防止与 RF→IS 组成回环）', () {
      final d = Igate.toRf(
        tnc2: 'ME-10>APRS,TCPIP*::BA7KSM   :hi',
        heardOnRf: {'BA7KSM'},
        myFullCall: 'ME-10',
        allowMessages: true,
      );
      expect(d.ok, isFalse);
      expect(d.reason, 'own-packet');
    });

    test('改写为射频整行：剥掉所有互联网路径项，接上本机射频中继', () {
      final out = Igate.toRfLine(
        tnc2: 'BG7LZQ-9>APRS,TCPIP*,qAC,SERVER::BA7KSM   :hi{AB1',
        rfPath: 'WIDE1-1,WIDE2-1',
      )!;
      expect(out,
          'BG7LZQ-9>APRS,WIDE1-1,WIDE2-1::BA7KSM   :hi{AB1');
      expect(out.contains('TCPIP'), isFalse);
      expect(out.contains('qA'), isFalse);
      expect(out.contains('SERVER'), isFalse);
    });

    test('射频中继路径为空时不硬塞逗号', () {
      final out = Igate.toRfLine(
        tnc2: 'A>APRS,TCPIP*::B   :x',
        rfPath: '',
      )!;
      expect(out, 'A>APRS::B   :x');
      expect(out.contains(',,'), isFalse);
    });
  });

  group('消息收件人解析', () {
    test('按 9 字符字段取值并去掉补位空格', () {
      expect(Igate.messageAddressee(':BA7KSM   :body'), 'BA7KSM');
      expect(Igate.messageAddressee(':BG7LZQ-9:body'), 'BG7LZQ-9');
    });
    test('非消息报文返回 null', () {
      expect(Igate.messageAddressee('!2230.00N>'), isNull);
      expect(Igate.messageAddressee(':no-colon'), isNull);
    });
  });

  group('去重（同一帧经多路径到达只能注入一次）', () {
    test('同样内容不同中继路径 → 视为同一条', () {
      final a = Igate.dedupeKey('A>B,D1*:hello');
      final b = Igate.dedupeKey('A>B,D1,D2*:hello');
      final c = Igate.dedupeKey('A>B:hello');
      expect(a, b);
      expect(b, c);
    });

    test('信息字段不同 → 视为不同报文', () {
      expect(Igate.dedupeKey('A>B:hi'),
          isNot(Igate.dedupeKey('A>B:hi2')));
    });

    test('窗口内重复被拒、窗口外放行', () {
      final d = GateDedupe();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      expect(d.accept('k', window: const Duration(seconds: 30), now: t0), isTrue);
      expect(
          d.accept('k',
              window: const Duration(seconds: 30),
              now: t0.add(const Duration(seconds: 10))),
          isFalse,
          reason: '30 秒内重复必须丢弃，否则 IS 上会出现多条相同报文');
      expect(
          d.accept('k',
              window: const Duration(seconds: 30),
              now: t0.add(const Duration(seconds: 31))),
          isTrue);
    });

    test('长期运行不会无限增长（过期项会被清理）', () {
      final d = GateDedupe();
      final t0 = DateTime(2026, 1, 1);
      // 时间必须**推进**：若所有条目时间戳相同，就没有任何一条是「过期」的，
      // 清理自然不会发生（那是测试前提错了，不是实现的问题）
      for (var i = 0; i < 1000; i++) {
        d.accept('key$i',
            window: const Duration(seconds: 1),
            now: t0.add(Duration(seconds: i * 2)));
      }
      // 断言的是「**有界**」而不是「很小」：清理是按阈值触发的，
      // 上界就是阈值本身再加一条刚插入的
      expect(d.size, lessThanOrEqualTo(GateDedupe.maxEntries + 1),
          reason: '过期项应被清理，内存占用必须有界（不能随运行时间线性增长）');
    });
  });

  group('射频「听到过」列表', () {
    test('过期后不再认为该台站还在射频上', () {
      final h = HeardList(ttl: const Duration(minutes: 30));
      final t0 = DateTime(2026, 1, 1, 12, 0);
      h.heard('ba7ksm', now: t0);
      expect(h.contains('BA7KSM', now: t0.add(const Duration(minutes: 10))),
          isTrue);
      expect(h.contains('BA7KSM', now: t0.add(const Duration(minutes: 40))),
          isFalse,
          reason: '台站可能已走远，过期后不该再往射频转消息');
      expect(h.active(now: t0.add(const Duration(minutes: 40))), isEmpty);
    });

    test('呼号大小写不敏感', () {
      final h = HeardList();
      h.heard('ba7ksm');
      expect(h.contains('BA7KSM'), isTrue);
    });
  });
}
