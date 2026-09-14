/// ─── AFSK 1200（Bell 202）声卡调制解调 + HDLC 帧定界 ───
///
/// 用途：「音频」数据来源的**协议层**。把本应用生成的 APRS 报文（TNC2 文本）
/// 编成 AX.25 → HDLC → NRZI → AFSK 音频（发）；把麦克风/线路输入的音频
/// 解出 AX.25 帧（收）。收到的帧仍交给 `Ax25.decodeToTnc2`（见 kiss.dart）与
/// `AppState._onAprsLine`，因此台站解析、消息、过滤等逻辑与 APRS-IS / TNC
/// 完全共用同一条管线。
///
/// 与 KISS/TNC 的关系：TNC 走「KISS 字节流」，音频走「PCM 采样流」，
/// 但 **HDLC/AX.25 那一层是同一套规范**：
///   * KISS 数据帧的载荷就是 AX.25 帧（含 FCS），由 `kiss.dart` 编解码；
///   * 音频链路的载荷同样是 AX.25 帧 —— 区别只是「字节 → 声音」这一段。
///
/// 参数（APRS 标准，1200bd VHF 分组无线）：
///   * 调制：AFSK，mark = 1200 Hz，space = 2200 Hz（Bell 202），1200 bd；
///   * 编码：NRZI（1 = 不变号，0 = 变号）+ HDLC 位填充（连续 5 个 1 后插 0）；
///   * 校验：CRC-16/X.25（poly 0x1021，反射 0x8408，初值 0xFFFF，取反后 LSB 先发）；
///   * 帧定界：flag 0x7E（HDLC 位反转后仍是自身，故收发方向无关）。
///
/// 解调算法（确定性、可单测，不依赖任何平台音频 API）：
///   ① 一阶高通去直流（声卡常有直流偏置）；
///   ② 一比特长滑窗**复数相关**：分别求 1200 Hz 与 2200 Hz 的能量，
///      判别量 d = |corr(1200)|² − |corr(2200)|²（d > 0 判标号）；
///   ③ 数字锁相（DPLL）：d 过零点即「比特中心」（因果滑窗带来半比特群时延），
///      用误差按比例微调相位，几十个前导 flag 内即可锁定；
///   ④ 相位归零处取样 → NRZI 解码 → HDLC 解填充 → FCS 校验 → AX.25 帧。
///
/// 参考实现：Bell 202 / AX.25（APRS101 第 9 章）、Dire Wolf、
/// `kiss.c`（Phil Karn KA9Q）。
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// AFSK / HDLC 参数
class AfskParams {
  /// 采样率（Hz）。22050 是声卡 TNC 的常用值（1200bd 下每比特 18.375 点）；
  /// 若设备不支持 22050，可改用 44100 / 48000 —— 本实现与采样率无关。
  final int sampleRate;

  /// 比特率（bd）。APRS 标准为 1200
  final double baud;

  /// 标号频率（Hz）：Bell 202 规定 mark = 1200
  final double markHz;

  /// 空号频率（Hz）：Bell 202 规定 space = 2200
  final double spaceHz;

  /// 发射前导时长（ms）。等价 KISS 的 TxDelay：发连续 flag 让对端解调器
  /// 锁定位时钟（射频上还要等中继/接收机静噪打开）。默认 300ms。
  final int txDelayMs;

  /// 帧尾 flag 数（≥1；2 更稳，给对端留出结束判定的余量）
  final int tailFlags;

  /// 输出幅度（0~1，相对满量程）。默认 0.6，给声卡/电台输入留 4dB 余量，
  /// 避免削顶（削顶会产生谐波，直接毁掉 FSK 频谱）。
  final double amplitude;

  const AfskParams({
    this.sampleRate = 22050,
    this.baud = 1200,
    this.markHz = 1200,
    this.spaceHz = 2200,
    this.txDelayMs = 300,
    this.tailFlags = 2,
    this.amplitude = 0.6,
  });

  /// 每比特采样数（可能不是整数，如 22050 / 1200 = 18.375）
  double get samplesPerBit => sampleRate / baud;

  /// 前导 flag 数：按时长算，但至少 4 个（约 27ms）——
  /// 即使 TxDelay 配 0，也要给对端解调器留锁定时间，否则整帧都收不到。
  int get preambleFlags {
    final n = (txDelayMs / 1000.0 * baud / 8).ceil();
    return n < 4 ? 4 : n;
  }

