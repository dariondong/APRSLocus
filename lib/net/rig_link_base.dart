/// 电台控制（Hamlib）的客户端抽象（平台无关部分）。
///
/// 这里**不链接 libhamlib**：hamlib 自带一个常驻进程 `rigctld`，本地 TCP 上
/// 一行一条命令（`f` 读频率、`F` 设频率、`T 1` 按 PTT）。所以这一层只是个
/// 文本协议客户端，实现见 `net/rig_link_io.dart`；Web 没有 TCP，走占位实现。
library;

/// 一次读回来的电台状态。
class RigStatus {
  /// 频率（Hz）。读不到就是 null。
  final int? freqHz;

  /// 模式（hamlib 的写法：FM / USB / AM …）。读不到就是空串。
  final String mode;

  /// 电台自报的型号信息（`rigctld` 的 `get_info`），可能为空。
  final String info;

  const RigStatus({this.freqHz, this.mode = '', this.info = ''});
}

/// rigctld 客户端接口。
abstract class RigLink {
  /// 现在是否连着 rigctld。
  bool get connected;

  /// 上一次失败的原因（给界面看，未本地化）。
  String get lastError;

  /// 连上 host:port 上的 rigctld。
  Future<bool> connect(String host, int port);

  /// 断开。只关 socket，不往电台发任何命令。
  void disconnect();

  /// 读型号、频率、模式。
  Future<RigStatus?> status();

  Future<bool> setFreq(int hz);

  Future<bool> setMode(String mode);

  Future<bool> setPtt(bool on);
}

/// 没有 TCP 的平台（Web）：一律当能力不存在，不抛异常。
class RigStub implements RigLink {
  @override
  bool get connected => false;

  @override
  String get lastError => 'unsupported';

  @override
  Future<bool> connect(String host, int port) async => false;

  @override
  void disconnect() {}

  @override
  Future<RigStatus?> status() async => null;

  @override
  Future<bool> setFreq(int hz) async => false;

  @override
  Future<bool> setMode(String mode) async => false;

  @override
  Future<bool> setPtt(bool on) async => false;
}
