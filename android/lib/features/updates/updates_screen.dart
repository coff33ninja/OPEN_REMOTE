import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/update_feed.dart';
import '../../core/models/updates_config.dart';
import '../../core/networking/github_updates_service.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({
    super.key,
    required this.service,
  });

  final GitHubUpdatesService service;

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  UpdateFeed? _feed;
  UpdatesConfig? _config;
  PackageInfo? _packageInfo;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _loadConfig();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final feed = await widget.service.fetchUpdates(
        forceRefresh: forceRefresh,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _feed = feed;
        _error = feed.error;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Update feed failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadConfig() async {
    final config = await widget.service.loadConfig();
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _config = config;
      _packageInfo = info;
    });
  }

  Future<void> _openUrl(String url) async {
    if (url.trim().isEmpty) {
      return;
    }

    final uri = Uri.parse(url);
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        _buildHeader(context, feed),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error ?? '',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.redAccent),
            ),
          ),
        const SizedBox(height: 20),
        _buildReleasesSection(context, feed),
        const SizedBox(height: 20),
        _buildCommitsSection(context, feed),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, UpdateFeed? feed) {
    final config = _config;
    final packageInfo = _packageInfo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Release Updates',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _loading ? null : () => _load(forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showConfigEditor(context),
                  icon: const Icon(Icons.tune),
                  label: const Text('Config'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: <Widget>[
                if (feed != null)
                  Chip(
                    label: Text(
                        'Last updated ${_formatTimestamp(feed.fetchedAt)}'),
                  ),
                if (feed?.isStale == true)
                  const Chip(
                    label: Text('Stale cache'),
                  ),
                if (packageInfo != null)
                  Chip(
                    label: Text(
                      'Android ${packageInfo.version}+${packageInfo.buildNumber}',
                    ),
                  ),
                if (config?.agentVersion != null &&
                    config!.agentVersion!.trim().isNotEmpty)
                  Chip(
                    label: Text('Agent ${config.agentVersion}'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pulls GitHub releases and recent commits so users can track changes without leaving the app.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (config?.releaseNotesPage.trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _openUrl(config!.releaseNotesPage),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Release notes'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReleasesSection(BuildContext context, UpdateFeed? feed) {
    final config = _config;
    final releases = feed?.releases ?? const <UpdateRelease>[];
    if (releases.isEmpty) {
      return _emptyCard(
        context,
        title: 'Releases',
        message: 'No releases cached yet.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Releases',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (config?.releasesPage.trim().isNotEmpty == true)
              OutlinedButton.icon(
                onPressed: () => _openUrl(config!.releasesPage),
                icon: const Icon(Icons.link),
                label: const Text('All releases'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...releases.map((UpdateRelease release) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            release.name.trim().isEmpty
                                ? release.tagName
                                : '${release.name} (${release.tagName})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: release.url.trim().isEmpty
                              ? null
                              : () => _openUrl(release.url),
                          icon: const Icon(Icons.open_in_new),
                          tooltip: 'Open release',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: <Widget>[
                        if (release.publishedAt != null)
                          Chip(
                            label: Text(
                              _formatTimestamp(release.publishedAt!),
                            ),
                          ),
                        if (release.isPrerelease)
                          const Chip(label: Text('Pre-release')),
                        if (release.isDraft) const Chip(label: Text('Draft')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      release.body.trim().isEmpty
                          ? 'No release notes.'
                          : release.body.trim(),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCommitsSection(BuildContext context, UpdateFeed? feed) {
    final config = _config;
    final commits = feed?.commits ?? const <UpdateCommit>[];
    if (commits.isEmpty) {
      return _emptyCard(
        context,
        title: 'Recent commits',
        message: 'No commits cached yet.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Recent commits',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: commits.map((UpdateCommit commit) {
              return ListTile(
                title: Text(_firstLine(commit.message)),
                subtitle: Text(
                  '${_shortSha(commit.sha)} • ${commit.author.isEmpty ? 'Unknown' : commit.author} • ${_formatTimestamp(commit.date)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new),
                  tooltip: 'Open commit',
                  onPressed: commit.url.trim().isEmpty
                      ? null
                      : () => _openUrl(commit.url),
                ),
              );
            }).toList(growable: false),
          ),
        ),
        if (config?.commitsPage.trim().isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: () => _openUrl(config!.commitsPage),
              icon: const Icon(Icons.link),
              label: const Text('View on GitHub'),
            ),
          ),
      ],
    );
  }

  Widget _emptyCard(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(message),
          ],
        ),
      ),
    );
  }

  String _shortSha(String sha) {
    if (sha.length <= 7) {
      return sha;
    }
    return sha.substring(0, 7);
  }

  String _firstLine(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return 'No message';
    }
    return trimmed.split('\n').first;
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return 'Unknown date';
    }
    final local = timestamp.toLocal();
    final iso = local.toIso8601String();
    final parts = iso.split('T');
    final date = parts.first;
    final time = parts.length > 1 ? parts.last.substring(0, 5) : '';
    return '$date $time'.trim();
  }

  Future<void> _showConfigEditor(BuildContext context) async {
    final config = _config;
    final controller = TextEditingController(
      text: config == null
          ? ''
          : const JsonEncoder.withIndent('  ').convert(config.toJson()),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Updates config'),
          content: TextField(
            controller: controller,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'Paste JSON config override',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                await widget.service.clearConfigOverride();
                if (!mounted) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.service.saveConfigOverride(controller.text);
                if (!mounted) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      await _loadConfig();
      await _load(forceRefresh: true);
    }
  }
}
