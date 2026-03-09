import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/device.dart';
import '../models/remote_layout.dart';

class PersistedAppState {
  const PersistedAppState({
    this.pairedDevices = const <Device>[],
    this.favoriteDeviceIds = const <String>{},
    this.recentDeviceIds = const <String>[],
    this.favoriteRemoteIds = const <String>{},
    this.cachedRemoteLayouts = const <RemoteLayout>[],
    this.designedRemoteLayouts = const <RemoteLayout>[],
    this.selectedDeviceId,
  });

  final List<Device> pairedDevices;
  final Set<String> favoriteDeviceIds;
  final List<String> recentDeviceIds;
  final Set<String> favoriteRemoteIds;
  final List<RemoteLayout> cachedRemoteLayouts;
  final List<RemoteLayout> designedRemoteLayouts;
  final String? selectedDeviceId;

  factory PersistedAppState.fromJson(Map<String, dynamic> json) {
    return PersistedAppState(
      pairedDevices: (json['paired_devices'] as List<dynamic>? ??
              const <dynamic>[])
          .map((dynamic item) => Device.fromJson(item as Map<String, dynamic>))
          .toList(),
      favoriteDeviceIds:
          (json['favorite_device_ids'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic item) => item.toString())
              .toSet(),
      recentDeviceIds:
          (json['recent_device_ids'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic item) => item.toString())
              .toList(),
      favoriteRemoteIds:
          (json['favorite_remote_ids'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic item) => item.toString())
              .toSet(),
      cachedRemoteLayouts: (json['cached_remote_layouts'] as List<dynamic>? ??
              json['saved_remote_layouts'] as List<dynamic>? ??
              const <dynamic>[])
          .map((dynamic item) =>
              RemoteLayout.fromJson(item as Map<String, dynamic>))
          .toList(),
      designedRemoteLayouts:
          (json['designed_remote_layouts'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic item) =>
                  RemoteLayout.fromJson(item as Map<String, dynamic>))
              .toList(),
      // Backward compatibility for older persisted state.
      // Once the migration settles, `saved_remote_layouts` can be removed.
      /*
      savedRemoteLayouts:
          (json['saved_remote_layouts'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic item) =>
                  RemoteLayout.fromJson(item as Map<String, dynamic>))
              .toList(),
      */
      selectedDeviceId: json['selected_device_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'paired_devices':
          pairedDevices.map((Device device) => device.toJson()).toList(),
      'favorite_device_ids': favoriteDeviceIds.toList()..sort(),
      'recent_device_ids': recentDeviceIds,
      'favorite_remote_ids': favoriteRemoteIds.toList()..sort(),
      'cached_remote_layouts': cachedRemoteLayouts
          .map((RemoteLayout remote) => remote.toJson())
          .toList(),
      'designed_remote_layouts': designedRemoteLayouts
          .map((RemoteLayout remote) => remote.toJson())
          .toList(),
      'selected_device_id': selectedDeviceId,
    }..removeWhere((String key, dynamic value) => value == null);
  }
}

class AppStateStore {
  const AppStateStore();

  static const String _storageKey = 'openremote.persisted_state';

  Future<PersistedAppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const PersistedAppState();
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return PersistedAppState.fromJson(json);
    } catch (_) {
      return const PersistedAppState();
    }
  }

  Future<void> save(PersistedAppState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }
}
