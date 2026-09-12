import 'dart:convert';

/// ADIF（Amateur Data Interchange Format）记录。
class AdifRecord {
  /// 对方呼号（导出时统一转大写）
  final String call;

  /// 通联起始时间（写入时转 UTC）
  final DateTime timeOn;

  const AdifRecord({required this.call, required this.timeOn});
}

/// 导出选项 —— 由用户在导出页选择。
///
/// 为什么需要这些选项：ADIF 的 `MODE` 是**必需**字段，很多日志软件
/// （含 QRZ Logbook）在缺少 `MODE` 时会**直接拒收整条记录**
/// —— 报错是「缺少 MODE」，而不是呼号或时间有问题。
/// 早期版本为了「不写入不确定的信息」而完全省略 MODE，结果文件导不进去，
/// 所以现在改为：给一个**默认有 MODE**、且可让用户自行调整的方案。
class AdifOptions {
  /// `MODE` 值。`null` = 不写（不推荐：多数日志软件会拒收）。
  /// 默认 `PKT`（Packet radio）—— 它是 ADIF 标准词表里的合法值，
  /// 也正是 APRS 的传输方式。
  final String? mode;

  /// 是否在 `MODE` 之外附加 `SUBMODE: APRS`。
  /// 仅在 [mode] 非空时生效（ADIF 规定 SUBMODE 不能脱离 MODE 单独出现）。
  final bool subModeAprs;

  /// `BAND` 值（如 `2m` / `70cm`）。`null` = 不写。
  /// 默认不写 —— APRS 的实际频段 App 无从得知，写错会污染日志。
  final String? band;

  /// `FREQ` 值（**MHz**，如 `144.640`）。`null` = 不写。
  ///
  /// 默认不写、由用户自行填写 —— 各地 APRS 频率不同，App 无从得知。
  /// 传入前必须已由 [Adif.normalizeFreq] 规范化（小数分隔符为 `.`）。
  final String? freq;

  /// 是否只写**基础呼号**（去掉 `-SSID`）。
  ///
  /// 会话里的呼号带 SSID（如 `BG7PGW-2`），而部分日志软件的呼号校验
  /// 只认基础呼号；打开后写成 `BG7PGW`。
  /// 默认关闭 —— 不做任何猜测性改写，用户明确需要时才开。
  final bool stripSsid;

  const AdifOptions({
    this.mode = 'PKT',
    this.subModeAprs = true,
    this.band,
    this.freq,
    this.stripSsid = false,
  });

  AdifOptions copyWith({
    Object? mode = _unset,
    bool? subModeAprs,
    Object? band = _unset,
    Object? freq = _unset,
    bool? stripSsid,
  }) => AdifOptions(
    mode: identical(mode, _unset) ? this.mode : mode as String?,
    subModeAprs: subModeAprs ?? this.subModeAprs,
    band: identical(band, _unset) ? this.band : band as String?,
    freq: identical(freq, _unset) ? this.freq : freq as String?,
    stripSsid: stripSsid ?? this.stripSsid,
  );

  /// 供 copyWith 区分「没传」与「显式传 null」
  static const _unset = Object();
}

/// ADIF 文本生成器。
///
/// 规范要点（都已在实现中遵守，并有单元测试钉住）：
/// - 每个字段写作 `<名称:长度>值`，**长度是值的 UTF-8 字节数**，不是字符数。
/// - 日期为 `YYYYMMDD`、时间为 `HHMMSS`，且**必须是 UTC**。
/// - 头部以 `<EOH>` 结束，每条记录以 `<EOR>` 结束。
/// - `SUBMODE` 不能脱离 `MODE` 单独出现。
class Adif {
  Adif._();

  /// 写入头部的 ADIF 版本
  static const version = '3.1.4';

