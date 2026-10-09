/// ─── 策略地图协议（APRS 消息上的自订应用层）───
///
/// 需求：和同群队友在地图上共享**标点 / 划线 / 画圈 / 集合点**，数据走 APRS msg。
///
/// 与 [GroupProto] 同一套思路：协议判定**只做一次**（[StrategyProto.parse]），
/// 产出结构化 [StrategyFrame]，调用方按 `op` 分派；取值一律走「切词」而不是
/// 「数字符」。
///
/// ## 帧格式（尽量短 —— 每个字节都是射频时隙）
///
/// ```
/// $M<版本> <OP> <ID> <载荷...>
/// ```
///
/// * 前缀 `$M` 表明是策略帧，`GroupProto` 不会误认（它以 `INVITE`/`【JOIN】`
///   等开头）；`$` 也**不是** APRS 消息体内的保留字符。
/// * `<OP>`：`P` 标点 / `L` 划线 / `C` 圈 / `R` 集合点 / `D` 删除 / `X` 清空 /
///   `S` 请求全量快照。
/// * `<ID>`：元素 ID，由创建者保证全网一致，便于后续更新/删除引用它。
/// * 划线较长时自动分片：`L <ID> <i>/<n> <点串>`，接收端收齐才落图。
///
/// ## 为什么处处以 67 字符为上限
///
/// APRS101 规定消息文本上限 67 字符（`AppState.tncMaxMsgLen`），射频下超长
/// 会被对端 TNC/网关**静默丢弃**。这里让编码器**默认就按 ≤67 输出**（超长的
/// 线自动分片），于是同一份代码在 APRS-IS 与射频上都能用，不必让调用方
/// 分别处理两种长度。
library;

import 'dart:ui' show Color;

/// 策略元素类型
enum StrategyKind { point, line, circle, rally }

/// 一个策略元素（设备上的真源副本）。
class StrategyItem {
  /// 稳定 ID（见 [StrategyProto.makeId]）
  final String id;

  final StrategyKind kind;

  /// 创建者呼号（大写）
  final String owner;

  /// 所属群呼号（大写）
  final String groupCall;

  /// 最后修改时间（毫秒）。冲突消解用「后写胜」。
  final int updatedAt;

  /// 点 / 集合点 / 圈的锚点；划线的首点也放这里便于排序与居中
  final double lat, lng;

  /// 圈半径（米），仅 [StrategyKind.circle] 用
  final int radiusM;

  /// 划线路径，仅 [StrategyKind.line] 用
  final List<(double, double)> path;

  /// 显示名（≤ [StrategyProto.maxLabelLen] 字符，可为空）
  final String label;

  /// 颜色索引（[StrategyProto.palette] 下标），仅线/圈用；-1 表示用默认色。
  ///
  /// 只传索引不传 RGB：每帧只剩 2 个字符预算，而调色板全网一致 ——
  /// 传索引既能表达「我选的这个颜色」，又不会把帧撑爆。
  final int colorIndex;

  const StrategyItem({
    required this.id,
    required this.kind,
    required this.owner,
    required this.groupCall,
    required this.updatedAt,
    required this.lat,
    required this.lng,
    this.radiusM = 0,
    this.path = const [],
    this.label = '',
    this.colorIndex = -1,
  });

  /// 归属键：跨群同名 ID 不冲突
  String get key => '$groupCall|$id';

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.index,
    'owner': owner,
    'groupCall': groupCall,
    'updatedAt': updatedAt,
    'lat': lat,
    'lng': lng,
    if (radiusM > 0) 'radiusM': radiusM,
    if (path.isNotEmpty)
      'path': path.map((p) => [p.$1, p.$2]).toList(),
    if (label.isNotEmpty) 'label': label,
    if (colorIndex >= 0) 'colorIndex': colorIndex,
  };

  factory StrategyItem.fromJson(Map<String, dynamic> j) {
    final rawPath = (j['path'] as List?) ?? const [];
    return StrategyItem(
      id: j['id'] as String,
      kind: StrategyKind.values[j['kind'] as int],
      owner: (j['owner'] as String).toUpperCase(),
      groupCall: (j['groupCall'] as String).toUpperCase(),
      updatedAt: j['updatedAt'] as int,
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      radiusM: (j['radiusM'] as num?)?.toInt() ?? 0,
      path: rawPath
          .map(
            (p) => (
              ((p as List)[0] as num).toDouble(),
              ((p as List)[1] as num).toDouble(),
            ),
          )
          .toList(),
      label: j['label'] as String? ?? '',
      colorIndex: (j['colorIndex'] as num?)?.toInt() ?? -1,
    );
  }

  /// 实际颜色（线/圈）。
  ///
  /// 放在模型层而不是 UI 层：编码/解码与绘制必须用**同一张**调色板，
  /// 否则「我选红色、对面看到蓝色」—— 分开写两张必然漂。
  Color get color => StrategyProto.colorAt(colorIndex);
}

