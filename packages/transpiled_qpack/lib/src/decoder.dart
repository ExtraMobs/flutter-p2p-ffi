part of 'qpack_impl.dart';

// Port of qpack/decoder.go (github.com/quic-go/qpack, commit
// c415cad59091662a20b7b1c4505fbb177dbda0e3).
//
// Deliberate deviation from upstream: Go's `Decoder.Decode(p []byte)`
// returns a `DecodeFunc` closure -- `func() (HeaderField, error)` -- that
// the caller invokes repeatedly until it returns `io.EOF`. [Decoder.decode]
// instead returns a lazily-evaluated `Iterable<HeaderField>` built with a
// `sync*` generator: nothing in the body runs until the iterable is first
// advanced (matching the closure's "does nothing until first called"
// behavior, including throwing on that first advance for a malformed
// Header Block Prefix), a normal end of input ends the iteration instead of
// signalling a sentinel `io.EOF` value, and any other decode failure is a
// thrown [FormatException] instead of a returned `error`. This fuses Go's
// `DecodeFunc` type into this one method, since introducing a Dart
// equivalent of a repeatedly-invoked closure-with-tuple-return would be
// less idiomatic than `Iterable<T>` for "call repeatedly until done".
// `readString`, `at`, and the four `parseX` helpers stay as private
// per-file helpers returning `(HeaderField, int bytesConsumed)` records
// instead of Go's `(HeaderField, []byte remaining, error)`, matching the
// same remaining-slice-to-consumed-count adaptation used in varint.dart.

/// Decodes QPACK header blocks (RFC 9204). A [Decoder] can be reused to
/// decode multiple header blocks on different streams on the same
/// connection (e.g., headers then trailers) -- this port carries no
/// dynamic table support, matching upstream qpack's current scope, so reuse
/// has no observable state to reset between calls.
///
/// Port of the Go `qpack.Decoder` struct. `NewDecoder` becomes the default
/// (const) constructor, since the Go struct is empty state.
class Decoder {
  /// Creates a decoder. Port of Go's `NewDecoder`.
  const Decoder();

  /// Decodes header fields from the given header block [p]. Does not copy
  /// [p]; the caller must ensure it remains valid while the returned
  /// [Iterable] is consumed.
  ///
  /// Throws [FormatException] on any decoding error, including a
  /// non-zero Required Insert Count or Base (this port has no dynamic
  /// table, so both are always required to be zero), a reference to the
  /// dynamic table, an out-of-range static table index, or truncated input.
  Iterable<HeaderField> decode(List<int> p) sync* {
    var offset = 0;

    final (requiredInsertCount, riConsumed) = _readVarInt(8, p, offset);
    offset += riConsumed;
    if (requiredInsertCount != 0) {
      throw const FormatException('expected Required Insert Count to be zero');
    }

    final (base, baseConsumed) = _readVarInt(7, p, offset);
    offset += baseConsumed;
    if (base != 0) {
      throw const FormatException('expected Base to be zero');
    }

    while (offset < p.length) {
      final b = p[offset];
      final HeaderField hf;
      final int consumed;
      if ((b & 0x80) > 0) {
        // 1xxxxxxx
        (hf, consumed) = _parseIndexedHeaderField(p, offset);
      } else if ((b & 0xc0) == 0x40) {
        // 01xxxxxx
        (hf, consumed) = _parseLiteralHeaderField(p, offset);
      } else if ((b & 0xe0) == 0x20) {
        // 001xxxxx
        (hf, consumed) = _parseLiteralHeaderFieldWithoutNameReference(
          p,
          offset,
        );
      } else {
        throw FormatException('unexpected type byte: 0x${b.toRadixString(16)}');
      }
      offset += consumed;
      yield hf;
    }
  }
}

/// Error message reproduced verbatim from Go's unexported
/// `errNoDynamicTable`.
const String _noDynamicTableMessage = 'no dynamic table';

/// Port of `(*Decoder).parseIndexedHeaderField`.
(HeaderField, int) _parseIndexedHeaderField(List<int> buf, int offset) {
  if (buf[offset] & 0x40 == 0) {
    throw const FormatException(_noDynamicTableMessage);
  }
  final (index, consumed) = _readVarInt(6, buf, offset);
  return (_staticTableAt(index), consumed);
}

/// Port of `(*Decoder).parseLiteralHeaderField`: a literal header field
/// whose name references one of the tables.
(HeaderField, int) _parseLiteralHeaderField(List<int> buf, int offset) {
  if (buf[offset] & 0x10 == 0) {
    throw const FormatException(_noDynamicTableMessage);
  }
  // The N-bit doesn't need checking here. It's only relevant when
  // re-encoding header fields, and determines whether the header field can
  // be added to the dynamic table. Since we don't support the dynamic
  // table, it can be ignored.
  final (index, idxConsumed) = _readVarInt(4, buf, offset);
  final hf = _staticTableAt(index);
  final valueOffset = offset + idxConsumed;
  if (valueOffset >= buf.length) {
    throw const FormatException('unexpected EOF while reading QPACK value');
  }
  final usesHuffman = buf[valueOffset] & 0x80 > 0;
  final (value, valConsumed) = _readString(buf, valueOffset, 7, usesHuffman);
  return (HeaderField(name: hf.name, value: value), idxConsumed + valConsumed);
}

/// Port of `(*Decoder).parseLiteralHeaderFieldWithoutNameReference`.
(HeaderField, int) _parseLiteralHeaderFieldWithoutNameReference(
  List<int> buf,
  int offset,
) {
  final usesHuffmanForName = buf[offset] & 0x8 > 0;
  final (name, nameConsumed) = _readString(buf, offset, 3, usesHuffmanForName);
  final valueOffset = offset + nameConsumed;
  if (valueOffset >= buf.length) {
    throw const FormatException('unexpected EOF while reading QPACK value');
  }
  final usesHuffmanForVal = buf[valueOffset] & 0x80 > 0;
  final (value, valConsumed) = _readString(
    buf,
    valueOffset,
    7,
    usesHuffmanForVal,
  );
  return (HeaderField(name: name, value: value), nameConsumed + valConsumed);
}

/// Port of `(*Decoder).readString`. Reads a length-prefixed, optionally
/// Huffman-encoded string with an [n]-bit length prefix starting at
/// [offset] in [data]. Returns the decoded string together with the total
/// number of bytes consumed (prefix length included).
(String, int) _readString(List<int> data, int offset, int n, bool usesHuffman) {
  final (l, lenConsumed) = _readVarInt(n, data, offset);
  final strStart = offset + lenConsumed;
  if (data.length - strStart < l) {
    throw const FormatException('unexpected EOF while reading QPACK string');
  }
  final raw = data.sublist(strStart, strStart + l);
  final val = usesHuffman
      ? _huffmanDecodeToString(raw)
      : String.fromCharCodes(raw);
  return (val, lenConsumed + l);
}

/// Port of `(*Decoder).at`. Throws a [FormatException] reproducing Go's
/// `invalidIndexError` message when [index] is out of range for the static
/// table (there is no dynamic table in this port).
HeaderField _staticTableAt(int index) {
  if (index >= _staticTableEntries.length) {
    throw FormatException('invalid indexed representation index $index');
  }
  return _staticTableEntries[index];
}
