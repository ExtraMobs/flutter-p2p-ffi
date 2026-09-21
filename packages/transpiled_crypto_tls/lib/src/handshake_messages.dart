// ignore_for_file: library_prefixes
// ignore_for_file: sort_constructors_first
// Each message class keeps its `factory ClassName.unmarshal(...)` next to
// `marshal()`, mirroring the Go source's own `marshal`-then-`unmarshal`
// method order for traceability, rather than moving it before the fields.
/// Port of the TLS 1.3 subset of Go's `crypto/tls` handshake_messages.go
/// (1964 lines total).
///
/// Scope boundary (Marco G.2, "Segurança TLS 1.3"): only the handshake
/// message types a plain TLS 1.3 `/tls/1.0.0` handshake needs. Explicitly
/// NOT ported (TLS 1.0-1.2-only message types, consumed only by the
/// out-of-scope TLS 1.2 handshake state machine): `certificateMsg`
/// (non-TLS13, `:1389-1422`), `serverKeyExchangeMsg` (`:1599-1622`),
/// `certificateStatusMsg` (`:1623-1652`), `serverHelloDoneMsg`
/// (`:1653-1664`), `clientKeyExchangeMsg` (`:1665-1692`),
/// `certificateRequestMsg` (non-TLS13, `:1714-1847`), `newSessionTicketMsg`
/// (non-TLS13, `:1883-1922`), `helloRequestMsg` (`:1923+`).
///
/// Go symbol -> upstream file:line -> Dart symbol:
///   - `clientHelloMsg` (`:71-103`) -> [ClientHelloMsg]. `marshalMsg`
///     (`:104-373`) is ported only for the non-ECH path (`echInner=false`);
///     `marshal` (`:375-377`) -> [ClientHelloMsg.marshal];
///     `marshalWithoutBinders` (`:382-400`) ->
///     [ClientHelloMsg.marshalWithoutBinders]; `updateBinders`
///     (`:404-416`) -> [ClientHelloMsg.updateBinders]; `unmarshal`
///     (`:418-680`) -> `ClientHelloMsg.unmarshal`. `originalBytes`
///     (`:682-684`) is Go-unexported (lowercase) and trivially `= original`;
///     not re-exposed as a separate method, just the [ClientHelloMsg.original]
///     field. `clone` (`:686-717`) is also Go-unexported and exists only for
///     the out-of-scope Encrypted Client Hello / HelloRetryRequest-retry
///     bookkeeping in the handshake state machine; not ported (named gap).
///   - `serverHelloMsg` (`:719-745`) -> [ServerHelloMsg]; `marshal`
///     (`:746-869`) -> `ServerHelloMsg.marshal`; `unmarshal` (`:871-997`) ->
///     `ServerHelloMsg.unmarshal`. Ported in full (every field/extension)
///     except `encryptedClientHello` (ECH, named gap -- see below).
///   - `encryptedExtensionsMsg` (`:1003-1009`) -> [EncryptedExtensionsMsg];
///     `marshal`/`unmarshal` (`:1011-1119`). `alpnProtocol`/`earlyData`/
///     `serverNameAck` implemented; `quicTransportParameters`/
///     `echRetryConfigs` declared but not wired (named gaps, see below).
///   - `endOfEarlyDataMsg` (`:1121-1131`) -> [EndOfEarlyDataMsg].
///   - `keyUpdateMsg` (`:1133-1168`) -> [KeyUpdateMsg].
///   - `newSessionTicketMsgTLS13` (`:1170-1243`) -> [NewSessionTicketMsgTls13].
///   - `certificateRequestMsgTLS13` (`:1245-1387`) ->
///     [CertificateRequestMsgTls13], ported in full including
///     `certificate_authorities`.
///   - `certificateMsgTLS13` (`:1459-1537`) -> [CertificateMsgTls13];
///     `marshalCertificate`/`unmarshalCertificate` (`:1484-1597`) ->
///     private `_marshalCertificateEntries`/`_unmarshalCertificateEntries`.
///     Go's `certificate Certificate` field embeds the full `common.go`
///     `Certificate` struct (out of scope here -- it also carries
///     `PrivateKey`, `Leaf`, `SupportedSignatureAlgorithms`, meaningless to a
///     pure wire codec, and porting a second, incomplete `Certificate` type
///     here risks colliding with a future faithful port of the real one).
///     Only its three wire-relevant sub-fields (`Certificate`/`OCSPStaple`/
///     `SignedCertificateTimestamps`) are flattened directly onto
///     [CertificateMsgTls13] instead.
///   - `finishedMsg` (`:1693-1712`) -> [FinishedMsg].
///   - `certificateVerifyMsg` (`:1848-1881`) -> [CertificateVerifyMsg].
///
/// Cross-cutting named gaps (declared as struct fields where Go has them,
/// for structural fidelity, but never marshaled or unmarshaled):
///   - QUIC transport parameters (`extensionQUICTransportParameters`,
///     `common.go:127`): out of scope for Marco G.2 (plain TLS security
///     transport over TCP); the QUIC-embedded TLS handshake is Marco G.1's
///     concern, a separate transport.
///   - Encrypted Client Hello / ECH (`extensionEncryptedClientHello`,
///     `extensionECHOuterExtensions`, `common.go:129-130`): a distinct draft
///     feature layered on top of the base handshake, not needed for a basic
///     interoperable TLS 1.3 handshake.
///   - Also skipped on [ClientHelloMsg] only (present and implemented on
///     [ServerHelloMsg], which was not given the same triage budget): OCSP
///     stapling (`ocspStapling`), TLS 1.2 curve point formats
///     (`supportedPoints`), TLS 1.0-1.2 session ticket resumption
///     (`ticketSupported`/`sessionTicket`, superseded by PSK in 1.3),
///     `signature_algorithms_cert` (`supportedSignatureAlgorithmsCert`),
///     secure renegotiation (`secureRenegotiationSupported`/
///     `secureRenegotiation`, TLS-1.2-era, RFC 5746), extended master secret
///     (`extendedMasterSecret`, TLS-1.2-era, RFC 7627), signed certificate
///     timestamps (`scts`), and 0-RTT early data (`earlyData`).
///
/// `golang.org/x/crypto/cryptobyte` (`Builder`/`String`), the encoding
/// library `handshake_messages.go` builds/parses wire bytes with, is a
/// separate Go module boundary from `go-stdlib` and out of scope to port
/// 1:1. Its wire BEHAVIOR (big-endian length-prefixed TLV, cursor-based
/// truncation-safe reads) is reproduced here by the private [_Builder]/
/// [_Reader] helpers instead, which have no direct Go-exported
/// correspondent and are therefore private (AGENTS.md: auxiliary symbols
/// with no exported Go correspondent should be private). [_Builder] builds
/// each length-prefixed sub-region into a fresh nested [_Builder], reads its
/// finished byte length, then writes the prefix followed by those bytes into
/// the parent -- behaviorally identical output to cryptobyte's single-pass
/// placeholder-then-backpatch approach, just two-pass, which is simpler to
/// write correctly in Dart and costs nothing worth avoiding at
/// handshake-message sizes (at most a few KiB). [_Reader] throws
/// [HandshakeMessageFormatException] on truncation/malformed input instead
/// of cryptobyte's `bool` "read ok?" return, since threading a bool through
/// every nested closure is exactly the Go-ism AGENTS.md Rule 8 wants adapted
/// -- letting the exception propagate out of a `ClassName.unmarshal` factory
/// constructor is both the idiomatic Dart replacement and, in practice,
/// simpler to write than Go's own `if !x.Read(...) { return false }` chains.
/// [_Reader.readBytes] and friends return views (`Uint8List.sublistView`)
/// into the original input buffer rather than copies, matching Go's own
/// slice-aliasing semantics (`cryptobyte.String` reads are also sub-slices
/// of the original backing array, not copies).
///
/// The small free-function helpers Go itself layers on top of cryptobyte
/// (`marshalingFunction`, `addBytesWithLength`, `readUint8/16/24LengthPrefixed`,
/// `:16-69`) are folded directly into [_Builder]/[_Reader] as methods rather
/// than kept as free functions, since Dart has no equivalent of passing a
/// `*Builder`/`*String` by pointer through a free function. `addUint64`/
/// `readUint64` (`:36-51`, a big-endian 64-bit value split into two uint32
/// halves) are NOT ported: no field of any message type in this pass is a
/// uint64 (the only consumer, `SessionState`, is out of scope); add them to
/// [_Builder]/[_Reader] if/when a future message needs them.
///
/// Every fixed-width big-endian integer write goes through
/// `package:boilerplate/fixed_types/golang.dart` (`Golang.Uint8`/`Uint16`/
/// `Uint32`) per AGENTS.md Regra 10 ("TLS é protocolo binário com inteiros
/// de 8/16/24/32 bits em big-endian"). There is no `Golang.Uint24` (Go has
/// no native uint24 either -- `cryptobyte.Builder.AddUint24` manually packs
/// 3 bytes); `_beUint24` goes through `Golang.Uint32` for the truncation
/// guarantee before dropping the high byte, mirroring `_beUint16` in
/// `key_schedule.dart`. Reads do not need `Golang.*`: reconstructing an int
/// from a fixed count of already-validated bytes has no overflow or
/// truncation concern the way writing an oversized value does.
///
/// Two Go structs referenced here are unexported (`keyShare`/`pskIdentity`,
/// `common.go:164-167, 177-180`) but are the element type of this file's own
/// public fields ([ClientHelloMsg.keyShares], [ServerHelloMsg.serverShare],
/// [ClientHelloMsg.pskIdentities]); promoted to public [KeyShare]/
/// [PskIdentity] per AGENTS.md's Cenário C (a private supporting type
/// transitively reachable from a public member must be promoted, not left
/// private, since Dart forbids exposing a private type through a public
/// member -- Regra 23). `CurveID`/`SignatureScheme` (`common.go:145,393`,
/// both `uintN` newtypes, out of scope for this task) are represented as
/// plain `int` matching their Go underlying width rather than inventing a
/// partial duplicate enum a future `common.go` port would need to reconcile
/// with.
///
/// Struct fields: like `key_schedule.dart`'s `CipherSuiteTls13`, every Go
/// field here is unexported (lowercase); all are made public (lowerCamelCase)
/// since external code (tests, and eventually the not-yet-ported handshake
/// state machine) needs to construct and inspect these messages.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;