/// 解析后的一帧（结构化，调用方不再碰字符串）。
///
/// 一条消息可能只是某条划线的一个分片，故带 [partIndex]/[partTotal]。
class StrategyFrame {
  /// 操作码，取自 [StrategyProto.ops]
  final String op;

  /// 元素 ID；`X`/`S` 无 ID 时为空
  final String id;

  final double lat, lng;
  final int radiusM;
  final List<(double, double)> path;
  final String label;

  /// 颜色索引（仅 L/C 用）；-1 表示未指定
  final int colorIndex;

  /// 分片序号（从 1 起）与总数；非分片为 1/1
  final int partIndex, partTotal;

  const StrategyFrame({
    required this.op,
    this.id = '',
    this.lat = 0,
    this.lng = 0,
    this.radiusM = 0,
    this.path = const [],
    this.label = '',
    this.colorIndex = -1,
    this.partIndex = 1,
    this.partTotal = 1,
  });

  StrategyKind? get kind => switch (op) {
    'P' => StrategyKind.point,
    'L' => StrategyKind.line,
    'C' => StrategyKind.circle,
    'R' => StrategyKind.rally,
    _ => null,
  };
}

/// 策略地图协议编解码 + 校验
class StrategyProto {
  StrategyProto._();

  /// 协议版本。解析到未知版本直接丢弃（未来格式演进不会让老客户端崩）。
  static const String version = '1';

  /// 消息体上限（APRS101）。与 `AppState.tncMaxMsgLen` 保持一致。
  static const int maxFrameLen = 67;

  /// 标签最大字符数（UTF-8 下每个中文占 3 字节，太长会顶爆帧预算）
  static const int maxLabelLen = 8;

  /// 圈半径上限（米）。超过视为误发。
  static const int maxRadiusM = 50000;

  /// 一条线最多分片数（防止有人构造超长路径刷屏）。
  /// 每片约 2 个点，40 片 ≈ 80 点，够画常规路线，又不至于一发几十条消息。
  static const int maxParts = 40;

  static const List<String> ops = ['P', 'L', 'C', 'R', 'D', 'X', 'S'];

  /// 线/圈可选颜色（全网固定，帧里只传下标）。
  ///
  /// 六个高对比色，压在卫星/路网底图上都能分辨；顺序即协议（改顺序等于改协议，
  /// 会让老客户端颜色错位）—— 新色只能往末尾加，不能插入/重排。
  static const List<Color> palette = [
    Color(0xFFE53935), // 0 红（默认）
    Color(0xFF1E88E5), // 1 蓝
    Color(0xFF43A047), // 2 绿
    Color(0xFFFB8C00), // 3 橙
    Color(0xFF8E24AA), // 4 紫
    Color(0xFF00ACC1), // 5 青
  ];

  /// 颜色下标 → 颜色；越界/未指定回落到调色板首色（红）。
  static Color colorAt(int index) =>
      index >= 0 && index < palette.length ? palette[index] : palette.first;

  static int _normColorIndex(int index) =>
      index >= 0 && index < palette.length ? index : -1;

  /// 元素 ID 生成：`<呼号后2~3位><序号>`，总长 ≤6，全网一致、够短。
  ///
  /// 呼号去掉 `-SSID` 后取**末尾 3 位**：中国呼号（BG7LZQ / BD4TYW）末 3 位
  /// 通常已能区分同群成员，且比整串省字节。
  static String makeId(String call, int seq) {
    final base = call.toUpperCase().replaceAll(RegExp(r'-\w+$'), '');
    final tail = base.length <= 3 ? base : base.substring(base.length - 3);
    return '$tail$seq';
  }

  /// ID 合法性：字母数字，≤6
  static bool validId(String id) =>
      id.isNotEmpty &&
      id.length <= 6 &&
      RegExp(r'^[A-Za-z0-9]+$').hasMatch(id);

