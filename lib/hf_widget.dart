import 'dart:convert';

import 'package:flutter/services.dart';

import 'app_widget.dart';
import 'hf.dart';
import 'l10n/app_localizations.dart';

/// ─── 短波 / 电离层传播桌面小组件（Android，4×2）───
///
/// 与天气组件（[AppWidgetBridge]）同一套架构：Flutter 侧算好、本地化好，
/// 推一份快照 JSON 给原生，原生只负责「把字符串放进格子」。
/// 详见 app_widget.dart 顶部关于「为什么组件不自己联网」的说明。
///
/// **本组件用的是同一个通道的另一个方法**（`updateHf`），不是新开通道：
/// 两者都由 [AppWidgetSync] 推送、同一个 Lifecycle，分通道只会多一份
/// attach 与错误处理。
///
/// **固定 4×2**：内容是一张「波段 × 昼夜」的**表**，表不能像列表那样优雅降级
/// （挤到 2×2 就只剩波段名、没有条件值）。所以原生侧声明 `resizeMode="none"`。

/// 快照格式版本（与 HfWidgetProvider.kt 的 SNAPSHOT_VERSION 必须一致）
const int kHfWidgetSnapshotVersion = 1;

/// 汇总指数格数（SFI / Kp / A）—— 与 aw_widget_hf.xml 的格子数一致
const int kHfWidgetSummaryCells = 3;

/// 波段行数上限（与 aw_widget_hf.xml 的行数一致；源数据是 4 个波段对）
const int kHfWidgetBandRows = 4;

/// 白底组件用的**基准色**（不提亮）。
///
/// 与天气组件的关键区别：天气组件压在**彩色渐变**上，所以要 `widgetTipTextArgb`
/// 提亮 35% 才看得清；短波组件是**白底**，提亮色反而太淡
/// （`#68C389` 在白底上几乎看不见）。面板本身就是浅色 UI、用的就是这组基准色，
/// 所以白底组件跟着用基准色才一致。
const Color _kGood = Color(0xFF16A34A);
const Color _kFair = Color(0xFFD97706);
const Color _kPoor = Color(0xFFE11D48);

/// Kp 指数 → 提示色。
///
/// Kp 是**地磁活动**强度（0–9）：越大越糟 —— 地磁扰动会抬高低纬吸收、
/// 让极区路径衰减，高波段尤其明显。所以 3 以内给绿、4 给橙、5 以上给红。
/// 阈值与 lib/hf.dart 的 `HfNow.geomagActive`（K≥4）/ `geomagStorm`（K≥5）一致。
int _kpArgb(int k) {
  if (k < 0) return 0; // 无数据：不染色
  if (k <= 3) return colorToArgb(_kGood);
  if (k == 4) return colorToArgb(_kFair);
  return colorToArgb(_kPoor);
}

/// A 指数 → 提示色。A 是 Kp 的日累计（越大越糟），阈值按业界习惯取 15/30。
int _aArgb(int a) {
  if (a < 0) return 0;
  if (a <= 15) return colorToArgb(_kGood);
  if (a <= 30) return colorToArgb(_kFair);
  return colorToArgb(_kPoor);
}

/// 一条波段行的展示数据（日间 / 夜间各自带本地化文案与颜色）
Map<String, Object?> _bandRow(HfBand b, AppLocalizations s) {
  final dq = hfQualityOf(b.day);
  final nq = hfQualityOf(b.night);
  return <String, Object?>{
    'name': b.label,
    'dayLabel': hfQualityLabel(dq, s),
    // 色带底色靠这个 level 名选（Kotlin 的 TRACK_BY_LEVEL → aw_track_*）。
    // 用**枚举名**而不是色值：白底 chip 是「实心色块 + 白字」，
    // 换底只能换 drawable（TextView 没有 setColorFilter），
    // 所以这里给的是「哪一张 drawable」而不是「什么颜色」。
    'dayLevel': dq.name,
    'nightLabel': hfQualityLabel(nq, s),
    'nightLevel': nq.name,
  };
}