  AfskParams copyWith({
    int? sampleRate,
    double? baud,
    double? markHz,
    double? spaceHz,
    int? txDelayMs,
    int? tailFlags,
    double? amplitude,
  }) =>
      AfskParams(
        sampleRate: sampleRate ?? this.sampleRate,
        baud: baud ?? this.baud,
        markHz: markHz ?? this.markHz,
        spaceHz: spaceHz ?? this.spaceHz,
        txDelayMs: txDelayMs ?? this.txDelayMs,
        tailFlags: tailFlags ?? this.tailFlags,
        amplitude: amplitude ?? this.amplitude,
      );

  Map<String, dynamic> toJson() => {
        'sampleRate': sampleRate,
        'baud': baud,
        'markHz': markHz,
        'spaceHz': spaceHz,
        'txDelayMs': txDelayMs,
        'tailFlags': tailFlags,
        'amplitude': amplitude,
      };

  static AfskParams fromJson(Object? j) {
    if (j is! Map) return const AfskParams();
    double d(Object? v, double fallback) =>
        v is num ? v.toDouble() : fallback;
    int i(Object? v, int fallback) => v is num ? v.toInt() : fallback;
    return AfskParams(
      sampleRate: i(j['sampleRate'], 22050).clamp(8000, 192000),
      baud: d(j['baud'], 1200).clamp(300, 9600),
      markHz: d(j['markHz'], 1200).clamp(300, 4000),
      spaceHz: d(j['spaceHz'], 2200).clamp(300, 4000),
      txDelayMs: i(j['txDelayMs'], 300).clamp(0, 2550),
      tailFlags: i(j['tailFlags'], 2).clamp(1, 16),
      amplitude: d(j['amplitude'], 0.6).clamp(0.05, 1.0),
    );
  }
}

/// HDLC：FCS、位序、位填充与帧组装（纯函数部分）
class Hdlc {
  Hdlc._();

  /// HDLC 帧定界符
  static const int flag = 0x7E;

  /// CRC-16/X.25：poly 0x1021（反射 0x8408），初值 0xFFFF，取反输出
  static int crc16X25(List<int> bytes, {int crc = 0xFFFF}) {
    for (var i = 0; i < bytes.length; i++) {
      crc ^= bytes[i] & 0xFF;
      for (var b = 0; b < 8; b++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0x8408 : crc >> 1;
      }
    }
    return crc & 0xFFFF;
  }

  /// 收端校验：整帧（含 2 字节 FCS）的 CRC 残差恒为 0xF0B8
  static bool checkFcs(List<int> frameWithFcs) =>
      crc16X25(frameWithFcs) == 0xF0B8;

  /// 追加 FCS。AX.25 规定 FCS **取反后低字节在前**（LSB first）
  static List<int> appendFcs(List<int> payload) {
    final fcs = crc16X25(payload) ^ 0xFFFF;
    return <int>[...payload, fcs & 0xFF, (fcs >> 8) & 0xFF];
  }

  /// 字节流 → 比特流。HDLC 每字节 **LSB 先发**
  static List<int> bits(List<int> bytes) {
    final out = <int>[];
    for (final b in bytes) {
      for (var i = 0; i < 8; i++) {
        out.add((b >> i) & 1);
      }
    }
    return out;
  }

  /// 位填充（透明传输）：数据区连续 5 个 1 之后插入一个 0
  static List<int> stuff(List<int> raw) {
    final out = <int>[];
    var ones = 0;
    for (final b in raw) {
      out.add(b);
      if (b == 1) {
        ones++;
        if (ones == 5) {
          out.add(0);
          ones = 0;
        }
      } else {
        ones = 0;
      }
    }
    return out;
  }

  /// 组装完整帧的比特流：前导 flag + 填充后的「数据+FCS」+ 尾 flag
  static List<int> frameBits(
    List<int> payload, {
    required int preambleFlags,
    required int tailFlags,
  }) {
    final out = <int>[];
    for (var i = 0; i < preambleFlags; i++) {
      out.addAll(bits(const [flag]));
    }
    out.addAll(stuff(bits(appendFcs(payload))));
    for (var i = 0; i < tailFlags; i++) {
      out.addAll(bits(const [flag]));
    }
    return out;
  }
}