  // ─── 编码 ───

  static String _fmtCoord(double v) => v.toStringAsFixed(5);

  /// 把元素编码成一到多帧（划线超长时自动分片）。
  ///
  /// 每一帧都保证 ≤ [maxFrameLen]；若单点都无法容纳（极端情况）则返回空列表，
  /// 由调用方提示「该元素过长，未发送」。
  static List<String> encode(StrategyItem it) {
    final head = '\$M$version ${_opOf(it.kind)} ${it.id}';
    switch (it.kind) {
      case StrategyKind.point:
      case StrategyKind.rally:
        final p = '${_fmtCoord(it.lat)},${_fmtCoord(it.lng)}';
        final label = _normLabel(it.label);
        final a = label.isEmpty ? '$head $p' : '$head $p $label';
        if (a.length <= maxFrameLen) return [a];
        // 退一步：只发坐标，丢标签（有图有点，信息优先）
        final b = '$head $p';
        return b.length <= maxFrameLen ? [b] : const [];
      case StrategyKind.circle:
        final ci = _normColorIndex(it.colorIndex);
        // 颜色只占 2 字符（`,<idx>`），与半径同段，解析时不增加 token 数
        final core =
            '${_fmtCoord(it.lat)},${_fmtCoord(it.lng)},${it.radiusM}'
            '${ci >= 0 ? ',$ci' : ''}';
        final label = _normLabel(it.label);
        final a = label.isEmpty ? '$head $core' : '$head $core $label';
        if (a.length <= maxFrameLen) return [a];
        final b = '$head $core';
        return b.length <= maxFrameLen ? [b] : const [];
      case StrategyKind.line:
        return _encodeLine(head, it.path, _normColorIndex(it.colorIndex));
    }
  }

  static String _opOf(StrategyKind k) => switch (k) {
    StrategyKind.point => 'P',
    StrategyKind.line => 'L',
    StrategyKind.circle => 'C',
    StrategyKind.rally => 'R',
  };

  static String _normLabel(String s) {
    var t = s.replaceAll(RegExp(r'[\r\n:]'), ' ').trim();
    if (t.runes.length > maxLabelLen) {
      t = String.fromCharCodes(t.runes.take(maxLabelLen));
    }
    return t;
  }

  /// 划线分片：贪心地把点塞进每帧，直到放不下再开下一片。
  ///
  /// 先按「一片也放不下额外一个点」的最小粒度切，再给每片补上 `<i>/<n>` 前缀
  /// 重新校验长度 —— 前缀长度固定（约 6 字符），所以补完不会溢出。
  static List<String> _encodeLine(
    String head,
    List<(double, double)> path,
    int colorIndex,
  ) {
    if (path.isEmpty) return const [];
    // 颜色段只写一次：跟在 ID 之后（`$M1 L <ID> <ci> …`），比每片都写更省；
    // 单点线与多片线共用这一步，两种形态的颜色必须一致。
    final h = colorIndex >= 0 ? '$head $colorIndex' : head;
    // 单点线退化为点
    if (path.length == 1) {
      final f = '$h ${_fmtCoord(path[0].$1)},${_fmtCoord(path[0].$2)}';
      return f.length <= maxFrameLen ? [f] : const [];
    }
    final coords = path
        .map((p) => '${_fmtCoord(p.$1)},${_fmtCoord(p.$2)}')
        .toList();

    // 先试单帧：能一帧发完就别分片（省时隙）
    final one = '$h ${coords.join(';')}';
    if (one.length <= maxFrameLen) return [one];

    // 预算：head + ' ' + 'i/n' + ' ' + 点串。分片前缀最长按 2 位算 → 8 字符。
    final budget = maxFrameLen - h.length - 1 - 8;
    final chunks = <List<String>>[];
    var cur = <String>[];
    var curLen = 0;
    for (final c in coords) {
      final add = (cur.isEmpty ? 0 : 1) + c.length; // 分隔符 ;
      if (cur.isNotEmpty && curLen + add > budget) {
        chunks.add(cur);
        cur = <String>[];
        curLen = 0;
      }
      if (cur.isNotEmpty) curLen += 1;
      cur.add(c);
      curLen += c.length;
    }
    if (cur.isNotEmpty) chunks.add(cur);

    if (chunks.length > maxParts) return const [];
    final out = <String>[];
    for (var i = 0; i < chunks.length; i++) {
      final frame =
          '$h ${i + 1}/${chunks.length} ${chunks[i].join(';')}';
      if (frame.length > maxFrameLen) return const []; // 兜底：宁可不发也不发坏的
      out.add(frame);
    }
    return out;
  }

