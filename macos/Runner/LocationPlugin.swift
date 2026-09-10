import CoreLocation
import FlutterMacOS

/// 定位通道的 macOS 原生实现（系统定位服务，含 Wi-Fi 定位 / GPS）。
///
/// 与 iOS / Android 共用同一套通道契约（见 ios/Runner/LocationPlugin.swift）：
///
/// 方法通道 `com.aprslocus/location`
///   `isAvailable` / `checkPermissions` / `requestPermissions` /
///   `startService(mode)` / `stopService` / `setLocationMode(mode)`
/// 事件通道 `com.aprslocus/location_events`
///   `{lat, lng, alt(米), speed(米/秒), bearing(度, 无效为 -1)}`
///
/// 与 iOS 的差异：macOS 无 `allowsBackgroundLocationUpdates`、
/// `pausesLocationUpdatesAutomatically`、`activityType`（均为 iOS 专有），
/// 故不设置。macOS 部署目标为 12.0（见 MACOSX_DEPLOYMENT_TARGET），
/// `authorizationStatus` 与 `locationManagerDidChangeAuthorization` 均为 macOS 11+
/// API，可直接使用。
///
/// 权限依赖：
///   - Info.plist 的 `NSLocationUsageDescription`
///   - 沙盒权限 `com.apple.security.personal-information.location`
final class MacLocationPlugin: NSObject, CLLocationManagerDelegate {
  static let methodChannelName = "com.aprslocus/location"
  static let eventChannelName = "com.aprslocus/location_events"

  private let manager = CLLocationManager()
  private var eventSink: FlutterEventSink?
  private var mode = "gps_network"

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = kCLDistanceFilterNone
  }

  // MARK: - 注册

  /// 由 `MainFlutterWindow.awakeFromNib` 用引擎的 messenger 注册
  static func register(with messenger: FlutterBinaryMessenger) {
    let plugin = MacLocationPlugin()
    let method = FlutterMethodChannel(
      name: methodChannelName, binaryMessenger: messenger)
    method.setMethodCallHandler { call, result in
      plugin.handle(call, result: result)
    }
    let events = FlutterEventChannel(
      name: eventChannelName, binaryMessenger: messenger)
    events.setStreamHandler(plugin)
    instances.append(plugin)
  }

  private static var instances: [MacLocationPlugin] = []

  // MARK: - 方法调用

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(true)

    case "checkPermissions":
      result(isAuthorized)

    case "requestPermissions":
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        if self.isAuthorized {
          result(true)
        } else if self.manager.authorizationStatus == .notDetermined {
          // macOS 上该方法与 requestAlwaysAuthorization 行为一致，
          // 授予后状态即 authorizedAlways（见 isAuthorized 注释）
          self.manager.requestWhenInUseAuthorization()
          result(false)
        } else {
          // 已拒绝 / 受限：系统不会再弹窗，需用户到「系统设置 → 隐私与安全性 → 定位服务」开启
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

  /// macOS 上**不存在** `CLAuthorizationStatus.authorizedWhenInUse`
  /// （编译器报 "'authorizedWhenInUse' is unavailable in macOS"）。
  /// macOS 无论请求哪种授权，授予后状态都报 `authorizedAlways`，故只判定它。
  private var isAuthorized: Bool {
    manager.authorizationStatus == .authorizedAlways
  }

  private func start(mode: String) {
    self.mode = mode
    guard isAuthorized else {
      emitStatus("请授予定位权限…")
      return
    }
    // macOS 同样无法只选「纯 GPS」；统一最高精度，由系统决定定位来源
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.startUpdatingLocation()
    manager.requestLocation()
    emitStatus("系统定位中…")
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
    // 丢弃过期缓存定位（系统首次常回调「最后一个已知位置」）
    if abs(loc.timestamp.timeIntervalSinceNow) > 15 { return }
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
      "provider": "macos",
    ])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    emitStatus("定位失败: \(error.localizedDescription)")
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if isAuthorized {
      emitStatus("已获定位权限")
    } else if manager.authorizationStatus == .denied {
      emitStatus("定位权限被拒绝，可在「系统设置 → 隐私与安全性 → 定位服务」中开启")
    }
  }
}

// MARK: - 事件通道

extension MacLocationPlugin: FlutterStreamHandler {
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
