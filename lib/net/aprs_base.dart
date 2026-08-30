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
  void send(String raw);
  void disconnect();
}
