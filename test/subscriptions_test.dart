import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/models.dart';
import 'package:aprslocus/subscriptions.dart';

Packet pkt(String raw,
        {String src = 'BG7LZQ-9',
        String? info,
        String type = 'position'}) =>
    Packet(
      raw,
      src,
      'APRS',
      type,
      DateTime(2026, 10, 26, 12),
      info: info,
    );

void main() {
  group('订阅匹配', () {
    test('台站：省略 SSID 时覆盖它的全部 SSID', () {
      final r = SubRule(id: 'a', kind: SubKind.station, value: 'bg7lzq');
      expect(subMatches(r, pkt('BG7LZQ-9>APRS:!3905.45N/07223.83W-')), isTrue);
      expect(subMatches(r, pkt('BG7LZQ>APRS:!3905.45N/07223.83W-', src: 'BG7LZQ')),
          isTrue);
      expect(subMatches(r, pkt('BG5CCC-7>APRS:!3905.45N/07223.83W-', src: 'BG5CCC-7')),
          isFalse);
    });

    test('台站：通配前缀', () {
      final r = SubRule(id: 'a', kind: SubKind.station, value: 'BG7*');
      expect(subMatches(r, pkt('X>APRS:', src: 'BG7LZQ-7')), isTrue);
      expect(subMatches(r, pkt('X>APRS:', src: 'BG5CCC-7')), isFalse);
    });

    test('中继：报文路径里出现它才算', () {
      final r = SubRule(id: 'b', kind: SubKind.digi, value: 'BH6RIZ-6');
      expect(
          subMatches(
              r, pkt('BG7LZQ-9>APRS,BH6RIZ-6*,WIDE2-1:!3905.45N/07223.83W-')),
          isTrue);
      expect(subMatches(r, pkt('BG7LZQ-9>APRS,WIDE2-1:!3905.45N/07223.83W-')),
          isFalse);
      // 只发不收的本机报文没有路径，不该命中任何中继
      expect(subMatches(r, pkt('BG7LZQ-9>APRS:!3905.45N/07223.83W-')), isFalse);
    });

    test('关键词：原文与摘要都看，大小写不敏感', () {
      final r = SubRule(id: 'c', kind: SubKind.keyword, value: 'APRSlocus');
      expect(
          subMatches(
              r,
              pkt('BG5CCC-7>APRS:>APRSlocus CONNECT v2.1.34 android',
                  src: 'BG5CCC-7')),
          isTrue);
      expect(subMatches(r, pkt('BG5CCC-7>APRS:!3905.45N/07223.83W-')),
          isFalse);
    });

    test('关掉的订阅不算命中', () {
      final r = SubRule(
          id: 'a', kind: SubKind.station, value: 'BG7LZQ', enabled: false);
      expect(subMatches(r, pkt('X>APRS:')), isFalse);
    });

    test('路径解析去掉 * 与空段', () {
      expect(
          subPathOf('A>APRS,BH6RIZ-6*,WIDE2-1:body'), ['BH6RIZ-6', 'WIDE2-1']);
      expect(subPathOf('A>APRS:body'), isEmpty);
    });

    // ── 身份与报文种类（2.1.36）──
    test('台站口径默认只看它自己发的，路径里出现它不算', () {
      final r = SubRule(id: 'a', kind: SubKind.station, value: 'BH6RIZ-6');
      expect(r.asSource, isTrue);
      expect(r.asPath, isFalse);
      final relayed = pkt('BG7LZQ-9>APRS,BH6RIZ-6*:!3905.45N/07223.83W-');
      expect(subMatch(r, relayed), isNull);
    });

    test('打开「经它中继」后，同一条命中的身份是 path', () {
      final r = SubRule(
          id: 'a', kind: SubKind.digi, value: 'BH6RIZ-6');
      expect(r.asSource, isFalse);
      expect(r.asPath, isTrue);
      final relayed = pkt('BG7LZQ-9>APRS,BH6RIZ-6*:!3905.45N/07223.83W-');
      expect(subMatch(r, relayed), SubRole.path);
      // 它自己发的也认得出来（两个身份都打开时）
      r.asSource = true;
      expect(subMatch(r, pkt('x>APRS:', src: 'BH6RIZ-6')), SubRole.source);
    });

    test('报文种类：信标与消息能分开看', () {
      final beaconOnly = SubRule(
          id: 'a', kind: SubKind.station, value: 'BG7LZQ',
          packet: SubPacket.beacon);
      expect(subMatches(beaconOnly, pkt('x>APRS:!3905.45N/07223.83W-')),
          isTrue);
      expect(
          subMatches(
              beaconOnly,
              pkt('x>APRS::BG7LZQ-2 :hello', type: 'message')),
          isFalse);
      final msgOnly = SubRule(
          id: 'b', kind: SubKind.station, value: 'BG7LZQ',
          packet: SubPacket.message);
      expect(
          subMatches(msgOnly, pkt('x>APRS::BG7LZQ-2 :hello', type: 'message')),
          isTrue);
      expect(subMatches(msgOnly, pkt('x>APRS:!3905.45N/07223.83W-')),
          isFalse);
    });

    test('报文种类判定：位置/状态/天气/对象都算信标', () {
      expect(subPacketKindOf(pkt('x>APRS:!39', type: 'position')), 'beacon');
      expect(subPacketKindOf(pkt('x>APRS:>hi', type: 'status')), 'beacon');
      expect(subPacketKindOf(pkt('x>APRS:_10090556', type: 'weather')),
          'beacon');
      expect(subPacketKindOf(pkt('x>APRS:;obj', type: 'object')), 'beacon');
      expect(subPacketKindOf(pkt('x>APRS::A :b', type: 'message')), 'message');
      expect(subPacketKindOf(pkt('x>APRS:#', type: 'unknown')), 'other');
    });
  });

  test('规则与记录能存能读', () {
    final rules = [
      SubRule(id: 'r1', kind: SubKind.station, value: 'BG7LZQ'),
      SubRule(id: 'r2', kind: SubKind.keyword, value: 'CNNET', hits: 3),
    ];
    rules[1].packet = SubPacket.message;
    final hits = [
      SubHit(
          ruleId: 'r2',
          call: 'BG5CCC-7',
          raw: 'BG5CCC-7>APRS::BG7LZQ-2 :CQ CNNET BG5CCC OL51',
          time: DateTime(2026, 10, 26, 12, 30),
          role: SubRole.source,
          packet: 'message'),
    ];
    final back = decodeSubscriptions(encodeSubscriptions(rules, hits));
    expect(back.rules.length, 2);
    expect(back.rules[0].kind, SubKind.station);
    expect(back.rules[1].hits, 3);
    expect(back.hits.length, 1);
    expect(back.hits.first.call, 'BG5CCC-7');
    expect(back.hits.first.time.minute, 30);
    expect(back.hits.first.role, SubRole.source);
    expect(back.hits.first.packet, 'message');
    expect(back.rules[1].packet, SubPacket.message);
    // 老存档没有这两个字段：按口径默认值读回来
    final old = decodeSubscriptions(
        '{"rules":[{"id":"o","kind":"digi","value":"BH6RIZ-6"}],"hits":[]}');
    expect(old.rules.single.asSource, isFalse);
    expect(old.rules.single.asPath, isTrue);
    expect(old.rules.single.packet, SubPacket.all);
  });

  test('坏掉的存档不会抛异常', () {
    final back = decodeSubscriptions('{not json');
    expect(back.rules, isEmpty);
    expect(back.hits, isEmpty);
  });
}
