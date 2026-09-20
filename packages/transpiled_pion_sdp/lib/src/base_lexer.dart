// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
part of '../transpiled_pion_sdp.dart';

// Port of github.com/pion/sdp/v3 base_lexer.go (revision fixed in
// doc/transpilation/UPSTREAM_LOCK.md).
//
// Go's `baseLexer` scans its input as raw bytes (`l.value[l.pos]` indexes a
// Go string's bytes, not runes). This port mirrors that byte-level algorithm
// exactly -- storing the UTF-8 encoding of the input in a `Uint8List` rather
// than iterating a Dart `String`'s UTF-16 code units -- so ASCII structural
// tokens (`=`, whitespace, CR/LF, digits) are matched identically and
// multi-byte UTF-8 sequences inside free-text fields pass through unexamined,
// exactly as they do upstream.

/// Thrown for the sentinel `errDocumentStart` (base_lexer.go:14), raised by
/// [_BaseLexer.unreadByte] when already at position 0.
class DocumentStartException implements Exception {
  @override
  String toString() => 'already on document start';
}

/// Thrown wherever upstream's hand-written lexer state machine reads past
/// the end of input (the Go stdlib sentinel `io.EOF`, read by
/// [_BaseLexer.readByte] at base_lexer.go:47-55). Some callers treat this as
/// a clean, successful stop (e.g. the end of a well-formed SDP document);
/// others propagate it as a genuine parse failure -- exactly which upstream
/// does per call site, reproduced here via `try`/`on` instead of Go's
/// `errors.Is(err, io.EOF)` checks.
class SdpUnexpectedEndOfInputException implements Exception {
  @override
  String toString() => 'sdp: unexpected end of input';
}

/// Thrown for the `syntaxError` struct (base_lexer.go:16-27), reporting the
/// byte offset and offending byte of a malformed SDP document.
class SdpSyntaxException implements Exception {
  SdpSyntaxException(this._bytes, int index) : index = index < 0 ? 0 : index;

  final Uint8List _bytes;

  /// Byte offset into the original document at which parsing failed.
  final int index;

  @override
  String toString() {
    final ch = index < _bytes.length ? _bytes[index] : 0;
    final printable = ch >= 0x20 && ch < 0x7f
        ? String.fromCharCode(ch)
        : r'\x' + ch.toRadixString(16).padLeft(2, '0');
    return 'sdp: syntax error at pos $index: "$printable"';
  }
}

/// Byte-level cursor over an SDP document. Port of `sdp.baseLexer`
/// (base_lexer.go:29).
class _BaseLexer {
  _BaseLexer(String value)
      : _bytes = Uint8List.fromList(utf8.encode(value)),
        pos = 0;

  final Uint8List _bytes;
  int pos;

  SdpSyntaxException syntaxError() => SdpSyntaxException(_bytes, pos - 1);

  void unreadByte() {
    if (pos <= 0) {
      throw DocumentStartException();
    }
    pos--;
  }

  int readByte() {
    if (pos >= _bytes.length) {
      throw SdpUnexpectedEndOfInputException();
    }
    final ch = _bytes[pos];
    pos++;
    return ch;
  }

  void nextLine() {
    while (true) {
      final int ch;
      try {
        ch = readByte();
      } on SdpUnexpectedEndOfInputException {
        return;
      }
      if (!_isNewline(ch)) {
        unreadByte();
        return;
      }
    }
  }

  void readWhitespace() {
    while (true) {
      final int ch;
      try {
        ch = readByte();
      } on SdpUnexpectedEndOfInputException {
        return;
      }
      if (!_isWhitespace(ch)) {
        unreadByte();
        return;
      }
    }
  }

  /// Reads an unsigned decimal field. Port of `baseLexer.readUint64Field`
  /// (base_lexer.go:85).
  ///
  /// Upstream uses its running total `i > 0` as a proxy for "at least one
  /// digit was read" rather than a dedicated flag; that means a lone `"0"`
  /// with nothing after it reads as if no digit had been seen at all, and
  /// hitting end-of-input at that point throws instead of yielding zero.
  /// This port keeps that exact quirk for fidelity.
  Golang.Uint64 readUint64Field() {
    var i = Golang.Uint64();
    while (true) {
      final int ch;
      try {
        ch = readByte();
      } on SdpUnexpectedEndOfInputException {
        if (i > Golang.Uint64()) {
          break;
        }
        rethrow;
      }
      if (_isNewline(ch)) {
        unreadByte();
        break;
      }
      if (_isWhitespace(ch)) {
        readWhitespace();
        break;
      }
      final digit = ch - 0x30;
      if (digit < 0 || digit > 9) {
        throw syntaxError();
      }
      i = i * Golang.Uint64(10) + Golang.Uint64(digit);
    }
    return i;
  }

  /// Returns the next field on this line, or the empty string if there are
  /// no more fields. Port of `baseLexer.readField` (base_lexer.go:140).
  String readField() {
    final start = pos;
    var stop = pos;
    while (true) {
      stop = pos;
      final int ch;
      try {
        ch = readByte();
      } on SdpUnexpectedEndOfInputException {
        if (stop > start) {
          break;
        }
        rethrow;
      }
      if (_isNewline(ch)) {
        unreadByte();
        break;
      }
      if (_isWhitespace(ch)) {
        readWhitespace();
        break;
      }
    }
    return utf8.decode(_bytes.sublist(start, stop));
  }

  /// Returns the symbols until line end. Port of `baseLexer.readLine`
  /// (base_lexer.go:186).
  String readLine() {
    final start = pos;
    var trim = 1;
    while (true) {
      final ch = readByte();
      if (ch == 0x0d) {
        trim++;
      }
      if (ch == 0x0a) {
        return utf8.decode(_bytes.sublist(start, pos - trim));
      }
    }
  }

  /// Reads the one-byte record type key (e.g. `v` in `v=0`). Port of
  /// `baseLexer.readType` (base_lexer.go:203).
  ///
  /// Returns `null` where upstream returns key `0` alongside `io.EOF`: both
  /// the "clean end of document" case and the "truncated mid-key" case
  /// collapse to the same outcome upstream (see `handleType` in util.go),
  /// which this mirrors by having both `readByte` failures here return
  /// `null` rather than only the first.
  int? readType() {
    while (true) {
      final int firstByte;
      try {
        firstByte = readByte();
      } on SdpUnexpectedEndOfInputException {
        return null;
      }

      if (_isNewline(firstByte)) {
        continue;
      }

      final int secondByte;
      try {
        secondByte = readByte();
      } on SdpUnexpectedEndOfInputException {
        return null;
      }

      if (secondByte != 0x3d) {
        throw syntaxError();
      }

      return firstByte;
    }
  }
}

bool _isNewline(int ch) => ch == 0x0a || ch == 0x0d;

bool _isWhitespace(int ch) => ch == 0x20 || ch == 0x09;

bool _anyOf(String element, List<String> data) => data.contains(element);

/// Thrown for the sentinel `errFieldMissing` (util.go:29), which upstream
/// uses purely as an internal control-flow signal inside `unmarshalOrigin`
/// (unmarshal.go) to fall back to default `AddressType`/`UnicastAddress`
/// values; it never escapes the public API.
class _FieldMissingException implements Exception {}

extension _LexerRequiredField on _Lexer {
  /// Port of `lexer.readRequiredField` (base_lexer.go:172).
  String readRequiredField() {
    final field = readField();
    if (field.isEmpty) {
      throw _FieldMissingException();
    }
    return field;
  }
}