/// 流式 HDLC 比特解码器
///
/// 输入是 NRZI 解码后的比特流（约定 1 = 不变号），输出是校验通过的
/// AX.25 帧（**不含** FCS）。状态机与 `KissDecoder` 同一思路：必须增量喂入，
/// 因为一次音频回调可能拿到半帧、也可能拿到多帧。
class HdlcDecoder {
  HdlcDecoder({this.onFrame});

  /// 解出一帧（已去掉 FCS，已通过校验）
  void Function(Uint8List frame)? onFrame;

  /// AX.25 UI 帧最小长度（地址 14 + 控制 1 + PID 1），再加 2 字节 FCS
  static const int minFrame = 16;

  /// 单帧长度上限，防噪声把内存撑爆
  static const int maxFrame = 512;

  int _shift = 0; // 8 位滑动寄存器（flag 检测）
  int _ones = 0; // 连续 1 的个数（填充/abort 判定）
  int _byte = 0; // 当前字节（LSB 先收）
  int _bitCount = 0;
  final List<int> _buf = <int>[];
  bool _inFrame = false;

  /// 是否已进入帧（供 DCD/日志用）
  bool get inFrame => _inFrame;

  void reset() {
    _shift = 0;
    _ones = 0;
    _byte = 0;
    _bitCount = 0;
    _buf.clear();
    _inFrame = false;
  }

  /// 处理一个 NRZI 解码后的比特
  void feedBit(int bit) {
    final b = bit & 1;
    // flag 检测：滑动 8 位比较 0x7E。0x7E 位反转后仍是自身，
    // 因此无论按 MSB 还是 LSB 方向移位都能识别（与字节边界无关）。
    _shift = ((_shift >> 1) | (b << 7)) & 0xFF;
    if (_shift == Hdlc.flag) {
      if (_inFrame) _finish();
      // flag 既结束上一帧也开启下一帧（共享 flag 约定）
      _inFrame = true;
      _buf.clear();
      _ones = 0;
      _byte = 0;
      _bitCount = 0;
      return;
    }
    if (!_inFrame) return;
    // 连续 7 个 1：既不是 flag（flag 是 6 个 1 + 0，已在上面识别）也不是填充，
    // 属非法序列（中止/噪声/失步）→ 丢弃本次接收。
    if (_ones >= 6) {
      reset();
      return;
    }
    // 位填充：数据区连续 5 个 1 后的那个 0 是填充位，丢弃
    if (b == 0 && _ones == 5) {
      _ones = 0;
      return;
    }
    _ones = b == 1 ? _ones + 1 : 0;
    _byte = (_byte >> 1) | (b << 7);
    if (++_bitCount == 8) {
      _buf.add(_byte);
      _byte = 0;
      _bitCount = 0;
      if (_buf.length > maxFrame) reset(); // 噪声：立刻停，别等 FCS
    }
  }

  void feedBits(Iterable<int> bits) {
    for (final b in bits) {
      feedBit(b);
    }
  }

  void _finish() {
    final n = _buf.length;
    // 太短（AX.25 地址+控制+PID 至少 16 字节）或 FCS 不符 → 丢弃
    if (n - 2 < minFrame) return;
    final frame = Uint8List.fromList(_buf);
    if (!Hdlc.checkFcs(frame)) return;
    onFrame?.call(Uint8List.sublistView(frame, 0, n - 2));
  }
}

/// AFSK 调制器：AX.25 帧字节 → PCM16 采样
class AfskModulator {
  final AfskParams params;

  AfskModulator(this.params);

  /// 调制一帧。返回单声道 16 位有符号 PCM（小端由调用方处理）
  Int16List modulate(List<int> ax25Frame) {
    final bits = Hdlc.frameBits(
      ax25Frame,
      preambleFlags: params.preambleFlags,
      tailFlags: params.tailFlags,
    );
    return modulateBits(bits);
  }

