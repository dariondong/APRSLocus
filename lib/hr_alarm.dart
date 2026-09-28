import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 心率异常告警（issue #21-8）───
///
/// 用户要的是：「如果连接到外置心率设备，而且设备正常情况下，用户心率处于不正常值时，
/// 系统通知弹出警告，可以选择跳转电话页面紧急电话，和给附近 100 公里内的台站信标发送信息」。
///
/// 三条设计上的取舍，都跟「误报的代价不对称」有关：
///
/// 1. **只提醒，不代替用户行动**。「拨号」与「发求助」都必须由用户亲手按 ——
///    误报的代价完全不对称：静默不动只是错过一次提醒，而**自动**发出去的 SOS
///    会让一群人真的出动、甚至惊动救援。
/// 2. **不自动发广播**。APRS 没有「广播给 100km 内所有台站」这种原语（消息是
///    点对点的），所以「给附近台站发信息」= 取**最近 5 个** 100km 内的台站逐个发
///    一条短信。条数上限是刻意的：一屏能扫完、也不会把信道刷满。
/// 3. **挂在外壳之上、由 seq 触发**（不是由某个页面触发）：告警可能在用户停留在
///    任何页面时发生（包括 1.0 与 2.0 两套外壳），挂在 [MaterialApp.home] 外面
///    才能保证「无论在哪个页面都弹得出来」。
///
/// 与 `AppState` 的分工：判定与冷却时间在 state 里（`_checkHrAlarm`），这里只负责
/// 把已经成立的告警**呈现**出来，并在用户处理完后 `clearHrAlarm()`。
class HrAlarmWatcher extends StatefulWidget {
  final AppState state;
  final Widget child;

  const HrAlarmWatcher({
    super.key,
    required this.state,
    required this.child,
  });

  /// 「附近」的半径（公里）——用户明确说 100 公里。
  static const double nearbyRadiusKm = 100;

  /// 一次最多给几个台站发（见类注释第 2 条）。
  static const int maxTargets = 5;

  @override
  State<HrAlarmWatcher> createState() => _HrAlarmWatcherState();
}

class _HrAlarmWatcherState extends State<HrAlarmWatcher> {
  int _lastSeq = 0;

  /// 正在显示告警（避免同一时刻叠两个对话框）
  bool _showing = false;

  AppState get st => widget.state;

  @override
  void initState() {
    super.initState();
    _lastSeq = st.hrAlarmSeq;
    st.addListener(_onState);
  }

  @override
  void dispose() {
    st.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (!mounted) return;
    final seq = st.hrAlarmSeq;
    if (seq == _lastSeq) return;
    _lastSeq = seq;
    // 放到帧后：这一跳多半发生在 notify 的同步回调里，直接弹会踩「build 期间
    // 改状态」那类问题（与 shell2 的跨页请求同一套处理）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_show());
    });
  }

  Future<void> _show() async {
    if (_showing) return;
    final bpm = st.hrAlarm;
    if (bpm == null) return;
    final s = S.of(context);
    _showing = true;
    final action = await showDialog<String>(
      context: context,
      // 告警必须能一路回到「关掉它」，所以不允许点空白关（barrierDismissible
      // 会让用户以为处理过了，而 hrAlarm 还挂着）。
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        icon: Icon(Icons.favorite_rounded, color: C.red, size: 34),
        title: Text(s.hrAlarmTitle, style: ts(16, w: FontWeight.w800)),
        content: Text(
          s.hrAlarmBody('$bpm', '${st.hrAlarmLow}', '${st.hrAlarmHigh}'),
          style: ts(13, h: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'dismiss'),
            child: Text(s.hrAlarmDismiss),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'sos'),
            child: Text(s.hrAlarmSendNearby,
                style: ts(13, c: C.orange, w: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.red),
            onPressed: () => Navigator.pop(ctx, 'call'),
            child: Text(s.hrAlarmCall),
          ),
        ],
      ),
    );
    _showing = false;
    if (!mounted) return;
    switch (action) {
      case 'call':
        unawaited(_call(st.emergencyTel));
      case 'sos':
        await _sendNearby();
      default:
        st.clearHrAlarm();
    }
  }

  Future<void> _call(String number) async {
    final s = S.of(context);
    try {
      final ok = await launchUrl(Uri.parse('tel:$number'));
      if (!ok) _toast(s.hrAlarmNoDialer);
    } catch (_) {
      // 桌面/平板没有电话功能：如实说，而不是静默什么都不发生
      _toast(s.hrAlarmNoDialer);
    }
    st.clearHrAlarm();
  }

  /// 给附近 [HrAlarmWatcher.nearbyRadiusKm] 内最近的几个台站发一条求助信息。
  ///
  /// 发送前**必须再确认一次**：这是真的会出现在别人手机上的东西。
  Future<void> _sendNearby() async {
    final s = S.of(context);
    final targets = st.nearbyStations(HrAlarmWatcher.nearbyRadiusKm,
        limit: HrAlarmWatcher.maxTargets);
    if (targets.isEmpty) {
      _toast(s.hrAlarmNoNearby);
      st.clearHrAlarm();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(s.hrAlarmSendConfirmTitle, style: ts(15, w: FontWeight.w800)),
        content: Text(
          // 占位符在 arb 里声明为 String，所以这里显式插值 ——
          // 直接传 int 会报 argument_type_not_assignable（CI 上踩过）。
          s.hrAlarmSendConfirmBody(
            '${targets.length}',
            targets.map((t) => t.call).join('、'),
          ),
          style: ts(13, h: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.hrAlarmSendNearby),
          ),
        ],
      ),
    );
    if (ok != true) {
      st.clearHrAlarm();
      return;
    }
    // 正文刻意短：射频模式下单条消息上限 67 字符（见 AppState.tncMaxMsgLen），
    // 而求救信息最不该因为太长而被拒发/截断。
    final pos = st.myHasFix
        ? '${st.myLat!.toStringAsFixed(4)},${st.myLng!.toStringAsFixed(4)}'
        : '--';
    final text = 'SOS HR=${st.hrAlarm ?? st.myHr ?? 0} $pos';
    var sent = 0;
    for (final t in targets) {
      try {
        st.sendMessage(t.call, text);
        sent++;
      } catch (_) {}
    }
    if (!mounted) return;
    _toast(s.hrAlarmSent('$sent'));
    st.clearHrAlarm();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
