// Port of github.com/pion/dtls/v3 internal/ciphersuite/*.go
//
// TLS Ciphers as registered with the IANA
// https://www.iana.org/assignments/tls-parameters/tls-parameters.xhtml#tls-parameters-4
//
// This Go package spans many files (ciphersuite.go, aes_ccm.go,
// aes_128_ccm.go, aes_256_ccm.go and one file per TLS_* suite), sharing the
// unexported `ID` type, `errCipherSuiteNotInit` and (via Go struct
// embedding) base-class method promotion across all of them. As with
// `pkg/crypto/ciphersuite`, this becomes one Dart library with the sibling
// files pulled in as `part`s, following `packages/transpiled_pion_sdp`'s
// convention.
///
/// Note on scope: this package's `internal/ciphersuite.ID` is a distinct Go
/// type from the root `dtls` package's own `CipherSuiteID` (declared in
/// `lib/src/cipher_suite.dart`, out of this task's scope) -- they happen to
/// share the same constant *values* but are unrelated types in both Go and
/// this port, exactly mirroring upstream.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart' as pkg_crypto;

import '../../pkg/crypto/ciphersuite/ciphersuite.dart' as crypto_ciphersuite;
import '../../pkg/crypto/clientcertificate/client_certificate.dart';
import '../../pkg/crypto/prf/prf.dart';
import '../../protocol/recordlayer/record_layer.dart';
import 'types/authentication_type.dart' as types;
import 'types/key_exchange_algorithm.dart' as types;

part 'aes_ccm.dart';
part 'aes_128_ccm.dart';
part 'aes_256_ccm.dart';
part 'tls_ecdhe_ecdsa_with_aes_128_ccm.dart';
part 'tls_ecdhe_ecdsa_with_aes_128_ccm8.dart';
part 'tls_ecdhe_ecdsa_with_aes_128_gcm_sha256.dart';
part 'tls_ecdhe_ecdsa_with_aes_256_cbc_sha.dart';
part 'tls_ecdhe_ecdsa_with_aes_256_gcm_sha384.dart';
part 'tls_ecdhe_psk_with_aes_128_cbc_sha256.dart';
part 'tls_ecdhe_rsa_with_aes_128_gcm_sha256.dart';
part 'tls_ecdhe_rsa_with_aes_256_cbc_sha.dart';
part 'tls_ecdhe_rsa_with_aes_256_gcm_sha384.dart';
part 'tls_psk_with_aes_128_cbc_sha256.dart';
part 'tls_psk_with_aes_128_ccm.dart';
part 'tls_psk_with_aes_128_ccm8.dart';
part 'tls_psk_with_aes_128_gcm_sha256.dart';
part 'tls_psk_with_aes_256_ccm8.dart';

/// errCipherSuiteNotInit -> &protocol.TemporaryError{...}.
class CipherSuiteNotInitializedException implements Exception {
  const CipherSuiteNotInitializedException([this.context]);

  final String? context;

  @override
  String toString() => context == null
      ? 'CipherSuite has not been initialized'
      : 'CipherSuite has not been initialized, $context';
}

/// ID is an ID for our supported CipherSuites.
class Id {
  const Id(this.value);

  final int value;

  // AES-128-CCM.
  static const Id tlsEcdheEcdsaWithAes128Ccm = Id(0xc0ac);
  static const Id tlsEcdheEcdsaWithAes128Ccm8 = Id(0xc0ae);

  // AES-128-GCM-SHA256.
  static const Id tlsEcdheEcdsaWithAes128GcmSha256 = Id(0xc02b);
  static const Id tlsEcdheRsaWithAes128GcmSha256 = Id(0xc02f);

  static const Id tlsEcdheEcdsaWithAes256GcmSha384 = Id(0xc02c);
  static const Id tlsEcdheRsaWithAes256GcmSha384 = Id(0xc030);

  // AES-256-CBC-SHA.
  static const Id tlsEcdheEcdsaWithAes256CbcSha = Id(0xc00a);
  static const Id tlsEcdheRsaWithAes256CbcSha = Id(0xc014);

  static const Id tlsPskWithAes128Ccm = Id(0xc0a4);
  static const Id tlsPskWithAes128Ccm8 = Id(0xc0a8);
  static const Id tlsPskWithAes256Ccm8 = Id(0xc0a9);
  static const Id tlsPskWithAes128GcmSha256 = Id(0x00a8);
  static const Id tlsPskWithAes128CbcSha256 = Id(0x00ae);

  static const Id tlsEcdhePskWithAes128CbcSha256 = Id(0xC037);

  @override
  String toString() {
    switch (value) {
      case 0xc0ac:
        return 'TLS_ECDHE_ECDSA_WITH_AES_128_CCM';
      case 0xc0ae:
        return 'TLS_ECDHE_ECDSA_WITH_AES_128_CCM_8';
      case 0xc02b:
        return 'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256';
      case 0xc02f:
        return 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256';
      case 0xc00a:
        return 'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA';
      case 0xc014:
        return 'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA';
      case 0xc0a4:
        return 'TLS_PSK_WITH_AES_128_CCM';
      case 0xc0a8:
        return 'TLS_PSK_WITH_AES_128_CCM_8';
      case 0xc0a9:
        return 'TLS_PSK_WITH_AES_256_CCM_8';
      case 0x00a8:
        return 'TLS_PSK_WITH_AES_128_GCM_SHA256';
      case 0x00ae:
        return 'TLS_PSK_WITH_AES_128_CBC_SHA256';
      case 0xc02c:
        return 'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384';
      case 0xc030:
        return 'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384';
      case 0xC037:
        return 'TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA256';
      default:
        return 'unknown($value)';
    }
  }

  @override
  bool operator ==(Object other) => other is Id && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
