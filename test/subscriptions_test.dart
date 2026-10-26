import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/models.dart';
import 'package:aprslocus/subscriptions.dart';

Packet pkt(String raw, {String src = 'BG7LZQ-9', String? info}) => Packet(
      raw,
      src,
      'APRS',
      'position',
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
  });

  test('规则与记录能存能读', () {
    final rules = [
      SubRule(id: 'r1', kind: SubKind.station, value: 'BG7LZQ'),
      SubRule(id: 'r2', kind: SubKind.keyword, value: 'CNNET', hits: 3),
    ];
    final hits = [
      SubHit(
          ruleId: 'r2',
          call: 'BG5CCC-7',
          raw: 'BG5CCC-7>APRS::BG7LZQ-2 :CQ CNNET BG5CCC OL51',
          time: DateTime(2026, 10, 26, 12, 30)),
    ];
    final back = decodeSubscriptions(encodeSubscriptions(rules, hits));
    expect(back.rules.length, 2);
    expect(back.rules[0].kind, SubKind.station);
    expect(back.rules[1].hits, 3);
    expect(back.hits.length, 1);
    expect(back.hits.first.call, 'BG5CCC-7');
    expect(back.hits.first.time.minute, 30);
  });

  test('坏掉的存档不会抛异常', () {
    final back = decodeSubscriptions('{not json');
    expect(back.rules, isEmpty);
    expect(back.hits, isEmpty);
  });
}
