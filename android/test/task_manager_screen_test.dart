import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/agent_data.dart';
import 'package:openremote_android/core/models/device.dart';
import 'package:openremote_android/core/networking/api_client.dart';
import 'package:openremote_android/features/task_manager/task_manager_screen.dart';

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

  testWidgets('TaskManagerScreen lists and terminates processes',
      (WidgetTester tester) async {
    final apiClient = _FakeApiClient(
      processes: const <AgentProcess>[
        AgentProcess(
          pid: 4242,
          name: 'notepad.exe',
          session: 'Console',
          sessionNum: '1',
          memory: '12 MB',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskManagerScreen(
            enabled: true,
            device: buildDevice(),
            apiClient: apiClient,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.text('notepad.exe'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.cancel_schedule_send));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terminate'));
    await tester.pumpAndSettle();

    expect(apiClient.terminated, contains(4242));
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient({required List<AgentProcess> processes})
      : _processes = processes;

  final List<AgentProcess> _processes;
  final List<int> terminated = <int>[];

  @override
  Future<List<AgentProcess>> fetchProcesses(Device device) async {
    return _processes;
  }

  @override
  Future<void> terminateProcess(Device device, int pid) async {
    terminated.add(pid);
  }
}
