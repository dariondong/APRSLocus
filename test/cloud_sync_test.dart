/// 云同步的纯逻辑回归：消息的云端 id、上传字段、同步地址。
///
/// 为什么这几条要钉在 CI：
///   * `syncMessageId` 是**两台设备对同一条消息算出同一个 id** 的唯一依据。
///     它一变（换了算法、改了字段顺序），第一次同步就会把整份消息历史重复
///     传一遍，而且云端去重也跟着失效 —— 界面上只表现为「同一个对话里
///     每条都成了两条」。
///   * 上传字段名与服务端的列一一对应，写错一个（`peer` 写成 `to`）不会报错，
///     只会安静地存成一列空值。
///   * 地址跟着「APRSNETCN」那条链路走：没填就用项目自己那台，填了就要补上
///     8899（APRS 端口与 HTTP 端口是分开的），这里钉住 `baseFor` 的三种输入。
library;

import 'package:aprslocus/aprsnetcn.dart';
import 'package:aprslocus/cloud_sync.dart';
import 'package:aprslocus/models.dart';
import 'package:flutter_test/flutter_test.dart';

AprsMsg msg(
  String from,
  String to,
  String text,
  int ms, {
  bool sent = false,
  bool acked = false,
  String? groupId,
}) =>
    AprsMsg(
      from,
      to,
      text,
      DateTime.fromMillisecondsSinceEpoch(ms),
      sent: sent,
      acked: acked,
      groupId: groupId,
    );

void main() {
  group('消息的云端 id', () {
    test('同一条消息在另一台设备上算出同一个 id', () {
      final a = msg('BG7LZQ', 'BG6TA', '到山下了', 1793942184000, sent: true);
      final b = msg('BG7LZQ', 'BG6TA', '到山下了', 1793942184000, sent: true);
      expect(syncMessageId(a), syncMessageId(b));
      expect(syncMessageId(a), isNotEmpty);
    });

    test('文本不同就是另一条', () {
      final a = msg('BG7LZQ', 'BG6TA', '到山下了', 1793942184000, sent: true);
      final b = msg('BG7LZQ', 'BG6TA', '到山顶了', 1793942184000, sent: true);
      expect(syncMessageId(a), isNot(syncMessageId(b)));
    });

    test('时间不同就是另一条', () {
      final a = msg('BG7LZQ', 'BG6TA', '好', 1793942184000, sent: true);
      final b = msg('BG7LZQ', 'BG6TA', '好', 1793942185000, sent: true);
      expect(syncMessageId(a), isNot(syncMessageId(b)));
    });

    test('id 的头一段就是时间（36 进制），好按 id 排序与排查', () {
      final m = msg('BG7LZQ', 'BG6TA', '好', 1793942184000, sent: true);
      expect(syncMessageId(m).split('-').first,
          1793942184000.toRadixString(36));
    });
  });

  group('上传字段', () {
    test('收到的消息：方向 in，对端是发件人', () {
      final payload =
          syncMessagePayload(msg('BG6TA', 'BG7LZQ', 'hi', 1700000000000));
      expect(payload['dir'], 'in');
      expect(payload['peer'], 'BG6TA');
      expect(payload['ts'], 1700000000000);
      expect(payload['acked'], false);
      expect(payload.containsKey('grp'), isFalse);
    });

    test('发出的消息：方向 out，对端是收件人', () {
      final payload = syncMessagePayload(
          msg('BG7LZQ', 'BG6TA', 'hi', 1700000000000, sent: true, acked: true));
      expect(payload['dir'], 'out');
      expect(payload['peer'], 'BG6TA');
      expect(payload['acked'], true);
    });

    test('群聊带上群 id', () {
      final payload = syncMessagePayload(
          msg('BG7LZQ', 'BG7LZQ-G1', 'hi', 1700000000000, groupId: 'g-1'));
      expect(payload['grp'], 'g-1');
    });

    test('mid 与 syncMessageId 一致', () {
      final m = msg('BG6TA', 'BG7LZQ', 'hi', 1700000000000);
      expect(syncMessagePayload(m)['mid'], syncMessageId(m));
    });
  });

  group('同步地址', () {
    test('链路地址空着就用项目自己那台', () {
      expect(SyncApi.baseFor(''), kAcnHttpBase);
      expect(SyncApi.baseFor('   '), kAcnHttpBase);
    });

    test('填了地址就跟着它走，并补上 8899', () {
      expect(SyncApi.baseFor('1.2.3.4'), 'http://1.2.3.4:8899');
      expect(SyncApi.baseFor(' 1.2.3.4 '), 'http://1.2.3.4:8899');
    });
  });
}
