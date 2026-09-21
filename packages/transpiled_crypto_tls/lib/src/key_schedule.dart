// ignore_for_file: library_prefixes
/// Port of the TLS 1.3 key schedule (RFC 8446, Section 7).
///
/// Go's `crypto/tls` key_schedule.go is a thin wrapper (84 lines) over the
/// actual HKDF-Expand-Label / secret-derivation machinery, which since Go's
/// FIPS 140 module-boundary refactor lives in the internal package
/// `crypto/internal/fips140/tls13` (`tls13.go`, 179 lines). Both are ported
/// together here because key_schedule.go's own methods are meaningless
/// without it, and `tls13` has no `go.mod` of its own -- it is part of the
/// same Go standard library module fixed in
/// `doc/transpilation/UPSTREAM_LOCK.md` as `go-stdlib`.
///
/// Go symbol -> upstream file:line -> Dart symbol:
///   - `tls13.ExpandLabel` (fips140/tls13/tls13.go:20-40) -> [expandLabel]
///   - `tls13.extract` (fips140/tls13/tls13.go:42-47) -> `_hkdfExtract`
///     (delegates the raw HKDF-Extract construction to `_hkdfExtract`, which
///     in turn uses `package:crypto`'s [crypto.Hmac] for the HMAC
///     primitive -- see `crypto/internal/fips140/hkdf/hkdf.go:13-25`)
///   - `hkdf.Expand` (fips140/hkdf/hkdf.go:27-52) -> `_hkdfExpand`
///   - `tls13.deriveSecret` (fips140/tls13/tls13.go:49-54) -> `_deriveSecret`
///   - `tls13.EarlySecret`/`NewEarlySecret`/`ResumptionBinderKey`/
///     `ClientEarlyTrafficSecret`/`HandshakeSecret`/`EarlyExporterMasterSecret`
///     (tls13.go:68-101, 162-167) -> [EarlySecret]
///   - `tls13.HandshakeSecret`/`ClientHandshakeTrafficSecret`/
///     `ServerHandshakeTrafficSecret`/`MasterSecret` (tls13.go:90-126)
///     -> [HandshakeSecret]
///   - `tls13.MasterSecret`/`ClientApplicationTrafficSecret`/
///     `ServerApplicationTrafficSecret`/`ResumptionMasterSecret`/
///     `ExporterMasterSecret` (tls13.go:115-158) -> [MasterSecret]
///   - `tls13.ExporterMasterSecret`/`Exporter` (tls13.go:146-174)
///     -> [ExporterMasterSecret]
///   - `(*cipherSuiteTLS13).nextTrafficSecret` (tls/key_schedule.go:20-24)
///     -> `CipherSuiteTls13.nextTrafficSecret`
///   - `(*cipherSuiteTLS13).trafficKey` (tls/key_schedule.go:26-31)
///     -> `CipherSuiteTls13.trafficKey`
///   - `(*cipherSuiteTLS13).finishedHash` (tls/key_schedule.go:33-41)
///     -> `CipherSuiteTls13.finishedHash`
///   - `(*cipherSuiteTLS13).exportKeyingMaterial` (tls/key_schedule.go:43-50)
///     -> `CipherSuiteTls13.exportKeyingMaterial`
///   - `cipherSuiteTLS13` struct (tls/cipher_suites.go:196-201) ->
///     [CipherSuiteTls13]. Declared here rather than in `cipher_suites.dart`
///     (which owns it upstream) because its four key-schedule methods are
///     meaningless without the primitives above and Dart has no equivalent
///     of Go's "add methods to a struct from another file in the same
///     package"; `cipher_suites.dart` imports this class instead.
///   - Go's private `aead` interface (tls/cipher_suites.go:446-451)
///     -> [CipherSuiteTls13Aead], declared here for the same reason: it is
///     the type of `CipherSuiteTls13.aead`.
///
/// Deliberately not ported here (named gap, not silently degraded):
/// `generateECDHEKey`, `curveForCurveID`, `keySharePrivateKeys`,
/// `x25519PublicKeySize` (tls/key_schedule.go:52-84). They depend on the
/// `CurveID` enum declared in `common.go`, which is explicitly out of scope
/// for this pass, and they are ECDHE key-exchange plumbing consumed by
/// `handshake_client_tls13.go`/`handshake_server_tls13.go` (also out of
/// scope) -- not by the pure key-schedule foundation ported here.
library;

import 'dart:typed_data';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:crypto/crypto.dart' as crypto;

