// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Parity vectors from go-libp2p-routing-helpers's own composed_test.go
// behavior (unset components behave like NullRouter).
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_routing_helpers/transpiled_libp2p_routing_helpers.dart';

import 'dummy_value_store.dart';

void main() {
  group('Compose', () {
    test('an unset ValueStore behaves like NullRouter', () async {
      final compose = Compose();
      expect(
        () => compose.putValue('key', Uint8List(0)),
        throwsA(isA<RoutingNotSupportedException>()),
      );
      expect(
        () => compose.getValue('key'),
        throwsA(isA<RoutingNotFoundException>()),
      );
    });

    test('a set ValueStore is delegated to', () async {
      final store = DummyValueStore();
      final compose = Compose(valueStore: store);
      final value = Uint8List.fromList([1, 2, 3]);
      await compose.putValue('/x/y', value);
      expect(await compose.getValue('/x/y'), equals(value));
    });

    test('an unset ContentRouting behaves like NullRouter', () async {
      final compose = Compose();
      final cid = await Cid.fromContent(Uint8List(0));
      expect(
        () => compose.provide(cid, false),
        throwsA(isA<RoutingNotSupportedException>()),
      );
      expect(await compose.findProvidersAsync(cid, 1).toList(), isEmpty);
    });

    test('an unset PeerRouting behaves like NullRouter', () async {
      final compose = Compose();
      final id = PeerId(value: Uint8List.fromList('x'.codeUnits));
      expect(
        () => compose.findPeer(id),
        throwsA(isA<RoutingNotFoundException>()),
      );
    });

    test(
      'bootstrap deduplicates identical components and combines errors',
      () async {
        final shared = DummyValueStore();
        final compose = Compose(valueStore: shared);
        await compose.bootstrap();
        expect(shared.bootstrapCalls, equals(1));
      },
    );
  });
}
