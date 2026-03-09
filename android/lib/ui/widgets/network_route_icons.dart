import 'package:flutter/material.dart';

import '../../core/models/device.dart';

IconData networkRouteIcon(
  String kind, {
  bool canWake = false,
  bool isVirtual = false,
}) {
  switch (kind) {
    case NetworkTransportKind.ethernet:
      return Icons.settings_ethernet;
    case NetworkTransportKind.wifi:
      return Icons.wifi;
    case NetworkTransportKind.vpn:
      return Icons.vpn_key;
    case NetworkTransportKind.virtualAdapter:
      return Icons.hub;
    case NetworkTransportKind.usb:
      return Icons.usb;
    case NetworkTransportKind.configured:
      return Icons.language;
    default:
      if (canWake) {
        return Icons.wifi_tethering;
      }
      if (isVirtual) {
        return Icons.hub;
      }
      return Icons.device_hub;
  }
}
