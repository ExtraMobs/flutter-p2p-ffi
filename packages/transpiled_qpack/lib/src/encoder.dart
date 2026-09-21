part of 'qpack_impl.dart';

// Port of qpack/encoder.go (github.com/quic-go/qpack, commit
// c415cad59091662a20b7b1c4505fbb177dbda0e3).
//
// Deliberate deviation from upstream: Go's `NewEncoder(w io.Writer)` writes
// each field's bytes straight to a caller-supplied `io.Writer` and returns
// only an `error`. This package has no `dart:io` dependency (a pure codec,
// kept portable to Web/Wasm per the project's rule for codec/multiformat
// packages), and `io.Writer` has no dart:io-free equivalent worth inventing
// here. [Encoder.writeField] instead returns the encoded bytes for that
// field directly (`Uint8List`), which is both dependency-free and a more
// direct "value in, value out" idiom than a writer callback would be. Any
// write failure is now the caller's own problem (writing the returned bytes
// wherever they need to go), so there is nothing left for this method to
// fail on -- it cannot throw for reasons internal to encoding, since every
// [HeaderField] the static table doesn't know is representable as a
// literal.

/// Performs QPACK encoding (RFC 9204), reusing only the static table:
/// this port carries no dynamic table support, matching upstream qpack's
/// current scope.
///
/// Port of the Go `qpack.Encoder` struct. `NewEncoder` becomes the default
/// constructor per this project's convention of not adding artificial
/// `newX` factory functions.
class Encoder {
  bool _wrotePrefix = false;

  /// Encodes [field] and returns the bytes for a single `Write` to the
  /// underlying transport, as Go's `WriteField` did to its `io.Writer`. May
  /// also produce bytes for the Header Block Prefix first, if this is the
  /// first field encoded since construction or the last [close].
  Uint8List writeField(HeaderField field) {
    var buf = <int>[];
    if (!_wrotePrefix) {
      buf = _appendVarInt(buf, 8, 0);
      buf = _appendVarInt(buf, 7, 0);
      _wrotePrefix = true;
    }

    final idxAndVals = _encoderMap[field.name];
    if (idxAndVals != null) {
      final values = idxAndVals.values;
      if (values == null) {
        if (field.value.isEmpty) {
          buf = _writeIndexedField(buf, idxAndVals.idx);
        } else {
          buf = _writeLiteralFieldWithNameReference(buf, field, idxAndVals.idx);
        }
      } else {
        final valIdx = values[field.value];
        if (valIdx != null) {
          buf = _writeIndexedField(buf, valIdx);
        } else {
          buf = _writeLiteralFieldWithNameReference(buf, field, idxAndVals.idx);
        }
      }
    } else {
      buf = _writeLiteralFieldWithoutNameReference(buf, field);
    }

    return Uint8List.fromList(buf);
  }

  /// Declares that the encoding is complete and resets the [Encoder] to be
  /// reused again for a new header block.
  void close() {
    _wrotePrefix = false;
  }

  /// Port of `writeLiteralFieldWithoutNameReference`: encodes a header
  /// field whose name is not present in the static table.
  List<int> _writeLiteralFieldWithoutNameReference(
    List<int> buf,
    HeaderField f,
  ) {
    var offset = buf.length;
    buf = _appendVarInt(buf, 3, _huffmanEncodeLength(f.name));
    buf[offset] ^= 0x20 ^ 0x8;
    buf = _appendHuffmanString(buf, f.name);
    offset = buf.length;
    buf = _appendVarInt(buf, 7, _huffmanEncodeLength(f.value));
    buf[offset] ^= 0x80;
    buf = _appendHuffmanString(buf, f.value);
    return buf;
  }

  /// Port of `writeLiteralFieldWithNameReference`: encodes a header field
  /// whose name is present in one of the tables.
  List<int> _writeLiteralFieldWithNameReference(
    List<int> buf,
    HeaderField f,
    int id,
  ) {
    var offset = buf.length;
    buf = _appendVarInt(buf, 4, id);
    // Set the 01NTxxxx pattern, forcing N to 0 and T to 1.
    buf[offset] ^= 0x50;
    offset = buf.length;
    buf = _appendVarInt(buf, 7, _huffmanEncodeLength(f.value));
    buf[offset] ^= 0x80;
    buf = _appendHuffmanString(buf, f.value);
    return buf;
  }

  /// Port of `writeIndexedField`: encodes an indexed field, meaning it's
  /// entirely defined in one of the tables.
  List<int> _writeIndexedField(List<int> buf, int id) {
    final offset = buf.length;
    buf = _appendVarInt(buf, 6, id);
    // Set the 1Txxxxxx pattern, forcing T to 1.
    buf[offset] ^= 0xc0;
    return buf;
  }
}
