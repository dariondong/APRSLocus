import 'models.dart';
import 'satellite.dart';

/// ─── On-Air Friends：把「现在守着哪个频点」写进信标备注 ───
///
/// 编码采用 APRS 的 **AFRS（Automatic Frequency Reporting System）/ QSY**
/// 标准位置备注格式（aprs.org/info/freqspec.txt）：
///
///     145.500MHz              守听 145.500
///     145.500MHz FM           再带模式（AFRS 没有模式字段，作为自由文本跟在后面）
///     145.500MHz FM GP 5W     末尾可再带附加参数（天线 / 功率 / T107 +060…）
///
/// 这样 Kenwood / Yaesu 等电台的 TUNE/QSY 键、以及其它 APRS 客户端，都能
/// 直接在备注里找到 `FFF.FFFMHz` 并调到这个频点 —— 不再只有本 App 能读。
///
/// 兼容：旧版本写的私有标记 `OAF:145.500:FM[:extra]` 仍然能解析（见
/// [decode]）；新版本不再产生它。
class OnAirInfo {
  /// 频率，MHz、三位小数（`145.500`）。空串 = 没设置。
  final String freq;

  /// 模式（`FM` / `USB` / `C4FM` …）。空串按 `FM` 处理。
  final String mode;

  /// AFRS 标准音调（`T107` / `t077` / `C023` / `D023`）。空 = 没写。
  final String tone;

  /// AFRS 标准偏移（`+060` / `-500` / `o060`）。空 = 没写。
  final String offset;

  /// 其余自由文本（天线、功率、范围…）。可空。
  final String extra;

  const OnAirInfo({
    required this.freq,
    this.mode = 'FM',
    this.tone = '',
    this.offset = '',
    this.extra = '',
  });

  /// 旧版本（<= 2.2.x）的私有标记，只用于兼容解析。
  static const String legacyMark = 'OAF:';

  /// 附加参数最多带多少字符：备注整段是有长度上限的，而这一项是「顺手补一句」，
  /// 不该把电量、心率这些真正有用的字段挤掉。
  static const int extraMax = 24;

  bool get configured => freq.isNotEmpty;

  /// 一行读数：`145.500 FM · T107 +060 · GP 5W`。
  String get label {
    if (!configured) return '';
    final bits = <String>['$freq ${mode.isEmpty ? 'FM' : mode}'];
    final ctcss = [tone, offset].where((x) => x.isNotEmpty).join(' ');
    if (ctcss.isNotEmpty) bits.add(ctcss);
    if (extra.isNotEmpty) bits.add(extra);
    return bits.join(' · ');
  }

  /// 编码成信标备注里的那一段（AFRS 标准）。
  ///
  /// 频率必须写成 `FFF.FFFMHz`（三位小数、`MHz` 按规范用混合大小写），
  /// 并且要放在自由文本的**最前面** —— 电台的 TUNE/QSY 键只认那个位置。
  /// 标准顺序：频率 → 音调 `Tnnn` → 偏移 `+XXX/-XXX` → 模式 → 其余自由文本。
  /// 没填频率时是空串（= 什么都不写）。
  String encode() {
    if (!configured) return '';
    // 兼容只填了「附加参数」的调用方：把开头的 Tnnn / +XXX 拆出来，
    // 按 AFRS 标准顺序重排（UI 只有一个附加参数框）。
    var t = tone;
    var o = offset;
    var e = extra;
    if (t.isEmpty && o.isEmpty) {
      final split = _splitToneOffset(extra);
      t = split.$1;
      o = split.$2;
      e = split.$3;
    }
    if (e.length > extraMax) e = e.substring(0, extraMax);
    final bits = <String>['${freq}MHz'];
    if (t.isNotEmpty) bits.add(t);
    if (o.isNotEmpty) bits.add(o);
    bits.add(mode.isEmpty ? 'FM' : mode);
    if (e.isNotEmpty) bits.add(e);
    return bits.join(' ');
  }

  /// 从一条备注里解析出来；没有、或格式不对，返回 null。
  ///
  /// 先认旧版的 `OAF:` 私有标记（兼容已经在网上跑的老报文），再认 AFRS
  /// 标准频率段。标准段对其它电台同样有效 —— 他们只要在备注里写了
  /// `146.82 MHz T107 …`，这里就能读出来。
  static OnAirInfo? decode(String? comment) {
    if (comment == null) return null;
    return _decodeLegacy(comment) ?? _decodeAfrs(comment);
  }

