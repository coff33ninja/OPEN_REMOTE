import 'dart:async';

import 'package:multicast_dns/multicast_dns.dart';

import '../models/device.dart';

class DiscoveryService {
  const DiscoveryService({
    this.serviceType = '_openremote._tcp',
    this.lookupTimeout = const Duration(seconds: 2),
  });

  final String serviceType;
  final Duration lookupTimeout;

  Future<List<Device>> discover() async {
    final client = MDnsClient();
    final devices = <String, Device>{};

    try {
      await client.start();
      final ptrRecords = await client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer('$serviceType.local'),
          )
          .timeout(
            lookupTimeout,
            onTimeout: (EventSink<PtrResourceRecord> sink) => sink.close(),
          )
          .toList();

      for (final ptr in ptrRecords) {
        final srvRecords = await client
            .lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
            )
            .timeout(
              lookupTimeout,
              onTimeout: (EventSink<SrvResourceRecord> sink) => sink.close(),
            )
            .toList();
        final txtRecords = await client
            .lookup<TxtResourceRecord>(
              ResourceRecordQuery.text(ptr.domainName),
            )
            .timeout(
              lookupTimeout,
              onTimeout: (EventSink<TxtResourceRecord> sink) => sink.close(),
            )
            .toList();

        final txtValues = <String, String>{};
        for (final record in txtRecords) {
          final entry = record.text;
          final separator = entry.indexOf('=');
          if (separator <= 0) {
            continue;
          }
          txtValues[entry.substring(0, separator)] =
              entry.substring(separator + 1);
        }

        for (final srv in srvRecords) {
          final hosts = await _resolveAddresses(client, srv.target);
          for (final host in hosts) {
            final id = '$host:${srv.port}';
            devices[id] = Device(
              id: id,
              name: _displayName(ptr.domainName),
              host: host,
              port: srv.port,
              serviceType: serviceType,
              websocketPath: txtValues['ws_path'] ?? '/ws',
              wakeTarget: txtValues['wake_mac'] == null
                  ? null
                  : WakeTarget(
                      mac: txtValues['wake_mac'] ?? '',
                      broadcast: txtValues['wake_broadcast'] ?? '',
                      port: int.tryParse(txtValues['wake_port'] ?? '') ?? 9,
                    ),
            );
          }
        }
      }
    } finally {
      client.stop();
    }

    return devices.values.toList()
      ..sort((Device left, Device right) => left.name.compareTo(right.name));
  }

  Future<List<String>> _resolveAddresses(
      MDnsClient client, String target) async {
    final ipv4Records = await client
        .lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(target),
        )
        .timeout(
          lookupTimeout,
          onTimeout: (EventSink<IPAddressResourceRecord> sink) => sink.close(),
        )
        .toList();
    if (ipv4Records.isNotEmpty) {
      return ipv4Records
          .map((IPAddressResourceRecord record) => record.address.address)
          .toList();
    }

    final ipv6Records = await client
        .lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv6(target),
        )
        .timeout(
          lookupTimeout,
          onTimeout: (EventSink<IPAddressResourceRecord> sink) => sink.close(),
        )
        .toList();

    return ipv6Records
        .map((IPAddressResourceRecord record) => record.address.address)
        .toList();
  }

  String _displayName(String domainName) {
    final suffix = '.$serviceType.local';
    if (domainName.endsWith(suffix)) {
      return domainName.substring(0, domainName.length - suffix.length);
    }

    return domainName.replaceAll('.local', '');
  }
}
