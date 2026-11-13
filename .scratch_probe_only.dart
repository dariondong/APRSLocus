import 'dart:io';

import 'package:aprslocus/strong_notice.dart';

Future<void> main() async {
  final text = await fetchStrongNoticeJson(userAgent: 'APRSLocus/2.2.5');
  stdout.writeln('fetch: ${text == null ? "null" : "${text.length} 字符"}');
  if (text == null) return;
  final all = StrongNotice.parseAll(text, 'zh');
  stdout.writeln('parseAll(zh): ${all.length} 条');
  for (final n in all) {
    stdout.writeln('  id=${n.id} level=${n.level} every=${n.every} '
        'until=${n.until} title=${n.title}');
    stdout.writeln('  worthShowing({}) = ${n.worthShowing({})}');
  }
  final pick = StrongNotice.pick(text, 'zh', {});
  stdout.writeln('pick(zh, {}) = ${pick?.id}');
  final pickTw = StrongNotice.pick(text, 'zh_TW', {});
  stdout.writeln('pick(zh_TW, {}) = ${pickTw?.id}');
  final pickEn = StrongNotice.pick(text, 'en', {});
  stdout.writeln('pick(en, {}) = ${pickEn?.id}');
  stdout.writeln('now = ${DateTime.now().toUtc()}');
}
