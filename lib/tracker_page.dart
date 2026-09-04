import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'models.dart';
import 'state.dart';
import 'widgets.dart';
import 'coord.dart';
import 'tile_map.dart';

/// 群组跟踪页：把聊天群的成员放到整屏地图跟踪（车队 / 好友结伴）
/// - 横屏：左侧成员栏 + 右侧全屏地图（导航风格）
/// - 竖屏：全屏地图 + 底部成员横条
/// - 进入时临时解锁横屏，退出后按用户设置恢复
/// - 点选成员 → 平滑锁定跟随该成员；提供「全览」缩放到全部成员
class TrackerPage extends StatefulWidget {
  final AppState state;
  final ChatGroup group;
  const TrackerPage({super.key, required this.state, required this.group});
  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

/// 跟踪成员：呼号 + 是否有位置数据（无位置 = 等待上报，仅显示占位）
class _Tm {
  final String call;
  final Station? st; // null = 尚无位置数据
  final bool isMe;
  const _Tm(this.call, this.st, {this.isMe = false});
}

class _TrackerPageState extends State<TrackerPage>
    with SingleTickerProviderStateMixin {
  double _zoom = 8.0;
  Offset _pan = Offset.zero;
  Size _size = Size.zero; // 整个页面可用区域（横竖屏判断等）
  Size _mapSize = Size.zero; // 地图实际区域（横屏不含左侧成员栏）——投影基准

  // 平滑平移动画
  late final AnimationController _panCtrl;
  Offset _panFrom = Offset.zero;
  Offset _panTo = Offset.zero;

  static const _baseLat = 39.9042;
  static const _baseLng = 116.4074;
  static final (double, double) _gcjBase = Gcj.wgsToGcj(_baseLat, _baseLng);

  MapType get _mapType {
    for (final m in MapType.values) {
      if (m.name == widget.state.mapType) return m;
    }
    return MapType.gaode;
  }

  bool get _isGcj => _mapType == MapType.gaode || _mapType == MapType.gaode_sat;
  (double, double) get _base => _isGcj ? _gcjBase : (_baseLat, _baseLng);

  /// 当前跟踪锁定（跟随）的呼号；null = 全览/自由
  String? _followCall;
  /// 快捷聊天面板输入焦点（回车发送后保持）
  final FocusNode _sheetFocus = FocusNode();

  /// 全览保持模式：点「全览」后开启；成员移动跑出视野时自动重新适配。
  /// 用户手动拖动/缩放/点人跟随即退出。
  bool _keepFitAll = false;
  DateTime _lastAutoFit = DateTime.fromMillisecondsSinceEpoch(0);
  bool _didAutoFit = false; // 首次进入自动全览一次

  @override
  void initState() {
    super.initState();
    _panCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addListener(() {
        final t = Curves.easeOutCubic.transform(_panCtrl.value);
        setState(() => _pan = Offset.lerp(_panFrom, _panTo, t)!);
      });
    // 临时解锁横屏（导航风格），退出后 restoreOrientation 恢复
    widget.state.unlockLandscape();
  }

  @override
  void dispose() {
    _panCtrl.dispose();
    _sheetFocus.dispose();
    widget.state.restoreOrientation();
    super.dispose();
  }

  (double, double) _tc(double lat, double lng) =>
      _isGcj ? Gcj.wgsToGcj(lat, lng) : (lat, lng);

  Offset _toScreen(double lat, double lng) {
    final t = _tc(lat, lng);
    final b = _base;
    final c = MapProj.latLngToPx(b.$1, b.$2, _zoom);
    final p = MapProj.latLngToPx(t.$1, t.$2, _zoom);
    return Offset(
      p.dx - c.dx + _mapSize.width / 2 + _pan.dx,
      p.dy - c.dy + _mapSize.height / 2 + _pan.dy,
    );
  }

  Offset _panFor(double lat, double lng, double zoom) {
    final b = _base;
    final g = _tc(lat, lng);
    final c = MapProj.latLngToPx(b.$1, b.$2, zoom);
    final p = MapProj.latLngToPx(g.$1, g.$2, zoom);
    return c - p;
  }

  /// 平滑平移中心到某点（主动触发：点成员/定位我；会打断当前动画立即跟随）
  void _smoothCenterOn(double lat, double lng, {bool instant = false}) {
    final target = _panFor(lat, lng, _zoom);
    if (instant || _mapSize.width == 0) {
      _pan = target;
      return;
    }
    _panCtrl.stop();
    _panFrom = _pan;
    _panTo = target;
    _panCtrl.forward(from: 0);
  }

  /// 跟随刷新（由 build 调用）：仅在目标位置显著变化且当前无动画时启动一次，
  /// 避免跟随模式下每次重建都重启动画导致无限重绘/卡死
  void _followTick(double lat, double lng) {
    final target = _panFor(lat, lng, _zoom);
    if (_panCtrl.isAnimating) return;
    if ((target - _pan).distance < 1.0) return;
    _panFrom = _pan;
    _panTo = target;
    _panCtrl.forward(from: 0);
  }

  void _zoomBy(double dz) {
    final z = (_zoom + dz).clamp(3.0, 19.0);
    final sf = math.pow(2, z - _zoom).toDouble();
    _panCtrl.stop();
    setState(() {
      _zoom = z;
      _pan = _pan * sf;
    });
  }

  /// 全览（keep=true 进入保持模式：成员跑出视野自动重新适配）
  void _fitAll({bool keep = true}) {
    final pts = <(double, double)>[];
    for (final m in _members()) {
      final s = m.st;
      if (s != null) pts.add((s.lat, s.lng));
    }
    if (pts.isEmpty) return;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in pts) {
      if (p.$1 < minLat) minLat = p.$1;
      if (p.$1 > maxLat) maxLat = p.$1;
      if (p.$2 < minLng) minLng = p.$2;
      if (p.$2 > maxLng) maxLng = p.$2;
    }
    final w = _mapSize.width > 100 ? _mapSize.width : 1000;
    final h = _mapSize.height > 100 ? _mapSize.height : 700;
    final spanLng = math.max(maxLng - minLng, 0.02);
    final spanY = math.max((_mercY(maxLat) - _mercY(minLat)).abs(), 1e-4);
    final zX = math.log((w - 120) * 360 / (spanLng * 256)) / math.ln2;
    final zY = math.log((h - 160) / (spanY * 256)) / math.ln2;
    final z = (zX < zY ? zX : zY).clamp(3.0, 16.0);
    final cLat = (minLat + maxLat) / 2;
    final cLng = (minLng + maxLng) / 2;
    _panCtrl.stop();
    final z0 = _zoom;
    setState(() {
      _zoom = z;
      _pan = _pan * math.pow(2, z - z0).toDouble();
      _followCall = null;
      _keepFitAll = keep;
    });
    _lastAutoFit = DateTime.now();
    // 平滑平移到成员群中心
    _panFrom = _pan;
    _panTo = _panFor(cLat, cLng, z);
    _panCtrl.forward(from: 0);
  }

