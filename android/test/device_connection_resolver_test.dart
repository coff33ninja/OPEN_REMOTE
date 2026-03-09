import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/device.dart';
import 'package:openremote_android/core/networking/device_connection_resolver.dart';

void main() {
  test('deviceConnectionCandidates prefers local routes when enabled', () {
    const device = Device(
      id: 'desk',
      name: 'Desk PC',
      host: '100.64.0.10',
      port: 9876,
      serviceType: '_openremote._tcp',
      preferredRouteHost: '100.64.0.10',
      networkRoutes: <NetworkRoute>[
        NetworkRoute(
          host: '192.168.0.10',
          friendlyName: 'Wi-Fi',
          kind: NetworkTransportKind.wifi,
          wakeTarget: WakeTarget(
            mac: 'AA:BB:CC:DD:EE:FF',
            broadcast: '192.168.0.255',
          ),
        ),
        NetworkRoute(
          host: '100.64.0.10',
          friendlyName: 'Tailscale',
          kind: NetworkTransportKind.vpn,
          preferred: true,
          isVirtual: true,
        ),
      ],
    );

    final candidates = deviceConnectionCandidates(
      device,
      preferLocalRoutes: true,
    );

    expect(
      candidates.map((NetworkRoute route) => route.host).toList(),
      <String>['192.168.0.10', '100.64.0.10'],
    );
  });
}
