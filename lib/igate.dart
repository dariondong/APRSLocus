/// ─── iGate（网关）：射频 ↔ APRS-IS 之间的报文转递 ───
///
/// ## 什么是 iGate
///
/// 把射频上收到的报文送上 APRS-IS（**RF→IS**），以及把 APRS-IS 上发给
/// 「本地刚刚听到过的电台」的消息送到射频（**IS→RF**）。前者让手台覆盖
/// 范围之外的报文进入互联网，后者让互联网上的消息能叫到只在上电台的台站。
///
/// ## 为什么这一段必须单独成文件、且必须是纯函数
///
/// iGate 有两类**会互相伤害**的错误，而且都不会立刻暴露：
///
///   ① **环路**：把从 APRS-IS 收到的报文又送回 APRS-IS → 同一条报文在
///      互联网上无限增殖。判据是报文里的 **q 构造**（`qAR`/`qAC`/`qAZ`…）
///      与 `TCPIP*`/`TCPXX*` 路径项 —— 这些只可能来自互联网，出现过就绝不
///      能再往 IS 送。
///   ② **重复注入**：同一帧会经不同中继路径多次到达（甚至同一网关的多个
///      接收机各收到一次）。没有去重，IS 上会出现多条一模一样的报文，
///      看起来像「网关在刷屏」。
///
/// 判据一多，靠「在收包函数里加几个 if」必然会漏；所以这里做成纯函数 +
/// 单元测试（`test/igate_test.dart`），收包侧只负责调用。
///
/// ## q 构造（APRS-IS 规范）
///
/// 网关在转递时必须在路径里插入自己的呼号与 q 构造：
///   * `qAr` —— 单向网关（只 RF→IS）
///   * `qAR` —— 双向网关（RF→IS + IS→RF）
/// 大小写**有意义**，不能混用：它告诉服务器「这条报文的来路与网关能力」。
library;

/// 转递判定结果
class GateDecision {
  /// 是否应当转递
  final bool ok;

  /// 放行原因 / 拒绝原因（拒绝原因用于日志与排查）
  final String reason;

  const GateDecision(this.ok, this.reason);

  static const GateDecision allow = GateDecision(true, 'ok');
}

class Igate {
  Igate._();

  /// 射频上允许的中继地址上限（AX.25 地址字段最多 8 个，含源与目的）
  static const int maxRfDigis = 8;

  /// 去重窗口：同一帧经多路径到达的时间跨度。取 30s 足够覆盖同一次发射
  /// 经不同中继先后到达的情况，又不会把两次真实发射误判为重复。
  static const Duration dedupeWindow = Duration(seconds: 30);

  // ─── RF → IS ───

  /// 判断一条**来自射频**的报文是否应当送到 APRS-IS。
  ///
  /// 拒绝的情形：
  ///   * 报头里已有 `TCPIP*` / `TCPXX*` —— 它本来就从互联网来（说明配了
  ///     双向网关或有人在 RF 上伪造），再送回去就是环路；
  ///   * 报头里已有 q 构造 —— 同上，已进过 IS；
  ///   * 报文源呼号就是本网关自己 —— 自己发的信标没必要再由自己转一遍；
  ///   * 报文体为空。
  static GateDecision toIs({
    required String tnc2,
    required String myFullCall,
  }) {
    final line = tnc2.trim();
    final gt = line.indexOf('>');
    final colon = line.indexOf(':');
    if (gt <= 0 || colon <= gt) return const GateDecision(false, 'malformed');
    final src = line.substring(0, gt).trim().toUpperCase();
    final header = line.substring(gt + 1, colon).toUpperCase();
    final body = line.substring(colon + 1);
    if (body.trim().isEmpty) return const GateDecision(false, 'empty-body');
    if (src.isEmpty) return const GateDecision(false, 'malformed');
    // 目的呼号不能为空：`A>:x` 这种报文送进 IS 只会是垃圾
    if (header.split(',').first.trim().isEmpty) {
      return const GateDecision(false, 'malformed');
    }
    if (src == myFullCall.toUpperCase()) {
      return const GateDecision(false, 'own-packet');
    }
    final parts = header.split(',');
    for (final p in parts) {
      final u = p.trim().toUpperCase().replaceAll('*', '');
      // 互联网来路标记
      if (u.startsWith('TCPIP') || u.startsWith('TCPXX')) {
        return const GateDecision(false, 'from-is');
      }
      // q 构造（qAC/qAR/qAZ/qAS...）：已由某个网关注入过
      if (u.length >= 3 && u.startsWith('Q') && _isQConstruct(u)) {
        return const GateDecision(false, 'has-q-construct');
      }
    }
    return GateDecision.allow;
  }