  /// 全览保持：检查是否有成员跑出视野（带边距），有则重新适配（带防抖）
  void _autoKeepFit() {
    if (!_keepFitAll || _panCtrl.isAnimating) return;
    // 防抖：至少 1.5s 才允许再次自动全览，避免成员密集跳动导致地图抽搐
    if (DateTime.now().difference(_lastAutoFit).inMilliseconds < 1500) return;
    if (_mapSize.width <= 0 || _mapSize.height <= 0) return;
    // 视口世界像素范围（含余量 70px）
    final b = _base;
    final c = MapProj.latLngToPx(b.$1, b.$2, _zoom);
    final left = c.dx - _mapSize.width / 2 - _pan.dx - 70;
    final right = c.dx + _mapSize.width / 2 - _pan.dx + 70;
    final top = c.dy - _mapSize.height / 2 - _pan.dy - 70;
    final bottom = c.dy + _mapSize.height / 2 - _pan.dy + 70;
    for (final m in _members()) {
      final s = m.st;
      if (s == null) continue;
      final t = _tc(s.lat, s.lng);
      final p = MapProj.latLngToPx(t.$1, t.$2, _zoom);
      if (p.dx < left || p.dx > right || p.dy < top || p.dy > bottom) {
        _fitAll(keep: true);
        return;
      }
    }
  }

  /// 退出全览保持（用户手动操作/点人时调用）
  void _exitKeepFit() {
    _keepFitAll = false;
  }

