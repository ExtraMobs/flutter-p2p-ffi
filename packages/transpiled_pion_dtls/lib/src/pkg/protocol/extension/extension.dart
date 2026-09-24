/// Port of `github.com/pion/dtls/v3/pkg/protocol/extension` (revision fixed
/// in doc/transpilation/UPSTREAM_LOCK.md) -- TLS/DTLS ClientHello/ServerHello
/// extension values.
///
/// Split across `lib/src/pkg/protocol/extension/*.dart` via `part`/`part of`,
/// one Dart file per Go file, mirroring the single Go package `extension`
/// (AGENTS.md "Estrutura"). Not re-exported by the package's top barrel
/// (owned by a concurrent agent -- see progress notes).
///
/// `golang.org/x/crypto/cryptobyte` (`Builder`/`String`), the wire-codec
/// library several files here use, is a separate Go module boundary and out
/// of scope to port 1:1 (same precedent as
/// `packages/transpiled_crypto_tls/lib/src/handshake_messages.dart`). Its
/// wire behavior is reproduced by the private [_CryptobyteBuilder]/
/// [_CryptobyteReader] helpers in `wire.dart`.
///
/// EXTERNAL DEPENDENCY NOT YET LANDED (as of this port): `alpn.go`,
/// `connection_id.go`, `cookie.go`, `key_share.go`,
/// `supported_elliptic_curves.go` need `github.com/pion/dtls/v3/pkg/crypto/
/// elliptic` (`Curve`, `CurveType`, `Curves()`, `CurveTypes()`,
/// `CurvePointFormat`, `CurvePointFormatUncompressed`);
/// `generic_signature_hash_extension.go`, `supported_signature_algorithms.go`,
/// `signature_algorithms_cert.go` need `pkg/crypto/hash` (`Algorithm`,
/// `Algorithms()`, `ExtractHashFromPSS`), `pkg/crypto/signature`
/// (`Algorithm`, `Algorithms()`, `isPSS()`) and `pkg/crypto/signaturehash`
/// (`Algorithm{hash, signature}`). These are owned by a concurrent agent
/// porting `pkg/crypto/*` (see PORT_RULES.md scope split) and are imported
/// here from their expected mirrored path
/// (`package:transpiled_pion_dtls/src/pkg/crypto/<pkg>/<pkg>.dart`, prefix =
/// Go package name per AGENTS.md Regra 25); until those files exist, `dart
/// analyze`/`dart test` on the files listed above fail on unresolved
/// imports. This is reported, not silently worked around with a stub
/// (PORT_RULES.md vetoes stubs).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:transpiled_pion_dtls/src/pkg/crypto/elliptic/elliptic.dart'
    as elliptic;
import 'package:transpiled_pion_dtls/src/pkg/crypto/hash/hash.dart' as hash;
import 'package:transpiled_pion_dtls/src/pkg/crypto/signature/signature.dart'
    as signature;
import 'package:transpiled_pion_dtls/src/pkg/crypto/signaturehash/signaturehash.dart'
    as signaturehash;
import 'package:transpiled_pion_dtls/src/pkg/protocol/protocol.dart'
    as protocol;

part 'errors.dart';
part 'wire.dart';
part 'srtp_protection_profile.dart';
part 'use_srtp.dart';
part 'supported_elliptic_curves.dart';
part 'supported_point_formats.dart';
part 'generic_signature_hash_extension.dart';
part 'supported_signature_algorithms.dart';
part 'signature_algorithms_cert.dart';
part 'use_master_secret.dart';
part 'server_name.dart';
part 'renegotiation_info.dart';
part 'alpn.dart';
part 'connection_id.dart';
part 'cookie.dart';
part 'psk_key_exchange_modes.dart';
part 'supported_versions.dart';
part 'key_share.dart';
part 'pre_shared_key.dart';

/// TypeValue is the 2 byte value for a TLS Extension as registered in the
/// IANA.
/// https://www.iana.org/assignments/tls-extensiontype-values/tls-extensiontype-values.xhtml
///
/// Port of `TypeValue` (extension.go:15-17) and its consts (extension.go:20-35).
enum TypeValue {
  serverName(0),
  supportedEllipticCurves(10),
  supportedPointFormats(11),
  supportedSignatureAlgorithms(13),
  useSrtp(14),
  alpn(16),
  useExtendedMasterSecret(23),
  preSharedKey(41),
  supportedVersions(43),
  cookie(44),
  pskKeyExchangeModes(45),
  signatureAlgorithmsCert(50),
  keyShare(51),
  connectionId(54),
  renegotiationInfo(65281);

