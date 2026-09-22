// Port of go-libp2p's `p2p/transport/webtransport/crypto.go`: the
// deterministic, short-lived certificate a WebTransport listener presents,
// and the checks a dialler runs against the one it is shown.
//
// A WebTransport peer is not authenticated by a CA chain -- a browser dials
// pinning the leaf by its SHA-256, through `serverCertificateHashes` -- so the
// W3C specification caps how long such a certificate may be valid, and
// go-libp2p enforces that cap on both sides. That cap is the whole reason
// this certificate cannot be the libp2p identity certificate, which is
// deliberately valid for a century: a Go peer refuses it outright with
// "cert must not be valid for longer than 14 days".
//
// Making the certificate *deterministic* in the host key and the validity
// window is what lets a node restart without changing the `/certhash/` it
// publishes, and without persisting anything.
//
// Following upstream's own lead (`crypto.go:155-159`), this machinery is kept
// self-contained rather than shared with the libp2p identity certificate in
// `p2p/security/tls/crypto.dart`: the two are independent on the wire and in
// their browser behaviour, and may diverge.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto_pkg;
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart' as pc;

import '../../../core/crypto/ecdsa_key.dart';
import '../../../core/crypto/key_types.dart';

/// The HKDF `info` string every deterministic value is derived under.
///
/// The misspelling is upstream's, at `crypto.go:28`, and is load-bearing: it
/// is the literal byte string fed to HKDF, so correcting it would change
/// every certificate a node has ever advertised.
const String _deterministicCertInfo = 'determinisitic cert';

/// The longest a *peer's* WebTransport certificate may be valid for, per the
/// check in `verifyRawCerts` (`crypto.go:139`). Upstream writes it as a
/// literal there rather than reusing its `certValidity` constant, and it stays
/// separate here for the same reason: how long a certificate this side will
/// accept is not the same statement as how long this side issues its own for.
const Duration _maxPeerCertValidity = Duration(days: 14);

/// NIST P-256 domain parameters -- the only curve go-libp2p generates
/// WebTransport certificates on (`crypto.go:80`).
final pc.ECDomainParameters _p256 = pc.ECCurve_secp256r1();

const List<int> _ecdsaWithSha256Oid = [1, 2, 840, 10045, 4, 3, 2];
const List<int> _keyUsageOid = [2, 5, 29, 15];
const List<int> _basicConstraintsOid = [2, 5, 29, 19];
const List<int> _extKeyUsageOid = [2, 5, 29, 37];
const List<int> _serverAuthOid = [1, 3, 6, 1, 5, 5, 7, 3, 1];
const List<int> _clientAuthOid = [1, 3, 6, 1, 5, 5, 7, 3, 2];

/// The PKCS#1 signature algorithm OIDs identifying an RSA certificate,
/// matching the `switch` in `verifyRawCerts` (`crypto.go:133-136`): md2, md5,
/// sha1, sha256, sha384 and sha512 with RSA encryption.
const List<List<int>> _rsaSignatureOids = [
  [1, 2, 840, 113549, 1, 1, 2],
  [1, 2, 840, 113549, 1, 1, 4],
  [1, 2, 840, 113549, 1, 1, 5],
  [1, 2, 840, 113549, 1, 1, 11],
  [1, 2, 840, 113549, 1, 1, 12],
  [1, 2, 840, 113549, 1, 1, 13],
];

/// Thrown when none of the `/certhash/` digests a multiaddr pins matches the
/// certificate the peer actually presented.
///
/// Go: `ErrCertHashMismatch` (`crypto.go:98-104`), renamed for Dart's
/// exception idiom as the audit's exception-naming rule requires.
class CertHashMismatchException implements Exception {
  /// Creates a [CertHashMismatchException].
  const CertHashMismatchException({
    required this.expected,
    required this.actual,
  });

  /// The SHA-256 of the leaf certificate the peer presented.
  final Uint8List expected;

  /// The digests the multiaddr pinned, any one of which would have matched.
  final List<Uint8List> actual;