// ---------------------------------------------------------------------------
// Wire-format constants: a minimal subset of Go's `common.go`, which is a
// different file/task and not ported here (see file header). These are the
// exact numeric values `common.go` declares (verified against
// `go-ipfs-reference/go-stdlib/src/crypto/tls/common.go`), kept private
// since `common.go` itself is out of this task's scope and a future port of
// it should become the single source of truth these get reconciled into.
// ---------------------------------------------------------------------------

const int _typeClientHello = 1;
const int _typeServerHello = 2;
const int _typeNewSessionTicket = 4;
const int _typeEndOfEarlyData = 5;
const int _typeEncryptedExtensions = 8;
const int _typeCertificate = 11;
const int _typeCertificateRequest = 13;
const int _typeCertificateVerify = 15;
const int _typeFinished = 20;
const int _typeKeyUpdate = 24;

const int _extensionServerName = 0;
const int _extensionStatusRequest = 5;
const int _extensionSupportedCurves = 10;
const int _extensionSupportedPoints = 11;
const int _extensionSignatureAlgorithms = 13;
const int _extensionALPN = 16;
const int _extensionSCT = 18;
const int _extensionExtendedMasterSecret = 23;
const int _extensionSessionTicket = 35;
const int _extensionPreSharedKey = 41;
const int _extensionEarlyData = 42;
const int _extensionSupportedVersions = 43;
const int _extensionCookie = 44;
const int _extensionPSKModes = 45;
const int _extensionCertificateAuthorities = 47;
const int _extensionSignatureAlgorithmsCert = 50;
const int _extensionKeyShare = 51;
const int _extensionQuicTransportParameters = 57;
const int _extensionRenegotiationInfo = 0xff01;

const int _statusTypeOCSP = 1;

/// Thrown by every `ClassName.unmarshal(...)` factory constructor in this
/// file when the wire bytes are truncated, malformed, or violate a
/// structural invariant of the TLS handshake message wire format (RFC 8446,
/// Section 4). Mirrors cryptobyte's `bool` "parse failed" signal
/// (`golang.org/x/crypto/cryptobyte`, out of scope -- see file header),
/// which AGENTS.md's Rule 8 vetoes reproducing as a public
/// `(T?, Exception?)` return.
final class HandshakeMessageFormatException implements Exception {
  /// Wraps a human-readable failure [message].
  const HandshakeMessageFormatException(this.message);

  /// Human-readable parse failure detail.
  final String message;

  @override
  String toString() => 'HandshakeMessageFormatException: $message';
}

// ---------------------------------------------------------------------------
// Private wire-format infrastructure (see file header for design rationale).
// ---------------------------------------------------------------------------

Uint8List _beUint8(int value) =>
    Uint8List.fromList([Golang.Uint8(value).toLittleEndianBytes()[0]]);

Uint8List _beUint16(int value) {
  final le = Golang.Uint16(value).toLittleEndianBytes();
  return Uint8List.fromList([le[1], le[0]]);
}

Uint8List _beUint24(int value) {
  final le = Golang.Uint32(
    value,
  ).toLittleEndianBytes(); // [b0,b1,b2,b3]; b3 dropped (24-bit truncation).
  return Uint8List.fromList([le[2], le[1], le[0]]);
}

Uint8List _beUint32(int value) {
  final le = Golang.Uint32(value).toLittleEndianBytes();
  return Uint8List.fromList([le[3], le[2], le[1], le[0]]);
}

/// Port of the wire-building behavior of `cryptobyte.Builder`
/// (`golang.org/x/crypto/cryptobyte`, out of scope -- see file header), plus
/// Go's own `addBytesWithLength` helper (`handshake_messages.go:26-34`).
final class _Builder {
  final BytesBuilder _buf = BytesBuilder(copy: false);

  void addUint8(int v) => _buf.add(_beUint8(v));

  void addUint16(int v) => _buf.add(_beUint16(v));

  void addUint24(int v) => _buf.add(_beUint24(v));

  void addUint32(int v) => _buf.add(_beUint32(v));

  void addBytes(List<int> v) => _buf.add(v);

  /// Port of `addBytesWithLength` (`handshake_messages.go:26-34`).
  void addBytesWithLength(List<int> v, int n) {
    if (v.length != n) {
      throw ArgumentError('invalid value length: expected $n, got ${v.length}');
    }
    _buf.add(v);
  }

  void addUint8LengthPrefixed(void Function(_Builder b) fn) =>
      _addLengthPrefixed(1, 0xFF, fn);

  void addUint16LengthPrefixed(void Function(_Builder b) fn) =>
      _addLengthPrefixed(2, 0xFFFF, fn);

  void addUint24LengthPrefixed(void Function(_Builder b) fn) =>
      _addLengthPrefixed(3, 0xFFFFFF, fn);

  void _addLengthPrefixed(
    int prefixWidth,
    int maxLen,
    void Function(_Builder b) fn,
  ) {
    final inner = _Builder();
    fn(inner);
    final body = inner.toBytes();
    if (body.length > maxLen) {
      throw StateError(
        'tls: internal error: length-prefixed body of ${body.length} bytes overflows a $prefixWidth-byte prefix',
      );
    }
    switch (prefixWidth) {
      case 1:
        addUint8(body.length);
      case 2:
        addUint16(body.length);
      case 3:
        addUint24(body.length);
    }
    addBytes(body);
  }

  Uint8List toBytes() => _buf.toBytes();
}

/// Port of the wire-parsing behavior of `cryptobyte.String`
/// (`golang.org/x/crypto/cryptobyte`, out of scope -- see file header), plus
/// Go's own `readUint8/16/24LengthPrefixed` helpers
/// (`handshake_messages.go:53-69`). Every read throws
/// [HandshakeMessageFormatException] on truncation instead of returning
/// `false` -- see file header for why.
final class _Reader {
  _Reader(this._data);

  final Uint8List _data;
  int _pos = 0;

  bool get isEmpty => _pos >= _data.length;

  int get remainingLength => _data.length - _pos;

  void _require(int n) {
    if (remainingLength < n) {
      throw const HandshakeMessageFormatException(
        'unexpected end of handshake message data',
      );
    }
  }

  /// Throws unless every byte of this reader has been consumed. Port of the
  /// generic `if !x.Empty() { return false }` checks scattered throughout
  /// `handshake_messages.go`.
  void expectEmpty() {
    if (!isEmpty) {
      throw const HandshakeMessageFormatException(
        'unexpected trailing bytes in handshake message',
      );
    }
  }

  void skip(int n) {
    _require(n);
    _pos += n;
  }

  int readUint8() {
    _require(1);
    return _data[_pos++];
  }

  int readUint16() {
    _require(2);
    final v = (_data[_pos] << 8) | _data[_pos + 1];
    _pos += 2;
    return v;
  }

  int readUint24() {
    _require(3);
    final v = (_data[_pos] << 16) | (_data[_pos + 1] << 8) | _data[_pos + 2];
    _pos += 3;
    return v;
  }

  int readUint32() {
    _require(4);
    final v =
        (_data[_pos] << 24) |
        (_data[_pos + 1] << 16) |
        (_data[_pos + 2] << 8) |
        _data[_pos + 3];
    _pos += 4;
    return v;
  }

  Uint8List readBytes(int n) {
    _require(n);
    final out = Uint8List.sublistView(_data, _pos, _pos + n);
    _pos += n;
    return out;
  }

  /// The rest of this reader's unread bytes.
  Uint8List readAll() => readBytes(remainingLength);

  Uint8List readUint8LengthPrefixed() => readBytes(readUint8());

  Uint8List readUint16LengthPrefixed() => readBytes(readUint16());

  Uint8List readUint24LengthPrefixed() => readBytes(readUint24());

  _Reader readUint8LengthPrefixedReader() => _Reader(readUint8LengthPrefixed());

  _Reader readUint16LengthPrefixedReader() =>
      _Reader(readUint16LengthPrefixed());

  _Reader readUint24LengthPrefixedReader() =>
      _Reader(readUint24LengthPrefixed());
}

// ---------------------------------------------------------------------------
// Promoted supporting types (see file header, Cenário C).
// ---------------------------------------------------------------------------

/// Port of the unexported `keyShare` struct (`common.go:164-167`): a single
/// TLS 1.3 Key Share entry (RFC 8446, Section 4.2.8).
final class KeyShare {
  /// Builds a key share from its group identifier and exchange data.
  KeyShare({required this.group, required this.data});

