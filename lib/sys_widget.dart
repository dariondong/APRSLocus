import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_widget.dart';
import 'l10n/app_localizations.dart';
import 'state.dart';

/// ─── 系统状态桌面小组件（Android，4×2）───
///
/// 与天气 / 短波组件同一套架构：Flutter 侧算好、本地化好，推一份快照 JSON，
/// 原生侧只负责「把字符串放进格子」。详见 app_widget.dart 顶部说明。
///
/// **它回答三个问题**（APRS 是后台长期运行的应用，这三件事最常被问）：
///   ① 还在收吗           → 四条链路的状态点 + 「收 N」
///   ② 我的位置有没有上报  → 定位状态 + 信标倒计时
///   ③ 为什么地图没台站    → 「台站 N」
///
/// **为什么链路是「三态」而不是「连上/没连上」**：`未启用`（用户根本没开这条）
/// 与 `已启用但没连上`（开了、连不上）对用户的意义完全不同 —— 前者不用管，
/// 后者要去查。混成一个「未连接」会让人对着没启用的链路白折腾。
/// 所以这里有三种状态、三种颜色。

/// 快照格式版本（与 SysWidgetProvider.kt 的 SNAPSHOT_VERSION 必须一致）
const int kSysWidgetSnapshotVersion = 1;

/// 链路格子数（与 aw_widget_sys.xml 的格子数一致）
const int kSysWidgetLinkCount = 4;

/// 链路状态色（与 `theme.dart` 的 C.green / C.yellow / C.grey 同一组取向，
/// 也与短波组件的条件色同一套「浅色/深色都够对比」的取值）。
const int _cOk = 0xFF16A34A; // 已连接
const int _cPending = 0xFFD97706; // 已启用、未连上
const int _cOff = 0xFF94A3B8; // 未启用

/// 一条链路在组件上的展示（名字 + 状态文案 + 状态色）
typedef SysLinkTile = ({String name, String state, int color});

/// 四条链路的展示数据。
///
/// 顺序是**固定的**（APRS-IS / TNC / 音频 / PKWDWPL），不按状态排序 ——
/// 位置固定用户才能「一眼扫到那条我想看的」；按状态排序会让每次刷新后
/// 位置都变，反而更难读。
List<SysLinkTile> sysLinkTiles(AppState st, AppLocalizations s) {
  SysLinkTile one(String src, String name) {
    if (!st.enabledSources.contains(src)) {
      return (name: name, state: s.sysLinkOff, color: _cOff);
    }
    if (st.isUp(src)) {
      return (name: name, state: s.connected, color: _cOk);
    }
    // 已启用但没连上：可能是正在连、也可能失败 —— 对用户来说都是「等一下/
    // 去查一下」，用同一个文案与颜色，不假装能区分。
    return (name: name, state: s.connecting, color: _cPending);
  }

  return [
    one(AppState.srcAprsIs, 'APRS-IS'),
    one(AppState.srcTnc, 'TNC'),
    one(AppState.srcAudio, s.sysLinkAudio),
    one(AppState.srcPkwdwpl, 'PKWDWPL'),
  ];
}

/// 组装系统状态快照（纯函数，不碰平台通道，便于单测）
Map<String, Object?> buildSysWidgetSnapshot({
  required AppState st,
  required AppLocalizations s,
  DateTime? now,
}) {
  final snap = <String, Object?>{
    'v': kSysWidgetSnapshotVersion,
    'ts': (now ?? DateTime.now()).millisecondsSinceEpoch,
    'title': s.sysTitle,
    'call': st.myFullCall,
    // 定位：已定位 / 等待定位（复用既有的 beaconWaitingFix，不另造词）
    'fixState': st.myHasFix ? s.sysFixOk : s.beaconWaitingFix,
    'grid': st.myGrid,
    'links': <Map<String, Object?>>[
      for (final t in sysLinkTiles(st, s))
        <String, Object?>{
          'name': t.name,
          'state': t.state,
          'color': t.color,
        },
    ],
    'rx': s.sysRx('${st.packetsRx}'),
    'tx': s.sysTx('${st.packetsTx}'),
    // 信标：直接把状态层**已本地化**的倒计时文案包进来 ——
    // 「已关闭 / 未连接 / 等待定位 / 45s / 即将」这些分支判断在 state.dart 里，
    // 组件侧再判一次就会两处漂移（那一类 bug 正是状态层刻意结构化的原因）。
    'beacon': s.sysBeacon(st.nextBeaconIn),
    'stations': s.sysStations('${st.stations.length}'),
    'emptyLabel': s.sysEmpty,
  };
  return snap;
}

/// 系统状态组件 ↔ Flutter 的桥
class SysWidgetBridge {
  SysWidgetBridge._();

  static const MethodChannel _ch = MethodChannel(kAppWidgetChannel);

  /// 已推送快照的指纹（与天气/短波同样的理由：内容没变就别过通道）
  static String? _lastFingerprint;

  static Future<void> push({
    required AppLocalizations s,
    required AppState st,
  }) async {
    final payload = jsonEncode(buildSysWidgetSnapshot(st: st, s: s));
    if (payload == _lastFingerprint) return;
    try {
      await _ch.invokeMethod<void>('updateSys', payload);
      _lastFingerprint = payload;
    } on MissingPluginException {
      // 非 Android（Windows / Web / 桌面调试）没有这个通道。照样记指纹，
      // 否则每次依赖变化都会重算一遍再白跑一次通道。
      _lastFingerprint = payload;
    } on PlatformException {
      // 刷新失败不记指纹，下次状态变化时还会再试
    }
  }

  static Future<void> clear() async {
    _lastFingerprint = null;
    try {
      await _ch.invokeMethod<void>('clearSys');
    } on MissingPluginException {
      // 非 Android：忽略
    } on PlatformException {
      // 忽略
    }
  }
}
