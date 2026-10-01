/// IC-705 / Icom LAN 的连接设置（平台中立，Web 也能引用）。
///
/// 这里只放**数据与校验**：真正的 UDP 实现在 `icom_lan_session.dart`
/// （仅 `dart:io` 平台可用），适配层在 `icom_lan_io.dart`。
library;

/// 会话配置。
class IcomLanConfig {
  const IcomLanConfig({
    required this.host,
    this.controlPort = 50001,
    required this.username,
    required this.password,
    this.clientName = 'APRSLocus',
    this.radioCivAddress = 0xa4,
    this.controllerCivAddress = 0xe0,
    this.usernameMaxLength = 16,
    this.passwordMaxLength = 16,
  });

  /// 电台 IP（局域网地址，如 192.168.1.143）。
  final String host;

  /// 控制端口；CI-V 与音频使用 controlPort+1 / controlPort+2。
  final int controlPort;

  /// 电台里配置的 Network User 名（明文，发送前用 passCode 编码）。
  final String username;

  /// 电台里配置的 Network User 密码。
  final String password;

  /// 客户端名（电台用它区分"自己的流"和"别人的流"）。
  final String clientName;

  /// 电台 CI-V 地址（IC-705 = 0xA4）。
  final int radioCivAddress;

  /// 本机 CI-V 地址（默认 0xE0）。
  final int controllerCivAddress;

  final int usernameMaxLength;
  final int passwordMaxLength;

  /// 校验配置；返回 null 表示合法，否则返回可直接展示的错误描述。
  String? validate() {
    if (host.trim().isEmpty) return '电台 IP 不能为空';
    if (controlPort <= 0 || controlPort > 0xffff - 2) {
      return '控制端口必须在 1..65533';
    }
    if (username.trim().isEmpty) {
      return '用户名不能为空（填电台里配置的 Network User 名）';
    }
    if (username.length > usernameMaxLength) {
      return '用户名最长 $usernameMaxLength 字符';
    }
    if (password.length > passwordMaxLength) {
      return '密码最长 $passwordMaxLength 字符';
    }
    if (clientName.isEmpty || clientName.length > 16) {
      return '客户端名必须在 1..16 字符';
    }
    var asciiOnly = true;
    for (final text in [username, password, clientName]) {
      for (final code in text.codeUnits) {
        if (code > 0x7f) asciiOnly = false;
      }
    }
    if (!asciiOnly) return '用户名/密码/客户端名只能是 ASCII 字符';
    return null;
  }

  IcomLanConfig copyWith({
    String? host,
    int? controlPort,
    String? username,
    String? password,
    String? clientName,
  }) =>
      IcomLanConfig(
        host: host ?? this.host,
        controlPort: controlPort ?? this.controlPort,
        username: username ?? this.username,
        password: password ?? this.password,
        clientName: clientName ?? this.clientName,
        radioCivAddress: radioCivAddress,
        controllerCivAddress: controllerCivAddress,
      );

  Map<String, dynamic> toJson() => {
        'host': host,
        'controlPort': controlPort,
        'username': username,
        'password': password,
        'clientName': clientName,
      };

  static IcomLanConfig fromJson(Object? json) {
    if (json is! Map) {
      return const IcomLanConfig(host: '', username: '', password: '');
    }
    int readInt(Object? value, int fallback) =>
        value is num ? value.toInt() : fallback;
    return IcomLanConfig(
      host: json['host']?.toString() ?? '',
      controlPort: readInt(json['controlPort'], 50001),
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? 'APRSLocus',
    );
  }
}
