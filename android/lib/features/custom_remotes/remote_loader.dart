import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/models/remote_layout.dart';

class RemoteLoader {
  const RemoteLoader();

  static const List<String> _bundledAssets = <String>[
    'assets/remotes/media_remote.json',
    'assets/remotes/meeting_controls.json',
    'assets/remotes/mouse_touchpad.json',
    'assets/remotes/movie_mode.json',
    'assets/remotes/presentation_remote.json',
  ];

  Future<List<RemoteLayout>> loadBundledRemotes() async {
    final remotes = <RemoteLayout>[];

    for (final assetPath in _bundledAssets) {
      final payload = await rootBundle.loadString(assetPath);
      final json = jsonDecode(payload) as Map<String, dynamic>;
      remotes.add(RemoteLayout.fromJson(json));
    }

    return remotes;
  }
}
