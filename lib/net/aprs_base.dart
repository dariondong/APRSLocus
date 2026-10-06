/// APRS-IS 连接器抽象
abstract class AprsConnector {
  bool connected = false;
  String server = 'rotate.aprs2.net';
  int port = 14580;
  String? wsUrl;
  String callsign = 'BV2AAA';
  String passcode = '-1';
  String filter = 'r/39.90/116.40/300';
  int rxCount = 0;
  void Function(String line)? onLine;
  void Function()? onDisconnected;

  Future<bool> connect();
  /// 发送一行 TNC2。返回 false = 这帧**没写进链路**（socket 没了 / 写异常）。
  ///
  /// 回传成败是给「状态帧自愈」用的：状态报文是一对（内置 CONNECT + 自定义
  /// 状态），第二帧被吞掉就会让用户自定义状态永远显示不出来。上层据此决定
  /// 要不要重发，而不是像以前那样一律当成发出去了。
  bool send(String raw);
  void disconnect();
}
