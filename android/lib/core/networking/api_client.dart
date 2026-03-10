import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../models/agent_data.dart';
import '../models/device.dart';
import '../models/pairing.dart';
import '../models/remote_layout.dart';

class ApiClient {
  const ApiClient();

  Future<Device> fetchMeta(Device device) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(
        Uri(
          scheme: 'http',
          host: device.host,
          port: device.port,
          path: '/api/v1/meta',
        ),
      );

      final response = await request.close();
      final payload = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Metadata request failed with status ${response.statusCode}: $payload',
        );
      }

      final json = jsonDecode(payload) as Map<String, dynamic>;
      final metadata = Device.fromJson(
        <String, dynamic>{
          ...json,
          'id': device.id,
          'access_token': device.accessToken,
        },
      );

      return device.copyWith(
        name: metadata.name,
        host: device.host,
        port: metadata.port,
        serviceType: metadata.serviceType,
        websocketPath: metadata.websocketPath,
        wakeTarget: device.routeForHost(device.host)?.wakeTarget ??
            metadata.routeForHost(device.host)?.wakeTarget ??
            device.wakeTarget ??
            metadata.wakeTarget,
        networkRoutes: mergeNetworkRoutes(
          metadata.networkRoutes,
          device.networkRoutes,
        ),
        preferredRouteHost: device.preferredRouteHost ??
            metadata.networkRoutes
                .where((NetworkRoute route) => route.preferred)
                .map((NetworkRoute route) => route.host)
                .firstOrNull,
        lastSuccessfulRouteHost: device.lastSuccessfulRouteHost,
        lastSeenAt: DateTime.now().toUtc(),
        lastConnectedAt: device.lastConnectedAt,
      );
    } finally {
      httpClient.close();
    }
  }

  Future<Device> completePairing(
    PairingPayload pairing,
    String clientDeviceName,
  ) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.postUrl(
        Uri(
          scheme: 'http',
          host: pairing.host,
          port: pairing.port,
          path: '/api/v1/pairing/complete',
        ),
      );
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(
          <String, dynamic>{
            'device_name': clientDeviceName,
            'pairing_token': pairing.token,
          },
        ),
      );

      final response = await request.close();
      final payload = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Pairing failed with status ${response.statusCode}: $payload',
        );
      }

      final json = jsonDecode(payload) as Map<String, dynamic>;
      return pairing.toDevice(accessToken: json['access_token'] as String?);
    } finally {
      httpClient.close();
    }
  }

  Future<List<RemoteLayout>> fetchRemoteCatalog(Device device) async {
    final httpClient = HttpClient();
    try {
      final catalogRequest = await httpClient.getUrl(
        Uri(
          scheme: 'http',
          host: device.host,
          port: device.port,
          path: '/api/v1/remotes/catalog',
        ),
      );
      final catalogResponse = await catalogRequest.close();
      final catalogPayload = await utf8.decoder.bind(catalogResponse).join();
      if (catalogResponse.statusCode < 200 ||
          catalogResponse.statusCode >= 300) {
        throw HttpException(
          'Remote catalog failed with status ${catalogResponse.statusCode}: $catalogPayload',
        );
      }

      final json = jsonDecode(catalogPayload) as Map<String, dynamic>;
      final remoteEntries =
          json['remotes'] as List<dynamic>? ?? const <dynamic>[];
      final remotes = <RemoteLayout>[];

      for (final entry in remoteEntries) {
        final item = entry as Map<String, dynamic>;
        final path = item['path'] as String?;
        if (path == null || path.isEmpty) {
          continue;
        }

        final remoteRequest = await httpClient.getUrl(
          Uri(
            scheme: 'http',
            host: device.host,
            port: device.port,
            path: path,
          ),
        );
        final remoteResponse = await remoteRequest.close();
        final remotePayload = await utf8.decoder.bind(remoteResponse).join();
        if (remoteResponse.statusCode < 200 ||
            remoteResponse.statusCode >= 300) {
          continue;
        }

        final remoteJson = jsonDecode(remotePayload) as Map<String, dynamic>;
        remotes.add(RemoteLayout.fromJson(remoteJson));
      }

      return remotes;
    } finally {
      httpClient.close();
    }
  }

  Future<Map<String, dynamic>> uploadFile(
    Device device, {
    required String fileName,
    required List<int> bytes,
    String? targetDirectory,
  }) async {
    final token = device.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Device must be paired before file upload.');
    }

    final httpClient = HttpClient();
    try {
      final request = await httpClient.postUrl(
        Uri(
          scheme: 'http',
          host: device.host,
          port: device.port,
          path: '/api/v1/files/upload',
        ),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(
        jsonEncode(
          <String, dynamic>{
            'name': path.basename(fileName),
            'base64_data': base64Encode(bytes),
            if (targetDirectory != null && targetDirectory.trim().isNotEmpty)
              'target_dir': targetDirectory,
          },
        ),
      );

      final response = await request.close();
      final payload = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'File upload failed with status ${response.statusCode}: $payload',
        );
      }

      return jsonDecode(payload) as Map<String, dynamic>;
    } finally {
      httpClient.close();
    }
  }

  Future<List<int>> downloadFile(
    Device device, {
    required String remotePath,
  }) async {
    final token = device.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Device must be paired before downloading files.');
    }

    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(
        Uri(
          scheme: 'http',
          host: device.host,
          port: device.port,
          path: '/api/v1/filesystem/download',
          queryParameters: <String, String>{'path': remotePath},
        ),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');

      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final payload = utf8.decode(bytes, allowMalformed: true);
        throw HttpException(
          'Download failed with status ${response.statusCode}: $payload',
        );
      }

      return bytes;
    } finally {
      httpClient.close();
    }
  }

  Future<List<FileSystemEntry>> fetchDirectory(
    Device device, {
    String pathValue = '',
  }) async {
    final token = device.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Device must be paired before browsing files.');
    }

    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(
        Uri(
          scheme: 'http',
          host: device.host,
          port: device.port,
          path: '/api/v1/filesystem',
          queryParameters:
              pathValue.isEmpty ? null : <String, String>{'path': pathValue},
        ),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');

      final response = await request.close();
      final payload = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Directory request failed with status ${response.statusCode}: $payload',
        );
      }

      final json = jsonDecode(payload) as Map<String, dynamic>;
      final entries = json['entries'] as List<dynamic>? ?? const <dynamic>[];
      return entries
          .map((dynamic item) =>
              FileSystemEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } finally {
      httpClient.close();
    }
  }

  Future<void> createFolder(
    Device device, {
    required String parentPath,
    required String name,
  }) async {
    await _postFilesystemAction(
      device,
      path: '/api/v1/filesystem/folder',
      payload: <String, dynamic>{
        'parent_path': parentPath,
        'name': name,
      },
      errorLabel: 'Create folder',
    );
  }

  Future<void> renameEntry(
    Device device, {
    required String entryPath,
    required String newName,
  }) async {
    await _postFilesystemAction(
      device,
      path: '/api/v1/filesystem/rename',
      payload: <String, dynamic>{
        'path': entryPath,
        'new_name': newName,
      },
      errorLabel: 'Rename',
    );
  }

  Future<void> deleteEntry(
    Device device, {
    required String entryPath,
  }) async {
    await _postFilesystemAction(
      device,
      path: '/api/v1/filesystem/delete',
      payload: <String, dynamic>{'path': entryPath},
      errorLabel: 'Delete',
    );
  }

  Future<void> moveEntry(
    Device device, {
    required String sourcePath,
    required String destinationPath,
  }) async {
    await _postFilesystemAction(
      device,
      path: '/api/v1/filesystem/move',
      payload: <String, dynamic>{
        'source_path': sourcePath,
        'destination_path': destinationPath,
      },
      errorLabel: 'Move',
    );
  }

  Future<void> copyEntry(
    Device device, {
    required String sourcePath,
    required String destinationPath,
  }) async {
    await _postFilesystemAction(
      device,
      path: '/api/v1/filesystem/copy',
      payload: <String, dynamic>{
        'source_path': sourcePath,
        'destination_path': destinationPath,
      },
      errorLabel: 'Copy',
    );
  }

  Future<void> openRemotePath(
    Device device, {
    required String entryPath,
  }) async {
    await _postFilesystemAction(
      device,
      path: '/api/v1/filesystem/open',
      payload: <String, dynamic>{'path': entryPath},
      errorLabel: 'Open path',
    );
  }

  Future<List<AgentProcess>> fetchProcesses(Device device) async {
    final token = device.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Device must be paired before listing processes.');
    }

    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(
        Uri(
          scheme: 'http',
          host: device.host,
          port: device.port,
          path: '/api/v1/processes',
        ),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');

      final response = await request.close();
      final payload = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Process request failed with status ${response.statusCode}: $payload',
        );
      }

      final json = jsonDecode(payload) as Map<String, dynamic>;
      final processes =
          json['processes'] as List<dynamic>? ?? const <dynamic>[];
      return processes
          .map((dynamic item) =>
              AgentProcess.fromJson(item as Map<String, dynamic>))
          .toList();
    } finally {
      httpClient.close();
    }
  }

  Future<List<AgentService>> fetchServices(Device device) async {
    final token = device.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Device must be paired before listing services.');
    }

    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(
        Uri(
          scheme: 'http',
          host: device.host,
          port: device.port,
          path: '/api/v1/services',
        ),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');

      final response = await request.close();
      final payload = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Services request failed with status ${response.statusCode}: $payload',
        );
      }

      final json = jsonDecode(payload) as Map<String, dynamic>;
      final entries = json['services'] as List<dynamic>? ?? const <dynamic>[];
      return entries
          .map((dynamic item) =>
              AgentService.fromJson(item as Map<String, dynamic>))
          .toList();
    } finally {
      httpClient.close();
    }
  }

  Future<void> startService(Device device, String name) async {
    await _postServiceAction(
      device,
      path: '/api/v1/services/start',
      name: name,
      label: 'Start service',
    );
  }

  Future<void> stopService(Device device, String name) async {
    await _postServiceAction(
      device,
      path: '/api/v1/services/stop',
      name: name,
      label: 'Stop service',
    );
  }

  Future<void> restartService(Device device, String name) async {
    await _postServiceAction(
      device,
      path: '/api/v1/services/restart',
      name: name,
      label: 'Restart service',
    );
  }

  Future<void> terminateProcess(Device device, int pid) async {
    final token = device.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Device must be paired before terminating processes.');
    }

    final httpClient = HttpClient();
    try {
      final request = await httpClient.postUrl(
        Uri(
          scheme: 'http',
          host: device.host,
          port: device.port,
          path: '/api/v1/processes/terminate',
        ),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(jsonEncode(<String, dynamic>{'pid': pid}));

      final response = await request.close();
      final payload = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Terminate process failed with status ${response.statusCode}: $payload',
        );
      }
    } finally {
      httpClient.close();
    }
  }

  Future<void> _postFilesystemAction(
    Device device, {
    required String path,
    required Map<String, dynamic> payload,
    required String errorLabel,
  }) async {
    final token = device.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Device must be paired before file actions.');
    }

    final httpClient = HttpClient();
    try {
      final request = await httpClient.postUrl(
        Uri(
          scheme: 'http',
          host: device.host,
          port: device.port,
          path: path,
        ),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(jsonEncode(payload));

      final response = await request.close();
      final responsePayload = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          '$errorLabel failed with status ${response.statusCode}: $responsePayload',
        );
      }
    } finally {
      httpClient.close();
    }
  }

  Future<void> _postServiceAction(
    Device device, {
    required String path,
    required String name,
    required String label,
  }) async {
    final token = device.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Device must be paired before service actions.');
    }

    final httpClient = HttpClient();
    try {
      final request = await httpClient.postUrl(
        Uri(
          scheme: 'http',
          host: device.host,
          port: device.port,
          path: path,
        ),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(jsonEncode(<String, dynamic>{'name': name}));

      final response = await request.close();
      final responsePayload = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          '$label failed with status ${response.statusCode}: $responsePayload',
        );
      }
    } finally {
      httpClient.close();
    }
  }
}
