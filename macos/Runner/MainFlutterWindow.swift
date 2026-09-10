import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 注册定位通道（系统定位服务）。
    // 此前 macOS 侧未实现该通道，Dart 端只能退回 IP 网络定位（城市级、误差极大），
    // 且沙盒缺少出网权限时连 IP 定位都拿不到，表现为「mac 无法定位」。
    MacLocationPlugin.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
