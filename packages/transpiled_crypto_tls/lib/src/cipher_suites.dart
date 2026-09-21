/// Port of the TLS 1.3 subset of Go's `crypto/tls` cipher_suites.go
/// (724 lines total).
///
/// Explicitly OUT OF SCOPE per this task's boundary (TLS 1.0-1.2 only, or
/// spanning both eras): `CipherSuite`/`CipherSuites`/`InsecureCipherSuites`/
/// `CipherSuiteName` (cipher_suites.go:28-115, the whole-catalog public API
/// covering every era), `cipherSuite`/`cipherSuites`/`cipherSuiteByID`/
/// `mutualCipherSuite`/`selectCipherSuite` (TLS 1.0-1.2 suite table),
/// `cipherSuitesPreferenceOrder(NoAES)`, `disabledCipherSuites`,
/// `rsaKexCiphers`, `tdesCiphers`, `aesgcmCiphers`, `isAESGCMPreferred`,
/// `cipherRC4`/`cipher3DES`/`cipherAES`/`macSHA1`/`macSHA256`,
/// `prefixNonceAEAD`, `aeadAESGCM` (the TLS 1.0-1.2 explicit-nonce AEAD
/// wrapper), `constantTimeHash`/`cthWrapper`/`newConstantTimeHash`,
/// `tls10MAC`, `rsaKA`/`ecdheECDSAKA`/`ecdheRSAKA`, and the TLS 1.0-1.2
/// cipher suite ID constants.
///
/// Go symbol -> upstream file:line -> Dart symbol:
///   - `TLS_AES_128_GCM_SHA256` (cipher_suites.go:709) -> [tlsAes128GcmSha256]
///   - `TLS_AES_256_GCM_SHA384` (cipher_suites.go:710) -> [tlsAes256GcmSha384]
///   - `TLS_CHACHA20_POLY1305_SHA256` (cipher_suites.go:711)
///     -> [tlsChacha20Poly1305Sha256]
///   - `cipherSuitesTLS13` (cipher_suites.go:213-217) -> [cipherSuitesTls13]
///   - `mutualCipherSuiteTLS13` (cipher_suites.go:664-671)
///     -> [mutualCipherSuiteTls13]
///   - `cipherSuiteTLS13ByID` (cipher_suites.go:673-680)
///     -> [cipherSuiteTls13ById]
///   - `aeadNonceLength` (cipher_suites.go:456) -> [aeadNonceLength].
///     `noncePrefixLength` (cipher_suites.go:457) is not ported: it sizes
///     the out-of-scope `prefixNonceAEAD`'s explicit nonce, which
///     `xorNonceAEAD` (the TLS 1.3 wrapper) has no equivalent of.
///   - `aead` interface (cipher_suites.go:446-451) -> `CipherSuiteTls13Aead`,
///     declared in `key_schedule.dart` (see that file's header)
///   - `xorNonceAEAD` and its methods (cipher_suites.go:484-516)
///     -> `_XorNonceAead`
///   - `aeadAESGCMTLS13` (cipher_suites.go:551-573) -> [aeadAesGcmTls13]
///   - `aeadChaCha20Poly1305` (cipher_suites.go:575-588)
///     -> [aeadChaCha20Poly1305]
///   - `cipherSuiteTLS13` struct + key-schedule methods -> `CipherSuiteTls13`,
///     declared in `key_schedule.dart` (Dart cannot add methods to an
///     imported class from a second file the way Go adds methods to a
///     struct from a second file in the same package).
///
/// AEAD primitives are `package:pointycastle`'s [pc.GCMBlockCipher] /
/// `pc.AESEngine` and [pc.ChaCha20Poly1305] / [pc.ChaCha7539Engine] /
/// [pc.Poly1305], not reimplemented -- this file ports only the TLS 1.3
/// nonce-construction wrapper (`xorNonceAEAD`) around them, matching Go's
/// own layering: `crypto/aes`, `crypto/internal/fips140/aes/gcm` and
/// `golang.org/x/crypto/chacha20poly1305` are equally out-of-scope base
/// primitives that Go itself does not reimplement in this file either.
/// `pc.AEADCipher.process()` is not used directly: it is correct for
/// [pc.GCMBlockCipher] (a `BaseAEADBlockCipher`, whose `process` calls
/// `processBytes` then `doFinal`) but silently wrong for
/// [pc.ChaCha20Poly1305] (a `BaseAEADCipher`, whose inherited `process` only
/// calls `processBytes` and never appends/verifies the tag via `doFinal`).
/// `_runAead` below drives both through the same explicit
/// `processBytes` + `doFinal` sequence so behavior does not depend on which
/// of pointycastle's two base classes the chosen cipher happens to extend.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;