  @override
  String toString() =>
      'CertHashMismatchException: cert hash not found: ${_hex(expected)} '
      '(expected: ${actual.map(_hex).join(', ')})';

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// A WebTransport certificate and the signer that proves possession of it.
///
/// Go returns `(*x509.Certificate, *ecdsa.PrivateKey)` from `generateCert`
/// and wraps both in a `tls.Config` (`getTLSConf`, `crypto.go:31-42`). This
/// port carries the DER and a signing closure instead: the DER is what both
/// callers need -- the TLS handshake sends it and the `/certhash/` hashes it
/// -- and the closure is exactly the shape the QUIC server takes, so no
/// pointycastle key type reaches a public signature.
class WebtransportCertificate {
  /// Creates a [WebtransportCertificate].
  const WebtransportCertificate({
    required this.certificateDer,
    required this.sign,
    required this.notBefore,
    required this.notAfter,
  });

  /// The DER encoding of the self-signed leaf certificate.
  final Uint8List certificateDer;

  /// Signs a TLS handshake transcript with the key this certificate attests.
  final Future<Uint8List> Function(Uint8List message) sign;

  /// When the certificate becomes valid.
  final DateTime notBefore;

  /// When the certificate stops being valid.
  final DateTime notAfter;

  /// The SHA-256 of [certificateDer], which is what a `/certhash/` pins.
  Uint8List get sha256 =>
      Uint8List.fromList(crypto_pkg.sha256.convert(certificateDer).bytes);
}

/// Generates the certificate a WebTransport listener presents, valid from
/// [start] to [end] and derived deterministically from [key] and [start].
///
/// Go: `generateCert` (`crypto.go:48-96`). Every value comes off one
/// HKDF-SHA256 stream keyed by the host private key, salted with [start] as
/// little-endian Unix nanoseconds and labelled [_deterministicCertInfo]: the
/// serial first (8 bytes, big-endian unsigned, floored at 1 so it is never
/// the zero RFC 5280 section 4.1.2.2 forbids), then 192 bits of seed for the
/// P-256 key.
///
/// Three deliberate divergences, none of them observable by a peer:
///
/// * Go turns the 192-bit seed into a key with `filippo.io/keygen`, a module
///   that is **not** part of the pinned upstream tree, so its exact byte
///   derivation cannot be read, let alone reproduced. This port expands the
///   same seed with HKDF-SHA256 and rejection-samples a scalar in `[1, n)`,
///   which is the "key pair generation by testing candidates" of
///   FIPS 186-5 A.2.1 that `keygen` documents itself as following.
/// * Go gets a deterministic signature by handing `ecdsa.Sign` a nil random
///   source (`deterministicSigner`, `crypto.go:161-175`); this port uses
///   RFC 6979, the standard construction for the same property.
/// * The ASN.1 encoding follows RFC 5280 directly rather than `crypto/x509`,
///   which is outside the sparse `go-stdlib` checkout (see
///   `doc/transpilation/UPSTREAM_LOCK.md`). The template being encoded is
///   upstream's, field for field (`crypto.go:66-75`).
///
/// Nothing on the wire compares these bytes against a Go implementation's: a
/// peer checks the certificate against the `/certhash/` that *this* node
/// published, so the derivation is never cross-checked. What has to hold, and
/// does, is the observable property -- the same host key and the same window
/// give the same certificate, so a restart keeps a `/certhash/` a peer may
/// already have cached.
Future<WebtransportCertificate> generateCert(
  PrivKey key,
  DateTime start,
  DateTime end,
) async {
  final reader = _DeterministicReader(
    seed: key.raw(),
    salt: _startTimeSalt(start),
    info: _deterministicCertInfo,
  );

  var serial = BigInt.zero;
  for (final b in reader.read(8)) {
    serial = (serial << 8) | BigInt.from(b);
  }
  if (serial == BigInt.zero) serial = BigInt.one;

  // 192 bits of entropy, as P-256 requires (`crypto.go:77`).
  final certKey = _ecdsaFromSeed(reader.read(192 ~/ 8));
  final spki = EcdsaPrivateKey.fromPointyCastle(certKey).getPublic().raw();

  final tbs = ASN1Sequence(
    elements: [
      ASN1Object(tag: 0xA0)..valueBytes = ASN1Integer(BigInt.two).encode(),
      ASN1Integer(serial),
      _ecdsaWithSha256AlgorithmIdentifier(),
      // `pkix.Name{}` is an empty RDNSequence, unlike the libp2p identity
      // certificate's, which carries a serial-number RDN.
      ASN1Sequence(elements: []), // issuer == subject: self-signed
      ASN1Sequence(elements: [_encodeAsn1Time(start), _encodeAsn1Time(end)]),
      ASN1Sequence(elements: []),
      ASN1Object.fromBytes(spki),
      ASN1Object(tag: 0xA3)
        ..valueBytes = ASN1Sequence(elements: _certExtensions()).encode(),
    ],
  );
  final tbsDer = tbs.encode();

  final certDer = ASN1Sequence(
    elements: [
      ASN1Object.fromBytes(tbsDer),
      _ecdsaWithSha256AlgorithmIdentifier(),
      ASN1BitString(stringValues: _signDeterministically(certKey, tbsDer))
        ..unusedbits = 0,
    ],
  ).encode();

  return WebtransportCertificate(
    certificateDer: certDer,
    sign: (message) async => _signDeterministically(certKey, message),
    notBefore: start,
    notAfter: end,
  );
}

/// Checks the certificate chain [rawCerts] a WebTransport peer presented
/// against the `/certhash/` digests [certHashes] taken from its multiaddr.
///
/// Go: `verifyRawCerts` (`crypto.go:107-146`), with all four of its checks --
/// the leaf hashes to a pinned digest; the certificate is not RSA; it is valid
/// for no more than fourteen days; and it is valid *now*. Each throws rather
/// than returning an error, per this project's error convention.
///
/// [certHashes] holds raw SHA-256 digests, not multihash envelopes: the W3C
/// WebTransport specification allows only SHA-256 for
/// `serverCertificateHashes`, which is why Go filters on
/// `h.Code == multihash.SHA2_256` (`crypto.go:117`).
///
/// [now] exists so the time-window check can be exercised by a test; Go reads
/// the clock directly at `crypto.go:142`.
void verifyRawCerts(
  List<Uint8List> rawCerts,
  List<Uint8List> certHashes, {
  DateTime? now,
}) {
  if (rawCerts.isEmpty) throw const FormatException('no cert');
  final leaf = rawCerts.last;
  final hash = Uint8List.fromList(crypto_pkg.sha256.convert(leaf).bytes);

  if (!certHashes.any((candidate) => _intsEqual(candidate, hash))) {
    throw CertHashMismatchException(expected: hash, actual: certHashes);
  }

  final parsed = _parseCertificate(leaf);
  if (_rsaSignatureOids.any(
    (oid) => _intsEqual(parsed.signatureAlgorithm, oid),
  )) {
    throw const FormatException('cert uses RSA');
  }

  final validity = parsed.notAfter.difference(parsed.notBefore);
  if (validity > _maxPeerCertValidity) {
    throw FormatException(
      'cert must not be valid for longer than 14 days '
      '(NotBefore: ${parsed.notBefore}, NotAfter: ${parsed.notAfter}, '
      'Length: $validity)',
    );
  }

  final at = (now ?? DateTime.now()).toUtc();
  if (at.isBefore(parsed.notBefore) || at.isAfter(parsed.notAfter)) {
    throw FormatException(
      'cert not valid (NotBefore: ${parsed.notBefore}, '
      'NotAfter: ${parsed.notAfter})',
    );
  }
}

/// `binary.LittleEndian.PutUint64(startTimeSalt, uint64(start.UnixNano()))`
/// (`crypto.go:54-56`).
Uint8List _startTimeSalt(DateTime start) {
  var value =
      (BigInt.from(start.toUtc().microsecondsSinceEpoch) * BigInt.from(1000))
          .toUnsigned(64);
  final salt = Uint8List(8);
  for (var i = 0; i < 8; i++) {
    salt[i] = (value & BigInt.from(0xff)).toInt();
    value >>= 8;
  }
  return salt;
}

/// The extensions of upstream's `certTempl` (`crypto.go:66-75`), encoded per
/// RFC 5280: `keyUsage` (critical), `extKeyUsage`, and `basicConstraints`
/// (critical, because `BasicConstraintsValid` is set alongside `IsCA`).
List<ASN1Object> _certExtensions() => [
  _extension(
    _keyUsageOid,
    critical: true,
    // digitalSignature is bit 0 and keyCertSign is bit 5
    // (RFC 5280 s. 4.2.1.3), numbered from the most significant bit, so the
    // two together are 0x84 with the low two bits unused.
    value: (ASN1BitString(stringValues: [0x84])..unusedbits = 2).encode(),
  ),
  _extension(
    _extKeyUsageOid,
    critical: false,
    // Upstream lists clientAuth before serverAuth (`crypto.go:71`).
    value: ASN1Sequence(
      elements: [
        ASN1ObjectIdentifier(_clientAuthOid),
        ASN1ObjectIdentifier(_serverAuthOid),
      ],
    ).encode(),
  ),
  _extension(
    _basicConstraintsOid,
    critical: true,
    value: ASN1Sequence(elements: [ASN1Boolean(true)]).encode(),
  ),
];

/// `Extension ::= SEQUENCE { extnID, critical BOOLEAN DEFAULT FALSE,
/// extnValue OCTET STRING }`. DER omits `critical` when false, per its
/// encoding rule for DEFAULT.
ASN1Sequence _extension(
  List<int> oid, {
  required bool critical,
  required Uint8List value,
}) => ASN1Sequence(
  elements: [
    ASN1ObjectIdentifier(oid),
    if (critical) ASN1Boolean(true),
    ASN1OctetString(octets: value),
  ],
);

/// `AlgorithmIdentifier` for ecdsa-with-SHA256, parameters absent (RFC 5758).
ASN1Sequence _ecdsaWithSha256AlgorithmIdentifier() =>
    ASN1Sequence(elements: [ASN1ObjectIdentifier(_ecdsaWithSha256Oid)]);

/// Encodes [dt] as `UTCTime` (years 1950-2049) or `GeneralizedTime`
/// otherwise, per RFC 5280's `Time` choice.
///
/// The `GeneralizedTime` branch is hand-rolled for the same reason the
/// identity certificate's is: pointycastle's `ASN1GeneralizedTime` does not
/// zero-pad single-digit fields, producing malformed DER.
ASN1Object _encodeAsn1Time(DateTime dt) {
  final utc = dt.toUtc();
  if (utc.year >= 1950 && utc.year <= 2049) return ASN1UtcTime(utc);
  String pad2(int v) => v.toString().padLeft(2, '0');
  final value =
      '${utc.year.toString().padLeft(4, '0')}${pad2(utc.month)}'
      '${pad2(utc.day)}${pad2(utc.hour)}${pad2(utc.minute)}'
      '${pad2(utc.second)}Z';
  return ASN1Object(tag: 0x18)
    ..valueBytes = Uint8List.fromList(ascii.encode(value));
}

/// Derives a P-256 private key from [seed] by testing candidates until one
/// falls in `[1, n)`, per FIPS 186-5 A.2.1. See [generateCert] for why this
/// stands in for `filippo.io/keygen`.
pc.ECPrivateKey _ecdsaFromSeed(Uint8List seed) {
  final reader = _DeterministicReader(
    seed: seed,
    salt: Uint8List(0),
    info: 'p256 candidate',
  );
  final n = _p256.n;
  while (true) {
    var d = BigInt.zero;
    for (final b in reader.read(32)) {
      d = (d << 8) | BigInt.from(b);
    }
    if (d == BigInt.zero || d >= n) continue;
    return pc.ECPrivateKey(d, _p256);
  }
}

/// Signs [message] with a nonce derived from the key and the message
/// (RFC 6979) rather than from a random source, so the certificate -- its
/// signature included -- is a function of the host key and the validity
/// window alone.
Uint8List _signDeterministically(pc.ECPrivateKey key, Uint8List message) {
  final digest = Uint8List.fromList(crypto_pkg.sha256.convert(message).bytes);
  final signer = pc.ECDSASigner(null, pc.HMac(pc.SHA256Digest(), 64))
    ..init(true, pc.PrivateKeyParameter<pc.ECPrivateKey>(key));
  final sig = signer.generateSignature(digest) as pc.ECSignature;
  // Low-S normalisation: both halves of a signature verify, so pinning the
  // canonical one keeps the encoding a function of the inputs alone.
  final n = _p256.n;
  final s = sig.s.compareTo(n >> 1) > 0 ? n - sig.s : sig.s;
  return ASN1Sequence(elements: [ASN1Integer(sig.r), ASN1Integer(s)]).encode();
}

/// An endless HKDF-SHA256 (RFC 5869) output stream.
///
/// Go: `newDeterministicReader` (`crypto.go:148-150`), which is
/// `hkdf.New(sha256.New, seed, salt, info)` -- an `io.Reader` callers read
/// from repeatedly, each read continuing where the last one stopped.
class _DeterministicReader {
  _DeterministicReader({
    required Uint8List seed,
    required Uint8List salt,
    required String info,
  }) : _info = Uint8List.fromList(ascii.encode(info)),
       _prk = _extract(salt, seed);

