/// 强提醒的解析与「这一次该不该弹」。
///
/// 这条路上错了**不会报错**：JSON 写坏 → 一条都不弹；`until` 写坏 → 旧公告
/// 糊在人脸上；`every` 忘了关 → 每开一次应用弹一次。所以把规则钉在这里。
import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/strong_notice.dart';

const _json = '''
{
  "updated": "2026-11-13",
  "items": [
    {
      "id": "a",
      "level": "warn",
      "title": {"zh": "今晚维护", "zh_TW": "今晚維護", "en": "Maintenance tonight"},
      "body": {"zh": "服务器要到凌晨两点。"},
      "actions": [{"label": {"zh": "看看进度"}, "url": "https://example.com/x"}]
    },
    {
      "id": "b",
      "level": "critical",
      "title": "一句话标题",
      "body": "一句话正文",
      "hard": false,
      "every": true,
      "until": "2026-11-30"
    },
    {
      "id": "c",
      "title": "缺正文"
    }
  ]
}
''';

void main() {
  test('按语言取文案，缺了就退到 zh 再退 en', () {
    final all = StrongNotice.parseAll(_json, 'zh');
    expect(all.length, 2); // c 缺正文，整条丢掉
    expect(all.first.title, '今晚维护');
    expect(StrongNotice.parseAll(_json, 'zh_TW').first.title, '今晚維護');
    expect(
      StrongNotice.parseAll(_json, 'en').first.title,
      'Maintenance tonight',
    );
    // 非中文界面退到 en（这一条有 en）；没 en 才用第一个非空值
    expect(StrongNotice.parseAll(_json, 'ja').first.title, 'Maintenance tonight');
    expect(
      StrongNotice.parseAll('{"items":[{"id":"x","title":{"zh":"只有中文"},"body":{"zh":"b"}}]}', 'ja')
          .single
          .title,
      '只有中文',
    );
    // 纯字符串不受语言影响
    expect(StrongNotice.parseAll(_json, 'en')[1].title, '一句话标题');
  });

  test('级别认不出就当 info，动作缺地址也留着', () {
    final n = StrongNotice(
      id: 'x',
      level: 'warning',
      title: 't',
      body: 'b',
    );
    // 构造时不做校验，pick 也不看 level —— 归一发生在解析里
    final parsed = StrongNotice.parseAll(
      '{"items":[{"id":"x","level":"warning","title":"t","body":"b"}]}',
      'zh',
    ).single;
    expect(parsed.level, 'info');
    final acts = StrongNotice.parseAll(_json, 'zh').first.actions;
    expect(acts.length, 1);
    expect(acts.first.label, '看看进度');
    expect(acts.first.url, 'https://example.com/x');
    expect(n.id, 'x');
  });

  test('弹过的不再弹，every 的那条每次都弹', () {
    final now = DateTime.utc(2026, 11, 20, 4); // 北京时间 12:00
    expect(StrongNotice.pick(_json, 'zh', {}, now: now)?.id, 'a');
    expect(StrongNotice.pick(_json, 'zh', {'a'}, now: now)?.id, 'b');
    // b 是 every：弹过也照弹
    expect(StrongNotice.pick(_json, 'zh', {'a', 'b'}, now: now)?.id, 'b');
  });

  test('过了 until 那天就不再弹（按北京时间）', () {
    final n = StrongNotice.parseAll(_json, 'zh').last;
    expect(n.until, '2026-11-30');
    // 北京 11-30 23:59 还算当天
    expect(n.worthShowing({}, now: DateTime.utc(2026, 11, 30, 15, 59)), isTrue);
    // 北京 12-01 00:01 就过期了
    expect(n.worthShowing({}, now: DateTime.utc(2026, 11, 30, 16, 1)), isFalse);
  });

  test('until 写错当没写（宁可弹出来，也不要因为格式错而永远不弹）', () {
    final n = StrongNotice.parseAll(
      '{"items":[{"id":"x","title":"t","body":"b","until":"2026/11/30"}]}',
      'zh',
    ).single;
    expect(n.worthShowing({}, now: DateTime.utc(2030, 1, 1)), isTrue);
  });

  test('空文件 / 坏 JSON / 缺 items 都给空表', () {
    expect(StrongNotice.parseAll('', 'zh'), isEmpty);
    expect(StrongNotice.parseAll(null, 'zh'), isEmpty);
    expect(StrongNotice.parseAll('{oops', 'zh'), isEmpty);
    expect(StrongNotice.parseAll('{"updated":"2026-11-13"}', 'zh'), isEmpty);
    expect(StrongNotice.parseAll('{"items":[]}', 'zh'), isEmpty);
    expect(StrongNotice.pick('{"items":[]}', 'zh', {}), isNull);
  });

  test('取址与官网那份文件一致', () {
    expect(StrongNotice.url, endsWith('/assets/strong_notice.json'));
  });
}
