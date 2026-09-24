part of 'handshake.dart';

// Port of pkg/protocol/handshake/errors.go. All vars there are
// Go-unexported (lowercase), so private (AGENTS.md).

final protocol.InternalException _errUnableToMarshalFragmented =
    protocol.InternalException('unable to marshal fragmented handshakes');
final protocol.InternalException _errHandshakeMessageUnset =
    protocol.InternalException('handshake message unset, unable to marshal');
final protocol.TemporaryException _errBufferTooSmall =
    protocol.TemporaryException('buffer is too small');
final protocol.InternalException _errLengthMismatch =
    protocol.InternalException('data length and declared length do not match');
final protocol.FatalException
_errInvalidClientKeyExchange = protocol.FatalException(
  'unable to determine if ClientKeyExchange is a public key or PSK Identity',
);
final protocol.FatalException _errInvalidHashAlgorithm =
    protocol.FatalException('invalid hash algorithm');
final protocol.FatalException _errInvalidSignatureAlgorithm =
    protocol.FatalException('invalid signature algorithm');
final protocol.FatalException _errCookieTooLong = protocol.FatalException(
  'cookie must not be longer then 255 bytes',
);
final protocol.FatalException _errInvalidEllipticCurveType =
    protocol.FatalException('invalid or unknown elliptic curve type');
final protocol.FatalException _errInvalidNamedCurve = protocol.FatalException(
  'invalid named curve',
);
final protocol.FatalException _errCipherSuiteUnset = protocol.FatalException(
  'server hello can not be created without a cipher suite',
);
final protocol.FatalException _errCompressionMethodUnset =
    protocol.FatalException(
      'server hello can not be created without a compression method',
    );
final protocol.FatalException _errInvalidCompressionMethod =
    protocol.FatalException('invalid or unknown compression method');
final protocol.InternalException _errNotImplemented =
    protocol.InternalException('feature has not been implemented yet');
final protocol.FatalException _errInvalidCertificateRequestContext =
    protocol.FatalException('invalid certificate request context');
final protocol.FatalException _errInvalidCertificateEntry =
    protocol.FatalException('invalid certificate entry');
final protocol.FatalException _errCertificateRequestContextTooLong =
    protocol.FatalException(
      'certificate request context must not be longer than 255 bytes',
    );
final protocol.FatalException _errCertificateListTooLong =
    protocol.FatalException(
      'certificate list must not be longer than 2^24-1 bytes',
    );
final protocol.FatalException _errInvalidExtensionsLength =
    protocol.FatalException(
      'extensions data must be between 2 and 2^16-1 bytes',
    );
final protocol.FatalException _errMissingSignatureAlgorithmsExtension =
    protocol.FatalException(
      'signature_algorithms extension is required in CertificateRequest',
    );
