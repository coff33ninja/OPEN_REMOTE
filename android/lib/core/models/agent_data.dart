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

class AgentCpuInfo {
  const AgentCpuInfo({
    required this.name,
    required this.loadPercent,
    required this.cores,
    required this.logicalCores,
    required this.maxMHz,
  });

  final String name;
  final int loadPercent;
  final int cores;
  final int logicalCores;
  final int maxMHz;

  factory AgentCpuInfo.fromJson(Map<String, dynamic> json) {
    return AgentCpuInfo(
      name: json['name'] as String? ?? '',
      loadPercent: (json['load_percent'] as num?)?.toInt() ?? 0,
      cores: (json['cores'] as num?)?.toInt() ?? 0,
      logicalCores: (json['logical_cores'] as num?)?.toInt() ?? 0,
      maxMHz: (json['max_mhz'] as num?)?.toInt() ?? 0,
    );
  }
}

class AgentMemoryInfo {
  const AgentMemoryInfo({
    required this.totalBytes,
    required this.freeBytes,
    required this.usedBytes,
    required this.usedPercent,
  });

  final int totalBytes;
  final int freeBytes;
  final int usedBytes;
  final double usedPercent;

  factory AgentMemoryInfo.fromJson(Map<String, dynamic> json) {
    return AgentMemoryInfo(
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
      freeBytes: (json['free_bytes'] as num?)?.toInt() ?? 0,
      usedBytes: (json['used_bytes'] as num?)?.toInt() ?? 0,
      usedPercent: (json['used_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AgentGpuInfo {
  const AgentGpuInfo({
    required this.name,
    required this.driver,
    required this.adapterBytes,
  });

  final String name;
  final String driver;
  final int adapterBytes;

  factory AgentGpuInfo.fromJson(Map<String, dynamic> json) {
    return AgentGpuInfo(
      name: json['name'] as String? ?? '',
      driver: json['driver'] as String? ?? '',
      adapterBytes: (json['adapter_bytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class AgentDiskInfo {
  const AgentDiskInfo({
    required this.name,
    required this.label,
    required this.fileSystem,
    required this.driveType,
    required this.totalBytes,
    required this.freeBytes,
    required this.usedBytes,
    required this.freePercent,
  });

  final String name;
  final String label;
  final String fileSystem;
  final String driveType;
  final int totalBytes;
  final int freeBytes;
  final int usedBytes;
  final double freePercent;

  factory AgentDiskInfo.fromJson(Map<String, dynamic> json) {
    return AgentDiskInfo(
      name: json['name'] as String? ?? '',
      label: json['label'] as String? ?? '',
      fileSystem: json['file_system'] as String? ?? '',
      driveType: json['drive_type'] as String? ?? '',
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
      freeBytes: (json['free_bytes'] as num?)?.toInt() ?? 0,
      usedBytes: (json['used_bytes'] as num?)?.toInt() ?? 0,
      freePercent: (json['free_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AgentSystemSnapshot {
  const AgentSystemSnapshot({
    required this.cpus,
    required this.memory,
    required this.gpus,
    required this.disks,
    required this.observedAt,
    required this.cacheError,
  });

  final List<AgentCpuInfo> cpus;
  final AgentMemoryInfo? memory;
  final List<AgentGpuInfo> gpus;
  final List<AgentDiskInfo> disks;
  final DateTime? observedAt;
  final String cacheError;

  factory AgentSystemSnapshot.fromJson(
    Map<String, dynamic> json, {
    DateTime? observedAt,
    String? cacheError,
  }) {
    final cpus = json['cpus'] as List<dynamic>? ?? const <dynamic>[];
    final gpus = json['gpus'] as List<dynamic>? ?? const <dynamic>[];
    final disks = json['disks'] as List<dynamic>? ?? const <dynamic>[];
    final memoryJson = json['memory'] as Map<String, dynamic>?;
    return AgentSystemSnapshot(
      cpus: cpus
          .map((dynamic item) =>
              AgentCpuInfo.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      memory: memoryJson == null ? null : AgentMemoryInfo.fromJson(memoryJson),
      gpus: gpus
          .map((dynamic item) =>
              AgentGpuInfo.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      disks: disks
          .map((dynamic item) =>
              AgentDiskInfo.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      observedAt: observedAt,
      cacheError: cacheError ?? '',
    );
  }
}
