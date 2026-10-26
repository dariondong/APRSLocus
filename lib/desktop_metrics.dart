import 'desktop_metrics_io.dart'
    if (dart.library.html) 'desktop_metrics_web.dart' as impl;

/// 电脑端的整机负载读数（CPU 使用率 / 内存占用率），用于随位置报文一起上报。
///
/// 实现分两套：`desktop_metrics_io.dart`（真读 /proc、wmic、vm_stat）与
/// `desktop_metrics_web.dart`（一律 null）。Web 构建里 `dart:io` 不存在，
/// 所以**不能**在跨平台代码里直接 import 它。
class DesktopMetrics {
  DesktopMetrics._();

  static ({int? cpu, int? mem})? get latest => impl.DesktopMetrics.latest;

  static bool get supported => impl.DesktopMetrics.supported;

  static Future<({int? cpu, int? mem})?> refresh({
    Duration minGap = const Duration(seconds: 15),
  }) =>
      impl.DesktopMetrics.refresh(minGap: minGap);
}
