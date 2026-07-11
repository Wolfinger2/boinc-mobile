import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DiscoveredBoincHost {
  const DiscoveredBoincHost({
    required this.address,
    required this.port,
    required this.source,
    this.name,
  });

  final String address;
  final int port;
  final String source;
  final String? name;

  String get displayName =>
      (name == null || name!.trim().isEmpty) ? address : name!.trim();
}

class BoincNetworkDiscovery {
  static const int defaultBoincPort = 31416;
  static const int helperPort = 31417;

  Future<List<DiscoveredBoincHost>> discover({
    Duration helperDuration = const Duration(seconds: 4),
    Duration connectTimeout = const Duration(milliseconds: 350),
  }) async {
    final results = <String, DiscoveredBoincHost>{};

    final helperResults = await _listenForHelpers(helperDuration);
    for (final host in helperResults) {
      results['${host.address}:${host.port}'] = host;
    }

    final localAddresses = await _localIpv4Addresses();
    for (final address in localAddresses) {
      final subnetResults = await _scan24Subnet(
        address,
        timeout: connectTimeout,
      );
      for (final host in subnetResults) {
        results.putIfAbsent('${host.address}:${host.port}', () => host);
      }
    }

    final list = results.values.toList()
      ..sort((a, b) => _ipSortKey(a.address).compareTo(_ipSortKey(b.address)));
    return list;
  }

  Future<List<DiscoveredBoincHost>> _listenForHelpers(Duration duration) async {
    RawDatagramSocket? socket;
    final results = <String, DiscoveredBoincHost>{};
    StreamSubscription<RawSocketEvent>? subscription;

    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        helperPort,
        reuseAddress: true,
      );

      final completer = Completer<void>();
      subscription = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket?.receive();
        if (datagram == null) return;

        try {
          final decoded = jsonDecode(utf8.decode(datagram.data));
          if (decoded is! Map<String, dynamic>) return;
          if (decoded['service'] != 'boinc-mobile-helper') return;

          final port = (decoded['port'] as num?)?.toInt() ?? defaultBoincPort;
          final name = decoded['name']?.toString();
          final configuredAddress = decoded['address']?.toString().trim();
          final address = configuredAddress == null ||
                  configuredAddress.isEmpty ||
                  configuredAddress == '0.0.0.0'
              ? datagram.address.address
              : configuredAddress;

          final host = DiscoveredBoincHost(
            address: address,
            port: port,
            name: name,
            source: 'Helper',
          );
          results['${host.address}:${host.port}'] = host;
        } catch (_) {
          // Fremde oder unvollständige UDP-Pakete ignorieren.
        }
      });

      Timer(duration, () {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
    } on SocketException {
      // Der Subnetz-Scan läuft trotzdem weiter.
    } finally {
      await subscription?.cancel();
      socket?.close();
    }

    return results.values.toList();
  }

  Future<List<String>> _localIpv4Addresses() async {
    final addresses = <String>[];
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );

    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (_isPrivateIpv4(address.address)) addresses.add(address.address);
      }
    }
    return addresses.toSet().toList();
  }

  Future<List<DiscoveredBoincHost>> _scan24Subnet(
    String localAddress, {
    required Duration timeout,
  }) async {
    final parts = localAddress.split('.');
    if (parts.length != 4) return const [];

    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
    final results = <DiscoveredBoincHost>[];
    const batchSize = 32;

    for (var start = 1; start <= 254; start += batchSize) {
      final end = (start + batchSize - 1).clamp(1, 254);
      final futures = <Future<void>>[];

      for (var host = start; host <= end; host++) {
        final address = '$prefix.$host';
        futures.add(() async {
          Socket? socket;
          try {
            socket = await Socket.connect(
              address,
              defaultBoincPort,
              timeout: timeout,
            );
            results.add(
              DiscoveredBoincHost(
                address: address,
                port: defaultBoincPort,
                source: 'Netzwerksuche',
              ),
            );
          } catch (_) {
            // Nicht erreichbare Adressen sind beim Scan normal.
          } finally {
            await socket?.close();
          }
        }());
      }
      await Future.wait(futures);
    }
    return results;
  }

  bool _isPrivateIpv4(String address) {
    final parts = address.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) return false;
    final a = parts[0]!;
    final b = parts[1]!;
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }

  int _ipSortKey(String address) {
    final parts = address.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) {
      return 0xFFFFFFFF;
    }
    return (parts[0]! << 24) | (parts[1]! << 16) | (parts[2]! << 8) | parts[3]!;
  }
}
