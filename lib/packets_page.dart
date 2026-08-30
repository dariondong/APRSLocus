import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
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
                          style: ts(14, c: C.blue, w: FontWeight.w700),
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
                      borderRadius: BorderRadius.circular(10),
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
                      borderRadius: BorderRadius.circular(10),
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
                          style: ts(14, c: C.grey),
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
            ],
          ),
        );
      },
    );
  }

  void _sendRaw() {
    if (_tx.text.trim().isEmpty) return;
    widget.state.sendPacket(_tx.text.trim());
    _tx.clear();
  }

  Widget _parsedList(List<Packet> list) {
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = list[i];
        final tc = _tc(p.type);
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 220 + i * 15),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(opacity: v, child: child),
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
              color: C.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fts(p.time), style: mono(10, c: C.greyLight)),
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