  /// HKDF-Extract: `PRK = HMAC-Hash(salt, IKM)`, with an all-zero salt of
  /// hash length when none is given (RFC 5869 s. 2.2).
  static Uint8List _extract(Uint8List salt, Uint8List ikm) =>
      Uint8List.fromList(
        crypto_pkg.Hmac(
          crypto_pkg.sha256,
          salt.isEmpty ? Uint8List(32) : salt,
        ).convert(ikm).bytes,
      );

  final Uint8List _prk;
  final Uint8List _info;
  Uint8List _block = Uint8List(0);
  final List<int> _buffered = [];
  int _counter = 0;

  /// The next [length] bytes of the stream.
  Uint8List read(int length) {
    while (_buffered.length < length) {
      _counter++;
      _block = Uint8List.fromList(
        crypto_pkg.Hmac(
          crypto_pkg.sha256,
          _prk,
        ).convert([..._block, ..._info, _counter]).bytes,
      );
      _buffered.addAll(_block);
    }
    final out = Uint8List.fromList(_buffered.sublist(0, length));
    _buffered.removeRange(0, length);
    return out;
  }
}

/// The fields of a parsed certificate that [verifyRawCerts] checks.
class _ParsedCertificate {
  const _ParsedCertificate({
    required this.signatureAlgorithm,
    required this.notBefore,
    required this.notAfter,
  });

