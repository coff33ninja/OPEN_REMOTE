import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/agent_data.dart';
import 'package:openremote_android/core/models/device.dart';
import 'package:openremote_android/core/networking/api_client.dart';
import 'package:openremote_android/features/file_explorer/file_explorer_screen.dart';

void main() {
  void setViewSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

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

  testWidgets('FileExplorerScreen filters and navigates directories',
      (WidgetTester tester) async {
    setViewSize(tester);

    final apiClient = _FakeApiClient(
      directories: <String, List<FileSystemEntry>>{
        '': const <FileSystemEntry>[
          FileSystemEntry(
            name: 'Docs',
            path: r'C:\Docs',
            isDir: true,
            size: 0,
            modified: '',
            isDrive: false,
          ),
          FileSystemEntry(
            name: 'note.txt',
            path: r'C:\note.txt',
            isDir: false,
            size: 12,
            modified: '2026-03-09T18:00:00Z',
            isDrive: false,
          ),
        ],
        r'C:\': const <FileSystemEntry>[
          FileSystemEntry(
            name: 'Docs',
            path: r'C:\Docs',
            isDir: true,
            size: 0,
            modified: '',
            isDrive: false,
          ),
          FileSystemEntry(
            name: 'note.txt',
            path: r'C:\note.txt',
            isDir: false,
            size: 12,
            modified: '2026-03-09T18:00:00Z',
            isDrive: false,
          ),
        ],
        r'C:\Docs': const <FileSystemEntry>[
          FileSystemEntry(
            name: 'child.txt',
            path: r'C:\Docs\child.txt',
            isDir: false,
            size: 24,
            modified: '2026-03-09T18:05:00Z',
            isDrive: false,
          ),
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FileExplorerScreen(
            enabled: true,
            device: buildDevice(),
            apiClient: apiClient,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('note.txt'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'note');
    await tester.pumpAndSettle();

    expect(find.text('Docs'), findsNothing);
    expect(find.text('note.txt'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Docs'));
    await tester.pumpAndSettle();

    expect(find.text('child.txt'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Up'));
    await tester.pumpAndSettle();

    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('note.txt'), findsOneWidget);
  });

  testWidgets('FileExplorerScreen creates folders and renames files',
      (WidgetTester tester) async {
    setViewSize(tester);

    final apiClient = _FakeApiClient(
      directories: <String, List<FileSystemEntry>>{
        '': const <FileSystemEntry>[
          FileSystemEntry(
            name: 'Docs',
            path: r'C:\Docs',
            isDir: true,
            size: 0,
            modified: '',
            isDrive: false,
          ),
        ],
        r'C:\Docs': const <FileSystemEntry>[
          FileSystemEntry(
            name: 'child.txt',
            path: r'C:\Docs\child.txt',
            isDir: false,
            size: 24,
            modified: '2026-03-09T18:05:00Z',
            isDrive: false,
          ),
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FileExplorerScreen(
            enabled: true,
            device: buildDevice(),
            apiClient: apiClient,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Docs'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'New Folder'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Specs',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(apiClient.createdFolders, <String>[r'C:\Docs|Specs']);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'child-renamed.txt',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();

    expect(
      apiClient.renamedEntries,
      <String>[r'C:\Docs\child.txt|child-renamed.txt'],
    );
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient({
    required Map<String, List<FileSystemEntry>> directories,
  }) : _directories = directories.map(
          (String key, List<FileSystemEntry> value) =>
              MapEntry<String, List<FileSystemEntry>>(
            key,
            List<FileSystemEntry>.from(value),
          ),
        );

  final Map<String, List<FileSystemEntry>> _directories;
  final List<String> createdFolders = <String>[];
  final List<String> renamedEntries = <String>[];

  @override
  Future<List<FileSystemEntry>> fetchDirectory(
    Device device, {
    String pathValue = '',
  }) async {
    return List<FileSystemEntry>.from(
      _directories[pathValue] ?? const <FileSystemEntry>[],
    );
  }

  @override
  Future<void> createFolder(
    Device device, {
    required String parentPath,
    required String name,
  }) async {
    createdFolders.add('$parentPath|$name');
    final folderPath = parentPath.isEmpty ? name : '$parentPath\\$name';
    final existing = List<FileSystemEntry>.from(
      _directories[parentPath] ?? const <FileSystemEntry>[],
    );
    existing.add(
      FileSystemEntry(
        name: name,
        path: folderPath,
        isDir: true,
        size: 0,
        modified: '',
        isDrive: false,
      ),
    );
    _directories[parentPath] = existing;
    _directories.putIfAbsent(folderPath, () => <FileSystemEntry>[]);
  }

  @override
  Future<void> renameEntry(
    Device device, {
    required String entryPath,
    required String newName,
  }) async {
    renamedEntries.add('$entryPath|$newName');
    _directories.updateAll((String _, List<FileSystemEntry> entries) {
      return entries.map((FileSystemEntry entry) {
        if (entry.path != entryPath) {
          return entry;
        }

        return FileSystemEntry(
          name: newName,
          path: entryPath.replaceFirst(entry.name, newName),
          isDir: entry.isDir,
          size: entry.size,
          modified: entry.modified,
          isDrive: entry.isDrive,
        );
      }).toList(growable: false);
    });
  }
}