  /// Port of `keyShare.group` (`common.go:165`): the `CurveID`/`NamedGroup`
  /// identifier. See the file header for why this is a plain `int`.
  final int group;

  /// Port of `keyShare.data` (`common.go:166`).
  final Uint8List data;
}

/// Port of the unexported `pskIdentity` struct (`common.go:177-180`): a
/// single TLS 1.3 PSK identity (RFC 8446, Section 4.2.11).
final class PskIdentity {
  /// Builds a PSK identity from its label and obfuscated ticket age.
  PskIdentity({required this.label, required this.obfuscatedTicketAge});

  /// Port of `pskIdentity.label` (`common.go:178`).
  final Uint8List label;

  /// Port of `pskIdentity.obfuscatedTicketAge` (`common.go:179`).
  final int obfuscatedTicketAge;
}

// ---------------------------------------------------------------------------
// Handshake messages.
// ---------------------------------------------------------------------------

/// Port of `clientHelloMsg` (`handshake_messages.go:71-103`).
final class ClientHelloMsg {
  /// Builds a ClientHello. Every field defaults to its Go zero value.
  ClientHelloMsg({
    this.original,
    this.vers = 0,
    Uint8List? random,
    Uint8List? sessionId,
    List<int>? cipherSuites,
    Uint8List? compressionMethods,
    this.serverName = '',
    this.ocspStapling = false,
    List<int>? supportedCurves,
    Uint8List? supportedPoints,
    this.ticketSupported = false,
    Uint8List? sessionTicket,
    List<int>? supportedSignatureAlgorithms,
    List<int>? supportedSignatureAlgorithmsCert,
    this.secureRenegotiationSupported = false,
    Uint8List? secureRenegotiation,
    this.extendedMasterSecret = false,
    List<String>? alpnProtocols,
    this.scts = false,
    List<int>? supportedVersions,
    Uint8List? cookie,
    List<KeyShare>? keyShares,
    this.earlyData = false,
    Uint8List? pskModes,
    List<PskIdentity>? pskIdentities,
    List<Uint8List>? pskBinders,
    this.quicTransportParameters,
    this.encryptedClientHello,
    List<int>? extensions,
  }) : random = random ?? Uint8List(0),
       sessionId = sessionId ?? Uint8List(0),
       cipherSuites = cipherSuites ?? <int>[],
       compressionMethods = compressionMethods ?? Uint8List(0),
       supportedCurves = supportedCurves ?? <int>[],
       supportedPoints = supportedPoints ?? Uint8List(0),
       sessionTicket = sessionTicket ?? Uint8List(0),
       supportedSignatureAlgorithms = supportedSignatureAlgorithms ?? <int>[],
       supportedSignatureAlgorithmsCert =
           supportedSignatureAlgorithmsCert ?? <int>[],
       secureRenegotiation = secureRenegotiation ?? Uint8List(0),
       alpnProtocols = alpnProtocols ?? <String>[],
       supportedVersions = supportedVersions ?? <int>[],
       cookie = cookie ?? Uint8List(0),
       keyShares = keyShares ?? <KeyShare>[],
       pskModes = pskModes ?? Uint8List(0),
       pskIdentities = pskIdentities ?? <PskIdentity>[],
       pskBinders = pskBinders ?? <Uint8List>[],
       extensions = extensions ?? <int>[];

  /// Port of `clientHelloMsg.original` (`:72`): the exact bytes this message
  /// was parsed from, when known. Preserved because
  /// [marshalWithoutBinders]/PSK binder computation need the exact original
  /// wire bytes rather than a re-serialization.
  Uint8List? original;

  /// Port of `clientHelloMsg.vers` (`:73`).
  int vers;

  /// Port of `clientHelloMsg.random` (`:74`).
  Uint8List random;

  /// Port of `clientHelloMsg.sessionId` (`:75`).
  Uint8List sessionId;

  /// Port of `clientHelloMsg.cipherSuites` (`:76`).
  List<int> cipherSuites;

  /// Port of `clientHelloMsg.compressionMethods` (`:77`).
  Uint8List compressionMethods;

  /// Port of `clientHelloMsg.serverName` (`:78`): SNI host name (RFC 6066,
  /// Section 3). Implemented.
  String serverName;

  /// Port of `clientHelloMsg.ocspStapling` (`:79`). Named gap: not marshaled
  /// or unmarshaled (see file header).
  bool ocspStapling;

  /// Port of `clientHelloMsg.supportedCurves` (`:80`): `supported_groups`
  /// in TLS 1.3 (RFC 8446, Section 4.2.7). Implemented.
  List<int> supportedCurves;

  /// Port of `clientHelloMsg.supportedPoints` (`:81`). Named gap.
  Uint8List supportedPoints;

  /// Port of `clientHelloMsg.ticketSupported` (`:82`). Named gap.
  bool ticketSupported;

  /// Port of `clientHelloMsg.sessionTicket` (`:83`). Named gap.
  Uint8List sessionTicket;

  /// Port of `clientHelloMsg.supportedSignatureAlgorithms` (`:84`).
  /// Implemented.
  List<int> supportedSignatureAlgorithms;

  /// Port of `clientHelloMsg.supportedSignatureAlgorithmsCert` (`:85`).
  /// Named gap.
  List<int> supportedSignatureAlgorithmsCert;

  /// Port of `clientHelloMsg.secureRenegotiationSupported` (`:86`). Named
  /// gap.
  bool secureRenegotiationSupported;

  /// Port of `clientHelloMsg.secureRenegotiation` (`:87`). Named gap.
  Uint8List secureRenegotiation;

  /// Port of `clientHelloMsg.extendedMasterSecret` (`:88`). Named gap.
  bool extendedMasterSecret;

  /// Port of `clientHelloMsg.alpnProtocols` (`:89`). Implemented.
  List<String> alpnProtocols;

  /// Port of `clientHelloMsg.scts` (`:90`). Named gap.
  bool scts;

  /// Port of `clientHelloMsg.supportedVersions` (`:91`). Implemented.
  List<int> supportedVersions;

  /// Port of `clientHelloMsg.cookie` (`:92`). Implemented.
  Uint8List cookie;

  /// Port of `clientHelloMsg.keyShares` (`:93`). Implemented.
  List<KeyShare> keyShares;

  /// Port of `clientHelloMsg.earlyData` (`:94`). Named gap.
  bool earlyData;

  /// Port of `clientHelloMsg.pskModes` (`:95`). Implemented.
  Uint8List pskModes;

  /// Port of `clientHelloMsg.pskIdentities` (`:96`). Implemented.
  List<PskIdentity> pskIdentities;

  /// Port of `clientHelloMsg.pskBinders` (`:97`). Implemented.
  List<Uint8List> pskBinders;

  /// Port of `clientHelloMsg.quicTransportParameters` (`:98`). Named gap
  /// (see file header).
  Uint8List? quicTransportParameters;

  /// Port of `clientHelloMsg.encryptedClientHello` (`:99`). Named gap (ECH,
  /// see file header).
  Uint8List? encryptedClientHello;

  /// Port of `clientHelloMsg.extensions` (`:101`): the raw extension IDs
  /// seen while unmarshaling, in order. Populated for every extension
  /// (implemented or not), matching Go's unconditional
  /// `m.extensions = append(m.extensions, extension)` before its switch.
  List<int> extensions;

