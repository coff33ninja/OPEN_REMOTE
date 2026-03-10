class UpdatesConfig {
  const UpdatesConfig({
    required this.owner,
    required this.repo,
    required this.releasesUrl,
    required this.commitsUrl,
    required this.releasesPage,
    required this.commitsPage,
    this.androidVersion,
    this.agentVersion,
  });

  final String owner;
  final String repo;
  final String releasesUrl;
  final String commitsUrl;
  final String releasesPage;
  final String commitsPage;
  final String? androidVersion;
  final String? agentVersion;

  factory UpdatesConfig.fromJson(Map<String, dynamic> json) {
    final repoJson = json['repo'] as Map<String, dynamic>? ?? const {};
    final linksJson = json['links'] as Map<String, dynamic>? ?? const {};
    final versionsJson = json['versions'] as Map<String, dynamic>? ?? const {};
    final owner = repoJson['owner'] as String? ?? '';
    final repo = repoJson['name'] as String? ?? '';
    final releasesPage = linksJson['releases'] as String? ?? '';
    final commitsPage = linksJson['commits'] as String? ?? '';
    return UpdatesConfig(
      owner: owner,
      repo: repo,
      releasesUrl: json['releases_url'] as String? ??
          _fallbackApiUrl(owner, repo, 'releases'),
      commitsUrl: json['commits_url'] as String? ??
          _fallbackApiUrl(owner, repo, 'commits'),
      releasesPage: releasesPage.isEmpty
          ? _fallbackWebUrl(owner, repo, 'releases')
          : releasesPage,
      commitsPage: commitsPage.isEmpty
          ? _fallbackWebUrl(owner, repo, 'commits')
          : commitsPage,
      androidVersion: versionsJson['android'] as String?,
      agentVersion: versionsJson['agent'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'repo': <String, dynamic>{
        'owner': owner,
        'name': repo,
      },
      'releases_url': releasesUrl,
      'commits_url': commitsUrl,
      'links': <String, dynamic>{
        'releases': releasesPage,
        'commits': commitsPage,
      },
      'versions': <String, dynamic>{
        'android': androidVersion,
        'agent': agentVersion,
      }..removeWhere((String key, dynamic value) => value == null),
    };
  }

  UpdatesConfig copyWith({
    String? owner,
    String? repo,
    String? releasesUrl,
    String? commitsUrl,
    String? releasesPage,
    String? commitsPage,
    String? androidVersion,
    String? agentVersion,
  }) {
    return UpdatesConfig(
      owner: owner ?? this.owner,
      repo: repo ?? this.repo,
      releasesUrl: releasesUrl ?? this.releasesUrl,
      commitsUrl: commitsUrl ?? this.commitsUrl,
      releasesPage: releasesPage ?? this.releasesPage,
      commitsPage: commitsPage ?? this.commitsPage,
      androidVersion: androidVersion ?? this.androidVersion,
      agentVersion: agentVersion ?? this.agentVersion,
    );
  }
}

String _fallbackApiUrl(String owner, String repo, String endpoint) {
  if (owner.isEmpty || repo.isEmpty) {
    return '';
  }
  return 'https://api.github.com/repos/$owner/$repo/$endpoint';
}

String _fallbackWebUrl(String owner, String repo, String endpoint) {
  if (owner.isEmpty || repo.isEmpty) {
    return '';
  }
  return 'https://github.com/$owner/$repo/$endpoint';
}
