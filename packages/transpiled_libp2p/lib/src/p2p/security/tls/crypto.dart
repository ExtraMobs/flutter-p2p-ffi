// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/p2p/security/tls/crypto.dart
//
// Port of go-libp2p's p2p/security/tls/crypto.go's *certificate* layer:
// the ephemeral, self-signed X.509 certificate that cryptographically ties
// a TLS connection to a libp2p identity key (`keyToCertificate`,
// `GenerateSignedExtension`, `certTemplate`), and the reverse verification
// that recovers the identity key from a peer's certificate chain
// (`PubKeyFromCertChain`).
//
// Out of scope, per the task that produced this file: the handshake/socket
// layer (`Identity`, `IdentityConfig`, `IdentityOption`, `NewIdentity`,
// `Identity.ConfigForPeer`, `tls.Config`) -- another workstream owns TLS
// 1.3 handshake wiring, and QUIC (Marco G.1) is expected to authenticate
// with this exact same certificate later. Because `NewIdentity`/`Identity`
// (the sole Go callers of `keyToCertificate`) are out of scope,
// `keyToCertificate` -- unexported in Go -- is promoted to public here as
// this port's certificate-issuing entry point; `certTemplate` stays
// private since nothing outside this file needs it (go-libp2p's
// `WithCertTemplate`/`IdentityConfig` customization hook is also out of
// scope, so this always uses the default template, matching
// `NewIdentity`'s behavior when no `IdentityOption` is passed).
//
// Per the libp2p-tls spec (and confirmed by crypto.go itself: `cert.Verify`
// is called with `InsecureSkipVerify: true` and a comment "This is not
// insecure here. We will verify the cert chain ourselves."), the
// certificate's own X.509 signature is never cryptographically checked by
// either side -- trust flows entirely through the embedded libp2p
// extension's signature, over the certificate's SubjectPublicKeyInfo, made
// with the libp2p identity key. `pubKeyFromCertChain` mirrors exactly what
// `cert.Verify(x509.VerifyOptions{Roots: pool})` actually validates when
// `pool` contains only the certificate itself (a self-signed leaf that is
// also its own trusted root): the validity period and the absence of
// unrecognized critical extensions -- see `crypto/x509/verify.go`'s
// `Certificate.Verify` (`opts.Roots.contains(c)` short-circuit) -- plus the
// libp2p extension's own signature, which is the actual authentication.
import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';

import '../../../core/crypto/ecdsa_key.dart';
import '../../../core/crypto/key_codec.dart';
import '../../../core/crypto/key_types.dart';
import 'extension.dart';

/// ~100 years, per go-libp2p's `certValidityPeriod` (crypto.go:25).
const Duration _certValidityPeriod = Duration(days: 100 * 365);

/// Prepended to a certificate's SubjectPublicKeyInfo before signing (or
/// verifying) with the libp2p identity key, per go-libp2p's
/// `certificatePrefix` (crypto.go:26).
const String _certificatePrefix = 'libp2p-tls-handshake:';

/// The libp2p TLS certificate extension's OID (`1.3.6.1.4.1.53594.1.1`),
/// per go-libp2p's `extensionID = getPrefixedExtensionID([]int{1, 1})`
/// (crypto.go:29).
final List<int> extensionId = getPrefixedExtensionId(const [1, 1]);

/// Whether the libp2p extension is marked critical. go-libp2p's
/// `extensionCritical` (crypto.go:30) is a mutable package var flipped to
/// `true` only by its own test suite ("so we can mark the extension
/// critical in tests"); production go-libp2p always leaves it `false`, and
/// that test-only toggle is out of scope here.
const bool _extensionCritical = false;

/// PKIX `id-at-serialNumber` (2.5.4.5), used for the certificate
/// Subject/Issuer `Name`'s single RDN, per go-libp2p's `certTemplate`
/// (crypto.go:284, `pkix.Name{SerialNumber: ...}`).
const List<int> _idAtSerialNumberOid = [2, 5, 4, 5];

/// `ecdsa-with-SHA256` (1.2.840.10045.4.3.2, RFC 5758), the signature
/// algorithm `x509.CreateCertificate` selects by default for a P-256
/// signing key -- the only kind `keyToCertificate` ever generates.
const List<int> _ecdsaWithSha256Oid = [1, 2, 840, 10045, 4, 3, 2];

/// `signedKey`, an ASN.1 `SEQUENCE { PubKey OCTET STRING, Signature OCTET
/// STRING }` carried as the libp2p extension's value, per go-libp2p's
/// unexported `signedKey` struct (crypto.go:32-35).
class _SignedKey {
  _SignedKey({required this.pubKey, required this.signature});