  /// Port of `(*clientHelloMsg).marshal` (`:375-377`), which is
  /// `marshalMsg(false)`. Only the non-ECH path is ported (ECH is a named
  /// gap; see file header) -- `marshalMsg`'s `echInner`/`echOuterExts`
  /// branching (`:104-373`) collapses away entirely.
  Uint8List marshal() {
    final exts = _Builder();
    if (serverName.isNotEmpty) {
      // RFC 6066, Section 3
      exts.addUint16(_extensionServerName);
      exts.addUint16LengthPrefixed((exts) {
        exts.addUint16LengthPrefixed((exts) {
          exts.addUint8(0); // name_type = host_name
          exts.addUint16LengthPrefixed(
            (exts) => exts.addBytes(utf8.encode(serverName)),
          );
        });
      });
    }
    if (supportedCurves.isNotEmpty) {
      // RFC 4492, Section 5.1.1 and RFC 8446, Section 4.2.7
      exts.addUint16(_extensionSupportedCurves);
      exts.addUint16LengthPrefixed((exts) {
        exts.addUint16LengthPrefixed((exts) {
          for (final curve in supportedCurves) {
            exts.addUint16(curve);
          }
        });
      });
    }
    if (supportedSignatureAlgorithms.isNotEmpty) {
      // RFC 5246, Section 7.4.1.4.1
      exts.addUint16(_extensionSignatureAlgorithms);
      exts.addUint16LengthPrefixed((exts) {
        exts.addUint16LengthPrefixed((exts) {
          for (final sigAlgo in supportedSignatureAlgorithms) {
            exts.addUint16(sigAlgo);
          }
        });
      });
    }
    if (alpnProtocols.isNotEmpty) {
      // RFC 7301, Section 3.1
      exts.addUint16(_extensionALPN);
      exts.addUint16LengthPrefixed((exts) {
        exts.addUint16LengthPrefixed((exts) {
          for (final proto in alpnProtocols) {
            exts.addUint8LengthPrefixed(
              (exts) => exts.addBytes(utf8.encode(proto)),
            );
          }
        });
      });
    }
    if (supportedVersions.isNotEmpty) {
      // RFC 8446, Section 4.2.1
      exts.addUint16(_extensionSupportedVersions);
      exts.addUint16LengthPrefixed((exts) {
        exts.addUint8LengthPrefixed((exts) {
          for (final vers in supportedVersions) {
            exts.addUint16(vers);
          }
        });
      });
    }
    if (cookie.isNotEmpty) {
      // RFC 8446, Section 4.2.2
      exts.addUint16(_extensionCookie);
      exts.addUint16LengthPrefixed((exts) {
        exts.addUint16LengthPrefixed((exts) => exts.addBytes(cookie));
      });
    }
    if (keyShares.isNotEmpty) {
      // RFC 8446, Section 4.2.8
      exts.addUint16(_extensionKeyShare);
      exts.addUint16LengthPrefixed((exts) {
        exts.addUint16LengthPrefixed((exts) {
          for (final ks in keyShares) {
            exts.addUint16(ks.group);
            exts.addUint16LengthPrefixed((exts) => exts.addBytes(ks.data));
          }
        });
      });
    }
    if (pskModes.isNotEmpty) {
      // RFC 8446, Section 4.2.9
      exts.addUint16(_extensionPSKModes);
      exts.addUint16LengthPrefixed((exts) {
        exts.addUint8LengthPrefixed((exts) => exts.addBytes(pskModes));
      });
    }
    if (quicTransportParameters != null) {
      // RFC 9001, Section 8.2
      exts.addUint16(_extensionQuicTransportParameters);
      exts.addUint16LengthPrefixed(
        (exts) => exts.addBytes(quicTransportParameters!),
      );
    }
    if (pskIdentities.isNotEmpty) {
      // RFC 8446, Section 4.2.11 -- pre_shared_key must be the last extension.
      exts.addUint16(_extensionPreSharedKey);
      exts.addUint16LengthPrefixed((exts) {
        exts.addUint16LengthPrefixed((exts) {
          for (final psk in pskIdentities) {
            exts.addUint16LengthPrefixed((exts) => exts.addBytes(psk.label));
            exts.addUint32(psk.obfuscatedTicketAge);
          }
        });
        exts.addUint16LengthPrefixed((exts) {
          for (final binder in pskBinders) {
            exts.addUint8LengthPrefixed((exts) => exts.addBytes(binder));
          }
        });
      });
    }
    final extBytes = exts.toBytes();

    final b = _Builder();
    b.addUint8(_typeClientHello);
    b.addUint24LengthPrefixed((b) {
      b.addUint16(vers);
      b.addBytesWithLength(random, 32);
      b.addUint8LengthPrefixed((b) => b.addBytes(sessionId));
      b.addUint16LengthPrefixed((b) {
        for (final suite in cipherSuites) {
          b.addUint16(suite);
        }
      });
      b.addUint8LengthPrefixed((b) => b.addBytes(compressionMethods));
      if (extBytes.isNotEmpty) {
        b.addUint16LengthPrefixed((b) => b.addBytes(extBytes));
      }
    });
    return b.toBytes();
  }

  /// Port of `(*clientHelloMsg).marshalWithoutBinders`
  /// (`:382-400`): the ClientHello through the PreSharedKeyExtension's
  /// `identities` field (RFC 8446, Section 4.2.11.2), i.e. everything except
  /// the trailing PSK binder list. [pskBinders] must already hold slices of
  /// the correct final length.
  Uint8List marshalWithoutBinders() {
    var bindersLen = 2; // uint16 length prefix of the whole binders list
    for (final binder in pskBinders) {
      bindersLen += 1 + binder.length; // uint8 length prefix + binder bytes
    }
    final fullMessage = original ?? marshal();
    return Uint8List.sublistView(
      fullMessage,
      0,
      fullMessage.length - bindersLen,
    );
  }

  /// Port of `(*clientHelloMsg).updateBinders` (`:404-416`): replaces
  /// [pskBinders] with [newBinders], which must have the same per-entry
  /// lengths as the current binders.
  void updateBinders(List<Uint8List> newBinders) {
    if (newBinders.length != pskBinders.length) {
      throw ArgumentError('tls: internal error: pskBinders length mismatch');
    }
    for (var i = 0; i < pskBinders.length; i++) {
      if (newBinders[i].length != pskBinders[i].length) {
        throw ArgumentError('tls: internal error: pskBinders length mismatch');
      }
    }
    pskBinders = newBinders;
  }

  /// Port of `(*clientHelloMsg).unmarshal` (`:418-680`). Extensions outside
  /// the implemented set (see file header) are ignored exactly like Go's own
  /// `default: continue` treats a genuinely unrecognized extension number.
  factory ClientHelloMsg.unmarshal(Uint8List data) {
    final m = ClientHelloMsg(original: data);
    final s = _Reader(data);
    s.skip(4); // message type and uint24 length field
    m.vers = s.readUint16();
    m.random = s.readBytes(32);
    m.sessionId = s.readUint8LengthPrefixed();

    final cipherSuitesReader = s.readUint16LengthPrefixedReader();
    while (!cipherSuitesReader.isEmpty) {
      m.cipherSuites.add(cipherSuitesReader.readUint16());
    }

    m.compressionMethods = s.readUint8LengthPrefixed();

    if (s.isEmpty) {
      // ClientHello is optionally followed by extension data.
      return m;
    }

    final extReader = s.readUint16LengthPrefixedReader();
    s.expectEmpty();

    final seenExts = <int>{};
    while (!extReader.isEmpty) {
      final extension = extReader.readUint16();
      final extData = extReader.readUint16LengthPrefixedReader();

      if (!seenExts.add(extension)) {
        throw const HandshakeMessageFormatException(
          'duplicate extension in ClientHello',
        );
      }
      m.extensions.add(extension);

      switch (extension) {
        case _extensionServerName:
          // RFC 6066, Section 3
          final nameList = extData.readUint16LengthPrefixedReader();
          if (nameList.isEmpty) {
            throw const HandshakeMessageFormatException(
              'empty server_name list',
            );
          }
          while (!nameList.isEmpty) {
            final nameType = nameList.readUint8();
            final serverNameReader = nameList.readUint16LengthPrefixedReader();
            if (serverNameReader.isEmpty) {
              throw const HandshakeMessageFormatException(
                'empty server_name entry',
              );
            }
            if (nameType != 0) continue;
            if (m.serverName.isNotEmpty) {
              throw const HandshakeMessageFormatException(
                'multiple names of the same name_type are prohibited',
              );
            }
            m.serverName = utf8.decode(serverNameReader.readAll());
            if (m.serverName.endsWith('.')) {
              throw const HandshakeMessageFormatException(
                'server_name may not include a trailing dot',
              );
            }
          }
        case _extensionSupportedCurves:
          // RFC 4492, Section 5.1.1 and RFC 8446, Section 4.2.7
          final curves = extData.readUint16LengthPrefixedReader();
          if (curves.isEmpty) {
            throw const HandshakeMessageFormatException(
              'empty supported_groups list',
            );
          }
          while (!curves.isEmpty) {
            m.supportedCurves.add(curves.readUint16());
          }
        case _extensionSignatureAlgorithms:
          // RFC 5246, Section 7.4.1.4.1
          final sigAndAlgs = extData.readUint16LengthPrefixedReader();
          if (sigAndAlgs.isEmpty) {
            throw const HandshakeMessageFormatException(
              'empty signature_algorithms list',
            );
          }
          while (!sigAndAlgs.isEmpty) {
            m.supportedSignatureAlgorithms.add(sigAndAlgs.readUint16());
          }
        case _extensionALPN:
          // RFC 7301, Section 3.1
          final protoList = extData.readUint16LengthPrefixedReader();
          if (protoList.isEmpty) {
            throw const HandshakeMessageFormatException(
              'empty alpn protocol list',
            );
          }
          while (!protoList.isEmpty) {
            final proto = protoList.readUint8LengthPrefixed();
            if (proto.isEmpty) {
              throw const HandshakeMessageFormatException(
                'empty alpn protocol name',
              );
            }
            m.alpnProtocols.add(utf8.decode(proto));
          }
        case _extensionSupportedVersions:
          // RFC 8446, Section 4.2.1
          final versList = extData.readUint8LengthPrefixedReader();
          if (versList.isEmpty) {
            throw const HandshakeMessageFormatException(
              'empty supported_versions list',
            );
          }
          while (!versList.isEmpty) {
            m.supportedVersions.add(versList.readUint16());
          }
        case _extensionCookie:
          // RFC 8446, Section 4.2.2
          m.cookie = extData.readUint16LengthPrefixed();
          if (m.cookie.isEmpty) {
            throw const HandshakeMessageFormatException('empty cookie');
          }
        case _extensionKeyShare:
          // RFC 8446, Section 4.2.8
          final clientShares = extData.readUint16LengthPrefixedReader();
          while (!clientShares.isEmpty) {
            final group = clientShares.readUint16();
            final ksData = clientShares.readUint16LengthPrefixed();
            if (ksData.isEmpty) {
              throw const HandshakeMessageFormatException(
                'empty key_share entry',
              );
            }
            m.keyShares.add(KeyShare(group: group, data: ksData));
          }
        case _extensionPSKModes:
          // RFC 8446, Section 4.2.9
          m.pskModes = extData.readUint8LengthPrefixed();
        case _extensionQuicTransportParameters:
          // RFC 9001, Section 8.2
          m.quicTransportParameters = extData.readAll();
        case _extensionPreSharedKey:
          // RFC 8446, Section 4.2.11
          if (!extReader.isEmpty) {
            throw const HandshakeMessageFormatException(
              'pre_shared_key must be the last extension',
            );
          }
          final identities = extData.readUint16LengthPrefixedReader();
          if (identities.isEmpty) {
            throw const HandshakeMessageFormatException(
              'empty psk identities list',
            );
          }
          while (!identities.isEmpty) {
            final label = identities.readUint16LengthPrefixed();
            final obfuscatedTicketAge = identities.readUint32();
            if (label.isEmpty) {
              throw const HandshakeMessageFormatException(
                'empty psk identity label',
              );
            }
            m.pskIdentities.add(
              PskIdentity(
                label: label,
                obfuscatedTicketAge: obfuscatedTicketAge,
              ),
            );
          }
          final binders = extData.readUint16LengthPrefixedReader();
          if (binders.isEmpty) {
            throw const HandshakeMessageFormatException(
              'empty psk binders list',
            );
          }
          while (!binders.isEmpty) {
            final binder = binders.readUint8LengthPrefixed();
            if (binder.isEmpty) {
              throw const HandshakeMessageFormatException('empty psk binder');
            }
            m.pskBinders.add(binder);
          }
        default:
          // Ignore unrecognized or deliberately unimplemented extensions.
          continue;
      }

      extData.expectEmpty();
    }

    return m;
  }
}

