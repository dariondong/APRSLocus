import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'guide.dart';
import 'models.dart';
import 'state.dart';
import 'widgets.dart';
import 'station_detail.dart';

class PacketsPage extends StatefulWidget {
  final AppState state;
  const PacketsPage({super.key, required this.state});
  @override
  State<PacketsPage> createState() => _PacketsPageState();
}

class _PacketsPageState extends State<PacketsPage> {
  String _filter = 'all';
  bool _raw = false;
  final _tx = TextEditingController();
  final _search = TextEditingController();

  List<Packet> _list(AppState st) {
    var p = st.packets;
    if (_filter != 'all') p = p.where((p) => p.type == _filter).toList();
    final q = _search.text.trim().toUpperCase();
    if (q.isNotEmpty) {
      p = p
          .where(
            (p) =>
                p.src.toUpperCase().contains(q) ||
                p.dest.toUpperCase().contains(q) ||
                p.raw.toUpperCase().contains(q) ||
                (p.info?.toUpperCase().contains(q) ?? false),
          )
          .toList();
    }
    return p;
  }

  Color _tc(String t) {
    switch (t) {
      case 'position':
        return C.green;
      case 'message':
        return C.blue;
      case 'weather':
        return C.yellow;
      case 'status':
        return C.purple;
      default:
        return C.cyan;
    }
  }

  String _tn(BuildContext context, String t) {
    switch (t) {
      case 'position':
        return S.of(context).position;
      case 'message':
        return S.of(context).message;
      case 'weather':
        return S.of(context).weather;
      case 'status':
        return S.of(context).statusType;
      default:
        return S.of(context).objectType;
    }
  }

  /// 来源 id → 短标签（数据包页把「从哪条链路上来」标在每一条上）。
  String _sn(BuildContext context, String s) {
    final l = S.of(context);
    switch (s) {
      case AppState.srcAprsIs:
        return l.packetSrcAprsIs;
      case AppState.srcTnc:
        return l.packetSrcTnc;
      case AppState.srcAudio:
        return l.packetSrcAudio;
      case AppState.srcPkwdwpl:
        return l.packetSrcPkwdwpl;
      default:
        return l.packetSrcLocal;
    }
  }

  /// 来源 id → 标签颜色（与数据来源页的配色一致，便于一眼分辨）。
  Color _sc(String s) {
    switch (s) {
      case AppState.srcAprsIs:
        return C.blue;
      case AppState.srcTnc:
        return C.green;
      case AppState.srcAudio:
        return C.orange;
      case AppState.srcPkwdwpl:
        return C.purple;
      default:
        return C.slate;
    }
  }

