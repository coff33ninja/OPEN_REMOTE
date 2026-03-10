import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/command.dart';

enum RemoteConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class RemoteClient {
  WebSocket? _socket;
  int _connectionId = 0;
  Object? _lastError;

  final ValueNotifier<RemoteConnectionState> connectionState =
      ValueNotifier<RemoteConnectionState>(RemoteConnectionState.disconnected);

  bool get isConnected =>
      connectionState.value == RemoteConnectionState.connected;

  Object? get lastError => _lastError;

  Future<void> connect(Uri url, {String? accessToken}) async {
    final connectionId = ++_connectionId;
    await _closeSocket();
    _lastError = null;
    connectionState.value = RemoteConnectionState.connecting;

    final resolvedUrl = accessToken == null || accessToken.isEmpty
        ? url
        : url.replace(
            queryParameters: <String, String>{
              ...url.queryParameters,
              'access_token': accessToken,
            },
          );

    try {
      final socket = await WebSocket.connect(resolvedUrl.toString());
      if (connectionId != _connectionId) {
        await socket.close();
        return;
      }

      _socket = socket;
      // Send periodic pings to surface silent disconnects quickly.
      socket.pingInterval = const Duration(seconds: 15);
      connectionState.value = RemoteConnectionState.connected;
      socket.done.then((_) => _handleSocketClosed(connectionId)).catchError(
        (Object error) => _handleSocketError(connectionId, error),
      );
    } catch (error) {
      if (connectionId == _connectionId) {
        _socket = null;
        _lastError = error;
        connectionState.value = RemoteConnectionState.error;
      }
      rethrow;
    }
  }

  Future<void> send(CommandEnvelope command) async {
    final socket = _socket;
    if (socket == null) {
      throw StateError('No active WebSocket connection.');
    }

    socket.add(jsonEncode(command.toJson()));
  }

  Future<void> dispose() async {
    _connectionId++;
    await _closeSocket();
    _lastError = null;
    connectionState.value = RemoteConnectionState.disconnected;
  }

  Future<void> _closeSocket() async {
    await _socket?.close();
    _socket = null;
  }

  void _handleSocketClosed(int connectionId) {
    if (connectionId != _connectionId) {
      return;
    }
    _socket = null;
    connectionState.value = RemoteConnectionState.disconnected;
  }

  void _handleSocketError(int connectionId, Object error) {
    if (connectionId != _connectionId) {
      return;
    }
    _socket = null;
    _lastError = error;
    connectionState.value = RemoteConnectionState.error;
  }
}
