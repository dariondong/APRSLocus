import CoreLocation
import Flutter
import UIKit

/// 定位通道的 iOS 原生实现。
///
/// 与 Android（MainActivity + LocationService）保持同一套通道契约：
///
/// 方法通道 `com.aprslocus/location`
///   - `isAvailable`        → true（Dart 侧据此判断原生是否已接入）
///   - `checkPermissions`   → Bool，当前是否已授权
///   - `requestPermissions` → 触发系统权限弹窗（不等待用户点击，Dart 侧会重试）
///   - `startService`       → 开始定位，参数 `mode`
///   - `stopService`        → 停止定位
///   - `setLocationMode`    → 运行中切换模式
///
/// 事件通道 `com.aprslocus/location_events`
///   `{lat, lng, alt(米), speed(米/秒), bearing(度, 无效为 -1)}`
///
/// 单位与 Android 端一致：`alt` 米、`speed` **米/秒**（Dart 侧再 *3.6 转 km/h）、
/// `bearing` 度且无效时 -1。CLLocationManager 的单位正好相同，可直接映射。
///
/// 注册方式不走 `GeneratedPluginRegistrant`，而是由 `AppDelegate` 调用
/// [LocationPlugin.register]，避免手工改动 `GeneratedPluginRegistrant.swift`
/// （该文件在每次 `flutter pub get` 时会被重新生成并覆盖）。
final class LocationPlugin: NSObject, CLLocationManagerDelegate {
  static let methodChannelName = "com.aprslocus/location"
  static let eventChannelName = "com.aprslocus/location_events"

  private let manager = CLLocationManager()
  private var eventSink: FlutterEventSink?
  private var mode = "gps_network"

  /// 是否已声明 location 后台模式（Info.plist 的 UIBackgroundModes）。
  /// 未声明时设置 `allowsBackgroundLocationUpdates` 会直接崩溃，故先探测。
  private static var hasBackgroundMode: Bool {
    guard let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes")
      as? [String] else { return false }
    return modes.contains("location")
  }

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = kCLDistanceFilterNone
    // 移动台站场景：需要速度/方位角连续更新
    manager.activityType = .otherNavigation
    if Self.hasBackgroundMode {
      manager.allowsBackgroundLocationUpdates = true
      // 自动暂停会中断追踪，必须关闭
      manager.pausesLocationUpdatesAutomatically = false
    }
  }

  // MARK: - 注册

  /// 用引擎的应用级 `FlutterBinaryMessenger` 注册（由 AppDelegate 传入）。
  /// 这是 `FlutterApplicationRegistrar` 的用途所在：面向**应用级**通道，
  /// 无需伪造一个 plugin 身份。
  static func register(with messenger: FlutterBinaryMessenger) {
    let plugin = LocationPlugin()
    let method = FlutterMethodChannel(
      name: methodChannelName, binaryMessenger: messenger)
    method.setMethodCallHandler { call, result in
      plugin.handle(call, result: result)
    }
    let events = FlutterEventChannel(
      name: eventChannelName, binaryMessenger: messenger)
    events.setStreamHandler(plugin)
    // 双重保活：通道会持有 handler，但显式持有一份更稳当
    instances.append(plugin)
  }

  private static var instances: [LocationPlugin] = []

  // MARK: - 方法调用

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(true)

    case "checkPermissions":
      result(isAuthorized)

    case "requestPermissions":
      // 只在主线程操作 CLLocationManager
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        if self.isAuthorized {
          result(true)
        } else if self.manager.authorizationStatus == .notDetermined {
          // 弹窗（.notDetermined 时系统才会弹出；已拒绝需去设置里改）
          self.manager.requestWhenInUseAuthorization()
          result(false)
        } else {
          // 已拒绝 / 受限：系统不会再弹窗，返回当前状态
          result(false)
        }
      }

    case "startService":
      let m = (call.arguments as? [String: Any])?["mode"] as? String
      DispatchQueue.main.async { [weak self] in
        self?.start(mode: m ?? "gps_network")
        result(true)
      }

    case "stopService":
      DispatchQueue.main.async { [weak self] in
        self?.manager.stopUpdatingLocation()
        result(true)
      }

    case "setLocationMode":
      let m = (call.arguments as? [String: Any])?["mode"] as? String
      mode = m ?? mode
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// 本工程 iOS 部署目标为 15.0（见 IPHONEOS_DEPLOYMENT_TARGET），
  /// 故可直接用 `authorizationStatus` 实例属性（iOS 14+）而不必兼容旧 API。
  private var isAuthorized: Bool {
    let status = manager.authorizationStatus
    return status == .authorizedAlways || status == .authorizedWhenInUse
  }

  private func start(mode: String) {
    self.mode = mode
    guard isAuthorized else {
      emitStatus("请授予定位权限…")
      return
    }
    // iOS 无法像 Android 那样「仅 GPS / GPS+网络」二选一，
    // 两种模式统一使用最高精度并允许系统自动选择定位源（含网络辅助）
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.startUpdatingLocation()
    manager.requestLocation() // 立即取一次，避免等待首次位移
    emitStatus("GPS 定位中…")
  }

  // MARK: - 事件输出

  private func emit(_ payload: [String: Any]) {
    guard let sink = eventSink else { return }
    DispatchQueue.main.async { sink(payload) }
  }

  private func emitStatus(_ text: String) {
    emit(["status": text])
  }

  // MARK: - CLLocationManagerDelegate

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let loc = locations.last else { return }
    // iOS 首次会回调「最后一个已知位置」，可能是很久以前的缓存，丢弃
    if abs(loc.timestamp.timeIntervalSinceNow) > 15 { return }
    // speed < 0 表示无效；bearing < 0 表示无效（与 Android 约定一致：-1）
    let speed = loc.speed >= 0 ? loc.speed : 0.0
    let bearing = loc.course >= 0 ? loc.course : -1.0
    let alt = loc.verticalAccuracy >= 0 ? loc.altitude : 0.0
    emit([
      "lat": loc.coordinate.latitude,
      "lng": loc.coordinate.longitude,
      "alt": alt,
      "speed": speed,
      "bearing": bearing,
      "accuracy": loc.horizontalAccuracy >= 0 ? loc.horizontalAccuracy : 0.0,
      "provider": "ios",
    ])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    emitStatus("定位失败: \(error.localizedDescription)")
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if isAuthorized {
      emitStatus("已获定位权限")
    } else if manager.authorizationStatus == .denied {
      emitStatus("定位权限被拒绝，可在「设置 → 隐私 → 定位服务」中开启")
    }
  }
}

// MARK: - 事件通道

extension LocationPlugin: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
