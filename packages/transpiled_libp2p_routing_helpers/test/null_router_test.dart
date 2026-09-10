// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Parity vectors from go-libp2p-routing-helpers's own null_test.go
// (go-ipfs-reference/go-libp2p-routing-helpers/null_test.go, TestNull).
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_routing_helpers/transpiled_libp2p_routing_helpers.dart';

void main() {
  group('NullRouter', () {
    const n = NullRouter();

    test('putValue always throws RoutingNotSupportedException', () {
      expect(
        () => n.putValue('anything', Uint8List(0)),
        throwsA(isA<RoutingNotSupportedException>()),
      );
    });

    test('getValue always throws RoutingNotFoundException', () {
      expect(
        () => n.getValue('anything'),
        throwsA(isA<RoutingNotFoundException>()),
      );
    });

    test('provide always throws RoutingNotSupportedException', () async {
      final cid = await Cid.fromContent(Uint8List(0));
      expect(
        () => n.provide(cid, false),
        throwsA(isA<RoutingNotSupportedException>()),
      );
    });

    test('findProvidersAsync always returns an empty stream', () async {
      final cid = await Cid.fromContent(Uint8List(0));
      final results = await n.findProvidersAsync(cid, 10).toList();
      expect(results, isEmpty);
    });

    test('findPeer always throws RoutingNotFoundException', () {
      final id = PeerId(value: Uint8List.fromList('thing'.codeUnits));
      expect(() => n.findPeer(id), throwsA(isA<RoutingNotFoundException>()));
    });

    test('bootstrap always succeeds instantly', () {
      expect(n.bootstrap(), completes);
    });
  });
}
