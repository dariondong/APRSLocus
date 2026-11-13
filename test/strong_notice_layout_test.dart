import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/strong_notice.dart';

void main() {
  group('正文排版：行首标记', () {
    test('小标题 / 段落 / 条目 / 等宽块', () {
      final blocks = parseNoticeBody('''
注入的构建流程从未执行。
【一、审计结论】
注入的构建流程由 v* 标签触发。
- 不会通过任何渠道索要密码、验证码。
`SHA-1: BE:7C:EC:BA:1C:8F`
''');
      expect(blocks.length, 5);
      expect(blocks[0].kind, NoticeBlockKind.paragraph);
      expect(blocks[1].kind, NoticeBlockKind.heading);
      expect(blocks[1].text, '一、审计结论');
      expect(blocks[2].kind, NoticeBlockKind.paragraph);
      expect(blocks[3].kind, NoticeBlockKind.bullet);
      expect(blocks[3].text, '不会通过任何渠道索要密码、验证码。');
      expect(blocks[4].kind, NoticeBlockKind.mono);
      expect(blocks[4].text, 'SHA-1: BE:7C:EC:BA:1C:8F');
    });

    test('空行跳过，单行不缩进也不丢', () {
      final blocks = parseNoticeBody('\n\n 一句话 \n\n');
      expect(blocks.length, 1);
      expect(blocks.single.kind, NoticeBlockKind.paragraph);
      expect(blocks.single.text, '一句话');
    });

    test('没闭合的方括号 / 反引号当普通段落，不吞内容', () {
      final blocks = parseNoticeBody('【没闭合\n`也没闭合\n【】');
      expect(blocks.length, 3);
      for (final b in blocks) {
        expect(b.kind, NoticeBlockKind.paragraph);
      }
    });
  });

  test('解析一条带小标题与指纹的提醒', () {
    const json = '''
{"items":[{"id":"x","level":"warn","title":"恢复更新","subtitle":"Audit complete · 12 Nov 2026",
"body":{"zh":"【一、结论】\\n`SHA-1: BE`\\n- 条目"}}]}
''';
    final n = StrongNotice.parseAll(json, 'zh').single;
    expect(n.title, '恢复更新');
    expect(n.subtitle, 'Audit complete · 12 Nov 2026');
    expect(n.level, 'warn');
    expect(parseNoticeBody(n.body).length, 3);
    // 没写 every 就是只弹一次
    expect(n.every, isFalse);
    expect(n.hard, isTrue);
  });
}