  /// 旧格式：`OAF:145.500:FM[:extra]`。
  ///
  /// 两个坑都是现网报文里撞到的（BG7PGW-2 的
  /// `… OAF:438.500:FM OAS:ISS:0548Z`）：
  ///   1. OAF 段后面可能还跟着另一段机器标记（`OAS:` 卫星过境），
  ///      不先切掉它，模式就会读成 `FM OAS`，整条判成格式不对；
  ///   2. 模式后面的分隔可以是空白而不只是冒号，附加参数自己带空格
  ///      （`GP 5W`），所以“词”只能切到第一个冒号或空白。
  static OnAirInfo? _decodeLegacy(String comment) {
    final i = comment.indexOf(legacyMark);
    if (i < 0) return null;
    var rest = comment.substring(i + legacyMark.length);
    final cut = rest.indexOf(SatQso.mark);
    if (cut > 0) rest = rest.substring(0, cut);
    rest = rest.trim();
    if (rest.isEmpty) return null;
    final f = _tokenEnd(rest);
    if (f <= 0) return null;
    final freq = normalizeOnAirFreq(rest.substring(0, f));
    if (freq.isEmpty) return null;
    var after = f < rest.length ? rest.substring(f + 1).trim() : '';
    // 整段都得解析得通才认（见类注释）：只写频率、没写模式的不是我们的标记。
    if (after.isEmpty) return null;
    var modeRaw = '';
    var extraRaw = '';
    if (after.isNotEmpty) {
      final m = _tokenEnd(after);
      modeRaw = after.substring(0, m).trim();
      if (m < after.length) {
        // 后面是 `:` 就跳过去，是空白就留在附加参数里
        extraRaw = after.substring(after[m] == ':' ? m + 1 : m).trim();
      }
    }
    if (modeRaw.isEmpty) return null;
    if (!_modeRe.hasMatch(modeRaw)) return null;
    final split = _splitToneOffset(extraRaw);
    final e = split.$3;
    return OnAirInfo(
      freq: freq,
      mode: modeRaw.toUpperCase(),
      tone: split.$1,
      offset: split.$2,
      extra: e.length > extraMax ? e.substring(0, extraMax) : e,
    );
  }

  /// AFRS 标准：`FFF.FFFMHz`（`MHz` 接收时大小写不敏感，允许 `146.82 MHz`）。
  ///
  /// 频率之后的自由文本里，若第一个词是已知模式（`FM` / `USB` / `C4FM`…）
  /// 就取作模式；否则按 `FM`（这是一条**话音**频率）。`T107` / `+060` 这类
  /// 音调与偏移保留在附加参数里，不吞掉。
  static OnAirInfo? _decodeAfrs(String comment) {
    final m = _afrsRe.firstMatch(comment);
    if (m == null) return null;
    final freq = normalizeOnAirFreq('${m.group(1)}.${m.group(2)}');
    if (freq.isEmpty) return null;
    var rest = comment.substring(m.end).trim();
    // 卫星过境标记（`OAS:ISS:0548Z`）不是频率的附加参数，先切掉
    final satCut = rest.indexOf(SatQso.mark);
    if (satCut > 0) rest = rest.substring(0, satCut).trim();
    // 去掉紧邻的分隔符（`/146.820MHz`、`145.500MHz, FM` 之类）
    rest = rest.replaceFirst(RegExp(r'^[/,:;\-]+'), '').trim();
    // AFRS 标准：频率后面可以跟 `Tnnn`（音调）与 `+XXX`/`-XXX`（偏移）。
    var tone = '';
    var offset = '';
    var tm = RegExp(r'^([TtCcDd]\d{3})(?=\s|$)').firstMatch(rest);
    if (tm != null) {
      tone = tm.group(1)!;
      rest = rest.substring(tm.end).trim();
    }
    var om = RegExp(r'^([+\-oO]\d{3})(?=\s|$)').firstMatch(rest);
    if (om != null) {
      offset = om.group(1)!;
      rest = rest.substring(om.end).trim();
    }
    var mode = '';
    var extra = rest;
    final first = RegExp(r'^([A-Za-z0-9/+.\-]{1,8})').firstMatch(rest);
    if (first != null) {
      final cand = first.group(1)!.toUpperCase();
      if (_knownModes.contains(cand)) {
        mode = cand;
        extra = rest.substring(first.end).trim();
      }
    }
    if (mode.isEmpty) mode = 'FM';
    if (extra.length > extraMax) extra = extra.substring(0, extraMax);
    return OnAirInfo(
      freq: freq,
      mode: mode,
      tone: tone,
      offset: offset,
      extra: extra,
    );
  }

