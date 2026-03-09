import 'dart:convert';
import 'dart:io';

import '../models/command.dart';

class RemoteClient {
  WebSocket? _socket;

  bool get isConnected => _socket != null;

  Future<void> connect(Uri url, {String? accessToken}) async {
    await dispose();

    final resolvedUrl = accessToken == null || accessToken.isEmpty
        ? url
        : url.replace(
            queryParameters: <String, String>{
              ...url.queryParameters,
              'access_token': accessToken,
            },
          );
    _socket = await WebSocket.connect(resolvedUrl.toString());
  }

  Future<void> send(CommandEnvelope command) async {
    final socket = _socket;
    if (socket == null) {
      throw StateError('No active WebSocket connection.');
    }

    socket.add(jsonEncode(command.toJson()));
  }

  Future<void> dispose() async {
    await _socket?.close();
    _socket = null;
  }
}
