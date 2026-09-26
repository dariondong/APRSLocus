import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart';

/// ─── 运动传感器（加速度计 + 指南针）───
///
/// Android / iOS 都有实现（原生 `MotionManager.kt` / `MotionPlugin.swift`）；
/// 其它平台一律返回 [MotionSample.unknown]，调用方按「没有传感器」的旧路径走，
/// 不需要分平台写逻辑。
///
/// 为什么不用 `sensors_plus` 之类的插件：本项目对第三方插件的取舍一贯是
/// 「能用平台通道自己搬的就不加依赖」（TNC / PKWDWPL / 音频 / USB 串口都是这么做的）。
/// 传感器只是读几个 Float，加一个插件要多维护一套 Android/iOS/Windows 三平台实现
/// 与版本兼容，不划算。
///
/// 采样方式是**拉取**而不是事件流：原生侧常驻监听、缓存最近一次结果，
/// Dart 侧在每次定位回调里 `refresh()` 一次。这样平台上不会有持续的事件流量，
/// 也不会因为「没有监听者」而在后台白白唤醒（退出/停止定位时 `stop()` 注销）。
class MotionSample {
  /// 设备上是否存在可用的运动传感器
  final bool available;

  /// 加速度计判断「真的在动」（RMS 线性加速度超阈值）
  final bool moving;

  /// 是否有可用的指南针（旋转矢量或加速度计 + 磁力计）
  final bool hasCompass;

  /// 磁北航向（度，0~360）；< 0 表示不可用
  final double heading;

  /// 线性加速度的 RMS（m/s²，已去重力）：静止约 0.0x，步行 0.5~3
  final double accel;

  const MotionSample({
    required this.available,
    required this.moving,
    required this.hasCompass,
    required this.heading,
    required this.accel,
  });

  static const MotionSample unknown = MotionSample(
    available: false,
    moving: false,
    hasCompass: false,
    heading: -1,
    accel: 0,
  );
}

class MotionService {
  MotionService._();
  static final MotionService instance = MotionService._();

  static const _channel = MethodChannel('com.aprslocus/motion');

  /// 最近一次采样结果（未启动/不支持时为 [MotionSample.unknown]）
  MotionSample sample = MotionSample.unknown;

  bool _started = false;

  /// Android（`MotionManager.kt`）与 iOS（`ios/Runner/MotionPlugin.swift`）都有实现；
  /// 其它平台一律返回 [MotionSample.unknown]，调用方按「没有传感器」的旧路径走。
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get running => _started;

  /// 启动传感器监听；设备没有传感器时静默失败（返回 false）。
  Future<bool> start() async {
    if (!supported) return false;
    if (_started) return true;
    try {
      final ok = await _channel.invokeMethod<bool>('start') ?? false;
      _started = ok;
      return ok;
    } catch (_) {
      // 通道缺席（旧 APK / 其它平台）不是错误，按「没有传感器」处理
      _started = false;
      return false;
    }
  }

  Future<void> stop() async {
    if (!supported) return;
    final was = _started;
    _started = false;
    sample = MotionSample.unknown;
    if (!was) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }

  /// 拉取一次最新采样。非 Android / 通道异常时保持上一次的值。
  Future<MotionSample> refresh() async {
    if (!supported || !_started) return sample;
    try {
      final r = await _channel.invokeMethod<Map<Object?, Object?>>('sample');
      if (r == null) return sample;
      sample = MotionSample(
        available: r['available'] == true,
        moving: r['moving'] == true,
        hasCompass: r['hasCompass'] == true,
        heading: (r['heading'] as num?)?.toDouble() ?? -1,
        accel: (r['accel'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {}
    return sample;
  }
}