import 'key_schedule.dart';

/// Port of `TLS_AES_128_GCM_SHA256` (`cipher_suites.go:709`).
const int tlsAes128GcmSha256 = 0x1301;

/// Port of `TLS_AES_256_GCM_SHA384` (`cipher_suites.go:710`).
const int tlsAes256GcmSha384 = 0x1302;

/// Port of `TLS_CHACHA20_POLY1305_SHA256` (`cipher_suites.go:711`).
const int tlsChacha20Poly1305Sha256 = 0x1303;

/// Port of `aeadNonceLength` (`cipher_suites.go:456`).
const int aeadNonceLength = 12;

/// The AEAD authentication tag length TLS 1.3 always uses, in bytes.
const int _tagLength = 16;

/// Port of `cipherSuitesTLS13` (`cipher_suites.go:213-217`). Go's own doc
/// comment there warns this "should be an internal detail" but is depended
/// on via `go:linkname` by third parties (`quic-go` among them); ported as a
/// plain public constant list since Dart has no equivalent linker escape
/// hatch to guard against, and nothing about that history changes the value.
final List<CipherSuiteTls13> cipherSuitesTls13 = [
  const CipherSuiteTls13(
    id: tlsAes128GcmSha256,
    keyLen: 16,
    aead: aeadAesGcmTls13,
    hash: crypto.sha256,
  ),
  const CipherSuiteTls13(
    id: tlsChacha20Poly1305Sha256,
    keyLen: 32,
    aead: aeadChaCha20Poly1305,
    hash: crypto.sha256,
  ),
  const CipherSuiteTls13(
    id: tlsAes256GcmSha384,
    keyLen: 32,
    aead: aeadAesGcmTls13,
    hash: crypto.sha384,
  ),
];

/// Port of `mutualCipherSuiteTLS13` (`cipher_suites.go:664-671`).
CipherSuiteTls13? mutualCipherSuiteTls13(List<int> have, int want) {
  for (final id in have) {
    if (id == want) return cipherSuiteTls13ById(id);
  }
  return null;
}

/// Port of `cipherSuiteTLS13ByID` (`cipher_suites.go:673-680`).
CipherSuiteTls13? cipherSuiteTls13ById(int id) {
  for (final suite in cipherSuitesTls13) {
    if (suite.id == id) return suite;
  }
  return null;
}

/// Port of `aeadAESGCMTLS13` (`cipher_suites.go:551-573`). Go picks between
/// BoringCrypto and the generic `crypto/internal/fips140/aes/gcm` path; both
/// are out-of-scope base-primitive selection Go itself performs beneath this
/// function, so this port always uses `package:pointycastle`'s
/// [pc.GCMBlockCipher] over the constant-time [pc.AESEngine] (AES-128 or
/// AES-256 selected automatically by `key.length`, matching Go's
/// `aes.NewCipher`; pointycastle's older `AESFastEngine` is `@Deprecated`
/// for side-channel issues and deliberately not used here).
CipherSuiteTls13Aead aeadAesGcmTls13(Uint8List key, Uint8List nonceMask) {
  if (nonceMask.length != aeadNonceLength) {
    throw ArgumentError('tls: internal error: wrong nonce length');
  }
  return _XorNonceGcmAead(key, nonceMask);
}

/// Port of `aeadChaCha20Poly1305` (`cipher_suites.go:575-588`), over
/// `package:pointycastle`'s [pc.ChaCha20Poly1305].
CipherSuiteTls13Aead aeadChaCha20Poly1305(Uint8List key, Uint8List nonceMask) {
  if (nonceMask.length != aeadNonceLength) {
    throw ArgumentError('tls: internal error: wrong nonce length');
  }
  return _XorNonceChaCha20Poly1305Aead(key, nonceMask);
}

/// Thrown by [CipherSuiteTls13Aead.open] when authentication fails. Mirrors
/// the unwrapped, unnamed `error` Go's `cipher.AEAD.Open` returns on tag
/// mismatch (`crypto/cipher`, out of this task's scope -- Go does not
/// declare a distinct named error type for it either).
final class AeadAuthenticationException implements Exception {
  /// Wraps the failure [message] from the underlying pointycastle exception.
  AeadAuthenticationException(this.message);

  /// Human-readable authentication failure detail.
  final String message;

  @override
  String toString() => 'AeadAuthenticationException: $message';
}

