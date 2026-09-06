import 'package:flutter/material.dart';

import 'theme.dart';
import 'models.dart';
import 'state.dart';
import 'widgets.dart';
import 'tracker_page.dart';

/// 从聊天群进入群组跟踪：列出所有聊天群 → 点击进入跟踪该群成员；
/// 也可“快速新建跟踪组”（从已接收台站勾选成员 + 手输补充）
void showTrackGroupPicker(BuildContext context, AppState st) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _GroupPicker(state: st),
  );
}

class _GroupPicker extends StatelessWidget {
  final AppState state;
  const _GroupPicker({required this.state});

  void _enter(BuildContext ctx, ChatGroup g) {
    Navigator.pop(ctx); // 关面板
    Navigator.push(
      ctx,
      MaterialPageRoute(builder: (_) => TrackerPage(state: state, group: g)),
    );
  }

  void _quickCreate(BuildContext ctx) async {
    // 在当前面板之上叠加“快速创建”弹层，结果用返回值回传；
    // 不手动连续 pop 多层，避免路由时序问题。
    final g = await showModalBottomSheet<ChatGroup>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (_) => _QuickCreateSheet(state: state),
    );
    if (g == null) return;
    // 关掉选群面板，进入跟踪页
    Navigator.of(ctx).pop();
    Navigator.of(ctx).push(
      MaterialPageRoute(builder: (_) => TrackerPage(state: state, group: g)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = List<ChatGroup>.from(state.chatGroups)
      ..sort((a, b) => a.name.compareTo(b.name));
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gps_fixed_rounded, size: 20, color: C.blue),
                const SizedBox(width: 8),
                Text(
                  S.of(context).groupTracking,
                  style: ts(16, w: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: C.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              S.of(context).groupTrackingHint,
              style: ts(11, c: C.grey, h: 1.5),
            ),
            const SizedBox(height: 8),
            // 快速新建跟踪组入口
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _quickCreate(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: C.blueBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: C.blue),
                    const SizedBox(width: 8),
                    Text(
                      S.of(context).quickTrackCreate,
                      style: ts(13, c: C.blue, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (groups.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: C.bgSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  S.of(context).trackGroupsEmptyHint,
                  textAlign: TextAlign.center,
                  style: ts(12, c: C.grey, h: 1.5),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final g in groups)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: C.bgSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 17,
                            backgroundColor: C.orangeBg,
                            child: Icon(Icons.group_rounded,
                                size: 18, color: C.orange),
                          ),
                          title: Text(
                            g.name,
                            style: ts(13, w: FontWeight.w700),
                          ),
                          subtitle: Text(
                            S
                                .of(context)
                                .memberOnlineCount(
                                  g.confirmedMembers.length,
                                  g.confirmedMembers.where((c) {
                                    for (final s in state.stations) {
                                      if (s.call.toUpperCase() == c) {
                                        return s.effectiveStatus != St.offline;
                                      }
                                    }
                                    return false;
                                  }).length,
                                ),
                            style: ts(10, c: C.grey),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Colors.black45,
                          ),
                          onTap: () => _enter(context, g),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 快速创建跟踪组：从已接收台站勾选 + 手输呼号
class _QuickCreateSheet extends StatefulWidget {
  final AppState state;
  const _QuickCreateSheet({required this.state});

  @override
  State<_QuickCreateSheet> createState() => _QuickCreateSheetState();
}

class _QuickCreateSheetState extends State<_QuickCreateSheet> {
  final _nameCtrl = TextEditingController();
  final _manualCtrl = TextEditingController();
  final Set<String> _picked = {};

  AppState get st => widget.state;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  /// 可勾选的台站：接收范围内且有位置/见过的台站（排除我自己与已手动输入的）
  List<String> get _candidates {
    final out = <String>[];
    final seen = <String>{};
    for (final s in st.stations) {
      if (!st.stationAllowedFor(s)) continue;
      final c = s.call.toUpperCase();
      if (c == st.myFullCall.toUpperCase()) continue;
      if (seen.add(c)) out.add(c);
    }
    out.sort();
    return out;
  }

  void _applyManual() {
    final text = _manualCtrl.text.trim();
    if (text.isEmpty) return;
    for (final part in text.split(RegExp(r'[,\s;，；]'))) {
      final c = part.trim().toUpperCase();
      if (c.isEmpty) continue;
      if (!RegExp(r'^[A-Z0-9]+-[A-Z0-9]+$').hasMatch(c) &&
          !RegExp(r'^[A-Z0-9]+$').hasMatch(c)) {
        continue;
      }
      _picked.add(c);
    }
    setState(() {});
  }

  ChatGroup _build() {
    final name = _nameCtrl.text.trim().isEmpty
        ? '跟踪组'
        : _nameCtrl.text.trim();
    // 仅跟踪用：成员全部视为已加入，不发邀请、不入聊天列表
    final g = ChatGroup(
      id: 'track_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      groupCall: 'T${DateTime.now().millisecondsSinceEpoch % 100000}',
      owner: st.myCall,
    );
    for (final c in _picked) {
      g.memberStatus[c] = GroupMemberStatus.joined;
    }
    return g;
  }

  void _confirm() {
    if (_picked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).quickTrackNeedMembers),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pop(_build());
  }

  @override
  Widget build(BuildContext context) {
    final cands = _candidates;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.group_add_rounded, size: 20, color: C.blue),
                const SizedBox(width: 8),
                Text(
                  S.of(context).quickTrackCreate,
                  style: ts(16, w: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: C.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              S.of(context).quickTrackHint,
              style: ts(11, c: C.grey, h: 1.5),
            ),
            const SizedBox(height: 12),
            // 组名（可选）
            TextField(
              controller: _nameCtrl,
              style: ts(13),
              decoration: InputDecoration(
                labelText: S.of(context).quickTrackName,
                labelStyle: ts(12, c: C.grey),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: C.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: C.border),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 从接收台站勾选
            Text(
              S.of(context).quickTrackPickLabel,
              style: ts(12, c: C.slate, w: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (cands.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.bgSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  S.of(context).quickTrackNoStations,
                  style: ts(11, c: C.grey),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in cands)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _picked.contains(c),
                        title: Text(
                          c,
                          style: ts(12.5, c: C.ink, w: FontWeight.w600),
                        ),
                        onChanged: (v) =>
                            setState(() => v! ? _picked.add(c) : _picked.remove(c)),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            // 手输补充
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualCtrl,
                    style: ts(13),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: S.of(context).quickTrackManualHint,
                      hintStyle: ts(12, c: C.greyLight),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: C.border),
                      ),
                    ),
                    onSubmitted: (_) => _applyManual(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _applyManual,
                  icon: Icon(Icons.add_rounded, color: C.blue),
                ),
              ],
            ),
            if (_picked.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in _picked)
                    InputChip(
                      label: Text(c, style: ts(11, w: FontWeight.w700)),
                      onDeleted: () => setState(() => _picked.remove(c)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: C.blueBg,
                      deleteIconColor: C.blue,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _confirm,
                icon: Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(
                  S.of(context).quickTrackStart,
                  style: ts(13, w: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: C.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
