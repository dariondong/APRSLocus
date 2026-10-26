/// Web：没有 `dart:io`，也就没有「本机 CPU / 内存占用」这回事。
///
/// 一律返回 null ⇒ 报文里就不带这两个字段（宁可少发，也不发编出来的数字）。
class DesktopMetrics {
  DesktopMetrics._();

  static ({int? cpu, int? mem})? latest;

  static DateTime? latestAt;

  static bool get supported => false;

  static Future<({int? cpu, int? mem})?> refresh({
    Duration minGap = const Duration(seconds: 15),
  }) async =>
      null;
}
