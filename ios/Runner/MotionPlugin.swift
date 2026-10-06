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

  // ── 碰撞 / 摔倒检测（issue #26 / #32），判据与 Android MotionManager 对齐 ──
  private static let sensGentle = 2.2
  private static let sensStandard = 3.0
  private static let sensFirm = 4.0
  private static let freefallG = 0.35
  private static let freefallMinMs = 80.0
  private static let freefallWatchMs = 2000.0
  private static let impactMoveG = 1.2
  private static let stillMs = 12000.0
  private static let cooldownMs = 180000.0
  private static let startGraceMs = 20000.0
  /// 无失重佐证时，「碰撞」要比灵敏度阈值再高一截才认（防「放手机」误报），与 Android 一致。
  private static let crashBarMult = 2.0
  private static let prefKey = "aprslocus.motion.sensitivity"

  private var impactAtMs: Double = 0        // 最近一次冲击时间（秒*1000）
  private var impactPeakG: Double = 0
  private var impactKind = ""
  private var lastCrashMs: Double = 0
  private var crashSeq = 0
  private var lastKind = ""
  private var freefallStartMs: Double = 0
  private var lastFreefallEndMs: Double = 0
  private var startedAtMs: Double = 0
  private var sensitivity = "standard"

  private var impactThresholdG: Double {
    switch sensitivity {
    case "gentle": return Self.sensGentle
    case "firm": return Self.sensFirm
    default: return Self.sensStandard
    }
  }

  private static func nowMs() -> Double {
    return Date().timeIntervalSince1970 * 1000.0
  }

  private let manager = CMMotionManager()

  private var started = false
  private var energy = 0.0
  private var lastAccel = 0.0
  /// 重力估计（仅「只有加速度计、没有 deviceMotion」的回退路径用）：一阶低通。
  private var gravity = [0.0, 0.0, 0.0]
  private var hasGravity = false
  private static let gravityAlpha = 0.15
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
    case "setSensitivity":
      // issue #32：设置碰撞/摔倒灵敏度（gentle / standard / firm），落盘到 UserDefaults。
      if let args = call.arguments as? [String: Any],
         let v = args["value"] as? String {
        setSensitivity(v)
      }
      result(true)
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
    hasGravity = false
    gravity = [0.0, 0.0, 0.0]
    heading = -1
    hasCompass = false
    impactAtMs = 0
    impactKind = ""
    freefallStartMs = 0
    startedAtMs = Self.nowMs()
    sensitivity = UserDefaults.standard.string(forKey: Self.prefKey) ?? "standard"

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
      // 用一阶低通估重力，再分离线性/总加速度（与 Android 的 gravity[]/accelEnergy 同一套）。
      manager.accelerometerUpdateInterval = 1.0 / 15.0
      manager.startAccelerometerUpdates(to: OperationQueue.main) { [weak self] data, _ in
        guard let self = self, let d = data else { return }
        let a = d.acceleration
        let raw = [a.x, a.y, a.z]
        if !self.hasGravity {
          self.gravity = raw
          self.hasGravity = true
        } else {
          for i in 0..<3 {
            self.gravity[i] += Self.gravityAlpha * (raw[i] - self.gravity[i])
          }
        }
        let lx = raw[0] - self.gravity[0]
        let ly = raw[1] - self.gravity[1]
        let lz = raw[2] - self.gravity[2]
        let lin = (lx * lx + ly * ly + lz * lz).squareRoot() * Self.gToMs2
        let tot = (raw[0] * raw[0] + raw[1] * raw[1] + raw[2] * raw[2]).squareRoot() * Self.gToMs2
        self.accumulate(linearMs2: lin, totalMs2: tot)
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
    // 线性（去重力）与总（含重力）加速度分开算：判失重只能用后者。
    let ua = m.userAcceleration
    let g = m.gravity
    let lin = (ua.x * ua.x + ua.y * ua.y + ua.z * ua.z).squareRoot() * Self.gToMs2
    let tx = ua.x + g.x, ty = ua.y + g.y, tz = ua.z + g.z
    let tot = (tx * tx + ty * ty + tz * tz).squareRoot() * Self.gToMs2
    accumulate(linearMs2: lin, totalMs2: tot)
  }

  private func accumulate(linearMs2: Double, totalMs2: Double) {
    let e = linearMs2 * linearMs2
    energy = energy * (1 - Self.energyAlpha) + e * Self.energyAlpha
    lastAccel = energy.squareRoot()
    checkImpact(linear: linearMs2, total: totalMs2)
  }

  /// 碰撞/摔倒判定（issue #26 / #32），与 Android MotionManager.checkImpact 同一套判据：
  /// 冲击 + 随后静止；冲击前有失重（自由落体）则判「摔倒」并用基准阈值，
  /// 否则判「碰撞」且要求冲击 ≥ 基准 × crashBarMult（防「放手机」误报）。
  private func checkImpact(linear: Double, total: Double) {
    let now = Self.nowMs()
    let lg = linear / Self.gToMs2
    let tg = total / Self.gToMs2

    // 失重用**总**加速度：正常静止≈1g，只有真失重才趋近 0。
    if tg <= Self.freefallG {
      if freefallStartMs == 0 { freefallStartMs = now }
    } else if freefallStartMs != 0 {
      if now - freefallStartMs >= Self.freefallMinMs { lastFreefallEndMs = now }
      freefallStartMs = 0
    }

    if impactAtMs == 0 {
      let fallWindow = lastFreefallEndMs != 0 &&
        now - lastFreefallEndMs <= Self.freefallWatchMs
      let bar = fallWindow ? impactThresholdG : impactThresholdG * Self.crashBarMult
      if lg >= bar && now - lastCrashMs > Self.cooldownMs &&
        now - startedAtMs > Self.startGraceMs {
        impactAtMs = now
        impactPeakG = lg
        impactKind = fallWindow ? "fall" : "crash"
      }
      return
    }
    if lg >= Self.impactMoveG {
      impactAtMs = 0
      impactPeakG = 0
      impactKind = ""
      return
    }
    if now - impactAtMs >= Self.stillMs {
      crashSeq += 1
      lastCrashMs = now
      lastKind = impactKind.isEmpty ? "crash" : impactKind
      impactAtMs = 0
      impactKind = ""
    }
  }

  private func setSensitivity(_ value: String) {
    let v = ["gentle", "standard", "firm"].contains(value) ? value : "standard"
    sensitivity = v
    UserDefaults.standard.set(v, forKey: Self.prefKey)
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
      // 碰撞/摔倒（issue #26 / #32），键名与 Android 对齐。
      "crashSeq": crashSeq,
      "hasCrashSensor": manager.isAccelerometerAvailable || manager.isDeviceMotionAvailable,
      "impactPending": impactAtMs != 0,
      "impactPeakG": (impactPeakG * 10).rounded() / 10,
      "lastKind": lastKind,
      "sensitivity": sensitivity,
    ]
  }

  private func norm360(_ deg: Double) -> Double {
    var d = deg.truncatingRemainder(dividingBy: 360)
    if d < 0 { d += 360 }
    return d
  }
}
