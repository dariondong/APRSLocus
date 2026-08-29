import 'aprs_base.dart';

/// 占位实现（无平台匹配时使用）
class AprsStub extends AprsConnector {
  @override
  Future<bool> connect() async => false;
  @override
  void send(String raw) {}
  @override
  void disconnect() {}
}

AprsConnector createAprs() => AprsStub();