/// TLS 1.3 always uses a zero-length explicit nonce: the per-record nonce is
/// derived by XORing the record sequence number into the traffic IV (RFC
/// 8446, Section 5.3), unlike the pre-1.3 AEAD suites `aead` also serves in
/// Go. Mirrors `aeadNonceLength` (tls/cipher_suites.go:456), duplicated here
/// (rather than imported from `cipher_suites.dart`) to avoid a circular
/// import, since `cipher_suites.dart` imports this file for
/// [CipherSuiteTls13].
const int _aeadNonceLength = 12;

/// Port of Go's private `aead` interface (`tls/cipher_suites.go:446-451`):
/// the `cipher.AEAD` contract (`crypto/cipher`, out of this task's scope)
/// plus TLS's own `explicitNonceLen()`. Concrete TLS 1.3 implementations
/// (`aeadAESGCMTLS13`, `aeadChaCha20Poly1305`) are built in
/// `cipher_suites.dart`.
abstract interface class CipherSuiteTls13Aead {
  /// Port of `cipher.AEAD.NonceSize` as seen through `xorNonceAEAD.NonceSize`
  /// (`tls/cipher_suites.go:489`): always 8 (a 64-bit sequence number) for
  /// TLS 1.3.
  int get nonceSize;

  /// Port of `cipher.AEAD.Overhead` (`tls/cipher_suites.go:490`).
  int get overhead;

  /// Port of `aead.explicitNonceLen` (`tls/cipher_suites.go:491`): always 0
  /// for TLS 1.3.
  int get explicitNonceLen;

  /// Port of `cipher.AEAD.Seal` as wrapped by `xorNonceAEAD.Seal`
  /// (`tls/cipher_suites.go:493-501`).
  Uint8List seal(
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List additionalData,
  );

  /// Port of `cipher.AEAD.Open` as wrapped by `xorNonceAEAD.Open`
  /// (`tls/cipher_suites.go:505-514`).
  Uint8List open(
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List additionalData,
  );
}

/// Port of `cipherSuiteTLS13` (`tls/cipher_suites.go:196-201`) plus its four
/// key-schedule methods (`tls/key_schedule.go:20-50`). See the file-level
/// doc comment for why both live here.
final class CipherSuiteTls13 {
  /// Builds a suite descriptor from its four upstream fields.
  const CipherSuiteTls13({
    required this.id,
    required this.keyLen,
    required this.aead,
    required this.hash,
  });

  /// Port of `cipherSuiteTLS13.id` (`tls/cipher_suites.go:197`).
  final int id;

  /// Port of `cipherSuiteTLS13.keyLen` (`tls/cipher_suites.go:198`).
  final int keyLen;

  /// Port of `cipherSuiteTLS13.aead` (`tls/cipher_suites.go:199`).
  final CipherSuiteTls13Aead Function(Uint8List key, Uint8List fixedNonce) aead;

  /// Port of `cipherSuiteTLS13.hash` (`tls/cipher_suites.go:200`).
  final crypto.Hash hash;

  /// Port of `(*cipherSuiteTLS13).nextTrafficSecret`
  /// (`tls/key_schedule.go:20-24`).
  Uint8List nextTrafficSecret(Uint8List trafficSecret) => expandLabel(
    hash,
    trafficSecret,
    'traffic upd',
    Uint8List(0),
    _hashSize(hash),
  );

  /// Port of `(*cipherSuiteTLS13).trafficKey` (`tls/key_schedule.go:26-31`).
  /// Go returns the pair via named results `(key, iv []byte)`; a Dart record
  /// preserves that shape without resorting to a positional 2-tuple.
  ({Uint8List key, Uint8List iv}) trafficKey(Uint8List trafficSecret) {
    final key = expandLabel(hash, trafficSecret, 'key', Uint8List(0), keyLen);
    final iv = expandLabel(
      hash,
      trafficSecret,
      'iv',
      Uint8List(0),
      _aeadNonceLength,
    );
    return (key: key, iv: iv);
  }

  /// Port of `(*cipherSuiteTLS13).finishedHash` (`tls/key_schedule.go:33-41`).
  Uint8List finishedHash(Uint8List baseKey, HandshakeTranscript transcript) {
    final finishedKey = expandLabel(
      hash,
      baseKey,
      'finished',
      Uint8List(0),
      _hashSize(hash),
    );
    final verifyData = crypto.Hmac(hash, finishedKey).convert(transcript.sum());
    return Uint8List.fromList(verifyData.bytes);
  }

