import 'package:aprslocus/group_chat.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aprslocus/state.dart';
import 'package:aprslocus/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// 群聊协议回归测试。
///
/// 背景：群聊是 APRS 之上的自订协议（群呼号广播 + 发往群主的私信命令）。
/// 原实现把协议判定散在四个函数里、各自 startsWith + 按固定长度 substring，
/// 于是出现一类「只补一处就漏另一处」的 bug。重写后协议解析只剩
/// [GroupProto.parse] 一个入口，测试就从这里钉行为。
void main() {
  // AppState 构造时会异步加载设备库（走 SharedPreferences）：
  //   ① 需要先初始化测试 binding；
  //   ② 需要给 SharedPreferences 一个内存实现（否则在测试环境里
  //      getInstance 会抛 MissingPluginException，而它是**异步**抛出的，
  //      会随机撞到某个正在跑的用例上，看起来像被测代码失败）。
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('协议解析（唯一入口）', () {
    test('INVITE：群名含空格也能完整取回（不得按长度切）', () {
      final m = GroupProto.parse('INVITE BG7LZQ-G1 车队 群');
      expect(m, isNotNull);
      expect(m!.kind, GroupKind.invite);
      expect(m.groupCall, 'BG7LZQ-G1');
      expect(m.name, '车队 群', reason: '群名里的空格必须保留');
    });

    test('群内广播：中文括号与英文括号都要认，且大小写不敏感', () {
      for (final raw in ['【JOIN】BA7KSM', '[join]ba7ksm', '【Join】Ba7Ksm']) {
        final m = GroupProto.parse(raw);
        expect(m?.kind, GroupKind.memberJoined, reason: raw);
        expect(m?.name, 'BA7KSM', reason: raw);
      }
      expect(GroupProto.parse('【LEAVE】BA7KSM')?.kind, GroupKind.memberLeft);
      expect(GroupProto.parse('[LEAVE]BA7KSM')?.kind, GroupKind.memberLeft);
    });

    test('私信命令：新短名与旧长名都接受（新旧版本互通）', () {
      expect(GroupProto.parse('JOIN_CONFIRM BG7LZQ-G1')?.kind,
          GroupKind.joinConfirm);
      expect(GroupProto.parse('JACK BG7LZQ-G1')?.kind, GroupKind.joinConfirm);
      expect(GroupProto.parse('JOIN_REQ BG7LZQ-G1')?.kind,
          GroupKind.joinRequest);
      expect(GroupProto.parse('JREQ BG7LZQ-G1')?.kind, GroupKind.joinRequest);
      expect(GroupProto.parse('LEFT BG7LZQ-G1')?.kind, GroupKind.leave);
      expect(GroupProto.parse('LACK BG7LZQ-G1')?.kind, GroupKind.leave);
      expect(GroupProto.parse('DECLINE BG7LZQ-G1')?.kind, GroupKind.decline);
    });

    test('同一语义只有一种解析结果（防止两处判断漂移）', () {
      // 「某人加入」无论从群内广播还是从群主视角的确认命令来，
      // 都必须解析成明确的一种 kind，不能各自为政。
      expect(GroupProto.parse('【JOIN】BA7KSM')?.kind, GroupKind.memberJoined);
      expect(GroupProto.parse('JOIN_CONFIRM BG7LZQ-G1')?.kind,
          GroupKind.joinConfirm);
      expect(GroupProto.parse('【JOIN】BA7KSM')?.kind,
          isNot(GroupProto.parse('JOIN_CONFIRM X')?.kind));
    });

    test('前后多余空格、大小写混乱不影响解析', () {
      final m = GroupProto.parse('   join_confirm   bg7lzq-g1   ');
      expect(m?.kind, GroupKind.joinConfirm);
      expect(m?.groupCall, 'BG7LZQ-G1');
    });

    test('普通聊天内容绝不能被误判为协议消息', () {
      for (final raw in [
        '你好，今天天气不错',
        'INVITATION 已收到',      // 前缀相似但不是 INVITE
        'JOIN',                   // 只有命令无参数
        '【JOIN】',               // 没有呼号
        '我 JOIN_CONFIRM 了',     // 出现在句中
        '',
        '   ',
      ]) {
        expect(GroupProto.parse(raw), isNull, reason: '误判: "$raw"');
      }
    });
  });

  group('校验（非法值必须在源头拦住）', () {
    test('群名：空/含冒号/含换行 一律拒绝', () {
      expect(GroupProto.validateName(''), 'empty');
      expect(GroupProto.validateName('   '), 'empty');
      expect(GroupProto.validateName('车队:主群'), 'invalid',
          reason: '冒号会破坏 APRS 消息体结构');
      expect(GroupProto.validateName('车队\n主群'), 'invalid');
    });

    test('群名超长拒绝（过长会让邀请报文超 APRS 消息上限）', () {
      expect(GroupProto.validateName('a' * GroupProto.maxGroupNameLen), isNull);
      expect(GroupProto.validateName('a' * (GroupProto.maxGroupNameLen + 1)),
          'too-long');
      // 中文按字符计，不按字节
      expect(GroupProto.validateName('群' * GroupProto.maxGroupNameLen), isNull);
    });

    test('群呼号：必须是合法呼号且总长 ≤ 9（否则 AX.25 地址会被截断）', () {
      expect(GroupProto.validateGroupCall('BG7LZQ-G1'), isNull);
      expect(GroupProto.validateGroupCall('BG7LZQ-G15'), 'too-long');
      expect(GroupProto.validateGroupCall(''), 'empty');
      expect(GroupProto.validateGroupCall('BG7 LZQ'), 'invalid');
      expect(GroupProto.validateGroupCall('群组-G1'), 'invalid');
    });
  });

  group('编码与解析互逆', () {
    test('各命令 encode→parse 往返一致', () {
      expect(GroupProto.parse(GroupProto.invite('BG7LZQ-G1', '车队群'))!.groupCall,
          'BG7LZQ-G1');
      expect(GroupProto.parse(GroupProto.invite('BG7LZQ-G1', '车队群'))!.name,
          '车队群');
      for (final f in [
        GroupProto.joinConfirm('BG7LZQ-G1'),
        GroupProto.decline('BG7LZQ-G1'),
        GroupProto.joinRequest('BG7LZQ-G1'),
        GroupProto.leave('BG7LZQ-G1'),
      ]) {
        expect(GroupProto.parse(f)?.groupCall, 'BG7LZQ-G1', reason: f);
      }
      expect(GroupProto.parse(GroupProto.memberJoined('ba7ksm'))?.name, 'BA7KSM');
    });
  });

  group('群聊状态一致性（state 层）', () {
    test('建群：群主立即 joined，被邀请者 pending', () async {
      final st = AppState();
      await Future<void>.delayed(Duration.zero);
      final g = st.createGroup('测试群', {'BA7KSM', 'BD7ABC'});
      expect(g.memberStatus[g.owner.toUpperCase()], GroupMemberStatus.joined,
          reason: '群主不能是「待确认」，否则自己在收件人里都没有');
      expect(g.memberStatus['BA7KSM'], GroupMemberStatus.pending);
      expect(g.memberStatus['BD7ABC'], GroupMemberStatus.pending);
      // 收件人只看 joined：群主必须在里面
      expect(g.recipients.contains(g.owner.toUpperCase()), isTrue);
    });

    test('群呼号生成：不超过 9 字符且序号递增', () async {
      final st = AppState();
      await Future<void>.delayed(Duration.zero);
      final g1 = st.createGroup('群一', {});
      final g2 = st.createGroup('群二', {});
      expect(g1.groupCall.length, lessThanOrEqualTo(9));
      expect(g2.groupCall.length, lessThanOrEqualTo(9));
      expect(g1.groupCall, isNot(g2.groupCall));
      expect(GroupProto.validateGroupCall(g1.groupCall), isNull,
          reason: '自动生成的群呼号必须合法');
      expect(GroupProto.validateGroupCall(g2.groupCall), isNull);
    });
  });
}
