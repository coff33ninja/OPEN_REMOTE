import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/agent_data.dart';
import 'package:openremote_android/core/models/device.dart';
import 'package:openremote_android/core/networking/api_client.dart';
import 'package:openremote_android/features/system_info/system_info_screen.dart';

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

  testWidgets('SystemInfoScreen renders snapshot data',
      (WidgetTester tester) async {
    final snapshot = AgentSystemSnapshot(
      cpus: const <AgentCpuInfo>[
        AgentCpuInfo(
          name: 'Ryzen',
          loadPercent: 42,
          cores: 8,
          logicalCores: 16,
          maxMHz: 4800,
        ),
      ],
      memory: const AgentMemoryInfo(
        totalBytes: 16 * 1024 * 1024 * 1024,
        freeBytes: 8 * 1024 * 1024 * 1024,
        usedBytes: 8 * 1024 * 1024 * 1024,
        usedPercent: 50,
      ),
      gpus: const <AgentGpuInfo>[
        AgentGpuInfo(
          name: 'RTX',
          driver: '551.23',
          adapterBytes: 8 * 1024 * 1024 * 1024,
        ),
      ],
      disks: const <AgentDiskInfo>[
        AgentDiskInfo(
          name: 'C:',
          label: 'OS',
          fileSystem: 'NTFS',
          driveType: 'Fixed',
          totalBytes: 512 * 1024 * 1024 * 1024,
          freeBytes: 256 * 1024 * 1024 * 1024,
          usedBytes: 256 * 1024 * 1024 * 1024,
          freePercent: 50,
        ),
      ],
      observedAt: DateTime.utc(2026, 3, 10, 12, 0, 0),
      cacheError: '',
    );

    final apiClient = _FakeApiClient(snapshot);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SystemInfoScreen(
            enabled: true,
            device: buildDevice(),
            apiClient: apiClient,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('Memory'), findsOneWidget);
    expect(find.text('GPU'), findsOneWidget);
    expect(find.text('Drives'), findsOneWidget);
    expect(find.text('Ryzen'), findsOneWidget);
    expect(find.textContaining('50.0%'), findsWidgets);
    expect(find.textContaining('Free 8.0 GB'), findsOneWidget);
    expect(find.textContaining('VRAM 8.0 GB'), findsOneWidget);
    expect(find.textContaining('Driver 551.23'), findsOneWidget);
    expect(find.textContaining('C:'), findsOneWidget);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.snapshot);

  final AgentSystemSnapshot snapshot;

  @override
  Future<AgentSystemSnapshot> fetchSystemSnapshot(Device device) async {
    return snapshot;
  }
}
