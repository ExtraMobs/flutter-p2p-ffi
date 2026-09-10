import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/core/discovery/options.dart';
import 'package:transpiled_libp2p/src/core/protocol/protocol.dart';
import 'package:transpiled_libp2p/src/core/network/network.dart';

// Upstream: go-libp2p e20bb60ffc4b4ee33640e5fe8f45fccce893cecd,
// core/discovery/options.go and core/protocol/id.go. AST: libp2p-index.
void main() {
  // core/network/context.go: With*/Get* delegate to context.WithValue/Value.
  // Dart's immutable NetworkContext carries those values through copyWith.
  group('NetworkContext [Atomic Audit]', () {
    test('copyWith() - preserves unrelated values and the original', () {
      const original = NetworkContext(noDialReason: 'reuse');
      final updated = original.copyWith(forceDirectDialReason: 'direct');
      expect(updated.noDialReason, 'reuse');
      expect(updated.forceDirectDialReason, 'direct');
      expect(original.forceDirectDialReason, isNull);
    });
  });
  test('withForceDirectDial() - creates an independent context', () {
    final updated = withForceDirectDial(NetworkContext.empty, 'direct');
    expect(getForceDirectDial(updated), (true, 'direct'));
    expect(getForceDirectDial(NetworkContext.empty), (false, ''));
  });
  test('getForceDirectDial() - empty reason still enables the option', () {
    expect(getForceDirectDial(NetworkContext.empty), (false, ''));
    expect(getForceDirectDial(withForceDirectDial(NetworkContext.empty, '')), (
      true,
      '',
    ));
  });
  test('withNoDial() - preserves other options', () {
    final updated = withNoDial(
      withForceDirectDial(NetworkContext.empty, 'direct'),
      'reuse',
    );
    expect(getNoDial(updated), (true, 'reuse'));
    expect(getForceDirectDial(updated), (true, 'direct'));
  });
  test('getNoDial() - distinguishes absent and empty reason', () {
    expect(getNoDial(NetworkContext.empty), (false, ''));
    expect(getNoDial(withNoDial(NetworkContext.empty, '')), (true, ''));
  });
  test('withDialPeerTimeout() - accepts zero without changing the default', () {
    final original = getDialPeerTimeout(NetworkContext.empty);
    expect(
      getDialPeerTimeout(
        withDialPeerTimeout(NetworkContext.empty, Duration.zero),
      ),
      Duration.zero,
    );
    expect(getDialPeerTimeout(NetworkContext.empty), original);
  });
  test('getDialPeerTimeout() - falls back to the current default', () {
    final original = dialPeerTimeout;
    addTearDown(() => dialPeerTimeout = original);
    dialPeerTimeout = const Duration(seconds: 3);
    expect(
      getDialPeerTimeout(NetworkContext.empty),
      const Duration(seconds: 3),
    );
    expect(
      getDialPeerTimeout(
        const NetworkContext(dialPeerTimeout: Duration(seconds: -1)),
      ),
      const Duration(seconds: -1),
    );
  });
  test('withSimultaneousConnect() - retains both roles', () {
    final client = withSimultaneousConnect(
      NetworkContext.empty,
      true,
      'client',
    );
    final both = withSimultaneousConnect(client, false, 'server');
    expect(both.simultaneousConnectClientReason, 'client');
    expect(both.simultaneousConnectServerReason, 'server');
    expect(client.simultaneousConnectServerReason, isNull);
  });
  test('getSimultaneousConnect() - client takes precedence over server', () {
    expect(getSimultaneousConnect(NetworkContext.empty), (false, false, ''));
    final server = withSimultaneousConnect(
      NetworkContext.empty,
      false,
      'server',
    );
    expect(getSimultaneousConnect(server), (true, false, 'server'));
    expect(getSimultaneousConnect(withSimultaneousConnect(server, true, '')), (
      true,
      true,
      '',
    ));
  });
  test(
    'withAllowLimitedConn() - enables limited connections independently',
    () {
      final updated = withAllowLimitedConn(NetworkContext.empty, 'relay');
      expect(getAllowLimitedConn(updated), (true, 'relay'));
      expect(getAllowLimitedConn(NetworkContext.empty), (false, ''));
    },
  );
  test('getAllowLimitedConn() - distinguishes absent and empty reason', () {
    expect(getAllowLimitedConn(NetworkContext.empty), (false, ''));
    expect(
      getAllowLimitedConn(withAllowLimitedConn(NetworkContext.empty, '')),
      (true, ''),
    );
  });
  test('withUseTransient() - shares the limited connection option', () {
    // ignore: deprecated_member_use_from_same_package
    final updated = withUseTransient(NetworkContext.empty, 'transient');
    expect(getAllowLimitedConn(updated), (true, 'transient'));
  });
  test('getUseTransient() - reads the canonical limited connection option', () {
    // ignore: deprecated_member_use_from_same_package
    expect(getUseTransient(NetworkContext.empty), (false, ''));
    // ignore: deprecated_member_use_from_same_package
    expect(
      getUseTransient(withAllowLimitedConn(NetworkContext.empty, 'relay')),
      (true, 'relay'),
    );
  });
  test('withConnManagementScope() - stores the exact scope object', () {
    const scope = NullScope();
    final updated = withConnManagementScope(NetworkContext.empty, scope);
    expect(unwrapConnManagementScope(updated), same(scope));
    expect(NetworkContext.empty.connManagementScope, isNull);
  });
  test('unwrapConnManagementScope() - rejects a context without a scope', () {
    expect(
      () => unwrapConnManagementScope(NetworkContext.empty),
      throwsA(isA<MissingConnManagementScopeException>()),
    );
    expect(
      unwrapConnManagementScope(
        withConnManagementScope(NetworkContext.empty, const NullScope()),
      ),
      isA<ConnManagementScope>(),
    );
  });
  test(
    'convertFromStrings() - preserves order, duplicates and empty input',
    () {
      final input = ['/a', '/b', '/a'];
      final result = convertFromStrings(input);
      input.clear();
      expect(result, ['/a', '/b', '/a']);
      expect(convertFromStrings([]), isEmpty);
    },
  );
  test('convertToStrings() - preserves identifiers and copies the input', () {
    final input = <ProtocolId>['/a', '', '/a'];
    final result = convertToStrings(input);
    input.clear();
    expect(result, ['/a', '', '/a']);
    expect(convertToStrings([]), isEmpty);
  });
  test('ttl() - assigns duration without modifying the limit', () {
    final options = DiscoveryOptions()..limit = 7;
    ttl(const Duration(seconds: -1))(options);
    expect(options.ttl, const Duration(seconds: -1));
    expect(options.limit, 7);
  });
  test('limit() - preserves zero and negative values', () {
    final options = DiscoveryOptions();
    limit(-1)(options);
    expect(options.limit, -1);
    limit(0)(options);
    expect(options.limit, 0);
    expect(options.ttl, Duration.zero);
  });
  group('DiscoveryOptions [Atomic Audit]', () {
    test('apply() - ordered options stop at the first error', () {
      final options = DiscoveryOptions();
      final failure = StateError('option failed');
      expect(options.other, isNull);
      expect(
        () => options.apply([
          limit(3),
          ttl(const Duration(seconds: 5)),
          limit(4),
          (_) => throw failure,
          limit(9),
        ]),
        throwsA(same(failure)),
      );
      expect(options.limit, 4);
      expect(options.ttl, const Duration(seconds: 5));
      options.apply([]);
      expect(options.limit, 4);
    });
  });
}