  final int value;
  const TypeValue(this.value);

  static TypeValue? tryFromValue(int val) {
    for (final t in TypeValue.values) {
      if (t.value == val) return t;
    }
    return null;
  }
}

/// Extension represents a single TLS extension.
///
/// Port of `Extension` (extension.go:38-42). `Marshal`/`Unmarshal` return
/// the value directly and throw on failure per AGENTS.md Regra 8.
abstract class Extension {
  Uint8List marshal();
  void unmarshal(Uint8List data);
  TypeValue get typeValue;
}

/// Unmarshal many extensions at once.
///
/// Port of `Unmarshal` (extension.go:45-83).
List<Extension> unmarshalExtensions(Uint8List buf) {
  if (buf.isEmpty) return [];
  if (buf.length < 2) throw _errBufferTooSmall;

  final declaredLen = (buf[0] << 8) | buf[1];
  if (buf.length - 2 != declaredLen) throw _errLengthMismatch;

  final extensions = <Extension>[];

  var offset = 2;
  while (offset < buf.length) {
    final bufView = Uint8List.sublistView(buf, offset);
    if (bufView.length < 2) throw _errBufferTooSmall;

    final typeCode = (bufView[0] << 8) | bufView[1];
    final type = TypeValue.tryFromValue(typeCode);
    // Go's Unmarshal (extension.go:56-108) switches on a fixed subset of
    // TypeValue consts; PskKeyExchangeModesTypeValue and PreSharedKeyValue
    // have consts but no case there (no `default:` action either), so a
    // wire extension of either type is silently skipped by this dispatcher
    // -- preserved here rather than "fixed", per AGENTS.md (byte-for-byte
    // upstream behavior, quirks included).
    Extension? e;
    switch (type) {
      case TypeValue.serverName:
        e = ServerName();
      case TypeValue.supportedEllipticCurves:
        e = SupportedEllipticCurves();
      case TypeValue.supportedPointFormats:
        e = SupportedPointFormats();
      case TypeValue.supportedSignatureAlgorithms:
        e = SupportedSignatureAlgorithms();
      case TypeValue.signatureAlgorithmsCert:
        e = SignatureAlgorithmsCert();
      case TypeValue.useSrtp:
        e = UseSrtp();
      case TypeValue.alpn:
        e = Alpn();
      case TypeValue.useExtendedMasterSecret:
        e = UseExtendedMasterSecret();
      case TypeValue.renegotiationInfo:
        e = RenegotiationInfo();
      case TypeValue.connectionId:
        e = ConnectionId();
      case TypeValue.supportedVersions:
        e = SupportedVersions();
      case TypeValue.keyShare:
        e = KeyShare();
      case TypeValue.cookie:
        e = CookieExt();
      case TypeValue.pskKeyExchangeModes:
      case TypeValue.preSharedKey:
      case null:
        e = null;
    }
    if (e != null) {
      e.unmarshal(bufView);
      extensions.add(e);
    }

    if (bufView.length < 4) throw _errBufferTooSmall;
    final extensionLength = (bufView[2] << 8) | bufView[3];
    offset += 4 + extensionLength;
  }

  return extensions;
}

/// Marshal many extensions at once.
///
/// Port of `Marshal` (extension.go:120-131).
Uint8List marshalExtensions(List<Extension> extensions) {
  final raw = BytesBuilder();
  for (final e in extensions) {
    raw.add(e.marshal());
  }
  final body = raw.toBytes();
  final out = Uint8List(2 + body.length);
  out[0] = (body.length >> 8) & 0xff;
  out[1] = body.length & 0xff;
  out.setRange(2, out.length, body);
  return out;
}

/// parseSignatureScheme parses a signature scheme from a uint16 value. It
/// handles both TLS 1.2 style (hash byte + signature byte) and TLS 1.3 style
/// (full uint16 PSS schemes). Returns the hash algorithm and signature
/// algorithm.
///
/// Port of `parseSignatureScheme` (extension.go:134-143).
({hash.Algorithm hash, signature.Algorithm signature}) parseSignatureScheme(
  int scheme,
) {
  if (signature.Algorithm(scheme).isPSS()) {
    return (
      hash: hash.extractHashFromPSS(scheme),
      signature: signature.Algorithm(scheme),
    );
  }
  return (
    hash: hash.Algorithm(scheme >> 8),
    signature: signature.Algorithm(scheme & 0xff),
  );
}
