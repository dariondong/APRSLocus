import 'models.dart';
import 'satellite.dart';

/// ─── On-Air Friends：把「现在守着哪个频点」写进信标备注 ───
///
/// 这一层只做**纯逻辑**（编码 / 解析 / 归一 / 挑出在线友台），不碰界面也不碰
/// AppState —— 解析规则是发送端与接收端**同一份**，一旦进了界面就会有人
/// 「顺手」只改一边，于是自己的包读不出来。
///
/// 为什么不用某个现成字段：APRS101 没有「守听频率」这个标准位置字段，
/// 中继台是把频点写在备注里（`439.75500MHz -5.0000MHz`），那是自由文本、
/// 无法可靠解析。这里用一个带前缀的短标记，写在我们自己信标备注的**最后**：
///
///     OAF:145.500:FM          守听 145.500、模式 FM
///     OAF:145.500:FM:GP 5W    末尾可以再带一段附加参数（自由文本）
///
/// 前缀取了 `OAF:`（On-Air Friends 的首字母），一眼能认出是谁写的；
/// 收端只在**整段**都解析得通时才认（见 [OnAirInfo.decode]），所以一条恰好
/// 含 `OAF:` 的普通备注不会被误当成在线友台。
class OnAirInfo {
  /// 频率，MHz、三位小数（`145.500`）。空串 = 没设置。
  final String freq;

  /// 模式（`FM` / `USB` / `C4FM` …）。空串按 `FM` 处理。
  final String mode;

  /// 附加参数（天线、功率、CTCSS…）。可空。
  final String extra;

  const OnAirInfo({required this.freq, this.mode = 'FM', this.extra = ''});

  /// 信标备注里的标记前缀。
  static const String mark = 'OAF:';

  /// 附加参数最多带多少字符：备注整段是有长度上限的（APRS101 的 43 字节说法
  /// 指的是标准信息域），而这一项是「顺手补一句」，不该把电量、心率这些
  /// 真正有用的字段挤掉。
  static const int extraMax = 24;

  bool get configured => freq.isNotEmpty;

  /// 一行读数：`145.500 FM`，有附加参数时 `145.500 FM · GP 5W`。
  String get label {
    if (!configured) return '';
    final m = mode.isEmpty ? 'FM' : mode;
    if (extra.isEmpty) return '$freq $m';
    return '$freq $m · $extra';
  }

  /// 编码成信标备注里的那一段。没填频率时是空串（= 什么都不写）。
  String encode() {
    if (!configured) return '';
    final m = mode.isEmpty ? 'FM' : mode;
    final e = extra.length > extraMax ? extra.substring(0, extraMax) : extra;
    final tail = e.isEmpty ? '' : ':$e';
    return '$mark$freq:$m$tail';
  }

  /// 从一条备注里解析出来；没有、或格式不对，返回 null。
  static OnAirInfo? decode(String? comment) {
    if (comment == null) return null;
    final i = comment.indexOf(mark);
    if (i < 0) return null;
    final rest = comment.substring(i + mark.length);
    if (rest.isEmpty) return null;
    // 频率 / 模式 / 其余全部当附加参数（附加参数里可以有冒号，所以只切两刀）。
    final first = rest.indexOf(':');
    if (first <= 0) return null;
    final freq = normalizeOnAirFreq(rest.substring(0, first));
    if (freq.isEmpty) return null;
    final afterFreq = rest.substring(first + 1);
    final second = afterFreq.indexOf(':');
    final modeRaw = (second < 0 ? afterFreq : afterFreq.substring(0, second))
        .trim();
    final extraRaw = second < 0 ? '' : afterFreq.substring(second + 1).trim();
    if (!_modeRe.hasMatch(modeRaw)) return null;
    return OnAirInfo(
      freq: freq,
      mode: modeRaw.toUpperCase(),
      extra: extraRaw.length > extraMax ? extraRaw.substring(0, extraMax) : extraRaw,
    );
  }

  /// 模式只认「字母数字 + 斜杠 + 点 + 加号」，长度 1~8。认出别的就不是我们的标记。
  static final RegExp _modeRe = RegExp(r'^[A-Za-z0-9/+.]{1,8}$');

  @override
  bool operator ==(Object other) =>
      other is OnAirInfo &&
      other.freq == freq &&
      other.mode == mode &&
      other.extra == extra;

  @override
  int get hashCode => Object.hash(freq, mode, extra);
}

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
    // 卫星过境单独一段，与 `OAF:` 各读各的（一颗星也可以只声明过境、不守频）。
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