  /// Port of `(*cipherSuiteTLS13).exportKeyingMaterial`
  /// (`tls/key_schedule.go:43-50`). Go's closure returns `([]byte, error)`,
  /// but the error is always `nil` in this implementation (`Exporter` cannot
  /// fail) -- the tuple exists only to satisfy an unrelated exporter
  /// interface, so the Dart signature drops it rather than inventing a
  /// public `(Uint8List?, Exception?)` return the AGENTS.md contract vetoes.
  Uint8List Function(String label, Uint8List context, int length)
  exportKeyingMaterial(MasterSecret secret, HandshakeTranscript transcript) {
    final expMasterSecret = secret.exporterMasterSecret(transcript);
    return (label, context, length) =>
        expMasterSecret.exporter(label, context, length);
  }
}

/// Adapts Go's `hash.Hash` "write bytes, peek the digest without ending
/// accumulation" semantics, used throughout the TLS 1.3 key schedule for the
/// running handshake transcript hash (RFC 8446, Section 4.4.1).
/// `package:crypto` only exposes one-shot [crypto.Hash.convert]; peeking the
/// current digest without resetting is reproduced here by recomputing over
/// the buffered bytes on each [sum] call. This is behaviorally identical to
/// Go's incremental `Sum(nil)` (both read the digest of everything written
/// so far, without disturbing further writes) and costs nothing worth
/// avoiding at handshake-message sizes (at most a few KiB).
///
/// Not a 1:1 port of a named Go type -- Go passes the stdlib `hash.Hash`
/// interface directly, which has no distinct exported name to preserve.
final class HandshakeTranscript {
  /// Starts an empty transcript hashed with [hash].
  HandshakeTranscript(this.hash);

  /// The digest algorithm driving this transcript (`crypto.SHA256` or
  /// `crypto.SHA384` for every TLS 1.3 cipher suite).
  final crypto.Hash hash;

  final BytesBuilder _buffer = BytesBuilder(copy: false);

  /// Port of `hash.Hash.Write`: appends to the transcript without hashing.
  void write(List<int> data) => _buffer.add(data);

  /// Port of `hash.Hash.Sum(nil)`: the digest of everything written so far.
  Uint8List sum() => Uint8List.fromList(hash.convert(_buffer.toBytes()).bytes);
}

/// Port of `tls13.ExpandLabel` (`fips140/tls13/tls13.go:20-40`):
/// HKDF-Expand-Label from RFC 8446, Section 7.1.
Uint8List expandLabel(
  crypto.Hash hash,
  Uint8List secret,
  String label,
  Uint8List context,
  int length,
) {
  final tls13Label = 'tls13 $label';
  final labelBytes = _asciiBytes(tls13Label);
  if (labelBytes.length > 255 || context.length > 255) {
    // Go panics here rather than returning an error: labels are fixed
    // strings and context is always a fixed-length computed hash or a
    // field with the same 255-byte limitation, so this is asserted to be
    // unreachable rather than a recoverable protocol error.
    throw StateError('tls13: label or context too long');
  }
  final hkdfLabel = BytesBuilder(copy: false)
    ..add(_beUint16(length))
    ..addByte(labelBytes.length)
    ..add(labelBytes)
    ..addByte(context.length)
    ..add(context);
  return _hkdfExpand(hash, secret, hkdfLabel.toBytes(), length);
}

/// Port of `tls13.deriveSecret` (`fips140/tls13/tls13.go:49-54`). `transcript
/// == null` mirrors Go's `transcript == nil` branch (`transcript = hash()`):
/// the digest of an empty transcript.
Uint8List _deriveSecret(
  crypto.Hash hash,
  Uint8List secret,
  String label,
  HandshakeTranscript? transcript,
) {
  final t = transcript ?? HandshakeTranscript(hash);
  return expandLabel(hash, secret, label, t.sum(), _hashSize(hash));
}

/// Port of `tls13.extract` (`fips140/tls13/tls13.go:42-47`) composed with the
/// HKDF-Extract construction it delegates to
/// (`fips140/hkdf/hkdf.go:13-25`): `newSecret == null` mirrors Go's
/// `newSecret == nil` branch (zero bytes of hash size), and the HMAC
/// primitive itself comes from `package:crypto`'s [crypto.Hmac] rather than
/// being reimplemented.
Uint8List _hkdfExtract(
  crypto.Hash hash, {
  required Uint8List? newSecret,
  required Uint8List? currentSecret,
}) {
  final ikm = newSecret ?? Uint8List(_hashSize(hash));
  final salt = currentSecret ?? Uint8List(_hashSize(hash));
  return Uint8List.fromList(crypto.Hmac(hash, salt).convert(ikm).bytes);
}

