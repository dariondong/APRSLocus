import 'dart:convert';

/// ADIF（Amateur Data Interchange Format）记录。
///
/// 本导出**只写呼号与时间**（CALL / QSO_DATE / TIME_ON），
/// 不写 MODE / BAND —— APRS 的频段 App 无从得知，写错反而会污染日志；
/// 留空让用户在自己的日志软件里统一补，比写入错误信息更安全。
class AdifRecord {
  /// 对方呼号（导出时统一转大写）
  final String call;

  /// 通联起始时间（写入时转 UTC）
  final DateTime timeOn;

  const AdifRecord({required this.call, required this.timeOn});
}

/// ADIF 文本生成器。
///
/// 规范要点（都已在实现中遵守，并有单元测试钉住）：
/// - 每个字段写作 `<名称:长度>值`，**长度是值的 UTF-8 字节数**，不是字符数。
///   呼号是 ASCII 时两者恰好相等，但代码不依赖这一点（值里出现非 ASCII 时会算错）。
/// - 日期为 `YYYYMMDD`、时间为 `HHMMSS`，且**必须是 UTC**。
/// - 头部以 `<EOH>` 结束，每条记录以 `<EOR>` 结束。
class Adif {
  Adif._();

  /// 写入头部的 ADIF 版本
  static const version = '3.1.4';

  /// 生成 ADIF 文本。
  ///
  /// [created] 为生成时间（头部 CREATED_TIMESTAMP），默认取当前时间。
  static String encode(
    List<AdifRecord> records, {
    String programId = 'APRSlocus',
    String programVersion = '',
    DateTime? created,
  }) {
    final b = StringBuffer()
      ..write(_field('ADIF_VER', version))
      ..write(_field('PROGRAMID', programId));
    if (programVersion.isNotEmpty) {
      b.write(_field('PROGRAMVERSION', programVersion));
    }
    final c = (created ?? DateTime.now()).toUtc();
    b
      ..write(_field('CREATED_TIMESTAMP', '${dateOf(c)} ${timeOf(c)}'))
      ..write('<EOH>')
      ..write('\n');

    for (final r in records) {
      final t = r.timeOn.toUtc();
      b
        ..write(_field('CALL', r.call.trim().toUpperCase()))
        ..write(_field('QSO_DATE', dateOf(t)))
        ..write(_field('TIME_ON', timeOf(t)))
        ..write('<EOR>')
        ..write('\n');
    }
    return b.toString();
  }

  /// `<名称:字节长度>值`
  static String _field(String name, String value) =>
      '<$name:${utf8.encode(value).length}>$value';

  /// `YYYYMMDD`（**UTC**）
  static String dateOf(DateTime utc) {
    final u = utc.toUtc();
    return '${u.year.toString().padLeft(4, '0')}'
        '${u.month.toString().padLeft(2, '0')}'
        '${u.day.toString().padLeft(2, '0')}';
  }

  /// `HHMMSS`（**UTC**）
  static String timeOf(DateTime utc) {
    final u = utc.toUtc();
    return '${u.hour.toString().padLeft(2, '0')}'
        '${u.minute.toString().padLeft(2, '0')}'
        '${u.second.toString().padLeft(2, '0')}';
  }

  /// 导出文件名：`APRSlocus_20260912_131500.adi`（按**本地时间**取名，便于用户辨认）
  static String fileName(DateTime local) => 'APRSlocus_'
      '${local.year.toString().padLeft(4, '0')}'
      '${local.month.toString().padLeft(2, '0')}'
      '${local.day.toString().padLeft(2, '0')}_'
      '${local.hour.toString().padLeft(2, '0')}'
      '${local.minute.toString().padLeft(2, '0')}'
      '${local.second.toString().padLeft(2, '0')}.adi';
}
