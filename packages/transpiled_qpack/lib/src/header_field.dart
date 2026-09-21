// Port of qpack/header_field.go (github.com/quic-go/qpack, commit
// c415cad59091662a20b7b1c4505fbb177dbda0e3).

/// A name-value pair. Both the name and value are treated as opaque
/// sequences of bytes.
///
/// Port of the Go `qpack.HeaderField` struct. Go structs are comparable by
/// value; [operator ==] and [hashCode] reproduce that here since Dart
/// classes do not get structural equality for free.
class HeaderField {
  /// Creates a header field. [value] defaults to the empty string, mirroring
  /// the Go zero value produced by struct literals such as
  /// `HeaderField{Name: ":authority"}`.
  const HeaderField({required this.name, this.value = ''});

  /// The header name (Go's `HeaderField.Name`).
  final String name;

  /// The header value (Go's `HeaderField.Value`).
  final String value;

  /// Reports whether the header field is an HTTP/3 pseudo header, i.e.
  /// whether its name starts with a colon. Not otherwise guaranteed to be a
  /// valid pseudo header field, though.
  bool isPseudo() => name.isNotEmpty && name.startsWith(':');

  @override
  bool operator ==(Object other) =>
      other is HeaderField && other.name == name && other.value == value;

  @override
  int get hashCode => Object.hash(name, value);

  @override
  String toString() => 'HeaderField(name: $name, value: $value)';
}