  factory _SignedKey.decode(Uint8List der) {
    final seq = ASN1Sequence.fromBytes(der);
    final elements = seq.elements;
    if (elements == null || elements.length < 2) {
      throw const FormatException('malformed signedKey sequence');
    }
    return _SignedKey(
      pubKey: (elements[0] as ASN1OctetString).octets!,
      signature: (elements[1] as ASN1OctetString).octets!,
    );
  }

  final Uint8List pubKey;
  final Uint8List signature;

  Uint8List encode() => ASN1Sequence(
    elements: [
      ASN1OctetString(octets: pubKey),
      ASN1OctetString(octets: signature),
    ],
  ).encode();
}

/// Uses the provided libp2p identity private key [sk] to sign
/// [certPublicKeySpkiDer] -- the DER `SubjectPublicKeyInfo` of a TLS
/// certificate's (ephemeral) public key -- and returns the resulting
/// libp2p certificate extension as `(id, critical, value)`, per
/// go-libp2p's `GenerateSignedExtension` (crypto.go:212-237).
///
/// Diverges from Go by taking the already-DER-encoded SPKI bytes rather
/// than a generic `crypto.PublicKey`: this port's only caller
/// ([keyToCertificate]) always generates an ECDSA P-256 certificate key,
/// and [EcdsaPublicKey.raw] already produces exactly that DER (matching
/// `x509.MarshalPKIXPublicKey`), so there's no generic public-key
/// abstraction to preserve here. Returns a record instead of a `pkix.
/// Extension` (a foreign, `crypto/x509/pkix` stdlib type with no
/// go-libp2p-owned Dart counterpart to promote to public API).
Future<({List<int> id, bool critical, Uint8List value})> generateSignedExtension(
  PrivKey sk,
  Uint8List certPublicKeySpkiDer,
) async {
  final keyBytes = marshalPublicKey(sk.getPublic());
  final signature = await sk.sign(
    Uint8List.fromList([...utf8.encode(_certificatePrefix), ...certPublicKeySpkiDer]),
  );
  final value = _SignedKey(pubKey: keyBytes, signature: signature).encode();
  return (id: extensionId, critical: _extensionCritical, value: value);
}

/// Generates a new ephemeral ECDSA (NIST P-256) key pair and a
/// corresponding self-signed X.509 certificate carrying the libp2p
/// extension that cryptographically ties it to [sk], per go-libp2p's
/// `keyToCertificate` (crypto.go:242-263) -- promoted to public here; see
/// the file-level doc comment for why.
///
/// Always uses the default certificate template (go-libp2p's
/// `certTemplate`, crypto.go:266-286): a random serial number and
/// Subject/Issuer serial number (each uniform in `[0, 2^62)`), validity
/// from one hour ago through ~100 years from now, and an otherwise-empty
/// Subject/Issuer name. go-libp2p's `WithCertTemplate` customization hook
/// exists solely to serve `NewIdentity`'s config API, which is out of
/// scope here.
Future<({Uint8List certificateDer, EcdsaPrivateKey privateKey})> keyToCertificate(PrivKey sk) async {
  final certKey = generateEcdsaKeyPair();
  final certPublicKeySpki = certKey.getPublic().raw();

  final ext = await generateSignedExtension(sk, certPublicKeySpki);
  final extensionSeq = ASN1Sequence(
    elements: [ASN1ObjectIdentifier(ext.id), ASN1OctetString(octets: ext.value)],
  );

  final tmpl = _certTemplate();

  final tbs = ASN1Sequence(
    elements: [
      ASN1Object(tag: 0xA0)..valueBytes = ASN1Integer(BigInt.two).encode(), // version v3
      ASN1Integer(tmpl.serialNumber),
      _ecdsaWithSha256AlgorithmIdentifier(),
      _buildName(tmpl.subjectSerialNumber), // issuer == subject: self-signed
      ASN1Sequence(
        elements: [_encodeAsn1Time(tmpl.notBefore), _encodeAsn1Time(tmpl.notAfter)],
      ),
      _buildName(tmpl.subjectSerialNumber), // subject
      ASN1Object.fromBytes(certPublicKeySpki),
      ASN1Object(tag: 0xA3)..valueBytes = ASN1Sequence(elements: [extensionSeq]).encode(),
    ],
  );
  final tbsDer = tbs.encode();
  final signature = await certKey.sign(tbsDer);

  final certDer = ASN1Sequence(
    elements: [
      ASN1Object.fromBytes(tbsDer),
      _ecdsaWithSha256AlgorithmIdentifier(),
      ASN1BitString(stringValues: signature)..unusedbits = 0,
    ],
  ).encode();

  return (certificateDer: certDer, privateKey: certKey);
}

