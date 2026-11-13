import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/models.dart';
import 'package:aprslocus/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 消息重发的回归测试。
///
/// 要钉住的是四件事，缺一件用户在射频上就会吃亏：
///   * 重发用的是**同一个报文编号**（`{XXXX`）：换了编号对方按 msgid 去重
///     就失效了，等于把同一句话发两遍；
///   * 重发间隔与次数按用户设定走，次数用完就停（不无限重发把频道刷满）；
///   * 对方回执到了就立刻取消，一次都不再多发；
///   * 链路断开期间不计次、不重发，也不把倒计时白走完。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 一台「能发消息」的本机：设好呼号，把消息链路摆成在线。
  AppState online() => AppState()
    ..myCall = 'BG7LZQ'
    ..mySsid = '7'
    ..debugSetLinkUp(AppState.srcAprsIs, true);

  /// 取出发出去的第一条私聊（`messages` 是新的在最前面）。
  AprsMsg firstSent(AppState st) =>
      st.messages.firstWhere((m) => m.sent && m.groupId == null);

  group('消息重发', () {
    test('默认开：间隔 30 秒、最多 2 次；非法值回到默认', () {
      final st = online();
      expect(st.msgResend, isTrue);
      expect(st.msgResendGapSec, 30);
      expect(st.msgResendTimes, 2);

      st.setMsgResendGap(7); // 不在选项里
      expect(st.msgResendGapSec, 30, reason: '认不出的间隔要回默认，不能存进去');
      st.setMsgResendGap(60);
      expect(st.msgResendGapSec, 60);

      st.setMsgResendTimes(9);
      expect(st.msgResendTimes, 2);
      st.setMsgResendTimes(3);
      expect(st.msgResendTimes, 3);
      st.dispose();
    });

    test('发出后排队；到点用同一个编号重发，并把次数记在消息上', () {
      final st = online();
      st.setMsgResendGap(15);
      st.sendMessage('BG0TST-9', '到山顶了');

      final m = firstSent(st);
      final id = m.id!;
      expect(st.msgResendOf(id), isNotNull, reason: '私聊发出后应当排上重发');

      // 还没到点：不动
      st.debugTickMsgResend(DateTime.now());
      expect(st.msgResendOf(id)!.tries, 0);

      // 拨到 16 秒之后：应当重发一次
      st.debugTickMsgResend(DateTime.now().add(const Duration(seconds: 16)));
      expect(st.msgResendOf(id)!.tries, 1);
      expect(m.tries, 1, reason: '重发次数要写在消息上，气泡才能显示');

      // 重发用的是**同一条帧、同一个编号**：这就是「重发不等于重复」的前提，
      // 对方收到两份时按 msgid 去重。
      final sentRaw =
          st.packets.firstWhere((p) => p.raw.contains('{$id')).raw;
      expect(st.msgResendOf(id)!.raw, sentRaw,
          reason: '重发必须用原编号与原内容，否则对方会当成新消息');
      st.dispose();
    });

    test('次数用完就停：从等待表里摘掉，消息上留着已重发的次数', () {
      final st = online();
      st.setMsgResendGap(15);
      st.setMsgResendTimes(1);
      st.sendMessage('BG0TST-9', '一句话');
      final m = firstSent(st);
      final id = m.id!;

      st.debugTickMsgResend(DateTime.now().add(const Duration(seconds: 16)));
      expect(m.tries, 1);
      expect(st.msgResendOf(id), isNotNull);

      // 下一轮到点时次数已用完：不再重发，任务摘掉
      st.debugTickMsgResend(DateTime.now().add(const Duration(seconds: 40)));
      expect(m.tries, 1, reason: '超过设定的次数后不能再发');
      expect(st.msgResendOf(id), isNull);
      st.dispose();
    });

    test('收到回执立刻取消重发，之后也不再发', () {
      final st = online();
      st.setMsgResendGap(15);
      st.sendMessage('BG0TST-9', '收到请回');
      final m = firstSent(st);
      final id = m.id!;

      // 对方回 `ack<编号>`（收件人补到 9 位，与真实报文一致）
      st.debugFeedLine('BG0TST-9>APRS::BG7LZQ-7 :ack$id');
      expect(m.acked, isTrue);
      expect(st.msgResendOf(id), isNull, reason: '回执到了就不该再排队');

      final before = st.packets.where((p) => p.raw.contains('{$id')).length;
      st.debugTickMsgResend(DateTime.now().add(const Duration(seconds: 60)));
      final after = st.packets.where((p) => p.raw.contains('{$id')).length;
      expect(after, before, reason: '回执之后一次都不该再发');
      expect(m.tries, 0);
      st.dispose();
    });

    test('链路断开期间不计次、不重发', () {
      final st = online();
      st.setMsgResendGap(15);
      st.sendMessage('BG0TST-9', '断线时别发');
      final m = firstSent(st);
      final id = m.id!;
      st.debugSetLinkUp(AppState.srcAprsIs, false);

      st.debugTickMsgResend(DateTime.now().add(const Duration(seconds: 16)));
      expect(m.tries, 0, reason: '链路没连上，这一轮不算重发');
      expect(st.msgResendOf(id), isNotNull, reason: '任务留着，链路回来再试');

      st.debugSetLinkUp(AppState.srcAprsIs, true);
      st.debugTickMsgResend(DateTime.now().add(const Duration(seconds: 20)));
      expect(m.tries, 1);
      st.dispose();
    });

    test('关掉开关时，手上排着的也一起取消', () {
      final st = online();
      st.sendMessage('BG0TST-9', '关了就停');
      final id = firstSent(st).id!;
      expect(st.msgResendOf(id), isNotNull);

      st.setMsgResend(false);
      expect(st.msgResend, isFalse);
      expect(st.msgResendOf(id), isNull);
      st.dispose();
    });

    test('关掉开关后新发的消息不再排队', () {
      final st = online();
      st.setMsgResend(false);
      st.sendMessage('BG0TST-9', '不开重发');
      final m = firstSent(st);
      expect(m.id, isNotNull);
      expect(st.msgResendOf(m.id), isNull);
      st.dispose();
    });

    test('次数用完仍没回执：点一下能重新发一轮（编号不变）', () {
      final st = online();
      st.setMsgResendGap(15);
      st.setMsgResendTimes(1);
      st.sendMessage('BG0TST-9', '再试一次');
      final m = firstSent(st);
      final id = m.id!;

      // 一轮用尽
      st.debugTickMsgResend(DateTime.now().add(const Duration(seconds: 16)));
      st.debugTickMsgResend(DateTime.now().add(const Duration(seconds: 40)));
      expect(m.tries, 1);
      expect(st.msgResendGaveUp(m), isTrue, reason: '发完一轮没回执，气泡上要能点');

      // 点一下：立刻再发，并从这一轮重新计数
      final before =
          st.packets.where((p) => p.raw.contains('{$id')).length;
      expect(st.resendMessage(m), isTrue);
      expect(m.tries, 0, reason: '手动重发开新的一轮，不是接着旧的次数往上加');
      expect(st.msgResendOf(id), isNotNull);
      expect(st.msgResendGaveUp(m), isFalse);
      // 手工重发也沿用原编号：对方按 msgid 去重
      final again = st.msgResendOf(id)!.raw;
      expect(again.contains('{$id'), isTrue);
      expect(st.packets.where((p) => p.raw.contains('{$id')).length,
          greaterThanOrEqualTo(before));
      st.dispose();
    });

    test('链路没连上时点它不会假装发出了（返回 false，界面提示一声）', () {
      final st = online();
      st.setMsgResendGap(15);
      st.setMsgResendTimes(1);
      st.sendMessage('BG0TST-9', '断线时的点击');
      final m = firstSent(st);
      st.debugTickMsgResend(DateTime.now().add(const Duration(seconds: 16)));
      st.debugTickMsgResend(DateTime.now().add(const Duration(seconds: 40)));
      st.debugSetLinkUp(AppState.srcAprsIs, false);
      expect(st.resendMessage(m), isFalse);
      expect(st.msgResendOf(m.id), isNull);
      st.dispose();
    });
  });
}
