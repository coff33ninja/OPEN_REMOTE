class UpdateRelease {
  const UpdateRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.publishedAt,
    required this.url,
    required this.isPrerelease,
    required this.isDraft,
  });

  final String tagName;
  final String name;
  final String body;
  final DateTime? publishedAt;
  final String url;
  final bool isPrerelease;
  final bool isDraft;

  factory UpdateRelease.fromJson(Map<String, dynamic> json) {
    return UpdateRelease(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      publishedAt: _parseTimestamp(json['published_at']),
      url: json['url'] as String? ?? '',
      isPrerelease: json['is_prerelease'] as bool? ?? false,
      isDraft: json['is_draft'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tag_name': tagName,
      'name': name,
      'body': body,
      'published_at': publishedAt?.toUtc().toIso8601String(),
      'url': url,
      'is_prerelease': isPrerelease,
      'is_draft': isDraft,
    };
  }
}

class UpdateCommit {
  const UpdateCommit({
    required this.sha,
    required this.message,
    required this.author,
    required this.date,
    required this.url,
  });

  final String sha;
  final String message;
  final String author;
  final DateTime? date;
  final String url;

  factory UpdateCommit.fromJson(Map<String, dynamic> json) {
    return UpdateCommit(
      sha: json['sha'] as String? ?? '',
      message: json['message'] as String? ?? '',
      author: json['author'] as String? ?? '',
      date: _parseTimestamp(json['date']),
      url: json['url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sha': sha,
      'message': message,
      'author': author,
      'date': date?.toUtc().toIso8601String(),
      'url': url,
    };
  }
}

class UpdateFeed {
  const UpdateFeed({
    required this.fetchedAt,
    required this.releases,
    required this.commits,
    this.isStale = false,
    this.error,
  });

  final DateTime fetchedAt;
  final List<UpdateRelease> releases;
  final List<UpdateCommit> commits;
  final bool isStale;
  final String? error;

  UpdateFeed copyWith({
    DateTime? fetchedAt,
    List<UpdateRelease>? releases,
    List<UpdateCommit>? commits,
    bool? isStale,
    String? error,
  }) {
    return UpdateFeed(
      fetchedAt: fetchedAt ?? this.fetchedAt,
      releases: releases ?? this.releases,
      commits: commits ?? this.commits,
      isStale: isStale ?? this.isStale,
      error: error,
    );
  }

  factory UpdateFeed.fromJson(Map<String, dynamic> json) {
    final releases = (json['releases'] as List<dynamic>? ?? const <dynamic>[])
        .map((dynamic item) =>
            UpdateRelease.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final commits = (json['commits'] as List<dynamic>? ?? const <dynamic>[])
        .map((dynamic item) =>
            UpdateCommit.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final fetchedAt =
        _parseTimestamp(json['fetched_at']) ?? DateTime.now().toUtc();

    return UpdateFeed(
      fetchedAt: fetchedAt,
      releases: releases,
      commits: commits,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fetched_at': fetchedAt.toUtc().toIso8601String(),
      'releases': releases.map((UpdateRelease item) => item.toJson()).toList(),
      'commits': commits.map((UpdateCommit item) => item.toJson()).toList(),
    };
  }
}

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.tryParse(value.toString());
}
