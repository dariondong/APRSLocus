// SPDX-License-Identifier: GPL-2.0-or-later
// See LICENSING.md: this file is additionally available under GPL-2.0-or-later.

library;

import 'dart:io';
import 'dart:typed_data';

export 'icom_lan_rx_session.dart';
export 'icom_lan_rx_session_types.dart';
export 'icom_lan_settings.dart';

import 'icom_lan_rx_session.dart';

/// 收到的 UDP 数据报（为端到端测试与接口兼容性保留）。
class IcomLanDatagram {
  const IcomLanDatagram(this.data, this.address, this.port);

  final Uint8List data;
  final InternetAddress address;
  final int port;
}

/// UDP 通道抽象接口（为测试与适配保留）。
abstract class IcomLanDatagramSocket {
  int get localPort;
  void Function(IcomLanDatagram datagram)? onDatagram;
  void Function(Object error)? onError;

  void send(Uint8List data, InternetAddress to, int port);
  void close();
}

/// 通道工厂类型定义。
typedef IcomLanSocketFactory = Future<IcomLanDatagramSocket> Function(
    int localPort);

/// 统一类型别名：IcomLanSession 映射为直译版 IcomLanRxSession。
typedef IcomLanSession = IcomLanRxSession;
