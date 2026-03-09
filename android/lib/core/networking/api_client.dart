import 'dart:convert';
import 'dart:io';

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
        wakeTarget: device.wakeTarget,
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
}
