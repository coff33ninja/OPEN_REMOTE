import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/device.dart';
import 'package:openremote_android/core/models/pairing.dart';
import 'package:openremote_android/core/networking/pairing_host_resolver.dart';

void main() {
  test('pairingHostCandidates retries .local and discovered device hosts', () {
    const pairing = PairingPayload(
      host: 'kusanagi',
      port: 9876,
      token: 'abcd',
      deviceName: 'KUSANAGI',
      serviceType: '_openremote._tcp',
      websocketPath: '/ws',
    );

    final candidates = pairingHostCandidates(pairing, <Device>[
      const Device(
        id: '192.168.0.250:9876',
        name: 'KUSANAGI',
        host: '192.168.0.250',
        port: 9876,
        serviceType: '_openremote._tcp',
      ),
    ]);

    expect(
        candidates.map((PairingPayload item) => item.host).toList(), <String>[
      'kusanagi',
      'kusanagi.local',
      '192.168.0.250',
    ]);
  });

  test('pairingHostCandidates includes advertised network options first', () {
    const pairing = PairingPayload(
      host: 'kusanagi',
      port: 9876,
      token: 'abcd',
      deviceName: 'KUSANAGI',
      serviceType: '_openremote._tcp',
      websocketPath: '/ws',
      networkOptions: <PairingNetworkOption>[
        PairingNetworkOption(
          name: 'Wi-Fi',
          host: '192.168.0.250',
          wakeTarget: WakeTarget(
            mac: 'AA:BB:CC:DD:EE:FF',
            broadcast: '192.168.0.255',
          ),
        ),
        PairingNetworkOption(
          name: 'Tailscale',
          host: '100.64.0.10',
        ),
      ],
    );

    final candidates = pairingHostCandidates(pairing, const <Device>[]);

    expect(
        candidates.map((PairingPayload item) => item.host).toList(), <String>[
      '192.168.0.250',
      '100.64.0.10',
      'kusanagi',
      'kusanagi.local',
    ]);
    expect(candidates.first.wakeTarget?.broadcast, '192.168.0.255');
    expect(candidates[1].wakeTarget, isNull);
  });

  test('pairingHostCandidates does not append .local for literal IP hosts', () {
    const pairing = PairingPayload(
      host: '192.168.0.250',
      port: 9876,
      token: 'abcd',
      deviceName: 'KUSANAGI',
      serviceType: '_openremote._tcp',
      websocketPath: '/ws',
    );

    final candidates = pairingHostCandidates(pairing, const <Device>[]);

    expect(
        candidates.map((PairingPayload item) => item.host).toList(), <String>[
      '192.168.0.250',
    ]);
  });
}
