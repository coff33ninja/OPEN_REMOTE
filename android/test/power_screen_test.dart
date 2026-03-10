import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/command.dart';
import 'package:openremote_android/core/models/device.dart';
import 'package:openremote_android/features/power_remote/power_screen.dart';

void main() {
  Device buildDevice({bool withWakeRoute = false}) {
    final route = withWakeRoute
        ? NetworkRoute(
            host: '192.168.0.10',
            kind: NetworkTransportKind.wifi,
            wakeTarget: const WakeTarget(
              mac: 'AA:BB:CC:DD:EE:FF',
              broadcast: '192.168.0.255',
            ),
          )
        : const NetworkRoute(host: '192.168.0.10');

    return Device(
      id: 'desk',
      name: 'Desk PC',
      host: '192.168.0.10',
      port: 9876,
      serviceType: '_openremote._tcp',
      accessToken: 'secret',
      networkRoutes: <NetworkRoute>[route],
      preferredRouteHost: route.host,
    );
  }

  testWidgets('PowerScreen sends wake when offline',
      (WidgetTester tester) async {
    final sent = <CommandEnvelope>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PowerScreen(
            device: buildDevice(withWakeRoute: true),
            isConnected: false,
            onSend: (CommandEnvelope command) async {
              sent.add(command);
            },
          ),
        ),
      ),
    );

    expect(find.text('Wake device'), findsOneWidget);

    await tester.tap(find.text('Wake'));
    await tester.pump();

    expect(sent, isNotEmpty);
    expect(sent.last.commandName, 'power_wake');
  });

  testWidgets('PowerScreen sends online power commands',
      (WidgetTester tester) async {
    final sent = <CommandEnvelope>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PowerScreen(
            device: buildDevice(),
            isConnected: true,
            onSend: (CommandEnvelope command) async {
              sent.add(command);
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Restart'));
    await tester.pump();
    await tester.tap(find.text('Shutdown'));
    await tester.pump();
    await tester.tap(find.text('Sleep'));
    await tester.pump();

    expect(
        sent.map((CommandEnvelope cmd) => cmd.commandName).toList(),
        containsAll(
            <String>['power_restart', 'power_shutdown', 'power_sleep']));
  });
}
