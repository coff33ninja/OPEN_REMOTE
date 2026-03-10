import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/device.dart';
import 'package:openremote_android/features/discovery/device_list.dart';

void main() {
  testWidgets('DeviceListScreen shows pair action for unpaired devices',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final device = Device(
      id: 'desk',
      name: 'Desk PC',
      host: '192.168.0.10',
      port: 9876,
      serviceType: '_openremote._tcp',
      networkRoutes: const <NetworkRoute>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceListScreen(
            devices: <Device>[device],
            selectedDevice: null,
            favoriteDeviceIds: const <String>{},
            recentDeviceIds: const <String>[],
            statusMessage: 'Ready',
            isConnected: false,
            pendingSharedCount: 0,
            onConnect: (Device device) async {},
            onPairUriSubmit: (String pairUri) async {},
            onToggleFavoriteDevice: (Device device) async {},
            onRefreshDevices: () async {},
            onOpenDeviceManager: () {},
          ),
        ),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Pair'), findsWidgets);
    final pairFirst = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Pair first').first,
    );
    expect(pairFirst.onPressed, isNull);
  });
}