  double _mercY(double lat) {
    final s = math.sin(lat * math.pi / 180);
    return (1 - math.log((1 + s) / (1 - s)) / (2 * math.pi)) / 2;
  }

  /// 跟踪成员：群成员(confirmedMembers) ∪ 我自己。排序：我 → 有位置 → 无位置
  List<_Tm> _members() {
    final calls = <String>{
      ...widget.group.confirmedMembers.map((c) => c.toUpperCase()),
      widget.state.myFullCall.toUpperCase(),
    };
    final out = <_Tm>[];
    for (final u in calls) {
      final isMe = u == widget.state.myFullCall.toUpperCase();
      Station? st;
      if (isMe) {
        st = widget.state.myHasFix ? widget.state.myStation : null;
      } else {
        for (final s in widget.state.stations) {
          if (s.call.toUpperCase() == u) {
            st = s;
            break;
          }
        }
      }
      out.add(_Tm(u, st, isMe: isMe));
    }
    // 排序：我 → 有位置(非离线 → 离线) → 无位置
    out.sort((a, b) {
      if (a.isMe != b.isMe) return a.isMe ? -1 : 1;
      final aHas = a.st != null;
      final bHas = b.st != null;
      if (aHas != bHas) return aHas ? -1 : 1;
      if (aHas && bHas) {
        final ao = a.st!.effectiveStatus == St.offline;
        final bo = b.st!.effectiveStatus == St.offline;
        if (ao != bo) return ao ? 1 : -1;
        return b.st!.lastHeard.compareTo(a.st!.lastHeard);
      }
      return a.call.compareTo(b.call);
    });
    return out;
  }

  _Tm? _memberByCall(String call) {
    final u = call.toUpperCase();
    for (final m in _members()) {
      if (m.call.toUpperCase() == u) return m;
    }
    return null;
  }