  /// 直接调制一段 HDLC 比特流（测试用；NRZI 编码在这里做）
  Int16List modulateBits(List<int> hdlcBits) {
    final spb = params.samplesPerBit;
    final total = (hdlcBits.length * spb).round();
    if (total <= 0) return Int16List(0);
    final out = Int16List(total);
    final incMark = 2 * math.pi * params.markHz / params.sampleRate;
    final incSpace = 2 * math.pi * params.spaceHz / params.sampleRate;
    final amp = params.amplitude * 32767.0;
    // 两个周期常量（相位归约，避免长时间累加丢精度）
    const twoPi = 2 * math.pi;
    // NRZI：初始发标号；数据位 0 → 变号，1 → 不变号。
    // ⚠️ 变号必须**每比特一次**：写在逐采样循环里会让 0 比特期间每个采样
    // 都翻转一次（等效发出近奈奎斯特的噪声），解调端必然解不出 —— 这个
    // bug 曾同时存在于 Dart 与 Python 参考实现，靠交叉验证才发现。
    var tone = 1;
    var toneBit = -1;
    var phase = 0.0;
    for (var n = 0; n < total; n++) {
      final bi = (n / spb).floor();
      final bit = bi < hdlcBits.length ? hdlcBits[bi] : 1;
      if (bi != toneBit) {
        toneBit = bi;
        if (bit == 0) tone ^= 1;
      }
      phase += tone == 1 ? incMark : incSpace;
      if (phase >= twoPi) phase -= twoPi;
      out[n] = (math.sin(phase) * amp).round().clamp(-32768, 32767);
    }
    _applyEdgeRamp(out);
    return out;
  }

  /// 首尾各 5ms 升余弦淡入淡出：避免开/关声造成的爆音与宽频冲击
  void _applyEdgeRamp(Int16List s) {
    final ramp = (params.sampleRate * 0.005).round();
    if (ramp * 2 >= s.length) return;
    for (var i = 0; i < ramp; i++) {
      final w = 0.5 - 0.5 * math.cos(math.pi * i / ramp);
      s[i] = (s[i] * w).round();
      final j = s.length - 1 - i;
      s[j] = (s[j] * w).round();
    }
  }
}

/// AFSK 解调器：PCM16 采样 → AX.25 帧
///
/// 使用方式（流式）：不断 `feed` / `feedBytes`，解出的帧通过 [onFrame] 回调
/// 或返回值拿到。内部状态可长期保持 —— 相邻报文共享 DPLL 相位，锁定更快。
class AfskDemodulator {
  AfskDemodulator(this.params, {this.onFrame}) {
    final n = params.samplesPerBit.round();
    _n = n < 4 ? 4 : n;
    _spb = params.samplesPerBit;
    _ring = Float64List(_n);
    _cos1 = Float64List(_n);
    _sin1 = Float64List(_n);
    _cos2 = Float64List(_n);
    _sin2 = Float64List(_n);
    final w1 = 2 * math.pi * params.markHz / params.sampleRate;
    final w2 = 2 * math.pi * params.spaceHz / params.sampleRate;
    for (var k = 0; k < _n; k++) {
      _cos1[k] = math.cos(w1 * k);
      _sin1[k] = math.sin(w1 * k);
      _cos2[k] = math.cos(w2 * k);
      _sin2[k] = math.sin(w2 * k);
    }
    _hdlc = HdlcDecoder();
  }

  final AfskParams params;

  /// 解出一帧（不含 FCS 的 AX.25 帧）
  void Function(Uint8List frame)? onFrame;

  late final int _n; // 相关窗口长度（≈1 比特整点数）
  late final double _spb; // 每比特采样数（可为小数，DPLL 用它）
  late final Float64List _ring;
  late final Float64List _cos1;
  late final Float64List _sin1;
  late final Float64List _cos2;
  late final Float64List _sin2;
  late final HdlcDecoder _hdlc;

  int _idx = 0;
  // 一阶高通（去直流）
  double _x1 = 0;
  double _y1 = 0;
  // DPLL：相位以采样点计，0 = 比特边界（取样点），_spb/2 = 比特中心（过零点）
  double _phase = 0;
  int _lastSign = 0;
  int _lastTone = -1;

  // 电平/质量指标（供 UI 电平表与日志）
  double _level = 0;
  double _peak = 0;
  int _frames = 0;
  int _badFrames = 0;

  /// 最近一次相关幅度（0~1，1 ≈ 满量程单音）
  double get level => _level;

  /// 近期峰值（缓慢衰减），UI 可据此画相对电平条
  double get peak => _peak;

  /// 解出的有效帧数
  int get frameCount => _frames;

  /// 已开始接收但中途中止（失步/噪声/超长）的帧数，用于判断信道质量
  int get badFrameCount => _badFrames;