/// Verifies a peer's certificate [chain] and extracts the peer's libp2p
/// public key, per go-libp2p's `PubKeyFromCertChain` (crypto.go:156-210).
///
/// [chain] holds raw DER-encoded X.509 certificates (Go's equivalent
/// takes already-`x509.ParseCertificate`d values; this port has no
/// standalone generic X.509 parser package to depend on, so it parses the
/// single element it requires internally).
///
/// Throws [FormatException] -- never returns null --
/// on any of: a chain that isn't exactly one certificate, a missing or
/// malformed libp2p extension, a certificate outside its validity period,
/// an unrecognized critical extension, or an invalid extension signature.
Future<PubKey> pubKeyFromCertChain(List<Uint8List> chain) async {
  if (chain.length != 1) {
    throw const FormatException('expected one certificates in the chain');
  }

  final certSeq = ASN1Sequence.fromBytes(chain[0]);
  final certElements = certSeq.elements!;
  if (certElements.isEmpty) {
    throw const FormatException('malformed X.509 certificate');
  }
  final tbsElements = (certElements[0] as ASN1Sequence).elements!;

  var idx = 0;
  if (tbsElements.isNotEmpty && tbsElements[0].tag == 0xA0) {
    idx = 1; // explicit [0] version present (always true for certs with extensions)
  }
  if (tbsElements.length < idx + 6) {
    throw const FormatException('malformed X.509 certificate');
  }
  final validityElements = (tbsElements[idx + 3] as ASN1Sequence).elements!;
  final subjectPublicKeyInfoElement = tbsElements[idx + 5];

  ASN1Sequence? extensionsSeq;
  for (var i = idx + 6; i < tbsElements.length; i++) {
    if (tbsElements[i].tag == 0xA3) {
      extensionsSeq = ASN1Sequence.fromBytes(tbsElements[i].valueBytes!);
      break;
    }
  }

  ASN1Sequence? keyExt;
  var hasUnrecognizedCriticalExtension = false;
  if (extensionsSeq != null) {
    for (final extObj in extensionsSeq.elements!) {
      final extSeq = extObj as ASN1Sequence;
      final oid = _oidComponents(extSeq.elements![0] as ASN1ObjectIdentifier);
      if (extensionIdEqual(oid, extensionId)) {
        keyExt = extSeq;
      } else if (_isExtensionCritical(extSeq)) {
        hasUnrecognizedCriticalExtension = true;
      }
    }
  }
  if (keyExt == null) {
    throw const FormatException('expected certificate to contain the key extension');
  }

  final notBefore = _decodeAsn1Time(validityElements[0]);
  final notAfter = _decodeAsn1Time(validityElements[1]);
  final now = DateTime.now().toUtc();
  if (now.isBefore(notBefore) || now.isAfter(notAfter)) {
    throw const FormatException(
      'certificate verification failed: x509: certificate has expired or is not yet valid',
    );
  }
  if (hasUnrecognizedCriticalExtension) {
    throw const FormatException(
      'certificate verification failed: x509: unhandled critical extension',
    );
  }

  final _SignedKey signedKey;
  try {
    signedKey = _SignedKey.decode((keyExt.elements!.last as ASN1OctetString).octets!);
  } catch (e) {
    throw FormatException('unmarshalling signed certificate failed: $e');
  }

  final PubKey pubKey;
  try {
    pubKey = unmarshalPublicKey(signedKey.pubKey);
  } catch (e) {
    throw FormatException('unmarshalling public key failed: $e');
  }

  final certKeyPub = subjectPublicKeyInfoElement.encode();
  final toVerify = Uint8List.fromList([...utf8.encode(_certificatePrefix), ...certKeyPub]);
  final valid = await pubKey.verify(toVerify, signedKey.signature);
  if (!valid) {
    throw const FormatException('signature invalid');
  }
  return pubKey;
}

/// The default certificate template, per go-libp2p's `certTemplate`
/// (crypto.go:266-286).
({BigInt serialNumber, BigInt subjectSerialNumber, DateTime notBefore, DateTime notAfter}) _certTemplate() {
  final rng = Random.secure();
  final now = DateTime.now().toUtc();
  return (
    serialNumber: _randomSerial(rng),
    subjectSerialNumber: _randomSerial(rng),
    notBefore: now.subtract(const Duration(hours: 1)),
    notAfter: now.add(_certValidityPeriod),
  );
}

/// A value uniform in `[0, 2^62)`, matching `rand.Int(rand.Reader,
/// big.NewInt(1 << 62))` (crypto.go:267-268, 273-274). `1 << 62` is a
/// power of two, so masking 8 random bytes to 62 bits is exact -- no
/// rejection sampling needed.
BigInt _randomSerial(Random rng) {
  var value = BigInt.zero;
  for (var i = 0; i < 8; i++) {
    value = (value << 8) | BigInt.from(rng.nextInt(256));
  }
  return value & ((BigInt.one << 62) - BigInt.one);
}

