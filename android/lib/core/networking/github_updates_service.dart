import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/update_feed.dart';

class GitHubUpdatesService {
  GitHubUpdatesService({
    this.owner = 'coff33ninja',
    this.repo = 'OPEN_REMOTE',
    this.cacheKey = 'updates_cache_v1',
    this.cacheTtl = const Duration(hours: 6),
  });

  final String owner;
  final String repo;
  final String cacheKey;
  final Duration cacheTtl;

  Future<UpdateFeed> fetchUpdates({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = _loadCache(prefs);
    final now = DateTime.now().toUtc();

    if (!forceRefresh &&
        cached != null &&
        now.difference(cached.fetchedAt) <= cacheTtl) {
      return cached;
    }

    try {
      final remote = await _fetchRemote();
      await _saveCache(prefs, remote);
      return remote;
    } catch (error) {
      if (cached != null) {
        return cached.copyWith(
          isStale: true,
          error: 'Last refresh failed: $error',
        );
      }
      rethrow;
    }
  }

  UpdateFeed? _loadCache(SharedPreferences prefs) {
    final raw = prefs.getString(cacheKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return UpdateFeed.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(SharedPreferences prefs, UpdateFeed feed) async {
    await prefs.setString(cacheKey, jsonEncode(feed.toJson()));
  }

  Future<UpdateFeed> _fetchRemote() async {
    final client = HttpClient();
    try {
      final releasesUri = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/releases?per_page=10',
      );
      final commitsUri = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/commits?per_page=20',
      );

      final releasesFuture = _getJson(client, releasesUri);
      final commitsFuture = _getJson(client, commitsUri);
      final responses = await Future.wait(<Future<dynamic>>[
        releasesFuture,
        commitsFuture,
      ]);

      final releases = _parseReleases(responses[0]);
      final commits = _parseCommits(responses[1]);

      return UpdateFeed(
        fetchedAt: DateTime.now().toUtc(),
        releases: releases,
        commits: commits,
      );
    } finally {
      client.close();
    }
  }

  Future<dynamic> _getJson(HttpClient client, Uri uri) async {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, 'OpenRemote-Android');
    request.headers.set('Accept', 'application/vnd.github+json');
    request.headers.set('X-GitHub-Api-Version', '2022-11-28');

    final response = await request.close();
    final payload = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'GitHub request failed with status ${response.statusCode}: $payload',
      );
    }

    return jsonDecode(payload);
  }

  List<UpdateRelease> _parseReleases(dynamic payload) {
    final list = payload is List ? payload : const <dynamic>[];
    return list.map((dynamic item) {
      final json = item as Map<String, dynamic>;
      return UpdateRelease(
        tagName: json['tag_name'] as String? ?? '',
        name: json['name'] as String? ?? '',
        body: json['body'] as String? ?? '',
        publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
        url: json['html_url'] as String? ?? '',
        isPrerelease: json['prerelease'] as bool? ?? false,
        isDraft: json['draft'] as bool? ?? false,
      );
    }).toList(growable: false);
  }

  List<UpdateCommit> _parseCommits(dynamic payload) {
    final list = payload is List ? payload : const <dynamic>[];
    return list.map((dynamic item) {
      final json = item as Map<String, dynamic>;
      final commitJson = json['commit'] as Map<String, dynamic>? ?? const {};
      final authorJson =
          commitJson['author'] as Map<String, dynamic>? ?? const {};
      return UpdateCommit(
        sha: json['sha'] as String? ?? '',
        message: commitJson['message'] as String? ?? '',
        author: authorJson['name'] as String? ?? '',
        date: DateTime.tryParse(authorJson['date'] as String? ?? ''),
        url: json['html_url'] as String? ?? '',
      );
    }).toList(growable: false);
  }
}
