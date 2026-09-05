import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'theme.dart';
import 'widgets.dart';

/// 用户协议页面（使用条款与免责声明）
/// - 正文存放于 assets/terms_zh.txt / terms_en.txt（与官网 docs 共用源）
/// - 顶部可切换 中文 / English
class TermsPage extends StatefulWidget {
  const TermsPage({super.key});
  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  bool _en = false;

  Future<String> _load() => rootBundle
      .loadString(_en ? 'assets/terms_en.txt' : 'assets/terms_zh.txt');

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
      ),
      body: Column(
        children: [
          // ── 语言切换 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Center(
              child: Container(
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
              ),
            ),
          ),
          // ── 正文 ──
          Expanded(
            child: FutureBuilder<String>(
              future: _load(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '${snap.error}',
                        style: ts(12, c: C.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: C.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: C.border, width: 0.4),
                        ),
                        child: SelectionArea(
                          child: Text(
                            snap.data!,
                            style: ts(13, c: C.ink, h: 1.9),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _langBtn(String label, bool en) {
    final active = _en == en;
    return GestureDetector(
      onTap: () {
        if (active) return;
        setState(() => _en = en);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? C.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: ts(12,
              c: active ? C.white : C.slate, w: FontWeight.w600),
        ),
      ),
    );
  }
}
