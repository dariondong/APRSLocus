// 会话列表头部「管理」按钮的对齐回归测试。
//
// 背景（这已是第二次出现）：头部标题用 `Flexible` 且其后跟 `Spacer` 时，
// 两者 flex 都是 1 → 各分走一半空白；而 Flexible 没占满的那份会被
// Row 留到最右侧，于是尾部的计数/管理按钮**被顶离右边缘**。
// 英文标题（Conversations）够长会占满份额，碰巧掩盖这个问题；
// 中文短标题「会话」实测偏移 37.5px。改用 Expanded 后间隙为 0。
//
// 本文件用真实布局测量（不靠肉眼）钉住这个不变量。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _barWidth = 252; // 横屏下会话列表栏（280）减内边距后的可用宽度

Future<void> _pumpBar(WidgetTester tester, String title, {required bool expanded}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _barWidth,
            child: Row(
              key: const ValueKey('bar'),
              children: [
                if (expanded)
                  Expanded(child: _title(title))
                else
                  Flexible(child: _title(title)),
                if (!expanded) const Spacer(),
                Container(
                  key: const ValueKey('count'),
                  height: 26,
                  width: 30,
                  color: Colors.blue,
                ),
                const SizedBox(width: 6),
                Container(
                  key: const ValueKey('manage'),
                  height: 26,
                  width: 60,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _title(String t) => Text(
  t,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: const TextStyle(fontSize: 20),
);

double _rightGap(WidgetTester tester) {
  final bar = tester.getRect(find.byKey(const ValueKey('bar')));
  final manage = tester.getRect(find.byKey(const ValueKey('manage')));
  return bar.right - manage.right;
}

void main() {
  testWidgets('Expanded：尾按钮严格贴右（中文短标题也不例外）', (tester) async {
    for (final title in ['会话', '会话列表', 'Conversations']) {
      await _pumpBar(tester, title, expanded: true);
      expect(
        _rightGap(tester),
        moreOrLessEquals(0, epsilon: 0.01),
        reason: 'title=$title 时尾部按钮未贴右',
      );
    }
  });

  testWidgets('Flexible + Spacer 会把尾按钮顶离右边缘（记录此陷阱）', (tester) async {
    // 中文短标题会暴露问题
    await _pumpBar(tester, '会话', expanded: false);
    expect(_rightGap(tester), greaterThan(1.0));
    // 英文标题较长、占满份额，反而看不出问题 —— 这正是它容易被漏掉的原因
    await _pumpBar(tester, 'Conversations', expanded: false);
    expect(_rightGap(tester), moreOrLessEquals(0, epsilon: 0.01));
  });

  test('源码守卫：_listHead / _manageHead 不得同时使用 Flexible 与 Spacer', () {
    final src = File('lib/messages_page.dart').readAsStringSync();
    for (final name in ['_listHead', '_manageHead']) {
      final body = _methodBody(src, name);
      expect(body, contains('Expanded('), reason: '$name 应使用 Expanded');
      expect(body, isNot(contains('Flexible(')),
          reason: '$name 不应使用 Flexible（会让尾按钮不贴右）');
      expect(body, isNot(contains('Spacer()')),
          reason: '$name 不应使用 Spacer（残留空白会落在最右侧）');
    }
  });
}

/// 取 `Widget <name>(...)` 方法体（按花括号配对；先剥离字符串与注释）
String _methodBody(String src, String name) {
  final i = src.indexOf('Widget $name(');
  if (i < 0) {
    throw StateError('未找到方法 $name');
  }
  final j = src.indexOf('{', i);
  var depth = 0;
  for (var k = j; k < src.length; k++) {
    final ch = src[k];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return _strip(src.substring(i, k + 1));
    }
  }
  throw StateError('$name 方法体未闭合');
}

/// 去掉字符串字面量与行注释，避免其中的花括号/关键词干扰
String _strip(String t) {
  final out = StringBuffer();
  var i = 0;
  while (i < t.length) {
    final ch = t[i];
    if (ch == '/' && i + 1 < t.length && t[i + 1] == '/') {
      final j = t.indexOf('\n', i);
      i = j < 0 ? t.length : j;
      continue;
    }
    if (ch == "'" || ch == '"') {
      i++;
      while (i < t.length) {
        if (t[i] == r'\') {
          i += 2;
          continue;
        }
        if (t[i] == ch) {
          i++;
          break;
        }
        i++;
      }
      continue;
    }
    out.write(ch);
    i++;
  }
  return out.toString();
}
