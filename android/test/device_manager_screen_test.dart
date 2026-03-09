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
            onConnect: (Device device) async {},
            onWake: (Device device) async {},
            onPairUriSubmit: (String pairUri) async {},
            onToggleFavoriteDevice: (Device device) async {},
            onDeleteDevice: (Device device) async {
              deleted.add(device.id);
            },
            onRefreshDevices: () async {},
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
}
