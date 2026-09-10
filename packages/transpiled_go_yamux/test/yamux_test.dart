// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_go_yamux/transpiled_go_yamux.dart';

class _Link implements YamuxTransport {
  _Link._(this._input);
  final StreamController<List<int>> _input;
  late final _Link _peer;
  bool _closed = false;

  static (_Link, _Link) pair() {
    late _Link a;
    late _Link b;
    a = _Link._(StreamController<List<int>>());
    b = _Link._(StreamController<List<int>>());
    a._peer = b;
    b._peer = a;
    return (a, b);
  }

  @override
  Stream<List<int>> get input => _input.stream;

  @override
  Future<void> write(Uint8List bytes) async {
    if (!_closed) _peer._input.add(Uint8List.fromList(bytes));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _input.close();
  }
}

void main() {
  test('encodes and incrementally decodes the upstream header vector', () {
    final frame = YamuxFrame(
      type: YamuxMessageType.data,
      flags: yamuxSyn,
      streamId: 1234,
      payload: Uint8List.fromList([1, 2, 3]),
    );
    expect(frame.encode(), [0, 0, 0, 1, 0, 0, 4, 210, 0, 0, 0, 3, 1, 2, 3]);
    final decoder = YamuxFrameDecoder();
    expect(decoder.add(frame.encode().sublist(0, 4)), isEmpty);
    final decoded = decoder.add(frame.encode().sublist(4)).single;
    expect(decoded.type, YamuxMessageType.data);
    expect(decoded.flags, yamuxSyn);
    expect(decoded.streamId, 1234);
    expect(decoded.payload, [1, 2, 3]);
  });

  test(
    'opens with odd/even IDs, transfers data, and removes closed streams',
    () async {
      final (clientTransport, serverTransport) = _Link.pair();
      final client = YamuxSession(clientTransport, isClient: true);
      final server = YamuxSession(serverTransport, isClient: false);
      final accepted = server.acceptStream();
      final outgoing = await client.openStream();
      final incoming = await accepted;
      expect(outgoing.streamId, 1);
      expect(incoming.streamId, 1);
      await outgoing.write(Uint8List.fromList([7, 8, 9]));
      expect(await incoming.read(), [7, 8, 9]);
      await outgoing.close();
      await incoming.close();
      await Future<void>.delayed(Duration.zero);
      expect(client.numStreams, 0);
      expect(server.numStreams, 0);
      await client.close();
      await server.close();
    },
  );

  test('reset propagates its error code and shutdown closes streams', () async {
    final (clientTransport, serverTransport) = _Link.pair();
    final client = YamuxSession(clientTransport, isClient: true);
    final server = YamuxSession(serverTransport, isClient: false);
    final accepted = server.acceptStream();
    final outgoing = await client.openStream();
    final incoming = await accepted;
    final read = incoming.read();
    await outgoing.reset(42);
    await expectLater(read, throwsA(isA<YamuxStreamResetException>()));
    expect(client.numStreams, 0);
    expect(server.numStreams, 0);
    await client.close();
    await server.close();
  });

  test('MaxIncomingStreams resets excess incoming streams', () async {
    final (clientTransport, serverTransport) = _Link.pair();
    final client = YamuxSession(clientTransport, isClient: true);
    final server = YamuxSession(
      serverTransport,
      isClient: false,
      config: const YamuxConfig(maxIncomingStreams: 1),
    );
    final first = await client.openStream();
    final second = await client.openStream();
    await Future<void>.delayed(Duration.zero);
    expect(server.numIncomingStreams, 1);
    await expectLater(
      second.write(Uint8List.fromList([1])),
      throwsA(isA<YamuxStreamResetException>()),
    );
    await first.reset();
    await client.close();
    await server.close();
  });

  test('more than 1100 sequential streams do not remain retained', () async {
    final (clientTransport, serverTransport) = _Link.pair();
    final client = YamuxSession(clientTransport, isClient: true);
    final server = YamuxSession(serverTransport, isClient: false);
    for (var i = 0; i < 1101; i++) {
      final accepted = server.acceptStream();
      final outgoing = await client.openStream();
      final incoming = await accepted;
      await outgoing.close();
      await incoming.close();
    }
    await Future<void>.delayed(Duration.zero);
    expect(client.numStreams, 0);
    expect(server.numStreams, 0);
    await client.close();
    await server.close();
  });

  test('delivers DATA before EOF when FIN is piggybacked', () async {
    final (clientTransport, serverTransport) = _Link.pair();
    final server = YamuxSession(serverTransport, isClient: false);
    final accepted = server.acceptStream();
    await clientTransport.write(
      YamuxFrame(
        type: YamuxMessageType.data,
        flags: yamuxSyn | yamuxFin,
        streamId: 1,
        payload: Uint8List.fromList([4, 2]),
      ).encode(),
    );
    final incoming = await accepted;
    expect(await incoming.read(), [4, 2]);
    expect(await incoming.read(), isNull);
    await incoming.close();
    await server.close();
  });

  test('config defaults and upstream validation limits', () {
    expect(YamuxConfig.defaults.acceptBacklog, 256);
    expect(YamuxConfig.defaults.maxIncomingStreams, 1000);
    expect(YamuxConfig.defaults.initialStreamWindowSize, 256 * 1024);
    expect(
      () => const YamuxConfig(maxMessageSize: 1023).verify(),
      throwsA(isA<YamuxConfigException>()),
    );
  });

  test(
    'decoder rejects oversized DATA from its header before body arrives',
    () {
      final decoder = YamuxFrameDecoder(maxDataLength: 2);
      final header = YamuxFrame(
        type: YamuxMessageType.data,
        payload: Uint8List.fromList([1, 2, 3]),
      ).encode().sublist(0, yamuxHeaderSize);
      expect(() => decoder.add(header), throwsA(isA<YamuxProtocolException>()));
    },
  );

  test('incremental decoder rejects an invalid version from the header', () {
    final header = Uint8List.fromList([9, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0]);
    expect(
      () => YamuxFrameDecoder().add(header),
      throwsA(isA<YamuxProtocolException>()),
    );
  });

  test('config follows upstream validation for negative RTT interval', () {
    const config = YamuxConfig(measureRttInterval: Duration(seconds: -1));
    expect(config.verify, returnsNormally);
  });

  test(
    'a blocked writer wakes on remote reset and never sends after it',
    () async {
      final (clientTransport, serverTransport) = _Link.pair();
      final client = YamuxSession(clientTransport, isClient: true);
      final server = YamuxSession(serverTransport, isClient: false);
      final accepted = server.acceptStream();
      final outgoing = await client.openStream();
      final incoming = await accepted;
      final write = outgoing.write(Uint8List(300 * 1024));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await incoming.reset();
      await expectLater(write, throwsA(isA<YamuxStreamResetException>()));
      await client.close();
      await server.close();
    },
  );
}
