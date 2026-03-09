import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/device.dart';
import 'package:openremote_android/core/networking/wake_on_lan_client.dart';

void main() {
  const client = WakeOnLanClient();

  test('buildMagicPacket repeats the target MAC', () {
    final packet = client.buildMagicPacket('01:23:45:67:89:ab');

    expect(packet.length, 102);
    expect(packet.take(6), everyElement(0xFF));
    expect(packet.skip(6).take(6), <int>[1, 35, 69, 103, 137, 171]);
  });

  test('send transmits the magic packet to the configured host', () async {
    final listener =
        await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(listener.close);

    final completer = Completer<List<int>>();
    listener.listen((RawSocketEvent event) {
      if (event != RawSocketEvent.read || completer.isCompleted) {
        return;
      }

      final datagram = listener.receive();
      if (datagram != null) {
        completer.complete(datagram.data);
      }
    });

    const wakeTarget = WakeTarget(
      mac: '01:23:45:67:89:AB',
      broadcast: '127.0.0.1',
      port: 9,
    );
    await client.send(
      wakeTarget.copyWith(port: listener.port),
    );

    final received = await completer.future.timeout(const Duration(seconds: 2));
    expect(received, client.buildMagicPacket(wakeTarget.mac));
  });
}
