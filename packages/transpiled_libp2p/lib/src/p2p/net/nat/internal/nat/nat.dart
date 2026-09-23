// ignore_for_file: public_member_api_docs
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

part 'upnp.dart';

/// Thrown when no external address is found on the NAT gateway.
class NoExternalAddressException implements Exception {
  const NoExternalAddressException();

  @override
  String toString() => 'no external address';
}

/// Thrown when no internal address is found on the local host.
class NoInternalAddressException implements Exception {
  const NoInternalAddressException();

  @override
  String toString() => 'no internal address';
}

/// Thrown when no NAT gateway is discovered on the network.
class NoNatFoundException implements Exception {
  const NoNatFoundException(this.errs);

  final List<Exception> errs;

  @override
  String toString() {
    final errStrs = errs.map((e) => e.toString()).join('; ');
    return 'no NAT found: [$errStrs]';
  }
}

/// Common interface for NAT devices (UPnP, NAT-PMP, etc.).
abstract interface class Nat {
  /// Returns the kind of NAT port mapping service that is used.
  String type();

  /// Returns the internal address of the gateway device.
  Future<InternetAddress> getDeviceAddress();

  /// Returns the external address of the gateway device.
  Future<InternetAddress> getExternalAddress();

  /// Returns the address of the local host.
  Future<InternetAddress> getInternalAddress();

  /// Maps a port on the local host to an external port.
  Future<int> addPortMapping(
    String protocol,
    int internalPort,
    String description,
    Duration timeout,
  );

  /// Removes a port mapping.
  Future<void> deletePortMapping(String protocol, int internalPort);
}

final _random = Random();

/// Generates a random port between 10000 and 65535.
int randomPort() {
  return _random.nextInt(65535 - 10000) + 10000;
}

/// Returns all NATs discovered in the network.
Future<(List<Nat>, List<Exception>)> discoverNats([
  Duration timeout = const Duration(seconds: 5),
]) async {
  final nats = <Nat>[];
  final errs = <Exception>[];

  try {
    final (ig1Nats, ig1Errs) = await _discoverUpnpIg1(timeout: timeout);
    nats.addAll(ig1Nats);
    errs.addAll(ig1Errs);

    final (ig2Nats, ig2Errs) = await _discoverUpnpIg2(timeout: timeout);
    nats.addAll(ig2Nats);
    errs.addAll(ig2Errs);

    if (nats.isEmpty) {
      final (genNats, genErrs) = await _discoverUpnpGenIgDev(timeout: timeout);
      nats.addAll(genNats);
      errs.addAll(genErrs);
    }
  } catch (e) {
    errs.add(e is Exception ? e : Exception(e.toString()));
  }

  return (nats, errs);
}

/// Attempts to find a gateway device on the local network.
Future<Nat> discoverGateway([
  Duration timeout = const Duration(seconds: 5),
]) async {
  final (nats, errs) = await discoverNats(timeout);

  if (nats.isEmpty) {
    throw NoNatFoundException(errs);
  }

  if (nats.length == 1) {
    if (errs.isNotEmpty) {
      dev.log(
        'NAT found, but some potentially unrelated errors occurred: $errs',
        name: 'libp2p.nat',
      );
    }
    return nats[0];
  }

  // Prefer gateways discovered last or best matching
  final bestNAT = nats.last;
  if (errs.isNotEmpty) {
    dev.log(
      'NAT found, but some potentially unrelated errors occurred: $errs',
      name: 'libp2p.nat',
    );
  }
  return bestNAT;
}