/// Port of `serverHelloMsg` (`handshake_messages.go:719-745`). Ported in
/// full except `encryptedClientHello` (ECH, named gap; see file header).
final class ServerHelloMsg {
  /// Builds a ServerHello. Every field defaults to its Go zero value.
  ServerHelloMsg({
    this.original,
    this.vers = 0,
    Uint8List? random,
    Uint8List? sessionId,
    this.cipherSuite = 0,
    this.compressionMethod = 0,
    this.ocspStapling = false,
    this.ticketSupported = false,
    this.secureRenegotiationSupported = false,
    Uint8List? secureRenegotiation,
    this.extendedMasterSecret = false,
    this.alpnProtocol = '',
    List<Uint8List>? scts,
    this.supportedVersion,
    this.serverShare,
    this.selectedIdentityPresent = false,
    this.selectedIdentity = 0,
    Uint8List? supportedPoints,
    this.encryptedClientHello,
    this.serverNameAck = false,
    Uint8List? cookie,
    this.selectedGroup,
  }) : random = random ?? Uint8List(0),
       sessionId = sessionId ?? Uint8List(0),
       secureRenegotiation = secureRenegotiation ?? Uint8List(0),
       scts = scts ?? <Uint8List>[],
       supportedPoints = supportedPoints ?? Uint8List(0),
       cookie = cookie ?? Uint8List(0);

  /// Port of `serverHelloMsg.original` (`:720`).
  Uint8List? original;

  /// Port of `serverHelloMsg.vers` (`:721`).
  int vers;

  /// Port of `serverHelloMsg.random` (`:722`).
  Uint8List random;

  /// Port of `serverHelloMsg.sessionId` (`:723`).
  Uint8List sessionId;

  /// Port of `serverHelloMsg.cipherSuite` (`:724`).
  int cipherSuite;

  /// Port of `serverHelloMsg.compressionMethod` (`:725`).
  int compressionMethod;

  /// Port of `serverHelloMsg.ocspStapling` (`:726`).
  bool ocspStapling;

  /// Port of `serverHelloMsg.ticketSupported` (`:727`).
  bool ticketSupported;

  /// Port of `serverHelloMsg.secureRenegotiationSupported` (`:728`).
  bool secureRenegotiationSupported;

  /// Port of `serverHelloMsg.secureRenegotiation` (`:729`).
  Uint8List secureRenegotiation;

  /// Port of `serverHelloMsg.extendedMasterSecret` (`:730`).
  bool extendedMasterSecret;

  /// Port of `serverHelloMsg.alpnProtocol` (`:731`).
  String alpnProtocol;

  /// Port of `serverHelloMsg.scts` (`:732`).
  List<Uint8List> scts;

  /// Port of `serverHelloMsg.supportedVersion` (`:733`). Go's zero value
  /// (`0`, not a valid TLS version) means absent; a nullable `int?` is the
  /// idiomatic Dart equivalent of that sentinel.
  int? supportedVersion;

  /// Port of `serverHelloMsg.serverShare` (`:734`). Go's zero value
  /// (`group == 0`) means absent; nullable here for the same reason as
  /// [supportedVersion].
  KeyShare? serverShare;

  /// Port of `serverHelloMsg.selectedIdentityPresent` (`:735`).
  bool selectedIdentityPresent;

  /// Port of `serverHelloMsg.selectedIdentity` (`:736`).
  int selectedIdentity;

  /// Port of `serverHelloMsg.supportedPoints` (`:737`).
  Uint8List supportedPoints;

  /// Port of `serverHelloMsg.encryptedClientHello` (`:738`). Named gap (ECH,
  /// see file header): declared for struct fidelity, never marshaled or
  /// unmarshaled.
  Uint8List? encryptedClientHello;

  /// Port of `serverHelloMsg.serverNameAck` (`:739`).
  bool serverNameAck;

  /// Port of `serverHelloMsg.cookie` (`:742`, HelloRetryRequest extension).
  Uint8List cookie;

  /// Port of `serverHelloMsg.selectedGroup` (`:743`, HelloRetryRequest
  /// extension). Nullable for the same reason as [supportedVersion].
  int? selectedGroup;

  /// Port of `(*serverHelloMsg).marshal` (`:746-869`).
  Uint8List marshal() {
    final exts = _Builder();
    if (ocspStapling) {
      exts.addUint16(_extensionStatusRequest);
      exts.addUint16(0); // empty extension_data
    }
    if (ticketSupported) {
      exts.addUint16(_extensionSessionTicket);
      exts.addUint16(0);
    }
    if (secureRenegotiationSupported) {
      exts.addUint16(_extensionRenegotiationInfo);
      exts.addUint16LengthPrefixed((exts) {
        exts.addUint8LengthPrefixed(
          (exts) => exts.addBytes(secureRenegotiation),
        );
      });
    }
    if (extendedMasterSecret) {
      exts.addUint16(_extensionExtendedMasterSecret);
      exts.addUint16(0);
    }
    if (alpnProtocol.isNotEmpty) {
      exts.addUint16(_extensionALPN);
      exts.addUint16LengthPrefixed((exts) {
        exts.addUint16LengthPrefixed((exts) {
          exts.addUint8LengthPrefixed(
            (exts) => exts.addBytes(utf8.encode(alpnProtocol)),
          );
        });
      });
    }
    if (scts.isNotEmpty) {
      exts.addUint16(_extensionSCT);
      exts.addUint16LengthPrefixed((exts) {
        exts.addUint16LengthPrefixed((exts) {
          for (final sct in scts) {
            exts.addUint16LengthPrefixed((exts) => exts.addBytes(sct));
          }
        });
      });
    }
    final sv = supportedVersion;
    if (sv != null) {
      exts.addUint16(_extensionSupportedVersions);
      exts.addUint16LengthPrefixed((exts) => exts.addUint16(sv));
    }
    final share = serverShare;
    if (share != null) {
      exts.addUint16(_extensionKeyShare);
      exts.addUint16LengthPrefixed((exts) {
        exts.addUint16(share.group);
        exts.addUint16LengthPrefixed((exts) => exts.addBytes(share.data));
      });
    }
    if (selectedIdentityPresent) {
      exts.addUint16(_extensionPreSharedKey);
      exts.addUint16LengthPrefixed((exts) => exts.addUint16(selectedIdentity));
    }
    if (cookie.isNotEmpty) {
      exts.addUint16(_extensionCookie);
      exts.addUint16LengthPrefixed((exts) {
        exts.addUint16LengthPrefixed((exts) => exts.addBytes(cookie));
      });
    }
    final group = selectedGroup;
    if (group != null) {
      exts.addUint16(_extensionKeyShare);
      exts.addUint16LengthPrefixed((exts) => exts.addUint16(group));
    }
    if (supportedPoints.isNotEmpty) {
      exts.addUint16(_extensionSupportedPoints);
      exts.addUint16LengthPrefixed((exts) {
        exts.addUint8LengthPrefixed((exts) => exts.addBytes(supportedPoints));
      });
    }
    // encryptedClientHello: named gap, never marshaled (see file header).
    if (serverNameAck) {
      exts.addUint16(_extensionServerName);
      exts.addUint16(0);
    }

    final extBytes = exts.toBytes();
    final b = _Builder();
    b.addUint8(_typeServerHello);
    b.addUint24LengthPrefixed((b) {
      b.addUint16(vers);
      b.addBytesWithLength(random, 32);
      b.addUint8LengthPrefixed((b) => b.addBytes(sessionId));
      b.addUint16(cipherSuite);
      b.addUint8(compressionMethod);
      if (extBytes.isNotEmpty) {
        b.addUint16LengthPrefixed((b) => b.addBytes(extBytes));
      }
    });
    return b.toBytes();
  }

