/// TNC 传输层抽象（平台无关部分）
///
/// 与 `net/aprs_base.dart` 的设计保持一致：本文件只放**接口与数据模型**，
/// 具体实现由 `net/tnc.dart` 条件导入
/// （Android/iOS → 原生蓝牙 SPP；Windows/Linux/macOS → 串口；Web → 占位）。
library;

/// 一个可绑定的 TNC 设备
///
/// - Android：`id` 为蓝牙 MAC 地址（经典 SPP / RFCOMM）
/// - Windows/Linux/macOS：`id` 为串口名（如 `COM5` / `/dev/ttyUSB0`）
class TncDevice {
  /// 平台标识：蓝牙 MAC 或串口名
  final String id;

  /// 展示名（蓝牙设备别名 / 串口友好名）
  final String name;

  /// 'bluetooth' | 'serial'
  final String kind;

  /// 是否已在系统里配对（串口恒为 true）
  final bool paired;

  const TncDevice({
    required this.id,
    this.name = '',
    this.kind = 'bluetooth',
    this.paired = true,
  });

  String get label => name.isEmpty ? id : '$name · $id';

  bool get isBluetooth => kind == 'bluetooth';

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'kind': kind, 'paired': paired};

  static TncDevice? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    return TncDevice(
      id: id,
      name: j['name']?.toString() ?? '',
      kind: j['kind']?.toString() ?? 'bluetooth',
      paired: j['paired'] == null ? true : j['paired'] == true,
    );
  }

  @override
  bool operator ==(Object other) => other is TncDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// TNC 链路传输接口
///
/// 只负责「把字节搬过去 / 搬回来」，KISS 组帧与 AX.25 编解码在 `kiss.dart`
/// 与 `TncLink` 里完成 —— 这样 Android 原生侧无需理解 APRS。
abstract class TncTransport {
  /// 当前是否已建立链路
  bool get connected;

  /// 平台能力探测（Web / 无蓝牙权限时为 false）
  Future<bool> get supported;

  /// 收到字节（KISS 原始流）
  void Function(List<int> bytes)? onBytes;

  /// 状态变化（用于日志与 UI 提示，文本为**未本地化**的调试串）
  void Function(String status)? onStatus;

  /// 链路被动断开（对端掉线 / 读循环结束）
  void Function()? onClosed;

  /// 列出可绑定设备
  Future<List<TncDevice>> listDevices();

  /// 请求平台权限（Android 12+ 的蓝牙运行时权限）。
  /// 返回是否已获得权限；无此概念的平台恒为 true。
  Future<bool> requestPermissions();

  /// 建立链路；返回 null 表示成功，否则返回错误描述
  Future<String?> connect(TncDevice device);

  /// 断开链路（幂等）
  Future<void> disconnect();

  /// 写入字节（调用方保证已完成 KISS 转义）
  void send(List<int> bytes);
}
