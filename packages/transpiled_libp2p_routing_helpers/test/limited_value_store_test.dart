// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Parity vectors from go-libp2p-routing-helpers's own limited_test.go
// (TestLimitedValueStore).
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_routing_helpers/transpiled_libp2p_routing_helpers.dart';

import 'dummy_value_store.dart';

void main() {
  group('LimitedValueStore', () {
    test(
      'allows keys under a supported namespace, denies everything else',
      () async {
        final store = DummyValueStore();
        final limited = LimitedValueStore(
          valueStore: store,
          namespaces: const ['allow'],
        );

        for (var i = 0; i < 3; i++) {
          final key = ['/allow/hello', '/allow/foo', '/allow/foo/bar'][i];
          final value = Uint8List.fromList([i]);
          await limited.putValue(key, value);
          final got = await limited.getValue(key);
          expect(got, equals(value));
        }

        for (final key in const [
          '/deny/hello',
          '/allow',
          'allow',
          'deny',
          '',
          '/',
          '//',
          '///',
          '//allow',
        ]) {
          expect(
            () => limited.putValue(key, Uint8List.fromList([1])),
            throwsA(isA<RoutingNotSupportedException>()),
            reason: 'expected put with key "$key" to be rejected',
          );
          expect(
            () => limited.getValue(key),
            throwsA(isA<RoutingNotFoundException>()),
            reason: 'expected get with key "$key" to be rejected',
          );

          // The underlying store itself has no such restriction.
          await store.putValue(key, Uint8List.fromList([1]));
          expect(
            () => limited.getValue(key),
            throwsA(anything),
            reason:
                'the namespace restriction still applies even once the'
                ' value exists in the underlying store',
          );
        }
      },
    );

    test(
      'bootstrap delegates to the underlying store when it supports it',
      () async {
        final store = DummyValueStore();
        final limited = LimitedValueStore(
          valueStore: store,
          namespaces: const [],
        );
        await limited.bootstrap();
        expect(store.bootstrapCalls, equals(1));
      },
    );
  });
}
