// IC-705 局域网链路工厂（条件导入）
//   - Android / iOS / Windows / Linux / macOS：真实实现（UDP + 协议栈）
//   - Web：占位（不支持）
import 'icom_lan_base.dart';
import 'icom_lan_settings.dart';
export 'icom_lan_base.dart';
export 'icom_lan_settings.dart';
import 'icom_lan_stub.dart' if (dart.library.io) 'icom_lan_io.dart' as impl;

IcomLanLink createIcomLanLink({required IcomLanConfig config}) =>
    impl.createIcomLanLink(config: config);
