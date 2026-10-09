import 'package:aprslocus/strategy_map.dart';
import 'package:flutter_test/flutter_test.dart';

/// 策略地图协议回归测试。
///
/// 这一层的正确性只有两条硬指标：
///   1. **任何输入都要能发出去** —— 编码结果必须 ≤ APRS 的 67 字符上限
///      （射频下超长会被对端静默丢弃），超长的线要自动分片；
///   2. **收到的畸形帧不能崩、不能污染图层** —— 解析要么给出合法帧，
///      要么返回 null。
void main() {
  group('编码：长度与分片', () {
    test('普通标点单帧且不超过 67', () {
      final frames = StrategyProto.encode(StrategyItem(
        id: 'YW1',
        kind: StrategyKind.point,
        owner: 'BD4TYW',
        groupCall: 'BD4TYW-G1',
        updatedAt: 1,
        lat: 39.12345,
        lng: 116.12345,
        label: '救援',
      ));
      expect(frames.length, 1);
      expect(frames.first.length <= StrategyProto.maxFrameLen, isTrue);
      expect(frames.first.startsWith('\$M1 P YW1 '), isTrue);
    });

    test('零散的中文标签也不会顶爆上限', () {
      final frames = StrategyProto.encode(StrategyItem(
        id: 'YW2',
        kind: StrategyKind.rally,
        owner: 'BD4TYW',
        groupCall: 'G',
        updatedAt: 1,
        lat: 39.12345,
        lng: 116.12345,
        label: '集合点集合点集合点集合点',
      ));
      expect(frames.length, 1);
      expect(frames.first.length <= StrategyProto.maxFrameLen, isTrue);
    });

    test('很长的线自动分片，且每片都 ≤ 67', () {
      final pts = <(double, double)>[
        for (var i = 0; i < 30; i++) (39.0 + i * 0.01, 116.0 + i * 0.01),
      ];
      final frames = StrategyProto.encode(StrategyItem(
        id: 'YW9',
        kind: StrategyKind.line,
        owner: 'BD4TYW',
        groupCall: 'G',
        updatedAt: 1,
        lat: pts.first.$1,
        lng: pts.first.$2,
        path: pts,
      ));
      expect(frames.length > 1, isTrue, reason: '30 个点不可能塞进一帧');
      for (final f in frames) {
        expect(f.length <= StrategyProto.maxFrameLen, isTrue);
      }
    });
  });

  group('解析：往返一致', () {
    test('标点往返', () {
      final it = StrategyItem(
        id: 'YW1',
        kind: StrategyKind.point,
        owner: 'BD4TYW',
        groupCall: 'G',
        updatedAt: 1,
        lat: 39.12345,
        lng: 116.12345,
        label: '救援',
      );
      final f = StrategyProto.parse(StrategyProto.encode(it).first);
      expect(f, isNotNull);
      expect(f!.op, 'P');
      expect(f.id, 'YW1');
      expect((f.lat - 39.12345).abs() < 1e-4, isTrue);
      expect(f.label, '救援');
    });

    test('圈往返（半径）', () {
      final f = StrategyProto.parse('\$M1 C YW5 39.12345,116.12345,800 禁区');
      expect(f, isNotNull);
      expect(f!.kind, StrategyKind.circle);
      expect(f.radiusM, 800);
      expect(f.label, '禁区');
    });

    test('划线分片解析出片号', () {
      final f = StrategyProto.parse('\$M1 L YW8 2/3 39.11,116.11;39.12,116.12');
      expect(f, isNotNull);
      expect(f!.op, 'L');
      expect(f.partIndex, 2);
      expect(f.partTotal, 3);
      expect(f.path.length, 2);
    });

    test('单帧划线没有片号', () {
      final f = StrategyProto.parse('\$M1 L YW8 39.11,116.11;39.12,116.12');
      expect(f, isNotNull);
      expect(f!.partIndex, 1);
      expect(f.partTotal, 1);
      expect(f.path.length, 2);
    });

    test('删除与清空', () {
      final d = StrategyProto.parse('\$M1 D YW3');
      expect(d!.op, 'D');
      expect(d.id, 'YW3');
      expect(StrategyProto.parse('\$M1 X')!.op, 'X');
      expect(StrategyProto.parse('\$M1 S')!.op, 'S');
    });
  });

  group('颜色：线/圈可选色往返一致', () {
    StrategyItem _mk(StrategyKind k, {int ci = -1, List<(double, double)>? p}) =>
        StrategyItem(
          id: 'YW9',
          kind: k,
          owner: 'BD4TYW',
          groupCall: 'G',
          updatedAt: 1,
          lat: 39.12345,
          lng: 116.12345,
          radiusM: k == StrategyKind.circle ? 800 : 0,
          path: p ?? const [],
          colorIndex: ci,
        );

    test('圈的颜色编进坐标段且能被解析回来', () {
      final frames = StrategyProto.encode(_mk(StrategyKind.circle, ci: 3));
      expect(frames.length, 1);
      final f = StrategyProto.parse(frames.first)!;
      expect(f.colorIndex, 3);
      expect(f.radiusM, 800);
    });

    test('线的颜色编在 ID 之后且不与片号/点串混淆', () {
      final frames = StrategyProto.encode(_mk(
        StrategyKind.line,
        ci: 2,
        p: const [(39.11, 116.11), (39.12, 116.12)],
      ));
      expect(frames.length, 1);
      final f = StrategyProto.parse(frames.first)!;
      expect(f.colorIndex, 2);
      expect(f.path.length, 2);
    });

    test('未指定颜色时不写颜色段，解析回 -1（大小写不敏感）', () {
      final frames = StrategyProto.encode(_mk(StrategyKind.circle));
      expect(frames.first.contains(',-1'), isFalse);
      expect(StrategyProto.parse(frames.first)!.colorIndex, -1);
      expect(StrategyProto.parse('\$M1 L YW8 39.11,116.11;39.12,116.12')!.colorIndex, -1);
    });

    test('越界颜色下标回落到 -1 而非报错', () {
      final f = StrategyProto.parse('\$M1 C YW1 39.0,116.0,800,99')!;
      expect(f.colorIndex, -1);
      final l = StrategyProto.parse('\$M1 L YW8 9 39.11,116.11;39.12,116.12')!;
      expect(l.colorIndex, -1);
    });

    test('调色板越界回落首色，不抛异常', () {
      expect(StrategyProto.colorAt(-1), StrategyProto.palette.first);
      expect(StrategyProto.colorAt(99), StrategyProto.palette.first);
      expect(StrategyProto.colorAt(1), StrategyProto.palette[1]);
    });

    test('带颜色后仍不超 67 字符上限', () {
      final frames = StrategyProto.encode(_mk(
        StrategyKind.line,
        ci: 5,
        p: [for (var i = 0; i < 40; i++) (39.0 + i / 1000, 116.0 + i / 1000)],
      ));
      expect(frames, isNotEmpty);
      for (final f in frames) {
        expect(f.length <= StrategyProto.maxFrameLen, isTrue);
      }
      // 分片线收齐后每一片都应带同一颜色
      for (final f in frames) {
        expect(StrategyProto.parse(f)!.colorIndex, 5);
      }
    });
  });

  group('解析：畸形帧一律拒绝', () {
    test('不是策略帧', () {
      expect(StrategyProto.parse('INVITE BG7LZQ-G1 群'), isNull);
      expect(StrategyProto.parse('普通消息'), isNull);
      expect(StrategyProto.parse('\$M2 P YW1 39.1,116.1'), isNull); // 未知版本
      expect(StrategyProto.parse('\$M1 Z YW1'), isNull); // 未知 OP
    });

    test('越界坐标 / 非法半径 / 非法 ID', () {
      expect(StrategyProto.parse('\$M1 P YW1 99.0,116.0'), isNull);
      expect(StrategyProto.parse('\$M1 P YW1 39.0,200.0'), isNull);
      expect(StrategyProto.parse('\$M1 C YW1 39.0,116.0,0'), isNull);
      expect(StrategyProto.parse('\$M1 C YW1 39.0,116.0,99999999'), isNull);
      expect(StrategyProto.parse('\$M1 P YW!1 39.0,116.0'), isNull);
      expect(StrategyProto.parse('\$M1 P 1234567 39.0,116.0'), isNull);
    });

    test('不合法的线分片被拒', () {
      expect(StrategyProto.parse('\$M1 L YW8 0/3 39.1,116.1'), isNull);
      expect(StrategyProto.parse('\$M1 L YW8 2/1 39.1,116.1'), isNull);
      expect(StrategyProto.parse('\$M1 L YW8'), isNull);
    });
  });

  group('ID 生成', () {
    test('取呼号末 3 位并加序号，长度可控', () {
      expect(StrategyProto.makeId('BD4TYW-7', 3), 'TYW3');
      expect(StrategyProto.makeId('BG7LZQ', 12), 'LZQ12');
      expect(StrategyProto.makeId('K1A', 1), 'K1A1');
    });
  });
}
