// SPDX-License-Identifier: GPL-2.0-or-later
// See LICENSING.md: this file is additionally available under GPL-2.0-or-later.

library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'icom_lan_rx_session_types.dart' show IcomLanChannelRole;

/// 收到的 UDP 数据报（数据 + 发送方来源）。
class IcomLanReceivedDatagram {
  const IcomLanReceivedDatagram({
    required this.data,
    required this.source,
  });

  final Uint8List data;
  final IcomLanSocketAddress source;

  @override
  String toString() =>
      'IcomLanReceivedDatagram(${data.length} bytes from $source)';
}

/// UDP 套接字网络地址（IP + 端口）。
class IcomLanSocketAddress {
  const IcomLanSocketAddress(this.address, this.port);

  final InternetAddress address;
  final int port;

  @override
  bool operator ==(Object other) =>
      other is IcomLanSocketAddress &&
      other.address.address == address.address &&
      other.port == port;

  @override
  int get hashCode => Object.hash(address.address, port);

  @override
  String toString() => '${address.address}:$port';
}

/// 底层数据报套接字抽象（便于单元测试注入 fake socket）。
abstract class IcomLanDatagramSocket {
  int get localPort;
  InternetAddress? get localAddress;
  bool get isClosed;

  void send(Uint8List data, InternetAddress address, int port);
  void close();
  void listen({
    required void Function(Uint8List data, IcomLanSocketAddress source) onDatagram,
    required void Function(Object error) onError,
    void Function()? onDone,
  });
}

/// 默认基于 `dart:io` 的 [RawDatagramSocket] 实现。
class DefaultIcomLanDatagramSocket implements IcomLanDatagramSocket {
  DefaultIcomLanDatagramSocket(this._socket);

  final RawDatagramSocket _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  bool _isClosed = false;

  @override
  int get localPort => _socket.port;

  @override
  InternetAddress? get localAddress => _socket.address;

  @override
  bool get isClosed => _isClosed;

  @override
  void send(Uint8List data, InternetAddress address, int port) {
    if (_isClosed) throw StateError('Socket is closed');
    _socket.send(data, address, port);
  }

  @override
  void close() {
    if (_isClosed) return;
    _isClosed = true;
    _subscription?.cancel();
    _subscription = null;
    _socket.close();
  }

  @override
  void listen({
    required void Function(Uint8List data, IcomLanSocketAddress source) onDatagram,
    required void Function(Object error) onError,
    void Function()? onDone,
  }) {
    _subscription = _socket.listen(
      (event) {
        if (event == RawSocketEvent.read) {
          while (true) {
            final datagram = _socket.receive();
            if (datagram == null) break;
            onDatagram(
              Uint8List.fromList(datagram.data),
              IcomLanSocketAddress(datagram.address, datagram.port),
            );
          }
        }
      },
      onError: (Object error) => onError(error),
      onDone: onDone,
      cancelOnError: false,
    );
  }
}

/// 套接字工厂函数类型。
typedef IcomLanDatagramSocketFactory = Future<IcomLanDatagramSocket> Function(
  IcomLanSocketAddress localAddress,
);

/// 默认数据报套接字工厂。
Future<IcomLanDatagramSocket> defaultIcomLanDatagramSocketFactory(
  IcomLanSocketAddress localAddress,
) async {
  final socket = await RawDatagramSocket.bind(
    localAddress.address,
    localAddress.port,
  );
  socket.broadcastEnabled = true;
  return DefaultIcomLanDatagramSocket(socket);
}

/// IC-705 数据报通道接口。
abstract class IcomLanDatagramChannel {
  IcomLanChannelRole get role;
  bool get isOpen;
  InternetAddress? get boundLocalAddress;
  int get localPort;
  IcomLanSocketAddress? get remoteEndpoint;

  Future<void> open();

  /// 设置发送目标。当 [lockSource] 为 false 时套接字不锁定来源，
  /// 允许广播探测目标接收电台发来的单播回复。
  void setRemoteEndpoint(
    IcomLanSocketAddress? endpoint, {
    bool lockSource = true,
  });