  @override
  void dispose() {
    _tx.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final st = widget.state;
        final list = _list(st);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 功能引导（首次进入显示；看过后不占位置）
              GuideTipCard(
                guideId: 'packets',
                state: widget.state,
                margin: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              // 头部（Wrap 自动换行，避免窄屏溢出）
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: C.blueBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cable_rounded, size: 16, color: C.blue),
                        SizedBox(width: 8),
                        Text(
                          S.of(context).packetConsole,
                          style: ts(13, c: C.blue, w: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: st.connected ? C.greenBg : C.yellowBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: st.connected ? C.green : C.red,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          st.connected
                              ? S.of(context).connected
                              : S.of(context).disconnected,
                          style: ts(
                            11,
                            c: st.connected ? C.green : C.red,
                            w: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: C.blueBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      S
                          .of(context)
                          .packetStats(
                            st.packetsPerMin,
                            st.packetsRx,
                            st.packetsTx,
                          ),
                      style: ts(11, c: C.blue, w: FontWeight.w600),
                    ),
                  ),
                  RoundIconBtn(
                    _raw ? Icons.code_rounded : Icons.view_list_rounded,
                    color: _raw ? C.blue : C.slate,
                    tooltip: _raw
                        ? S.of(context).rawMode
                        : S.of(context).parsedMode,
                    onTap: () => setState(() => _raw = !_raw),
                  ),
                ],
              ),
              SizedBox(height: 14),
              // 筛选
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip2(
                      label: S.of(context).all,
                      selected: _filter == 'all',
                      color: C.slate,
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                    SizedBox(width: 6),
                    FilterChip2(
                      label: S.of(context).position,
                      selected: _filter == 'position',
                      color: C.green,
                      onTap: () => setState(() => _filter = 'position'),
                    ),
                    SizedBox(width: 6),
                    FilterChip2(
                      label: S.of(context).message,
                      selected: _filter == 'message',
                      color: C.blue,
                      onTap: () => setState(() => _filter = 'message'),
                    ),
                    SizedBox(width: 6),
                    FilterChip2(
                      label: S.of(context).weather,
                      selected: _filter == 'weather',
                      color: C.yellow,
                      onTap: () => setState(() => _filter = 'weather'),
                    ),
                    SizedBox(width: 6),
                    FilterChip2(
                      label: S.of(context).statusType,
                      selected: _filter == 'status',
                      color: C.purple,
                      onTap: () => setState(() => _filter = 'status'),
                    ),
                    SizedBox(width: 6),
                    FilterChip2(
                      label: S.of(context).objectType,
                      selected: _filter == 'object',
                      color: C.cyan,
                      onTap: () => setState(() => _filter = 'object'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              // 搜索
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: ts(13),
                decoration: InputDecoration(
                  hintText: S.of(context).searchPacket,
                  hintStyle: ts(12, c: C.greyLight),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: C.grey,
                  ),
                  suffixIcon: _search.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _search.clear();
                            setState(() {});
                          },
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: C.grey,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: C.white,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: C.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
              SizedBox(height: 14),
              // 列表
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(
                          _filter != 'all' || _search.text.isNotEmpty
                              ? S.of(context).noMatchingPackets
                              : S.of(context).noPackets,
                          style: ts(13, c: C.grey),
                        ),
                      )
                    : _raw
                    ? _rawList(list)
                    : _parsedList(list),
              ),
              SizedBox(height: 8),
              // 手动发送
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tx,
                      style: mono(11),
                      decoration: InputDecoration(
                        hintText: S.of(context).manualInject,
                        hintStyle: ts(12, c: C.grey),
                        filled: true,
                        fillColor: C.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: C.border),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _sendRaw(),
                    ),
                  ),
                  SizedBox(width: 8),
                  RoundIconBtn(
                    Icons.send_rounded,
                    color: C.blue,
                    tooltip: S.of(context).send,
                    onTap: _sendRaw,
                  ),
                ],
              ),
              SizedBox(height: 6),
              // 发送前就把「会走哪条链路、限长多少」写出来：手写报文最常踩的
              // 两个坑就是「格式不合法」与「拿到 APRS-IS 的报文直接往射频发」，
              // 这两件事在点发送之前就能提醒到。
              _injectHint(st, S.of(context)),
            ],
          ),
        );
      },
    );
  }

  /// 手动注入的上下文提示：当前链路 + 长度 + 格式
  Widget _injectHint(AppState st, S l) {
    final bytes = utf8.encode(_tx.text.trim()).length;
    final parts = <String>[
      st.usingRf
          ? l.packetLimitRf(bytes, st.rfMaxFrame)
          : l.packetLimitIs(bytes),
      '${l.kissRfPath}: ${st.txPath}',
    ];
    // 射频下带 TCPIP* 几乎总是「从 APRS-IS 复制的报文」——发出去前先提醒
    if (st.usingRf && _tx.text.toUpperCase().contains('TCPIP')) {
      parts.add(l.packetTcpipWarning);
    }
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        parts.join(' · '),
        style: ts(10, c: st.usingRf ? C.orange : C.greyLight, h: 1.4),
      ),
    );
  }

  /// 手动注入并发送：把结果如实反馈给用户（旧实现无论成败都毫无提示）
  Future<void> _sendRaw() async {
    final line = _tx.text.trim();
    if (line.isEmpty) return;
    final l = S.of(context);
    final err = widget.state.sendPacket(line);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err == null ? l.packetSent(line) : l.packetSendFailed(linkErrorText(l, err)),
          style: ts(12),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: err == null ? C.green : C.red,
        duration: Duration(seconds: err == null ? 2 : 5),
      ),
    );
    // 失败时保留输入：用户改一个字符就能重发，不用重新敲一遍
    if (err == null) {
      _tx.clear();
      setState(() {});
    }
  }

  Widget _parsedList(List<Packet> list) {
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = list[i];
        final tc = _tc(p.type);
        // 淡入**只在元素创建时播一次**（见 _FadeInOnce）。原写法把 TweenAnimationBuilder
        // 放在 itemBuilder 里、且时长随行号无限增长（第 1000 行要 15 秒），ListView 每次
        // 重建 / 回收元素都会重播 —— 一屏行逐帧重绘，正是这个页面卡顿的主因。
        return _FadeInOnce(
          delayMs: (i % 8) * 18,
          child: SoftCard(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openStation(p.src),
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: p.raw));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(S.of(context).copiedPacket, style: ts(12)),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: tc.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _tn(context, p.type),
                            style: ts(9, c: tc, w: FontWeight.w700, ls: 0.5),
                          ),
                        ),
                        SizedBox(width: 6),
                        // 来源徽标：一眼看出这条报文是从 APRS-IS 还是射频
                        // （TNC / 声卡）来的 —— 排查链路问题时最关键的一条信息。
                        Tooltip(
                          message: S.of(context).packetSource,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _sc(p.source).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _sc(p.source),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _sn(context, p.source),
                                  style: ts(9,
                                      c: _sc(p.source), w: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            p.src,
                            style: ts(12, c: C.blue, w: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(' → ', style: ts(12, c: C.greyLight)),
                        Flexible(
                          child: Text(
                            p.dest,
                            style: ts(12, c: C.slate),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(_fmt(p.time), style: ts(10, c: C.grey)),
                      ],
                    ),
                    if (p.info != null) ...[
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: C.bgSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(p.info!, style: mono(11, c: C.slate)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _rawList(List<Packet> list) {
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final p = list[i];
        return GestureDetector(
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: p.raw));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(S.of(context).copiedPacket, style: ts(12)),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: C.surfaceFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fts(p.time), style: mono(10, c: C.greyLight)),
                SizedBox(width: 8),
                // 原始模式下也标来源：排查时常常只看这一屏。
                Text(
                  _sn(context, p.source),
                  style: mono(10, c: _sc(p.source)),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.raw,
                    style: mono(11, c: C.green),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openStation(String call) {
    Station? s;
    for (final x in widget.state.stations) {
      if (x.call == call) {
        s = x;
        break;
      }
    }
    if (s != null) {
      final station = s;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => StationDetail(state: widget.state, station: station),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).noPositionInfo(call)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _fmt(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return S.of(context).secondsAgo(d.inSeconds);
    if (d.inMinutes < 60) return S.of(context).minutesAgo(d.inMinutes);
    if (d.inHours < 24) return S.of(context).hoursAgo(d.inHours);
    return S.of(context).daysAgo(d.inDays);
  }

  String _fts(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

/// 让子树**只淡入一次**（元素创建时），而不是每次 rebuild 重播。
///
/// 为什么不用 TweenAnimationBuilder：它在 build 里被调用一次就重启动画一次，
/// 而 ListView 的元素在滚动中会反复 build / 回收 —— 于是整屏行一直在逐帧重绘。
class _FadeInOnce extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _FadeInOnce({required this.child, this.delayMs = 0});

  @override
  State<_FadeInOnce> createState() => _FadeInOnceState();
}

class _FadeInOnceState extends State<_FadeInOnce> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    // 交错一点点，让新到的一批报文是"刷出来"的；但封顶，不随行号增长。
    Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: widget.child,
      );
}
