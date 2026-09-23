// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:io';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/p2p/net/nat/internal/nat/nat.dart' as nat_package;
import 'package:transpiled_libp2p/src/p2p/net/nat/nat.dart';

class _MockInternalNat implements nat_package.Nat {
  _MockInternalNat({
    InternetAddress? extAddr,
  }) : _extAddr = extAddr ?? InternetAddress('203.0.113.88');

  final InternetAddress _extAddr;
  final Map<String, int> mappings = {};

  @override
  String type() => 'mock-internal-nat';

  @override
  Future<InternetAddress> getDeviceAddress() async => InternetAddress('192.168.1.1');

  @override
  Future<InternetAddress> getExternalAddress() async => _extAddr;

  @override
  Future<InternetAddress> getInternalAddress() async => InternetAddress('192.168.1.50');

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
  group('NoMappingException [Atomic Audit]', () {
    test('toString() - returns descriptive error string', () {
      const err = NoMappingException();
      expect(err.toString(), equals('mapping not established'));
    });
  });

  group('Nat [Atomic Audit]', () {
    test('addMapping() - adds mapping and returns external port', () async {
      final mock = _MockInternalNat();
      final nat = Nat(mock);
      addTearDown(nat.close);

      final extPort = await nat.addMapping('tcp', 4001);
      expect(extPort, equals(4001));
    });

    test('getMapping() - retrieves mapped external address and port', () async {
      final mock = _MockInternalNat();
      final nat = Nat(mock);
      addTearDown(nat.close);

      await nat.addMapping('tcp', 4001);
      // Allow background external address update to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final mapping = nat.getMapping('tcp', 4001);
      expect(mapping, isNotNull);
      expect(mapping!.$1.address, equals('203.0.113.88'));
      expect(mapping.$2, equals(4001));
    });

    test('removeMapping() - removes active mapping from gateway', () async {
      final mock = _MockInternalNat();
      final nat = Nat(mock);
      addTearDown(nat.close);

      await nat.addMapping('tcp', 4001);
      await nat.removeMapping('tcp', 4001);

      expect(() => nat.removeMapping('tcp', 4001), throwsA(isA<NoMappingException>()));
    });

    test('close() - shuts down active mappings and stops background renewal', () async {
      final mock = _MockInternalNat();
      final nat = Nat(mock);

      await nat.addMapping('tcp', 4001);
      await nat.close();

      expect(() => nat.addMapping('tcp', 4002), throwsA(isA<StateError>()));
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('discoverNat() - executes NAT discovery with timeout', () async {
      try {
        final nat = await discoverNat(const Duration(milliseconds: 100));
        addTearDown(nat.close);
        expect(nat, isNotNull);
      } catch (e) {
        expect(e, isA<nat_package.NoNatFoundException>());
      }
    });
  });
}
