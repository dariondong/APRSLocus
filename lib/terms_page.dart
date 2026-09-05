import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'widgets.dart';

/// 官网协议正文地址（与 docs/assets 同源，改协议只需更新网站即可生效）
const _kTermsBase = 'https://aprslocus.theez.top/';

/// 用户协议页面（使用条款与免责声明）
/// - 优先从官网在线加载协议全文（保证最新）；失败/超时回退到本地打包副本
/// - 顶部可切换 中文 / English，支持刷新、在浏览器打开
class TermsPage extends StatefulWidget {
  const TermsPage({super.key});
  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  bool _en = false;
  bool _inited = false;
  late Future<_TermsResult> _future;

  String get _file => _en ? 'terms_en.txt' : 'terms_zh.txt';
  String get _localKey => 'assets/$_file';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    // 默认协议语言跟随 App 当前语言
    _en = Localizations.localeOf(context).languageCode == 'en';
    _future = _load();
  }

  void _reload() => setState(() => _future = _load());

  void _switchLang(bool en) {
    if (_en == en) return;
    setState(() {
      _en = en;
      _future = _load();
    });
  }

  /// 优先官网在线，失败/超时回退本地
  Future<_TermsResult> _load() async {
    try {
      final t = await _fetchOnline().timeout(const Duration(seconds: 8));
      if (t.trim().isNotEmpty) return _TermsResult(t, online: true);
    } catch (_) {
      // 网络不可用 / 超时 → 走本地
    }
    try {
      final t = await rootBundle.loadString(_localKey);
      return _TermsResult(t, online: false);
    } catch (_) {
      return _TermsResult('', online: false);
    }
  }

  Future<String> _fetchOnline() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);
    try {
      final url = Uri.parse('$_kTermsBase')
          .resolve('assets/$_file')
          .toString();
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.userAgentHeader, 'APRSlocus/${_en ? 'en' : 'zh'}');
      final res = await req.close();
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      return await res.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: C.ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          S.of(context).userAgreement,
          style: ts(16, w: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _en ? 'Refresh' : '刷新',
            icon: Icon(Icons.refresh_rounded, color: C.blue, size: 20),
            onPressed: _reload,
          ),
          IconButton(
            tooltip: _en ? 'Open in browser' : '在浏览器打开',
            icon: Icon(Icons.open_in_new_rounded, color: C.blue, size: 18),
            onPressed: () => launchUrl(
              Uri.parse('$_kTermsBase${_en ? 'en/terms.html' : 'terms.html'}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 语言切换 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _langSwitch(),
                const SizedBox(width: 10),
                _sourceBadge(),
              ],
            ),
          ),
          // ── 正文 ──
          Expanded(
            child: FutureBuilder<_TermsResult>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasData && snap.data!.text.isNotEmpty) {
                  final blocks = _parseBlocks(snap.data!.text);
                  return _buildDoc(blocks);
                }
                if (snap.hasError ||
                    (snap.hasData && snap.data!.text.isEmpty)) {
                  return _buildError(snap.error);
                }
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: C.blue,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        _en ? 'Loading…' : '加载中…',
                        style: ts(12, c: C.grey),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 语言切换胶囊 ──
  Widget _langSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: C.greyBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langBtn('中文', false),
          _langBtn('English', true),
        ],
      ),
    );
  }

  Widget _langBtn(String label, bool en) {
    final active = _en == en;
    return GestureDetector(
      onTap: () => _switchLang(en),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? C.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: ts(12, c: active ? C.white : C.slate, w: FontWeight.w600),
        ),
      ),
    );
  }

  // ── 来源徽章（在线最新版 / 离线缓存） ──
  Widget _sourceBadge() {
    // 通过 FutureBuilder 结果判断来源需要额外状态；用 Future 完成回调维护简单标记
    return FutureBuilder<_TermsResult>(
      future: _future,
      builder: (context, snap) {
        final loading = !snap.hasData;
        final online = snap.data?.online ?? false;
        final color = loading ? C.grey : (online ? C.green : C.grey);
        final label = loading
            ? (_en ? '…' : '…')
            : online
                ? (_en ? 'Live' : '官网最新版')
                : (_en ? 'Cached' : '离线缓存');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: loading ? C.greyBg : (online ? C.greenBg : C.greyBg),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 5),
              Text(label, style: ts(10, c: color, w: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }

  // ── 错误视图（在线+本地都失败） ──
  Widget _buildError(Object? err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: C.greyLight),
            const SizedBox(height: 14),
            Text(
              _en
                  ? 'Failed to load the agreement. Check your network and try again.'
                  : '协议加载失败，请检查网络后重试。',
              style: ts(13, c: C.slate, h: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(_en ? 'Retry' : '重试'),
              style: FilledButton.styleFrom(backgroundColor: C.blue),
            ),
          ],
        ),
      ),
    );
  }

  // ── 正文文档 ──
  Widget _buildDoc(List<_Block> blocks) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
            decoration: BoxDecoration(
              color: C.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: C.border, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: C.ink.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final b in blocks) _blockWidget(b),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _blockWidget(_Block b) {
    switch (b.kind) {
      case 1: // 文档大标题
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(b.text,
              style: ts(19, w: FontWeight.w800, ls: -0.3, h: 1.5)),
        );
      case 2: // 元信息（版本/更新日期）
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(b.text, style: ts(12, c: C.grey, h: 1.6)),
        );
      case 3: // 章节标题
        return Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(b.text, style: ts(15, w: FontWeight.w800, h: 1.4)),
        );
      case 4: // 条款正文
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(b.text, style: ts(13.5, c: C.ink, h: 1.85)),
        );
      case 5: // 分隔线
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1, thickness: 0.5, color: C.border),
        );
      default: // 空行占位由解析跳过
        return const SizedBox.shrink();
    }
  }
}

/// 协议解析结果
class _TermsResult {
  final String text;
  final bool online;
  _TermsResult(this.text, {required this.online});
}

/// 行块：kind 1=大标题 2=元信息 3=章节标题 4=正文 5=分隔线
class _Block {
  final String text;
  final int kind;
  _Block(this.text, this.kind);
}

final _reZhHead = RegExp(r'^[一二三四五六七八九十]+、');
final _reEnHead = RegExp(r'^[1-9]\d*\.\s+[A-Z]');
final _reMeta = RegExp(r'^(版本|Version|更新日期|Effective Date)');

/// 把协议纯文本解析成带样式的块序列
List<_Block> _parseBlocks(String text) {
  final out = <_Block>[];
  final lines = text.split('\n');
  bool first = true;
  for (final raw in lines) {
    final t = raw.trim();
    if (t.isEmpty) continue;
    if (t.startsWith('---')) {
      out.add(_Block('', 5));
      continue;
    }
    if (first) {
      first = false;
      out.add(_Block(t, 1)); // 首行 = 文档标题
      continue;
    }
    if (_reMeta.hasMatch(t)) {
      out.add(_Block(t, 2));
      continue;
    }
    if (_reZhHead.hasMatch(t) || _reEnHead.hasMatch(t)) {
      out.add(_Block(t, 3));
      continue;
    }
    out.add(_Block(t, 4));
  }
  return out;
}
