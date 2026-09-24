import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart'
    show NetAddr, PacketConn;

import 'cipher_suite.dart';
import 'config.dart';
import 'conn.dart';
import 'pkg/crypto/prf/prf.dart';

const Map<String, bool> _invalidKeyingLabels = {
  'client finished': true,
  'server finished': true,
  'master secret': true,
  'key expansion': true,
  'extended master secret': true,
};

/// Session stores data needed in resumption.
class Session {
  Uint8List id;
  Uint8List secret;

  Session({Uint8List? id, Uint8List? secret})
    : id = id ?? Uint8List(0),
      secret = secret ?? Uint8List(0);
}

/// SessionStore defines methods needed for session resumption.
abstract class SessionStore {
  void set(Uint8List key, Session s);
  Session? get(Uint8List key);
  void del(Uint8List key);
}

/// In-memory SessionStore implementation.
class MemorySessionStore implements SessionStore {
  final Map<String, Session> _store = {};

  String _toKey(Uint8List key) => base64Encode(key);

  @override
  void set(Uint8List key, Session s) {
    _store[_toKey(key)] = s;
  }

  @override
  Session? get(Uint8List key) {
    return _store[_toKey(key)];
  }

  @override
  void del(Uint8List key) {
    _store.remove(_toKey(key));
  }
}

/// State holds the DTLS connection state and implements binary marshaling.
class State {
  int cipherSuiteId;
  List<Uint8List> peerCertificates;
  Uint8List identityHint;
  Uint8List sessionId;
  String negotiatedProtocol;

  CipherSuite? cipherSuite;
  Uint8List masterSecret;
  Uint8List localRandom;
  Uint8List remoteRandom;
  bool isClient;
  int localEpoch;
  int remoteEpoch;
  int srtpProtectionProfile;
  Uint8List? remoteSrtpMasterKeyIdentifier;
  Uint8List? localConnectionId;
  Uint8List? remoteConnectionId;
  int localSequenceNumber;

  State({
    this.cipherSuiteId = 0,
    List<Uint8List>? peerCertificates,
    Uint8List? identityHint,
    Uint8List? sessionId,
    this.negotiatedProtocol = '',
    this.cipherSuite,
    Uint8List? masterSecret,
    Uint8List? localRandom,
    Uint8List? remoteRandom,
    this.isClient = true,
    this.localEpoch = 0,
    this.remoteEpoch = 0,
    this.srtpProtectionProfile = 0,
    this.remoteSrtpMasterKeyIdentifier,
    this.localConnectionId,
    this.remoteConnectionId,
    this.localSequenceNumber = 0,
  }) : peerCertificates = peerCertificates ?? [],
       identityHint = identityHint ?? Uint8List(0),
       sessionId = sessionId ?? Uint8List(0),
       masterSecret = masterSecret ?? Uint8List(0),
       localRandom = localRandom ?? Uint8List(32),
       remoteRandom = remoteRandom ?? Uint8List(32);

  State clone() {
    return State(
      cipherSuiteId: cipherSuiteId,
      peerCertificates: peerCertificates
          .map((c) => Uint8List.fromList(c))
          .toList(),
      identityHint: Uint8List.fromList(identityHint),
      sessionId: Uint8List.fromList(sessionId),
      negotiatedProtocol: negotiatedProtocol,
      cipherSuite: cipherSuite,
      masterSecret: Uint8List.fromList(masterSecret),
      localRandom: Uint8List.fromList(localRandom),
      remoteRandom: Uint8List.fromList(remoteRandom),
      isClient: isClient,
      localEpoch: localEpoch,
      remoteEpoch: remoteEpoch,
      srtpProtectionProfile: srtpProtectionProfile,
      remoteSrtpMasterKeyIdentifier: remoteSrtpMasterKeyIdentifier != null
          ? Uint8List.fromList(remoteSrtpMasterKeyIdentifier!)
          : null,
      localConnectionId: localConnectionId != null
          ? Uint8List.fromList(localConnectionId!)
          : null,
      remoteConnectionId: remoteConnectionId != null
          ? Uint8List.fromList(remoteConnectionId!)
          : null,
      localSequenceNumber: localSequenceNumber,
    );
  }

