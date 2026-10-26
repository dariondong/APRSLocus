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
  bool _asSource = true;
  bool _asPath = false;
  SubPacket _packet = SubPacket.all;

  /// 换口径时把身份开关恢复成该口径的默认值
  void _applyKindDefaults(SubKind k) {
    _kind = k;
    _asSource = k != SubKind.digi;
    _asPath = k == SubKind.digi;
  }

  String _packetLabel(S l, SubPacket p) => switch (p) {
        SubPacket.all => l.subsPacketAll,
        SubPacket.beacon => l.subsPacketBeacon,
        SubPacket.message => l.subsPacketMessage,
      };

  /// 规则行上那行小字：口径 · 身份 · 报文 · 命中数
  String _ruleSub(S l, SubRule r) {
    final bits = <String>[_kindLabel(l, r.kind)];
    if (r.kind != SubKind.keyword) {
      bits.add(r.asSource && r.asPath
          ? '${l.subsRoleSource}+${l.subsRolePath}'
          : (r.asSource ? l.subsRoleSource : l.subsRolePath));
    }
    bits.add(_packetLabel(l, r.packet));
    bits.add(l.subsHitsCount('${r.hits}'));
    return bits.join(' · ');
  }

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

  /// 加一条 / 改一条：口径 + 值 + 看它哪一面 + 哪类报文
  ///
  /// 「看它哪一面」是用户要的那层细节：同一个呼号，它**自己发的**信标说明它
  /// 还活着，**经它中继**的信标说明它在中继链路上干活。两个开关都打开时两边
  /// 都记，每条命中标清楚是哪一种。关键词口径没有身份，只有报文种类可挑。
  Future<void> _editSheet({SubRule? rule}) async {
    final st = widget.state;
    final s = S.of(context);
    final editing = rule != null;
    _input.text = rule?.value ?? '';
    if (editing) {
      _kind = rule.kind;
      _asSource = rule.asSource;
      _asPath = rule.asPath;
      _packet = rule.packet;
    } else {
      _applyKindDefaults(SubKind.station);
      _packet = SubPacket.all;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: MaterialSurface(
            radius: 24,
            topOnly: true,
            child: Container(
              decoration: BoxDecoration(
                color: C.sheetFill,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(editing ? s.subsEdit : s.subsAdd,
                      style: ts(16, w: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final k in SubKind.values)
                        _chip(
                          label: _kindLabel(s, k),
                          icon: _kindIcon(k),
                          color: _kindColor(k),
                          on: _kind == k,
                          onTap: () => setSheet(() => _applyKindDefaults(k)),
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
                    onSubmitted: (_) => _submit(ctx, rule),
                  ),
                  if (_kind != SubKind.keyword) ...[
                    const SizedBox(height: 14),
                    Text(s.subsRoleTitle,
                        style: ts(11, c: C.grey, w: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(
                          label: s.subsRoleSource,
                          icon: Icons.cell_tower_rounded,
                          color: C.blue,
                          on: _asSource,
                          // 两个都关掉就等于什么都收不到：最后一个不许关
                          onTap: () => setSheet(() {
                            if (_asSource && !_asPath) return;
                            _asSource = !_asSource;
                          }),
                        ),
                        _chip(
                          label: s.subsRolePath,
                          icon: Icons.route_rounded,
                          color: C.orange,
                          on: _asPath,
                          onTap: () => setSheet(() {
                            if (_asPath && !_asSource) return;
                            _asPath = !_asPath;
                          }),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(s.subsPacketTitle,
                      style: ts(11, c: C.grey, w: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in SubPacket.values)
                        _chip(
                          label: _packetLabel(s, p),
                          color: C.cyan,
                          on: _packet == p,
                          onTap: () => setSheet(() => _packet = p),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => _submit(ctx, rule),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: C.blue,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: elev2(),
                        ),
                        child: Text(editing ? s.save : s.subsAdd,
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

  /// 一枚可点的小胶囊：选中是实心底，未选中是浅底细边
  Widget _chip({
    required String label,
    IconData? icon,
    required bool on,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? color : C.bgSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? color : C.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: on ? Colors.white : C.grey),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: ts(12,
                    c: on ? Colors.white : C.slate, w: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  void _submit(BuildContext ctx, SubRule? rule) {
    final s = S.of(context);
    final value = _input.text.trim();
    if (value.isEmpty) return;
    if (rule == null) {
      final ok = widget.state.addSubscription(
        _kind,
        value,
        asSource: _asSource,
        asPath: _asPath,
        packet: _packet,
      );
      Navigator.pop(ctx);
      _toast(ok ? s.subsAdded(value) : s.subsExists(value));
      return;
    }
    widget.state.updateSubscription(
      rule.id,
      kind: _kind,
      value: value,
      asSource: _asSource,
      asPath: _asPath,
      packet: _packet,
    );
    Navigator.pop(ctx);
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
              const SizedBox(height: 12),
              _notifyRow(s, st),
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
            child: GestureDetector(
              // 整条名字区域可点 = 改这一条（之前只能删掉重加）
              onTap: () => _editSheet(rule: r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(13, w: FontWeight.w800, ls: 0.4)),
                  const SizedBox(height: 2),
                  Text(
                    _ruleSub(s, r),
                    style: ts(10, c: C.grey),
                  ),
                ],
              ),
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

  /// 命中要不要弹到系统通知栏（默认开）。
  ///
  /// 命中记录不受它影响：关掉只是不弹通知，命中照旧记在下面。
  Widget _notifyRow(S s, AppState st) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
      decoration: BoxDecoration(
        color: C.surfaceFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border, width: 0.6),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active_rounded, size: 16, color: C.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(s.subsNotify,
                style: ts(12, c: C.slate, w: FontWeight.w600)),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: st.subsNotify,
              onChanged: (v) => st.setSubsNotify(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addRow(S s) {
    return GestureDetector(
      onTap: () => _editSheet(),
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

  /// 一条命中是靠什么进来的：「发出 · 信标」「中继 · 消息」……
  ///
  /// 关键词口径没有身份，只写报文种类；升级前的老记录两个字段都没有，返回空。
  String _hitTag(S s, SubHit h, SubRule? rule) {
    final bits = <String>[];
    if (rule == null || rule.kind != SubKind.keyword) {
      final r = h.role;
      if (r != null) {
        bits.add(r == SubRole.source ? s.subsHitSource : s.subsHitPath);
      }
    }
    if (h.packet == 'beacon') bits.add(s.subsPacketBeacon);
    if (h.packet == 'message') bits.add(s.subsPacketMessage);
    return bits.join(' · ');
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
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _hitTag(s, h, rule),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts(9, c: C.grey, w: FontWeight.w700),
                ),
              ),
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