  final List<int> signatureAlgorithm;
  final DateTime notBefore;
  final DateTime notAfter;
}

/// Reads the signature algorithm and the validity window out of a DER
/// certificate, which is all [verifyRawCerts] needs.
_ParsedCertificate _parseCertificate(Uint8List der) {
  final cert = ASN1Parser(der).nextObject() as ASN1Sequence;
  final tbs = cert.elements![0] as ASN1Sequence;
  final algorithm =
      (cert.elements![1] as ASN1Sequence).elements![0] as ASN1ObjectIdentifier;

  // `[0] EXPLICIT Version` is optional -- absent means v1 -- so the validity
  // SEQUENCE sits one place further along when it is present.
  final hasVersion = tbs.elements![0].tag == 0xA0;
  final validity = tbs.elements![hasVersion ? 4 : 3] as ASN1Sequence;

  return _ParsedCertificate(
    signatureAlgorithm: _oidComponents(algorithm),
    notBefore: _decodeAsn1Time(validity.elements![0]),
    notAfter: _decodeAsn1Time(validity.elements![1]),
  );
}

/// [ASN1ObjectIdentifier.objectIdentifier] as a proper `List<int>`.
///
/// pointycastle's own field is a `Uint8List`, which silently truncates any
/// OID arc above 255 to its low byte; its string form does not share that
/// bug, so the component list is rebuilt from the string.
List<int> _oidComponents(ASN1ObjectIdentifier oid) =>
    oid.objectIdentifierAsString!.split('.').map(int.parse).toList();

/// Decodes a `Validity` element (`UTCTime` or `GeneralizedTime`).
///
/// Does not use [ASN1UtcTime.time]: pointycastle applies RFC 5280's century
/// rule as `YY > 75` instead of `YY >= 50`.
DateTime _decodeAsn1Time(ASN1Object element) {
  if (element is ASN1GeneralizedTime) return element.dateTimeValue!.toUtc();
  final text = ascii.decode(element.valueBytes!);
  final yy = int.parse(text.substring(0, 2));
  return DateTime.utc(
    yy >= 50 ? 1900 + yy : 2000 + yy,
    int.parse(text.substring(2, 4)),
    int.parse(text.substring(4, 6)),
    int.parse(text.substring(6, 8)),
    int.parse(text.substring(8, 10)),
    int.parse(text.substring(10, 12)),
  );
}

bool _intsEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
