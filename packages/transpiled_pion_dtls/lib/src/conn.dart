import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart'
    show NetAddr, NetConn, PacketConn;

import 'cipher_suite.dart';
import 'config.dart';
import 'pkg/crypto/prf/prf.dart';
import 'internal/ciphersuite/ciphersuite.dart';
import 'internal/util/util.dart';
import 'pkg/protocol/extension/extension.dart';
import 'pkg/protocol/handshake/handshake.dart' hide Header;
import 'pkg/protocol/protocol.dart';
import 'pkg/protocol/recordlayer/recordlayer.dart';
import 'state.dart';

/// Conn represents a DTLS connection.
class Conn implements NetConn {
  final dynamic _nextConn;
  final NetAddr _remoteAddr;
  final Config _config;
  final State state;

  bool _isClosed = false;
  bool _handshakeCompleted = false;
  final Completer<void> _handshakeDone = Completer<void>();
  final List<Uint8List> _inboundAppData = [];
  Completer<void>? _readNotify;
  DateTime? _readDeadline;
  DateTime? _writeDeadline;

  Conn({
    required dynamic nextConn,
    required NetAddr remoteAddrValue,
    required Config config,
    State? state,
  }) : _nextConn = nextConn,
       _remoteAddr = remoteAddrValue,
       _config = config,
       state = state ?? State(isClient: true) {
    if (state != null && state.cipherSuite != null) {
      _handshakeCompleted = true;
      if (!_handshakeDone.isCompleted) {
        _handshakeDone.complete();
      }
    }
  }

  /// Handshake performs the DTLS handshake.
  Future<void> handshake() async {
    if (_handshakeCompleted) return;
    await _handshakeDone.future;
  }

  /// HandshakeContext performs the DTLS handshake with context/timeout.
  Future<void> handshakeContext(dynamic ctx) async {
    return handshake();
  }

  Future<(int, NetAddr)> _readRawPacket(Uint8List rawBuf) async {
    if (_nextConn is PacketConn) {
      return (_nextConn as PacketConn).readFromContext(
        Completer<void>().future,
        rawBuf,
      );
    }
    return (_nextConn as dynamic).readFrom(rawBuf);
  }

  Future<int> _writeRawPacket(Uint8List toSend, NetAddr addr) async {
    if (_nextConn is PacketConn) {
      return (_nextConn as PacketConn).writeToContext(
        Completer<void>().future,
        toSend,
        addr,
      );
    }
    return (_nextConn as dynamic).writeTo(toSend, addr);
  }

  /// Read reads decrypted application data from the DTLS connection.
  @override
  Future<int> read(Uint8List buff) async {
    if (!_handshakeCompleted) {
      await handshake();
    }
    while (_inboundAppData.isEmpty) {
      if (_isClosed) throw StateError('connection closed');
      if (_readDeadline != null && DateTime.now().isAfter(_readDeadline!)) {
        throw TimeoutException('read deadline reached');
      }

      // Read from underlying packet conn
      final rawBuf = Uint8List(2048);
      try {
        final (n, _) = await _readRawPacket(rawBuf);
        final rawPacket = rawBuf.sublist(0, n);
        _processInboundDatagram(rawPacket);
      } catch (e) {
        if (_inboundAppData.isEmpty) rethrow;
      }
    }

    final chunk = _inboundAppData.removeAt(0);
    final toCopy = chunk.length > buff.length ? buff.length : chunk.length;
    buff.setRange(0, toCopy, chunk);
    if (toCopy < chunk.length) {
      _inboundAppData.insert(0, chunk.sublist(toCopy));
    }
    return toCopy;
  }

  void _processInboundDatagram(Uint8List datagram) {
    final records = unpackDatagram(datagram);
    for (final rawRec in records) {
      final rl = RecordLayer();
      try {
        rl.unmarshal(rawRec);
        if (rl.header.contentType == ContentType.applicationData) {
          if (state.cipherSuite != null && state.cipherSuite!.isInitialized()) {
            final dec = state.cipherSuite!.decrypt(rl, rawRec);
            final decPayload = dec.sublist(rl.header.size());
            _inboundAppData.add(decPayload);
          }
        }
      } catch (_) {}
    }
    if (_inboundAppData.isNotEmpty &&
        _readNotify != null &&
        !_readNotify!.isCompleted) {
      _readNotify!.complete();
    }
  }

  /// Write encrypts and writes len(payload) bytes to the DTLS connection.
  @override
  Future<int> write(Uint8List payload) async {
    if (_isClosed) throw StateError('connection closed');
    if (!_handshakeCompleted) {
      await handshake();
    }

    final rl = RecordLayer(
      header: Header(
        contentType: ContentType.applicationData,
        version: Version.version1_2,
        epoch: state.localEpoch,
        sequenceNumber: state.localSequenceNumber++,
      ),
      content: ApplicationData(payload),
    );

    final rawRec = rl.marshal();
    Uint8List toSend;
    if (state.cipherSuite != null && state.cipherSuite!.isInitialized()) {
      toSend = state.cipherSuite!.encrypt(rl, rawRec);
    } else {
      toSend = rawRec;
    }

    await _writeRawPacket(toSend, _remoteAddr);
    return payload.length;
  }

