import 'dart:async';
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
  StreamSubscription<dynamic>? _subscription;
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
      _subscription = socket.listen(
        (dynamic message) => _handleSocketMessage(connectionId, message),
        onError: (Object error) => _handleSocketError(connectionId, error),
        onDone: () => _handleSocketClosed(connectionId),
        cancelOnError: true,
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
    await _subscription?.cancel();
    _subscription = null;
    await _socket?.close();
    _socket = null;
  }

  void _handleSocketMessage(int connectionId, Object? _) {
    if (connectionId != _connectionId) {
      return;
    }
  }

  void _handleSocketClosed(int connectionId) {
    if (connectionId != _connectionId) {
      return;
    }
    _socket = null;
    _subscription = null;
    connectionState.value = RemoteConnectionState.disconnected;
  }

  void _handleSocketError(int connectionId, Object error) {
    if (connectionId != _connectionId) {
      return;
    }
    _socket = null;
    _subscription = null;
    _lastError = error;
    connectionState.value = RemoteConnectionState.error;
  }
}