/// Port of `hkdf.Expand` (`fips140/hkdf/hkdf.go:27-52`), RFC 5869's
/// HKDF-Expand, over `package:crypto`'s [crypto.Hmac] primitive.
Uint8List _hkdfExpand(
  crypto.Hash hash,
  Uint8List pseudorandomKey,
  List<int> info,
  int keyLen,
) {
  final out = BytesBuilder(copy: false);
  var counter = 0;
  var buf = const <int>[];
  while (out.length < keyLen) {
    counter += 1;
    if (counter > 255) {
      // Mirrors Go's `panic("hkdf: counter overflow")`: unreachable for any
      // TLS 1.3 key length (at most 48 bytes, one iteration).
      throw StateError('hkdf: counter overflow');
    }
    final block = BytesBuilder(copy: false)
      ..add(buf)
      ..add(info)
      ..addByte(counter);
    buf = crypto.Hmac(hash, pseudorandomKey).convert(block.toBytes()).bytes;
    final remain = keyLen - out.length;
    out.add(remain < buf.length ? buf.sublist(0, remain) : buf);
  }
  return out.toBytes();
}

int _hashSize(crypto.Hash hash) => hash.convert(const <int>[]).bytes.length;

Uint8List _asciiBytes(String s) => Uint8List.fromList(s.codeUnits);

/// Big-endian 16-bit length prefix, truncated modulo 2^16 like every Go
/// numeric conversion. `package:boilerplate`'s `Golang.Uint16` only exposes
/// little-endian bytes (`toLittleEndianBytes`); byte order is reversed here
/// rather than duplicating the modulo-2^16 truncation it already guarantees.
Uint8List _beUint16(int value) {
  final le = Golang.Uint16(value).toLittleEndianBytes();
  return Uint8List.fromList([le[1], le[0]]);
}

/// Port of `tls13.EarlySecret` and its methods
/// (`fips140/tls13/tls13.go:68-88, 162-167`). Only constructible via
/// [EarlySecret.new], mirroring Go's single exported constructor
/// `NewEarlySecret` -- there is no other way to obtain one upstream either.
final class EarlySecret {
  /// Port of `tls13.NewEarlySecret` (`fips140/tls13/tls13.go:73-78`).
  ///
  /// [psk] is nullable so Go's `NewEarlySecret(hash, nil)` stays expressible:
  /// `extract` replaces a nil secret with `hashSize` zero bytes, which is the
  /// no-PSK early secret of RFC 8446 Section 7.1. An *empty* list is a
  /// different input and yields a different, wrong secret.
  EarlySecret(crypto.Hash hash, Uint8List? psk)
    : _hash = hash,
      _secret = _hkdfExtract(hash, newSecret: psk, currentSecret: null);

  final crypto.Hash _hash;
  final Uint8List _secret;

  /// Port of `(*EarlySecret).ResumptionBinderKey`
  /// (`fips140/tls13/tls13.go:80-82`).
  Uint8List resumptionBinderKey() =>
      _deriveSecret(_hash, _secret, 'res binder', null);

  /// Port of `(*EarlySecret).ClientEarlyTrafficSecret`
  /// (`fips140/tls13/tls13.go:86-88`).
  Uint8List clientEarlyTrafficSecret(HandshakeTranscript transcript) =>
      _deriveSecret(_hash, _secret, 'c e traffic', transcript);

  /// Port of `(*EarlySecret).EarlyExporterMasterSecret`
  /// (`fips140/tls13/tls13.go:162-167`).
  ExporterMasterSecret earlyExporterMasterSecret(
    HandshakeTranscript transcript,
  ) => ExporterMasterSecret._(
    _deriveSecret(_hash, _secret, 'e exp master', transcript),
    _hash,
  );

  /// Port of `(*EarlySecret).HandshakeSecret` (`fips140/tls13/tls13.go:95-101`).
  HandshakeSecret handshakeSecret(Uint8List sharedSecret) {
    final derived = _deriveSecret(_hash, _secret, 'derived', null);
    return HandshakeSecret._(
      _hkdfExtract(_hash, newSecret: sharedSecret, currentSecret: derived),
      _hash,
    );
  }
}

