import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:openremote_android/core/models/update_feed.dart';
import 'package:openremote_android/core/models/updates_config.dart';
import 'package:openremote_android/core/networking/github_updates_service.dart';
import 'package:openremote_android/features/updates/updates_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UpdatesScreen renders release and commit data',
      (WidgetTester tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'OpenRemote',
      packageName: 'openremote',
      version: '0.1.13',
      buildNumber: '13',
      buildSignature: 'test',
    );

    final feed = UpdateFeed(
      fetchedAt: DateTime.utc(2026, 3, 10, 12, 0),
      releases: const <UpdateRelease>[
        UpdateRelease(
          tagName: 'v0.1.13',
          name: 'OpenRemote v0.1.13',
          body: 'Telemetry snapshot',
          publishedAt: null,
          url: 'https://example.com/release',
          isPrerelease: false,
          isDraft: false,
        ),
      ],
      commits: const <UpdateCommit>[
        UpdateCommit(
          sha: 'abcdef1234567',
          message: 'Add telemetry snapshot',
          author: 'Dev',
          date: null,
          url: 'https://example.com/commit',
        ),
      ],
    );

    final config = const UpdatesConfig(
      owner: 'coff33ninja',
      repo: 'OPEN_REMOTE',
      releasesUrl:
          'https://api.github.com/repos/coff33ninja/OPEN_REMOTE/releases',
      commitsUrl:
          'https://api.github.com/repos/coff33ninja/OPEN_REMOTE/commits',
      releasesPage: 'https://github.com/coff33ninja/OPEN_REMOTE/releases',
      commitsPage: 'https://github.com/coff33ninja/OPEN_REMOTE/commits/main',
      releaseNotesPage:
          'https://github.com/coff33ninja/OPEN_REMOTE/blob/main/docs/releases.md',
      androidVersion: '0.1.13+13',
      agentVersion: '0.1.13',
    );

    final service = _FakeUpdatesService(feed, config);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdatesScreen(service: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Release Updates'), findsOneWidget);
    expect(find.text('OpenRemote v0.1.13 (v0.1.13)'), findsOneWidget);
    expect(find.text('Add telemetry snapshot'), findsOneWidget);
    expect(find.text('Release notes'), findsOneWidget);
  });
}

class _FakeUpdatesService extends GitHubUpdatesService {
  _FakeUpdatesService(this.feed, this.config);

  final UpdateFeed feed;
  final UpdatesConfig config;

  @override
  Future<UpdateFeed> fetchUpdates({bool forceRefresh = false}) async {
    return feed;
  }

  @override
  Future<UpdatesConfig> loadConfig() async {
    return config;
  }
}