  /// 频率段后面跟的模式词（AFRS 没有模式字段，这是本 App 的自由文本约定）。
  static const Set<String> _knownModes = {
    'FM', 'NFM', 'WFM', 'AM', 'USB', 'LSB', 'SSB', 'CW',
    'C4FM', 'DMR', 'DSTAR', 'D-STAR', 'YSF', 'P25', 'NXDN', 'M17',
    'FT8', 'FT4', 'RTTY', 'PSK31',
  };

  /// AFRS 频率段：`145.500MHz` / `146.82 MHz`；4 位整数也收（1296.000MHz）。
  static final RegExp _afrsRe = RegExp(
    r'(?<![0-9.])(\d{1,4})\.(\d{1,3})\s*MHz',
    caseSensitive: false,
  );

  /// 一段“词”到哪儿结束：第一个冒号或空白。
  static int _tokenEnd(String s) {
    for (var k = 0; k < s.length; k++) {
      final c = s[k];
      if (c == ':' || c == ' ' || c == '\t') return k;
    }
    return s.length;
  }

  /// 模式只认「字母数字 + 斜杠 + 点 + 加号」，长度 1~8。认出别的就不是我们的标记。
  static final RegExp _modeRe = RegExp(r'^[A-Za-z0-9/+.]{1,8}$');
  /// 把自由文本开头的 `T107` / `t077` / `+060` / `-500` 拆出来。
  static (String tone, String offset, String rest) _splitToneOffset(String raw) {
    var s = raw.trim();
    var tone = '';
    var offset = '';
    var m = RegExp(r'^([TtCcDd]\d{3})(?=\s|$)').firstMatch(s);
    if (m != null) {
      tone = m.group(1)!;
      s = s.substring(m.end).trim();
    }
    m = RegExp(r'^([+\-oO]\d{3})(?=\s|$)').firstMatch(s);
    if (m != null) {
      offset = m.group(1)!;
      s = s.substring(m.end).trim();
    }
    return (tone, offset, s);
  }

  @override
  bool operator ==(Object other) =>
      other is OnAirInfo &&
      other.freq == freq &&
      other.mode == mode &&
      other.tone == tone &&
      other.offset == offset &&
      other.extra == extra;

  @override
  int get hashCode => Object.hash(freq, mode, tone, offset, extra);
}

/// 一条收到的标准 QSY APRS 消息（`QSY 145.500MHz?`）。
///
/// 后缀含义（aprs.org/info/freqspec.txt）：
///   * `?` = 自动改频，除非用户按 NO；
///   * `!` = 立即自动改频；
///   * `.` = 只提示，由用户手动 TUNE；
///   * 没有后缀 = 按「只提示」处理。
///
/// 允许消息末尾再带一段自由说明（规范里的 `...`），但频率与后缀必须在开头。
class QsyRequest {
  /// 归一后的频率（`145.500`）。
  final String freq;

  /// `?` / `!` / `.` / 空串。
  final String suffix;

  const QsyRequest(this.freq, this.suffix);

  static QsyRequest? parse(String text) {
    final m = RegExp(
      r'^\s*QSY\s+(\d{1,4}(?:\.\d{1,3})?)\s*(?:MHz)?\s*([?!.]?)(?:\s+.*)?$',
      caseSensitive: false,
    ).firstMatch(text.trim());
    if (m == null) return null;
    final freq = normalizeOnAirFreq(m.group(1)!);
    if (freq.isEmpty) return null;
    return QsyRequest(freq, m.group(2) ?? '');
  }
}

/// 模式能不能写进 `OAF:` 段：字母数字与 `+ / .`，1~8 位。
///
/// 与收端的判据同一份 —— 自己填的模式若不合这条，发出去谁都读不出来。
bool isValidOnAirMode(String mode) =>
    RegExp(r'^[A-Za-z0-9/+.]{1,8}$').hasMatch(mode.trim());

