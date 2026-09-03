import 'package:flutter/material.dart';

import 'theme.dart';
import 'models.dart';
import 'state.dart';
import 'widgets.dart';
import 'tracker_page.dart';

/// 从聊天群进入群组跟踪：列出所有聊天群 → 点击进入跟踪该群成员
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

  @override
  Widget build(BuildContext context) {
    final groups = List<ChatGroup>.from(state.chatGroups)
      ..sort((a, b) => a.name.compareTo(b.name));
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
