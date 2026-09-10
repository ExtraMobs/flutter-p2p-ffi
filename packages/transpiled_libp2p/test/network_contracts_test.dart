// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  test('network error strings and matches reproduce Go contracts', () {
    final stream = StreamException(
      errorCode: streamProtocolViolation,
      remote: true,
      transportError: StateError('closed'),
    );
    final connection = ConnException(errorCode: connShutdown, remote: false);

    expect(
      stream.toString(),
      'stream reset (remote): code: 0x1004: transport error: Bad state: closed',
    );
    expect(connection.toString(), 'connection closed (local): code: 0x1006');
    expect(
      stream.matches(
        StreamException(errorCode: streamProtocolViolation, remote: true),
      ),
      isTrue,
    );
    expect(
      connection.matches(ConnException(errorCode: connShutdown, remote: false)),
      isTrue,
    );
    expect(() => StreamException(errorCode: -1, remote: false), throwsRangeError);
  });

  test('NAT values and null resource manager reproduce exported behavior', () {
    expect(NatDeviceType.endpointIndependent.text, 'Endpoint Independent');
    expect(NatTransportProtocol.udp.text, 'UDP');
    expect(natDeviceTypeCone, NatDeviceType.endpointIndependent);

    const manager = NullResourceManager();
    var systemVisited = false;
    manager.viewSystem((scope) {
      systemVisited = true;
      expect(scope.stat().memory, 0);
    });
    expect(systemVisited, isTrue);
    expect(manager.verifySourceAddress(Object()), isFalse);
  });

  test('notify bundle is a no-op until each callback is set', () {
    var listens = 0;
    var closes = 0;
    var connections = 0;
    var disconnections = 0;
    final bundle = NotifyBundle(
      listenF: (_, _) => listens++,
      listenCloseF: (_, _) => closes++,
      connectedF: (_, _) => connections++,
      disconnectedF: (_, _) => disconnections++,
    );

    bundle.listen(_Network(), Multiaddr.empty);
    bundle.listenClose(_Network(), Multiaddr.empty);
    bundle.connected(_Network(), _Conn());
    bundle.disconnected(_Network(), _Conn());

    expect((listens, closes, connections, disconnections), (1, 1, 1, 1));
    const NoopNotifiee().listen(_Network(), Multiaddr.empty);
  });
}

final class _Network implements Network {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Conn implements Conn {}