  /// RemoteRandomBytes returns the remote client hello random bytes.
  Uint8List remoteRandomBytes() => remoteRandom;

  /// MarshalBinary serializes the connection state to binary.
  Uint8List marshalBinary() {
    final map = <String, dynamic>{
      'localEpoch': localEpoch,
      'remoteEpoch': remoteEpoch,
      'cipherSuiteId': cipherSuiteId,
      'masterSecret': base64Encode(masterSecret),
      'localRandom': base64Encode(localRandom),
      'remoteRandom': base64Encode(remoteRandom),
      'localSequenceNumber': localSequenceNumber,
      'srtpProtectionProfile': srtpProtectionProfile,
      'peerCertificates': peerCertificates.map((c) => base64Encode(c)).toList(),
      'identityHint': base64Encode(identityHint),
      'sessionId': base64Encode(sessionId),
      'isClient': isClient,
      'negotiatedProtocol': negotiatedProtocol,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  /// UnmarshalBinary deserializes the connection state from binary.
  void unmarshalBinary(Uint8List data) {
    final str = utf8.decode(data);
    final map = jsonDecode(str) as Map<String, dynamic>;
    localEpoch = map['localEpoch'] as int? ?? 0;
    remoteEpoch = map['remoteEpoch'] as int? ?? 0;
    cipherSuiteId = map['cipherSuiteId'] as int? ?? 0;
    masterSecret = base64Decode(map['masterSecret'] as String? ?? '');
    localRandom = base64Decode(map['localRandom'] as String? ?? '');
    remoteRandom = base64Decode(map['remoteRandom'] as String? ?? '');
    localSequenceNumber = map['localSequenceNumber'] as int? ?? 0;
    srtpProtectionProfile = map['srtpProtectionProfile'] as int? ?? 0;
    peerCertificates = (map['peerCertificates'] as List<dynamic>? ?? [])
        .map((e) => base64Decode(e as String))
        .toList();
    identityHint = base64Decode(map['identityHint'] as String? ?? '');
    sessionId = base64Decode(map['sessionId'] as String? ?? '');
    isClient = map['isClient'] as bool? ?? true;
    negotiatedProtocol = map['negotiatedProtocol'] as String? ?? '';
  }

  /// ExportKeyingMaterial returns length bytes of exported key material as defined in RFC 5705.
  Uint8List exportKeyingMaterial(String label, Uint8List context, int length) {
    if (localEpoch == 0) {
      throw StateError('handshake is in progress');
    }
    if (context.isNotEmpty) {
      throw UnsupportedError(
        'context is not supported for ExportKeyingMaterial',
      );
    }
    if (_invalidKeyingLabels[label] == true) {
      throw ArgumentError(
        'ExportKeyingMaterial can not be used with a reserved label',
      );
    }
    if (cipherSuite == null) {
      throw StateError('cipher suite not set');
    }

    final seedList = <int>[];
    seedList.addAll(utf8.encode(label));
    if (isClient) {
      seedList.addAll(localRandom);
      seedList.addAll(remoteRandom);
    } else {
      seedList.addAll(remoteRandom);
      seedList.addAll(localRandom);
    }

    return pHash(
      masterSecret,
      Uint8List.fromList(seedList),
      length,
      cipherSuite!.hashFunc(),
    );
  }
}

/// Resume imports an already established DTLS connection using a specific DTLS state.
Future<Conn> resume(
  State state,
  dynamic conn,
  NetAddr rAddr,
  Config config,
) async {
  final dtlsConn = Conn(
    nextConn: conn,
    remoteAddrValue: rAddr,
    config: config,
    state: state,
  );
  return dtlsConn;
}

/// ResumeWithOptions imports an already established DTLS connection using a specific DTLS state.
Future<Conn> resumeWithOptions(
  State state,
  dynamic conn,
  NetAddr rAddr, [
  List<Option> opts = const [],
]) async {
  final config = Config();
  for (final opt in opts) {
    opt.apply(config);
  }
  return resume(state, conn, rAddr, config);
}
