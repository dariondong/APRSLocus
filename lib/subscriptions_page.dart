import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'material.dart';
import 'state.dart';
import 'subscriptions.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 订阅 ───
///
/// 三种口径：台站 / 中继 / 关键词（见 lib/subscriptions.dart）。
/// 页面上半是规则，下半是命中记录；规则能开关也能删，记录可清空。
class SubscriptionsPage extends StatefulWidget {
  final AppState state;
  const SubscriptionsPage({super.key, required this.state});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  final _input = TextEditingController();
  SubKind _kind = SubKind.station;

  @override
  void initState() {
    super.initState();
    // 进来就算看过了：设置页那行的小红点跟着清掉
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.state.markSubscriptionsRead();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String _kindLabel(S l, SubKind k) => switch (k) {
        SubKind.station => l.subsKindStation,
        SubKind.digi => l.subsKindDigi,
        SubKind.keyword => l.subsKindKeyword,
      };

  String _fieldHint(S l, SubKind k) => switch (k) {
        SubKind.station => l.subsFieldStation,
        SubKind.digi => l.subsFieldDigi,
        SubKind.keyword => l.subsFieldKeyword,
      };

  IconData _kindIcon(SubKind k) => switch (k) {
        SubKind.station => Icons.cell_tower_rounded,
        SubKind.digi => Icons.route_rounded,
        SubKind.keyword => Icons.tag_rounded,
      };

  Color _kindColor(SubKind k) => switch (k) {
        SubKind.station => C.blue,
        SubKind.digi => C.orange,
        SubKind.keyword => C.cyan,
      };

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  /// 加一条：选口径 + 填值
  Future<void> _addSheet() async {
    final st = widget.state;
    final s = S.of(context);
    _input.clear();
    _kind = SubKind.station;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: MaterialSurface(
            radius: 24,
            topOnly: true,
            child: Container(
              decoration: BoxDecoration(
                color: C.sheetFill,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.subsAdd, style: ts(16, w: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final k in SubKind.values)
                        GestureDetector(
                          onTap: () => setSheet(() => _kind = k),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _kind == k ? _kindColor(k) : C.bgSoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: _kind == k
                                      ? _kindColor(k)
                                      : C.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_kindIcon(k),
                                    size: 13,
                                    color: _kind == k ? Colors.white : C.grey),
                                const SizedBox(width: 5),
                                Text(_kindLabel(s, k),
                                    style: ts(12,
                                        c: _kind == k ? Colors.white : C.slate,
                                        w: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _input,
                    autofocus: true,
                    textCapitalization: _kind == SubKind.keyword
                        ? TextCapitalization.none
                        : TextCapitalization.characters,
                    style: ts(13, w: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: _fieldHint(s, _kind),
                      hintStyle: ts(12, c: C.greyLight),
                      isDense: true,
                      filled: true,
                      fillColor: C.bgSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: C.border),
                      ),
                    ),
                    onSubmitted: (_) => _submit(ctx),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => _submit(ctx),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: C.blue,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: elev2(),
                        ),
                        child: Text(s.subsAdd,
                            style: ts(13,
                                c: Colors.white, w: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    st.markSubscriptionsRead();
  }

  void _submit(BuildContext ctx) {
    final s = S.of(context);
    final value = _input.text.trim();
    if (value.isEmpty) return;
    final ok = widget.state.addSubscription(_kind, value);
    Navigator.pop(ctx);
    _toast(ok ? s.subsAdded(value) : s.subsExists(value));
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    final s = S.of(context);
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final rules = st.subscriptions;
        final hits = st.subHits;
        return Scaffold(
          backgroundColor: C.bg,
          appBar: MaterialAppBar(
            AppBar(
              backgroundColor: C.surfaceFillStrong,
              elevation: 0,
              leading: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  s.back,
                  style: ts(13, c: C.blue, w: FontWeight.w600),
                ),
              ),
              leadingWidth: 56,
              title: Text(s.subsTitle,
                  style: ts(16, w: FontWeight.w800, h: 1.0)),
              actions: [
                if (hits.isNotEmpty)
                  TextButton(
                    onPressed: () => st.clearSubHits(),
                    child: Text(s.subsClear,
                        style: ts(12, c: C.grey, w: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Text(s.subsLead,
                  style: ts(12, c: C.slate, h: 1.6)),
              const SizedBox(height: 14),
              // ── 规则 ──
              if (rules.isEmpty)
                SoftCard(
                  child: Column(
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          size: 26, color: C.greyLight),
                      const SizedBox(height: 8),
                      Text(s.subsEmpty,
                          style: ts(13, w: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(s.subsEmptyNote,
                          textAlign: TextAlign.center,
                          style: ts(11, c: C.grey, h: 1.5)),
                    ],
                  ),
                )
              else
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    children: [
                      for (var i = 0; i < rules.length; i++) ...[
                        if (i > 0)
                          Divider(height: 0.6, color: C.border, thickness: 0.6),
                        _ruleRow(s, st, rules[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _addRow(s),
              const SizedBox(height: 20),
              // ── 命中记录 ──
              Row(
                children: [
                  Icon(Icons.inbox_rounded, size: 14, color: C.slate),
                  const SizedBox(width: 6),
                  Text(s.subsHitsTitle,
                      style: ts(12, c: C.slate, w: FontWeight.w700)),
                  const Spacer(),
                  if (hits.isNotEmpty)
                    Text(s.subsHitsCount('${hits.length}'),
                        style: ts(11, c: C.grey)),
                ],
              ),
              const SizedBox(height: 8),
              if (hits.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(s.subsNoHits, style: ts(11, c: C.grey)),
                )
              else
                for (final h in hits) _hitRow(st, s, h),
            ],
          ),
        );
      },
    );
  }

  Widget _ruleRow(S s, AppState st, SubRule r) {
    final c = _kindColor(r.kind);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(_kindIcon(r.kind), size: 16, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(13, w: FontWeight.w800, ls: 0.4)),
                const SizedBox(height: 2),
                Text(
                  '${_kindLabel(s, r.kind)} · ${s.subsHitsCount('${r.hits}')}',
                  style: ts(10, c: C.grey),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: r.enabled,
              onChanged: (v) => st.setSubscriptionEnabled(r.id, v),
            ),
          ),
          GestureDetector(
            onTap: () => st.removeSubscription(r.id),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close_rounded, size: 16, color: C.greyLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addRow(S s) {
    return GestureDetector(
      onTap: _addSheet,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: C.blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.blue.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 16, color: C.blue),
            const SizedBox(width: 4),
            Text(s.subsAdd,
                style: ts(13, c: C.blue, w: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _hitRow(AppState st, S s, SubHit h) {
    SubRule? rule;
    for (final r in st.subscriptions) {
      if (r.id == h.ruleId) {
        rule = r;
        break;
      }
    }
    final c = rule == null ? C.grey : _kindColor(rule.kind);
    final hhmm =
        '${h.time.hour.toString().padLeft(2, '0')}:${h.time.minute.toString().padLeft(2, '0')}';
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(h.call, style: ts(12, w: FontWeight.w800)),
              const SizedBox(width: 8),
              if (rule != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(rule.value,
                      style: ts(9, c: c, w: FontWeight.w700)),
                ),
              const Spacer(),
              Text(hhmm, style: ts(10, c: C.grey)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: h.raw));
                  _toast(s.subsCopied);
                },
                child: Icon(Icons.copy_rounded, size: 14, color: C.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(h.raw,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ts(10, c: C.slate, h: 1.45)),
        ],
      ),
    );
  }
}
