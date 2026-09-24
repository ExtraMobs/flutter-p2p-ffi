/// Port of `github.com/pion/dtls/v3/pkg/protocol/handshake` (revision fixed
/// in doc/transpilation/UPSTREAM_LOCK.md) -- the DTLS wire protocol for
/// handshakes.
///
/// Split across `lib/src/pkg/protocol/handshake/*.dart` via `part`/`part of`,
/// one Dart file per Go file, mirroring the single Go package `handshake`
/// (AGENTS.md "Estrutura"). Not re-exported by the package's top barrel
/// (owned by a concurrent agent -- see progress notes).
///
/// `golang.org/x/crypto/cryptobyte` is used by `message_certificate_13.go`
/// and `message_certificate_request_13.go`; its wire behavior is reproduced
/// by the private [_CryptobyteBuilder]/[_CryptobyteReader] helpers in
/// `wire.dart` (same precedent as `pkg/protocol/extension`'s own copy and
/// `packages/transpiled_crypto_tls`; see that package's library doc).
///
/// EXTERNAL DEPENDENCY NOT YET LANDED (as of this port):
/// `message_certificate_request.go` needs `pkg/crypto/clientcertificate`
/// (`ClientCertificateType`, `types()`), `pkg/crypto/hash`, `pkg/crypto/
/// signature`, `pkg/crypto/signaturehash`; `message_certificate_verify.go`
/// and `message_server_key_exchange.go` need `pkg/crypto/hash`/`pkg/crypto/
/// signature`; `message_server_key_exchange.go` additionally needs
/// `pkg/crypto/elliptic`. All owned by a concurrent agent (PORT_RULES.md
/// scope split) and imported from their expected mirrored path; until they
/// exist, `dart analyze`/`dart test` on the files above fail on unresolved
/// imports (reported, not stubbed).
///
/// `KeyExchangeAlgorithm` (`internal/ciphersuite/types.KeyExchangeAlgorithm`,
/// a bitmask `int`) is represented in this codebase, at package scope, by
/// `lib/src/cipher_suite.dart`'s `cipherSuiteKeyExchangeAlgorithmPsk`/`Ecdhe`
/// `int` constants (outside this port's own scope -- root `lib/src/*.dart`
/// -- but already present and reused here rather than redeclared, per
/// AGENTS.md "reutilize o port auditado"). Go's `(a KeyExchangeAlgorithm)
/// Has(v)` (`(a & v) == v`) is inlined at each call site rather than ported
/// as a method, since the type is a plain `int` here, not a wrapped newtype.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:transpiled_pion_dtls/src/cipher_suite.dart' as cipherSuite;
import 'package:transpiled_pion_dtls/src/internal/util/util.dart' as util;
import 'package:transpiled_pion_dtls/src/pkg/crypto/clientcertificate/clientcertificate.dart'
    as clientcertificate;
import 'package:transpiled_pion_dtls/src/pkg/crypto/elliptic/elliptic.dart'
    as elliptic;
import 'package:transpiled_pion_dtls/src/pkg/crypto/hash/hash.dart' as hash;
import 'package:transpiled_pion_dtls/src/pkg/crypto/signature/signature.dart'
    as signature;
import 'package:transpiled_pion_dtls/src/pkg/crypto/signaturehash/signaturehash.dart'
    as signaturehash;
import 'package:transpiled_pion_dtls/src/pkg/protocol/extension/extension.dart'
    as extension;
import 'package:transpiled_pion_dtls/src/pkg/protocol/protocol.dart'
    as protocol;

part 'errors.dart';
part 'wire.dart';
part 'cipher_suite.dart';
part 'header.dart';
part 'random.dart';
part 'message_hello_verify_request.dart';
part 'message_client_hello.dart';
part 'message_server_hello.dart';
part 'message_certificate.dart';
part 'message_certificate_13.dart';
part 'message_certificate_request.dart';
part 'message_certificate_request_13.dart';
part 'message_certificate_verify.dart';
part 'message_server_key_exchange.dart';
part 'message_client_key_exchange.dart';
part 'message_server_hello_done.dart';
part 'message_finished.dart';

/// Type is the unique identifier for each handshake message.
/// https://tools.ietf.org/html/rfc5246#section-7.4
///
/// Port of `Type` (handshake.go:16) and its consts (handshake.go:19-29).
/// Named `HandshakeType` (already the established name in this package
/// before this reorganization) since a bare `Type` would be an unhelpfully
/// generic top-level public name for a library other files import by
/// prefix.
enum HandshakeType {
  helloRequest(0),
  clientHello(1),
  serverHello(2),
  helloVerifyRequest(3),
  certificate(11),
  serverKeyExchange(12),
  certificateRequest(13),
  serverHelloDone(14),
  certificateVerify(15),
  clientKeyExchange(16),
  finished(20);

