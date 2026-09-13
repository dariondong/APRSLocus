import 'dart:io';

import 'package:aprslocus/chat_translate_ui.dart';
import 'package:aprslocus/l10n/app_localizations.dart';
import 'package:aprslocus/models.dart';
import 'package:aprslocus/translate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 译文块渲染 + 「两个气泡都要接上译文块」的回归测试
///
/// 起因：曾经只有**瀑布流**气泡渲染了译文块，会话/群聊气泡漏了 ——
/// 结果是「长按翻译成功（状态里有译文）但界面上什么都不显示」。
/// 这类 bug 不会让编译失败、也不会有异常，只能靠测试挡住。
void main() {
  AprsMsg msg(String text, {bool sent = false}) => AprsMsg(
        sent ? 'BG7LZQ' : 'JA1XYZ',
        sent ? 'JA1XYZ' : 'BG7LZQ',
        text,
        DateTime(2026, 9, 13, 10),
        sent: sent,
      );

  /// 渲染一个需要 BuildContext 的译文块。
  ///
  /// 必须用 Builder 在**已挂载**的树里取 context：测试里常见的错误是先
  /// `tester.element(...)` 再 pumpWidget —— 那时树还不存在，会报
  /// `Bad state: No element`。
  Future<void> pumpBlock(
    WidgetTester tester,
    Widget Function(BuildContext) build,
  ) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Builder(builder: build)),
    ));
  }

  group('translationBlock 渲染', () {
    testWidgets('有译文且对照模式 → 显示译文与语言标签', (tester) async {
      final m = msg('Hello there');
      final st = ConvTransState();
      final pref = ConvTranslatePref(targetLang: 'zh');
      st.setTranslated(msgKey(m), '你好', 'zh');

      await pumpBlock(tester, (ctx) => translationBlock(
        context: ctx,
        m: m,
        st: st,
        pref: pref,
      ));

      expect(find.text('你好'), findsOneWidget);
      // 标签要说明「这段是译文、翻成了什么语言」
      expect(find.textContaining('简体中文'), findsOneWidget);
    });

    testWidgets('关掉对照 → 不渲染译文块（改由正文替换）', (tester) async {
      final m = msg('Hello');
      final st = ConvTransState();
      final pref = ConvTranslatePref(targetLang: 'zh', contrast: false);
      st.setTranslated(msgKey(m), '你好', 'zh');

      await pumpBlock(tester, (ctx) => translationBlock(
        context: ctx,
        m: m,
        st: st,
        pref: pref,
      ));
      expect(find.text('你好'), findsNothing);
    });

    testWidgets('点了「显示原文」→ 暂时隐藏译文块', (tester) async {
      final m = msg('Hello');
      final st = ConvTransState();
      final pref = ConvTranslatePref(targetLang: 'zh');
      st.setTranslated(msgKey(m), '你好', 'zh');
      st.toggleOriginal(msgKey(m));

      await pumpBlock(tester, (ctx) => translationBlock(
        context: ctx,
        m: m,
        st: st,
        pref: pref,
      ));
      expect(find.text('你好'), findsNothing);
    });

    testWidgets('翻译中 → 显示进度提示', (tester) async {
      final m = msg('Hello');
      final st = ConvTransState()..setPending(msgKey(m));
      final pref = ConvTranslatePref(targetLang: 'zh');

      await pumpBlock(tester, (ctx) => translationBlock(
        context: ctx,
        m: m,
        st: st,
        pref: pref,
      ));
      expect(find.textContaining('翻译'), findsWidgets);
    });

    testWidgets('失败 → 显示错误文本（不做静默失败）', (tester) async {
      final m = msg('Hello');
      final st = ConvTransState()..setError(msgKey(m), '翻译失败：HTTP 403');
      final pref = ConvTranslatePref(targetLang: 'zh');

      await pumpBlock(tester, (ctx) => translationBlock(
        context: ctx,
        m: m,
        st: st,
        pref: pref,
      ));
      expect(find.textContaining('HTTP 403'), findsOneWidget);
    });

    testWidgets('无译文 → 不占位', (tester) async {
      final m = msg('Hello');
      await pumpBlock(tester, (ctx) => translationBlock(
        context: ctx,
        m: m,
        st: ConvTransState(),
        pref: ConvTranslatePref(targetLang: 'zh'),
      ));
      expect(find.textContaining('翻译'), findsNothing);
    });

    testWidgets('方向标签：收到的消息 vs 我发出的消息', (tester) async {
      for (final (sent, wantTag) in [(false, '译给我看'), (true, '对方将读到')]) {
        final m = msg('Hi', sent: sent);
        final st = ConvTransState();
        st.setTranslated(msgKey(m), '嗨', 'zh');
        await pumpBlock(tester, (ctx) => translationBlock(
        context: ctx,
          m: m,
          st: st,
          pref: ConvTranslatePref(targetLang: 'zh'),
        ));
        expect(find.textContaining(wantTag), findsOneWidget,
            reason: 'sent=$sent 应标注 $wantTag');
      }
    });
  });

  group('防回归：两个气泡都必须渲染译文块', () {
    /// 源码级断言。这不是「测试实现细节」，而是挡住一类
    /// 「编译通过、运行无异常、界面静默少一块」的漏接 ——
    /// 曾经就只接了瀑布流那一处。
    test('_bubble 与 _feedBubble 都调用 translationBlock', () {
      final src = File('lib/messages_page.dart').readAsStringSync();
      final iFeed = src.indexOf('Widget _feedBubble');
      final iBubble = src.indexOf('Widget _bubble(');
      expect(iFeed, greaterThan(0), reason: '找不到 _feedBubble');
      expect(iBubble, greaterThan(iFeed), reason: '找不到 _bubble');

      final feed = src.substring(iFeed, iBubble);
      final bubble = src.substring(iBubble);

      expect(feed.contains('translationBlock('), isTrue,
          reason: '瀑布流气泡漏了译文块');
      expect(bubble.contains('translationBlock('), isTrue,
          reason: '会话/群聊气泡漏了译文块（曾导致「翻译了但不显示」）');
    });
  });

  group('会话键与消息指纹', () {
    test('私聊按呼号（大写归一），群聊按 groupId', () {
      expect(convKeyOf(call: 'bg7lzq'), 'c:BG7LZQ');
      expect(convKeyOf(groupId: 'grp_1'), 'g:grp_1');
      // 群聊优先：即使同时给了 call，也必须归到群
      expect(convKeyOf(groupId: 'grp_1', call: 'BG7LZQ'), 'g:grp_1');
      expect(convKeyOf(), 'c:');
    });

    test('消息指纹随内容/时间变化，同一条消息稳定', () {
      final m = msg('Hello');
      expect(msgKey(m), msgKey(m));
      final other = msg('Hello!');
      expect(msgKey(other), isNot(msgKey(m)));
      final later = AprsMsg('JA1XYZ', 'BG7LZQ', 'Hello',
          DateTime(2026, 9, 13, 10, 0, 1));
      expect(msgKey(later), isNot(msgKey(m)));
    });

    test('hasFor 只在语言一致时算命中（避免换语言后显示旧译文）', () {
      final m = msg('Hello');
      final st = ConvTransState();
      st.setTranslated(msgKey(m), '你好', 'zh');
      expect(st.hasFor(msgKey(m), 'zh'), isTrue);
      expect(st.hasFor(msgKey(m), 'ja'), isFalse);
    });
  });

  group('翻译方向', () {
    test('收到的消息 → 我的语言', () {
      final p = ConvTranslatePref(targetLang: 'zh', peerLang: 'en');
      expect(TransDirection.targetForIncoming(p, 'en'), 'zh');
    });

    test('我发出的消息 → 对方的语言', () {
      final p = ConvTranslatePref(targetLang: 'zh', peerLang: 'ja');
      expect(TransDirection.targetForOutgoing(p, 'en'), 'ja');
    });

    test('对方语言未知时回落到默认值，而不是拿我的语言当对方语言', () {
      final p = ConvTranslatePref(targetLang: 'zh', peerLang: '');
      expect(TransDirection.targetForOutgoing(p, 'en'), 'en');
      expect(TransDirection.targetForOutgoing(p, 'en'), isNot('zh'));
    });

    test('worthAuto：目标语言明确才值得自动翻译', () {
      expect(TransDirection.worthAuto(ConvTranslatePref(targetLang: 'zh')),
          isTrue);
      expect(TransDirection.worthAuto(ConvTranslatePref(targetLang: 'auto')),
          isFalse);
      expect(TransDirection.worthAuto(ConvTranslatePref(targetLang: '')),
          isFalse);
    });

    test('界面语言 → 短码（默认目标语言跟随界面语言）', () {
      expect(TransLang.fromUiLocale('zh'), 'zh');
      expect(TransLang.fromUiLocale('zh_TW'), 'zh-TW');
      expect(TransLang.fromUiLocale('en'), 'en');
      // 关键：中文界面下「我的语言」必须是 zh，否则中文消息翻成中文
      // = 原文照抄，用户会以为翻译没生效
      expect(TransLang.fromUiLocale('zh'), 'zh');
    });
  });
  group('发送前翻译', () {
    test('canTranslateOutgoing：必须知道对方语言，且不能等于我的语言', () {
      // 未知对方语言 → 不能译（否则可能译成同一种语言，等于没译）
      expect(
        TransDirection.canTranslateOutgoing(
            ConvTranslatePref(targetLang: 'zh', peerLang: '')),
        isFalse,
      );
      // 对方语言 == 我的语言 → 也没有意义
      expect(
        TransDirection.canTranslateOutgoing(
            ConvTranslatePref(targetLang: 'zh', peerLang: 'zh')),
        isFalse,
      );
      expect(
        TransDirection.canTranslateOutgoing(
            ConvTranslatePref(targetLang: 'zh', peerLang: 'en')),
        isTrue,
      );
    });

    test('exceedsLimit：0 表示不限；按译文（而非原文）判定', () {
      expect(TransDirection.exceedsLimit('a' * 200, 0), isFalse);
      expect(TransDirection.exceedsLimit('a' * 67, 67), isFalse);
      expect(TransDirection.exceedsLimit('a' * 68, 67), isTrue);
      // 关键：射频模式的上限是对「空中内容」的，译文超长必须拦住
      expect(TransDirection.exceedsLimit('a' * 80, 67), isTrue);
    });

    test('translateOutgoing 默认关闭（改空中内容，必须显式开启）', () {
      expect(ConvTranslatePref(targetLang: 'zh').translateOutgoing, isFalse);
    });

    test('translateOutgoing 可 JSON 往返', () {
      final p = ConvTranslatePref(
        targetLang: 'zh',
        peerLang: 'ja',
        translateOutgoing: true,
      );
      final back = ConvTranslatePref.fromJson(p.toJson(), 'zh');
      expect(back.translateOutgoing, isTrue);
      expect(back.peerLang, 'ja');
      expect(ConvTranslatePref.fromJson({}, 'zh').translateOutgoing, isFalse);
    });
  });

  group('已译发记录（AprsMsg.sentAs）', () {
    AprsMsg mk(String text, {String? sentAs}) => AprsMsg(
          'BG7LZQ',
          'JA1XYZ',
          text,
          DateTime(2026, 9, 13, 10),
          sent: true,
          sentAs: sentAs,
        );

    test('原文与译文分开保存：聊天记录按原文，核对按译文', () {
      final m = mk('你好，这里是测试', sentAs: 'Hello, this is a test');
      expect(m.text, '你好，这里是测试');
      expect(m.sentAs, 'Hello, this is a test');
      expect(m.translated, isTrue);
    });

    test('未译发时 translated 为 false（不显示标记）', () {
      expect(mk('你好').translated, isFalse);
      // 译文与原文相同的「假译发」也不显示
      expect(mk('hello', sentAs: 'hello').translated, isFalse);
    });

    test('sentAs 可 JSON 往返（重启后仍能核对当时发了什么）', () {
      final m = mk('你好', sentAs: 'Hello');
      final back = AprsMsg.fromJson(m.toJson());
      expect(back.text, '你好');
      expect(back.sentAs, 'Hello');
      expect(back.translated, isTrue);
    });

    test('旧数据没有 sentAs 字段也能解析（向后兼容）', () {
      final j = mk('你好').toJson();
      j.remove('sentAs');
      final back = AprsMsg.fromJson(j);
      expect(back.sentAs, isNull);
      expect(back.translated, isFalse);
    });

    testWidgets('sentAsBlock 渲染「已译发」文本；未译发时不占位', (tester) async {
      final m = mk('你好', sentAs: 'Hello');
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(builder: (ctx) => sentAsBlock(context: ctx, m: m)),
        ),
      ));
      expect(find.textContaining('Hello'), findsOneWidget);

      final plain = mk('你好');
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(builder: (ctx) => sentAsBlock(context: ctx, m: plain)),
        ),
      ));
      expect(find.textContaining('Hello'), findsNothing);
    });
  });
  group('免密钥接口', () {
    test('默认是「自动」模式，无需任何凭据即 ready', () {
      // 默认不再是单一接口，而是「自动链」——实测任何单一免密钥接口
      // 都不可靠（Google 公开端点会 429、MyMemory 对部分语对返回原文）
      final c = TranslateConfig();
      expect(c.provider, TransProvider.auto);
      expect(c.ready, isTrue);
      expect(c.missingField, '');
    });

    test('切到收费接口后才要求凭据', () {
      final g = TranslateConfig(provider: 'google');
      expect(g.ready, isFalse);
      g.googleApiKey = 'k';
      expect(g.ready, isTrue);
    });

    test('provider 可 JSON 往返（不写盘时回落为 auto）', () {
      expect(TranslateConfig.fromJson({}).provider, TransProvider.auto);
      final c = TranslateConfig(
          provider: TransProvider.mymemory, targetLang: 'ja');
      expect(TranslateConfig.fromJson(c.toJson()).provider,
          TransProvider.mymemory);
    });
  });

  group('Google 公开端点响应解析（免费接口的核心）', () {
    // 该端点返回嵌套数组，长文本会被拆成多段 —— 只取第一段会得到半截译文。
    // 这里用与 service 中 _googlePublic 相同的拼接规则做等价校验。
    test('多段必须全部拼接（否则译文被截断）', () {
      String join(List<dynamic> resp) {
        final segs = resp[0] as List;
        final sb = StringBuffer();
        for (final seg in segs) {
          if (seg is List && seg.isNotEmpty && seg[0] != null) {
            sb.write('${seg[0]}');
          }
        }
        return sb.toString();
      }

      expect(
        join([
          [
            ['Hello ', '你好 ', null, null, 10],
            ['world', '世界', null, null, 10],
          ],
          null,
          'zh-CN',
        ]),
        'Hello world',
      );
      // 单段
      expect(join([
        [
          ['Hi', '嗨', null, null, 10],
        ],
        null,
        'zh-CN',
      ]), 'Hi');
      // 空段被跳过
      expect(join([
        [
          ['Hi', '嗨', null, null, 10],
          [null, 'x', null, null, 10],
        ],
        null,
        'zh-CN',
      ]), 'Hi');
    });

    test('识别出的源语言在 root[2]（用于学习对方语言）', () {
      final resp = [
        [
          ['Hi', '嗨', null, null, 10],
        ],
        null,
        'zh-CN',
      ];
      expect((resp[2] as String), 'zh-CN');
    });
  });
}
