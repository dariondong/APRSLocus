import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // 注册定位通道（原生 GPS）。
    //
    // 此前 iOS 侧未实现该通道，而 Dart 端 iOS 走的是原生分支
    // → checkPermissions 抛 MissingPluginException 被当作「未授权」，
    // 表现为一直停在「请授予定位权限…」，即用户反馈的「iOS 无法定位」。
    //
    // 这里用 applicationRegistrar 的 messenger：按引擎头文件说明，
    // 它是面向「应用级方法通道」的入口（FlutterImplicitEngineBridge
    // 的 applicationRegistrar 属性，专为注册应用级通道/服务而设）。
    LocationPlugin.register(with: engineBridge.applicationRegistrar.messenger())
  }
}
