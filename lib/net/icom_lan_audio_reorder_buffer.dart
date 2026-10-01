/// 接收音频重排缓冲（对应 mod 的 `session/Ic705AudioReorderBuffer.kt`）。
///
/// 目标：序号连续地写出音频，同时吸收少量 UDP 抖动；真丢包时**最多补两包静音**
/// 再报"断点"，让下游解调器复位。样本数按奇偶从**真实流**学习，避免用错
/// 采样率导致的静音时长偏差。
///
/// 线程安全由持有者（[IcomLanRxAudioReceiver]）保证 —— 与 mod 一致。
library;

import 'dart:typed_data';

import 'icom_lan_audio_sequence_policy.dart';

/// 音频断点种类。
enum IcomLanAudioDiscontinuityKind { gap, outOfOrder }

/// 音频断点（期望序号 / 实际序号 / 缺了几个包）。
class IcomLanAudioDiscontinuity {
  const IcomLanAudioDiscontinuity({
    required this.kind,
    required this.expectedSequence,
    required this.actualSequence,
    required this.missingPacketCount,
  });

  final IcomLanAudioDiscontinuityKind kind;
  final int expectedSequence;
  final int actualSequence;
  final int missingPacketCount;
}

/// 收包结果（与 mod 的 `Ic705AudioReceiveResult` 一一对应）。
enum IcomLanAudioReceiveResult {
  accepted,
  buffered,
  duplicateDropped,
  outOfOrderDropped,
}

class IcomLanAudioReorderBuffer {
  IcomLanAudioReorderBuffer({
    required this.writeSamples,
    this.onDiscontinuity,
  });

  /// 样本落点（通常直接写进解调器）。
  final void Function(Int16List samples) writeSamples;

  /// 断点回调（缺包超过补齐上限时触发）。
  final void Function(IcomLanAudioDiscontinuity discontinuity)? onDiscontinuity;

  /// 观测到的样本数合法区间（用于学习真实包大小）。
  static const int minSaneObservedSamples = 1;
  static const int maxSaneObservedSamples = 480;

  int? _nextAudioSequence;
  int? _lastDeliveredSequence;
  final Map<int, Int16List> _pendingAudio = {};
  final List<int> _observedSampleCountsByParity = [0, 0];

  IcomLanAudioReceiveResult accept(int sequence, Int16List samples) {
    if (_lastDeliveredSequence == sequence || _pendingAudio.containsKey(sequence)) {
      return IcomLanAudioReceiveResult.duplicateDropped;
    }

    final expectedSequence = _nextAudioSequence;
    if (expectedSequence == null) {
      _deliver(sequence, samples);
      return IcomLanAudioReceiveResult.accepted;
    }

    final forwardDistance =
        icomLanAudioSequenceDistance(expectedSequence, sequence);
    if (forwardDistance == 0) {
      _deliver(sequence, samples);
      _drainContiguousPending();
      return IcomLanAudioReceiveResult.accepted;
    }
    if (forwardDistance >= kIcomLanAudioHalfSequenceSpace) {
      // 这包迟到了，而它的缺口在放出更新的音频时已经处理过；
      // 这里再复位一次会把一次网络断点变成两次解调器复位。
      return IcomLanAudioReceiveResult.outOfOrderDropped;
    }
    if (forwardDistance > kIcomLanAudioMaxReorderPackets) {
      _reportGapAndDeliver(expectedSequence, sequence, samples);
      _drainContiguousPending();
      return IcomLanAudioReceiveResult.accepted;
    }
    _pendingAudio[sequence] = samples;
    if (_pendingAudio.length >= kIcomLanAudioMaxReorderPackets) {
      _releaseNearestPending(expectedSequence);
      return IcomLanAudioReceiveResult.accepted;
    }
    return IcomLanAudioReceiveResult.buffered;
  }

  void reset() {
    _nextAudioSequence = null;
    _lastDeliveredSequence = null;
    _pendingAudio.clear();
    _observedSampleCountsByParity[0] = 0;
    _observedSampleCountsByParity[1] = 0;
  }

  void _deliver(int sequence, Int16List samples, {int? observedSampleCount}) {
    writeSamples(samples);
    final observed = observedSampleCount ?? samples.length;
    if (observed >= minSaneObservedSamples &&
        observed <= maxSaneObservedSamples) {
      _observedSampleCountsByParity[sequence & 1] = observed;
    }
    _lastDeliveredSequence = sequence;
    _nextAudioSequence = incrementIcomLanAudioSequence(sequence);
  }

  void _drainContiguousPending() {
    while (true) {
      final expected = _nextAudioSequence;
      if (expected == null) return;
      final samples = _pendingAudio.remove(expected);
      if (samples == null) return;
      _deliver(expected, samples);
    }
  }

  void _releaseNearestPending(int expectedSequence) {
    int? bestSequence;
    var bestDistance = 0x10000;
    for (final sequence in _pendingAudio.keys) {
      final distance = icomLanAudioSequenceDistance(expectedSequence, sequence);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestSequence = sequence;
      }
    }
    if (bestSequence == null) return;
    final samples = _pendingAudio.remove(bestSequence);
    if (samples == null) return;
    _reportGapAndDeliver(expectedSequence, bestSequence, samples);
    _drainContiguousPending();
  }

  void _reportGapAndDeliver(
      int expectedSequence, int actualSequence, Int16List samples) {
    final missingPacketCount =
        icomLanAudioSequenceDistance(expectedSequence, actualSequence);
    if (missingPacketCount <= kIcomLanAudioMaxConcealedPackets) {
      var concealedSampleCount = 0;
      for (var offset = 0; offset < missingPacketCount; offset++) {
        concealedSampleCount += _samplesForConcealment(
            (expectedSequence + offset) & 0xffff);
      }
      final concealed = Int16List(concealedSampleCount + samples.length);
      concealed.setRange(concealedSampleCount, concealed.length, samples);
      // 学习到的包大小必须记**真实**那个，否则补出来的大包会把后续补齐越补越长。
      _deliver(actualSequence, concealed, observedSampleCount: samples.length);
      return;
    }
    onDiscontinuity?.call(IcomLanAudioDiscontinuity(
      kind: IcomLanAudioDiscontinuityKind.gap,
      expectedSequence: expectedSequence,
      actualSequence: actualSequence,
      missingPacketCount: missingPacketCount,
    ));
    _deliver(actualSequence, samples);
  }

  int _samplesForConcealment(int sequence) {
    final observed = _observedSampleCountsByParity[sequence & 1];
    return observed >= minSaneObservedSamples &&
            observed <= maxSaneObservedSamples
        ? observed
        : icomLanSamplesPerReceivePacket(sequence);
  }
}