/// `pkix.Name{SerialNumber: subjectSerialNumber.String()}`'s RDNSequence:
/// a single RDN holding one `id-at-serialNumber` `AttributeTypeAndValue`,
/// per go-libp2p's `certTemplate` (crypto.go:284).
ASN1Sequence _buildName(BigInt subjectSerialNumber) => ASN1Sequence(
  elements: [
    ASN1Set(
      elements: [
        ASN1Sequence(
          elements: [
            ASN1ObjectIdentifier(_idAtSerialNumberOid),
            ASN1PrintableString(stringValue: subjectSerialNumber.toString()),
          ],
        ),
      ],
    ),
  ],
);

/// `AlgorithmIdentifier ::= SEQUENCE { algorithm OBJECT IDENTIFIER }` for
/// ecdsa-with-SHA256, with parameters absent (RFC 5758) -- unlike RSA's,
/// ECDSA's `AlgorithmIdentifier` carries no `NULL` parameters field.
ASN1Sequence _ecdsaWithSha256AlgorithmIdentifier() =>
    ASN1Sequence(elements: [ASN1ObjectIdentifier(_ecdsaWithSha256Oid)]);

/// Encodes [dt] as `UTCTime` (years 1950-2049) or `GeneralizedTime`
/// otherwise, per RFC 5280's `Time` choice rule -- `certTemplate`'s
/// `notBefore` (~now) always encodes as `UTCTime`, `notAfter` (~100 years
/// out) always as `GeneralizedTime`.
ASN1Object _encodeAsn1Time(DateTime dt) {
  final utc = dt.toUtc();
  if (utc.year >= 1950 && utc.year <= 2049) {
    return ASN1UtcTime(utc);
  }
  String pad2(int v) => v.toString().padLeft(2, '0');
  final value =
      '${utc.year.toString().padLeft(4, '0')}${pad2(utc.month)}${pad2(utc.day)}'
      '${pad2(utc.hour)}${pad2(utc.minute)}${pad2(utc.second)}Z';
  // Hand-rolled rather than ASN1GeneralizedTime(dt)..encode(): that
  // encoder doesn't zero-pad month/day/hour/minute/second, producing
  // malformed DER for any single-digit field.
  return ASN1Object(tag: 0x18)..valueBytes = Uint8List.fromList(ascii.encode(value));
}

/// Decodes a `Validity` element (`UTCTime` or `GeneralizedTime`) parsed by
/// [ASN1Sequence.fromBytes].
DateTime _decodeAsn1Time(ASN1Object el) {
  if (el is ASN1UtcTime) return _decodeUtcTimeValue(el.valueBytes!);
  if (el is ASN1GeneralizedTime) return el.dateTimeValue!;
  throw FormatException('unsupported certificate time encoding (tag ${el.tag})');
}

/// Decodes a raw `UTCTime` value (`YYMMDDHHMMSSZ`), applying RFC 5280's
/// century rule directly (`YY >= 50` => `19YY`, else `20YY`).
///
/// Doesn't use [ASN1UtcTime.time]: pointycastle's own parser applies the
/// rule as `YY > 75` instead of `YY >= 50`, misdating e.g. go-libp2p's own
/// test vectors' `750101130000Z` to `2075` instead of RFC 5280's `1975`.
DateTime _decodeUtcTimeValue(Uint8List valueBytes) {
  final s = ascii.decode(valueBytes);
  final yy = int.parse(s.substring(0, 2));
  final year = yy >= 50 ? 1900 + yy : 2000 + yy;
  return DateTime.utc(
    year,
    int.parse(s.substring(2, 4)),
    int.parse(s.substring(4, 6)),
    int.parse(s.substring(6, 8)),
    int.parse(s.substring(8, 10)),
    int.parse(s.substring(10, 12)),
  );
}

/// [ASN1ObjectIdentifier.objectIdentifier] as a proper `List<int>`.
///
/// pointycastle's own field is a `Uint8List`, which silently truncates any
/// OID arc above 255 to its low byte -- e.g. this extension's own arc
/// `53594` (the libp2p private enterprise number) decodes to `90`. Its
/// `objectIdentifierAsString` (`"1.3.6.1.4.1.53594.1.1"`) doesn't share
/// that bug, so this reconstructs the component list from that string
/// instead of trusting the truncated field.
List<int> _oidComponents(ASN1ObjectIdentifier oid) =>
    oid.objectIdentifierAsString!.split('.').map(int.parse).toList();

/// Whether an `Extension` SEQUENCE's optional `critical BOOLEAN DEFAULT
/// FALSE` is present and true.
bool _isExtensionCritical(ASN1Sequence extSeq) {
  final elements = extSeq.elements!;
  if (elements.length < 3) return false;
  final maybeCritical = elements[1];
  return maybeCritical is ASN1Boolean && (maybeCritical.boolValue ?? false);
}
