import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/agent_data.dart';
import 'package:openremote_android/core/models/device.dart';
import 'package:openremote_android/core/networking/api_client.dart';
import 'package:openremote_android/features/services/services_screen.dart';

void main() {
  Device buildDevice() {
    return const Device(
      id: 'desk',
      name: 'Desk PC',
      host: '192.168.0.10',
      port: 9876,
      serviceType: '_openremote._tcp',
      accessToken: 'secret',
    );
  }

  testWidgets('ServicesScreen loads and filters services',
      (WidgetTester tester) async {
    final apiClient = _FakeApiClient(
      services: const <AgentService>[
        AgentService(
          name: 'Spooler',
          displayName: 'Print Spooler',
          status: 'Running',
          statusReason: '',
          startType: 'Automatic',
        ),
        AgentService(
          name: 'wuauserv',
          displayName: 'Windows Update',
          status: 'Stopped',
          statusReason: '',
          startType: 'Manual',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServicesScreen(
            enabled: true,
            device: buildDevice(),
            apiClient: apiClient,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.text('Print Spooler'), findsOneWidget);
    expect(find.text('Windows Update'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'update');
    await tester.pumpAndSettle();

    expect(find.text('Print Spooler'), findsNothing);
    expect(find.text('Windows Update'), findsOneWidget);
  });

  testWidgets('ServicesScreen triggers service actions',
      (WidgetTester tester) async {
    final apiClient = _FakeApiClient(
      services: const <AgentService>[
        AgentService(
          name: 'Spooler',
          displayName: 'Print Spooler',
          status: 'Running',
          statusReason: '',
          startType: 'Automatic',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServicesScreen(
            enabled: true,
            device: buildDevice(),
            apiClient: apiClient,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(apiClient.restartCalls, contains('Spooler'));
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient({required List<AgentService> services}) : _services = services;

  final List<AgentService> _services;
  final List<String> startCalls = <String>[];
  final List<String> stopCalls = <String>[];
  final List<String> restartCalls = <String>[];

  @override
  Future<List<AgentService>> fetchServices(Device device) async {
    return _services;
  }

  @override
  Future<void> startService(Device device, String name) async {
    startCalls.add(name);
  }

  @override
  Future<void> stopService(Device device, String name) async {
    stopCalls.add(name);
  }

  @override
  Future<void> restartService(Device device, String name) async {
    restartCalls.add(name);
  }
}
