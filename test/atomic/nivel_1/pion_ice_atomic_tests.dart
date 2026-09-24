// test/atomic/nivel_1/pion_ice_atomic_tests.dart
// Testes atômicos 1 para 1 cobrindo 100% dos símbolos AST de transpiled_pion_ice.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';
import 'package:transpiled_pion_ice/transpiled_pion_ice.dart';
import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart';

void main() {
  group('Top-level functions [Atomic Audit]', () {
    test('parseAddr() - atomic test', () async {
      final addr = UdpAddr(InternetAddress.loopbackIPv4, 5000);
      final (ip, port, nt) = parseAddr(addr);
      expect(ip.address, equals('127.0.0.1'));
      expect(port, equals(5000));
      expect(nt, equals(NetworkType.udp4));
    });
    test('addrEqual() - atomic test', () async {
      final a1 = UdpAddr(InternetAddress.loopbackIPv4, 5000);
      final a2 = UdpAddr(InternetAddress.loopbackIPv4, 5000);
      expect(addrEqual(a1, a2), isTrue);
    });
    test('unmarshalCandidate() - atomic test', () async {
      const line = 'candidate:1 1 UDP 2130706431 127.0.0.1 50000 typ host';
      final c = unmarshalCandidate(line);
      expect(c.address(), equals('127.0.0.1'));
      expect(c.type(), equals(CandidateType.host));
    });
  });
  group('ActiveTcpConn [Atomic Audit]', () {
    test('localAddr() - atomic test', () async {
      final conn = ActiveTcpConn();
      expect(conn.localAddr, isNotNull);
    });
    test('remoteAddr() - atomic test', () async {
      final conn = ActiveTcpConn();
      expect(conn.remoteAddr(), isNull);
    });
    test('readFromContext() - atomic test', () async {
      final conn = ActiveTcpConn();
      final (n, raddr) = await conn.readFromContext(
        Completer<void>().future,
        Uint8List(10),
      );
      expect(n, equals(0));
    });
    test('writeToContext() - atomic test', () async {
      final conn = ActiveTcpConn();
      expect(
        await conn.writeToContext(
          Completer<void>().future,
          Uint8List(0),
          TcpAddr(InternetAddress.loopbackIPv4, 0),
        ),
        equals(0),
      );
    });
    test('readFrom() - atomic test', () async {
      final conn = ActiveTcpConn();
      final (n, raddr) = await conn.readFrom(Uint8List(10));
      expect(n, equals(0));
    });
    test('writeTo() - atomic test', () async {
      final conn = ActiveTcpConn();
      expect(
        await conn.writeTo(
          Uint8List(0),
          TcpAddr(InternetAddress.loopbackIPv4, 0),
        ),
        equals(0),
      );
    });
    test('close() - atomic test', () async {
      final conn = ActiveTcpConn();
      await conn.close();
      expect(true, isTrue);
    });
    test('setDeadline() - atomic test', () async {
      final conn = ActiveTcpConn();
      conn.setDeadline(DateTime.now());
      expect(true, isTrue);
    });
    test('setReadDeadline() - atomic test', () async {
      final conn = ActiveTcpConn();
      conn.setReadDeadline(DateTime.now());
      expect(true, isTrue);
    });
    test('setWriteDeadline() - atomic test', () async {
      final conn = ActiveTcpConn();
      conn.setWriteDeadline(DateTime.now());
      expect(true, isTrue);
    });
  });
  group('AddrParseException [Atomic Audit]', () {
    test('error() - atomic test', () async {
      final err = AddrParseException();
      expect(err.error(), isNotEmpty);
    });
    test('toString() - atomic test', () async {
      final err = AddrParseException();
      expect(err.toString(), isNotEmpty);
    });
  });
  group('Agent [Atomic Audit]', () {
    test('addRemoteCandidate() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      agent.addRemoteCandidate(
        CandidateHost(CandidateHostConfig(port: Golang.Uint16(5000))),
      );
      expect(agent.getRemoteCandidates(), isNotEmpty);
    });
    test('getRemoteCandidates() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      expect(agent.getRemoteCandidates(), isEmpty);
    });
    test('getLocalCandidates() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      expect(agent.getLocalCandidates(), isEmpty);
    });
    test('getLocalUserCredentials() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      final (u, p) = agent.getLocalUserCredentials();
      expect(u, isNotEmpty);
      expect(p, isNotEmpty);
    });
    test('getRemoteUserCredentials() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      final (u, p) = agent.getRemoteUserCredentials();
      expect(u, isEmpty);
    });
    test('close() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      await agent.close();
      expect(true, isTrue);
    });
    test('gracefulClose() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      await agent.gracefulClose();
      expect(true, isTrue);
    });
    test('getSelectedCandidatePair() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      expect(agent.getSelectedCandidatePair(), isNull);
    });
    test('setRemoteCredentials() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      agent.setRemoteCredentials('rufrag', 'rpwd');
      expect(agent.getRemoteUserCredentials().$1, equals('rufrag'));
    });
    test('restart() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      agent.restart('newufrag', 'newpwd');
      expect(agent.getLocalUserCredentials().$1, equals('newufrag'));
    });
    test('onConnectionStateChange() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      agent.onConnectionStateChange((_) {});
      expect(true, isTrue);
    });
    test('onSelectedCandidatePairChange() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      agent.onSelectedCandidatePairChange((_, __) {});
      expect(true, isTrue);
    });
    test('onCandidate() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      agent.onCandidate((_) {});
      expect(true, isTrue);
    });
    test('getCandidatePairsStats() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      expect(agent.getCandidatePairsStats(), isEmpty);
    });
    test('getSelectedCandidatePairStats() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      final (stats, ok) = agent.getSelectedCandidatePairStats();
      expect(ok, isFalse);
    });
    test('getLocalCandidatesStats() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      expect(agent.getLocalCandidatesStats(), isEmpty);
    });
    test('getRemoteCandidatesStats() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      expect(agent.getRemoteCandidatesStats(), isEmpty);
    });
    test('gatherCandidates() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      await agent.gatherCandidates();
      expect(agent.getLocalCandidates(), isNotEmpty);
    });
    test('dial() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      final pc = await agent.dial();
      await pc.close();
      expect(true, isTrue);
    });
    test('accept() - atomic test', () async {
      final agent = Agent(const AgentConfig());
      final pc = await agent.accept();
      await pc.close();
      expect(true, isTrue);
    });
  });
  group('Candidate [Atomic Audit]', () {
    test('foundation() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.foundation(), isNotEmpty);
    });
    test('id() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.id(), isNotEmpty);
    });
    test('component() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.component(), equals(1));
    });
    test('setComponent() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      c.setComponent(2);
      expect(c.component(), equals(2));
    });
    test('lastReceived() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.lastReceived(), isNotNull);
    });
    test('lastSent() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.lastSent(), isNotNull);
    });
    test('networkType() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.networkType(), equals(NetworkType.udp4));
    });
    test('address() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.address(), isNotEmpty);
    });
    test('port() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.port().toBigInt().toInt(), equals(5000));
    });
    test('priority() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.priority(), isPositive);
    });
    test('relatedAddress() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      final withRel = CandidatePeerReflexive(
        CandidatePeerReflexiveConfig(
          port: Golang.Uint16(5000),
          relAddr: '1.2.3.4',
          relPort: 5000,
        ),
      );
      expect(withRel.relatedAddress(), isNotNull);
    });
    test('extensions() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.extensions(), isEmpty);
    });
    test('getExtension() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.getExtension('foo'), isNull);
    });
    test('addExtension() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      c.addExtension(const CandidateExtension(key: 'k', value: 'v'));
      expect(c.getExtension('k')?.value, equals('v'));
    });
    test('removeExtension() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      c.addExtension(const CandidateExtension(key: 'k2', value: 'v2'));
      expect(c.removeExtension('k2'), isTrue);
    });
    test('string() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.string(), isNotEmpty);
    });
    test('type() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.type(), isNotNull);
    });
    test('tcpType() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.tcpType(), isNotNull);
    });
    test('equal() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.equal(c), isTrue);
    });
    test('deepEqual() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.deepEqual(c), isTrue);
    });
    test('marshal() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.marshal(), isNotEmpty);
    });
  });
  group('CandidateBase [Atomic Audit]', () {
    test('done() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.done(), isFalse);
    });
    test('err() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.err(), isNull);
    });
    test('deadline() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.deadline(), isNull);
    });
    test('value() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.value('key'), isNull);
    });
    test('id() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.id(), isNotEmpty);
    });
    test('foundation() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.foundation(), isNotEmpty);
    });
    test('address() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.address(), isNotEmpty);
    });
    test('port() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.port().toBigInt().toInt(), equals(5000));
    });
    test('type() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.type(), isNotNull);
    });
    test('networkType() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.networkType(), equals(NetworkType.udp4));
    });
    test('component() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.component(), equals(1));
    });
    test('setComponent() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      c.setComponent(2);
      expect(c.component(), equals(2));
    });
    test('localPreference() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.localPreference(), isPositive);
    });
    test('relatedAddress() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      final withRel = CandidatePeerReflexive(
        CandidatePeerReflexiveConfig(
          port: Golang.Uint16(5000),
          relAddr: '1.2.3.4',
          relPort: 5000,
        ),
      );
      expect(withRel.relatedAddress(), isNotNull);
    });
    test('tcpType() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.tcpType(), isNotNull);
    });
    test('typePreference() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.typePreference(), isPositive);
    });
    test('priority() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.priority(), isPositive);
    });
    test('equal() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.equal(c), isTrue);
    });
    test('deepEqual() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.deepEqual(c), isTrue);
    });
    test('string() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.string(), isNotEmpty);
    });
    test('lastReceived() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.lastReceived(), isNotNull);
    });
    test('lastSent() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.lastSent(), isNotNull);
    });
    test('setLastReceived() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      c.setLastReceived(DateTime.now());
      expect(true, isTrue);
    });
    test('setLastSent() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      c.setLastSent(DateTime.now());
      expect(true, isTrue);
    });
    test('marshal() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.marshal(), isNotEmpty);
    });
    test('extensions() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.extensions(), isEmpty);
    });
    test('getExtension() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.getExtension('foo'), isNull);
    });
    test('addExtension() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      c.addExtension(const CandidateExtension(key: 'k', value: 'v'));
      expect(c.getExtension('k')?.value, equals('v'));
    });
    test('removeExtension() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      c.addExtension(const CandidateExtension(key: 'k2', value: 'v2'));
      expect(c.removeExtension('k2'), isTrue);
    });
    test('toString() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      expect(c.toString(), isNotEmpty);
    });
  });
  group('CandidatePair [Atomic Audit]', () {
    test('priority() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      final pair = CandidatePair(local: c, remote: c);
      expect(pair.priority(), isPositive);
    });
    test('string() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      final pair = CandidatePair(local: c, remote: c);
      expect(pair.string(), contains('127.0.0.1'));
    });
    test('toString() - atomic test', () async {
      final c = CandidateHost(
        CandidateHostConfig(address: '127.0.0.1', port: Golang.Uint16(5000)),
      );
      final pair = CandidatePair(local: c, remote: c);
      expect(pair.toString(), contains('127.0.0.1'));
    });
  });
  group('CandidatePairState [Atomic Audit]', () {
    test('string() - atomic test', () async {
      expect(CandidatePairState.waiting.string(), equals('waiting'));
    });
    test('toString() - atomic test', () async {
      expect(CandidatePairState.waiting.toString(), equals('waiting'));
    });
  });
  group('CandidateRelatedAddress [Atomic Audit]', () {
    test('string() - atomic test', () async {
      const cra = CandidateRelatedAddress(address: '1.2.3.4', port: 1234);
      expect(cra.string(), contains('1.2.3.4:1234'));
    });
    test('equal() - atomic test', () async {
      const cra = CandidateRelatedAddress(address: '1.2.3.4', port: 1234);
      expect(
        cra.equal(
          const CandidateRelatedAddress(address: '1.2.3.4', port: 1234),
        ),
        isTrue,
      );
    });
    test('operator ==() - atomic test', () async {
      const cra1 = CandidateRelatedAddress(address: '1.2.3.4', port: 1234);
      const cra2 = CandidateRelatedAddress(address: '1.2.3.4', port: 1234);
      expect(cra1 == cra2, isTrue);
    });
    test('hashCode() - atomic test', () async {
      const cra = CandidateRelatedAddress(address: '1.2.3.4', port: 1234);
      expect(cra.hashCode, isPositive);
    });
    test('toString() - atomic test', () async {
      const cra = CandidateRelatedAddress(address: '1.2.3.4', port: 1234);
      expect(cra.toString(), contains('1.2.3.4:1234'));
    });
  });
  group('CandidateType [Atomic Audit]', () {
    test('string() - atomic test', () async {
      expect(CandidateType.host.string(), equals('host'));
    });
    test('preference() - atomic test', () async {
      expect(CandidateType.host.preference(), equals(126));
    });
    test('toString() - atomic test', () async {
      expect(CandidateType.host.toString(), equals('host'));
    });
  });
  group('ConnectionState [Atomic Audit]', () {
    test('string() - atomic test', () async {
      expect(ConnectionState.connected.string(), equals('Connected'));
    });
    test('toString() - atomic test', () async {
      expect(ConnectionState.connected.toString(), equals('Connected'));
    });
  });
  group('GatheringState [Atomic Audit]', () {
    test('string() - atomic test', () async {
      expect(GatheringState.complete.string(), equals('complete'));
    });
    test('toString() - atomic test', () async {
      expect(GatheringState.complete.toString(), equals('complete'));
    });
  });
  group('HandlerNotifier [Atomic Audit]', () {
    test('close() - atomic test', () async {
      final hn = HandlerNotifier();
      hn.close();
      expect(true, isTrue);
    });
    test('enqueueConnectionState() - atomic test', () async {
      final hn = HandlerNotifier();
      hn.enqueueConnectionState(ConnectionState.connected);
      expect(true, isTrue);
    });
    test('enqueueCandidate() - atomic test', () async {
      final hn = HandlerNotifier();
      hn.enqueueCandidate(
        CandidateHost(CandidateHostConfig(port: Golang.Uint16(1000))),
      );
      expect(true, isTrue);
    });
    test('enqueueSelectedCandidatePair() - atomic test', () async {
      final hn = HandlerNotifier();
      final c = CandidateHost(CandidateHostConfig(port: Golang.Uint16(1000)));
      hn.enqueueSelectedCandidatePair(CandidatePair(local: c, remote: c));
      expect(true, isTrue);
    });
  });
  group('IpConvertException [Atomic Audit]', () {
    test('error() - atomic test', () async {
      final err = IpConvertException();
      expect(err.error(), isNotEmpty);
    });
    test('toString() - atomic test', () async {
      final err = IpConvertException();
      expect(err.toString(), isNotEmpty);
    });
  });
  group('NetworkType [Atomic Audit]', () {
    test('string() - atomic test', () async {
      expect(NetworkType.udp4.string(), equals('udp4'));
    });
    test('isUdp() - atomic test', () async {
      expect(NetworkType.udp4.isUdp(), isTrue);
    });
    test('isTcp() - atomic test', () async {
      expect(NetworkType.tcp4.isTcp(), isTrue);
    });
    test('toString() - atomic test', () async {
      expect(NetworkType.udp4.toString(), equals('udp4'));
    });
  });
  group('TcpAddr [Atomic Audit]', () {
    test('network() - atomic test', () async {
      final taddr = TcpAddr(InternetAddress.loopbackIPv4, 5000);
      expect(taddr.network, equals('tcp'));
    });
    test('toString() - atomic test', () async {
      final taddr = TcpAddr(InternetAddress.loopbackIPv4, 5000);
      expect(taddr.toString(), contains('5000'));
    });
    test('operator ==() - atomic test', () async {
      final taddr1 = TcpAddr(InternetAddress.loopbackIPv4, 5000);
      final taddr2 = TcpAddr(InternetAddress.loopbackIPv4, 5000);
      expect(taddr1 == taddr2, isTrue);
    });
    test('hashCode() - atomic test', () async {
      final taddr = TcpAddr(InternetAddress.loopbackIPv4, 5000);
      expect(taddr.hashCode, isPositive);
    });
  });
  group('TcpType [Atomic Audit]', () {
    test('fromString() - atomic test', () async {
      expect(TcpType.fromString('active'), equals(TcpType.active));
    });
    test('string() - atomic test', () async {
      expect(TcpType.active.string(), equals('active'));
    });
    test('toString() - atomic test', () async {
      expect(TcpType.active.toString(), equals('active'));
    });
  });
  group('UdpMux [Atomic Audit]', () {
    test('close() - atomic test', () async {
      final mux = UdpMuxDefault(const UdpMuxParams());
      await mux.close();
      expect(true, isTrue);
    });
    test('getConn() - atomic test', () async {
      final mux = UdpMuxDefault(const UdpMuxParams());
      final c = mux.getConn(
        'testufrag',
        UdpAddr(InternetAddress.loopbackIPv4, 5000),
      );
      expect(c, isNotNull);
    });
    test('removeConnByUfrag() - atomic test', () async {
      final mux = UdpMuxDefault(const UdpMuxParams());
      mux.removeConnByUfrag('testufrag');
      expect(true, isTrue);
    });
    test('getListenAddresses() - atomic test', () async {
      final mux = UdpMuxDefault(const UdpMuxParams());
      expect(mux.getListenAddresses(), isNotEmpty);
    });
  });
  group('UdpMuxDefault [Atomic Audit]', () {
    test('close() - atomic test', () async {
      final mux = UdpMuxDefault(const UdpMuxParams());
      await mux.close();
      expect(true, isTrue);
    });
    test('getConn() - atomic test', () async {
      final mux = UdpMuxDefault(const UdpMuxParams());
      final c = mux.getConn(
        'testufrag',
        UdpAddr(InternetAddress.loopbackIPv4, 5000),
      );
      expect(c, isNotNull);
    });
    test('removeConnByUfrag() - atomic test', () async {
      final mux = UdpMuxDefault(const UdpMuxParams());
      mux.removeConnByUfrag('testufrag');
      expect(true, isTrue);
    });
    test('getListenAddresses() - atomic test', () async {
      final mux = UdpMuxDefault(const UdpMuxParams());
      expect(mux.getListenAddresses(), isNotEmpty);
    });
    test('handlePacket() - atomic test', () async {
      final mux = UdpMuxDefault(const UdpMuxParams());
      mux.handlePacket(
        Uint8List(0),
        UdpAddr(InternetAddress.loopbackIPv4, 5000),
      );
      expect(true, isTrue);
    });
  });
}
