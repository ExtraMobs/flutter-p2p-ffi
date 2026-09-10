// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:convert';
import 'dart:core' hide String;
import 'dart:core' as core;
import 'dart:typed_data';

import 'rune.dart';

/// Immutable Go string: a sequence of bytes, not necessarily valid UTF-8.
final class String implements Comparable<String> {
  /// Go zero value is the empty string.
  String() : _bytes = Uint8List(0);

  /// Go string([]byte) copies bytes without UTF-8 validation or replacement.
  String.fromBytes(Uint8List bytes) : _bytes = Uint8List.fromList(bytes);

  // Only receives fresh buffers allocated by this library, never caller bytes.
  String._owned(this._bytes);

  /// Go string(runeValue), after the rune's int32 conversion has occurred.
  factory String.fromRune(Rune value) => String.fromCodePoint(value.toBigInt());

  /// Go string(integer): UTF-8 for a Unicode scalar, U+FFFD otherwise.
  /// Pass the value after any source-type conversion, not its raw bits.
  factory String.fromCodePoint(BigInt value) {
    final valid =
        value >= BigInt.zero &&
        value <= BigInt.from(0x10ffff) &&
        !(value >= BigInt.from(0xd800) && value <= BigInt.from(0xdfff));
    return String.fromDart(
      core.String.fromCharCode(valid ? value.toInt() : 0xfffd),
    );
  }

  /// Explicit boundary from Dart text to its UTF-8 representation.
  /// Dart unpaired surrogates follow the standard UTF-8 encoder's replacement.
  String.fromDart(core.String value)
    : _bytes = Uint8List.fromList(utf8.encode(value));

  final Uint8List _bytes;

  /// Go len(s): bytes, not Unicode code points or UTF-16 code units.
  int get length => _bytes.length;

  /// Go s[index]; out-of-range access throws RangeError (Go runtime panic).
  int operator [](int index) => _bytes[index];

  /// Go []byte(s) returns an independent, mutable byte sequence.
  Uint8List toBytes() => Uint8List.fromList(_bytes);

  /// Explicit strict UTF-8 decoding; arbitrary Go bytes may not be Dart text.
  core.String toDart() => utf8.decode(_bytes);

  /// Go s[low:high] operates on byte boundaries, even within UTF-8 sequences.
  String slice([int low = 0, int? high]) {
    final end = high ?? length;
    RangeError.checkValidRange(low, end, length);
    return String.fromBytes(Uint8List.sublistView(_bytes, low, end));
  }

  /// Go string concatenation preserves bytes verbatim.
  String operator +(String other) {
    final bytes = Uint8List(length + other.length);
    bytes.setRange(0, length, _bytes);
    bytes.setRange(length, bytes.length, other._bytes);
    return String._owned(bytes);
  }

  @override
  int compareTo(String other) {
    final end = length < other.length ? length : other.length;
    for (var i = 0; i < end; i++) {
      final difference = _bytes[i] - other._bytes[i];
      if (difference != 0) return difference;
    }
    return length.compareTo(other.length);
  }

  /// Go string comparisons are lexicographic by bytes.
  bool operator <(String other) => compareTo(other) < 0;

  /// Go string comparisons are lexicographic by bytes.
  bool operator <=(String other) => compareTo(other) <= 0;

  /// Go string comparisons are lexicographic by bytes.
  bool operator >(String other) => compareTo(other) > 0;

  /// Go string comparisons are lexicographic by bytes.
  bool operator >=(String other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) => other is String && compareTo(other) == 0;
  @override
  int get hashCode => Object.hashAll(_bytes);
}
