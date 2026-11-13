/// ─── 一版更新日志里的「改了什么」 ───
///
/// 装上新版之后那句简要提示（`lib/update_welcome.dart`）要显示的是**这一版**
/// 改了什么，不是整篇日志。日志正文长什么样由发布流程决定：由
/// `tool/release_notes.py` 从 CHANGELOG 里切出这一版那一段，于是形如
///
/// ```
/// > 这是预发布，用来先装上试试。
///
/// ## [2.2.3] - 2026-11-12
///
/// ### 更新
///
/// - 更新页会显示这个安装包的签名到底校没校。
/// - 更新渠道的那份清单改由官网下发。
/// ```
///
/// 取法：跳过 `>` 的引用块，从第一个 `## ` 标题（这一版）开始收 `- ` 行，
/// 到下一个 `## ` 标题（下一版 / 英文那一份）为止。
List<String> updateNotesSummary(String body, {int max = 5}) {
  if (body.trim().isEmpty || max <= 0) return const [];
  final out = <String>[];
  var inSection = false;
  for (final raw in body.split('\n')) {
    final line = raw.trimRight();
    if (line.startsWith('## ')) {
      if (inSection) break; // 下一版 / 英文版：只要头一段
      inSection = true;
      continue;
    }
    if (!inSection) continue;
    final t = line.trim();
    if (!t.startsWith('- ') && !t.startsWith('* ')) continue;
    final text = _plain(t.substring(2));
    if (text.isEmpty) continue;
    if (out.contains(text)) continue; // 同一句写了两遍只留一条
    out.add(text);
    if (out.length >= max) break;
  }
  if (out.isNotEmpty) return out;
  // 没有 `## ` 标题的日志（比如手写的 release body）：退一步，收开头的 `- ` 行。
  for (final raw in body.split('\n')) {
    final t = raw.trim();
    if (!t.startsWith('- ') && !t.startsWith('* ')) continue;
    final text = _plain(t.substring(2));
    if (text.isEmpty || out.contains(text)) continue;
    out.add(text);
    if (out.length >= max) break;
  }
  return out;
}

/// 去掉行内的 markdown 修饰（粗体、行内代码、链接语法），提示里不摆符号。
String _plain(String s) {
  var t = s.replaceAll('**', '').replaceAll('`', '');
  // [文字](url) → 文字
  t = t.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1) ?? '');
  return t.trim();
}