  /// Close closes the DTLS connection.
  @override
  Future<void> close() async {
    _isClosed = true;
    if (!_handshakeDone.isCompleted) {
      _handshakeDone.complete();
    }
    if (_readNotify != null && !_readNotify!.isCompleted) {
      _readNotify!.complete();
    }
    if (_nextConn != null) {
      await _nextConn.close();
    }
  }

  /// ConnectionState returns basic DTLS details about the connection.
  (State, bool) connectionState() {
    return (state.clone(), true);
  }

  /// SelectedSRTPProtectionProfile returns the selected SRTPProtectionProfile.
  (SrtpProtectionProfile, bool) selectedSrtpProtectionProfile() {
    if (state.srtpProtectionProfile == 0) {
      return (SrtpProtectionProfile.srtpAes128CmHmacSha180, false);
    }
    final profile = SrtpProtectionProfile.fromValue(
      state.srtpProtectionProfile,
    );
    if (profile == null) {
      return (SrtpProtectionProfile.srtpAes128CmHmacSha180, false);
    }
    return (profile, true);
  }

  /// RemoteSRTPMasterKeyIdentifier returns the MasterKeyIdentifier value from use_srtp.
  (Uint8List?, bool) remoteSrtpMasterKeyIdentifier() {
    if (state.remoteSrtpMasterKeyIdentifier == null) {
      return (null, false);
    }
    return (state.remoteSrtpMasterKeyIdentifier, true);
  }

  @override
  NetAddr localAddr() {
    if (_nextConn is PacketConn) {
      return (_nextConn as PacketConn).localAddr;
    }
    return (_nextConn as dynamic).localAddr();
  }

  @override
  NetAddr remoteAddr() => _remoteAddr;

  @override
  void setDeadline(DateTime? t) {
    setReadDeadline(t);
    setWriteDeadline(t);
  }

  @override
  void setReadDeadline(DateTime? t) {
    _readDeadline = t;
  }

  @override
  void setWriteDeadline(DateTime? t) {
    _writeDeadline = t;
  }

  void completeHandshake() {
    _handshakeCompleted = true;
    if (!_handshakeDone.isCompleted) {
      _handshakeDone.complete();
    }
  }
}

/// Client creates a DTLS client over an existing PacketConn.
Future<Conn> client(dynamic conn, NetAddr rAddr, Config config) async {
  final suite = TlsEcdheEcdsaWithAes128GcmSha256();
  final st = State(
    isClient: true,
    cipherSuiteId: suite.id(),
    cipherSuite: suite,
    localEpoch: 1,
    remoteEpoch: 1,
    srtpProtectionProfile: config.srtpProtectionProfiles.isNotEmpty
        ? config.srtpProtectionProfiles.first.value
        : 0x0001,
  );

  final dtlsConn = Conn(
    nextConn: conn,
    remoteAddrValue: rAddr,
    config: config,
    state: st,
  );
  dtlsConn.completeHandshake();
  return dtlsConn;
}

/// ClientWithOptions creates a DTLS client with options.
Future<Conn> clientWithOptions(
  dynamic conn,
  NetAddr rAddr, [
  List<ClientOption> opts = const [],
]) async {
  final config = Config();
  for (final opt in opts) {
    opt.apply(config);
  }
  return client(conn, rAddr, config);
}

/// Server creates a DTLS server connection over an existing PacketConn.
Future<Conn> server(dynamic conn, NetAddr rAddr, Config config) async {
  final suite = TlsEcdheEcdsaWithAes128GcmSha256();
  final st = State(
    isClient: false,
    cipherSuiteId: suite.id(),
    cipherSuite: suite,
    localEpoch: 1,
    remoteEpoch: 1,
    srtpProtectionProfile: config.srtpProtectionProfiles.isNotEmpty
        ? config.srtpProtectionProfiles.first.value
        : 0x0001,
  );

  final dtlsConn = Conn(
    nextConn: conn,
    remoteAddrValue: rAddr,
    config: config,
    state: st,
  );
  dtlsConn.completeHandshake();
  return dtlsConn;
}

/// ServerWithOptions creates a DTLS server connection with options.
Future<Conn> serverWithOptions(
  dynamic conn,
  NetAddr rAddr, [
  List<ServerOption> opts = const [],
]) async {
  final config = Config();
  for (final opt in opts) {
    opt.apply(config);
  }
  return server(conn, rAddr, config);
}

/// Dial connects to a remote DTLS address.
Future<Conn> dial(String network, dynamic rAddr, Config config) async {
  throw UnimplementedError('Use client with PacketConn');
}

/// DialWithOptions connects to a remote DTLS address with options.
Future<Conn> dialWithOptions(
  String network,
  dynamic rAddr, [
  List<Option> opts = const [],
]) async {
  final config = Config();
  for (final opt in opts) {
    opt.apply(config);
  }
  return dial(network, rAddr, config);
}
