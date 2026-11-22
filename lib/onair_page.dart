import 'dart:async';

import 'package:flutter/material.dart';

import 'map_rail.dart';
import 'material.dart';
import 'onair.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── On-Air Friends ───
///
/// 三块内容共用一份数据（[OnAirInfo] 与 [onAirFriendsOf]）：
///   * [OnAirChip] 是主页地图上那张小卡片；
///   * [OnAirPage] 是点开之后的设置与友台列表；
///   * 信标备注由 AppState._beaconComment 写出去（同一份编码规则）。
///
/// 所以「守听什么」只有一个出处：改完保存，卡片、信标、别人的列表立刻一致。
class OnAirPage extends StatelessWidget {
  final AppState state;
  const OnAirPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SettingsPageShell(
      title: s.onAirTitle,
      subtitle: s.onAirLead,
      icon: Icons.podcasts_rounded,
      color: C.green,
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) => Column(
          children: [
            OnAirCards(state: state),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// 设置卡 + 友台列表卡。两页共用（主页卡片只负责跳到这里）。
class OnAirCards extends StatefulWidget {
  final AppState state;
  const OnAirCards({super.key, required this.state});

  @override
  State<OnAirCards> createState() => _OnAirCardsState();
}

class _OnAirCardsState extends State<OnAirCards> {
  late final TextEditingController _freq;
  late final TextEditingController _extra;
  late final TextEditingController _filter;
  String _mode = 'FM';
  String _fltMode = '';
  Timer? _fltDebounce;

  /// 能填的模式。都是 ham 里常见的；填别的接不住也没关系 —— 收端只当字符串显示。
  static const _modes = <String>[
    'FM',
    'NFM',
    'AM',
    'USB',
    'LSB',
    'CW',
    'C4FM',
    'DMR',
    'FT8',
  ];

  AppState get st => widget.state;

  @override
  void initState() {
    super.initState();
    _freq = TextEditingController(text: st.onAirFreq);
    _extra = TextEditingController(text: st.onAirExtra);
    _filter = TextEditingController();
    if (_modes.contains(st.onAirMode)) _mode = st.onAirMode;
  }

  @override
  void dispose() {
    _fltDebounce?.cancel();
    _freq.dispose();
    _extra.dispose();
    _filter.dispose();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  void _save() {
    final ok = st.saveOnAir(
      freq: _freq.text,
      mode: _mode,
      extra: _extra.text,
    );
    if (!ok) {
      _toast(S.of(context).onAirFreqBad);
      return;
    }
    // 存的是归一后的值（145500 → 145.500）：把框里也换成这个，免得框里一个样、
    // 卡片上另一个样。
    _freq.text = st.onAirFreq;
    _toast(S.of(context).onAirSaved);
  }

  /// 点一位友台 → 写一句约通联的话，走普通 APRS 消息发出去。
  Future<void> _compose(OnAirFriend f) async {
    final s = S.of(context);
    final ctrl = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.onAirQso} · ${f.call}',
                  style: ts(13, w: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(f.info.label, style: ts(11.5, c: C.slate)),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: ts(13),
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: s.onAirQsoHint,
                    hintStyle: ts(13, c: C.grey),
                    filled: true,
                    fillColor: C.surfaceFill,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: C.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: C.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: C.blue, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        child: Text(S.of(ctx).cancel, style: ts(13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: C.blue,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onPressed: () =>
                            Navigator.pop(ctx, ctrl.text.trim()),
                        child: Text(s.onAirQsoSend, style: ts(13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    ctrl.dispose();
    if (text == null || text.isEmpty || !mounted) return;
    if (!st.msgLinkUp) {
      _toast(S.of(context).onAirQsoNoLink);
      return;
    }
    st.sendMessage(f.call, text);
    _toast(S.of(context).onAirQsoSent);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final all = st.onAirFriends;
    final modes = onAirModesOf(all);
    final q = _filter.text.trim().toLowerCase();
    final list = all.where((f) {
      if (_fltMode.isNotEmpty &&
          (f.info.mode.isEmpty ? 'FM' : f.info.mode) != _fltMode) {
        return false;
      }
      if (q.isEmpty) return true;
      return f.info.freq.contains(q) ||
          f.call.toLowerCase().contains(q) ||
          f.info.mode.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        SettingsSectionCard(
          title: s.onAirEnable,
          icon: Icons.podcasts_rounded,
          color: C.green,
          trailing: SettingsSwitch(
            '',
            value: st.onAirOn,
            color: C.green,
            onChanged: st.setOnAirOn,
          ),
          children: [
            if (st.onAirOn) ...[
              SettingsInput(
                s.onAirFreq,
                _freq,
                hint: '145.500',
                badge: st.onAirFreq.isEmpty ? s.oobeDoneUnset : null,
              ),
              SettingsChoice<String>(
                s.onAirMode,
                value: _mode,
                options: _modes,
                labelOf: (m) => m,
                onChanged: (v) => setState(() => _mode = v),
              ),
              SettingsInput(
                s.onAirExtra,
                _extra,
                hint: s.onAirExtraHint,
                onChanged: (_) => setState(() {}),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: C.green,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onPressed: _save,
                        child: Text(s.onAirSave, style: ts(13)),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              // 关着的时候不摆一排空输入框：先说清楚它做什么，再让用户自己开。
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Text(s.onAirLead, style: ts(12, c: C.slate)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSectionCard(
          title: s.onAirFriends,
          icon: Icons.people_alt_rounded,
          color: C.green,
          subtitle: s.onAirTtlNote,
          trailing: Text('${all.length}', style: ts(13, w: FontWeight.w700)),
          children: [
            if (all.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _modeChip(s.onAirFilterAll, _fltMode.isEmpty, ''),
                      for (final m in modes)
                        _modeChip(m, _fltMode == m, m),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                child: TextField(
                  controller: _filter,
                  style: ts(13),
                  onChanged: (_) {
                    _fltDebounce?.cancel();
                    _fltDebounce = Timer(
                      const Duration(milliseconds: 250),
                      () {
                        if (mounted) setState(() {});
                      },
                    );
                  },
                  decoration: InputDecoration(
                    hintText: s.onAirFilterFreq,
                    hintStyle: ts(13, c: C.grey),
                    prefixIcon:
                        Icon(Icons.search_rounded, size: 18, color: C.grey),
                    filled: true,
                    fillColor: C.surfaceFill,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: C.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: C.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: C.blue, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Text(s.onAirEmpty, style: ts(12, c: C.grey)),
              )
            else
              for (final f in list) _friendRow(f),
          ],
        ),
      ],
    );
  }

  Widget _modeChip(String label, bool active, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _fltMode = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? C.greenBg : C.greyBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? C.green.withValues(alpha: 0.45) : C.border,
            ),
          ),
          child: Text(
            label,
            style: ts(
              11.5,
              w: active ? FontWeight.w700 : FontWeight.w500,
              c: active ? C.green : C.slate,
            ),
          ),
        ),
      ),
    );
  }

  /// 「多久前听到的」：与台站页同一套人话（秒 / 分 / 时 / 天）。
  String _ago(BuildContext context, DateTime at) {
    final s = S.of(context);
    final d = DateTime.now().difference(at);
    if (d.inSeconds < 60) return s.secondsAgo(d.inSeconds);
    if (d.inMinutes < 60) return s.minutesAgo(d.inMinutes);
    if (d.inHours < 24) return s.hoursAgo(d.inHours);
    return s.daysAgo(d.inDays);
  }

  /// 一位友台一行：呼号 + 模式 + 频率 + 附加参数，右边是最后听到的时间。
  ///
  /// 点整行 = 约通联（不需要再找一个按钮：列表里最想做的事就是跟这一位说句话）。
  Widget _friendRow(OnAirFriend f) {
    final extra = f.info.extra;
    return InkWell(
      onTap: () => unawaited(_compose(f)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: C.greenBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                f.info.mode.isEmpty ? 'FM' : f.info.mode,
                style: ts(10, w: FontWeight.w700, c: C.green),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.call,
                    style: ts(13, w: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    extra.isEmpty
                        ? '${f.info.freq} MHz'
                        : '${f.info.freq} MHz · $extra',
                    style: ts(11, c: C.slate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _ago(context, f.seen),
              style: ts(10, c: C.grey),
            ),
            const SizedBox(width: 6),
            Icon(Icons.forum_rounded, size: 16, color: C.blue),
          ],
        ),
      ),
    );
  }
}

/// 主页地图左上那一列里的 On-Air 读数行。
///
/// 出现条件：启用了 APRS 服务器类型的链路，且本机呼号合法（见 AppState.onAirVisible）。
/// 它和同列其它行同一个外形（见 `lib/map_rail.dart`）：图标 + 一行读数 + 一枚箭头。
/// 开着且服务器在线时图标、描边与标题转绿，右端写友台数；其余状态只有一个灰读数。
///
/// 以前它是一张自带呼吸辉光的独立卡片：左列里唯一一块会动的、也是最宽的东西，
/// 与上下几枚胶囊叠在一起就是「好乱 难看」的来源。辉光去掉了 —— 状态改用颜色与
/// 友台数表达，既省一层每帧动画，也让这一列安静下来。
class OnAirChip extends StatelessWidget {
  final AppState state;
  const OnAirChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final st = state;
    if (!st.onAirVisible) return const SizedBox.shrink();
    final s = S.of(context);
    final up = st.onAirServerUp;
    final on = st.onAirOn && up;
    final friends = on ? st.onAirFriends.length : 0;
    final status = !up
        ? s.onAirNeedServer
        : !st.onAirOn
            ? s.onAirOff
            : st.onAirFreq.isEmpty
                ? s.onAirNoFreq
                : st.onAirInfo.label;
    final accent = on ? C.green : C.grey;
    return MapRailItem(
      icon: Icons.podcasts_rounded,
      iconColor: accent,
      borderColor: on ? accent.withValues(alpha: 0.30) : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OnAirPage(state: st)),
      ),
      // 两行：上行是名字与友台数，下行是这一行真正要读的东西（频率 + 模式，
      // 没开时是一句原因）。挤成一行时频率与模式会被省略号吃掉，那正是这张卡
      // 唯一有用的内容。
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                s.onAirTitle,
                style: ts(10.5, c: on ? C.green : C.grey, w: FontWeight.w700),
              ),
              const Spacer(),
              if (friends > 0)
                Text(
                  s.onAirFriendCount('$friends'),
                  style: ts(10, c: C.green, w: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ts(
              on ? 12.5 : 12,
              c: on ? C.ink : C.grey,
              w: on ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 16,
        color: on ? C.green : C.grey,
      ),
    );
  }
}
