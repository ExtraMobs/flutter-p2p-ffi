// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
part of '../transpiled_pion_sdp.dart';

// Port of github.com/pion/sdp/v3 direction.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).

/// A marker for the transmission direction of an endpoint. Port of the
/// `sdp.Direction` type (direction.go:9) and its four exported constants.
///
/// Go's `Direction` is a bare `int` whose zero value (no exported constant
/// names it; `direction.go` casts it as `Direction(unknown)`) is only ever
/// observed as the default value of the unset `ExtMap.Direction` struct
/// field (see `extmap.go`). This port represents that "no direction was
/// present" case with `Direction?` being `null` at the call site
/// ([ExtMap.direction]) rather than adding a synthetic fifth enum member,
/// which keeps [Direction] itself a closed, exhaustive Dart `enum`.
enum Direction {
  /// Bidirectional communication.
  sendRecv('sendrecv'),

  /// Outgoing communication only.
  sendOnly('sendonly'),

  /// Incoming communication only.
  recvOnly('recvonly'),

  /// No communication.
  inactive('inactive');

  const Direction(this._wireValue);

  final String _wireValue;

  /// Parses [raw] into a [Direction]. Port of `sdp.NewDirection`
  /// (direction.go:34).
  ///
  /// The Go signature returns `(Direction, error)`; per this project's rule
  /// against public error-tuple returns, an unrecognized [raw] value throws
  /// [FormatException] instead of returning the Go zero value alongside
  /// `errDirectionString`.
  factory Direction.fromRaw(String raw) {
    for (final value in Direction.values) {
      if (value._wireValue == raw) {
        return value;
      }
    }
    throw FormatException('invalid direction string', raw);
  }

  /// Port of `Direction.String` (direction.go:49): the RFC 4566 wire token
  /// for this direction (e.g. `"sendrecv"`).
  @override
  String toString() => _wireValue;
}
