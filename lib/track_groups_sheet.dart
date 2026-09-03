import 'package:flutter/material.dart';

import 'theme.dart';
import 'models.dart';
import 'state.dart';
import 'widgets.dart';
import 'tracker_page.dart';

/// 跟踪组管理面板：列出跟踪组 → 进入跟踪 / 新建 / 编辑成员 / 删除
void showTrackGroupsSheet(BuildContext context, AppState st) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _TrackGroupsSheet(state: st),
  );
}

class _TrackGroupsSheet extends StatefulWidget {
  final AppState state;
  const _TrackGroupsSheet({required this.state});
  @override
  State<_TrackGroupsSheet> createState() => _TrackGroupsSheetState();
}

class _TrackGroupsSheetState extends State<_TrackGroupsSheet> {
  AppState get st => widget.state;

  void _enter(TrackGroup g) {
    Navigator.pop(context); // 关面板
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrackerPage(state: st, group: g)),
    );
  }

  Future<void> _createGroup() async {
    final name = await _askName(context, '');
    if (name == null || name.trim().isEmpty || !mounted) return;
    final g = st.createTrackGroup(name.trim());
    if (!mounted) return;
    final ok = await _pickMembers(context, g, creating: true);
    if (ok == true && mounted) _enter(g);
  }

  Future<void> _editGroup(TrackGroup g) async {
    final picked = await _pickMembers(context, g, creating: false);
    if (picked == true && mounted) setState(() {});
  }

  Future<String?> _askName(BuildContext ctx, String initial) async {
    final ctrl = TextEditingController(text: initial);
    final r = await showDialog<String>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          S.of(dctx).newTrackGroup,
          style: ts(15, w: FontWeight.w800),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: ts(14),
          decoration: InputDecoration(
            hintText: S.of(dctx).trackGroupNameHint,
            filled: true,
            fillColor: C.bgSoft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(S.of(dctx).cancel, style: ts(13, c: C.slate)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.blue),
            onPressed: () => Navigator.pop(dctx, ctrl.text.trim()),
            child: Text(S.of(dctx).confirm, style: ts(13)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return r;
  }

  /// 从所有已见台站勾选成员
  Future<bool?> _pickMembers(
    BuildContext ctx,
    TrackGroup g, {
    required bool creating,
  }) async {
    final candidates = st.stations
        .where((s) => s.lat != 0 || s.lng != 0)
        .toList()
      ..sort((a, b) => b.lastHeard.compareTo(a.lastHeard));
    final selected = <String>{
      ...g.calls,
      st.myFullCall.toUpperCase(),
    };
    final r = await showModalBottomSheet<bool>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sctx) => StatefulBuilder(
        builder: (sctx, setSheet) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sctx).size.height * 0.8,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
                child: Row(
                  children: [
                    Icon(Icons.group_rounded, size: 20, color: C.blue),
                    const SizedBox(width: 8),
                    Text(
                      creating
                          ? S.of(sctx).pickTrackMembers
                          : S.of(sctx).editTrackGroup,
                      style: ts(16, w: FontWeight.w800),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(sctx),
                      child: Text(S.of(sctx).close, style: ts(13, c: C.grey)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    for (final s in candidates)
                      CheckboxListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(s.call, style: ts(13, w: FontWeight.w600)),
                        subtitle: Text(
                          S.of(sctx).trackMemberSub(
                            s.typeName,
                            localizedLastSeen(sctx, s),
                          ),
                          style: ts(10, c: C.grey),
                        ),
                        secondary: CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              s.color.withValues(alpha: 0.2),
                          child: Icon(s.icon, size: 14, color: s.color),
                        ),
                        value: selected.contains(s.call.toUpperCase()),
                        onChanged: (v) => setSheet(() {
                          final u = s.call.toUpperCase();
                          if (v == true) {
                            selected.add(u);
                          } else {
                            selected.remove(u);
                          }
                        }),
                      ),
                    if (candidates.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          S.of(sctx).noStationsYet,
                          textAlign: TextAlign.center,
                          style: ts(12, c: C.grey),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: C.blue),
                    onPressed: () => Navigator.pop(sctx, true),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      S.of(sctx).saveAndTrack,
                      style: ts(14, w: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (r == true) {
      // 始终包含自己
      st.updateTrackGroup(g.id, calls: selected);
      return true;
    }
    return false;
  }

  void _deleteGroup(TrackGroup g) {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(S.of(dctx).deleteTrackGroup, style: ts(15, w: FontWeight.w800)),
        content: Text(
          S.of(dctx).deleteTrackGroupConfirm(g.name),
          style: ts(13, h: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(S.of(dctx).cancel, style: ts(13, c: C.slate)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.red),
            onPressed: () {
              st.deleteTrackGroup(g.id);
              Navigator.pop(dctx);
              if (mounted) setState(() {});
            },
            child: Text(S.of(dctx).confirmDelete, style: ts(13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = List<TrackGroup>.from(st.trackGroups);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
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
            const SizedBox(height: 12),
            // 新建按钮
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: C.blue),
                onPressed: _createGroup,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  S.of(context).newTrackGroup,
                  style: ts(14, w: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
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
                            backgroundColor: C.blueBg,
                            child: Icon(Icons.group_rounded,
                                size: 18, color: C.blue),
                          ),
                          title: Text(
                            g.name,
                            style: ts(13, w: FontWeight.w700),
                          ),
                          subtitle: Text(
                            S.of(context).memberCount(g.calls.length),
                            style: ts(10, c: C.grey),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.edit_rounded,
                                    size: 16, color: C.slate),
                                tooltip: S.of(context).editTrackGroup,
                                onPressed: () => _editGroup(g),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.delete_outline_rounded,
                                    size: 16, color: C.red),
                                tooltip: S.of(context).deleteTrackGroup,
                                onPressed: () => _deleteGroup(g),
                              ),
                            ],
                          ),
                          onTap: () => _enter(g),
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