  /// Port of `(*serverHelloMsg).unmarshal` (`:871-997`).
  factory ServerHelloMsg.unmarshal(Uint8List data) {
    final m = ServerHelloMsg(original: data);
    final s = _Reader(data);
    s.skip(4); // message type and uint24 length field
    m.vers = s.readUint16();
    m.random = s.readBytes(32);
    m.sessionId = s.readUint8LengthPrefixed();
    m.cipherSuite = s.readUint16();
    m.compressionMethod = s.readUint8();

    if (s.isEmpty) {
      // ServerHello is optionally followed by extension data.
      return m;
    }

    final extReader = s.readUint16LengthPrefixedReader();
    s.expectEmpty();

    final seenExts = <int>{};
    while (!extReader.isEmpty) {
      final extension = extReader.readUint16();
      final extData = extReader.readUint16LengthPrefixedReader();

      if (!seenExts.add(extension)) {
        throw const HandshakeMessageFormatException(
          'duplicate extension in ServerHello',
        );
      }

      switch (extension) {
        case _extensionStatusRequest:
          m.ocspStapling = true;
        case _extensionSessionTicket:
          m.ticketSupported = true;
        case _extensionRenegotiationInfo:
          m.secureRenegotiation = extData.readUint8LengthPrefixed();
          m.secureRenegotiationSupported = true;
        case _extensionExtendedMasterSecret:
          m.extendedMasterSecret = true;
        case _extensionALPN:
          final protoList = extData.readUint16LengthPrefixedReader();
          if (protoList.isEmpty) {
            throw const HandshakeMessageFormatException(
              'empty alpn protocol list',
            );
          }
          final proto = protoList.readUint8LengthPrefixed();
          if (proto.isEmpty || !protoList.isEmpty) {
            throw const HandshakeMessageFormatException(
              'server_hello alpn must carry exactly one protocol',
            );
          }
          m.alpnProtocol = utf8.decode(proto);
        case _extensionSCT:
          final sctList = extData.readUint16LengthPrefixedReader();
          if (sctList.isEmpty) {
            throw const HandshakeMessageFormatException(
              'empty signed_certificate_timestamp list',
            );
          }
          while (!sctList.isEmpty) {
            final sct = sctList.readUint16LengthPrefixed();
            if (sct.isEmpty) {
              throw const HandshakeMessageFormatException(
                'empty signed_certificate_timestamp',
              );
            }
            m.scts.add(sct);
          }
        case _extensionSupportedVersions:
          m.supportedVersion = extData.readUint16();
        case _extensionCookie:
          m.cookie = extData.readUint16LengthPrefixed();
          if (m.cookie.isEmpty) {
            throw const HandshakeMessageFormatException('empty cookie');
          }
        case _extensionKeyShare:
          // Different formats in ServerHello and HelloRetryRequest -- accept
          // either, matching Go's `len(extData) == 2` sniff (RFC 8446,
          // Section 4.2.8).
          if (extData.remainingLength == 2) {
            m.selectedGroup = extData.readUint16();
          } else {
            final group = extData.readUint16();
            final ksData = extData.readUint16LengthPrefixed();
            m.serverShare = KeyShare(group: group, data: ksData);
          }
        case _extensionPreSharedKey:
          m.selectedIdentityPresent = true;
          m.selectedIdentity = extData.readUint16();
        case _extensionSupportedPoints:
          // RFC 4492, Section 5.1.2
          m.supportedPoints = extData.readUint8LengthPrefixed();
          if (m.supportedPoints.isEmpty) {
            throw const HandshakeMessageFormatException(
              'empty supported_points list',
            );
          }
        case _extensionServerName:
          if (!extData.isEmpty) {
            throw const HandshakeMessageFormatException(
              'server_name ack must be empty',
            );
          }
          m.serverNameAck = true;
        default:
          // Ignore unrecognized extensions (also covers the encryptedClientHello gap).
          continue;
      }

      extData.expectEmpty();
    }

    return m;
  }
}

/// Port of `encryptedExtensionsMsg` (`handshake_messages.go:1003-1009`).
/// `alpnProtocol`/`earlyData`/`serverNameAck` implemented;
/// `quicTransportParameters`/`echRetryConfigs` are named gaps (see file
/// header).
final class EncryptedExtensionsMsg {
  /// Builds an EncryptedExtensions message. Every field defaults to its Go
  /// zero value.
  EncryptedExtensionsMsg({
    this.alpnProtocol = '',
    this.quicTransportParameters,
    this.earlyData = false,
    this.echRetryConfigs,
    this.serverNameAck = false,
  });

  /// Port of `encryptedExtensionsMsg.alpnProtocol` (`:1004`). Implemented.
  String alpnProtocol;

  /// Port of `encryptedExtensionsMsg.quicTransportParameters` (`:1005`).
  /// Named gap.
  Uint8List? quicTransportParameters;

  /// Port of `encryptedExtensionsMsg.earlyData` (`:1006`). Implemented.
  bool earlyData;

  /// Port of `encryptedExtensionsMsg.echRetryConfigs` (`:1007`). Named gap.
  Uint8List? echRetryConfigs;

  /// Port of `encryptedExtensionsMsg.serverNameAck` (`:1008`). Implemented.
  bool serverNameAck;

  /// Port of `(*encryptedExtensionsMsg).marshal` (`:1011-1052`).
  Uint8List marshal() {
    final b = _Builder();
    b.addUint8(_typeEncryptedExtensions);
    b.addUint24LengthPrefixed((b) {
      b.addUint16LengthPrefixed((b) {
        if (alpnProtocol.isNotEmpty) {
          b.addUint16(_extensionALPN);
          b.addUint16LengthPrefixed((b) {
            b.addUint16LengthPrefixed((b) {
              b.addUint8LengthPrefixed(
                (b) => b.addBytes(utf8.encode(alpnProtocol)),
              );
            });
          });
        }
        if (quicTransportParameters != null) {
          // RFC 9001, Section 8.2
          b.addUint16(_extensionQuicTransportParameters);
          b.addUint16LengthPrefixed(
            (b) => b.addBytes(quicTransportParameters!),
          );
        }
        if (earlyData) {
          // RFC 8446, Section 4.2.10
          b.addUint16(_extensionEarlyData);
          b.addUint16(0);
        }
        // echRetryConfigs: named gap, never marshaled.
        if (serverNameAck) {
          b.addUint16(_extensionServerName);
          b.addUint16(0);
        }
      });
    });
    return b.toBytes();
  }

  /// Port of `(*encryptedExtensionsMsg).unmarshal` (`:1054-1119`).
  factory EncryptedExtensionsMsg.unmarshal(Uint8List data) {
    final m = EncryptedExtensionsMsg();
    final s = _Reader(data);
    s.skip(4); // message type and uint24 length field
    final extReader = s.readUint16LengthPrefixedReader();
    s.expectEmpty();

    final seenExts = <int>{};
    while (!extReader.isEmpty) {
      final extension = extReader.readUint16();
      final extData = extReader.readUint16LengthPrefixedReader();

      if (!seenExts.add(extension)) {
        throw const HandshakeMessageFormatException(
          'duplicate extension in EncryptedExtensions',
        );
      }

      switch (extension) {
        case _extensionALPN:
          final protoList = extData.readUint16LengthPrefixedReader();
          if (protoList.isEmpty) {
            throw const HandshakeMessageFormatException(
              'empty alpn protocol list',
            );
          }
          final proto = protoList.readUint8LengthPrefixed();
          if (proto.isEmpty || !protoList.isEmpty) {
            throw const HandshakeMessageFormatException(
              'encrypted_extensions alpn must carry exactly one protocol',
            );
          }
          m.alpnProtocol = utf8.decode(proto);
        case _extensionEarlyData:
          m.earlyData = true;
        case _extensionServerName:
          if (!extData.isEmpty) {
            throw const HandshakeMessageFormatException(
              'server_name ack must be empty',
            );
          }
          m.serverNameAck = true;
        case _extensionQuicTransportParameters:
          // RFC 9001, Section 8.2
          m.quicTransportParameters = extData.readAll();
        default:
          // Ignore unrecognized extensions (also covers the QUIC/ECH gaps).
          continue;
      }

      extData.expectEmpty();
    }

    return m;
  }
}

/// Port of `endOfEarlyDataMsg` (`handshake_messages.go:1121`): the empty
/// EndOfEarlyData message (RFC 8446, Section 4.5).
final class EndOfEarlyDataMsg {
  /// Builds the (fieldless) EndOfEarlyData message.
  const EndOfEarlyDataMsg();

  /// Port of `(*endOfEarlyDataMsg).marshal` (`:1123-1127`).
  Uint8List marshal() => Uint8List.fromList([_typeEndOfEarlyData, 0, 0, 0]);

  /// Port of `(*endOfEarlyDataMsg).unmarshal` (`:1129-1131`).
  factory EndOfEarlyDataMsg.unmarshal(Uint8List data) {
    if (data.length != 4) {
      throw const HandshakeMessageFormatException(
        'end_of_early_data must be exactly 4 bytes',
      );
    }
    return const EndOfEarlyDataMsg();
  }
}

/// Port of `keyUpdateMsg` (`handshake_messages.go:1133-1135`, RFC 8446,
/// Section 4.6.3).
final class KeyUpdateMsg {
  /// Builds a KeyUpdate message.
  KeyUpdateMsg({this.updateRequested = false});

  /// Port of `keyUpdateMsg.updateRequested` (`:1134`).
  bool updateRequested;

