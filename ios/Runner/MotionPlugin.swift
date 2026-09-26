import CoreMotion
import Flutter
import UIKit

/// 运动传感器（加速度计 + 指南针）的 **iOS 原生实现**。
///
/// 与 Android（`MotionManager.kt`）保持同一套通道契约：
///
///   方法通道 `com.aprslocus/motion`
///     - `start`  → Bool（设备有 deviceMotion / 加速度计才 true）
///     - `stop`   → null
///     - `sample` → Map {available, moving, hasCompass, heading, pitch, roll, accel}
///
/// 单位与 Android 对齐：
///   * `accel` 是**线性加速度 RMS（m/s²）**：CoreMotion 的 `userAcceleration`
///     单位是 g（已去重力），这里 ×9.80665 换成 m/s²，再走同一套指数平均；
///   * `heading` 是磁北航向（度，不可用时 < 0）：取 `attitude.yaw`，参考系优先磁北。
///
/// 采样率取 15Hz（≈ Android `SENSOR_DELAY_UI`）：判「在不在动」与拿航向都够用。
final class MotionPlugin: NSObject {
  static let channelName = "com.aprslocus/motion"

  /// 线性加速度 RMS 超过它才认为「真的在动」（m/s²），与 Android 一致。
  private static let moveThreshold = 0.35
  /// 线性加速度能量的指数平均系数，与 Android 一致。
  private static let energyAlpha = 0.2
  /// g → m/s²。
  private static let gToMs2 = 9.80665

  private let manager = CMMotionManager()

  private var started = false
  private var energy = 0.0
  private var lastAccel = 0.0
  private var heading = -1.0
  private var pitch = 0.0
  private var roll = 0.0
  private var hasCompass = false

  private static var instances: [MotionPlugin] = []

  static func register(with messenger: FlutterBinaryMessenger) {
    let plugin = MotionPlugin()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      plugin.handle(call, result: result)
    }
    instances.append(plugin)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      result(start())
    case "stop":
      stop()
      result(nil)
    case "sample":
      result(snapshot())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private var available: Bool {
    manager.isDeviceMotionAvailable || manager.isAccelerometerAvailable
  }

  /// 注册监听。没有 deviceMotion 也没有加速度计时返回 false（上层按「无传感器」处理）。
  private func start() -> Bool {
    if started { return true }
    guard available else { return false }
    energy = 0
    lastAccel = 0
    heading = -1
    hasCompass = false

    if manager.isDeviceMotionAvailable {
      // 磁北参考系下 yaw 才是磁航向；设备不支持磁北时退回任意参考系，
      // 此时 hasCompass=false，上层不会把 yaw 当罗盘用。
      let magnetic = CMMotionManager.availableAttitudeReferenceFrames()
        .contains(.xMagneticNorthZVertical)
      let frame: CMAttitudeReferenceFrame = magnetic ? .xMagneticNorthZVertical : .xArbitraryZVertical
      hasCompass = magnetic
      manager.deviceMotionUpdateInterval = 1.0 / 15.0
      manager.startDeviceMotionUpdates(using: frame, to: OperationQueue.main) { [weak self] motion, _ in
        guard let self = self, let m = motion else { return }
        self.onDeviceMotion(m)
      }
    } else {
      // 只有加速度计：至少能回答「在不在动」，航向不可用。
      manager.accelerometerUpdateInterval = 1.0 / 15.0
      manager.startAccelerometerUpdates(to: OperationQueue.main) { [weak self] data, _ in
        guard let self = self, let d = data else { return }
        let a = d.acceleration
        self.accumulate(ax: a.x, ay: a.y, az: a.z)
      }
    }
    started = true
    return true
  }

  private func stop() {
    guard started else { return }
    manager.stopDeviceMotionUpdates()
    manager.stopAccelerometerUpdates()
    started = false
    energy = 0
    lastAccel = 0
    heading = -1
    hasCompass = false
  }

  private func onDeviceMotion(_ m: CMDeviceMotion) {
    heading = norm360(m.attitude.yaw * 180.0 / Double.pi)
    pitch = m.attitude.pitch * 180.0 / Double.pi
    roll = m.attitude.roll * 180.0 / Double.pi
    let a = m.userAcceleration
    accumulate(ax: a.x, ay: a.y, az: a.z)
  }

  private func accumulate(ax: Double, ay: Double, az: Double) {
    // userAcceleration 单位是 g → m/s²（与 Android 的加速度计单位一致）
    let mx = ax * Self.gToMs2
    let my = ay * Self.gToMs2
    let mz = az * Self.gToMs2
    let e = mx * mx + my * my + mz * mz
    energy = energy * (1 - Self.energyAlpha) + e * Self.energyAlpha
    lastAccel = energy.squareRoot()
  }

  private func snapshot() -> [String: Any] {
    return [
      "available": available,
      "moving": lastAccel > Self.moveThreshold,
      "hasCompass": hasCompass,
      "heading": heading,
      "pitch": pitch,
      "roll": roll,
      "accel": lastAccel,
    ]
  }

  private func norm360(_ deg: Double) -> Double {
    var d = deg.truncatingRemainder(dividingBy: 360)
    if d < 0 { d += 360 }
    return d
  }
}
