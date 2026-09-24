part of 'extension.dart';

// Port of pkg/protocol/extension/errors.go. `ErrALPNInvalidFormat` is
// Go-exported (capitalized), so kept public; every other var here is
// Go-unexported (lowercase), so private (AGENTS.md).

/// ErrALPNInvalidFormat is raised when the ALPN format is invalid.
///
/// Port of `ErrALPNInvalidFormat` (errors.go:13-15).
final protocol.FatalException errAlpnInvalidFormat = protocol.FatalException(
  'invalid alpn format',
);

final protocol.FatalException _errAlpnNoAppProto = protocol.FatalException(
  'no application protocol',
);
final protocol.TemporaryException _errBufferTooSmall =
    protocol.TemporaryException('buffer is too small');
final protocol.FatalException _errInvalidExtensionType =
    protocol.FatalException('invalid extension type');
final protocol.FatalException _errInvalidSniFormat = protocol.FatalException(
  'invalid server name format',
);
final protocol.FatalException _errInvalidCidFormat = protocol.FatalException(
  'invalid connection ID format',
);
final protocol.InternalException _errLengthMismatch =
    protocol.InternalException('data length and declared length do not match');
final protocol.FatalException _errMasterKeyIdentifierTooLarge =
    protocol.FatalException('master key identifier is over 255 bytes');
final protocol.FatalException _errPreSharedKeyFormat = protocol.FatalException(
  'invalid Pre-Shared Key extension format',
);
final protocol.FatalException _errPskKeyExchangeModesFormat =
    protocol.FatalException(
      'invalid Pre-Shared Key Exchange Modes extension format',
    );
final protocol.InternalException _errNoPskKeyExchangeMode =
    protocol.InternalException(
      'no mode set for the Pre-Shared Key Exchange Modes extension',
    );
final protocol.FatalException _errCookieExtFormat = protocol.FatalException(
  'invalid cookie format',
);
final protocol.FatalException _errInvalidKeyShareFormat =
    protocol.FatalException('invalid key_share format');
final protocol.FatalException _errDuplicateKeyShare = protocol.FatalException(
  'duplicate key_share group',
);
final protocol.FatalException _errInvalidSupportedVersionsFormat =
    protocol.FatalException('invalid supported_versions format');
final protocol.InternalException _errInvalidDtlsVersion =
    protocol.InternalException('invalid dtls version was provided');