  /// Port of `(*keyUpdateMsg).marshal` (`:1137-1149`).
  Uint8List marshal() {
    final b = _Builder();
    b.addUint8(_typeKeyUpdate);
    b.addUint24LengthPrefixed((b) => b.addUint8(updateRequested ? 1 : 0));
    return b.toBytes();
  }

  /// Port of `(*keyUpdateMsg).unmarshal` (`:1151-1168`).
  factory KeyUpdateMsg.unmarshal(Uint8List data) {
    final s = _Reader(data);
    s.skip(4); // message type and uint24 length field
    final updateRequested = s.readUint8();
    s.expectEmpty();
    switch (updateRequested) {
      case 0:
        return KeyUpdateMsg(updateRequested: false);
      case 1:
        return KeyUpdateMsg(updateRequested: true);
      default:
        throw const HandshakeMessageFormatException(
          'invalid key_update request value',
        );
    }
  }
}

/// Port of `newSessionTicketMsgTLS13` (`handshake_messages.go:1170-1176`).
final class NewSessionTicketMsgTls13 {
  /// Builds a NewSessionTicket message. Every field defaults to its Go zero
  /// value.
  NewSessionTicketMsgTls13({
    this.lifetime = 0,
    this.ageAdd = 0,
    Uint8List? nonce,
    Uint8List? label,
    this.maxEarlyData = 0,
  }) : nonce = nonce ?? Uint8List(0),
       label = label ?? Uint8List(0);

  /// Port of `newSessionTicketMsgTLS13.lifetime` (`:1171`).
  int lifetime;

  /// Port of `newSessionTicketMsgTLS13.ageAdd` (`:1172`).
  int ageAdd;

  /// Port of `newSessionTicketMsgTLS13.nonce` (`:1173`).
  Uint8List nonce;

  /// Port of `newSessionTicketMsgTLS13.label` (`:1174`).
  Uint8List label;

  /// Port of `newSessionTicketMsgTLS13.maxEarlyData` (`:1175`). `0` means
  /// the `early_data` extension is omitted (matching Go's `if
  /// m.maxEarlyData > 0`).
  int maxEarlyData;

  /// Port of `(*newSessionTicketMsgTLS13).marshal` (`:1178-1202`).
  Uint8List marshal() {
    final b = _Builder();
    b.addUint8(_typeNewSessionTicket);
    b.addUint24LengthPrefixed((b) {
      b.addUint32(lifetime);
      b.addUint32(ageAdd);
      b.addUint8LengthPrefixed((b) => b.addBytes(nonce));
      b.addUint16LengthPrefixed((b) => b.addBytes(label));
      b.addUint16LengthPrefixed((b) {
        if (maxEarlyData > 0) {
          b.addUint16(_extensionEarlyData);
          b.addUint16LengthPrefixed((b) => b.addUint32(maxEarlyData));
        }
      });
    });
    return b.toBytes();
  }

  /// Port of `(*newSessionTicketMsgTLS13).unmarshal` (`:1204-1243`).
  factory NewSessionTicketMsgTls13.unmarshal(Uint8List data) {
    final s = _Reader(data);
    s.skip(4); // message type and uint24 length field
    final lifetime = s.readUint32();
    final ageAdd = s.readUint32();
    final nonce = s.readUint8LengthPrefixed();
    final label = s.readUint16LengthPrefixed();
    final extReader = s.readUint16LengthPrefixedReader();
    s.expectEmpty();

    var maxEarlyData = 0;
    while (!extReader.isEmpty) {
      final extension = extReader.readUint16();
      final extData = extReader.readUint16LengthPrefixedReader();
      switch (extension) {
        case _extensionEarlyData:
          maxEarlyData = extData.readUint32();
        default:
          continue;
      }
      extData.expectEmpty();
    }

    return NewSessionTicketMsgTls13(
      lifetime: lifetime,
      ageAdd: ageAdd,
      nonce: nonce,
      label: label,
      maxEarlyData: maxEarlyData,
    );
  }
}

/// Port of `certificateRequestMsgTLS13`
/// (`handshake_messages.go:1245-1251`). Ported in full, including
/// `certificate_authorities`.
final class CertificateRequestMsgTls13 {
  /// Builds a CertificateRequest message. Every field defaults to its Go
  /// zero value.
  CertificateRequestMsgTls13({
    this.ocspStapling = false,
    this.scts = false,
    List<int>? supportedSignatureAlgorithms,
    List<int>? supportedSignatureAlgorithmsCert,
    List<Uint8List>? certificateAuthorities,
  }) : supportedSignatureAlgorithms = supportedSignatureAlgorithms ?? <int>[],
       supportedSignatureAlgorithmsCert =
           supportedSignatureAlgorithmsCert ?? <int>[],
       certificateAuthorities = certificateAuthorities ?? <Uint8List>[];

  /// Port of `certificateRequestMsgTLS13.ocspStapling` (`:1246`).
  bool ocspStapling;

  /// Port of `certificateRequestMsgTLS13.scts` (`:1247`).
  bool scts;

  /// Port of `certificateRequestMsgTLS13.supportedSignatureAlgorithms`
  /// (`:1248`).
  List<int> supportedSignatureAlgorithms;

  /// Port of `certificateRequestMsgTLS13.supportedSignatureAlgorithmsCert`
  /// (`:1249`).
  List<int> supportedSignatureAlgorithmsCert;

  /// Port of `certificateRequestMsgTLS13.certificateAuthorities` (`:1250`).
  List<Uint8List> certificateAuthorities;

  /// Port of `(*certificateRequestMsgTLS13).marshal` (`:1253-1311`).
  Uint8List marshal() {
    final b = _Builder();
    b.addUint8(_typeCertificateRequest);
    b.addUint24LengthPrefixed((b) {
      b.addUint8(0); // certificate_request_context: zero length
      b.addUint16LengthPrefixed((b) {
        if (ocspStapling) {
          b.addUint16(_extensionStatusRequest);
          b.addUint16(0);
        }
        if (scts) {
          b.addUint16(_extensionSCT);
          b.addUint16(0);
        }
        if (supportedSignatureAlgorithms.isNotEmpty) {
          b.addUint16(_extensionSignatureAlgorithms);
          b.addUint16LengthPrefixed((b) {
            b.addUint16LengthPrefixed((b) {
              for (final sigAlgo in supportedSignatureAlgorithms) {
                b.addUint16(sigAlgo);
              }
            });
          });
        }
        if (supportedSignatureAlgorithmsCert.isNotEmpty) {
          b.addUint16(_extensionSignatureAlgorithmsCert);
          b.addUint16LengthPrefixed((b) {
            b.addUint16LengthPrefixed((b) {
              for (final sigAlgo in supportedSignatureAlgorithmsCert) {
                b.addUint16(sigAlgo);
              }
            });
          });
        }
        if (certificateAuthorities.isNotEmpty) {
          b.addUint16(_extensionCertificateAuthorities);
          b.addUint16LengthPrefixed((b) {
            b.addUint16LengthPrefixed((b) {
              for (final ca in certificateAuthorities) {
                b.addUint16LengthPrefixed((b) => b.addBytes(ca));
              }
            });
          });
        }
      });
    });
    return b.toBytes();
  }

  /// Port of `(*certificateRequestMsgTLS13).unmarshal` (`:1313-1387`).
  factory CertificateRequestMsgTls13.unmarshal(Uint8List data) {
    final s = _Reader(data);
    s.skip(4); // message type and uint24 length field
    final context = s.readUint8LengthPrefixed();
    if (context.isNotEmpty) {
      throw const HandshakeMessageFormatException(
        'certificate_request_context must be empty',
      );
    }
    final extReader = s.readUint16LengthPrefixedReader();
    s.expectEmpty();

    final m = CertificateRequestMsgTls13();
    while (!extReader.isEmpty) {
      final extension = extReader.readUint16();
      final extData = extReader.readUint16LengthPrefixedReader();
      switch (extension) {
        case _extensionStatusRequest:
          m.ocspStapling = true;
        case _extensionSCT:
          m.scts = true;
        case _extensionSignatureAlgorithms:
          final sigAndAlgs = extData.readUint16LengthPrefixedReader();
          if (sigAndAlgs.isEmpty) {
            throw const HandshakeMessageFormatException(
              'empty signature_algorithms list',
            );
          }
          while (!sigAndAlgs.isEmpty) {
            m.supportedSignatureAlgorithms.add(sigAndAlgs.readUint16());
          }
        case _extensionSignatureAlgorithmsCert:
          final sigAndAlgs = extData.readUint16LengthPrefixedReader();
          if (sigAndAlgs.isEmpty) {
            throw const HandshakeMessageFormatException(
              'empty signature_algorithms_cert list',
            );
          }
          while (!sigAndAlgs.isEmpty) {
            m.supportedSignatureAlgorithmsCert.add(sigAndAlgs.readUint16());
          }
        case _extensionCertificateAuthorities:
          final auths = extData.readUint16LengthPrefixedReader();
          if (auths.isEmpty) {
            throw const HandshakeMessageFormatException(
              'empty certificate_authorities list',
            );
          }
          while (!auths.isEmpty) {
            final ca = auths.readUint16LengthPrefixed();
            if (ca.isEmpty) {
              throw const HandshakeMessageFormatException(
                'empty certificate_authority entry',
              );
            }
            m.certificateAuthorities.add(ca);
          }
        default:
          continue;
      }
      extData.expectEmpty();
    }

    return m;
  }
}

