// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:io';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/p2p/net/nat/internal/nat/nat.dart';

class _MockInternalNat implements Nat {
  _MockInternalNat({
    this.natType = 'mock-nat',
    InternetAddress? deviceAddr,
    InternetAddress? externalAddr,
    InternetAddress? internalAddr,
  }) : _deviceAddr = deviceAddr ?? InternetAddress('192.168.1.1'),
       _externalAddr = externalAddr ?? InternetAddress('203.0.113.10'),
       _internalAddr = internalAddr ?? InternetAddress('192.168.1.100');

  final String natType;
  final InternetAddress _deviceAddr;
  final InternetAddress _externalAddr;
  final InternetAddress _internalAddr;

  final Map<String, int> mappings = {};

  @override
  String type() => natType;

  @override
  Future<InternetAddress> getDeviceAddress() async => _deviceAddr;

  @override
  Future<InternetAddress> getExternalAddress() async => _externalAddr;

  @override
  Future<InternetAddress> getInternalAddress() async => _internalAddr;

  @override
  Future<int> addPortMapping(
    String protocol,
    int internalPort,
    String description,
    Duration timeout,
  ) async {
    mappings['$protocol:$internalPort'] = internalPort;
    return internalPort;
  }

  @override
  Future<void> deletePortMapping(String protocol, int internalPort) async {
    mappings.remove('$protocol:$internalPort');
  }
}

void main() {
  group('NoExternalAddressException [Atomic Audit]', () {
    test('toString() - returns descriptive error string', () {
      const err = NoExternalAddressException();
      expect(err.toString(), equals('no external address'));
    });
  });

  group('NoInternalAddressException [Atomic Audit]', () {
    test('toString() - returns descriptive error string', () {
      const err = NoInternalAddressException();
      expect(err.toString(), equals('no internal address'));
    });
  });

  group('NoNatFoundException [Atomic Audit]', () {
    test('toString() - formats contained errors', () {
      final err = NoNatFoundException([
        Exception('timeout'),
        Exception('unreachable'),
      ]);
      expect(err.toString(), contains('no NAT found:'));
      expect(err.toString(), contains('timeout'));
      expect(err.toString(), contains('unreachable'));
      expect(err.errs, hasLength(2));
    });
  });

  group('Nat [Atomic Audit]', () {
    test('type() - returns NAT implementation type', () {
      final nat = _MockInternalNat(natType: 'UPNP (IG1)');
      expect(nat.type(), equals('UPNP (IG1)'));
    });

    test('getDeviceAddress() - returns gateway address', () async {
      final nat = _MockInternalNat();
      final dev = await nat.getDeviceAddress();
      expect(dev.address, equals('192.168.1.1'));
    });

    test('getExternalAddress() - returns external WAN address', () async {
      final nat = _MockInternalNat();
      final ext = await nat.getExternalAddress();
      expect(ext.address, equals('203.0.113.10'));
    });

    test('getInternalAddress() - returns internal local address', () async {
      final nat = _MockInternalNat();
      final internal = await nat.getInternalAddress();
      expect(internal.address, equals('192.168.1.100'));
    });

    test('addPortMapping() - creates port mapping', () async {
      final nat = _MockInternalNat();
      final port = await nat.addPortMapping(
        'tcp',
        4001,
        'test',
        const Duration(seconds: 30),
      );
      expect(port, equals(4001));
      expect(nat.mappings['tcp:4001'], equals(4001));
    });

    test('deletePortMapping() - removes port mapping', () async {
      final nat = _MockInternalNat();
      await nat.addPortMapping(
        'tcp',
        4001,
        'test',
        const Duration(seconds: 30),
      );
      await nat.deletePortMapping('tcp', 4001);
      expect(nat.mappings.containsKey('tcp:4001'), isFalse);
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('randomPort() - returns port in valid dynamic range', () {
      for (var i = 0; i < 50; i++) {
        final p = randomPort();
        expect(p, greaterThanOrEqualTo(10000));
        expect(p, lessThanOrEqualTo(65535));
      }
    });

    test(
      'discoverNats() - returns discovered NATs or empty without hanging',
      () async {
        final (nats, errs) = await discoverNats(
          const Duration(milliseconds: 100),
        );
        expect(nats, isA<List<Nat>>());
        expect(errs, isA<List<Exception>>());
      },
    );

    test('discoverGateway() - attempts discovery with short timeout', () async {
      try {
        final nat = await discoverGateway(const Duration(milliseconds: 100));
        expect(nat, isNotNull);
      } on NoNatFoundException catch (e) {
        expect(e.toString(), contains('no NAT found'));
      }
    });
  });
}