  /// 地图上点击位置附近是否有成员标记（像素命中），用于“点地图成员=跟随”
  _Tm? _hitMember(Offset pos, List<_Tm> members) {
    _Tm? best;
    double bestD = 24 * 24; // 命中半径 24px
    for (final m in members) {
      final s = m.st;
      if (s == null) continue;
      final p = _toScreen(s.lat, s.lng);
      final d = (p - pos).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = m;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final members = _members();
        // 跟随模式：成员位置变化 → 平滑居中跟随（带防循环守护）
        final follow = _followCall == null ? null : _memberByCall(_followCall!);
        if (follow?.st != null) {
          _followTick(follow!.st!.lat, follow.st!.lng);
        } else {
          // 非跟随（自由/全览保持）：成员跑出视野时自动重新适配（帧后安全执行）
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _autoKeepFit();
          });
        }
        return Scaffold(
          backgroundColor: C.mapBg,
          body: LayoutBuilder(
            builder: (context, c) {
              _size = Size(c.maxWidth, c.maxHeight);
              final landscape = c.maxWidth >= c.maxHeight * 1.1;
              return landscape
                  ? _landscape(members)
                  : _portrait(members);
            },
          ),
        );
      },
    );
  }

  // ─── 地图主体（横竖屏共用）───
  Widget _mapBody(List<_Tm> members) {
    return LayoutBuilder(
      builder: (context, c) {
        // 地图区域实际尺寸（横屏=右半部，竖屏=全宽）——投影/视野都以此为准
        _mapSize = Size(c.maxWidth, c.maxHeight);
        // 首次进入（尺寸就绪后）自动全览一次，用户打开即可看到全部成员
        if (!_didAutoFit && c.maxWidth > 0) {
          _didAutoFit = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fitAll(keep: false);
          });
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            TileMapView(
              centerLat: _base.$1,
              centerLng: _base.$2,
              zoom: _zoom,
              pan: _pan,
              onPan: (d) {
                _exitKeepFit();
                _panCtrl.stop();
                setState(() => _pan += d);
              },
              onViewChanged: (z, p) {
                _exitKeepFit();
                setState(() {
                  _zoom = z;
                  _pan = p;
                  _followCall = null;
                });
              },
              onZoomRequest: (z, p) {
                _exitKeepFit();
                setState(() {
                  _zoom = z;
                  _pan = p;
                  _followCall = null;
                });
              },
              onTap: (pos) {
                _exitKeepFit();
                // 点在地图上的成员标记 → 跟随该成员（更直觉）
                final hit = _hitMember(pos, members);
                if (hit != null) {
                  setState(() => _followCall = hit.call);
                  final st = hit.st;
                  if (st != null) _smoothCenterOn(st.lat, st.lng);
                } else {
                  setState(() => _followCall = null);
                }
              },
              mapType: _mapType,
            ),
            IgnorePointer(
              child: CustomPaint(
                size: _mapSize,
                painter: _TrackerOverlayPainter(
                  members: members.where((m) => m.st != null).map((m) => m.st!).toList(),
                  myCall: widget.state.myFullCall,
                  followCall: _followCall,
                  myHasFix: widget.state.myHasFix,
                  myLat: widget.state.myLat,
                  myLng: widget.state.myLng,
                  toScreen: _toScreen,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 地图模式徽章：提示当前是跟随某成员 / 全览保持 / 自由浏览
  Widget _modeBadge() {
    Widget? chip;
    if (_followCall != null) {
      final m = _memberByCall(_followCall!);
      if (m != null) {
        chip = _badgePill(
          icon: Icons.gps_fixed_rounded,
          text: m.isMe
              ? S.of(context).trackModeMe
              : S.of(context).trackModeFollow(m.call),
          color: C.blue,
        );
      }
    } else if (_keepFitAll) {
      chip = _badgePill(
        icon: Icons.zoom_out_map_rounded,
        text: S.of(context).trackModeFitAll,
        color: C.green,
      );
    }
    if (chip == null) return const SizedBox.shrink();
    return IgnorePointer(child: chip);
  }

  Widget _badgePill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: softShadow(blur: 10, alpha: 0.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: ts(10, c: Colors.white, w: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── 横屏：左成员栏 + 全屏地图 ───
  Widget _landscape(List<_Tm> members) {
    // 左侧栏整体放入 SafeArea：横屏刘海/圆角不会挡住顶栏与返回键
    return SafeArea(
      child: Row(
        children: [
          Container(
            width: 238,
            color: C.white,
            child: Column(
              children: [
                _header(members, showGroupChat: true),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: members.length,
                    itemBuilder: (_, i) => _memberTile(members[i]),
                  ),
                ),
                _toolRow(),
              ],
            ),
          ),
          // 横屏：地图区左上角叠模式徽章（不遮挡，地图上方无 header）
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _mapBody(members),
                Positioned(left: 10, top: 10, child: _modeBadge()),
                // 底部会话条（最新消息实时预览）
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: _chatBar(members),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 竖屏：地图 + 顶部标题 + 底部成员条 ───
  Widget _portrait(List<_Tm> members) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _mapBody(members),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: _header(members, showGroupChat: true),
              ),
              // 模式徽章（跟随中 / 全览保持）——位于 header 下方，不被遮挡
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
                child: Row(children: [_modeBadge()]),
              ),
              const Spacer(),
              // 底部会话条（最新消息实时预览，点击可回复；无消息时隐藏不占位）
              if (_recentGroupMsgs().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                  child: _chatBar(members),
                ),
              if (members.isNotEmpty)
                Container(
                  height: 96,
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  decoration: BoxDecoration(
                    color: C.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    boxShadow: softShadow(blur: 16, alpha: 0.12),
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    itemCount: members.length,
                    itemBuilder: (_, i) =>
                        SizedBox(width: 208, child: _memberTile(members[i])),
                  ),
                )
              else
                _emptyHint(),
              _toolRow(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(List<_Tm> members, {bool showGroupChat = false}) {
    final withPos = members.where((m) => m.st != null).length;
    final online = members
        .where((m) => m.st != null && m.st!.effectiveStatus != St.offline)
        .length;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: C.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          boxShadow: softShadow(blur: 10, alpha: 0.08),
        ),
        child: Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.arrow_back_rounded, size: 20, color: C.ink),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.group.name,
                    style: ts(14, w: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    S
                        .of(context)
                        .trackHeader(members.length, online, withPos),
                    style: ts(9, c: C.grey),
                  ),
                ],
              ),
            ),
            // 群聊快捷入口（可选，横屏成员栏显示）
            if (showGroupChat)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: S.of(context).groupChatShort,
                icon: Icon(Icons.chat_bubble_rounded,
                    size: 18, color: C.orange),
                onPressed: () => _openChatSheet(null),
              ),
            // 全览（进入自动保持模式；再次点击退出）
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: S.of(context).fitAll,
              icon: Icon(
                Icons.zoom_out_map_rounded,
                size: 19,
                color: _keepFitAll ? Colors.white : C.blue,
              ),
              style: IconButton.styleFrom(
                backgroundColor: _keepFitAll
                    ? C.green
                    : C.blueBg,
                disabledBackgroundColor: Colors.transparent,
              ),
              onPressed: () {
                if (_keepFitAll) {
                  _exitKeepFit();
                } else {
                  _fitAll(keep: true);
                }
              },
            ),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }

  Widget _emptyHint() => Padding(
    padding: const EdgeInsets.all(20),
    child: Text(
      S.of(context).trackGroupEmpty,
      textAlign: TextAlign.center,
      style: ts(11, c: C.grey, h: 1.5),
    ),
  );

  Widget _memberTile(_Tm m) {
    final s = m.st;
    final sel = _followCall == m.call;
    final hasPos = s != null;
    final offline = !hasPos || s!.effectiveStatus == St.offline;
    final moving = hasPos && s!.effectiveStatus == St.moving;
    final color = offline ? C.grey : s!.color;
    final dist = hasPos && widget.state.myHasFix
        ? s!.distKm(widget.state.myLat!, widget.state.myLng!)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Material(
        color: sel ? C.blueBg : C.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (!hasPos) return; // 无位置不可跟随
            _exitKeepFit();
            setState(() {
              _followCall = _followCall == m.call ? null : m.call;
            });
            if (_followCall == m.call) _smoothCenterOn(s!.lat, s.lng);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel
                    ? C.blue.withValues(alpha: 0.6)
                    : C.border.withValues(alpha: 0.5),
                width: sel ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                // 状态头像
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: offline ? 0.08 : 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: moving ? color : color.withValues(alpha: 0.4),
                      width: moving ? 2 : 1.5,
                    ),
                  ),
                  child: hasPos
                      ? Icon(
                          moving
                              ? Icons.navigation_rounded
                              : s!.icon,
                          color: color,
                          size: 15,
                        )
                      : Icon(Icons.hourglass_empty_rounded,
                          color: color, size: 15),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.isMe
                                  ? '${m.call} · ${S.of(context).meLabel}'
                                  : m.call,
                              style: ts(12,
                                  c: m.isMe
                                      ? C.blue
                                      : (offline ? C.grey : C.ink),
                                  w: FontWeight.w800),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (moving) ...[
                            const SizedBox(width: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: C.blueBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                localizedStatusLabel(context, s!.effectiveStatus),
                                style: ts(8,
                                    c: C.blue, w: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _memberSub(m, dist),
                        style: ts(9.5, c: C.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 距离胶囊
                if (dist != null)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: C.bgSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${dist.toStringAsFixed(1)}km',
                      style: ts(9, c: C.slate, w: FontWeight.w700),
                    ),
                  ),
                // 跟随指示
                if (sel)
                  Icon(Icons.my_location_rounded, size: 15, color: C.blue),
                // 私聊快捷
                if (!m.isMe)
                  GestureDetector(
                    onTap: () => _openChatSheet(m.call),
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: C.cyanBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.chat_rounded,
                          size: 13, color: C.cyan),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _memberSub(_Tm m, double? dist) {
    final s = m.st;
    final buf = StringBuffer();
    if (m.isMe) {
      buf.write(s != null
          ? (s.speed != null && s.speed! > 0.5
              ? '${s.speed!.toStringAsFixed(0)} km/h'
              : S.of(context).trackActive)
          : S.of(context).trackWaitingPos);
    } else if (s == null) {
      buf.write(S.of(context).trackWaitingPos);
    } else if (s.effectiveStatus == St.offline) {
      buf.write(localizedLastSeen(context, s));
    } else {
      if (s.speed != null && s.speed! > 0.5) {
        buf.write('${s.speed!.toStringAsFixed(0)} km/h');
      }
      if (s.course != null && s.course! >= 0) {
        buf.write(buf.isEmpty ? '' : ' · ');
        buf.write('${s.course!.round()}°');
      }
      if (buf.isEmpty) buf.write(S.of(context).trackActive);
      buf.write(' · ${localizedLastSeen(context, s)}');
    }
    if (dist != null) {
      buf.write(buf.isEmpty ? '' : ' · ');
      buf.write('${dist.toStringAsFixed(1)} km');
    }
    return buf.toString();
  }

  /// 发送快捷聊天消息
  void _sheetSend(
    TextEditingController ctrl,
    bool isGroup,
    String? target,
    void Function() refresh,
  ) {
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    if (isGroup) {
      widget.state.sendGroupMessage(
        widget.group.groupCall,
        text,
        groupId: widget.group.id,
      );
    } else {
      widget.state.sendMessage(target!, text);
    }
    ctrl.clear();
    refresh();
  }

  /// 快捷聊天面板：target 为 null 表示发到整个群；否则私聊该成员
  void _openChatSheet(String? target) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(bctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (bctx, setSheet) {
              final isGroup = target == null;
              final title = isGroup
                  ? S.of(bctx).groupChatTitle(widget.group.name)
                  : S.of(bctx).chatWithTitle(target!);
              final hist = widget.state.messages
                  .where((m) {
                    if (isGroup) return m.groupId == widget.group.id;
                    return m.from == target || m.to == target;
                  })
                  .take(30)
                  .toList();
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isGroup ? Icons.group_rounded : Icons.person_rounded,
                          size: 18,
                          color: isGroup ? C.orange : C.cyan,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(title,
                              style: ts(15, w: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.close_rounded, color: C.grey),
                          onPressed: () => Navigator.pop(bctx),
                        ),
                      ],
                    ),
                    if (hist.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: ListView.builder(
                          shrinkWrap: true,
                          reverse: true,
                          itemCount: hist.length,
                          itemBuilder: (_, i) {
                            final m = hist[i];
                            final mine = m.from == widget.state.myFullCall;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: mine ? C.blueBg : C.bgSoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(m.text,
                                      style: ts(12, c: C.ink),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(S.of(bctx).noMessagesHint,
                            style: ts(11, c: C.greyLight)),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            focusNode: _sheetFocus,
                            textInputAction: TextInputAction.send,
                            autofocus: true,
                            style: ts(13),
                            minLines: 1,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: isGroup
                                  ? S.of(bctx).chatToGroupHint
                                  : S.of(bctx).chatToHint(target),
                              hintStyle: ts(12, c: C.grey),
                              isDense: true,
                              filled: true,
                              fillColor: C.bgSoft,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) {
                              _sheetSend(ctrl, isGroup, target, () {
                                setSheet(() {});
                              });
                              // 回车发送后保持焦点继续输入
                              _sheetFocus.requestFocus();
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            _sheetSend(ctrl, isGroup, target, () {
                              setSheet(() {});
                            });
                            _sheetFocus.requestFocus();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: C.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.send_rounded,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ).then((_) => ctrl.dispose());
  }

  /// 本群最近收到的消息（会话条展示用）
  List<AprsMsg> _recentGroupMsgs() {
    final out = <AprsMsg>[];
    for (final m in widget.state.messages) {
      final isGroupMsg = m.groupId == widget.group.id;
      final fromMember =
          widget.group.confirmedMembers.contains(m.from.toUpperCase());
      final toMember =
          widget.group.confirmedMembers.contains(m.to.toUpperCase());
      if ((isGroupMsg || fromMember || toMember) && !m.sent) {
        out.add(m);
        if (out.length >= 5) break;
      }
    }
    return out;
  }

  /// 地图底部会话条：显示最近收到的群/成员消息，点击打开对应聊天
  Widget _chatBar(List<_Tm> members) {
    final recent = _recentGroupMsgs();
    if (recent.isEmpty) return const SizedBox.shrink();
    final m = recent.first;
    final mine = m.from == widget.state.myFullCall;
    final fromName = mine ? S.of(context).meLabel : m.from;
    final isGroupMsg = m.groupId == widget.group.id;
    final target = isGroupMsg ? null : m.from;
    return GestureDetector(
        onTap: () => _openChatSheet(target),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: C.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.border.withValues(alpha: 0.6)),
            boxShadow: softShadow(blur: 14, alpha: 0.18),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: (isGroupMsg ? C.orange : C.cyan)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGroupMsg ? Icons.group_rounded : Icons.person_rounded,
                  size: 14,
                  color: isGroupMsg ? C.orange : C.cyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isGroupMsg ? widget.group.name : fromName,
                          style: ts(10, c: C.slate, w: FontWeight.w700),
                        ),
                        if (recent.length > 1) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: C.red,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '${recent.length}',
                              style: ts(8,
                                  c: Colors.white, w: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      m.text,
                      style: ts(11, c: C.ink, w: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.reply_rounded, size: 14, color: C.blue),
            ],
          ),
        ),
    );
  }

  Widget _toolRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoundIconBtn(
            Icons.my_location_rounded,
            tooltip: S.of(context).locateMe,
            color: C.blue,
            onTap: () {
              if (widget.state.myHasFix &&
                  widget.state.myLat != null &&
                  widget.state.myLng != null) {
                _exitKeepFit();
                setState(() {
                  _followCall = widget.state.myFullCall;
                  _smoothCenterOn(
                    widget.state.myLat!,
                    widget.state.myLng!,
                    instant: true,
                  );
                });
              }
            },
          ),
          const SizedBox(width: 6),
          RoundIconBtn(Icons.add_rounded, onTap: () => _zoomBy(1)),
          const SizedBox(width: 6),
          RoundIconBtn(Icons.remove_rounded, onTap: () => _zoomBy(-1)),
        ],
      ),
    );
  }
}

