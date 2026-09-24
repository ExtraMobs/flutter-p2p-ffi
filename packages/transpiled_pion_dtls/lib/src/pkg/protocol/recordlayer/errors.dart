part of 'recordlayer.dart';

// Port of pkg/protocol/recordlayer/errors.go. `ErrInvalidPacketLength` is
// Go-exported (capitalized), so kept public; every other var here is
// Go-unexported (lowercase), so private (AGENTS.md).

/// ErrInvalidPacketLength is returned when the packet length too small or
/// declared length do not match.
///
/// Port of `ErrInvalidPacketLength` (errors.go:14-17).
final protocol.TemporaryException errInvalidPacketLength =
    protocol.TemporaryException(
      'packet length and declared length do not match',
    );

final protocol.TemporaryException _errBufferTooSmall =
    protocol.TemporaryException('buffer is too small');
final protocol.InternalException _errSequenceNumberOverflow =
    protocol.InternalException('sequence number overflow');
final protocol.FatalException _errUnsupportedProtocolVersion =
    protocol.FatalException('unsupported protocol version');
final protocol.TemporaryException _errInvalidContentType =
    protocol.TemporaryException('invalid content type');
