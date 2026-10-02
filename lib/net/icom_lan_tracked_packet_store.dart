/// 追踪包存储（对应 mod 的 `session/Ic705TrackedPacketStore.kt`）。
///
/// 电台会按外层序号请求重传，所以发出去的包要留一小段时间；同时：
///   * 序号**只增不减**（本地发失败时 `discard` 只删内容、不回收序号）；
///   * 有保留时长与条数上限，长会话不会无限增长。
library;

import 'dart:typed_data';

import 'icom_lan_protocol.dart';

/// 一个被追踪的包（序号 + 已写入序号的副本）。
class IcomLanTrackedPacket {
  const IcomLanTrackedPacket(this.sequence, this.data);

  final int sequence;
  final Uint8List data;
}

class IcomLanTrackedPacketStore {
  IcomLanTrackedPacketStore({
    int initialSequence = 1,
    this.retentionMillis = 10000,
    this.maxEntries = 512,
    int Function()? monotonicMillis,
  }) : _nextSequence = initialSequence,
       _monotonicMillis = monotonicMillis ?? _defaultMonotonic {
    if (initialSequence < 0 || initialSequence > 0xffff) {
      throw ArgumentError('initialSequence must fit in 16 bits');
    }
    if (retentionMillis <= 0) throw ArgumentError('retentionMillis must be > 0');
    if (maxEntries <= 0) throw ArgumentError('maxEntries must be > 0');
    _lastTrackedAtMillis = _monotonicMillis();
  }

  static int _defaultMonotonic() =>
      DateTime.now().microsecondsSinceEpoch ~/ 1000;

  final int retentionMillis;
  final int maxEntries;
  final int Function() _monotonicMillis;

  final Map<int, _Entry> _entries = {}; // 插入序即时间序（Dart 的 Map 保序）
  int _nextSequence;
  late int _lastTrackedAtMillis;

  /// 分配序号、写入头部 0x06，并留存副本。
  IcomLanTrackedPacket track(Uint8List template) {
    if (template.length < IcomLanControlCodec.packetSize) {
      throw ArgumentError('Tracked packet must contain the common Icom header');
    }
    final now = _monotonicMillis();
    _purge(now);
    final sequence = _nextSequence;
    _nextSequence = (_nextSequence + 1) & 0xffff;
    final immutable = Uint8List.fromList(template);
    IcomLanBytes.writeUInt16Le(immutable, 0x06, sequence);
    _entries[sequence] = _Entry(now, immutable);
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    _lastTrackedAtMillis = now;
    return IcomLanTrackedPacket(sequence, Uint8List.fromList(immutable));
  }

  /// 本地发送失败时调用：删掉内容，避免电台重传请求把一条失败命令复活。
  ///
  /// **序号不回收** —— 后继包可能已经观察到下一个值，回退是不安全的。
  void discard(int sequence) {
    if (sequence < 0 || sequence > 0xffff) {
      throw ArgumentError('sequence must fit in 16 bits');
    }
    _entries.remove(sequence);
  }

  Uint8List? find(int sequence) {
    if (sequence < 0 || sequence > 0xffff) {
      throw ArgumentError('sequence must fit in 16 bits');
    }
    _purge(_monotonicMillis());
    final entry = _entries[sequence];
    return entry == null ? null : Uint8List.fromList(entry.data);
  }

  /// 距上次 track 的毫秒数（用于 tracked idle 判定）。
  int millisSinceLastTracked() {
    final delta = _monotonicMillis() - _lastTrackedAtMillis;
    return delta < 0 ? 0 : delta;
  }

  void _purge(int now) {
    _entries.removeWhere((_, entry) => now - entry.storedAtMillis > retentionMillis);
  }
}

class _Entry {
  const _Entry(this.storedAtMillis, this.data);

  final int storedAtMillis;
  final Uint8List data;
}
