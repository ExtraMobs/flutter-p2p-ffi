// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

/// Go bool value with private byte storage; no implicit numeric conversion.
final class Bool {
  /// The Go zero value is false. Byte encoding is private, not a Go ABI promise.
  Bool([bool value = false]) : _bytes = Uint8List.fromList([value ? 1 : 0]);

  final Uint8List _bytes;

  /// Explicit boundary for Dart conditionals, which require a native bool.
  bool toBool() => _bytes[0] != 0;

  /// Go !x; Dart cannot overload the logical negation operator.
  Bool not() => Bool(!toBool());

  /// Go x && rhs: evaluates rhs only when x is true.
  Bool and(Bool Function() rhs) => toBool() ? rhs() : this;

  /// Go x || rhs: evaluates rhs only when x is false.
  Bool or(Bool Function() rhs) => toBool() ? this : rhs();

  @override
  bool operator ==(Object other) => other is Bool && toBool() == other.toBool();
  @override
  int get hashCode => toBool().hashCode;
  @override
  String toString() => toBool().toString();
}
