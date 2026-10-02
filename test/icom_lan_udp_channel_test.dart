// SPDX-License-Identifier: GPL-2.0-or-later
// See LICENSING.md: this file is additionally available under GPL-2.0-or-later.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_rx_session_types.dart';
import 'package:aprslocus/net/icom_lan_udp_channel.dart';

void main() {
  group('IcomLanUdpChannel', () {
    test('sendsAndReceivesThroughOneConnectedEndpoint', () async {
      final loopback = InternetAddress.loopbackIPv4;
      final peer = await RawDatagramSocket.bind(loopback, 0);
      final receivedCompleter = Completer<IcomLanReceivedDatagram>();

      final channel = IcomLanUdpChannel(
        role: IcomLanChannelRole.audio,
        localAddress: IcomLanSocketAddress(loopback, 0),
        onDatagram: (datagram) {
          if (!receivedCompleter.isCompleted) {
            receivedCompleter.complete(datagram);
          }
        },
      );

      try {
        final peerEndpoint = IcomLanSocketAddress(loopback, peer.port);
        channel.setRemoteEndpoint(peerEndpoint);
        await channel.open();
        expect(channel.isOpen, isTrue);

        final outbound = Uint8List.fromList([0x01, 0x02, 0x03]);
        channel.send(outbound);

        final peerReceivedCompleter = Completer<Uint8List>();
        peer.listen((event) {
          if (event == RawSocketEvent.read) {
            final d = peer.receive();
            if (d != null && !peerReceivedCompleter.isCompleted) {
              peerReceivedCompleter.complete(Uint8List.fromList(d.data));
            }
          }
        });

        final peerReceived = await peerReceivedCompleter.future.timeout(
          const Duration(seconds: 2),
        );
        expect(peerReceived, equals(outbound));

        final inbound = Uint8List.fromList([0x11, 0x12]);
        peer.send(inbound, loopback, channel.localPort);

        final delivered = await receivedCompleter.future.timeout(
          const Duration(seconds: 2),
        );
        expect(delivered.data, equals(inbound));
        expect(delivered.source.port, equals(peer.port));
      } finally {
        await channel.close();
        peer.close();
      }

      expect(channel.isOpen, isFalse);
    });

    test(
        'unconnectedDiscoveryAcceptsUnicastReplyBeforeLockingItsSource',
        () async {
      final loopback = InternetAddress.loopbackIPv4;
      final discoveryTarget = await RawDatagramSocket.bind(loopback, 0);
      final replySource = await RawDatagramSocket.bind(loopback, 0);

      final received = <IcomLanReceivedDatagram>[];
      final firstReplyCompleter = Completer<void>();
      final secondReplyCompleter = Completer<void>();

      final channel = IcomLanUdpChannel(
        role: IcomLanChannelRole.control,
        localAddress: IcomLanSocketAddress(loopback, 0),
        onDatagram: (datagram) {
          received.add(datagram);
          if (received.length == 1 && !firstReplyCompleter.isCompleted) {
            firstReplyCompleter.complete();
          } else if (received.length == 2 &&
              !secondReplyCompleter.isCompleted) {
            secondReplyCompleter.complete();
          }
        },
      );

      try {
        final discoveryEndpoint =
            IcomLanSocketAddress(loopback, discoveryTarget.port);
        channel.setRemoteEndpoint(discoveryEndpoint, lockSource: false);
        await channel.open();

        final discovery = Uint8List.fromList([0x21, 0x22]);
        channel.send(discovery);

        final discoveryReceivedCompleter = Completer<Uint8List>();
        discoveryTarget.listen((event) {
          if (event == RawSocketEvent.read) {
            final d = discoveryTarget.receive();
            if (d != null && !discoveryReceivedCompleter.isCompleted) {
              discoveryReceivedCompleter.complete(Uint8List.fromList(d.data));
            }
          }
        });

        final targetReceived =
            await discoveryReceivedCompleter.future.timeout(
          const Duration(seconds: 2),
        );
        expect(targetReceived, equals(discovery));

        final unicastReply = Uint8List.fromList([0x31, 0x32]);
        replySource.send(unicastReply, loopback, channel.localPort);

        await firstReplyCompleter.future.timeout(
          const Duration(seconds: 2),
        );
        final discoveredSource = received.single.source;
        expect(discoveredSource.port, equals(replySource.port));

        channel.setRemoteEndpoint(discoveredSource, lockSource: true);
        expect(channel.remoteEndpoint, equals(discoveredSource));

        // Wrong source should be ignored by locked channel
        final wrongSource = Uint8List.fromList([0x41]);
        discoveryTarget.send(wrongSource, loopback, channel.localPort);

        // Locked reply from replySource should be accepted
        final lockedReply = Uint8List.fromList([0x51]);
        replySource.send(lockedReply, loopback, channel.localPort);

        await secondReplyCompleter.future.timeout(
          const Duration(seconds: 2),
        );

        final receivedPayloads = received.map((r) => r.data).toList();
        expect(receivedPayloads.length, equals(2));
        expect(receivedPayloads[0], equals(unicastReply));
        expect(receivedPayloads[1], equals(lockedReply));

        // Outbound send to locked endpoint
        final lockedReceivedCompleter = Completer<Uint8List>();
        replySource.listen((event) {
          if (event == RawSocketEvent.read) {
            final d = replySource.receive();
            if (d != null && !lockedReceivedCompleter.isCompleted) {
              lockedReceivedCompleter.complete(Uint8List.fromList(d.data));
            }
          }
        });

        final lockedOutbound = Uint8List.fromList([0x61, 0x62]);
        channel.send(lockedOutbound);

        final replyReceived =
            await lockedReceivedCompleter.future.timeout(
          const Duration(seconds: 2),
        );
        expect(replyReceived, equals(lockedOutbound));
      } finally {
        await channel.close();
        discoveryTarget.close();
        replySource.close();
      }
    });

    test('dropsInboundDatagramUntilRemoteEndpointIsConfigured', () async {
      final loopback = InternetAddress.loopbackIPv4;
      final sender = await RawDatagramSocket.bind(loopback, 0);
      final acceptedCompleter = Completer<IcomLanReceivedDatagram>();

      final channel = IcomLanUdpChannel(
        role: IcomLanChannelRole.civ,
        localAddress: IcomLanSocketAddress(loopback, 0),
        onDatagram: (datagram) {
          if (!acceptedCompleter.isCompleted) {
            acceptedCompleter.complete(datagram);
          }
        },
      );

      try {
        await channel.open();

        final ignored = Uint8List.fromList([0x71]);
        sender.send(ignored, loopback, channel.localPort);

        // Allow some time for unconfigured endpoint to ignore it
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(acceptedCompleter.isCompleted, isFalse);

        final senderEndpoint = IcomLanSocketAddress(loopback, sender.port);
        channel.setRemoteEndpoint(senderEndpoint, lockSource: false);

        final delivered = Uint8List.fromList([0x72]);
        sender.send(delivered, loopback, channel.localPort);

        final result = await acceptedCompleter.future.timeout(
          const Duration(seconds: 2),
        );
        expect(result.data, equals(delivered));
      } finally {
        await channel.close();
        sender.close();
      }
    });

    test('closeIsIdempotentAndUnblocksReceive', () async {
      final channel = IcomLanUdpChannel(
        role: IcomLanChannelRole.control,
        localAddress:
            IcomLanSocketAddress(InternetAddress.loopbackIPv4, 0),
        onDatagram: (_) {},
      );
      await channel.open();
      expect(channel.isOpen, isTrue);

      await channel.close();
      await channel.close();

      expect(channel.isOpen, isFalse);
    });

    test('sendThrowsWhenNotOpenOrNotConfigured', () async {
      final channel = IcomLanUdpChannel(
        role: IcomLanChannelRole.control,
        onDatagram: (_) {},
      );

      expect(
        () => channel.send(Uint8List.fromList([1, 2, 3])),
        throwsStateError,
      );

      await channel.open();
      expect(
        () => channel.send(Uint8List.fromList([1, 2, 3])),
        throwsStateError, // remote endpoint not configured
      );

      await channel.close();
    });

    test('onDatagramCallbackErrorCallsOnError', () async {
      final loopback = InternetAddress.loopbackIPv4;
      final sender = await RawDatagramSocket.bind(loopback, 0);
      final errorCompleter = Completer<Object>();

      final channel = IcomLanUdpChannel(
        role: IcomLanChannelRole.civ,
        localAddress: IcomLanSocketAddress(loopback, 0),
        onDatagram: (_) {
          throw StateError('callback explosion');
        },
        onError: (err) {
          if (!errorCompleter.isCompleted) {
            errorCompleter.complete(err);
          }
        },
      );

      try {
        final senderEndpoint = IcomLanSocketAddress(loopback, sender.port);
        channel.setRemoteEndpoint(senderEndpoint);
        await channel.open();

        sender.send(Uint8List.fromList([1]), loopback, channel.localPort);

        final error = await errorCompleter.future.timeout(
          const Duration(seconds: 2),
        );
        expect(error.toString(), contains('callback failed'));
      } finally {
        await channel.close();
        sender.close();
      }
    });
  });
}
