/// Port of `errors.go` (pion/stun v3.1.1).
///
/// `error` return values from the upstream Go become thrown typed
/// exceptions (AGENTS.md, "RULE_NO_GO_STYLE_ERROR_TUPLES"): every sentinel
/// `errors.New(...)` variable becomes its own `Exception`-suffixed class
/// (AGENTS.md, "RULE_EXCEPTION_NAMING") carrying the same message Go used,
/// so `catch (e) { print(e); }` on the Dart side prints the same text a Go
/// caller would see from `err.Error()`. `newDecodeErr`/`newAttrDecodeErr`
/// (private Go constructor functions) become named factory constructors on
/// [DecodeException] rather than free `newX` functions (AGENTS.md,
/// "RULE_NO_NEW_X_FUNCTIONS").
library;

/// Port of `DecodeErrPlace` (errors.go:37-40): records where a decode error
/// occurred.
final class DecodeErrPlace {
  /// Creates a place with the given [parent] and [children] segments.
  const DecodeErrPlace({required this.parent, required this.children});

  /// The outer context the error occurred in (e.g. `'message'`).
  final String parent;

  /// The inner context the error occurred in (e.g. `'cookie'`).
  final String children;

  @override
  String toString() => '$parent/$children';

  @override
  bool operator ==(Object other) =>
      other is DecodeErrPlace &&
      other.parent == parent &&
      other.children == children;

  @override
  int get hashCode => Object.hash(parent, children);
}

/// Port of `DecodeErr` (errors.go:11-14): records an error and the place it
/// occurred at.
final class DecodeException implements Exception {
  /// Creates a decode exception at [place] with the given [message].
  const DecodeException(this.place, this.message);

  /// Port of `newDecodeErr` (errors.go:53-58).
  factory DecodeException.at(String parent, String children, String message) {
    return DecodeException(
      DecodeErrPlace(parent: parent, children: children),
      message,
    );
  }

  /// Port of `newAttrDecodeErr` (errors.go:60-62).
  factory DecodeException.forAttribute(String children, String message) =>
      DecodeException.at('attribute', children, message);

  /// The place the error occurred at.
  final DecodeErrPlace place;

  /// The human-readable detail message.
  final String message;

  /// Port of `DecodeErr.IsInvalidCookie` (errors.go:16-19).
  bool get isInvalidCookie =>
      place == const DecodeErrPlace(parent: 'message', children: 'cookie');

  /// Port of `DecodeErr.IsPlaceParent` (errors.go:21-24).
  bool isPlaceParent(String p) => place.parent == p;

  /// Port of `DecodeErr.IsPlaceChildren` (errors.go:26-29).
  bool isPlaceChildren(String c) => place.children == c;

  /// Port of `DecodeErr.IsPlace` (errors.go:31-34).
  bool isPlace(DecodeErrPlace p) => place == p;

  @override
  String toString() => 'BadFormat for $place: $message';
}

/// Port of `ErrAttributeSizeInvalid` (errors.go:64): decoded attribute size
/// is invalid.
final class AttributeSizeInvalidException implements Exception {
  /// Creates the exception.
  const AttributeSizeInvalidException();

  @override
  String toString() => 'attribute size is invalid';
}

/// Port of `ErrAttributeSizeOverflow` (errors.go:66): decoded attribute size
/// is too big.
final class AttributeSizeOverflowException implements Exception {
  /// Creates the exception.
  const AttributeSizeOverflowException();

  @override
  String toString() => 'attribute size overflow';
}

/// Port of Go stdlib's `io.ErrUnexpectedEOF`, used by `addr.go`'s
/// `MappedAddress.GetFromAs` and `xoraddr.go`'s `XORMappedAddress.GetFromAs`
/// when a MAPPED-ADDRESS/XOR-MAPPED-ADDRESS attribute value is too short to
/// contain even the 4-byte family/port header.
final class UnexpectedEofException implements Exception {
  /// Creates the exception.
  const UnexpectedEofException();

  @override
  String toString() => 'unexpected EOF';
}
