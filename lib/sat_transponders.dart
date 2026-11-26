/// 内置的常用卫星频点 / 转发器预设。
///
/// 数据是业余卫星的公开常用频率（AMSAT / SatNOGS 口径），只用于**填到界面和
/// 电台**，不参与 APRS 报文解析。卫星转发器会变，发射前以官方频率公告为准。
class SatTransponder {
  /// 卫星名包含这个关键字（大写）就认为适用。
  final String match;

  /// 转发器名称（技术名，跨语言通用）。
  final String name;

  /// 上行 / 下行标称频率（MHz）。
  final double upMhz;
  final double downMhz;

  /// 亚音（'67.0' / '141.3'，没有就是空）。
  final String tone;

  /// 模式说明（FM / AFSK 1200 / LSB/USB）。
  final String mode;

  /// 线性转发器是否倒置（上行 USB 时下行 LSB 之类）。
  final bool invert;

  /// 备注（区域差异、路径等）。
  final String note;

  const SatTransponder({
    required this.match,
    required this.name,
    required this.upMhz,
    required this.downMhz,
    this.tone = '',
    this.mode = 'FM',
    this.invert = false,
    this.note = '',
  });

  bool get isAprs => mode == 'AFSK 1200';
}

const List<SatTransponder> kSatTransponders = [
  // ─── APRS 数传（145.825 同频）───
  SatTransponder(
    match: 'ISS',
    name: 'APRS digipeater',
    upMhz: 145.825,
    downMhz: 145.825,
    mode: 'AFSK 1200',
    note: 'Path ARISS',
  ),
  SatTransponder(
    match: 'ISS',
    name: 'Voice (FM)',
    upMhz: 145.200,
    downMhz: 145.800,
    tone: '67.0',
    note: 'Uplink varies by region (R2 144.490)',
  ),
  SatTransponder(
    match: 'NO-84',
    name: 'APRS digipeater',
    upMhz: 145.825,
    downMhz: 145.825,
    mode: 'AFSK 1200',
  ),
  SatTransponder(
    match: 'PSAT',
    name: 'APRS digipeater',
    upMhz: 145.825,
    downMhz: 145.825,
    mode: 'AFSK 1200',
  ),
  SatTransponder(
    match: 'PCSAT',
    name: 'APRS digipeater',
    upMhz: 145.825,
    downMhz: 145.825,
    mode: 'AFSK 1200',
  ),
  // ─── FM 语音卫星 ───
  SatTransponder(
    match: 'SO-50',
    name: 'FM voice',
    upMhz: 145.850,
    downMhz: 436.795,
    tone: '67.0',
  ),
  SatTransponder(
    match: 'AO-91',
    name: 'FM voice',
    upMhz: 435.250,
    downMhz: 145.960,
    tone: '67.0',
  ),
  SatTransponder(
    match: 'AO-92',
    name: 'FM voice',
    upMhz: 435.350,
    downMhz: 145.880,
    tone: '67.0',
  ),
  SatTransponder(
    match: 'PO-101',
    name: 'FM voice',
    upMhz: 437.500,
    downMhz: 145.900,
    tone: '141.3',
  ),
  SatTransponder(
    match: 'AO-27',
    name: 'FM voice',
    upMhz: 145.850,
    downMhz: 436.795,
  ),
  // ─── 线性转发器（倒置）───
  SatTransponder(
    match: 'CAS-4A',
    name: 'Linear (inverting)',
    upMhz: 435.220,
    downMhz: 145.860,
    mode: 'LSB/USB',
    invert: true,
  ),
  SatTransponder(
    match: 'CAS-4B',
    name: 'Linear (inverting)',
    upMhz: 435.280,
    downMhz: 145.925,
    mode: 'LSB/USB',
    invert: true,
  ),
];

/// 这颗星可用的内置预设（按名字子串匹配）。
List<SatTransponder> transpondersFor(String satName) {
  final n = satName.trim().toUpperCase();
  if (n.isEmpty) return const [];
  return [
    for (final t in kSatTransponders)
      if (n.contains(t.match)) t,
  ];
}