  /// 从路径段里挑出**真正的中继地址**，丢掉互联网专有项。
  ///
  /// 这里有个容易漏的细节：q 构造后面紧跟的那个 token 是**网关呼号**
  /// （`qAC,SERVER` 里的 SERVER），不是中继。只丢 q 构造本身会把网关呼号
  /// 当成中继留下来 —— IS 上的报文就凭空多出一个不存在的 digipeater。
  /// 所以遇到 q 构造要连带吃掉下一个 token。
  static List<String> rfDigisOf(
    List<String> parts, {
    int max = maxRfDigis,
  }) {
    final out = <String>[];
    var skipNext = false;
    for (final raw in parts.skip(1)) {
      final u = raw.trim().toUpperCase().replaceAll('*', '');
      if (u.isEmpty) continue;
      if (skipNext) {
        skipNext = false; // 这是 q 构造附带的网关呼号，丢弃
        continue;
      }
      if (u.startsWith('TCPIP') || u.startsWith('TCPXX')) continue;
      if (u.startsWith('Q') && _isQConstruct(u)) {
        skipNext = true; // 下一项是网关呼号
        continue;
      }
      out.add(raw.replaceAll('*', '').trim());
      if (out.length >= max) break;
    }
    return out;
  }

  /// q 构造形如 `qAR` / `qAC` / `qAZ` / `qAo`，第 3 位是 A-Z/a-o
  static bool _isQConstruct(String upper) {
    if (upper.length < 3) return false;
    if (upper[0] != 'Q') return false;
    final c = upper[2];
    return (c.codeUnitAt(0) >= 0x41 && c.codeUnitAt(0) <= 0x5A) || c == 'O';
  }

  /// 把射频报文改写成可发往 APRS-IS 的整行。
  ///
  /// 变换（顺序有意义）：
  ///   ① 去掉中继地址上的 `*`（`*` 表示「这一跳是被本机听到的」，是**本地
  ///      观察结果**，不属于报文本身，带上会污染 IS 上的路径信息）；
  ///   ② 丢掉 `TCPIP*`/`TCPXX*`（保险，正常已被 [toIs] 拦下）；
  ///   ③ 追加 `qA(r|R),本网关呼号`；
  ///   ④ 中继数量截到 AX.25 上限。
  ///
  /// [twoWay] 为 true 时用 `qAR`（双向网关），否则 `qAr`（单向）。
  static String? toIsLine({
    required String tnc2,
    required String myFullCall,
    required bool twoWay,
  }) {
    final line = tnc2.trim();
    final gt = line.indexOf('>');
    final colon = line.indexOf(':');
    if (gt <= 0 || colon <= gt) return null;
    final src = line.substring(0, gt).trim().toUpperCase();
    final header = line.substring(gt + 1, colon);
    final body = line.substring(colon + 1);

    final parts = header
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    final dest = parts.first;
    if (dest.isEmpty) return null;
    final digis = rfDigisOf(parts);
    final q = twoWay ? 'qAR' : 'qAr';
    final path = [dest, ...digis, q, myFullCall.toUpperCase()].join(',');
    return '$src>$path:$body';
  }

  // ─── IS → RF ───

  /// APRS 消息体的收件人字段（`:` 后 9 字符，空格补齐）
  static String? messageAddressee(String body) {
    if (!body.startsWith(':')) return null;
    final rest = body.substring(1);
    final colon = rest.indexOf(':');
    if (colon < 0) return null;
    final to = rest.substring(0, colon).trim();
    return to.isEmpty ? null : to.toUpperCase();
  }

  /// 判断一条**来自 APRS-IS** 的报文是否应当送到射频。
  ///
  /// 只转**消息**，且收件人必须在 [heardOnRf] 里（近期在射频上听到过的
  /// 台站）。这是通行的做法，理由：
  ///   * 位置/天气这类广播报文在射频上占大量时隙，且本地台站本来就能直接
  ///     收到，转发只会增加信道占用（这也是多数 iGate 被投诉的原因）；
  ///   * 消息是**点对点**的：只有收件人自己在等它，转发价值最高，
  ///     而且不转就彻底丢了（只在上电台的台站收不到互联网消息）。
  static GateDecision toRf({
    required String tnc2,
    required Set<String> heardOnRf,
    required String myFullCall,
    required bool allowMessages,
  }) {
    if (!allowMessages) return const GateDecision(false, 'is-to-rf-off');
    final line = tnc2.trim();
    final gt = line.indexOf('>');
    final colon = line.indexOf(':');
    if (gt <= 0 || colon <= gt) return const GateDecision(false, 'malformed');
    final src = line.substring(0, gt).trim().toUpperCase();
    if (src == myFullCall.toUpperCase()) {
      return const GateDecision(false, 'own-packet');
    }
    final body = line.substring(colon + 1);
    final to = messageAddressee(body);
    if (to == null) return const GateDecision(false, 'not-a-message');
    if (!heardOnRf.contains(to)) {
      return const GateDecision(false, 'addressee-not-heard');
    }
    return GateDecision.allow;
  }

