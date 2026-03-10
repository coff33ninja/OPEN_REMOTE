import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/device.dart';
import 'package:openremote_android/features/discovery/device_manager_screen.dart';

void main() {
  testWidgets('DeviceManagerScreen confirms before forgetting a device',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final deleted = <String>[];
    final device = Device(
      id: 'desk',
      name: 'Desk PC',
      host: '192.168.0.10',
      port: 9876,
      serviceType: '_openremote._tcp',
      accessToken: 'secret',
      wakeTarget: const WakeTarget(
        mac: 'AA:BB:CC:DD:EE:FF',
        broadcast: '192.168.0.255',
      ),
      networkRoutes: const <NetworkRoute>[
        NetworkRoute(
          host: '192.168.0.10',
          friendlyName: 'Wi-Fi',
          kind: NetworkTransportKind.wifi,
          wakeTarget: WakeTarget(
            mac: 'AA:BB:CC:DD:EE:FF',
            broadcast: '192.168.0.255',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceManagerScreen(
            devices: <Device>[device],
            selectedDevice: device,
            favoriteDeviceIds: const <String>{'desk'},
            recentDeviceIds: const <String>['desk'],
            statusMessage: 'Ready',
            preferLocalRoutes: true,
            onConnect: (Device device) async {},
            onPairUriSubmit: (String pairUri) async {},
            onToggleFavoriteDevice: (Device device) async {},
            onDeleteDevice: (Device device) async {
              deleted.add(device.id);
            },
            onRefreshDevices: () async {},
            onSetPreferredRoute: (Device device, NetworkRoute route) async {},
            onSetRoutePolicy: (Device device, String policy) async {},
            onPreferLocalRoutesChanged: (bool value) async {},
          ),
        ),
      ),
    );

    expect(find.text('Device manager'), findsOneWidget);
    expect(find.text('Desk PC'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Forget Desk PC?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Forget'));
    await tester.pumpAndSettle();

    expect(deleted, <String>['desk']);
  });

  testWidgets('DeviceManagerScreen shows route issue and policy details',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final device = Device(
      id: 'desk',
      name: 'Desk PC',
      host: '100.64.0.10',
      port: 9876,
      serviceType: '_openremote._tcp',
      routePolicy: DeviceRoutePolicy.rememberedFirst,
      preferredRouteHost: '100.64.0.10',
      lastSuccessfulRouteHost: '192.168.0.10',
      lastFailedRouteHost: '100.64.0.10',
      lastConnectedAt: DateTime.utc(2026, 3, 9, 16),
      lastFailedAt: DateTime.utc(2026, 3, 9, 17),
      lastFailureMessage: 'socket timeout',
      networkRoutes: const <NetworkRoute>[
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceManagerScreen(
            devices: <Device>[device],
            selectedDevice: device,
            favoriteDeviceIds: const <String>{},
            recentDeviceIds: const <String>[],
            statusMessage: 'Ready',
            preferLocalRoutes: true,
            onConnect: (Device device) async {},
            onPairUriSubmit: (String pairUri) async {},
            onToggleFavoriteDevice: (Device device) async {},
            onDeleteDevice: (Device device) async {},
            onRefreshDevices: () async {},
            onSetPreferredRoute: (Device device, NetworkRoute route) async {},
            onSetRoutePolicy: (Device device, String policy) async {},
            onPreferLocalRoutesChanged: (bool value) async {},
          ),
        ),
      ),
    );

    expect(find.text('Route issue'), findsOneWidget);
    expect(find.text('Prefer remembered'), findsOneWidget);
    expect(find.textContaining('Last route failure: socket timeout'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Details'));
    await tester.pumpAndSettle();

    expect(find.text('Last failed route: 100.64.0.10'), findsOneWidget);
    expect(find.text('socket timeout'), findsOneWidget);
    expect(find.text('Route policy'), findsOneWidget);
  });
}