/// 组装短波组件的快照（纯函数，不碰平台通道，便于单测）。
///
/// 所有面向用户的文案都由 [AppLocalizations] 取好，原生侧不做任何条件判断
/// 与本地化 —— 包括「Good/Fair/Poor」的中文说法，也是这里翻好的。
Map<String, Object?> buildHfWidgetSnapshot({
  required HfCenter hf,
  required AppLocalizations s,
  DateTime? now,
}) {
  final snap = <String, Object?>{
    'v': kHfWidgetSnapshotVersion,
    // 快照生成时刻（调试用）
    'ts': (now ?? DateTime.now()).millisecondsSinceEpoch,
    'hasData': false,
    'title': s.hfTitle,
    'indices': <Map<String, Object?>>[],
    // 列头两列：位置由布局的等分列决定（与下面 chip 左边缘对齐），
    // 文案要本地化所以由这里给
    'dayLabel': s.hfDay,
    'nightLabel': s.hfNight,
    'bands': <Map<String, Object?>>[],
    // 空状态：直接复用「暂无数据」提示（它就是此刻最该说的一句话）
    'emptyLabel': s.hfNoData,
  };

  final h = hf.now;
  if (h == null) return snap;

  snap['hasData'] = true;
  // 汇总行：SFI 不染色（它只是「太阳活动强度」，高低各有玩法，不是好坏）；
  // Kp / A 染色，因为它们是「传播今天稳不稳」的直接指标。
  snap['indices'] = <Map<String, Object?>>[
    <String, Object?>{'label': s.hfSfi, 'value': h.sfi, 'color': 0},
    <String, Object?>{
      'label': s.hfKp,
      'value': h.kIndex,
      'color': _kpArgb(h.kValue),
    },
    <String, Object?>{
      'label': s.hfAIndex,
      'value': h.aIndex,
      'color': _aArgb(h.aValue),
    },
  ];
  snap['bands'] = <Map<String, Object?>>[
    for (final b in h.bands.take(kHfWidgetBandRows)) _bandRow(b, s),
  ];
  // ── 6m 段（只给「更高的档位」用）──
  //
  // 4×2 放不下：4 个 HF 波段对 + 指数行已经把 296×140dp 占满（实测 126.3/130）。
  // 硬塞会把 chip 高与字号再压一轮 —— 而那正是前一版被判定「挤」的原因。
  // 所以 6m 只在用户把组件拉高时显示（布局有 4×2 / 4×3 两档）。
  //
  // 6m 与 HF 波段的传播机理完全不同（Es / 极光 / F2），**不并进那张表** ——
  // 它没有「日间/夜间」之分，硬并会让「6m 日间 Poor」这种组合读起来像同一机理。
  final six = hfSixMeter(h);
  snap['six'] = <String, Object?>{
    'title': s.hfSixMeter,
    'es': s.hfEs,
    // ⚠ 必须过 hfQualityLabel：这里是**源数据的原始串**（'Good'/'Band Closed'…），
    //   直接下发会在中文界面里显示英文。原先就是漏了这一步 ——
    //   而 'Band Closed' 恰恰是 6m 最常见的取值，等于长期露英文。
    //   （对照：逐波段表的 dayLabel/nightLabel 一直是本地化的，只有这里漏了。）
    'esValue': hfQualityLabel(hfQualityOf(six.es), s),
    'aurora': s.hfAurora,
    'auroraValue': hfQualityLabel(hfQualityOf(six.aurora), s),
    'f2': s.hfF2,
    'f2Value': six.f2 ? s.hfQGood : HfNow.none,
    'level': six.quality.name,
    'label': hfQualityLabel(six.quality, s),
    'color': colorToArgb(hfQualityColor(six.quality)),
  };
  return snap;
}

/// 短波组件 ↔ Flutter 的桥。
class HfWidgetBridge {
  HfWidgetBridge._();

  static const MethodChannel _ch = MethodChannel(kAppWidgetChannel);

  /// 已推送快照的指纹（与天气组件同样的理由：内容没变就别过通道）
  static String? _lastFingerprint;

  /// 组装当前快照并推给原生（落盘 + 刷新短波组件的 RemoteViews）。
  static Future<void> push({
    required AppLocalizations s,
    required HfCenter hf,
  }) async {
    final payload = jsonEncode(buildHfWidgetSnapshot(hf: hf, s: s));
    if (payload == _lastFingerprint) return;

    try {
      await _ch.invokeMethod<void>('updateHf', payload);
      _lastFingerprint = payload;
    } on MissingPluginException {
      // 非 Android（Windows / Web / 桌面调试）没有这个通道。照样记指纹，
      // 否则每次依赖变化都会重算一遍再白跑一次通道。
      _lastFingerprint = payload;
    } on PlatformException {
      // 刷新失败不记指纹，下次状态变化时还会再试
    }
  }

  /// 清空已保存的快照（组件回到占位态）
  static Future<void> clear() async {
    _lastFingerprint = null;
    try {
      await _ch.invokeMethod<void>('clearHf');
    } on MissingPluginException {
      // 非 Android：忽略
    } on PlatformException {
      // 忽略
    }
  }
}