/// 覆盖层：轨迹折线 + 成员标记 + 我的位置
class _TrackerOverlayPainter extends CustomPainter {
  final List<Station> members;
  final String myCall;
  final String? followCall;
  final bool myHasFix;
  final double? myLat, myLng;
  final Offset Function(double lat, double lng) toScreen;
  _TrackerOverlayPainter({
    required this.members,
    required this.myCall,
    required this.followCall,
    required this.myHasFix,
    required this.myLat,
    required this.myLng,
    required this.toScreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 轨迹（我自己的轨迹也画，浅色）
    for (final s in members) {
      if (s.track.length < 2) continue;
      final path = Path();
      bool first = true;
      for (final p in s.track) {
        final o = toScreen(p.lat, p.lng);
        if (first) {
          path.moveTo(o.dx, o.dy);
          first = false;
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      final isMe = s.call.toUpperCase() == myCall.toUpperCase();
      canvas.drawPath(
        path,
        Paint()
          ..color = (isMe ? C.blue : s.color).withValues(alpha: isMe ? 0.4 : 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // 成员标记（含我自己，我用蓝点标出）
    for (final s in members) {
      if (s.lat == 0 && s.lng == 0) continue;
      final o = toScreen(s.lat, s.lng);
      if (o.dx < -40 ||
          o.dx > size.width + 40 ||
          o.dy < -40 ||
          o.dy > size.height + 40) {
        continue;
      }
      final isMe = s.call.toUpperCase() == myCall.toUpperCase();
      final offline = s.effectiveStatus == St.offline;
      final sel = followCall == s.call;
      final c = isMe ? C.blue : (offline ? C.grey : s.color);
      if (sel) {
        canvas.drawCircle(o, 17, Paint()..color = c.withValues(alpha: 0.18));
        canvas.drawCircle(
          o,
          17,
          Paint()
            ..color = c.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
      canvas.drawCircle(o, isMe ? 6.5 : 7.5, Paint()..color = c);
      canvas.drawCircle(
        o,
        isMe ? 6.5 : 7.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
      if (isMe) {
        // 我的位置加外圈强调
        canvas.drawCircle(o, 11, Paint()..color = C.blue.withValues(alpha: 0.15));
      }
      // 呼号标签
      final tp = TextPainter(
        text: TextSpan(
          text: s.call,
          style: TextStyle(
            color: offline ? C.grey : C.ink,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final bg = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          o.dx - tp.width / 2 - 3,
          o.dy - 21 - tp.height,
          tp.width + 6,
          tp.height + 3,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        bg,
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
      tp.paint(canvas, Offset(o.dx - tp.width / 2, o.dy - 21 - tp.height + 1));
    }
  }

  @override
  bool shouldRepaint(covariant _TrackerOverlayPainter old) => true;
}
