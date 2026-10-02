// 追踪包存储回归（对应 mod 的 Ic705TrackedPacketStoreTest）
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_protocol.dart';
import 'package:aprslocus/net/icom_lan_tracked_packet_store.dart';

Uint8List controlTemplate() => IcomLanControlCodec.encode(
      const IcomLanControlPacket(
        type: IcomLanControlCodec.typeNull,
        sequence: 0,
        senderId: 0x11223344,
        receiverId: 0x55667788,
      ),
    );

void main() {
  test('分配序号，并保留不可被外部改动的重传副本', () {
    var now = 100;
    final store = IcomLanTrackedPacketStore(monotonicMillis: () => now);
    final template = controlTemplate();

    final tracked = store.track(template);
    template[0] = 0;
    tracked.data[0] = 0;

    expect(tracked.sequence, 1);
    final cached = store.find(1)!;
    expect(IcomLanBytes.readUInt16Le(cached, 0x06), 1);
    expect(cached[0], IcomLanControlCodec.packetSize);
    expect(cached[1], 0);
  });

  test('过期清除，且序号在 16 位内回绕', () {
    var now = 100;
    final store = IcomLanTrackedPacketStore(
      initialSequence: 0xffff,
      retentionMillis: 10,
      monotonicMillis: () => now,
    );

    expect(store.track(controlTemplate()).sequence, 0xffff);
    expect(store.track(controlTemplate()).sequence, 0);
    now = 111;
    expect(store.find(0xffff), isNull);
    expect(store.find(0), isNull);
  });

  test('取出的字节改不动存储里的副本', () {
    final store = IcomLanTrackedPacketStore();
    final expected = store.track(controlTemplate()).data;
    final firstRead = store.find(1)!;
    for (var i = 0; i < firstRead.length; i++) {
      firstRead[i] = 0;
    }
    expect(store.find(1), expected);
  });

  test('本地发送失败后丢弃内容，但序号不回收', () {
    final store = IcomLanTrackedPacketStore();
    final failed = store.track(controlTemplate());
    store.discard(failed.sequence);

    expect(store.find(failed.sequence), isNull);
    expect(store.track(controlTemplate()).sequence, 2);
  });

  test('超出条数上限时丢最旧的', () {
    final store = IcomLanTrackedPacketStore(maxEntries: 3, retentionMillis: 60000);
    for (var i = 0; i < 5; i++) {
      store.track(controlTemplate());
    }
    expect(store.find(1), isNull);
    expect(store.find(2), isNull);
    expect(store.find(3), isNotNull);
    expect(store.find(5), isNotNull);
  });
}