/// Port of `tls13.HandshakeSecret` and its methods
/// (`fips140/tls13/tls13.go:90-113`). Only constructible via
/// [EarlySecret.handshakeSecret], mirroring the upstream API: Go exports no
/// constructor for this type either.
final class HandshakeSecret {
  HandshakeSecret._(this._secret, this._hash);

  final crypto.Hash _hash;
  final Uint8List _secret;

  /// Port of `(*HandshakeSecret).ClientHandshakeTrafficSecret`
  /// (`fips140/tls13/tls13.go:103-107`).
  Uint8List clientHandshakeTrafficSecret(HandshakeTranscript transcript) =>
      _deriveSecret(_hash, _secret, 'c hs traffic', transcript);

  /// Port of `(*HandshakeSecret).ServerHandshakeTrafficSecret`
  /// (`fips140/tls13/tls13.go:109-113`).
  Uint8List serverHandshakeTrafficSecret(HandshakeTranscript transcript) =>
      _deriveSecret(_hash, _secret, 's hs traffic', transcript);

  /// Port of `(*HandshakeSecret).MasterSecret` (`fips140/tls13/tls13.go:120-126`).
  MasterSecret masterSecret() {
    final derived = _deriveSecret(_hash, _secret, 'derived', null);
    return MasterSecret._(
      _hkdfExtract(_hash, newSecret: null, currentSecret: derived),
      _hash,
    );
  }
}

/// Port of `tls13.MasterSecret` and its methods
/// (`fips140/tls13/tls13.go:115-158`). Only constructible via
/// [HandshakeSecret.masterSecret].
final class MasterSecret {
  MasterSecret._(this._secret, this._hash);

  final crypto.Hash _hash;
  final Uint8List _secret;

  /// Port of `(*MasterSecret).ClientApplicationTrafficSecret`
  /// (`fips140/tls13/tls13.go:128-132`).
  Uint8List clientApplicationTrafficSecret(HandshakeTranscript transcript) =>
      _deriveSecret(_hash, _secret, 'c ap traffic', transcript);

  /// Port of `(*MasterSecret).ServerApplicationTrafficSecret`
  /// (`fips140/tls13/tls13.go:134-138`).
  Uint8List serverApplicationTrafficSecret(HandshakeTranscript transcript) =>
      _deriveSecret(_hash, _secret, 's ap traffic', transcript);

  /// Port of `(*MasterSecret).ResumptionMasterSecret`
  /// (`fips140/tls13/tls13.go:140-144`).
  Uint8List resumptionMasterSecret(HandshakeTranscript transcript) =>
      _deriveSecret(_hash, _secret, 'res master', transcript);

  /// Port of `(*MasterSecret).ExporterMasterSecret`
  /// (`fips140/tls13/tls13.go:151-158`).
  ExporterMasterSecret exporterMasterSecret(HandshakeTranscript transcript) =>
      ExporterMasterSecret._(
        _deriveSecret(_hash, _secret, 'exp master', transcript),
        _hash,
      );
}

/// Port of `tls13.ExporterMasterSecret` and its methods
/// (`fips140/tls13/tls13.go:146-178`, including the `TestingOnlyExporterSecret`
/// test accessor used by `key_schedule_test.go`'s `TestACVPVectors`). Only
/// constructible via [MasterSecret.exporterMasterSecret] or
/// [EarlySecret.earlyExporterMasterSecret].
final class ExporterMasterSecret {
  ExporterMasterSecret._(this._secret, this._hash);

  final crypto.Hash _hash;
  final Uint8List _secret;

  /// Port of `(*ExporterMasterSecret).Exporter` (`fips140/tls13/tls13.go:169-174`).
  Uint8List exporter(String label, Uint8List context, int length) {
    final secret = _deriveSecret(_hash, _secret, label, null);
    final h = HandshakeTranscript(_hash)..write(context);
    return expandLabel(_hash, secret, 'exporter', h.sum(), length);
  }

  /// Port of `TestingOnlyExporterSecret` (`fips140/tls13/tls13.go:176-178`):
  /// the ACVP test vectors (`key_schedule_test.go`'s `TestACVPVectors`)
  /// compare the raw exporter secret directly, bypassing `Exporter`'s label
  /// expansion. Exposed here under the same "testing only" contract so the
  /// atomic test can reproduce that vector without extra scaffolding in
  /// `lib/`.
  Uint8List testingOnlyExporterSecret() => _secret;
}
