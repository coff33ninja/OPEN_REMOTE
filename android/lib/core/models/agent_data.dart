class FileSystemEntry {
  const FileSystemEntry({
    required this.name,
    required this.path,
    required this.isDir,
    required this.size,
    required this.modified,
    required this.isDrive,
  });

  final String name;
  final String path;
  final bool isDir;
  final int size;
  final String modified;
  final bool isDrive;

  factory FileSystemEntry.fromJson(Map<String, dynamic> json) {
    return FileSystemEntry(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      isDir: json['is_dir'] as bool? ?? false,
      size: (json['size'] as num?)?.toInt() ?? 0,
      modified: json['modified'] as String? ?? '',
      isDrive: json['is_drive'] as bool? ?? false,
    );
  }
}

class AgentProcess {
  const AgentProcess({
    required this.pid,
    required this.name,
    required this.session,
    required this.sessionNum,
    required this.memory,
  });

  final int pid;
  final String name;
  final String session;
  final String sessionNum;
  final String memory;

  factory AgentProcess.fromJson(Map<String, dynamic> json) {
    return AgentProcess(
      pid: (json['pid'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      session: json['session'] as String? ?? '',
      sessionNum: json['session_num'] as String? ?? '',
      memory: json['memory'] as String? ?? '',
    );
  }
}

class AgentService {
  const AgentService({
    required this.name,
    required this.displayName,
    required this.status,
    required this.statusReason,
    required this.startType,
  });

  final String name;
  final String displayName;
  final String status;
  final String statusReason;
  final String startType;

  factory AgentService.fromJson(Map<String, dynamic> json) {
    return AgentService(
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusReason: json['status_reason'] as String? ?? '',
      startType: json['start_type'] as String? ?? '',
    );
  }
}
