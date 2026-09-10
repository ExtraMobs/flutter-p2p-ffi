// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Adapted from go-libp2p core/routing/query_test.go and
// query_race_test.go at e20bb60ffc4b4ee33640e5fe8f45fccce893cecd.
import 'dart:async';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  test('QueryEventType values match query.go iota values', () {
    expect([
      sendingQuery,
      peerResponse,
      finalPeer,
      queryError,
      provider,
      value,
      addingPeer,
      dialingPeer,
    ], equals(List<int>.generate(8, (index) => index)));
    expect(queryEventBufferSize, 16);
  });

  test('query event JSON matches Go and preserves unknown event types', () {
    const encoded = '{"Extra":"detail","ID":"","Responses":null,"Type":99}';
    final event = QueryEvent.fromJsonString(encoded);

    expect(event.id, isNull);
    expect(event.type, 99);
    expect(event.responses, isNull);
    expect(event.extra, 'detail');
    expect(event.toJsonString(), encoded);
  });

  test('events are ordered, cross async gaps, and close cleanly', () async {
    final registration = registerForQueryEvents();
    final received = <QueryEvent>[];
    final done = Completer<void>();
    registration.events.listen(received.add, onDone: done.complete);

    expect(subscribesToQueryEvents(), isFalse);
    await registration.run(() async {
      expect(subscribesToQueryEvents(), isTrue);
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 100; i++) {
        publishQueryEvent(QueryEvent(extra: '$i'));
      }
    });

    await registration.close();
    await done.future;
    expect(received.map((event) => event.extra), [
      for (var i = 0; i < 100; i++) '$i',
    ]);
  });

  test('publishing without a registered zone is a no-op', () {
    expect(
      () => publishQueryEvent(QueryEvent(extra: 'ignored')),
      returnsNormally,
    );
  });

  test('close cancels the registration and drains queued events', () async {
    final registration = registerForQueryEvents();
    final received = <String>[];
    final done = Completer<void>();
    registration.events.listen(
      (event) => received.add(event.extra),
      onDone: done.complete,
    );

    registration.run(() {
      publishQueryEvent(QueryEvent(extra: 'before'));
      publishQueryEvent(QueryEvent(extra: 'queued'));
    });
    await registration.close();
    registration.run(() => publishQueryEvent(QueryEvent(extra: 'after')));
    await done.future;

    expect(received, ['before', 'queued']);
  });

  test('responses and address lists are copied before delivery', () async {
    final registration = registerForQueryEvents();
    final received = registration.events.first;
    final originalAddress = Multiaddr.parse('/ip4/1.2.3.4/tcp/4001');
    final laterAddress = Multiaddr.parse('/ip4/5.6.7.8/tcp/4001');
    final peer = PeerId.decode(
      'QmYwAPJzv5CZsnAzt8auVZRnGiM2C6CBybVxDsaj6MPpud',
    );
    final info = AddrInfo(id: peer, addrs: [originalAddress]);
    final event = QueryEvent(type: peerResponse, responses: [info]);

    registration.run(() => publishQueryEvent(event));
    event.responses!.clear();
    info.addrs.add(laterAddress);

    final delivered = await received;
    expect(delivered.responses, hasLength(1));
    expect(delivered.responses!.single, isNot(same(info)));
    expect(delivered.responses!.single!.addrs, [originalAddress]);
    await registration.close();
  });
}
