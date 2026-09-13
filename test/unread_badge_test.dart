import 'package:aprslocus/models.dart';
import 'package:aprslocus/state.dart';
import 'package:flutter_test/flutter_test.dart';

/// 未读小红点的回归测试
///
/// 背景：曾报告「聊天的消息小红点有时候不会消除」。查下来是一组相关缺陷：
///   ① `markGroupRead` 只写已读时间点、**漏了重算未读** → 读完群聊红点不消
///   ② 收到**群消息时完全不递增**未读（`if (!isGroupMsg) unreadMessages++`），
///      于是红点要等别的操作触发重算才突然冒出，读了又消不掉
///   ③ 私聊只在**点开时**标一次已读 → 会话开着时来新消息会一直算未读
///   ④ 呼号大小写不统一（`_readAt['bg7lzq']` 与 `m.from == 'BG7LZQ'` 不匹配）
///
/// 修法是让未读数成为**派生值**（唯一真源 `_recalcUnread`），
/// 并让「当前正在看的会话」不计入未读。下面的用例把这四条锁住。
///
/// 这些测试直接操作 AppState 的消息列表，不依赖网络与本地化。
void main() {
  /// 造一条收到的私聊消息
  AprsMsg priv(String from, {String me = 'BG7LZQ', DateTime? at}) => AprsMsg(
        from,
        me,
        'hello',
        at ?? DateTime.now(),
        sent: false,
      );

  /// 造一条收到的群聊消息
  AprsMsg groupMsg(String from, String groupId, {String me = 'BG7LZQ',
      DateTime? at}) => AprsMsg(
        from,
        groupId,
        'hi group',
        at ?? DateTime.now(),
        sent: false,
        groupId: groupId,
      );

  group('呼号归一化', () {
    test('大小写不同视为同一会话（APRS 呼号大小写不敏感）', () {
      expect(AppState.normCall('bg7lzq'), 'BG7LZQ');
      expect(AppState.normCall('  Bg7LzQ-9 '), 'BG7LZQ-9');
      expect(AppState.normCall('bg7lzq'), AppState.normCall('BG7LZQ'));
    });

    test('会话键：私聊按呼号（归一化）、群聊按 groupId', () {
      expect(AppState.convKeyOfMsg(priv('bg7lzq')), 'c:BG7LZQ');
      expect(AppState.convKeyOfMsg(groupMsg('JA1XYZ', 'grp_1')), 'g:grp_1');
    });
  });

  group('已读标记必须让未读数下降（bug ①）', () {
    test('标记群聊已读后，未读数应减少', () {
      final st = AppState();
      final t = DateTime.now().subtract(const Duration(seconds: 5));
      st.messages
        ..clear()
        ..add(groupMsg('JA1XYZ', 'grp_1', at: t))
        ..add(groupMsg('JA1XYZ', 'grp_1', at: t.add(const Duration(seconds: 1))));

      st.recalcUnreadForTest();
      expect(st.unreadMessages, 2, reason: '两条群消息都应计为未读');

      st.markGroupRead('grp_1');
      // 修复前这里是 2（markGroupRead 漏了重算），表现为「读完群红点不消」
      expect(st.unreadMessages, 0, reason: '标记群已读后应立即清零');
    });

    test('标记私聊已读后，未读数应减少', () {
      final st = AppState();
      st.messages
        ..clear()
        ..add(priv('JA1XYZ'));
      st.recalcUnreadForTest();
      expect(st.unreadMessages, 1);

      st.markConversationRead('JA1XYZ');
      expect(st.unreadMessages, 0);
    });
  });

  group('群消息也要计入未读（bug ②）', () {
    test('收到群消息后未读数应包含它', () {
      final st = AppState();
      st.messages
        ..clear()
        ..add(groupMsg('JA1XYZ', 'grp_1'));
      st.recalcUnreadForTest();
      // 修复前：收群消息时完全不 ++，只有别的操作触发重算才会出现
      expect(st.unreadMessages, 1);
    });

    test('群聊与私聊未读同时计入', () {
      final st = AppState();
      st.messages
        ..clear()
        ..add(priv('JA1XYZ'))
        ..add(groupMsg('BD3QID', 'grp_1'));
      st.recalcUnreadForTest();
      expect(st.unreadMessages, 2);
    });
  });

  group('正在查看的会话不计未读（bug ③）', () {
    test('把会话设为「正在查看」后，它的消息不计未读', () {
      final st = AppState();
      st.messages
        ..clear()
        ..add(priv('JA1XYZ'));
      st.recalcUnreadForTest();
      expect(st.unreadMessages, 1);

      st.setActiveConversation(call: 'JA1XYZ');
      expect(st.unreadMessages, 0, reason: '正看着的会话不该有红点');

      // 离开会话后又应重新计为未读
      st.setActiveConversation();
      expect(st.unreadMessages, 1);
    });

    test('群聊同理', () {
      final st = AppState();
      st.messages
        ..clear()
        ..add(groupMsg('JA1XYZ', 'grp_1'));
      st.setActiveConversation(groupId: 'grp_1');
      expect(st.unreadMessages, 0);
      st.setActiveConversation();
      expect(st.unreadMessages, 1);
    });

    test('正在查看 A 会话时，B 会话的消息仍然计未读', () {
      final st = AppState();
      st.messages
        ..clear()
        ..add(priv('JA1XYZ'))
        ..add(priv('BD3QID'));
      st.setActiveConversation(call: 'JA1XYZ');
      expect(st.unreadMessages, 1, reason: '只应跳过当前会话');
    });
  });

  group('大小写不同不应导致红点不消（bug ④）', () {
    test('同一台站以不同大小写发来的消息，标记一次已读应全部消掉', () {
      // 这是真正会暴露问题的场景：同一台站先后以 'ja1xyz' 与 'JA1XYZ'
      // 发来消息（APRS 呼号大小写不敏感，报文里写法可能不一致）。
      // 若已读键不做归一化，标了其中一个，另一个会一直红着 —— 永不消除。
      final st = AppState();
      st.messages
        ..clear()
        ..add(priv('ja1xyz'));
      st.recalcUnreadForTest();
      expect(st.unreadMessages, 1);

      // 用「另一种大小写」标记已读
      st.markConversationRead('JA1XYZ');
      expect(st.unreadMessages, 0,
          reason: '大小写不同不应视为另一个会话（否则红点永不消除）');

      // 反向再来一次：已读键是小写、消息是大写
      final st2 = AppState();
      st2.messages
        ..clear()
        ..add(priv('JA1XYZ'));
      st2.markConversationRead('ja1xyz');
      expect(st2.unreadMessages, 0, reason: '反方向同样要匹配');
    });

    test('conversationUnread 也按归一化匹配', () {
      final st = AppState();
      st.messages
        ..clear()
        ..add(priv('ja1xyz'));
      expect(st.conversationUnread('JA1XYZ'), 1);
      expect(st.conversationUnread('ja1xyz'), 1);
    });

    test('群消息不会被误算进同名的私聊会话', () {
      final st = AppState();
      st.messages
        ..clear()
        ..add(groupMsg('JA1XYZ', 'grp_1'));
      // 群消息的 from 是 JA1XYZ，但不该出现在 JA1XYZ 的私聊未读里
      expect(st.conversationUnread('JA1XYZ'), 0);
    });
  });

  group('自己发的消息不计未读', () {
    test('sent 的消息始终不计', () {
      final st = AppState();
      st.messages
        ..clear()
        ..add(AprsMsg('BG7LZQ', 'JA1XYZ', 'hi', DateTime.now(), sent: true));
      st.recalcUnreadForTest();
      expect(st.unreadMessages, 0);
    });

    test('系统消息不计（如「XX 加入群聊」）', () {
      final st = AppState();
      st.messages
        ..clear()
        ..add(AprsMsg('JA1XYZ', 'grp_1', 'XX 加入了群聊', DateTime.now(),
            system: true, groupId: 'grp_1'));
      st.recalcUnreadForTest();
      expect(st.unreadMessages, 0);
    });
  });

  group('已读时间点语义', () {
    test('已读之后到达的消息仍计未读', () {
      final st = AppState();
      st.messages.clear();
      st.markConversationRead('JA1XYZ'); // 先标已读
      // 再收到一条更晚的消息
      st.messages.add(priv('JA1XYZ',
          at: DateTime.now().add(const Duration(seconds: 1))));
      st.recalcUnreadForTest();
      expect(st.unreadMessages, 1, reason: '标已读后新到的消息应计未读');
    });

    test('已读之前的旧消息不计未读（历史消息不该一直红着）', () {
      final st = AppState();
      st.messages
        ..clear()
        ..add(priv('JA1XYZ',
            at: DateTime.now().subtract(const Duration(minutes: 5))));
      st.markConversationRead('JA1XYZ');
      expect(st.unreadMessages, 0);
    });
  });
}
