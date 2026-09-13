import 'tnc_base.dart';

/// 占位实现（Web 等无匹配平台）
class TncStub implements TncTransport {
  List<int> Function()? _noop;

  @override
  bool get connected => false;

  @override
  Future<bool> get supported async => false;

  @override
  void Function(List<int> bytes)? onBytes;

  @override
  void Function(String status)? onStatus;

  @override
  void Function()? onClosed;

  @override
  Future<List<TncDevice>> listDevices() async => const [];

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<String?> connect(TncDevice device) async => 'unsupported';

  @override
  Future<void> disconnect() async {}

  @override
  void send(List<int> bytes) {
    _noop?.call();
  }
}

TncTransport createTncTransport() => TncStub();