/// Port of `certificateMsgTLS13` (`handshake_messages.go:1459-1463`). See
/// the file header for why `Certificate.Certificate`/`OCSPStaple`/
/// `SignedCertificateTimestamps` are flattened directly onto this class
/// instead of nesting a `Certificate` type.
final class CertificateMsgTls13 {
  /// Builds a CertificateMsgTls13. Every field defaults to its Go zero
  /// value.
  CertificateMsgTls13({
    List<Uint8List>? certificateChain,
    this.ocspStaple,
    this.signedCertificateTimestamps,
    this.ocspStapling = false,
    this.scts = false,
  }) : certificateChain = certificateChain ?? <Uint8List>[];

  /// Port of `certificateMsgTLS13.certificate.Certificate`
  /// (`common.go`'s `Certificate.Certificate [][]byte`): the DER-encoded
  /// certificate chain, leaf first.
  List<Uint8List> certificateChain;

  /// Port of `certificate.OCSPStaple`. On the wire only when [ocspStapling]
  /// is true, mirroring `marshalCertificate` zeroing it out otherwise.
  Uint8List? ocspStaple;

  /// Port of `certificate.SignedCertificateTimestamps`. On the wire only
  /// when [scts] is true.
  List<Uint8List>? signedCertificateTimestamps;

  /// Port of `certificateMsgTLS13.ocspStapling` (`:1461`).
  bool ocspStapling;

  /// Port of `certificateMsgTLS13.scts` (`:1462`).
  bool scts;

  /// Port of `(*certificateMsgTLS13).marshal` (`:1465-1482`), composed with
  /// `marshalCertificate` (`:1484-1519`).
  Uint8List marshal() {
    final b = _Builder();
    b.addUint8(_typeCertificate);
    b.addUint24LengthPrefixed((b) {
      b.addUint8(0); // certificate_request_context: zero length
      _marshalCertificateEntries(
        b,
        chain: certificateChain,
        ocspStaple: ocspStapling ? ocspStaple : null,
        scts: scts ? signedCertificateTimestamps : null,
      );
    });
    return b.toBytes();
  }

  /// Port of `(*certificateMsgTLS13).unmarshal` (`:1521-1537`), composed
  /// with `unmarshalCertificate` (`:1539-1597`).
  factory CertificateMsgTls13.unmarshal(Uint8List data) {
    final s = _Reader(data);
    s.skip(4); // message type and uint24 length field
    final context = s.readUint8LengthPrefixed();
    if (context.isNotEmpty) {
      throw const HandshakeMessageFormatException(
        'certificate_request_context must be empty',
      );
    }
    final decoded = _unmarshalCertificateEntries(s);
    s.expectEmpty();
    return CertificateMsgTls13(
      certificateChain: decoded.chain,
      ocspStaple: decoded.ocspStaple,
      signedCertificateTimestamps: decoded.scts,
      ocspStapling: decoded.ocspStaple != null,
      scts: decoded.scts != null,
    );
  }
}

/// Port of `marshalCertificate` (`handshake_messages.go:1484-1519`).
void _marshalCertificateEntries(
  _Builder b, {
  required List<Uint8List> chain,
  required Uint8List? ocspStaple,
  required List<Uint8List>? scts,
}) {
  b.addUint24LengthPrefixed((b) {
    for (var i = 0; i < chain.length; i++) {
      b.addUint24LengthPrefixed((b) => b.addBytes(chain[i]));
      b.addUint16LengthPrefixed((b) {
        if (i > 0) {
          // This library only supports OCSP and SCT for leaf certificates.
          return;
        }
        if (ocspStaple != null) {
          b.addUint16(_extensionStatusRequest);
          b.addUint16LengthPrefixed((b) {
            b.addUint8(_statusTypeOCSP);
            b.addUint24LengthPrefixed((b) => b.addBytes(ocspStaple));
          });
        }
        if (scts != null) {
          b.addUint16(_extensionSCT);
          b.addUint16LengthPrefixed((b) {
            b.addUint16LengthPrefixed((b) {
              for (final sct in scts) {
                b.addUint16LengthPrefixed((b) => b.addBytes(sct));
              }
            });
          });
        }
      });
    }
  });
}

/// Port of `unmarshalCertificate` (`handshake_messages.go:1539-1597`).
({List<Uint8List> chain, Uint8List? ocspStaple, List<Uint8List>? scts})
_unmarshalCertificateEntries(_Reader s) {
  final certListReader = s.readUint24LengthPrefixedReader();
  final chain = <Uint8List>[];
  Uint8List? ocspStaple;
  List<Uint8List>? scts;

  while (!certListReader.isEmpty) {
    final cert = certListReader.readUint24LengthPrefixed();
    final extReader = certListReader.readUint16LengthPrefixedReader();
    chain.add(cert);

    while (!extReader.isEmpty) {
      final extension = extReader.readUint16();
      final extData = extReader.readUint16LengthPrefixedReader();
      if (chain.length > 1) {
        // This library only supports OCSP and SCT for leaf certificates.
        continue;
      }
      switch (extension) {
        case _extensionStatusRequest:
          final statusType = extData.readUint8();
          if (statusType != _statusTypeOCSP) {
            throw const HandshakeMessageFormatException(
              'unsupported certificate_status_type',
            );
          }
          ocspStaple = extData.readUint24LengthPrefixed();
          if (ocspStaple.isEmpty) {
            throw const HandshakeMessageFormatException('empty OCSP staple');
          }
        case _extensionSCT:
          final sctListReader = extData.readUint16LengthPrefixedReader();
          if (sctListReader.isEmpty) {
            throw const HandshakeMessageFormatException(
              'empty signed_certificate_timestamp list',
            );
          }
          scts ??= <Uint8List>[];
          while (!sctListReader.isEmpty) {
            final sct = sctListReader.readUint16LengthPrefixed();
            if (sct.isEmpty) {
              throw const HandshakeMessageFormatException(
                'empty signed_certificate_timestamp',
              );
            }
            scts.add(sct);
          }
        default:
          continue;
      }
      extData.expectEmpty();
    }
  }

  return (chain: chain, ocspStaple: ocspStaple, scts: scts);
}

/// Port of `finishedMsg` (`handshake_messages.go:1693-1695`, RFC 8446,
/// Section 4.4.4).
final class FinishedMsg {
  /// Builds a Finished message from its `verify_data`.
  FinishedMsg({Uint8List? verifyData})
    : verifyData = verifyData ?? Uint8List(0);

  /// Port of `finishedMsg.verifyData` (`:1694`): produced by
  /// `CipherSuiteTls13.finishedHash` in `key_schedule.dart`.
  Uint8List verifyData;

  /// Port of `(*finishedMsg).marshal` (`:1697-1705`).
  Uint8List marshal() {
    final b = _Builder();
    b.addUint8(_typeFinished);
    b.addUint24LengthPrefixed((b) => b.addBytes(verifyData));
    return b.toBytes();
  }

  /// Port of `(*finishedMsg).unmarshal` (`:1707-1712`).
  factory FinishedMsg.unmarshal(Uint8List data) {
    final s = _Reader(data);
    s.skip(1); // message type only
    final verifyData = s.readUint24LengthPrefixed();
    s.expectEmpty();
    return FinishedMsg(verifyData: verifyData);
  }
}

/// Port of `certificateVerifyMsg` (`handshake_messages.go:1848-1852`).
final class CertificateVerifyMsg {
  /// Builds a CertificateVerify message.
  CertificateVerifyMsg({
    this.hasSignatureAlgorithm = true,
    this.signatureAlgorithm = 0,
    Uint8List? signature,
  }) : signature = signature ?? Uint8List(0);

  /// Port of `certificateVerifyMsg.hasSignatureAlgorithm` (`:1849`): the
  /// format change introduced in TLS 1.2. Always `true` for TLS 1.3, kept
  /// as a field for struct fidelity with the shared TLS 1.2/1.3 Go type.
  bool hasSignatureAlgorithm;

  /// Port of `certificateVerifyMsg.signatureAlgorithm` (`:1850`). See the
  /// file header for why this is a plain `int` (`SignatureScheme`).
  int signatureAlgorithm;

  /// Port of `certificateVerifyMsg.signature` (`:1851`).
  Uint8List signature;

  /// Port of `(*certificateVerifyMsg).marshal` (`:1854-1867`).
  Uint8List marshal() {
    final b = _Builder();
    b.addUint8(_typeCertificateVerify);
    b.addUint24LengthPrefixed((b) {
      if (hasSignatureAlgorithm) {
        b.addUint16(signatureAlgorithm);
      }
      b.addUint16LengthPrefixed((b) => b.addBytes(signature));
    });
    return b.toBytes();
  }

  /// Port of `(*certificateVerifyMsg).unmarshal` (`:1869-1881`).
  factory CertificateVerifyMsg.unmarshal(
    Uint8List data, {
    bool hasSignatureAlgorithm = true,
  }) {
    final s = _Reader(data);
    s.skip(4); // message type and uint24 length field
    var signatureAlgorithm = 0;
    if (hasSignatureAlgorithm) {
      signatureAlgorithm = s.readUint16();
    }
    final signature = s.readUint16LengthPrefixed();
    s.expectEmpty();
    return CertificateVerifyMsg(
      hasSignatureAlgorithm: hasSignatureAlgorithm,
      signatureAlgorithm: signatureAlgorithm,
      signature: signature,
    );
  }
}