  void send(Uint8List data);
  Future<void> close();
}

/// 数据报通道工厂函数类型。
typedef IcomLanDatagramChannelFactory = IcomLanDatagramChannel Function({
  required IcomLanChannelRole role,
  required IcomLanSocketAddress localAddress,
  required void Function(IcomLanReceivedDatagram datagram) onDatagram,
  void Function(Object error)? onError,
});

/// One UDP channel used by the Icom LAN control, CI-V, or audio stream.
///
/// Packet encoding, sequence numbers, retries, and reconnect policy intentionally
/// belong to the session layer. This class only owns socket lifetime and source
/// endpoint filtering. Logical source locking is enforced upon receiving.
class IcomLanUdpChannel implements IcomLanDatagramChannel {
  IcomLanUdpChannel({
    required this.role,
    IcomLanSocketAddress? localAddress,
    IcomLanDatagramSocketFactory? socketFactory,
    required this.onDatagram,
    this.onError,
  })  : localAddress = localAddress ??
            IcomLanSocketAddress(InternetAddress.anyIPv4, 0),
        _socketFactory =
            socketFactory ?? defaultIcomLanDatagramSocketFactory;

  @override
  final IcomLanChannelRole role;
  final IcomLanSocketAddress localAddress;
  final IcomLanDatagramSocketFactory _socketFactory;
  final void Function(IcomLanReceivedDatagram datagram) onDatagram;
  final void Function(Object error)? onError;

  IcomLanDatagramSocket? _socket;
  IcomLanSocketAddress? _configuredRemoteEndpoint;
  bool _remoteSourceLocked = false;

  @override
  bool get isOpen => _socket != null && !_socket!.isClosed;

  @override
  int get localPort => _socket?.localPort ?? 0;

  @override
  InternetAddress? get boundLocalAddress => _socket?.localAddress;

  @override
  IcomLanSocketAddress? get remoteEndpoint => _configuredRemoteEndpoint;

  @override
  Future<void> open() async {
    if (_socket != null) {
      throw StateError('$role UDP channel is already open');
    }
    final createdSocket = await _socketFactory(localAddress);
    _socket = createdSocket;
    createdSocket.listen(
      onDatagram: (data, source) {
        if (_socket != createdSocket || createdSocket.isClosed) return;
        // CI-V and audio sockets are opened before the control channel has
        // negotiated their radio endpoints. Ignore traffic until then.
        final expectedSource = _configuredRemoteEndpoint;
        if (expectedSource == null) return;
        if (_remoteSourceLocked && source != expectedSource) return;
        try {
          onDatagram(
            IcomLanReceivedDatagram(
              data: data,
              source: source,
            ),
          );
        } catch (error) {
          onError?.call(
            Exception('$role datagram callback failed: $error'),
          );
        }
      },
      onError: (error) {
        if (_socket == createdSocket && !createdSocket.isClosed) {
          onError?.call(error);
        }
      },
      onDone: () {
        if (_socket == createdSocket) {
          _socket = null;
        }
      },
    );
  }

  /// Changes the send target and, when requested, the accepted source endpoint.
  @override
  void setRemoteEndpoint(
    IcomLanSocketAddress? endpoint, {
    bool lockSource = true,
  }) {
    _configuredRemoteEndpoint = endpoint;
    _remoteSourceLocked = endpoint != null && lockSource;
  }

  @override
  void send(Uint8List data) {
    final currentSocket = _socket;
    if (currentSocket == null) {
      throw StateError('$role UDP channel is not open');
    }
    if (currentSocket.isClosed) {
      throw StateError('$role UDP channel is closed');
    }
    final target = _configuredRemoteEndpoint;
    if (target == null) {
      throw StateError('$role remote endpoint is not configured');
    }
    currentSocket.send(data, target.address, target.port);
  }

  @override
  Future<void> close() async {
    final currentSocket = _socket;
    _socket = null;
    currentSocket?.close();
  }
}