  /// DPLL 是否已锁定（有信号且相位误差稳定）
  bool get synced => _synced;
  bool _synced = false;
  int _goodRun = 0;
  int _badRun = 0;

  void reset() {
    _idx = 0;
    _x1 = 0;
    _y1 = 0;
    _phase = 0;
    _lastSign = 0;
    _lastTone = -1;
    _level = 0;
    _peak = 0;
    _synced = false;
    _goodRun = 0;
    _badRun = 0;
    _hdlc.reset();
  }

  /// 喂入一段 16 位有符号 PCM，返回本次解出的所有帧（同时也会触发 [onFrame]）
  List<Uint8List> feed(Int16List samples) {
    final out = <Uint8List>[];
    final prevOnFrame = _hdlc.onFrame;
    _hdlc.onFrame = (f) {
      _frames++;
      out.add(f);
      onFrame?.call(f);
    };
    try {
      for (var s = 0; s < samples.length; s++) {
        _processSample(samples[s] / 32768.0);
      }
    } finally {
      _hdlc.onFrame = prevOnFrame;
    }
    return out;
  }

  /// 喂入小端 16 位 PCM 字节流（Android 原生 / WAV 数据块的原始形态）
  List<Uint8List> feedBytes(Uint8List bytes) {
    final n = bytes.length >> 1;
    final s = Int16List(n);
    for (var i = 0; i < n; i++) {
      var v = bytes[i * 2] | (bytes[i * 2 + 1] << 8);
      if (v >= 0x8000) v -= 0x10000; // 小端有符号
      s[i] = v;
    }
    return feed(s);
  }

  void _processSample(double x) {
    // ① 去直流：声卡/电台线路输入常带直流偏置，会压缩相关器动态范围
    final y = x - _x1 + 0.995 * _y1;
    _x1 = x;
    _y1 = y;
    _ring[_idx] = y;
    // ② 一比特长滑窗复数相关（环形缓冲顺序读取，避免取模）
    double c1 = 0, s1 = 0, c2 = 0, s2 = 0;
    var j = _idx;
    for (var k = 0; k < _n; k++) {
      final v = _ring[j];
      c1 += v * _cos1[k];
      s1 += v * _sin1[k];
      c2 += v * _cos2[k];
      s2 += v * _sin2[k];
      if (--j < 0) j = _n - 1;
    }
    _idx++;
    if (_idx >= _n) _idx = 0;
    final m1 = c1 * c1 + s1 * s1;
    final m2 = c2 * c2 + s2 * s2;
    final d = m1 - m2;
    // 电平：满幅单音相关幅度 ≈ N/2，故 /(N/2) 归一到 0~1
    final half = _n / 2.0;
    final lv = math.sqrt(m1 + m2) / half;
    _level = lv > 1.0 ? 1.0 : lv;
    if (_level > _peak) {
      _peak = _level;
    } else {
      _peak *= 0.9995;
    }
    // ③ DPLL：d 过零 = 比特中心（因果窗半比特群时延）；相位在 0（边界）取样
    final sign = d > 0 ? 1 : (d < 0 ? -1 : _lastSign);
    if (sign != 0 && _lastSign != 0 && sign != _lastSign) {
      var err = _spb / 2 - _phase; // 理想相位 = 半比特
      if (err > _spb / 2) {
        err -= _spb;
      } else if (err < -_spb / 2) {
        err += _spb;
      }
      // 只在「离理想位置不远」时牵引，避免锁到噪声引起的假过零
      if (err.abs() < _spb * 0.35) {
        _phase += err * 0.22;
        _goodRun++;
        _badRun = 0;
        if (_goodRun > 24) _synced = true;
      }
    } else {
      _badRun++;
      if (_badRun > 200) {
        _synced = false;
        _goodRun = 0;
      }
    }
    _lastSign = sign;
    _phase += 1.0;
    if (_phase >= _spb) {
      _phase -= _spb;
      final tone = d > 0 ? 1 : 0;
      if (_lastTone < 0) {
        _lastTone = tone;
      } else {
        // NRZI 解码：变号 = 0，不变 = 1
        final bit = tone == _lastTone ? 1 : 0;
        _lastTone = tone;
        final before = _hdlc.inFrame;
        _hdlc.feedBit(bit);
        if (before && !_hdlc.inFrame) _badFrames++;
      }
    }
  }
}
