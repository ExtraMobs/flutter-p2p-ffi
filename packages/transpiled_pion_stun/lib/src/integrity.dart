/// Port of `integrity.go` (pion/stun v3.1.1).
///
/// Upstream's `newHMAC` (integrity.go:42-48) pulls a pre-keyed `hash.Hash`
/// from `internal/hmac`'s `sync.Pool` (`AcquireSHA1`/`PutSHA1`,
/// `internal/hmac/pool.go`) purely to avoid re-deriving the HMAC ipad/opad
/// on every call -- a GC-pressure optimization with no effect on the
/// computed bytes: `internal/hmac.New` (`internal/hmac/hmac.go`) implements
/// the exact same FIPS 198-1 construction as `crypto/hmac` and
/// `package:crypto`'s `Hmac`. This port computes HMAC-SHA1 directly with
/// `package:crypto`'s `Hmac(sha1, key)` (AGENTS.md ladder rung 3: stdlib/
/// already-installed dependency over hand-rolled reimplementation) and does
/// not port the pool: it is a private, non-exported optimization with zero
/// observable effect on [MessageIntegrity.addTo]/[MessageIntegrity.check].
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'attributes.dart';
import 'checks.dart';
import 'helpers.dart';
import 'message.dart';

const String _credentialsSep = ':';

const int _messageIntegritySize = 20;

/// Port of `ErrFingerprintBeforeIntegrity` (integrity.go:59): the
/// FINGERPRINT attribute is already in the message, so MESSAGE-INTEGRITY
/// cannot be added.
final class FingerprintBeforeIntegrityException implements Exception {
  const FingerprintBeforeIntegrityException();

  @override
  String toString() => 'FINGERPRINT before MESSAGE-INTEGRITY attribute';
}

/// Port of `ErrIntegrityMismatch` (integrity.go:91): computed HMAC differs
/// from the expected value.
final class IntegrityMismatchException implements Exception {
  const IntegrityMismatchException();

  @override
  String toString() => 'integrity check failed';
}

Uint8List _hmacSha1(Uint8List key, Uint8List message) =>
    Uint8List.fromList(Hmac(sha1, key).convert(message).bytes);

/// Port of `MessageIntegrity` (integrity.go:41): the MESSAGE-INTEGRITY
/// attribute (RFC 5389 Section 15.4).
final class MessageIntegrity implements Setter, Checker {
  const MessageIntegrity(this.key);

  /// Port of `NewLongTermIntegrity` (integrity.go:20-27): a key for
  /// long-term credentials. [username], [realm] and [password] must be
  /// SASL-prepared. Not a free `newX` function (AGENTS.md,
  /// "RULE_NO_NEW_X_FUNCTIONS"): it builds a [MessageIntegrity], so it
  /// belongs on the class as a named constructor.
  factory MessageIntegrity.longTerm(String username, String realm, String password) {
    final k = [username, realm, password].join(_credentialsSep);
    return MessageIntegrity(Uint8List.fromList(md5.convert(utf8.encode(k)).bytes));
  }

  /// Port of `NewShortTermIntegrity` (integrity.go:30-33): a key for
  /// short-term credentials. [password] must be SASL-prepared.
  factory MessageIntegrity.shortTerm(String password) =>
      MessageIntegrity(Uint8List.fromList(utf8.encode(password)));

  final Uint8List key;

  /// Port of `MessageIntegrity.String` (integrity.go:52-54).
  @override
  String toString() {
    final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'KEY: 0x$hex';
  }

  /// Port of `MessageIntegrity.AddTo` (integrity.go:62-79): CPU costly, as
  /// in upstream.
  @override
  void addTo(Message msg) {
    for (final a in msg.attributes) {
      if (a.type == AttrType.fingerprint) {
        throw const FingerprintBeforeIntegrityException();
      }
    }
    // The text used as input to HMAC is the STUN message, including the
    // header, up to and including the attribute preceding
    // MESSAGE-INTEGRITY.
    final length = msg.length;
    msg.length += _messageIntegritySize + attributeHeaderSize;
    msg.writeLength();
    final v = _hmacSha1(key, msg.raw);
    msg.length = length;

    final vBuf = Uint8List(20);
    vBuf.setRange(0, v.length, v);

    msg.add(AttrType.messageIntegrity, vBuf);
  }

  /// Port of `MessageIntegrity.Check` (integrity.go:85-108): CPU costly, as
  /// in upstream.
  @override
  void check(Message msg) {
    final val = msg.get(AttrType.messageIntegrity);

    final length = msg.length;
    var afterIntegrity = false;
    var sizeReduced = 0;
    for (final a in msg.attributes) {
      if (afterIntegrity) {
        sizeReduced += nearestPaddedValueLength(a.length);
        sizeReduced += attributeHeaderSize;
      }
      if (a.type == AttrType.messageIntegrity) {
        afterIntegrity = true;
      }
    }
    msg.length -= sizeReduced;
    msg.writeLength();
    final startOfHmac =
        messageHeaderSize + msg.length - (attributeHeaderSize + _messageIntegritySize);
    final b = Uint8List.sublistView(msg.raw, 0, startOfHmac);
    final expected = _hmacSha1(key, b);
    msg.length = length;
    msg.writeLength();

    checkHmac(val, expected);
  }
}