  // ─── 解析 ───

  /// 把一条 APRS 消息文本解析成策略帧；不是策略帧时返回 null。
  /// 这是策略判定的**唯一入口**。
  static StrategyFrame? parse(String raw) {
    final text = raw.trim();
    if (!text.startsWith('\$M')) return null;
    final parts = text.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final tag = parts[0]; // $M1
    if (tag.length < 3 || tag.substring(2) != version) return null;
    final op = parts[1].toUpperCase();
    if (!ops.contains(op)) return null;
    final rest = parts.skip(2).toList();

    // X / S：无参数
    if (op == 'X' || op == 'S') return StrategyFrame(op: op);

    if (rest.isEmpty) return null;
    final id = rest[0].toUpperCase();
    if (!validId(id)) return null;
    final payload = rest.skip(1).toList();

    switch (op) {
      case 'D':
        return StrategyFrame(op: op, id: id);
      case 'P':
      case 'R':
        if (payload.isEmpty) return null;
        final ll = _parseLatLng(payload[0]);
        if (ll == null) return null;
        return StrategyFrame(
          op: op,
          id: id,
          lat: ll.$1,
          lng: ll.$2,
          label: _joinLabel(payload, 1),
        );
      case 'C':
        if (payload.isEmpty) return null;
        final segs = payload[0].split(',');
        if (segs.length < 3) return null;
        final lat = double.tryParse(segs[0]);
        final lng = double.tryParse(segs[1]);
        final r = int.tryParse(segs[2]);
        if (lat == null || lng == null || r == null) return null;
        // 第 4 段是可选颜色下标（`lat,lng,r[,ci]`），老客户端不带
        final ci = segs.length >= 4 ? (int.tryParse(segs[3]) ?? -1) : -1;
        if (!_inRange(lat, lng) || r <= 0 || r > maxRadiusM) return null;
        return StrategyFrame(
          op: op,
          id: id,
          lat: lat,
          lng: lng,
          radiusM: r,
          label: _joinLabel(payload, 1),
          colorIndex: _normColorIndex(ci),
        );
      case 'L':
        if (payload.isEmpty) return null;
        var rest = payload;
        // 可选颜色 token：ID 之后紧跟一个**纯数字**（点串必含 `.`/`,`，
        // `<i>/<n>` 必含 `/`，所以纯数字只能是我们写的颜色下标）
        var ci = -1;
        if (RegExp(r'^\d$').hasMatch(rest[0])) {
          ci = int.tryParse(rest[0]) ?? -1;
          rest = rest.skip(1).toList();
          if (rest.isEmpty) return null;
        }
        var idx = 1, total = 1, ptsToken = rest[0];
        // 分片写法：`<i>/<n>` 作为独立 token
        final slash = rest[0].split('/');
        if (slash.length == 2) {
          final i = int.tryParse(slash[0]);
          final n = int.tryParse(slash[1]);
          if (i != null && n != null && i >= 1 && n >= 1 && i <= n) {
            idx = i;
            total = n;
            if (rest.length < 2) return null;
            ptsToken = rest[1];
          }
        }
        if (total > maxParts) return null;
        final pts = <(double, double)>[];
        for (final s in ptsToken.split(';')) {
          final ll = _parseLatLng(s);
          if (ll == null) return null;
          pts.add(ll);
        }
        if (pts.isEmpty) return null;
        return StrategyFrame(
          op: op,
          id: id,
          path: pts,
          colorIndex: _normColorIndex(ci),
          partIndex: idx,
          partTotal: total,
        );
      default:
        return null;
    }
  }

  static (double, double)? _parseLatLng(String s) {
    final segs = s.split(',');
    if (segs.length != 2) return null;
    final lat = double.tryParse(segs[0]);
    final lng = double.tryParse(segs[1]);
    if (lat == null || lng == null) return null;
    if (!_inRange(lat, lng)) return null;
    return (lat, lng);
  }

  static bool _inRange(double lat, double lng) =>
      lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

  static String _joinLabel(List<String> tokens, int from) =>
      from >= tokens.length ? '' : _normLabel(tokens.skip(from).join(' '));
}