  /// 把 APRS-IS 报文改写成可发射的射频整行。
  ///
  /// 关键是**剥掉所有互联网专有的路径项**（`TCPIP*`、`TCPXX*`、q 构造）——
  /// 它们在射频上是无效中继，不剥掉会被当成中继地址发出去（等于让某台站
  /// 白转发一次），有的 TNC 还会直接拒发。然后接上本机配置的射频中继路径。
  static String? toRfLine({
    required String tnc2,
    required String rfPath,
  }) {
    final line = tnc2.trim();
    final gt = line.indexOf('>');
    final colon = line.indexOf(':');
    if (gt <= 0 || colon <= gt) return null;
    final src = line.substring(0, gt).trim().toUpperCase();
    final header = line.substring(gt + 1, colon);
    final body = line.substring(colon + 1);

    final parts = header
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    final dest = parts.first;
    if (dest.isEmpty) return null;
    final digis = rfDigisOf(parts);
    // 射频中继路径来自本机配置（如 WIDE1-1,WIDE2-1）
    final rf = rfPath
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .where((s) => !s.toUpperCase().startsWith('TCPIP'))
        .toList();
    final path = [dest, ...digis, ...rf].join(',');
    return '$src>$path:$body';
  }

  // ─── 去重 ───

  /// 转递去重缓存：`源呼号|信息字段` → 首次见到的时间。
  ///
  /// 用**信息字段**而不是整行做键：同一帧经不同中继到达时，路径不同
  /// （中继个数与 `*` 位置都会变），但信息字段一定相同。
  static String dedupeKey(String tnc2) {
    final line = tnc2.trim();
    final gt = line.indexOf('>');
    final colon = line.indexOf(':');
    if (gt <= 0 || colon <= gt) return line.toUpperCase();
    final src = line.substring(0, gt).trim().toUpperCase();
    final body = line.substring(colon + 1).trim().toUpperCase();
    return '$src|$body';
  }
}

/// 带过期清理的去重集合（纯逻辑，便于测试）
class GateDedupe {
  /// 触发清理的条目阈值。
  ///
  /// 刻意不做成「每次插入都全表扫描」：正常运行时条目数远小于此值，
  /// 全表扫描是白白浪费；超过阈值再做一次整体清理，内存占用**有界**
  /// （上界约为 [maxEntries] + 1 条）。
  static const int maxEntries = 512;

  final Map<String, DateTime> _seen = {};

  /// 记录一条；返回 true 表示「是新的，应当处理」。
  ///
  /// [now] 可注入，便于测试时间窗口。
  bool accept(String key, {required Duration window, DateTime? now}) {
    final t = now ?? DateTime.now();
    final last = _seen[key];
    if (last != null && t.difference(last) < window) return false;
    _seen[key] = t;
    // 顺手清理过期项，避免长时间运行后无限增长
    if (_seen.length > maxEntries) {
      _seen.removeWhere((_, v) => t.difference(v) >= window);
    }
    return true;
  }

  int get size => _seen.length;

  void clear() => _seen.clear();
}

/// 射频「听到过」的台站列表（IS→RF 消息转递的依据）
class HeardList {
  HeardList({this.ttl = const Duration(hours: 1)});

  /// 记忆时长：超过则不再认为该台站还在射频上（它可能已经走远了）
  final Duration ttl;
  final Map<String, DateTime> _last = {};

  void heard(String call, {DateTime? now}) {
    final c = call.trim().toUpperCase();
    if (c.isEmpty) return;
    _last[c] = now ?? DateTime.now();
  }

  bool contains(String call, {DateTime? now}) {
    final c = call.trim().toUpperCase();
    final t = _last[c];
    if (t == null) return false;
    return (now ?? DateTime.now()).difference(t) < ttl;
  }

  /// 当前仍在有效期内的台站集合（传给 [Igate.toRf]）
  Set<String> active({DateTime? now}) {
    final t = now ?? DateTime.now();
    return _last.entries
        .where((e) => t.difference(e.value) < ttl)
        .map((e) => e.key)
        .toSet();
  }

  int get size => _last.length;

  void clear() => _last.clear();
}
