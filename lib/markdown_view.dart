import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'web_embed.dart';

/// ─── Markdown 渲染（公告用）───
///
/// 用户需求：「md 应用内支持渲染 MD 和超链接」。
///
/// ## 为什么只引入**解析器**、渲染自己写
///
/// pubspec 里加的是 `markdown`（纯 Dart 解析器，依赖只有 args/meta），
/// 而不是 `flutter_markdown` / `markdown_widget`：
///
/// * `flutter_markdown` 已停止维护，且会把渲染样式**锁死在它自己的默认值**上；
///   本应用有整套自己的排版令牌（[ts]、`C.*`），公告要和界面看起来是一家的。
/// * `markdown_widget` 会多带一串依赖；而本机跑不了 `flutter pub get`，
///   依赖树越深、猜错的风险越大。
/// * 只引解析器的话，**语法支持是完整的**（用 `ExtensionSet.gitHubFlavored`：
///   标题、列表、表格、删除线、自动链接、代码块都在），只是把 AST 变成
///   Flutter widget 这一步由这里负责 —— 也就是样式与链接行为都由我们说了算。
///
/// ## 两个实现细节（都是踩过才写的）
///
/// 1. **链接用 [WidgetSpan] 而不是 `TapGestureRecognizer`**：
///    recognizer 是 `ChangeNotifier`，得在 State 里 dispose，否则每重建一次就
///    泄漏一批；而公告这种「随时可能因为刷新而重建」的页面最容易踩。
///    WidgetSpan 里放一个 `GestureDetector` 没有这个问题。
/// 2. **相对链接要补全**：[baseUrl] 用来把 `/manual/` 这类相对地址拼成绝对地址，
///    否则 `launchUrl` 会直接失败（而用户只看到「点了没反应」）。
class MarkdownView extends StatelessWidget {
  /// Markdown 原文
  final String data;

  /// 相对链接/图片的基准地址（一般是官网根，见 `NoticeStore.base`）
  final String? baseUrl;

  const MarkdownView(this.data, {super.key, this.baseUrl});

  /// 内嵌视频指令：一整行 `@video <URL>`（见 [WebEmbed]）。
  ///
  /// 为什么用独立一行、而不是约定 Markdown 语法：**旧版兼容** ——
  /// 不认识这条指令的旧版本 app 会把它当普通文字（GFM 还会把裸 URL 变成
  /// 可点链接），不会白屏；而新版把它渲染成内嵌播放器。
  static final RegExp _videoLine = RegExp(r'^@video\s+(\S+)\s*$');

  @override
  Widget build(BuildContext context) {
    // gitHubFlavored 而不是 commonMark：公告需要**表格**与**自动链接**
    // （把裸 URL 也变成可点的），这两样都是 GFM 扩展。
    //
    // 先按 `@video` 指令把原文切成「Markdown 片段 + 内嵌块」：
    // 指令行不交给 Markdown 解析（解析器会把 `@video` 当普通文字）。
    final children = <Widget>[];
    final buf = StringBuffer();
    void flush() {
      final src = buf.toString();
      buf.clear();
      if (src.trim().isEmpty) return;
      final nodes = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored)
          .parse(src);
      children.addAll(_blocks(context, nodes));
    }

    for (final line in data.split('\n')) {
      final m = _videoLine.firstMatch(line.trim());
      if (m != null) {
        flush();
        children.add(WebEmbed(url: m.group(1)!, height: 240));
        children.add(const SizedBox(height: 12));
      } else {
        buf.writeln(line);
      }
    }
    flush();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  // ─────────────────────────── 块级 ───────────────────────────

  List<Widget> _blocks(BuildContext context, List<md.Node> nodes) {
    final out = <Widget>[];
    for (final n in nodes) {
      final w = _block(context, n);
      if (w != null) out.add(w);
    }
    return out;
  }