/// Port of `xorNonceAEAD` (`cipher_suites.go:484-516`): wraps an AEAD by
/// XORing the (8-byte, big-endian record sequence number) nonce into a fixed
/// mask before each call, per RFC 8446 Section 5.3.
///
/// `pc.GCMBlockCipher` (`AEADBlockCipher`) and `pc.ChaCha20Poly1305`
/// (`AEADCipher`) are two unrelated pointycastle interfaces with no common
/// supertype exposing `processBytes`/`doFinal`/`getOutputSize`, so this base
/// class factors only the nonce-XOR math and the [CipherSuiteTls13Aead]
/// contract; [_XorNonceGcmAead] and [_XorNonceChaCha20Poly1305Aead] each
/// drive their concrete pointycastle cipher explicitly. A fresh cipher is
/// built and `init`-ed per [seal]/[open] call rather than mutating a shared
/// one, since pointycastle binds both key and nonce at `init` time;
/// AES-GCM/ChaCha20-Poly1305 are stateless across calls given the same key,
/// so this is behaviorally identical to Go's single `cipher.AEAD` instance
/// handling a fresh nonce per `Seal`/`Open` call.
sealed class _XorNonceAead implements CipherSuiteTls13Aead {
  _XorNonceAead(Uint8List key, Uint8List nonceMask)
    : _key = Uint8List.fromList(key),
      _nonceMask = Uint8List.fromList(nonceMask);

  final Uint8List _key;
  final Uint8List _nonceMask;

  @override
  int get nonceSize => 8; // Port of `xorNonceAEAD.NonceSize` (cipher_suites.go:489): 64-bit sequence number.

  @override
  int get overhead => _tagLength; // Port of `xorNonceAEAD.Overhead` (cipher_suites.go:490).

  @override
  int get explicitNonceLen => 0; // Port of `xorNonceAEAD.explicitNonceLen` (cipher_suites.go:491).

  Uint8List _effectiveNonce(Uint8List nonce) {
    if (nonce.length != nonceSize) {
      throw ArgumentError('tls: internal error: wrong nonce length');
    }
    final effective = Uint8List.fromList(_nonceMask);
    for (var i = 0; i < nonce.length; i++) {
      effective[4 + i] ^= nonce[i];
    }
    return effective;
  }

  /// Runs the concrete cipher, already `init`-ed by the subclass, through
  /// `processBytes` + `doFinal`. Not `pc.AEADCipher.process`/the default
  /// `pc.AEADBlockCipher.process` for [pc.ChaCha20Poly1305]: see the
  /// file-level doc comment for why.
  Uint8List _run(
    bool forEncryption,
    Uint8List nonce,
    Uint8List input,
    Uint8List additionalData,
  );

  @override
  Uint8List seal(
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List additionalData,
  ) => _run(true, _effectiveNonce(nonce), plaintext, additionalData);

  @override
  Uint8List open(
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List additionalData,
  ) {
    try {
      return _run(false, _effectiveNonce(nonce), ciphertext, additionalData);
    } on pc.InvalidCipherTextException catch (e) {
      throw AeadAuthenticationException(e.message);
    } on ArgumentError catch (e) {
      final message = e.message;
      if (message is String && message.contains('mac check')) {
        throw AeadAuthenticationException(message);
      }
      rethrow;
    }
  }
}

final class _XorNonceGcmAead extends _XorNonceAead {
  _XorNonceGcmAead(super.key, super.nonceMask);

  @override
  Uint8List _run(
    bool forEncryption,
    Uint8List nonce,
    Uint8List input,
    Uint8List additionalData,
  ) {
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(
        forEncryption,
        pc.AEADParameters(
          pc.KeyParameter(_key),
          _tagLength * 8,
          nonce,
          additionalData,
        ),
      );
    final out = Uint8List(cipher.getOutputSize(input.length));
    var len = cipher.processBytes(input, 0, input.length, out, 0);
    len += cipher.doFinal(out, len);
    return Uint8List.view(out.buffer, out.offsetInBytes, len);
  }
}

final class _XorNonceChaCha20Poly1305Aead extends _XorNonceAead {
  _XorNonceChaCha20Poly1305Aead(super.key, super.nonceMask);

  @override
  Uint8List _run(
    bool forEncryption,
    Uint8List nonce,
    Uint8List input,
    Uint8List additionalData,
  ) {
    final cipher = pc.ChaCha20Poly1305(pc.ChaCha7539Engine(), pc.Poly1305())
      ..init(
        forEncryption,
        pc.AEADParameters(
          pc.KeyParameter(_key),
          _tagLength * 8,
          nonce,
          additionalData,
        ),
      );
    final out = Uint8List(cipher.getOutputSize(input.length));
    var len = cipher.processBytes(input, 0, input.length, out, 0);
    len += cipher.doFinal(out, len);
    return Uint8List.view(out.buffer, out.offsetInBytes, len);
  }
}
