import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'models.dart';
import 'state.dart';
import 'widgets.dart';
import 'station_detail.dart';

class MessagesPage extends StatefulWidget {
  final AppState state;
  final bool isActive; // 是否当前显示的 tab（IndexedStack 中非活动页不拦截返回键）
  const MessagesPage({super.key, required this.state, this.isActive = true});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  String _selected = '';
  bool _showList = true;
  bool _feedMode = true; // 瀑布流模式（默认）
  String? _selectedGroupId; // 当前打开的群聊ID
  final Set<String> _groupRecipients = {}; // 临时群发目标（创建群聊用）
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _scrollFeed = ScrollController();
  final _scrollGroup = ScrollController();
  final _scrollChat = ScrollController();
  final _manualAddCtrl = TextEditingController(); // 手动添加呼号

  Widget get _manualAddField => TextField(
    controller: _manualAddCtrl,
    style: ts(12),
    textCapitalization: TextCapitalization.characters,
    onSubmitted: (_) {
      final call = _manualAddCtrl.text.trim().toUpperCase();
      if (call.isNotEmpty && call.length >= 3) {
        _manualAddCtrl.clear();
      }
    },
    decoration: InputDecoration(
      hintText: S.of(context).manualCallsignHint,
      hintStyle: ts(11, c: C.greyLight),
      isDense: true,
      filled: true,
      fillColor: C.bgSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
  );

  @override
  void initState() {
    super.initState();
    _loadFeedMode();
  }

  Future<void> _loadFeedMode() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _feedMode = p.getBool('msg_feed_mode') ?? true);
  }

  Future<void> _saveFeedMode(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('msg_feed_mode', v);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _scrollFeed.dispose();
    _scrollGroup.dispose();
    _scrollChat.dispose();
    _manualAddCtrl.dispose();
    super.dispose();
  }

  List<String> _partners(AppState st) {
    final s = <String>{};
    for (final m in st.messages) {
      // 排除群聊消息（有 groupId 或收件人是群呼号）
      if (m.groupId != null) continue;
      final isGroupCall = st.chatGroups.any(
        (g) =>
            g.groupCall.toUpperCase() == m.to.toUpperCase() ||
            g.groupCall.toUpperCase() == m.from.toUpperCase(),
      );
      if (isGroupCall) continue;
      s.add(m.sent ? m.to : m.from);
    }
    // 收藏/手动联系人也显示在会话列表
    for (final st2 in st.stations) {
      if (st2.favorite || st2.manual) s.add(st2.call);
    }
    return s.toList();
  }

  List<AprsMsg> _chatWith(AppState st, String call) => st.messages.where((m) {
    // 排除群聊消息
    if (m.groupId != null) return false;
    final isGroupCall = st.chatGroups.any(
      (g) =>
          g.groupCall.toUpperCase() == m.to.toUpperCase() ||
          g.groupCall.toUpperCase() == m.from.toUpperCase(),
    );
    if (isGroupCall) return false;
    return m.from == call || m.to == call;
  }).toList();

  bool _isFav(AppState st, String call) {
    for (final s in st.stations) {
      if (s.call == call) return s.favorite;
    }
    return false;
  }

  /// 按呼号打开站台面板（找不到时用临时对象）
  void _openStation(AppState st, String call) {
    Station? found;
    for (final x in st.stations) {
      if (x.call == call) {
        found = x;
        break;
      }
    }
    final station =
        found ??
        Station(
          call: call,
          symbol: '/',
          lat: st.myLat ?? 0,
          lng: st.myLng ?? 0,
          lastHeard: DateTime.now(),
          status: St.offline,
          comment: S.of(context).noPacketReceived,
        );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StationDetail(state: st, station: station),
    );
  }

  /// 会话对方的网格定位
  String _partnerGrid(AppState st, String call) {
    for (final s in st.stations) {
      if (s.call == call) return s.grid;
    }
    return 'APRS';
  }

  /// 群聊消息：合并所有群成员的收发消息，返回 (消息, 发送者呼号) 按时间倒序
  List<(AprsMsg, String)> _groupMessages(AppState st, {ChatGroup? group}) {
    final result = <(AprsMsg, String)>[];
    // 兼容旧版：未指定 group 时用 _groupRecipients
    final members = group?.confirmedMembers ?? _groupRecipients;
    for (final m in st.messages) {
      // 新版：通过 groupId 匹配（不依赖成员是否已确认）
      if (group != null && m.groupId == group.id) {
        final sender = m.sent ? S.of(context).meLabel : m.from;
        result.add((m, sender));
        continue;
      }
      // 兼容旧版群发（无 groupId）：按成员过滤
      if (group == null) {
        if (members.isEmpty) continue;
        if (m.sent) {
          if (members.contains(m.to)) result.add((m, S.of(context).meLabel));
        } else {
          if (members.contains(m.from)) result.add((m, m.from));
        }
      }
    }
    result.sort((a, b) => b.$1.time.compareTo(a.$1.time));
    return result;
  }

  /// 获取某个群聊的未读消息数
  int _groupUnreadCount(AppState st, ChatGroup group) =>
      st.groupUnreadCount(group.id);

  /// 获取某个群聊的最后一条消息预览
  (String sender, String text, DateTime time)? _groupLastMsg(
    AppState st,
    ChatGroup group,
  ) {
    for (final m in st.messages) {
      if (m.groupId == group.id) {
        final sender = m.sent ? S.of(context).meLabel : m.from;
        return (sender, m.text, m.time);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final st = widget.state;
        final partners = _partners(st);
        if (_selected.isEmpty && partners.isNotEmpty)
          _selected = partners.first;

        return LayoutBuilder(
          builder: (context, constraints) {
            final landscape =
                MediaQuery.of(context).orientation == Orientation.landscape;
            final narrow = !landscape && constraints.maxWidth < 720;
            // 是否处于"聊天详情"（窄屏下非列表页）
            final inChatDetail = !_feedMode && narrow && !_showList;
            // 非活动 tab（IndexedStack 隐藏时）不拦截返回键
            final interceptBack = widget.isActive && inChatDetail;
            return PopScope(
              canPop: !interceptBack,
              onPopInvokedWithResult: (didPop, _) {
                // 系统返回键：从聊天详情回到会话列表
                if (!didPop && interceptBack) {
                  setState(() {
                    _selectedGroupId = null;
                    _showList = true;
                  });
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 页面标题 + 瀑布流/会话切换
                    Row(
                      children: [
                        Text(S.of(context).messages, style: T.h1),
                        const Spacer(),
                        _modeToggle(),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _feedMode
                          ? _feedPane(st)
                          : narrow
                          ? (_showList
                                ? _listPane(st, partners)
                                : _chatPane(st))
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: 280,
                                  child: _listPane(st, partners),
                                ),
                                const SizedBox(width: 16),
                                Expanded(child: _chatPane(st)),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── 瀑布流 / 会话 切换 ───
  Widget _modeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: C.bgSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modePill(true, S.of(context).feedMode),
          _modePill(false, S.of(context).conversationMode),
        ],
      ),
    );
  }

  Widget _modePill(bool feed, String label) {
    final sel = _feedMode == feed;
    return GestureDetector(
      onTap: () {
        setState(() => _feedMode = feed);
        _saveFeedMode(feed);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? C.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: ts(12, c: sel ? Colors.white : C.slate, w: FontWeight.w600),
        ),
      ),
    );
  }

  // ─── 瀑布流：全部消息连续滚动 ───
  Widget _feedPane(AppState st) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: C.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.waves_rounded, size: 16, color: C.blue),
                SizedBox(width: 6),
                Text(
                  S.of(context).messageFeed,
                  style: ts(12, c: C.blue, w: FontWeight.w700),
                ),
                Spacer(),
                Text(
                  S.of(context).messageTotal(st.messages.length),
                  style: ts(11, c: C.grey),
                ),
              ],
            ),
          ),
          // 列表：reverse=true，新消息在最底部，自动跟随
          Expanded(
            child: st.messages.isEmpty
                ? Center(
                    child: Text(
                      S.of(context).noMessages,
                      style: TextStyle(color: C.grey, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollFeed,
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: st.messages.length,
                    itemBuilder: (_, i) {
                      final m = st.messages[i];
                      return GestureDetector(
                        onTap: () {
                          // 群聊消息 → 打开对应群聊；私聊 → 打开对应联系人
                          // 同时退出瀑布流模式进入会话模式
                          if (m.groupId != null) {
                            setState(() {
                              _feedMode = false;
                              _saveFeedMode(false);
                              _selectedGroupId = m.groupId;
                              _selected = '';
                              _showList = false;
                            });
                          } else {
                            setState(() {
                              _feedMode = false;
                              _saveFeedMode(false);
                              _selectedGroupId = null;
                              _selected = m.sent ? m.to : m.from;
                              _showList = false;
                            });
                          }
                        },
                        child: _feedBubble(m),
                      );
                    },
                  ),
          ),
          _inputBar(st),
        ],
      ),
    );
  }

  Widget _feedBubble(AprsMsg m) {
    final mine = m.sent;
    // 群聊名称
    String? groupName;
    if (m.groupId != null) {
      for (final g in widget.state.chatGroups) {
        if (g.id == m.groupId) {
          groupName = g.name;
          break;
        }
      }
    }
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: m.text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).copiedClipboard),
            backgroundColor: C.blue,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? C.blueBg : C.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: mine ? C.blue.withValues(alpha: 0.2) : C.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${m.time.hour.toString().padLeft(2, '0')}:'
              '${m.time.minute.toString().padLeft(2, '0')}:'
              '${m.time.second.toString().padLeft(2, '0')}',
              style: mono(9, c: C.grey),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (m.groupId != null)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: C.orangeBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            groupName ?? S.of(context).groupShortLabel,
                            style: ts(8, c: C.orange, w: FontWeight.w700),
                          ),
                        ),
                      Text(
                        mine ? '→ ${m.to}' : '← ${m.from}',
                        style: ts(
                          10,
                          c: mine ? C.blue : C.green,
                          w: FontWeight.w700,
                        ),
                      ),
                      if (mine && m.groupId == null) ...[
                        SizedBox(width: 4),
                        Icon(
                          m.acked ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 11,
                          color: m.acked ? C.blue : C.greyLight,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2),
                  _urlRichText(m.text, ts(12, c: C.ink)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 输入栏（瀑布流 / 会话共用） ───
  Widget _inputBar(AppState st) {
    final inGroupChat = _selectedGroupId != null;
    final group = inGroupChat
        ? st.chatGroups.where((g) => g.id == _selectedGroupId).firstOrNull
        : null;
    final hintText = inGroupChat
        ? S.of(context).sendToGroupHint(group?.name ?? S.of(context).groupChat)
        : _selected.isNotEmpty
        ? S.of(context).sendToCallHint(_selected)
        : S.of(context).selectMessageReply;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: C.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              style: ts(13),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: ts(13, c: C.grey),
                filled: true,
                fillColor: C.bgSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: C.blue,
                borderRadius: BorderRadius.circular(12),
                boxShadow: softShadow(blur: 12, alpha: 0.2),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listPane(AppState st, List<String> partners) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(S.of(context).conversations, style: T.h2),
                    Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: C.blueBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${st.messages.length}',
                        style: ts(11, c: C.blue, w: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                // 快捷操作：新建会话 / 群发 / 新建群聊
                Row(
                  children: [
                    _convActionBtn(
                      Icons.add_comment_rounded,
                      S.of(context).newConversation,
                      C.blue,
                      () {
                        _showAddConversationDialog(st);
                      },
                    ),
                    SizedBox(width: 6),
                    _convActionBtn(
                      Icons.campaign_rounded,
                      S.of(context).broadcastShort,
                      C.purple,
                      () {
                        _showBroadcastDialog(st);
                      },
                    ),
                    SizedBox(width: 6),
                    _convActionBtn(
                      Icons.group_add_rounded,
                      S.of(context).newGroup,
                      C.orange,
                      () {
                        _showCreateGroupDialog(st);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1),
          // ─── 统一会话列表（群聊 + 单聊） ───
          Expanded(
            child: st.chatGroups.isEmpty && partners.isEmpty
                ? Center(
                    child: Text(
                      S.of(context).noConversations,
                      style: ts(12, c: C.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: st.chatGroups.length + partners.length,
                    itemBuilder: (_, i) {
                      // 群聊在前，单聊在后
                      if (i < st.chatGroups.length) {
                        final g = st.chatGroups[i];
                        return _groupListItem(st, g);
                      }
                      final p = partners[i - st.chatGroups.length];
                      return _chatListItem(st, p);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _groupListItem(AppState st, ChatGroup g) {
    final unread = _groupUnreadCount(st, g);
    final last = _groupLastMsg(st, g);
    final sel = _selectedGroupId == g.id;
    return GestureDetector(
      onTap: () {
        st.markGroupRead(g.id);
        setState(() {
          _selectedGroupId = g.id;
          _selected = '';
          _showList = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? C.orangeBg : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: sel ? C.orange : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: C.orangeBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.group_rounded, color: C.orange, size: 20),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          g.name,
                          style: ts(
                            13,
                            w: FontWeight.w600,
                            c: sel ? C.orange : C.slate,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: C.orangeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          S.of(context).groupShortLabel,
                          style: ts(8, c: C.orange, w: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1),
                  Text(
                    last != null
                        ? '${last.$1}: ${last.$2}'
                        : S.of(context).memberCount(g.confirmedMembers.length),
                    style: ts(11, c: C.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: C.orange,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$unread',
                  style: ts(9, c: Colors.white, w: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chatListItem(AppState st, String p) {
    final msgs = _chatWith(st, p);
    final last = msgs.isNotEmpty ? msgs.first : null;
    final unread = st.conversationUnread(p);
    final sel = _selected == p && _selectedGroupId == null;
    return GestureDetector(
      onTap: () {
        widget.state.markConversationRead(p);
        setState(() {
          _selected = p;
          _selectedGroupId = null;
          _showList = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? C.blueBg : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: sel ? C.blue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: C.blueBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: Text(
                  p.length >= 2 ? p.substring(p.length - 2) : p,
                  style: ts(11, c: C.blue, w: FontWeight.w700),
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p, style: ts(13, w: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text(
                    last?.text ?? '',
                    style: ts(11, c: C.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: C.blue,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$unread',
                  style: ts(9, c: Colors.white, w: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chatPane(AppState st) {
    // ─── 群聊视图 ───
    if (_selectedGroupId != null) {
      final group = st.chatGroups
          .where((g) => g.id == _selectedGroupId)
          .firstOrNull;
      if (group == null) {
        _selectedGroupId = null;
        return Center(
          child: Text(S.of(context).groupNotFound, style: ts(13, c: C.grey)),
        );
      }
      final msgs = _groupMessages(st, group: group);
      // 正在查看该群时，标记为已读
      if (_selectedGroupId == group.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedGroupId == group.id) {
            st.markGroupRead(group.id);
          }
        });
      }
      return SoftCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: C.border)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedGroupId = null;
                      _showList = true;
                    }),
                    child: Icon(Icons.arrow_back_rounded, color: C.grey),
                  ),
                  SizedBox(width: 10),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: C.orangeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.group_rounded, color: C.orange, size: 18),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showGroupMembersSheet(st, group),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(group.name, style: ts(14, w: FontWeight.w700)),
                          SizedBox(height: 1),
                          Text(
                            S.of(context).groupCallsignLine(group.groupCall),
                            style: ts(10, c: C.orange, w: FontWeight.w600),
                          ),
                          SizedBox(height: 1),
                          Text(
                            S
                                .of(context)
                                .memberCountTap(group.confirmedMembers.length),
                            style: ts(10, c: C.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 邀请按钮（仅群主可见）
                  if (group.isOwner(st.myCall))
                    GestureDetector(
                      onTap: () => _showInviteMemberDialog(st, group),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: C.greenBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_add_rounded,
                              size: 12,
                              color: C.green,
                            ),
                            SizedBox(width: 3),
                            Text(
                              S.of(context).invite,
                              style: ts(10, c: C.green, w: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(width: 6),
                  // 非群主显示退出按钮
                  if (!group.isOwner(st.myCall))
                    GestureDetector(
                      onTap: () => _showLeaveGroupConfirm(st, group),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: C.redBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          S.of(context).leaveAction,
                          style: ts(10, c: C.red, w: FontWeight.w600),
                        ),
                      ),
                    ),
                  if (!group.isOwner(st.myCall)) SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _showEditGroupDialog(st, group),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: C.blueBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        S.of(context).manage,
                        style: ts(10, c: C.blue, w: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: msgs.isEmpty
                  ? Center(
                      child: Text(
                        S.of(context).noGroupMessages,
                        style: ts(13, c: C.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollGroup,
                      reverse: true,
                      padding: const EdgeInsets.all(14),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final (msg, sender) = msgs[i];
                        return _bubble(
                          msg,
                          groupSender: sender,
                          onSenderTap: sender == S.of(context).meLabel
                              ? null
                              : () => _openStation(st, sender),
                        );
                      },
                    ),
            ),
            _inputBar(st),
          ],
        ),
      );
    }
    // ─── 单聊视图 ───
    return _selected.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.forum_outlined, size: 52, color: C.greyLight),
                SizedBox(height: 12),
                Text(
                  S.of(context).selectConversation,
                  style: ts(14, c: C.grey),
                ),
              ],
            ),
          )
        : SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: C.border)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _showList = true),
                        child: Icon(Icons.arrow_back_rounded, color: C.grey),
                      ),
                      SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _openStation(st, _selected),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: C.blueBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  _selected.length >= 2
                                      ? _selected.substring(
                                          _selected.length - 2,
                                        )
                                      : _selected,
                                  style: ts(10, c: C.blue, w: FontWeight.w700),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(_selected, style: ts(15, w: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Spacer(),
                      GestureDetector(
                        onTap: () => st.toggleFavorite(_selected),
                        child: Icon(
                          _isFav(st, _selected)
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 22,
                          color: _isFav(st, _selected) ? C.orange : C.grey,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        _partnerGrid(st, _selected),
                        style: mono(10, c: C.grey),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: _scrollChat,
                    reverse: true,
                    padding: const EdgeInsets.all(14),
                    children: _chatWith(
                      st,
                      _selected,
                    ).map((m) => _bubble(m)).toList(),
                  ),
                ),
                _inputBar(st),
              ],
            ),
          );
  }

  Widget _bubble(AprsMsg m, {String? groupSender, VoidCallback? onSenderTap}) {
    final mine = m.sent;
    // 系统消息：居中灰色小字
    if (m.system) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: C.greyLight.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            localizedSystemMessage(context, m.text),
            style: ts(10, c: C.grey, w: FontWeight.w500),
          ),
        ),
      );
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: m.text));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context).copiedClipboard),
              backgroundColor: C.blue,
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.55,
          ),
          decoration: BoxDecoration(
            color: mine ? C.blueBg : C.bgSoft,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 4),
              bottomRight: Radius.circular(mine ? 4 : 14),
            ),
            border: Border.all(
              color: mine ? C.blue.withValues(alpha: 0.15) : C.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine && groupSender != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: GestureDetector(
                    onTap: onSenderTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          groupSender,
                          style: ts(
                            10,
                            c: _memberColor(groupSender),
                            w: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 10,
                          color: C.greyLight,
                        ),
                      ],
                    ),
                  ),
                ),
              _urlRichText(m.text, ts(13)),
              SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${m.time.hour.toString().padLeft(2, '0')}:${m.time.minute.toString().padLeft(2, '0')}',
                    style: ts(9, c: C.grey),
                  ),
                  if (mine && m.groupId == null) ...[
                    SizedBox(width: 4),
                    Icon(
                      m.acked ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 12,
                      color: m.acked ? C.blue : C.greyLight,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 群成员名字颜色：根据呼号哈希从一组颜色中选一个
  static final _memberColors = [
    C.blue,
    C.green,
    C.orange,
    C.purple,
    Color(0xFF0D9488),
    Color(0xFFDB2777),
    Color(0xFFB45309),
  ];

  Color _memberColor(String call) {
    final h = call.codeUnits.fold<int>(0, (acc, u) => (acc + u) * 31);
    return _memberColors[h.abs() % _memberColors.length];
  }

  /// 解析文本中的 URL，返回可点击的 RichText
  Widget _urlRichText(String text, TextStyle baseStyle) {
    final urlRe = RegExp(
      r'(https?://[^\s<>"{}|\\^`\[\]]+|www\.[^\s<>"{}|\\^`\[\]]+)',
      caseSensitive: false,
    );
    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in urlRe.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final url = match.group(0)!;
      final fullUrl = url.startsWith('http') ? url : 'https://$url';
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: C.blue,
            decoration: TextDecoration.underline,
            decorationColor: C.blue,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => launchUrl(
              Uri.parse(fullUrl),
              mode: LaunchMode.externalApplication,
            ),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: text));
    return RichText(
      text: TextSpan(children: spans, style: baseStyle),
    );
  }

  /// 会话页快捷操作按钮
  Widget _convActionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: ts(11, c: color, w: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 新建会话对话框（手动添加联系人并打开会话）
  void _showAddConversationDialog(AppState st) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = ctrl.text.trim().toUpperCase();
          final suggestions = q.isEmpty
              ? <Station>[]
              : st.stations
                    .where(
                      (s) =>
                          s.call.toUpperCase().contains(q) &&
                          s.call != st.myFullCall,
                    )
                    .take(8)
                    .toList();
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              S.of(context).newConversation,
              style: ts(16, w: FontWeight.w700),
            ),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    S.of(context).newConversationDesc,
                    style: ts(12, c: C.grey),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    style: ts(14),
                    onChanged: (_) => setDialogState(() {}),
                    onSubmitted: (_) => _startConversation(st, ctrl.text),
                    decoration: InputDecoration(
                      hintText: S.of(context).callsignExample,
                      hintStyle: ts(13, c: C.greyLight),
                      filled: true,
                      fillColor: C.bgSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (suggestions.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: C.bgSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: suggestions.map((s) {
                          return GestureDetector(
                            onTap: () {
                              ctrl.text = s.call;
                              setDialogState(() {});
                              _startConversation(st, s.call);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: C.border,
                                    width: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.radio_button_checked_rounded,
                                    size: 14,
                                    color: C.blue,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    s.call,
                                    style: ts(13, w: FontWeight.w600),
                                  ),
                                  Spacer(),
                                  Text(s.typeName, style: ts(10, c: C.grey)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).cancel, style: ts(13, c: C.grey)),
              ),
              FilledButton(
                onPressed: () => _startConversation(st, ctrl.text),
                style: FilledButton.styleFrom(
                  backgroundColor: C.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  S.of(context).start,
                  style: ts(13, c: Colors.white, w: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 开始新会话
  void _startConversation(AppState st, String callRaw) {
    final call = callRaw.trim().toUpperCase();
    if (call.isEmpty || call == st.myFullCall.toUpperCase()) return;
    // 添加到联系人（若不在列表）
    st.addManualStation(call);
    Navigator.pop(context);
    setState(() {
      _feedMode = false;
      _saveFeedMode(false);
      _selectedGroupId = null;
      _selected = call;
      _showList = false;
    });
  }

  /// 群发消息对话框（选择多个联系人，批量发送同一条消息）
  /// 群发消息对话框：两步向导（第1步选人 → 第2步填内容）
  void _showBroadcastDialog(AppState st) {
    final selected = <String>{};
    final searchCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    bool onlyOnline = true;
    int step = 1; // 1=选人, 2=填内容
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          var list = st.stations.where((s) => s.call != st.myFullCall).toList();
          if (onlyOnline) {
            list = list.where((s) => s.status != St.offline).toList();
          }
          final q = searchCtrl.text.trim().toUpperCase();
          if (q.isNotEmpty) {
            list = list.where((s) => s.call.toUpperCase().contains(q)).toList();
          }
          list.sort((a, b) {
            if (a.status == St.online && b.status != St.online) return -1;
            if (a.status != St.online && b.status == St.online) return 1;
            return a.call.compareTo(b.call);
          });
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.campaign_rounded, size: 18, color: C.purple),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of(context).broadcastMessage,
                    style: ts(16, w: FontWeight.w700),
                  ),
                ),
                // 步骤指示
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: C.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$step/2',
                    style: ts(11, c: C.purple, w: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.55,
              child: Column(
                children: [
                  // ─── 步骤指示条 ───
                  Row(
                    children: [
                      _stepDot(1, step, S.of(context).stepRecipients),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: step >= 2 ? C.purple : C.greyLight,
                        ),
                      ),
                      _stepDot(2, step, S.of(context).stepContent),
                    ],
                  ),
                  SizedBox(height: 12),
                  // ─── 第1步：选择接收人 ───
                  if (step == 1) ...[
                    // 搜索
                    TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      style: ts(13),
                      decoration: InputDecoration(
                        hintText: S.of(context).searchCallsign,
                        hintStyle: ts(12, c: C.greyLight),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: C.grey,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: C.bgSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        _pickerActionBtn(
                          S.of(context).selectAllOnline,
                          Icons.check_circle_outline_rounded,
                          () {
                            setDialogState(() {
                              for (final s in list) {
                                if (s.status != St.offline)
                                  selected.add(s.call);
                              }
                            });
                          },
                        ),
                        SizedBox(width: 6),
                        _pickerActionBtn(
                          S.of(context).clearSelection,
                          Icons.cancel_outlined,
                          () {
                            setDialogState(() => selected.clear());
                          },
                        ),
                        Spacer(),
                        GestureDetector(
                          onTap: () =>
                              setDialogState(() => onlyOnline = !onlyOnline),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: onlyOnline
                                  ? C.purple.withValues(alpha: 0.12)
                                  : C.bgSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  onlyOnline
                                      ? Icons.filter_list_rounded
                                      : Icons.filter_list_off_rounded,
                                  size: 14,
                                  color: onlyOnline ? C.purple : C.grey,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  onlyOnline
                                      ? S.of(context).onlineOnly
                                      : S.of(context).all,
                                  style: ts(
                                    10,
                                    c: onlyOnline ? C.purple : C.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    // 已选数量
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: C.purple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        selected.isEmpty
                            ? S.of(context).noRecipients
                            : S.of(context).selectedRecipients(selected.length),
                        style: ts(
                          11,
                          c: selected.isEmpty ? C.grey : C.purple,
                          w: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    Expanded(
                      child: list.isEmpty
                          ? Center(
                              child: Text(
                                S.of(context).noStations,
                                style: ts(12, c: C.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (_, i) {
                                final s = list[i];
                                final sel = selected.contains(s.call);
                                return GestureDetector(
                                  onTap: () => setDialogState(() {
                                    if (sel)
                                      selected.remove(s.call);
                                    else
                                      selected.add(s.call);
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 7,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          sel
                                              ? Icons.check_circle_rounded
                                              : Icons
                                                    .radio_button_unchecked_rounded,
                                          size: 20,
                                          color: sel ? C.purple : C.greyLight,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          s.call,
                                          style: ts(13, w: FontWeight.w600),
                                        ),
                                        Spacer(),
                                        Text(
                                          s.typeName,
                                          style: ts(10, c: C.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                  // ─── 第2步：填写内容 ───
                  if (step == 2) ...[
                    // 已选接收人汇总
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: C.purple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        S
                            .of(context)
                            .sendRecipientsList(
                              selected.length,
                              selected.join(', '),
                            ),
                        style: ts(11, c: C.purple, w: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: msgCtrl,
                      style: ts(13),
                      autofocus: true,
                      maxLines: 5,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: S.of(context).broadcastContentHint,
                        hintStyle: ts(12, c: C.greyLight),
                        filled: true,
                        fillColor: C.bgSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      S.of(context).broadcastHint,
                      style: ts(10, c: C.greyLight),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (step == 1) {
                    Navigator.pop(context);
                  } else {
                    setDialogState(() => step = 1);
                  }
                },
                child: Text(
                  step == 1 ? S.of(context).cancel : S.of(context).previous,
                  style: ts(13, c: C.grey),
                ),
              ),
              if (step == 1)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: C.purple,
                    disabledBackgroundColor: C.greyLight,
                  ),
                  onPressed: selected.isEmpty
                      ? null
                      : () => setDialogState(() => step = 2),
                  child: Text(
                    S.of(context).next,
                    style: ts(13, c: Colors.white, w: FontWeight.w700),
                  ),
                )
              else
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: C.purple,
                    disabledBackgroundColor: C.greyLight,
                  ),
                  onPressed: msgCtrl.text.trim().isEmpty
                      ? null
                      : () {
                          final text = msgCtrl.text.trim();
                          for (final call in selected) {
                            widget.state.sendMessage(call, text);
                          }
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                S.of(context).broadcastSent(selected.length),
                              ),
                              backgroundColor: C.purple,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                  child: Text(
                    S.of(context).send,
                    style: ts(13, c: Colors.white, w: FontWeight.w700),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _stepDot(int n, int current, String label) {
    final active = n <= current;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: active ? C.purple : C.greyLight,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$n',
              style: ts(10, c: Colors.white, w: FontWeight.w700),
            ),
          ),
        ),
        SizedBox(width: 4),
        Text(label, style: ts(10, c: active ? C.purple : C.grey)),
      ],
    );
  }

  /// 新建群聊对话框：两步向导（第1步填名称 → 第2步选成员）
  void _showCreateGroupDialog(AppState st) {
    final nameCtrl = TextEditingController();
    final selected = <String>{};
    bool onlyOnline = true;
    final searchCtrl = TextEditingController();
    int step = 1; // 1=填名称, 2=选成员
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          var list = st.stations.where((s) => s.call != st.myFullCall).toList();
          if (onlyOnline)
            list = list.where((s) => s.status != St.offline).toList();
          final q = searchCtrl.text.trim().toUpperCase();
          if (q.isNotEmpty)
            list = list.where((s) => s.call.toUpperCase().contains(q)).toList();
          list.sort((a, b) {
            if (a.status == St.online && b.status != St.online) return -1;
            if (a.status != St.online && b.status == St.online) return 1;
            return a.call.compareTo(b.call);
          });
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Row(
              children: [
                Icon(Icons.group_add_rounded, size: 18, color: C.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of(context).newGroup,
                    style: ts(16, w: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: C.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$step/2',
                    style: ts(11, c: C.orange, w: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.5,
              child: Column(
                children: [
                  // ─── 步骤指示条 ───
                  Row(
                    children: [
                      _stepDot(1, step, S.of(context).stepName),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: step >= 2 ? C.orange : C.greyLight,
                        ),
                      ),
                      _stepDot(2, step, S.of(context).stepMembers),
                    ],
                  ),
                  SizedBox(height: 14),
                  // ─── 第1步：填群名称 ───
                  if (step == 1) ...[
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      style: ts(14),
                      onChanged: (_) => setDialogState(() {}),
                      onSubmitted: (_) {
                        if (nameCtrl.text.trim().isNotEmpty) {
                          setDialogState(() => step = 2);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: S.of(context).groupNameHint,
                        hintStyle: ts(13, c: C.greyLight),
                        prefixIcon: Icon(
                          Icons.group_rounded,
                          size: 18,
                          color: C.orange,
                        ),
                        filled: true,
                        fillColor: C.bgSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: C.orangeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: C.orange,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              S.of(context).groupChatExplain,
                              style: ts(
                                11,
                                c: C.orange,
                                w: FontWeight.w500,
                                h: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Spacer(),
                  ],
                  // ─── 第2步：选择成员 ───
                  if (step == 2) ...[
                    TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      style: ts(13),
                      decoration: InputDecoration(
                        hintText: S.of(context).searchCallsign,
                        hintStyle: ts(12, c: C.greyLight),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: C.grey,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: C.bgSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        _pickerActionBtn(
                          S.of(context).selectAllOnline,
                          Icons.check_circle_outline_rounded,
                          () {
                            setDialogState(() {
                              for (final s in list) {
                                if (s.status != St.offline)
                                  selected.add(s.call);
                              }
                            });
                          },
                        ),
                        SizedBox(width: 6),
                        _pickerActionBtn(
                          S.of(context).clearSelection,
                          Icons.cancel_outlined,
                          () {
                            setDialogState(() => selected.clear());
                          },
                        ),
                        Spacer(),
                        GestureDetector(
                          onTap: () =>
                              setDialogState(() => onlyOnline = !onlyOnline),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: onlyOnline ? C.blueBg : C.bgSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  onlyOnline
                                      ? Icons.filter_list_rounded
                                      : Icons.filter_list_off_rounded,
                                  size: 14,
                                  color: onlyOnline ? C.blue : C.grey,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  onlyOnline
                                      ? S.of(context).onlineOnly
                                      : S.of(context).all,
                                  style: ts(
                                    10,
                                    c: onlyOnline ? C.blue : C.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // 已选数量
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: C.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        selected.isEmpty
                            ? S.of(context).noMembersSelected
                            : S.of(context).selectedRecipients(selected.length),
                        style: ts(
                          11,
                          c: selected.isEmpty ? C.grey : C.orange,
                          w: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: list.isEmpty
                          ? Center(
                              child: Text(
                                S.of(context).noStations,
                                style: ts(13, c: C.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (_, i) {
                                final s = list[i];
                                final sel = selected.contains(s.call);
                                return GestureDetector(
                                  onTap: () => setDialogState(() {
                                    if (sel)
                                      selected.remove(s.call);
                                    else
                                      selected.add(s.call);
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          sel
                                              ? Icons.check_circle_rounded
                                              : Icons
                                                    .radio_button_unchecked_rounded,
                                          size: 20,
                                          color: sel ? C.orange : C.greyLight,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          s.call,
                                          style: ts(13, w: FontWeight.w600),
                                        ),
                                        Spacer(),
                                        Text(
                                          s.typeName,
                                          style: ts(10, c: C.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (step == 1) {
                    Navigator.pop(ctx);
                  } else {
                    setDialogState(() => step = 1);
                  }
                },
                child: Text(
                  step == 1 ? S.of(context).cancel : S.of(context).previous,
                  style: ts(13, c: C.grey),
                ),
              ),
              if (step == 1)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: C.orange,
                    disabledBackgroundColor: C.greyLight,
                  ),
                  onPressed: nameCtrl.text.trim().isEmpty
                      ? null
                      : () => setDialogState(() => step = 2),
                  child: Text(
                    S.of(context).next,
                    style: ts(13, c: Colors.white, w: FontWeight.w700),
                  ),
                )
              else
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: C.orange,
                    disabledBackgroundColor: C.greyLight,
                  ),
                  onPressed: selected.isEmpty
                      ? null
                      : () {
                          final g = widget.state.createGroup(
                            nameCtrl.text.trim(),
                            selected,
                          );
                          // 向每个选中的成员发送 INVITE
                          for (final m in selected) {
                            widget.state.sendInvite(g.groupCall, m, g.name);
                          }
                          Navigator.pop(ctx);
                          setState(() {
                            _selectedGroupId = g.id;
                            _selected = '';
                            _showList = false;
                          });
                        },
                  child: Text(
                    S.of(context).create,
                    style: ts(13, c: Colors.white, w: FontWeight.w700),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 群管理面板（底部弹出）
  void _showEditGroupDialog(AppState st, ChatGroup group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollCtrl) => StatefulBuilder(
          builder: (ctx, setSheetState) {
            // 收集所有相关成员：memberStatus 全部 + active
            final allMembers = <String>{...group.allMemberCalls};
            allMembers.removeWhere(
              (m) => m.toUpperCase() == st.myFullCall.toUpperCase(),
            );

            return Column(
              children: [
                // ─── 顶部拖拽手柄 + 标题 ───
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: C.greyLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: C.orangeBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.group_rounded,
                              color: C.orange,
                              size: 22,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: ts(16, w: FontWeight.w700),
                                ),
                                Text(
                                  S
                                      .of(context)
                                      .groupCallsignLine(group.groupCall),
                                  style: ts(
                                    12,
                                    c: C.orange,
                                    w: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showDeleteGroupConfirm(st, group);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: C.redBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: C.red,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                    ],
                  ),
                ),
                Divider(height: 1),
                // ─── 成员列表 ───
                Expanded(
                  child: allMembers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.group_off_rounded,
                                size: 48,
                                color: C.greyLight,
                              ),
                              SizedBox(height: 8),
                              Text(
                                S.of(context).noMembers,
                                style: ts(13, c: C.grey),
                              ),
                              SizedBox(height: 4),
                              Text(
                                S.of(context).inviteMembersHint,
                                style: ts(11, c: C.greyLight),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: allMembers.length,
                          itemBuilder: (_, i) {
                            final call = allMembers.elementAt(i);
                            final status =
                                group.memberStatus[call.toUpperCase()];
                            final isBlocked = group.blockedMembers.contains(
                              call.toUpperCase(),
                            );
                            final isOnline = st.stations.any(
                              (s) =>
                                  s.call.toUpperCase() == call.toUpperCase() &&
                                  s.status == St.online,
                            );

                            // 状态标签（优先显示群成员状态，其次在线状态）
                            String statusText;
                            Color statusColor;
                            final isOnlineStation = st.stations.any(
                              (s) =>
                                  s.call.toUpperCase() == call.toUpperCase() &&
                                  s.status != St.offline,
                            );
                            if (isBlocked) {
                              statusText = S.of(context).memberBlocked;
                              statusColor = C.red;
                            } else if (status == GroupMemberStatus.joined) {
                              statusText = isOnlineStation
                                  ? S.of(context).online
                                  : S.of(context).memberJoined;
                              statusColor = isOnlineStation ? C.green : C.blue;
                            } else if (status == GroupMemberStatus.pending) {
                              statusText = S.of(context).memberPending;
                              statusColor = C.yellow;
                            } else if (status == GroupMemberStatus.declined) {
                              statusText = S.of(context).memberDeclined;
                              statusColor = C.red;
                            } else if (status == GroupMemberStatus.left) {
                              statusText = S.of(context).memberLeft;
                              statusColor = C.grey;
                            } else if (status == GroupMemberStatus.timeout) {
                              statusText = S.of(context).memberTimeout;
                              statusColor = C.grey;
                            } else {
                              statusText = isOnlineStation
                                  ? S.of(context).online
                                  : S.of(context).offline;
                              statusColor = isOnlineStation ? C.green : C.grey;
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  // 在线状态点
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // 呼号 + 状态
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          call,
                                          style: ts(14, w: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          statusText,
                                          style: ts(11, c: statusColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 操作按钮
                                  if (!isBlocked)
                                    GestureDetector(
                                      onTap: () {
                                        // 移除成员：从 memberStatus 和 activeMembers 删除
                                        setSheetState(() {
                                          group.memberStatus.remove(
                                            call.toUpperCase(),
                                          );
                                          group.activeMembers.remove(
                                            call.toUpperCase(),
                                          );
                                        });
                                        // 保存群聊变更（持久化 + 刷新）
                                        st.saveGroupNow();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: C.redBg,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          S.of(context).remove,
                                          style: ts(
                                            11,
                                            c: C.red,
                                            w: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (!isBlocked) SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setSheetState(() {
                                        if (isBlocked) {
                                          group.blockedMembers.remove(
                                            call.toUpperCase(),
                                          );
                                        } else {
                                          group.blockedMembers.add(
                                            call.toUpperCase(),
                                          );
                                        }
                                      });
                                      st.saveGroupNow();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isBlocked
                                            ? C.greenBg
                                            : C.yellowBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isBlocked
                                            ? S.of(context).unblock
                                            : S.of(context).block,
                                        style: ts(
                                          11,
                                          c: isBlocked ? C.green : C.yellow,
                                          w: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Divider(height: 1),
                // ─── 底部操作栏 ───
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showInviteMemberDialog(st, group);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: C.orangeBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_add_rounded,
                                    size: 16,
                                    color: C.orange,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    S.of(context).inviteMembers,
                                    style: ts(
                                      13,
                                      c: C.orange,
                                      w: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 删除群组确认
  void _showDeleteGroupConfirm(AppState st, ChatGroup group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          S.of(context).deleteGroup,
          style: ts(16, w: FontWeight.w700),
        ),
        content: Text(
          S.of(context).deleteGroupConfirm(group.name),
          style: ts(13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).cancel, style: ts(13, c: C.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.red),
            onPressed: () {
              st.deleteGroup(group.id);
              Navigator.pop(ctx);
              setState(() {
                _selectedGroupId = null;
                _showList = true;
              });
            },
            child: Text(
              S.of(context).delete,
              style: ts(13, c: Colors.white, w: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// 群成员列表底部面板
  void _showGroupMembersSheet(AppState st, ChatGroup group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          // 所有成员：memberStatus 全部 + active
          final allMembers = <String>{...group.allMemberCalls};
          final members =
              allMembers
                  .where((m) => m.toUpperCase() != st.myFullCall.toUpperCase())
                  .toList()
                ..sort();
          final onlineCount = members
              .where(
                (m) => st.stations.any(
                  (s) =>
                      s.call.toUpperCase() == m.toUpperCase() &&
                      s.status == St.online,
                ),
              )
              .length;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: C.greyLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    SizedBox(width: 20),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: C.orangeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.group_rounded,
                        color: C.orange,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(group.name, style: ts(16, w: FontWeight.w700)),
                          Text(
                            S
                                .of(context)
                                .memberOnlineCount(members.length, onlineCount),
                            style: ts(12, c: C.grey),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (group.isOwner(st.myCall)) {
                          _showInviteMemberDialog(st, group);
                        }
                      },
                      child: Text(
                        group.isOwner(st.myCall)
                            ? '+ ${S.of(context).invite}'
                            : S.of(context).done,
                        style: ts(13, c: C.orange, w: FontWeight.w700),
                      ),
                    ),
                    SizedBox(width: 8),
                  ],
                ),
                SizedBox(height: 8),
                Divider(height: 1),
                Flexible(
                  child: members.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(30),
                          child: Center(
                            child: Text(
                              S.of(context).noMembers,
                              style: ts(13, c: C.grey),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: members.length,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemBuilder: (_, i) {
                            final call = members[i];
                            final isOnline = st.stations.any(
                              (s) =>
                                  s.call.toUpperCase() == call.toUpperCase() &&
                                  s.status == St.online,
                            );
                            final isOwner = group.isOwner(call);
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: isOnline
                                    ? C.greenBg
                                    : C.bgSoft,
                                child: Icon(
                                  isOnline
                                      ? Icons.person_rounded
                                      : Icons.person_off_outlined,
                                  size: 18,
                                  color: isOnline ? C.green : C.grey,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(call, style: ts(13, w: FontWeight.w600)),
                                  if (isOwner) ...[
                                    SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: C.orangeBg,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        S.of(context).groupOwner,
                                        style: ts(
                                          9,
                                          c: C.orange,
                                          w: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                isOnline
                                    ? S.of(context).online
                                    : S.of(context).offline,
                                style: ts(11, c: isOnline ? C.green : C.grey),
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                _openStation(st, call);
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 成员退出群组确认
  void _showLeaveGroupConfirm(AppState st, ChatGroup group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          S.of(context).leaveGroup,
          style: ts(16, w: FontWeight.w700),
        ),
        content: Text(
          S.of(context).leaveGroupConfirm(group.name),
          style: ts(13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).cancel, style: ts(13, c: C.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.red),
            onPressed: () {
              // 发送 LEAVE 给群主
              st.sendLeave(group.owner, group.groupCall);
              // 从本地移除
              st.deleteGroup(group.id);
              Navigator.pop(ctx);
              setState(() {
                _selectedGroupId = null;
                _showList = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(S.of(context).leftGroup(group.name)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              S.of(context).leave,
              style: ts(13, c: Colors.white, w: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// 邀请新成员对话框（群主使用）
  void _showInviteMemberDialog(AppState st, ChatGroup group) {
    final searchCtrl = TextEditingController();
    final manualCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          var list = st.stations
              .where(
                (s) =>
                    s.call != st.myFullCall &&
                    !group.confirmedMembers.contains(s.call.toUpperCase()) &&
                    !group.memberStatus.containsKey(s.call.toUpperCase()),
              )
              .toList();
          list = list.where((s) => s.status != St.offline).toList();
          final q = searchCtrl.text.trim().toUpperCase();
          if (q.isNotEmpty)
            list = list.where((s) => s.call.toUpperCase().contains(q)).toList();
          list.sort((a, b) => a.call.compareTo(b.call));
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text(
              S.of(context).inviteMembersTo(group.name),
              style: ts(15, w: FontWeight.w700),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.45,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    S.of(context).groupCallsignLine(group.groupCall),
                    style: ts(11, c: C.orange, w: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    style: ts(13),
                    decoration: InputDecoration(
                      hintText: S.of(context).searchCallsign,
                      hintStyle: ts(12, c: C.greyLight),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: C.grey,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: C.bgSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  // 手动输入呼号
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: manualCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: ts(13),
                          decoration: InputDecoration(
                            hintText: S.of(context).manualCallsign,
                            hintStyle: ts(12, c: C.greyLight),
                            isDense: true,
                            filled: true,
                            fillColor: C.bgSoft,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          final call = manualCtrl.text.trim().toUpperCase();
                          if (call.isNotEmpty && call.length >= 3) {
                            widget.state.sendInvite(
                              group.groupCall,
                              call,
                              group.name,
                            );
                            manualCtrl.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(S.of(context).inviteSent(call)),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: C.orangeBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            S.of(context).invite,
                            style: ts(11, c: C.orange, w: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: Text(
                              S.of(context).noMoreOnlineStations,
                              style: ts(12, c: C.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final s = list[i];
                              final invited = group.memberStatus.containsKey(
                                s.call.toUpperCase(),
                              );
                              return GestureDetector(
                                onTap: invited
                                    ? null
                                    : () {
                                        widget.state.sendInvite(
                                          group.groupCall,
                                          s.call,
                                          group.name,
                                        );
                                        setDialogState(() {});
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              S.of(context).inviteSent(s.call),
                                            ),
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
                                          ),
                                        );
                                      },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        invited
                                            ? Icons.check_circle_rounded
                                            : Icons
                                                  .radio_button_unchecked_rounded,
                                        size: 18,
                                        color: invited ? C.green : C.greyLight,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        s.call,
                                        style: ts(13, w: FontWeight.w600),
                                      ),
                                      Spacer(),
                                      if (invited)
                                        Text(
                                          S.of(context).invited,
                                          style: ts(10, c: C.green),
                                        )
                                      else
                                        Text(
                                          S.of(context).tapToInvite,
                                          style: ts(10, c: C.orange),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(S.of(context).done, style: ts(13, c: C.blue)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pickerActionBtn(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: C.bgSoft,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: C.slate),
            SizedBox(width: 3),
            Text(label, style: ts(10, c: C.slate)),
          ],
        ),
      ),
    );
  }

  void _showAddContactDialog(AppState st) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // 输入时联想匹配的呼号
          final q = ctrl.text.trim().toUpperCase();
          final suggestions = q.isEmpty
              ? <Station>[]
              : st.stations
                    .where(
                      (s) =>
                          s.call.toUpperCase().contains(q) &&
                          s.call != st.myFullCall,
                    )
                    .take(8)
                    .toList();
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              S.of(context).addContact,
              style: ts(16, w: FontWeight.w700),
            ),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(S.of(context).addContactDesc, style: ts(12, c: C.grey)),
                  SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    style: ts(14),
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: S.of(context).callsignExample,
                      hintStyle: ts(13, c: C.greyLight),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: C.grey,
                      ),
                      filled: true,
                      fillColor: C.bgSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  // 联想呼号列表
                  if (suggestions.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: C.bgSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        itemBuilder: (_, i) {
                          final s = suggestions[i];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              s.favorite
                                  ? Icons.star_rounded
                                  : Icons.radio_rounded,
                              size: 16,
                              color: s.favorite ? C.orange : C.blue,
                            ),
                            title: Text(
                              s.call,
                              style: ts(13, w: FontWeight.w600),
                            ),
                            subtitle: Text(
                              s.status == St.offline
                                  ? S.of(context).offline
                                  : S.of(context).online,
                              style: ts(10, c: C.grey),
                            ),
                            trailing: Icon(
                              Icons.add_circle_outline_rounded,
                              size: 18,
                              color: C.blue,
                            ),
                            onTap: () {
                              ctrl.text = s.call;
                              ctrl.selection = TextSelection.collapsed(
                                offset: ctrl.text.length,
                              );
                              setDialogState(() {});
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).cancel, style: ts(13, c: C.grey)),
              ),
              FilledButton(
                onPressed: () {
                  final call = ctrl.text.trim().toUpperCase();
                  if (call.isNotEmpty) {
                    st.addManualStation(call);
                    setState(() => _selected = call);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(S.of(context).contactAdded(call)),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: C.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  S.of(context).add,
                  style: ts(13, c: Colors.white, w: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _send() {
    if (_input.text.isEmpty) return;
    // 群聊发送
    if (_selectedGroupId != null) {
      final group = widget.state.chatGroups
          .where((g) => g.id == _selectedGroupId)
          .firstOrNull;
      if (group != null) {
        widget.state.sendGroupMessage(
          group.groupCall,
          _input.text.trim(),
          groupId: group.id,
        );
      }
      _input.clear();
      Future.delayed(const Duration(milliseconds: 80), () {
        if (_scrollGroup.hasClients) {
          _scrollGroup.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
      return;
    }
    if (_selected.isEmpty) return;
    widget.state.sendMessage(_selected, _input.text.trim());
    _input.clear();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollChat.hasClients) {
        _scrollChat.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