  final int value;
  const HandshakeType(this.value);

  static HandshakeType? tryFromValue(int val) {
    for (final t in HandshakeType.values) {
      if (t.value == val) return t;
    }
    return null;
  }

  /// Port of `Type.String` (handshake.go:32-58).
  @override
  String toString() {
    switch (this) {
      case HandshakeType.helloRequest:
        return 'HelloRequest';
      case HandshakeType.clientHello:
        return 'ClientHello';
      case HandshakeType.serverHello:
        return 'ServerHello';
      case HandshakeType.helloVerifyRequest:
        return 'HelloVerifyRequest';
      case HandshakeType.certificate:
        return 'TypeCertificate';
      case HandshakeType.serverKeyExchange:
        return 'ServerKeyExchange';
      case HandshakeType.certificateRequest:
        return 'CertificateRequest';
      case HandshakeType.serverHelloDone:
        return 'ServerHelloDone';
      case HandshakeType.certificateVerify:
        return 'CertificateVerify';
      case HandshakeType.clientKeyExchange:
        return 'ClientKeyExchange';
      case HandshakeType.finished:
        return 'Finished';
    }
  }
}

/// Message is the body of a Handshake datagram.
///
/// Port of `Message` (handshake.go:61-65). `Marshal`/`Unmarshal` return the
/// value directly and throw on failure per AGENTS.md Regra 8.
abstract class Message {
  Uint8List marshal();
  void unmarshal(Uint8List data);
  HandshakeType get type;
}

/// Handshake protocol is responsible for selecting a cipher spec and
/// generating a master secret, which together comprise the primary
/// cryptographic parameters associated with a secure session. The handshake
/// protocol can also optionally authenticate parties who have certificates
/// signed by a trusted certificate authority.
/// https://tools.ietf.org/html/rfc5246#section-7.3
///
/// Port of `Handshake` (handshake.go:73-78) and its methods
/// `ContentType`/`Marshal`/`Unmarshal` (handshake.go:81-144).
final class Handshake implements protocol.Content {
  HandshakeHeader header;
  Message? message;

  /// For unmarshaling `MessageServerKeyExchange`/`MessageClientKeyExchange`,
  /// which need to know the negotiated key exchange algorithm to parse their
  /// variable wire shape. A plain `int` bitmask -- see this library's doc.
  int keyExchangeAlgorithm;

  Handshake({
    HandshakeHeader? header,
    this.message,
    this.keyExchangeAlgorithm = 0,
  }) : header = header ?? HandshakeHeader();

  @override
  protocol.ContentType contentType() => protocol.ContentType.handshake;

  @override
  Uint8List marshal() {
    final msg = message;
    if (msg == null) throw _errHandshakeMessageUnset;
    if (header.fragmentOffset != 0) throw _errUnableToMarshalFragmented;

    final msgBytes = msg.marshal();

    header.length = msgBytes.length;
    header.fragmentLength = header.length;
    header.type = msg.type;
    final headerBytes = header.marshal();

    final out = Uint8List(headerBytes.length + msgBytes.length);
    out.setRange(0, headerBytes.length, headerBytes);
    out.setRange(headerBytes.length, out.length, msgBytes);
    return out;
  }

  @override
  void unmarshal(Uint8List data) {
    header.unmarshal(data);

    final reportedLen = util.bigEndianUint24(Uint8List.sublistView(data, 1));
    if (data.length - handshakeHeaderLength != reportedLen) {
      throw _errLengthMismatch;
    }
    if (reportedLen != header.fragmentLength) throw _errLengthMismatch;

    switch (HandshakeType.tryFromValue(data[0])) {
      case null:
        throw _errNotImplemented;
      case HandshakeType.helloRequest:
        throw _errNotImplemented;
      case HandshakeType.clientHello:
        message = MessageClientHello();
      case HandshakeType.helloVerifyRequest:
        message = MessageHelloVerifyRequest();
      case HandshakeType.serverHello:
        message = MessageServerHello();
      case HandshakeType.certificate:
        message = MessageCertificate();
      case HandshakeType.serverKeyExchange:
        message = MessageServerKeyExchange(
          keyExchangeAlgorithm: keyExchangeAlgorithm,
        );
      case HandshakeType.certificateRequest:
        message = MessageCertificateRequest();
      case HandshakeType.serverHelloDone:
        message = MessageServerHelloDone();
      case HandshakeType.clientKeyExchange:
        message = MessageClientKeyExchange(
          keyExchangeAlgorithm: keyExchangeAlgorithm,
        );
      case HandshakeType.finished:
        message = MessageFinished();
      case HandshakeType.certificateVerify:
        message = MessageCertificateVerify();
    }

    message!.unmarshal(Uint8List.sublistView(data, handshakeHeaderLength));
  }
}