  Widget? _block(BuildContext context, md.Node node) {
    if (node is! md.Element) {
      // 顶层裸文本（少见）：当段落处理，别直接丢内容
      final t = node.textContent.trim();
      return t.isEmpty ? null : _para(context, [node]);
    }
    switch (node.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        final level = int.parse(node.tag.substring(1));
        // 字号按级别递减；行高比正文小一点，标题才「紧」
        final size = switch (level) {
          1 => 18.0,
          2 => 16.0,
          3 => 14.5,
          _ => 13.5,
        };
        return Padding(
          padding: EdgeInsets.only(top: level == 1 ? 2 : 12, bottom: 6),
          child: _rich(context, node.children ?? const [],
              ts(size, w: FontWeight.w800, h: 1.35)),
        );
      case 'p':
        return _para(context, node.children ?? const []);
      case 'ul':
      case 'ol':
        // 有序列表要自己编号：`ol` 的 start 属性（若有）作为起点
        final start =
            int.tryParse(node.attributes['start'] ?? '') ?? 1;
        return Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _listItems(context, node, node.tag == 'ol', start, 0),
          ),
        );
      case 'blockquote':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(10, 2, 0, 2),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: C.blue.withValues(alpha: 0.45), width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _blocks(context, node.children ?? const []),
          ),
        );
      case 'pre':
        // 代码块：整块等宽 + 浅底。**不解析行内语法**（这是代码）
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: C.bgSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: C.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(node.textContent.trimRight(), style: mono(11.5, c: C.ink)),
          ),
        );
      case 'hr':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, color: C.border),
        );
      case 'table':
        return _table(context, node);
      case 'img':
        return _image(context, node);
      default:
        // 其它块（含 GFM 任务列表的 input 之类）走「当段落渲染子节点」的兜底，
        // 宁可样式朴素，也不要把内容吞掉。
        final kids = node.children;
        if (kids == null || kids.isEmpty) return null;
        return _para(context, kids);
    }
  }

  Widget _para(BuildContext context, List<md.Node> kids) {
    // 空段落（连续空行）不出空盒子
    if (kids.every((k) => k.textContent.trim().isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: _rich(context, kids, ts(12.5, c: C.slate, h: 1.6)),
    );
  }

  List<Widget> _listItems(BuildContext context, md.Element list, bool ordered,
      int start, int depth) {
    final out = <Widget>[];
    var n = start;
    for (final child in list.children ?? const <md.Node>[]) {
      if (child is! md.Element || child.tag != 'li') continue;
      final kids = child.children ?? const <md.Node>[];
      // li 里可能既有行内内容、又有嵌套列表：拆开分别渲染
      final inline = <md.Node>[];
      final nested = <md.Element>[];
      for (final k in kids) {
        if (k is md.Element && (k.tag == 'ul' || k.tag == 'ol')) {
          nested.add(k);
        } else {
          inline.add(k);
        }
      }
      final marker = ordered ? '$n.' : '•';
      // 任务列表（GFM）：`- [x] 事项` 的第一个子节点是 input
      out.add(Padding(
        padding: EdgeInsets.only(left: depth * 14.0, top: 2, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              child: Text(marker,
                  style: ts(12.5, c: C.grey, w: FontWeight.w600, h: 1.6)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (inline.isNotEmpty)
                    _rich(context, inline, ts(12.5, c: C.slate, h: 1.6)),
                  for (final nn in nested)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _listItems(
                            context,
                            nn,
                            nn.tag == 'ol',
                            int.tryParse(nn.attributes['start'] ?? '') ?? 1,
                            depth + 1),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ));
      n++;
    }
    return out;
  }

  Widget _table(BuildContext context, md.Element table) {
    final rows = <md.Element>[];
    for (final sec in table.children ?? const <md.Node>[]) {
      if (sec is md.Element && (sec.tag == 'thead' || sec.tag == 'tbody')) {
        for (final tr in sec.children ?? const <md.Node>[]) {
          if (tr is md.Element && tr.tag == 'tr') rows.add(tr);
        }
      } else if (sec is md.Element && sec.tag == 'tr') {
        rows.add(sec);
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    final body = <TableRow>[];
    for (var r = 0; r < rows.length; r++) {
      final cells = <TableCell>[];
      for (final c in rows[r].children ?? const <md.Node>[]) {
        if (c is! md.Element || (c.tag != 'th' && c.tag != 'td')) continue;
        final head = c.tag == 'th' || r == 0;
        cells.add(TableCell(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: _rich(
              context,
              c.children ?? const [],
              ts(11.5,
                  c: head ? C.ink : C.slate,
                  w: head ? FontWeight.w700 : FontWeight.w500,
                  h: 1.4),
            ),
          ),
        ));
      }
      if (cells.isEmpty) continue;
      body.add(TableRow(
        decoration: r == 0
            ? BoxDecoration(color: C.bgSoft)
            : null,
        children: cells,
      ));
    }
    if (body.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: C.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Table(
            border: TableBorder.symmetric(
              inside: BorderSide(color: C.border, width: 0.6),
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: body,
          ),
        ),
      ),
    );
  }

  /// 块级图片：等比缩放、限高，加载中与失败都有交代
  Widget _image(BuildContext context, md.Element el) {
    final src = _abs(el.attributes['src'] ?? '');
    final alt = el.attributes['alt'] ?? '';
    if (src.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          src,
          fit: BoxFit.cover,
          // 上限 220：公告图是**说明**用的，不该把正文挤到屏幕外
          height: null,
          errorBuilder: (_, _, _) => Container(
            padding: const EdgeInsets.all(10),
            color: C.bgSoft,
            child: Text('🖼 $alt'.trim(),
                style: ts(11, c: C.grey, h: 1.4)),
          ),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : Container(
                  height: 80,
                  alignment: Alignment.center,
                  color: C.bgSoft,
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
        ),
      ),
    );
  }

  // ─────────────────────────── 行内 ───────────────────────────

  Widget _rich(BuildContext context, List<md.Node> kids, TextStyle base) =>
      Text.rich(TextSpan(children: _spans(context, kids, base)));

  List<InlineSpan> _spans(
      BuildContext context, List<md.Node> nodes, TextStyle style) {
    final out = <InlineSpan>[];
    for (final n in nodes) {
      if (n is md.Text) {
        out.add(TextSpan(text: n.text, style: style));
        continue;
      }
      if (n is! md.Element) {
        final t = n.textContent;
        if (t.isNotEmpty) out.add(TextSpan(text: t, style: style));
        continue;
      }
      switch (n.tag) {
        case 'strong':
          out.addAll(_spans(context, n.children ?? const [],
              style.copyWith(fontWeight: FontWeight.w800)));
        case 'em':
          out.addAll(_spans(context, n.children ?? const [],
              style.copyWith(fontStyle: FontStyle.italic)));
        case 'del':
          out.addAll(_spans(context, n.children ?? const [],
              style.copyWith(decoration: TextDecoration.lineThrough)));
        case 'code':
          // 行内代码：等宽 + 浅底（用 backgroundColor 而不是再套容器，
          // 否则行内盒子会破坏基线对齐）
          out.addAll(_spans(context, n.children ?? const [],
              mono(11.5, c: C.ink).copyWith(
                  backgroundColor: C.bgSoft)));
        case 'a':
          final url = _abs(n.attributes['href'] ?? '');
          final label = n.textContent;
          if (url.isEmpty) {
            out.add(TextSpan(text: label, style: style));
          } else {
            out.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                onTap: () => openExternal(context, url),
                child: Text(label,
                    style: style.copyWith(
                      color: C.blue,
                      decoration: TextDecoration.underline,
                      decorationColor: C.blue,
                    )),
              ),
            ));
          }
        case 'br':
          out.add(const TextSpan(text: '\n'));
        case 'img':
          final src = _abs(n.attributes['src'] ?? '');
          final alt = n.attributes['alt'] ?? '';
          if (src.isEmpty) {
            out.add(TextSpan(text: alt, style: style));
          } else {
            out.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Image.network(
                src,
                height: 16,
                errorBuilder: (_, _, _) => Text(alt, style: style),
              ),
            ));
          }
        case 'input':
          // GFM 任务列表的勾选框：用字符画，别引入真控件（不可交互更合适）
          final checked = n.attributes.containsKey('checked');
          out.add(TextSpan(text: checked ? '☑ ' : '☐ ', style: style));
        default:
          out.addAll(_spans(context, n.children ?? const [], style));
      }
    }
    return out;
  }

  /// 相对地址 → 绝对地址。`launchUrl` 只认绝对地址，
  /// 不补的话用户看到的是「点了没反应」。
  String _abs(String url) {
    if (url.isEmpty) return '';
    if (url.contains('://')) return url;
    final base = baseUrl;
    if (base == null || base.isEmpty) return url;
    if (url.startsWith('/')) return '$base$url';
    if (url.startsWith('#')) return ''; // 段内锚点：应用内没有对应位置
    return '$base/$url';
  }
}

/// 打开外部链接（全应用统一的打开方式：交给系统浏览器）。
///
/// 抽成函数是为了**只有一处**决定 `LaunchMode`：公告里的链接、关于页的链接、
/// 会员卡里的链接必须行为一致，各写一份必然会漂。
Future<void> openExternal(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  // 失败要说出来：静默失败会让用户以为「链接是坏的」
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(url), behavior: SnackBarBehavior.floating),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(url), behavior: SnackBarBehavior.floating),
      );
    }
  }
}