  /// 可选的 `MODE` 值（含 `null` = 不写），供 UI 下拉框使用。
  /// 只列与本应用相关的几种，避免把整个 ADIF 词表塞进界面。
  static const modeChoices = <String?>['PKT', 'FM', 'DATA', null];

  /// 可选的 `BAND` 值（含 `null` = 不写）。均为 ADIF 标准写法。
  static const bandChoices = <String?>[null, '2m', '70cm', '1.25m', '23cm', '6m'];

  /// 常用 APRS 频率（MHz），供界面一键填入；**用户仍可手改任意值**。
  ///
  /// 依次为 VHF 上各地常用的 APRS 信道：中国 144.640、欧洲 144.800、
  /// 北美 144.390、国际空间站 145.825。
  /// 之所以只做「预设」而不做固定下拉：APRS 频率随地区/中继而异，
  /// 写死列表一定会漏掉某些地区，所以预设只当快捷方式。
  static const freqPresets = <String>['144.640', '144.800', '144.390', '145.825'];

  /// 规范化用户输入的频率（**MHz**）。返回 `null` = 格式无效。
  ///
  /// 宽容处理三件事（用户常直接从频率表复制粘贴）：
  /// - 去掉首尾空白
  /// - 去掉误粘的单位后缀 `MHz`
  /// - 把欧式逗号小数（`144,640`）改成点
  ///
  /// **为什么必须把逗号改成点**：ADIF 规定小数分隔符是 `.`，
  /// 与操作系统语言环境无关。若原样写 `<FREQ:7>144,640`，
  /// 欧/法语区的日志软件会当成非法数字或解析错位。
  static String? normalizeFreq(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    // 注意：Dart 的 RegExp 是 ECMAScript 语法，**不支持 `(?i)` 内联标志**
    // （写 `(?i)` 会直接抛 FormatException: Invalid group）——
    // 大小写不敏感必须用 caseSensitive 参数。
    s = s.replaceAll(RegExp(r'\s*mhz$', caseSensitive: false), '').trim();
    s = s.replaceAll(',', '.');
    // 只接受十进制正数（必须有前导数字，避免 `.5` 这类歧义写法）
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(s)) return null;
    final v = double.tryParse(s);
    if (v == null || v <= 0 || v > 30000) return null;
    return s;
  }

  /// 去掉呼号尾部的 `-SSID`：`BG7PGW-2` → `BG7PGW`（无 SSID 时原样返回）
  static String stripSsid(String call) {
    final c = call.trim();
    final i = c.indexOf('-');
    return i <= 0 ? c : c.substring(0, i);
  }

  /// 生成 ADIF 文本。
  ///
  /// [created] 为生成时间（头部 CREATED_TIMESTAMP），默认取当前时间。
  static String encode(
    List<AdifRecord> records, {
    AdifOptions options = const AdifOptions(),
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
      b.write(record(r, options));
    }
    return b.toString();
  }

  /// 单条记录的文本（供导出拼装，也供界面「预览」直接复用，
  /// 保证预览与实际写出的内容**必然一致**）。
  static String record(AdifRecord r, AdifOptions options) {
    final t = r.timeOn.toUtc();
    final call = r.call.trim().toUpperCase();
    final b = StringBuffer()
      ..write(_field('CALL', options.stripSsid ? stripSsid(call) : call))
      ..write(_field('QSO_DATE', dateOf(t)))
      ..write(_field('TIME_ON', timeOf(t)));
    // MODE 是多数日志软件的必需字段；SUBMODE 必须依附于 MODE
    if (options.mode != null) {
      b.write(_field('MODE', options.mode!));
      if (options.subModeAprs) b.write(_field('SUBMODE', 'APRS'));
    }
    if (options.band != null) b.write(_field('BAND', options.band!));
    // FREQ 是数值型，单位 MHz（小数分隔符固定用 `.`，见 normalizeFreq）
    if (options.freq != null) b.write(_field('FREQ', options.freq!));
    b
      ..write('<EOR>')
      ..write('\n');
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