/// 把用户随手填的频率归一成 `145.500`（MHz、三位小数）；填不成返回空串。
///
/// 三种常见写法都收，因为用户不会去想「这里是 MHz 还是 kHz」：
///   * 带小数点：`145.5` / `145.500` → 当 MHz；
///   * 纯数字 1~4 位：`145` → 145.000 MHz；
///   * 纯数字 5~7 位：`145500` → 当 kHz；
///   * 纯数字 8 位以上：`145500000` → 当 Hz。
/// 超出 0.1~6000 MHz 的当填错（返回空串，界面给一句提示），不悄悄改成别的值。
String normalizeOnAirFreq(String raw) {
  var t = raw.trim();
  if (t.isEmpty) return '';
  // 「MHz / kHz / Hz」这类单位后缀：留着只会让 double.tryParse 失败
  // Dart 的 RegExp 是 ECMAScript 语法，不支持 `(?i)` 内联标志（写了会直接抛
  // FormatException: Invalid group），大小写不敏感只能走 caseSensitive。
  t = t.replaceAll(RegExp(r'\s*[mk]?hz$', caseSensitive: false), '').trim();
  double? mhz;
  if (t.contains('.')) {
    mhz = double.tryParse(t);
  } else {
    final n = int.tryParse(t);
    if (n == null) return '';
    if (t.length <= 4) {
      mhz = n.toDouble();
    } else if (t.length <= 7) {
      mhz = n / 1000;
    } else {
      mhz = n / 1000000;
    }
  }
  if (mhz == null || mhz.isNaN || mhz <= 0 || mhz > 6000) return '';
  return mhz.toStringAsFixed(3);
}

/// 一条在线友台：谁、守着什么、最后一次听到是什么时候。
///
/// 直接抱着 [Station] 而不是复制几个字段：呼号、备注、最后时间都是台站自己
/// 的属性，复制一份就会出现「列表里写 145.500、点进去台站详情是旧的」。
class OnAirFriend {
  final Station station;
  final OnAirInfo info;

  /// 这一位声明的卫星过境（备注里的 `OAS:星名:HHMMZ`）；不玩卫星就是 null。
  final SatQso? sat;

  const OnAirFriend(this.station, this.info, {this.sat});

  String get call => station.call;
  DateTime get seen => station.lastHeard;
}

/// 多久没听到就算下线。
///
/// 与「守听」这件事的节奏对齐：信标一般几分钟一帧，30 分钟没一帧基本就是关机
/// 或不在服务区了。再长会让列表里挂着一堆早就走掉的人，再短则网络抖动就掉。
const Duration kOnAirTtl = Duration(minutes: 30);

/// 从台站列表里挑出「开着 On-Air Friends 且没过期」的那些，按最后听到倒序。
///
/// [self] 是本机完整呼号（含 SSID）：自己发的信标也能收回来，但「在线友台」
/// 不该包含自己。
List<OnAirFriend> onAirFriendsOf(
  Iterable<Station> stations, {
  String self = '',
  DateTime? now,
  Duration ttl = kOnAirTtl,
}) {
  final at = now ?? DateTime.now();
  final me = self.trim().toUpperCase();
  final out = <OnAirFriend>[];
  for (final s in stations) {
    if (me.isNotEmpty && s.call.trim().toUpperCase() == me) continue;
    if (at.difference(s.lastHeard) > ttl) continue;
    final info = OnAirInfo.decode(s.comment);
    if (info == null) continue;
    // 卫星过境单独一段，与频率标记各读各的（一颗星也可以只声明过境、不守频）。
    out.add(OnAirFriend(s, info, sat: SatQso.decode(s.comment)));
  }
  out.sort((a, b) => b.seen.compareTo(a.seen));
  return out;
}

/// 列表里出现过的模式（含一次「全部」由界面自己加），按出现次数多的在前。
List<String> onAirModesOf(List<OnAirFriend> friends) {
  final count = <String, int>{};
  for (final f in friends) {
    final m = f.info.mode.isEmpty ? 'FM' : f.info.mode;
    count[m] = (count[m] ?? 0) + 1;
  }
  final modes = count.keys.toList();
  modes.sort((a, b) {
    final d = (count[b] ?? 0).compareTo(count[a] ?? 0);
    return d != 0 ? d : a.compareTo(b);
  });
  return modes;
}
