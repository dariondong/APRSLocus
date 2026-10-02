// SPDX-License-Identifier: GPL-2.0-or-later
// See LICENSING.md: this file is additionally available under GPL-2.0-or-later.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_android_network.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IcomLanAndroidNetwork', () {
    const channel = MethodChannel('test_ic705_network');

    test('parses available radio network response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'findRadioNetwork') {
          return {
            'status': 'AVAILABLE',
            'networkHandle': 12345678,
            'ipv4Address': '192.168.249.2',
          };
        }
        return null;
      });

      final info = await IcomLanAndroidNetwork.findRadioNetwork(
        overrideChannel: channel,
      );
      expect(info, isNotNull);
      expect(info!.isAvailable, isTrue);
      expect(info.status, equals('AVAILABLE'));
      expect(info.networkHandle, equals(12345678));
      expect(info.ipv4Address, equals('192.168.249.2'));
    });

    test('handles not found network response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'findRadioNetwork') {
          return {
            'status': 'NOT_FOUND',
            'networkHandle': null,
            'ipv4Address': null,
          };
        }
        return null;
      });

      final info = await IcomLanAndroidNetwork.findRadioNetwork(
        overrideChannel: channel,
      );
      expect(info, isNotNull);
      expect(info!.isAvailable, isFalse);
      expect(info.status, equals('NOT_FOUND'));
      expect(info.networkHandle, isNull);
      expect(info.ipv4Address, isNull);
    });

    test('handles channel error gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'NET_ERROR', message: 'Failed');
      });

      final info = await IcomLanAndroidNetwork.findRadioNetwork(
        overrideChannel: channel,
      );
      expect(info, isNull);
    });
  });
}
