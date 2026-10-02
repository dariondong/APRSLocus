/// WLAN / Icom LAN 的连接设置（平台中立，Web 也能引用）。
///
/// 这里只放**数据与校验**：真正的 UDP 实现在 `icom_lan_session.dart`
/// （仅 `dart:io` 平台可用），适配层在 `icom_lan_io.dart`。
library;

/// WLAN / Wi-Fi / Icom LAN 支持的电台型号。
enum WlanRadioModel {
  ic705(
    id: 'IC-705',
    displayName: 'Icom IC-705',
    defaultCivAddress: 0xA4,
    defaultPort: 50001,
    description: '便携全模式 QRP 电台（内置 Wi-Fi AP / STA）',
  ),
  ic9700(
    id: 'IC-9700',
    displayName: 'Icom IC-9700',
    defaultCivAddress: 0xA2,
    defaultPort: 50001,
    description: 'VHF/UHF/1.2GHz 全模式基站（以太网 LAN / Wi-Fi）',
  ),
  ic7610(
    id: 'IC-7610',
    displayName: 'Icom IC-7610',
    defaultCivAddress: 0x98,
    defaultPort: 50001,
    description: 'HF/50MHz 双接收 SDR 基站（以太网 LAN）',
  ),
  ic905(
    id: 'IC-905',
    displayName: 'Icom IC-905',
    defaultCivAddress: 0xAC,
    defaultPort: 50001,
    description: '144MHz~10GHz 全模式微波电台（以太网 LAN）',
  ),
  custom(
    id: 'CUSTOM',
    displayName: '自定义 / 其他 (Custom)',
    defaultCivAddress: 0xA4,
    defaultPort: 50001,
    description: '自定义 Icom 电台 CI-V 地址与端口',
  );

  const WlanRadioModel({
    required this.id,
    required this.displayName,
    required this.defaultCivAddress,
    this.defaultPort = 50001,
    required this.description,
  });

  final String id;
  final String displayName;
  final int defaultCivAddress;
  final int defaultPort;
  final String description;

  String get defaultCivHex =>
      '0x${defaultCivAddress.toRadixString(16).toUpperCase()}';

  static WlanRadioModel fromId(String? id) {
    if (id == null || id.trim().isEmpty) return WlanRadioModel.ic705;
    final clean = id.trim().toUpperCase();
    return WlanRadioModel.values.firstWhere(
      (m) => m.id.toUpperCase() == clean || m.name.toUpperCase() == clean,
      orElse: () => WlanRadioModel.ic705,
    );
  }
}

/// 会话配置。
class IcomLanConfig {
  const IcomLanConfig({
    required this.host,
    this.controlPort = 50001,
    required this.username,
    required this.password,
    this.clientName = 'APRSLocus',
    this.model = WlanRadioModel.ic705,
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

  /// 电台型号预置。
  final WlanRadioModel model;

  /// 电台 CI-V 地址（IC-705 = 0xA4，IC-9700 = 0xA2，IC-7610 = 0x98，IC-905 = 0xAC）。
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
    if (radioCivAddress <= 0 || radioCivAddress > 0xEF) {
      return 'CI-V 地址无效（应在 0x01..0xEF）';
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
    WlanRadioModel? model,
    int? radioCivAddress,
    int? controllerCivAddress,
  }) =>
      IcomLanConfig(
        host: host ?? this.host,
        controlPort: controlPort ?? this.controlPort,
        username: username ?? this.username,
        password: password ?? this.password,
        clientName: clientName ?? this.clientName,
        model: model ?? this.model,
        radioCivAddress: radioCivAddress ?? this.radioCivAddress,
        controllerCivAddress:
            controllerCivAddress ?? this.controllerCivAddress,
      );

  Map<String, dynamic> toJson() => {
        'host': host,
        'controlPort': controlPort,
        'username': username,
        'password': password,
        'clientName': clientName,
        'model': model.id,
        'radioCivAddress': radioCivAddress,
      };

  static IcomLanConfig fromJson(Object? json) {
    if (json is! Map) {
      return const IcomLanConfig(host: '', username: '', password: '');
    }
    int readInt(Object? value, int fallback) =>
        value is num ? value.toInt() : fallback;
    final model = WlanRadioModel.fromId(json['model']?.toString());
    return IcomLanConfig(
      host: json['host']?.toString() ?? '',
      controlPort: readInt(json['controlPort'], model.defaultPort),
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? 'APRSLocus',
      model: model,
      radioCivAddress:
          readInt(json['radioCivAddress'], model.defaultCivAddress),
    );
  }
}
